%sql

CREATE OR REPLACE TABLE oulad.clean.student_vle AS
SELECT 
  code_module,
  code_presentation,
  id_student,
  id_site,
  date,
  SUM(sum_click) as sum_click,  -- Aggregate clicks from duplicates
  COUNT(*) as original_record_count  -- Track how many raw records were combined
FROM oulad.raw.student_vle
GROUP BY 
  code_module,
  code_presentation,
  id_student,
  id_site,
  date
ORDER BY 
  code_module,
  code_presentation,
  id_student,
  date;

-- Compare raw vs cleaned table statistics

SELECT 
  'Raw Table' as table_name,
  COUNT(*) as total_rows,
  COUNT(DISTINCT CONCAT(code_module, code_presentation, id_student, id_site, date)) as unique_combinations,
  COUNT(DISTINCT id_student) as unique_students,
  SUM(sum_click) as total_clicks
FROM oulad.raw.student_vle

UNION ALL

SELECT 
  'Clean Table' as table_name,
  COUNT(*) as total_rows,
  COUNT(DISTINCT CONCAT(code_module, code_presentation, id_student, id_site, date)) as unique_combinations,
  COUNT(DISTINCT id_student) as unique_students,
  SUM(sum_click) as total_clicks
FROM oulad.clean.student_vle;

-- Create a table with outlier flags for further investigation

CREATE OR REPLACE TABLE oulad.clean.student_vle_with_flags AS
SELECT 
  *,
  -- Flag outliers and edge cases
  CASE 
    WHEN sum_click > 1000 THEN 'high_click_outlier'
    WHEN sum_click > 5000 THEN 'extreme_click_outlier'
    ELSE 'normal'
  END as click_outlier_flag,
  
  CASE 
    WHEN date < -20 THEN 'pre_course_access'
    WHEN date > 250 THEN 'late_course_access'
    WHEN date < 0 THEN 'pre_start_normal'
    ELSE 'normal'
  END as date_outlier_flag,
  
  -- Add a composite quality flag
  CASE 
    WHEN sum_click > 1000 OR date < -20 OR date > 250 THEN 'review_needed'
    ELSE 'clean'
  END as quality_flag
  
FROM oulad.clean.student_vle;

-- Get counts of flagged records by type

SELECT 
  quality_flag,
  click_outlier_flag,
  date_outlier_flag,
  COUNT(*) as record_count,
  COUNT(DISTINCT id_student) as student_count,
  MIN(sum_click) as min_clicks,
  MAX(sum_click) as max_clicks,
  AVG(sum_click) as avg_clicks,
  MIN(date) as min_date,
  MAX(date) as max_date
FROM oulad.clean.student_vle_with_flags
GROUP BY quality_flag, click_outlier_flag, date_outlier_flag
ORDER BY record_count DESC;

-- Investigate records with unusually high click counts

SELECT 
  code_module,
  code_presentation,
  id_student,
  id_site,
  date,
  sum_click,
  original_record_count,
  click_outlier_flag,
  date_outlier_flag
FROM oulad.clean.student_vle_with_flags
WHERE sum_click > 1000
ORDER BY sum_click DESC
LIMIT 50;

-- Create final cleaned table excluding extreme outliers
-- You can adjust filtering criteria based on business rules

CREATE OR REPLACE TABLE oulad.clean.student_vle_final AS
SELECT 
  code_module,
  code_presentation,
  id_student,
  id_site,
  date,
  sum_click,
  -- Add metadata columns
  original_record_count,
  CASE 
    WHEN date < -20 THEN TRUE 
    ELSE FALSE 
  END as is_pre_course_access,
  CASE 
    WHEN date > 250 THEN TRUE 
    ELSE FALSE 
  END as is_late_access,
  CASE 
    WHEN sum_click > 1000 THEN TRUE 
    ELSE FALSE 
  END as is_high_click_outlier
FROM oulad.clean.student_vle_with_flags
WHERE 
  sum_click <= 5000  -- Remove only extreme outliers (adjust threshold as needed)
  -- Uncomment below to also filter by date range:
  -- AND date >= -20 
  -- AND date <= 250
ORDER BY 
  code_module,
  code_presentation,
  id_student,
  date;

-- Final summary statistics comparing all versions

SELECT 
  'Raw' as version,
  COUNT(*) as total_records,
  COUNT(DISTINCT id_student) as unique_students,
  COUNT(DISTINCT id_site) as unique_sites,
  SUM(sum_click) as total_clicks,
  AVG(sum_click) as avg_clicks,
  MIN(date) as min_date,
  MAX(date) as max_date
FROM oulad.raw.student_vle

UNION ALL

SELECT 
  'Deduplicated' as version,
  COUNT(*) as total_records,
  COUNT(DISTINCT id_student) as unique_students,
  COUNT(DISTINCT id_site) as unique_sites,
  SUM(sum_click) as total_clicks,
  AVG(sum_click) as avg_clicks,
  MIN(date) as min_date,
  MAX(date) as max_date
FROM oulad.clean.student_vle

UNION ALL

SELECT 
  'Final Clean' as version,
  COUNT(*) as total_records,
  COUNT(DISTINCT id_student) as unique_students,
  COUNT(DISTINCT id_site) as unique_sites,
  SUM(sum_click) as total_clicks,
  AVG(sum_click) as avg_clicks,
  MIN(date) as min_date,
  MAX(date) as max_date
FROM oulad.clean.student_vle_final

ORDER BY version;

