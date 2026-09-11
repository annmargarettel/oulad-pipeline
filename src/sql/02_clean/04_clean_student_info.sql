-- CLEAN studentInfo
-- Grain: one row is one student in one module presentation.
-- 32,593 rows in, 32,593 rows out. Nothing is deleted, problems are flagged.
--
-- What this file does
--   1. Trims and normalises every column, and casts with TRY_CAST so a bad value
--      becomes a NULL we can flag rather than an error that kills the load.
--   2. Turns the literal string '?' in imd_band into a real NULL. The source encodes
--      "not known" that way, so a plain null check on this file returns zero and
--      hides 1,111 missing values.
--   3. Normalises the one band written '10-20' while the other nine carry a '%'.
--      The original is kept in imd_band_raw so the change is auditable.
--   4. Adds imd_decile_low so the bands sort correctly on a dashboard, and
--      credit_load_band so the strongest withdrawal signal is one column.
--   5. Gives every row a dq_status and a readable dq_flags array.
--      The mart can filter with: WHERE dq_status <> 'REJECT'

CREATE OR REPLACE TABLE oulad.clean.student_info
COMMENT 'One row per student enrolment in one module presentation. Cleaned, typed, DQ-flagged.'
AS
WITH typed AS (
  SELECT
    -- the composite primary key
    UPPER(TRIM(code_module))                              AS code_module,
    UPPER(TRIM(code_presentation))                        AS code_presentation,
    id_student                                            AS id_student,

    -- demographics
    UPPER(TRIM(gender))                                   AS gender,
    NULLIF(TRIM(region), '')                              AS region,
    NULLIF(TRIM(highest_education), '')                   AS highest_education,

    -- imd_band, the column that needed the most work.
    -- The source encodes "not known" as the literal string '?', and writes one
    -- band as '10-20' while the other nine carry a '%'.
    CASE
      WHEN TRIM(imd_band) IN ('?', '')             THEN NULL
      WHEN TRIM(imd_band) RLIKE '^[0-9]+-[0-9]+$'  THEN CONCAT(TRIM(imd_band), '%')
      ELSE TRIM(imd_band)
    END                                                   AS imd_band,
    TRIM(imd_band)                                        AS imd_band_raw,

    NULLIF(TRIM(age_band), '')                            AS age_band,
    num_of_prev_attempts                                  AS num_of_prev_attempts,
    studied_credits                                       AS studied_credits,
    UPPER(TRIM(disability))                               AS disability,
    NULLIF(TRIM(final_result), '')                        AS final_result
  FROM oulad.raw.student_info
),

-- One student can sit several presentations. This counts how many different
-- age_bands the source gives the same student, which is what breaks dim_student.
student_age AS (
  SELECT id_student, COUNT(DISTINCT age_band) AS age_bands_seen_for_student
  FROM typed
  GROUP BY id_student
),

derived AS (
  SELECT
    t.*,
    sa.age_bands_seen_for_student,
    MD5(CONCAT_WS('|', t.code_module, t.code_presentation, CAST(t.id_student AS STRING))) AS enrolment_key,
    (t.imd_band IS NULL)                                          AS imd_band_is_missing,
    TRY_CAST(SPLIT(t.imd_band, '-')[0] AS INT)                    AS imd_decile_low,
    CASE
      WHEN t.studied_credits > 240 THEN 'over 240 (flagged outlier)'
      WHEN t.studied_credits > 120 THEN '121-240'
      WHEN t.studied_credits > 60  THEN '61-120'
      ELSE                              '60 or less'
    END                                                           AS credit_load_band,
    (t.final_result = 'Withdrawn')                                AS is_withdrawn
  FROM typed t
  LEFT JOIN student_age sa ON sa.id_student = t.id_student
),

flagged AS (
  SELECT
    d.*,
    ARRAY_COMPACT(ARRAY(
      CASE WHEN d.imd_band_is_missing
           THEN 'WARN: imd_band not known, source wrote ?' END,
      CASE WHEN d.imd_band_raw RLIKE '^[0-9]+-[0-9]+$'
           THEN 'WARN: imd_band label normalised, source was missing the % sign' END,
      CASE WHEN d.num_of_prev_attempts > 2
           THEN 'WARN: more than two previous attempts' END,
      CASE WHEN d.age_bands_seen_for_student > 1
           THEN 'WARN: age_band differs across this students presentations' END,
      CASE WHEN d.studied_credits > 240
           THEN 'WARN: studied_credits above the 99th percentile' END,
      CASE WHEN d.id_student IS NULL
           THEN 'REJECT: id_student is null' END,
      CASE WHEN d.final_result IS NULL
             OR d.final_result NOT IN ('Pass', 'Fail', 'Withdrawn', 'Distinction')
           THEN 'REJECT: final_result is not a known outcome' END
    )) AS dq_flags
  FROM derived d
)

SELECT
  enrolment_key,
  code_module,
  code_presentation,
  id_student,
  gender,
  region,
  highest_education,
  imd_band,
  imd_band_raw,
  imd_band_is_missing,
  imd_decile_low,
  age_band,
  age_bands_seen_for_student,
  num_of_prev_attempts,
  studied_credits,
  credit_load_band,
  disability,
  final_result,
  is_withdrawn,
  dq_flags,
  CASE
    WHEN EXISTS(dq_flags, f -> f LIKE 'REJECT:%') THEN 'REJECT'
    WHEN SIZE(dq_flags) > 0                       THEN 'WARN'
    ELSE                                               'PASS'
  END AS dq_status,
  current_timestamp() AS _cleaned_at
FROM flagged;

-- Verification. All four should come back clean before the mart reads this table.
--   1. Row count matches raw:        32,593 = 32,593
--   2. Composite key is unique:      0 duplicates
--   3. Nothing rejected:             0 rows
--   4. Missing imd_band is flagged, not dropped: 1,111 rows still present
SELECT
  (SELECT COUNT(*) FROM oulad.raw.student_info)                          AS raw_rows,
  COUNT(*)                                                              AS clean_rows,
  COUNT(*) - COUNT(DISTINCT code_module, code_presentation, id_student)  AS duplicate_keys,
  COUNT_IF(dq_status = 'REJECT')                                        AS rejected,
  COUNT_IF(dq_status = 'WARN')                                          AS flagged,
  COUNT_IF(imd_band_is_missing)                                         AS imd_band_not_known
FROM oulad.clean.student_info;
