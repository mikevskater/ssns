-- Integration Tests: Temp Table Completion
-- Test IDs: 4451-4500
-- Tests temporary table completion scenarios

return {
  -- ============================================================================
  -- 4451-4460: Basic temp table reference completion
  -- ============================================================================
  {
    number = 4451,
    description = "Temp table - local temp table in FROM",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TempEmployees",
          "Employees",
        },
      },
    },
  },
  {
    number = 4452,
    description = "Temp table - local temp table with prefix filter",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT * FROM #Temp█]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TempEmployees",
        },
      },
    },
  },
  {
    number = 4453,
    description = "Temp table - global temp table in FROM",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE ##GlobalTemp (ID INT, Name VARCHAR(100))
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "##GlobalTemp",
          "Employees",
        },
      },
    },
  },
  {
    number = 4454,
    description = "Temp table - multiple temp tables",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #Temp1 (ID INT)
CREATE TABLE #Temp2 (Name VARCHAR(100))
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#Temp1",
          "#Temp2",
        },
      },
    },
  },
  {
    number = 4455,
    description = "Temp table - SELECT INTO creates temp table",
    database = "vim_dadbod_test",
    query = [[SELECT * INTO #TempResult FROM Employees
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TempResult",
          "Employees",
        },
      },
    },
  },
  {
    number = 4456,
    description = "Temp table - temp table in JOIN",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempDept (DeptID INT, DeptName VARCHAR(100))
SELECT * FROM Employees e JOIN █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TempDept",
          "Departments",
        },
      },
    },
  },
  {
    number = 4457,
    description = "Temp table - temp table with alias",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT t.█ FROM #TempEmployees t]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
        },
      },
    },
  },
  {
    number = 4458,
    description = "Temp table - INSERT INTO temp table",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
INSERT INTO █ (ID, Name) VALUES (1, 'Test')]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TempEmployees",
        },
      },
    },
  },
  {
    number = 4459,
    description = "Temp table - UPDATE temp table",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
UPDATE █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TempEmployees",
          "Employees",
        },
      },
    },
  },
  {
    number = 4460,
    description = "Temp table - DELETE FROM temp table",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
DELETE FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TempEmployees",
        },
      },
    },
  },

  -- ============================================================================
  -- 4461-4470: Temp table column completion
  -- ============================================================================
  {
    number = 4461,
    description = "Temp table - columns from CREATE TABLE definition",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (EmployeeID INT, FirstName VARCHAR(50), LastName VARCHAR(50))
SELECT █ FROM #TempEmployees]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4462,
    description = "Temp table - columns from SELECT INTO",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID, FirstName, DepartmentID INTO #TempEmp FROM Employees
SELECT █ FROM #TempEmp]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "DepartmentID",
        },
        excludes = {
          "LastName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4463,
    description = "Temp table - columns from SELECT * INTO",
    database = "vim_dadbod_test",
    query = [[SELECT * INTO #TempEmp FROM Employees
SELECT █ FROM #TempEmp]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4464,
    description = "Temp table - columns in WHERE clause",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100), Salary DECIMAL(10,2))
SELECT * FROM #TempEmployees WHERE █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
          "Salary",
        },
      },
    },
  },
  {
    number = 4465,
    description = "Temp table - columns in UPDATE SET",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100), Salary DECIMAL(10,2))
UPDATE #TempEmployees SET █ = 'New Value']],
    expected = {
      type = "column",
      items = {
        includes = {
          "Name",
          "Salary",
        },
      },
    },
  },
  {
    number = 4466,
    description = "Temp table - columns in INSERT column list",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100), Salary DECIMAL(10,2))
INSERT INTO #TempEmployees (█) VALUES (1, 'Test', 50000)]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
          "Salary",
        },
      },
    },
  },
  {
    number = 4467,
    description = "Temp table - columns in ORDER BY",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100), Salary DECIMAL(10,2))
SELECT * FROM #TempEmployees ORDER BY █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
          "Salary",
        },
      },
    },
  },
  {
    number = 4468,
    description = "Temp table - columns in GROUP BY",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, DeptID INT, Salary DECIMAL(10,2))
SELECT DeptID, SUM(Salary) FROM #TempEmployees GROUP BY █]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DeptID",
        },
      },
    },
  },
  {
    number = 4469,
    description = "Temp table - columns in ON clause",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempDept (DeptID INT, DeptName VARCHAR(100))
SELECT * FROM Employees e JOIN #TempDept t ON e.DepartmentID =█ t.]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DeptID",
        },
      },
    },
  },
  {
    number = 4470,
    description = "Temp table - alias-qualified columns",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT te.ID, te.█ FROM #TempEmployees te]],
    expected = {
      type = "column",
      items = {
        includes = {
          "Name",
        },
      },
    },
  },

  -- ============================================================================
  -- 4471-4480: Temp table with complex definitions
  -- ============================================================================
  {
    number = 4471,
    description = "Temp table - with PRIMARY KEY",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT PRIMARY KEY, Name VARCHAR(100) NOT NULL)
SELECT █ FROM #TempEmployees]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
        },
      },
    },
  },
  {
    number = 4472,
    description = "Temp table - with DEFAULT values",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100) DEFAULT 'Unknown', CreatedDate DATETIME DEFAULT GETDATE())
SELECT █ FROM #TempEmployees]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
          "CreatedDate",
        },
      },
    },
  },
  {
    number = 4473,
    description = "Temp table - with IDENTITY column",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT IDENTITY(1,1), Name VARCHAR(100))
SELECT █ FROM #TempEmployees]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
        },
      },
    },
  },
  {
    number = 4474,
    description = "Temp table - with computed column",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (FirstName VARCHAR(50), LastName VARCHAR(50), FullName AS FirstName + ' ' + LastName)
SELECT █ FROM #TempEmployees]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
          "FullName",
        },
      },
    },
  },
  {
    number = 4475,
    description = "Temp table - with CHECK constraint",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Age INT CHECK (Age >= 18), Name VARCHAR(100))
SELECT █ FROM #TempEmployees]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Age",
          "Name",
        },
      },
    },
  },
  {
    number = 4476,
    description = "Temp table - with multiple data types",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempData (
  IntCol INT,
  BigIntCol BIGINT,
  DecimalCol DECIMAL(18,2),
  VarcharCol VARCHAR(MAX),
  NVarcharCol NVARCHAR(100),
  DateCol DATE,
  DateTimeCol DATETIME2,
  BitCol BIT,
  UniqueCol UNIQUEIDENTIFIER
)
SELECT █ FROM #TempData]],
    expected = {
      type = "column",
      items = {
        includes = {
          "IntCol",
          "BigIntCol",
          "DecimalCol",
          "VarcharCol",
          "DateCol",
          "BitCol",
        },
      },
    },
  },
  {
    number = 4477,
    description = "Temp table - SELECT INTO with JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT e.EmployeeID, e.FirstName, d.DepartmentName
INTO #EmpDept
FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID
SELECT █ FROM #EmpDept]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4478,
    description = "Temp table - SELECT INTO with aliased columns",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID AS ID, FirstName AS Name INTO #TempEmp FROM Employees
SELECT █ FROM #TempEmp]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
        },
        excludes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4479,
    description = "Temp table - SELECT INTO with aggregation",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) AS EmpCount, AVG(Salary) AS AvgSalary
INTO #DeptStats
FROM Employees GROUP BY DepartmentID
SELECT █ FROM #DeptStats]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "EmpCount",
          "AvgSalary",
        },
      },
    },
  },
  {
    number = 4480,
    description = "Temp table - with index definition",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100), INDEX IX_Name (Name))
SELECT █ FROM #TempEmployees]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
        },
      },
    },
  },

  -- ============================================================================
  -- 4481-4490: Temp table scope and visibility
  -- ============================================================================
  {
    number = 4481,
    description = "Temp table - defined in earlier batch",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
GO
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TempEmployees",
        },
      },
    },
  },
  {
    number = 4482,
    description = "Temp table - not visible after DROP",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
DROP TABLE #TempEmployees
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        excludes = {
          "#TempEmployees",
        },
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4483,
    description = "Temp table - recreated after DROP",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT)
DROP TABLE #TempEmployees
CREATE TABLE #TempEmployees (NewID INT, NewName VARCHAR(100))
SELECT █ FROM #TempEmployees]],
    expected = {
      type = "column",
      items = {
        includes = {
          "NewID",
          "NewName",
        },
        excludes = {
          "ID",
        },
      },
    },
  },
  {
    number = 4484,
    description = "Temp table - IF EXISTS scope",
    database = "vim_dadbod_test",
    query = [[IF OBJECT_ID('tempdb..#TempEmployees') IS NOT NULL DROP TABLE #TempEmployees
CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TempEmployees",
        },
      },
    },
  },
  {
    number = 4485,
    description = "Temp table - multiple temp tables different batches",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #Temp1 (Col1 INT)
GO
CREATE TABLE #Temp2 (Col2 VARCHAR(100))
GO
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#Temp1",
          "#Temp2",
        },
      },
    },
  },
  {
    number = 4486,
    description = "Temp table - in stored procedure body",
    database = "vim_dadbod_test",
    query = [[CREATE PROCEDURE sp_Test AS
BEGIN
  CREATE TABLE #LocalTemp (ID INT, Value VARCHAR(100))
  SELECT * FROM█
END]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#LocalTemp",
          "Employees",
        },
      },
    },
  },
  {
    number = 4487,
    description = "Temp table - in IF block",
    database = "vim_dadbod_test",
    query = [[IF 1=1
BEGIN
  CREATE TABLE #ConditionalTemp (ID INT)
  SELECT * FROM█
END]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#ConditionalTemp",
        },
      },
    },
  },
  {
    number = 4488,
    description = "Temp table - global temp visible",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE ##GlobalTemp (ID INT, Name VARCHAR(100))
GO
SELECT * FROM ##█]],
    expected = {
      type = "table",
      items = {
        includes = {
          "##GlobalTemp",
        },
      },
    },
  },
  {
    number = 4489,
    description = "Temp table - mixed local and global",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #LocalTemp (ID INT)
CREATE TABLE ##GlobalTemp (GID INT)
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#LocalTemp",
          "##GlobalTemp",
        },
      },
    },
  },
  {
    number = 4490,
    description = "Temp table - in transaction",
    database = "vim_dadbod_test",
    query = [[BEGIN TRANSACTION
CREATE TABLE #TranTemp (ID INT, Name VARCHAR(100))
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TranTemp",
        },
      },
    },
  },

  -- ============================================================================
  -- 4491-4500: Temp table edge cases
  -- ============================================================================
  {
    number = 4491,
    description = "Temp table - with schema prefix",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT * FROM dbo.█]],
    expected = {
      type = "table",
      items = {
        -- Temp tables don't use schema prefix
        includes = {
          "Employees",
        },
        excludes = {
          "#TempEmployees",
        },
      },
    },
  },
  {
    number = 4492,
    description = "Temp table - long temp table name",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #VeryLongTempTableNameForTestingPurposes (ID INT)
SELECT * FROM #Very█]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#VeryLongTempTableNameForTestingPurposes",
        },
      },
    },
  },
  {
    number = 4493,
    description = "Temp table - name with numbers",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #Temp123 (ID INT)
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#Temp123",
        },
      },
    },
  },
  {
    number = 4494,
    description = "Temp table - name with underscores",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #Temp_Table_Name (ID INT)
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#Temp_Table_Name",
        },
      },
    },
  },
  {
    number = 4495,
    description = "Temp table - truncated name (116+ chars)",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #ThisIsAVeryLongTableNameThatWillBeTruncatedBySQL (ID INT)
SELECT * FROM #This█]],
    expected = {
      type = "table",
      items = {
        includes_any = {
          "#ThisIsAVeryLongTableNameThatWillBeTruncatedBySQL",
        },
      },
    },
  },
  {
    number = 4496,
    description = "Temp table - TRUNCATE TABLE",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
TRUNCATE TABLE █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TempEmployees",
        },
      },
    },
  },
  {
    number = 4497,
    description = "Temp table - ALTER TABLE",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT)
ALTER TABLE █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "#TempEmployees",
        },
      },
    },
  },
  {
    number = 4498,
    description = "Temp table - columns after ALTER TABLE ADD",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (ID INT)
ALTER TABLE #TempEmployees ADD NewCol VARCHAR(100)
SELECT █ FROM #TempEmployees]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "NewCol",
        },
      },
    },
  },
  {
    number = 4499,
    description = "Temp table - sp_rename temp table column",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #TempEmployees (OldName INT)
EXEC sp_rename '#TempEmployees.OldName', 'NewName', 'COLUMN'
SELECT █ FROM #TempEmployees]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "NewName",
          "OldName",
        },
      },
    },
  },
  {
    number = 4500,
    description = "Temp table - complex multi-temp table query",
    database = "vim_dadbod_test",
    query = [[CREATE TABLE #Temp1 (ID INT, DeptID INT)
CREATE TABLE #Temp2 (DeptID INT, DeptName VARCHAR(100))
SELECT t1.ID, t1.DeptID, t2.█
FROM #Temp1 t1
JOIN #Temp2 t2 ON t1.DeptID = t2.DeptID]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DeptName",
        },
      },
    },
  },
}
