CREATE TABLE IF NOT EXISTS DimCourse (
    code_module STRING NOT NULL,
    CONSTRAINT pk_dimcourse PRIMARY KEY (code_module)
) USING DELTA;

INSERT OVERWRITE DimCourse
SELECT DISTINCT
    code_module
FROM oulad.clean.courses;