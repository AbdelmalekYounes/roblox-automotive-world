--!strict
-- Clôture de la phase 1 de l'Aster : file ordonnée des applications d'apparence (`ApplyQueue`).
-- Scénario de régression : changements successifs et opérations lentes simulées (le moteur est
-- remplacé par des fonctions qui attendent). Vérifie qu'une opération expirée ne peut jamais
-- appliquer une ancienne apparence après un choix plus récent.

local task = require("@lune/task")

return function(T: any, H: any)
    local ApplyQueue = H.require("ServerScriptService.AutomotiveWorldServer.Avatar.ApplyQueue")

    T.suite("Clôture Aster phase 1 — file des applications d'apparence")

    -- « Moteur » simulé : applique une valeur après `delay` secondes et journalise l'ordre.
    local function engine()
        local self = { Applied = nil :: any, Log = {} :: { string } }
        function self.apply(value: any, delay: number): () -> ()
            return function()
                table.insert(self.Log, "début " .. tostring(value))
                task.wait(delay)
                self.Applied = value
                table.insert(self.Log, "fin " .. tostring(value))
            end
        end
        return self
    end

    local function waitIdle(queue: any, key: any, timeout: number)
        local start = os.clock()
        while queue:pending(key) > 0 and os.clock() - start < timeout do
            task.wait(0.02)
        end
    end

    T.test("Opération expirée : garde son tour, la suivante applique l'état le plus récent", function()
        local queue = ApplyQueue.new({
            Scheduler = task,
            TimeoutS = 0.1,
            AbandonS = 2,
            PollS = 0.01,
        })
        local e = engine()
        local key = {}
        local outcomeA = queue:run(key, e.apply("ancienne", 0.4))
        T.equal(outcomeA, "Timeout", "appelant libéré au délai")
        T.equal(queue:pending(key), 1, "opération expirée toujours en cours")
        local outcomeB = queue:run(key, e.apply("nouvelle", 0.05))
        T.equal(outcomeB, "Ok", "la suivante aboutit")
        T.equal(e.Applied, "nouvelle", "état final : le choix le plus récent")
        T.equal(
            table.concat(e.Log, " / "),
            "début ancienne / fin ancienne / début nouvelle / fin nouvelle",
            "aucun chevauchement : la suivante attend la fin réelle"
        )
        task.wait(0.5)
        T.equal(e.Applied, "nouvelle", "rien d'ancien appliqué après coup")
        T.equal(queue:pending(key), 0, "file vide")
    end)

    T.test("Changements successifs rapides : ordre des demandes respecté, dernier choix appliqué", function()
        local queue = ApplyQueue.new({
            Scheduler = task,
            TimeoutS = 0.05,
            AbandonS = 2,
            PollS = 0.01,
        })
        local e = engine()
        local key = {}
        local delays = { 0.15, 0.02, 0.12, 0.01, 0.08 }
        for index, delay in delays do
            task.spawn(function()
                queue:run(key, e.apply(index, delay))
            end)
            task.wait(0.005)
        end
        waitIdle(queue, key, 3)
        T.equal(e.Applied, 5, "état final : la 5e demande")
        local order = {}
        for _, line in e.Log do
            local value = string.match(line, "^début (%d+)$")
            if value then
                table.insert(order, value)
            end
        end
        T.equal(table.concat(order, ","), "1,2,3,4,5", "exécution dans l'ordre des demandes")
        for index = 1, #e.Log - 1, 2 do
            T.truthy(string.find(e.Log[index], "^début") ~= nil, "début avant fin (pas de chevauchement)")
            T.truthy(string.find(e.Log[index + 1], "^fin") ~= nil, "fin avant le début suivant")
        end
    end)

    T.test("Opération bloquée : abandonnée, puis réconciliée si elle se termine après coup", function()
        local staleCalls = 0
        local desired = "nouvelle"
        local e = engine()
        local queue: any
        queue = ApplyQueue.new({
            Scheduler = task,
            TimeoutS = 0.05,
            AbandonS = 0.2,
            PollS = 0.01,
            OnStale = function(key: any)
                staleCalls += 1
                -- Réconciliation : réapplique l'état voulu, à son tour dans la file.
                queue:run(key, e.apply(desired, 0.01))
            end,
        })
        local key = {}
        T.equal(queue:run(key, e.apply("ancienne", 0.6)), "Timeout", "bloquée : appelant libéré")
        local started = os.clock()
        T.equal(queue:run(key, e.apply("nouvelle", 0.02)), "Ok", "file reprise après abandon")
        T.truthy(os.clock() - started >= 0.1, "attente de l'abandon avant de reprendre")
        T.equal(e.Applied, "nouvelle", "nouvelle apparence appliquée")
        task.wait(0.6) -- l'opération bloquée se termine et écrase l'état…
        waitIdle(queue, key, 1)
        T.equal(staleCalls, 1, "fin tardive détectée une fois")
        T.equal(queue.Stale, 1, "compteur de fins tardives")
        T.equal(e.Applied, "nouvelle", "… puis l'état voulu est rétabli")
    end)

    T.test("Erreur du moteur : issue « Failed », la file continue ; clés indépendantes", function()
        local queue = ApplyQueue.new({
            Scheduler = task,
            TimeoutS = 0.5,
            AbandonS = 2,
            PollS = 0.01,
        })
        local outcome, message = queue:run("a", function()
            error("refus simulé")
        end)
        T.equal(outcome, "Failed")
        T.truthy(string.find(message, "refus simulé", 1, true) ~= nil, "message conservé")
        T.equal(queue:pending("a"), 0, "tour libéré après erreur")
        local e = engine()
        local slowDone = false
        task.spawn(function()
            queue:run("lente", e.apply("x", 0.3))
            slowDone = true
        end)
        task.wait(0.01)
        local start = os.clock()
        T.equal(queue:run("rapide", e.apply("y", 0.01)), "Ok")
        T.truthy(os.clock() - start < 0.2, "une autre clé n'attend pas")
        T.truthy(not slowDone, "la clé lente est encore en cours")
        waitIdle(queue, "lente", 1)
    end)

    -- Gabarit final de l'Aster : retiré avec le modèle (lot BASE-01).

    T.test("AvatarService : toutes les applications passent par la file", function()
        local node = H.game()
        for segment in string.gmatch("ServerScriptService.AutomotiveWorldServer.Avatar.AvatarService", "[^%.]+") do
            node = node:FindFirstChild(segment)
        end
        local source = node.Source
        local direct = 0
        for line in string.gmatch(source, "[^\n]+") do
            if string.find(line, "ApplyDescriptionAsync(", 1, true) and not string.find(line, "^%s*%-%-") then
                direct += 1
            end
        end
        -- Trois appels du moteur, chacun dans une opération de la file (corps, tenue, rétablissement).
        T.equal(direct, 3, "trois appels au moteur")
        local queued = 0
        for _ in string.gmatch(source, "applyQueue:run%(") do
            queued += 1
        end
        T.equal(queued, 3, "trois passages par la file")
        T.truthy(string.find(source, "applyBounded", 1, true) == nil, "ancienne attente non ordonnée retirée")
    end)
end
