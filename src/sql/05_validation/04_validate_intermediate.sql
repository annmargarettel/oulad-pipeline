-- Not NULL test on id_student in fact_assessments
SELECT
    'fact_assessments' AS table_name,
    'id_student' AS column_name,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id_student) AS null_count,
    CASE
        WHEN COUNT(*) - COUNT(id_student) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM oulad.mart.fact_assessments;

-- Not NULL test on id_student in vle_interactions
SELECT
    'fact_vle_interactions' AS table_name,
    'id_student' AS column_name,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id_student) AS null_count,
    CASE
        WHEN COUNT(*) - COUNT(id_student) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_result
FROM oulad.mart.fact_vle_interactions;

-- duplicate test fact_assessments

SELECT
    id_student,
    id_assessment,
    COUNT(*) AS duplicate_count
FROM oulad.mart.fact_assessments
GROUP BY
    id_student,
    id_assessment
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- duplicate count fact vle interactions
SELECT
    id_student,
    id_site,
    date,
    COUNT(*) AS duplicate_count
FROM oulad.mart.fact_vle_interactions
GROUP BY
    id_student,
    id_site,
    date
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
