
CREATE TABLE dbo.Cities
(
  cityid  CHAR(3)     NOT NULL PRIMARY KEY,
  city    VARCHAR(30) NOT NULL,
  region  VARCHAR(30) NULL,
  country VARCHAR(30) NOT NULL
);

INSERT INTO dbo.Cities(cityid, city, region, country) VALUES
  ('ATL', 'Atlanta', 'GA', 'USA'),
  ('ORD', 'Chicago', 'IL', 'USA'),
  ('DEN', 'Denver', 'CO', 'USA'),
  ('IAH', 'Houston', 'TX', 'USA'),
  ('MCI', 'Kansas City', 'KS', 'USA'),
  ('LAX', 'Los Angeles', 'CA', 'USA'),
  ('MIA', 'Miami', 'FL', 'USA'),
  ('MSP', 'Minneapolis', 'MN', 'USA'),
  ('JFK', 'New York', 'NY', 'USA'),
  ('SEA', 'Seattle', 'WA', 'USA'),
  ('SFO', 'San Francisco', 'CA', 'USA'),
  ('ANC', 'Anchorage', 'AK', 'USA'),
  ('FAI', 'Fairbanks', 'AK', 'USA');

CREATE TABLE dbo.Roads
(
  city1       CHAR(3) NOT NULL REFERENCES dbo.Cities,
  city2       CHAR(3) NOT NULL REFERENCES dbo.Cities,
  distance INT     NOT NULL,
  PRIMARY KEY(city1, city2),
  CHECK(city1 < city2),
  CHECK(distance > 0)
);

INSERT INTO dbo.Roads(city1, city2, distance) VALUES
  ('ANC', 'FAI',  359),
  ('ATL', 'ORD',  715),
  ('ATL', 'IAH',  800),
  ('ATL', 'MCI',  805),
  ('ATL', 'MIA',  665),
  ('ATL', 'JFK',  865),
  ('DEN', 'IAH', 1120),
  ('DEN', 'MCI',  600),
  ('DEN', 'LAX', 1025),
  ('DEN', 'MSP',  915),
  ('DEN', 'SEA', 1335),
  ('DEN', 'SFO', 1270),
  ('IAH', 'MCI',  795),
  ('IAH', 'LAX', 1550),
  ('IAH', 'MIA', 1190),
  ('JFK', 'ORD',  795),
  ('LAX', 'SFO',  385),
  ('MCI', 'ORD',  525),
  ('MCI', 'MSP',  440),
  ('MSP', 'ORD',  410),
  ('MSP', 'SEA', 2015),
  ('SEA', 'SFO',  815);
GO

---------------------------------------------------------------------
-- Undirected Cyclic Graph
---------------------------------------------------------------------

-- Transitive Closure of Roads (Undirected Cyclic Graph)
WITH Roads2 -- Two rows for each pair (f-->t, t-->f)
AS
(
  SELECT city1 AS from_city, city2 AS to_city FROM dbo.Roads
  UNION ALL
  SELECT city2, city1 FROM dbo.Roads
),
RoadPaths AS
(
  -- Return all first-level reachability pairs
  SELECT from_city, to_city,
    -- path is needed to identify cycles
    CAST('.' + from_city + '.' + to_city + '.' AS VARCHAR(MAX)) AS path
  FROM Roads2

  UNION ALL

  -- Return next-level reachability pairs
  SELECT F.from_city, T.to_city,
    CAST(F.path + T.to_city + '.' AS VARCHAR(MAX))
  FROM RoadPaths AS F
    JOIN Roads2 AS T
      -- if to_city appears in from_city's path, cycle detected
      ON CASE WHEN F.path LIKE '%.' + T.to_city + '.%'
              THEN 1 ELSE 0 END = 0
      AND F.to_city = T.from_city
)
-- Return Transitive Closure of Roads
SELECT DISTINCT from_city, to_city
FROM RoadPaths;
GO

-- Creation Script for the RoadsTC UDF
IF OBJECT_ID('dbo.RoadsTC') IS NOT NULL
  DROP FUNCTION dbo.RoadsTC;
GO

CREATE FUNCTION dbo.RoadsTC() RETURNS @RoadsTC TABLE (
  from_city VARCHAR(3) NOT NULL,
  to_city   VARCHAR(3) NOT NULL,
  PRIMARY KEY (from_city, to_city)
)
AS
BEGIN
  DECLARE @added as INT;

  INSERT INTO @RoadsTC(from_city, to_city)
    SELECT city1, city2 FROM dbo.Roads;

  SET @added = @@rowcount;

  INSERT INTO @RoadsTC
    SELECT city2, city1 FROM dbo.Roads

  SET @added = @added + @@rowcount;

  WHILE @added > 0 BEGIN

    INSERT INTO @RoadsTC
      SELECT DISTINCT TC.from_city, R.city2
      FROM @RoadsTC AS TC
        JOIN dbo.Roads AS R
          ON R.city1 = TC.to_city
      WHERE NOT EXISTS
        (SELECT * FROM @RoadsTC AS TC2
         WHERE TC2.from_city = TC.from_city
           AND TC2.to_city = R.city2)
        AND TC.from_city <> R.city2;

    SET @added = @@rowcount;

    INSERT INTO @RoadsTC
      SELECT DISTINCT TC.from_city, R.city1
      FROM @RoadsTC AS TC
        JOIN dbo.Roads AS R
          ON R.city2 = TC.to_city
      WHERE NOT EXISTS
        (SELECT * FROM @RoadsTC AS TC2
         WHERE TC2.from_city = TC.from_city
           AND TC2.to_city = R.city1)
        AND TC.from_city <> R.city1;

    SET @added = @added + @@rowcount;
  END
  RETURN;
END
GO

-- Use the RoadsTC UDF
SELECT * FROM dbo.RoadsTC();
GO

-- All paths and distances in Roads (15262 rows)
WITH Roads2
AS
(
  SELECT city1 AS from_city, city2 AS to_city, distance FROM dbo.Roads
  UNION ALL
  SELECT city2, city1, distance FROM dbo.Roads
),
RoadPaths AS
(
  SELECT from_city, to_city, distance,
    CAST('.' + from_city + '.' + to_city + '.' AS VARCHAR(MAX)) AS path
  FROM Roads2

  UNION ALL

  SELECT F.from_city, T.to_city, F.distance + T.distance,
    CAST(F.path + T.to_city + '.' AS VARCHAR(MAX))
  FROM RoadPaths AS F
    JOIN Roads2 AS T
      ON CASE WHEN F.path LIKE '%.' + T.to_city + '.%'
              THEN 1 ELSE 0 END = 0
      AND F.to_city = T.from_city
)
-- Return all paths and distances
SELECT * FROM RoadPaths;

-- Shortest paths in Roads
WITH Roads2
AS
(
  SELECT city1 AS from_city, city2 AS to_city, distance FROM dbo.Roads
  UNION ALL
  SELECT city2, city1, distance FROM dbo.Roads
),
RoadPaths AS
(
  SELECT from_city, to_city, distance,
    CAST('.' + from_city + '.' + to_city + '.' AS VARCHAR(MAX)) AS path
  FROM Roads2

  UNION ALL

  SELECT F.from_city, T.to_city, F.distance + T.distance,
    CAST(F.path + T.to_city + '.' AS VARCHAR(MAX))
  FROM RoadPaths AS F
    JOIN Roads2 AS T
      ON CASE WHEN F.path LIKE '%.' + T.to_city + '.%'
              THEN 1 ELSE 0 END = 0
      AND F.to_city = T.from_city
),
RoadsMinDist -- Min distance for each pair in TC
AS
(
  SELECT from_city, to_city, MIN(distance) AS mindist
  FROM RoadPaths
  GROUP BY from_city, to_city
)
-- Return shortest paths and distances
SELECT RP.*
FROM RoadsMinDist AS RMD
  JOIN RoadPaths AS RP
    ON RMD.from_city = RP.from_city
    AND RMD.to_city = RP.to_city
    AND RMD.mindist = RP.distance;
GO

-- Load Shortest Road Paths Into a Table
WITH Roads2
AS
(
  SELECT city1 AS from_city, city2 AS to_city, distance FROM dbo.Roads
  UNION ALL
  SELECT city2, city1, distance FROM dbo.Roads
),
RoadPaths AS
(
  SELECT from_city, to_city, distance,
    CAST('.' + from_city + '.' + to_city + '.' AS VARCHAR(MAX)) AS path
  FROM Roads2

  UNION ALL

  SELECT F.from_city, T.to_city, F.distance + T.distance,
    CAST(F.path + T.to_city + '.' AS VARCHAR(MAX))
  FROM RoadPaths AS F
    JOIN Roads2 AS T
      ON CASE WHEN F.path LIKE '%.' + T.to_city + '.%'
              THEN 1 ELSE 0 END = 0
      AND F.to_city = T.from_city
),
RoadsMinDist
AS
(
  SELECT from_city, to_city, MIN(distance) AS mindist
  FROM RoadPaths
  GROUP BY from_city, to_city
)
SELECT RP.*
INTO dbo.RoadPaths
FROM RoadsMinDist AS RMD
  JOIN RoadPaths AS RP
    ON RMD.from_city = RP.from_city
    AND RMD.to_city = RP.to_city
    AND RMD.mindist = RP.distance;

CREATE UNIQUE CLUSTERED INDEX idx_uc_from_city_to_city
  ON dbo.RoadPaths(from_city, to_city);
GO

-- Return shortest path between Los Angeles and New York
SELECT * FROM dbo.RoadPaths 
WHERE from_city = 'LAX' AND to_city = 'JFK';
GO

-- Creation Script for the RoadsTC UDF
IF OBJECT_ID('dbo.RoadsTC') IS NOT NULL
  DROP FUNCTION dbo.RoadsTC;
GO
CREATE FUNCTION dbo.RoadsTC() RETURNS @RoadsTC TABLE
(
  uniquifier INT          NOT NULL IDENTITY,
  from_city  VARCHAR(3)   NOT NULL,
  to_city    VARCHAR(3)   NOT NULL,
  distance   INT          NOT NULL,
  route      VARCHAR(MAX) NOT NULL,
  PRIMARY KEY (from_city, to_city, uniquifier)
)
AS
BEGIN
  DECLARE @added AS INT;

  INSERT INTO @RoadsTC
    SELECT city1 AS from_city, city2 AS to_city, distance,
      '.' + city1 + '.' + city2 + '.'
    FROM dbo.Roads;

  SET @added = @@rowcount;

  INSERT INTO @RoadsTC
    SELECT city2, city1, distance, '.' + city2 + '.' + city1 + '.'
    FROM dbo.Roads;

  SET @added = @added + @@rowcount;

  WHILE @added > 0 BEGIN
    INSERT INTO @RoadsTC
      SELECT DISTINCT TC.from_city, R.city2,
        TC.distance + R.distance, TC.route + city2 + '.'
      FROM @RoadsTC AS TC
        JOIN dbo.Roads AS R
          ON R.city1 = TC.to_city
      WHERE NOT EXISTS
        (SELECT * FROM @RoadsTC AS TC2
         WHERE TC2.from_city = TC.from_city
           AND TC2.to_city = R.city2
           AND TC2.distance <= TC.distance + R.distance)
        AND TC.from_city <> R.city2;

    SET @added = @@rowcount;

    INSERT INTO @RoadsTC
      SELECT DISTINCT TC.from_city, R.city1,
        TC.distance + R.distance, TC.route + city1 + '.'
      FROM @RoadsTC AS TC
        JOIN dbo.Roads AS R
          ON R.city2 = TC.to_city
      WHERE NOT EXISTS
        (SELECT * FROM @RoadsTC AS TC2
         WHERE TC2.from_city = TC.from_city
           AND TC2.to_city = R.city1
           AND TC2.distance <= TC.distance + R.distance)
        AND TC.from_city <> R.city1;

    SET @added = @added + @@rowcount;
  END
  RETURN;
END
GO

-- Return shortest paths and distances
SELECT from_city, to_city, distance, route
FROM (SELECT from_city, to_city, distance, route,
        RANK() OVER (PARTITION BY from_city, to_city
                     ORDER BY distance) AS rk
      FROM dbo.RoadsTC()) AS RTC
WHERE rk = 1;
GO

-- Cleanup
DROP TABLE dbo.RoadPaths;
GO