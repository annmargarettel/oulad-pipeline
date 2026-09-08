-- =============================================================================
-- student_info  |  BUSINESS DASHBOARD TILE QUERIES
-- Owner: Kinah
-- Sandbox: src/sql/07_testing_sandbox/Kinah
--
-- @ocharlenemae: this is the student_info half of the business dashboard, ready
-- to lift. Nothing writes. Every tile names its chart type and the sentence it
-- is meant to support, so the caption writes itself.
--
-- One thing that saves you work: imd_decile_low already exists on the clean
-- table, so the deprivation bands sort correctly without a CASE statement.
--
-- Reads oulad.clean.student_info (PR #2).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TILE 1  Trust header. Counters across the top.
-- Caption: 32,593 rows, 28,785 students, 0 rejected. The mart can use all of it.
-- ---------------------------------------------------------------------------
SELECT
  COUNT(*)                                                       AS rows_in_clean,
  COUNT(DISTINCT id_student)                                     AS students,
  ROUND(COUNT_IF(dq_status = 'PASS')  * 100.0 / COUNT(*), 1)     AS pct_pass,
  ROUND(COUNT_IF(dq_status = 'WARN')  * 100.0 / COUNT(*), 1)     AS pct_warn,
  COUNT_IF(dq_status = 'REJECT')                                 AS rows_rejected,
  COUNT(*) - COUNT_IF(dq_status = 'REJECT')                      AS rows_usable_by_mart
FROM oulad.clean.student_info;

-- ---------------------------------------------------------------------------
-- TILE 2  Q2. Withdrawal by credit load. Vertical bar, 4 bars, last one amber.
-- Caption: the strongest signal in the table, and perfectly monotonic.
-- 25.35, 38.75, 50.84, 59.48. Take on more credits, drop out more.
-- The amber bar is the flagged outlier bucket, which is the visual argument
-- for keeping outliers rather than deleting them.
-- ---------------------------------------------------------------------------
SELECT
  credit_load_band,
  COUNT(*)                                                          AS enrolments,
  ROUND(COUNT_IF(final_result = 'Withdrawn') * 100.0 / COUNT(*), 2) AS pct_withdrawn,
  ROUND(AVG(studied_credits), 1)                                    AS avg_credits
FROM oulad.clean.student_info
WHERE dq_status <> 'REJECT'
GROUP BY credit_load_band
ORDER BY credit_load_band;

-- ---------------------------------------------------------------------------
-- TILE 3  Q2. Withdrawal by deprivation band. Vertical bar, 11 bars, ordered
-- by sort_order. The eleventh is amber and labelled "not known".
-- Caption: 37.18 percent most deprived down to 25.87 least, an 11 point spread.
-- Say "same direction", not "monotonic". The middle bands move around:
-- 35.44 to 36.15, 30.94 to 32.00, 28.78 to 29.57, 27.68 to 28.02 all rise.
-- ---------------------------------------------------------------------------
SELECT
  COALESCE(imd_band, 'not known')                                    AS imd_band_label,
  COALESCE(imd_decile_low, 999)                                      AS sort_order,
  imd_band_is_missing                                                AS is_flagged,
  COUNT(*)                                                           AS enrolments,
  ROUND(COUNT_IF(final_result = 'Withdrawn') * 100.0 / COUNT(*), 2)  AS pct_withdrawn
FROM oulad.clean.student_info
WHERE dq_status <> 'REJECT'
GROUP BY 1, 2, 3
ORDER BY sort_order;

-- ---------------------------------------------------------------------------
-- TILE 4  Why we flag instead of delete. Grouped bar, 4 groups of 2.
-- Caption: title it "why we flag instead of delete". The 1,111 rows where the
-- source wrote a question mark withdraw 21.24 percent against 31.51 for
-- reported bands, and take distinction at nearly twice the rate. If the bars
-- matched, dropping them would be harmless. They do not match.
-- ---------------------------------------------------------------------------
SELECT
  CASE WHEN imd_band_is_missing THEN 'imd_band missing (flagged)'
       ELSE 'imd_band reported' END                                   AS cohort,
  COUNT(*)                                                            AS enrolments,
  ROUND(COUNT_IF(final_result = 'Withdrawn')   * 100.0 / COUNT(*), 2) AS pct_withdrawn,
  ROUND(COUNT_IF(final_result = 'Fail')        * 100.0 / COUNT(*), 2) AS pct_fail,
  ROUND(COUNT_IF(final_result = 'Pass')        * 100.0 / COUNT(*), 2) AS pct_pass,
  ROUND(COUNT_IF(final_result = 'Distinction') * 100.0 / COUNT(*), 2) AS pct_distinction
FROM oulad.clean.student_info
WHERE dq_status <> 'REJECT'
GROUP BY 1
ORDER BY 1;

-- ---------------------------------------------------------------------------
-- TILE 5  Q2. Withdrawal by demographic slice. Small multiples, one short bar
-- chart per slice. One query covers gender, age band, education and disability.
-- Caption: no formal qualifications is the highest at 42.94 percent, then
-- disability Y at 39.35, then repeaters at 35.26. Gender moves it 1.2 points,
-- which is to say gender is not the story.
-- ---------------------------------------------------------------------------
SELECT 'gender'            AS slice, gender            AS value, COUNT(*) AS enrolments,
       ROUND(COUNT_IF(final_result = 'Withdrawn') * 100.0 / COUNT(*), 2) AS pct_withdrawn
FROM oulad.clean.student_info WHERE dq_status <> 'REJECT' GROUP BY gender
UNION ALL
SELECT 'age_band',           age_band,           COUNT(*),
       ROUND(COUNT_IF(final_result = 'Withdrawn') * 100.0 / COUNT(*), 2)
FROM oulad.clean.student_info WHERE dq_status <> 'REJECT' GROUP BY age_band
UNION ALL
SELECT 'highest_education',  highest_education,  COUNT(*),
       ROUND(COUNT_IF(final_result = 'Withdrawn') * 100.0 / COUNT(*), 2)
FROM oulad.clean.student_info WHERE dq_status <> 'REJECT' GROUP BY highest_education
UNION ALL
SELECT 'disability',         disability,         COUNT(*),
       ROUND(COUNT_IF(final_result = 'Withdrawn') * 100.0 / COUNT(*), 2)
FROM oulad.clean.student_info WHERE dq_status <> 'REJECT' GROUP BY disability
ORDER BY slice, pct_withdrawn DESC;

-- ---------------------------------------------------------------------------
-- TILE 6  Q1. Outcome mix by previous attempts. 100% stacked bar, fixed order.
-- Caption: the 3 or more bucket is the flagged one and is labelled as such.
-- ---------------------------------------------------------------------------
SELECT
  CASE WHEN num_of_prev_attempts >= 3 THEN '3 or more (flagged)'
       ELSE CAST(num_of_prev_attempts AS STRING) END                AS prev_attempts,
  final_result,
  COUNT(*)                                                          AS enrolments
FROM oulad.clean.student_info
WHERE dq_status <> 'REJECT'
GROUP BY 1, final_result
ORDER BY 1, final_result;

-- ---------------------------------------------------------------------------
-- TILE 7  Q1. The outcome side of engagement vs performance.
-- Caption: 31.16 percent of enrolments never finished. Whatever the VLE fact
-- says about clicks, a third of the population is the group to explain.
-- ---------------------------------------------------------------------------
SELECT
  final_result,
  COUNT(*)                                                AS enrolments,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)      AS pct
FROM oulad.clean.student_info
WHERE dq_status <> 'REJECT'
GROUP BY final_result
ORDER BY enrolments DESC;

-- ---------------------------------------------------------------------------
-- TILE 8  Q3. Coverage. Heatmap, so nobody reads a trend off a thin cell.
-- Caption: 22 module presentations exist, not 28. BBB 7,909 enrolments down to
-- AAA 748, which only ran in 2013J and 2014J.
-- ---------------------------------------------------------------------------
SELECT
  code_module,
  code_presentation,
  COUNT(*)                                                       AS enrolments,
  COUNT(DISTINCT id_student)                                     AS students,
  ROUND(COUNT_IF(dq_status = 'WARN') * 100.0 / COUNT(*), 1)      AS pct_flagged
FROM oulad.clean.student_info
WHERE dq_status <> 'REJECT'
GROUP BY code_module, code_presentation
ORDER BY code_module, code_presentation;
