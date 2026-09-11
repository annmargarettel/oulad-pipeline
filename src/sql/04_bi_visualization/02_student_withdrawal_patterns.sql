--What patterns appear among students who withdraw?

-- Compares withdrawn vs non-withdrawn students across:
--   (a) demographic profile (DimDemographics)
--   (b) engagement level and how early it dropped off (FactVLEInteractions + DimDate)
 
WITH student_engagement AS (
    SELECT
        f.id_student,
        f.code_module,
        f.code_presentation,
        SUM(f.sum_click)                                   AS total_clicks,
        MAX(d.relative_week)                               AS last_active_week,
        MAX(CASE WHEN d.relative_week <= 4  THEN f.sum_click END) AS early_clicks
    FROM fact_vle_interactions f
    JOIN DimDate d ON f.date = d.date
    GROUP BY f.id_student, f.code_module, f.code_presentation
)
SELECT
    s.is_withdrawn,
    dem.age_band,
    dem.highest_education,
    dem.imd_band,
    dem.disability,
    dem.num_of_previous_attempts,
    dem.studied_credits,
    COUNT(DISTINCT s.id_student)                    AS num_students,
    ROUND(AVG(se.total_clicks), 0)                  AS avg_total_clicks,
    ROUND(AVG(se.last_active_week), 1)              AS avg_last_active_week,
    ROUND(AVG(s.date_unregistration), 1)            AS avg_unregistration_day
FROM dim_student s
JOIN dim_demographics dem
    ON s.id_student = dem.id_student
JOIN student_engagement se
    ON  s.id_student        = se.id_student
    AND dem.code_module     = se.code_module
    AND dem.code_presentation = se.code_presentation
GROUP BY
    s.is_withdrawn, dem.age_band, dem.highest_education,
    dem.imd_band, dem.disability, dem.num_of_previous_attempts, dem.studied_credits
ORDER BY s.is_withdrawn DESC, num_students DESC;
