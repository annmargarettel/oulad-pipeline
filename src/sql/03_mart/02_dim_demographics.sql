CREATE OR REPLACE TABLE oulad.mart.dim_demographics AS
SELECT
    si.id_student,
    si.code_module,
    si.code_presentation,
    si.gender,
    si.region,
    si.highest_education,
    si.imd_band,
    si.age_band,
    si.num_of_prev_attempts,
    si.studied_credits,
    si.disability
FROM oulad.clean.student_info AS si
LEFT JOIN oulad.mart.dim_student AS ds
    ON si.id_student = ds.id_student
LEFT JOIN oulad.mart.dim_module_presentation AS dmp
    ON  si.code_module       = dmp.code_module
    AND si.code_presentation = dmp.code_presentation
WHERE ds.id_student IS NOT NULL;   -- keep only rows tied to a real, known student;
                                     -- don't let the module_presentation join drop rows