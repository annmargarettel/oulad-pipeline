DECLARE OR REPLACE VARIABLE profiling_sql STRING;

SET VAR profiling_sql = (
    SELECT concat_ws(
        '\nUNION ALL\n',

        collect_list(
            concat(
                'SELECT ',
                char(39), table_name, char(39), ' AS table_name, ',
                char(39), column_name, char(39), ' AS column_name, ',
                char(39), data_type, char(39), ' AS data_type, ',

                'COUNT(*) AS total_rows, ',

                'COUNT(*) - COUNT(`', column_name, '`) AS null_count, ',

                'ROUND(100.0 * ',
                '(COUNT(*) - COUNT(`', column_name, '`)) / COUNT(*), 2',
                ') AS null_percentage, ',

                'COUNT(DISTINCT `', column_name, '`) AS distinct_count, ',

                'ROUND(100.0 * COUNT(DISTINCT `', column_name, '`) ',
                '/ COUNT(*), 2) AS distinct_percentage, ',

                'CAST(MIN(`', column_name, '`) AS STRING) AS min_value, ',

                'CAST(MAX(`', column_name, '`) AS STRING) AS max_value, ',

                '(SELECT CAST(`', column_name, '` AS STRING) ',
                'FROM `oulad`.`raw`.`', table_name, '` ',
                'WHERE `', column_name, '` IS NOT NULL ',
                'GROUP BY `', column_name, '` ',
                'ORDER BY COUNT(*) DESC ',
                'LIMIT 1) AS most_common_value ',

                'FROM `oulad`.`raw`.`', table_name, '`'
            )
        )
    )
    FROM oulad.information_schema.columns
    WHERE table_schema = 'raw'
);

EXECUTE IMMEDIATE profiling_sql;