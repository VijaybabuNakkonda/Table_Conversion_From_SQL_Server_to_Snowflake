/*
Purpose: Purpose of this scirpts is to read information_schema from SQL Server and generate table creation scripts
based on snowflake datatype

Version Number     Date            ModifiedBy                  Description
--------------------------------------------------------------------------------------
v1.0               06-01-2019      Vijaybabu Nakkonda          Initial Version
v1.1               06-26-2019      Sonny Rivera                Use Quotes for Names

Exeuction Method: Connect to SQL Server database and execution. Copy result queries into Snowflake to create table objects

*/
select Table_name, Script from
(
 SELECT
        dbo.fn_GetAplhaNumericOnly(TABLE_SCHEMA)+'.'+dbo.fn_GetAplhaNumericOnly(TABLE_NAME) Table_Name
        ,'CREATE or REPLACE TABLE "' + dbo.fn_GetAplhaNumericOnly(TABLE_SCHEMA)+'"."'+dbo.fn_GetAplhaNumericOnly(TABLE_NAME) +'"'
		+ ' (' + LEFT(cols.list, LEN(cols.list) - 1 ) + ');' Script
	from
	INFORMATION_SCHEMA.TABLES ist
	inner join sys.tables t
	on t.object_id=object_id(ist.TABLE_SCHEMA+'.'+ist.table_name)
	cross apply(
        SELECT
			'"' + UPPER (dbo.fn_GetAplhaNumericOnly(column_name)) + '" '
            + case	when DATA_TYPE like ('%int%') then replace (DATA_TYPE,'tiny','small')
					when DATA_TYPE like ('%char%') then replace (DATA_TYPE,'n','')
					when DATA_TYPE in ('money','smallmoney') then 'decimal'
					when DATA_TYPE ='date' then DATA_TYPE
					when DATA_TYPE like '%datetime%' then 'timestamp_tz'
					when DATA_TYPE in ('datetimeoffset') then 'timestamp_tz'
					when DATA_TYPE in ('uniqueidentifier') then 'varchar (36)'
					when DATA_TYPE in ('bit') then 'boolean'
					when DATA_TYPE in ('decimal','numeric') then DATA_TYPE
					when DATA_TYPE in ('float','real') then 'float'
                    when DATA_TYPE in ('ntext') then 'string'
					when DATA_TYPE like '%binary%' then DATA_TYPE
					else 'variant' end
            + CASE
                WHEN data_type in ('decimal','numeric','money','smallmoney') THEN '(' + CAST(numeric_precision as VARCHAR) + ', ' + CAST(numeric_scale as VARCHAR) + ')'
                when data_Type like '%char%' then COALESCE('(' + CASE WHEN character_maximum_length = -1 THEN '16000' ELSE CAST(character_maximum_length as VARCHAR) END + ')', '')
				else ''
            END
            + ' '
            + case when exists ( select * from syscolumns
            where id = object_id(ist.TABLE_SCHEMA+'.'+ist.table_name) and name = isc.column_name and columnproperty(id,name,'IsIdentity') = 1 ) then
            'IDENTITY(' + cast(ident_seed(ist.TABLE_SCHEMA+'.'+ist.TABLE_NAME) as varchar) + ',' + cast(ident_incr(ist.TABLE_SCHEMA+'.'+ist.TABLE_NAME) as varchar) + ')'
            else ''
            end
			+ ' '
            + CASE WHEN isc.IS_NULLABLE = 'No' THEN 'NOT NULL' ELSE 'NULL' END
            + CASE WHEN isc.COLUMN_DEFAULT IS NOT NULL THEN ' DEFAULT ' +
					case
						when DATA_TYPE like '%datetime%' then replace(COLUMN_DEFAULT,'getdate()','current_timestamp()::timestamp_ntz')
						when DATA_TYPE = 'datetimeoffset' then replace(COLUMN_DEFAULT,'getdate()','current_timestamp()::timestamp_tz')
						when DATA_TYPE = 'uniqueidentifier' then replace(COLUMN_DEFAULT,'newid','uuid_string')
						when DATA_TYPE = 'bit' then replace(replace(COLUMN_DEFAULT,'0','false'),'1','true')
					else
						isc.COLUMN_DEFAULT
					end
				ELSE '' END
            + ','
        FROM
            INFORMATION_SCHEMA.COLUMNS isc
		where
		isc.TABLE_SCHEMA=ist.TABLE_SCHEMA
		and isc.TABLE_NAME=ist.TABLE_NAME
        and isc.COLUMN_NAME not like 'Meta%'
        and isc.COLUMN_NAME not in ('BOXFER')
        ORDER BY ordinal_position
        FOR XML PATH('')
    ) cols (list)
    WHERE
        t.type = 'U'

) Snowflake_DDL

where Snowflake_DDL.Table_Name like 'ROW.stg%'
order by Snowflake_DDL.Table_Name asc
