-- =============================================================================
-- student_info  |  25 DATA QUALITY CHECKS
-- Owner: Kinah
-- Sandbox: src/sql/07_testing_sandbox/Kinah
--
-- READS
--   oulad.clean.student_info   arrives with PR #2, still open pending bronze validations
--   oulad.raw.student_info     for the volume reconciliation
--   oulad.raw.courses          for the referential integrity check
--
-- Mia and @anjelikamarquez: the CTE below is the part to lift. It returns one row
-- per check with the same shape for every table, so your validations can UNION
-- straight onto it. Nothing here writes. To persist, wrap the final SELECT in
--   CREATE OR REPLACE TABLE oulad.validation.dq_check_results AS ...
-- once we agree the table name as a team.
--
-- SCHEMA, one row per check
--   executed_at, dataset, layer, check_id, check_name, check_type, dq_dimension,
--   column_name, expectation, threshold, severity, total_count, fail_count,
--   fail_pct, status, business_question, owner
--
-- STATUS RULE
--   fail_count = 0                    -> PASS
--   fail_pct  > threshold             -> the check's own severity (WARN or FAIL)
--   fail_pct <= threshold, but > 0    -> WARN
--
-- CURRENT RESULT: 19 PASS, 6 WARN, 0 FAIL. No threshold breached.
-- =============================================================================

WITH s AS (SELECT * FROM oulad.clean.student_info),
     r AS (SELECT * FROM oulad.raw.student_info),

checks AS (

  -- NULL, 5 checks -------------------------------------------------------------
  SELECT 1 AS check_id, 'imd_band_is_known' AS check_name, 'NULL' AS check_type,
         'Completeness' AS dq_dimension, 'imd_band' AS column_name,
         'imd_band is populated for every enrolment' AS expectation,
         5.00 AS threshold_pct, 'WARN' AS severity,
         COUNT(*) AS total_count, COUNT_IF(imd_band IS NULL) AS fail_count,
         'Q2 withdrawal patterns' AS business_question FROM s
  UNION ALL
  SELECT 2, 'region_not_null', 'NULL', 'Completeness', 'region',
         'region is populated for every enrolment', 0.00, 'WARN',
         COUNT(*), COUNT_IF(region IS NULL), 'Q2 withdrawal patterns' FROM s
  UNION ALL
  SELECT 3, 'final_result_not_null', 'NULL', 'Completeness', 'final_result',
         'every enrolment has an outcome recorded', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(final_result IS NULL), 'Q1 engagement vs performance' FROM s
  UNION ALL
  SELECT 4, 'id_student_not_null', 'NULL', 'Completeness', 'id_student',
         'every enrolment identifies a student', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(id_student IS NULL), 'Q3 activity through the course' FROM s
  UNION ALL
  SELECT 5, 'module_presentation_not_null', 'NULL', 'Completeness', 'code_module, code_presentation',
         'every enrolment names the module presentation it belongs to', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_module IS NULL OR code_presentation IS NULL),
         'Q3 activity through the course' FROM s

  -- ACCEPTED VALUES, 6 checks --------------------------------------------------
  UNION ALL
  SELECT 6, 'final_result_accepted_values', 'ACCEPTED VALUES', 'Validity', 'final_result',
         'final_result is Pass, Fail, Withdrawn or Distinction', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(final_result NOT IN ('Pass','Fail','Withdrawn','Distinction')),
         'Q1 engagement vs performance' FROM s
  UNION ALL
  SELECT 7, 'gender_accepted_values', 'ACCEPTED VALUES', 'Validity', 'gender',
         'gender is M or F', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(gender NOT IN ('M','F')), 'Q2 withdrawal patterns' FROM s
  UNION ALL
  SELECT 8, 'age_band_accepted_values', 'ACCEPTED VALUES', 'Validity', 'age_band',
         'age_band is 0-35, 35-55 or 55<=', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(age_band NOT IN ('0-35','35-55','55<=')),
         'Q2 withdrawal patterns' FROM s
  UNION ALL
  SELECT 9, 'disability_accepted_values', 'ACCEPTED VALUES', 'Validity', 'disability',
         'disability is Y or N', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(disability NOT IN ('Y','N')), 'Q2 withdrawal patterns' FROM s
  UNION ALL
  SELECT 10, 'imd_band_label_format', 'ACCEPTED VALUES', 'Consistency', 'imd_band',
         'every band label in the source carries the % sign', 15.00, 'WARN',
         COUNT(*), COUNT_IF(imd_band_raw RLIKE '^[0-9]+-[0-9]+$'),
         'Q2 withdrawal patterns' FROM s
  UNION ALL
  -- Regression test. This can only pass. That is the point: it proves the
  -- '?' to NULL rule actually ran. If someone drops that CASE branch, this turns.
  SELECT 11, 'imd_band_sentinel_removed', 'ACCEPTED VALUES', 'Consistency', 'imd_band',
         'the literal string ? never survives into the clean layer', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(imd_band = '?'), 'Q2 withdrawal patterns' FROM s

  -- RANGE, 4 checks ------------------------------------------------------------
  UNION ALL
  SELECT 12, 'studied_credits_positive', 'RANGE', 'Validity', 'studied_credits',
         'studied_credits is greater than zero', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(studied_credits <= 0), 'Q2 withdrawal patterns' FROM s
  UNION ALL
  SELECT 13, 'num_of_prev_attempts_not_negative', 'RANGE', 'Validity', 'num_of_prev_attempts',
         'num_of_prev_attempts is zero or more', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(num_of_prev_attempts < 0), 'Q2 withdrawal patterns' FROM s
  UNION ALL
  SELECT 14, 'studied_credits_within_p99', 'RANGE', 'Accuracy', 'studied_credits',
         'studied_credits is at or below the 99th percentile, 240', 1.00, 'WARN',
         COUNT(*), COUNT_IF(studied_credits > 240), 'Q2 withdrawal patterns' FROM s
  UNION ALL
  SELECT 15, 'num_of_prev_attempts_within_tail', 'RANGE', 'Accuracy', 'num_of_prev_attempts',
         '2 or fewer, which covers 99.4% of rows', 1.00, 'WARN',
         COUNT(*), COUNT_IF(num_of_prev_attempts > 2), 'Q2 withdrawal patterns' FROM s

  -- SCHEMA, 2 checks. The raw layer types these at read time, so this proves
  -- nothing was silently lost in the cast.
  UNION ALL
  SELECT 16, 'id_student_casts_to_int', 'SCHEMA', 'Validity', 'id_student',
         'every raw id_student survives the cast to INT', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(TRY_CAST(CAST(id_student AS STRING) AS INT) IS NULL),
         'Q3 activity through the course' FROM r
  UNION ALL
  SELECT 17, 'numeric_columns_cast_cleanly', 'SCHEMA', 'Validity', 'studied_credits, num_of_prev_attempts',
         'every numeric column casts without loss', 0.00, 'FAIL',
         COUNT(*),
         COUNT_IF(TRY_CAST(CAST(studied_credits AS STRING) AS INT) IS NULL
               OR TRY_CAST(CAST(num_of_prev_attempts AS STRING) AS INT) IS NULL),
         'Q2 withdrawal patterns' FROM r

  -- UNIQUE, 5 checks -----------------------------------------------------------
  UNION ALL
  SELECT 18, 'composite_key_unique', 'UNIQUE', 'Uniqueness', 'code_module, code_presentation, id_student',
         'the grain holds: one row per student per module presentation', 0.00, 'FAIL',
         COUNT(*), COUNT(*) - COUNT(DISTINCT code_module, code_presentation, id_student),
         'Q3 activity through the course' FROM s
  UNION ALL
  SELECT 19, 'enrolment_key_unique', 'UNIQUE', 'Uniqueness', 'enrolment_key',
         'the surrogate key is one to one with the composite key', 0.00, 'FAIL',
         COUNT(*), COUNT(*) - COUNT(DISTINCT enrolment_key),
         'Q3 activity through the course' FROM s
  UNION ALL
  -- NULL SAFETY. Read this one before copying it.
  --   COUNT(*) - COUNT(DISTINCT col1, col2, ... coln)
  -- is the obvious way to write this and it is wrong. COUNT(DISTINCT a, b, c)
  -- drops any row where ANY argument is NULL, so the moment imd_band's '?'
  -- sentinel became a proper NULL this check reported 1,111 duplicates that do
  -- not exist. It passed against raw and only broke after the cleaning worked.
  -- COUNT over a SELECT DISTINCT subquery treats NULL as a value and gives 0.
  SELECT 20, 'no_duplicate_full_rows', 'UNIQUE', 'Uniqueness', 'all source columns',
         'no two rows identical across every column, counted NULL-safely', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s)
         - (SELECT COUNT(*) FROM (
              SELECT DISTINCT code_module, code_presentation, id_student, gender, region,
                     highest_education, imd_band, age_band, num_of_prev_attempts,
                     studied_credits, disability, final_result FROM s) d),
         'Q3 activity through the course'
  UNION ALL
  SELECT 21, 'age_band_stable_per_student', 'UNIQUE', 'Consistency', 'age_band',
         'one age_band per student across presentations', 1.00, 'WARN',
         COUNT(*), COUNT_IF(age_bands_seen_for_student > 1),
         'Q2 withdrawal patterns' FROM s
  UNION ALL
  SELECT 22, 'one_row_per_student_after_collapse', 'UNIQUE', 'Uniqueness', 'id_student',
         'collapsing demographics yields one row per student', 1.00, 'WARN',
         (SELECT COUNT(DISTINCT id_student) FROM s),
         (SELECT COUNT(*) FROM (SELECT DISTINCT id_student, gender, region,
                 highest_education, imd_band, age_band, disability FROM s) d)
         - (SELECT COUNT(DISTINCT id_student) FROM s),
         'Q3 activity through the course'

  -- REFERENTIAL INTEGRITY, 1 check ---------------------------------------------
  UNION ALL
  SELECT 23, 'module_presentation_exists_in_courses', 'REFERENTIAL INTEGRITY', 'Referential integrity',
         'code_module, code_presentation', 'every enrolment points at a real presentation',
         0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s
          WHERE NOT EXISTS (SELECT 1 FROM oulad.raw.courses c
                            WHERE c.code_module = s.code_module
                              AND c.code_presentation = s.code_presentation)),
         'Q3 activity through the course'

  -- VOLUME, 2 checks -----------------------------------------------------------
  UNION ALL
  SELECT 24, 'clean_row_count_equals_raw', 'VOLUME', 'Completeness', 'table',
         'nothing lost or invented between layers', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM r),
         ABS((SELECT COUNT(*) FROM r) - (SELECT COUNT(*) FROM s)),
         'Q3 activity through the course'
  UNION ALL
  SELECT 25, 'row_count_within_expected_band', 'VOLUME', 'Completeness', 'table',
         'row count sits inside the expected 30k to 35k band for this file', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         CASE WHEN (SELECT COUNT(*) FROM s) BETWEEN 30000 AND 35000 THEN 0 ELSE 1 END,
         'Q3 activity through the course'
)

SELECT
  current_timestamp()                                          AS executed_at,
  'oulad.clean.student_info'                                   AS dataset,
  'clean'                                                      AS layer,
  check_id,
  check_name,
  check_type,
  dq_dimension,
  column_name,
  expectation,
  threshold_pct                                                AS threshold,
  severity,
  total_count,
  fail_count,
  ROUND(fail_count * 100.0 / NULLIF(total_count, 0), 4)        AS fail_pct,
  CASE
    WHEN fail_count = 0                                                    THEN 'PASS'
    WHEN fail_count * 100.0 / NULLIF(total_count, 0) > threshold_pct       THEN severity
    ELSE                                                                        'WARN'
  END                                                          AS status,
  business_question,
  'Kinah'                                                      AS owner
FROM checks
ORDER BY check_id;
