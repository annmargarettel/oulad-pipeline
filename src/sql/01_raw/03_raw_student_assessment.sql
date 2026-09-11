-- INGEST studentAssessment.csv

CREATE TABLE IF NOT EXISTS oulad.raw.student_assessment AS

SELECT *

FROM read_files(

    -- Replace with your volume file path
    '/Volumes/workspace/default/ftw-b12/shared/week07/studentAssessment.csv',
    format => 'csv',
    header => true,
    schema => 'id_assessment INT, id_student INT, date_submitted INT, is_banked INT, score INT'
)
