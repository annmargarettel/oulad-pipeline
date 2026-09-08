-- =============================================================================
-- student_info  |  DQ DASHBOARD TILE QUERIES
-- Owner: Kinah
-- Sandbox: src/sql/07_testing_sandbox/Kinah
--
-- @ocharlenemae: these are the tile queries. Each block is one widget, nothing
-- writes, and every tile has a one line caption in the comment above it so the
-- dashboard can be built without asking me what a number means.
--
-- Reads oulad.clean.student_info (PR #2) and the check results from
-- 01_student_info_25_dq_checks.sql. If we have not persisted the check results
-- yet, paste that file's CTE in place of the dq_check_results reference.
--
-- The bar this is built to: a reader answers "can I trust this data" in ten
-- seconds, then drills overview, dataset, check, failure, top to bottom.
--
-- Built as a live dashboard in my workspace as
-- "OULAD Week 7 Data Quality: student_info" if you want to see the layout.
-- Colours: PASS #1B6E45, WARN #B26A00, FAIL #A62B1F, and nothing else uses them.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TILE 1  Health header. One counter row, top of the page.
-- Caption: 25 checks, 19 passed, 6 warned, 0 failed. Usable, read the flags.
-- overall_health is a sentence not a colour, because a colour needs a legend.
-- ---------------------------------------------------------------------------
SELECT
  COUNT(*)                                                     AS checks_run,
  COUNT_IF(status = 'PASS')                                    AS passed,
  COUNT_IF(status = 'WARN')                                    AS warned,
  COUNT_IF(status = 'FAIL')                                    AS failed,
  ROUND(COUNT_IF(status = 'PASS') * 100.0 / COUNT(*), 1)       AS pass_rate_pct,
  CASE WHEN COUNT_IF(status = 'FAIL') > 0 THEN 'DO NOT SHIP'
       WHEN COUNT_IF(status = 'WARN') > 0 THEN 'USABLE, READ THE FLAGS'
       ELSE                                    'HEALTHY' END   AS overall_health,
  MAX(executed_at)                                             AS last_checked
FROM oulad.validation.dq_check_results;

-- ---------------------------------------------------------------------------
-- TILE 2  Pass rate by check type. Stacked bar, colour by status.
-- Caption: SCHEMA, VOLUME and REFERENTIAL INTEGRITY are clean. UNIQUE and
-- RANGE carry every flag, which is what a moving age band and a long numeric
-- tail look like.
-- ---------------------------------------------------------------------------
SELECT check_type, status, COUNT(*) AS checks
FROM oulad.validation.dq_check_results
GROUP BY check_type, status
ORDER BY check_type, status;

-- ---------------------------------------------------------------------------
-- TILE 3  By dataset and layer. Table.
-- Caption: one dataset today. The tile exists so it still reads correctly when
-- the other five tables land, which is the point of a dashboard.
-- ---------------------------------------------------------------------------
SELECT
  layer,
  dataset,
  COUNT(*)                          AS checks,
  COUNT_IF(status = 'FAIL')         AS critical_failures,
  COUNT_IF(status = 'WARN')         AS warnings,
  MAX(executed_at)                  AS last_checked
FROM oulad.validation.dq_check_results
GROUP BY layer, dataset
ORDER BY critical_failures DESC, warnings DESC;

-- ---------------------------------------------------------------------------
-- TILE 4  Critical failures. Table, and it should normally be empty.
-- Caption: nothing here means nothing is blocking. Keep the tile on the page
-- when it is empty, showing 0 in grey. An absent tile and an empty tile look
-- identical to a reader who does not know the page, and only one reassures.
-- ---------------------------------------------------------------------------
SELECT check_id, check_name, check_type, column_name, expectation,
       fail_count, fail_pct, threshold, business_question, owner
FROM oulad.validation.dq_check_results
WHERE status = 'FAIL'
ORDER BY fail_pct DESC;

-- ---------------------------------------------------------------------------
-- TILE 5  What flagged, and what it was allowed to be. Table, worst first.
-- Caption: every row shows the threshold that decided its status, so a reader
-- can tell the difference between bad and known and tolerated.
-- ---------------------------------------------------------------------------
SELECT check_id, check_name, check_type, dq_dimension,
       fail_count, fail_pct, threshold, severity, status,
       ROUND(threshold - fail_pct, 4) AS headroom_pct,
       business_question
FROM oulad.validation.dq_check_results
WHERE fail_count > 0
ORDER BY fail_count DESC;

-- ---------------------------------------------------------------------------
-- TILE 6  Row level health. Single stacked bar, not a donut.
-- Caption: checks are a statement about the table. This is a statement about
-- the rows a reader is about to use. 84.65 percent clean, 15.35 flagged, 0 dropped.
-- ---------------------------------------------------------------------------
SELECT
  dq_status,
  COUNT(*)                                                AS rows_in_table,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)      AS pct,
  COUNT(DISTINCT id_student)                              AS students
FROM oulad.clean.student_info
GROUP BY dq_status
ORDER BY dq_status;

-- ---------------------------------------------------------------------------
-- TILE 7  Which flags fired. Horizontal bar, longest first, value labels on.
-- Caption: the label fix is the biggest at 3,516 rows. The 1,111 the source
-- wrote as a question mark is the one that matters.
-- ---------------------------------------------------------------------------
SELECT
  REPLACE(flag, 'WARN: ', '')                                                   AS flag,
  COUNT(*)                                                                      AS rows_flagged,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM oulad.clean.student_info), 2)  AS pct_of_table,
  COUNT(DISTINCT id_student)                                                    AS students_affected
FROM oulad.clean.student_info
LATERAL VIEW EXPLODE(dq_flags) AS flag
GROUP BY flag
ORDER BY rows_flagged DESC;

-- ---------------------------------------------------------------------------
-- TILE 8  The actual failing rows. Table, capped.
-- Caption: a count tells you something is wrong. This tells you what to fix.
-- Parameterise the flag in the dashboard so one tile serves all five.
-- ---------------------------------------------------------------------------
SELECT
  enrolment_key, code_module, code_presentation, id_student,
  imd_band_raw, imd_band, studied_credits, num_of_prev_attempts,
  age_bands_seen_for_student, final_result, dq_status, dq_flags
FROM oulad.clean.student_info
WHERE dq_status <> 'PASS'
ORDER BY SIZE(dq_flags) DESC, studied_credits DESC
LIMIT 200;

-- ---------------------------------------------------------------------------
-- TILE 9  Coverage. Heatmap, module on y, presentation on x, colour pct_flagged.
-- Caption: so nobody reads a trend off a thin cell. 22 module presentations
-- exist, not 28. AAA only ran in 2013J and 2014J.
-- ---------------------------------------------------------------------------
SELECT
  code_module,
  code_presentation,
  COUNT(*)                                                   AS enrolments,
  COUNT_IF(dq_status = 'WARN')                               AS rows_flagged,
  ROUND(COUNT_IF(dq_status = 'WARN') * 100.0 / COUNT(*), 1)  AS pct_flagged
FROM oulad.clean.student_info
WHERE dq_status <> 'REJECT'
GROUP BY code_module, code_presentation
ORDER BY code_module, code_presentation;
