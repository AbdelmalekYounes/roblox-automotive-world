--!strict
--[[
    Kits de maillages (lot VEH3D-01) : carrosseries 3D importées, à la place de la carrosserie provisoire.

    EXCEPTION du propriétaire au CLAUDE.md (« aucun emprunt de modèle ») : modèle tiers « 2017 Mclaren 720s »
    (CC BY 4.0, _Sheep19, modifié ; registre docs/vehicle-3d/MODELES_TIERS.md, crédits docs/CREDITS_ACTIFS.md).
    Maillages envoyés sur Roblox par le propriétaire ; le gabarit (`assets/meshkits/*.rbxm`, ServerStorage) est
    cloné par la fabrique. La physique (châssis, roues, forces) est INCHANGÉE : seuls les visuels, les sièges, les
    repères et les boîtes de collision changent.

    Garde-fou : un kit n'est utilisé que si son gabarit est présent et que CHACUN de ses maillages porte un
    identifiant d'actif inscrit au manifeste (`Shared.Assets.AssetManifest`) ; sinon la fabrique garde la
    carrosserie provisoire (aucun identifiant inventé, aucun maillage inconnu).

    Repère : celui du châssis (studs, origine au centre de gravité, avant vers −Z). Valeurs MESURÉES sur le modèle
    (dépôt d'art : `vehicles/wk_comete/renders_720s/finition.json`, export `wk_comete_720s_lod0.json`).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AssetManifest =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"):WaitForChild("AssetManifest"))

local MeshKits = {}

local MeshKitData =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles"):WaitForChild("MeshKitData"))

export type Kit = MeshKitData.Kit
MeshKits.Kits = MeshKitData.Kits
MeshKits.assetNumber = MeshKitData.assetNumber

-- Identifiants autorisés par le manifeste pour un kit.
local function allowed(kit: Kit): { [number]: boolean }
    local set: { [number]: boolean } = {}
    local entry = AssetManifest.get(kit.ManifestId)
    local ids: { number } = {}
    if entry and entry.RobloxAssetIds then
        ids = entry.RobloxAssetIds
    end
    for _, id in ids do
        set[id] = true
    end
    return set
end

-- Gabarit utilisable (présent, tous les maillages autorisés), sinon nil et la raison.
function MeshKits.template(definitionId: string): (Kit?, Model?, string?)
    local kit = MeshKits.Kits[definitionId]
    if kit == nil then
        return nil, nil, "SansKit"
    end
    local folder = ServerStorage:FindFirstChild("AutomotiveWorldMeshKits")
    local template = folder and folder:FindFirstChild(kit.Template)
    if template == nil or not template:IsA("Model") then
        return nil, nil, "GabaritAbsent"
    end
    local ok = allowed(kit)
    local count = 0
    for _, item in template:GetDescendants() do
        if item:IsA("MeshPart") then
            count += 1
            local id = MeshKitData.assetNumber(item.MeshId)
            if id == nil or not ok[id] then
                return nil, nil, "MaillageNonAutorise"
            end
        end
    end
    if count == 0 or template:FindFirstChild(kit.Reference, true) == nil then
        return nil, nil, "GabaritIncomplet"
    end
    return kit, template :: Model, nil
end

local function weld(root: BasePart, part: BasePart)
    local w = Instance.new("WeldConstraint")
    w.Part0 = root
    w.Part1 = part
    w.Parent = part
end

local function visualOnly(part: BasePart)
    part.Anchored = false
    part.Massless = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
end

local function matches(name: string, patterns: { string }): boolean
    for _, p in patterns do
        if string.find(name, p, 1, true) then
            return true
        end
    end
    return false
end

--[[
    Pose la carrosserie 3D : clone du gabarit (pièces de roues exceptées), recalé dans le repère du châssis, soudé et
    sans masse ; vitrage rendu transparent ; boîtes de collision invisibles aux noms des zones ; sources de lumière.
    Rend les pièces de roues (par roue du jeu) pour `attachWheels`.
]]
function MeshKits.build(kit: Kit, template: Model, root: BasePart, body: Instance): { [string]: { BasePart } }
    local copy = template:Clone()
    local reference = copy:FindFirstChild(kit.Reference, true) :: BasePart
    -- Décalage du gabarit : sa pièce de référence doit tomber sur son centre mesuré dans le repère du châssis.
    local shift = reference.Position - kit.ReferenceCenter
    local wheelNames: { [string]: string } = {}
    for wheel, names in kit.Wheels do
        for _, n in names do
            wheelNames[n] = wheel
        end
    end
    local wheels: { [string]: { BasePart } } = {}
    local details = Instance.new("Folder")
    details.Name = "Details"
    details.Parent = body
    for _, item in copy:GetDescendants() do
        if item:IsA("MeshPart") then
            local local_ = CFrame.new(item.Position - shift) * item.CFrame.Rotation
            item.CFrame = root.CFrame * local_
            visualOnly(item)
            if string.find(string.lower(item.Name), kit.GlassPattern, 1, true) then
                -- Import glTF : transparence non reprise (MODELES_TIERS.md §5) ; vitrage sombre, ≥ 0,3.
                item.Material = Enum.Material.Glass
                item.Color = Color3.fromRGB(28, 32, 38)
                item.Transparency = 0.45
            end
            local wheel = wheelNames[item.Name]
            if wheel then
                wheels[wheel] = wheels[wheel] or {}
                table.insert(wheels[wheel], item)
                item.Parent = nil
            else
                weld(root, item)
                item.Parent = if matches(item.Name, kit.DetailPattern) then details else body
            end
        end
    end
    copy:Destroy()
    for name, box in kit.Collisions do
        local part = Instance.new("Part")
        part.Name = name
        part.Size = box.Size
        part.CFrame = root.CFrame * CFrame.new(box.Center)
        part.Transparency = 1
        part.Massless = true
        part.CanCollide = true
        part.CanQuery = true
        part.CanTouch = false
        part.CastShadow = false
        part.Anchored = false
        -- Lue par DamageService : boîte sans visuel, jamais copiée en panneau déformé.
        part:SetAttribute("AWCollisionOnly", true)
        weld(root, part)
        part.Parent = body
    end
    for _, spec in kit.Lights do
        local part = Instance.new("Part")
        part.Name = spec.Name
        part.Size = spec.Size
        part.CFrame = root.CFrame * CFrame.new(spec.Position)
        part.Transparency = 1
        visualOnly(part)
        weld(root, part)
        local light: any = if spec.Light == "Head" then Instance.new("SpotLight") else Instance.new("PointLight")
        light.Name = "Lumiere"
        light.Enabled = false
        light.Brightness = if spec.Light == "Head" then 3 else 1
        light.Range = if spec.Light == "Head" then 40 else 8
        light.Color = if spec.Light == "Head" then Color3.fromRGB(255, 244, 214) else Color3.fromRGB(255, 40, 30)
        if light:IsA("SpotLight") then
            light.Face = Enum.NormalId.Front
            light.Angle = 60
        end
        light.Parent = part
        part:SetAttribute("AWLight", spec.Light)
        part.Parent = body
    end
    return wheels
end

--[[
    Roues : la roue du jeu (pièce animée par Motor6D.Transform) devient invisible ; les pièces du modèle lui sont
    soudées à leur position mesurée (voie du modèle 3,5 à 4,7 cm plus étroite que la physique, décision du
    propriétaire « Garder l'échelle »), et tournent avec elle.
]]
function MeshKits.attachWheels(wheel: BasePart, parts: { BasePart })
    wheel.Transparency = 1
    for _, child in wheel:GetChildren() do
        if child:IsA("BasePart") then
            child:Destroy()
        end
    end
    for _, part in parts do
        visualOnly(part)
        local w = Instance.new("WeldConstraint")
        w.Part0 = wheel
        w.Part1 = part
        w.Parent = part
        part.Parent = wheel
    end
end

return table.freeze(MeshKits)
