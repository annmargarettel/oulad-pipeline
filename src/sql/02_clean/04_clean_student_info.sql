-- Clean student_info
-- Grain: one row is one student in one module presentation
-- Expected row count: 32,593 rows in, 32,593 out (no change)
--
-- CLEANING ONLY. No DQ checks, no dq_flags, no dq_status in this file.
-- The 25 data quality checks for this table are handed off separately and write
-- into oulad.validation.staging with table_name = 'student_info'.
--
-- What this file does
-- 1. Trims and standardises casing on every string column.
-- 2. Casts with TRY_CAST, never bare CAST, so a bad value becomes a NULL the
--    validations can count rather than an error that kills the load.
-- 3. imd_band: the source writes "not known" as the literal string '?'. That is a
--    present value, so a plain null check on this file returns zero and hides
--    1,111 rows. '?' becomes a real NULL here.
-- 4. imd_band: one band is written '10-20' with no percent sign, 3,516 rows, while
--    the other nine carry a '%'. Normalised to '10-20%' so the ten bands sort and
--    join as one series. The untouched value stays in imd_band_raw, so this is the
--    only value in the table that is changed rather than left alone, and the change
--    is auditable.
-- 5. Adds the derived columns the mart and the validations read. These are
--    cleaning-layer conveniences, not DQ results: enrolment_key, imd_band_raw,
--    imd_band_is_missing, imd_decile_low, age_bands_seen_for_student,
--    credit_load_band, is_withdrawn.
--    Three of them are inputs to the staging validations, so dropping them breaks
--    those checks: imd_band_raw (label format), enrolment_key (surrogate key
--    uniqueness), age_bands_seen_for_student (age_band stable per student).
-- 6. Deletes nothing. Rows in equals rows out.
--
-- Reads:  oulad.raw.student_info
-- Writes: oulad.clean.student_info

CREATE OR REPLACE TABLE oulad.clean.student_info
COMMENT 'One row per student enrolment in one module presentation. Cleaned and typed.'
AS
WITH typed AS (
  SELECT
    -- composite business key
    UPPER(TRIM(code_module))                       AS code_module,
    UPPER(TRIM(code_presentation))                 AS code_presentation,
    TRY_CAST(TRIM(CAST(id_student AS STRING)) AS INT) AS id_student,

    -- demographics
    UPPER(TRIM(gender))                            AS gender,
    NULLIF(TRIM(region), '')                       AS region,
    NULLIF(TRIM(highest_education), '')            AS highest_education,

    -- imd_band, the column that needed the most work.
    -- '?' is the source's "not known". '10-20' is the one band missing its '%'.
    CASE
      WHEN TRIM(imd_band) IN ('?', '')                 THEN NULL
      WHEN TRIM(imd_band) RLIKE '^[0-9]+-[0-9]+$'      THEN CONCAT(TRIM(imd_band), '%')
      ELSE TRIM(imd_band)
    END                                            AS imd_band,
    TRIM(imd_band)                                 AS imd_band_raw,

    NULLIF(TRIM(age_band), '')                     AS age_band,
    TRY_CAST(TRIM(CAST(num_of_prev_attempts AS STRING)) AS INT) AS num_of_prev_attempts,
    TRY_CAST(TRIM(CAST(studied_credits AS STRING)) AS INT)      AS studied_credits,
    UPPER(TRIM(disability))                        AS disability,
    NULLIF(TRIM(final_result), '')                 AS final_result
  FROM oulad.raw.student_info
),

-- One student can sit several presentations. This counts how many different
-- age_bands the source gives the same student. 72 students have two, because they
-- crossed into the next bracket between courses. dim_student has to collapse with
-- ROW_NUMBER rather than SELECT DISTINCT or every fact row for those 72 joins twice.
student_age AS (
  SELECT id_student, COUNT(DISTINCT age_band) AS age_bands_seen_for_student
  FROM typed
  GROUP BY id_student
)

SELECT
  -- surrogate key over the composite business key, so a downstream table can
  -- reference one column instead of three
  MD5(CONCAT_WS('|', t.code_module, t.code_presentation,
                CAST(t.id_student AS STRING)))     AS enrolment_key,

  -- composite business key
  t.code_module,
  t.code_presentation,
  t.id_student,

  -- the twelve source columns, cleaned and typed
  t.gender,
  t.region,
  t.highest_education,
  t.imd_band,
  t.imd_band_raw,
  t.age_band,
  t.num_of_prev_attempts,
  t.studied_credits,
  t.disability,
  t.final_result,

  -- derived, so a dashboard tile or a validation does not re-derive them
  (t.imd_band IS NULL)                             AS imd_band_is_missing,
  TRY_CAST(SPLIT(t.imd_band, '-')[0] AS INT)       AS imd_decile_low,
  sa.age_bands_seen_for_student,
  CASE
    WHEN t.studied_credits > 240 THEN 'over 240 (flagged outlier)'
    WHEN t.studied_credits > 120 THEN '121-240'
    WHEN t.studied_credits >  60 THEN '61-120'
    ELSE '60 or less'
  END                                              AS credit_load_band,
  (t.final_result = 'Withdrawn')                   AS is_withdrawn,

  current_timestamp()                              AS _cleaned_at
FROM typed t
LEFT JOIN student_age sa
  ON sa.id_student = t.id_student;
