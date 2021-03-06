

----------------------------------------------------------------------
-- Max Concurrent Sessions
----------------------------------------------------------------------

-- Creating and Populating Sessions
SET NOCOUNT ON;
USE TSQL2012;

IF OBJECT_ID('dbo.Sessions', 'U') IS NOT NULL DROP TABLE dbo.Sessions;

CREATE TABLE dbo.Sessions
(
  keycol    INT         NOT NULL,
  app       VARCHAR(10) NOT NULL,
  usr       VARCHAR(10) NOT NULL,
  host      VARCHAR(10) NOT NULL,
  starttime DATETIME    NOT NULL,
  endtime   DATETIME    NOT NULL,
  CONSTRAINT PK_Sessions PRIMARY KEY(keycol),
  CHECK(endtime > starttime)
);
GO

CREATE UNIQUE INDEX idx_nc_app_st_et ON dbo.Sessions(app, starttime, keycol) INCLUDE(endtime);
CREATE UNIQUE INDEX idx_nc_app_et_st ON dbo.Sessions(app, endtime, keycol) INCLUDE(starttime);

-- small set of sample data
TRUNCATE TABLE dbo.Sessions;

INSERT INTO dbo.Sessions(keycol, app, usr, host, starttime, endtime) VALUES
  (2,  'app1', 'user1', 'host1', '20120212 08:30', '20120212 10:30'),
  (3,  'app1', 'user2', 'host1', '20120212 08:30', '20120212 08:45'),
  (5,  'app1', 'user3', 'host2', '20120212 09:00', '20120212 09:30'),
  (7,  'app1', 'user4', 'host2', '20120212 09:15', '20120212 10:30'),
  (11, 'app1', 'user5', 'host3', '20120212 09:15', '20120212 09:30'),
  (13, 'app1', 'user6', 'host3', '20120212 10:30', '20120212 14:30'),
  (17, 'app1', 'user7', 'host4', '20120212 10:45', '20120212 11:30'),
  (19, 'app1', 'user8', 'host4', '20120212 11:00', '20120212 12:30'),
  (23, 'app2', 'user8', 'host1', '20120212 08:30', '20120212 08:45'),
  (29, 'app2', 'user7', 'host1', '20120212 09:00', '20120212 09:30'),
  (31, 'app2', 'user6', 'host2', '20120212 11:45', '20120212 12:00'),
  (37, 'app2', 'user5', 'host2', '20120212 12:30', '20120212 14:00'),
  (41, 'app2', 'user4', 'host3', '20120212 12:45', '20120212 13:30'),
  (43, 'app2', 'user3', 'host3', '20120212 13:00', '20120212 14:00'),
  (47, 'app2', 'user2', 'host4', '20120212 14:00', '20120212 16:30'),
  (53, 'app2', 'user1', 'host4', '20120212 15:30', '20120212 17:00');
GO

/*
app        mx
---------- -----------
app1       3
app2       4
*/

-- large set of sample data
TRUNCATE TABLE dbo.Sessions;

DECLARE 
  @numrows AS INT = 100000, -- total number of rows 
  @numapps AS INT = 10;     -- number of applications

INSERT INTO dbo.Sessions WITH(TABLOCK)
    (keycol, app, usr, host, starttime, endtime)
  SELECT
    ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS keycol, 
    D.*,
    DATEADD(
      second,
      1 + ABS(CHECKSUM(NEWID())) % (20*60),
      starttime) AS endtime
  FROM
  (
    SELECT 
      'app' + CAST(1 + ABS(CHECKSUM(NEWID())) % @numapps AS VARCHAR(10)) AS app,
      'user1' AS usr,
      'host1' AS host,
      DATEADD(
        second,
        1 + ABS(CHECKSUM(NEWID())) % (30*24*60*60),
        '20120101') AS starttime
    FROM dbo.GetNums(1, @numrows) AS Nums
  ) AS D;
GO

-- Traditional set-based solution
WITH TimePoints AS 
(
  SELECT app, starttime AS ts FROM dbo.Sessions
),
Counts AS
(
  SELECT app, ts,
    (SELECT COUNT(*)
     FROM dbo.Sessions AS S
     WHERE P.app = S.app
       AND P.ts >= S.starttime
       AND P.ts < S.endtime) AS concurrent
  FROM TimePoints AS P
)      
SELECT app, MAX(concurrent) AS mx
FROM Counts
GROUP BY app;

-- query used by cursor solution
SELECT app, starttime AS ts, +1 AS type
FROM dbo.Sessions
  
UNION ALL
  
SELECT app, endtime, -1
FROM dbo.Sessions
  
ORDER BY app, ts, type;

/*
app        ts                      type
---------- ----------------------- -----------
app1       2012-02-12 08:30:00.000 1
app1       2012-02-12 08:30:00.000 1
app1       2012-02-12 08:45:00.000 -1
app1       2012-02-12 09:00:00.000 1
app1       2012-02-12 09:15:00.000 1
app1       2012-02-12 09:15:00.000 1
app1       2012-02-12 09:30:00.000 -1
app1       2012-02-12 09:30:00.000 -1
app1       2012-02-12 10:30:00.000 -1
app1       2012-02-12 10:30:00.000 -1
...
*/

-- cursor-based solution
DECLARE
  @app AS varchar(10), 
  @prevapp AS varchar (10),
  @ts AS datetime,
  @type AS int,
  @concurrent AS int, 
  @mx AS int;

DECLARE @AppsMx TABLE
(
  app varchar (10) NOT NULL PRIMARY KEY,
  mx int NOT NULL
);

DECLARE sessions_cur CURSOR FAST_FORWARD FOR
  SELECT app, starttime AS ts, +1 AS type
  FROM dbo.Sessions
  
  UNION ALL
  
  SELECT app, endtime, -1
  FROM dbo.Sessions
  
  ORDER BY app, ts, type;

OPEN sessions_cur;

FETCH NEXT FROM sessions_cur
  INTO @app, @ts, @type;

SET @prevapp = @app;
SET @concurrent = 0;
SET @mx = 0;

WHILE @@FETCH_STATUS = 0
BEGIN
  IF @app <> @prevapp
  BEGIN
    INSERT INTO @AppsMx VALUES(@prevapp, @mx);
    SET @concurrent = 0;
    SET @mx = 0;
    SET @prevapp = @app;
  END

  SET @concurrent = @concurrent + @type;
  IF @concurrent > @mx SET @mx = @concurrent;
  
  FETCH NEXT FROM sessions_cur
    INTO @app, @ts, @type;
END

IF @prevapp IS NOT NULL
  INSERT INTO @AppsMx VALUES(@prevapp, @mx);

CLOSE sessions_cur;

DEALLOCATE sessions_cur;

SELECT * FROM @AppsMx;
GO

-- solution using window aggregate function
WITH C1 AS
(
  SELECT app, starttime AS ts, +1 AS type
  FROM dbo.Sessions

  UNION ALL

  SELECT app, endtime, -1
  FROM dbo.Sessions
),
C2 AS
(
  SELECT *,
    SUM(type) OVER(PARTITION BY app ORDER BY ts, type
                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cnt
  FROM C1
)
SELECT app, MAX(cnt) AS mx
FROM C2
GROUP BY app;

-- solution using ROW_NUMBER
WITH C1 AS
(
  SELECT app, starttime AS ts, +1 AS type, keycol,
    ROW_NUMBER() OVER(PARTITION BY app ORDER BY starttime, keycol) AS start_ordinal
  FROM dbo.Sessions

  UNION ALL

  SELECT app, endtime, -1, keycol, NULL
  FROM dbo.Sessions
),
C2 AS
(
  SELECT *,
    ROW_NUMBER() OVER(PARTITION BY app ORDER BY ts, type, keycol) AS start_or_end_ordinal
  FROM C1
)
SELECT app, MAX(start_ordinal - (start_or_end_ordinal - start_ordinal)) AS mx
FROM C2
GROUP BY app;

