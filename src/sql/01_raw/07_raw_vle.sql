-- INGEST vle.csv

CREATE TABLE IF NOT EXISTS oulad.raw.vle AS

SELECT *

FROM read_files(

    -- Replace with your volume file path
    '/Volumes/workspace/default/ftw-b12/shared/week07/vle.csv',
    format => 'csv',
    header => true,
    schema => 'id_site INT, code_module STRING, code_presentation STRING, activity_type STRING, week_from INT, week_to INT'
)
