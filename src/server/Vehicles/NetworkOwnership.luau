--!strict
-- Transitions de propriété réseau d'un véhicule, VÉRIFIÉES.
--
-- Roblox peut refuser `SetNetworkOwner` (pièce ancrée ou soudée à une pièce
-- ancrée, joueur parti…) ou ne pas appliquer le propriétaire demandé. Une
-- transition n'est donc considérée comme réussie que si `GetNetworkOwner`
-- confirme ensuite le propriétaire demandé. Ce module est pur (aucun service
-- Roblox) : l'accès au moteur passe par un « port » fourni par l'appelant, ce
-- qui permet de le tester hors Studio (tests Lune).

local NetworkOwnership = {}

-- Accès au moteur : `set` peut lever une erreur, `get` aussi.
export type Port<Owner> = {
    set: (owner: Owner?) -> (),
    get: () -> Owner?,
}

export type Outcome = "Applied" | "Refused" | "Unreadable" | "Mismatch"

-- Tente la transition puis la vérifie. Renvoie le résultat et, en cas
-- d'échec, un texte de diagnostic (journal serveur uniquement).
function NetworkOwnership.transfer<Owner>(port: Port<Owner>, desired: Owner?): (Outcome, string?)
    local setError: string? = nil
    local setOk = xpcall(function()
        port.set(desired)
    end, function(err)
        setError = tostring(err)
    end)
    if not setOk then
        return "Refused", setError
    end
    local getOk, actual = pcall(port.get)
    if not getOk then
        return "Unreadable", tostring(actual)
    end
    if actual ~= desired then
        return "Mismatch", "propriétaire effectif différent du propriétaire demandé"
    end
    return "Applied", nil
end

-- Lecture protégée du propriétaire effectif. `ok = false` si la lecture échoue
-- (par exemple sur une pièce ancrée, que personne ne simule).
function NetworkOwnership.read<Owner>(port: Port<Owner>): (boolean, Owner?)
    local ok, actual = pcall(port.get)
    if not ok then
        return false, nil
    end
    return true, actual
end

return NetworkOwnership
