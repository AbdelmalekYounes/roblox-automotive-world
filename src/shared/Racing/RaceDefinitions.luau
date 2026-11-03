--!strict
--[[
    Catégories de compétition (lot 0.6, cahier des charges §6) : les six
    disciplines, les types d'épreuve et les modes, avec leurs règles
    PARAMÉTRABLES. Un seul socle de course (Racing/*) ; chaque discipline n'a
    que ses règles propres ici (départ, arrivée, pénalités, rémunération).

    Toutes les valeurs numériques sont des HYPOTHÈSES DE TRAVAIL réglables (le
    cahier des charges ne fixe aucun barème de course) ; elles ne constituent
    pas un équilibrage final. Le serveur seul les applique.

    Unités : secondes, mètres, km/h quand indiqué, crédits entiers.
]]

local RaceDefinitions = {}

RaceDefinitions.Version = "0.6.0-travail"

export type DisciplineId = "Sprint" | "Circuit" | "TimeTrial" | "Drift" | "Drag" | "Rally"
-- Grid : grille ; Lights : arbre de départ (drag) ; Individual : départs
-- individuels espacés (contre-la-montre, rallye) ; Zone : session en zone (drift).
export type StartKind = "Grid" | "Lights" | "Individual" | "Zone"
-- Official : publique rémunérée ; Ranked : officielle classée ; Private : salon
-- privé (faible rémunération encadrée si éligible) ; Training : entraînement (rien).
export type KindId = "Official" | "Ranked" | "Private" | "Training"
export type ModeId = "Protected" | "Realistic"

export type Discipline = {
    Id: DisciplineId,
    Label: string,
    Start: StartKind,
    -- Classement : par temps officiel (Time) ou par score (Score).
    Ranking: "Time" | "Score",
    -- Échelle classée : "Race" (sprint et circuit, Elo multijoueur), "Drift"
    -- (logique propre, par rapport au score de référence du parcours) ou nil.
    Ladder: string?,
    -- Rémunération : crédits par minute de RÉFÉRENCE du parcours, à performance 1.
    RatePerMin: number,
    -- Coûts estimés du mode réaliste (crédits) par km de course : usure et
    -- réparation probables ; l'énergie est estimée à part (EnergyPerKm).
    WearCostPerKm: number,
    -- Pénalités (secondes) et tolérances.
    FalseStartPenaltyS: number, -- départ anticipé (grille, départ individuel)
    OffCourseGraceS: number, -- sortie de tracé tolérée avant pénalité
    OffCoursePenaltyPerS: number, -- par seconde au-delà de la tolérance
    MissedCheckpointPenaltyS: number?, -- rallye : point manqué = pénalité (nil = retour obligatoire)
    CorridorM: number, -- distance au tracé au-delà de laquelle on est « hors tracé »
    -- Pénalité maximale d'une excursion : un pilote honnête qui sort et revient
    -- n'est jamais disqualifié ; un raccourci ne fait rien gagner, car les
    -- points de contrôle restent obligatoires dans l'ordre.
    OffCoursePenaltyCapS: number,
    LaneDisqualifyS: number?, -- drag : sortie de couloir prolongée = manche invalidée
    FinishWindowS: number, -- après le premier arrivé, délai laissé aux autres
}

local function discipline(d: Discipline): Discipline
    return table.freeze(d)
end

local DISCIPLINES: { [DisciplineId]: Discipline } = {
    Sprint = discipline({
        Id = "Sprint",
        Label = "Sprint",
        Start = "Grid",
        Ranking = "Time",
        Ladder = "Race",
        RatePerMin = 195,
        WearCostPerKm = 30,
        FalseStartPenaltyS = 5,
        OffCourseGraceS = 2,
        OffCoursePenaltyPerS = 2,
        MissedCheckpointPenaltyS = nil,
        CorridorM = 22,
        OffCoursePenaltyCapS = 12,
        LaneDisqualifyS = nil,
        FinishWindowS = 60,
    }),
    Circuit = discipline({
        Id = "Circuit",
        Label = "Circuit",
        Start = "Grid",
        Ranking = "Time",
        Ladder = "Race",
        RatePerMin = 195,
        WearCostPerKm = 35,
        FalseStartPenaltyS = 5,
        OffCourseGraceS = 2,
        OffCoursePenaltyPerS = 2,
        MissedCheckpointPenaltyS = nil,
        CorridorM = 22,
        OffCoursePenaltyCapS = 12,
        LaneDisqualifyS = nil,
        FinishWindowS = 60,
    }),
    TimeTrial = discipline({
        Id = "TimeTrial",
        Label = "Contre-la-montre",
        Start = "Individual",
        Ranking = "Time",
        Ladder = nil,
        RatePerMin = 185,
        WearCostPerKm = 20,
        FalseStartPenaltyS = 5,
        OffCourseGraceS = 2,
        OffCoursePenaltyPerS = 2,
        MissedCheckpointPenaltyS = nil,
        CorridorM = 22,
        OffCoursePenaltyCapS = 12,
        LaneDisqualifyS = nil,
        FinishWindowS = 0,
    }),
    Drift = discipline({
        Id = "Drift",
        Label = "Drift",
        Start = "Zone",
        Ranking = "Score",
        Ladder = "Drift",
        RatePerMin = 190,
        WearCostPerKm = 60,
        FalseStartPenaltyS = 0,
        OffCourseGraceS = 0,
        OffCoursePenaltyPerS = 0,
        MissedCheckpointPenaltyS = nil,
        CorridorM = 0,
        OffCoursePenaltyCapS = 0,
        LaneDisqualifyS = nil,
        FinishWindowS = 0,
    }),
    Drag = discipline({
        Id = "Drag",
        Label = "Drag",
        Start = "Lights",
        Ranking = "Time",
        Ladder = nil,
        RatePerMin = 215,
        WearCostPerKm = 40,
        FalseStartPenaltyS = 0, -- faux départ = manche perdue (feu rouge)
        OffCourseGraceS = 0.5,
        OffCoursePenaltyPerS = 0,
        MissedCheckpointPenaltyS = nil,
        CorridorM = 8,
        OffCoursePenaltyCapS = 0,
        LaneDisqualifyS = 1.5,
        FinishWindowS = 15,
    }),
    Rally = discipline({
        Id = "Rally",
        Label = "Rallye",
        Start = "Individual",
        Ranking = "Time",
        Ladder = nil,
        RatePerMin = 205,
        WearCostPerKm = 55,
        FalseStartPenaltyS = 10,
        OffCourseGraceS = 3,
        OffCoursePenaltyPerS = 1,
        MissedCheckpointPenaltyS = 30,
        CorridorM = 16,
        OffCoursePenaltyCapS = 25,
        LaneDisqualifyS = nil,
        FinishWindowS = 0,
    }),
}
RaceDefinitions.Disciplines = table.freeze(DISCIPLINES)
RaceDefinitions.DisciplineOrder =
    table.freeze({ "Sprint", "Circuit", "TimeTrial", "Drift", "Drag", "Rally" } :: { DisciplineId })

export type Kind = {
    Id: KindId,
    Label: string,
    RewardFactor: number, -- multiplicateur des crédits (0 : aucun)
    Ranked: boolean,
    Records: boolean, -- records éligibles (conditions normalisées obligatoires)
    -- Météo et adhérence standardisées (AUD-WEATHER-01) : toujours (classée),
    -- sur les parcours à records seulement (officielle), jamais (privée,
    -- entraînement : météo dynamique du monde).
    NormalizedConditions: "Always" | "RecordCourses" | "Never",
    Reservation: boolean, -- réservation exclusive du véhicule (AUD-RACE-02)
    OrganizerSettings: boolean, -- l'organisateur règle les paramètres autorisés
    MaxPaidPerHour: number, -- épreuves rémunérées par heure (anti-abus)
}

RaceDefinitions.Kinds = table.freeze({
    Official = table.freeze({
        Id = "Official",
        Label = "Officielle",
        RewardFactor = 1,
        Ranked = false,
        Records = true,
        NormalizedConditions = "RecordCourses",
        Reservation = true,
        OrganizerSettings = false,
        MaxPaidPerHour = 20,
    }),
    Ranked = table.freeze({
        Id = "Ranked",
        Label = "Classée",
        RewardFactor = 1,
        Ranked = true,
        Records = true,
        NormalizedConditions = "Always",
        Reservation = true,
        OrganizerSettings = false,
        MaxPaidPerHour = 20,
    }),
    Private = table.freeze({
        Id = "Private",
        Label = "Privée",
        -- Faible rémunération encadrée, seulement si le salon est éligible.
        RewardFactor = 0.2,
        Ranked = false,
        Records = false,
        NormalizedConditions = "Never",
        Reservation = true,
        OrganizerSettings = true,
        MaxPaidPerHour = 3,
    }),
    Training = table.freeze({
        Id = "Training",
        Label = "Entraînement",
        RewardFactor = 0,
        Ranked = false,
        Records = false,
        NormalizedConditions = "Never",
        -- Aucune conséquence durable (session protégée), aucune récompense :
        -- pas de réservation durable nécessaire, mais l'exemplaire reste bloqué
        -- pour les opérations incompatibles le temps de la session.
        Reservation = true,
        OrganizerSettings = true,
        MaxPaidPerHour = 0,
    }),
} :: { [KindId]: Kind })

RaceDefinitions.Modes = table.freeze({
    Protected = table.freeze({ Id = "Protected", Label = "Protégé" }),
    Realistic = table.freeze({ Id = "Realistic", Label = "Réaliste" }),
} :: { [ModeId]: { Id: ModeId, Label: string } })

-- Paramètres qu'un organisateur de salon privé ou d'entraînement peut régler.
RaceDefinitions.OrganizerLimits = table.freeze({
    Laps = { Min = 1, Max = 10 },
    MaxParticipants = { Min = 1, Max = 12 },
    Modes = { "Protected", "Realistic" },
})

-- Calendrier commun des épreuves (secondes).
RaceDefinitions.Timing = table.freeze({
    LobbyMaxS = 300, -- inscription ouverte au plus 5 min
    AutoStartS = 45, -- départ quand le minimum est atteint, après ce délai
    ReadyCheckS = 20, -- confirmation de disponibilité avant verrouillage
    GridS = 25, -- après le verrouillage : rejoindre sa place sur la grille
    CountdownS = 5, -- compte à rebours final (feux de grille, départs individuels)
    StagingS = 30, -- drag : délai pour se placer en pré-départ
    LightStepS = 0.5, -- drag : intervalle entre les feux orange
    IndividualIntervalS = 20, -- contre-la-montre et rallye : départs espacés
    ReconnectWindowS = 90, -- AUD-RECON-01 : cible d'environ 90 s
    DriftSessionS = 90, -- drift : durée de la session de zone
    MaxRaceS = 1200, -- au-delà, l'épreuve est close (aucun participant bloqué)
})

-- Énergie consommée estimée par km de course, en crédits (≈ 25 L/100 km à
-- 12 crédits/L, barème du lot 0.5) : part du complément brut du mode réaliste.
RaceDefinitions.EnergyCostPerKm = 3

-- Rentabilité : plafond horaire et répétitions dégressives (jamais sous 50 %).
RaceDefinitions.RepeatFactors = table.freeze({ 1, 1, 0.85, 0.7, 0.6, 0.5 })
RaceDefinitions.RepeatWindowS = 3600

-- Récompenses de fin de saison (crédits, configurables) selon le rang final,
-- versées une fois par saison et par échelle si le joueur a assez joué.
RaceDefinitions.SeasonRewards = table.freeze({
    MinRankedRaces = 10,
    ByRank = table.freeze({ 2_000, 5_000, 10_000, 18_000, 30_000 }),
})

function RaceDefinitions.discipline(id: any): Discipline?
    if type(id) ~= "string" then
        return nil
    end
    return (DISCIPLINES :: any)[id]
end

function RaceDefinitions.kind(id: any): Kind?
    if type(id) ~= "string" then
        return nil
    end
    return (RaceDefinitions.Kinds :: any)[id]
end

-- Conditions normalisées pour cette épreuve ? (parcours sans circulation et
-- versionné : RecordEligible, voir RaceCourses).
function RaceDefinitions.normalized(kind: Kind, recordEligible: boolean): boolean
    return kind.NormalizedConditions == "Always" or (kind.NormalizedConditions == "RecordCourses" and recordEligible)
end

function RaceDefinitions.validMode(id: any): boolean
    return id == "Protected" or id == "Realistic"
end

return table.freeze(RaceDefinitions)
