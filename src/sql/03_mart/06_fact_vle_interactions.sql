CREATE OR REPLACE TABLE oulad.mart.fact_vle_interactions AS
SELECT 
    sv.id_student,
    sv.code_module,
    sv.code_presentation,
    sv.date,
    sv.id_site,
    v.activity_type,
    sv.sum_click
FROM oulad.clean.student_vle AS sv
-- Join with VLE metadata to enrich interactions with activity_type
LEFT JOIN oulad.clean.vle AS v
    ON sv.id_site = v.id_site
   AND sv.code_module = v.code_module
   AND sv.code_presentation = v.code_presentation
-- Enforce referential integrity against existing dimension tables
INNER JOIN oulad.mart.dim_student AS ds
    ON sv.id_student = ds.id_student
INNER JOIN oulad.mart.dim_module_presentation AS dmp
    ON sv.code_module = dmp.code_module
   AND sv.code_presentation = dmp.code_presentation
INNER JOIN oulad.mart.dim_date AS dd
    ON sv.date = dd.date;