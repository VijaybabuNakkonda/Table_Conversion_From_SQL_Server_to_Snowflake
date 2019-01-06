# Table_Conversion_From_SQL_Server_to_Snowflake
Scripts to convert tables from SQL Server to Snowflake

Create a small function to remove special characters from table name in SQL Server.Square brackets are not allowed in snowflake.

--1. 
create FUNCTION [dbo].[fn_GetAplhaNumericOnly](@input VARCHAR(250))
RETURNS VARCHAR(250)
AS
BEGIN 
WHILE PATINDEX('%[^A-Za-z.''0-9]%',@input) > 0
SET @input = STUFF(@input,PATINDEX('%[^A-Za-z.''0-9]%',@input),1,'')
RETURN @input
END

Table_Creation_Script.sql: Script to read Information_Schema from SQL Server and generate create table scripts to execute on Snowflake

Apply_Primary_Key_and_Foreign_Key.sql: Script to read Information_Schema from SQL Server and generate primary and foreign key constraints to execute on Snowflake.





