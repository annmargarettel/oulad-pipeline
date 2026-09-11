-- ============================================================
-- SILVER / CLEAN LAYER
-- student_assessment
-- ============================================================

CREATE OR REPLACE TABLE oulad.clean.student_assessment AS

SELECT

    -- Assessment ID → numeric
    TRY_CAST(id_assessment AS BIGINT) AS id_assessment,

    -- Student ID → numeric
    TRY_CAST(id_student AS BIGINT) AS id_student,

    -- Date submitted → integer
    TRY_CAST(date_submitted AS INT) AS date_submitted,

    -- Banked flag → integer
    TRY_CAST(is_banked AS INT) AS is_banked,

    -- Score → numeric
    TRY_CAST(score AS DOUBLE) AS score

FROM oulad.raw.student_assessment;

SELECT *
FROM oulad.clean.student_assessment;