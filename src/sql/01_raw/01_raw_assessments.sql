-- INGEST assessments.csv

CREATE OR REPLACE TABLE oulad.raw.assessments AS

SELECT *

FROM read_files(

    -- Replace with your volume file path
    '/Volumes/chinook/default/ftw-b12-de/shared/week07/assessments.csv',
    format => 'csv',
    header => true,
    schema => 'code_module STRING, code_presentation STRING, id_assessment INT, assessment_type STRING, date INT, weight INT'
);