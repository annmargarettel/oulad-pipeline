-- ----------------------------------------------------------
-- DIM: DimDate (grain: calendar date)
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS DimDate (
    date            INT NOT NULL,
    relative_week   INT,
    course_phase    STRING,
    CONSTRAINT pk_dimdate PRIMARY KEY (date)
) USING DELTA;