-- Business Question: What patterns appear among students who withdraw?
WITH withdrawals AS (
    SELECT
        id_student,
        date_unregistration
    FROM oulad.mart.dim_student
    WHERE final_result IS NOT NULL
      AND is_withdrawn = TRUE
      AND date_unregistration IS NOT NULL
),

binned AS (
    SELECT
        FLOOR(date_unregistration / 90.0) * 90 AS bin_start,
        FLOOR(date_unregistration / 90.0) * 90 + 89 AS bin_end
    FROM withdrawals
)

SELECT
    bin_start,
    bin_end,
    CONCAT(CAST(bin_start AS STRING), ' to ', CAST(bin_end AS STRING)) AS day_bin_label,
    COUNT(*) AS withdrawal_count

FROM binned
GROUP BY bin_start, bin_end
ORDER BY bin_start;