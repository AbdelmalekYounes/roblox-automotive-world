--!strict
-- Identifiants des expériences Roblox par environnement (voir Environment).
-- VIDES tant que l'expérience de test isolée et l'expérience de production
-- n'ont pas été créées par le propriétaire : tout s'exécute alors en mémoire.
-- Seul le propriétaire du projet peut renseigner ces listes.
return table.freeze({
    TestGameIds = table.freeze({}) :: { number },
    ProdGameIds = table.freeze({}) :: { number },
    SchemaTag = "v1",
})
