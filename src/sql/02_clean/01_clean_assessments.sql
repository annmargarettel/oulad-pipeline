
/* ============================================================================
  ASSESSMENTS — SILVER LAYER
  Reads assessments.csv directly and produces a clean table:
  oulad.clean.clean_assessments
  No rows are ever dropped here — bad/unconvertible values become SQL NULL,
  the row itself always stays.
  ============================================================================ */



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
 
FROM oulad.raw.assessments;



