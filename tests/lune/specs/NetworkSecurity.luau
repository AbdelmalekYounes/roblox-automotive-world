--!strict
-- Tests des défenses réseau pures : décodage des commandes, plausibilité des
-- mouvements et limitation de débit.

return function(T: any, H: any)
    local InputCodec = H.require("ReplicatedStorage.Shared.Vehicles.InputCodec")
    local MovementRules = H.require("ServerScriptService.AutomotiveWorldServer.Security.MovementRules")
    local RateLimiter = H.require("ServerScriptService.AutomotiveWorldServer.Security.RateLimiter")

    T.suite("Décodage des commandes client")

    T.test("aller-retour encode/decode", function()
        local decoded =
            InputCodec.decode(InputCodec.encode({ Throttle = 0.756, Brake = 0, Steer = -0.333, Handbrake = true }))
        T.truthy(decoded)
        T.near(decoded.Throttle, 0.76, 1e-9)
        T.near(decoded.Steer, -0.33, 1e-9)
        T.equal(decoded.Handbrake, true)
    end)

    T.test("valeurs hors bornes ramenées dans les bornes", function()
        local decoded = InputCodec.decode({ 50, -3, 9, 1 })
        T.equal(decoded.Throttle, 1)
        T.equal(decoded.Brake, 0)
        T.equal(decoded.Steer, 1)
    end)

    for label, payload in
        {
            ["non-table"] = "texte" :: any,
            ["NaN"] = { 0 / 0, 0, 0, 0 },
            ["infini"] = { 0, math.huge, 0, 0 },
            ["type incorrect"] = { "1", 0, 0, 0 },
            ["champ manquant"] = { 1, 0, 0 },
        }
    do
        T.test("charge utile rejetée : " .. label, function()
            T.equal(InputCodec.decode(payload), nil)
        end)
    end

    T.test("charge utile rejetée : nil", function()
        T.equal(InputCodec.decode(nil), nil)
    end)

    T.suite("Plausibilité des mouvements (serveur)")

    local maxSpeed = 280 / 3.6
    local function sample(time: number, z: number, speed: number)
        return { Time = time, X = 0, Y = 0, Z = z, SpeedMs = speed }
    end

    T.test("mouvement normal accepté", function()
        T.equal(MovementRules.evaluate(sample(0, 0, 20), sample(0.2, 4, 20), maxSpeed), "Ok")
    end)

    T.test("à-coup réseau toléré (rattrapage de 0,5 s en un échantillon)", function()
        -- 30 m/s pendant 0,7 s cumulées arrivées d'un coup : 21 m.
        T.equal(MovementRules.evaluate(sample(0, 0, 30), sample(0.2, 21, 30), maxSpeed) ~= "Impossible", true)
    end)

    T.test("survitesse légère → suspect seulement", function()
        local verdict = MovementRules.evaluate(sample(0, 0, 0), sample(0.2, 0, maxSpeed * 1.5), maxSpeed)
        T.equal(verdict, "Suspicious")
    end)

    T.test("survitesse impossible → correction", function()
        local verdict, reason = MovementRules.evaluate(sample(0, 0, 0), sample(0.2, 0, maxSpeed * 3), maxSpeed)
        T.equal(verdict, "Impossible")
        T.equal(reason, "Overspeed")
    end)

    T.test("téléportation → correction", function()
        local verdict, reason = MovementRules.evaluate(sample(0, 0, 10), sample(0.2, 500, 10), maxSpeed)
        T.equal(verdict, "Impossible")
        T.equal(reason, "Teleport")
    end)

    T.test("valeurs non finies → correction", function()
        local verdict = MovementRules.evaluate(sample(0, 0, 10), sample(0.2, 0 / 0, 10), maxSpeed)
        T.equal(verdict, "Impossible")
    end)

    T.suite("Limitation de débit")

    T.test("rafale bornée puis recharge", function()
        local bucket = RateLimiter.new(5, 2, 0)
        local accepted = 0
        for _ = 1, 20 do
            if RateLimiter.consume(bucket, 0) then
                accepted += 1
            end
        end
        T.equal(accepted, 5, "capacité")
        T.equal(RateLimiter.consume(bucket, 0.4), false, "pas encore rechargé")
        T.equal(RateLimiter.consume(bucket, 0.6), true, "un jeton rechargé")
    end)
end
