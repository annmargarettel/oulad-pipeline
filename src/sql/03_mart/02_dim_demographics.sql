-- ----------------------------------------------------------
-- DIM: DimDemographics (grain: student + module + presentation)
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_demographics (
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
        REFERENCES dim_student (id_student),
    CONSTRAINT fk_dimdemo_modpres FOREIGN KEY (code_module, code_presentation)
        REFERENCES dim_module_presentation (code_module, code_presentation)
) USING DELTA;