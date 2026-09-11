-- ----------------------------------------------------------
-- FACT: FactVLEInteractions
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact_vle_interactions (
    id_student          INT NOT NULL,
    code_module         STRING NOT NULL,
    code_presentation   STRING NOT NULL,
    date                INT NOT NULL,
    id_site             INT NOT NULL,
    activity_type       STRING,
    sum_click           INT,
    CONSTRAINT pk_factvle PRIMARY KEY (id_student, code_module, code_presentation, date, id_site),
    CONSTRAINT fk_factvle_student FOREIGN KEY (id_student)
        REFERENCES dim_student (id_student),
    CONSTRAINT fk_factvle_modpres FOREIGN KEY (code_module, code_presentation)
        REFERENCES dim_module_presentation (code_module, code_presentation),
    CONSTRAINT fk_factvle_date FOREIGN KEY (date)
        REFERENCES DimDate (date)
) USING DELTA;