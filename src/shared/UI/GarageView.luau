--!strict
--[[
    Garage V1.2 (lot UI-03, maquette « Garage.dc.html ») : règles de présentation PURES, testables hors Studio.

    Ce module ne décide de rien côté jeu : il met en forme les données RÉELLES de l'instantané du serveur
    (ProgressionService) et des catalogues (définitions, VehicleCatalog, TuningRules). Le serveur revalide toute
    demande ; les disponibilités calculées ici ne servent qu'à griser un bouton et à en donner la raison.

    Textes : chaînes françaises servant de clés de traduction (dictionnaire PanelTexts, Localization.tr).
    Rien n'est inventé : une valeur absente des données n'est pas affichée (ex. 0–100 km/h, description).
]]

local GarageView = {}

GarageView.Tabs =
    table.freeze({ "Collection", "Véhicule", "Propriétés", "Préparation", "Configurations", "Invitations" })
GarageView.PrepTabs = table.freeze({ "Réglages", "Pièces", "Esthétique" })
GarageView.MaxConfigurations = 5

-- Vues de la caméra (degrés, 0 = face avant ; maquette : 3/4 35°, avant 0°, arrière 180°, profil 90°).
GarageView.Views = table.freeze({
    table.freeze({ Id = "ThreeQuarter", Label = "3/4", Angle = 35 }),
    table.freeze({ Id = "Front", Label = "Avant", Angle = 0 }),
    table.freeze({ Id = "Rear", Label = "Arrière", Angle = 180 }),
    table.freeze({ Id = "Side", Label = "Profil", Angle = 90 }),
})
GarageView.DefaultAngle = 35
-- Zoom de la caméra orbitale (molette) : plage de la maquette.
GarageView.ZoomMin = 0.8
GarageView.ZoomMax = 1.4

local ENERGY = { Petrol = "essence", Diesel = "diesel", Electric = "électrique" }
local GEARBOX = {
    Manual = "manuelle",
    Automatic = "automatique",
    DualClutch = "double embrayage",
    Sequential = "séquentielle",
    CVT = "variation continue",
    SingleSpeed = "rapport unique",
}
local LAYOUT = { FWD = "traction", RWD = "propulsion", AWD = "intégrale" }

GarageView.StorageLabels = table.freeze({ Stored = "Rangé", Displayed = "Exposé", Out = "Sorti" })
-- Couleur du badge de rangement (jetons V1.2) : rangé discret, exposé ambre doux, sorti cyan.
GarageView.StorageTokens = table.freeze({ Stored = "TextMuted", Displayed = "AmberSoftText", Out = "GpsCyan" })

-- Onglet suivant / précédent (touches [ ] et PageUp / PageDown, LB / RB) : boucle sur les six onglets.
function GarageView.cycleTab(tab: string, direction: number): string
    local index = table.find(GarageView.Tabs, tab) or 1
    local count = #GarageView.Tabs
    return GarageView.Tabs[((index - 1 + direction) % count) + 1]
end

-- Retour (Retour arrière, bouton B) : Préparation et Configurations reviennent au Véhicule ; les autres onglets à la
-- Collection ; depuis la Collection, nil = fermer le garage.
function GarageView.backTab(tab: string): string?
    if tab == "Préparation" or tab == "Configurations" then
        return "Véhicule"
    elseif tab == "Collection" then
        return nil
    end
    return "Collection"
end

-- Le garage permet les modifications seulement dans une propriété ou un garage public (le serveur le revérifie).
function GarageView.inGarage(context: any): boolean
    local kind = type(context) == "table" and context.Kind or nil
    return kind == "Property" or kind == "PublicGarage"
end

function GarageView.contextLabel(context: any): string
    local kind = type(context) == "table" and context.Kind or nil
    if kind == "Property" then
        return "Propriété · garage privé"
    elseif kind == "PublicGarage" then
        return "Garage public"
    elseif kind == "Visit" then
        return "Visite d'une propriété"
    end
    return "Hors garage · consultation"
end

export type StatusKind = "Pending" | "Confirmed" | "Rejected" | "Offline" | "Info"

-- État affiché d'une réponse du serveur. `nil` (appel échoué) = hors ligne : rien n'est confirmé.
function GarageView.statusKind(status: string?): StatusKind
    if status == "Pending" then
        return "Pending"
    elseif status == "Confirmed" then
        return "Confirmed"
    elseif status == "Rejected" then
        return "Rejected"
    elseif status == nil or status == "Unavailable" then
        return "Offline"
    end
    return "Info"
end

-- Jetons de fond et de texte du bandeau d'état (maquette : en attente ambre, refus et hors ligne rouge, confirmé vert).
function GarageView.statusTokens(kind: StatusKind): (string, string)
    if kind == "Pending" then
        return "AmberSoft", "AmberSoftText"
    elseif kind == "Confirmed" then
        return "OkBg", "OkText"
    elseif kind == "Rejected" or kind == "Offline" then
        return "DangerBg", "DangerText"
    end
    return "Surface1", "TextMuted"
end

local function freeSlot(property: any): number?
    if type(property) ~= "table" then
        return nil
    end
    for slot = 1, property.Capacity or 0 do
        if (property.Slots or {})[tostring(slot)] == nil then
            return slot
        end
    end
    return nil
end
GarageView.freeSlot = freeSlot

export type Action = { Enabled: boolean, Reason: string?, Slot: number?, Kind: string? }

-- Barre d'actions du véhicule (Sortir, Exposer, Ranger). `property` : propriété du contexte, si dans une propriété.
function GarageView.vehicleActions(vehicle: any, snapshot: any, property: any): { [string]: Action }
    local storage = (vehicle and vehicle.Storage) or {}
    local context = (snapshot and snapshot.Context) or {}
    local out = storage.State == "Out"
    local takeOut: Action = if out
        then { Enabled = false, Reason = "Déjà sorti" }
        elseif snapshot and snapshot.OutVehicle ~= nil then {
            Enabled = false,
            Reason = "Un autre véhicule est déjà sorti",
        }
        else { Enabled = true }
    local display: Action
    if context.Kind ~= "Property" or property == nil then
        display = { Enabled = false, Reason = "Exige d'être dans votre propriété" }
    elseif out then
        display = { Enabled = false, Reason = "Déjà sorti" }
    elseif storage.State == "Displayed" then
        display = { Enabled = false, Reason = "Déjà exposé" }
    else
        local slot = freeSlot(property)
        display = if slot then { Enabled = true, Slot = slot } else { Enabled = false, Reason = "Aucune place libre" }
    end
    local store: Action
    if out then
        store = { Enabled = true, Kind = "Return" }
    elseif storage.State == "Displayed" and context.Kind == "Property" then
        store = { Enabled = true, Kind = "Store" }
    elseif storage.State == "Displayed" then
        store = { Enabled = false, Reason = "Exige d'être dans votre propriété" }
    else
        store = { Enabled = false, Reason = "Déjà rangé" }
    end
    return { TakeOut = takeOut, Display = display, Store = store }
end

-- Puissance maximale (kW) : moteur thermique d'après sa courbe de couple (P = C × ω), électrique d'après sa fiche.
function GarageView.peakPowerKw(definition: any): number?
    local powertrain = definition and definition.Powertrain
    if powertrain == nil then
        return nil
    end
    if powertrain.Motor then
        return powertrain.Motor.MaxPowerKw
    end
    local best = nil
    for _, point in (powertrain.Engine and powertrain.Engine.TorqueCurve) or {} do
        local kw = point.TorqueNm * point.Rpm * 2 * math.pi / 60 / 1000
        best = if best == nil then kw else math.max(best, kw)
    end
    return best
end

local function thousands(value: number): string
    local text = tostring(math.floor(value + 0.5))
    local result = string.reverse(text):gsub("(%d%d%d)", "%1 ")
    return (string.reverse(result):gsub("^ ", ""))
end
GarageView.thousands = thousands

local function decimal(value: number, digits: number): string
    return (string.gsub(string.format("%." .. digits .. "f", value), "%.", ","))
end

-- Ligne courte des cartes : énergie · boîte · transmission.
function GarageView.driveLine(definition: any): { string }
    local powertrain = definition.Powertrain
    return {
        ENERGY[powertrain.Energy.Kind] or powertrain.Energy.Kind,
        GEARBOX[powertrain.Transmission.Kind] or powertrain.Transmission.Kind,
        LAYOUT[powertrain.Drivetrain.Layout] or powertrain.Drivetrain.Layout,
    }
end

-- Catégorie : catalogue commercial, sinon prototype technique (P-01 à P-03 n'y figurent pas).
function GarageView.category(definition: any, entry: any): string
    if type(entry) == "table" and type(entry.Category) == "string" then
        return entry.Category
    end
    return if definition and definition.IsTestPrototype then "Prototype technique" else "Hors catalogue"
end

-- Statut de la gamme (maquette : « Proposé · en attente d'approbation »).
function GarageView.availability(definition: any, entry: any): (string?, string?)
    if type(entry) == "table" then
        if entry.Availability == "PendingApproval" or entry.Availability == "Working" then
            return "Proposé · en attente d'approbation",
                "Modèle fictif proposé, achetable en développement seulement (gamme non approuvée)."
        elseif entry.Availability == "Official" then
            return nil, nil
        end
    end
    if definition and definition.IsTestPrototype then
        -- Pas de badge : la catégorie affiche déjà « Prototype technique ».
        return nil, "Prototype technique de développement, hors catalogue commercial."
    end
    return nil, nil
end

export type Spec = { Key: string, Value: string, Unit: string? }

-- Fiche technique : uniquement des valeurs lues dans la définition et le catalogue (aucune mesure inventée).
-- Les valeurs sont des nombres mis en forme ; les mots (énergie, boîte…) sont des clés à traduire.
function GarageView.specs(definition: any, entry: any): { Spec }
    local chassis = definition.Chassis
    local powertrain = definition.Powertrain
    local list: { Spec } = {}
    local function add(key: string, value: string, translate: boolean?)
        table.insert(list, { Key = key, Value = value, Unit = if translate then "tr" else nil })
    end
    local drive = GarageView.driveLine(definition)
    add("Énergie", drive[1], true)
    add("Boîte", drive[2], true)
    add("Transmission", drive[3], true)
    local kw = GarageView.peakPowerKw(definition)
    if kw then
        add("Puissance", string.format("%d kW", math.floor(kw + 0.5)))
    end
    add("Masse", thousands(chassis.MassKg) .. " kg")
    add(
        "L × l × h (emp.) m",
        string.format(
            "%s × %s × %s (%s)",
            decimal(chassis.LengthM, 2),
            decimal(chassis.WidthM, 2),
            decimal(chassis.HeightM, 2),
            decimal(chassis.WheelbaseM, 2)
        )
    )
    local energy = powertrain.Energy
    add(
        "Réservoir / batterie",
        if energy.Kind == "Electric"
            then string.format("%s kWh", decimal(energy.Capacity, 0))
            else string.format("%s L", decimal(energy.Capacity, 0))
    )
    local aids = {}
    if definition.Aids.Abs then
        table.insert(aids, "ABS")
    end
    if definition.Aids.TractionControl then
        table.insert(aids, "TCS")
    end
    if definition.Aids.StabilityControl then
        table.insert(aids, "ESP")
    end
    add("Aides", if #aids > 0 then table.concat(aids, ", ") else "aucune", #aids == 0)
    if type(entry) == "table" and type(entry.Price) == "number" then
        add("Valeur catalogue", thousands(entry.Price) .. " cr")
    end
    return list
end

-- Pas d'un réglage selon son unité (maquette : 50 tr/min, 5 mm, 0,01).
function GarageView.tuningStep(range: any): number
    if range.Unit == "tr/min" then
        return 50
    elseif range.Unit == "m" then
        return 0.005
    end
    return 0.01
end

-- Valeur d'un réglage mise en forme (maquette) : coefficient « 1,05× », hauteur « +0,010 m », régime, pourcentage.
function GarageView.formatTuning(range: any, value: number): string
    if range.Unit == "tr/min" then
        return string.format("%d tr/min", math.floor(value + 0.5))
    elseif range.Unit == "m" then
        return (if value >= 0 then "+" else "") .. decimal(value, 3) .. " m"
    elseif range.Unit == "×" then
        return decimal(value, 2) .. "×"
    end
    return string.format("%d %%", math.floor(value * 100 + 0.5))
end

-- Valeur ramenée sur la grille du pas et dans la plage.
function GarageView.snap(range: any, value: number): number
    local step = GarageView.tuningStep(range)
    local snapped = range.Min + math.floor((value - range.Min) / step + 0.5) * step
    return math.clamp(snapped, range.Min, range.Max)
end

-- Brouillon en cours : un réglage différent de la valeur enregistrée, ou une esthétique différente.
function GarageView.hasDraft(vehicle: any, draftTuning: { [string]: number }, draftCosmetics: any): boolean
    if vehicle == nil then
        return false
    end
    local saved = vehicle.Tuning or {}
    for key, value in draftTuning do
        if saved[key] == nil or math.abs(saved[key] - value) > 1e-9 then
            return true
        end
    end
    if type(draftCosmetics) == "table" then
        local current = vehicle.Cosmetics or {}
        for _, key in { "BodyColor", "AccentColor", "Finish", "Wheels", "ShowLabel" } do
            if draftCosmetics[key] ~= current[key] then
                return true
            end
        end
        for slot, value in draftCosmetics.BodyKit or {} do
            if ((current.BodyKit or {})[slot] or "Stock") ~= value then
                return true
            end
        end
        local a, b = draftCosmetics.Accessories or {}, current.Accessories or {}
        if #a ~= #b then
            return true
        end
        for _, id in a do
            if not table.find(b, id) then
                return true
            end
        end
    end
    return false
end

-- Accessoire ajouté ou retiré, sans dépasser le maximum du catalogue.
function GarageView.toggleAccessory(list: { string }, id: string, max: number): { string }
    local copy = table.clone(list)
    local index = table.find(copy, id)
    if index then
        table.remove(copy, index)
    elseif #copy < max then
        table.insert(copy, id)
    end
    return copy
end

-- Actions d'un emplacement de configuration (1 à 5) : enregistrer à la suite seulement, appliquer et supprimer s'il
-- existe ; tout exige d'être au garage (ou la capacité correspondante).
function GarageView.configActions(
    index: number,
    configurations: { any },
    inGarage: boolean,
    caps: any
): { [string]: Action }
    local exists = configurations[index] ~= nil
    local reason = if inGarage then nil else "Exige une propriété ou un garage public"
    return {
        Save = {
            Enabled = inGarage and index <= #configurations + 1,
            Reason = if not inGarage then reason elseif index > #configurations + 1 then "Remplir dans l'ordre" else nil,
        },
        Apply = {
            Enabled = exists and caps.ApplyConfiguration == true,
            Reason = if not exists then "Emplacement vide" elseif caps.ApplyConfiguration ~= true then reason else nil,
        },
        Delete = {
            Enabled = exists and inGarage,
            Reason = if not exists then "Emplacement vide" else reason,
        },
    }
end

-- Largeur minimale des cartes de la collection (maquette : 300 px, 240 en disposition compacte) et nombre de colonnes.
function GarageView.cardColumns(width: number, compact: boolean, gap: number): (number, number)
    local minimum = if compact then 240 else 300
    local columns = math.max(1, math.floor((width + gap) / (minimum + gap)))
    local cardWidth = math.floor((width - gap * (columns - 1)) / columns)
    return columns, cardWidth
end

return table.freeze(GarageView)
