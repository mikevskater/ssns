-- Integration Tests: JOIN Suggestions - FK-Based Suggestions
-- Test IDs: 4301-4350
-- Tests FK-based table suggestions in JOIN context

return {
  -- ============================================================================
  -- 4301-4315: Direct FK suggestions (1-hop)
  -- ============================================================================
  {
    number = 4301,
    description = "FK suggestion - Employees -> Departments (1 hop)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN ]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",  -- FK: Employees.DepartmentID -> Departments.DepartmentID
        },
      },
    },
  },
  {
    number = 4302,
    description = "FK suggestion - Orders -> Customers (1 hop)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN ]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Customers",  -- FK: Orders.CustomerID -> Customers.CustomerID
        },
      },
    },
  },
  {
    number = 4303,
    description = "FK suggestion - Orders -> Employees (1 hop)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN ]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Employees",  -- FK: Orders.EmployeeID -> Employees.EmployeeID
        },
      },
    },
  },
  {
    number = 4304,
    description = "FK suggestion - Customers -> Countries (1 hop)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Customers c JOIN ]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Countries",  -- FK: Customers.CountryID -> Countries.CountryID
        },
      },
    },
  },
  {
    number = 4305,
    description = "FK suggestion - Countries -> Regions (1 hop)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Countries c JOIN ]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Regions",  -- FK: Countries.RegionID -> Regions.RegionID
        },
      },
    },
  },
  {
    number = 4306,
    description = "FK suggestion - self-referential (Employees.ManagerID -> Employees)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN ]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Employees",  -- FK: Employees.ManagerID -> Employees.EmployeeID (self-ref)
        },
      },
    },
  },
  {
    number = 4307,
    description = "FK suggestion - with ON clause auto-generated",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN ]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",
        },
        has_on_clause = true,  -- insertText should contain " ON e.DepartmentID = d.DepartmentID"
      },
    },
  },
  {
    number = 4308,
    description = "FK suggestion - LEFT JOIN preserves FK awareness",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e LEFT JOIN ]],
    cursor = { line = 0, col = 37 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4309,
    description = "FK suggestion - INNER JOIN preserves FK awareness",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e INNER JOIN ]],
    cursor = { line = 0, col = 38 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4310,
    description = "FK suggestion - RIGHT JOIN preserves FK awareness",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e RIGHT JOIN ]],
    cursor = { line = 0, col = 38 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4311,
    description = "FK suggestion - multiple FKs from same table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN ]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "join_suggestion",
      items = {
        -- Orders has FKs to both Customers and Employees
        includes = {
          "Customers",
          "Employees",
        },
      },
    },
  },
  {
    number = 4312,
    description = "FK suggestion - schema-qualified source table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Employees e JOIN ]],
    cursor = { line = 0, col = 35 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4313,
    description = "FK suggestion - multiline query",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
JOIN ]],
    cursor = { line = 2, col = 5 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4314,
    description = "FK suggestion - FK priority over non-FK tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN ]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "join_suggestion",
      items = {
        -- Departments should be higher priority due to FK
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4315,
    description = "FK suggestion - no FK still shows all tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Regions r JOIN ]],
    cursor = { line = 0, col = 29 },
    expected = {
      type = "table",
      items = {
        -- Regions has no outgoing FKs, so all tables should be available
        includes = {
          "Employees",
          "Departments",
          "Countries",
        },
      },
    },
  },

  -- ============================================================================
  -- 4316-4330: Multi-hop FK chains (2 hops)
  -- ============================================================================
  {
    number = 4316,
    description = "FK chain - Orders -> Customers (existing) + Countries (2 hop)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Customers c ON o.CustomerID = c.CustomerID JOIN ]],
    cursor = { line = 0, col = 76 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Countries",  -- 1 hop from Customers
          "Employees",  -- 1 hop from Orders
        },
      },
    },
  },
  {
    number = 4317,
    description = "FK chain - Customers -> Countries (existing) + Regions (2 hop)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Customers c JOIN Countries co ON c.CountryID = co.CountryID JOIN ]],
    cursor = { line = 0, col = 78 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Regions",  -- 1 hop from Countries
        },
      },
    },
  },
  {
    number = 4318,
    description = "FK chain - three-table join, third table FK suggestions",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN Countries co ON c.CountryID = co.CountryID
JOIN ]],
    cursor = { line = 4, col = 5 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Regions",    -- 1 hop from Countries
          "Employees",  -- 1 hop from Orders
        },
      },
    },
  },
  {
    number = 4319,
    description = "FK chain - full chain Orders -> Customers -> Countries -> Regions",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN Countries co ON c.CountryID = co.CountryID
JOIN Regions r ON co.RegionID = r.RegionID
JOIN ]],
    cursor = { line = 4, col = 5 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",  -- From Orders FK
          "Departments",  -- From Employees FK (if in chain)
        },
      },
    },
  },
  {
    number = 4320,
    description = "FK chain - Employees -> Departments (existing) + next hops",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN ]],
    cursor = { line = 0, col = 83 },
    expected = {
      type = "join_suggestion",
      items = {
        includes_any = {
          "Projects",  -- If Projects has FK to Departments
          "Locations",  -- If Departments has FK to Locations
        },
      },
    },
  },
  {
    number = 4321,
    description = "FK chain - suggests tables reachable in 2 hops",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN ]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Customers",   -- 1 hop
          "Employees",   -- 1 hop
          "Countries",   -- 2 hops via Customers
          "Departments", -- 2 hops via Employees
        },
      },
    },
  },
  {
    number = 4322,
    description = "FK chain - 2-hop suggestions show via indicator",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN ]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "join_suggestion",
      items = {
        -- Countries should have "via Customers" in label or detail
        includes = {
          "Countries",
        },
      },
    },
  },
  {
    number = 4323,
    description = "FK chain - skip already joined tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Customers c ON o.CustomerID = c.CustomerID JOIN ]],
    cursor = { line = 0, col = 76 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Countries",  -- Available from Customers
        },
        excludes = {
          "Customers",  -- Already in query, should not re-suggest
        },
      },
    },
  },
  {
    number = 4324,
    description = "FK chain - multiline complex join chain",
    database = "vim_dadbod_test",
    query = [[SELECT
  o.OrderID,
  c.CustomerName,
  co.CountryName
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
LEFT JOIN Countries co ON c.CountryID = co.CountryID
JOIN ]],
    cursor = { line = 7, col = 5 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Regions",
          "Employees",
        },
      },
    },
  },
  {
    number = 4325,
    description = "FK chain - chain from middle table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Customers c JOIN ]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Countries",  -- 1 hop
          "Orders",     -- Reverse FK (Orders.CustomerID -> Customers)
          "Regions",    -- 2 hops via Countries
        },
      },
    },
  },
  {
    number = 4326,
    description = "FK chain - bidirectional FK navigation",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Departments d JOIN ]],
    cursor = { line = 0, col = 33 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Employees",  -- Reverse FK: Employees.DepartmentID -> Departments
        },
      },
    },
  },
  {
    number = 4327,
    description = "FK chain - cycle prevention (don't suggest circular)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e1 JOIN Employees e2 ON e1.ManagerID = e2.EmployeeID JOIN ]],
    cursor = { line = 0, col = 80 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",
        },
        -- Employees already in query twice, but more Employees JOINs might still be valid for self-ref
      },
    },
  },
  {
    number = 4328,
    description = "FK chain - with different JOIN types in chain",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Orders o
INNER JOIN Customers c ON o.CustomerID = c.CustomerID
LEFT JOIN Countries co ON c.CountryID = co.CountryID
RIGHT JOIN ]],
    cursor = { line = 4, col = 11 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Regions",
        },
      },
    },
  },
  {
    number = 4329,
    description = "FK chain - schema-qualified tables in chain",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Orders o JOIN dbo.Customers c ON o.CustomerID = c.CustomerID JOIN ]],
    cursor = { line = 0, col = 81 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Countries",
        },
      },
    },
  },
  {
    number = 4330,
    description = "FK chain - prefix filter in multi-hop",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Customers c ON o.CustomerID = c.CustomerID JOIN Coun]],
    cursor = { line = 0, col = 80 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Countries",
        },
      },
    },
  },

  -- ============================================================================
  -- 4331-4350: Alias generation and complex scenarios
  -- ============================================================================
  {
    number = 4331,
    description = "Alias generation - single letter for short table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN ]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",  -- Should suggest with alias like 'd'
        },
      },
    },
  },
  {
    number = 4332,
    description = "Alias generation - avoids conflict with existing 'd'",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e, Dummy d JOIN ]],
    cursor = { line = 0, col = 40 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",  -- Should use 'de' or 'dep' since 'd' is taken
        },
      },
    },
  },
  {
    number = 4333,
    description = "Alias generation - multiple conflicting aliases",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e, Data d, Details de JOIN ]],
    cursor = { line = 0, col = 51 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",  -- Should use 'dep' or full name since 'd' and 'de' taken
        },
      },
    },
  },
  {
    number = 4334,
    description = "Alias generation - case insensitive conflict check",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees E JOIN ]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",  -- 'e' is taken (case insensitive), suggest 'd' for Departments
        },
      },
    },
  },
  {
    number = 4335,
    description = "ON clause generation - single column FK",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN ]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",
        },
        has_on_clause = true,  -- Should contain "ON e.DepartmentID = d.DepartmentID"
      },
    },
  },
  {
    number = 4336,
    description = "ON clause generation - uses correct source alias",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees emp JOIN ]],
    cursor = { line = 0, col = 34 },
    expected = {
      type = "join_suggestion",
      items = {
        includes = {
          "Departments",
        },
        has_on_clause = true,  -- Should use 'emp' in ON clause, not 'e'
      },
    },
  },
  {
    number = 4337,
    description = "Complex scenario - mixed aliases and table names",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees, Departments d JOIN ]],
    cursor = { line = 0, col = 44 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Projects",
          "Orders",
        },
      },
    },
  },
  {
    number = 4338,
    description = "Complex scenario - subquery in FROM",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM (SELECT * FROM Employees WHERE DeptID = 1) e JOIN ]],
    cursor = { line = 0, col = 64 },
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
    number = 4339,
    description = "Complex scenario - CTE as source",
    database = "vim_dadbod_test",
    query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT * FROM EmpCTE e JOIN ]],
    cursor = { line = 1, col = 28 },
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
    number = 4340,
    description = "Complex scenario - cross-database JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN TEST.dbo.]],
    cursor = { line = 0, col = 40 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "TestTable",
        },
      },
    },
  },
  {
    number = 4341,
    description = "FK suggestion - preserves schema in insertText",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM hr.Benefits b JOIN ]],
    cursor = { line = 0, col = 33 },
    expected = {
      type = "join_suggestion",
      items = {
        includes_any = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4342,
    description = "FK suggestion - view with underlying FK",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM vw_ActiveEmployees v JOIN ]],
    cursor = { line = 0, col = 40 },
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
    number = 4343,
    description = "CROSS JOIN - no ON clause needed",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e CROSS JOIN ]],
    cursor = { line = 0, col = 38 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
        -- CROSS JOIN shouldn't auto-generate ON clause
      },
    },
  },
  {
    number = 4344,
    description = "JOIN after CROSS JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e CROSS JOIN Departments d JOIN ]],
    cursor = { line = 0, col = 55 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Projects",
        },
      },
    },
  },
  {
    number = 4345,
    description = "Multiple FKs to same table - disambiguation",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Projects p JOIN ]],
    cursor = { line = 0, col = 30 },
    expected = {
      type = "join_suggestion",
      items = {
        -- If Projects has both LeadID and ManagerID -> Employees
        includes_any = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4346,
    description = "Compound FK - multiple columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM OrderDetails od JOIN ]],
    cursor = { line = 0, col = 35 },
    expected = {
      type = "join_suggestion",
      items = {
        includes_any = {
          "Orders",
          "Products",
        },
      },
    },
  },
  {
    number = 4347,
    description = "FK with different column names",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN ]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "join_suggestion",
      items = {
        -- FK: Employees.DepartmentID -> Departments.DepartmentID (same name)
        -- FK: Employees.ManagerID -> Employees.EmployeeID (different name)
        includes = {
          "Departments",
          "Employees",
        },
      },
    },
  },
  {
    number = 4348,
    description = "Documentation shows FK path",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN ]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "join_suggestion",
      items = {
        -- Documentation should show FK info
        includes = {
          "Customers",
        },
      },
    },
  },
  {
    number = 4349,
    description = "Priority - FK tables before non-FK tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN ]],
    cursor = { line = 0, col = 32 },
    expected = {
      type = "join_suggestion",
      items = {
        -- Departments (FK) should sort before Customers (no direct FK)
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4350,
    description = "Priority - 1-hop before 2-hop",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN ]],
    cursor = { line = 0, col = 28 },
    expected = {
      type = "join_suggestion",
      items = {
        -- Customers (1 hop) should sort before Countries (2 hops via Customers)
        includes = {
          "Customers",
          "Countries",
        },
      },
    },
  },
}
