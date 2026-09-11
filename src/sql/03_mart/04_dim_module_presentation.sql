-- ----------------------------------------------------------
-- DIM: DimModulePresentation (grain: module + presentation)
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_module_presentation (
    code_module              STRING NOT NULL,
    code_presentation        STRING NOT NULL,
    module_presentation_length INT,
    CONSTRAINT pk_dimmodpres PRIMARY KEY (code_module, code_presentation),
    CONSTRAINT fk_dimmodpres_course FOREIGN KEY (code_module)
        REFERENCES dim_course (code_module)
) USING DELTA;