-- Integration Tests: CTE Completion
-- Test IDs: 4401-4450
-- Tests Common Table Expression (CTE) completion scenarios

return {
  -- ============================================================================
  -- 4401-4410: Basic CTE table reference completion
  -- ============================================================================
  {
    number = 4401,
    description = "CTE - reference CTE name in FROM clause",
    database = "vim_dadbod_test",
    query = [[WITH EmployeeCTE AS (SELECT * FROM Employees)
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "EmployeeCTE",
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4402,
    description = "CTE - reference CTE in JOIN",
    database = "vim_dadbod_test",
    query = [[WITH DeptCTE AS (SELECT * FROM Departments)
SELECT * FROM Employees e JOIN █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "DeptCTE",
          "Departments",
        },
      },
    },
  },
  {
    number = 4403,
    description = "CTE - multiple CTEs available",
    database = "vim_dadbod_test",
    query = [[WITH
  EmpCTE AS (SELECT * FROM Employees),
  DeptCTE AS (SELECT * FROM Departments)
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "EmpCTE",
          "DeptCTE",
          "Employees",
        },
      },
    },
  },
  {
    number = 4404,
    description = "CTE - CTE name completion with prefix",
    database = "vim_dadbod_test",
    query = [[WITH EmployeeCTE AS (SELECT * FROM Employees)
SELECT * FROM Emp█]],
    expected = {
      type = "table",
      items = {
        includes = {
          "EmployeeCTE",
          "Employees",
        },
      },
    },
  },
  {
    number = 4405,
    description = "CTE - CTE with explicit column list",
    database = "vim_dadbod_test",
    query = [[WITH EmployeeCTE (ID, Name, Dept) AS (SELECT EmployeeID, FirstName, DepartmentID FROM Employees)
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "EmployeeCTE",
        },
      },
    },
  },
  {
    number = 4406,
    description = "CTE - nested CTE reference",
    database = "vim_dadbod_test",
    query = [[WITH
  Base AS (SELECT * FROM Employees),
  Derived AS (SELECT * FROM Base)
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Base",
          "Derived",
        },
      },
    },
  },
  {
    number = 4407,
    description = "CTE - recursive CTE reference",
    database = "vim_dadbod_test",
    query = [[WITH EmpHierarchy AS (
  SELECT EmployeeID, DepartmentID, 1 AS Level FROM Employees WHERE DepartmentID IS NULL
  UNION ALL
  SELECT e.EmployeeID, e.DepartmentID, eh.Level + 1 FROM Employees e JOIN EmpHierarchy eh ON e.DepartmentID = eh.EmployeeID
)
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "EmpHierarchy",
          "Employees",
        },
      },
    },
  },
  {
    number = 4408,
    description = "CTE - CTE in subquery FROM",
    database = "vim_dadbod_test",
    query = [[WITH DeptCTE AS (SELECT * FROM Departments)
SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM █)]],
    expected = {
      type = "table",
      items = {
        includes = {
          "DeptCTE",
          "Departments",
        },
      },
    },
  },
  {
    number = 4409,
    description = "CTE - CTE not visible outside query",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
        excludes = {
          "EmployeeCTE",
          "DeptCTE",
        },
      },
    },
  },
  {
    number = 4410,
    description = "CTE - case insensitive CTE name",
    database = "vim_dadbod_test",
    query = [[WITH employeecte AS (SELECT * FROM Employees)
SELECT * FROM EMPLOYEE█]],
    expected = {
      type = "table",
      items = {
        includes_any = {
          "employeecte",
          "EmployeeCTE",
          "Employees",
        },
      },
    },
  },

  -- ============================================================================
  -- 4411-4420: CTE column completion
  -- ============================================================================
  {
    number = 4411,
    description = "CTE - columns from CTE (inherited from source)",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT █ FROM EmpCTE]],
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
    number = 4412,
    description = "CTE - columns from CTE with alias",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT e.█ FROM EmpCTE e]],
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
    number = 4413,
    description = "CTE - columns from CTE with explicit column list",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE (ID, Name, Dept) AS (SELECT EmployeeID, FirstName, DepartmentID FROM Employees)
SELECT █ FROM EmpCTE]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Name",
          "Dept",
        },
        excludes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4414,
    description = "CTE - columns from CTE with selected columns",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees)
SELECT █ FROM EmpCTE]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
        excludes = {
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4415,
    description = "CTE - columns from CTE with aliased columns",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT EmployeeID AS ID, FirstName AS Name FROM Employees)
SELECT █ FROM EmpCTE]],
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
    number = 4416,
    description = "CTE - columns from recursive CTE",
    database = "vim_dadbod_test",
    query = [[WITH EmpHierarchy AS (
  SELECT EmployeeID, DepartmentID, 1 AS Level FROM Employees WHERE DepartmentID IS NULL
  UNION ALL
  SELECT e.EmployeeID, e.DepartmentID, eh.Level + 1 FROM Employees e JOIN EmpHierarchy eh ON e.DepartmentID = eh.EmployeeID
)
SELECT █ FROM EmpHierarchy]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
          "Level",
        },
      },
    },
  },
  {
    number = 4417,
    description = "CTE - columns from multiple CTEs",
    database = "vim_dadbod_test",
    query = [[WITH
  EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees),
  DeptCTE AS (SELECT DepartmentID, DepartmentName FROM Departments)
SELECT e.█, d. FROM EmpCTE e, DeptCTE d]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
        excludes = {
          "DepartmentID",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4418,
    description = "CTE - columns from second CTE",
    database = "vim_dadbod_test",
    query = [[WITH
  EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees),
  DeptCTE AS (SELECT DepartmentID, DepartmentName FROM Departments)
SELECT e.EmployeeID, d.█ FROM EmpCTE e, DeptCTE d]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "DepartmentName",
        },
        excludes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4419,
    description = "CTE - columns in ON clause with CTE",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT * FROM EmpCTE e JOIN Departments d ON e.█]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4420,
    description = "CTE - columns in WHERE with CTE",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT * FROM EmpCTE WHERE █]],
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

  -- ============================================================================
  -- 4421-4430: Complex CTE scenarios
  -- ============================================================================
  {
    number = 4421,
    description = "CTE - CTE with aggregation",
    database = "vim_dadbod_test",
    query = [[WITH DeptStats AS (SELECT DepartmentID, COUNT(*) AS EmpCount, AVG(Salary) AS AvgSalary FROM Employees GROUP BY DepartmentID)
SELECT █ FROM DeptStats]],
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
    number = 4422,
    description = "CTE - CTE with JOIN inside",
    database = "vim_dadbod_test",
    query = [[WITH EmpDept AS (SELECT e.EmployeeID, e.FirstName, d.DepartmentName FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID)
SELECT █ FROM EmpDept]],
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
    number = 4423,
    description = "CTE - CTE with window function",
    database = "vim_dadbod_test",
    query = [[WITH RankedEmps AS (SELECT EmployeeID, FirstName, Salary, ROW_NUMBER() OVER (ORDER BY Salary DESC) AS Rank FROM Employees)
SELECT █ FROM RankedEmps]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "Salary",
          "Rank",
        },
      },
    },
  },
  {
    number = 4424,
    description = "CTE - CTE used in INSERT",
    database = "vim_dadbod_test",
    query = [[WITH SourceData AS (SELECT * FROM Employees WHERE DepartmentID = 1)
INSERT INTO Projects SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "SourceData",
          "Employees",
        },
      },
    },
  },
  {
    number = 4425,
    description = "CTE - CTE used in UPDATE FROM",
    database = "vim_dadbod_test",
    query = [[WITH DeptAvg AS (SELECT DepartmentID, AVG(Salary) AS AvgSal FROM Employees GROUP BY DepartmentID)
UPDATE e SET e.Salary = d.AvgSal FROM Employees e JOIN █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "DeptAvg",
        },
      },
    },
  },
  {
    number = 4426,
    description = "CTE - CTE used in DELETE",
    database = "vim_dadbod_test",
    query = [[WITH ToDelete AS (SELECT EmployeeID FROM Employees WHERE IsActive = 0)
DELETE FROM Employees WHERE EmployeeID IN (SELECT █ FROM ToDelete)]],
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
    number = 4427,
    description = "CTE - CTE with UNION",
    database = "vim_dadbod_test",
    query = [[WITH Combined AS (
  SELECT EmployeeID AS ID, FirstName AS Name FROM Employees
  UNION ALL
  SELECT Id AS ID, Name AS Name FROM Customers
)
SELECT █ FROM Combined]],
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
    number = 4428,
    description = "CTE - CTE with CASE expression",
    database = "vim_dadbod_test",
    query = [[WITH EmpCategory AS (SELECT EmployeeID, CASE WHEN Salary > 100000 THEN 'High' ELSE 'Normal' END AS SalaryCategory FROM Employees)
SELECT █ FROM EmpCategory]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "SalaryCategory",
        },
      },
    },
  },
  {
    number = 4429,
    description = "CTE - CTE with subquery in SELECT",
    database = "vim_dadbod_test",
    query = [[WITH EmpWithDept AS (SELECT EmployeeID, (SELECT DepartmentName FROM Departments d WHERE d.DepartmentID = e.DepartmentID) AS DeptName FROM Employees e)
SELECT █ FROM EmpWithDept]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DeptName",
        },
      },
    },
  },
  {
    number = 4430,
    description = "CTE - CTE in EXISTS subquery",
    database = "vim_dadbod_test",
    query = [[WITH ActiveDepts AS (SELECT DepartmentID FROM Departments WHERE Budget > 0)
SELECT * FROM Employees e WHERE EXISTS (SELECT 1 FROM █ WHERE DepartmentID = e.DepartmentID)]],
    expected = {
      type = "table",
      items = {
        includes = {
          "ActiveDepts",
          "Departments",
        },
      },
    },
  },

  -- ============================================================================
  -- 4431-4440: CTE edge cases
  -- ============================================================================
  {
    number = 4431,
    description = "CTE - CTE name shadows table name",
    database = "vim_dadbod_test",
    query = [[WITH Employees AS (SELECT EmployeeID, FirstName FROM Employees WHERE DepartmentID = 1)
SELECT █ FROM Employees]],
    expected = {
      type = "column",
      items = {
        -- CTE shadows the table, so only CTE columns available
        includes = {
          "EmployeeID",
          "FirstName",
        },
        excludes = {
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4432,
    description = "CTE - CTE with same column names from different sources",
    database = "vim_dadbod_test",
    query = [[WITH Combined AS (
  SELECT DepartmentID FROM Employees
  UNION
  SELECT DepartmentID FROM Departments
)
SELECT █ FROM Combined]],
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
    number = 4433,
    description = "CTE - deeply nested CTEs (3 levels)",
    database = "vim_dadbod_test",
    query = [[WITH
  L1 AS (SELECT * FROM Employees),
  L2 AS (SELECT * FROM L1 WHERE DepartmentID = 1),
  L3 AS (SELECT EmployeeID, FirstName FROM L2)
SELECT █ FROM L3]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
        excludes = {
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4434,
    description = "CTE - CTE with * expansion tracking",
    database = "vim_dadbod_test",
    query = [[WITH AllEmps AS (SELECT * FROM Employees)
SELECT * FROM AllEmps WHERE █]],
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
    number = 4435,
    description = "CTE - CTE referenced multiple times",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT * FROM EmpCTE e1 JOIN EmpCTE e2 ON e1.DepartmentID = e2.█]],
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
    number = 4436,
    description = "CTE - CTE with computed column",
    database = "vim_dadbod_test",
    query = [[WITH EmpFull AS (SELECT EmployeeID, FirstName + ' ' + LastName AS FullName FROM Employees)
SELECT █ FROM EmpFull]],
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
    number = 4437,
    description = "CTE - CTE inside CTE definition not visible outside",
    database = "vim_dadbod_test",
    query = [[WITH Outer AS (
  SELECT * FROM Employees
)
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Outer",
        },
      },
    },
  },
  {
    number = 4438,
    description = "CTE - CTE with TOP clause",
    database = "vim_dadbod_test",
    query = [[WITH TopEmps AS (SELECT TOP 10 * FROM Employees ORDER BY Salary DESC)
SELECT █ FROM TopEmps]],
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
    number = 4439,
    description = "CTE - CTE with DISTINCT",
    database = "vim_dadbod_test",
    query = [[WITH UniqueDepts AS (SELECT DISTINCT DepartmentID FROM Employees)
SELECT █ FROM UniqueDepts]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
        excludes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4440,
    description = "CTE - empty column list error handling",
    database = "vim_dadbod_test",
    query = [[WITH InvalidCTE () AS (SELECT * FROM Employees)
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        -- Should still show regular tables even with invalid CTE syntax
        includes_any = {
          "Employees",
          "Departments",
        },
      },
    },
  },

  -- ============================================================================
  -- 4441-4450: CTE with various clause contexts
  -- ============================================================================
  {
    number = 4441,
    description = "CTE - ORDER BY with CTE columns",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName, Salary FROM Employees)
SELECT * FROM EmpCTE ORDER BY █]],
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
    number = 4442,
    description = "CTE - GROUP BY with CTE columns",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT DepartmentID, Salary FROM Employees)
SELECT DepartmentID, SUM(Salary) FROM EmpCTE GROUP BY █]],
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
    number = 4443,
    description = "CTE - HAVING with CTE columns",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT DepartmentID, Salary FROM Employees)
SELECT DepartmentID, AVG(Salary) FROM EmpCTE GROUP BY DepartmentID HAVING AVG(█) > 50000]],
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
    number = 4444,
    description = "CTE - multiple CTEs with different column sets",
    database = "vim_dadbod_test",
    query = [[WITH
  Emp AS (SELECT EmployeeID, FirstName FROM Employees),
  Dept AS (SELECT DepartmentID, DepartmentName FROM Departments),
  Proj AS (SELECT ProjectID, ProjectName FROM Projects)
SELECT e.EmployeeID, d.DepartmentName, p.█ FROM Emp e, Dept d, Proj p]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ProjectID",
          "ProjectName",
        },
        excludes = {
          "EmployeeID",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4445,
    description = "CTE - CTE in correlated subquery",
    database = "vim_dadbod_test",
    query = [[WITH DeptCTE AS (SELECT DepartmentID, Budget FROM Departments)
SELECT * FROM Employees e WHERE e.Salary > (SELECT Budget FROM DeptCTE d WHERE d.DepartmentID = e.█)]],
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
    number = 4446,
    description = "CTE - CTE with CROSS APPLY",
    database = "vim_dadbod_test",
    query = [[WITH DeptCTE AS (SELECT * FROM Departments)
SELECT * FROM DeptCTE d CROSS APPLY (SELECT * FROM Employees e WHERE e.DepartmentID = d.█) x]],
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
    number = 4447,
    description = "CTE - CTE with OUTER APPLY",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT * FROM EmpCTE e OUTER APPLY (SELECT TOP 1 * FROM Orders o WHERE o.EmployeeId = e.█) x]],
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
    number = 4448,
    description = "CTE - CTE referenced in MERGE statement",
    database = "vim_dadbod_test",
    query = [[WITH SourceCTE AS (SELECT * FROM Employees WHERE DepartmentID = 1)
MERGE INTO Employees AS target
USING █ AS source
ON target.EmployeeID = source.EmployeeID]],
    expected = {
      type = "table",
      items = {
        includes = {
          "SourceCTE",
        },
      },
    },
  },
  {
    number = 4449,
    description = "CTE - CTE columns in MERGE condition",
    database = "vim_dadbod_test",
    query = [[WITH SourceCTE AS (SELECT EmployeeID, FirstName, Salary FROM Employees WHERE DepartmentID = 1)
MERGE INTO Employees AS target
USING SourceCTE AS source
ON target.EmployeeID = source.█]],
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
    number = 4450,
    description = "CTE - CTE with OUTPUT clause",
    database = "vim_dadbod_test",
    query = [[WITH ToUpdate AS (SELECT EmployeeID FROM Employees WHERE DepartmentID = 1)
UPDATE Employees SET Salary = Salary * 1.1
OUTPUT inserted.█
WHERE EmployeeID IN (SELECT EmployeeID FROM ToUpdate)]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "Salary",
          "FirstName",
        },
      },
    },
  },
}
