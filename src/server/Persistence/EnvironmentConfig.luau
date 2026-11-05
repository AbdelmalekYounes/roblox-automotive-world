--!strict
-- Identifiants des expériences Roblox par environnement (voir Environment).
-- Seul le propriétaire du projet peut renseigner ces listes.
-- Test : expérience PRIVÉE créée et publiée par le propriétaire le 2026-11-05 (« Automotive World Test »,
-- GameId 10774855477, PlaceId 130603661962826, relevés par lui dans Studio) → DataStore isolé « AW_TEST_… ».
-- Production : aucune expérience déclarée (jamais de DataStore de production).
return table.freeze({
    TestGameIds = table.freeze({ 10774855477 }) :: { number },
    ProdGameIds = table.freeze({}) :: { number },
    SchemaTag = "v1",
})
