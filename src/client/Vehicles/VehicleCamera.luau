--!strict
-- Caméras du véhicule piloté (cahier des charges §3.4) :
-- - poursuite proche et lointaine (lot 0.1) ;
-- - cockpit, capot et pare-chocs (lot 0.2) : vues solidaires du véhicule,
--   placées sur des attachements que VehicleFactory dérive de la géométrie de
--   chaque modèle (tête du conducteur, avant du capot, bouclier avant).
-- - regard libre (lot CAMERA-01) : dans toutes les vues, le joueur peut
--   regarder autour (clic droit maintenu, stick droit, doigt). Vues
--   embarquées : la « tête » tourne sur place (±120°, −40° à +30°) ; vues de
--   poursuite : orbite autour du véhicule (360°). Retour progressif au centre
--   après relâchement, plus rapide dès 15 km/h (Shared/Vehicles/FreeLook).
--   Le regard est suspendu tant qu'une interface est ouverte ou qu'un texte
--   est saisi : il ne vole ni la souris ni le stick aux fenêtres.
-- Changer de vue ou regarder autour ne touche ni aux commandes ni à la
-- simulation. Le mode photo (§9.3) n'est pas dans ce module.
--
-- Interface prévue pour la 2e vague (mains sur le volant, téléphone tenu en
-- main, portières) — décrite dans docs/lot-camera-01/RAPPORT_CAMERA_01.md :
-- `setLookOverride`, `hasLookOverride`, `setCharacterVisibilityFilter`,
-- `isCockpit`, `lookAngles` (l'instance est donnée par
-- `VehicleController.getCamera()`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local FreeLook = require(VehiclesShared:WaitForChild("FreeLook"))
local FreeLookInput = require(script.Parent.FreeLookInput)
local UIState = require(script.Parent.Parent.UI.UIState)
local UIManager = require(script.Parent.Parent.UI.UIManager)

local VehicleCamera = {}
VehicleCamera.__index = VehicleCamera

export type Preset = {
    Name: string,
    Kind: "Chase" | "Mounted",
    -- Poursuite.
    Distance: number,
    Height: number,
    FocusHeight: number,
    LookAhead: number,
    -- Vue embarquée : attachement du châssis et champ de vision.
    Attachment: string?,
    Fov: number,
}

--[[
    Visée imposée temporairement (2e vague : zoom sur le téléphone tenu en main,
    regard vers une portière…). Tant qu'elle est posée, le regard libre est
    suspendu et la caméra glisse vers `Target()` en `BlendS` secondes ; quand
    elle est retirée, la caméra revient à la vue normale sur la même durée.
    - Target : relu à CHAQUE image (suivre une main, un objet qui bouge) ; nil
      pour cette image = garder la dernière visée connue. Une erreur dans la
      fonction est interceptée (la vue normale est conservée).
    - Fov : champ de vision imposé (degrés), nil = celui de la vue courante.
    - BlendS : durée du fondu (s), défaut 0,35.
]]
export type LookOverride = {
    Target: () -> CFrame?,
    Fov: number?,
    BlendS: number?,
}

-- Filtre d'affichage du personnage en vue cockpit : vrai = la pièce reste
-- VISIBLE pour le conducteur (ex. bras et mains sur le volant, 2e vague).
export type VisibilityFilter = (Instance) -> boolean

local PRESETS: { Preset } = {
    { Name = "Proche", Kind = "Chase", Distance = 13, Height = 4.2, FocusHeight = 2.2, LookAhead = 6, Fov = 70 },
    { Name = "Lointaine", Kind = "Chase", Distance = 22, Height = 7, FocusHeight = 2.5, LookAhead = 8, Fov = 70 },
    {
        Name = "Cockpit",
        Kind = "Mounted",
        Distance = 0,
        Height = 0,
        FocusHeight = 0,
        LookAhead = 0,
        Attachment = "CameraCockpit",
        Fov = 75,
    },
    {
        Name = "Capot",
        Kind = "Mounted",
        Distance = 0,
        Height = 0,
        FocusHeight = 0,
        LookAhead = 0,
        Attachment = "CameraHood",
        Fov = 72,
    },
    {
        Name = "Pare-chocs",
        Kind = "Mounted",
        Distance = 0,
        Height = 0,
        FocusHeight = 0,
        LookAhead = 0,
        Attachment = "CameraBumper",
        Fov = 72,
    },
}

local HEADING_SMOOTHING = 5
local POSITION_SMOOTHING = 14
-- Vue embarquée : léger lissage de l'orientation seulement (pas de retard de position).
local MOUNT_ROTATION_SMOOTHING = 25
-- Orbite : élévation de la caméra au-dessus du point visé bornée par sécurité
-- (le rayon anti-traversée protège ensuite du sol et des murs).
local ORBIT_ELEVATION_MIN = math.rad(-5)
local ORBIT_ELEVATION_MAX = math.rad(80)
local KMH_PER_STUD_S = Constants.MetersPerStud * 3.6

type CameraFields = {
    Camera: Camera,
    Model: Model?,
    Root: BasePart?,
    Character: Model?,
    PresetIndex: number,
    Heading: Vector3,
    Position: Vector3?,
    MountRotation: CFrame?,
    Params: RaycastParams,
    PreviousType: Enum.CameraType,
    PreviousFov: number,
    CharacterHidden: boolean,
    -- Lot CAMERA-01.
    Look: FreeLook.State,
    Input: FreeLookInput.FreeLookInput,
    Mounted: boolean,
    Override: LookOverride?,
    OverrideAlpha: number,
    OverrideCFrame: CFrame?,
    OverrideFov: number?,
    OverrideBlendS: number?,
    VisibilityFilter: VisibilityFilter?,
}

export type VehicleCamera = typeof(setmetatable({} :: CameraFields, VehicleCamera))

function VehicleCamera.new(): VehicleCamera
    local camera = Workspace.CurrentCamera :: Camera
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true
    return setmetatable(
        {
            Camera = camera,
            Model = nil,
            Root = nil,
            Character = nil,
            PresetIndex = 1,
            Heading = Vector3.new(0, 0, -1),
            Position = nil,
            MountRotation = nil,
            Params = params,
            PreviousType = camera.CameraType,
            PreviousFov = camera.FieldOfView,
            CharacterHidden = false,
            Look = FreeLook.newState(),
            Input = FreeLookInput.new(),
            Mounted = false,
            Override = nil,
            OverrideAlpha = 0,
            OverrideCFrame = nil,
            OverrideFov = nil,
            OverrideBlendS = nil,
            VisibilityFilter = nil,
        } :: CameraFields,
        VehicleCamera
    )
end

-- Applique la visibilité LOCALE du personnage (les autres joueurs le voient
-- toujours) : masqué en cockpit, sauf les pièces retenues par le filtre.
local function applyCharacterVisibility(self: VehicleCamera)
    local character = self.Character
    if character == nil then
        return
    end
    local hidden = self.CharacterHidden
    local keep = self.VisibilityFilter
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") or descendant:IsA("Decal") then
            local visible = not hidden or (keep ~= nil and keep(descendant));
            (descendant :: any).LocalTransparencyModifier = if visible then 0 else 1
        end
    end
end

-- En cockpit, le personnage du conducteur masquerait la vue : il est rendu
-- invisible LOCALEMENT.
local function setCharacterHidden(self: VehicleCamera, hidden: boolean)
    if self.CharacterHidden == hidden then
        return
    end
    self.CharacterHidden = hidden
    applyCharacterVisibility(self)
end

function VehicleCamera.start(self: VehicleCamera, model: Model, character: Model?)
    local root = model.PrimaryPart
    if root == nil then
        return
    end
    self.Camera = Workspace.CurrentCamera :: Camera
    self.Model = model
    self.Root = root
    self.Character = character
    self.PreviousType = self.Camera.CameraType
    self.PreviousFov = self.Camera.FieldOfView
    local look = root.CFrame.LookVector
    self.Heading = Vector3.new(look.X, 0, look.Z).Unit
    self.Position = nil
    self.MountRotation = nil
    self.CharacterHidden = false
    self.Params.FilterDescendantsInstances = if character then { model, character } else { model }
    self.Camera.CameraType = Enum.CameraType.Scriptable
    FreeLook.reset(self.Look)
    self.Input:connect()
end

function VehicleCamera.stop(self: VehicleCamera, humanoid: Humanoid?)
    if self.Model == nil then
        return
    end
    -- Souris rendue, regard et visée imposée abandonnés (la conduite s'arrête).
    self.Input:disconnect()
    FreeLook.reset(self.Look)
    self.Override = nil
    self.OverrideAlpha = 0
    self.OverrideCFrame = nil
    setCharacterHidden(self, false)
    self.Model = nil
    self.Root = nil
    self.Character = nil
    self.Camera.CameraType = Enum.CameraType.Custom
    self.Camera.FieldOfView = self.PreviousFov
    if humanoid then
        self.Camera.CameraSubject = humanoid
    end
end

-- Vue suivante ; retourne son nom (affiché par le HUD). Le regard repart droit devant.
function VehicleCamera.togglePreset(self: VehicleCamera): string
    self.PresetIndex = self.PresetIndex % #PRESETS + 1
    self.Position = nil
    self.MountRotation = nil
    FreeLook.reset(self.Look)
    return PRESETS[self.PresetIndex].Name
end

function VehicleCamera.presetName(self: VehicleCamera): string
    return PRESETS[self.PresetIndex].Name
end

function VehicleCamera.presetNames(): { string }
    local names = {}
    for _, preset in PRESETS do
        table.insert(names, preset.Name)
    end
    return names
end

------------------------------------------------------------------------------
-- Interface pour la 2e vague (lot CAMERA-01) : posée et documentée, non
-- utilisée par le jeu dans ce lot.
------------------------------------------------------------------------------

-- Pose (ou retire avec nil) une visée imposée. Une seule à la fois : la
-- dernière posée remplace la précédente. Retirée automatiquement en fin de conduite.
function VehicleCamera.setLookOverride(self: VehicleCamera, override: LookOverride?)
    if override then
        self.OverrideBlendS = override.BlendS
    end
    self.Override = override
end

-- Vrai tant qu'une visée imposée est posée (le fondu de retour peut encore durer).
function VehicleCamera.hasLookOverride(self: VehicleCamera): boolean
    return self.Override ~= nil
end

-- Pièces du personnage gardées visibles en vue cockpit (nil = tout masquer,
-- comportement par défaut). Appliqué aussitôt si la vue cockpit est active.
function VehicleCamera.setCharacterVisibilityFilter(self: VehicleCamera, keep: VisibilityFilter?)
    self.VisibilityFilter = keep
    if self.CharacterHidden then
        applyCharacterVisibility(self)
    end
end

-- Vrai en vue cockpit effective (attachement présent, personnage masqué).
function VehicleCamera.isCockpit(self: VehicleCamera): boolean
    return self.Model ~= nil and self.CharacterHidden
end

-- Regard libre courant, relatif au véhicule (radians) : lacet (positif = à
-- droite) et tangage (positif = vers le haut). (0, 0) = droit devant.
function VehicleCamera.lookAngles(self: VehicleCamera): (number, number)
    return self.Look.Yaw, self.Look.Pitch
end

------------------------------------------------------------------------------
-- Rendu
------------------------------------------------------------------------------

local function mountedAttachment(root: BasePart, preset: Preset): Attachment?
    if preset.Kind ~= "Mounted" then
        return nil
    end
    local attachment = root:FindFirstChild(preset.Attachment :: string)
    if attachment and attachment:IsA("Attachment") then
        return attachment
    end
    return nil
end

local function mountedView(self: VehicleCamera, attachment: Attachment, dt: number): CFrame
    local target = attachment.WorldCFrame
    local rotation = target.Rotation
    local previous = self.MountRotation
    if previous then
        rotation = previous:Lerp(rotation, 1 - math.exp(-MOUNT_ROTATION_SMOOTHING * dt))
    end
    self.MountRotation = rotation
    -- Tête tournée sur place : lacet puis tangage, dans le repère du véhicule.
    local head = CFrame.Angles(0, -self.Look.Yaw, 0) * CFrame.Angles(self.Look.Pitch, 0, 0)
    return CFrame.new(target.Position) * rotation * head
end

local function chaseView(self: VehicleCamera, root: BasePart, preset: Preset, dt: number): CFrame
    local cframe = root.CFrame
    local flatLook = Vector3.new(cframe.LookVector.X, 0, cframe.LookVector.Z)
    if flatLook.Magnitude > 0.2 then
        -- Lissage exponentiel indépendant de la cadence d'image.
        local alpha = 1 - math.exp(-HEADING_SMOOTHING * dt)
        local blended = self.Heading:Lerp(flatLook.Unit, alpha)
        if blended.Magnitude > 1e-3 then
            self.Heading = blended.Unit
        end
    end

    -- Orbite : direction de visée = cap du véhicule tourné du lacet du regard ;
    -- élévation de base (hauteur / distance du préréglage) diminuée du tangage
    -- (regarder vers le haut abaisse la caméra). Regard nul = vue d'origine.
    local direction = CFrame.fromAxisAngle(Vector3.yAxis, -self.Look.Yaw):VectorToWorldSpace(self.Heading)
    local radius = math.sqrt(preset.Distance * preset.Distance + preset.Height * preset.Height)
    local elevation = math.clamp(
        math.atan2(preset.Height, preset.Distance) - self.Look.Pitch,
        ORBIT_ELEVATION_MIN,
        ORBIT_ELEVATION_MAX
    )
    local focus = root.Position + Vector3.new(0, preset.FocusHeight, 0)
    local desired = focus - direction * (radius * math.cos(elevation)) + Vector3.new(0, radius * math.sin(elevation), 0)

    -- Évite que la caméra traverse murs et décors.
    local offset = desired - focus
    local hit = Workspace:Raycast(focus, offset, self.Params)
    if hit then
        desired = hit.Position - offset.Unit * 0.5
    end

    local previous = self.Position
    local position = if previous then previous:Lerp(desired, 1 - math.exp(-POSITION_SMOOTHING * dt)) else desired
    self.Position = position
    return CFrame.lookAt(position, focus + direction * preset.LookAhead)
end

-- Lit les commandes du regard libre et fait avancer son état (limites, retour au centre).
local function updateLook(self: VehicleCamera, dt: number, mounted: boolean, speedKmh: number)
    local limits = if mounted then FreeLook.Limits.Mounted else FreeLook.Limits.Orbit
    if mounted ~= self.Mounted then
        -- Vue embarquée introuvable (repli sur la poursuite) ou retrouvée : limites du nouveau mode.
        self.Mounted = mounted
        FreeLook.clamp(self.Look, limits)
    end
    -- Interface ouverte (téléphone, menus, carte, mode photo…), saisie de texte
    -- ou visée imposée : le regard libre ne lit plus rien et rend la souris.
    local suspended = self.Override ~= nil or UIManager.anyOpen() or UserInputService:GetFocusedTextBox() ~= nil
    self.Input:setSuspended(suspended)
    local cameraPrefs = UIState.prefs().Camera
    local dYaw, dPitch, holding = self.Input:consume(dt, cameraPrefs.Sensitivity, cameraPrefs.InvertY)
    FreeLook.applyDelta(self.Look, dYaw, dPitch, limits)
    FreeLook.step(self.Look, dt, holding, speedKmh)
end

-- Fondu vers / depuis une visée imposée.
local function applyOverride(self: VehicleCamera, base: CFrame, baseFov: number, dt: number): (CFrame, number)
    local override = self.Override
    if override then
        local ok, target = pcall(override.Target)
        if ok and typeof(target) == "CFrame" then
            self.OverrideCFrame = target
            self.OverrideFov = override.Fov
        end
    end
    self.OverrideAlpha = FreeLook.stepBlend(self.OverrideAlpha, override ~= nil, dt, self.OverrideBlendS)
    local target = self.OverrideCFrame
    if self.OverrideAlpha <= 0 or target == nil then
        if override == nil then
            self.OverrideCFrame = nil
        end
        return base, baseFov
    end
    local eased = FreeLook.ease(self.OverrideAlpha)
    local fov = self.OverrideFov or baseFov
    return base:Lerp(target, eased), baseFov + (fov - baseFov) * eased
end

function VehicleCamera.update(self: VehicleCamera, dt: number)
    local root = self.Root
    if root == nil or root.Parent == nil then
        return
    end
    local preset = PRESETS[self.PresetIndex]
    local attachment = mountedAttachment(root, preset)
    local speed = root.AssemblyLinearVelocity.Magnitude
    updateLook(self, dt, attachment ~= nil, speed * KMH_PER_STUD_S)

    local view: CFrame
    local fov: number
    if attachment then
        view = mountedView(self, attachment, dt)
        fov = preset.Fov
        setCharacterHidden(self, preset.Attachment == "CameraCockpit")
    else
        setCharacterHidden(self, false)
        view = chaseView(self, root, preset, dt)
        fov = preset.Fov + math.min(speed * 0.06, 12)
    end
    local finalView, finalFov = applyOverride(self, view, fov, dt)
    self.Camera.FieldOfView = finalFov
    self.Camera.CFrame = finalView
end

return VehicleCamera
