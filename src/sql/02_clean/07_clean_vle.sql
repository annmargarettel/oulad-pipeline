CREATE TABLE oulad.clean.vle AS
WITH data_cleaning AS (
    SELECT
        CAST(id_site AS INT) AS id_site,
        UPPER(TRIM(code_module)) AS code_module,
        UPPER(TRIM(code_presentation)) AS code_presentation,
        LOWER(TRIM(activity_type)) AS activity_type,
        CAST(week_from AS INT) AS week_from,
        CAST(week_to AS INT) AS week_to
    FROM oulad.raw.vle
),

dq_flagging AS (
    SELECT
        id_site,
        code_module,
        code_presentation,
        activity_type,
        week_from,
        week_to,
        
        -- Individual DQ Flags
        -- Invalid: NULL id_site, code_module, code_presentation, activity_type,
        -- Invalid: negative week_from, week_to
        -- Invalid: week_from > week_to
        CASE WHEN id_site IS NULL THEN 1 ELSE 0 END AS flag_null_id_site,
        CASE WHEN code_module IS NULL OR code_module = '' THEN 1 ELSE 0 END AS flag_missing_code_module,
        CASE WHEN code_presentation IS NULL OR code_presentation = '' THEN 1 ELSE 0 END AS flag_missing_code_presentation,
        CASE WHEN activity_type IS NULL OR activity_type = '' THEN 1 ELSE 0 END AS flag_missing_activity_type,
        CASE WHEN week_from < 0 THEN 1 ELSE 0 END AS flag_invalid_week_from,
        CASE WHEN week_to < 0 THEN 1 ELSE 0 END AS flag_invalid_week_to,
        CASE WHEN week_from > week_to THEN 1 ELSE 0 END AS flag_logical_week_mismatch,
        
        -- Composite DQ Status
        CASE 
            WHEN id_site IS NULL 
              OR code_module IS NULL OR code_module = '' 
              OR code_presentation IS NULL OR code_presentation = ''
              OR activity_type IS NULL OR activity_type = ''
              OR week_from < 0 OR week_to < 0 
              OR week_from > week_to 
            THEN 'INVALID'
            WHEN week_from IS NULL OR week_to IS NULL 
            THEN 'WARNING_MISSING_WEEKS'
            ELSE 'VALID'
        END AS dq_status
    FROM data_cleaning
)

SELECT 
    id_site,
    code_module,
    code_presentation,
    activity_type,
    week_from,
    week_to,
    flag_null_id_site,
    flag_missing_code_module,
    flag_missing_code_presentation,
    flag_missing_activity_type,
    flag_invalid_week_from,
    flag_invalid_week_to,
    flag_logical_week_mismatch,
    dq_status,
    CURRENT_TIMESTAMP AS processed_at
FROM dq_flagging;