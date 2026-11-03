--!strict
--[[
    Choix DÉFINITIF du véhicule gratuit de départ (§3.1, §10.1, AUD-ONB-01,
    SCN-01). Mutation pure, à exécuter dans une transaction d'identifiant fixe
    « Grant:Starter » (ProfileSession.commit) : un double clic, une latence ou
    une déconnexion ne peuvent pas créer de second exemplaire.

    - Choix explicite parmi la liste officielle (StarterCatalog) ; liste vide
      tant que les modèles de lancement ne sont pas validés → refus.
    - Exemplaire incessible (ni vente ni transfert), origine « Starter ».
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local VehicleOwnership = require(script.Parent.VehicleOwnership)

local StarterSelection = {}

StarterSelection.TxId = "Grant:Starter"

--[[
    `candidates` : identifiants officiels (StarterCatalog.Candidates, ou liste
    synthétique dans les tests) ; `prepare(modelId)` fournit la réserve et
    l'apparence de livraison du modèle (nil si le modèle n'existe pas).
]]
function StarterSelection.choose(
    profile: ProfileSchema.Profile,
    modelId: any,
    candidates: { string },
    now: number,
    prepare: (string) -> (number?, { [string]: any }?)
): (boolean, any)
    if #candidates == 0 then
        return false, "StarterCatalogUnavailable"
    end
    if profile.Starter.State == "Chosen" or profile.Grants.Starter ~= nil then
        return false, "StarterAlreadyChosen"
    end
    if type(modelId) ~= "string" or table.find(candidates, modelId) == nil then
        return false, "StarterNotCandidate"
    end
    local energy, cosmetics = prepare(modelId)
    if energy == nil or cosmetics == nil then
        return false, "StarterModelMissing"
    end
    local vehicleId = VehicleOwnership.add(profile, {
        ModelId = modelId,
        Origin = "Starter",
        Untransferable = true,
        Synthetic = false,
        EnergyFraction = energy,
        Cosmetics = cosmetics,
    }, now)
    profile.Starter = { State = "Chosen", ModelId = modelId, VehicleId = vehicleId, ChosenAt = now }
    profile.Grants.Starter = { At = now, Ref = vehicleId }
    return true, { VehicleId = vehicleId, ModelId = modelId }
end

return table.freeze(StarterSelection)
