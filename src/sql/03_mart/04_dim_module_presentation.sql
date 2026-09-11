CREATE OR REPLACE TABLE oulad.mart.dim_module_presentation AS
SELECT DISTINCT
    c.code_module,
    dc.code_module AS code_presentation_module, -- validates reference to dim_course
    c.code_presentation,
    c.module_presentation_length
FROM oulad.clean.courses AS c
INNER JOIN oulad.mart.dim_course AS dc
    ON c.code_module = dc.code_module;