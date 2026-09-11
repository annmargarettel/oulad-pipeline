CREATE OR REPLACE TABLE oulad.mart.dim_course AS
SELECT DISTINCT
    code_module
FROM oulad.clean.courses;