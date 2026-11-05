--!strict
--[[
    Groupes côté client (lot 0.7) : vue filtrée reçue du serveur (membres,
    invitations, joueurs présents, canaux), positions partagées par les
    membres qui l'ont accepté, et demandes (créer, inviter, accepter,
    refuser, quitter, exclure, confier la direction, dissoudre, partager sa
    position, proposer une épreuve). Toute décision appartient au serveur.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocialController = {}

local request: RemoteFunction
local view: any = nil
local positions: { any } = {}
local listeners: { () -> () } = {}
local notifier: (string, string, any?) -> () = function(_k: string, _l: string, _p: any?) end
local raceListener: ((string) -> ())? = nil

local function changed()
    for _, listener in listeners do
        task.spawn(listener)
    end
end

function SocialController.onChanged(listener: () -> ())
    table.insert(listeners, listener)
end

function SocialController.setNotifier(fn: (string, string, any?) -> ())
    notifier = fn
end

function SocialController.onRaceSuggested(fn: (string) -> ())
    raceListener = fn
end

function SocialController.view(): any
    return view
end

-- Positions des membres de MON groupe qui partagent (déjà filtrées par le serveur).
function SocialController.positions(): { any }
    return positions
end

function SocialController.send(action: string, payload: any?): any
    local ok, response = pcall(function()
        return request:InvokeServer(action, payload or {})
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = "ServerUnreachable" }
    end
    if response.Status ~= "Ok" then
        notifier(response.Error or "ServerError", "Warning")
    end
    if action == "Snapshot" and response.Result then
        view = response.Result
        changed()
    end
    return response
end

function SocialController.start()
    local folder = ReplicatedStorage:WaitForChild("AWSocial")
    request = folder:WaitForChild("Request") :: RemoteFunction
    local push = folder:WaitForChild("Push") :: RemoteEvent
    push.OnClientEvent:Connect(function(kind: any, data: any)
        if kind == "View" and type(data) == "table" then
            view = data
            changed()
        elseif kind == "Positions" and type(data) == "table" then
            positions = data
        elseif kind == "Notice" and type(data) == "table" and type(data.Key) == "string" then
            notifier(data.Key, "Info", data.Params)
        elseif kind == "RaceSuggested" and type(data) == "table" and raceListener then
            (raceListener :: (string) -> ())(data.CourseId)
        end
    end)
    task.spawn(SocialController.send, "Snapshot")
end

return SocialController
