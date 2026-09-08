-- Clean student_registration
-- Grain: One row represents one student registering for one course presentation
-- Expected row count: 32,593 rows in, 32,593 out (no change)

-- What this file does
--     1. Casts course codes to strict VARCHAR types (3 and 5 characters) while trimming whitespace and converting letters to UPPERCASE for exact formatting
--     2. Casts student IDs and day offsets strictly to integers, as student IDs in this dataset are formatted as numeric keys and relative days are kept as whole numbers
--     3. Keeps missing dates as true NULLs (without using COALESCE or text substitute) so mathematical operations, counts, and average remain accurate
--     4. Prepares the clean silver data to feed into the gold layer for dimension and fact tables

CREATE OR REPLACE TABLE oulad.clean.student_registration AS
SELECT
  UPPER(TRIM(CAST(code_module AS VARCHAR(3)))) AS code_module,
  UPPER(TRIM(CAST(code_presentation AS VARCHAR(5)))) AS code_presentation,
  CAST(id_student AS INT) AS id_student,
  CAST(date_registration AS INT) AS date_registration,
  CAST(date_unregistration AS INT) AS date_unregistration
FROM oulad.raw.student_registration;