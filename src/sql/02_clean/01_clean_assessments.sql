
/* ============================================================================
  ASSESSMENTS — SILVER LAYER
  Reads assessments.csv directly and produces a clean table:
  oulad.clean.clean_assessments
  No rows are ever dropped here — bad/unconvertible values become SQL NULL,
  the row itself always stays.
  ============================================================================ */


CREATE SCHEMA IF NOT EXISTS oulad.clean;


-- Load raw CSV as STRING so the literal text "null" doesn't break casting.
CREATE OR REPLACE TEMPORARY VIEW raw_assessments AS
SELECT code_module, code_presentation, id_assessment, assessment_type, date, weight
FROM read_files(
 '/Volumes/workspace/default/ftw-b12/shared/week07/assessments.csv',
 format => 'csv',
 header => true,
 schema => 'code_module STRING, code_presentation STRING, id_assessment STRING, assessment_type STRING, date STRING, weight STRING'
);


CREATE OR REPLACE TABLE oulad.clean.clean_assessments AS
SELECT
 upper(trim(code_module))                                AS code_module,        -- standardize casing/whitespace
 upper(trim(code_presentation))                          AS code_presentation,  -- standardize casing/whitespace
 try_cast(trim(id_assessment) AS INT)                    AS id_assessment,      -- text -> int; NULL if it can't convert (row stays)
 CASE upper(trim(assessment_type))                                              -- collapse to 3 fixed values
   WHEN 'TMA'  THEN 'TMA'
   WHEN 'CMA'  THEN 'CMA'
   WHEN 'EXAM' THEN 'Exam'
   ELSE NULL                                                                    -- anything unrecognized -> NULL, row stays
 END                                                      AS assessment_type,
 try_cast(NULLIF(lower(trim(date)),   'null') AS INT)     AS date,               -- "null" text -> real NULL -> int
 try_cast(NULLIF(lower(trim(weight)), 'null') AS DOUBLE)  AS weight              -- "null" text -> real NULL -> double
FROM raw_assessments
;


