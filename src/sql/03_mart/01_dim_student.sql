-- ----------------------------------------------------------
-- DIM: DimStudent (grain: student)
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_student (
    id_student          INT NOT NULL,
    final_result        STRING,
    date_registration   INT,
    date_unregistration INT,
    is_withdrawn        BOOLEAN,
    CONSTRAINT pk_dimstudent PRIMARY KEY (id_student)
) USING DELTA;