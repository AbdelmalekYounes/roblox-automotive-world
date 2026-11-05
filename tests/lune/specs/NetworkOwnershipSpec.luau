--!strict
-- Tests des transitions de propriété réseau vérifiées (module pur, port simulé).

return function(T: any, H: any)
    local NetworkOwnership = H.require("ServerScriptService.AutomotiveWorldServer.Vehicles.NetworkOwnership")

    -- Port simulé : `apply` décide de ce que le « moteur » fait de la demande.
    local function fakePort(apply: (desired: string?) -> string?, readFails: boolean?)
        local state = { owner = nil :: string?, calls = 0 }
        local port = {
            set = function(desired: string?)
                state.calls += 1
                state.owner = apply(desired)
            end,
            get = function(): string?
                if readFails then
                    error("lecture impossible sur une pièce ancrée")
                end
                return state.owner
            end,
        }
        return port, state
    end

    T.suite("Propriété réseau vérifiée")

    T.test("attribution acceptée et confirmée → Applied", function()
        local port, state = fakePort(function(desired)
            return desired
        end)
        local outcome, detail = NetworkOwnership.transfer(port, "joueur1")
        T.equal(outcome, "Applied")
        T.equal(detail, nil)
        T.equal(state.owner, "joueur1")
    end)

    T.test("retour au serveur (nil) confirmé → Applied", function()
        local port = fakePort(function(desired)
            return desired
        end)
        T.equal((NetworkOwnership.transfer(port, nil)), "Applied")
    end)

    T.test("SetNetworkOwner lève une erreur (pièce ancrée) → Refused, pas de succès supposé", function()
        local port = {
            set = function(_: string?)
                error("Network Ownership API cannot be called on Anchored parts")
            end,
            get = function(): string?
                return nil
            end,
        }
        local outcome, detail = NetworkOwnership.transfer(port, "joueur1")
        T.equal(outcome, "Refused")
        T.truthy(detail ~= nil and string.find(detail, "Anchored", 1, true) ~= nil, "diagnostic conservé")
    end)

    T.test("le moteur garde un autre propriétaire → Mismatch", function()
        local port = fakePort(function(_)
            return "serveur-garde"
        end)
        T.equal((NetworkOwnership.transfer(port, "joueur1")), "Mismatch")
    end)

    T.test("propriétaire illisible après la demande → Unreadable (jamais Applied)", function()
        local port = fakePort(function(desired)
            return desired
        end, true)
        T.equal((NetworkOwnership.transfer(port, "joueur1")), "Unreadable")
    end)

    T.test("lecture protégée : erreur → (false, nil)", function()
        local port = fakePort(function(desired)
            return desired
        end, true)
        local ok, owner = NetworkOwnership.read(port)
        T.equal(ok, false)
        T.equal(owner, nil)
    end)
end
