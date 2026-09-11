-- Business Question: Can we flag at-risk students before the course starts, using only what is known at enrollment?
WITH demographics_deduped AS (
    SELECT *
    FROM (
        SELECT
            dem.*,
            ROW_NUMBER() OVER (
                PARTITION BY CAST(dem.id_student AS BIGINT)
                ORDER BY dem.code_presentation
            ) AS rn
        FROM oulad.mart.dim_demographics AS dem
    )
    WHERE rn = 1
),

baseline_risk AS (
    SELECT
        COUNT(DISTINCT id_student) AS total_cohort_students,
        SUM(CASE WHEN final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) AS total_at_risk_students,
        ROUND(
            SUM(CASE WHEN final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) * 100.0
                / NULLIF(COUNT(DISTINCT id_student), 0), 1
        ) AS baseline_risk_pct
    FROM oulad.mart.dim_student
    WHERE final_result IS NOT NULL
),

demographic_risk_by_factor AS (
    SELECT
        'Age Band' AS risk_factor,
        COALESCE(dem.age_band, 'Unknown') AS factor_value,
        COUNT(DISTINCT s.id_student) AS total_students,
        SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) AS at_risk_count
    FROM oulad.mart.dim_student AS s
    LEFT JOIN demographics_deduped AS dem
        ON CAST(s.id_student AS BIGINT) = CAST(dem.id_student AS BIGINT)
    WHERE s.final_result IS NOT NULL
    GROUP BY dem.age_band

    UNION ALL

    SELECT
        'Highest Education' AS risk_factor,
        COALESCE(dem.highest_education, 'Unknown') AS factor_value,
        COUNT(DISTINCT s.id_student) AS total_students,
        SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) AS at_risk_count
    FROM oulad.mart.dim_student AS s
    LEFT JOIN demographics_deduped AS dem
        ON CAST(s.id_student AS BIGINT) = CAST(dem.id_student AS BIGINT)
    WHERE s.final_result IS NOT NULL
    GROUP BY dem.highest_education

    UNION ALL

    SELECT
        'IMD Band' AS risk_factor,
        COALESCE(dem.imd_band, 'Unknown') AS factor_value,
        COUNT(DISTINCT s.id_student) AS total_students,
        SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) AS at_risk_count
    FROM oulad.mart.dim_student AS s
    LEFT JOIN demographics_deduped AS dem
        ON CAST(s.id_student AS BIGINT) = CAST(dem.id_student AS BIGINT)
    WHERE s.final_result IS NOT NULL
    GROUP BY dem.imd_band

    UNION ALL

    SELECT
        'Disability' AS risk_factor,
        COALESCE(dem.disability, 'Unknown') AS factor_value,
        COUNT(DISTINCT s.id_student) AS total_students,
        SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) AS at_risk_count
    
    FROM oulad.mart.dim_student AS s
    LEFT JOIN demographics_deduped AS dem
        ON CAST(s.id_student AS BIGINT) = CAST(dem.id_student AS BIGINT)
    WHERE s.final_result IS NOT NULL
    GROUP BY dem.disability

    UNION ALL

    SELECT
        'Previous Attempts' AS risk_factor,
        COALESCE(CAST(dem.num_of_prev_attempts AS STRING), 'Unknown') AS factor_value,
        COUNT(DISTINCT s.id_student) AS total_students,
        SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) AS at_risk_count
    FROM oulad.mart.dim_student AS s
    LEFT JOIN demographics_deduped AS dem
        ON CAST(s.id_student AS BIGINT) = CAST(dem.id_student AS BIGINT)
    WHERE s.final_result IS NOT NULL
    GROUP BY dem.num_of_prev_attempts
),

final AS (
    SELECT
        f.risk_factor,
        f.factor_value,
        f.total_students,
        f.at_risk_count,
        ROUND(f.at_risk_count * 100.0 / NULLIF(f.total_students, 0), 1) AS risk_rate_pct,
        b.baseline_risk_pct,
        ROUND((f.at_risk_count * 100.0 / NULLIF(f.total_students, 0)) - b.baseline_risk_pct, 1) AS risk_delta_vs_baseline,
        CASE
            WHEN (f.at_risk_count * 100.0 / NULLIF(f.total_students, 0)) >= b.baseline_risk_pct + 10 THEN 'HIGH RISK'
            WHEN (f.at_risk_count * 100.0 / NULLIF(f.total_students, 0)) >= b.baseline_risk_pct + 5  THEN 'ELEVATED RISK'
            WHEN (f.at_risk_count * 100.0 / NULLIF(f.total_students, 0)) <= b.baseline_risk_pct - 5  THEN 'LOW RISK'
            ELSE 'AVERAGE RISK'
        END AS risk_category
    FROM demographic_risk_by_factor AS f
    CROSS JOIN baseline_risk AS b
    WHERE f.total_students >= 100
)

SELECT *
FROM final
ORDER BY risk_factor, risk_rate_pct DESC;