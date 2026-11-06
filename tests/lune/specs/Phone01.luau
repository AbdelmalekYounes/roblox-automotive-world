--!strict
-- Lot PHONE-01 : téléphone tenu en main. Contrôles hors Studio : géométrie de la prise en main sur un gabarit
-- R15 approché, cadrage de la caméra (rectangle exact de l'écran dans la vue), choix de l'affichage, préférence,
-- textes FR/EN et branchements dans les sources. Le rendu, le zoom réel, les entrées (souris, manette, tactile)
-- et la vue des autres joueurs relèvent de l'essai du propriétaire (docs/lot-phone-01/RAPPORT_PHONE_01.md).

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local PhoneHold = H.require(SHARED .. "UI.PhoneHold")
    local Preferences = H.require(SHARED .. "UI.Preferences")
    local Localization = H.require(SHARED .. "UI.Localization")
    local roblox = require("@lune/roblox")
    local CFrame = roblox.CFrame
    local Vector2 = roblox.Vector2
    local Vector3 = roblox.Vector3

    local function source(path: string): string
        local node = H.game()
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
            assert(node, path)
        end
        return node.Source
    end

    local CLIENT = "StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient."
    local METERS_PER_STUD = 0.28

    --[[
        Gabarit R15 « bloc » par défaut, cotes APPROCHÉES (studs) : articulations C0 (pièce parente) et C1
        (pièce enfant) ; yeux 0,1 st au-dessus et 0,45 st devant le centre de la tête. Sert à vérifier
        que la pose et la prise en main tournent l'écran vers le visage ; les avatars réels varient.
    ]]
    local function rig(alpha: number): (CFrame, CFrame, Vector3)
        local torso = CFrame.new(0, 3, 0)
        local upper = torso
            * CFrame.new(1, 0.563, 0)
            * PhoneHold.jointOffset("RightShoulder", alpha)
            * CFrame.new(-0.5, 0.42, 0):Inverse()
        local lower = upper
            * CFrame.new(0, -0.334, 0)
            * PhoneHold.jointOffset("RightElbow", alpha)
            * CFrame.new(0, 0.261, 0):Inverse()
        local hand = lower * CFrame.new(0, -0.501, 0) * CFrame.new(0, 0.125, 0):Inverse()
        local head = torso * CFrame.new(0, 0.8, 0) * CFrame.new(0, -0.6, 0):Inverse()
        local eye = (head * CFrame.new(0, 0.1, -0.45)).Position
        return torso, hand * PhoneHold.gripCFrame(), eye
    end

    T.suite("PHONE-01 : téléphone tenu en main")

    T.test(
        "modèle original aux cotes d'un smartphone (≈ 7,5 × 15 × 0,8 cm), dalle au rapport de l'interface",
        function()
            local b, sc = PhoneHold.Body, PhoneHold.Screen
            T.between(b.Width * METERS_PER_STUD * 100, 7, 8, "largeur (cm)")
            T.between(b.Height * METERS_PER_STUD * 100, 14.5, 16, "hauteur (cm)")
            T.between(b.Thickness * METERS_PER_STUD * 100, 0.6, 1, "épaisseur (cm)")
            T.truthy(sc.Width < b.Width - 0.02 and sc.Height < b.Height - 0.02, "dalle entourée d'un bord")
            T.near(sc.Width / sc.Height, PhoneHold.ScreenPixels.X / PhoneHold.ScreenPixels.Y, 1e-9, "même rapport")
            T.truthy(b.Corner * 2 < b.Width, "coins arrondis possibles")
        end
    )

    T.test("pose et prise en main : écran tourné vers les yeux, devant la poitrine, à ≈ 30 cm", function()
        local torso, phone, eye = rig(1)
        local toEye = eye - phone.Position
        local angle = math.deg(math.acos(phone.LookVector:Dot(toEye.Unit)))
        T.between(angle, 0, 10, "écran face aux yeux (degrés)")
        T.between(toEye.Magnitude * METERS_PER_STUD * 100, 25, 40, "distance des yeux (cm)")
        local local_ = torso:PointToObjectSpace(phone.Position)
        T.truthy(local_.Z < -0.8, "devant le buste")
        T.between(local_.X, -0.1, 0.8, "côté droit, près de l'axe du corps")
        T.truthy(phone.Position.Y < eye.Y, "sous les yeux (regard vers le bas)")
        T.truthy(phone.UpVector.Y > 0.5, "haut de l'écran vers le haut")
    end)

    T.test("décalages du bras : nuls au repos, bornés, articulation inconnue ignorée", function()
        T.truthy(PhoneHold.jointOffset("RightShoulder", 0) == CFrame.identity, "repos")
        T.truthy(PhoneHold.jointOffset("RightShoulder", 0 / 0) == CFrame.identity, "valeur non finie")
        T.truthy(PhoneHold.jointOffset("LeftShoulder", 1) == CFrame.identity, "bras gauche non touché")
        local full = PhoneHold.jointOffset("RightElbow", 1)
        local beyond = PhoneHold.jointOffset("RightElbow", 3)
        T.truthy(full == beyond, "progression bornée à 1")
        local x = full:ToEulerAnglesYXZ()
        T.near(math.deg(x), PhoneHold.Arm.RightElbow.Pitch, 1e-4, "coude plié")
        T.truthy(PhoneHold.ArmParts.RightShoulder == "RightUpperArm", "épaule du R15")
        T.truthy(PhoneHold.ArmParts.RightElbow == "RightLowerArm", "coude du R15")
    end)

    T.test("cadrage : caméra sur la normale de l'écran, écran exactement à la hauteur voulue de la vue", function()
        local f = PhoneHold.Framing
        local _, phone = rig(1)
        local screen = phone * CFrame.new(0, 0, -(PhoneHold.Body.Thickness / 2 + 0.003))
        for _, fill in { f.Fill, f.FillCloser } do
            local d = PhoneHold.viewDistance(PhoneHold.Screen.Height, f.Fov, fill)
            local view = PhoneHold.viewCFrame(screen, d)
            T.near((view.Position - screen.Position).Magnitude, d, 1e-4, "distance")
            T.near(view.LookVector:Dot(-screen.LookVector), 1, 1e-6, "regard vers la dalle")
            T.near(view.UpVector:Dot(screen.UpVector), 1, 1e-6, "verticale de l'écran conservée")
            -- Coin supérieur droit de la dalle dans le repère de la caméra : projection perspective.
            local corner = view:PointToObjectSpace(
                screen:PointToWorldSpace(Vector3.new(PhoneHold.Screen.Width / 2, PhoneHold.Screen.Height / 2, 0))
            )
            local projectedY = (corner.Y / -corner.Z) / math.tan(math.rad(f.Fov) / 2)
            T.near(math.abs(projectedY), fill, 1e-4, "demi-hauteur projetée = part de la vue")
            local center, size = PhoneHold.overlayRect(Vector2.new(1920, 1080), fill)
            T.near(center.X, 960, 1e-9)
            T.near(center.Y, 540, 1e-9)
            T.near(size.Y, 1080 * fill, 1e-3, "hauteur de l'interface (Vector2 en simple précision)")
            T.near(size.X / size.Y, 360 / 760, 1e-5, "rapport de la dalle")
        end
        T.truthy(f.FillCloser > f.Fill and f.FillCloser <= 1, "« + » rapproche sans déborder")
        T.truthy(f.ReducedBlendS < f.BlendS, "fondu réduit avec « Réduire les animations »")
        T.truthy(PhoneHold.viewDistance(0.5, 40, 0) > 0, "part nulle bornée")
    end)

    T.test("affichage : Auto = en main sauf disposition compacte ; choix explicite respecté", function()
        T.equal(PhoneHold.display("Auto", false), "InHand")
        T.equal(PhoneHold.display("Auto", true), "Classic")
        T.equal(PhoneHold.display("InHand", true), "InHand")
        T.equal(PhoneHold.display("Classic", false), "Classic")
        T.equal(PhoneHold.display(nil, false), "InHand", "valeur absente : Auto")
        T.truthy(PhoneHold.freezesWalking(true, false), "à pied en main : arrêt")
        T.truthy(not PhoneHold.freezesWalking(true, true), "assis : jamais bloqué")
        T.truthy(not PhoneHold.freezesWalking(false, false), "classique : marche libre")
    end)

    T.test("préférence « Affichage du téléphone » : défaut Auto, valeurs nettoyées", function()
        T.equal(Preferences.defaults().Phone.Display, "Auto")
        T.equal(Preferences.sanitize({ Phone = { Display = "Classic" } }).Phone.Display, "Classic")
        T.equal(Preferences.sanitize({ Phone = { Display = "Hologramme" } }).Phone.Display, "Auto")
        T.equal(Preferences.sanitize({ Phone = "x" }).Phone.Display, "Auto")
        T.equal(Preferences.sanitize(nil).Phone.Display, "Auto", "profil ancien")
        T.equal(#Preferences.PhoneDisplays, 3)
        for _, value in Preferences.PhoneDisplays do
            local key = "settings.phoneDisplay." .. value
            T.truthy(Localization.t(key, nil, "fr") ~= key and Localization.t(key, nil, "en") ~= key, key)
        end
        for _, key in { "settings.phoneDisplay", "settings.phoneDisplay.note", "settings.phoneDisplay.InHand" } do
            T.truthy(Localization.t(key, nil, "fr") ~= Localization.t(key, nil, "en"), key .. " : FR et EN")
        end
    end)

    T.test(
        "serveur : modèle en pièces simples, soudé par la prise en main, sans réglage C0 ni actif importé",
        function()
            local server = source("ServerScriptService.AutomotiveWorldServer.Social.InterfaceService")
            T.truthy(string.find(server, "PhoneHold.gripCFrame()", 1, true) ~= nil, "prise en main partagée")
            T.truthy(string.find(server, 'Instance.new("Weld")', 1, true) ~= nil, "soudure à décalage")
            T.truthy(string.find(server, "TweenService", 1, true) == nil, "plus de réglage C0 de l'épaule")
            T.truthy(string.find(server, "rbxassetid", 1, true) == nil, "aucun actif importé")
            T.truthy(string.find(server, "MeshId", 1, true) == nil, "aucun maillage externe")
            T.truthy(string.find(server, '"EcranGenerique"', 1, true) ~= nil, "écran générique vu des autres")
        end
    )

    T.test("client : zoom par la visée imposée au volant, caméra rendue, interface calée sur l'écran", function()
        local hold = source(CLIENT .. "UI.PhoneHoldController")
        for _, needle in
            {
                "setLookOverride(",
                "setLookOverride(nil)",
                "VehicleController.isDriving()",
                "Enum.CameraType.Scriptable",
                "BindToRenderStep",
                "ReduceMotion",
                "LocalTransparencyModifier",
                "controls:Disable()",
            }
        do
            T.truthy(string.find(hold, needle, 1, true) ~= nil, needle)
        end
        T.truthy(string.find(hold, 'SeatPose")', 1, true) == nil, "pose assise (ANIM-01) ni requise ni modifiée")
        local phone = source(CLIENT .. "UI.PhoneController")
        for _, needle in
            {
                "PhoneHoldController.overlay()",
                "PhoneHoldController.returnS()",
                '"settings.phoneDisplay"',
                "Preferences.PhoneDisplays",
            }
        do
            T.truthy(string.find(phone, needle, 1, true) ~= nil, needle)
        end
        local vehicle = source(CLIENT .. "Vehicles.VehicleController")
        T.truthy(string.find(vehicle, "function VehicleController.isDriving()", 1, true) ~= nil, "accès conduite")
    end)
end
