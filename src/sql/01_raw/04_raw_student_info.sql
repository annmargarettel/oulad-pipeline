-- INGEST studentInfo.csv

CREATE TABLE IF NOT EXISTS oulad.raw.student_info AS

SELECT *

FROM read_files(

    -- Replace with your volume file path
    '/Volumes/workspace/default/ftw-b12/shared/week07/studentInfo.csv',
    format => 'csv',
    header => true,
    schema => 'code_module STRING, code_presentation STRING, id_student INT, gender STRING, region STRING, highest_education STRING, imd_band STRING, age_band STRING, num_of_prev_attempts INT, studied_credits INT, disability STRING, final_result STRING'
)
