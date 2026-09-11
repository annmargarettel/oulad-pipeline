-- FACT: FactAssessments
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS FactAssessments (
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
        REFERENCES DimStudent (id_student),
    CONSTRAINT fk_factassess_modpres FOREIGN KEY (code_module, code_presentation)
        REFERENCES DimModulePresentation (code_module, code_presentation),
    CONSTRAINT fk_factassess_date FOREIGN KEY (date)
        REFERENCES DimDate (date)
) USING DELTA;

-- ----------------------------------------------------------
INSERT OVERWRITE FactAssessments
SELECT
    sa.id_student,
    a.code_module,
    a.code_presentation,
    a.date,
    sa.id_assessment,
    a.assessment_type,
    a.weight,
    sa.score,
    sa.date_submitted,
    (sa.date_submitted - a.date) AS submission_delay,
    CAST(sa.is_banked AS BOOLEAN) AS is_banked
FROM oulad.clean.student_assessment sa
INNER JOIN oulad.clean.01_clean_assessments a
    ON sa.id_assessment = a.id_assessment
WHERE sa.id_student IS NOT NULL
  AND sa.id_assessment IS NOT NULL
  AND a.date IS NOT NULL;

