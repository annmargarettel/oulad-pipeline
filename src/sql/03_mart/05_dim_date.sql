CREATE OR REPLACE TABLE oulad.mart.dim_date AS
WITH date_sequence AS (
    -- Generates a range of relative days covering pre-course (-30) to end of module (300)
    SELECT explode(sequence(-30, 300)) AS date
)
SELECT 
    date,
    -- Calculate relative week (Day 0-6 = Week 1, Day -7 to -1 = Week 0/Pre-course, etc.)
    CAST(FLOOR(date / 7.0) AS INT) AS relative_week,
    -- Assign business course phases
    CASE 
        WHEN date < 0 THEN 'Pre-Course'
        WHEN date BETWEEN 0 AND 30 THEN 'Early Course'
        WHEN date BETWEEN 31 AND 180 THEN 'Mid Course'
        ELSE 'Late / Assessment Phase'
    END AS course_phase
FROM date_sequence;