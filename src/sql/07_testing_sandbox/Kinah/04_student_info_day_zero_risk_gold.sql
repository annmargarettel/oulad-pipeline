-- =============================================================================
-- student_info  |  DAY ZERO WITHDRAWAL RISK  |  the bonus question
-- Owner: Kinah
-- Sandbox: src/sql/07_testing_sandbox/Kinah
--
-- QUESTION: can we flag an at-risk student before the course starts, using only
-- what is known on day zero?
--
-- Yes, and this is the transparent version. An additive rubric over enrolment
-- time columns only. It never reads final_result, so it is not fitted to the
-- answer. final_result appears once at the bottom, purely to validate.
--
-- Nothing writes. To persist, wrap in
--   CREATE OR REPLACE TABLE oulad.mart.student_risk_at_enrolment AS ...
-- but that is Crizza's layer, so flagging it here rather than creating it.
--
-- VALIDATED RESULT
--   low      19,036 rows  58.4%  avg score 0.61  withdrawn 25.08%  distinction 12.12%
--   medium   11,994 rows  36.8%  avg score 2.30  withdrawn 38.15%  distinction  5.71%
--   high      1,563 rows   4.8%  avg score 4.29  withdrawn 51.57%  distinction  1.98%
--
-- Withdrawal roughly doubles low to high. Distinction falls six-fold.
--
-- SAY THIS OUT LOUD WHEN PRESENTING IT: that is a cohort ranking, not a
-- prediction. Roughly half the high band did not withdraw. It is a list of who
-- to reach out to first, not a verdict on anyone.
-- =============================================================================

WITH scored AS (
  SELECT
    enrolment_key,
    code_module,
    code_presentation,
    id_student,

    -- the rubric, all day zero columns
      CASE WHEN studied_credits > 240      THEN 3
           WHEN studied_credits > 120      THEN 2
           WHEN studied_credits > 60       THEN 1
           ELSE 0 END
    + CASE WHEN num_of_prev_attempts >= 3  THEN 2
           WHEN num_of_prev_attempts >= 1  THEN 1
           ELSE 0 END
    + CASE WHEN imd_decile_low <= 20       THEN 1 ELSE 0 END
    + CASE WHEN highest_education IN ('No Formal quals', 'Lower Than A Level')
                                           THEN 1 ELSE 0 END
    + CASE WHEN disability = 'Y'           THEN 1 ELSE 0 END   AS risk_score,

    -- the reasons, so a human can see why a student scored what they scored
    ARRAY_COMPACT(ARRAY(
      CASE WHEN studied_credits > 240      THEN 'credit load over 240' END,
      CASE WHEN studied_credits > 120 AND studied_credits <= 240
                                           THEN 'credit load 121 to 240' END,
      CASE WHEN studied_credits > 60  AND studied_credits <= 120
                                           THEN 'credit load 61 to 120' END,
      CASE WHEN num_of_prev_attempts >= 3  THEN 'three or more previous attempts' END,
      CASE WHEN num_of_prev_attempts BETWEEN 1 AND 2
                                           THEN 'one or two previous attempts' END,
      CASE WHEN imd_decile_low <= 20       THEN 'most deprived two bands' END,
      CASE WHEN highest_education IN ('No Formal quals', 'Lower Than A Level')
                                           THEN 'below A level on entry' END,
      CASE WHEN disability = 'Y'           THEN 'disability declared' END
    ))                                                          AS risk_reasons,

    studied_credits,
    num_of_prev_attempts,
    imd_band,
    imd_decile_low,
    highest_education,
    disability,
    final_result
  FROM oulad.clean.student_info
  WHERE dq_status <> 'REJECT'
)

SELECT
  enrolment_key,
  code_module,
  code_presentation,
  id_student,
  risk_score,
  CASE WHEN risk_score >= 4 THEN '3. high'
       WHEN risk_score >= 2 THEN '2. medium'
       ELSE                      '1. low' END AS risk_band,
  risk_reasons,
  studied_credits,
  num_of_prev_attempts,
  imd_band,
  highest_education,
  disability,
  final_result
FROM scored;

-- ---------------------------------------------------------------------------
-- VALIDATION. Run this after the above. This is the only place final_result
-- is used, and only to check the rubric separates the cohort.
-- If the three withdrawal rates are flat, the rubric is worthless. They are not.
-- ---------------------------------------------------------------------------
WITH scored AS (
  SELECT
      CASE WHEN studied_credits > 240      THEN 3
           WHEN studied_credits > 120      THEN 2
           WHEN studied_credits > 60       THEN 1
           ELSE 0 END
    + CASE WHEN num_of_prev_attempts >= 3  THEN 2
           WHEN num_of_prev_attempts >= 1  THEN 1
           ELSE 0 END
    + CASE WHEN imd_decile_low <= 20       THEN 1 ELSE 0 END
    + CASE WHEN highest_education IN ('No Formal quals', 'Lower Than A Level')
                                           THEN 1 ELSE 0 END
    + CASE WHEN disability = 'Y'           THEN 1 ELSE 0 END   AS risk_score,
    final_result
  FROM oulad.clean.student_info
  WHERE dq_status <> 'REJECT'
)
SELECT
  CASE WHEN risk_score >= 4 THEN '3. high'
       WHEN risk_score >= 2 THEN '2. medium'
       ELSE                      '1. low' END                            AS risk_band,
  COUNT(*)                                                               AS enrolments,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)                     AS pct_of_cohort,
  ROUND(AVG(risk_score), 2)                                              AS avg_risk_score,
  ROUND(COUNT_IF(final_result = 'Withdrawn')   * 100.0 / COUNT(*), 2)    AS pct_withdrawn,
  ROUND(COUNT_IF(final_result = 'Distinction') * 100.0 / COUNT(*), 2)    AS pct_distinction
FROM scored
GROUP BY 1
ORDER BY 1;
