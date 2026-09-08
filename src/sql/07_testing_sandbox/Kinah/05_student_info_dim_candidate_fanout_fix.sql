-- =============================================================================
-- student_info  |  ONE ROW PER STUDENT, AND THE FANOUT IT FIXES
-- Owner: Kinah
-- Sandbox: src/sql/07_testing_sandbox/Kinah
--
-- READ THIS BEFORE BUILDING dim_student. This is the one thing from my table
-- that can silently corrupt the fact tables.
--
-- THE PROBLEM
--   SELECT DISTINCT on the demographic columns returns 28,857 rows for
--   28,785 students. 72 students report a different age_band in different
--   presentations, which is what you would expect from real people over two
--   years of data.
--
--   If dim_student is built off that distinct, each of those 72 students has
--   two dimension rows. Every fact row for them then joins twice, and every
--   click and every assessment they ever made is counted twice. Nobody sees an
--   error. The totals are just wrong.
--
-- THE FIX
--   Collapse to one row per student with ROW_NUMBER, keeping the most recent
--   presentation. code_presentation sorts chronologically as plain text:
--   2013B, 2013J, 2014B, 2014J. So ORDER BY code_presentation DESC works
--   without parsing it.
--
--   The student who changed is kept and marked, not quietly overwritten, so
--   the next person does not have to rediscover the 72.
--
-- PROOF: 28,785 rows, 28,785 distinct keys, 0 duplicates, 72 marked.
--
-- Nothing writes. This belongs in the mart, which is not my layer, so it is
-- here as a reference rather than as a CREATE.
-- =============================================================================

WITH ranked AS (
  SELECT
    id_student,
    gender,
    region,
    highest_education,
    imd_band,
    imd_decile_low,
    age_band,
    disability,
    code_module,
    code_presentation,
    age_bands_seen_for_student,
    ROW_NUMBER() OVER (
      PARTITION BY id_student
      ORDER BY code_presentation DESC, code_module DESC
    ) AS rn
  FROM oulad.clean.student_info
  WHERE dq_status <> 'REJECT'
)

SELECT
  MD5(CAST(id_student AS STRING))              AS student_key,
  id_student,
  gender,
  region,
  highest_education,
  imd_band,
  imd_decile_low,
  age_band,
  disability,
  code_module                                  AS demographics_from_module,
  code_presentation                            AS demographics_from_presentation,
  (age_bands_seen_for_student > 1)             AS age_band_changed_over_time
FROM ranked
WHERE rn = 1;

-- ---------------------------------------------------------------------------
-- PROOF. All four numbers have to come back clean before the mart joins this.
--   1. one row per student
--   2. keys are unique
--   3. zero duplicates
--   4. the 72 who changed are kept and marked, not dropped
-- ---------------------------------------------------------------------------
WITH ranked AS (
  SELECT id_student, age_bands_seen_for_student,
         ROW_NUMBER() OVER (PARTITION BY id_student
                            ORDER BY code_presentation DESC, code_module DESC) AS rn
  FROM oulad.clean.student_info
  WHERE dq_status <> 'REJECT'
),
collapsed AS (SELECT * FROM ranked WHERE rn = 1)
SELECT
  (SELECT COUNT(DISTINCT id_student) FROM oulad.clean.student_info) AS students_in_clean,
  COUNT(*)                                                         AS rows_in_dim,
  COUNT(DISTINCT id_student)                                       AS distinct_keys,
  COUNT(*) - COUNT(DISTINCT id_student)                            AS duplicate_keys,
  COUNT_IF(age_bands_seen_for_student > 1)                         AS students_marked_as_changed
FROM collapsed;

-- ---------------------------------------------------------------------------
-- The fanout itself, if you want to see it rather than take my word for it.
-- The first number is what a naive SELECT DISTINCT gives you. The second is
-- the truth. The gap is the 72 students, appearing twice each.
-- ---------------------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM (
      SELECT DISTINCT id_student, gender, region, highest_education,
             imd_band, age_band, disability
      FROM oulad.clean.student_info WHERE dq_status <> 'REJECT') d) AS naive_distinct_rows,
  (SELECT COUNT(DISTINCT id_student) FROM oulad.clean.student_info
   WHERE dq_status <> 'REJECT')                                    AS actual_students,
  (SELECT COUNT(DISTINCT id_student) FROM oulad.clean.student_info
   WHERE age_bands_seen_for_student > 1)                           AS students_who_changed;
