-- Business Question: How does student activity change through the course?
WITH activity_totals AS (
    SELECT 
        activity_type,
        SUM(sum_click) AS total_vol
    FROM oulad.mart.fact_vle_interactions
    GROUP BY activity_type
),

top_activities AS (
    SELECT activity_type
    FROM activity_totals
    ORDER BY total_vol DESC
    LIMIT 2
),

activity_bucketed AS (
    SELECT
        f.id_student,
        f.date,
        f.sum_click,
        CASE 
            WHEN f.activity_type IN (SELECT activity_type FROM top_activities) 
            THEN f.activity_type 
            ELSE 'Other' 
        END AS activity_type_grouped
    FROM oulad.mart.fact_vle_interactions AS f
)

SELECT
    d.course_phase,
    d.relative_week,
    s.final_result,
    a.activity_type_grouped,
    COUNT(DISTINCT a.id_student)  AS active_students,
    SUM(a.sum_click)              AS total_clicks,
    ROUND(SUM(a.sum_click) * 1.0 / NULLIF(COUNT(DISTINCT a.id_student), 0), 1) AS avg_clicks_per_active_student

FROM activity_bucketed AS a
INNER JOIN oulad.mart.dim_date AS d
    ON a.date = d.date
INNER JOIN oulad.mart.dim_student AS s
    ON a.id_student = s.id_student
WHERE s.final_result IS NOT NULL
GROUP BY 
    d.course_phase,
    d.relative_week,
    s.final_result,
    a.activity_type_grouped
ORDER BY 
    d.relative_week ASC,
    a.activity_type_grouped ASC;