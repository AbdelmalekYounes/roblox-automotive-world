--!strict
--[[
    Données SYNTHÉTIQUES de développement (lot 0.4, AUD-ENV-01).

    Uniquement dans l'environnement Dev (stockage mémoire, rien n'est
    persisté) : le service ne l'appelle que si Environment.allowsSynthetic.
    Donne de quoi éprouver les garages et la préparation : les trois
    prototypes d'essai (exemplaires « DevSynthetic », incessibles, marqués
    synthétiques : ce ne sont PAS des voitures de départ), une propriété
    moyenne et une pièce de chaque type. Attribution unique (Grants.DevSeed),
    à exécuter dans la transaction d'identifiant fixe TxId.
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local VehicleOwnership = require(script.Parent.VehicleOwnership)
local PropertyRules = require(script.Parent.PropertyRules)
local Wallet = require(script.Parent.Parent.Economy.Wallet)

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local PartCatalog = require(Shared.Garage.PartCatalog)
local CosmeticCatalog = require(Shared.Garage.CosmeticCatalog)

local DevSeed = {}

DevSeed.TxId = "Grant:DevSeed"
-- Lot BASE-01 (point P2) : aucun véhicule synthétique ; propriété, pièces et solde de développement restent.
DevSeed.Models = table.freeze({}) :: { string }
DevSeed.PropertyOffer = "RES-METRO-LOFTS"
-- Lot BASE-01 : 250 000 (au lieu de 150 000) pour pouvoir acheter le seul modèle du jeu, la Comète (185 000), en
-- développement, maintenant qu'aucun véhicule synthétique n'est donné.
DevSeed.SyntheticBalance = 250_000

function DevSeed.apply(profile: ProfileSchema.Profile, now: number, lookup: (string) -> any): (boolean, any)
    if profile.Grants.DevSeed ~= nil then
        return false, "DevSeedAlreadyApplied"
    end
    local vehicles = 0
    for _, modelId in DevSeed.Models do
        local definition = lookup(modelId)
        if definition then
            VehicleOwnership.add(profile, {
                ModelId = modelId,
                Origin = "DevSynthetic",
                Untransferable = true,
                Synthetic = true,
                EnergyFraction = definition.Powertrain.Energy.InitialFraction,
                Cosmetics = CosmeticCatalog.defaults(definition),
            }, now)
            vehicles += 1
        end
    end
    PropertyRules.acquire(profile, DevSeed.PropertyOffer, "DevSynthetic", true, now)
    for _, part in PartCatalog.Parts do
        local id = ProfileSchema.nextId(profile, "Part", "PT")
        profile.Parts[id] = {
            Id = id,
            PartId = part.Id,
            AcquiredAt = now,
            Origin = "DevSynthetic",
            Synthetic = true,
        }
    end
    -- Lot 0.5 : crédits SYNTHÉTIQUES pour éprouver l'économie (Dev, mémoire seulement).
    Wallet.credit(profile, DevSeed.SyntheticBalance, "DevSynthetic", "dev-seed", now)
    profile.Grants.DevSeed = { At = now, Ref = "synthetic" }
    return true, { Vehicles = vehicles }
end

return table.freeze(DevSeed)
