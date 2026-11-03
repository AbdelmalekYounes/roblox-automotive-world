--!strict
--[[
    Invitations de visite (§4.4, AUD-SOC-01, AUD-PERM-01, AUD-PRIV-01),
    règles PURES.

    - Invitation INDIVIDUELLE : une propriété, un joueur (UserId vérifié par le
      serveur : jamais un nom saisi), une échéance.
    - Droits séparés : Visit (entrer) et Drive (conduire l'exemplaire sorti du
      propriétaire). Aucun droit de modification ; aucun accès aux données
      économiques ni au profil.
    - Révocation : immédiate pour toute nouvelle action ; l'usage en cours est
      arrêté en état sûr par le service (sortie de la propriété, véhicule
      immobilisé), sans perte d'actif.
    - Interface prévue pour les groupes (lot 0.7) : `PermissionSource`. Seule
      la source « Invitation » existe dans ce lot.
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)

local InvitationRules = {}

InvitationRules.MinDurationS = 5 * 60
InvitationRules.MaxDurationS = 24 * 3600

export type Right = "Visit" | "Drive"

-- Source de permissions (invitations aujourd'hui, groupes au lot 0.7).
export type PermissionSource = {
    Name: string,
    allows: (
        ownerProfile: ProfileSchema.Profile,
        propertyId: string?,
        guestUserId: number,
        right: Right,
        now: number
    ) -> boolean,
}

local function active(invitation: ProfileSchema.Invitation, now: number): boolean
    return not invitation.Revoked and invitation.ExpiresAt > now
end
InvitationRules.active = active

function InvitationRules.activeCount(profile: ProfileSchema.Profile, now: number): number
    local count = 0
    for _, invitation in profile.Invitations do
        if active(invitation, now) then
            count += 1
        end
    end
    return count
end

function InvitationRules.create(
    profile: ProfileSchema.Profile,
    propertyId: any,
    guestUserId: any,
    visit: any,
    drive: any,
    duration: any,
    now: number
): (boolean, any)
    if type(propertyId) ~= "string" or profile.Properties[propertyId] == nil then
        return false, "PropertyNotOwned"
    end
    -- Identifiant entier non nul (les joueurs des sessions de test de Studio ont
    -- des UserId négatifs) ; la présence réelle du joueur est vérifiée par le service.
    if type(guestUserId) ~= "number" or guestUserId ~= math.floor(guestUserId) or guestUserId == 0 then
        return false, "InviteGuestInvalid"
    end
    if guestUserId == profile.UserId then
        return false, "InviteSelf"
    end
    if type(visit) ~= "boolean" or type(drive) ~= "boolean" or not (visit or drive) then
        return false, "InviteRights"
    end
    if
        type(duration) ~= "number"
        or duration < InvitationRules.MinDurationS
        or duration > InvitationRules.MaxDurationS
    then
        return false, "InviteDuration"
    end
    if InvitationRules.activeCount(profile, now) >= ProfileSchema.MaxActiveInvitations then
        return false, "InviteLimit"
    end
    -- Purge des invitations échues (bornage du profil, sans effet sur les droits).
    for id, invitation in profile.Invitations do
        if not active(invitation, now) then
            profile.Invitations[id] = nil
        end
    end
    local id = ProfileSchema.nextId(profile, "Invitation", "I")
    profile.Invitations[id] = {
        Id = id,
        PropertyId = propertyId,
        GuestUserId = guestUserId,
        Visit = visit,
        Drive = drive,
        CreatedAt = now,
        ExpiresAt = now + duration,
        Revoked = false,
    }
    return true, { InvitationId = id, ExpiresAt = now + duration }
end

function InvitationRules.revoke(profile: ProfileSchema.Profile, invitationId: any): (boolean, any)
    local invitation = if type(invitationId) == "string" then profile.Invitations[invitationId] else nil
    if invitation == nil then
        return false, "InviteUnknown"
    end
    invitation.Revoked = true
    return true, { InvitationId = invitation.Id, GuestUserId = invitation.GuestUserId }
end

--[[
    Le visiteur `guestUserId` a-t-il le droit `right` ? Pour Visit, sur la
    propriété donnée ; pour Drive, sur n'importe quelle propriété du
    propriétaire (prêt d'usage de l'exemplaire sorti).
]]
function InvitationRules.allows(
    owner: ProfileSchema.Profile,
    propertyId: string?,
    guestUserId: number,
    right: Right,
    now: number
): boolean
    if guestUserId == owner.UserId then
        return true
    end
    for _, invitation in owner.Invitations do
        if invitation.GuestUserId == guestUserId and active(invitation, now) then
            if right == "Visit" and invitation.Visit and invitation.PropertyId == propertyId then
                return true
            elseif right == "Drive" and invitation.Drive then
                return true
            end
        end
    end
    return false
end

InvitationRules.InvitationSource = table.freeze({
    Name = "Invitation",
    allows = InvitationRules.allows,
}) :: PermissionSource

-- Groupes (lot 0.7) : non implémentés, n'accordent rien.
InvitationRules.GroupSource = table.freeze({
    Name = "Group",
    allows = function(): boolean
        return false
    end,
}) :: PermissionSource

-- Combinaison des sources (un seul « oui » suffit ; chaque source est indépendante).
function InvitationRules.check(
    sources: { PermissionSource },
    owner: ProfileSchema.Profile,
    propertyId: string?,
    guestUserId: number,
    right: Right,
    now: number
): boolean
    for _, source in sources do
        if source.allows(owner, propertyId, guestUserId, right, now) then
            return true
        end
    end
    return false
end

return table.freeze(InvitationRules)
