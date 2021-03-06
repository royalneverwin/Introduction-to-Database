
CREATE TABLE Employees
(
  empid   INT         NOT NULL PRIMARY KEY,
  mgrid   INT         NULL     REFERENCES dbo.Employees,
  empname VARCHAR(25) NOT NULL,
  salary  DECIMAL(10,2)      NOT NULL,
  CHECK (empid <> mgrid)
);

INSERT INTO Employees(empid, mgrid, empname, salary) VALUES
  (1,  NULL, 'David'  , 10000.00),
  (2,  1,    'Eitan'  ,  7000.00),
  (3,  1,    'Ina'    ,  7500.00),
  (4,  2,    'Seraph' ,  5000.00),
  (5,  2,    'Jiru'   ,  5500.00),
  (6,  2,    'Steve'  ,  4500.00),
  (7,  3,    'Aaron'  ,  5000.00),
  (8,  5,    'Lilach' ,  3500.00),
  (9,  7,    'Rita'   ,  3000.00),
  (10, 5,    'Sean'   , 3000.00),
  (11, 7,    'Gabriel',  3000.00),
  (12, 9,    'Emilia' ,  2000.00),
  (13, 9,    'Michael',  2000.00),
  (14, 9,    'Didi'   ,  1500.00);

-- Subtree of a Given Root, CTE Solution
DECLARE @root AS INT = 3;

WITH Subs
AS
(
  -- Anchor member returns root node
  SELECT empid, empname, 0 AS lvl 
  FROM dbo.Employees
  WHERE empid = @root

  UNION ALL

  -- Recursive member returns next level of children
  SELECT C.empid, C.empname, P.lvl + 1
  FROM Subs AS P
    JOIN dbo.Employees AS C
      ON C.mgrid = P.empid
)
SELECT * FROM Subs;


-- Subtree with level limit, CTE Solution, with MAXRECURSION

DECLARE @root AS INT = 3;

WITH Subs
AS
(
  SELECT empid, empname, 0 AS lvl 
  FROM dbo.Employees
  WHERE empid = @root

  UNION ALL

  SELECT C.empid, C.empname, P.lvl + 1
  FROM Subs AS P
    JOIN dbo.Employees AS C
      ON C.mgrid = P.empid
)
SELECT * FROM Subs
OPTION (MAXRECURSION 2);
GO

-- Subtree with level limit, CTE Solution, with level column
DECLARE @root AS INT = 3, @maxlevels AS INT = 2;

WITH Subs
AS
(
  SELECT empid, empname, 0 AS lvl 
  FROM dbo.Employees
  WHERE empid = @root

  UNION ALL

  SELECT C.empid, C.empname, P.lvl + 1
  FROM Subs AS P
    JOIN dbo.Employees AS C
      ON C.mgrid = P.empid
)
SELECT * FROM Subs
WHERE lvl <= @maxlevels;

---------------------------------------------------------------------
-- Sub-Path
---------------------------------------------------------------------

-- Ancestors of a Given Node, CTE Solution

-- Ancestors of a given node, CTE Solution
DECLARE @empid AS INT = 8;

WITH Mgrs
AS
(
  SELECT empid, mgrid, empname, 0 AS lvl 
  FROM dbo.Employees
  WHERE empid = @empid

  UNION ALL

  SELECT P.empid, P.mgrid, P.empname, C.lvl + 1
  FROM Mgrs AS C
    JOIN dbo.Employees AS P
      ON C.mgrid = P.empid
)
SELECT * FROM Mgrs;

-- Ancestors of a given node, limit 2 levels
SELECT empid, lvl
FROM dbo.Managers(8, 2) AS M;
GO

-- Ancestors with Level Limit, CTE Solution
DECLARE @empid AS INT = 8, @maxlevels AS INT = 2;

WITH Mgrs
AS
(
  SELECT empid, mgrid, empname, 0 AS lvl 
  FROM dbo.Employees
  WHERE empid = @empid

  UNION ALL

  SELECT P.empid, P.mgrid, P.empname, C.lvl + 1
  FROM Mgrs AS C
    JOIN dbo.Employees AS P
      ON C.mgrid = P.empid
)
SELECT * FROM Mgrs
WHERE lvl <= @maxlevels;

-- Ancestor that is 2 levels above a given node
SELECT empid
FROM dbo.Managers(8, 2) AS M
WHERE lvl = 2;
GO

-- Subtree with Path Enumeration, CTE Solution

-- Descendants of a given node, with Materialized Path, CTE Solution
DECLARE @root AS INT = 1;

WITH Subs
AS
(
  SELECT empid, empname, 0 AS lvl,
    -- Path of root = '.' + empid + '.'
    CAST('.' + CAST(empid AS VARCHAR(10)) + '.'
         AS VARCHAR(MAX)) AS path
  FROM dbo.Employees
  WHERE empid = @root

  UNION ALL

  SELECT C.empid, C.empname, P.lvl + 1,
    -- Path of child = parent's path + child empid + '.'
    CAST(P.path + CAST(C.empid AS VARCHAR(10)) + '.'
         AS VARCHAR(MAX))
  FROM Subs AS P
    JOIN dbo.Employees AS C
      ON C.mgrid = P.empid
)
SELECT empid, REPLICATE(' | ', lvl) + empname AS empname
FROM Subs
ORDER BY path;

---------------------------------------------------------------------
-- Sorting
---------------------------------------------------------------------

-- Sorting Hierarchy by empname, CTE Solution
DECLARE @root AS INT = 1;

WITH Subs
AS
(
  SELECT empid, empname, 0 AS lvl,
    -- Path of root is 1 (binary)
    CAST(1 AS VARBINARY(MAX)) AS sort_path
  FROM dbo.Employees
  WHERE empid = @root

  UNION ALL

  SELECT C.empid, C.empname, P.lvl + 1,
    -- Path of child = parent's path + child row number (binary)
    P.sort_path + CAST(
      ROW_NUMBER() OVER(PARTITION BY C.mgrid
                        ORDER BY C.empname) -- sort col(s)
      AS BINARY(4))
  FROM Subs AS P
    JOIN dbo.Employees AS C
      ON C.mgrid = P.empid
)
SELECT empid, ROW_NUMBER() OVER(ORDER BY sort_path) AS sortval,
  REPLICATE(' | ', lvl) + empname AS empname
FROM Subs
ORDER BY sortval;
GO

-- Sorting Hierarchy by salary, CTE Solution
DECLARE @root AS INT = 1;

WITH Subs
AS
(
  SELECT empid, empname, salary, 0 AS lvl,
    -- Path of root = 1 (binary)
    CAST(1 AS VARBINARY(MAX)) AS sort_path
  FROM dbo.Employees
  WHERE empid = @root

  UNION ALL

  SELECT C.empid, C.empname, C.salary, P.lvl + 1,
    -- Path of child = parent's path + child row number (binary)
    P.sort_path + CAST(
      ROW_NUMBER() OVER(PARTITION BY C.mgrid
                        ORDER BY C.salary) -- sort col(s)
      AS BINARY(4))
  FROM Subs AS P
    JOIN dbo.Employees AS C
      ON C.mgrid = P.empid
)
SELECT empid, salary, ROW_NUMBER() OVER(ORDER BY sort_path) AS sortval,
  REPLICATE(' | ', lvl) + empname AS empname
FROM Subs
ORDER BY sortval;

---------------------------------------------------------------------
-- Cycles
---------------------------------------------------------------------

-- Create a cyclic path
UPDATE dbo.Employees SET mgrid = 14 WHERE empid = 1;
GO

-- Detecting Cycles, CTE Solution
DECLARE @root AS INT = 1;

WITH Subs
AS
(
  SELECT empid, empname, 0 AS lvl,
    CAST('.' + CAST(empid AS VARCHAR(10)) + '.'
         AS VARCHAR(MAX)) AS path,
    -- Obviously root has no cycle
    0 AS cycle
  FROM dbo.Employees
  WHERE empid = @root

  UNION ALL

  SELECT C.empid, C.empname, P.lvl + 1,
    CAST(P.path + CAST(C.empid AS VARCHAR(10)) + '.'
         AS VARCHAR(MAX)),
    -- Cycle detected if parent's path contains child's id
    CASE WHEN P.path LIKE '%.' + CAST(C.empid AS VARCHAR(10)) + '.%'
      THEN 1 ELSE 0 END
  FROM Subs AS P
    JOIN dbo.Employees AS C
      ON C.mgrid = P.empid
)
SELECT empid, empname, cycle, path
FROM Subs;
GO

-- Not Pursuing Cycles, CTE Solution
DECLARE @root AS INT = 1;

WITH Subs
AS
(
  SELECT empid, empname, 0 AS lvl,
    CAST('.' + CAST(empid AS VARCHAR(10)) + '.'
         AS VARCHAR(MAX)) AS path,
    -- Obviously root has no cycle
    0 AS cycle
  FROM dbo.Employees
  WHERE empid = @root

  UNION ALL

  SELECT C.empid, C.empname, P.lvl + 1,
    CAST(P.path + CAST(C.empid AS VARCHAR(10)) + '.'
         AS VARCHAR(MAX)),
    -- Cycle detected if parent's path contains child's id
    CASE WHEN P.path LIKE '%.' + CAST(C.empid AS VARCHAR(10)) + '.%'
      THEN 1 ELSE 0 END
  FROM Subs AS P
    JOIN dbo.Employees AS C
      ON C.mgrid = P.empid
      AND P.cycle = 0 -- do not pursue branch for parent with cycle
)
SELECT empid, empname, cycle, path
FROM Subs;
GO

-- Isolating Cyclic Paths, CTE Solution
DECLARE @root AS INT = 1;

WITH Subs
AS
(
  SELECT empid, empname, 0 AS lvl,
    CAST('.' + CAST(empid AS VARCHAR(10)) + '.'
         AS VARCHAR(MAX)) AS path,
    -- Obviously root has no cycle
    0 AS cycle
  FROM dbo.Employees
  WHERE empid = @root

  UNION ALL

  SELECT C.empid, C.empname, P.lvl + 1,
    CAST(P.path + CAST(C.empid AS VARCHAR(10)) + '.'
         AS VARCHAR(MAX)),
    -- Cycle detected if parent's path contains child's id
    CASE WHEN P.path LIKE '%.' + CAST(C.empid AS VARCHAR(10)) + '.%'
      THEN 1 ELSE 0 END
  FROM Subs AS P
    JOIN dbo.Employees AS C
      ON C.mgrid = P.empid
      AND P.cycle = 0
)
SELECT path FROM Subs WHERE cycle = 1;

-- Fix cyclic path
UPDATE dbo.Employees SET mgrid = NULL WHERE empid = 1;

---------------------------------------------------------------------
-- Materialized Path
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Custom Materialized Path
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Maintaining Data
---------------------------------------------------------------------

-- DDL for Employees with Path
SET NOCOUNT ON;
USE tempdb;
GO
IF OBJECT_ID('dbo.Employees') IS NOT NULL
  DROP TABLE dbo.Employees;
GO
CREATE TABLE dbo.Employees
(
  empid   INT          NOT NULL PRIMARY KEY NONCLUSTERED,
  mgrid   INT          NULL     REFERENCES dbo.Employees,
  empname VARCHAR(25)  NOT NULL,
  salary  MONEY        NOT NULL,
  lvl     INT          NOT NULL,
  path    VARCHAR(900) NOT NULL UNIQUE CLUSTERED
);
CREATE UNIQUE INDEX idx_unc_mgrid_empid ON dbo.Employees(mgrid, empid);
GO

---------------------------------------------------------------------
-- Adding Employees who Manage No One (Leaves)
---------------------------------------------------------------------

-- Creation Script for Procedure AddEmp

---------------------------------------------------------------------
-- Stored Procedure: AddEmp,
--   Inserts new employee who manages no one into the table
---------------------------------------------------------------------
USE tempdb;
GO
IF OBJECT_ID('dbo.AddEmp') IS NOT NULL
  DROP PROC dbo.AddEmp;
GO
CREATE PROC dbo.AddEmp
  @empid   INT,
  @mgrid   INT,
  @empname VARCHAR(25),
  @salary  MONEY
AS

SET NOCOUNT ON;

-- Handle case where the new employee has no manager (root)
IF @mgrid IS NULL
  INSERT INTO dbo.Employees(empid, mgrid, empname, salary, lvl, path)
    VALUES(@empid, @mgrid, @empname, @salary,
      0, '.' + CAST(@empid AS VARCHAR(10)) + '.');
-- Handle subordinate case (non-root)
ELSE
  INSERT INTO dbo.Employees(empid, mgrid, empname, salary, lvl, path)
    SELECT @empid, @mgrid, @empname, @salary, 
      lvl + 1, path + CAST(@empid AS VARCHAR(10)) + '.'
    FROM dbo.Employees
    WHERE empid = @mgrid;
GO

-- Sample Data for Employees with Path
EXEC dbo.AddEmp
  @empid = 1, @mgrid = NULL, @empname = 'David', @salary = $10000.00;
EXEC dbo.AddEmp
  @empid = 2, @mgrid = 1, @empname = 'Eitan', @salary = $7000.00;
EXEC dbo.AddEmp
  @empid = 3, @mgrid = 1, @empname = 'Ina', @salary = $7500.00;
EXEC dbo.AddEmp
  @empid = 4, @mgrid = 2, @empname = 'Seraph', @salary = $5000.00;
EXEC dbo.AddEmp
  @empid = 5, @mgrid = 2, @empname = 'Jiru', @salary = $5500.00;
EXEC dbo.AddEmp
  @empid = 6, @mgrid = 2, @empname = 'Steve', @salary = $4500.00;
EXEC dbo.AddEmp
  @empid = 7, @mgrid = 3, @empname = 'Aaron', @salary = $5000.00;
EXEC dbo.AddEmp
  @empid = 8, @mgrid = 5, @empname = 'Lilach', @salary = $3500.00;
EXEC dbo.AddEmp
  @empid = 9, @mgrid = 7, @empname = 'Rita', @salary = $3000.00;
EXEC dbo.AddEmp
  @empid = 10, @mgrid = 5, @empname = 'Sean', @salary = $3000.00;
EXEC dbo.AddEmp
  @empid = 11, @mgrid = 7, @empname = 'Gabriel', @salary = $3000.00;
EXEC dbo.AddEmp
  @empid = 12, @mgrid = 9, @empname = 'Emilia', @salary = $2000.00;
EXEC dbo.AddEmp
  @empid = 13, @mgrid = 9, @empname = 'Michael', @salary = $2000.00;
EXEC dbo.AddEmp
  @empid = 14, @mgrid = 9, @empname = 'Didi', @salary = $1500.00;
GO

-- Examine data after load
SELECT empid, mgrid, empname, salary, lvl, path
FROM dbo.Employees
ORDER BY path;

---------------------------------------------------------------------
-- Moving a Subtree
---------------------------------------------------------------------

-- Creation Script for Procedure MoveSubtree

---------------------------------------------------------------------
-- Stored Procedure: MoveSubtree,
--   Moves a whole subtree of a given root to a new location
--   under a given manager
---------------------------------------------------------------------
USE tempdb;
GO
IF OBJECT_ID('dbo.MoveSubtree') IS NOT NULL
  DROP PROC dbo.MoveSubtree;
GO
CREATE PROC dbo.MoveSubtree
  @root  INT,
  @mgrid INT
AS

SET NOCOUNT ON;

BEGIN TRAN;
  -- Update level and path of all employees in the subtree (E)
  -- Set level = 
  --   current level + new manager's level - old manager's level
  -- Set path = 
  --   in current path remove old manager's path 
  --   and substitute with new manager's path
  UPDATE E
    SET lvl  = E.lvl + NM.lvl - OM.lvl,
        path = STUFF(E.path, 1, LEN(OM.path), NM.path)
  FROM dbo.Employees AS E          -- E = Employees    (subtree)
    JOIN dbo.Employees AS R        -- R = Root         (one row)
      ON R.empid = @root
      AND E.path LIKE R.path + '%'
    JOIN dbo.Employees AS OM       -- OM = Old Manager (one row)
      ON OM.empid = R.mgrid
    JOIN dbo.Employees AS NM       -- NM = New Manager (one row)
      ON NM.empid = @mgrid;
  
  -- Update root's new manager
  UPDATE dbo.Employees SET mgrid = @mgrid WHERE empid = @root;
COMMIT TRAN;
GO

-- Before moving subtree
SELECT empid, REPLICATE(' | ', lvl) + empname AS empname, lvl, path
FROM dbo.Employees
ORDER BY path;

-- Move Subtree
BEGIN TRAN;

  EXEC dbo.MoveSubtree
  @root  = 7,
  @mgrid = 10;

  -- After moving subtree
  SELECT empid, REPLICATE(' | ', lvl) + empname AS empname, lvl, path
  FROM dbo.Employees
  ORDER BY path;

ROLLBACK TRAN; -- rollback used in order not to apply the change

---------------------------------------------------------------------
-- Removing a Subtree
---------------------------------------------------------------------

-- Before deleteting subtree
SELECT empid, REPLICATE(' | ', lvl) + empname AS empname, lvl, path
FROM dbo.Employees
ORDER BY path;

-- Delete Subtree
BEGIN TRAN;

  DELETE FROM dbo.Employees
  WHERE path LIKE 
    (SELECT M.path + '%'
     FROM dbo.Employees as M
     WHERE M.empid = 7);

  -- After deleting subtree
  SELECT empid, REPLICATE(' | ', lvl) + empname AS empname, lvl, path
  FROM dbo.Employees
  ORDER BY path;

ROLLBACK TRAN; -- rollback used in order not to apply the change

---------------------------------------------------------------------
-- Querying Materialized Path
---------------------------------------------------------------------

-- Subtree of a given root
SELECT REPLICATE(' | ', E.lvl - M.lvl) + E.empname
FROM dbo.Employees AS E
  JOIN dbo.Employees AS M
    ON M.empid = 3 -- root
    AND E.path LIKE M.path + '%'
ORDER BY E.path;

-- Subtree of a given root, excluding root
SELECT REPLICATE(' | ', E.lvl - M.lvl - 1) + E.empname
FROM dbo.Employees AS E
  JOIN dbo.Employees AS M
    ON M.empid = 3
    AND E.path LIKE M.path + '_%'
ORDER BY E.path;

-- Leaf nodes under a given root
SELECT E.empid, E.empname
FROM dbo.Employees AS E
  JOIN dbo.Employees AS M
    ON M.empid = 3
    AND E.path LIKE M.path + '%'
WHERE NOT EXISTS
  (SELECT * 
   FROM dbo.Employees AS E2
   WHERE E2.mgrid = E.empid);

-- Subtree of a given root, limit number of levels
SELECT REPLICATE(' | ', E.lvl - M.lvl) + E.empname
FROM dbo.Employees AS E
  JOIN dbo.Employees AS M
    ON M.empid = 3
    AND E.path LIKE M.path + '%'
    AND E.lvl - M.lvl <= 2
ORDER BY E.path;

-- Nodes that are n levels under a given root
SELECT E.empid, E.empname
FROM dbo.Employees AS E
  JOIN dbo.Employees AS M
    ON M.empid = 3
    AND E.path LIKE M.path + '%'
    AND E.lvl - M.lvl = 2;

-- Ancestors of a given node (requires a table scan)
SELECT REPLICATE(' | ', M.lvl) + M.empname
FROM dbo.Employees AS E
  JOIN dbo.Employees AS M
    ON E.empid = 14
    AND E.path LIKE M.path + '%'
ORDER BY E.path;

-- Creating and Populating Auxiliary Table of Numbers
SET NOCOUNT ON;
USE tempdb;
GO
IF OBJECT_ID('dbo.Nums') IS NOT NULL
  DROP TABLE dbo.Nums;
GO
CREATE TABLE dbo.Nums(n INT NOT NULL PRIMARY KEY);
DECLARE @max AS INT = 1000000, @rc AS INT = 1;

INSERT INTO Nums VALUES(1);
WHILE @rc * 2 <= @max
BEGIN
  INSERT INTO dbo.Nums SELECT n + @rc FROM dbo.Nums;
  SET @rc = @rc * 2;
END

INSERT INTO dbo.Nums 
  SELECT n + @rc FROM dbo.Nums WHERE n + @rc <= @max;
GO

-- Creation Script for Function SplitPath
USE tempdb;
GO
IF OBJECT_ID('dbo.SplitPath') IS NOT NULL
  DROP FUNCTION dbo.SplitPath;
GO
CREATE FUNCTION dbo.SplitPath(@empid AS INT) RETURNS TABLE
AS
RETURN
  SELECT
    ROW_NUMBER() OVER(ORDER BY n) AS pos,
    CAST(SUBSTRING(path, n + 1,
           CHARINDEX('.', path, n + 1) - n - 1) AS INT) AS empid
  FROM dbo.Employees
    JOIN dbo.Nums
      ON empid = @empid
      AND n < LEN(path)
      AND SUBSTRING(path, n, 1) = '.';
GO

-- Test SplitPath function
SELECT pos, empid FROM dbo.SplitPath(14);

-- Getting ancestors using SplitPath function
SELECT REPLICATE(' | ', lvl) + empname
FROM dbo.SplitPath(14) AS SP
  JOIN dbo.Employees AS E
    ON E.empid = SP.empid
ORDER BY path;

-- Presentation
SELECT REPLICATE(' | ', lvl) + empname
FROM dbo.Employees
ORDER BY path;


---------------------------------------------------------------------
-- Sorting Separated Lists of Values
---------------------------------------------------------------------

USE tempdb;
IF OBJECT_ID('dbo.IPs', 'U') IS NOT NULL DROP TABLE dbo.IPs;

-- Creation script for table IPs
CREATE TABLE dbo.IPs
(
  ip varchar(15) NOT NULL,
  CONSTRAINT PK_IPs PRIMARY KEY(ip),
  -- CHECK constraint that validates IPs
  CONSTRAINT CHK_IP_valid CHECK
  (
      -- 3 periods and no empty octets
      ip LIKE '_%._%._%._%'
    AND
      -- not 4 periods or more
      ip NOT LIKE '%.%.%.%.%'
    AND
      -- no characters other than digits and periods
      ip NOT LIKE '%[^0-9.]%'
    AND
      -- not more than 3 digits per octet
      ip NOT LIKE '%[0-9][0-9][0-9][0-9]%'
    AND
      -- NOT 300 - 999
      ip NOT LIKE '%[3-9][0-9][0-9]%'
    AND
      -- NOT 260 - 299
      ip NOT LIKE '%2[6-9][0-9]%'
    AND
      -- NOT 256 - 259
      ip NOT LIKE '%25[6-9]%'
  )
);
GO

-- Sample data
INSERT INTO dbo.IPs(ip) VALUES
  ('131.107.2.201'),
  ('131.33.2.201'),
  ('131.33.2.202'),
  ('3.107.2.4'),
  ('3.107.3.169'),
  ('3.107.104.172'),
  ('22.107.202.123'),
  ('22.20.2.77'),
  ('22.156.9.91'),
  ('22.156.89.32');

-- IP Patterns
IF OBJECT_ID('dbo.IPPatterns') IS NOT NULL DROP VIEW dbo.IPPatterns;
GO
CREATE VIEW dbo.IPPatterns
AS

SELECT
  REPLICATE('_', N1.n) + '.' + REPLICATE('_', N2.n) + '.'
    + REPLICATE('_', N3.n) + '.' + REPLICATE('_', N4.n) AS pattern,
  N1.n AS l1, N2.n AS l2, N3.n AS l3, N4.n AS l4,
  1 AS s1, N1.n+2 AS s2, N1.n+N2.n+3 AS s3, N1.n+N2.n+N3.n+4 AS s4
FROM dbo.Nums AS N1, dbo.Nums AS N2, dbo.Nums AS N3, dbo.Nums AS N4
WHERE N1.n <= 3 AND N2.n <= 3 AND N3.n <= 3 AND N4.n <= 3;
GO

-- Sort IPs, solution 1
SELECT ip
FROM dbo.IPs
  JOIN dbo.IPPatterns
    ON ip LIKE pattern
ORDER BY
  CAST(SUBSTRING(ip, s1, l1) AS TINYINT),
  CAST(SUBSTRING(ip, s2, l2) AS TINYINT),
  CAST(SUBSTRING(ip, s3, l3) AS TINYINT),
  CAST(SUBSTRING(ip, s4, l4) AS TINYINT);

-- Sort IPs, solution 2
SELECT ip
FROM dbo.IPs
ORDER BY CAST('/' + ip + '/' AS HIERARCHYID);

-- Generic form of problem
SET NOCOUNT ON;
USE tempdb;
IF OBJECT_ID('dbo.T1', 'U') IS NOT NULL DROP TABLE dbo.T1;

CREATE TABLE dbo.T1
(
  id  INT          NOT NULL IDENTITY PRIMARY KEY,
  val VARCHAR(500) NOT NULL
);
GO

INSERT INTO dbo.T1(val) VALUES
  ('100'),
  ('7,4,250'),
  ('22,40,5,60,4,100,300,478,19710212'),
  ('22,40,5,60,4,99,300,478,19710212'),
  ('22,40,5,60,4,99,300,478,9999999'),
  ('10,30,40,50,20,30,40'),
  ('7,4,250'),
  ('-1'),
  ('-2'),
  ('-11'),
  ('-22'),
  ('-123'),
  ('-321'),
  ('22,40,5,60,4,-100,300,478,19710212'),
  ('22,40,5,60,4,-99,300,478,19710212');

SELECT id, val
FROM dbo.T1
ORDER BY CAST('/' + REPLACE(val, ',', '/') + '/' AS HIERARCHYID);

---------------------------------------------------------------------
-- Nested Sets
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Assigning Left and Right Values 
---------------------------------------------------------------------

-- Producing Binary Sort Paths Representing Nested Sets Relationships
USE tempdb;
GO
-- Create index to speed sorting siblings by empname, empid
CREATE UNIQUE INDEX idx_unc_mgrid_empname_empid
  ON dbo.Employees(mgrid, empname, empid);
GO

DECLARE @root AS INT = 1;

-- CTE with two numbers: 1 and 2
WITH TwoNums
AS
(
  SELECT n FROM(VALUES(1),(2)) AS D(n)
),
-- CTE with two binary sort paths for each node:
--   One smaller than descendants sort paths
--   One greater than descendants sort paths
SortPath
AS
(
  SELECT empid, 0 AS lvl, n,
    CAST(n AS VARBINARY(MAX)) AS sort_path
  FROM dbo.Employees CROSS JOIN TwoNums
  WHERE empid = @root

  UNION ALL

  SELECT C.empid, P.lvl + 1, TN.n, 
    P.sort_path + CAST(
      (-1+ROW_NUMBER() OVER(PARTITION BY C.mgrid
                        -- *** determines order of siblings ***
                        ORDER BY C.empname, C.empid))/2*2+TN.n
      AS BINARY(4))
  FROM SortPath AS P
    JOIN dbo.Employees AS C
      ON P.n = 1
      AND C.mgrid = P.empid
    CROSS JOIN TwoNums AS TN
)
SELECT * FROM SortPath
ORDER BY sort_path;
GO

-- CTE Code That Creates Nested Sets Relationships
DECLARE @root AS INT = 1;

-- CTE with two numbers: 1 and 2
WITH TwoNums
AS
(
  SELECT n FROM(VALUES(1),(2)) AS D(n)
),
-- CTE with two binary sort paths for each node:
--   One smaller than descendants sort paths
--   One greater than descendants sort paths
SortPath
AS
(
  SELECT empid, 0 AS lvl, n,
    CAST(n AS VARBINARY(MAX)) AS sort_path
  FROM dbo.Employees CROSS JOIN TwoNums
  WHERE empid = @root

  UNION ALL

  SELECT C.empid, P.lvl + 1, TN.n, 
    P.sort_path + CAST(
      ROW_NUMBER() OVER(PARTITION BY C.mgrid
                        -- *** determines order of siblings ***
                        ORDER BY C.empname, C.empid, TN.n)
      AS BINARY(4))
  FROM SortPath AS P
    JOIN dbo.Employees AS C
      ON P.n = 1
      AND C.mgrid = P.empid
    CROSS JOIN TwoNums AS TN
),
-- CTE with Row Numbers Representing sort_path Order
Sort
AS
(
  SELECT empid, lvl,
    ROW_NUMBER() OVER(ORDER BY sort_path) AS sortval
  FROM SortPath
),
-- CTE with Left and Right Values Representing
-- Nested Sets Relationships
NestedSets
AS
(
  SELECT empid, lvl, MIN(sortval) AS lft, MAX(sortval) AS rgt
  FROM Sort
  GROUP BY empid, lvl
)
SELECT * FROM NestedSets
ORDER BY lft;
GO

-- Materializing Nested Sets Relationships in a Table 
SET NOCOUNT ON;
USE tempdb;
GO

DECLARE @root AS INT = 1;

WITH TwoNums
AS
(
  SELECT n FROM(VALUES(1),(2)) AS D(n)
),
SortPath
AS
(
  SELECT empid, 0 AS lvl, n,
    CAST(n AS VARBINARY(MAX)) AS sort_path
  FROM dbo.Employees CROSS JOIN TwoNums
  WHERE empid = @root

  UNION ALL

  SELECT C.empid, P.lvl + 1, TN.n, 
    P.sort_path + CAST(
      ROW_NUMBER() OVER(PARTITION BY C.mgrid
                        -- *** determines order of siblings ***
                        ORDER BY C.empname, C.empid, TN.n)
      AS BINARY(4))
  FROM SortPath AS P
    JOIN dbo.Employees AS C
      ON P.n = 1
      AND C.mgrid = P.empid
    CROSS JOIN TwoNums AS TN
),
Sort
AS
(
  SELECT empid, lvl,
    ROW_NUMBER() OVER(ORDER BY sort_path) AS sortval
  FROM SortPath
),
NestedSets
AS
(
  SELECT empid, lvl, MIN(sortval) AS lft, MAX(sortval) AS rgt
  FROM Sort
  GROUP BY empid, lvl
)
SELECT E.empid, E.empname, E.salary, NS.lvl, NS.lft, NS.rgt
INTO dbo.EmployeesNS
FROM NestedSets AS NS
  JOIN dbo.Employees AS E
    ON E.empid = NS.empid;

ALTER TABLE dbo.EmployeesNS ADD PRIMARY KEY NONCLUSTERED(empid);
CREATE UNIQUE CLUSTERED INDEX idx_unc_lft_rgt ON dbo.EmployeesNS(lft, rgt);
GO

---------------------------------------------------------------------
-- Querying
---------------------------------------------------------------------

-- Descendants of a given root
SELECT C.empid, REPLICATE(' | ', C.lvl - P.lvl) + C.empname AS empname
FROM dbo.EmployeesNS AS P
  JOIN dbo.EmployeesNS AS C
    ON P.empid = 3
    AND C.lft >= P.lft AND C.rgt <= P.rgt
ORDER BY C.lft;

-- Descendants of a given root, limiting 2 levels
SELECT C.empid, REPLICATE(' | ', C.lvl - P.lvl) + C.empname AS empname
FROM dbo.EmployeesNS AS P
  JOIN dbo.EmployeesNS AS C
    ON P.empid = 3
    AND C.lft >= P.lft AND C.rgt <= P.rgt
    AND C.lvl - P.lvl <= 2
ORDER BY C.lft;

-- Leaf nodes under a given root
SELECT C.empid, C.empname
FROM dbo.EmployeesNS AS P
  JOIN dbo.EmployeesNS AS C
    ON P.empid = 3
    AND C.lft >= P.lft AND C.rgt <= P.rgt
WHERE C.rgt - C.lft = 1;

-- Count of subordinates of each node
SELECT empid, (rgt - lft - 1) / 2 AS cnt,
  REPLICATE(' | ', lvl) + empname AS empname
FROM dbo.EmployeesNS
ORDER BY lft;

-- Ancestors of a given node
SELECT P.empid, P.empname, P.lvl
FROM dbo.EmployeesNS AS P
  JOIN dbo.EmployeesNS AS C
    ON C.empid = 14
    AND C.lft >= P.lft AND C.rgt <= P.rgt;
GO

-- Cleanup
DROP TABLE dbo.EmployeesNS;
GO

