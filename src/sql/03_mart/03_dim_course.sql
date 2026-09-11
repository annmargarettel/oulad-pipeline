CREATE TABLE IF NOT EXISTS dim_course (
    code_module STRING NOT NULL,
    CONSTRAINT pk_dimcourse PRIMARY KEY (code_module)
) USING DELTA;