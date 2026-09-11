-- ----------------------------------------------------------
-- FACT: FactAssessments
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact_assessments (
    id_student          INT NOT NULL,
    code_module         STRING NOT NULL,
    code_presentation   STRING NOT NULL,
    date                INT NOT NULL,
    id_assessment       INT NOT NULL,
    assessment_type     STRING,
    weight              DECIMAL(5,2),
    score               DECIMAL(5,2),
    date_submitted      INT,
    submission_delay    INT,
    is_banked           BOOLEAN,
    CONSTRAINT pk_factassess PRIMARY KEY (id_student, code_module, code_presentation, date, id_assessment),
    CONSTRAINT fk_factassess_student FOREIGN KEY (id_student)
        REFERENCES dim_student (id_student),
    CONSTRAINT fk_factassess_modpres FOREIGN KEY (code_module, code_presentation)
        REFERENCES dim_module_presentation (code_module, code_presentation),
    CONSTRAINT fk_factassess_date FOREIGN KEY (date)
        REFERENCES DimDate (date)
) USING DELTA;