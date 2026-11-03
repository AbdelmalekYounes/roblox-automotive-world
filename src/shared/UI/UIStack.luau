--!strict
--[[
    Pile des interfaces (lot 0.7), PURE : une seule interface MODALE
    principale à la fois, superpositions légères (téléphone réduit, carte en
    consultation), retour et restauration du focus.

    - open(modale) ferme la modale précédente (jamais deux panneaux qui se
      superposent et capturent les mêmes touches) ; le focus d'avant
      l'ouverture est mémorisé pour être rendu à la fermeture.
    - close / back : l'interface du dessus se ferme ; le focus revient au
      contrôle précédent s'il existe encore (sinon : aucun, la conduite reprend).
    - capturesDriving : vrai tant qu'une modale est ouverte (les commandes de
      conduite sont alors ignorées et devront être relâchées puis renouvelées).
]]

local UIStack = {}

export type Kind = "Modal" | "Overlay"

export type Entry = {
    Name: string,
    Kind: Kind,
    ReturnFocus: any?, -- contrôle sélectionné avant l'ouverture
    Quick: boolean, -- mode rapide (conduite)
}

export type Stack = { Entries: { Entry } }

function UIStack.new(): Stack
    return { Entries = {} }
end

function UIStack.top(stack: Stack): Entry?
    return stack.Entries[#stack.Entries]
end

function UIStack.find(stack: Stack, name: string): (Entry?, number?)
    for index, entry in stack.Entries do
        if entry.Name == name then
            return entry, index
        end
    end
    return nil, nil
end

function UIStack.isOpen(stack: Stack, name: string): boolean
    return (UIStack.find(stack, name)) ~= nil
end

function UIStack.modal(stack: Stack): Entry?
    for index = #stack.Entries, 1, -1 do
        local entry = stack.Entries[index]
        if entry.Kind == "Modal" then
            return entry
        end
    end
    return nil
end

--[[
    Ouvre une interface. Renvoie la liste des interfaces FERMÉES en
    conséquence (à masquer par l'appelant). Rouvrir une interface déjà
    ouverte la remet au-dessus sans rien fermer d'autre.
]]
function UIStack.open(stack: Stack, name: string, kind: Kind, focus: any?, quick: boolean?): { Entry }
    local closed: { Entry } = {}
    local existing, index = UIStack.find(stack, name)
    if existing and index then
        table.remove(stack.Entries, index)
        existing.Quick = quick == true
        table.insert(stack.Entries, existing)
        return closed
    end
    local returnFocus = focus
    if kind == "Modal" then
        -- Une seule modale : la précédente se ferme, son focus de retour est repris.
        for i = #stack.Entries, 1, -1 do
            local entry = stack.Entries[i]
            if entry.Kind == "Modal" then
                table.remove(stack.Entries, i)
                table.insert(closed, entry)
                returnFocus = entry.ReturnFocus
            end
        end
    end
    table.insert(stack.Entries, { Name = name, Kind = kind, ReturnFocus = returnFocus, Quick = quick == true })
    return closed
end

-- Ferme une interface ; renvoie le focus à restaurer (ou nil).
function UIStack.close(stack: Stack, name: string): (boolean, any?)
    local entry, index = UIStack.find(stack, name)
    if entry == nil or index == nil then
        return false, nil
    end
    table.remove(stack.Entries, index)
    return true, entry.ReturnFocus
end

-- Retour : ferme l'interface du dessus.
function UIStack.back(stack: Stack): (string?, any?)
    local entry = UIStack.top(stack)
    if entry == nil then
        return nil, nil
    end
    local _, focus = UIStack.close(stack, entry.Name)
    return entry.Name, focus
end

function UIStack.capturesDriving(stack: Stack): boolean
    local modal = UIStack.modal(stack)
    return modal ~= nil and not modal.Quick
end

-- Passage en mode rapide (conduite) : la modale reste, réduite, sans capturer.
function UIStack.setQuick(stack: Stack, quick: boolean)
    for _, entry in stack.Entries do
        entry.Quick = quick
    end
end

return table.freeze(UIStack)
