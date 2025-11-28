-- Integration Tests: Subquery Completion
-- Test IDs: 4501-4550
-- Tests subquery completion scenarios

return {
  -- ============================================================================
  -- 4501-4510: Basic subquery table completion
  -- ============================================================================
  {
    number = 4501,
    description = "Subquery - table completion in scalar subquery",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID, (SELECT DepartmentName FROM █) FROM Employees]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
          "Employees",
        },
      },
    },
  },
  {
    number = 4502,
    description = "Subquery - table completion in WHERE IN subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM █)]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4503,
    description = "Subquery - table completion in EXISTS subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e WHERE EXISTS (SELECT 1 FROM █)]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
          "Orders",
        },
      },
    },
  },
  {
    number = 4504,
    description = "Subquery - table completion in FROM subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (SELECT * FROM █) sub]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4505,
    description = "Subquery - table completion in JOIN subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN (SELECT * FROM █) sub ON e.DepartmentID = sub.DepartmentID]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4506,
    description = "Subquery - table completion in HAVING subquery",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING COUNT(*) > (SELECT AVG(Budget) FROM █ )]],
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Departments",
          "Employees",
        },
      },
    },
  },
  {
    number = 4507,
    description = "Subquery - table completion in SELECT CASE subquery",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID, CASE WHEN Salary > (SELECT AVG(Salary) FROM █) THEN 'High' ELSE 'Low' END FROM Employees]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4508,
    description = "Subquery - nested subquery table completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM Departments WHERE ManagerID IN (SELECT EmployeeID FROM █ ))]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4509,
    description = "Subquery - CROSS APPLY subquery table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Departments d CROSS APPLY (SELECT TOP 5 * FROM █) x]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4510,
    description = "Subquery - OUTER APPLY subquery table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e OUTER APPLY (SELECT TOP 1 * FROM █) o]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Orders",
        },
      },
    },
  },

  -- ============================================================================
  -- 4511-4520: Subquery column completion
  -- ============================================================================
  {
    number = 4511,
    description = "Subquery - column completion in scalar subquery",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID, (SELECT █ FROM Departments WHERE DepartmentID = e.DepartmentID) FROM Employees e]],
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
    number = 4512,
    description = "Subquery - column completion in WHERE IN subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DepartmentID IN (SELECT █ FROM Departments)]],
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
    number = 4513,
    description = "Subquery - column completion in FROM subquery SELECT",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (SELECT █ FROM Employees) sub]],
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
    number = 4514,
    description = "Subquery - derived table column completion outer query",
    database = "vim_dadbod_test",
    query = [[SELECT sub.█ FROM (SELECT EmployeeID, FirstName FROM Employees) sub]],
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
    number = 4515,
    description = "Subquery - derived table column with alias",
    database = "vim_dadbod_test",
    query = [[SELECT sub.█ FROM (SELECT EmployeeID AS ID, FirstName AS Name FROM Employees) sub]],
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
    number = 4516,
    description = "Subquery - correlated subquery outer reference",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e WHERE Salary > (SELECT AVG(Salary) FROM Employees WHERE DepartmentID = e.█)]],
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
    number = 4517,
    description = "Subquery - EXISTS subquery column completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e WHERE EXISTS (SELECT 1 FROM Departments d WHERE d.DepartmentID = e.█)]],
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
    number = 4518,
    description = "Subquery - column from inner subquery WHERE",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (SELECT * FROM Employees WHERE █) sub]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
          "Salary",
        },
      },
    },
  },
  {
    number = 4519,
    description = "Subquery - APPLY column completion",
    database = "vim_dadbod_test",
    query = [[SELECT d.DepartmentName, x.█ FROM Departments d CROSS APPLY (SELECT TOP 5 EmployeeID, FirstName FROM Employees e WHERE e.DepartmentID = d.DepartmentID) x]],
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
    number = 4520,
    description = "Subquery - nested subquery inner column",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM Departments WHERE █ > 100)]],
    expected = {
      type = "column",
      items = {
        includes = {
          "Budget",
          "ManagerID",
        },
      },
    },
  },

  -- ============================================================================
  -- 4521-4530: Complex subquery scenarios
  -- ============================================================================
  {
    number = 4521,
    description = "Subquery - multiple derived tables",
    database = "vim_dadbod_test",
    query = [[SELECT e.EmpID, d.DeptName
FROM (SELECT EmployeeID AS EmpID, DepartmentID FROM Employees) e
JOIN (SELECT DepartmentID, DepartmentName AS DeptName FROM Departments) d
ON e.DepartmentID = d.█]],
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
    number = 4522,
    description = "Subquery - derived table with aggregation",
    database = "vim_dadbod_test",
    query = [[SELECT sub.█ FROM (SELECT DepartmentID, COUNT(*) AS EmpCount, AVG(Salary) AS AvgSal FROM Employees GROUP BY DepartmentID) sub]],
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "EmpCount",
          "AvgSal",
        },
      },
    },
  },
  {
    number = 4523,
    description = "Subquery - derived table with window function",
    database = "vim_dadbod_test",
    query = [[SELECT sub.█ FROM (SELECT EmployeeID, Salary, ROW_NUMBER() OVER (ORDER BY Salary DESC) AS Rank FROM Employees) sub]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "Salary",
          "Rank",
        },
      },
    },
  },
  {
    number = 4524,
    description = "Subquery - subquery in UNION",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (
  SELECT EmployeeID AS ID, FirstName AS Name FROM Employees
  UNION ALL
  SELECT Id AS ID, Name AS Name FROM Customers
) combined WHERE █]],
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
    number = 4525,
    description = "Subquery - three-level nesting columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (
  SELECT * FROM (
    SELECT EmployeeID, FirstName FROM Employees
  ) inner1
) outer1 WHERE █]],
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
    number = 4526,
    description = "Subquery - subquery in INSERT SELECT",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Archive_Employees
SELECT * FROM (SELECT █ FROM Employees WHERE IsActive = 0) sub]],
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
    number = 4527,
    description = "Subquery - subquery in UPDATE FROM",
    database = "vim_dadbod_test",
    query = [[UPDATE e SET e.Salary = sub.NewSalary
FROM Employees e
JOIN (SELECT EmployeeID, Salary * 1.1 AS NewSalary FROM Employees WHERE DepartmentID = 1) sub
ON e.EmployeeID = sub.█]],
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
    number = 4528,
    description = "Subquery - lateral/APPLY with outer reference",
    database = "vim_dadbod_test",
    query = [[SELECT d.*, emp.*
FROM Departments d
CROSS APPLY (SELECT █ FROM Employees e WHERE e.DepartmentID = d.DepartmentID ORDER BY e.Salary DESC) emp]],
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
    number = 4529,
    description = "Subquery - subquery with CASE expression columns",
    database = "vim_dadbod_test",
    query = [[SELECT sub.█ FROM (
  SELECT EmployeeID,
    CASE WHEN Salary > 100000 THEN 'High' ELSE 'Normal' END AS SalaryLevel
  FROM Employees
) sub]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "SalaryLevel",
        },
      },
    },
  },
  {
    number = 4530,
    description = "Subquery - subquery with scalar subquery column",
    database = "vim_dadbod_test",
    query = [[SELECT sub.█ FROM (
  SELECT EmployeeID,
    (SELECT DepartmentName FROM Departments d WHERE d.DepartmentID = e.DepartmentID) AS DeptName
  FROM Employees e
) sub]],
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

  -- ============================================================================
  -- 4531-4540: Subquery with various operators
  -- ============================================================================
  {
    number = 4531,
    description = "Subquery - ALL operator subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE Salary > ALL (SELECT █ FROM Employees WHERE DepartmentID = 1)]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "Salary",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4532,
    description = "Subquery - ANY/SOME operator subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE Salary > ANY (SELECT █ FROM Employees WHERE DepartmentID = 1)]],
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
    number = 4533,
    description = "Subquery - NOT IN subquery columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DepartmentID NOT IN (SELECT █ FROM Departments WHERE Budget < 1000)]],
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
    number = 4534,
    description = "Subquery - NOT EXISTS subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Departments d WHERE NOT EXISTS (SELECT 1 FROM Employees e WHERE e.DepartmentID = d.█)]],
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
    number = 4535,
    description = "Subquery - comparison with subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE Salary = (SELECT MAX()█ FROM Employees)]],
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
    number = 4536,
    description = "Subquery - BETWEEN with subqueries",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE Salary BETWEEN (SELECT MIN()█ FROM Employees) AND (SELECT MAX(Salary) FROM Employees)]],
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
    number = 4537,
    description = "Subquery - LIKE with subquery (edge case)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE FirstName LIKE (SELECT █ FROM Employees WHERE EmployeeID = 1)]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4538,
    description = "Subquery - subquery in COALESCE",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID, COALESCE(DepartmentID, (SELECT  FROM█ Departments WHERE DepartmentID = 1)) FROM Employees]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "DepartmentID",
          "ManagerID",
        },
      },
    },
  },
  {
    number = 4539,
    description = "Subquery - subquery in IIF",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID, IIF(Salary > (SELECT AVG()█ FROM Employees), 'Above', 'Below') FROM Employees]],
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
    number = 4540,
    description = "Subquery - multiple subqueries in WHERE",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees
WHERE DepartmentID IN (SELECT DepartmentID FROM Departments WHERE Budget > 100000)
AND DepartmentID IN (SELECT █ FROM Employees WHERE IsActive = 1)]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },

  -- ============================================================================
  -- 4541-4550: Subquery edge cases
  -- ============================================================================
  {
    number = 4541,
    description = "Subquery - empty derived table alias",
    database = "vim_dadbod_test",
    query = [[SELECT █ FROM (SELECT * FROM Employees)]],
    expected = {
      type = "column",
      items = {
        -- Should still work even without alias (though SQL requires it)
        includes_any = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4542,
    description = "Subquery - multiline subquery formatting",
    database = "vim_dadbod_test",
    query = [[SELECT sub.█
FROM (
  SELECT
    EmployeeID,
    FirstName,
    LastName
  FROM Employees
) sub]],
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
    number = 4543,
    description = "Subquery - deeply nested (4 levels)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (
  SELECT * FROM (
    SELECT * FROM (
      SELECT EmployeeID FROM Employees
    ) l1
  ) l2
) l3 WHERE █]],
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
    number = 4544,
    description = "Subquery - subquery with same alias as outer table",
    database = "vim_dadbod_test",
    query = [[SELECT e.█ FROM Employees e WHERE DepartmentID IN (SELECT DepartmentID FROM Departments e)]],
    expected = {
      type = "column",
      items = {
        -- Outer 'e' should refer to Employees
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4545,
    description = "Subquery - correlated with multiple outer references",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.Salary > (SELECT AVG(Salary) FROM Employees WHERE DepartmentID = d.█ AND DepartmentID = e.DepartmentID)]],
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
    number = 4546,
    description = "Subquery - subquery in PIVOT",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (SELECT █ FROM Employees) src
PIVOT (COUNT(EmployeeID) FOR DepartmentID IN ([1], [2], [3])) pvt]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4547,
    description = "Subquery - subquery in UNPIVOT source",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (SELECT █ FROM Orders) src
UNPIVOT (Value FOR Quarter IN (OrderId, CustomerId, Total)) unpvt]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "OrderId",
          "CustomerId",
          "Total",
        },
      },
    },
  },
  {
    number = 4548,
    description = "Subquery - VALUES as derived table",
    database = "vim_dadbod_test",
    query = [[SELECT v.█ FROM (VALUES (1, 'A'), (2, 'B'), (3, 'C')) AS v(ID, Letter)]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
          "Letter",
        },
      },
    },
  },
  {
    number = 4549,
    description = "Subquery - TOP in subquery",
    database = "vim_dadbod_test",
    query = [[SELECT sub.█ FROM (SELECT TOP 10  FROM Employees ORDER BY Salary DESC) sub]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "Salary",
        },
      },
    },
  },
  {
    number = 4550,
    description = "Subquery - OFFSET FETCH in subquery",
    database = "vim_dadbod_test",
    query = [[SELECT sub.█ FROM (SELECT EmployeeID, FirstName FROM Employees ORDER BY EmployeeID OFFSET 10 ROWS FETCH NEXT 5 ROWS ONLY) sub]],
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
}
