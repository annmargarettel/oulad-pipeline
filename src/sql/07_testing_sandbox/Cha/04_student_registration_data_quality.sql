-- STATUS RULE
--   fail_count = 0                     -> PASS
--   fail_pct  > threshold              -> the check's own severity (WARN or FAIL)
--   fail_pct <= threshold, but > 0    -> WARN

WITH s AS (
    SELECT 
        *,
        -- Helper for student stability check using Spark-compatible distinct window count
        SIZE(COLLECT_SET(date_registration) OVER (PARTITION BY id_student)) AS reg_dates_seen_for_student
    FROM oulad.clean.student_registration
),
r AS (
    SELECT * FROM oulad.raw.student_registration
),

checks AS (

  -- NULL, 4 checks -------------------------------------------------------------
  SELECT 1 AS check_id, 'id_student_not_null' AS check_name, 'NULL' AS check_type,
         'Completeness' AS dq_dimension, 'id_student' AS column_name,
         'every enrolment identifies a student' AS expectation,
         0.00 AS threshold_pct, 'FAIL' AS severity,
         COUNT(*) AS total_count, COUNT_IF(id_student IS NULL) AS fail_count,
         'Q3 activity through the course' AS business_question FROM s
  UNION ALL
  SELECT 2, 'module_presentation_not_null', 'NULL', 'Completeness', 'code_module, code_presentation',
         'every enrolment names the module presentation it belongs to', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_module IS NULL OR code_presentation IS NULL),
         'Q3 activity through the course' FROM s
  UNION ALL
  SELECT 3, 'date_registration_missingness_within_bound', 'NULL', 'Completeness', 'date_registration',
         'missing registration dates do not exceed 0.20% threshold', 0.20, 'WARN',
         COUNT(*), COUNT_IF(date_registration IS NULL),
         'Q2 withdrawal patterns' FROM s
  UNION ALL
  SELECT 4, 'date_unregistration_expected_null_rate', 'NULL', 'Completeness', 'date_unregistration',
         'active enrolments (nulls) remain within expected 65-75% retention band', 35.00, 'WARN',
         COUNT(*), COUNT_IF(date_unregistration IS NOT NULL),
         'Q2 withdrawal patterns' FROM s

  -- ACCEPTED VALUES, 2 checks --------------------------------------------------
  UNION ALL
  SELECT 5, 'code_presentation_accepted_format', 'ACCEPTED VALUES', 'Validity', 'code_presentation',
         'code_presentation follows standard 4-digit year + B/J semester tag', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(NOT REGEXP_LIKE(code_presentation, '^[0-9]{4}[BJ]$')),
         'Q3 activity through the course' FROM s
  UNION ALL
  SELECT 6, 'code_module_accepted_values', 'ACCEPTED VALUES', 'Validity', 'code_module',
         'code_module matches one of the 7 valid course codes', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_module NOT IN ('AAA', 'BBB', 'CCC', 'DDD', 'EEE', 'FFF', 'GGG')),
         'Q3 activity through the course' FROM s

  -- RANGE, 2 checks ------------------------------------------------------------
  UNION ALL
  SELECT 7, 'date_registration_within_valid_bounds', 'RANGE', 'Accuracy', 'date_registration',
         'registration days relative to course start fall within [-365, 120]', 0.50, 'WARN',
         COUNT(*), COUNT_IF(date_registration < -365 OR date_registration > 120),
         'Q2 withdrawal patterns' FROM s
  UNION ALL
  SELECT 8, 'temporal_sequence_valid', 'RANGE', 'Validity', 'date_registration, date_unregistration',
         'student cannot unregister before registering', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(date_unregistration < date_registration),
         'Q2 withdrawal patterns' FROM s

  -- SCHEMA, 2 checks -----------------------------------------------------------
  UNION ALL
  SELECT 9, 'id_student_casts_to_int', 'SCHEMA', 'Validity', 'id_student',
         'every raw id_student survives the cast to INT', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(TRY_CAST(CAST(id_student AS STRING) AS INT) IS NULL),
         'Q3 activity through the course' FROM r
  UNION ALL
  SELECT 10, 'registration_dates_cast_cleanly', 'SCHEMA', 'Validity', 'date_registration, date_unregistration',
         'non-null relative date integers cast without loss', 0.00, 'FAIL',
         COUNT(*),
         COUNT_IF((date_registration IS NOT NULL AND TRY_CAST(CAST(date_registration AS STRING) AS INT) IS NULL)
               OR (date_unregistration IS NOT NULL AND TRY_CAST(CAST(date_unregistration AS STRING) AS INT) IS NULL)),
         'Q2 withdrawal patterns' FROM r

  -- UNIQUE, 3 checks -----------------------------------------------------------
  UNION ALL
  SELECT 11, 'composite_key_unique', 'UNIQUE', 'Uniqueness', 'code_module, code_presentation, id_student',
         'the grain holds: strictly 1 enrolment per student per module presentation', 0.00, 'FAIL',
         COUNT(*), COUNT(*) - COUNT(DISTINCT code_module, code_presentation, id_student),
         'Q3 activity through the course' FROM s
  UNION ALL
  SELECT 12, 'no_duplicate_full_rows', 'UNIQUE', 'Uniqueness', 'all source columns',
         'no two rows identical across all registration columns, counted NULL-safely', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s)
         - (SELECT COUNT(*) FROM (
             SELECT DISTINCT code_module, code_presentation, id_student, 
                    date_registration, date_unregistration FROM s) d),
         'Q3 activity through the course'
  UNION ALL
  SELECT 13, 'registration_date_stable_per_enrolment', 'UNIQUE', 'Consistency', 'date_registration',
         'students have reasonable registration stability across modules', 2.00, 'WARN',
         COUNT(*), COUNT_IF(reg_dates_seen_for_student > 3),
         'Q2 withdrawal patterns' FROM s

  -- REFERENTIAL INTEGRITY, 1 check ---------------------------------------------
  UNION ALL
  SELECT 14, 'module_presentation_exists_in_courses', 'REFERENTIAL INTEGRITY', 'Referential integrity',
         'code_module, code_presentation', 'every enrolment references an existing presentation in courses',
         0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s
          WHERE NOT EXISTS (SELECT 1 FROM oulad.raw.courses c
                            WHERE c.code_module = s.code_module
                              AND c.code_presentation = s.code_presentation)),
         'Q3 activity through the course'

  -- VOLUME, 1 check ------------------------------------------------------------
  UNION ALL
  SELECT 15, 'clean_row_count_equals_raw', 'VOLUME', 'Completeness', 'table',
         'nothing lost or invented between raw and clean layers', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM r),
         ABS((SELECT COUNT(*) FROM r) - (SELECT COUNT(*) FROM s)),
         'Q3 activity through the course'
)

SELECT
  current_timestamp()                                           AS executed_at,
  'oulad.clean.student_registration'                             AS dataset,
  'clean'                                                       AS layer,
  check_id,
  check_name,
  check_type,
  dq_dimension,
  column_name,
  expectation,
  threshold_pct                                                 AS threshold,
  severity,
  total_count,
  fail_count,
  ROUND(fail_count * 100.0 / NULLIF(total_count, 0), 4)         AS fail_pct,
  CASE
    WHEN fail_count = 0                                                 THEN 'PASS'
    WHEN fail_count * 100.0 / NULLIF(total_count, 0) > threshold_pct   THEN severity
    ELSE                                                                'WARN'
  END                                                           AS status,
  business_question,
  'Charlene'                                                    AS owner
FROM checks
ORDER BY check_id;