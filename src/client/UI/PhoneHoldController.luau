--!strict
--[[
    Téléphone tenu en main (lot PHONE-01), côté client. Cœur pur : Shared/UI/PhoneHold.

    1. Bras qui tient le téléphone, pour TOUS les personnages portant l'attribut `AWPhoneRaised`
       (posé par le serveur, InterfaceService) : épaule et coude droits multipliés dans `Transform`
       après l'animation (`PreSimulation`), Motor6D comme AnimationConstraint (QA-A10). La pose assise
       (SeatPoseController, lot ANIM-01) ne touche plus aux bras pendant ce temps. Si l'animation n'a
       pas réécrit `Transform` depuis notre dernière écriture, l'ancien décalage est retiré d'abord
       (pas de cumul). Chaque client applique la même pose : tout le monde voit le bras levé.
    2. Zoom de la caméra sur l'écran du téléphone du joueur local (affichage « en main ») :
       - au volant : visée imposée de la caméra du véhicule (`VehicleCamera:setLookOverride`, CAMERA-01),
         aussi en roulant (décision du propriétaire) ;
       - à pied et passager (caméra Roblox par défaut) : caméra prise en main (`Scriptable`) le temps de
         l'usage, puis rendue à l'endroit qu'elle occupait par rapport au personnage ; à pied, les
         commandes de marche sont suspendues (le personnage s'arrête), rendues au rangement.
       Pendant le zoom, la main, le bras droit et le téléphone restent visibles localement, la tête et
       ses accessoires sont masqués (la caméra passe devant le visage) ; valeurs d'origine rétablies.
    3. `overlay()` donne à PhoneController le rectangle de l'écran dans la vue quand le zoom est arrivé :
       l'interface y est dessinée (calque recalé, net, toutes entrées comme avant).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PhoneHold = require(Shared:WaitForChild("UI"):WaitForChild("PhoneHold"))
local FreeLook = require(Shared:WaitForChild("Vehicles"):WaitForChild("FreeLook"))
local UIState = require(script.Parent.UIState)
local VehicleController = require(script.Parent.Parent:WaitForChild("Vehicles"):WaitForChild("VehicleController"))

local PhoneHoldController = {}

local player = Players.LocalPlayer
local FRAMING = PhoneHold.Framing
local RENDER_NAME = "AWPhoneHold"

-- ======================== 1. Bras (tous les personnages) ========================

type ArmEntry = { Alpha: number, Written: CFrame, Offset: CFrame }
local arms: { [any]: ArmEntry } = {}

local function sameFrame(a: CFrame, b: CFrame): boolean
    return (a.Position - b.Position).Magnitude < 1e-5
        and a.LookVector:Dot(b.LookVector) > 1 - 1e-7
        and a.UpVector:Dot(b.UpVector) > 1 - 1e-7
end

local function updateArms(dt: number)
    for _, other in Players:GetPlayers() do
        local character = other.Character
        if character == nil then
            continue
        end
        local wanted = character:GetAttribute(PhoneHold.Attribute) == true
        for name, partName in PhoneHold.ArmParts do
            local part = character:FindFirstChild(partName)
            local found = part and part:FindFirstChild(name)
            if found == nil or not (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then
                continue
            end
            -- Motor6D ou AnimationConstraint : tous deux exposent `Transform`.
            local joint = found :: any
            local entry = arms[joint]
            if entry == nil and not wanted then
                continue
            end
            local current: ArmEntry = entry or { Alpha = 0, Written = joint.Transform, Offset = CFrame.identity }
            local base: CFrame = joint.Transform
            if entry and sameFrame(base, entry.Written) then
                base = entry.Offset:Inverse() * base
            end
            current.Alpha = math.clamp(current.Alpha + (if wanted then dt else -dt) / PhoneHold.RaiseS, 0, 1)
            current.Offset = PhoneHold.jointOffset(name, FreeLook.ease(current.Alpha))
            current.Written = current.Offset * base
            joint.Transform = current.Written
            if current.Alpha > 0 or wanted then
                arms[joint] = current
            else
                arms[joint] = nil
            end
        end
    end
    for joint in arms do
        if joint.Parent == nil then
            arms[joint] = nil
        end
    end
end

-- ======================== 2. Zoom (joueur local) ========================

local wantOpen = false -- téléphone sorti par le joueur local
local inHand = false -- affichage « en main » demandé
local closer = false -- « + » : écran plus grand
local openedAt = 0
local timedOut = false
local fill = FRAMING.Fill
local alpha = 0 -- avancement du zoom (0 à 1)
local lastView: CFrame? = nil

-- Caméra par défaut prise en main (à pied, passager).
type OwnCamera = { Type: Enum.CameraType, Fov: number, Relative: CFrame?, Root: BasePart?, Absolute: CFrame }
local own: OwnCamera? = nil
local vehicleOverride = false
-- Champ de vision à rétablir si une conduite commence pendant le zoom (la caméra du véhicule mémorise
-- alors notre champ réduit et le rendrait en fin de conduite).
local fovAfterDriving: number? = nil
local wasDriving = false
local frozen = false

local saved: { [Instance]: number } = {}

local function blendS(): number
    return if UIState.prefs().Access.ReduceMotion then FRAMING.ReducedBlendS else FRAMING.BlendS
end

local function phoneScreen(): BasePart?
    local character = player.Character
    local model = character and character:FindFirstChild(PhoneHold.ModelName)
    local screen = model and model:FindFirstChild(PhoneHold.ScreenName, true)
    return if screen and screen:IsA("BasePart") then screen else nil
end

local function currentView(): CFrame?
    local screen = phoneScreen()
    if screen == nil then
        return lastView
    end
    local view = PhoneHold.viewCFrame(screen.CFrame, PhoneHold.viewDistance(PhoneHold.Screen.Height, FRAMING.Fov, fill))
    lastView = view
    return view
end

local function setControls(enabled: boolean)
    local scripts = player:FindFirstChild("PlayerScripts")
    local module = scripts and scripts:FindFirstChild("PlayerModule")
    if module == nil or not module:IsA("ModuleScript") then
        return
    end
    local ok, playerModule = pcall(require, module)
    if not ok then
        return
    end
    pcall(function()
        local controls = (playerModule :: any):GetControls()
        if enabled then
            controls:Enable()
        else
            controls:Disable()
        end
    end)
end

-- Transparence locale : valeur d'origine mémorisée à la première écriture, rétablie à la fin.
local function setLocal(item: Instance, value: number)
    if not (item:IsA("BasePart") or item:IsA("Decal")) then
        return
    end
    local target = item :: any
    if saved[item] == nil then
        saved[item] = target.LocalTransparencyModifier
    end
    target.LocalTransparencyModifier = value
end

local function restoreLocal()
    for item, value in saved do
        if item.Parent then
            (item :: any).LocalTransparencyModifier = value
        end
    end
    table.clear(saved)
end

local function attachedToHead(accessory: Instance, head: Instance): boolean
    local handle = accessory:FindFirstChild("Handle")
    if handle == nil then
        return false
    end
    for _, weld in handle:GetChildren() do
        if weld:IsA("JointInstance") and (weld.Part0 == head or weld.Part1 == head) then
            return true
        end
        if weld:IsA("WeldConstraint") and (weld.Part0 == head or weld.Part1 == head) then
            return true
        end
    end
    return false
end

local function applyVisibility(amount: number)
    local character = player.Character
    if character == nil then
        return
    end
    -- Bras droit et téléphone visibles (même en vue cockpit, où le personnage est masqué).
    for _, name in { "RightUpperArm", "RightLowerArm", "RightHand" } do
        local part = character:FindFirstChild(name)
        if part then
            setLocal(part, 0)
        end
    end
    local model = character:FindFirstChild(PhoneHold.ModelName)
    if model then
        for _, item in model:GetDescendants() do
            setLocal(item, 0)
        end
    end
    -- Tête et accessoires de tête masqués quand la caméra arrive devant le visage.
    local head = character:FindFirstChild("Head")
    if head and amount >= FRAMING.HideHeadAbove then
        setLocal(head, 1)
        for _, item in head:GetDescendants() do
            setLocal(item, 1)
        end
        for _, accessory in character:GetChildren() do
            if accessory:IsA("Accessory") and attachedToHead(accessory, head) then
                for _, item in accessory:GetDescendants() do
                    setLocal(item, 1)
                end
            end
        end
    elseif head and saved[head] ~= nil then
        -- Retour : tête rendue dès la moitié du dézoom.
        local keep: { [Instance]: number } = {}
        for item, value in saved do
            if item == head or item:IsDescendantOf(head) or item:FindFirstAncestorOfClass("Accessory") then
                (item :: any).LocalTransparencyModifier = value
            else
                keep[item] = value
            end
        end
        saved = keep
    end
end

local function rootOf(): BasePart?
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return if root and root:IsA("BasePart") then root else nil
end

local function seated(): boolean
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.SeatPart ~= nil
end

-- Caméra par défaut : prise (mémoire de sa place par rapport au personnage) et rendue.
local function takeOwnCamera(camera: Camera)
    local root = rootOf()
    own = {
        Type = camera.CameraType,
        Fov = camera.FieldOfView,
        Root = root,
        Relative = if root then root.CFrame:ToObjectSpace(camera.CFrame) else nil,
        Absolute = camera.CFrame,
    }
    camera.CameraType = Enum.CameraType.Scriptable
end

local function ownHome(state: OwnCamera): CFrame
    local root = state.Root
    if root and root.Parent and state.Relative then
        return root.CFrame * state.Relative
    end
    return state.Absolute
end

-- `mode` : « Return » (fin du dézoom, caméra reposée à sa place), « Reset » (personnage remplacé, sans
-- fondu) ou « Handover » (une conduite commence : la caméra du véhicule a déjà pris la main, son type n'est
-- pas touché).
local function releaseOwnCamera(camera: Camera, mode: "Return" | "Reset" | "Handover")
    local state = own
    if state == nil then
        return
    end
    own = nil
    if mode == "Handover" then
        return
    end
    if mode == "Return" then
        camera.CFrame = ownHome(state)
    end
    camera.FieldOfView = state.Fov
    -- Jamais rendre « Scriptable » : c'est notre propre réglage (cas d'un enchaînement rapide).
    camera.CameraType = if state.Type == Enum.CameraType.Scriptable then Enum.CameraType.Custom else state.Type
end

local function step(dt: number)
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return
    end
    local driving = VehicleController.isDriving()
    if driving ~= wasDriving then
        if not driving and fovAfterDriving then
            camera.FieldOfView = fovAfterDriving
            fovAfterDriving = nil
        end
        wasDriving = driving
        vehicleOverride = false
    end
    local screen = phoneScreen()
    if wantOpen and inHand and screen == nil and os.clock() - openedAt > FRAMING.ModelTimeoutS then
        timedOut = true
    end
    local wantZoom = wantOpen and inHand and not timedOut and (screen ~= nil or alpha > 0)
    local target = if closer then FRAMING.FillCloser else FRAMING.Fill
    fill += (target - fill) * (1 - math.exp(-12 * dt))

    -- Marche suspendue à pied pendant l'usage en main.
    local freeze = wantOpen and PhoneHold.freezesWalking(inHand and not timedOut, seated())
    if freeze ~= frozen then
        frozen = freeze
        if freeze then
            setControls(false)
        elseif not driving then
            -- Au volant, les commandes par défaut restent coupées par VehicleController (rendues en fin de
            -- conduite) : ne jamais les rendre ici.
            setControls(true)
        end
    end

    if driving then
        if own then
            -- Conduite commencée pendant le zoom (rare) : caméra rendue sans fondu, la caméra du véhicule
            -- prend la suite ; son champ de vision d'origine sera rétabli en fin de conduite.
            fovAfterDriving = own.Fov
            releaseOwnCamera(camera, "Handover")
        end
        local vehicleCamera = VehicleController.getCamera()
        if wantZoom and not vehicleOverride then
            vehicleOverride = true
            vehicleCamera:setLookOverride({
                Target = currentView,
                Fov = FRAMING.Fov,
                BlendS = blendS(),
            })
        elseif not wantZoom and vehicleOverride then
            vehicleOverride = false
            vehicleCamera:setLookOverride(nil)
        end
        -- Avancement estimé du fondu de la caméra du véhicule (même loi que FreeLook.stepBlend).
        alpha = FreeLook.stepBlend(alpha, wantZoom, dt, blendS())
    else
        if wantZoom and own == nil then
            takeOwnCamera(camera)
        end
        local state = own
        if state then
            alpha = FreeLook.stepBlend(alpha, wantZoom, dt, blendS())
            local home = ownHome(state)
            local view = currentView() or home
            local eased = FreeLook.ease(alpha)
            camera.CFrame = home:Lerp(view, eased)
            camera.FieldOfView = state.Fov + (FRAMING.Fov - state.Fov) * eased
            -- Souris libre pour toucher l'écran (vue à la première personne : elle restait bloquée au centre).
            if wantZoom then
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end
            if alpha <= 0 and not wantZoom then
                releaseOwnCamera(camera, "Return")
            end
        else
            alpha = 0
        end
    end

    if alpha > 0 then
        applyVisibility(alpha)
    elseif next(saved) ~= nil then
        restoreLocal()
    end
    if not wantOpen and alpha <= 0 then
        lastView = nil
    end
end

-- ======================== Interface publique ========================

-- Téléphone sorti par le joueur local. `hand` : affichage en main (zoom) ; sinon classique.
function PhoneHoldController.open(hand: boolean)
    if not wantOpen then
        openedAt = os.clock()
        timedOut = false
    end
    wantOpen = true
    inHand = hand
end

-- Rangement : le zoom revient en `BlendS` secondes.
function PhoneHoldController.close()
    wantOpen = false
end

-- Bascule entre l'affichage en main et classique sans ranger le téléphone (réglage changé).
function PhoneHoldController.setInHand(hand: boolean)
    inHand = hand
end

-- « + » : écran plus grand dans la vue.
function PhoneHoldController.setCloser(value: boolean)
    closer = value
end

-- Vrai si le modèle du serveur n'est jamais arrivé (personnage sans main…) : affichage classique.
function PhoneHoldController.failed(): boolean
    return timedOut
end

-- Durée du retour de la caméra (le téléphone est rangé côté serveur après ce délai).
function PhoneHoldController.returnS(): number
    return blendS()
end

-- Rectangle de l'écran dans la vue (px, origine en haut à gauche de la vue) quand le zoom est arrivé.
function PhoneHoldController.overlay(): (Vector2?, Vector2?)
    local camera = Workspace.CurrentCamera
    if not (wantOpen and inHand) or timedOut or alpha < FRAMING.OverlayAt or camera == nil then
        return nil, nil
    end
    if phoneScreen() == nil then
        return nil, nil
    end
    local center, size = PhoneHold.overlayRect(camera.ViewportSize, fill)
    return center, size
end

local started = false
function PhoneHoldController.start()
    if started then
        return
    end
    started = true
    RunService.PreSimulation:Connect(updateArms)
    -- Après la caméra Roblox (priorité Camera) : notre position de caméra et nos transparences gagnent.
    RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, step)
    player.CharacterRemoving:Connect(function()
        -- Personnage remplacé : rien à rétablir sur l'ancien ; caméra rendue sans fondu.
        table.clear(saved)
        local camera = Workspace.CurrentCamera
        if camera and own then
            releaseOwnCamera(camera, "Reset")
        end
        alpha = 0
        lastView = nil
        if frozen then
            frozen = false
            setControls(true)
        end
    end)
end

return PhoneHoldController
