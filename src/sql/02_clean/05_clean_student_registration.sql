-- Clean student_registration
-- Grain: One row represents one student registering for one course presentation
-- Expected row count: 32,593 rows in, 32,593 out (no change)

-- What this file does
--     1. Sanitizes course codes by trimming whitespace, converting to UPPERCASE, and enforcing exact string length rules (3 chars for code_module, 5 chars for code_presentation); invalid or out-of-length strings are safely nullified and cast to strict VARCHAR types using TRY_CAST
--     2. Casts student IDs and day offsets strictly to integers, as student IDs in this dataset are formatted as numeric keys and relative days are kept as whole numbers
--     3. Keeps missing dates as true NULLs (without using COALESCE or text substitute) so mathematical operations, counts, and average remain accurate
--     4. Prepares the clean silver data to feed into the gold layer for dimension and fact tables

CREATE OR REPLACE TABLE oulad.clean.student_registration AS
SELECT
  -- Enforces EXACTLY 3 characters; anything else becomes NULL
  CASE 
    WHEN LENGTH(TRIM(code_module)) = 3 
    THEN TRY_CAST(UPPER(TRIM(code_module)) AS VARCHAR(3))
    ELSE NULL 
  END AS code_module,

  -- Enforces EXACTLY 5 characters for presentation codes (e.g., '2013J')
  CASE 
    WHEN LENGTH(TRIM(code_presentation)) = 5 
    THEN TRY_CAST(UPPER(TRIM(code_presentation)) AS VARCHAR(5))
    ELSE NULL 
  END AS code_presentation,

  TRY_CAST(id_student AS BIGINT) AS id_student,
  TRY_CAST(date_registration AS INT) AS date_registration,
  TRY_CAST(date_unregistration AS INT) AS date_unregistration
FROM oulad.raw.student_registration;