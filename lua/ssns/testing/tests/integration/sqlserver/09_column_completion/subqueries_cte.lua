-- Integration Tests: Column Completion - Subqueries and CTEs
-- Test IDs: 4231-4270
-- Tests column completion in subqueries, derived tables, and CTEs

return {
  -- ============================================================================
  -- 4231-4245: Subqueries and Derived Tables
  -- ============================================================================
  {
    number = 4231,
    description = "Subquery - columns in SELECT subquery",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID, (SELECT  FROM Departments WHERE DepartmentID = e.DepartmentID) FROM Employees e]],
    cursor = { line = 0, col = 26 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4232,
    description = "Subquery - columns in WHERE subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DepartmentID IN (SELECT  FROM Departments)]],
    cursor = { line = 0, col = 57 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4233,
    description = "Subquery - correlated subquery outer reference",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e WHERE Salary > (SELECT AVG(Salary) FROM Employees WHERE DepartmentID = e.)]],
    cursor = { line = 0, col = 100 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4234,
    description = "Derived table - columns from derived table",
    database = "vim_dadbod_test",
    query = [[SELECT  FROM (SELECT EmployeeID, FirstName FROM Employees) AS sub]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
        excludes = {
          "LastName",  -- Not selected in subquery
          "Salary",
        },
      },
    },
  },
  {
    number = 4235,
    description = "Derived table - alias-qualified",
    database = "vim_dadbod_test",
    query = [[SELECT sub. FROM (SELECT EmployeeID, FirstName FROM Employees) AS sub]],
    cursor = { line = 0, col = 11 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4236,
    description = "Derived table - with expression alias",
    database = "vim_dadbod_test",
    query = [[SELECT  FROM (SELECT EmployeeID, FirstName + ' ' + LastName AS FullName FROM Employees) sub]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FullName",
        },
      },
    },
  },
  {
    number = 4237,
    description = "Derived table - JOIN with derived table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN (SELECT DepartmentID, DepartmentName FROM Departments) d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 109 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4238,
    description = "Nested subquery - inner subquery columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM Departments WHERE ManagerID IN (SELECT  FROM Employees))]],
    cursor = { line = 0, col = 116 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4239,
    description = "EXISTS subquery - columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e WHERE EXISTS (SELECT 1 FROM Departments d WHERE d.ManagerID = e.)]],
    cursor = { line = 0, col = 91 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4240,
    description = "Subquery with multiple tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (SELECT e.FirstName, d.DepartmentName FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID) sub WHERE sub.]],
    cursor = { line = 0, col = 143 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4241,
    description = "Scalar subquery - column reference",
    database = "vim_dadbod_test",
    query = [[SELECT (SELECT  FROM Departments d WHERE d.DepartmentID = e.DepartmentID) AS DeptName FROM Employees e]],
    cursor = { line = 0, col = 15 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4242,
    description = "Derived table - multiline",
    database = "vim_dadbod_test",
    query = [[SELECT sub.
FROM (
  SELECT EmployeeID, FirstName
  FROM Employees
) AS sub]],
    cursor = { line = 0, col = 11 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4243,
    description = "Subquery in FROM with star expansion",
    database = "vim_dadbod_test",
    query = [[SELECT  FROM (SELECT * FROM Employees WHERE DepartmentID = 1) AS filtered]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4244,
    description = "CROSS APPLY - columns from applied function",
    database = "vim_dadbod_test",
    query = [[SELECT e.*, f. FROM Employees e CROSS APPLY fn_GetEmployeesBySalaryRange(50000, 100000) AS f]],
    cursor = { line = 0, col = 15 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4245,
    description = "OUTER APPLY - columns",
    database = "vim_dadbod_test",
    query = [[SELECT e.FirstName, details. FROM Employees e OUTER APPLY (SELECT TOP 1 * FROM Projects) AS details]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "ProjectName",
          "ProjectID",
        },
      },
    },
  },

  -- ============================================================================
  -- 4246-4270: Common Table Expressions (CTEs)
  -- ============================================================================
  {
    number = 4246,
    description = "CTE - basic column completion from CTE",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees)
SELECT  FROM EmpCTE]],
    cursor = { line = 1, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
        excludes = {
          "LastName",
        },
      },
    },
  },
  {
    number = 4247,
    description = "CTE - alias-qualified column",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees)
SELECT c. FROM EmpCTE c]],
    cursor = { line = 1, col = 9 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4248,
    description = "CTE - with column definition",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE (ID, Name) AS (SELECT EmployeeID, FirstName FROM Employees)
SELECT  FROM EmpCTE]],
    cursor = { line = 1, col = 7 },
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
    number = 4249,
    description = "CTE - multiple CTEs first CTE",
    database = "vim_dadbod_test",
    query = [[WITH
  EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees),
  DeptCTE AS (SELECT DepartmentID, DepartmentName FROM Departments)
SELECT e. FROM EmpCTE e, DeptCTE d]],
    cursor = { line = 3, col = 9 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
        excludes = {
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4250,
    description = "CTE - multiple CTEs second CTE",
    database = "vim_dadbod_test",
    query = [[WITH
  EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees),
  DeptCTE AS (SELECT DepartmentID, DepartmentName FROM Departments)
SELECT d. FROM EmpCTE e, DeptCTE d]],
    cursor = { line = 3, col = 9 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "DepartmentName",
        },
        excludes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4251,
    description = "CTE - JOIN with CTE",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT EmployeeID, DepartmentID FROM Employees)
SELECT * FROM EmpCTE e JOIN Departments d ON e.DepartmentID = d.]],
    cursor = { line = 1, col = 66 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4252,
    description = "CTE - recursive CTE columns",
    database = "vim_dadbod_test",
    query = [[WITH RECURSIVE EmpHierarchy AS (
  SELECT EmployeeID, ManagerID, FirstName, 1 as Level FROM Employees WHERE ManagerID IS NULL
  UNION ALL
  SELECT e.EmployeeID, e.ManagerID, e.FirstName, h.Level + 1 FROM Employees e JOIN EmpHierarchy h ON e.ManagerID = h.EmployeeID
)
SELECT  FROM EmpHierarchy]],
    cursor = { line = 5, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "ManagerID",
          "FirstName",
          "Level",
        },
      },
    },
  },
  {
    number = 4253,
    description = "CTE - CTE referencing another CTE",
    database = "vim_dadbod_test",
    query = [[WITH
  EmpCTE AS (SELECT EmployeeID, FirstName, DepartmentID FROM Employees),
  EnrichedCTE AS (SELECT e.*, d.DepartmentName FROM EmpCTE e JOIN Departments d ON e.DepartmentID = d.DepartmentID)
SELECT  FROM EnrichedCTE]],
    cursor = { line = 3, col = 7 },
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
    number = 4254,
    description = "CTE - WHERE clause completion",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName, Salary FROM Employees)
SELECT * FROM EmpCTE WHERE ]],
    cursor = { line = 1, col = 27 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4255,
    description = "CTE - ORDER BY completion",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees)
SELECT * FROM EmpCTE ORDER BY ]],
    cursor = { line = 1, col = 30 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4256,
    description = "CTE - multiline complex",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (
  SELECT
    EmployeeID,
    FirstName,
    LastName
  FROM Employees
  WHERE DepartmentID = 1
)
SELECT
  c.
FROM EmpCTE c]],
    cursor = { line = 9, col = 4 },
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
    number = 4257,
    description = "CTE - used in subquery",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT EmployeeID, DepartmentID FROM Employees)
SELECT * FROM Departments d WHERE d.DepartmentID IN (SELECT  FROM EmpCTE)]],
    cursor = { line = 1, col = 63 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4258,
    description = "CTE - aggregate in CTE",
    database = "vim_dadbod_test",
    query = [[WITH DeptStats AS (SELECT DepartmentID, COUNT(*) AS EmpCount, AVG(Salary) AS AvgSalary FROM Employees GROUP BY DepartmentID)
SELECT  FROM DeptStats]],
    cursor = { line = 1, col = 7 },
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
    number = 4259,
    description = "CTE - with star in CTE",
    database = "vim_dadbod_test",
    query = [[WITH AllEmps AS (SELECT * FROM Employees)
SELECT a. FROM AllEmps a]],
    cursor = { line = 1, col = 9 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4260,
    description = "CTE - CTE name completion in FROM",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT EmployeeID FROM Employees)
SELECT * FROM ]],
    cursor = { line = 1, col = 14 },
    expected = {
      type = "table",
      items = {
        includes = {
          "EmpCTE",
          "Employees",
        },
      },
    },
  },
  {
    number = 4261,
    description = "CTE - UPDATE with CTE",
    database = "vim_dadbod_test",
    query = [[WITH ToUpdate AS (SELECT EmployeeID, Salary FROM Employees WHERE DepartmentID = 1)
UPDATE ToUpdate SET ]],
    cursor = { line = 1, col = 20 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
        },
      },
    },
  },
  {
    number = 4262,
    description = "CTE - DELETE with CTE",
    database = "vim_dadbod_test",
    query = [[WITH ToDelete AS (SELECT EmployeeID FROM Employees WHERE DepartmentID = 1)
DELETE FROM ToDelete WHERE ]],
    cursor = { line = 1, col = 27 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4263,
    description = "CTE - INSERT from CTE",
    database = "vim_dadbod_test",
    query = [[WITH NewEmps AS (SELECT FirstName, LastName FROM Employees WHERE DepartmentID = 1)
INSERT INTO Employees (FirstName, LastName) SELECT  FROM NewEmps]],
    cursor = { line = 1, col = 51 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4264,
    description = "CTE - CTE not visible outside WITH",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM EmpCTE]],
    cursor = { line = 0, col = 14 },
    expected = {
      type = "table",
      items = {
        excludes = {
          "EmpCTE",  -- Should not be visible without WITH
        },
      },
    },
  },
  {
    number = 4265,
    description = "CTE - three CTEs chain",
    database = "vim_dadbod_test",
    query = [[WITH
  A AS (SELECT EmployeeID, DepartmentID FROM Employees),
  B AS (SELECT DepartmentID, DepartmentName FROM Departments),
  C AS (SELECT a.EmployeeID, b.DepartmentName FROM A a JOIN B b ON a.DepartmentID = b.DepartmentID)
SELECT  FROM C]],
    cursor = { line = 4, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4266,
    description = "CTE - expression column in CTE",
    database = "vim_dadbod_test",
    query = [[WITH EmpNames AS (SELECT EmployeeID, FirstName + ' ' + LastName AS FullName FROM Employees)
SELECT  FROM EmpNames]],
    cursor = { line = 1, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FullName",
        },
      },
    },
  },
  {
    number = 4267,
    description = "CTE - CASE expression in CTE",
    database = "vim_dadbod_test",
    query = [[WITH SalaryBands AS (SELECT EmployeeID, CASE WHEN Salary > 100000 THEN 'High' ELSE 'Low' END AS Band FROM Employees)
SELECT  FROM SalaryBands]],
    cursor = { line = 1, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "Band",
        },
      },
    },
  },
  {
    number = 4268,
    description = "CTE - window function in CTE",
    database = "vim_dadbod_test",
    query = [[WITH Ranked AS (SELECT EmployeeID, ROW_NUMBER() OVER (ORDER BY Salary DESC) AS RowNum FROM Employees)
SELECT  FROM Ranked]],
    cursor = { line = 1, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "RowNum",
        },
      },
    },
  },
  {
    number = 4269,
    description = "CTE - UNION in CTE",
    database = "vim_dadbod_test",
    query = [[WITH Combined AS (
  SELECT EmployeeID, FirstName FROM Employees WHERE DepartmentID = 1
  UNION ALL
  SELECT EmployeeID, FirstName FROM Employees WHERE DepartmentID = 2
)
SELECT  FROM Combined]],
    cursor = { line = 5, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4270,
    description = "CTE - nested CTE reference chain",
    database = "vim_dadbod_test",
    query = [[WITH
  Level1 AS (SELECT EmployeeID FROM Employees),
  Level2 AS (SELECT * FROM Level1),
  Level3 AS (SELECT * FROM Level2)
SELECT  FROM Level3]],
    cursor = { line = 4, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
}
