--!strict
--[[
    Session d'un profil sur CE serveur (lot 0.4) : chargement sous verrou,
    migrations, mutations, sauvegardes confirmées et libération. Logique PURE :
    le stockage, l'horloge et les jetons sont injectés (testable par Lune avec
    MemoryProfileRepository, utilisée en jeu par ProfileService).

    États :
    - Active      : profil chargé, verrou détenu, écritures autorisées ;
    - ReadOnly    : profil lisible mais non inscriptible (version plus récente
      que ce serveur, donnée invalide, environnement différent) : aucune
      opération sensible (AUD-DATA-01, AUD-MIG-01) ;
    - Locked      : une autre session détient le verrou (non expiré) ;
    - Unavailable : stockage injoignable : opérations persistantes suspendues ;
    - Lost        : verrou repris par une autre session : ce serveur n'écrit
      plus RIEN (jamais d'écrasement d'un état plus récent) ;
    - Released    : session terminée.

    Durabilité (§8.3) : une transaction sensible n'est « Confirmed » qu'après
    une écriture CONFIRMÉE qui la contient ; sinon elle reste « Pending » et
    une sauvegarde ultérieure la confirmera. Une réponse incertaine du
    stockage est réconciliée par relecture du jeton d'écriture.
]]

local ProfileSchema = require(script.Parent.ProfileSchema)
local ProfileMigration = require(script.Parent.ProfileMigration)
local ProfileSessionLock = require(script.Parent.ProfileSessionLock)
local TransactionService = require(script.Parent.TransactionService)
local StructuredLog = require(script.Parent.StructuredLog)

local ProfileSession = {}
ProfileSession.__index = ProfileSession

export type State = "New" | "Active" | "ReadOnly" | "Locked" | "Unavailable" | "Lost" | "Released"

export type Options = {
    Repository: any, -- ProfileRepository.Repository
    Key: string,
    UserId: number,
    Session: string,
    Server: string,
    Environment: string,
    Clock: () -> number,
    Token: () -> string,
    Log: StructuredLog.Log?,
    LockTtl: number?, -- s, durée de validité d'un verrou sans rafraîchissement
    MinWriteInterval: number?, -- s, écart minimal entre deux écritures (budget par clé)
    AutosaveInterval: number?, -- s
    Migrations: { ProfileMigration.Migration }?,
    -- Préparation d'un profil chargé (normalisation, attributions dues).
    OnLoaded: ((ProfileSchema.Profile, now: number) -> boolean)?,
    -- Suspension des opérations sensibles (incident, AUD-INC-01) : renvoie la
    -- raison ou nil. Les sauvegardes ordinaires continuent.
    Suspended: (() -> string?)?,
}

export type CommitResult = {
    Status: "Confirmed" | "Pending" | "Duplicate" | "Rejected" | "Unavailable",
    Result: any,
    Error: string?,
    -- Vrai si la transaction avait DÉJÀ été appliquée (répétition) : l'appelant
    -- ne doit refaire aucun effet de bord (ex. matérialiser un véhicule).
    Replayed: boolean?,
}

type Fields = {
    Options: Options,
    State: State,
    Data: ProfileSchema.Profile?,
    Generation: number,
    Revision: number, -- incrémenté à chaque mutation locale
    SavedRevision: number, -- dernière révision écrite et confirmée
    LastWriteAt: number,
    Pending: { [string]: number }, -- transaction → révision qui l'a appliquée
    Confirmed: { string }, -- transactions confirmées depuis le dernier relevé
    Detail: string?,
    -- Écriture en cours : UpdateAsync cède la main ; une seconde écriture
    -- simultanée partirait d'une génération périmée et serait refusée.
    Saving: boolean,
}

export type Session = typeof(setmetatable({} :: Fields, ProfileSession))

function ProfileSession.new(options: Options): Session
    return setmetatable({
        Options = options,
        State = "New" :: State,
        Data = nil,
        Generation = 0,
        Revision = 0,
        SavedRevision = 0,
        LastWriteAt = -math.huge,
        Pending = {},
        Confirmed = {},
        Detail = nil,
        Saving = false,
    }, ProfileSession)
end

local function log(self: Session, level: StructuredLog.Level, event: string, fields: { [string]: any }?)
    local sink = self.Options.Log
    if sink then
        local merged: { [string]: any } = { UserId = self.Options.UserId }
        local extra: { [string]: any } = fields or {}
        for key, value in extra do
            merged[key] = value
        end
        sink:write(level, event, merged)
    end
end

local function ttl(self: Session): number
    return self.Options.LockTtl or 300
end

-- Relecture après une réponse incertaine : l'écriture `token` a-t-elle eu lieu ?
local function reconcile(self: Session, token: string): ("Applied" | "NotApplied" | "LockLost" | "Unknown", any)
    local read = self.Options.Repository:read(self.Options.Key)
    if not read.Ok then
        return "Unknown", nil
    end
    local envelope = read.Value
    if envelope and envelope.Meta and envelope.Meta.LastToken == token then
        return "Applied", envelope
    end
    local lock = envelope and envelope.Meta and envelope.Meta.Lock
    if lock and lock.Session == self.Options.Session and envelope.Meta.Generation == self.Generation then
        return "NotApplied", envelope
    end
    return "LockLost", envelope
end

local function adopt(self: Session, data: any, now: number)
    local migrations = ProfileMigration.migrate(data, nil, self.Options.Migrations)
    if migrations.Status == "Newer" then
        self.State = "ReadOnly"
        self.Detail = "SchemaNewer"
        self.Data = data
        log(self, "Warn", "ProfileNewerSchema", { Version = data.SchemaVersion })
        return
    elseif migrations.Status == "Invalid" then
        self.State = "ReadOnly"
        self.Detail = "SchemaInvalid"
        self.Data = nil
        log(self, "Error", "ProfileInvalid", {})
        return
    end
    local profile = migrations.Data :: ProfileSchema.Profile
    local valid, errors = ProfileSchema.validate(profile)
    if not valid then
        self.State = "ReadOnly"
        self.Detail = "ProfileInconsistent"
        self.Data = profile
        log(self, "Error", "ProfileInconsistent", { First = errors[1], Count = #errors })
        return
    end
    if profile.Environment ~= self.Options.Environment then
        -- Aucun transfert de possessions entre environnements (AUD-ENV-01).
        self.State = "ReadOnly"
        self.Detail = "EnvironmentMismatch"
        self.Data = profile
        log(self, "Error", "ProfileEnvironmentMismatch", { Stored = profile.Environment })
        return
    end
    self.Data = profile
    self.State = "Active"
    if migrations.Status == "Migrated" then
        self.Revision += 1
        log(self, "Info", "ProfileMigrated", { Steps = #migrations.Steps, To = profile.SchemaVersion })
    end
    if self.Options.OnLoaded and self.Options.OnLoaded(profile, now) then
        self.Revision += 1
    end
end

--[[
    Chargement : prise du verrou (UpdateAsync), puis migration et validation.
    Renvoie l'état atteint. Un état « Locked » ou « Unavailable » peut être
    retenté par l'appelant après un délai.
]]
function ProfileSession.load(self: Session): State
    local options = self.Options
    local now = options.Clock()
    local token = options.Token()
    local outcome: ProfileSessionLock.Outcome = { Status = "Locked" }
    local result = options.Repository:update(
        options.Key,
        ProfileSessionLock.acquire(options.Session, options.Server, now, ttl(self), token, outcome)
    )
    local envelope: any = nil
    if result.Status == "Ok" then
        envelope = result.Value
    elseif result.Status == "Cancelled" then
        self.State = "Locked"
        local holder = outcome.Holder
        log(self, "Info", "ProfileLocked", { Until = if holder then holder.ExpiresAt else 0 })
        return self.State
    elseif result.Status == "Uncertain" then
        local verdict, read = reconcile(self, token)
        if verdict == "Applied" then
            envelope = read
        else
            self.State = "Unavailable"
            log(self, "Warn", "ProfileLoadUncertain", { Verdict = verdict })
            return self.State
        end
    else
        self.State = "Unavailable"
        log(self, "Warn", "ProfileLoadFailed", { Error = result.Error })
        return self.State
    end

    if outcome.Status == "Recovered" then
        log(self, "Warn", "ProfileLockRecovered", { Previous = if outcome.Holder then outcome.Holder.Server else "" })
    end
    self.Generation = envelope.Meta.Generation
    self.LastWriteAt = now
    if envelope.Data == nil then
        self.Data = ProfileSchema.new(options.UserId, now, options.Environment)
        self.State = "Active"
        self.Revision += 1
        log(self, "Info", "ProfileCreated", {})
        if options.OnLoaded then
            options.OnLoaded(self.Data :: ProfileSchema.Profile, now)
        end
    else
        adopt(self, envelope.Data, now)
    end
    return self.State
end

function ProfileSession.dirty(self: Session): boolean
    return self.Revision ~= self.SavedRevision
end

--[[
    Sauvegarde. `release` libère le verrou (déconnexion, arrêt). Respecte
    l'écart minimal entre deux écritures (budget de requêtes par clé) sauf à
    la libération. Renvoie : "Saved", "Clean", "Throttled", "Failed",
    "Lost", "Released" ou "Skipped".
]]
local saveNow: (Session, boolean?) -> string

function ProfileSession.save(self: Session, release: boolean?): string
    if self.Saving then
        return "Busy"
    end
    self.Saving = true
    local ok, status = pcall(saveNow, self, release)
    self.Saving = false
    if not ok then
        log(self, "Error", "ProfileSaveError", { Error = tostring(status) })
        return "Failed"
    end
    return status
end

function saveNow(self: Session, release: boolean?): string
    local options = self.Options
    local now = options.Clock()
    if self.State == "ReadOnly" and release then
        local outcome: ProfileSessionLock.Outcome = { Status = "LockLost" }
        local result = options.Repository:update(
            options.Key,
            ProfileSessionLock.release(options.Session, now, options.Token(), outcome)
        )
        self.State = "Released"
        return if result.Status == "Ok" then "Released" else "Failed"
    end
    if self.State ~= "Active" then
        return "Skipped"
    end
    if not release and not self:dirty() then
        return "Clean"
    end
    if not release and now - self.LastWriteAt < (options.MinWriteInterval or 6) then
        return "Throttled"
    end
    local token = options.Token()
    local revision = self.Revision
    local snapshot = ProfileMigration.deepCopy(self.Data)
    local outcome: ProfileSessionLock.Outcome = { Status = "LockLost" }
    local result = options.Repository:update(
        options.Key,
        ProfileSessionLock.save(
            options.Session,
            self.Generation,
            snapshot,
            now,
            ttl(self),
            token,
            release == true,
            outcome
        )
    )
    local applied: any = nil
    if result.Status == "Ok" then
        applied = result.Value
    elseif result.Status == "Uncertain" then
        local verdict, read = reconcile(self, token)
        log(self, "Warn", "ProfileSaveUncertain", { Verdict = verdict })
        if verdict == "Applied" then
            applied = read
        elseif verdict == "LockLost" then
            self.State = "Lost"
            log(self, "Error", "ProfileLockLost", {})
            return "Lost"
        else
            return "Failed"
        end
    elseif result.Status == "Cancelled" then
        -- Verrou repris ou génération différente : ce serveur n'écrit plus.
        self.State = "Lost"
        log(self, "Error", "ProfileWriteRefused", { Reason = outcome.Status })
        return "Lost"
    else
        log(self, "Warn", "ProfileSaveFailed", { Error = result.Error })
        return "Failed"
    end

    self.Generation = applied.Meta.Generation
    self.LastWriteAt = now
    self.SavedRevision = revision
    for txId, txRevision in self.Pending do
        if txRevision <= revision then
            self.Pending[txId] = nil
            table.insert(self.Confirmed, txId)
        end
    end
    if release then
        self.State = "Released"
        return "Released"
    end
    return "Saved"
end

-- Transactions confirmées depuis le dernier appel (pour informer les clients).
function ProfileSession.takeConfirmed(self: Session): { string }
    local list = self.Confirmed
    self.Confirmed = {}
    return list
end

function ProfileSession.isPending(self: Session, txId: string): boolean
    return self.Pending[txId] ~= nil
end

--[[
    Mutation NON sensible (kilométrage, état durable) : appliquée en mémoire,
    écrite à la prochaine sauvegarde périodique.
]]
function ProfileSession.mutate(self: Session, mutate: (ProfileSchema.Profile) -> boolean): boolean
    if self.State ~= "Active" or self.Data == nil then
        return false
    end
    if mutate(self.Data :: ProfileSchema.Profile) then
        self.Revision += 1
        return true
    end
    return false
end

-- Mutation SENSIBLE identifiée, idempotente, confirmée par écriture durable.
function ProfileSession.commit(
    self: Session,
    txId: string,
    kind: string,
    mutate: TransactionService.Mutation
): CommitResult
    if self.State ~= "Active" or self.Data == nil then
        return { Status = "Unavailable", Result = nil, Error = "Profile" .. self.State }
    end
    local suspended = self.Options.Suspended and self.Options.Suspended()
    if suspended then
        return { Status = "Unavailable", Result = nil, Error = "WritesSuspended" }
    end
    local data = self.Data :: ProfileSchema.Profile
    local previous = TransactionService.previous(data, txId)
    if previous then
        if self.Pending[txId] then
            return { Status = "Pending", Result = previous.Result, Replayed = true }
        end
        return { Status = "Duplicate", Result = previous.Result, Replayed = true }
    end
    local now = self.Options.Clock()
    local ok, result, updated = TransactionService.apply(data, txId, kind, now, mutate)
    if not ok then
        return { Status = "Rejected", Result = nil, Error = tostring(result) }
    end
    self.Data = updated
    self.Revision += 1
    self.Pending[txId] = self.Revision
    log(self, "Info", "TxApplied", { Tx = txId, Kind = kind })
    local status = self:save()
    if status == "Saved" then
        -- Retirée de la liste des confirmations à notifier : la réponse suffit.
        local index = table.find(self.Confirmed, txId)
        if index then
            table.remove(self.Confirmed, index)
        end
        return { Status = "Confirmed", Result = result }
    end
    return { Status = "Pending", Result = result, Error = status }
end

--[[
    Battement périodique : sauvegarde des transactions en attente dès que le
    budget le permet, sauvegarde périodique des données modifiées, et
    rafraîchissement du verrou avant son échéance.
]]
function ProfileSession.tick(self: Session): string
    if self.State ~= "Active" then
        return "Skipped"
    end
    local now = self.Options.Clock()
    local since = now - self.LastWriteAt
    if next(self.Pending) ~= nil then
        return self:save()
    end
    if self:dirty() and since >= (self.Options.AutosaveInterval or 60) then
        return self:save()
    end
    if since >= ttl(self) / 3 then
        -- Rafraîchissement du verrou (écriture sans changement de données).
        self.Revision += 1
        return self:save()
    end
    return "Idle"
end

return ProfileSession
