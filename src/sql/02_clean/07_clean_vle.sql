%sql
-- Create cleaned student_vle table by aggregating duplicate records
-- This combines multiple interactions on the same day by the same student on the same site

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