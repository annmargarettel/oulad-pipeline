-- How does student activity change through the course?

-- Uses DimDate's relative_week / course_phase to build a weekly activity
-- trend line, split by final outcome so trajectories can be compared.
 
SELECT
    d.course_phase,
    d.relative_week,
    s.final_result,
    COUNT(DISTINCT f.id_student)          AS active_students,
    SUM(f.sum_click)                      AS total_clicks,
    ROUND(SUM(f.sum_click) * 1.0 / COUNT(DISTINCT f.id_student), 1) AS avg_clicks_per_active_student
FROM fact_vle_interactions f
JOIN DimDate d
    ON f.date = d.date
JOIN dim_student s
    ON f.id_student = s.id_student
GROUP BY d.course_phase, d.relative_week, s.final_result
ORDER BY d.relative_week, s.final_result;
 