-- Question 4: Can we flag at-risk students before the course starts, 
-- using only what is known at enrollment?
--
-- CONSTRAINT: Uses ONLY pre-enrollment demographic data from DimDemographics
-- NO engagement data, NO assessment data, NO activity patterns
--
-- Approach:
-- 1. Calculate risk rates (% Fail/Withdrawn) for each demographic segment
-- 2. Identify high-risk demographic combinations
-- 3. Create a composite risk score based on multiple factors

-- Step 1: Calculate risk rates by demographic factor
WITH demographic_risk_by_factor AS (
    SELECT
        'age_band' AS risk_factor,
        dem.age_band AS factor_value,
        COUNT(*) AS total_students,
        SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) AS at_risk_count,
        ROUND(SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS risk_rate_pct
    FROM dim_demographics dem
    JOIN dim_student s ON dem.id_student = s.id_student
    WHERE s.final_result IS NOT NULL
    GROUP BY dem.age_band
    
    UNION ALL
    
    SELECT
        'highest_education' AS risk_factor,
        dem.highest_education AS factor_value,
        COUNT(*) AS total_students,
        SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) AS at_risk_count,
        ROUND(SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS risk_rate_pct
    FROM dim_demographics dem
    JOIN dim_student s ON dem.id_student = s.id_student
    WHERE s.final_result IS NOT NULL
    GROUP BY dem.highest_education
    
    UNION ALL
    
    SELECT
        'imd_band' AS risk_factor,
        dem.imd_band AS factor_value,
        COUNT(*) AS total_students,
        SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) AS at_risk_count,
        ROUND(SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS risk_rate_pct
    FROM dim_demographics dem
    JOIN dim_student s ON dem.id_student = s.id_student
    WHERE s.final_result IS NOT NULL
    GROUP BY dem.imd_band
    
    UNION ALL
    
    SELECT
        'disability' AS risk_factor,
        dem.disability AS factor_value,
        COUNT(*) AS total_students,
        SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) AS at_risk_count,
        ROUND(SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS risk_rate_pct
    FROM dim_demographics dem
    JOIN dim_student s ON dem.id_student = s.id_student
    WHERE s.final_result IS NOT NULL
    GROUP BY dem.disability
    
    UNION ALL
    
    SELECT
        'num_previous_attempts' AS risk_factor,
        CAST(dem.num_of_previous_attempts AS STRING) AS factor_value,
        COUNT(*) AS total_students,
        SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) AS at_risk_count,
        ROUND(SUM(CASE WHEN s.final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS risk_rate_pct
    FROM dim_demographics dem
    JOIN dim_student s ON dem.id_student = s.id_student
    WHERE s.final_result IS NOT NULL
    GROUP BY dem.num_of_previous_attempts
),

-- Step 2: Calculate overall baseline risk rate
baseline_risk AS (
    SELECT
        ROUND(SUM(CASE WHEN final_result IN ('Fail', 'Withdrawn') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS baseline_risk_pct
    FROM dim_student
    WHERE final_result IS NOT NULL
)

-- Step 3: Identify high-risk factors (above baseline)
SELECT
    risk_factor,
    factor_value,
    total_students,
    at_risk_count,
    risk_rate_pct,
    (SELECT baseline_risk_pct FROM baseline_risk) AS baseline_risk_pct,
    ROUND(risk_rate_pct - (SELECT baseline_risk_pct FROM baseline_risk), 1) AS risk_delta_vs_baseline,
    CASE
        WHEN risk_rate_pct >= (SELECT baseline_risk_pct FROM baseline_risk) + 10 THEN 'HIGH RISK'
        WHEN risk_rate_pct >= (SELECT baseline_risk_pct FROM baseline_risk) + 5 THEN 'ELEVATED RISK'
        WHEN risk_rate_pct <= (SELECT baseline_risk_pct FROM baseline_risk) - 5 THEN 'LOW RISK'
        ELSE 'AVERAGE RISK'
    END AS risk_category
FROM demographic_risk_by_factor
WHERE total_students >= 100  -- Only factors with sufficient sample size
ORDER BY risk_rate_pct DESC, total_students DESC;