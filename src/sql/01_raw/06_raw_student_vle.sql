-- INGEST studentVLE.csv

CREATE TABLE IF NOT EXISTS oulad.raw.student_vle AS

SELECT *

FROM read_files(

    -- Replace with your volume file path
    '/Volumes/ftw/chinook/ftw-b12-de/shared/week07/studentVle.csv',
    format => 'csv',
    header => true,
    schema => 'code_module STRING, code_presentation STRING, id_student INT, id_site INT, date INT, sum_click INT'
)