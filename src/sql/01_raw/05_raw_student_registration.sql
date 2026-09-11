-- INGEST studentRegistration.csv

CREATE TABLE IF NOT EXISTS oulad.raw.student_registration AS

SELECT *

FROM read_files(

    -- Replace with your volume file path
    '/Volumes/workspace/default/ftw-b12/shared/week07/studentRegistration.csv',
    format => 'csv',
    header => true,
    schema => 'code_module STRING, code_presentation STRING, id_student INT, date_registration INT, date_unregistration INT'
)
