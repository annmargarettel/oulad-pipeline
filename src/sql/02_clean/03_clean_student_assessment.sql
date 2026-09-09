
--this csv has 173,912 rows × 5 columns


CREATE OR REPLACE TABLE oulad.clean.studentAssessment AS

SELECT
--makes sure the assessment ID is numeric
    CAST(id_assessment AS BIGINT) AS id_assessment,
--makes the student ID numeric
    CAST(id_student AS BIGINT) AS id_student,
--makes the date offset numeric
    CAST(date_submitted AS INT) AS date_submitted,
--makes the flag numeric
    CAST(is_banked AS INT) AS is_banked,
--makes the scores numeric
    CAST(score AS INT) AS score    

FROM oulad.raw.student_assessment

WHERE id_assessment IS NOT NULL
  AND id_student IS NOT NULL;


--checking row count
SELECT COUNT(*)
FROM oulad.clean.studentAssessment;

--checking data types
DESCRIBE oulad.clean.studentAssessment;

--checking nulls
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN id_assessment IS NULL THEN 1 ELSE 0 END) AS null_id_assessment,
    SUM(CASE WHEN id_student IS NULL THEN 1 ELSE 0 END) AS null_id_student,
    SUM(CASE WHEN date_submitted IS NULL THEN 1 ELSE 0 END) AS null_date_submitted,
    SUM(CASE WHEN is_banked IS NULL THEN 1 ELSE 0 END) AS null_is_banked,
    SUM(CASE WHEN score IS NULL THEN 1 ELSE 0 END) AS null_score
FROM oulad.clean.studentAssessment;


--DQ RESULTS TABLE
CREATE TABLE IF NOT EXISTS oulad.clean.dq_check_results (
    check_id STRING,
    check_name STRING,
    layer STRING,
    table_name STRING,
    status STRING,
    failed_rows BIGINT,
    check_timestamp TIMESTAMP
);

-- Clear previous results before running the checks
TRUNCATE TABLE oulad.clean.dq_check_results;

--DQ01 — Student ID cannot be NULL
INSERT INTO oulad.clean.dq_check_results

SELECT
    'DQ01' AS check_id,
    'Student ID Not Null' AS check_name,
    'Silver' AS layer,
    'studentAssessment' AS table_name,

    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    COUNT(*) AS failed_rows,

    current_timestamp() AS check_timestamp

FROM oulad.clean.studentAssessment
WHERE id_student IS NULL;

--DQ02 — Assessment ID cannot be NULL
INSERT INTO oulad.clean.dq_check_results

SELECT
    'DQ02' AS check_id,
    'Assessment ID Not Null' AS check_name,
    'Silver' AS layer,
    'studentAssessment' AS table_name,

    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    COUNT(*) AS failed_rows,

    current_timestamp() AS check_timestamp

FROM oulad.clean.studentAssessment
WHERE id_assessment IS NULL;

--DQ03 — Student + Assessment must be unique
INSERT INTO oulad.clean.dq_check_results

SELECT
    'DQ03' AS check_id,
    'Student Assessment Grain Unique' AS check_name,
    'Silver' AS layer,
    'studentAssessment' AS table_name,

    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    COUNT(*) AS failed_rows,

    current_timestamp() AS check_timestamp

FROM (
    SELECT
        id_student,
        id_assessment
    FROM oulad.clean.studentAssessment
    GROUP BY
        id_student,
        id_assessment
    HAVING COUNT(*) > 1
);

--DQ04 — Score must be between 0 and 100
INSERT INTO oulad.clean.dq_check_results

SELECT
    'DQ04' AS check_id,
    'Score Within Valid Range' AS check_name,
    'Silver' AS layer,
    'studentAssessment' AS table_name,

    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    COUNT(*) AS failed_rows,

    current_timestamp() AS check_timestamp

FROM oulad.clean.studentAssessment
WHERE score IS NOT NULL
  AND (score < 0 OR score > 100);

--DQ05 — is_banked must be 0 or 1
INSERT INTO oulad.clean.dq_check_results

SELECT
    'DQ05' AS check_id,
    'is_banked Valid Values' AS check_name,
    'Silver' AS layer,
    'studentAssessment' AS table_name,

    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,

    COUNT(*) AS failed_rows,

    current_timestamp() AS check_timestamp

FROM oulad.clean.studentAssessment
WHERE is_banked IS NULL
   OR is_banked NOT IN (0, 1);

--View the results
SELECT *
FROM oulad.clean.dq_check_results
WHERE table_name = 'studentAssessment'
ORDER BY check_id;