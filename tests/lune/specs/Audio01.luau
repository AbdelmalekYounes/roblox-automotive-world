--!strict
-- Lot AUDIO-01 : sons de moteur réalistes. Contrôles hors Studio : régimes de la Comète (décision D3), régime
-- transmis pour le son des autres joueurs (codec et serveur), modèle sonore v2 (profils enregistrés, événements,
-- habitacle, Doppler), validation des profils. L'écoute et le rendu en jeu relèvent du propriétaire.

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")
    local InputCodec = H.require(SHARED .. "Vehicles.InputCodec")
    local Model = H.require(SHARED .. "Audio.EngineAudioModel")
    local Profiles = H.require(SHARED .. "Audio.EngineSoundProfiles")
    local game = H.game()

    local function source(path: string): string
        local node = game
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
            assert(node, path)
        end
        return node.Source
    end

    -- Profil d'essai (aucun profil réel tant que les enregistrements ne sont pas traités).
    local PROFILE = {
        Prefix = "audio.engine.essai.",
        Points = { 900, 1300, 1900, 2700, 3900, 5600 },
        IdleRpm = 850,
        LimiterRpm = 7200,
        Turbo = true,
        Pops = true,
        Gain = 0.9,
    }

    local function volumes(layers: { any }): { [string]: number }
        local out = {}
        for _, layer in layers do
            out[layer.Id] = layer.Volume
        end
        return out
    end

    local function state(rpm: number, load: number, extra: { [string]: any }?): any
        local s: any = { Rpm = rpm, Load = load, Running = true, Stalled = false, Gear = nil }
        for k, v in extra or {} do
            s[k] = v
        end
        return s
    end

    T.suite("AUDIO-01 — sons de moteur réalistes")

    T.test("1. Comète à 8 500 tr/min (D3), puissance maximale inchangée ; Brio à 7 200", function()
        local comete = Definitions.get("wk_comete")
        local engine = comete.Powertrain.Engine
        T.equal(engine.LimiterRpm, 8500)
        T.equal(engine.RedlineRpm, 8300)
        T.equal(comete.Powertrain.Transmission.ShiftUpRpm, 8100)
        local ok, errors = Definitions.validate(comete)
        T.truthy(ok, table.concat(errors, " ; "))
        local peak = 0
        for _, point in engine.TorqueCurve do
            peak = math.max(peak, point.TorqueNm * point.Rpm / 9549)
        end
        T.truthy(peak > 460 and peak < 480, string.format("puissance maximale %.0f kW (ancienne : ~470)", peak))
        T.equal(Definitions.get("wk_brio").Powertrain.Engine.LimiterRpm, 7200)
    end)

    T.test("2. régime transmis : codec borné, ancien client accepté, serveur purement sonore", function()
        local command = { Throttle = 0.8, Brake = 0, Steer = 0.1, Handbrake = false, Clutch = 0 }
        local decoded, energy, rpm = InputCodec.decode(InputCodec.encode(command, 0.5, 6234))
        T.truthy(decoded ~= nil, "commande décodée")
        T.equal(energy, 0.5)
        T.equal(rpm, 6200, "régime quantifié par pas de 100")
        local _, _, legacy = InputCodec.decode({ 0.5, 0, 0, 0, 0 })
        T.equal(legacy, nil, "ancien client : pas de régime")
        local _, _, bad = InputCodec.decode({ 0.5, 0, 0, 0, 0, 0 / 0 })
        T.equal(bad, nil, "régime NaN refusé")
        local _, _, huge = InputCodec.decode({ 0.5, 0, 0, 0, 0, 1e9 })
        T.equal(huge, InputCodec.MaxRpm, "régime borné")
        local service = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleService")
        T.truthy(string.find(service, "engine.LimiterRpm * 1.05", 1, true) ~= nil, "borne : rupteur du modèle + 5 %")
        T.truthy(
            string.find(service, "SetAttribute(Constants.Attributes.AudioRpm, nil)", 1, true) ~= nil,
            "plus de conducteur : son retiré"
        )
        local controller = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.VehicleController")
        T.truthy(
            string.find(controller, "InputCodec.encode(driverInput, sessionEnergyUsed(current), rpm)", 1, true) ~= nil
        )
    end)

    T.test("3. couches d'un profil : fondu régime et charge, silence moteur coupé, transposition bornée", function()
        local atPoint = volumes(Model.profileLayers(PROFILE, state(2700, 1), "High"))
        T.truthy(math.abs(atPoint["audio.engine.essai.on.2700"] - PROFILE.Gain) < 1e-9, "boucle en charge pleine")
        T.equal(atPoint["audio.engine.essai.off.2700"], 0, "décharge muette pied au plancher")
        T.equal(atPoint["audio.engine.essai.on.1900"], 0, "voisine muette au régime exact")
        local lifted = volumes(Model.profileLayers(PROFILE, state(3300, 0), "High"))
        T.equal(lifted["audio.engine.essai.on.2700"], 0, "pied levé : aucune boucle en charge")
        local sum = lifted["audio.engine.essai.off.2700"] + lifted["audio.engine.essai.off.3900"]
        T.truthy(math.abs(sum - PROFILE.Gain) < 1e-9, "fondu entre 2 700 et 3 900 : somme constante")
        local off = volumes(Model.profileLayers(PROFILE, state(3000, 1, { Running = false }), "High"))
        for id, volume in off do
            T.equal(volume, 0, id .. " : moteur coupé")
        end
        for _, layer in Model.profileLayers(PROFILE, state(9000, 1), "High") do
            T.truthy(layer.Speed >= Model.ProfileMinSpeed and layer.Speed <= Model.ProfileMaxSpeed, layer.Id)
        end
        local idle = volumes(Model.profileLayers(PROFILE, state(850, 0), "High"))
        T.truthy(idle["audio.engine.essai.turbo"] == 0, "turbo muet au ralenti")
        local loud = 0
        for _, layer in Model.profileLayers(PROFILE, state(3300, 0.6), "Low") do
            loud += if layer.Volume > 0 then 1 else 0
        end
        T.truthy(loud <= 2, "qualité basse : deux couches au plus")
    end)

    T.test("4. événements : démarrage, arrêt, calage, rapport, rupteur, pétarades, turbo", function()
        local function has(list: { string }, name: string): boolean
            return table.find(list, name) ~= nil
        end
        local stopped = state(0, 0, { Running = false })
        T.truthy(has(Model.events(PROFILE, stopped, state(850, 0)), "Start"), "démarrage")
        T.truthy(has(Model.events(PROFILE, state(850, 0), stopped), "Stop"), "arrêt")
        local stall = Model.events(PROFILE, state(600, 0.2), state(0, 0, { Running = false, Stalled = true }))
        T.truthy(has(stall, "Stall") and not has(stall, "Stop"), "calage, pas d'arrêt")
        T.truthy(has(Model.events(PROFILE, state(6000, 1, { Gear = 2 }), state(4400, 1, { Gear = 3 })), "Shift"))
        T.truthy(has(Model.events(PROFILE, state(6000, 1), state(4400, 1)), "Shift"), "rapport déduit de la chute")
        T.truthy(not has(Model.events(PROFILE, state(6000, 0), state(4400, 0)), "Shift"), "pied levé : pas de rapport")
        T.truthy(has(Model.events(PROFILE, state(7000, 1), state(7150, 1)), "Limiter"), "rupteur")
        local lift = Model.events(PROFILE, state(6000, 1), state(5900, 0))
        T.truthy(has(lift, "Pops") and has(lift, "BlowOff"), "lever de pied à haut régime")
        local quiet = table.clone(PROFILE)
        quiet.Pops, quiet.Turbo = false, false
        T.equal(#Model.events(quiet, state(6000, 1), state(5900, 0)), 0, "profil sans pétarades ni turbo")
        T.truthy(
            not has(Model.events(PROFILE, state(2500, 1), state(2400, 0)), "Pops"),
            "pas de pétarades à bas régime"
        )
    end)

    T.test("5. habitacle étouffé, Doppler borné", function()
        local cabin, outside = Model.listening(true), Model.listening(false)
        T.truthy(cabin.HighGain < -6 and cabin.LowGain > 0, "aigus coupés, graves renforcés en cabine")
        T.truthy(outside.LowGain == 0 and outside.MidGain == 0 and outside.HighGain == 0, "extérieur neutre")
        T.equal(Model.doppler(0), 1)
        T.truthy(Model.doppler(30) > 1 and Model.doppler(-30) < 1, "plus aigu en approche, plus grave en s'éloignant")
        T.equal(Model.doppler(1000), Model.DopplerMax)
        T.equal(Model.doppler(-1000), Model.DopplerMin)
    end)

    T.test("6. profils : contrôle de cohérence ; chaque ressource d'un profil déclarée au manifeste", function()
        local AssetManifest = H.require(SHARED .. "Assets.AssetManifest")
        T.equal(#Profiles.validate(PROFILE), 0, "profil d'essai valide")
        local gap = table.clone(PROFILE)
        gap.Points = { 900, 2500, 6500 }
        T.truthy(#Profiles.validate(gap) > 0, "trois boucles trop espacées refusées")
        local short = table.clone(PROFILE)
        short.Points = { 900, 1300, 1900 }
        T.truthy(#Profiles.validate(short) > 0, "rupteur hors de portée refusé")
        for id, profile in Profiles.Profiles do
            local errors = Profiles.validate(profile)
            T.equal(#errors, 0, id .. " : " .. table.concat(errors, " ; "))
            local definition = Definitions.get(id)
            T.truthy(definition ~= nil, id .. " : définition existante")
            T.equal(profile.LimiterRpm, definition.Powertrain.Engine.LimiterRpm, id .. " : rupteur de la définition")
            for _, assetId in Profiles.assetIds(profile) do
                local asset = AssetManifest.get(assetId)
                T.truthy(asset ~= nil and asset.Category == "Audio", assetId .. " : déclaré au manifeste")
            end
        end
        -- Brio (lot AUDIO-01) : 15 sons enregistrés (CC0), aucun identifiant Roblox avant l'envoi du propriétaire.
        local brio = Profiles.Profiles.wk_brio
        T.truthy(brio ~= nil, "profil de la Brio")
        local ids = Profiles.assetIds(brio)
        T.equal(#ids, 15, "6 régimes × charge / décharge + démarrage, arrêt, calage")
        for _, assetId in ids do
            local asset = AssetManifest.get(assetId)
            T.truthy(string.find(asset.Licence, "CC0", 1, true) ~= nil, assetId .. " : licence CC0")
            T.truthy(string.match(asset.Output, "^build/audio/engines/brio/[a-z0-9.]+%.wav$") ~= nil, assetId)
            T.equal(asset.RobloxAssetId, nil, assetId .. " : pas encore envoyé")
        end
        T.equal(#AssetManifest.validate(), 0, "manifeste cohérent")
        local count = 0
        for _ in Profiles.Profiles do
            count += 1
        end
        T.note("Profils inscrits : " .. count)
    end)
end
