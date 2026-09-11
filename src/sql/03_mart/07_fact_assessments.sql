CREATE OR REPLACE TABLE oulad.mart.fact_assessments AS
SELECT 
    sa.id_student,
    a.code_module,
    a.code_presentation,
    a.date,
    sa.id_assessment,
    a.assessment_type,
    CAST(a.weight AS DECIMAL(5,2)) AS weight,
    CAST(sa.score AS DECIMAL(5,2)) AS score,
    sa.date_submitted,
    (sa.date_submitted - a.date) AS submission_delay,
    CAST(sa.is_banked AS BOOLEAN) AS is_banked
FROM oulad.clean.student_assessment AS sa
INNER JOIN oulad.clean.assessments AS a
    ON sa.id_assessment = a.id_assessment
-- Enforce referential integrity against dimension tables
INNER JOIN oulad.mart.dim_student AS ds
    ON sa.id_student = ds.id_student
INNER JOIN oulad.mart.dim_module_presentation AS dmp
    ON a.code_module = dmp.code_module
   AND a.code_presentation = dmp.code_presentation
INNER JOIN oulad.mart.dim_date AS dd
    ON a.date = dd.date;