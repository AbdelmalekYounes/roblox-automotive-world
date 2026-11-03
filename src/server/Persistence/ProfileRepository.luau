--!strict
--[[
    Interface de stockage des profils, commune à l'adaptateur DataStore
    (DataStoreProfileRepository) et à l'adaptateur mémoire des tests
    (MemoryProfileRepository).

    update(key, transform) applique une transformation conditionnelle
    (sémantique de UpdateAsync : transform(ancien) → nouveau, ou nil pour
    annuler) et renvoie un résultat explicite :
    - "Ok"        : écriture appliquée et confirmée ;
    - "Cancelled" : la transformation a renvoyé nil (rien d'écrit) ;
    - "Failed"    : échec certain, rien n'a été écrit ;
    - "Uncertain" : réponse perdue, l'écriture a PEUT-ÊTRE été appliquée : il
      faut relire et réconcilier (jamais rejouer à l'aveugle, §8.3).
]]

local ProfileRepository = {}

export type UpdateStatus = "Ok" | "Cancelled" | "Failed" | "Uncertain"

export type UpdateResult = {
    Status: UpdateStatus,
    Value: any?,
    Error: string?,
}

export type ReadResult = {
    Ok: boolean,
    Value: any?,
    Error: string?,
}

export type Repository = {
    Name: string,
    update: (self: any, key: string, transform: (any) -> any?) -> UpdateResult,
    read: (self: any, key: string) -> ReadResult,
}

-- Clé stable d'un profil : fondée sur le UserId, jamais sur le nom.
function ProfileRepository.keyFor(userId: number): string
    assert(userId == math.floor(userId) and userId ~= 0, "UserId invalide")
    return "Profile_" .. tostring(userId)
end

return table.freeze(ProfileRepository)
