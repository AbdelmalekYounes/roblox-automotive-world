--!strict
--[[
    Schéma VERSIONNÉ du profil joueur (lot 0.4, §8.2, §8.5, AUD-MIG-01).

    Un seul enregistrement par joueur (clé stable fondée sur le UserId)
    regroupe les données liées : collection de véhicules, pièces, propriétés,
    invitations, attributions uniques et journal récent des transactions. Les
    écritures d'un même joueur sont ainsi atomiques (une seule clé).

    Distinctions imposées (lot 0.4 §5) :
    - modèle du catalogue (ModelId) ≠ exemplaire possédé (Vehicle.Id) ;
    - pièces installées (Vehicle.InstalledParts → exemplaires de Parts) ≠ pièces
      détachées (Parts sans InstalledOn) ;
    - réglages sauvegardés (Tuning, Configurations) ≠ données temporaires de
      conduite (jamais dans le profil, sauf l'état durable : énergie,
      dégâts, kilométrage) ;
    - droits : Untransferable (incessible), Reservation (opération en cours).

    Champs inconnus : conservés tels quels (jamais supprimés en silence).
    Pur : aucune dépendance Roblox, testable par Lune.
]]

local ProfileSchema = {}

ProfileSchema.Version = 1
-- Taille maximale visée d'un enregistrement (le DataStore accepte 4 Mo).
-- Au-delà, les nouvelles acquisitions sont refusées par une limite TECHNIQUE
-- explicite, à arbitrer (§4.2) ; stratégie de fractionnement : rapport du lot.
ProfileSchema.SoftLimitBytes = 3_500_000
ProfileSchema.MaxConfigurations = 5
ProfileSchema.MaxRecentTransactions = 100
ProfileSchema.MaxActiveInvitations = 20

export type StorageState = "Stored" | "Displayed" | "Out"

export type Storage = {
    State: StorageState,
    PropertyId: string?, -- exposé : propriété
    Slot: number?, -- exposé : place
    -- Sorti : session serveur qui a matérialisé le véhicule, et place d'exposition
    -- à retrouver au retour si elle est encore libre.
    Session: string?,
    ReturnProperty: string?,
    ReturnSlot: number?,
}

export type Reservation = { Kind: string, TxId: string, Since: number, ExpiresAt: number }

export type Configuration = {
    Name: string,
    UpdatedAt: number,
    Tuning: { [string]: number },
    Parts: { [string]: string }, -- emplacement → pièce du catalogue (« série » = absent)
    Cosmetics: { [string]: any },
}

export type Damage = {
    Version: number,
    Zones: { [string]: number },
    Engine: number,
    Steering: number,
    SteeringPullSide: number,
    Suspension: { number },
    Impacts: number,
}

export type Vehicle = {
    Schema: number,
    Id: string,
    ModelId: string,
    OwnerUserId: number,
    AcquiredAt: number,
    Origin: string, -- "Starter" | "Purchase" | "Transfer" | "DevSynthetic" | …
    Untransferable: boolean,
    Synthetic: boolean, -- donnée de développement : jamais hors environnement Dev
    OdometerKm: number,
    Energy: number, -- fraction 0..1 de la réserve du modèle
    Damage: Damage,
    InstalledParts: { [string]: string }, -- emplacement → identifiant d'exemplaire de pièce
    Tuning: { [string]: number },
    Cosmetics: { [string]: any },
    Configurations: { Configuration },
    Storage: Storage,
    Reservation: Reservation?,
    UpdatedAt: number,
}

export type PartItem = {
    Id: string,
    PartId: string, -- pièce du catalogue
    AcquiredAt: number,
    Origin: string,
    PaidPrice: number?, -- montant réellement payé (revente 75 %, lot 0.5)
    InstalledOn: string?, -- véhicule ; nil = pièce détachée
    Synthetic: boolean,
}

export type Property = {
    Id: string,
    OfferId: string,
    Category: string,
    AcquiredAt: number,
    Origin: string, -- "FreeStarter" | "Purchase" | "DevSynthetic"
    Sellable: boolean,
    GarageLevel: number,
    Modules: { [string]: { InstalledAt: number } },
    Synthetic: boolean,
}

export type Invitation = {
    Id: string,
    PropertyId: string,
    GuestUserId: number,
    Visit: boolean,
    Drive: boolean,
    CreatedAt: number,
    ExpiresAt: number,
    Revoked: boolean,
}

export type TransactionEntry = { Kind: string, At: number, Result: any }

export type Profile = {
    SchemaVersion: number,
    UserId: number,
    CreatedAt: number,
    UpdatedAt: number,
    Environment: string, -- environnement d'origine (jamais transféré : AUD-ENV-01)
    Counters: { [string]: number },
    -- Attributions uniques (jamais purgées) : propriété gratuite, starter.
    Grants: { [string]: { At: number, Ref: string } },
    Starter: { State: string, ModelId: string?, VehicleId: string?, ChosenAt: number? },
    Vehicles: { [string]: Vehicle },
    Parts: { [string]: PartItem },
    Properties: { [string]: Property },
    Invitations: { [string]: Invitation },
    Transactions: { [string]: TransactionEntry },
}

function ProfileSchema.new(userId: number, now: number, environment: string): Profile
    return {
        SchemaVersion = ProfileSchema.Version,
        UserId = userId,
        CreatedAt = now,
        UpdatedAt = now,
        Environment = environment,
        Counters = { Vehicle = 0, Part = 0, Property = 0, Invitation = 0 },
        Grants = {},
        Starter = { State = "Pending" },
        Vehicles = {},
        Parts = {},
        Properties = {},
        Invitations = {},
        Transactions = {},
    }
end

-- Identifiant unique permanent : préfixe, UserId du premier détenteur et
-- compteur persistant du profil (jamais réutilisé une fois sauvegardé).
function ProfileSchema.nextId(profile: Profile, counter: string, prefix: string): string
    local value = (profile.Counters[counter] or 0) + 1
    profile.Counters[counter] = value
    return string.format("%s-%d-%d", prefix, profile.UserId, value)
end

-- Dégâts neufs (même format que Physics/DamageModel, version 1).
function ProfileSchema.pristineDamage(): Damage
    return {
        Version = 1,
        Zones = { Front = 0, Rear = 0, Left = 0, Right = 0 },
        Engine = 1,
        Steering = 1,
        SteeringPullSide = 0,
        Suspension = { 1, 1, 1, 1 },
        Impacts = 0,
    }
end

local function isInteger(value: any): boolean
    return type(value) == "number" and value == math.floor(value)
end

local function fraction(value: any): boolean
    return type(value) == "number" and value == value and value >= 0 and value <= 1
end

-- Validation structurelle complète ; renvoie la liste des erreurs.
function ProfileSchema.validate(profile: any): (boolean, { string })
    local errors: { string } = {}
    local function check(condition: boolean, message: string)
        if not condition then
            table.insert(errors, message)
        end
    end
    if type(profile) ~= "table" then
        return false, { "ProfileNotTable" }
    end
    check(profile.SchemaVersion == ProfileSchema.Version, "SchemaVersion")
    check(isInteger(profile.UserId) and profile.UserId ~= 0, "UserId")
    for _, key in { "Counters", "Grants", "Starter", "Vehicles", "Parts", "Properties", "Invitations", "Transactions" } do
        check(type(profile[key]) == "table", "Missing:" .. key)
    end
    if #errors > 0 then
        return false, errors
    end
    for id, vehicle in profile.Vehicles do
        local prefix = "Vehicle:" .. tostring(id) .. ":"
        check(type(vehicle) == "table" and vehicle.Id == id, prefix .. "Id")
        if type(vehicle) ~= "table" then
            continue
        end
        check(type(vehicle.ModelId) == "string", prefix .. "ModelId")
        check(vehicle.OwnerUserId == profile.UserId, prefix .. "Owner")
        check(fraction(vehicle.Energy), prefix .. "Energy")
        check(type(vehicle.OdometerKm) == "number" and vehicle.OdometerKm >= 0, prefix .. "Odometer")
        check(
            type(vehicle.Configurations) == "table" and #vehicle.Configurations <= ProfileSchema.MaxConfigurations,
            prefix .. "Configurations"
        )
        local storage = vehicle.Storage
        check(
            type(storage) == "table"
                and (storage.State == "Stored" or storage.State == "Displayed" or storage.State == "Out"),
            prefix .. "Storage"
        )
        if type(storage) == "table" and storage.State == "Displayed" then
            check(
                profile.Properties[storage.PropertyId or ""] ~= nil and isInteger(storage.Slot),
                prefix .. "DisplaySlot"
            )
        end
        for slot, partId in vehicle.InstalledParts or {} do
            local part = profile.Parts[partId]
            check(part ~= nil and part.InstalledOn == id, prefix .. "InstalledPart:" .. tostring(slot))
        end
    end
    -- Une place d'exposition n'accueille qu'un véhicule.
    local occupied: { [string]: string } = {}
    for id, vehicle in profile.Vehicles do
        local storage = vehicle.Storage
        if type(storage) == "table" and storage.State == "Displayed" then
            local key = tostring(storage.PropertyId) .. "#" .. tostring(storage.Slot)
            check(occupied[key] == nil, "SlotTaken:" .. key)
            occupied[key] = id
        end
    end
    -- Une pièce installée l'est sur un seul véhicule, qui la référence.
    for id, part in profile.Parts do
        if part.InstalledOn ~= nil then
            local vehicle = profile.Vehicles[part.InstalledOn]
            local referenced = false
            if vehicle then
                for _, installed in vehicle.InstalledParts do
                    if installed == id then
                        referenced = true
                    end
                end
            end
            check(referenced, "PartOrphan:" .. tostring(id))
        end
    end
    local count = 0
    for _, property in profile.Properties do
        count += 1
        check(
            type(property.OfferId) == "string" and isInteger(property.GarageLevel),
            "Property:" .. tostring(property.Id)
        )
    end
    check(count <= 5, "PropertyLimit")
    return #errors == 0, errors
end

--[[
    Taille approximative de l'enregistrement sérialisé (octets), sans service
    Roblox : sert à refuser proprement une acquisition qui dépasserait la
    limite technique avant toute écriture.
]]
function ProfileSchema.estimateSize(value: any): number
    local kind = type(value)
    if kind == "table" then
        local size = 2
        for key, child in value do
            size += ProfileSchema.estimateSize(key) + ProfileSchema.estimateSize(child) + 2
        end
        return size
    elseif kind == "string" then
        return #value + 2
    elseif kind == "number" then
        return 12
    elseif kind == "boolean" then
        return 5
    end
    return 4
end

return table.freeze(ProfileSchema)
