--!strict
--[[
    Mutations SENSIBLES identifiées et idempotentes (AUD-TX-01, AUD-UI-02).

    Une mutation sensible porte un identifiant de transaction :
    - fixe pour une attribution unique (ex. « Grant:FreeProperty ») ;
    - fourni par le client pour une demande (anti double clic), préfixé et
      validé par le serveur : il ne sert qu'à reconnaître une répétition, il
      n'accorde aucun droit.

    La mutation s'exécute sur une COPIE du profil : si elle échoue, rien n'est
    modifié ; si elle réussit, la copie remplace le profil et la transaction
    est inscrite au journal du profil, ce qui rend toute répétition inerte
    (la réponse d'origine est renvoyée). Le caractère DURABLE (sauvegarde
    confirmée) est géré par ProfileSession.

    Ce lot ne traite que des transactions mono-profil. Les transactions entre
    profils (vente entre joueurs, lot 0.5) exigeront un enregistrement de
    transaction séparé avec réservation, confirmation et compensation : voir
    docs/lot-0.4/ARCHITECTURE_LOT_0.4.md.
]]

local ProfileSchema = require(script.Parent.ProfileSchema)
local ProfileMigration = require(script.Parent.ProfileMigration)

local TransactionService = {}

-- Identifiant de demande accepté depuis un client (lettres, chiffres, tiret).
TransactionService.MaxRequestIdLength = 40

export type Mutation = (profile: ProfileSchema.Profile) -> (boolean, any)

function TransactionService.clientTxId(requestId: any): string?
    if type(requestId) ~= "string" or #requestId < 8 or #requestId > TransactionService.MaxRequestIdLength then
        return nil
    end
    if string.find(requestId, "[^%w%-]") then
        return nil
    end
    return "C:" .. requestId
end

-- Ancienne réponse si la transaction a déjà été appliquée.
function TransactionService.previous(profile: ProfileSchema.Profile, txId: string): ProfileSchema.TransactionEntry?
    return profile.Transactions[txId]
end

-- Journal récent borné : les plus anciennes entrées partent en premier.
local function prune(profile: ProfileSchema.Profile)
    local ids: { string } = {}
    for id in profile.Transactions do
        table.insert(ids, id)
    end
    local excess = #ids - ProfileSchema.MaxRecentTransactions
    if excess <= 0 then
        return
    end
    table.sort(ids, function(a, b)
        local ta, tb = profile.Transactions[a].At, profile.Transactions[b].At
        if ta ~= tb then
            return ta < tb
        end
        return a < b
    end)
    for i = 1, excess do
        profile.Transactions[ids[i]] = nil
    end
end

--[[
    Applique `mutate` sur une copie. Renvoie (ok, résultat ou clé d'erreur,
    nouveau profil). Ne modifie jamais `profile`.
]]
function TransactionService.apply(
    profile: ProfileSchema.Profile,
    txId: string,
    kind: string,
    now: number,
    mutate: Mutation
): (boolean, any, ProfileSchema.Profile?)
    if profile.Transactions[txId] then
        return false, "TxDuplicate", nil
    end
    local copy = ProfileMigration.deepCopy(profile)
    local ok, result = mutate(copy)
    if not ok then
        return false, result, nil
    end
    -- Garde-fou : la mutation ne doit jamais produire un profil incohérent.
    local valid, errors = ProfileSchema.validate(copy)
    if not valid then
        return false, "ProfileInconsistent:" .. tostring(errors[1]), nil
    end
    if ProfileSchema.estimateSize(copy) > ProfileSchema.SoftLimitBytes then
        return false, "ProfileTooLarge", nil
    end
    copy.Transactions[txId] = { Kind = kind, At = now, Result = result }
    copy.UpdatedAt = now
    prune(copy)
    return true, result, copy
end

return table.freeze(TransactionService)
