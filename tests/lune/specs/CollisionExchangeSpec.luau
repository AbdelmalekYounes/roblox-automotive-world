--!strict
-- Tests de l'échange d'impulsion entre véhicules de deux joueurs (module pur).
-- Les trajectoires sont synthétiques, à 60 Hz, comme les positions répliquées
-- observées par le serveur.

return function(T: any, H: any)
    local Exchange = H.require("ReplicatedStorage.Shared.Vehicles.Physics.CollisionExchange")

    local MASS = 1250
    local HZ = 60

    -- Trajectoire sur l'axe X : vitesse `before` jusqu'à `contactAt`, puis `after`.
    local function track(startX: number, before: number, after: number, contactAt: number, duration: number)
        local samples = {}
        local x = startX
        for i = 0, math.floor(duration * HZ) do
            local t = i / HZ
            table.insert(samples, { Time = t, X = x, Z = 0 })
            x += (if t < contactAt then before else after) / HZ
        end
        return samples
    end

    local NOW = 1.0
    local CONTACT = 0.7

    T.suite("Échange d'impulsion entre véhicules de deux joueurs")

    T.test(
        "choc latéral, percuteur arrêté net chez lui : le percuté reçoit le Δv d'un choc de carrosseries",
        function()
            local striker = track(0, 5.4, 0, CONTACT, NOW)
            local struck = track(10, 0, 0, CONTACT, NOW)
            local result = Exchange.assess(striker, MASS, struck, MASS, 1, 0, NOW)
            T.truthy(result ~= nil, "contact confirmé")
            T.near(result.LossMs, 5.4, 0.05)
            T.near(result.ClosingMs, 5.4, 0.05)
            -- Borne du choc de carrosseries : (1 + 0,3)·½·5,4 = 3,51 m/s (masses égales),
            -- inférieure à la conservation pure (5,4 m/s, équivalente à un choc élastique).
            T.near(result.TargetDeltaVMs, 3.51, 0.05)
        end
    )

    T.test("percuteur partiellement ralenti : Δv proportionnel à la perte réelle", function()
        local striker = track(0, 5.4, 2.7, CONTACT, NOW) -- perte 2,7 m/s < borne 3,51
        local struck = track(10, 0, 0, CONTACT, NOW)
        local result = Exchange.assess(striker, MASS, struck, MASS, 1, 0, NOW)
        T.near(result.TargetDeltaVMs, 2.7, 0.05)
    end)

    T.test("masses différentes : conservation de la quantité de mouvement", function()
        local striker = track(0, 4, 3, CONTACT, NOW) -- perte 1 m/s, sous la borne
        local struck = track(10, 0, 0, CONTACT, NOW)
        local result = Exchange.assess(striker, 2000, struck, 1000, 1, 0, NOW)
        T.near(2000 * result.LossMs, 1000 * result.TargetDeltaVMs, 2)
    end)

    T.test("borne physique : jamais plus que le choc de carrosseries à la vitesse de rapprochement", function()
        -- Percuteur léger qui « perd » beaucoup (ou triche) contre un percuté lourd.
        local striker = track(0, 5, 0, CONTACT, NOW)
        local struck = track(10, 0, 0, CONTACT, NOW)
        local result = Exchange.assess(striker, 3000, struck, 1000, 1, 0, NOW)
        local bound = (1 + Exchange.DefaultParams.Restitution) * 3000 / 4000 * result.ClosingMs
        T.truthy(result.TargetDeltaVMs <= bound + 1e-9, "borne (1 + e)·mS/(mS + mT)·v respectée")
        T.near(result.TargetDeltaVMs, bound, 0.05, "la borne s'applique ici")
    end)

    T.test("aucune décélération du percuteur → aucun contact confirmé (pas d'impulsion)", function()
        local striker = track(0, 5.4, 5.4, CONTACT, NOW)
        local struck = track(10, 0, 0, CONTACT, NOW)
        T.equal(Exchange.assess(striker, MASS, struck, MASS, 1, 0, NOW), nil)
    end)

    T.test("véhicules qui s'éloignent → aucun contact confirmé", function()
        local striker = track(0, -3, -6, CONTACT, NOW)
        local struck = track(10, 2, 2, CONTACT, NOW)
        T.equal(Exchange.assess(striker, MASS, struck, MASS, 1, 0, NOW), nil)
    end)

    T.test("freinage du percuteur sans rapprochement (percuté plus rapide devant) → aucun contact", function()
        local striker = track(0, 5, 2, CONTACT, NOW)
        local struck = track(10, 6, 6, CONTACT, NOW)
        T.equal(Exchange.assess(striker, MASS, struck, MASS, 1, 0, NOW), nil)
    end)

    T.test("le véhicule poussé n'est jamais pris pour un percuteur (pas d'impulsion en retour)", function()
        -- Couple inversé : « percuteur » = véhicule percuté, normale vers le vrai percuteur.
        local pushed = track(10, 0, 3, CONTACT, NOW) -- poussé vers +X, donc s'éloigne selon -X
        local realStriker = track(0, 5.4, 0, CONTACT, NOW)
        T.equal(Exchange.assess(pushed, MASS, realStriker, MASS, -1, 0, NOW), nil)
    end)

    T.test("éjection numérique d'un véhicule garé : vitesse plausible bornée", function()
        -- Choc à 5,4 m/s : jamais plus de 2 × 5,4 + 1 m/s pour le véhicule percuté.
        T.near(Exchange.maxPlausibleSpeed(0, 5.4, 1 / 60), 13.8, 1e-9) -- 2 × 5,4 + 3 m/s (éjection mesurée : 59 m/s)
        -- Hors choc : accélération bornée d'un pas au suivant (chute libre comprise).
        T.near(Exchange.maxPlausibleSpeed(30, 0, 1 / 60), 30 + 50 / 60, 1e-9)
        T.truthy(Exchange.maxPlausibleSpeed(0, 0, 1 / 60) >= 9.81 / 60, "la gravité reste possible")
    end)

    T.test("complément : seule la part non reçue est appliquée, jamais retirée", function()
        T.near(Exchange.complement(5, 0), 5, 1e-9)
        T.near(Exchange.complement(5, 1.5), 3.5, 1e-9)
        T.near(Exchange.complement(5, 7), 0, 1e-9, "choc frontal : déjà rebondi, rien n'est retiré")
        T.near(Exchange.complement(-1, 0), 0, 1e-9)
    end)

    T.test("déjà reçu : poussée faible déjà freinée par les pneus comptée quand même", function()
        -- 0 → 1,2 m/s (poussée de la copie du percuteur) puis retour à 0,2 par frottement.
        local history = { 0, 0, 0.4, 1.2, 0.9, 0.5, 0.2 }
        T.near(Exchange.alreadyReceived(history, 0.2), 1.2, 1e-9)
        T.near(Exchange.alreadyReceived({}, 0), 0, 1e-9)
        -- Véhicule qui ralentit seul (freinage) : rien n'est compté comme reçu.
        T.near(Exchange.alreadyReceived({ 3, 2.5, 2, 1.5 }, 1), 0, 1e-9)
    end)

    T.test("système complet : le percuté atteint exactement le Δv cible, sans double comptage", function()
        local striker = track(0, 5.4, 0, CONTACT, NOW)
        local struck = track(10, 0, 0, CONTACT, NOW)
        local result = Exchange.assess(striker, MASS, struck, MASS, 1, 0, NOW)
        -- La copie répliquée a déjà donné 0,8 m/s au percuté dans sa simulation.
        local applied = Exchange.complement(result.TargetDeltaVMs, Exchange.alreadyReceived({ 0, 0.8, 0.5 }, 0.4))
        T.near(0.8 + applied, result.TargetDeltaVMs, 1e-9, "reçu dans sa simulation + complément = cible")
        -- La quantité de mouvement transmise ne dépasse jamais celle perdue par le percuteur.
        T.truthy(MASS * (0.8 + applied) <= MASS * result.LossMs + 1e-6)
    end)
end
