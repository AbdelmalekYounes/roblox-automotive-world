-- Essais CLIENT du lot 0.9.1 (session « ui », place de développement, 1 joueur).
-- Parcours des interfaces par de VRAIS clics et de VRAIES touches : le module AW_TestGui
-- imprime des commandes que l'outil de la VM exécute par SendInput (voir GuiDriver.luau
-- et tools/vm/ScreenCapture.cs). Aucune fonction d'interface ni aucun RemoteEvent n'est
-- appelé pour AGIR ; les remotes du jeu (« Snapshot », « Status ») et AWTestQuery ne
-- servent qu'à LIRE le résultat côté serveur.
-- Seules aides instrumentées, signalées dans le rapport (préfixe « placement ») :
-- le personnage est posé près d'une invite (au lieu de marcher jusqu'à elle) ; l'invite
-- est ensuite déclenchée par la vraie touche E.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
-- « ui_marche » : seulement la concession et le marché (reproduction ciblée, lot 0.9.1).
local sessionName = ReplicatedStorage:GetAttribute("AWTestSession")
if sessionName ~= "ui" and sessionName ~= "ui_marche" then
    return
end
local ONLY: { [string]: boolean }? = if sessionName == "ui_marche" then { concession = true, marche = true } else nil

local steps = {}
local measures = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end
local function trace(message: string)
    print(string.format("[AW_Test] ui %.1f s : %s", os.clock() - sessionStart, message))
end

local Gui = require(ReplicatedStorage:WaitForChild("AW_TestGui", 30)) :: any
local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30) :: RemoteEvent
local query = ReplicatedStorage:WaitForChild("AWTestQuery", 30) :: RemoteFunction
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local client = player:WaitForChild("PlayerScripts"):WaitForChild("AutomotiveWorldClient")
local VehicleController = require(client:WaitForChild("Vehicles"):WaitForChild("VehicleController", 10)) :: any
local waitFor = Gui.waitFor

-- Lecture de l'état autoritaire (test seulement).
local function server(): any
    local ok, result = pcall(function()
        return query:InvokeServer()
    end)
    return if ok and type(result) == "table" then result else { Ready = false }
end

-- Lecture par le remote du jeu (même réponse que celle que reçoit l'interface).
-- Lectures espacées de 0,6 s (limiteur : 6 demandes, 2/s) : une lecture refusée
-- (« RateLimited ») ne doit jamais passer pour un état vide (faux succès corrigé après la
-- tâche 20261103-210055).
local lastRead = 0
local function read(folder: string, action: string): any
    local wait = 0.6 - (os.clock() - lastRead)
    if wait > 0 then
        task.wait(wait)
    end
    lastRead = os.clock()
    local remote = (ReplicatedStorage:WaitForChild(folder, 10) :: Instance):WaitForChild(
            "Request",
            10
        ) :: RemoteFunction
    local ok, response = pcall(function()
        return remote:InvokeServer(action, { RequestId = HttpService:GenerateGUID(false) })
    end)
    return if ok and type(response) == "table" then response else { Status = "Error", Error = tostring(response) }
end

local function screen(name: string): Instance?
    return playerGui:FindFirstChild(name)
end

-- Bouton affiché dont le texte vaut exactement « text » (onglets, « Fermer »).
-- « clipped » : accepte aussi un bouton affiché mais rogné par un cadre défilant.
local function exact(root: Instance?, text: string, clipped: boolean?): GuiButton?
    if root == nil then
        return nil
    end
    for _, item in root:GetDescendants() do
        if item:IsA("TextButton") and item.Text == text and (Gui.shown(item) or clipped and Gui.present(item)) then
            return item
        end
    end
    return nil
end

local function anyShown(root: Instance?): boolean
    if root == nil then
        return false
    end
    if root:IsA("LayerCollector") and not root.Enabled then
        return false
    end
    for _, item in root:GetChildren() do
        if item:IsA("Frame") and Gui.shown(item) and item.AbsoluteSize.X >= 400 then
            return true
        end
    end
    return false
end

-- Pied de panneau : dernier libellé affiché en bas du grand cadre (résultat, erreur).
local function footerText(root: Instance?): string
    if root == nil then
        return ""
    end
    local best, bestY = "", -1
    for _, item in root:GetDescendants() do
        if item:IsA("TextLabel") and Gui.shown(item) and item.Text ~= "" then
            local y = item.AbsolutePosition.Y
            if y > bestY then
                best, bestY = item.Text, y
            end
        end
    end
    return best
end

local function notifications(): string
    local root = screen("AWNotifications")
    local texts = {}
    if root then
        for _, item in root:GetDescendants() do
            if item:IsA("TextLabel") and Gui.shown(item) and item.Text ~= "" then
                table.insert(texts, item.Text)
            end
        end
    end
    return table.concat(texts, " | ")
end

local function rootPart(): BasePart?
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Placement (instrumenté, signalé) : personnage posé à « distance » studs d'un point.
local function placeNear(target: Vector3, distance: number, label: string)
    local root = rootPart()
    if root == nil then
        return
    end
    local from = target + Vector3.new(distance, 3, 0)
    root.CFrame = CFrame.lookAt(from, Vector3.new(target.X, from.Y, target.Z))
    root.AssemblyLinearVelocity = Vector3.zero
    record(
        "ui.placement." .. label,
        true,
        string.format("personnage posé à %d st de la cible (instrumenté)", distance)
    )
    task.wait(1.2)
end

-- Clic réel enregistré comme étape.
local function click(name: string, item: GuiObject?, label: string): boolean
    local ok, detail = Gui.click(item, label)
    record(name, ok, detail)
    task.wait(0.35)
    return ok
end

local initial = server()
waitFor(function()
    return initial.Ready or (function()
        initial = server()
        return initial.Ready
    end)()
end, 40)
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart", 20)
task.wait(3)

---------------------------------------------------------------------------
-- 1. Étalonnage des vraies entrées.
---------------------------------------------------------------------------
local mouseOk, mouseDetail = Gui.calibrate(3)
record("ui.entrees.souris_reelle_recue", mouseOk, mouseDetail)
if not mouseOk then
    record(
        "ui.entrees.campagne_interface",
        false,
        "aucun clic réel n'a atteint le jeu : parcours d'interface NON EXÉCUTÉS (rien n'est simulé à la place)"
    )
    reportEvent:FireServer({ vehicle = "ui", steps = steps, measures = measures, gui = Gui.report() })
    return
end
local keysOk, keysDetail = Gui.calibrateKeys()
record("ui.entrees.clavier_reel_recu", keysOk, keysDetail)
Gui.park()

local function phase(name: string, body: () -> ())
    if ONLY and not ONLY[name] then
        return
    end
    trace("phase " .. name)
    local ok, err = xpcall(body, debug.traceback)
    if not ok then
        record("ui." .. name .. ".execution", false, err)
    end
    -- Rien ne doit rester ouvert d'une phase à l'autre.
    task.wait(0.5)
end

---------------------------------------------------------------------------
-- 2. Parcours d'arrivée (fenêtre ouverte d'elle-même au premier lancement).
---------------------------------------------------------------------------
phase("arrivee", function()
    local window = screen("AWOnboarding")
    local opened = waitFor(function()
        return Gui.findButton(window, "Suivant") ~= nil or Gui.findButton(window, "Choisir") ~= nil
    end, 25)
    record("ui.arrivee.ouverte_au_lancement", opened, server().Onboarding and server().Onboarding.Step)
    Gui.shot("arrivee_bienvenue", { step = "Welcome" })
    local visited = {}
    local cancelled = false
    local visibilityChecked = false
    for _ = 1, 14 do
        local state = server()
        local step = state.Onboarding and state.Onboarding.Step or "?"
        table.insert(visited, step)
        local confirm = exact(window, "Confirmer", true)
        local cancel = exact(window, "Annuler", true)
        local choose = Gui.findButton(window, "Choisir la")
        local enter = Gui.findButton(window, "Entrer dans le monde")
        local nextButton = exact(window, "Suivant")
        if confirm and cancel then
            task.wait(0.4) -- garde de confirmation (appui frais ≥ 0,25 s)
            if not visibilityChecked then
                -- QA-F13 : la confirmation doit apparaître sans que le joueur ait à la chercher.
                visibilityChecked = true
                record(
                    "ui.arrivee.confirmation_visible_sans_defilement",
                    Gui.shown(confirm) and Gui.shown(cancel),
                    string.format("Confirmer à y = %d", confirm.AbsolutePosition.Y)
                )
                Gui.shot("arrivee_confirmation_affichee", { step = step })
            end
            -- Sinon, défilement par la vraie molette, comme le ferait un joueur.
            local _, notches = Gui.reveal(if cancelled then confirm else cancel)
            if notches > 0 then
                record("ui.arrivee.info_defilement_molette", true, notches .. " cran(s)")
            end
            if not cancelled then
                click("ui.arrivee.annuler_le_choix", cancel, "Annuler")
                task.wait(1)
                record("ui.arrivee.annulation_sans_effet", server().Starter.State ~= "Chosen", server().Starter.State)
                cancelled = true
            else
                Gui.shot("arrivee_confirmation_choix", { step = step })
                click("ui.arrivee.confirmer_le_choix", confirm, "Confirmer")
                local chosen = waitFor(function()
                    return server().Starter.State == "Chosen"
                end, 8)
                record("ui.arrivee.choix_enregistre_serveur", chosen, server().Starter.ModelId)
            end
        elseif choose and server().Starter.State ~= "Chosen" then
            Gui.shot("arrivee_candidats", { step = step })
            click("ui.arrivee.choisir_" .. #visited, choose, choose.Text)
            task.wait(0.8)
            record(
                "ui.arrivee.choix_demande_confirmation",
                server().Starter.State ~= "Chosen" and exact(window, "Confirmer", true) ~= nil,
                "état serveur après « Choisir » : " .. tostring(server().Starter.State)
            )
        elseif enter then
            Gui.shot("arrivee_fin", { step = step })
            click("ui.arrivee.entrer_dans_le_monde", enter, "Entrer dans le monde")
            local closed = waitFor(function()
                return not anyShown(window)
            end, 5)
            record("ui.arrivee.fenetre_fermee", closed)
            break
        elseif nextButton then
            click("ui.arrivee.suivant_" .. step, nextButton, "Suivant (" .. step .. ")")
            local before = step
            waitFor(function()
                local now = server().Onboarding
                return now ~= nil and now.Step ~= before
            end, 6)
            Gui.shot("arrivee_" .. string.lower(tostring(server().Onboarding and server().Onboarding.Step)), {})
        else
            task.wait(1)
        end
    end
    record("ui.arrivee.etapes_parcourues", server().Onboarding.Step == "Done", table.concat(visited, " → "))
end)

---------------------------------------------------------------------------
-- 3. Garage, collection, personnalisation, propriétés (touche P).
---------------------------------------------------------------------------
local function openByKey(key: string, guiName: string, label: string): boolean
    Gui.key(key)
    local ok = waitFor(function()
        return anyShown(screen(guiName))
    end, 4)
    record("ui." .. label .. ".ouverture_touche_" .. key, ok, guiName)
    if ok then
        local selected = GuiService.SelectedObject
        record(
            "ui." .. label .. ".info_focus",
            true,
            if selected then selected:GetFullName() .. " « " .. tostring((selected :: any).Text) .. " »" else "aucun"
        )
    end
    return ok
end

local function tabs(guiName: string, label: string, names: { string }, after: ((string) -> ())?)
    local root = screen(guiName)
    for _, tab in names do
        local button = exact(root, tab)
        if click("ui." .. label .. ".onglet_" .. tab, button, tab) then
            task.wait(0.8)
            Gui.shot(label .. "_" .. tab, { tab = tab })
            if after then
                after(tab)
            end
        end
    end
end

local function closeWith(guiName: string, label: string, how: string)
    local root = screen(guiName)
    if how == "Fermer" then
        click("ui." .. label .. ".bouton_fermer", exact(root, "Fermer"), "Fermer")
    else
        Gui.key(how)
    end
    local closed = waitFor(function()
        return not anyShown(screen(guiName))
    end, 4)
    record("ui." .. label .. ".fermeture_" .. how, closed)
end

phase("garage", function()
    local before = server()
    if not openByKey("P", "AWProgression", "garage") then
        return
    end
    local root = screen("AWProgression")
    tabs(
        "AWProgression",
        "garage",
        { "Collection", "Véhicule", "Propriétés", "Préparation", "Configurations", "Invitations" },
        function(tab)
            if tab == "Configurations" then
                local box: TextBox? = nil
                for _, item in (root :: Instance):GetDescendants() do
                    if item:IsA("TextBox") and Gui.shown(item) then
                        box = item
                    end
                end
                if box then
                    Gui.click(box, "champ du nom")
                    task.wait(0.4)
                    Gui.type("Essai GUI 1")
                    local typed = waitFor(function()
                        return (box :: TextBox).Text == "Essai GUI 1"
                    end, 4)
                    record("ui.garage.saisie_texte_reelle", typed, "texte lu : « " .. (box :: TextBox).Text .. " »")
                    Gui.key("Return")
                    task.wait(0.5)
                    local save = Gui.findButton(root, "Enregistrer ici")
                    if click("ui.garage.enregistrer_configuration", save, "Enregistrer ici") then
                        task.wait(2)
                        record("ui.garage.info_retour_enregistrement", true, footerText(root))
                        Gui.shot("garage_configuration_retour", {})
                    end
                else
                    record("ui.garage.saisie_texte_reelle", false, "champ texte absent de l'onglet")
                end
            elseif tab == "Collection" then
                record("ui.garage.info_collection", true, footerText(root))
                -- Sélection d'un exemplaire (exigée par les onglets Véhicule et Configurations).
                local row = Gui.findButton(root, "Prototype d'essai P-01")
                if click("ui.garage.selection_vehicule", row, "Prototype d'essai P-01") then
                    task.wait(1)
                    Gui.shot("garage_vehicule_selectionne", {})
                end
            end
        end
    )
    -- Touche Entrée alors que le focus (contour) est resté sur un autre bouton que l'onglet
    -- actif : observation d'une éventuelle action involontaire (aucune attendue côté serveur).
    local selected = GuiService.SelectedObject
    local beforeTexts = footerText(root)
    local stateBefore = server()
    Gui.key("Return")
    task.wait(1.2)
    local stateAfter = server()
    record(
        "ui.garage.info_touche_entree_avec_focus",
        true,
        string.format(
            "focus %s ; pied « %s » → « %s »",
            if selected then "« " .. tostring((selected :: any).Text) .. " »" else "aucun",
            beforeTexts,
            footerText(root)
        )
    )
    record(
        "ui.garage.entree_sans_effet_serveur",
        stateAfter.Balance == stateBefore.Balance and stateAfter.VehicleCount == stateBefore.VehicleCount,
        string.format("solde %d → %d", stateBefore.Balance, stateAfter.Balance)
    )
    Gui.shot("garage_apres_touche_entree", {})
    closeWith("AWProgression", "garage", "Fermer")
    local after = server()
    record(
        "ui.garage.aucune_action_involontaire",
        after.Balance == before.Balance and after.VehicleCount == before.VehicleCount,
        string.format(
            "solde %d → %d, véhicules %d → %d",
            before.Balance,
            after.Balance,
            before.VehicleCount,
            after.VehicleCount
        )
    )
end)

---------------------------------------------------------------------------
-- 4. Économie : métiers, concession, marché, immobilier, services (touche J).
---------------------------------------------------------------------------
phase("economie", function()
    local before = server()
    if not openByKey("J", "AWEconomy", "economie") then
        return
    end
    local root = screen("AWEconomy")
    tabs("AWEconomy", "economie", { "Portefeuille", "Concession", "Marché", "Immobilier", "Services", "Métiers" })
    -- Métier lancé et abandonné par l'interface ; résultat lu sur le serveur.
    local job = Gui.findButton(root, "Livraison de colis")
    if click("ui.economie.demarrer_metier", job, "Livraison de colis") then
        local started = waitFor(function()
            local snapshot = read("AWEconomy", "Snapshot")
            return snapshot.Snapshot ~= nil and snapshot.Snapshot.Mission ~= nil
                or snapshot.Result ~= nil and snapshot.Result.Mission ~= nil
        end, 6)
        record("ui.economie.mission_creee_serveur", started, notifications())
        Gui.shot("economie_mission_en_cours", {})
        local abandon = Gui.findButton(root, "Abandonner")
        if click("ui.economie.abandonner_metier", abandon, "Abandonner (sans paiement)") then
            local ended = waitFor(function()
                local snapshot = read("AWEconomy", "Snapshot")
                return snapshot.Snapshot ~= nil and snapshot.Snapshot.Mission == nil
            end, 8)
            record("ui.economie.mission_abandonnee_serveur", ended, footerText(root))
        end
    end
    -- Concession hors d'un point de vente : bouton grisé, aucun achat.
    local dealerTab = exact(root, "Concession")
    if click("ui.economie.onglet_concession_hors_lieu", dealerTab, "Concession") then
        task.wait(0.8)
        local quote = Gui.findButton(root, "Devis d'achat")
        if quote then
            Gui.click(quote, "Devis d'achat (grisé)")
            task.wait(1.2)
            record(
                "ui.economie.devis_grise_sans_effet",
                exact(root, "Confirmer") == nil and server().Balance == before.Balance,
                "solde " .. server().Balance
            )
        end
    end
    closeWith("AWEconomy", "economie", "Backspace")
    local after = server()
    record(
        "ui.economie.aucune_action_involontaire",
        after.Balance == before.Balance and after.VehicleCount == before.VehicleCount,
        string.format(
            "solde %d → %d, véhicules %d → %d",
            before.Balance,
            after.Balance,
            before.VehicleCount,
            after.VehicleCount
        )
    )
end)

-- Concession par son invite (vraie touche E), devis, annulation, puis achat confirmé.
phase("concession", function()
    local zone = Workspace:FindFirstChild("AutomotiveTestZone")
    local part = zone and zone:FindFirstChild("ConcessionEssai", true) :: BasePart?
    if part == nil then
        record("ui.concession.invite_trouvee", false, "ConcessionEssai absente")
        return
    end
    placeNear(part.Position, 6, "concession")
    local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
    Gui.key("E", math.floor(((prompt and prompt.HoldDuration) or 0.3) * 1000) + 500)
    local opened = waitFor(function()
        return anyShown(screen("AWEconomy"))
    end, 5)
    record("ui.concession.ouverture_par_invite_touche_E", opened)
    if not opened then
        return
    end
    local root = screen("AWEconomy")
    task.wait(1)
    Gui.shot("concession_catalogue", {})
    local before = server()
    -- Premier bouton ACTIF (les boutons grisés n'ont ni couleur automatique ni action).
    local function activeQuote(): GuiButton?
        for _, item in (root :: Instance):GetDescendants() do
            if item:IsA("TextButton") and item.Text == "Devis d'achat" and item.AutoButtonColor and Gui.shown(item) then
                return item
            end
        end
        return nil
    end
    if click("ui.concession.devis_achat", activeQuote(), "Devis d'achat") then
        local confirmShown = waitFor(function()
            return exact(root, "Confirmer") ~= nil
        end, 5)
        record("ui.concession.confirmation_affichee", confirmShown, footerText(root))
        Gui.shot("concession_confirmation", {})
        task.wait(0.4)
        click("ui.concession.annuler", exact(root, "Annuler"), "Annuler")
        task.wait(1)
        record("ui.concession.annulation_sans_effet", server().Balance == before.Balance, "solde " .. server().Balance)
        if click("ui.concession.devis_achat_2", activeQuote(), "Devis d'achat") then
            waitFor(function()
                return exact(root, "Confirmer") ~= nil
            end, 5)
            task.wait(0.45)
            click("ui.concession.confirmer_achat", exact(root, "Confirmer"), "Confirmer")
            local bought = waitFor(function()
                local now = server()
                return now.VehicleCount == before.VehicleCount + 1 and now.Balance < before.Balance
            end, 8)
            local after = server()
            record(
                "ui.concession.achat_verifie_serveur",
                bought,
                string.format(
                    "solde %d → %d, véhicules %d → %d, pied : %s",
                    before.Balance,
                    after.Balance,
                    before.VehicleCount,
                    after.VehicleCount,
                    footerText(root)
                )
            )
            Gui.shot("concession_achat_confirme", {})
        end
    end
    closeWith("AWEconomy", "concession", "Fermer")
end)

---------------------------------------------------------------------------
-- 5. Courses et classements (touche K).
---------------------------------------------------------------------------
-- Marché : mise en vente du véhicule acheté, puis retrait de l'annonce (vrais clics).
-- nil si la lecture a échoué (jamais confondu avec « aucune annonce »).
local function myListings(): { any }?
    local snapshot = read("AWEconomy", "Snapshot").Snapshot
    if snapshot == nil then
        return nil
    end
    local mine = {}
    for _, listing in snapshot.Listings or {} do
        if listing.Mine then
            table.insert(mine, listing)
        end
    end
    return mine
end
local function activeButton(root: Instance?, text: string): GuiButton?
    if root == nil then
        return nil
    end
    for _, item in root:GetDescendants() do
        if item:IsA("TextButton") and item.Text == text and item.AutoButtonColor and Gui.present(item) then
            return item
        end
    end
    return nil
end

phase("marche", function()
    if not openByKey("J", "AWEconomy", "marche") then
        return
    end
    local root = screen("AWEconomy")
    click("ui.marche.onglet", exact(root, "Marché"), "Marché")
    task.wait(1.2)
    local listButton = activeButton(root, "Devis de mise en vente")
    Gui.reveal(listButton)
    if not click("ui.marche.devis_mise_en_vente", listButton, "Devis de mise en vente") then
        record("ui.marche.info_vehicules", true, "aucun exemplaire cessible : " .. footerText(root))
        closeWith("AWEconomy", "marche", "Fermer")
        return
    end
    waitFor(function()
        return exact(root, "Confirmer") ~= nil
    end, 5)
    task.wait(0.45)
    Gui.shot("marche_confirmation_mise_en_vente", {})
    click("ui.marche.confirmer_mise_en_vente", exact(root, "Confirmer"), "Confirmer")
    local listed = waitFor(function()
        local mine = myListings()
        return mine ~= nil and #mine > 0
    end, 10)
    record("ui.marche.annonce_publiee_serveur", listed, footerText(root))
    task.wait(1)
    Gui.shot("marche_annonce_publiee", {})
    local withdraw = activeButton(root, "Retirer l'annonce")
    Gui.reveal(withdraw)
    if click("ui.marche.retirer_annonce", withdraw, "Retirer l'annonce") then
        local remaining: { any }? = nil
        local removed = waitFor(function()
            remaining = myListings()
            return remaining ~= nil and #(remaining :: { any }) == 0
        end, 8)
        record(
            "ui.marche.annonce_retiree_serveur",
            removed,
            string.format(
                "pied « %s », annonces restantes %s",
                footerText(root),
                if remaining then tostring(#(remaining :: { any })) else "lecture refusée"
            )
        )
        Gui.shot("marche_apres_retrait", {})
    end
    closeWith("AWEconomy", "marche", "Fermer")
end)

phase("courses", function()
    if not openByKey("K", "AWRacing", "courses") then
        return
    end
    local root = screen("AWRacing")
    tabs("AWRacing", "courses", { "Épreuves", "Mon épreuve", "Résultats", "Classements" }, function(tab)
        if tab == "Classements" then
            local drift = Gui.findButton(root, "Tableau drift")
            if click("ui.courses.tableau_drift", drift, "Tableau drift") then
                task.wait(1.5)
                Gui.shot("classements_drift", {})
                record("ui.courses.info_tableau_drift", true, footerText(root))
            end
        elseif tab == "Épreuves" then
            local course = Gui.findButton(root, "Sprint")
            if click("ui.courses.detail_parcours", course, if course then course.Text else "parcours") then
                task.wait(1)
                Gui.shot("courses_detail_parcours", {})
                local records = Gui.findButton(root, "Records du parcours")
                if click("ui.courses.records_parcours", records, "Records du parcours") then
                    task.wait(1.5)
                    Gui.shot("courses_records", {})
                end
            end
        end
    end)
    closeWith("AWRacing", "courses", "Fermer")
end)

---------------------------------------------------------------------------
-- 6. Téléphone, paramètres, social (touche T).
---------------------------------------------------------------------------
local function phoneOpen(): boolean
    local phone = screen("AWPhone") :: ScreenGui?
    return phone ~= nil and phone.Enabled
end
local function phoneButton(pattern: string): GuiButton?
    return Gui.findButton(screen("AWPhone"), pattern)
end

phase("telephone", function()
    Gui.key("T")
    local opened = waitFor(phoneOpen, 4)
    record("ui.telephone.ouverture_touche_T", opened)
    if not opened then
        return
    end
    local held = waitFor(function()
        return player.Character ~= nil and player.Character:FindFirstChild("TelephoneAW", true) ~= nil
    end, 4)
    record("ui.telephone.en_main_serveur", held, "modèle TelephoneAW sur le personnage")
    Gui.shot("telephone_accueil", {})
    -- Paramètres : niveau du HUD changé par un clic, lu ensuite sur le serveur.
    if click("ui.telephone.app_parametres", phoneButton("Paramètres"), "Paramètres") then
        task.wait(0.8)
        Gui.shot("telephone_parametres", {})
        click("ui.telephone.page_interface", phoneButton("Interface"), "Interface")
        task.wait(0.6)
        local hud = phoneButton("Niveau du HUD")
        local beforeText = if hud then hud.Text else ""
        local beforePrefs = server().Preferences
        if click("ui.telephone.niveau_hud", hud, beforeText) then
            task.wait(0.8)
            local after = phoneButton("Niveau du HUD")
            record(
                "ui.telephone.reglage_change_ecran",
                after ~= nil and after.Text ~= beforeText,
                (after and after.Text) or "?"
            )
            local saved = waitFor(function()
                local prefs = server().Preferences
                return HttpService:JSONEncode(prefs) ~= HttpService:JSONEncode(beforePrefs)
            end, 12)
            record("ui.telephone.reglage_enregistre_serveur", saved, "préférences relues par AWTestQuery")
            -- Remis comme avant (deux autres clics : trois niveaux).
            for _ = 1, 2 do
                Gui.click(phoneButton("Niveau du HUD"), "Niveau du HUD")
                task.wait(0.6)
            end
        end
        for _, page in { "Commandes", "Accessibilité", "Audio", "Graphismes" } do
            if click("ui.telephone.page_" .. page, phoneButton(page), page) then
                task.wait(0.6)
                Gui.shot("parametres_" .. page, {})
            end
        end
        click("ui.telephone.retour_parametres", phoneButton("Retour"), "← Retour")
        task.wait(0.6)
    end
    for _, app in { "Social", "Véhicules", "Missions", "Guide", "Notifications" } do
        if click("ui.telephone.app_" .. app, phoneButton(app), app) then
            task.wait(0.8)
            Gui.shot("telephone_" .. app, {})
            click("ui.telephone.retour_" .. app, phoneButton("Retour"), "← Retour")
            task.wait(0.5)
        end
    end
    click("ui.telephone.fermer", phoneButton("×"), "×")
    local closed = waitFor(function()
        return not phoneOpen()
    end, 4)
    record("ui.telephone.fermeture_bouton", closed)
    local put = waitFor(function()
        return player.Character ~= nil and player.Character:FindFirstChild("TelephoneAW", true) == nil
    end, 4)
    record("ui.telephone.range_serveur", put)
end)

---------------------------------------------------------------------------
-- 7. Carte et GPS (touche M, bouton « Définir comme destination », touche X).
---------------------------------------------------------------------------
phase("carte", function()
    Gui.key("M")
    local map = screen("AWMap") :: ScreenGui?
    local opened = waitFor(function()
        return map ~= nil and map.Enabled
    end, 4)
    record("ui.carte.ouverture_touche_M", opened)
    if not opened then
        return
    end
    task.wait(1.5)
    Gui.shot("carte_ouverte", {})
    click("ui.carte.zoom_plus", Gui.findButton(map, "Zoom +"), "Zoom +")
    task.wait(0.6)
    Gui.shot("carte_zoom", {})
    local poi: GuiButton? = nil
    -- Lieu à plus de 80 m (sinon « Vous êtes arrivé » aussitôt) : distance lue dans le libellé.
    for _, item in (map :: Instance):GetDescendants() do
        if item:IsA("TextButton") and Gui.shown(item) and string.find(item.Text, " — ", 1, true) then
            local value, unit = string.match(item.Text, "— ([%d%.,]+) (k?m)")
            local meters = tonumber(value and (string.gsub(value, ",", ".")) or "0") or 0
            if unit == "km" then
                meters *= 1000
            end
            if meters > 80 then
                poi = item
                break
            end
        end
    end
    if click("ui.carte.choisir_lieu", poi, if poi then poi.Text else "lieu") then
        task.wait(0.6)
        click(
            "ui.carte.definir_destination",
            Gui.findButton(map, "Définir comme destination"),
            "Définir comme destination"
        )
        local guidance = waitFor(function()
            local hud = screen("AWHud")
            local panel = hud and hud:FindFirstChild("Guidage", true)
            return panel ~= nil and Gui.shown(panel)
        end, 5)
        record("ui.carte.guidage_affiche", guidance, notifications())
        Gui.shot("carte_destination", {})
    end
    click("ui.carte.fermer", Gui.findButton(map, "Fermer"), "Fermer")
    waitFor(function()
        return not (map :: ScreenGui).Enabled
    end, 4)
    record("ui.carte.fermee", not (map :: ScreenGui).Enabled)
    task.wait(0.5)
    Gui.shot("hud_guidage_a_pied", {})
    Gui.key("X")
    local cleared = waitFor(function()
        local hud = screen("AWHud")
        local panel = hud and hud:FindFirstChild("Guidage", true)
        return panel == nil or not Gui.shown(panel)
    end, 4)
    record("ui.carte.destination_effacee_touche_X", cleared)
end)

---------------------------------------------------------------------------
-- 8. Mode photo (touche O) et niveau du HUD (touche H).
---------------------------------------------------------------------------
phase("photo", function()
    local camera = Workspace.CurrentCamera :: Camera
    local cameraType = camera.CameraType
    local RacePanel = require(client:WaitForChild("UI"):WaitForChild("RacePanel")) :: any
    local photo: ScreenGui? = nil
    local function isOpen(): boolean
        -- ScreenGui recherché à chaque essai : il peut n'être créé qu'à l'ouverture.
        photo = screen("AWPhoto") :: ScreenGui?
        return photo ~= nil and (photo :: ScreenGui).Enabled
    end
    -- Diagnostic : touches reçues par le moteur, état « en course » vu par le mode photo.
    task.wait(1.5)
    local stopKeys = Gui.recordKeys()
    Gui.key("O")
    local opened = waitFor(isOpen, 4)
    local firstKeys = table.concat(stopKeys(), ",")
    local attempts = 1
    if not opened then
        -- Diagnostic : touche témoin (L), puis O par code virtuel au lieu du code de balayage.
        task.wait(1)
        local stopControl = Gui.recordKeys()
        Gui.key("L")
        task.wait(0.8)
        Gui.keyWith("vk", "O")
        attempts = 2
        opened = waitFor(isOpen, 4)
        firstKeys ..= " | témoin et O (code virtuel) : " .. table.concat(stopControl(), ",")
    end
    record(
        "ui.photo.ouverture_touche_O",
        opened,
        string.format(
            "essai(s) %d, touches reçues au 1er essai : %s, en course : %s, notifications : %s",
            attempts,
            firstKeys,
            tostring(RacePanel.racing()),
            notifications()
        )
    )
    if not opened then
        return
    end
    task.wait(0.8)
    Gui.shot("photo_ouvert", {})
    local function named(name: string): GuiButton?
        local found = (photo :: Instance):FindFirstChild(name, true)
        return if found and found:IsA("GuiButton") then found else nil
    end
    click("ui.photo.zoom", named("photo.zoomIn"), "photo.zoomIn")
    click("ui.photo.filtre", named("photo.filter"), "photo.filter")
    task.wait(0.6)
    Gui.shot("photo_filtre", {})
    click("ui.photo.quitter", named("photo.exit"), "Quitter")
    local closed = waitFor(function()
        return not (photo :: ScreenGui).Enabled or not anyShown(photo)
    end, 4)
    task.wait(0.5)
    record("ui.photo.fermeture_et_camera", closed and camera.CameraType == cameraType, tostring(camera.CameraType))
end)

phase("hud", function()
    local before = notifications()
    Gui.key("H")
    local changed = waitFor(function()
        return string.find(notifications(), "HUD", 1, true) ~= nil and notifications() ~= before
    end, 3)
    record("ui.hud.niveau_touche_H", changed, notifications())
    Gui.key("H")
    task.wait(0.4)
    Gui.key("H")
    task.wait(0.4)
end)

---------------------------------------------------------------------------
-- 9. Passage à la conduite : embarquement (touche E), accélérateur réel (W),
--    menus refusés en roulant, téléphone en mode rapide, aucune action parasite.
---------------------------------------------------------------------------
local function speed(): number
    local ok, snapshot = pcall(VehicleController.getTestSnapshot)
    return if ok and type(snapshot) == "table" then snapshot.SpeedKmh or 0 else 0
end
local function seated(): boolean
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.SeatPart ~= nil and humanoid.SeatPart.Name == "DriverSeat"
end

phase("conduite", function()
    local fleet = Workspace:FindFirstChild("VehiculesEssai")
    local model: Model? = nil
    if fleet then
        for _, item in fleet:GetChildren() do
            -- Boîte automatique (P-01) : une boîte manuelle resterait au point mort sans
            -- passage de rapport (capture 0088 de la tâche 20261103-203223).
            if
                item:IsA("Model")
                and item:GetAttribute("DriverUserId") == 0
                and item:GetAttribute("DefinitionId") == "proto_p01"
                and item:FindFirstChild("DriverSeat", true)
            then
                model = item
                break
            end
        end
    end
    if model == nil then
        record("ui.conduite.vehicule_libre", false)
        return
    end
    local door = model:FindFirstChild("DriverDoor", true) :: Attachment?
    local target = if door then door.WorldPosition else model:GetPivot().Position
    for attempt = 1, 3 do
        placeNear(target, 3, "portiere_" .. attempt)
        Gui.key("E", 800)
        if waitFor(seated, 4) then
            break
        end
    end
    record("ui.conduite.embarquement_touche_E", seated(), model.Name)
    if not seated() then
        return
    end
    task.wait(1.5)
    Gui.shot("conduite_hud_arret", { vehicle = model.Name })
    Gui.key("V")
    task.wait(1)
    Gui.shot("conduite_camera_V", { vehicle = model.Name })
    Gui.key("V")
    task.wait(0.5)
    -- Accélérateur réel : touche W maintenue.
    Gui.keyDown("W")
    local moving = waitFor(function()
        return speed() > 15
    end, 8)
    record("ui.conduite.accelerateur_touche_W", moving, string.format("%.1f km/h", speed()))
    if moving then
        Gui.key("P")
        task.wait(1.2)
        record(
            "ui.conduite.garage_refuse_en_roulant",
            not anyShown(screen("AWProgression")),
            "notification : " .. notifications()
        )
        Gui.shot("conduite_menu_refuse", { kmh = speed() })
        Gui.key("T")
        local quick = waitFor(phoneOpen, 3)
        record("ui.conduite.telephone_mode_rapide", quick, string.format("%.1f km/h", speed()))
        Gui.shot("telephone_en_conduite", { kmh = speed() })
        Gui.key("T")
        task.wait(0.6)
    end
    Gui.keyUp("W")
    -- Freinage réel (S) jusqu'à l'arrêt, puis relâché (sinon marche arrière, arbitrage A3).
    Gui.keyDown("S")
    waitFor(function()
        return speed() < 3
    end, 12)
    Gui.keyUp("S")
    Gui.key("Space", 1200)
    task.wait(1)
    record("ui.conduite.arret_touche_S", speed() < 3, string.format("%.1f km/h", speed()))
    -- Menu ouvert à l'arrêt : l'accélérateur ne doit rien faire. Frein à main tenu (sinon la
    -- boîte automatique rampe au ralenti et le panneau se ferme dès 1 m/s, comme prévu) ;
    -- l'effet de W est lu sur le régime moteur.
    local function rpm(): number
        local ok, snapshot = pcall(VehicleController.getTestSnapshot)
        return if ok and type(snapshot) == "table" then snapshot.EngineRpm or 0 else 0
    end
    Gui.keyDown("Space")
    task.wait(0.8)
    local idle = rpm()
    if openByKey("P", "AWProgression", "conduite_garage") then
        task.wait(0.5)
        Gui.keyDown("W")
        local peak = idle
        local t0 = os.clock()
        while os.clock() - t0 < 2 do
            peak = math.max(peak, rpm())
            task.wait(0.05)
        end
        Gui.keyUp("W")
        record(
            "ui.conduite.accelerateur_ignore_menu_ouvert",
            peak < idle + 600 and speed() < 3,
            string.format("régime %.0f → max %.0f tr/min, %.1f km/h", idle, peak, speed())
        )
        closeWith("AWProgression", "conduite_garage", "Fermer")
    end
    Gui.keyUp("Space")
    Gui.key("F", 400)
    local out = waitFor(function()
        return not seated()
    end, 5)
    record("ui.conduite.sortie_touche_F", out)
end)

for _, shot in Gui.report().shots do
    record(
        "ui.capture." .. shot.name,
        true,
        string.format(
            "commande %d, personnage (%d, %d, %d) st, contexte %s",
            shot.id,
            shot.x,
            shot.y,
            shot.z,
            tostring(shot.context)
        )
    )
end
record(
    "ui.info_entrees",
    true,
    HttpService:JSONEncode({ commands = Gui.report().commands, latency = Gui.report().clickLatencyMean })
)
measures.clicLatenceMoyenneS = Gui.report().clickLatencyMean
reportEvent:FireServer({ vehicle = "ui", steps = steps, measures = measures, gui = Gui.report() })
