-- ============================================================
-- SILVER / CLEAN LAYER
-- clean_student_assessment
-- ============================================================

CREATE OR REPLACE TABLE oulad.clean.clean_student_assessment AS

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

DROP TABLE IF EXISTS oulad.clean.student_assessment;
