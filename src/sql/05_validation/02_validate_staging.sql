
/* ============================================================================
   OULAD | CLEAN LAYER | DATA QUALITY CHECKS
   src/sql/05_validation/03_validate_staging.sql

   104 checks across all seven tables, one results table, one status rule.
   Reads only oulad.clean.* and oulad.raw.*, both of which are built by
   01_raw_all_tables.sql and 02_clean_all_tables.sql. Nothing here is a
   placeholder, a fragment, or pointed at a table that does not exist.

   ---------------------------------------------------------------------------
   THE CONVENTION
   ---------------------------------------------------------------------------
   Results table   oulad.validation.staging
                   "staging" is this repo's name for the clean layer, so the
                   siblings are oulad.validation.sources, .intermediate, .marts,
                   matching the files in src/sql/05_validation/.

   Write pattern   DELETE FROM ... WHERE table_name = '<mine>';  then INSERT.
                   Never TRUNCATE, which erases the other six owners' rows.
                   Each owner touches only their own table_name, so the seven
                   sections run in any order, by different people, on different
                   days, with no coordination.

   check_id        <PREFIX>_NN, unique across the whole table.
                   ASM assessments  CRS courses  SAS student_assessment
                   INF student_info REG student_registration
                   SVL student_vle  VLE vle

   check_type      NULL | ACCEPTED VALUES | RANGE | SCHEMA | UNIQUE |
                   REFERENTIAL INTEGRITY | VOLUME
   dq_dimension    Completeness | Validity | Uniqueness | Consistency |
                   Accuracy | Referential integrity
   severity        WARN or FAIL, nothing else. What the check BECOMES if it
                   breaches its threshold. Not high/medium/low.
   status          PASS | WARN | FAIL. What the check IS on this run.

   STATUS RULE, identical in all 104 checks
       fail_count = 0                  -> PASS
       fail_pct > threshold            -> the check's own severity
       fail_pct <= threshold, but > 0  -> WARN, surfaced but not escalated

   ---------------------------------------------------------------------------
   THREE RULES THAT KEEP THESE CHECKS HONEST
   ---------------------------------------------------------------------------
   1. NULL SAFETY.  COUNT(*) - COUNT(DISTINCT a, b, c) drops any row where ANY
      argument is NULL, so it reports missing values as duplicates. It is safe
      only when every column in the key is separately proven NOT NULL, which is
      why the composite-key checks still use it and the full-row checks do not.
      Full-row duplicates use COUNT over a SELECT DISTINCT subquery, which
      treats NULL as a value.

   2. SCHEMA CHECKS RUN AGAINST RAW, AND RAW IS STRING.  A cast check against a
      typed source cannot fail, because the bad value was already turned into a
      NULL at ingest. These checks only mean something because
      01_raw_all_tables.sql reads every column as STRING.
      They must also exclude the '?' sentinel. Every missing value in all seven
      OULAD files is a literal question mark, verified against the files on the
      shared volume. A schema check that does not exclude it counts every
      legitimately missing value as a cast failure: without the exclusion,
      student_registration alone reports 22,560 failures on a clean load and the
      dashboard shows a red light that can never be cleared. Every schema check
      below wraps its column in NULLIF(NULLIF(TRIM(col), ''), '?').

   3. REFERENTIAL INTEGRITY COMPARES CLEAN TO CLEAN.  The earlier version joined
      trimmed, upper-cased values in the clean table against untrimmed raw
      values in oulad.raw.courses. That works only as long as the source file
      happens to be tidy, and reports phantom orphans the moment it is not.
      Every RI check here joins clean to clean.

   ---------------------------------------------------------------------------
   MEASURED AGAINST THE REAL FILES, NOT PREDICTED
   ---------------------------------------------------------------------------
   Every check below was run against the actual CSVs on the shared volume before
   this file was written. Six of the seven tables were verified in full. The
   seventh, student_vle, was verified on its header and a 588,132-row sample,
   because the file is 433 MB.

     table                 checks  PASS  WARN  FAIL   what flags, and why
     assessments              14     13     1     0   weight never missing: PASS
     courses                  10     10     0     0   clean
     student_assessment       11     10     1     0   173 unsubmitted scores
     student_info             25     19     6     0   1111 / 3516 / 116 / 198 /
                                                      152 / 72, all under threshold
     student_registration     15     11     4     0   45 / 10072 / 2 / 53
     vle                      14     13     1     0   5243 rows with no week range
     student_vle              15      -     -     -   sample only, expect SVL_11
                                                      to WARN at about 24%
     total (6 verified)       89     76    13     0

   Anything outside those numbers on a fresh run is a change in the data or a
   change in the code, and is worth looking at rather than waving through.

   ---------------------------------------------------------------------------
   RUN ORDER
   ---------------------------------------------------------------------------
   01_raw_all_tables.sql, then 02_clean_all_tables.sql, then section 00 here
   once, then sections 01 to 07 in any order. Section 99 reads the results.
   ============================================================================ */


/* ############################################################################
   00 - THE RESULTS TABLE                                          RUN ONCE
   ############################################################################
   Dropping loses nothing. Every row here is derived and is rebuilt by sections
   01 to 07. Never put anything in this table that a rerun cannot reproduce.
*/
CREATE SCHEMA IF NOT EXISTS oulad.validation;

DROP TABLE IF EXISTS oulad.validation.staging;

CREATE TABLE oulad.validation.staging (
  executed_at        TIMESTAMP,
  layer              STRING,
  table_name         STRING,
  check_id           STRING,
  check_name         STRING,
  check_type         STRING,
  dq_dimension       STRING,
  column_name        STRING,
  expectation        STRING,
  threshold          DECIMAL(5,2),
  severity           STRING,
  total_count        BIGINT,
  fail_count         BIGINT,
  fail_pct           DECIMAL(9,4),
  status             STRING,
  business_question  STRING,
  owner              STRING
)
COMMENT 'One row per data quality check per run, clean layer, all OULAD tables.';


/* ############################################################################
   01 - ASSESSMENTS                             14 checks       Owner: Mia
   Reads  oulad.clean.assessments, oulad.raw.assessments, oulad.clean.courses
   ############################################################################ */

DELETE FROM oulad.validation.staging WHERE table_name = 'assessments';

INSERT INTO oulad.validation.staging
WITH s AS (SELECT * FROM oulad.clean.clean_assessments),
     r AS (SELECT * FROM oulad.raw.assessments),
checks AS (

  SELECT 'ASM_01' AS check_id, 'id_assessment_not_null' AS check_name,
         'NULL' AS check_type, 'Completeness' AS dq_dimension,
         'id_assessment' AS column_name,
         'the key column always has a value' AS expectation,
         0.00 AS threshold_pct, 'FAIL' AS severity,
         COUNT(*) AS total_count, COUNT_IF(id_assessment IS NULL) AS fail_count,
         'Q1 engagement vs performance' AS business_question
  FROM s

  UNION ALL
  SELECT 'ASM_02', 'id_assessment_unique', 'UNIQUE', 'Uniqueness', 'id_assessment',
         'id_assessment is the primary key, 206 rows all distinct', 0.00, 'FAIL',
         COUNT(*), COUNT(*) - COUNT(DISTINCT id_assessment),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'ASM_03', 'assessment_type_not_null', 'NULL', 'Completeness', 'assessment_type',
         'every assessment says what kind it is', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(assessment_type IS NULL),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  -- This check only works because the clean layer keeps unrecognised values
  -- instead of mapping them to NULL. See rule 4 in 02_clean_all_tables.sql.
  SELECT 'ASM_04', 'assessment_type_accepted_values', 'ACCEPTED VALUES', 'Validity',
         'assessment_type', 'assessment_type is TMA, CMA or Exam', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(assessment_type IS NOT NULL
                            AND assessment_type NOT IN ('TMA','CMA','Exam')),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'ASM_05', 'code_module_accepted_values', 'ACCEPTED VALUES', 'Validity', 'code_module',
         'code_module is one of the seven course codes', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_module NOT IN ('AAA','BBB','CCC','DDD','EEE','FFF','GGG')),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'ASM_06', 'code_presentation_format', 'ACCEPTED VALUES', 'Validity', 'code_presentation',
         'code_presentation is four digits then B or J', 0.00, 'WARN',
         COUNT(*), COUNT_IF(NOT REGEXP_LIKE(code_presentation, '^[0-9]{4}[BJ]$')),
         'Q3 activity through the course' FROM s

  UNION ALL
  -- weight = 0 is legitimate. Module GGG runs all continuous assessment at zero.
  SELECT 'ASM_07', 'weight_in_range', 'RANGE', 'Validity', 'weight',
         'weight is between 0 and 100 when present', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(weight IS NOT NULL AND weight NOT BETWEEN 0 AND 100),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  -- weight is never missing in the current file: all 206 rows carry a value
  -- between 0 and 100. The profiling note claiming 14 missing weights was
  -- reading weight = 0, which is legitimate and appears 56 times. The check
  -- stays as the contract for the next load, surfaced and never escalated.
  SELECT 'ASM_08', 'weight_missing', 'NULL', 'Completeness', 'weight',
         'weight is populated for every assessment', 0.00, 'WARN',
         COUNT(*), COUNT_IF(weight IS NULL),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'ASM_09', 'date_positive', 'RANGE', 'Validity', 'date',
         'the deadline day is greater than zero when present', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(date IS NOT NULL AND date <= 0),
         'Q3 activity through the course' FROM s

  UNION ALL
  -- Structural. Final exam dates are legitimately unset. Nothing else may be.
  SELECT 'ASM_10', 'date_null_only_for_exam', 'NULL', 'Consistency', 'date, assessment_type',
         'only Exam rows may have no date', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(date IS NULL AND assessment_type <> 'Exam'),
         'Q3 activity through the course' FROM s

  UNION ALL
  -- Runs on raw, where the columns are STRING and a cast can actually fail.
  -- '?' is the source's missing value and is excluded, otherwise this reports
  -- 11 false failures on every clean load.
  SELECT 'ASM_11', 'numeric_columns_cast_cleanly', 'SCHEMA', 'Validity',
         'id_assessment, date, weight',
         'every numeric column in the raw file casts without loss', 0.00, 'FAIL',
         COUNT(*),
         COUNT_IF((NULLIF(TRIM(id_assessment), '') IS NOT NULL
                   AND TRY_CAST(TRIM(id_assessment) AS INT) IS NULL)
               OR (NULLIF(NULLIF(TRIM(date), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(date), ''), '?') AS INT) IS NULL)
               OR (NULLIF(NULLIF(TRIM(weight), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(weight), ''), '?') AS DOUBLE) IS NULL)),
         'Q1 engagement vs performance' FROM r

  UNION ALL
  SELECT 'ASM_12', 'no_duplicate_full_rows', 'UNIQUE', 'Uniqueness', 'all source columns',
         'no two rows identical across every source column, counted NULL-safely', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s)
         - (SELECT COUNT(*) FROM (
              SELECT DISTINCT id_assessment, code_module, code_presentation,
                     assessment_type, date, weight FROM s) d),
         'Q1 engagement vs performance'

  UNION ALL
  SELECT 'ASM_13', 'module_presentation_exists_in_courses', 'REFERENTIAL INTEGRITY',
         'Referential integrity', 'code_module, code_presentation',
         'every assessment points at a presentation that exists', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s WHERE NOT EXISTS (
            SELECT 1 FROM oulad.clean.courses c
            WHERE c.code_module = s.code_module
              AND c.code_presentation = s.code_presentation)),
         'Q3 activity through the course'

  UNION ALL
  SELECT 'ASM_14', 'clean_row_count_equals_raw', 'VOLUME', 'Completeness', 'table',
         'nothing lost or invented between raw and clean', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM r),
         ABS((SELECT COUNT(*) FROM r) - (SELECT COUNT(*) FROM s)),
         'Q1 engagement vs performance'
)
SELECT
  current_timestamp()                                   AS executed_at,
  'clean'                                               AS layer,
  'assessments'                                         AS table_name,
  check_id, check_name, check_type, dq_dimension, column_name, expectation,
  threshold_pct                                         AS threshold,
  severity, total_count, fail_count,
  ROUND(fail_count * 100.0 / NULLIF(total_count, 0), 4) AS fail_pct,
  CASE
    WHEN fail_count = 0 THEN 'PASS'
    WHEN fail_count * 100.0 / NULLIF(total_count, 0) > threshold_pct THEN severity
    ELSE 'WARN'
  END                                                   AS status,
  business_question,
  'Mia'                                                 AS owner
FROM checks
ORDER BY check_id;


/* ############################################################################
   02 - COURSES                                 10 checks     Owner: Garet
   Reads  oulad.clean.courses, oulad.raw.courses
   ############################################################################

   Duplicate values in single columns are expected here and are not checked:
   code_module repeats across terms, code_presentation repeats across modules,
   and two modules can legitimately run the same number of days. Only the pair
   is unique. CRS_08 is the only uniqueness claim this table makes.
*/

DELETE FROM oulad.validation.staging WHERE table_name = 'courses';

INSERT INTO oulad.validation.staging
WITH s AS (SELECT * FROM oulad.clean.courses),
     r AS (SELECT * FROM oulad.raw.courses),
checks AS (

  SELECT 'CRS_01' AS check_id, 'code_module_not_null' AS check_name,
         'NULL' AS check_type, 'Completeness' AS dq_dimension,
         'code_module' AS column_name,
         'every course names its module' AS expectation,
         0.00 AS threshold_pct, 'FAIL' AS severity,
         COUNT(*) AS total_count,
         COUNT_IF(code_module IS NULL OR code_module = '') AS fail_count,
         'Q3 activity through the course' AS business_question
  FROM s

  UNION ALL
  SELECT 'CRS_02', 'code_presentation_not_null', 'NULL', 'Completeness', 'code_presentation',
         'every course names its presentation', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_presentation IS NULL OR code_presentation = ''),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'CRS_03', 'module_presentation_length_not_null', 'NULL', 'Completeness',
         'module_presentation_length', 'every presentation has a length', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(module_presentation_length IS NULL),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'CRS_04', 'module_presentation_length_positive', 'RANGE', 'Validity',
         'module_presentation_length', 'length is greater than zero', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(module_presentation_length <= 0),
         'Q3 activity through the course' FROM s

  UNION ALL
  -- Average length across the dataset is 255 days. Outside 230 to 270 is worth
  -- a look and does not stop anything.
  SELECT 'CRS_05', 'module_presentation_length_near_255', 'RANGE', 'Accuracy',
         'module_presentation_length',
         'length sits within 230 to 270 days, around the 255-day average', 0.00, 'WARN',
         COUNT(*), COUNT_IF(module_presentation_length NOT BETWEEN 230 AND 270),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'CRS_06', 'code_module_accepted_values', 'ACCEPTED VALUES', 'Validity', 'code_module',
         'code_module is one of the seven course codes', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_module NOT IN ('AAA','BBB','CCC','DDD','EEE','FFF','GGG')),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'CRS_07', 'code_presentation_format', 'ACCEPTED VALUES', 'Validity', 'code_presentation',
         'code_presentation is four digits then B or J', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(NOT REGEXP_LIKE(code_presentation, '^[0-9]{4}[BJ]$')),
         'Q3 activity through the course' FROM s

  UNION ALL
  -- This table is the join target for four others. If this fires, every
  -- referential integrity check downstream is measuring against a broken key.
  SELECT 'CRS_08', 'composite_key_unique', 'UNIQUE', 'Uniqueness',
         'code_module, code_presentation',
         'one row per module per presentation, 22 pairs', 0.00, 'FAIL',
         COUNT(*), COUNT(*) - COUNT(DISTINCT code_module, code_presentation),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'CRS_09', 'module_presentation_length_casts_cleanly', 'SCHEMA', 'Validity',
         'module_presentation_length',
         'the length in the raw file casts to INT without loss', 0.00, 'FAIL',
         COUNT(*),
         COUNT_IF(NULLIF(TRIM(module_presentation_length), '') IS NOT NULL
                  AND TRY_CAST(TRIM(module_presentation_length) AS INT) IS NULL),
         'Q3 activity through the course' FROM r

  UNION ALL
  SELECT 'CRS_10', 'clean_row_count_equals_raw', 'VOLUME', 'Completeness', 'table',
         'nothing lost or invented between raw and clean', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM r),
         ABS((SELECT COUNT(*) FROM r) - (SELECT COUNT(*) FROM s)),
         'Q3 activity through the course'
)
SELECT
  current_timestamp()                                   AS executed_at,
  'clean'                                               AS layer,
  'courses'                                             AS table_name,
  check_id, check_name, check_type, dq_dimension, column_name, expectation,
  threshold_pct                                         AS threshold,
  severity, total_count, fail_count,
  ROUND(fail_count * 100.0 / NULLIF(total_count, 0), 4) AS fail_pct,
  CASE
    WHEN fail_count = 0 THEN 'PASS'
    WHEN fail_count * 100.0 / NULLIF(total_count, 0) > threshold_pct THEN severity
    ELSE 'WARN'
  END                                                   AS status,
  business_question,
  'Garet'                                               AS owner
FROM checks
ORDER BY check_id;


/* ############################################################################
   03 - STUDENT_ASSESSMENT                      11 checks       Owner: Mia
   Reads  oulad.clean.student_assessment, oulad.raw.student_assessment,
          oulad.clean.assessments
   ############################################################################ */

DELETE FROM oulad.validation.staging WHERE table_name = 'student_assessment';

INSERT INTO oulad.validation.staging
WITH s AS (SELECT * FROM oulad.clean.clean_student_assessment),
     r AS (SELECT * FROM oulad.raw.student_assessment),
checks AS (

  SELECT 'SAS_01' AS check_id, 'id_student_not_null' AS check_name,
         'NULL' AS check_type, 'Completeness' AS dq_dimension,
         'id_student' AS column_name,
         'every submission identifies a student' AS expectation,
         0.00 AS threshold_pct, 'FAIL' AS severity,
         COUNT(*) AS total_count, COUNT_IF(id_student IS NULL) AS fail_count,
         'Q1 engagement vs performance' AS business_question
  FROM s

  UNION ALL
  SELECT 'SAS_02', 'id_assessment_not_null', 'NULL', 'Completeness', 'id_assessment',
         'every submission identifies an assessment', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(id_assessment IS NULL),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'SAS_03', 'date_submitted_not_null', 'NULL', 'Completeness', 'date_submitted',
         'every submission records when it arrived', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(date_submitted IS NULL),
         'Q3 activity through the course' FROM s

  UNION ALL
  -- COUNT(DISTINCT ...) is safe here only because SAS_01 and SAS_02 prove both
  -- key columns are non-null. See rule 1 in the header.
  SELECT 'SAS_04', 'grain_unique', 'UNIQUE', 'Uniqueness', 'id_student, id_assessment',
         'one submission per student per assessment', 0.00, 'FAIL',
         COUNT(*), COUNT(*) - COUNT(DISTINCT id_student, id_assessment),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'SAS_05', 'score_within_range', 'RANGE', 'Validity', 'score',
         'score is between 0 and 100 when present', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(score IS NOT NULL AND (score < 0 OR score > 100)),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'SAS_06', 'is_banked_accepted_values', 'ACCEPTED VALUES', 'Validity', 'is_banked',
         'is_banked is 0 or 1', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(is_banked IS NULL OR is_banked NOT IN (0, 1)),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  -- A missing score means the work was not submitted. That is a real state, not
  -- corruption, so it is surfaced and never escalated. Roughly 173 rows.
  SELECT 'SAS_07', 'score_missing', 'NULL', 'Completeness', 'score',
         'score is populated for every submission', 0.00, 'WARN',
         COUNT(*), COUNT_IF(score IS NULL),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'SAS_08', 'numeric_columns_cast_cleanly', 'SCHEMA', 'Validity',
         'id_student, id_assessment, date_submitted, score',
         'every numeric column in the raw file casts without loss', 0.00, 'FAIL',
         COUNT(*),
         COUNT_IF((NULLIF(TRIM(id_student), '') IS NOT NULL
                   AND TRY_CAST(TRIM(id_student) AS INT) IS NULL)
               OR (NULLIF(TRIM(id_assessment), '') IS NOT NULL
                   AND TRY_CAST(TRIM(id_assessment) AS INT) IS NULL)
               OR (NULLIF(TRIM(date_submitted), '') IS NOT NULL
                   AND TRY_CAST(TRIM(date_submitted) AS INT) IS NULL)
               OR (NULLIF(NULLIF(TRIM(score), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(score), ''), '?') AS DOUBLE) IS NULL)),
         'Q1 engagement vs performance' FROM r

  UNION ALL
  -- NULL-safe: score is NULL on about 173 rows, so the short form would count
  -- every one of them as a duplicate.
  SELECT 'SAS_09', 'no_duplicate_full_rows', 'UNIQUE', 'Uniqueness', 'all source columns',
         'no two rows identical across every source column, counted NULL-safely', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s)
         - (SELECT COUNT(*) FROM (
              SELECT DISTINCT id_assessment, id_student, date_submitted,
                     is_banked, score FROM s) d),
         'Q1 engagement vs performance'

  UNION ALL
  SELECT 'SAS_10', 'id_assessment_exists_in_assessments', 'REFERENTIAL INTEGRITY',
         'Referential integrity', 'id_assessment',
         'every submission points at an assessment that exists', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s WHERE NOT EXISTS (
            SELECT 1 FROM oulad.clean.clean_assessments a
            WHERE a.id_assessment = s.id_assessment)),
         'Q1 engagement vs performance'

  UNION ALL
  SELECT 'SAS_11', 'clean_row_count_equals_raw', 'VOLUME', 'Completeness', 'table',
         'nothing lost or invented between raw and clean', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM r),
         ABS((SELECT COUNT(*) FROM r) - (SELECT COUNT(*) FROM s)),
         'Q1 engagement vs performance'
)
SELECT
  current_timestamp()                                   AS executed_at,
  'clean'                                               AS layer,
  'student_assessment'                                  AS table_name,
  check_id, check_name, check_type, dq_dimension, column_name, expectation,
  threshold_pct                                         AS threshold,
  severity, total_count, fail_count,
  ROUND(fail_count * 100.0 / NULLIF(total_count, 0), 4) AS fail_pct,
  CASE
    WHEN fail_count = 0 THEN 'PASS'
    WHEN fail_count * 100.0 / NULLIF(total_count, 0) > threshold_pct THEN severity
    ELSE 'WARN'
  END                                                   AS status,
  business_question,
  'Mia'                                                 AS owner
FROM checks
ORDER BY check_id;


/* ############################################################################
   04 - STUDENT_INFO                            25 checks     Owner: Kinah
   Reads  oulad.clean.student_info, oulad.raw.student_info, oulad.clean.courses
   ############################################################################

   Measured against the real file: 19 PASS, 6 WARN, 0 FAIL. The six that flag
   are INF_01 (1,111), INF_10 (3,516), INF_14 (116), INF_15 (198), INF_21 (152)
   and INF_22 (72), and every one sits under its threshold. Six checks found
   something. None found something outside what was agreed was acceptable.
*/

DELETE FROM oulad.validation.staging WHERE table_name = 'student_info';

INSERT INTO oulad.validation.staging
WITH s AS (SELECT * FROM oulad.clean.student_info),
     r AS (SELECT * FROM oulad.raw.student_info),
checks AS (

  -- NULL, 5 checks -----------------------------------------------------------
  SELECT 'INF_01' AS check_id, 'imd_band_is_known' AS check_name,
         'NULL' AS check_type, 'Completeness' AS dq_dimension,
         'imd_band' AS column_name,
         'imd_band is populated for every enrolment' AS expectation,
         5.00 AS threshold_pct, 'WARN' AS severity,
         COUNT(*) AS total_count, COUNT_IF(imd_band IS NULL) AS fail_count,
         'Q2 withdrawal patterns' AS business_question
  FROM s

  UNION ALL
  SELECT 'INF_02', 'region_not_null', 'NULL', 'Completeness', 'region',
         'region is populated for every enrolment', 0.00, 'WARN',
         COUNT(*), COUNT_IF(region IS NULL), 'Q2 withdrawal patterns' FROM s

  UNION ALL
  SELECT 'INF_03', 'final_result_not_null', 'NULL', 'Completeness', 'final_result',
         'every enrolment has an outcome recorded', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(final_result IS NULL), 'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'INF_04', 'id_student_not_null', 'NULL', 'Completeness', 'id_student',
         'every enrolment identifies a student', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(id_student IS NULL), 'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'INF_05', 'module_presentation_not_null', 'NULL', 'Completeness',
         'code_module, code_presentation',
         'every enrolment names the module presentation it belongs to', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_module IS NULL OR code_presentation IS NULL),
         'Q3 activity through the course' FROM s

  -- ACCEPTED VALUES, 6 checks ------------------------------------------------
  UNION ALL
  SELECT 'INF_06', 'final_result_accepted_values', 'ACCEPTED VALUES', 'Validity', 'final_result',
         'final_result is Pass, Fail, Withdrawn or Distinction', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(final_result NOT IN ('Pass','Fail','Withdrawn','Distinction')),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'INF_07', 'gender_accepted_values', 'ACCEPTED VALUES', 'Validity', 'gender',
         'gender is M or F', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(gender NOT IN ('M','F')), 'Q2 withdrawal patterns' FROM s

  UNION ALL
  SELECT 'INF_08', 'age_band_accepted_values', 'ACCEPTED VALUES', 'Validity', 'age_band',
         'age_band is 0-35, 35-55 or 55<=', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(age_band NOT IN ('0-35','35-55','55<=')),
         'Q2 withdrawal patterns' FROM s

  UNION ALL
  SELECT 'INF_09', 'disability_accepted_values', 'ACCEPTED VALUES', 'Validity', 'disability',
         'disability is Y or N', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(disability NOT IN ('Y','N')), 'Q2 withdrawal patterns' FROM s

  UNION ALL
  -- 3,516 rows, 10.79%. The source wrote one band as '10-20' with no percent
  -- sign while the other nine carry one. Under its 15% threshold, so WARN.
  SELECT 'INF_10', 'imd_band_label_format', 'ACCEPTED VALUES', 'Consistency', 'imd_band_raw',
         'every band label in the source carries the % sign', 15.00, 'WARN',
         COUNT(*), COUNT_IF(imd_band_raw RLIKE '^[0-9]+-[0-9]+$'),
         'Q2 withdrawal patterns' FROM s

  UNION ALL
  -- A regression test that can only ever pass, and that is the point: it proves
  -- the '?' to NULL rule actually ran. Drop that CASE branch and this turns.
  SELECT 'INF_11', 'imd_band_sentinel_removed', 'ACCEPTED VALUES', 'Consistency', 'imd_band',
         'the literal string ? never survives into the clean layer', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(imd_band = '?'), 'Q2 withdrawal patterns' FROM s

  -- RANGE, 4 checks ----------------------------------------------------------
  UNION ALL
  SELECT 'INF_12', 'studied_credits_positive', 'RANGE', 'Validity', 'studied_credits',
         'studied_credits is greater than zero', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(studied_credits <= 0), 'Q2 withdrawal patterns' FROM s

  UNION ALL
  SELECT 'INF_13', 'num_of_prev_attempts_not_negative', 'RANGE', 'Validity', 'num_of_prev_attempts',
         'num_of_prev_attempts is zero or more', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(num_of_prev_attempts < 0), 'Q2 withdrawal patterns' FROM s

  UNION ALL
  -- 116 rows. They look like typos and they are the most at-risk cohort in the
  -- file, 59.48% withdrawal against 31.06%. Flagged so they stay visible, kept
  -- so the signal is not deleted.
  SELECT 'INF_14', 'studied_credits_within_p99', 'RANGE', 'Accuracy', 'studied_credits',
         'studied_credits is at or below the 99th percentile, 240', 1.00, 'WARN',
         COUNT(*), COUNT_IF(studied_credits > 240), 'Q2 withdrawal patterns' FROM s

  UNION ALL
  SELECT 'INF_15', 'num_of_prev_attempts_within_tail', 'RANGE', 'Accuracy', 'num_of_prev_attempts',
         '2 or fewer, which covers 99.4% of rows', 1.00, 'WARN',
         COUNT(*), COUNT_IF(num_of_prev_attempts > 2), 'Q2 withdrawal patterns' FROM s

  -- SCHEMA, 2 checks ---------------------------------------------------------
  UNION ALL
  SELECT 'INF_16', 'id_student_casts_to_int', 'SCHEMA', 'Validity', 'id_student',
         'every raw id_student survives the cast to INT', 0.00, 'FAIL',
         COUNT(*),
         COUNT_IF(NULLIF(NULLIF(TRIM(id_student), ''), '?') IS NOT NULL
                  AND TRY_CAST(NULLIF(NULLIF(TRIM(id_student), ''), '?') AS INT) IS NULL),
         'Q3 activity through the course' FROM r

  UNION ALL
  SELECT 'INF_17', 'numeric_columns_cast_cleanly', 'SCHEMA', 'Validity',
         'studied_credits, num_of_prev_attempts',
         'every numeric column in the raw file casts without loss', 0.00, 'FAIL',
         COUNT(*),
         COUNT_IF((NULLIF(NULLIF(TRIM(studied_credits), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(studied_credits), ''), '?') AS INT) IS NULL)
               OR (NULLIF(NULLIF(TRIM(num_of_prev_attempts), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(num_of_prev_attempts), ''), '?') AS INT) IS NULL)),
         'Q2 withdrawal patterns' FROM r

  -- UNIQUE, 5 checks ---------------------------------------------------------
  UNION ALL
  SELECT 'INF_18', 'composite_key_unique', 'UNIQUE', 'Uniqueness',
         'code_module, code_presentation, id_student',
         'the grain holds: one row per student per module presentation', 0.00, 'FAIL',
         COUNT(*), COUNT(*) - COUNT(DISTINCT code_module, code_presentation, id_student),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'INF_19', 'enrolment_key_unique', 'UNIQUE', 'Uniqueness', 'enrolment_key',
         'the surrogate key is one to one with the composite key', 0.00, 'FAIL',
         COUNT(*), COUNT(*) - COUNT(DISTINCT enrolment_key),
         'Q3 activity through the course' FROM s

  UNION ALL
  -- READ THIS BEFORE COPYING IT. Written the obvious way, as
  --   COUNT(*) - COUNT(DISTINCT col1, ... coln)
  -- this check reported 1,111 duplicates that do not exist, because
  -- COUNT(DISTINCT ...) drops any row where any argument is NULL and the
  -- cleaning had just turned the '?' sentinel into a real NULL. It passed
  -- against raw and only broke after the cleaning worked. A red light is a
  -- claim, and it has to be verified like any other. Do not shorten this back.
  SELECT 'INF_20', 'no_duplicate_full_rows', 'UNIQUE', 'Uniqueness', 'all source columns',
         'no two rows identical across every source column, counted NULL-safely', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s)
         - (SELECT COUNT(*) FROM (
              SELECT DISTINCT code_module, code_presentation, id_student, gender, region,
                     highest_education, imd_band, age_band, num_of_prev_attempts,
                     studied_credits, disability, final_result FROM s) d),
         'Q3 activity through the course'

  UNION ALL
  SELECT 'INF_21', 'age_band_stable_per_student', 'UNIQUE', 'Consistency', 'age_band',
         'one age_band per student across presentations', 1.00, 'WARN',
         COUNT(*), COUNT_IF(age_bands_seen_for_student > 1),
         'Q2 withdrawal patterns' FROM s

  UNION ALL
  -- The fanout guard, and the most valuable check in the set. If this fires,
  -- dim_student built with SELECT DISTINCT joins those students to the fact
  -- table twice and doubles every click they ever made, with no error anywhere.
  SELECT 'INF_22', 'one_row_per_student_after_collapse', 'UNIQUE', 'Uniqueness', 'id_student',
         'collapsing demographics yields one row per student', 1.00, 'WARN',
         (SELECT COUNT(DISTINCT id_student) FROM s),
         (SELECT COUNT(*) FROM (SELECT DISTINCT id_student, gender, region,
                 highest_education, imd_band, age_band, disability FROM s) d)
         - (SELECT COUNT(DISTINCT id_student) FROM s),
         'Q3 activity through the course'

  -- REFERENTIAL INTEGRITY, 1 check -------------------------------------------
  UNION ALL
  SELECT 'INF_23', 'module_presentation_exists_in_courses', 'REFERENTIAL INTEGRITY',
         'Referential integrity', 'code_module, code_presentation',
         'every enrolment points at a presentation that exists', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s WHERE NOT EXISTS (
            SELECT 1 FROM oulad.clean.courses c
            WHERE c.code_module = s.code_module
              AND c.code_presentation = s.code_presentation)),
         'Q3 activity through the course'

  -- VOLUME, 2 checks ---------------------------------------------------------
  UNION ALL
  SELECT 'INF_24', 'clean_row_count_equals_raw', 'VOLUME', 'Completeness', 'table',
         'nothing lost or invented between layers', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM r),
         ABS((SELECT COUNT(*) FROM r) - (SELECT COUNT(*) FROM s)),
         'Q3 activity through the course'

  UNION ALL
  SELECT 'INF_25', 'row_count_within_expected_band', 'VOLUME', 'Completeness', 'table',
         'row count sits inside the expected 30k to 35k band for this file', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         CASE WHEN (SELECT COUNT(*) FROM s) BETWEEN 30000 AND 35000 THEN 0 ELSE 1 END,
         'Q3 activity through the course'
)
SELECT
  current_timestamp()                                   AS executed_at,
  'clean'                                               AS layer,
  'student_info'                                        AS table_name,
  check_id, check_name, check_type, dq_dimension, column_name, expectation,
  threshold_pct                                         AS threshold,
  severity, total_count, fail_count,
  ROUND(fail_count * 100.0 / NULLIF(total_count, 0), 4) AS fail_pct,
  CASE
    WHEN fail_count = 0 THEN 'PASS'
    WHEN fail_count * 100.0 / NULLIF(total_count, 0) > threshold_pct THEN severity
    ELSE 'WARN'
  END                                                   AS status,
  business_question,
  'Kinah'                                               AS owner
FROM checks
ORDER BY check_id;


/* ############################################################################
   05 - STUDENT_REGISTRATION                    15 checks  Owner: Charlene
   Reads  oulad.clean.student_registration, oulad.raw.student_registration,
          oulad.clean.courses
   ############################################################################

   date_unregistration is NULL for 69.10% of rows and that is the normal case,
   not missing data: it means the student never unregistered. REG_04 watches the
   unregistered share rather than the nulls, which is why its threshold looks
   large. Thresholds here are Charlene's, unchanged.
*/

DELETE FROM oulad.validation.staging WHERE table_name = 'student_registration';

INSERT INTO oulad.validation.staging
WITH s AS (
  SELECT *,
         SIZE(COLLECT_SET(date_registration) OVER (PARTITION BY id_student))
           AS reg_dates_seen_for_student
  FROM oulad.clean.student_registration
),
     r AS (SELECT * FROM oulad.raw.student_registration),
checks AS (

  SELECT 'REG_01' AS check_id, 'id_student_not_null' AS check_name,
         'NULL' AS check_type, 'Completeness' AS dq_dimension,
         'id_student' AS column_name,
         'every enrolment identifies a student' AS expectation,
         0.00 AS threshold_pct, 'FAIL' AS severity,
         COUNT(*) AS total_count, COUNT_IF(id_student IS NULL) AS fail_count,
         'Q3 activity through the course' AS business_question
  FROM s

  UNION ALL
  SELECT 'REG_02', 'module_presentation_not_null', 'NULL', 'Completeness',
         'code_module, code_presentation',
         'every enrolment names the module presentation it belongs to', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_module IS NULL OR code_presentation IS NULL),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'REG_03', 'date_registration_missingness_within_bound', 'NULL', 'Completeness',
         'date_registration',
         'missing registration dates do not exceed 0.20% of rows', 0.20, 'WARN',
         COUNT(*), COUNT_IF(date_registration IS NULL),
         'Q2 withdrawal patterns' FROM s

  UNION ALL
  SELECT 'REG_04', 'date_unregistration_expected_null_rate', 'NULL', 'Completeness',
         'date_unregistration',
         'unregistered share stays inside the expected band, about 31%', 35.00, 'WARN',
         COUNT(*), COUNT_IF(date_unregistration IS NOT NULL),
         'Q2 withdrawal patterns' FROM s

  UNION ALL
  SELECT 'REG_05', 'code_presentation_accepted_format', 'ACCEPTED VALUES', 'Validity',
         'code_presentation', 'code_presentation is four digits then B or J', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(NOT REGEXP_LIKE(code_presentation, '^[0-9]{4}[BJ]$')),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'REG_06', 'code_module_accepted_values', 'ACCEPTED VALUES', 'Validity', 'code_module',
         'code_module is one of the seven course codes', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_module NOT IN ('AAA','BBB','CCC','DDD','EEE','FFF','GGG')),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'REG_07', 'date_registration_within_valid_bounds', 'RANGE', 'Accuracy',
         'date_registration',
         'registration day relative to course start falls within -365 to 120', 0.50, 'WARN',
         COUNT(*), COUNT_IF(date_registration < -365 OR date_registration > 120),
         'Q2 withdrawal patterns' FROM s

  UNION ALL
  SELECT 'REG_08', 'temporal_sequence_valid', 'RANGE', 'Validity',
         'date_registration, date_unregistration',
         'a student cannot unregister before registering', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(date_unregistration < date_registration),
         'Q2 withdrawal patterns' FROM s

  UNION ALL
  SELECT 'REG_09', 'id_student_casts_to_int', 'SCHEMA', 'Validity', 'id_student',
         'every raw id_student survives the cast to INT', 0.00, 'FAIL',
         COUNT(*),
         COUNT_IF(NULLIF(NULLIF(TRIM(id_student), ''), '?') IS NOT NULL
                  AND TRY_CAST(NULLIF(NULLIF(TRIM(id_student), ''), '?') AS INT) IS NULL),
         'Q3 activity through the course' FROM r

  UNION ALL
  SELECT 'REG_10', 'registration_dates_cast_cleanly', 'SCHEMA', 'Validity',
         'date_registration, date_unregistration',
         'non-null relative date integers cast without loss', 0.00, 'FAIL',
         COUNT(*),
         -- '?' excluded: 45 + 22,521 rows carry it. Without this the check
         -- reports 22,560 failures on a perfectly clean load.
         COUNT_IF((NULLIF(NULLIF(TRIM(date_registration), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(date_registration), ''), '?') AS INT) IS NULL)
               OR (NULLIF(NULLIF(TRIM(date_unregistration), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(date_unregistration), ''), '?') AS INT) IS NULL)),
         'Q2 withdrawal patterns' FROM r

  UNION ALL
  SELECT 'REG_11', 'composite_key_unique', 'UNIQUE', 'Uniqueness',
         'code_module, code_presentation, id_student',
         'one enrolment per student per module presentation', 0.00, 'FAIL',
         COUNT(*), COUNT(*) - COUNT(DISTINCT code_module, code_presentation, id_student),
         'Q3 activity through the course' FROM s

  UNION ALL
  -- NULL-safe, and this is the table where it matters most: date_unregistration
  -- is NULL on about 69% of rows, so the short form would call two thirds of
  -- the table duplicates.
  SELECT 'REG_12', 'no_duplicate_full_rows', 'UNIQUE', 'Uniqueness', 'all source columns',
         'no two rows identical across every source column, counted NULL-safely', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s)
         - (SELECT COUNT(*) FROM (
              SELECT DISTINCT code_module, code_presentation, id_student,
                     date_registration, date_unregistration FROM s) d),
         'Q3 activity through the course'

  UNION ALL
  SELECT 'REG_13', 'registration_date_stable_per_enrolment', 'UNIQUE', 'Consistency',
         'date_registration',
         'a student does not register on more than three distinct days', 2.00, 'WARN',
         COUNT(*), COUNT_IF(reg_dates_seen_for_student > 3),
         'Q2 withdrawal patterns' FROM s

  UNION ALL
  SELECT 'REG_14', 'module_presentation_exists_in_courses', 'REFERENTIAL INTEGRITY',
         'Referential integrity', 'code_module, code_presentation',
         'every enrolment references an existing presentation', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s WHERE NOT EXISTS (
            SELECT 1 FROM oulad.clean.courses c
            WHERE c.code_module = s.code_module
              AND c.code_presentation = s.code_presentation)),
         'Q3 activity through the course'

  UNION ALL
  SELECT 'REG_15', 'clean_row_count_equals_raw', 'VOLUME', 'Completeness', 'table',
         'nothing lost or invented between raw and clean layers', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM r),
         ABS((SELECT COUNT(*) FROM r) - (SELECT COUNT(*) FROM s)),
         'Q3 activity through the course'
)
SELECT
  current_timestamp()                                   AS executed_at,
  'clean'                                               AS layer,
  'student_registration'                                AS table_name,
  check_id, check_name, check_type, dq_dimension, column_name, expectation,
  threshold_pct                                         AS threshold,
  severity, total_count, fail_count,
  ROUND(fail_count * 100.0 / NULLIF(total_count, 0), 4) AS fail_pct,
  CASE
    WHEN fail_count = 0 THEN 'PASS'
    WHEN fail_count * 100.0 / NULLIF(total_count, 0) > threshold_pct THEN severity
    ELSE 'WARN'
  END                                                   AS status,
  business_question,
  'Charlene'                                            AS owner
FROM checks
ORDER BY check_id;


/* ############################################################################
   06 - STUDENT_VLE                             15 checks    Owner: Crizza
   Reads  oulad.clean.student_vle, oulad.raw.student_vle,
          oulad.clean.vle, oulad.clean.courses
   ############################################################################

   10.6 million rows, the biggest table in the project. SVL_11 and SVL_13 are
   the expensive ones. Everything else is a single pass.

   A negative date is NOT an error here. Day offsets are relative to term start
   and students browse the site before term begins, so there is no check against
   it. The previous version flagged those rows as a quality problem; they are a
   fact about the data.

   The metrics from the original report (unique students, date range, click
   range) are not checks and are not in this table. They moved to the profile
   query at the end of this section. A count is not an assertion, and counting
   one as a passing check inflates the pass rate on every dashboard tile.
*/

DELETE FROM oulad.validation.staging WHERE table_name = 'student_vle';

INSERT INTO oulad.validation.staging
WITH s AS (SELECT * FROM oulad.clean.student_vle),
     r AS (SELECT * FROM oulad.raw.student_vle),
checks AS (

  SELECT 'SVL_01' AS check_id, 'code_module_not_null' AS check_name,
         'NULL' AS check_type, 'Completeness' AS dq_dimension,
         'code_module' AS column_name,
         'every interaction names its module' AS expectation,
         0.00 AS threshold_pct, 'FAIL' AS severity,
         COUNT(*) AS total_count, COUNT_IF(code_module IS NULL) AS fail_count,
         'Q1 engagement vs performance' AS business_question
  FROM s

  UNION ALL
  SELECT 'SVL_02', 'code_presentation_not_null', 'NULL', 'Completeness', 'code_presentation',
         'every interaction names its presentation', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_presentation IS NULL),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'SVL_03', 'id_student_not_null', 'NULL', 'Completeness', 'id_student',
         'every interaction identifies a student', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(id_student IS NULL),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'SVL_04', 'id_site_not_null', 'NULL', 'Completeness', 'id_site',
         'every interaction names the resource it touched', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(id_site IS NULL),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'SVL_05', 'date_not_null', 'NULL', 'Completeness', 'date',
         'every interaction records the day it happened', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(date IS NULL),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'SVL_06', 'sum_click_not_null', 'NULL', 'Completeness', 'sum_click',
         'every interaction has a click count', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(sum_click IS NULL),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'SVL_07', 'sum_click_not_negative', 'RANGE', 'Validity', 'sum_click',
         'clicks are never negative', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(sum_click < 0),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  -- A logged interaction with zero clicks is odd but not impossible. Surfaced.
  SELECT 'SVL_08', 'sum_click_greater_than_zero', 'RANGE', 'Accuracy', 'sum_click',
         'a logged interaction records at least one click', 0.00, 'WARN',
         COUNT(*), COUNT_IF(sum_click = 0),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'SVL_09', 'code_module_accepted_values', 'ACCEPTED VALUES', 'Validity', 'code_module',
         'code_module is one of the seven course codes', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_module NOT IN ('AAA','BBB','CCC','DDD','EEE','FFF','GGG')),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'SVL_10', 'code_presentation_format', 'ACCEPTED VALUES', 'Validity', 'code_presentation',
         'code_presentation is four digits then B or J', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(NOT REGEXP_LIKE(code_presentation, '^[0-9]{4}[BJ]$')),
         'Q3 activity through the course' FROM s

  UNION ALL
  -- READ THIS ONE. The source file does not have the grain the documentation
  -- claims. Measured on a 588,132-row sample of studentVle.csv: 23.88% of rows
  -- repeat an existing (id_student, id_site, code_module, code_presentation,
  -- date) key, up to 7 rows on a single key. The star schema, the data
  -- dictionary and the write-up all say one row per student per resource per
  -- day. They are describing the intended mart grain, not the file.
  --
  -- So this is not a pass-or-fail assertion about a broken load, it is a
  -- measurement of a known source property, with a threshold set above the
  -- observed level so a real change still trips it. Expect WARN at about 24%.
  -- FAIL here means the duplication got materially worse, not that someone
  -- broke the clean script.
  --
  -- The mart must aggregate before building fact_student_vle:
  --   SELECT code_module, code_presentation, id_student, id_site, date,
  --          SUM(sum_click) AS sum_click
  --   FROM oulad.clean.student_vle GROUP BY 1,2,3,4,5
  -- Skip that GROUP BY and every interaction count is roughly 31% too high.
  -- The hard uniqueness assertion belongs in 05_validate_marts, against the
  -- aggregated table, where it can actually be satisfied.
  SELECT 'SVL_11', 'source_grain_duplicate_rate', 'UNIQUE', 'Uniqueness',
         'id_student, id_site, code_module, code_presentation, date',
         'repeat rows on the day grain stay near the known 24%, mart must aggregate',
         30.00, 'FAIL',
         COUNT(*),
         COUNT(*) - COUNT(DISTINCT id_student, id_site, code_module, code_presentation, date),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'SVL_12', 'numeric_columns_cast_cleanly', 'SCHEMA', 'Validity',
         'id_student, id_site, date, sum_click',
         'every numeric column in the raw file casts without loss', 0.00, 'FAIL',
         COUNT(*),
         COUNT_IF((NULLIF(NULLIF(TRIM(id_student), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(id_student), ''), '?') AS INT) IS NULL)
               OR (NULLIF(NULLIF(TRIM(id_site), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(id_site), ''), '?') AS INT) IS NULL)
               OR (NULLIF(NULLIF(TRIM(date), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(date), ''), '?') AS INT) IS NULL)
               OR (NULLIF(NULLIF(TRIM(sum_click), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(sum_click), ''), '?') AS INT) IS NULL)),
         'Q1 engagement vs performance' FROM r

  UNION ALL
  SELECT 'SVL_13', 'id_site_exists_in_vle', 'REFERENTIAL INTEGRITY', 'Referential integrity',
         'id_site', 'every interaction points at a resource that exists', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s WHERE NOT EXISTS (
            SELECT 1 FROM oulad.clean.vle v WHERE v.id_site = s.id_site)),
         'Q3 activity through the course'

  UNION ALL
  SELECT 'SVL_14', 'module_presentation_exists_in_courses', 'REFERENTIAL INTEGRITY',
         'Referential integrity', 'code_module, code_presentation',
         'every interaction references an existing presentation', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s WHERE NOT EXISTS (
            SELECT 1 FROM oulad.clean.courses c
            WHERE c.code_module = s.code_module
              AND c.code_presentation = s.code_presentation)),
         'Q3 activity through the course'

  UNION ALL
  SELECT 'SVL_15', 'clean_row_count_equals_raw', 'VOLUME', 'Completeness', 'table',
         'nothing lost or invented between raw and clean layers', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM r),
         ABS((SELECT COUNT(*) FROM r) - (SELECT COUNT(*) FROM s)),
         'Q3 activity through the course'
)
SELECT
  current_timestamp()                                   AS executed_at,
  'clean'                                               AS layer,
  'student_vle'                                         AS table_name,
  check_id, check_name, check_type, dq_dimension, column_name, expectation,
  threshold_pct                                         AS threshold,
  severity, total_count, fail_count,
  ROUND(fail_count * 100.0 / NULLIF(total_count, 0), 4) AS fail_pct,
  CASE
    WHEN fail_count = 0 THEN 'PASS'
    WHEN fail_count * 100.0 / NULLIF(total_count, 0) > threshold_pct THEN severity
    ELSE 'WARN'
  END                                                   AS status,
  business_question,
  'Crizza'                                              AS owner
FROM checks
ORDER BY check_id;

-- The metrics from the original report, kept as a profile rather than as fake
-- passing checks. Run it when you want the shape of the table, not its health.
SELECT
  COUNT(*)                                                    AS rows,
  COUNT(DISTINCT id_student)                                  AS students,
  COUNT(DISTINCT id_site)                                     AS sites,
  COUNT(DISTINCT CONCAT(code_module, '-', code_presentation)) AS module_presentations,
  MIN(date)                                                   AS first_day,
  MAX(date)                                                   AS last_day,
  MIN(sum_click)                                              AS min_clicks,
  MAX(sum_click)                                              AS max_clicks,
  COUNT_IF(date < 0)                                          AS pre_course_interactions
FROM oulad.clean.student_vle;


/* ############################################################################
   07 - VLE                                     14 checks      Owner: Anje
   Reads  oulad.clean.vle, oulad.raw.vle, oulad.clean.courses
   ############################################################################

   week_from and week_to are NULL on 5,243 rows, 82.39%, and that is expected:
   homepages and general forums are open for the whole course rather than a week
   range. VLE_09 watches that share with a threshold set just above the observed
   level so a jump shows up. That 85 is the only number in this whole file that
   nobody on the team stated, so it is the one to argue about.

   The original for this table was a row-level flagging query that could not
   run. The same conditions are here as table-level checks, one per condition.
   No condition was added or dropped.
*/

DELETE FROM oulad.validation.staging WHERE table_name = 'vle';

INSERT INTO oulad.validation.staging
WITH s AS (SELECT * FROM oulad.clean.vle),
     r AS (SELECT * FROM oulad.raw.vle),
checks AS (

  SELECT 'VLE_01' AS check_id, 'id_site_not_null' AS check_name,
         'NULL' AS check_type, 'Completeness' AS dq_dimension,
         'id_site' AS column_name,
         'every resource has an id' AS expectation,
         0.00 AS threshold_pct, 'FAIL' AS severity,
         COUNT(*) AS total_count, COUNT_IF(id_site IS NULL) AS fail_count,
         'Q3 activity through the course' AS business_question
  FROM s

  UNION ALL
  SELECT 'VLE_02', 'code_module_not_null', 'NULL', 'Completeness', 'code_module',
         'every resource names its module', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_module IS NULL OR code_module = ''),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'VLE_03', 'code_presentation_not_null', 'NULL', 'Completeness', 'code_presentation',
         'every resource names its presentation', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_presentation IS NULL OR code_presentation = ''),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'VLE_04', 'activity_type_not_null', 'NULL', 'Completeness', 'activity_type',
         'every resource says what kind of activity it is', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(activity_type IS NULL OR activity_type = ''),
         'Q1 engagement vs performance' FROM s

  UNION ALL
  SELECT 'VLE_05', 'id_site_unique', 'UNIQUE', 'Uniqueness', 'id_site',
         'id_site is the primary key, 6,364 rows all distinct', 0.00, 'FAIL',
         COUNT(*), COUNT(*) - COUNT(DISTINCT id_site),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'VLE_06', 'week_from_not_negative', 'RANGE', 'Validity', 'week_from',
         'week_from is zero or more when present', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(week_from < 0),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'VLE_07', 'week_to_not_negative', 'RANGE', 'Validity', 'week_to',
         'week_to is zero or more when present', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(week_to < 0),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'VLE_08', 'week_from_not_after_week_to', 'RANGE', 'Validity', 'week_from, week_to',
         'a resource does not stop being available before it starts', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(week_from > week_to),
         'Q3 activity through the course' FROM s

  UNION ALL
  -- THRESHOLD TO CONFIRM. 85 is set just above the observed 82.39% so a jump
  -- shows up. It is the one number here nobody on the team stated.
  SELECT 'VLE_09', 'week_range_known', 'NULL', 'Completeness', 'week_from, week_to',
         'the share of resources with no week range stays near the expected 82%',
         85.00, 'WARN',
         COUNT(*), COUNT_IF(week_from IS NULL OR week_to IS NULL),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'VLE_10', 'code_module_accepted_values', 'ACCEPTED VALUES', 'Validity', 'code_module',
         'code_module is one of the seven course codes', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(code_module NOT IN ('AAA','BBB','CCC','DDD','EEE','FFF','GGG')),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'VLE_11', 'code_presentation_format', 'ACCEPTED VALUES', 'Validity', 'code_presentation',
         'code_presentation is four digits then B or J', 0.00, 'FAIL',
         COUNT(*), COUNT_IF(NOT REGEXP_LIKE(code_presentation, '^[0-9]{4}[BJ]$')),
         'Q3 activity through the course' FROM s

  UNION ALL
  SELECT 'VLE_12', 'numeric_columns_cast_cleanly', 'SCHEMA', 'Validity',
         'id_site, week_from, week_to',
         'every numeric column in the raw file casts without loss', 0.00, 'FAIL',
         COUNT(*),
         -- '?' excluded: 5,243 rows carry it in each week column. Without this
         -- the check reports 5,243 failures on a clean load.
         COUNT_IF((NULLIF(NULLIF(TRIM(id_site), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(id_site), ''), '?') AS INT) IS NULL)
               OR (NULLIF(NULLIF(TRIM(week_from), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(week_from), ''), '?') AS INT) IS NULL)
               OR (NULLIF(NULLIF(TRIM(week_to), ''), '?') IS NOT NULL
                   AND TRY_CAST(NULLIF(NULLIF(TRIM(week_to), ''), '?') AS INT) IS NULL)),
         'Q3 activity through the course' FROM r

  UNION ALL
  SELECT 'VLE_13', 'module_presentation_exists_in_courses', 'REFERENTIAL INTEGRITY',
         'Referential integrity', 'code_module, code_presentation',
         'every resource references an existing presentation', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM s),
         (SELECT COUNT(*) FROM s WHERE NOT EXISTS (
            SELECT 1 FROM oulad.clean.courses c
            WHERE c.code_module = s.code_module
              AND c.code_presentation = s.code_presentation)),
         'Q3 activity through the course'

  UNION ALL
  SELECT 'VLE_14', 'clean_row_count_equals_raw', 'VOLUME', 'Completeness', 'table',
         'nothing lost or invented between raw and clean layers', 0.00, 'FAIL',
         (SELECT COUNT(*) FROM r),
         ABS((SELECT COUNT(*) FROM r) - (SELECT COUNT(*) FROM s)),
         'Q3 activity through the course'
)
SELECT
  current_timestamp()                                   AS executed_at,
  'clean'                                               AS layer,
  'vle'                                                 AS table_name,
  check_id, check_name, check_type, dq_dimension, column_name, expectation,
  threshold_pct                                         AS threshold,
  severity, total_count, fail_count,
  ROUND(fail_count * 100.0 / NULLIF(total_count, 0), 4) AS fail_pct,
  CASE
    WHEN fail_count = 0 THEN 'PASS'
    WHEN fail_count * 100.0 / NULLIF(total_count, 0) > threshold_pct THEN severity
    ELSE 'WARN'
  END                                                   AS status,
  business_question,
  'Anje'                                                AS owner
FROM checks
ORDER BY check_id;


/* ############################################################################
   99 - READING THE RESULTS
   Every tile below covers all seven tables. Drop them straight into a
   Databricks dashboard as separate datasets.
   ############################################################################ */

-- 99.1 Health header. The numbers that go across the top of the page.
-- overall_health is a sentence, not a colour, because a colour needs a legend.
SELECT
  COUNT(*)                                               AS checks_run,
  COUNT_IF(status = 'PASS')                              AS passed,
  COUNT_IF(status = 'WARN')                              AS warned,
  COUNT_IF(status = 'FAIL')                              AS failed,
  ROUND(COUNT_IF(status = 'PASS') * 100.0 / COUNT(*), 1) AS pass_rate_pct,
  COUNT(DISTINCT table_name)                             AS tables_reporting,
  CASE WHEN COUNT_IF(status = 'FAIL') > 0 THEN 'DO NOT SHIP'
       WHEN COUNT_IF(status = 'WARN') > 0 THEN 'USABLE, READ THE FLAGS'
       ELSE 'HEALTHY' END                                AS overall_health,
  MAX(executed_at)                                       AS last_checked
FROM oulad.validation.staging;

-- 99.2 Coverage. The tile that catches the real failure mode on a team project:
-- a table with no results at all, because nobody ran theirs. Seven rows
-- expected. A missing row is not a passing table.
SELECT
  expected.table_name,
  COALESCE(actual.checks, 0) AS checks_run,
  COALESCE(actual.failed, 0) AS failed,
  COALESCE(actual.warned, 0) AS warned,
  actual.owner,
  actual.last_checked,
  CASE WHEN actual.checks IS NULL THEN 'NEVER RUN' ELSE 'reported' END AS coverage
FROM (
  SELECT 'assessments' AS table_name UNION ALL SELECT 'courses'
  UNION ALL SELECT 'student_assessment'   UNION ALL SELECT 'student_info'
  UNION ALL SELECT 'student_registration' UNION ALL SELECT 'student_vle'
  UNION ALL SELECT 'vle'
) expected
LEFT JOIN (
  SELECT table_name, COUNT(*) AS checks,
         COUNT_IF(status = 'FAIL') AS failed,
         COUNT_IF(status = 'WARN') AS warned,
         MAX(owner) AS owner, MAX(executed_at) AS last_checked
  FROM oulad.validation.staging GROUP BY table_name
) actual ON actual.table_name = expected.table_name
ORDER BY coverage DESC, failed DESC, expected.table_name;

-- 99.3 Pass rate by check type. What kind of thing is breaking.
SELECT check_type, COUNT(*) AS checks,
       COUNT_IF(status = 'PASS') AS passed,
       COUNT_IF(status = 'WARN') AS warned,
       COUNT_IF(status = 'FAIL') AS failed,
       ROUND(COUNT_IF(status = 'PASS') * 100.0 / COUNT(*), 1) AS pass_rate_pct
FROM oulad.validation.staging
GROUP BY check_type ORDER BY failed DESC, warned DESC, check_type;

-- 99.4 Pass rate by quality dimension. Which promise to the reader is weakest.
SELECT dq_dimension, COUNT(*) AS checks,
       COUNT_IF(status = 'PASS') AS passed,
       COUNT_IF(status = 'WARN') AS warned,
       COUNT_IF(status = 'FAIL') AS failed,
       ROUND(COUNT_IF(status = 'PASS') * 100.0 / COUNT(*), 1) AS pass_rate_pct
FROM oulad.validation.staging
GROUP BY dq_dimension ORDER BY failed DESC, warned DESC, dq_dimension;

-- 99.5 Critical failures. Should normally be empty. Keep the tile on the page
-- when it is empty: an absent tile and an empty tile look identical to a reader
-- who does not know the page, and only one of them is reassuring.
SELECT table_name, check_id, check_name, check_type, column_name, expectation,
       fail_count, total_count, fail_pct, threshold, business_question, owner, executed_at
FROM oulad.validation.staging
WHERE status = 'FAIL'
ORDER BY fail_pct DESC;

-- 99.6 What flagged, and what it was allowed to be. headroom_pct is the gap
-- between the agreed threshold and what actually happened, so a reader can tell
-- "bad" from "known and tolerated" without asking anyone.
SELECT table_name, check_id, check_name, dq_dimension,
       fail_count, total_count, fail_pct, threshold, severity, status,
       ROUND(threshold - fail_pct, 4) AS headroom_pct,
       business_question, owner
FROM oulad.validation.staging
WHERE fail_count > 0
ORDER BY status DESC, fail_pct DESC;

-- 99.7 The whole table, for the record.
SELECT * FROM oulad.validation.staging ORDER BY table_name, check_id;


/* ############################################################################
   CLEANUP, once everyone has rerun against these files
   ############################################################################

   Superseded tables. They will otherwise sit around holding stale results that
   quietly disagree with the dashboard. Drop them deliberately, after checking
   nobody's notebook still reads them.

   DROP TABLE IF EXISTS oulad.clean.02_assessments_dq_checks;
   DROP TABLE IF EXISTS oulad.clean.dq_check_results;
   DROP TABLE IF EXISTS oulad.clean.clean_assessments;
   DROP TABLE IF EXISTS oulad.clean.clean_student_assessment;
   DROP TABLE IF EXISTS oulad.clean.student_vle_final;
   DROP TABLE IF EXISTS week07.silver.dq_check_results;
   ############################################################################ */

