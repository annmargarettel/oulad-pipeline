CREATE TABLE IF NOT EXISTS oulad.mart.DimCourse (
    code_module STRING NOT NULL,
    CONSTRAINT pk_dimcourse PRIMARY KEY (code_module)
) USING DELTA;

INSERT OVERWRITE oulad.mart.DimCourse
SELECT DISTINCT
    code_module
FROM oulad.clean.courses;