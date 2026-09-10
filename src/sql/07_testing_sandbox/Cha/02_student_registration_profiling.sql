-- DATASET VOLUME & PRIMARY KEYS UNIQUENESS PROFILE -- 
-- Discovers the total record count and evaluates whether (code_module, code_presentation, id_student) functions are unique compound key --
SELECT 
    COUNT(*) AS total_records,
    COUNT(DISTINCT id_student) AS unique_students,
    COUNT(DISTINCT code_module) AS unique_modules,
    COUNT(DISTINCT code_presentation) AS unique_presentations,
    COUNT(DISTINCT CONCAT(code_module, '-', code_presentation, '-', CAST(id_student AS STRING))) AS unique_composite_keys,
    COUNT(*) - COUNT(DISTINCT CONCAT(code_module, '-', code_presentation, '-', CAST(id_student AS STRING))) AS duplicate_composite_keys
FROM oulad.raw.student_registration;

---

-- COLUMN-LEVEL METRIC PROFILE --
-- Provides a standardized, long-format summary of data types, missingness, cardinality, and zero/null distributions across all columns --
WITH profile_base AS (
  SELECT
    COUNT(*) AS total_rows,
    
    -- code_module metrics
    COUNT(code_module) AS code_module_non_nulls,
    COUNT(DISTINCT code_module) AS code_module_distinct,
    
    -- code_presentation metrics
    COUNT(code_presentation) AS code_presentation_non_nulls,
    COUNT(DISTINCT code_presentation) AS code_presentation_distinct,
    
    -- id_student metrics
    COUNT(id_student) AS id_student_non_nulls,
    COUNT(DISTINCT id_student) AS id_student_distinct,
    
    -- date_registration metrics
    COUNT(date_registration) AS date_reg_non_nulls,
    COUNT_IF(date_registration IS NULL OR CAST(date_registration AS STRING) IN ('?', '')) AS date_reg_missing,
    COUNT(DISTINCT date_registration) AS date_reg_distinct,
    MIN(CAST(date_registration AS INT)) AS date_reg_min,
    MAX(CAST(date_registration AS INT)) AS date_reg_max,
    
    -- date_unregistration metrics
    COUNT(date_unregistration) AS date_unreg_non_nulls,
    COUNT_IF(date_unregistration IS NULL OR CAST(date_unregistration AS STRING) IN ('?', '')) AS date_unreg_missing,
    COUNT(DISTINCT date_unregistration) AS date_unreg_distinct,
    MIN(CAST(date_unregistration AS INT)) AS date_unreg_min,
    MAX(CAST(date_unregistration AS INT)) AS date_unreg_max
  FROM oulad.raw.student_registration
)
SELECT 
    'code_module' AS column_name, 
    'VARCHAR' AS inferred_type, 
    total_rows, 
    total_rows - code_module_non_nulls AS missing_count, 
    CONCAT(CAST(ROUND((total_rows - code_module_non_nulls) * 100.0 / total_rows, 2) AS STRING), '%') AS missing_pct, 
    code_module_distinct AS distinct_count, 
    NULL AS min_val, 
    NULL AS max_val 
FROM profile_base

UNION ALL

SELECT 
    'code_presentation', 
    'VARCHAR', 
    total_rows, 
    total_rows - code_presentation_non_nulls, 
    CONCAT(CAST(ROUND((total_rows - code_presentation_non_nulls) * 100.0 / total_rows, 2) AS STRING), '%'), 
    code_presentation_distinct, 
    NULL, 
    NULL 
FROM profile_base

UNION ALL

SELECT 
    'id_student', 
    'INTEGER', 
    total_rows, 
    total_rows - id_student_non_nulls, 
    CONCAT(CAST(ROUND((total_rows - id_student_non_nulls) * 100.0 / total_rows, 2) AS STRING), '%'), 
    id_student_distinct, 
    NULL, 
    NULL 
FROM profile_base

UNION ALL

SELECT 
    'date_registration', 
    'INTEGER', 
    total_rows, 
    date_reg_missing, 
    CONCAT(CAST(ROUND(date_reg_missing * 100.0 / total_rows, 2) AS STRING), '%'), 
    date_reg_distinct, 
    CAST(date_reg_min AS STRING), 
    CAST(date_reg_max AS STRING) 
FROM profile_base

UNION ALL

SELECT 
    'date_unregistration', 
    'INTEGER', 
    total_rows, 
    date_unreg_missing, 
    CONCAT(CAST(ROUND(date_unreg_missing * 100.0 / total_rows, 2) AS STRING), '%'), 
    date_unreg_distinct, 
    CAST(date_unreg_min AS STRING), 
    CAST(date_unreg_max AS STRING) 
FROM profile_base;
 
---

-- DATE_REGISTRATION VALUE DISTRIBUTION PROFILE --
-- Profiles the registration timing distributions (early vs. day-0 vs. late vs. missing) --
SELECT 
    CASE 
        WHEN date_registration IS NULL OR CAST(date_registration AS STRING) IN ('?', '') THEN '4. Missing / Unrecorded'
        WHEN CAST(date_registration AS INT) < 0 THEN '1. Early Registration (< 0)'
        WHEN CAST(date_registration AS INT) = 0 THEN '2. On Start Date (0)'
        WHEN CAST(date_registration AS INT) > 0 THEN '3. Late Registration (> 0)'
    END AS registration_cohort,
    COUNT(*) AS student_count,
    CONCAT(CAST(ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS STRING), '%') AS pct_of_total,
    MIN(CAST(date_registration AS INT)) AS min_days,
    MAX(CAST(date_registration AS INT)) AS max_days
FROM oulad.raw.student_registration
GROUP BY 1
ORDER BY 1;

---

-- DATE_UNREGISTRATION COMPLETION VS WITHDRAWAL PROFILE --
-- Discovers the overall completion vs withdrawal balance in the raw dataset --
SELECT 
    CASE 
        WHEN date_unregistration IS NULL OR CAST(date_unregistration AS STRING) IN ('?', '') THEN 'Completed / Stayed Enrolled'
        ELSE 'Withdrew / Unregistered'
    END AS enrollment_status,
    COUNT(*) AS total_students,
    CONCAT(CAST(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM oulad.raw.student_registration), 2) AS STRING), '%') AS pct_of_total
FROM oulad.raw.student_registration
GROUP BY 1;

---

-- TEMPORAL LOGIC & OUTLIER DISCOVERY --
-- Discovers impossible or illogical timing combinations in the raw data without rejecting them yet --
SELECT 
    -- Unregistered before registered
    COUNT_IF(CAST(date_unregistration AS INT) < CAST(date_registration AS INT)) AS unreg_before_reg_count,
    CONCAT(CAST(ROUND(COUNT_IF(CAST(date_unregistration AS INT) < CAST(date_registration AS INT)) * 100.0 / COUNT(*), 2) AS STRING), '%') AS unreg_before_reg_pct,
    
    -- Extreme early registrations
    COUNT_IF(CAST(date_registration AS INT) < -365) AS extreme_early_reg_count,
    CONCAT(CAST(ROUND(COUNT_IF(CAST(date_registration AS INT) < -365) * 100.0 / COUNT(*), 2) AS STRING), '%') AS extreme_early_reg_pct,
    
    -- Extreme late registrations
    COUNT_IF(CAST(date_registration AS INT) > 100) AS extreme_late_reg_count,
    CONCAT(CAST(ROUND(COUNT_IF(CAST(date_registration AS INT) > 100) * 100.0 / COUNT(*), 2) AS STRING), '%') AS extreme_late_reg_pct,
    
    -- Unregistered without registration date record
    COUNT_IF(date_registration IS NULL AND date_unregistration IS NOT NULL) AS unreg_without_reg_count,
    CONCAT(CAST(ROUND(COUNT_IF(date_registration IS NULL AND date_unregistration IS NOT NULL) * 100.0 / COUNT(*), 2) AS STRING), '%') AS unreg_without_reg_pct
FROM oulad.raw.student_registration;