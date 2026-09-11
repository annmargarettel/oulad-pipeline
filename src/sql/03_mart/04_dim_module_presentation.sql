-- DIM: DimModulePresentation (grain: module + presentation)
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS oulad.mart.DimModulePresentation (
    code_module              STRING NOT NULL,
    code_presentation        STRING NOT NULL,
    module_presentation_length INT,
    CONSTRAINT pk_dimmodpres PRIMARY KEY (code_module, code_presentation),
    CONSTRAINT fk_dimmodpres_course FOREIGN KEY (code_module)
        REFERENCES oulad.mart.DimCourse (code_module)
) USING DELTA;

INSERT OVERWRITE oulad.mart.DimModulePresentation
SELECT DISTINCT
    code_module,
    code_presentation,
    module_presentation_length
FROM oulad.clean.courses;