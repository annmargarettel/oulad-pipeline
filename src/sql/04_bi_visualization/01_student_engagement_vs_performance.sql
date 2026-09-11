%sql
-- Business Question: How does student engagement relate to performance?
--
WITH engagement AS (
    -- Aggregate VLE interactions per student per module/presentation
    SELECT
        vle.id_student,
        vle.code_module,
        vle.code_presentation,
        SUM(vle.sum_click)                AS total_clicks,
        COUNT(DISTINCT vle.date)          AS active_days,
        COUNT(DISTINCT vle.activity_type) AS distinct_activity_types,
        COUNT(DISTINCT vle.id_site)       AS unique_resources_accessed
    FROM fact_vle_interactions vle
    GROUP BY vle.id_student, vle.code_module, vle.code_presentation
),
performance AS (
    -- Aggregate assessment performance per student per module/presentation
    SELECT
        assess.id_student,
        assess.code_module,
        assess.code_presentation,
        -- Weight scores by assessment weight for accurate performance measure
        SUM(assess.score * assess.weight) / NULLIF(SUM(assess.weight), 0) AS weighted_avg_score,
        AVG(assess.score)                                                   AS simple_avg_score,
        COUNT(*)                                                            AS assessments_taken,
        COUNT(CASE WHEN assess.submission_delay > 0 THEN 1 END)             AS late_submissions,
        AVG(assess.submission_delay)                                        AS avg_submission_delay
    FROM fact_assessments assess
    WHERE assess.is_banked = false  -- Exclude banked/resit assessments for cleaner signal
    GROUP BY assess.id_student, assess.code_module, assess.code_presentation
),
student_metrics AS (
    -- Join engagement + performance + actual outcomes, add engagement quartile
    SELECT
        stud.id_student,
        stud.final_result,
        stud.is_withdrawn,
        eng.total_clicks,
        eng.active_days,
        eng.distinct_activity_types,
        eng.unique_resources_accessed,
        perf.weighted_avg_score,
        perf.simple_avg_score,
        perf.assessments_taken,
        perf.late_submissions,
        perf.avg_submission_delay,
        -- NTILE(4) creates 4 equal-sized groups based on total clicks
        NTILE(4) OVER (ORDER BY eng.total_clicks) AS engagement_quartile
    FROM engagement eng
    INNER JOIN performance perf
        ON  eng.id_student        = perf.id_student
        AND eng.code_module       = perf.code_module
        AND eng.code_presentation = perf.code_presentation
    INNER JOIN dim_student stud
        ON eng.id_student = stud.id_student
    WHERE stud.final_result IS NOT NULL  -- Only students with known outcomes
),
with_correlation AS (
    -- Calculate correlation in separate CTE to avoid window function nesting
    SELECT
        *,
        -- CORR() measures linear relationship between clicks and performance (-1 to +1)
        CORR(total_clicks, weighted_avg_score) OVER () AS overall_correlation
    FROM student_metrics
)
SELECT
    engagement_quartile,
    final_result,
    COUNT(*)                                   AS student_count,
    
    -- Engagement metrics by quartile and outcome
    ROUND(AVG(total_clicks), 0)                AS avg_total_clicks,
    ROUND(AVG(active_days), 1)                 AS avg_active_days,
    ROUND(AVG(distinct_activity_types), 1)     AS avg_activity_types,
    ROUND(AVG(unique_resources_accessed), 0)   AS avg_resources_accessed,
    
    -- Performance metrics by quartile and outcome
    ROUND(AVG(weighted_avg_score), 1)          AS avg_weighted_score,
    ROUND(AVG(simple_avg_score), 1)            AS avg_simple_score,
    ROUND(AVG(assessments_taken), 1)           AS avg_assessments_taken,
    ROUND(AVG(late_submissions), 2)            AS avg_late_submissions,
    ROUND(AVG(avg_submission_delay), 1)        AS avg_days_late,
    
    -- Withdrawal rate within each group
    ROUND(SUM(CASE WHEN is_withdrawn THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS withdrawal_rate_pct,
    
    -- Overall correlation (same for all rows)
    ROUND(MAX(overall_correlation), 3)         AS clicks_vs_score_corr
FROM with_correlation
GROUP BY engagement_quartile, final_result
ORDER BY engagement_quartile, final_result;