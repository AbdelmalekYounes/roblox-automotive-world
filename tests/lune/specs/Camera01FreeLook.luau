--!strict
-- Lot CAMERA-01 : caméra libre en conduite. Contrôles hors Studio : logique pure du regard (limites,
-- sensibilité, inversion, zone morte, retour au centre, fondu d'une visée imposée), préférences du joueur,
-- textes FR/EN et présence de l'interface prévue pour la 2e vague. La lecture réelle de la souris, de la
-- manette et du doigt, et le rendu dans Studio relèvent de l'essai du propriétaire (rapport du lot).

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local FreeLook = H.require(SHARED .. "Vehicles.FreeLook")
    local Preferences = H.require(SHARED .. "UI.Preferences")
    local Localization = H.require(SHARED .. "UI.Localization")
    local game = H.game()

    local function source(path: string): string
        local node = game
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
            assert(node, path)
        end
        return node.Source
    end

    local DT = 1 / 60
    local MOUNTED = FreeLook.Limits.Mounted
    local ORBIT = FreeLook.Limits.Orbit

    -- Fait avancer le retour au centre pendant `seconds` (sans sollicitation).
    local function idle(state: any, seconds: number, speedKmh: number)
        for _ = 1, math.floor(seconds / DT + 0.5) do
            FreeLook.step(state, DT, false, speedKmh)
        end
    end

    T.suite("CAMERA-01 : caméra libre en conduite")

    T.test("limites réalistes des vues embarquées : ±120° en lacet, −40° à +30° en tangage", function()
        local state = FreeLook.newState()
        FreeLook.applyDelta(state, math.rad(500), math.rad(90), MOUNTED)
        T.near(state.Yaw, math.rad(120), 1e-9, "lacet borné à droite")
        T.near(state.Pitch, math.rad(30), 1e-9, "tangage borné en haut")
        FreeLook.applyDelta(state, math.rad(-1000), math.rad(-500), MOUNTED)
        T.near(state.Yaw, math.rad(-120), 1e-9, "lacet borné à gauche")
        T.near(state.Pitch, math.rad(-40), 1e-9, "tangage borné en bas")
    end)

    T.test("orbite des vues de poursuite : 360° en lacet (circulaire), tangage −60° à +10°", function()
        local state = FreeLook.newState()
        FreeLook.applyDelta(state, math.rad(170), 0, ORBIT)
        FreeLook.applyDelta(state, math.rad(20), 0, ORBIT)
        T.near(state.Yaw, math.rad(-170), 1e-9, "passage par l'arrière : 190° → −170°")
        FreeLook.applyDelta(state, math.rad(720), 0, ORBIT)
        T.near(state.Yaw, math.rad(-170), 1e-9, "deux tours complets : même direction")
        FreeLook.applyDelta(state, 0, math.rad(200), ORBIT)
        T.near(state.Pitch, math.rad(10), 1e-9, "caméra abaissée de 10° au plus")
        FreeLook.applyDelta(state, 0, math.rad(-400), ORBIT)
        T.near(state.Pitch, math.rad(-60), 1e-9, "caméra montée de 60° au plus")
        T.between(FreeLook.wrapAngle(math.pi), -math.pi, math.pi, "π reste dans l'intervalle")
        T.near(FreeLook.wrapAngle(-math.pi), math.pi, 1e-9, "−π ramené à π")
    end)

    T.test("passage d'une orbite à une vue embarquée : regard reborné", function()
        local state = FreeLook.newState()
        FreeLook.applyDelta(state, math.rad(170), math.rad(-55), ORBIT)
        FreeLook.clamp(state, MOUNTED)
        T.near(state.Yaw, math.rad(120), 1e-9)
        T.near(state.Pitch, math.rad(-40), 1e-9)
    end)

    T.test("valeurs non finies ignorées : la caméra ne se perd jamais", function()
        local state = FreeLook.newState()
        FreeLook.applyDelta(state, 0 / 0, 0, MOUNTED)
        FreeLook.applyDelta(state, math.huge, 0, ORBIT)
        T.equal(state.Yaw, 0)
        T.equal(state.Pitch, 0)
        local dYaw, dPitch = FreeLook.stickDelta(0 / 0, 1, DT, 3, false)
        T.equal(dYaw, 0)
        T.equal(dPitch, 0)
        FreeLook.step(state, DT, false, 0 / 0)
        T.equal(state.Yaw, 0)
    end)

    T.test("souris et doigt : sens, sensibilité et inversion verticale", function()
        local dYaw, dPitch = FreeLook.pointerDelta(100, -40, FreeLook.MouseRadPerPixel, 3, false)
        T.near(dYaw, math.rad(25), 1e-9, "100 px à droite = 25° à droite (sensibilité 3)")
        T.near(dPitch, math.rad(10), 1e-9, "souris vers le haut = regard vers le haut")
        local _, inverted = FreeLook.pointerDelta(100, -40, FreeLook.MouseRadPerPixel, 3, true)
        T.near(inverted, -math.rad(10), 1e-9, "inversion verticale")
        local slow = FreeLook.pointerDelta(100, 0, FreeLook.MouseRadPerPixel, 1, false)
        local fast = FreeLook.pointerDelta(100, 0, FreeLook.MouseRadPerPixel, 5, false)
        T.near(slow, math.rad(12.5), 1e-9, "sensibilité 1 = ×0,5")
        T.near(fast, math.rad(50), 1e-9, "sensibilité 5 = ×2")
        T.equal(FreeLook.sensitivity(nil), 1, "valeur absente : défaut")
        T.equal(FreeLook.sensitivity(99), 2, "valeur hors bornes : bornée")
        T.equal(FreeLook.sensitivity(0 / 0), 1, "valeur invalide : défaut")
        local touch = FreeLook.pointerDelta(100, 0, FreeLook.TouchRadPerPixel, 3, false)
        T.near(touch, math.rad(35), 1e-9, "doigt : 0,35° par pixel")
    end)

    T.test("stick droit : zone morte, courbe progressive, 150°/s à fond", function()
        local dYaw, dPitch = FreeLook.stickDelta(0.1, 0.1, DT, 3, false)
        T.equal(dYaw, 0, "dérive dans la zone morte ignorée")
        T.equal(dPitch, 0)
        T.truthy(not FreeLook.stickHeld(0.1, 0.1), "stick au repos : regard non tenu")
        dYaw, dPitch = FreeLook.stickDelta(1, 0, 1, 3, false)
        T.near(dYaw, math.rad(150), 1e-9, "à fond pendant 1 s")
        T.equal(dPitch, 0)
        local half = FreeLook.stickDelta(0.575, 0, 1, 3, false)
        T.near(half, math.rad(150) * 0.25, 1e-6, "mi-course utile : quart de la vitesse (courbe quadratique)")
        local _, up = FreeLook.stickDelta(0, 1, 1, 3, false)
        T.truthy(up > 0, "stick vers le haut = regard vers le haut")
        local _, upInverted = FreeLook.stickDelta(0, 1, 1, 3, true)
        T.truthy(upInverted < 0, "inversion verticale")
        T.truthy(FreeLook.stickHeld(0, 0.5), "stick sollicité : regard tenu")
    end)

    T.test("retour au centre à l'arrêt : 1,5 s d'attente puis ≈ 0,7 s", function()
        local state = FreeLook.newState()
        FreeLook.applyDelta(state, math.rad(90), math.rad(-20), MOUNTED)
        idle(state, 1.4, 0)
        T.near(state.Yaw, math.rad(90), 1e-9, "rien ne bouge avant 1,5 s")
        idle(state, 0.1 + 0.7, 0)
        T.between(state.Yaw, 0, math.rad(90) * 0.06, "≈ 95 % du chemin parcouru en 0,7 s")
        idle(state, 3, 0)
        T.truthy(FreeLook.isCentered(state), "regard exactement recentré")
    end)

    T.test("retour au centre accéléré dès 15 km/h : 0,4 s d'attente puis ≈ 0,4 s", function()
        local state = FreeLook.newState()
        FreeLook.applyDelta(state, math.rad(-100), 0, MOUNTED)
        idle(state, 0.35, 30)
        T.near(state.Yaw, math.rad(-100), 1e-9, "rien avant 0,4 s")
        idle(state, 0.05 + 0.4, 30)
        T.between(state.Yaw, math.rad(-100) * 0.06, 0, "≈ 95 % en 0,4 s")
        local slow = FreeLook.newState()
        FreeLook.applyDelta(slow, math.rad(-100), 0, MOUNTED)
        idle(slow, 0.8, 10)
        T.near(slow.Yaw, math.rad(-100), 1e-9, "sous 15 km/h : délai de 1,5 s conservé")
    end)

    T.test("regard tenu (clic droit, doigt, stick) : aucun retour au centre, même en roulant", function()
        local state = FreeLook.newState()
        FreeLook.applyDelta(state, math.rad(60), 0, MOUNTED)
        for _ = 1, 300 do
            FreeLook.step(state, DT, true, 90)
        end
        T.near(state.Yaw, math.rad(60), 1e-9)
        T.equal(state.IdleS, 0)
        T.truthy(state.Holding)
        -- Relâché : le délai repart de zéro.
        idle(state, 0.3, 90)
        T.near(state.Yaw, math.rad(60), 1e-9, "délai repartant au relâchement")
    end)

    T.test("orbite derrière le véhicule : retour par le chemin le plus court", function()
        local state = FreeLook.newState()
        FreeLook.applyDelta(state, math.rad(-175), 0, ORBIT)
        local previous = state.Yaw
        for _ = 1, 260 do
            FreeLook.step(state, DT, false, 0)
            T.truthy(state.Yaw <= 0 and state.Yaw >= previous - 1e-12, "lacet monotone vers 0 sans traverser ±180°")
            previous = state.Yaw
        end
        T.truthy(FreeLook.isCentered(state))
    end)

    T.test("retour au centre indépendant de la cadence d'image", function()
        local a, b = FreeLook.newState(), FreeLook.newState()
        FreeLook.applyDelta(a, math.rad(80), 0, MOUNTED)
        FreeLook.applyDelta(b, math.rad(80), 0, MOUNTED)
        for _ = 1, 120 do
            FreeLook.step(a, 1 / 120, false, 0)
        end
        for _ = 1, 30 do
            FreeLook.step(b, 1 / 30, false, 0)
        end
        for _ = 1, 72 do
            FreeLook.step(a, 1 / 120, false, 0)
        end
        for _ = 1, 18 do
            FreeLook.step(b, 1 / 30, false, 0)
        end
        T.near(a.Yaw, b.Yaw, math.rad(0.5), "120 i/s et 30 i/s : même regard après 1,6 s")
    end)

    T.test("fondu d'une visée imposée (2e vague) : aller, retour, adoucissement", function()
        local alpha = 0
        for _ = 1, 10 do
            alpha = FreeLook.stepBlend(alpha, true, 0.035, nil)
        end
        T.near(alpha, 1, 1e-9, "0,35 s par défaut")
        alpha = FreeLook.stepBlend(alpha, false, 0.1, 0.2)
        T.near(alpha, 0.5, 1e-9, "retour sur la durée demandée")
        T.equal(FreeLook.stepBlend(0, false, 1, nil), 0, "borné à 0")
        T.equal(FreeLook.ease(0), 0)
        T.equal(FreeLook.ease(1), 1)
        T.near(FreeLook.ease(0.5), 0.5, 1e-9)
    end)

    T.test("préférences : sensibilité 1 à 5 (défaut 3) et inversion verticale nettoyées", function()
        local defaults = Preferences.defaults()
        T.equal(defaults.Camera.Sensitivity, 3)
        T.equal(defaults.Camera.InvertY, false)
        local dirty = Preferences.sanitize({ Camera = { Sensitivity = 42, InvertY = "oui", Inconnu = 1 } })
        T.equal(dirty.Camera.Sensitivity, 5, "bornée")
        T.equal(dirty.Camera.InvertY, false, "booléen attendu")
        T.equal(dirty.Camera.Inconnu, nil, "champ inconnu ignoré")
        local old = Preferences.sanitize({ Version = 2, Language = "en" })
        T.equal(old.Camera.Sensitivity, 3, "profil existant sans réglage caméra : défauts")
        T.truthy(Preferences.equal(Preferences.sanitize(defaults), defaults), "défauts stables")
    end)

    T.test("textes FR et EN des réglages de la caméra", function()
        for _, key in { "settings.cameraSensitivity", "settings.cameraInvertY", "settings.cameraSection" } do
            local entry = Localization.Entries[key]
            T.truthy(entry ~= nil, "clé présente : " .. key)
            T.truthy(type(entry[1]) == "string" and type(entry[2]) == "string", "FR et EN : " .. key)
            local fr = Localization.placeholders(entry[1])
            local en = Localization.placeholders(entry[2])
            T.equal(table.concat(fr, ","), table.concat(en, ","), "paramètres alignés : " .. key)
        end
    end)

    T.test(
        "interface de la caméra : vue « Cockpit » conservée, points d'accès de la 2e vague présents",
        function()
            local camera = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.VehicleCamera")
            T.truthy(string.find(camera, 'Name = "Cockpit"', 1, true) ~= nil, "nom lu par l'audio (habitacle)")
            for _, name in
                {
                    "function VehicleCamera.setLookOverride",
                    "function VehicleCamera.hasLookOverride",
                    "function VehicleCamera.setCharacterVisibilityFilter",
                    "function VehicleCamera.isCockpit",
                    "function VehicleCamera.lookAngles",
                }
            do
                T.truthy(string.find(camera, name, 1, true) ~= nil, name)
            end
            local input = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.FreeLookInput")
            T.truthy(string.find(input, "MouseButton2", 1, true) ~= nil, "clic droit maintenu")
            T.truthy(string.find(input, "Thumbstick2", 1, true) ~= nil, "stick droit")
            T.truthy(string.find(input, "UserInputType.Touch", 1, true) ~= nil, "doigt")
            T.truthy(string.find(input, "SavedBehavior", 1, true) ~= nil, "comportement de la souris restauré")
        end
    )
end
