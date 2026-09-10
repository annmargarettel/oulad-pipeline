SELECT
    'assessments' AS table_name,
    'code_module' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(code_module) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_module)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT code_module) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT code_module) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.assessments

UNION ALL

SELECT
    'assessments' AS table_name,
    'code_presentation' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(code_presentation) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_presentation)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT code_presentation) AS distinct_count,
    ROUND(
       100 * (COUNT(DISTINCT code_presentation) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.assessments

UNION ALL

SELECT
    'assessments' AS table_name,
    'id_assessment' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id_assessment) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(id_assessment)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT id_assessment) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT id_assessment) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.assessments

UNION ALL

SELECT
    'assessments' AS table_name,
    'assessment_type' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(assessment_type) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(assessment_type)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT assessment_type) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT assessment_type)) / COUNT(*),2
    ) AS distinct_percentage
FROM
    oulad.raw.assessments

UNION ALL

SELECT
    'assessments' AS table_name,
    'date' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(date) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(date)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT date) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT date) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.assessments

UNION ALL

SELECT
    'assessments' AS table_name,
    'weight' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(weight) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(weight)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT weight) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT weight) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.assessments    

UNION ALL

SELECT
    'courses' AS table_name,
    'code_module' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(code_module) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_module)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT code_module) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT code_module) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.courses

UNION ALL  

SELECT
    'courses' AS table_name,
    'code_presentation' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(code_presentation) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_presentation)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT code_presentation) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT code_presentation) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.courses

UNION ALL

SELECT
    'courses' AS table_name,
    'module_presentation_length' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(module_presentation_length) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(module_presentation_length)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT module_presentation_length) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT module_presentation_length) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.courses

UNION ALL

SELECT
    'student_assessment' AS table_name,
    'id_assessment' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id_assessment) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(id_assessment)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT id_assessment) AS distinct_count,
    ROUND( 
        100 * (COUNT(DISTINCT id_assessment) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_assessment

UNION ALL

SELECT
    'training_set' AS table_name,
    'id_student' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id_student) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(id_student)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT id_student) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT id_student) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_assessment

UNION ALL

SELECT
    'student_assessment' AS table_name,
    'date_submitted' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(date_submitted) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(date_submitted)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT date_submitted) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT date_submitted) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_assessment

UNION ALL

SELECT
    'student_assessment' AS table_name,
    'is_banked' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(is_banked) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(is_banked)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT is_banked) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT is_banked) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_assessment

UNION ALL

SELECT
    'student_assessment' AS table_name,
    'score' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(score) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(score)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT score) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT score) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_assessment

UNION ALL

SELECT
    'student_info' AS table_name,
    'code_module' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(code_module) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_module)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT code_module) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT code_module) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_info

UNION ALL

SELECT
    'student_info' AS table_name,
    'code_presentation' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(code_presentation) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_presentation)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT code_presentation) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT code_presentation) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_info

UNION ALL

SELECT
    'student_info' AS table_name,
    'id_student' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id_student) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(id_student))/COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT id_student) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT id_student) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_info

UNION ALL

SELECT
    'student_info' AS table_name,
    'region' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(region) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(region)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT region) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT region) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_info

UNION ALL

SELECT
    'student_info' AS table_name,
    'highest_education' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(highest_education) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(highest_education)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT highest_education) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT highest_education) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_info

UNION ALL

SELECT
    'student_info' AS table_name,
    'imd_band' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(imd_band) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(imd_band)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT imd_band) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT imd_band) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_info

UNION ALL

SELECT
    'student_info' AS table_name,
    'age_band' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(age_band) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(age_band)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT age_band) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT age_band) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_info

UNION ALL

SELECT
    'student_info' AS table_name,
    'num_of_prev_attempts' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(num_of_prev_attempts) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(num_of_prev_attempts)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT num_of_prev_attempts) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT num_of_prev_attempts) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_info

UNION ALL

SELECT
    'student_info' AS table_name,
    'studied_credits' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(studied_credits) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(studied_credits)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT studied_credits) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT studied_credits) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_info

UNION ALL

SELECT
    'student_info' AS table_name,
    'disability' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(disability) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(disability)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT disability) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT disability) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_info

UNION ALL

SELECT
    'student_info' AS table_name,
    'final_result' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(final_result) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(final_result)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT final_result) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT final_result) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_info

UNION ALL

SELECT
    'student_registration' AS table_name,
    'code_module' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(code_module) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_module)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT code_module) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT code_module) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_registration

UNION ALL

SELECT
    'student_registration' AS table_name,
    'code_presentation' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(code_presentation) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_presentation)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT code_presentation) AS distinct_count,   
    ROUND(
        100 * (COUNT(DISTINCT code_presentation) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_registration

UNION ALL

SELECT
    'student_registration' AS table_name,
    'id_student' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id_student) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(id_student)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT id_student) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT id_student) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_registration

UNION ALL

SELECT
    'student_registration' AS table_name,
    'date_registration' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(date_registration) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(date_registration)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT date_registration) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT date_registration) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_registration

UNION ALL

SELECT
    'student_registration' AS table_name,
    'date_unregistration' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(date_unregistration) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(date_unregistration)) / COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT date_unregistration) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT date_unregistration) / COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_registration

UNION ALL

SELECT
    'student_vle' AS table_name,
    'code_module' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(code_module) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_module))/COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT(code_module)) AS dintinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(code_module))/COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_vle

UNION ALL

SELECT
    'student_vle' AS table_name,
    'code_presentation' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(code_presentation) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_presentation))/COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT(code_presentation)) AS dintinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(code_presentation))/COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_vle

UNION ALL

SELECT
    'student_vle' AS table_name,
    'id_student' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id_student) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(id_student))/COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT(id_student)) AS dintinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(id_student))/COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_vle

UNION ALL

SELECT
    'student_vle' AS table_name,
    'id_site' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id_site) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(id_site))/COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT(id_site)) AS dintinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(id_site))/COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_vle

UNION ALL

SELECT
    'student_vle' AS table_name,
    'date' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(date) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(date))/COUNT(*),2
    ) AS null_percentage,
    COUNT(DISTINCT(date)) AS dintinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(date))/COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_vle

UNION ALL

SELECT
    'student_vle' AS table_name,
    'sum_click' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(sum_click) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(sum_click))/COUNT(*),2
    ) AS null_percentage, 
    COUNT(DISTINCT(sum_click)) AS dintinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(sum_click))/COUNT(*)),2
    ) AS distinct_percentage
FROM
    oulad.raw.student_vle

UNION ALL

SELECT
    'vle' AS table_name,
    'id_site' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id_site) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(id_site))/COUNT(*), 2
    ) AS null_percentage,
    COUNT(DISTINCT(id_site)) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(id_site))/COUNT(*)), 2
    ) AS distinct_percentage
FROM     oulad.raw.vle

UNION ALL

SELECT
    'vle' AS table_name,
    'code_module' AS column,
    COUNT(*) AS total_rows, 
    COUNT(*) - COUNT(code_module) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_module))/COUNT(*), 2
    ) AS null_percentage,
    COUNT(DISTINCT(code_module)) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(code_module))/COUNT(*)), 2
    ) AS distinct_percentage
FROM     oulad.raw.vle

UNION ALL

SELECT
    'vle' AS table_name,
    'code_presentation' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(code_presentation) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(code_presentation))/COUNT(*), 2
    ) AS null_percentage,
    COUNT(DISTINCT(code_presentation)) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(code_presentation))/COUNT(*)), 2
    ) AS distinct_percentage
FROM     oulad.raw.vle

UNION ALL

SELECT
    'vle' AS table_name,
    'activity_type' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(activity_type) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(activity_type))/COUNT(*), 2
    ) AS null_percentage,
    COUNT(DISTINCT(activity_type)) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(activity_type))/COUNT(*)), 2
    ) AS distinct_percentage
FROM     oulad.raw.vle

UNION ALL

SELECT
    'vle' AS table_name,
    'week_from' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(week_from) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(week_from))/COUNT(*), 2
    ) AS null_percentage,
    COUNT(DISTINCT(week_from)) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(week_from))/COUNT(*)), 2
    ) AS distinct_percentage
FROM     oulad.raw.vle

UNION ALL

SELECT 
    'vle' AS table_name,
    'week_to' AS column,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(week_to) AS null_count,
    ROUND(
        100 * (COUNT(*) - COUNT(week_to))/COUNT(*), 2
    ) AS null_percentage,
    COUNT(DISTINCT(week_to)) AS distinct_count,
    ROUND(
        100 * (COUNT(DISTINCT(week_to))/COUNT(*)), 2
    ) AS distinct_percentage
FROM     oulad.raw.vle;