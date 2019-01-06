/*
Purpose: Purpose of this scirpts is to read information_schema from SQL Server and generate primary key and foreign key relations

Version Number     Date            ModifiedBy                  Description
--------------------------------------------------------------------------------------
v1.0               06-01-2019      Vijaybabu Nakkonda          Initial Version


Exeuction Method: Connect to SQL Server database and execution. Copy result queries into Snowflake to apply primary key and foreign key relation

*/

 SELECT 'alter table '+ tc.TABLE_SCHEMA +'.'+ tc.TABLE_NAME +' ADD CONSTRAINT ' + tc.constraint_name
        + ' ' + tc.constraint_type + ' (' + LEFT(c.list, LEN(c.list)-1) + ')' PK_Constraint_Script
    FROM
        information_schema.table_constraints tc
        CROSS APPLY(
            SELECT '' + kcu.column_name + ', '
            FROM  information_schema.key_column_usage kcu
            WHERE kcu.constraint_name = tc.constraint_name
            ORDER BY kcu.ordinal_position
            FOR XML PATH('')
        ) c (list)
		where
		tc.CONSTRAINT_TYPE in ('PRIMARY KEY')
union all
SELECT distinct 'alter table '+ tc.TABLE_SCHEMA +'.'+ tc.TABLE_NAME +' ADD CONSTRAINT ' + tc.constraint_name
        + ' ' + tc.constraint_type + ' (' + LEFT(c.list, LEN(c.list)-1) + ')'
        + COALESCE(CHAR(10) + r.list, '; ') FK_Constraint_Script
    FROM
        information_schema.table_constraints tc
        CROSS APPLY(
            SELECT '' + kcu.column_name + ', '
            FROM  information_schema.key_column_usage kcu
            WHERE kcu.constraint_name = tc.constraint_name
            ORDER BY kcu.ordinal_position
            FOR XML PATH('')
        ) c (list)
        OUTER APPLY(
            -- // http://stackoverflow.com/questions/3907879/sql-server-howto-get-foreign-key-reference-from-information-schema
            SELECT '  REFERENCES ' + t1.Table_Name + '(' + LEFT(t.list, LEN(t.list)-1) + '); '
			from
			(SELECT '' + kcu2.column_name + ','
			FROM information_schema.referential_constraints as rc
                JOIN information_schema.key_column_usage as kcu1 
				ON (kcu1.constraint_catalog = rc.constraint_catalog AND kcu1.constraint_schema = rc.constraint_schema AND kcu1.constraint_name = rc.constraint_name)
                JOIN information_schema.key_column_usage as kcu2 
				ON (kcu2.constraint_catalog = rc.unique_constraint_catalog AND kcu2.constraint_schema = rc.unique_constraint_schema AND kcu2.constraint_name = rc.unique_constraint_name AND kcu2.ordinal_position = KCU1.ordinal_position)
            WHERE
                kcu1.constraint_catalog = tc.constraint_catalog AND kcu1.constraint_schema = tc.constraint_schema AND kcu1.constraint_name = tc.constraint_name
			FOR XML PATH('') ) t (list)
			cross join 
			(SELECT kcu1.constraint_schema + '.' + '' + kcu2.table_name Table_Name
			FROM information_schema.referential_constraints as rc
                JOIN information_schema.key_column_usage as kcu1 
				ON (kcu1.constraint_catalog = rc.constraint_catalog AND kcu1.constraint_schema = rc.constraint_schema AND kcu1.constraint_name = rc.constraint_name)
                JOIN information_schema.key_column_usage as kcu2 
				ON (kcu2.constraint_catalog = rc.unique_constraint_catalog AND kcu2.constraint_schema = rc.unique_constraint_schema AND kcu2.constraint_name = rc.unique_constraint_name AND kcu2.ordinal_position = KCU1.ordinal_position)
            WHERE
               kcu1.constraint_catalog = tc.constraint_catalog AND kcu1.constraint_schema = tc.constraint_schema AND kcu1.constraint_name = tc.constraint_name			
			) t1
        ) r (list)
		where
		tc.CONSTRAINT_TYPE in ('FOREIGN KEY')