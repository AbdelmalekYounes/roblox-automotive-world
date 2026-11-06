--!strict
-- Lot AUDIO-02 : moteur de la Comète. Contrôles hors Studio :
-- - profil (V8 biturbo, rupteur 8 500) ;
-- - ressources et licences (pack « V8 Lotus » en CC BY 4.0 avec crédit en jeu, compléments CC0) ;
-- - couches (turbo, transposition bornée) et événements (pétarades et décharge au lever de pied) ;
-- - boîte à double embrayage.
-- L'écoute et le rendu en jeu relèvent du propriétaire.

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local Model = H.require(SHARED .. "Audio.EngineAudioModel")
    local Profiles = H.require(SHARED .. "Audio.EngineSoundProfiles")
    local AssetManifest = H.require(SHARED .. "Assets.AssetManifest")
    local Attributions = H.require(SHARED .. "Assets.Attributions")
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")

    local profile = Profiles.Profiles.wk_comete

    local function state(rpm: number, load: number): any
        return { Rpm = rpm, Load = load, Running = true, Stalled = false, Gear = nil }
    end

    T.suite("AUDIO-02 — moteur de la Comète")

    T.test("1. profil : valide, rupteur de la définition, turbo et pétarades (décision D2)", function()
        T.truthy(profile ~= nil, "profil de la Comète")
        T.equal(#Profiles.validate(profile), 0, table.concat(Profiles.validate(profile), " ; "))
        local definition = Definitions.get("wk_comete")
        T.equal(profile.LimiterRpm, definition.Powertrain.Engine.LimiterRpm, "rupteur 8 500 (décision D3)")
        T.equal(profile.IdleRpm, definition.Powertrain.Engine.IdleRpm)
        T.truthy(profile.Turbo and profile.Pops, "turbo et pétarades")
        T.equal(definition.Powertrain.Transmission.Kind, "DualClutch", "boîte à double embrayage (720S)")
    end)

    T.test(
        "2. ressources : 20 sons jouables ; licences CC BY (crédit en jeu) ou CC0 ; sortie « micro B »",
        function()
            local ids = Profiles.assetIds(profile)
            T.equal(
                #ids,
                20,
                "7 régimes × charge / décharge + démarrage, arrêt, calage, turbo, décharge, pétarades"
            )
            local cc0 = { turbo = true, blowoff = true, pops = true }
            local seen = {}
            for _, assetId in ids do
                local asset = AssetManifest.get(assetId)
                T.truthy(asset ~= nil and asset.Category == "Audio", assetId .. " : déclaré")
                local name = string.sub(assetId, #profile.Prefix + 1)
                T.truthy(
                    string.match(asset.Output, "^build/audio/engines/comete/micro_b/[a-z0-9.]+%.wav$") ~= nil,
                    assetId .. " : variante « micro B »"
                )
                -- Envoyés sur Roblox par le propriétaire le 2026-11-06 (audio02_comete.rbxm) : jouables, distincts.
                T.equal(
                    asset.RobloxAssetId,
                    AssetManifest.CometeEngineSoundIds[name],
                    assetId .. " : identifiant du propriétaire"
                )
                T.truthy(AssetManifest.playable(assetId), assetId .. " : jouable")
                T.truthy(not seen[asset.RobloxAssetId], assetId .. " : identifiant unique")
                seen[asset.RobloxAssetId] = true
                if cc0[name] then
                    T.truthy(string.find(asset.Licence, "CC0", 1, true) ~= nil, assetId .. " : CC0")
                else
                    T.truthy(string.find(asset.Licence, "CC BY 4.0", 1, true) ~= nil, assetId .. " : CC BY 4.0")
                    local credit = Attributions.forManifest(assetId)
                    T.truthy(credit ~= nil and credit.Creator == "wikusv", assetId .. " : auteur crédité en jeu")
                end
            end
            T.equal(Attributions.forManifest("audio.engine.brio.on.1000"), nil, "la Brio (CC0) n'a pas de crédit")
        end
    )

    T.test("3. couches : transposition bornée jusqu'au rupteur, sifflement du turbo selon la charge", function()
        local function layers(rpm: number, load: number): { [string]: any }
            local out = {}
            for _, layer in Model.profileLayers(profile, state(rpm, load), "High") do
                out[layer.Id] = layer
            end
            return out
        end
        local top = layers(8500, 1)
        T.truthy(top["audio.engine.comete.on.6000"].Volume > 0.5, "au rupteur : boucle de 6 000 tr/min")
        T.truthy(top["audio.engine.comete.on.6000"].Speed <= Model.ProfileMaxSpeed, "transposition bornée")
        local turbo = top["audio.engine.comete.turbo"]
        T.truthy(turbo ~= nil and turbo.Volume > 0, "turbo à pleine charge et haut régime")
        T.equal(layers(850, 0)["audio.engine.comete.turbo"].Volume, 0, "pas de turbo au ralenti")
        T.truthy(layers(5000, 0.05)["audio.engine.comete.turbo"].Volume < 0.01, "pas de turbo pied levé")
    end)

    T.test("4. événements : pétarades et décharge au lever de pied à haut régime, rien au ralenti", function()
        local function has(list: { string }, name: string): boolean
            return table.find(list, name) ~= nil
        end
        local lift = Model.events(profile, state(7000, 1), state(6900, 0))
        T.truthy(has(lift, "Pops") and has(lift, "BlowOff"), "lever de pied à 7 000 tr/min")
        local low = Model.events(profile, state(2500, 1), state(2400, 0))
        T.truthy(not has(low, "Pops") and not has(low, "BlowOff"), "à 2 500 tr/min : ni pétarades ni décharge")
        T.truthy(has(Model.events(profile, state(8400, 1), state(8450, 1)), "Limiter"), "rupteur")
    end)
end
