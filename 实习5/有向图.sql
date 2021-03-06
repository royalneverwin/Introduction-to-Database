
---------------------------------------------------------------------
-- Bill Of Materials (BOM)
---------------------------------------------------------------------

-- Listing 12-2: DDL & Sample Data for Parts, BOM
SET NOCOUNT ON;
USE tempdb;
GO
IF OBJECT_ID('dbo.BOM') IS NOT NULL
  DROP TABLE dbo.BOM;
GO
IF OBJECT_ID('dbo.Parts') IS NOT NULL
  DROP TABLE dbo.Parts;
GO
CREATE TABLE dbo.Parts
(
  partid   INT         NOT NULL PRIMARY KEY,
  partname VARCHAR(25) NOT NULL
);

INSERT INTO dbo.Parts(partid, partname) VALUES
  ( 1, 'Black Tea'      ),
  ( 2, 'White Tea'      ),
  ( 3, 'Latte'          ),
  ( 4, 'Espresso'       ),
  ( 5, 'Double Espresso'),
  ( 6, 'Cup Cover'      ),
  ( 7, 'Regular Cup'    ),
  ( 8, 'Stirrer'        ),
  ( 9, 'Espresso Cup'   ),
  (10, 'Tea Shot'       ),
  (11, 'Milk'           ),
  (12, 'Coffee Shot'    ),
  (13, 'Tea Leaves'     ),
  (14, 'Water'          ),
  (15, 'Sugar Bag'      ),
  (16, 'Ground Coffee'  ),
  (17, 'Coffee Beans'   );

CREATE TABLE dbo.BOM
(
  partid     INT           NOT NULL REFERENCES dbo.Parts,
  assemblyid INT           NULL     REFERENCES dbo.Parts,
  unit       VARCHAR(3)    NOT NULL,
  qty        DECIMAL(8, 2) NOT NULL,
  UNIQUE(partid, assemblyid),
  CHECK (partid <> assemblyid)
);

INSERT INTO dbo.BOM(partid, assemblyid, unit, qty) VALUES
  ( 1, NULL, 'EA',   1.00),
  ( 2, NULL, 'EA',   1.00),
  ( 3, NULL, 'EA',   1.00),
  ( 4, NULL, 'EA',   1.00),
  ( 5, NULL, 'EA',   1.00),
  ( 6,    1, 'EA',   1.00),
  ( 7,    1, 'EA',   1.00),
  (10,    1, 'EA',   1.00),
  (14,    1, 'mL', 230.00),
  ( 6,    2, 'EA',   1.00),
  ( 7,    2, 'EA',   1.00),
  (10,    2, 'EA',   1.00),
  (14,    2, 'mL', 205.00),
  (11,    2, 'mL',  25.00),
  ( 6,    3, 'EA',   1.00),
  ( 7,    3, 'EA',   1.00),
  (11,    3, 'mL', 225.00),
  (12,    3, 'EA',   1.00),
  ( 9,    4, 'EA',   1.00),
  (12,    4, 'EA',   1.00),
  ( 9,    5, 'EA',   1.00),
  (12,    5, 'EA',   2.00),
  (13,   10, 'g' ,   5.00),
  (14,   10, 'mL',  20.00),
  (14,   12, 'mL',  20.00),
  (16,   12, 'g' ,  15.00),
  (17,   16, 'g' ,  15.00);
GO

---------------------------------------------------------------------
-- Transitive Closure
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Directed Acyclic Graph (DAG)
---------------------------------------------------------------------

-- Transitive Closure of BOM (DAG)
WITH BOMTC
AS
(
  -- Return all first-level containment relationships
  SELECT assemblyid, partid
  FROM dbo.BOM
  WHERE assemblyid IS NOT NULL

  UNION ALL

  -- Return next-level containment relationships
  SELECT P.assemblyid, C.partid
  FROM BOMTC AS P
    JOIN dbo.BOM AS C
      ON C.assemblyid = P.partid
)
-- Return distinct pairs that have
-- transitive containment relationships
SELECT DISTINCT assemblyid, partid
FROM BOMTC;
GO

-- Listing 12-4: Creation Script for the BOMTC UDF
IF OBJECT_ID('dbo.BOMTC') IS NOT NULL
  DROP FUNCTION dbo.BOMTC;
GO

CREATE FUNCTION BOMTC() RETURNS @BOMTC TABLE
(
  assemblyid INT NOT NULL,
  partid     INT NOT NULL,
  PRIMARY KEY (assemblyid, partid)
)
AS
BEGIN
  INSERT INTO @BOMTC(assemblyid, partid)
    SELECT assemblyid, partid
    FROM dbo.BOM
    WHERE assemblyid IS NOT NULL

  WHILE @@rowcount > 0
    INSERT INTO @BOMTC
    SELECT P.assemblyid, C.partid
    FROM @BOMTC AS P
      JOIN dbo.BOM AS C
        ON C.assemblyid = P.partid
    WHERE NOT EXISTS
      (SELECT * FROM @BOMTC AS P2
       WHERE P2.assemblyid = P.assemblyid
       AND P2.partid = C.partid);

  RETURN;
END
GO

-- Use the BOMTC UDF
SELECT assemblyid, partid FROM BOMTC();
GO

-- All Paths in BOM
WITH BOMPaths
AS
(
  SELECT assemblyid, partid,
    1 AS distance, -- distance in first level is 1
    -- path in first level is .assemblyid.partid.
    '.' + CAST(assemblyid AS VARCHAR(MAX)) +
    '.' + CAST(partid     AS VARCHAR(MAX)) + '.' AS path
  FROM dbo.BOM
  WHERE assemblyid IS NOT NULL

  UNION ALL

  SELECT P.assemblyid, C.partid,
    -- distance in next level is parent's distance + 1
    P.distance + 1,
    -- path in next level is parent_path.child_partid.
    P.path + CAST(C.partid AS VARCHAR(MAX)) + '.'
  FROM BOMPaths AS P
    JOIN dbo.BOM AS C
      ON C.assemblyid = P.partid
)
-- Return all paths
SELECT * FROM BOMPaths;

-- Shortest Paths in BOM
WITH BOMPaths -- All paths
AS
(
  SELECT assemblyid, partid,
    1 AS distance,
    '.' + CAST(assemblyid AS VARCHAR(MAX)) +
    '.' + CAST(partid     AS VARCHAR(MAX)) + '.' AS path
  FROM dbo.BOM
  WHERE assemblyid IS NOT NULL

  UNION ALL

  SELECT P.assemblyid, C.partid,
    P.distance + 1,
    P.path + CAST(C.partid AS VARCHAR(MAX)) + '.'
  FROM BOMPaths AS P
    JOIN dbo.BOM AS C
      ON C.assemblyid = P.partid
),
BOMMinDist AS -- Minimum distance for each pair
(
  SELECT assemblyid, partid, MIN(distance) AS mindist
  FROM BOMPaths
  GROUP BY assemblyid, partid
)
-- Shortest path for each pair
SELECT BP.*
FROM BOMMinDist AS BMD
  JOIN BOMPaths AS BP
    ON BMD.assemblyid = BP.assemblyid
    AND BMD.partid = BP.partid
    AND BMD.mindist = BP.distance;
GO

