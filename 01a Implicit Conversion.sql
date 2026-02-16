USE StackOverflow2013;
SET STATISTICS TIME, IO ON;
SET NOCOUNT ON;
EXEC dbo.DropIndexes;
DBCC FREEPROCCACHE;













/*Harmless implicit conversion*/
SELECT TOP (1000) 
    CAST(u.Id AS varchar(10))
FROM dbo.Users AS u
ORDER BY u.Id DESC;

/*Um...*/
SELECT TOP (1000) 
    u.Id
FROM dbo.Users AS u
ORDER BY CAST(u.Id AS varchar(10)) DESC;





































/*Creating a new table with bad choices*/
SELECT 
    u.Id,
    u.AboutMe,
    u.Age,
    u.CreationDate,
    DisplayName = 
        ISNULL
        (
            CONVERT
            (
                varchar(40), 
                u.DisplayName
            ), 
            ''
        ),
    u.DownVotes,
    u.EmailHash,
    u.LastAccessDate,
    u.Location,
    u.Reputation,
    u.UpVotes,
    u.Views,
    u.WebsiteUrl,
    u.AccountId
INTO dbo.UsersBad
FROM dbo.Users AS u
ORDER BY u.Id;

ALTER TABLE 
    dbo.UsersBad 
ADD CONSTRAINT 
    PK_UsersBad_Id 
PRIMARY KEY CLUSTERED 
    (Id);
GO 

/*
I want to show you three things

1. Fixing the parameter datatype will get us a missing index request

2. Even if we add the index, SQL Server can’t use it as efficiently with the wrong datatype

3. What CPU usage looks like under load before and after fixing the parameter datatype, and adding the index
*/


















/*How to miss an index*/

/*Toggle datatype to show differences*/
CREATE OR ALTER PROCEDURE 
    dbo.BadUsersQuery 
(
    @DisplayName nvarchar(40)
)
AS
BEGIN

    SELECT DISTINCT 
        u.DisplayName, 
        u.Reputation, 
        u.CreationDate
    FROM dbo.UsersBad AS u
    WHERE u.DisplayName = @DisplayName;

END;

EXEC dbo.BadUsersQuery 
    @DisplayName = N'Eggs McLaren';

















/*How do we do with an index?*/
CREATE INDEX 
    whatever 
ON dbo.UsersBad 
    (DisplayName);
GO

/*Toggle datatype to show differences*/
CREATE OR ALTER PROCEDURE 
    dbo.BadUsersQuery 
(
    @DisplayName varchar(40)
)
AS
BEGIN

    SELECT DISTINCT 
        u.DisplayName, 
        u.Reputation, 
        u.CreationDate
    FROM dbo.UsersBad AS u
    WHERE u.DisplayName = @DisplayName;

END;

EXEC dbo.BadUsersQuery 
    @DisplayName = N'Eggs McLaren';


























/*How do we do under load?*/
GO


/*Toggle datatype to show differences*/
CREATE OR ALTER PROCEDURE 
    dbo.BadUsersQuery 
(
    @DisplayName varchar(40)
)
AS
BEGIN

    SELECT DISTINCT 
        u.DisplayName, 
        u.Reputation, 
        u.CreationDate
    FROM dbo.UsersBad AS u
    WHERE u.DisplayName = @DisplayName;

END;
GO

EXEC dbo.BadUsersQuery 
    @DisplayName = N'Eggs McLaren';

--ostress -SSQL2017 -d"StackOverflow2013" -Q"EXEC dbo.BadUsersQuery @DisplayName = N'Eggs McLaren';" -U"ostress" -P"ostress" -q20 -r50 -o"C:\temp\crap"
