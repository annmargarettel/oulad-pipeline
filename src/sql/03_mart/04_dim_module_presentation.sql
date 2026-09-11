-- DIM: DimModulePresentation (grain: module + presentation)
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS DimModulePresentation (
    code_module              STRING NOT NULL,
    code_presentation        STRING NOT NULL,
    module_presentation_length INT,
    CONSTRAINT pk_dimmodpres PRIMARY KEY (code_module, code_presentation),
    CONSTRAINT fk_dimmodpres_course FOREIGN KEY (code_module)
        REFERENCES DimCourse (code_module)
) USING DELTA;

INSERT OVERWRITE DimDemographics
SELECT
    id_student,
    code_module,
    code_presentation,
    gender,
    region,
    highest_education,
    imd_band,
    age_band,
    num_of_prev_attempts AS num_of_previous_attempts,
    studied_credits,
    disability
FROM oulad.clean.student_info
WHERE id_student IS NOT NULL
  AND code_module IS NOT NULL
  AND code_presentation IS NOT NULL;