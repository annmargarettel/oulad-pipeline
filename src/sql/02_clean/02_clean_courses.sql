-- Clean courses
-- Expected row count: 22 rows in, 22 out (no change)

CREATE OR REPLACE TABLE oulad.clean.courses AS

SELECT
    -- Trim whitespace, upper-case, and cast module code to string
    CAST(TRIM(UPPER(code_module)) AS STRING) AS code_module,
    
    -- Trim whitespace, upper-case, and cast presentation code to string
    CAST(TRIM(UPPER(code_presentation)) AS STRING) AS code_presentation,

    -- Standardize module duration in days as an explicit 64-bit integer
    CAST(module_presentation_length AS BIGINT) AS module_presentation_length

FROM oulad.raw.courses;
