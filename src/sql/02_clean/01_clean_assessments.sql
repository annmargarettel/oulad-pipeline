

CREATE SCHEMA IF NOT EXISTS oulad.clean;


CREATE OR REPLACE TEMPORARY VIEW raw_assessments AS
SELECT
  code_module, code_presentation, id_assessment, assessment_type, date, weight
FROM read_files(
  '/Volumes/workspace/default/ftw-b12/shared/week07/assessments.csv',
  format => 'csv',
  header => true,
  schema => 'code_module STRING, code_presentation STRING, id_assessment STRING, assessment_type STRING, date STRING, weight STRING'
);


CREATE OR REPLACE TABLE oulad.clean.01_clean_assessments AS
WITH typed AS (
  -- Stage 1: convert every column to the right type, and fix "null" text.
  SELECT
    upper(trim(code_module)) AS code_module,
    upper(trim(code_presentation)) AS code_presentation,
    try_cast(trim(id_assessment) AS INT) AS id_assessment,
    initcap(trim(assessment_type)) AS assessment_type_raw,
    -- NULLIF(x, 'null') turns the literal text "null" into a true NULL.
    -- TRY_CAST then safely turns that (now-real) value into a number.
    try_cast(NULLIF(lower(trim(date)),   'null') AS INT) AS date,
    try_cast(NULLIF(lower(trim(weight)), 'null') AS DOUBLE) AS weight
  FROM raw_assessments
),
standardized AS (
  -- Stage 2: force assessment_type into exactly one of 3 accepted values.
  SELECT
    *,
    CASE
      WHEN upper(assessment_type_raw) = 'TMA'  THEN 'TMA'
      WHEN upper(assessment_type_raw) = 'CMA'  THEN 'CMA'
      WHEN upper(assessment_type_raw) = 'EXAM' THEN 'Exam'
      ELSE NULL
    END AS assessment_type
  FROM typed
),
deduped AS (
  -- Stage 3: if an id_assessment repeats, number the copies and keep #1.
  SELECT *,
         row_number() OVER (PARTITION BY id_assessment ORDER BY id_assessment) AS rn
  FROM standardized
)
-- Final stage: pick the columns we want to keep, add the two flag columns,
-- and only keep rows that pass our must-have rules.
SELECT
  code_module,
  code_presentation,
  id_assessment,
  assessment_type,
  date,
  weight,
  (date IS NULL AND assessment_type = 'Exam') AS is_date_null_expected,
  (weight IS NULL) AS is_weight_missing,
  current_timestamp() AS _silver_load_ts
FROM deduped
WHERE rn = 1 -- keep only the first copy of each id
  AND id_assessment IS NOT NULL -- must have converted to a real number
  AND assessment_type IS NOT NULL  -- must be TMA, CMA, or Exam
  AND (weight IS NULL OR weight BETWEEN 0 AND 100) -- weight must make sense if present
  AND (date IS NULL OR date > 0); -- date must make sense if present

-- Anything that got filtered out above lands here instead of disappearing,
-- so nothing is silently thrown away — someone can review it later.
-- "Quarantine" just means "set aside for review, not trusted yet."
CREATE OR REPLACE TABLE oulad.clean.01_clean_assessments_quarantine AS
WITH typed AS (
  SELECT
    upper(trim(code_module)) AS code_module,
    upper(trim(code_presentation)) AS code_presentation,
    try_cast(trim(id_assessment) AS INT) AS id_assessment,
    trim(assessment_type) AS assessment_type_raw,
    try_cast(NULLIF(lower(trim(date)),'null') AS INT) AS date,
    try_cast(NULLIF(lower(trim(weight)), 'null') AS DOUBLE) AS weight
  FROM raw_assessments
)
SELECT *,
  -- This column explains WHY each row was set aside.
  CASE
    WHEN id_assessment IS NULL THEN 'id_assessment_uncastable'
    WHEN upper(assessment_type_raw) NOT IN ('TMA','CMA','EXAM') THEN 'assessment_type_out_of_domain'
    WHEN weight IS NOT NULL AND weight NOT BETWEEN 0 AND 100 THEN 'weight_out_of_range'
    WHEN date IS NOT NULL AND date <= 0 THEN 'date_out_of_range'
    ELSE 'other'
  END AS quarantine_reason
FROM typed
WHERE id_assessment IS NULL
   OR upper(assessment_type_raw) NOT IN ('TMA','CMA','EXAM')
   OR (weight IS NOT NULL AND weight NOT BETWEEN 0 AND 100)
   OR (date IS NOT NULL AND date <= 0);


--STEP 4 — VALIDATION (checking the CLEANED data actually meets the rules)
-- Every check below is expected to come back TRUE, since we just cleaned the data ourselves.


CREATE OR REPLACE TEMPORARY VIEW vw_silver_validation_results AS
SELECT 'row_count_matches_raw_minus_quarantine' AS check_name,
       (SELECT count(*) FROM oulad.clean.01_clean_assessments) =
       (SELECT count(*) FROM raw_assessments) - (SELECT count(*) FROM oulad.clean.01_clean_assessments_quarantine) AS passed
UNION ALL
SELECT 'id_assessment_not_null',   sum(CASE WHEN id_assessment IS NULL THEN 1 ELSE 0 END) = 0 FROM oulad.clean.01_clean_assessments
UNION ALL
SELECT 'id_assessment_unique',     count(*) = count(DISTINCT id_assessment)                  FROM oulad.clean.01_clean_assessments
UNION ALL
SELECT 'assessment_type_in_domain', sum(CASE WHEN assessment_type NOT IN ('TMA','CMA','Exam') THEN 1 ELSE 0 END) = 0 FROM oulad.clean.01_clean_assessments
UNION ALL
SELECT 'weight_in_range_when_present',
       sum(CASE WHEN weight IS NOT NULL AND weight NOT BETWEEN 0 AND 100 THEN 1 ELSE 0 END) = 0 FROM oulad.clean.01_clean_assessments
UNION ALL
SELECT 'date_positive_when_present',
       sum(CASE WHEN date IS NOT NULL AND date <= 0 THEN 1 ELSE 0 END) = 0 FROM oulad.clean.01_clean_assessments
UNION ALL
SELECT 'null_date_only_on_exam',
       sum(CASE WHEN date IS NULL AND assessment_type <> 'Exam' THEN 1 ELSE 0 END) = 0 FROM oulad.clean.01_clean_assessments
UNION ALL
SELECT 'no_literal_null_strings_remaining',
       sum(CASE WHEN cast(date AS STRING) = 'null' OR cast(weight AS STRING) = 'null' THEN 1 ELSE 0 END) = 0 FROM oulad.clean.01_clean_assessments
UNION ALL
SELECT 'code_presentation_format',
       sum(CASE WHEN code_presentation NOT RLIKE '^[0-9]{4}[BJ]$' THEN 1 ELSE 0 END) = 0 FROM oulad.clean.01_clean_assessments;

-- Run this to see which checks passed (true) or failed (false).
SELECT * FROM vw_silver_validation_results;

-- Just informational: flags any course where the non-Exam weights don't
-- add up close to 100 (and isn't the special all-zero GGG case).
SELECT code_module, code_presentation, sum(weight) AS sum_weight_non_exam
FROM oulad.clean.01_clean_assessments
WHERE assessment_type <> 'Exam'
GROUP BY code_module, code_presentation
HAVING sum(weight) NOT BETWEEN 95 AND 100.001 AND sum(weight) <> 0
ORDER BY sum_weight_non_exam;



-- STEP 5 — SAVED VIEWS SHOWING ANY VALUES STILL MISSING AFTER CLEANING


CREATE OR REPLACE TEMPORARY VIEW vw_silver_null_date AS
SELECT * FROM oulad.clean.01_clean_assessments WHERE date IS NULL;

-- This one should always come back EMPTY — it means a non-Exam row
-- somehow still has a missing date, which shouldn't happen after cleaning.
CREATE OR REPLACE TEMPORARY VIEW vw_silver_null_date_unexpected AS
SELECT * FROM oulad.clean.01_clean_assessments WHERE date IS NULL AND assessment_type <> 'Exam';

CREATE OR REPLACE TEMPORARY VIEW vw_silver_null_weight AS
SELECT * FROM oulad.clean.01_clean_assessments WHERE weight IS NULL;

-- Any row missing either value at all.
CREATE OR REPLACE TEMPORARY VIEW vw_silver_any_null AS
SELECT * FROM oulad.clean.01_clean_assessments WHERE date IS NULL OR weight IS NULL;

SELECT * FROM vw_silver_any_null;