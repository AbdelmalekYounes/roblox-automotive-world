--!strict
--[[
    Catalogue PUR des pièces mécaniques (§4.3, AUD-ECO-02).

    Une pièce du catalogue est un TYPE ; une pièce possédée est un exemplaire
    du profil (identifiant unique), soit installée sur un véhicule, soit
    détachée. La pièce d'origine (« série ») n'est pas un exemplaire : c'est
    l'absence de pièce installée dans l'emplacement.

    Effets modestes et documentés, appliqués à une COPIE de la définition du
    modèle (TuningRules.apply), puis revalidés. Aucun prix ici (lot 0.5) ;
    les pièces ne s'obtiennent pas encore en jeu (sauf données synthétiques de
    développement).
]]

local PartCatalog = {}

export type Slot = "Tires" | "Brakes" | "Suspension" | "RearDifferential" | "FrontDifferential" | "EngineMap"

local SLOTS: { Slot } = { "Tires", "Brakes", "Suspension", "RearDifferential", "FrontDifferential", "EngineMap" }
PartCatalog.Slots = table.freeze(SLOTS)

export type Part = {
    Id: string,
    Slot: Slot,
    Label: string,
    -- Compatibilité déclarative (vide = tous les modèles).
    Layouts: { string }?, -- architectures de transmission acceptées
    Energies: { string }?, -- énergies acceptées
    -- Effets (multiplicateurs ou valeurs), interprétés par TuningRules.apply.
    Effects: { [string]: number },
    -- Élargit les plages de réglage de l'emplacement (ex. combinés filetés).
    WidensTuning: boolean,
}

local function part(props: Part): Part
    return table.freeze(props)
end

local PARTS: { Part } = {
    part({
        Id = "TIRE-SPORT",
        Slot = "Tires",
        Label = "Pneus sport",
        Effects = { PeakFriction = 1.06, WetGrip = 0.96 },
        WidensTuning = false,
    }),
    part({
        Id = "TIRE-RAIN",
        Slot = "Tires",
        Label = "Pneus pluie",
        Effects = { PeakFriction = 0.97, WetGrip = 1.12 },
        WidensTuning = false,
    }),
    part({
        Id = "BRAKE-SPORT",
        Slot = "Brakes",
        Label = "Freins sport",
        Effects = { BrakeTorque = 1.15 },
        WidensTuning = false,
    }),
    part({
        Id = "SUSP-COILOVER",
        Slot = "Suspension",
        Label = "Combinés filetés",
        Effects = {},
        WidensTuning = true,
    }),
    part({
        Id = "DIFF-LSD-REAR",
        Slot = "RearDifferential",
        Label = "Autobloquant arrière",
        Layouts = { "RWD", "AWD" },
        Effects = { PreloadNm = 50, PowerLockRatio = 0.35, CoastLockRatio = 0.2 },
        WidensTuning = false,
    }),
    part({
        Id = "DIFF-LSD-FRONT",
        Slot = "FrontDifferential",
        Label = "Autobloquant avant",
        Layouts = { "FWD", "AWD" },
        Effects = { PreloadNm = 40, PowerLockRatio = 0.25, CoastLockRatio = 0.1 },
        WidensTuning = false,
    }),
    part({
        Id = "ECU-SPORT",
        Slot = "EngineMap",
        Label = "Cartographie moteur sport",
        Energies = { "Petrol", "Diesel" },
        Effects = { Torque = 1.04 },
        WidensTuning = false,
    }),
}
PartCatalog.Parts = table.freeze(PARTS)

local byId: { [string]: Part } = {}
for _, item in PARTS do
    assert(byId[item.Id] == nil, "pièce dupliquée : " .. item.Id)
    byId[item.Id] = item
end

function PartCatalog.get(id: string): Part?
    return byId[id]
end

-- La pièce convient-elle à ce modèle (définition du lot 0.2) ?
function PartCatalog.compatible(item: Part, definition: any): boolean
    local powertrain = definition.Powertrain
    if item.Layouts and table.find(item.Layouts, powertrain.Drivetrain.Layout) == nil then
        return false
    end
    if item.Energies and table.find(item.Energies, powertrain.Energy.Kind) == nil then
        return false
    end
    return true
end

return table.freeze(PartCatalog)
