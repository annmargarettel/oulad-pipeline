-- DIM: DimStudent (grain: student)
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS DimStudent (
    id_student          INT NOT NULL,
    final_result        STRING,
    date_registration   INT,
    date_unregistration INT,
    is_withdrawn        BOOLEAN,
    CONSTRAINT pk_dimstudent PRIMARY KEY (id_student)
) USING DELTA;

-- DIM: DimStudent
-- Grain: one row per student
-- Combines student_info and student_registration
-- ----------------------------------------------------------
INSERT OVERWRITE DimStudent
SELECT DISTINCT
    si.id_student,
    si.final_result,
    sr.date_registration,
    sr.date_unregistration,
    si.is_withdrawn
FROM oulad.clean.student_info si
LEFT JOIN oulad.clean.student_registration sr
    ON si.id_student = sr.id_student
    AND si.code_module = sr.code_module
    AND si.code_presentation = sr.code_presentation
WHERE si.id_student IS NOT NULL;

-- ----------------------------------------------------------
-- DIM: DimModulePresentation
-- Grain: one row per module + presentation combination
-- ----------------------------------------------------------
INSERT OVERWRITE DimModulePresentation
SELECT DISTINCT
    code_module,
    code_presentation,
    module_presentation_length
FROM oulad.clean.courses;
