-- Integration Tests: Edge Cases and Special Scenarios
-- Test IDs: 4721-4800
-- Tests edge cases, special characters, complex queries, and error scenarios

return {
  -- ============================================================================
  -- 4721-4740: Special characters and identifiers
  -- ============================================================================
  {
    number = 4721,
    description = "Edge case - table with spaces in name",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [Table With Spaces] █]],
    expected = {
      type = "valid",
      valid = true,
    },
  },
  {
    number = 4722,
    description = "Edge case - column with spaces in SELECT",
    database = "vim_dadbod_test",
    query = [[SELECT [First Name]█ FROM Employees]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "First Name",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4723,
    description = "Edge case - reserved word as column name",
    database = "vim_dadbod_test",
    query = [[SELECT [select], [from], [where]█ FROM ReservedTable]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "select",
          "from",
          "where",
        },
      },
    },
  },
  {
    number = 4724,
    description = "Edge case - Unicode table name",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [テーブル] █]],
    expected = {
      type = "valid",
      valid = true,
    },
  },
  {
    number = 4725,
    description = "Edge case - Unicode column names",
    database = "vim_dadbod_test",
    query = [[SELECT [名前], [住所] F█ROM JapaneseTable]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "名前",
          "住所",
        },
      },
    },
  },
  {
    number = 4726,
    description = "Edge case - table name starting with number",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [123Table]█ ]],
    expected = {
      type = "valid",
      valid = true,
    },
  },
  {
    number = 4727,
    description = "Edge case - column with special characters",
    database = "vim_dadbod_test",
    query = [[SELECT [Column#1], [Column@2]█ FROM SpecialChars]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "Column#1",
          "Column@2",
        },
      },
    },
  },
  {
    number = 4728,
    description = "Edge case - double quotes identifier (QUOTED_IDENTIFIER)",
    database = "vim_dadbod_test",
    query = [[SELECT "FirstName"█ FROM Employees]],
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4729,
    description = "Edge case - mixed bracket and dot notation",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [dbo].[Employees]█ ]],
    expected = {
      type = "valid",
      valid = true,
    },
  },
  {
    number = 4730,
    description = "Edge case - empty brackets",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [].█]],
    expected = {
      -- Invalid identifier
      type = "error",
    },
  },
  {
    number = 4731,
    description = "Edge case - very long identifier (128 chars)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM VeryLongTableNameThatIsExactlyOneHundredAndTwentyEightCharactersLongWhichIsTheMaximumAllowedB█yS]],
    expected = {
      type = "table",
      items = {
        includes_any = {
          "VeryLongTableName",
        },
      },
    },
  },
  {
    number = 4732,
    description = "Edge case - identifier with embedded brackets",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [Table[With]Brackets]█ ]],
    expected = {
      -- Needs to escape brackets with double brackets
      type = "error",
    },
  },
  {
    number = 4733,
    description = "Edge case - escaped brackets",
    database = "vim_dadbod_test",
    query = [=[SELECT * FROM [Table] ]With█]]Brackets] ]=],
    expected = {
      type = "valid",
      valid = true,
    },
  },
  {
    number = 4734,
    description = "Edge case - alias same as table name",
    database = "vim_dadbod_test",
    query = [[SELECT Employees.█ FROM Employees Employees]],
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
    number = 4735,
    description = "Edge case - alias shadows table name",
    database = "vim_dadbod_test",
    query = [[SELECT Departments.█ FROM Employees Departments]],
    expected = {
      type = "column",
      items = {
        -- Alias 'Departments' refers to Employees table
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
    number = 4736,
    description = "Edge case - case sensitivity test",
    database = "vim_dadbod_test",
    query = [[SELECT EMPLOYEEID, employeeid, EmployeeID FRO█M Employees]],
    expected = {
      -- SQL Server is case-insensitive by default
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4737,
    description = "Edge case - leading/trailing whitespace",
    database = "vim_dadbod_test",
    query = [[SELECT   FirstName   ,   LastName  █ FROM   Employees]],
    expected = {
      type = "valid",
      valid = true,
    },
  },
  {
    number = 4738,
    description = "Edge case - tab character as whitespace",
    database = "vim_dadbod_test",
    query = "SELECT\tFirstName\tFROM█\tEmployees",
    expected = {
      type = "valid",
      valid = true,
    },
  },
  {
    number = 4739,
    description = "Edge case - newline in middle of identifier (error)",
    database = "vim_dadbod_test",
    query = [[SELECT First█
Name FROM Employees]],
    expected = {
      type = "error",
    },
  },
  {
    number = 4740,
    description = "Edge case - semicolon separator",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees; SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },

  -- ============================================================================
  -- 4741-4760: Complex query structures
  -- ============================================================================
  {
    number = 4741,
    description = "Complex - deeply nested parentheses",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE (((( █= 1))))]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "IsActive",
        },
      },
    },
  },
  {
    number = 4742,
    description = "Complex - UNION with different column counts (error)",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID, FirstName FROM Employees UNION SELECT DepartmentID FROM Department█s]],
    expected = {
      type = "error",
    },
  },
  {
    number = 4743,
    description = "Complex - EXCEPT query columns",
    database = "vim_dadbod_test",
    query = [[SELECT █ FROM Employees EXCEPT SELECT EmployeeID FROM Employees WHERE IsActive = 0]],
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
    number = 4744,
    description = "Complex - INTERSECT query",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID FROM Employees INTERSECT SELECT  FROM De█partments]],
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
    number = 4745,
    description = "Complex - multiple CTEs with UNION",
    database = "vim_dadbod_test",
    query = [[WITH
  CTE1 AS (SELECT EmployeeID FROM Employees),
  CTE2 AS (SELECT EmployeeID FROM Employees WHERE DepartmentID = 1)
SELECT * FROM CTE1
UNION ALL
SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "CTE2",
          "CTE1",
        },
      },
    },
  },
  {
    number = 4746,
    description = "Complex - correlated subquery with multiple outer refs",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
WHERE EXISTS (
  SELECT 1 FROM Departments d
  WHERE d.DepartmentID = e.DepartmentID
  AND d.ManagerID = e.█
)]],
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
    number = 4747,
    description = "Complex - window function with PARTITION BY",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID, ROW_NUMBER() OVER (PARTITION BY █ ORDER BY Salary DESC) FROM Employees]],
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
    number = 4748,
    description = "Complex - window function with ROWS BETWEEN",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID, SUM(Salary) OVER (ORDER BY █ ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) FROM Employees]],
    expected = {
      type = "column",
      items = {
        includes = {
          "HireDate",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4749,
    description = "Complex - PIVOT query column",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (SELECT DepartmentID, █ FROM Employees) src PIVOT (COUNT(EmployeeID) FOR DepartmentID IN ([1],[2])) pvt]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "DepartmentID",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4750,
    description = "Complex - FOR XML PATH columns",
    database = "vim_dadbod_test",
    query = [[SELECT █ FROM Employees FOR XML PATH('Employee'), ROOT('Employees')]],
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
    number = 4751,
    description = "Complex - FOR JSON PATH columns",
    database = "vim_dadbod_test",
    query = [[SELECT █ FROM Employees FOR JSON PATH]],
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
    number = 4752,
    description = "Complex - OPENJSON columns",
    database = "vim_dadbod_test",
    query = [[SELECT █ FROM OPENJSON(@json) WITH (ID INT, Name VARCHAR(100))]],
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
    number = 4753,
    description = "Complex - OPENXML columns",
    database = "vim_dadbod_test",
    query = [[SELECT █ FROM OPENXML(@hdoc, '/root/emp') WITH (ID INT, Name VARCHAR(100))]],
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
    number = 4754,
    description = "Complex - CROSS APPLY with VALUES",
    database = "vim_dadbod_test",
    query = [[SELECT e.EmployeeID, v. FR█OM Employees e CROSS APPLY (VALUES (1, 'A'), (2, 'B')) v(Num, Letter)]],
    expected = {
      type = "column",
      items = {
        includes = {
          "Num",
          "Letter",
        },
      },
    },
  },
  {
    number = 4755,
    description = "Complex - recursive CTE with depth limit",
    database = "vim_dadbod_test",
    query = [[WITH RecCTE AS (
  SELECT EmployeeID, DepartmentID, 0 AS Depth FROM Employees WHERE DepartmentID IS NULL
  UNION ALL
  SELECT e.EmployeeID, e.DepartmentID, r.Depth + 1 FROM Employees e JOIN RecCTE r ON e.DepartmentID = r.EmployeeID WHERE r.Depth < 10
)
SELECT █ FROM RecCTE]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
          "Depth",
        },
      },
    },
  },
  {
    number = 4756,
    description = "Complex - temporal table FOR SYSTEM_TIME",
    database = "vim_dadbod_test",
    query = [[SELECT █ FROM Employees FOR SYSTEM_TIME AS OF '2024-01-01']],
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
    number = 4757,
    description = "Complex - TABLESAMPLE clause",
    database = "vim_dadbod_test",
    query = [[SELECT █ FROM Employees TABLESAMPLE (10 PERCENT)]],
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
    number = 4758,
    description = "Complex - table hint NOLOCK",
    database = "vim_dadbod_test",
    query = [[SELECT █ FROM Employees WITH (NOLOCK)]],
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
    number = 4759,
    description = "Complex - query hint OPTION",
    database = "vim_dadbod_test",
    query = [[SELECT █ FROM Employees OPTION (MAXDOP 1)]],
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
    number = 4760,
    description = "Complex - READPAST hint",
    database = "vim_dadbod_test",
    query = [[SELECT TOP 10 █ FROM Employees WITH (READPAST)]],
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
  -- 4761-4780: Error handling and invalid queries
  -- ============================================================================
  {
    number = 4761,
    description = "Error - incomplete SELECT",
    database = "vim_dadbod_test",
    query = [[SELECT █]],
    expected = {
      type = "column",
      -- Should still offer columns from context if available
      items = {
        count = 0,
      },
    },
  },
  {
    number = 4762,
    description = "Error - missing FROM clause",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID█]],
    expected = {
      -- Valid SQL without FROM (scalar select)
      type = "valid",
      valid = true,
    },
  },
  {
    number = 4763,
    description = "Error - invalid table name",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM NonExistentTable WHERE █]],
    expected = {
      type = "column",
      items = {
        count = 0,
      },
    },
  },
  {
    number = 4764,
    description = "Error - invalid column in SELECT",
    database = "vim_dadbod_test",
    query = [[SELECT NonExistentColumn, █ FROM Employees]],
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
    number = 4765,
    description = "Error - syntax error before cursor",
    database = "vim_dadbod_test",
    query = [[SELECT * FORM Employees WHERE █]],
    expected = {
      -- Typo 'FORM' instead of 'FROM'
      type = "error",
    },
  },
  {
    number = 4766,
    description = "Error - unclosed string literal",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE FirstName = 'John█]],
    expected = {
      type = "error",
    },
  },
  {
    number = 4767,
    description = "Error - unclosed bracket",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [Employees WHERE █]],
    expected = {
      type = "error",
    },
  },
  {
    number = 4768,
    description = "Error - mismatched parentheses",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE (DepartmentID = 1█]],
    expected = {
      -- Still in valid expression context
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4769,
    description = "Error - double FROM keyword",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM FROM █Employees]],
    expected = {
      type = "error",
    },
  },
  {
    number = 4770,
    description = "Error - missing comma between columns",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID FirstName █FROM Employees]],
    expected = {
      -- 'FirstName' interpreted as alias for EmployeeID
      type = "valid",
      valid = true,
    },
  },
  {
    number = 4771,
    description = "Error - invalid alias position",
    database = "vim_dadbod_test",
    query = [[SELECT AS █alias FROM Employees]],
    expected = {
      type = "error",
    },
  },
  {
    number = 4772,
    description = "Error - GROUP BY without aggregate",
    database = "vim_dadbod_test",
    query = [[SELECT FirstName, █ FROM Employees GROUP BY DepartmentID]],
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
    number = 4773,
    description = "Error - ORDER BY with invalid column",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID FROM Employees ORDER BY █]],
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
    number = 4774,
    description = "Error - HAVING without GROUP BY",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees HAVING █ > 0]],
    expected = {
      -- HAVING without GROUP BY is error, but still suggest columns
      type = "column",
      items = {
        includes_any = {
          "COUNT",
          "SUM",
        },
      },
    },
  },
  {
    number = 4775,
    description = "Error - subquery missing alias",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (SELECT * FROM Employees)█]],
    expected = {
      type = "error",
    },
  },
  {
    number = 4776,
    description = "Error - INSERT without VALUES or SELECT",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (EmployeeID)█]],
    expected = {
      type = "error",
    },
  },
  {
    number = 4777,
    description = "Error - UPDATE without SET",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees WHERE EmployeeID = 1█]],
    expected = {
      type = "error",
    },
  },
  {
    number = 4778,
    description = "Error - DELETE with invalid syntax",
    database = "vim_dadbod_test",
    query = [[DELETE Employees SET█]],
    expected = {
      type = "error",
    },
  },
  {
    number = 4779,
    description = "Error - CTE without SELECT",
    database = "vim_dadbod_test",
    query = [[WITH CTE AS (SELECT * FROM Employees)█]],
    expected = {
      type = "error",
    },
  },
  {
    number = 4780,
    description = "Error - recursive CTE without UNION ALL",
    database = "vim_dadbod_test",
    query = [[WITH RecCTE AS (SELECT * FROM Employees UNION SELECT * FROM RecCTE) SELECT * FROM RecCT█E]],
    expected = {
      -- UNION instead of UNION ALL in recursive CTE
      type = "warning",
      items = {
        includes_any = {
          "recursive_union",
        },
      },
    },
  },

  -- ============================================================================
  -- 4781-4800: Performance and stress tests
  -- ============================================================================
  {
    number = 4781,
    description = "Stress - very long query (1000+ chars)",
    database = "vim_dadbod_test",
    query = [[SELECT e.EmployeeID, e.FirstName, e.LastName, e.Email, e.HireDate, e.Salary, e.DepartmentID, e.IsActive, d.DepartmentID, d.DepartmentName, d.Budget, d.ManagerID, p.ProjectID, p.ProjectName, p.StartDate, p.EndDate, p.Budget, p.Status FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON d.DepartmentID █= p.ProjectID WHERE ]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "DepartmentID",
          "ProjectID",
        },
      },
    },
  },
  {
    number = 4782,
    description = "Stress - many columns in SELECT",
    database = "vim_dadbod_test",
    query = [[SELECT Col1, Col2, Col3, Col4, Col5, Col6, Col7, Col8, Col9, Col10, Col11, Col12, Col13, Col14, Col15, Col16, Col17, Col18, Col19, Col20,█  FROM WideTable]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "Col21",
          "Col22",
        },
      },
    },
  },
  {
    number = 4783,
    description = "Stress - many JOINs (10 tables)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM T1 JOIN T2 ON T1.ID = T2.ID JOIN T3 ON T2.ID = T3.ID JOIN T4 ON T3.ID = T4.ID JOIN T5 ON T4.ID = T5.ID JOIN T6 ON T5.ID = T6.ID JOIN T7 ON T6.ID = T7.ID JOIN T8 ON T7.ID = T8.ID JOIN T9 ON T8.ID = T9.ID JOIN T10 ON T9.ID = T10█.]],
    expected = {
      type = "column",
      items = {
        includes = {
          "ID",
        },
      },
    },
  },
  {
    number = 4784,
    description = "Stress - deeply nested subqueries (5 levels)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT█  FROM Employees) l1) l2) l3) l4]],
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
    number = 4785,
    description = "Stress - many CTEs (5+)",
    database = "vim_dadbod_test",
    query = [[WITH CTE1 AS (SELECT 1 AS A), CTE2 AS (SELECT 2 AS B), CTE3 AS (SELECT 3 AS C), CTE4 AS (SELECT 4 AS D), CTE5 AS (SELECT 5 AS E) SELECT * F█ROM ]],
    expected = {
      type = "table",
      items = {
        includes = {
          "CTE1",
          "CTE2",
          "CTE3",
          "CTE4",
          "CTE5",
        },
      },
    },
  },
  {
    number = 4786,
    description = "Stress - complex WHERE with many conditions",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE (A = 1 OR B = 2) AND (C = 3 OR D = 4) AND (E = 5 OR F = 6) AND (G = 7 OR H = 8) █AND ]],
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
    number = 4787,
    description = "Stress - multiline query (10+ lines)",
    database = "vim_dadbod_test",
    query = [[SELECT
  e.EmployeeID,
  e.FirstName,
  e.LastName,
  e.Salary,
  d.DepartmentName,
  p.ProjectName
FROM Employees e
INNER JOIN Departments d
  ON e.DepartmentID = d.DepartmentID
LEFT JOIN Projects p
  ON e.EmployeeID = p.ProjectID
WHERE
  e.IsActive = 1
  AND d.Budget > 100000
  AND █]],
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "DepartmentID",
          "ProjectID",
        },
      },
    },
  },
  {
    number = 4788,
    description = "Stress - batch with many statements",
    database = "vim_dadbod_test",
    query = [[SELECT 1; SELECT 2; SELECT 3; SELECT 4; SELECT 5; SELECT  FROM █Employees]],
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
    number = 4789,
    description = "Stress - GO batch separator",
    database = "vim_dadbod_test",
    query = [[SELECT 1
GO
SELECT █ FROM Employees]],
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
    number = 4790,
    description = "Stress - mixed DML in batch",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Log VALUES (1); UPDATE Stats SET Count = Count + 1; SELECT  FRO█M Employees]],
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
    number = 4791,
    description = "Context - cursor at very start of query",
    database = "vim_dadbod_test",
    query = [[█ FROM Employees]],
    expected = {
      type = "keyword",
      items = {
        includes_any = {
          "SELECT",
          "INSERT",
          "UPDATE",
          "DELETE",
        },
      },
    },
  },
  {
    number = 4792,
    description = "Context - cursor at very end of query",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE EmployeeID = 1 █]],
    expected = {
      type = "keyword",
      items = {
        includes_any = {
          "AND",
          "OR",
          "ORDER BY",
        },
      },
    },
  },
  {
    number = 4793,
    description = "Context - empty query",
    database = "vim_dadbod_test",
    query = [[█]],
    expected = {
      type = "keyword",
      items = {
        includes = {
          "SELECT",
          "INSERT",
          "UPDATE",
          "DELETE",
          "WITH",
        },
      },
    },
  },
  {
    number = 4794,
    description = "Context - whitespace only",
    database = "vim_dadbod_test",
    query = [[   █]],
    expected = {
      type = "keyword",
      items = {
        includes = {
          "SELECT",
        },
      },
    },
  },
  {
    number = 4795,
    description = "Context - comment only",
    database = "vim_dadbod_test",
    query = [[-- This is a comment
█]],
    expected = {
      type = "keyword",
      items = {
        includes = {
          "SELECT",
        },
      },
    },
  },
  {
    number = 4796,
    description = "Context - block comment",
    database = "vim_dadbod_test",
    query = [[/* Block comment */ SELECT █ FROM Employees]],
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
    number = 4797,
    description = "Context - cursor inside comment",
    database = "vim_dadbod_test",
    query = [[SELECT * /* comment █ */ FROM Employees]],
    expected = {
      type = "none",
    },
  },
  {
    number = 4798,
    description = "Context - cursor inside string literal",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE FirstName = 'Jo█']],
    expected = {
      type = "none",
    },
  },
  {
    number = 4799,
    description = "Context - after line comment",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees -- comment
WHERE █]],
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
    number = 4800,
    description = "Context - mixed comments and code",
    database = "vim_dadbod_test",
    query = [[SELECT /* col */  /* more */ FROM /* table */ Employees WHERE /* condition */█  = 1]],
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "IsActive",
        },
      },
    },
  },
}
