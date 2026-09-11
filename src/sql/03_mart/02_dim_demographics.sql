-- DIM: DimDemographics (grain: student + module + presentation)
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS DimDemographics (
    id_student              INT NOT NULL,
    code_module             STRING NOT NULL,
    code_presentation       STRING NOT NULL,
    gender                  STRING,
    region                  STRING,
    highest_education       STRING,
    imd_band                STRING,
    age_band                STRING,
    num_of_previous_attempts INT,
    studied_credits         INT,
    disability              STRING,
    CONSTRAINT pk_dimdemo PRIMARY KEY (id_student, code_module, code_presentation),
    CONSTRAINT fk_dimdemo_student FOREIGN KEY (id_student)
        REFERENCES DimStudent (id_student),
    CONSTRAINT fk_dimdemo_modpres FOREIGN KEY (code_module, code_presentation)
        REFERENCES DimModulePresentation (code_module, code_presentation)
) USING DELTA;


-- DIM: DimDemographics
-- Grain: one row per student per module presentation
-- ----------------------------------------------------------
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

