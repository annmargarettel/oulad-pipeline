-- DIM: DimDate (grain: calendar date)
-- ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS oulad.mart.DimDate (
    date            INT NOT NULL,
    relative_week   INT,
    course_phase    STRING,
    CONSTRAINT pk_dimdate PRIMARY KEY (date)
) USING DELTA;

-- DIM: DimDate
-- Grain: one row per unique date
-- Generate from all date columns across tables
-- ----------------------------------------------------------
INSERT OVERWRITE oulad.mart.DimDate
WITH all_dates AS (
    -- Dates from assessments
    SELECT DISTINCT date AS date_value
    FROM oulad.clean.clean_assessments
    WHERE date IS NOT NULL
    
    UNION
    
    -- Dates from student_vle
    SELECT DISTINCT date AS date_value
    FROM oulad.clean.student_vle
    WHERE date IS NOT NULL
    
    UNION
    
    -- Registration dates
    SELECT DISTINCT date_registration AS date_value
    FROM oulad.clean.student_registration
    WHERE date_registration IS NOT NULL
    
    UNION
    
    -- Unregistration dates
    SELECT DISTINCT date_unregistration AS date_value
    FROM oulad.clean.student_registration
    WHERE date_unregistration IS NOT NULL
    
    UNION
    
    -- Submission dates
    SELECT DISTINCT date_submitted AS date_value
    FROM oulad.clean.clean_student_assessment
    WHERE date_submitted IS NOT NULL
)
SELECT
    date_value AS date,
    FLOOR(date_value / 7) AS relative_week,
    CASE
        WHEN date_value < 0 THEN 'Pre-course'
        WHEN date_value BETWEEN 0 AND 90 THEN 'Early'
        WHEN date_value BETWEEN 91 AND 180 THEN 'Mid'
        WHEN date_value > 180 THEN 'Late'
        ELSE 'Unknown'
    END AS course_phase
FROM all_dates;