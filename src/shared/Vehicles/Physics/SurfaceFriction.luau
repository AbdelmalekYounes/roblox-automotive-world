--!strict
-- Multiplicateurs d'adhérence par revêtement (noms de matériaux Roblox).
-- Valeurs provisoires de conception, non mesurées : à calibrer au lot 0.2
-- avec la météo (pluie) prévue au chapitre 2.3 du cahier des charges.

local SurfaceFriction = {}

local BY_MATERIAL: { [string]: number } = {
    Asphalt = 1.0,
    Concrete = 0.95,
    Pavement = 0.95,
    SmoothPlastic = 0.9,
    Plastic = 0.9,
    Brick = 0.85,
    Cobblestone = 0.8,
    Slate = 0.85,
    Rock = 0.8,
    Basalt = 0.8,
    Metal = 0.7,
    DiamondPlate = 0.75,
    CorrodedMetal = 0.7,
    Wood = 0.75,
    WoodPlanks = 0.75,
    Ground = 0.65,
    LeafyGrass = 0.55,
    Grass = 0.55,
    Mud = 0.4,
    Sand = 0.5,
    Sandstone = 0.75,
    Gravel = 0.6,
    Snow = 0.3,
    Glacier = 0.15,
    Ice = 0.12,
    Water = 0.2,
}

SurfaceFriction.Default = 0.9

function SurfaceFriction.forMaterialName(materialName: string): number
    return BY_MATERIAL[materialName] or SurfaceFriction.Default
end

return table.freeze(SurfaceFriction)
