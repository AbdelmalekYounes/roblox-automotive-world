--!strict
--[[
    GPS côté client (lot 0.7) : destination, itinéraire, guidage, recalcul.
    Règles pures : Shared/Navigation/RouteGuide (graphe routier du lot 0.3).

    - Monde ouvert : itinéraire routier selon un profil (routes, tout-terrain) ;
      zone d'essai (sans graphe) : guidage direct.
    - Calcul hors du rendu (tâche séparée), suivi 4 fois par seconde,
      recalcul seulement après une sortie d'itinéraire prolongée et pas plus
      d'une fois toutes les 5 s.
    - Objectif de mission suivi automatiquement (si aucune destination
      choisie par le joueur) ; objectif de course ou point d'inscription sur
      demande. AUCUNE téléportation : le GPS n'indique que le chemin.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local RouteGuide = require(Shared:WaitForChild("Navigation"):WaitForChild("RouteGuide"))
local MapIndex = require(Shared.Navigation.MapIndex)

local GPSController = {}

local S = 1 / Constants.MetersPerStud

export type State = {
    Destination: { X: number, Z: number, Label: string, Source: string }?,
    Plan: RouteGuide.Plan?,
    Progress: RouteGuide.Progress?,
    Status: string, -- "Idle" | "Computing" | "Guiding" | "NoRoute" | "Invalid" | "Arrived"
    Profile: RouteGuide.Profile,
}

local state: State = { Destination = nil, Plan = nil, Progress = nil, Status = "Idle", Profile = "Road" }
local graph: any = nil
local index: MapIndex.Index? = nil
local openWorld = false
local recalc = RouteGuide.newRecalcState(0)
local listeners: { () -> () } = {}
local computing = false
local notifier: (string, string) -> () = function(_k: string, _l: string) end

local function changed()
    for _, listener in listeners do
        task.spawn(listener)
    end
end

function GPSController.onChanged(listener: () -> ())
    table.insert(listeners, listener)
end

function GPSController.setNotifier(fn: (string, string) -> ())
    notifier = fn
end

function GPSController.state(): State
    return state
end

-- Données routières partagées avec la carte (construites une fois, monde ouvert).
function GPSController.mapIndex(): MapIndex.Index?
    return index
end

function GPSController.openWorld(): boolean
    return openWorld
end

local function position(): (number?, number?)
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root.Position.X / S, root.Position.Z / S
    end
    return nil, nil
end

local function compute(reason: string)
    local destination = state.Destination
    local x, z = position()
    if destination == nil or x == nil or z == nil or computing then
        return
    end
    computing = true
    state.Status = "Computing"
    changed()
    task.spawn(function()
        local plan, err
        if openWorld and graph and index then
            plan, err = RouteGuide.plan(
                graph,
                index :: MapIndex.Index,
                x :: number,
                z :: number,
                destination.X,
                destination.Z,
                state.Profile
            )
        else
            plan, err = RouteGuide.direct(x :: number, z :: number, destination.X, destination.Z)
        end
        computing = false
        if state.Destination ~= destination then
            return -- destination remplacée pendant le calcul
        end
        if plan == nil then
            state.Plan = nil
            state.Status = if err == "Invalid" then "Invalid" else "NoRoute"
            notifier(if err == "Invalid" then "gps.invalid" else "gps.noRoute", "Warning")
        else
            state.Plan = plan
            state.Status = "Guiding"
            if reason == "Recalc" then
                notifier("gps.recomputing", "Info")
            end
        end
        changed()
    end)
end

--[[
    Choisit une destination (mètres). `source` : "Player", "Mission", "Race",
    "Poi". Une nouvelle destination remplace l'ancienne.
]]
function GPSController.setDestination(x: number, z: number, label: string, source: string?)
    state.Destination = { X = x, Z = z, Label = label, Source = source or "Player" }
    state.Plan = nil
    state.Progress = nil
    recalc = RouteGuide.newRecalcState(os.clock())
    compute("New")
end

function GPSController.clear()
    state.Destination = nil
    state.Plan = nil
    state.Progress = nil
    state.Status = "Idle"
    changed()
end

function GPSController.setProfile(profile: RouteGuide.Profile)
    state.Profile = profile
    if state.Destination then
        compute("New")
    end
end

-- Objectif de mission : suivi automatique s'il n'y a pas de destination choisie.
function GPSController.missionTarget(point: { X: number, Z: number }?, label: string?)
    local current = state.Destination
    if point == nil then
        if current and current.Source == "Mission" then
            GPSController.clear()
        end
        return
    end
    if current and current.Source ~= "Mission" then
        return
    end
    if current and math.abs(current.X - point.X) < 1 and math.abs(current.Z - point.Z) < 1 then
        return
    end
    GPSController.setDestination(point.X, point.Z, label or "", "Mission")
end

local function track()
    local plan = state.Plan
    local x, z = position()
    if plan == nil or x == nil or z == nil or state.Status ~= "Guiding" then
        return
    end
    local progress =
        RouteGuide.track(plan, x :: number, z :: number, if state.Progress then state.Progress.Hint else nil)
    state.Progress = progress
    if progress.Arrived then
        state.Status = "Arrived"
        notifier("gps.arrived", "Info")
        local source = if state.Destination then state.Destination.Source else ""
        if source ~= "Mission" then
            state.Destination = nil
            state.Plan = nil
        end
    elseif RouteGuide.shouldRecalc(recalc, progress, os.clock()) then
        compute("Recalc")
    end
    changed()
end

function GPSController.start()
    openWorld = ReplicatedStorage:GetAttribute("AutomotiveWorldMode") == "OpenWorld"
    if openWorld then
        -- Construction différée : la conduite démarre sans attendre l'index routier.
        task.defer(function()
            local World = Shared:WaitForChild("World")
            local RoadGraph = require(World:WaitForChild("RoadGraph"))
            graph = RoadGraph.get()
            index = MapIndex.build(graph.Layout)
            changed()
        end)
    end
    local timer = 0
    RunService.Heartbeat:Connect(function(dt)
        timer += dt
        if timer >= 0.25 then
            timer = 0
            track()
        end
    end)
end

return GPSController
