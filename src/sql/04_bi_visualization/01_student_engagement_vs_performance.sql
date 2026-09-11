-- Business Question: How does student engagement relate to performance?
WITH engagement AS (
    -- Aggregate VLE interactions per student per module/presentation
    SELECT
        vle.id_student,
        vle.code_module,
        vle.code_presentation,
        SUM(vle.sum_click)                 AS total_clicks,
        COUNT(DISTINCT vle.date)           AS active_days,
        COUNT(DISTINCT vle.activity_type)  AS distinct_activity_types,
        COUNT(DISTINCT vle.id_site)        AS unique_resources_accessed
    FROM oulad.mart.fact_vle_interactions AS vle
    GROUP BY vle.id_student, vle.code_module, vle.code_presentation
),
performance AS (
    -- Aggregate assessment performance per student per module/presentation
    SELECT
        assess.id_student,
        assess.code_module,
        assess.code_presentation,
        SUM(assess.score * assess.weight) / NULLIF(SUM(assess.weight), 0) AS weighted_avg_score,
        AVG(assess.score)                                                AS simple_avg_score,
        COUNT(*)                                                         AS assessments_taken,
        COUNT(CASE WHEN assess.submission_delay > 0 THEN 1 END)          AS late_submissions,
        AVG(assess.submission_delay)                                     AS avg_submission_delay
    FROM oulad.mart.fact_assessments AS assess
    WHERE assess.is_banked = false
    GROUP BY assess.id_student, assess.code_module, assess.code_presentation
),
student_metrics AS (
    -- Join student roster (base) with engagement + performance, so zero-engagement
    -- students are kept instead of silently dropped by an inner join
    SELECT
        stud.id_student,
        eng.code_module,
        eng.code_presentation,
        stud.final_result,
        stud.is_withdrawn,
        COALESCE(eng.total_clicks, 0)               AS total_clicks,
        COALESCE(eng.active_days, 0)                AS active_days,
        COALESCE(eng.distinct_activity_types, 0)    AS distinct_activity_types,
        COALESCE(eng.unique_resources_accessed, 0)  AS unique_resources_accessed,
        perf.weighted_avg_score,
        perf.simple_avg_score,
        COALESCE(perf.assessments_taken, 0)         AS assessments_taken,
        COALESCE(perf.late_submissions, 0)          AS late_submissions,
        perf.avg_submission_delay,
        -- Relative engagement quartile PER module presentation
        -- (zero-click students naturally sort into quartile 1)
        NTILE(4) OVER (
            PARTITION BY eng.code_module, eng.code_presentation
            ORDER BY COALESCE(eng.total_clicks, 0)
        ) AS engagement_quartile
    FROM oulad.mart.dim_student AS stud
    LEFT JOIN engagement AS eng
        ON stud.id_student = eng.id_student
    LEFT JOIN performance AS perf
        ON  eng.id_student        = perf.id_student
        AND eng.code_module       = perf.code_module
        AND eng.code_presentation = perf.code_presentation
    WHERE stud.final_result IS NOT NULL
      AND eng.code_module IS NOT NULL          -- keep rows tied to an actual module/presentation
),
with_correlation AS (
    SELECT
        *,
        -- Correlation computed WITHIN each engagement quartile, not one global
        -- constant repeated across every row
        CORR(total_clicks, weighted_avg_score) OVER (
            PARTITION BY engagement_quartile
        ) AS quartile_correlation
    FROM student_metrics
)
SELECT
    engagement_quartile,
    final_result,
    COUNT(*)                                                                    AS student_count,

    -- Engagement metrics
    ROUND(AVG(total_clicks), 0)                                                 AS avg_total_clicks,
    ROUND(AVG(active_days), 1)                                                  AS avg_active_days,
    ROUND(AVG(distinct_activity_types), 1)                                      AS avg_activity_types,
    ROUND(AVG(unique_resources_accessed), 0)                                    AS avg_resources_accessed,

    -- Performance metrics
    ROUND(AVG(weighted_avg_score), 1)                                           AS avg_weighted_score,
    ROUND(AVG(simple_avg_score), 1)                                             AS avg_simple_score,
    ROUND(AVG(assessments_taken), 1)                                            AS avg_assessments_taken,
    ROUND(AVG(late_submissions), 2)                                             AS avg_late_submissions,
    ROUND(AVG(avg_submission_delay), 1)                                         AS avg_days_late,

    -- Outcome metrics
    ROUND(SUM(CASE WHEN is_withdrawn THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS withdrawal_rate_pct,
    ROUND(MAX(quartile_correlation), 3)                                         AS clicks_vs_score_corr_in_quartile

FROM with_correlation
GROUP BY engagement_quartile, final_result
ORDER BY engagement_quartile, final_result;