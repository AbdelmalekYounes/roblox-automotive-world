--!strict
-- Lot AUDIO-03 : sons des pneus. Contrôles hors Studio : familles de revêtement, résumé des roues (crissement,
-- glissade, roulement), couches sonores, glissement transmis pour les autres joueurs (codec et serveur), manifeste,
-- et réaction du son à la VRAIE dynamique (banc planaire : freinage avec et sans ABS, croisière). L'écoute et le rendu
-- en jeu relèvent du propriétaire.

local PlanarSim = require("../PlanarSim")

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local Model = H.require(SHARED .. "Audio.TireAudioModel")
    local InputCodec = H.require(SHARED .. "Vehicles.InputCodec")
    local AmbienceModel = H.require(SHARED .. "Audio.AmbienceModel")
    local game = H.game()

    local function source(path: string): string
        local node = game
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
            assert(node, path)
        end
        return node.Source
    end

    local PEAK_RATIO, PEAK_ANGLE = 0.1, math.rad(7)

    -- Roue au sol, roulant sans glisser à `v` m/s, modifiable par `extra`.
    local function wheel(v: number, extra: { [string]: any }?): any
        local w: any = {
            Grounded = true,
            SlipRatio = 0,
            SlipAngle = 0,
            ContactVx = v,
            ContactVy = 0,
            RollingSpeed = v,
            Surface = "Hard",
            Wetness = 0,
        }
        for k, value in extra or {} do
            w[k] = value
        end
        return w
    end

    local function four(w: any): { any }
        return { table.clone(w), table.clone(w), table.clone(w), table.clone(w) }
    end

    local function volumes(layers: { any }): { [string]: number }
        local out = {}
        for _, layer in layers do
            out[layer.Id] = layer.Volume
        end
        return out
    end

    local ids = Model.Ids

    T.suite("AUDIO-03 — sons des pneus")

    T.test("1. familles de revêtement : matériaux Roblox, codes réseau, décodage défensif", function()
        T.equal(Model.surfaceOf("Asphalt"), "Hard")
        T.equal(Model.surfaceOf("SmoothPlastic"), "Hard", "matériau courant de la carte : dur")
        T.equal(Model.surfaceOf("Gravel"), "Loose")
        T.equal(Model.surfaceOf("Pebble"), "Loose", "chemins en pièces")
        T.equal(Model.surfaceOf("Grass"), "Soft")
        T.equal(Model.surfaceOf("Snow"), "Soft")
        T.equal(Model.surfaceOf("Ice"), "Ice")
        T.equal(Model.surfaceOf(nil), "Hard", "hors contact : dur par défaut")
        for _, name in Model.Surfaces do
            T.equal(Model.surfaceFromCode(Model.surfaceCode(name)), name, name .. " : aller-retour")
        end
        T.equal(Model.surfaceFromCode(0 / 0), "Hard", "NaN refusé")
        T.equal(Model.surfaceFromCode("Loose"), "Hard", "type invalide refusé")
        T.equal(Model.surfaceFromCode(99), "Ice", "code borné")
    end)

    T.test("2. résumé des roues : croisière muette, virage limite, blocage, patinage, manœuvre lente", function()
        local cruise = Model.summarize(four(wheel(20)), PEAK_RATIO, PEAK_ANGLE)
        T.equal(cruise.Squeal, 0, "croisière : aucun crissement")
        T.truthy(math.abs(cruise.Speed - 20) < 1e-9 and cruise.Grounded == 1)
        -- Virage normal (3°, sous le seuil de 0,7 × pic) : muet.
        local gentle = wheel(20, { SlipAngle = math.rad(3), ContactVy = 20 * math.tan(math.rad(3)) })
        T.equal(Model.summarize(four(gentle), PEAK_RATIO, PEAK_ANGLE).Squeal, 0, "virage normal muet")
        -- Version 2 (retour du propriétaire en jeu) : rien au pic d'adhérence ; crissement seulement au-delà, quand le
        -- pneu glisse vraiment, croissant avec la dérive.
        local function corner(deg: number): number
            local w = wheel(20, { SlipAngle = math.rad(deg), ContactVy = 20 * math.tan(math.rad(deg)) })
            return Model.summarize(four(w), PEAK_RATIO, PEAK_ANGLE).Squeal
        end
        T.equal(corner(7), 0, "au pic d'adhérence (7°) : muet")
        T.equal(corner(8.5), 0, "juste au-delà du pic : encore muet")
        T.truthy(corner(12) > 0 and corner(20) > corner(12), "glisse : crissement croissant avec la dérive")
        T.equal(corner(30), 1, "dérapage large : plein crissement")
        -- Braquage à fond à 20 km/h (au clavier) : avant au-delà de son pic sans vraie glissade → muet.
        local slowTurn = wheel(5.6, { SlipAngle = math.rad(10), ContactVy = 5.6 * math.tan(math.rad(10)) })
        T.equal(Model.summarize(four(slowTurn), PEAK_RATIO, PEAK_ANGLE).Squeal, 0, "braquage à basse vitesse muet")
        -- Roues bloquées à 20 m/s : crissement et glissade franche.
        local locked = Model.summarize(four(wheel(20, { SlipRatio = -1, RollingSpeed = 0 })), PEAK_RATIO, PEAK_ANGLE)
        T.equal(locked.Squeal, 1, "blocage : plein crissement")
        T.truthy(locked.Scrub > 0.9, "blocage : glissade franche")
        T.truthy(locked.SlipSpeed > 19, "vitesse de glissement = vitesse du véhicule")
        -- Patinage au départ (roues motrices avant seulement, véhicule presque arrêté).
        local spin = four(wheel(0.5))
        -- Démarrage en force : roues à 8 m/s pour 0,5 m/s au sol, glissement 15 (150 × le pic).
        spin[1].RollingSpeed, spin[1].SlipRatio = 8, 15
        spin[2].RollingSpeed, spin[2].SlipRatio = 8, 15
        local burnout = Model.summarize(spin, PEAK_RATIO, PEAK_ANGLE)
        T.truthy(burnout.Squeal > 0.9, "démarrage en force des deux roues : plein crissement")
        -- Version 4 (« son plus tolérant ») : patinage modéré d'un essieu muet, blocage au même glissement audible.
        local function axle(ratio: number, rolling: number): number
            local w = four(wheel(15))
            for index = 3, 4 do
                w[index].SlipRatio, w[index].RollingSpeed = ratio, rolling
            end
            return Model.summarize(w, PEAK_RATIO, PEAK_ANGLE).Squeal
        end
        T.equal(axle(0.6, 24), 0, "patinage à 6 × le pic : muet")
        T.truthy(axle(0.6, 24) < axle(-0.6, 6), "blocage au même glissement : audible")
        T.truthy(axle(-0.6, 6) > 0.5, "blocage à 6 × le pic : crissement")
        T.truthy(axle(4, 75) > 0.9, "patinage à 40 × le pic : plein crissement")
        -- Version 3 : une roue seule qui patine (roue intérieure en virage) ne crisse pas ; les deux roues d'un essieu,
        -- si (frein à main : arrière bloqué).
        local one = four(wheel(20))
        one[1].SlipRatio, one[1].RollingSpeed = 1, 30
        T.equal(Model.summarize(one, PEAK_RATIO, PEAK_ANGLE).Squeal, 0, "roue intérieure qui patine seule : muet")
        local handbrake = four(wheel(15))
        handbrake[3].SlipRatio, handbrake[3].RollingSpeed = -1, 0
        handbrake[4].SlipRatio, handbrake[4].RollingSpeed = -1, 0
        local rear = Model.summarize(handbrake, PEAK_RATIO, PEAK_ANGLE).Squeal
        T.truthy(rear > 0.9, string.format("essieu arrière bloqué (deux roues) : %.2f", rear))
        -- Sous-virage : l'avant seul au-delà de son pic ne crisse qu'à vitesse élevée.
        local function understeer(v: number): number
            local w = four(wheel(v))
            for index = 1, 2 do
                w[index].SlipAngle = math.rad(28)
            end
            return Model.summarize(w, PEAK_RATIO, PEAK_ANGLE).Squeal
        end
        T.equal(understeer(11), 0, "40 km/h, avant à 28° de dérive : muet")
        T.truthy(understeer(25) > 0.5, "90 km/h, avant à 28° de dérive : crissement")
        -- Manœuvre lente : grand angle de dérive mais vitesse de glissement minime → muet.
        local slow = wheel(0.2, { SlipAngle = math.rad(30), ContactVy = 0.1 })
        T.equal(Model.summarize(four(slow), PEAK_RATIO, PEAK_ANGLE).Squeal, 0, "parking : muet")
        -- En l'air : rien au sol.
        local air = Model.summarize(four(wheel(20, { Grounded = false })), PEAK_RATIO, PEAK_ANGLE)
        T.truthy(air.Grounded == 0 and air.Speed == 0 and air.Squeal == 0, "en l'air : aucun son de contact")
        -- Revêtement majoritaire et humidité moyenne.
        local mixed = four(wheel(10, { Wetness = 1 }))
        mixed[1].Surface, mixed[2].Surface, mixed[3].Surface = "Loose", "Loose", "Loose"
        local summary = Model.summarize(mixed, PEAK_RATIO, PEAK_ANGLE, true)
        T.truthy(summary.Surface == "Loose" and summary.Wetness == 1 and summary.Abs, "famille majoritaire, ABS")
    end)

    T.test("3. couches : roulement selon la vitesse et le revêtement, crissement selon le sol", function()
        local function layersAt(v: number, extra: { [string]: any }?, quality: string?): { [string]: number }
            local summary = Model.summarize(four(wheel(v, extra)), PEAK_RATIO, PEAK_ANGLE)
            return volumes(Model.layers(summary, 1200, quality or "High"))
        end
        for id, volume in layersAt(0) do
            T.equal(volume, 0, id .. " : silence à l'arrêt")
        end
        local slow, mid, fast = layersAt(5)[ids.RollDry], layersAt(15)[ids.RollDry], layersAt(33)[ids.RollDry]
        T.truthy(slow > 0 and mid > slow and fast > mid, "roulement croissant avec la vitesse")
        T.truthy(fast <= 1, "volume borné")
        local loose = layersAt(15, { Surface = "Loose" })
        T.truthy(loose[ids.RollLoose] > 0 and loose[ids.RollDry] == 0, "gravier : crépitement, pas de roulement sec")
        local wet = layersAt(15, { Wetness = 1 })
        T.truthy(wet[ids.RollWet] > 0 and wet[ids.RollDry] < mid, "mouillé : chuintement, roulement sec réduit")
        T.equal(layersAt(15)[ids.RollWet], 0, "sec : aucun chuintement")
        -- Glissade (roues bloquées) selon le revêtement.
        local hard = layersAt(20, { SlipRatio = -1, RollingSpeed = 0 })
        T.truthy(hard[ids.Squeal] > 0.5 and hard[ids.Scrub] > 0 and hard[ids.SlideLoose] == 0, "asphalte : crissement")
        local wetSlide = layersAt(20, { SlipRatio = -1, RollingSpeed = 0, Wetness = 1 })
        T.truthy(wetSlide[ids.Squeal] < hard[ids.Squeal] * 0.5, "mouillé : crissement atténué")
        local gravel = layersAt(20, { SlipRatio = -1, RollingSpeed = 0, Surface = "Loose" })
        T.truthy(gravel[ids.Squeal] == 0 and gravel[ids.SlideLoose] > 0.5, "gravier : glissade de gravier")
        local ice = layersAt(20, { SlipRatio = -1, RollingSpeed = 0, Surface = "Ice" })
        T.truthy(ice[ids.Squeal] < 0.1, "glace : presque aucun crissement")
        -- Qualité basse : deux couches audibles au plus.
        local audible = 0
        for _, volume in layersAt(20, { SlipRatio = -1, RollingSpeed = 0, Wetness = 0.5 }, "Low") do
            audible += if volume > 0 then 1 else 0
        end
        T.truthy(audible <= 2, "qualité basse : deux couches au plus")
        -- Véhicule lourd : roulement plus fort, plus grave.
        local summary = Model.summarize(four(wheel(15)), PEAK_RATIO, PEAK_ANGLE)
        local light, heavy = Model.layers(summary, 900, "High"), Model.layers(summary, 2000, "High")
        T.truthy(heavy[1].Volume > light[1].Volume and heavy[1].Speed < light[1].Speed, "masse : plus fort et grave")
    end)

    T.test("4. ABS : grondement pulsé (véhicule conduit seulement), vitesses de lecture bornées", function()
        local sliding = four(wheel(20, { SlipRatio = -0.3, RollingSpeed = 14 }))
        local summary = Model.summarize(sliding, PEAK_RATIO, PEAK_ANGLE, true)
        local low, high = math.huge, 0
        for step = 0, 40 do
            local v = volumes(Model.layers(summary, 1200, "High", step / 400))[ids.Squeal]
            low, high = math.min(low, v), math.max(high, v)
        end
        T.truthy(high > low * 1.5, string.format("pulsation : %.2f à %.2f", low, high))
        local steady = volumes(Model.layers(summary, 1200, "High"))[ids.Squeal]
        T.truthy(steady > 0, "sans horloge (véhicule observé) : crissement continu")
        for _, slip in { 0, 0.5, 1 } do
            for _, layer in Model.layers(Model.observed(slip, 0, 40, 1), 1200, "High") do
                T.truthy(layer.Speed >= 0.7 and layer.Speed <= 1.4, layer.Id .. " : vitesse de lecture bornée")
                T.truthy(layer.Volume >= 0 and layer.Volume <= 1, layer.Id .. " : volume borné")
            end
        end
    end)

    T.test("5. glissement transmis : codec borné, ancien client accepté, serveur purement sonore", function()
        local command = { Throttle = 0.6, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
        local encoded = InputCodec.appendTire(InputCodec.encode(command, 0.2, 3000), 0.66, 1)
        T.equal(encoded[7], 0.7, "glissement quantifié par pas de 0,1")
        T.equal(encoded[8], 1)
        local decoded, energy, rpm, slip, surface = InputCodec.decode(encoded)
        T.truthy(decoded ~= nil and energy == 0.2 and rpm == 3000, "valeurs d'AUDIO-01 inchangées")
        T.equal(slip, 0.7)
        T.equal(surface, 1)
        local _, _, _, legacySlip, legacySurface = InputCodec.decode({ 0.5, 0, 0, 0, 0, 3000 })
        T.truthy(legacySlip == nil and legacySurface == nil, "ancien client : pas de pneus")
        local _, _, _, nanSlip = InputCodec.decode({ 0.5, 0, 0, 0, 0, 3000, 0 / 0, 0 })
        T.equal(nanSlip, nil, "glissement NaN refusé")
        local _, _, _, bigSlip, bigSurface = InputCodec.decode({ 0.5, 0, 0, 0, 0, 3000, 50, 9 })
        T.truthy(bigSlip == 1 and bigSurface == 3, "valeurs bornées")
        local service = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleService")
        T.truthy(
            string.find(service, "if speedMs < 1 and input.Throttle < 0.1 then", 1, true) ~= nil,
            "contexte : pas de crissement à l'arrêt sans accélérateur"
        )
        T.truthy(
            string.find(service, "SetAttribute(Constants.Attributes.AudioTireSlip, nil)", 1, true) ~= nil,
            "plus de conducteur : glissement retiré"
        )
        local controller = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.VehicleController")
        T.truthy(string.find(controller, "InputCodec.appendTire(", 1, true) ~= nil, "déclaration envoyée")
        T.truthy(string.find(controller, "TireAudio = lastTireSummary", 1, true) ~= nil, "résumé transmis au son")
        local audio = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Audio.AudioController")
        T.truthy(
            string.find(audio, "observedTireLayers(entry.Model", 1, true) ~= nil,
            "véhicules observés sonorisés"
        )
        T.truthy(
            string.find(audio, 'equalizeGroup("AWEffects", cockpit)', 1, true) ~= nil,
            "pneus étouffés en cabine"
        )
    end)

    T.test("6. manifeste : chaque son de pneu déclaré, catégorie « Effets », source et licence", function()
        local AssetManifest = H.require(SHARED .. "Assets.AssetManifest")
        for _, id in ids do
            local asset = AssetManifest.get(id)
            T.truthy(asset ~= nil and asset.Category == "Audio", id .. " : déclaré")
            T.equal(AmbienceModel.categoryOf(id), "Effects", id .. " : volume « Effets » (décision Q4)")
            T.truthy(string.sub(asset.Output or "", 1, 18) == "build/audio/tires/", id .. " : sortie de l'outil")
            T.truthy(string.find(asset.Licence, "CC0", 1, true) ~= nil, id .. " : licence relevée")
            -- Envoyés sur Roblox par le propriétaire le 2026-11-06 (audio03_pneus.rbxm) : jouables.
            T.truthy(AssetManifest.playable(id), id .. " : identifiant Roblox présent")
        end
        local seen = {}
        for _, number in AssetManifest.TireSoundIds do
            T.truthy(seen[number] == nil, "identifiants distincts")
            seen[number] = true
        end
    end)

    T.test("7. vraie dynamique (banc planaire, Brio) : freinage fort avec et sans ABS, croisière", function()
        local Dynamics = H.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
        local definition = H.require(SHARED .. "Vehicles.VehicleDefinitions").get("wk_brio")
        local tires = definition.Tires
        local function run(abs: boolean, brake: number): (number, number, boolean, number?, number?)
            local peak, sum, count, absSeen = 0, 0, 0, false
            local first: number?, last: number? = nil, nil
            PlanarSim.run(Dynamics, definition, {
                Dt = 1 / 240,
                Duration = 3,
                InitialForward = 80 / 3.6,
                Prepare = function(state: any)
                    state.Aids.Abs = abs
                end,
                Input = function(t: number, snapshot: any, state: any)
                    local samples = {}
                    for _, w in state.Wheels do
                        table.insert(samples, {
                            Grounded = true,
                            SlipRatio = w.SlipRatio,
                            SlipAngle = w.SlipAngle,
                            ContactVx = snapshot.Forward,
                            ContactVy = snapshot.Lateral,
                            RollingSpeed = w.AngularVelocity * tires.RadiusM,
                            Surface = "Hard",
                            Wetness = 0,
                        })
                    end
                    -- Les 0,1 premières secondes sont écartées : transitoire du départ lancé du banc (roues mises à la
                    -- vitesse du châssis), relevé le 2026-11-06 entre 0,008 et 0,033 s en roue libre (crissement
                    -- max 0,054), sans équivalent en jeu.
                    if snapshot.Forward > 3 and t >= 0.1 then
                        local s = Model.summarize(
                            samples,
                            tires.PeakSlipRatio,
                            math.rad(tires.PeakSlipAngleDeg),
                            state.AidActivity.Abs
                        )
                        peak = math.max(peak, s.Squeal)
                        sum += s.Squeal
                        count += 1
                        absSeen = absSeen or s.Abs
                        if s.Squeal > 0 then
                            first = first or t
                            last = t
                        end
                    end
                    return { Throttle = 0, Brake = brake, Steer = 0, Handbrake = false, Clutch = 0 }
                end,
            })
            return peak, if count > 0 then sum / count else 0, absSeen, first, last
        end
        local lockedPeak, lockedMean = run(false, 1)
        local absPeak, absMean, absSeen = run(true, 1)
        local cruisePeak, cruiseMean, _, cruiseFirst, cruiseLast = run(true, 0)
        print(
            string.format(
                "      sans ABS : crissement max %.2f, moyen %.2f ; avec ABS : max %.2f, moyen %.2f ; roue libre : max %.3f, moyen %.4f, de %s à %s s",
                lockedPeak,
                lockedMean,
                absPeak,
                absMean,
                cruisePeak,
                cruiseMean,
                tostring(cruiseFirst),
                tostring(cruiseLast)
            )
        )
        T.truthy(lockedMean > 0.6, "sans ABS : roues bloquées, crissement net")
        T.truthy(absSeen, "avec ABS : ABS en action détecté")
        T.truthy(absMean < lockedMean, "avec ABS : moins de crissement que roues bloquées")
        T.truthy(absMean >= Model.AbsSquealFloor * 0.8, "avec ABS : grondement audible (plancher sonore)")
        T.equal(cruiseMean, 0, "roue libre en ligne droite : aucun crissement")
    end)

    T.test(
        "8. vraie dynamique (banc planaire, Brio) : braquer ne crisse pas, seule la perte d'adhérence crisse",
        function()
            local Dynamics = H.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
            local definition = H.require(SHARED .. "Vehicles.VehicleDefinitions").get("wk_brio")
            local tires = definition.Tires
            -- Braquage d'un coup (crémaillère limitée, comme au clavier) puis tenu ; accélérateur fixe (`throttle`) ou
            -- vitesse tenue (nil) ; frein à main facultatif entre 0,3 et 1,5 s ; aides coupées (comme au départ d'une
            -- session). Crissement maximal après 0,1 s.
            local function corner(kmh: number, steer: number, throttle: number?, handbrake: boolean?): number
                local peak = 0
                PlanarSim.run(Dynamics, definition, {
                    Dt = 1 / 240,
                    Duration = 2.5,
                    InitialForward = kmh / 3.6,
                    Input = function(t: number, snapshot: any, state: any)
                        local samples = {}
                        for _, w in state.Wheels do
                            table.insert(samples, {
                                Grounded = true,
                                SlipRatio = w.SlipRatio,
                                SlipAngle = w.SlipAngle,
                                ContactVx = snapshot.Forward,
                                ContactVy = snapshot.Lateral,
                                RollingSpeed = w.AngularVelocity * tires.RadiusM,
                                Surface = "Hard",
                                Wetness = 0,
                            })
                        end
                        if t >= 0.1 then
                            local s = Model.summarize(samples, tires.PeakSlipRatio, math.rad(tires.PeakSlipAngleDeg))
                            peak = math.max(peak, s.Squeal)
                        end
                        return {
                            Throttle = throttle or math.clamp((kmh / 3.6 - snapshot.Forward) * 0.5 + 0.2, 0, 1),
                            Brake = 0,
                            Steer = steer,
                            Handbrake = handbrake == true and t > 0.3 and t < 1.5,
                            Clutch = 0,
                        }
                    end,
                })
                return peak
            end
            -- Second retour du propriétaire en jeu : virages au clavier (braquage à fond), accélérateur relâché ou
            -- enfoncé (la roue avant intérieure patine alors seule), de 20 à 60 km/h → muets.
            for _, kmh in { 20, 30, 40, 60 } do
                for _, throttle in { 0, 1 } do
                    T.equal(
                        corner(kmh, 1, throttle),
                        0,
                        string.format("%d km/h, braquage à fond, accélérateur %d : muet", kmh, throttle)
                    )
                end
            end
            T.equal(corner(40, 0.5), 0, "40 km/h, mi-braquage, vitesse tenue : muet")
            local fast, handbrake = corner(100, 1, 0), corner(40, 0.5, 0, true)
            print(
                string.format(
                    "      100 km/h braquage à fond : crissement %.2f ; frein à main en virage à 40 km/h : %.2f",
                    fast,
                    handbrake
                )
            )
            T.truthy(fast > 0.5, "100 km/h braquage à fond : sous-virage franc, crissement")
            T.truthy(handbrake > 0.8, "frein à main en virage : l'arrière glisse, crissement")

            -- Version 4, Comète (propulsion, 475 kW), aides coupées comme au départ d'une session, accélérateur à fond
            -- en ligne droite : le patinage modéré de l'arrière ne crisse presque plus ; le départ arrêté reste audible.
            local comete = H.require(SHARED .. "Vehicles.VehicleDefinitions").get("wk_comete")
            local function straight(kmh: number, tc: boolean): (number, number)
                local peak, sum, count = 0, 0, 0
                PlanarSim.run(Dynamics, comete, {
                    Dt = 1 / 240,
                    Duration = 3,
                    InitialForward = kmh / 3.6,
                    Prepare = function(state: any)
                        state.Aids.TractionControl = tc
                    end,
                    Input = function(t: number, snapshot: any, state: any)
                        local samples = {}
                        for _, w in state.Wheels do
                            table.insert(samples, {
                                Grounded = true,
                                SlipRatio = w.SlipRatio,
                                SlipAngle = w.SlipAngle,
                                ContactVx = snapshot.Forward,
                                ContactVy = snapshot.Lateral,
                                RollingSpeed = w.AngularVelocity * comete.Tires.RadiusM,
                                Surface = "Hard",
                                Wetness = 0,
                            })
                        end
                        if t >= 0.1 then
                            local s = Model.summarize(
                                samples,
                                comete.Tires.PeakSlipRatio,
                                math.rad(comete.Tires.PeakSlipAngleDeg)
                            )
                            peak = math.max(peak, s.Squeal)
                            sum += s.Squeal
                            count += 1
                        end
                        return { Throttle = 1, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
                    end,
                })
                return peak, sum / math.max(count, 1)
            end
            local launchPeak, launchMean = straight(0, false)
            local _, mean20 = straight(20, false)
            local _, mean40 = straight(40, false)
            local _, tcMean = straight(20, true)
            print(
                string.format(
                    "      Comète à fond sans antipatinage : départ arrêté max %.2f moyen %.2f ; 20 km/h moyen %.2f ; 40 km/h moyen %.2f ; avec antipatinage 20 km/h moyen %.2f",
                    launchPeak,
                    launchMean,
                    mean20,
                    mean40,
                    tcMean
                )
            )
            T.truthy(launchPeak > 0.8, "Comète, départ arrêté à fond : démarrage en force audible")
            T.truthy(mean20 < 0.15 and mean40 < 0.05, "Comète à fond en ligne droite lancée : presque muette")
            T.equal(tcMean, 0, "Comète avec antipatinage : muette")
        end
    )
end
