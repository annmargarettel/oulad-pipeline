CREATE OR REPLACE TABLE oulad.mart.dim_student AS
SELECT
    si.id_student,
    si.final_result,
    sr.date_registration,
    sr.date_unregistration,
    CASE
        WHEN lower(trim(si.final_result)) = 'withdrawn' THEN TRUE
        ELSE FALSE
    END AS is_withdrawn
FROM oulad.clean.student_info AS si
LEFT JOIN oulad.clean.student_registration AS sr
    ON  si.id_student       = sr.id_student
    AND si.code_module      = sr.code_module
    AND si.code_presentation = sr.code_presentation;