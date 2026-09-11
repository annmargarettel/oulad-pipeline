-- INGEST courses.csv

CREATE OR REPLACE TABLE oulad.raw.courses AS

SELECT *

FROM read_files(
    
    -- Replace with your volume file path
    '/Volumes/workspace/default/ftw-b12/shared/week07/courses.csv',
    format => 'csv',
    header => true,
    schema => 'code_module STRING, code_presentation STRING, module_presentation_length INT'
);
