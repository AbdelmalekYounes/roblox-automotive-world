--!strict
--[[
    Préférences d'interface du joueur (lot 0.7, §7.1, §7.4), PURES : valeurs
    par défaut, validation et nettoyage. Partagées par le client (affichage)
    et le serveur (sauvegarde dans le profil, schéma 4).

    Seules des préférences DURABLES utiles sont conservées : HUD, mini-carte,
    notifications, accessibilité, langue, audio, graphismes (lot 0.8),
    préférences sociales,
    raccourcis clavier personnalisés et caméra en conduite (lot CAMERA-01 :
    sensibilité, inversion verticale). Rien de temporaire (état d'un menu,
    animation). Le partage de position n'est JAMAIS une préférence durable :
    il est désactivé par défaut à chaque groupe (AUD-PRIV-01).
    Toute valeur reçue du client est nettoyée (bornes, énumérations) ; un
    champ inconnu est ignoré.
]]

local Preferences = {}

-- Version 2 (lot 0.8) : volumes par catégorie, coupure radio, qualité graphique.
-- Les anciennes valeurs « Vehicles » et « World » deviennent Moteur et Environnement.
Preferences.Version = 2
-- Délai minimal entre deux envois du client (le serveur ne fait que marquer
-- le profil « à sauvegarder » : l'écriture suit la sauvegarde périodique).
Preferences.SendIntervalS = 5

export type Hud = {
    Level: "Minimal" | "Standard" | "Full",
    Scale: number, -- %
    Corner: "BottomRight" | "BottomLeft",
    ShowMinimap: boolean,
    MinimapZoom: number, -- 1 (proche) à 4 (large)
    MinimapRotate: boolean,
    DevHud: boolean,
    DrivingInfo: boolean, -- informations de mission ou de course pendant la conduite
}

export type Access = {
    TextScale: number, -- %
    HighContrast: boolean,
    ReduceMotion: boolean,
    PanelOpacity: number, -- %
    NavSensitivity: number, -- 1 à 5 (répétition de la navigation manette)
    ReduceSecondary: boolean,
    VisualAlerts: boolean,
}

export type Prefs = {
    Version: number,
    Language: "fr" | "en",
    Hud: Hud,
    Access: Access,
    Notifications: { Info: boolean, Warning: boolean },
    Audio: {
        Master: number,
        Engine: number,
        Environment: number,
        Interface: number,
        Effects: number,
        Radio: number,
        Voice: number,
        RadioMuted: boolean, -- coupure personnelle de la radio (chaque occupant)
    },
    Graphics: { Quality: "Low" | "Medium" | "High" },
    Social: { ShowSharedMembers: boolean, AcceptInvites: boolean },
    Bindings: { [string]: string }, -- action → touche clavier personnalisée
    -- Lot CAMERA-01 : caméra libre en conduite (sensibilité 1 à 5, inversion verticale).
    Camera: { Sensitivity: number, InvertY: boolean },
}

function Preferences.defaults(): Prefs
    return {
        Version = Preferences.Version,
        Language = "fr",
        Hud = {
            Level = "Standard",
            Scale = 100,
            Corner = "BottomRight",
            ShowMinimap = true,
            MinimapZoom = 2,
            MinimapRotate = true,
            DevHud = false,
            DrivingInfo = true,
        },
        Access = {
            TextScale = 100,
            HighContrast = false,
            ReduceMotion = false,
            PanelOpacity = 92,
            NavSensitivity = 3,
            ReduceSecondary = false,
            VisualAlerts = true,
        },
        Notifications = { Info = true, Warning = true },
        Audio = {
            Master = 100,
            Engine = 100,
            Environment = 90,
            Interface = 80,
            Effects = 100,
            Radio = 70,
            Voice = 100,
            RadioMuted = false,
        },
        Graphics = { Quality = "Medium" },
        Social = { ShowSharedMembers = true, AcceptInvites = true },
        Bindings = {},
        -- Lot CAMERA-01 : un profil existant sans ces champs reçoit ces valeurs (aucune migration).
        Camera = { Sensitivity = 3, InvertY = false },
    }
end

Preferences.Ranges = table.freeze({
    Scale = { 70, 140 },
    MinimapZoom = { 1, 4 },
    TextScale = { 80, 150 },
    PanelOpacity = { 50, 100 },
    NavSensitivity = { 1, 5 },
    Volume = { 0, 100 },
    -- Lot CAMERA-01.
    CameraSensitivity = { 1, 5 },
})

local function number(value: any, fallback: number, range: { number }): number
    if type(value) ~= "number" or value ~= value then
        return fallback
    end
    return math.clamp(math.floor(value + 0.5), range[1], range[2])
end

local function bool(value: any, fallback: boolean): boolean
    if type(value) == "boolean" then
        return value
    end
    return fallback
end

local function enum(value: any, allowed: { string }, fallback: string): any
    if type(value) == "string" and table.find(allowed, value) then
        return value
    end
    return fallback
end

-- Touche acceptée pour un raccourci personnalisé (nom d'un Enum.KeyCode simple).
local function keyName(value: any): boolean
    return type(value) == "string" and #value >= 1 and #value <= 16 and string.match(value, "^%w+$") ~= nil
end

--[[
    Nettoie une valeur quelconque (profil ancien, envoi client) : renvoie des
    préférences complètes et valides, sans champ inconnu.
]]
function Preferences.sanitize(raw: any, knownActions: { string }?): Prefs
    local d = Preferences.defaults()
    local r = Preferences.Ranges
    local source = if type(raw) == "table" then raw else {}
    local hud = if type(source.Hud) == "table" then source.Hud else {}
    local access = if type(source.Access) == "table" then source.Access else {}
    local notifications = if type(source.Notifications) == "table" then source.Notifications else {}
    local audio = if type(source.Audio) == "table" then source.Audio else {}
    local social = if type(source.Social) == "table" then source.Social else {}
    local graphics = if type(source.Graphics) == "table" then source.Graphics else {}
    local cameraPrefs = if type(source.Camera) == "table" then source.Camera else {}
    local bindings: { [string]: string } = {}
    if type(source.Bindings) == "table" then
        local count = 0
        for action, key in source.Bindings do
            if type(action) == "string" and keyName(key) and count < 16 then
                if knownActions == nil or table.find(knownActions, action) then
                    bindings[action] = key
                    count += 1
                end
            end
        end
    end
    return {
        Version = Preferences.Version,
        Language = enum(source.Language, { "fr", "en" }, d.Language),
        Hud = {
            Level = enum(hud.Level, { "Minimal", "Standard", "Full" }, d.Hud.Level),
            Scale = number(hud.Scale, d.Hud.Scale, r.Scale),
            Corner = enum(hud.Corner, { "BottomRight", "BottomLeft" }, d.Hud.Corner),
            ShowMinimap = bool(hud.ShowMinimap, d.Hud.ShowMinimap),
            MinimapZoom = number(hud.MinimapZoom, d.Hud.MinimapZoom, r.MinimapZoom),
            MinimapRotate = bool(hud.MinimapRotate, d.Hud.MinimapRotate),
            DevHud = bool(hud.DevHud, d.Hud.DevHud),
            DrivingInfo = bool(hud.DrivingInfo, d.Hud.DrivingInfo),
        },
        Access = {
            TextScale = number(access.TextScale, d.Access.TextScale, r.TextScale),
            HighContrast = bool(access.HighContrast, d.Access.HighContrast),
            ReduceMotion = bool(access.ReduceMotion, d.Access.ReduceMotion),
            PanelOpacity = number(access.PanelOpacity, d.Access.PanelOpacity, r.PanelOpacity),
            NavSensitivity = number(access.NavSensitivity, d.Access.NavSensitivity, r.NavSensitivity),
            ReduceSecondary = bool(access.ReduceSecondary, d.Access.ReduceSecondary),
            VisualAlerts = bool(access.VisualAlerts, d.Access.VisualAlerts),
        },
        -- Les alertes critiques ne se désactivent pas (AUD-ACCESS-01).
        Notifications = {
            Info = bool(notifications.Info, d.Notifications.Info),
            Warning = bool(notifications.Warning, d.Notifications.Warning),
        },
        Audio = {
            Master = number(audio.Master, d.Audio.Master, r.Volume),
            Engine = number(if audio.Engine ~= nil then audio.Engine else audio.Vehicles, d.Audio.Engine, r.Volume),
            Environment = number(
                if audio.Environment ~= nil then audio.Environment else audio.World,
                d.Audio.Environment,
                r.Volume
            ),
            Interface = number(audio.Interface, d.Audio.Interface, r.Volume),
            Effects = number(audio.Effects, d.Audio.Effects, r.Volume),
            Radio = number(audio.Radio, d.Audio.Radio, r.Volume),
            Voice = number(audio.Voice, d.Audio.Voice, r.Volume),
            RadioMuted = bool(audio.RadioMuted, d.Audio.RadioMuted),
        },
        Graphics = {
            Quality = enum(graphics.Quality, { "Low", "Medium", "High" }, d.Graphics.Quality),
        },
        Social = {
            ShowSharedMembers = bool(social.ShowSharedMembers, d.Social.ShowSharedMembers),
            AcceptInvites = bool(social.AcceptInvites, d.Social.AcceptInvites),
        },
        Bindings = bindings,
        -- Lot CAMERA-01.
        Camera = {
            Sensitivity = number(cameraPrefs.Sensitivity, d.Camera.Sensitivity, r.CameraSensitivity),
            InvertY = bool(cameraPrefs.InvertY, d.Camera.InvertY),
        },
    }
end

-- Égalité de contenu (évite un envoi ou une écriture inutile).
function Preferences.equal(a: any, b: any): boolean
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in a do
        if not Preferences.equal(value, b[key]) then
            return false
        end
    end
    for key in b do
        if a[key] == nil then
            return false
        end
    end
    return true
end

function Preferences.copy(value: any): any
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for key, child in value do
        out[key] = Preferences.copy(child)
    end
    return out
end

return table.freeze(Preferences)
