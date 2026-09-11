-- FACT: FactVLEInteractions
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS oulad.mart.FactVLEInteractions (
    id_student          INT NOT NULL,
    code_module         STRING NOT NULL,
    code_presentation   STRING NOT NULL,
    date                INT NOT NULL,
    id_site             INT NOT NULL,
    activity_type       STRING,
    sum_click           INT,
    CONSTRAINT pk_factvle PRIMARY KEY (id_student, code_module, code_presentation, date, id_site),
    CONSTRAINT fk_factvle_student FOREIGN KEY (id_student)
        REFERENCES oulad.mart.DimStudent (id_student),
    CONSTRAINT fk_factvle_modpres FOREIGN KEY (code_module, code_presentation)
        REFERENCES oulad.mart.DimModulePresentation (code_module, code_presentation),
    CONSTRAINT fk_factvle_date FOREIGN KEY (date)
        REFERENCES oulad.mart.DimDate (date)
) USING DELTA;

INSERT OVERWRITE oulad.mart.FactVLEInteractions
SELECT
    sv.id_student,
    sv.code_module,
    sv.code_presentation,
    sv.date,
    sv.id_site,
    v.activity_type,
    sv.sum_click
FROM oulad.clean.student_vle sv
INNER JOIN oulad.clean.vle v
    ON sv.id_site = v.id_site
    AND sv.code_module = v.code_module
    AND sv.code_presentation = v.code_presentation
WHERE sv.id_student IS NOT NULL
  AND sv.date IS NOT NULL
  AND sv.id_site IS NOT NULL;