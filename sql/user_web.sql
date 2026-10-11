CREATE LOGIN webuser WITH PASSWORD = 'WebPass123!';
GO
USE LabsSQLI;
GO
CREATE USER webuser FOR LOGIN webuser;
ALTER ROLE db_owner ADD MEMBER webuser;