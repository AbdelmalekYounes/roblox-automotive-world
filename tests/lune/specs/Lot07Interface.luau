--!strict
-- Lot 0.7 — interface, GPS, smartphone et social : règles PURES (itinéraires,
-- guidage, projection, points d'intérêt, pile d'écrans, focus, conduite,
-- raccourcis, confirmations, notifications, groupes, confidentialité,
-- localisation, préférences). Ne valide PAS l'affichage réel, la navigation
-- avec trafic et streaming, ni les essais humains (NON TESTÉ, QA_BACKLOG).

local SERVER = "ServerScriptService.AutomotiveWorldServer."
local SHARED = "ReplicatedStorage.Shared."

return function(T: any, H: any)
    local RouteGuide = H.require(SHARED .. "Navigation.RouteGuide")
    local MapIndex = H.require(SHARED .. "Navigation.MapIndex")
    local MapProjection = H.require(SHARED .. "Navigation.MapProjection")
    local RoadGraph = H.require(SHARED .. "World.RoadGraph")
    local WorldLayout = H.require(SHARED .. "World.WorldLayout")
    local UIStack = H.require(SHARED .. "UI.UIStack")
    local DrivingGate = H.require(SHARED .. "UI.DrivingGate")
    local InputMap = H.require(SHARED .. "UI.InputMap")
    local NotificationQueue = H.require(SHARED .. "UI.NotificationQueue")
    local Preferences = H.require(SHARED .. "UI.Preferences")
    local Localization = H.require(SHARED .. "UI.Localization")
    local PropertyCatalog = H.require(SHARED .. "Garage.PropertyCatalog")
    local RaceCourses = H.require(SHARED .. "Racing.RaceCourses")
    local GroupRules = H.require(SERVER .. "Social.GroupRules")
    local PointsOfInterest = H.require(SERVER .. "Social.PointsOfInterest")
    local RaceCourse = H.require(SERVER .. "Racing.RaceCourse")
    local ProfileSchema = H.require(SERVER .. "Persistence.ProfileSchema")
    local ProfileMigration = H.require(SERVER .. "Persistence.ProfileMigration")
    local InputArbiter = H.require("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.InputArbiter")

    -- Sérialisation simple (recherche d'une valeur dans une vue).
    local function dump(value: any): string
        if type(value) ~= "table" then
            return tostring(value)
        end
        local parts = {}
        for key, child in value do
            table.insert(parts, tostring(key) .. "=" .. dump(child))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end

    local graph = RoadGraph.get()
    local index = MapIndex.build(graph.Layout)
    local nodes = graph.Layout.Network.NodeById

    T.suite("Lot 0.7 — GPS et itinéraires")

    T.test("calcul d'itinéraire routier : longueur, durée, manœuvres, routes autorisées", function()
        -- Place Centrale → Port-Soleil (littoral), plusieurs kilomètres.
        local from, to = nodes["O"], nodes["L0"]
        local plan, err = RouteGuide.plan(graph, index, from.X + 5, from.Z + 5, to.X, to.Z, "Road")
        T.truthy(plan ~= nil, tostring(err))
        local straight = math.sqrt((to.X - from.X) ^ 2 + (to.Z - from.Z) ^ 2)
        T.truthy(plan.LengthM >= straight * 0.98, "pas plus court que la ligne droite")
        T.truthy(plan.LengthM < straight * 2.5, "itinéraire raisonnable : " .. math.floor(plan.LengthM))
        T.truthy(plan.TimeS > 0 and plan.TimeS < 3600, "durée estimée")
        T.equal(plan.Maneuvers[#plan.Maneuvers].Kind, "Arrive", "arrivée en dernier")
        T.truthy(#plan.Maneuvers >= 2, "au moins une manœuvre avant l'arrivée")
        local previous = -1
        for _, maneuver in plan.Maneuvers do
            T.truthy(maneuver.Along >= previous, "manœuvres ordonnées")
            previous = maneuver.Along
        end
        -- Profil « routes » : aucun chemin ni piste n'est emprunté.
        T.truthy(
            not RouteGuide.allowsClass("Road", "Chemin") and not RouteGuide.allowsClass("Road", "Piste"),
            "restrictions"
        )
        T.truthy(RouteGuide.allowsClass("AllTerrain", "Chemin"), "tout-terrain : chemins autorisés")
        T.note(
            string.format(
                "Itinéraire Place Centrale → Port-Soleil : %.1f km, %d min, %d manœuvres",
                plan.LengthM / 1000,
                math.ceil(plan.TimeS / 60),
                #plan.Maneuvers
            )
        )
    end)

    T.test("destination de mission à plusieurs km : trouvée et guidée", function()
        local from, to = nodes["MS_P"], nodes["M_COL"]
        local plan = RouteGuide.plan(graph, index, from.X, from.Z, to.X, to.Z, "Road")
        T.truthy(
            plan ~= nil and plan.LengthM > 5000,
            "itinéraire de " .. (if plan then math.floor(plan.LengthM) else 0) .. " m"
        )
        local progress = RouteGuide.track(plan, from.X, from.Z, nil)
        T.truthy(progress.Next ~= nil and progress.ToNextM >= 0, "prochaine manœuvre")
        T.near(progress.RemainingM, plan.LengthM, 30, "distance restante au départ")
    end)

    T.test("recalcul limité, destinations invalides, arrivée", function()
        local _, invalid = RouteGuide.plan(graph, index, 0, 0, 0 / 0, 10, "Road")
        T.equal(invalid, "Invalid", "NaN refusé")
        local _, far = RouteGuide.plan(graph, index, 0, 0, 90000, 0, "Road")
        T.equal(far, "Invalid", "hors carte refusé")
        local from, to = nodes["O"], nodes["C_E"]
        local plan = RouteGuide.plan(graph, index, from.X, from.Z, to.X, to.Z, "Road")
        local state = RouteGuide.newRecalcState(0)
        local off = RouteGuide.track(plan, from.X + 200, from.Z + 200, nil)
        T.truthy(off.OffRouteM > RouteGuide.OffRouteM, "hors itinéraire détecté")
        T.truthy(not RouteGuide.shouldRecalc(state, off, 10), "pas de recalcul immédiat")
        T.truthy(not RouteGuide.shouldRecalc(state, off, 11), "pas avant la tolérance")
        T.truthy(RouteGuide.shouldRecalc(state, off, 13.5), "recalcul après 3 s hors itinéraire")
        T.truthy(not RouteGuide.shouldRecalc(state, off, 14), "pas de recalcul en rafale")
        local on = RouteGuide.track(plan, from.X, from.Z, nil)
        T.truthy(not RouteGuide.shouldRecalc(state, on, 30), "sur l'itinéraire : rien")
        local arrived = RouteGuide.track(plan, to.X, to.Z, nil)
        T.truthy(arrived.Arrived, "arrivée détectée")
        local direct = RouteGuide.direct(0, 0, 30, 40)
        T.near(direct.LengthM, 50, 1e-6, "guidage direct (zone d'essai)")
    end)

    T.test("conversion monde ↔ carte : aller-retour, véhicule vers le haut, bord", function()
        local view = MapProjection.view(100, -200, 0.5, math.rad(30), 200, 200)
        for _, p in { { 100, -200 }, { 160, -150 }, { -40, -400 } } do
            local u, v = MapProjection.toMap(view, p[1], p[2])
            local x, z = MapProjection.toWorld(view, u, v)
            T.near(x, p[1], 1e-6, "x")
            T.near(z, p[2], 1e-6, "z")
        end
        -- Un point devant le véhicule (cap 30°) est au-dessus du centre.
        local h = math.rad(30)
        local u, v = MapProjection.toMap(view, 100 + math.sin(h) * 50, -200 - math.cos(h) * 50)
        T.near(u, 100, 1e-6, "aligné")
        T.truthy(v < 100, "devant = en haut")
        local cu, cv = MapProjection.clampToEdge(view, 900, 100, 10)
        T.near(cu, 190, 1e-6, "objectif hors vue ramené au bord")
        T.near(cv, 100, 1e-6, "bord droit")
        -- Index de dessin : moins de points que les tracés d'origine, requête locale.
        T.truthy(#index.Segments < index.PointCount, "tracés simplifiés")
        local local_ = MapIndex.query(index, -300, -300, 300, 300, 1)
        T.truthy(#local_ > 0 and #local_ < #index.Segments / 5, "requête limitée aux cellules visibles")
        T.equal(MapIndex.minImportanceFor(8000), 4, "niveau de détail réduit à grande échelle")
    end)

    T.test("points d'intérêt : issus des registres existants, valides, personnels filtrés", function()
        local layout = WorldLayout.get()
        local places = {}
        local wanted =
            { PublicGarage = true, Dealership = true, FuelStation = true, ChargingHub = true, CarWash = true }
        for _, placement in layout.Placements do
            if wanted[placement.Kind] then
                table.insert(places, {
                    Id = placement.Id,
                    Kind = placement.Kind,
                    Label = placement.Name,
                    X = placement.Center.X,
                    Z = placement.Center.Z,
                })
            end
        end
        for _, offer in PropertyCatalog.Offers do
            local placement = layout.PlacementById[offer.Entrance]
            table.insert(places, {
                Id = offer.Entrance,
                Kind = "Entrance",
                Label = placement.Name,
                X = placement.Center.X,
                Z = placement.Center.Z,
            })
        end
        local races = {}
        for _, course in RaceCourses.forPlace("OpenWorld") do
            local built = RaceCourse.build(course)
            table.insert(
                races,
                { Id = course.Id, Name = course.Name, X = built.Registration.X, Z = built.Registration.Z }
            )
        end
        local placements = {}
        for _, placement in layout.Placements do
            table.insert(placements, {
                Id = placement.Id,
                Kind = placement.Kind,
                Name = placement.Name,
                X = placement.Center.X,
                Z = placement.Center.Z,
            })
        end
        local points = PointsOfInterest.public(places, races, placements)
        local errors = PointsOfInterest.validate(points)
        T.equal(#errors, 0, table.concat(errors, ";"))
        local kinds = {}
        for _, point in points do
            kinds[point.Kind] = (kinds[point.Kind] or 0) + 1
            local id = string.sub(point.Id, 3)
            if point.Source == "Locations" then
                T.truthy(layout.PlacementById[id] ~= nil, "lieu de la carte : " .. id)
            elseif point.Source == "RaceCourse" then
                T.truthy(RaceCourses.get(id) ~= nil, "parcours : " .. id)
            end
        end
        for _, kind in
            {
                "Dealership",
                "PublicGarage",
                "FuelStation",
                "ChargingHub",
                "CarWash",
                "RaceStart",
                "SocialSpot",
                "PropertyOffer",
            }
        do
            T.truthy((kinds[kind] or 0) > 0, "catégorie présente : " .. kind)
        end
        T.equal(kinds.RaceStart, 16, "16 départs de course")
        -- Points personnels : seulement les propriétés fournies (celles du joueur).
        local personal = PointsOfInterest.personal(
            { { Id = "PR-1", OfferId = PropertyCatalog.Offers[1].Id, Name = "A" } },
            function(offerId)
                local offer = PropertyCatalog.offer(offerId)
                local placement = layout.PlacementById[offer.Entrance]
                return {
                    Id = offer.Entrance,
                    Kind = "Entrance",
                    Label = "x",
                    X = placement.Center.X,
                    Z = placement.Center.Z,
                }
            end,
            { Label = "Livraison", X = 10, Z = 20 }
        )
        T.equal(#personal, 2, "sa propriété et sa mission")
        T.equal(#PointsOfInterest.validate(personal), 0, "valides")
        local duplicate = table.clone(points)
        table.insert(duplicate, points[1])
        T.truthy(#PointsOfInterest.validate(duplicate) > 0, "doublon détecté")
    end)

    T.suite("Lot 0.7 — interfaces, focus, conduite, commandes")

    T.test("une seule modale à la fois ; fermeture et retour cohérents", function()
        local stack = UIStack.new()
        T.equal(#UIStack.open(stack, "Garage", "Modal", "focus-jeu"), 0, "rien à fermer")
        local closed = UIStack.open(stack, "Economy", "Modal", "focus-garage")
        T.equal(#closed, 1, "le garage se ferme")
        T.equal(closed[1].Name, "Garage", "modale précédente fermée")
        T.truthy(not UIStack.isOpen(stack, "Garage"), "jamais deux modales")
        T.truthy(UIStack.capturesDriving(stack), "modale : conduite capturée")
        UIStack.open(stack, "Notice", "Overlay", "focus-eco")
        local name = UIStack.back(stack)
        T.equal(name, "Notice", "retour : le dessus se ferme d'abord")
        local ok, focus = UIStack.close(stack, "Economy")
        T.truthy(ok, "fermé")
        T.equal(focus, "focus-jeu", "focus rendu au contrôle d'avant le premier écran")
        T.truthy(not UIStack.capturesDriving(stack), "plus rien n'est capturé")
        T.equal(UIStack.back(stack), nil, "retour sans écran : rien")
    end)

    T.test("focus : mémorisé par écran, mode rapide sans capture", function()
        local stack = UIStack.new()
        UIStack.open(stack, "Phone", "Modal", "bouton-A")
        UIStack.open(stack, "Phone", "Modal", "ignoré")
        local _, focus = UIStack.close(stack, "Phone")
        T.equal(focus, "bouton-A", "rouvrir ne remplace pas le focus de retour")
        UIStack.open(stack, "Phone", "Modal", nil, true)
        T.truthy(not UIStack.capturesDriving(stack), "mode rapide : la conduite n'est pas capturée")
    end)

    T.test("menus complets et confirmations financières bloqués en mouvement", function()
        T.equal(DrivingGate.mode(false, 20), "OnFoot", "à pied")
        T.equal(DrivingGate.mode(true, 0.2), "Stopped", "à l'arrêt")
        T.equal(DrivingGate.mode(true, 5), "Moving", "en mouvement")
        T.equal(DrivingGate.mode(true, 0.8, "Moving"), "Moving", "hystérésis")
        T.equal(DrivingGate.mode(true, 0.3, "Moving"), "Stopped", "arrêt")
        T.truthy(not DrivingGate.allows("Full", "Moving"), "écran complet refusé en roulant")
        T.truthy(DrivingGate.allows("Quick", "Moving"), "actions rapides autorisées")
        T.truthy(not DrivingGate.canConfirm("Moving"), "aucune confirmation en roulant")
        T.truthy(
            DrivingGate.allows("Full", "Stopped") and DrivingGate.canConfirm("OnFoot"),
            "à l'arrêt ou à pied : autorisé"
        )
    end)

    T.test("aucune double confirmation lors d'un changement de périphérique", function()
        local guard = InputMap.newGuard(0)
        InputMap.deviceChanged(guard, "KeyboardMouse", 0)
        InputMap.arm(guard, 10)
        T.truthy(not InputMap.accepts(guard, 9.9), "pression antérieure à l'affichage refusée")
        T.truthy(not InputMap.accepts(guard, 10.1), "pression trop rapide refusée")
        T.truthy(InputMap.accepts(guard, 10.4), "pression neuve acceptée")
        InputMap.deviceChanged(guard, "Gamepad", 20)
        T.truthy(not InputMap.accepts(guard, 20.1), "juste après le passage à la manette : refusée")
        T.truthy(InputMap.accepts(guard, 20.5), "nouvelle pression sur la manette : acceptée")
        InputMap.deviceChanged(guard, "Gamepad", 30)
        T.truthy(InputMap.accepts(guard, 30.1), "même périphérique : pas de délai supplémentaire")
        -- Une interface qui capture la conduite : rien ne passe, puis relâcher avant de reprendre.
        local arbiter = InputArbiter.newState()
        local keys = { Throttle = true, Brake = false, Left = false, Right = false, Handbrake = false }
        local pad = { Connected = true, Throttle = 1, Brake = 0, Steer = 0, Handbrake = false }
        local command =
            InputArbiter.step(arbiter, keys, pad, { Typing = false, WindowFocused = true, UiCaptured = true }, 0.1)
        T.equal(command.Throttle, 0, "capturé : aucune accélération")
        command =
            InputArbiter.step(arbiter, keys, pad, { Typing = false, WindowFocused = true, UiCaptured = false }, 0.1)
        T.equal(command.Throttle, 0, "après fermeture : commandes maintenues ignorées")
    end)

    T.test("raccourcis : P/J/K conservés, touches réservées et conflits refusés", function()
        T.equal(InputMap.keyFor("Garage", {}), "P", "P")
        T.equal(InputMap.keyFor("Economy", {}), "J", "J")
        T.equal(InputMap.keyFor("Races", {}), "K", "K")
        T.truthy(InputMap.consistent({}), "défauts cohérents")
        T.equal(select(2, InputMap.validate({}, "Phone", "W")), "Reserved", "touche de conduite refusée")
        T.equal(select(2, InputMap.validate({}, "Phone", "J")), "Conflict:Economy", "conflit refusé")
        T.equal(select(2, InputMap.validate({}, "Back", "L")), "NotRebindable", "retour non personnalisable")
        T.truthy((InputMap.validate({}, "Phone", "Y")), "touche libre acceptée")
        T.equal(InputMap.keyFor("Phone", { Phone = "Y" }), "Y", "personnalisation appliquée")
    end)

    T.suite("Lot 0.7 — notifications")

    T.test("trois niveaux, priorités en conduite, regroupement, historique", function()
        local q = NotificationQueue.new()
        local driving = { Driving = true, ReduceSecondary = false, Enabled = { Info = true, Warning = true } }
        local _, info = NotificationQueue.push(q, "notif.missionAvailable", "Info", 0, driving)
        local _, warn = NotificationQueue.push(q, "notif.lowFuel", "Warning", 0, driving, { percent = 12 })
        local critical, crit = NotificationQueue.push(q, "notif.mechanicalFailure", "Critical", 0, driving)
        T.equal(info, "Defer", "information différée en conduite")
        T.equal(warn, "Compact", "avertissement compact en conduite")
        T.equal(crit, "Show", "critique toujours affichée")
        T.truthy(critical.Multimodal, "critique multimodale")
        T.equal(#NotificationQueue.flushDeferred(q), 1, "résumé à l'arrêt")
        local _, again = NotificationQueue.push(q, "notif.lowFuel", "Warning", 5, driving)
        T.equal(again, "Repeat", "répétition regroupée")
        local fuel = nil
        for _, item in q.History do
            if item.Key == "notif.lowFuel" then
                fuel = item
            end
        end
        T.equal(fuel.Count, 2, "compteur")
        local quiet = { Driving = false, ReduceSecondary = true, Enabled = { Info = true, Warning = false } }
        T.equal(
            select(2, NotificationQueue.push(q, "x.info", "Info", 100, quiet)),
            "HistoryOnly",
            "secondaires réduites"
        )
        T.equal(
            select(2, NotificationQueue.push(q, "x.warn", "Warning", 100, quiet)),
            "HistoryOnly",
            "niveau désactivé"
        )
        T.equal(
            select(2, NotificationQueue.push(q, "x.crit", "Critical", 100, quiet)),
            "Show",
            "critique jamais désactivée"
        )
        for i = 1, 80 do
            NotificationQueue.push(q, "k" .. i, "Info", 200 + i, quiet)
        end
        T.equal(#q.History, NotificationQueue.MaxHistory, "historique borné")
        T.truthy(NotificationQueue.unread(q) > 0, "non lues")
        NotificationQueue.markAllRead(q)
        T.equal(NotificationQueue.unread(q), 0, "lues")
    end)

    T.suite("Lot 0.7 — groupes et confidentialité")

    T.test("groupe de huit membres au plus", function()
        local r = GroupRules.new("t")
        GroupRules.create(r, 1, 0)
        for userId = 2, 8 do
            local invite = GroupRules.invite(r, 1, userId, 0)
            T.truthy(invite ~= nil, "invitation " .. userId)
            T.truthy(GroupRules.accept(r, userId, invite.Id, 1), "accepte " .. userId)
        end
        T.equal(GroupRules.count(GroupRules.groupOf(r, 1)), 8, "huit membres")
        T.equal(select(2, GroupRules.invite(r, 1, 9, 2)), "GroupFull", "neuvième refusé")
        T.equal(select(2, GroupRules.create(r, 3, 2)), "GroupAlready", "un groupe à la fois")
    end)

    T.test("invitations : droits, expiration, retrait, refus ; départs et direction", function()
        local r = GroupRules.new("t")
        local invite = GroupRules.invite(r, 1, 2, 0)
        T.truthy(invite ~= nil, "le groupe est créé à la première invitation")
        T.equal(select(2, GroupRules.invite(r, 1, 2, 0)), "GroupInvitePending", "pas deux fois")
        T.equal(select(2, GroupRules.accept(r, 2, invite.Id, 500)), "GroupInviteExpired", "expirée")
        local second = GroupRules.invite(r, 1, 2, 600)
        T.truthy(GroupRules.revokeInvite(r, 1, second.Id), "retirée par le responsable")
        T.equal(select(2, GroupRules.accept(r, 2, second.Id, 601)), "GroupInviteExpired", "retirée : inutilisable")
        local third = GroupRules.invite(r, 1, 2, 602)
        T.truthy(GroupRules.decline(r, 2, third.Id), "refusée")
        local fourth = GroupRules.invite(r, 1, 2, 603)
        GroupRules.accept(r, 2, fourth.Id, 604)
        T.equal(select(2, GroupRules.invite(r, 2, 3, 605)), "GroupNotLeader", "seul le responsable invite")
        T.equal(select(2, GroupRules.kick(r, 2, 1)), "GroupNotLeader", "seul le responsable exclut")
        T.equal(
            select(2, GroupRules.invite(r, 1, 3, 606, false)),
            "GroupTargetBusy",
            "destinataire n'acceptant pas d'invitation"
        )
        -- Le responsable part : direction transmise ; le dernier part : groupe dissous.
        local events = GroupRules.leave(r, 1)
        T.equal(GroupRules.groupOf(r, 2).Leader, 2, "nouveau responsable")
        T.truthy(#events >= 2, "événements de départ et de direction")
        local last = GroupRules.leave(r, 2)
        T.equal(last[#last].Kind, "Dissolved", "groupe vide dissous")
        -- Responsable déconnecté plus de 60 s : direction confiée à un présent.
        local g = GroupRules.create(r, 10, 1000)
        GroupRules.accept(r, 11, GroupRules.invite(r, 10, 11, 1000).Id, 1000)
        GroupRules.setOnline(r, 10, false, 1001)
        GroupRules.tick(r, 1030)
        T.equal(g.Leader, 10, "pas avant la grâce")
        GroupRules.tick(r, 1062)
        T.equal(g.Leader, 11, "après la grâce : membre présent")
        GroupRules.tick(r, 1001 + GroupRules.MemberGraceS + 1)
        T.equal(GroupRules.groupOf(r, 10), nil, "absent trop longtemps : retiré")
    end)

    T.test("partage de position désactivé par défaut, limité au groupe, révocable", function()
        local r = GroupRules.new("t")
        GroupRules.create(r, 1, 0)
        GroupRules.accept(r, 2, GroupRules.invite(r, 1, 2, 0).Id, 0)
        GroupRules.create(r, 5, 0)
        local positions = {
            [1] = { X = 1, Z = 1, Heading = 0 },
            [2] = { X = 2, Z = 2, Heading = 0 },
            [5] = { X = 5, Z = 5, Heading = 0 },
        }
        T.equal(next(GroupRules.visiblePositions(r, 2, positions)), nil, "par défaut : rien n'est partagé")
        GroupRules.setSharing(r, 1, true, 10)
        local seen = GroupRules.visiblePositions(r, 2, positions)
        T.truthy(seen[1] ~= nil and seen[5] == nil, "visible par son groupe seulement")
        T.equal(next(GroupRules.visiblePositions(r, 5, positions)), nil, "jamais hors du groupe")
        T.equal(GroupRules.visiblePositions(r, 1, positions)[1], nil, "jamais à soi-même")
        GroupRules.setSharing(r, 1, false, 11)
        T.equal(next(GroupRules.visiblePositions(r, 2, positions)), nil, "désactivation immédiate")
        GroupRules.setSharing(r, 1, true, 12)
        GroupRules.setOnline(r, 1, false, 13)
        T.equal(next(GroupRules.visiblePositions(r, 2, positions)), nil, "déconnexion : partage arrêté")
        GroupRules.setOnline(r, 1, true, 14)
        T.equal(next(GroupRules.visiblePositions(r, 2, positions)), nil, "reconnexion : toujours désactivé")
        GroupRules.setSharing(r, 1, true, 20)
        GroupRules.tick(r, 20 + GroupRules.SharingMaxS + 1)
        T.equal(next(GroupRules.visiblePositions(r, 2, positions)), nil, "échéance : arrêté")
        GroupRules.setSharing(r, 2, true, 30)
        GroupRules.leave(r, 2)
        T.equal(GroupRules.groupOf(r, 2), nil, "sorti du groupe")
        T.equal(next(GroupRules.visiblePositions(r, 1, positions)), nil, "sortie : plus aucun partage")
    end)

    T.test("vue sociale filtrée : aucune donnée privée transmise", function()
        local r = GroupRules.new("t")
        GroupRules.create(r, 1, 0)
        GroupRules.accept(r, 2, GroupRules.invite(r, 1, 2, 0).Id, 0)
        GroupRules.invite(r, 1, 3, 0)
        -- Annuaire « trop bavard » : soldes, collection, propriétés, transactions.
        local leaky = function(userId: number)
            return {
                Name = "J" .. userId,
                Friend = true,
                Wallet = { Balance = 999999 },
                Vehicles = { "V-1" },
                Properties = { "P-1" },
                Transactions = { "tx" },
                Profile = {},
            }
        end
        local view = GroupRules.view(r, 2, leaky, 1)
        local allowed = {}
        for _, field in GroupRules.MemberFields do
            allowed[field] = true
        end
        local function check(member: any)
            for key in member do
                T.truthy(allowed[key], "champ autorisé seulement : " .. tostring(key))
            end
        end
        for _, member in view.Group.Members do
            check(member)
        end
        T.equal(#view.Outgoing, 0, "les invitations sortantes ne sont visibles que du responsable")
        local leaderView = GroupRules.view(r, 1, leaky, 1)
        for _, invite in leaderView.Outgoing do
            check(invite.To)
        end
        local outsider = GroupRules.view(r, 3, leaky, 1)
        T.equal(outsider.Group, nil, "invité non membre : aucun détail du groupe")
        for _, invite in outsider.Incoming do
            check(invite.From)
        end
        T.truthy(not string.find(dump(view), "999999"), "solde absent")
    end)

    T.suite("Lot 0.7 — localisation et préférences")

    T.test("FR/EN : toutes les clés traduites, mêmes paramètres, clés du serveur couvertes", function()
        local count = 0
        for key, entry in Localization.Entries do
            count += 1
            T.equal(#entry, 2, key .. " : deux langues")
            if key ~= "Ok" then
                T.truthy(#entry[1] > 0 and #entry[2] > 0, key .. " : textes non vides")
            end
            T.equal(
                table.concat(Localization.placeholders(entry[1]), ","),
                table.concat(Localization.placeholders(entry[2]), ","),
                key .. " : mêmes paramètres"
            )
        end
        T.truthy(count >= 300, "textes essentiels : " .. count)
        Localization.setLanguage("en")
        T.equal(Localization.t("InsufficientFunds"), "Insufficient balance.", "anglais")
        T.equal(
            Localization.t("gps.in", { distance = "300 m", action = "Turn left" }),
            "In 300 m: Turn left",
            "paramètres nommés"
        )
        T.equal(Localization.format("ExitTooFast", 5), "Slow below 5 km/h to get out.", "ancien format")
        Localization.setLanguage("fr")
        T.equal(Localization.t("InsufficientFunds"), "Solde insuffisant.", "retour au français à chaud")
        T.equal(Localization.t("TuningOutOfRange:Spring"), "Réglage hors plage.", "préfixe générique")
        T.equal(Localization.distance(1260, "fr"), "1,3 km", "distance FR")
        T.equal(Localization.distance(1260, "en"), "1.3 km", "distance EN")
        T.equal(Localization.amount(1234567, "en"), "1,234,567", "montant EN")
        -- Chaque clé d'erreur renvoyée par les services serveur a sa traduction.
        local missing = {}
        for _, descendant in H.game():GetDescendants() do
            if
                descendant.ClassName == "ModuleScript"
                and string.find(descendant:GetFullName(), "AutomotiveWorldServer", 1, true)
            then
                for key in string.gmatch(descendant.Source, 'rejected%("([%w:]+)"%)') do
                    if not Localization.has(key) then
                        missing[key] = true
                    end
                end
            end
        end
        local list = {}
        for key in missing do
            table.insert(list, key)
        end
        table.sort(list)
        T.equal(#list, 0, "clés sans traduction : " .. table.concat(list, ", "))
    end)

    T.test("préférences : migration v3 → v4, nettoyage, défauts sûrs", function()
        local current = ProfileSchema.new(42, 0, "Dev")
        T.truthy(Preferences.equal(current.Preferences, Preferences.defaults()), "profil neuf : défauts")
        local v3: any = ProfileMigration.deepCopy(current)
        v3.SchemaVersion = 3
        v3.Preferences = nil
        local migrated = ProfileMigration.migrate(v3)
        T.equal(migrated.Status, "Migrated", "migré")
        T.equal(migrated.Data.SchemaVersion, 4, "schéma 4")
        T.truthy((ProfileSchema.validate(migrated.Data)), "profil valide")
        T.equal(migrated.Data.Preferences.Language, "fr", "langue par défaut")
        T.equal(v3.Preferences, nil, "original intact")
        local dirty = Preferences.sanitize({
            Language = "de",
            Hud = { Level = "Énorme", Scale = 999, MinimapZoom = -3 },
            Access = { TextScale = 10, HighContrast = "oui" },
            Notifications = { Info = false, Critical = false },
            Bindings = { Phone = "Y", Inconnu = "Z", Map = "M;drop" },
            Wallet = { Balance = 1 },
        }, InputMap.actions())
        T.equal(dirty.Language, "fr", "langue inconnue refusée")
        T.equal(dirty.Hud.Level, "Standard", "niveau inconnu refusé")
        T.equal(dirty.Hud.Scale, 140, "taille bornée")
        T.equal(dirty.Hud.MinimapZoom, 1, "zoom borné")
        T.equal(dirty.Access.TextScale, 80, "texte borné")
        T.equal(dirty.Access.HighContrast, false, "type invalide : défaut")
        T.equal(dirty.Notifications.Info, false, "préférence respectée")
        T.equal((dirty.Notifications :: any).Critical, nil, "les alertes critiques ne se désactivent pas")
        T.equal(dirty.Bindings.Phone, "Y", "raccourci valide conservé")
        T.equal(dirty.Bindings.Inconnu, nil, "action inconnue retirée")
        T.equal(dirty.Bindings.Map, nil, "touche invalide retirée")
        T.equal((dirty :: any).Wallet, nil, "champ étranger ignoré")
        T.equal(
            (dirty.Social :: any).ShareLocation,
            nil,
            "le partage de position n'est jamais une préférence durable"
        )
    end)
end
