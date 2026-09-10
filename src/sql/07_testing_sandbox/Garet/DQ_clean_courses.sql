CREATE TABLE IF NOT EXISTS oulad.validation.staging (
    check_id STRING,
    check_name STRING,
    layer STRING,
    table_name STRING,
    status STRING,          -- PASS, WARN, FAIL
    failed_rows BIGINT,
    check_timestamp TIMESTAMP
);

-- Clear previous results for this table before running checks
DELETE FROM oulad.validation.staging WHERE table_name = 'courses';


-- DQ01 — code_module cannot be NULL or empty (FAIL if any missing)
INSERT INTO oulad.validation.staging
SELECT
    'DQ01' AS check_id,
    'Module Code Not Null' AS check_name,
    'Silver' AS layer,
    'courses' AS table_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) AS failed_rows,
    CURRENT_TIMESTAMP() AS check_timestamp
FROM oulad.clean.courses
WHERE code_module IS NULL OR code_module = '';


-- DQ02 — code_presentation cannot be NULL or empty (FAIL if any missing)
INSERT INTO oulad.validation.staging
SELECT
    'DQ02' AS check_id,
    'Presentation Code Not Null' AS check_name,
    'Silver' AS layer,
    'courses' AS table_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) AS failed_rows,
    CURRENT_TIMESTAMP() AS check_timestamp
FROM oulad.clean.courses
WHERE code_presentation IS NULL OR code_presentation = '';


-- DQ03 — module_presentation_length cannot be NULL (FAIL if missing)
INSERT INTO oulad.validation.staging
SELECT
    'DQ03' AS check_id,
    'Presentation Length Not Null' AS check_name,
    'Silver' AS layer,
    'courses' AS table_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) AS failed_rows,
    CURRENT_TIMESTAMP() AS check_timestamp
FROM oulad.clean.courses
WHERE module_presentation_length IS NULL;


/*
  BENCHMARK NOTE:
  - Average module presentation length across the dataset is 255 days.
  - DQ04 checks for invalid/impossible lengths (<= 0 causes FAIL) and flags courses 
    deviating significantly from the 255-day average (outside 230–270 days triggers WARN).
*/
-- DQ04 — module_presentation_length range check
INSERT INTO oulad.validation.staging
SELECT
    'DQ04' AS check_id,
    'Presentation Length Near 255 Avg' AS check_name,
    'Silver' AS layer,
    'courses' AS table_name,
    CASE 
        WHEN SUM(CASE WHEN module_presentation_length <= 0 THEN 1 ELSE 0 END) > 0 THEN 'FAIL'
        WHEN SUM(CASE WHEN module_presentation_length NOT BETWEEN 230 AND 270 THEN 1 ELSE 0 END) > 0 THEN 'WARN'
        ELSE 'PASS' 
    END AS status,
    SUM(CASE WHEN module_presentation_length <= 0 OR module_presentation_length NOT BETWEEN 230 AND 270 THEN 1 ELSE 0 END) AS failed_rows,
    CURRENT_TIMESTAMP() AS check_timestamp
FROM oulad.clean.courses;


/* 
  BUSINESS RULE & DUPLICATION NOTE:
  - Repeated/duplicate values in individual columns are EXPECTED and ALLOWED:
    1. code_module appears multiple times across different academic terms (e.g., AAA offered in 2013J and 2014J).
    2. code_presentation appears across different modules as standard term codes (e.g., 2013J applies to AAA, BBB, CCC).
    3. module_presentation_length can naturally be identical across different modules (e.g., multiple 255-day courses).
  - Primary Key Check: ONLY the COMPOSITE PAIR (code_module + code_presentation) must be strictly unique.
*/
-- DQ05 — Composite Primary Key Unique (FAIL if identical module-presentation pairs exist)
INSERT INTO oulad.validation.staging
SELECT
    'DQ05' AS check_id,
    'Course Composite PK Unique' AS check_name,
    'Silver' AS layer,
    'courses' AS table_name,
    CASE WHEN (COUNT(*) - COUNT(DISTINCT code_module, code_presentation)) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    (COUNT(*) - COUNT(DISTINCT code_module, code_presentation)) AS failed_rows,
    CURRENT_TIMESTAMP() AS check_timestamp
FROM oulad.clean.courses;


-- View validation results
SELECT *
FROM oulad.validation.staging
WHERE table_name = 'courses'
ORDER BY check_id;
