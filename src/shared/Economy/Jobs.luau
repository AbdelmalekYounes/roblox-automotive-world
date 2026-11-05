--!strict
--[[
    Les huit familles de missions du cahier des charges (§5.2), lot 0.5.

    Paramètres PROVISOIRES et réglables (pas un équilibrage final) :
    - RatePerMin : crédits par minute ESTIMÉE de mission à difficulté 1 et
      qualité parfaite. ~165 crédits/min ≈ 10 000/h, cohérent avec l'ordre de
      grandeur illustratif de 8 000 à 12 000 crédits par heure (§5.1).
    - Vehicle : « Own » (véhicule personnel), « Professional » (véhicule
      professionnel temporaire disponible), « Provided » (véhicule fourni par
      la mission, toujours).
    - Risk : majoration pour cargaisons fragiles ou épreuves exigeantes.
    Le métier « Delivery » accepte toujours un véhicule professionnel : un
    joueur sans crédit ni véhicule personnel a donc toujours une mission
    rémunérée ordinaire (AUD-ECO-01).
]]

local Jobs = {}

export type VehicleRule = "Own" | "Professional" | "Provided"

export type Job = {
    Id: string,
    Label: string,
    Description: string,
    RatePerMin: number,
    Risk: number, -- majoration (0 = aucune)
    Vehicle: VehicleRule,
    ProfessionalModel: string?, -- véhicule technique prêté (jamais possédé)
}

local function job(props: Job): Job
    return table.freeze(props)
end

local JOBS: { Job } = {
    job({
        Id = "Taxi",
        Label = "Taxi / VTC",
        Description = "Prendre un passager, l'emmener à destination ; service premium selon la réputation.",
        RatePerMin = 165,
        Risk = 0,
        Vehicle = "Professional",
        ProfessionalModel = "wk_brio", -- lot VEH3D-02 : la Brio, véhicule de service prêté
    }),
    job({
        Id = "Delivery",
        Label = "Livraison de colis",
        Description = "Récupérer des colis et les livrer dans les temps.",
        RatePerMin = 160,
        Risk = 0,
        Vehicle = "Professional",
        ProfessionalModel = "wk_brio", -- lot VEH3D-02 : la Brio, véhicule de service prêté
    }),
    job({
        Id = "SpecialParts",
        Label = "Transport de pièces spéciales",
        Description = "Cargaison fragile et précieuse : conduite souple exigée.",
        RatePerMin = 160,
        Risk = 0.15,
        Vehicle = "Own",
    }),
    job({
        Id = "Assistance",
        Label = "Assistance routière",
        Description = "Rejoindre un automobiliste immobilisé et intervenir sur place.",
        RatePerMin = 165,
        Risk = 0.05,
        Vehicle = "Own",
    }),
    job({
        Id = "Convoy",
        Label = "Voiturier et convoyage",
        Description = "Déplacer un véhicule confié jusqu'à sa place, sans l'abîmer.",
        RatePerMin = 160,
        Risk = 0.1,
        Vehicle = "Provided",
        ProfessionalModel = "wk_brio", -- lot VEH3D-02 : la Brio, véhicule de service prêté
    }),
    job({
        Id = "Precision",
        Label = "Stationnement et slalom",
        Description = "Portes à franchir, plots à éviter, créneau final précis.",
        RatePerMin = 170,
        Risk = 0.05,
        Vehicle = "Own",
    }),
    job({
        Id = "Exploration",
        Label = "Exploration tout-terrain",
        Description = "Rejoindre des points d'exploration par les chemins et la montagne.",
        RatePerMin = 160,
        Risk = 0.1,
        Vehicle = "Own",
    }),
    job({
        Id = "Testing",
        Label = "Essais automobiles",
        Description = "Mesures d'accélération et de freinage sur un véhicule d'essai fourni.",
        RatePerMin = 165,
        Risk = 0.1,
        Vehicle = "Provided",
        ProfessionalModel = "wk_brio", -- lot VEH3D-02 : la Brio, véhicule de service prêté
    }),
}
Jobs.List = table.freeze(JOBS)

local byId: { [string]: Job } = {}
for _, item in JOBS do
    byId[item.Id] = item
end

function Jobs.get(id: string): Job?
    return byId[id]
end

-- Métiers accessibles sans aucun véhicule personnel (AUD-ECO-01).
function Jobs.withoutPersonalVehicle(): { Job }
    local list = {}
    for _, item in JOBS do
        if item.Vehicle ~= "Own" then
            table.insert(list, item)
        end
    end
    return list
end

return table.freeze(Jobs)
