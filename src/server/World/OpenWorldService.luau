--!strict
-- Démarrage du monde ouvert (lot 0.3) : la carte est un modèle généré hors
-- ligne (tools/world/build-world.luau → build/world/OpenWorld.rbxm), inclus dans
-- la place openworld.project.json. Le serveur ne reconstruit AUCUNE pièce de
-- décor au démarrage : il vérifie la version de la carte, relève les plots du
-- parc des prototypes et encadre les apparitions des joueurs.
--
-- Aucune attribution définitive de véhicule : les prototypes du parc restent
-- des véhicules d'essai partagés, comme dans la zone d'essai.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World")
local WorldConfig = require(WorldShared:WaitForChild("WorldConfig"))

local OpenWorldService = {}

-- Parc des prototypes servant de point de départ (seul parc de ce lot).
OpenWorldService.FleetServiceId = "FLEET-METRO"
-- Apparitions actives : celle voisine du parc. Les autres apparitions de la
-- carte existent (Motorsport, Littoral) mais restent désactivées tant qu'aucun
-- véhicule n'y est disponible (sinon le joueur devrait marcher plusieurs km).
OpenWorldService.ActiveSpawns = table.freeze({ "SPAWN-METRO" })

export type OpenWorld = {
    Root: Model,
    Pads: { BasePart },
}

function OpenWorldService.start(): OpenWorld
    local root = Workspace:FindFirstChild("OpenWorld")
    assert(root and root:IsA("Model"), "Carte du monde ouvert absente : lancer tools/world/build-world.luau")
    local version = root:GetAttribute("MapVersion")
    assert(
        version == WorldConfig.MapVersion,
        string.format(
            "Carte générée en version %s, données en %s : régénérer",
            tostring(version),
            WorldConfig.MapVersion
        )
    )

    -- Plots du parc, dans l'ordre de leur numéro.
    local pads: { BasePart } = {}
    for _, slot in CollectionService:GetTagged("AWFleetSlot") do
        local service = slot:FindFirstAncestorWhichIsA("Model")
        if
            slot:IsA("BasePart")
            and slot:IsDescendantOf(root)
            and service
            and service.Name == OpenWorldService.FleetServiceId
        then
            table.insert(pads, slot)
        end
    end
    table.sort(pads, function(a, b)
        return (a:GetAttribute("SlotIndex") :: number) < (b:GetAttribute("SlotIndex") :: number)
    end)
    assert(#pads > 0, "Parc des prototypes introuvable dans la carte")

    -- Apparitions des joueurs : seules celles listées sont actives.
    for _, spawn in root:GetDescendants() do
        if spawn:IsA("SpawnLocation") then
            local service = spawn:FindFirstAncestorWhichIsA("Model")
            spawn.Enabled = service ~= nil and table.find(OpenWorldService.ActiveSpawns, service.Name) ~= nil
        end
    end

    return { Root = root, Pads = pads }
end

return table.freeze(OpenWorldService)
