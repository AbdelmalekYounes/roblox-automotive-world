--!strict
-- Tests de l'arbitrage clavier / manette / saisie de texte (module pur).
-- Ces tests vérifient la LOGIQUE ; la lecture réelle des touches et de la
-- manette par Roblox reste un essai humain (voir RAPPORT_TESTS.md).

return function(T: any, H: any)
    local Arbiter = H.require("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.InputArbiter")

    local DT = 1 / 60
    local FOCUSED = { Typing = false, WindowFocused = true }

    local function keys(overrides: { [string]: boolean }?): any
        local sample = { Throttle = false, Brake = false, Left = false, Right = false, Handbrake = false }
        for key, value in overrides or {} do
            sample[key] = value
        end
        return sample
    end

    local function pad(overrides: { [string]: any }?): any
        local sample = { Connected = true, Throttle = 0, Brake = 0, Steer = 0, Handbrake = false }
        for key, value in overrides or {} do
            sample[key] = value
        end
        return sample
    end

    -- Fait tourner l'arbitre n images avec les mêmes entrées ; renvoie la dernière sortie.
    local function run(state: any, k: any, p: any, context: any, frames: number): (any, any)
        local command, lastEvent = nil, nil
        for _ = 1, frames do
            local event
            command, event = Arbiter.step(state, k, p, context, DT)
            lastEvent = event or lastEvent
        end
        return command, lastEvent
    end

    T.suite("Arbitrage des périphériques")

    T.test("touche maintenue dès l'embarquement : ignorée tant qu'elle n'est pas relâchée", function()
        local state = Arbiter.newState()
        local command = run(state, keys({ Throttle = true }), pad(), FOCUSED, 30)
        T.equal(command.Throttle, 0, "pas d'accélération involontaire")
        run(state, keys(), pad(), FOCUSED, 2)
        command = run(state, keys({ Throttle = true }), pad(), FOCUSED, 30)
        T.near(command.Throttle, 1, 1e-6, "nouvel appui pris en compte")
        T.equal(state.Active, "Keyboard")
    end)

    T.test("rampe clavier conservée (A2) : 0 → 100 % en 0,2 s", function()
        local state = Arbiter.newState()
        run(state, keys(), pad(), FOCUSED, 1)
        local command = run(state, keys({ Throttle = true }), pad(), FOCUSED, 6)
        T.near(command.Throttle, 0.5, 0.01, "50 % après 0,1 s")
        command = run(state, keys({ Throttle = true }), pad(), FOCUSED, 6)
        T.near(command.Throttle, 1, 1e-6, "100 % après 0,2 s")
    end)

    T.test("stick qui dérive hors zone morte : n'interfère pas avec le clavier", function()
        local state = Arbiter.newState()
        local drifting = pad({ Steer = 0.4 })
        run(state, keys(), drifting, FOCUSED, 2)
        local command = run(state, keys({ Throttle = true }), drifting, FOCUSED, 20)
        T.equal(state.Active, "Keyboard")
        T.near(command.Steer, 0, 1e-9, "aucun braquage venant du stick")
    end)

    T.test("passage clavier → manette sur commande fraîche, puis retour au clavier", function()
        local state = Arbiter.newState()
        run(state, keys(), pad(), FOCUSED, 2)
        run(state, keys({ Throttle = true }), pad(), FOCUSED, 20)
        -- La manette, au repos, est sollicitée : elle prend la main.
        local command = run(state, keys(), pad({ Throttle = 0.6 }), FOCUSED, 2)
        T.equal(state.Active, "Gamepad")
        T.near(command.Throttle, 0.6, 1e-9, "gâchette analogique proportionnelle")
        -- Gâchette encore maintenue, appui clavier frais : le clavier reprend la main.
        command = run(state, keys({ Brake = true }), pad({ Throttle = 0.6 }), FOCUSED, 20)
        T.equal(state.Active, "Keyboard")
        T.near(command.Throttle, 0, 1e-9, "la gâchette maintenue n'accélère plus")
        T.truthy(command.Brake > 0.99, "le frein clavier s'applique")
    end)

    T.test("pas de cumul : un seul périphérique pilote à la fois", function()
        local state = Arbiter.newState()
        run(state, keys(), pad(), FOCUSED, 2)
        run(state, keys(), pad({ Steer = -1 }), FOCUSED, 2)
        -- Le clavier a été vu au repos : son appui est frais et il prend la main.
        local command = run(state, keys({ Right = true }), pad({ Steer = -1 }), FOCUSED, 20)
        T.equal(state.Active, "Keyboard")
        T.truthy(command.Steer > 0.99, "braquage du seul clavier, sans mélange avec le stick")
    end)

    T.test("saisie de texte : clavier ignoré, commandes clavier retombent à zéro", function()
        local state = Arbiter.newState()
        run(state, keys(), pad(), FOCUSED, 2)
        run(state, keys({ Throttle = true, Left = true }), pad(), FOCUSED, 30)
        local typing = { Typing = true, WindowFocused = true }
        local command = run(state, keys({ Throttle = true, Left = true, Handbrake = true }), pad(), typing, 30)
        T.near(command.Throttle, 0, 1e-9, "pas d'accélération en tapant « z »")
        T.near(command.Steer, 0, 1e-9, "pas de braquage en tapant « q »")
        T.equal(command.Handbrake, false, "pas de frein à main en tapant une espace")
    end)

    T.test("fin de saisie : une touche restée enfoncée doit être relâchée puis renouvelée", function()
        local state = Arbiter.newState()
        run(state, keys(), pad(), FOCUSED, 2)
        run(state, keys({ Throttle = true }), pad(), { Typing = true, WindowFocused = true }, 10)
        -- Le joueur quitte le chat en gardant « z » enfoncée : la frappe n'était pas une commande.
        local command = run(state, keys({ Throttle = true }), pad(), FOCUSED, 30)
        T.near(command.Throttle, 0, 1e-9, "aucune accélération à la sortie du chat")
        run(state, keys(), pad(), FOCUSED, 1)
        command = run(state, keys({ Throttle = true }), pad(), FOCUSED, 30)
        T.near(command.Throttle, 1, 1e-6, "nouvel appui pris en compte")
    end)

    T.test("perte de focus de la fenêtre : clavier et manette relâchés", function()
        local state = Arbiter.newState()
        run(state, keys(), pad(), FOCUSED, 2)
        run(state, keys({ Throttle = true }), pad(), FOCUSED, 30)
        local command =
            run(state, keys({ Throttle = true }), pad({ Throttle = 1 }), { Typing = false, WindowFocused = false }, 30)
        T.near(command.Throttle, 0, 1e-9)
        T.equal(state.Active, nil)
    end)

    T.test("retour du focus avec une touche « bloquée » enfoncée : aucune commande", function()
        local state = Arbiter.newState()
        run(state, keys(), pad(), FOCUSED, 2)
        run(state, keys({ Throttle = true }), pad(), FOCUSED, 10)
        run(state, keys({ Throttle = true }), pad(), { Typing = false, WindowFocused = false }, 10)
        -- Le relâchement a été perdu hors focus : la touche paraît encore enfoncée.
        local command = run(state, keys({ Throttle = true }), pad(), FOCUSED, 30)
        T.near(command.Throttle, 0, 1e-9, "pas d'accélération fantôme")
    end)

    T.test(
        "manette déconnectée en pleine accélération : relâchée, événement signalé, aucune reprise automatique",
        function()
            local state = Arbiter.newState()
            run(state, keys(), pad(), FOCUSED, 2)
            run(state, keys(), pad({ Throttle = 1, Steer = 0.8 }), FOCUSED, 5)
            T.equal(state.Active, "Gamepad")
            local command, event = run(state, keys(), Arbiter.DisconnectedGamepad, FOCUSED, 1)
            T.equal(event, "GamepadDisconnected")
            T.equal(state.Active, nil)
            T.near(command.Throttle, 0, 1e-9)
            T.near(command.Steer, 0, 1e-9)
            -- Reconnexion avec la gâchette encore enfoncée : ignorée jusqu'au relâchement.
            command = run(state, keys(), pad({ Throttle = 1 }), FOCUSED, 10)
            T.near(command.Throttle, 0, 1e-9, "pas de redémarrage involontaire à la reconnexion")
            run(state, keys(), pad(), FOCUSED, 1)
            command = run(state, keys(), pad({ Throttle = 1 }), FOCUSED, 1)
            T.near(command.Throttle, 1, 1e-9, "nouvel appui accepté")
        end
    )

    T.test("zones mortes manette : gâchette effleurée et stick au centre ignorés", function()
        local shaped = Arbiter.shapeGamepad(pad({ Throttle = 0.03, Brake = 0.02, Steer = 0.1 }))
        T.equal(shaped.Throttle, 0)
        T.equal(shaped.Brake, 0)
        T.equal(shaped.Steer, 0)
        local full = Arbiter.shapeGamepad(pad({ Steer = -1 }))
        T.near(full.Steer, -1, 1e-9, "plein braquage conservé après remise à l'échelle")
    end)
end
