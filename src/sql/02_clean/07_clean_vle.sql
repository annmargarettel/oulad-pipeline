CREATE OR REPLACE TABLE oulad.clean.vle AS
SELECT
    TRY_CAST(id_site AS INT) AS id_site,
    UPPER(TRIM(code_module)) AS code_module,
    UPPER(TRIM(code_presentation)) AS code_presentation,
    LOWER(TRIM(activity_type)) AS activity_type,
    TRY_CAST(week_from AS INT) AS week_from,
    TRY_CAST(week_to AS INT) AS week_to
FROM oulad.raw.vle

