--!strict
-- Proposition patinage (docs/PROPOSITION_PATINAGE.md), décision du propriétaire du 2026-11-06 : « E puis B ».
-- E : avis « antipatinage désactivé » quand une roue motrice patine franchement (information, aucune aide cachée).
-- B : antipatinage ACTIF au début de chaque session s'il équipe le modèle (amendement A-02). Contrôles hors Studio ;
-- le rendu en jeu relève du propriétaire.

local PlanarSim = require("../PlanarSim")

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local SpinNotice = H.require(SHARED .. "Vehicles.SpinNotice")
    local Constants = H.require(SHARED .. "Vehicles.VehicleConstants")
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")
    local Dynamics = H.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
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

    T.suite("Patinage — avis (E) et antipatinage actif au départ (B)")

    T.test(
        "1. avis : seulement si l'antipatinage équipe le modèle, est coupé, et qu'une roue motrice patine 0,3 s",
        function()
            local comete = Definitions.get("wk_comete")
            local state = Dynamics.createState(comete)
            state.Gear = 1
            local function spin(ratio: number)
                for _, wheel in state.Wheels do
                    wheel.SlipRatio = if wheel.DriveShare > 0 then ratio else 0
                end
            end
            local function run(seconds: number): boolean
                local timer, shown = 0, false
                for _ = 1, math.floor(seconds * 60 + 0.5) do
                    local notify
                    timer, notify = SpinNotice.step(timer, state, comete, 1 / 60)
                    shown = shown or notify
                end
                return shown
            end
            state.Aids.TractionControl = false
            spin(0.5)
            T.truthy(run(0.4), "patinage franc tenu 0,4 s : avis")
            T.truthy(not run(0.2), "à-coup de 0,2 s : pas d'avis")
            spin(0.2)
            T.truthy(not run(1), "glissement de 2 × le pic (régulation de l'antipatinage) : pas d'avis")
            spin(-0.5)
            T.truthy(not run(1), "blocage au freinage : pas d'avis")
            spin(0.5)
            state.Aids.TractionControl = true
            T.truthy(not run(1), "antipatinage actif : pas d'avis")
            local bare = table.clone(comete)
            bare.Aids = { Abs = true, TractionControl = false, StabilityControl = true }
            state.Aids.TractionControl = false
            local timer, notify = 0, false
            for _ = 1, 60 do
                timer, notify = SpinNotice.step(timer, state, bare, 1 / 60)
                T.truthy(not notify, "modèle sans antipatinage : rien à activer, pas d'avis")
            end
            local fr, en = Localization.t("TractionSpinAidOff"), Localization.t("TractionSpinAidOff", nil, "en")
            T.truthy(string.find(fr, "touche 2", 1, true) ~= nil, "texte joueur par clé, commande indiquée : " .. fr)
            T.truthy(type(en) == "string" and en ~= fr, "texte anglais")
        end
    )

    T.test("2. avis branché au contrôleur, une fois par session, sans modifier les commandes", function()
        local controller = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.VehicleController")
        T.truthy(string.find(controller, 'DevHud.showNotice("TractionSpinAidOff")', 1, true) ~= nil, "avis montré")
        T.truthy(string.find(controller, "current.SpinNoticeShown = true", 1, true) ~= nil, "une fois par session")
        T.truthy(
            string.find(controller, "if current.Simulating and not current.SpinNoticeShown then", 1, true) ~= nil,
            "seulement pour le véhicule simulé par ce joueur"
        )
    end)

    T.test(
        "3. antipatinage actif au départ (amendement A-02), ABS et ESP désactivés, aide absente non ajoutée",
        function()
            T.equal(Constants.AidsOnAtStart.TractionControl, true)
            T.equal(Constants.AidsOnAtStart.Abs, nil, "ABS toujours désactivé au départ")
            T.equal(Constants.AidsOnAtStart.StabilityControl, nil, "ESP toujours désactivé au départ")
            local service = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleService")
            T.truthy(
                string.find(
                    service,
                    "Constants.AidsOnAtStart[aid] == true and (record.Definition.Aids :: any)[aid] == true",
                    1,
                    true
                ) ~= nil,
                "seulement si le modèle en est équipé"
            )
            for _, id in { "wk_brio", "wk_comete" } do
                T.truthy(Definitions.get(id).Aids.TractionControl == true, id .. " : équipé de l'antipatinage")
            end
            -- L'état de la dynamique reste neutre : c'est le serveur qui active l'aide en début de session.
            T.equal(Dynamics.createState(Definitions.get("wk_comete")).Aids.TractionControl, false)
        end
    )

    T.test("4. banc planaire (Comète, départ arrêté à fond) : avis sans antipatinage, aucun avec", function()
        local comete = Definitions.get("wk_comete")
        local function launch(tc: boolean): number?
            local timer, at = 0, nil :: number?
            PlanarSim.run(Dynamics, comete, {
                Dt = 1 / 240,
                Duration = 4,
                Prepare = function(state: any)
                    state.Aids.TractionControl = tc
                end,
                Input = function(t: number, _snapshot: any, state: any)
                    local notify
                    timer, notify = SpinNotice.step(timer, state, comete, 1 / 240)
                    if notify and at == nil then
                        at = t
                    end
                    return { Throttle = math.clamp(t / 0.2, 0, 1), Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
                end,
            })
            return at
        end
        local off, on = launch(false), launch(true)
        print(string.format("      avis sans antipatinage à %s s ; avec : %s", tostring(off), tostring(on)))
        T.truthy(off ~= nil and (off :: number) < 1, "sans antipatinage : avis dans la première seconde")
        T.equal(on, nil, "avec antipatinage : aucun avis")
    end)
end
