-- Test file: joins_provider.lua
-- IDs: 3201-3300
-- Tests: JoinsProvider completion for JOIN suggestions with FK-based ON clauses
--
-- Test categories:
-- - 3201-3230: Direct FK suggestions (1-hop)
-- - 3231-3260: Multi-hop FK chains (2+ hops)
-- - 3261-3280: Alias generation
-- - 3281-3295: Fallback tables (no FK)
-- - 3296-3300: Edge cases

return {
  -- ========================================
  -- Direct FK Suggestions (3201-3230)
  -- ========================================

  {
    id = 3201,
    type = "provider",
    provider = "joins",
    name = "Basic FK suggestion - Employees to Departments",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Departments" },
      },
      insert_text_contains = "ON e.DepartmentID = ",
    },
  },

  {
    id = 3202,
    type = "provider",
    provider = "joins",
    name = "FK with auto-generated ON clause",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Departments",
          insertText = "Departments d ON e.DepartmentID = d.DepartmentID",
        },
      },
    },
  },

  {
    id = 3203,
    type = "provider",
    provider = "joins",
    name = "FK alias generation - first letter",
    input = "SELECT * FROM Departments JOIN |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Departments", alias = nil, schema = "dbo" }
      },
      aliases = {},
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees",
          insertText = "Employees e ON Departments.DepartmentID = e.DepartmentID",
        },
      },
    },
  },

  {
    id = 3204,
    type = "provider",
    provider = "joins",
    name = "Multiple FK options from same table",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Customers", "Employees" }, -- Both FK targets
      },
    },
  },

  {
    id = 3205,
    type = "provider",
    provider = "joins",
    name = "Self-referential FK - Employees.ManagerID",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees (Manager)",
          insertText = "Employees m ON e.ManagerID = m.EmployeeID",
          documentation = "Self-join via ManagerID",
        },
      },
    },
  },

  {
    id = 3206,
    type = "provider",
    provider = "joins",
    name = "FK with schema prefix",
    input = "SELECT * FROM dbo.Employees e JOIN |",
    cursor = { line = 1, col = 36 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Departments",
          insertText = "dbo.Departments d ON e.DepartmentID = d.DepartmentID",
        },
      },
    },
  },

  {
    id = 3207,
    type = "provider",
    provider = "joins",
    name = "FK reverse direction - Departments to Employees",
    input = "SELECT * FROM Departments d JOIN |",
    cursor = { line = 1, col = 35 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Departments", alias = "d", schema = "dbo" }
      },
      aliases = { d = "Departments" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees",
          insertText = "Employees e ON d.DepartmentID = e.DepartmentID",
        },
      },
    },
  },

  {
    id = 3208,
    type = "provider",
    provider = "joins",
    name = "Multiple column FK",
    input = "SELECT * FROM OrderDetails od JOIN |",
    cursor = { line = 1, col = 36 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "OrderDetails", alias = "od", schema = "dbo" }
      },
      aliases = { od = "OrderDetails" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Orders",
          insertText = "Orders o ON od.OrderID = o.OrderID AND od.ProductID = o.ProductID",
        },
      },
    },
  },

  {
    id = 3209,
    type = "provider",
    provider = "joins",
    name = "FK priority over non-FK tables",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      priority_order = {
        "Departments", -- FK target (higher priority)
        "Orders",      -- FK target
        "Countries",   -- Non-FK table (lower priority)
      },
    },
  },

  {
    id = 3210,
    type = "provider",
    provider = "joins",
    name = "FK with existing alias conflict - needs d2",
    input = "SELECT * FROM Employees e JOIN Divisions d JOIN |",
    cursor = { line = 1, col = 50 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Divisions", alias = "d", schema = "dbo" }
      },
      aliases = { e = "Employees", d = "Divisions" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Departments",
          insertText = "Departments d2 ON e.DepartmentID = d2.DepartmentID",
        },
      },
    },
  },

  {
    id = 3211,
    type = "provider",
    provider = "joins",
    name = "FK from Orders to Customers",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Customers",
          insertText = "Customers c ON o.CustomerID = c.CustomerID",
        },
      },
    },
  },

  {
    id = 3212,
    type = "provider",
    provider = "joins",
    name = "FK from Customers to Countries",
    input = "SELECT * FROM Customers c JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Customers", alias = "c", schema = "dbo" }
      },
      aliases = { c = "Customers" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          insertText = "Countries co ON c.CountryID = co.CountryID",
        },
      },
    },
  },

  {
    id = 3213,
    type = "provider",
    provider = "joins",
    name = "FK with INNER JOIN keyword",
    input = "SELECT * FROM Employees e INNER JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Departments" },
      },
    },
  },

  {
    id = 3214,
    type = "provider",
    provider = "joins",
    name = "FK with LEFT JOIN keyword",
    input = "SELECT * FROM Employees e LEFT JOIN |",
    cursor = { line = 1, col = 37 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Departments" },
      },
    },
  },

  {
    id = 3215,
    type = "provider",
    provider = "joins",
    name = "FK with RIGHT JOIN keyword",
    input = "SELECT * FROM Employees e RIGHT JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Departments" },
      },
    },
  },

  {
    id = 3216,
    type = "provider",
    provider = "joins",
    name = "FK with FULL OUTER JOIN keyword",
    input = "SELECT * FROM Employees e FULL OUTER JOIN |",
    cursor = { line = 1, col = 44 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Departments" },
      },
    },
  },

  {
    id = 3217,
    type = "provider",
    provider = "joins",
    name = "FK excludes already joined tables",
    input = "SELECT * FROM Employees e JOIN Departments d JOIN |",
    cursor = { line = 1, col = 51 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" }
      },
      aliases = { e = "Employees", d = "Departments" },
    },
    expected = {
      type = "join",
      items = {
        excludes = { "Departments" }, -- Already joined
        includes = { "Orders" },      -- Still available via FK
      },
    },
  },

  {
    id = 3218,
    type = "provider",
    provider = "joins",
    name = "FK with table without alias",
    input = "SELECT * FROM Employees JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = nil, schema = "dbo" }
      },
      aliases = {},
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Departments",
          insertText = "Departments d ON Employees.DepartmentID = d.DepartmentID",
        },
      },
    },
  },

  {
    id = 3219,
    type = "provider",
    provider = "joins",
    name = "FK with composite JOIN from multiple tables",
    input = "SELECT * FROM Employees e JOIN Departments d JOIN |",
    cursor = { line = 1, col = 51 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" }
      },
      aliases = { e = "Employees", d = "Departments" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Orders" }, -- FK from Employees
      },
    },
  },

  {
    id = 3220,
    type = "provider",
    provider = "joins",
    name = "FK with case-insensitive table names",
    input = "SELECT * FROM employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "employees" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Departments" },
      },
    },
  },

  {
    id = 3221,
    type = "provider",
    provider = "joins",
    name = "FK with documentation describing relationship",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Departments",
          documentation_contains = "Foreign key: DepartmentID",
        },
      },
    },
  },

  {
    id = 3222,
    type = "provider",
    provider = "joins",
    name = "FK from Countries to Regions",
    input = "SELECT * FROM Countries c JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Countries", alias = "c", schema = "dbo" }
      },
      aliases = { c = "Countries" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Regions",
          insertText = "Regions r ON c.RegionID = r.RegionID",
        },
      },
    },
  },

  {
    id = 3223,
    type = "provider",
    provider = "joins",
    name = "FK with nullable foreign key",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
      nullable_fk = true,
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Departments",
          documentation_contains = "nullable",
        },
      },
    },
  },

  {
    id = 3224,
    type = "provider",
    provider = "joins",
    name = "FK with multi-line query",
    input = "SELECT *\nFROM Employees e\nJOIN |",
    cursor = { line = 3, col = 6 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Departments" },
      },
    },
  },

  {
    id = 3225,
    type = "provider",
    provider = "joins",
    name = "FK with WHERE clause present",
    input = "SELECT * FROM Employees e JOIN | WHERE e.Active = 1",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Departments" },
      },
    },
  },

  {
    id = 3226,
    type = "provider",
    provider = "joins",
    name = "FK with ORDER BY clause present",
    input = "SELECT * FROM Employees e JOIN | ORDER BY e.LastName",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Departments" },
      },
    },
  },

  {
    id = 3227,
    type = "provider",
    provider = "joins",
    name = "FK with GROUP BY clause present",
    input = "SELECT * FROM Employees e JOIN | GROUP BY e.DepartmentID",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Departments" },
      },
    },
  },

  {
    id = 3228,
    type = "provider",
    provider = "joins",
    name = "FK suggestion includes table kind",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Departments",
          kind = "Table",
        },
      },
    },
  },

  {
    id = 3229,
    type = "provider",
    provider = "joins",
    name = "FK from table with underscore name",
    input = "SELECT * FROM Employee_Roles er JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employee_Roles", alias = "er", schema = "dbo" }
      },
      aliases = { er = "Employee_Roles" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Employees", "Roles" },
      },
    },
  },

  {
    id = 3230,
    type = "provider",
    provider = "joins",
    name = "FK with mixed case schema name",
    input = "SELECT * FROM HumanResources.Employees e JOIN |",
    cursor = { line = 1, col = 47 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "HumanResources" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "HumanResources" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Departments",
          insertText = "HumanResources.Departments d ON e.DepartmentID = d.DepartmentID",
        },
      },
    },
  },

  -- ========================================
  -- Multi-Hop FK Chains (3231-3260)
  -- ========================================

  {
    id = 3231,
    type = "provider",
    provider = "joins",
    name = "2-hop FK chain - Orders -> Customers -> Countries",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Countries" }, -- 2-hop via Customers
      },
    },
  },

  {
    id = 3232,
    type = "provider",
    provider = "joins",
    name = "2-hop FK documentation shows path",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          documentation_contains = "via Customers",
        },
      },
    },
  },

  {
    id = 3233,
    type = "provider",
    provider = "joins",
    name = "2-hop priority lower than 1-hop",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      priority_order = {
        "Customers",  -- 1-hop (higher priority)
        "Employees",  -- 1-hop
        "Countries",  -- 2-hop (lower priority)
      },
    },
  },

  {
    id = 3234,
    type = "provider",
    provider = "joins",
    name = "Multiple 2-hop paths available",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Countries", "Departments" }, -- via Customers and via Employees
      },
    },
  },

  {
    id = 3235,
    type = "provider",
    provider = "joins",
    name = "2-hop with schema qualification",
    input = "SELECT * FROM dbo.Orders o JOIN |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          insertText_contains = "dbo.Countries",
        },
      },
    },
  },

  {
    id = 3236,
    type = "provider",
    provider = "joins",
    name = "2-hop alias generation",
    input = "SELECT * FROM Orders o JOIN Customers c JOIN |",
    cursor = { line = 1, col = 46 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" },
        { name = "Customers", alias = "c", schema = "dbo" }
      },
      aliases = { o = "Orders", c = "Customers" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          insertText = "Countries co ON c.CountryID = co.CountryID",
        },
      },
    },
  },

  {
    id = 3237,
    type = "provider",
    provider = "joins",
    name = "2-hop self-referential chain",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees (Manager's Manager)",
          documentation_contains = "2-hop",
        },
      },
    },
  },

  {
    id = 3238,
    type = "provider",
    provider = "joins",
    name = "2-hop through junction table",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Products" }, -- via OrderDetails
      },
    },
  },

  {
    id = 3239,
    type = "provider",
    provider = "joins",
    name = "2-hop ON clause includes intermediate join",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          insertText_contains = "Customers c ON",
        },
      },
    },
  },

  {
    id = 3240,
    type = "provider",
    provider = "joins",
    name = "2-hop suggests intermediate table first",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      priority_order = {
        "Customers",  -- 1-hop, suggest first
        "Countries",  -- 2-hop, suggest after
      },
    },
  },

  {
    id = 3241,
    type = "provider",
    provider = "joins",
    name = "2-hop from Customers to Regions",
    input = "SELECT * FROM Customers c JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Customers", alias = "c", schema = "dbo" }
      },
      aliases = { c = "Customers" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Regions",
          documentation_contains = "via Countries",
        },
      },
    },
  },

  {
    id = 3242,
    type = "provider",
    provider = "joins",
    name = "2-hop excludes already joined intermediate",
    input = "SELECT * FROM Orders o JOIN Customers c JOIN |",
    cursor = { line = 1, col = 46 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" },
        { name = "Customers", alias = "c", schema = "dbo" }
      },
      aliases = { o = "Orders", c = "Customers" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          insertText = "Countries co ON c.CountryID = co.CountryID", -- No Customers join
        },
      },
    },
  },

  {
    id = 3243,
    type = "provider",
    provider = "joins",
    name = "2-hop with multiple intermediates",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Departments",
          documentation_contains = "via Employees",
        },
      },
    },
  },

  {
    id = 3244,
    type = "provider",
    provider = "joins",
    name = "2-hop maximum distance limit",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        excludes = { "Regions" }, -- 3-hop (too far)
      },
    },
  },

  {
    id = 3245,
    type = "provider",
    provider = "joins",
    name = "2-hop with case-insensitive matching",
    input = "SELECT * FROM orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "orders" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Countries" },
      },
    },
  },

  {
    id = 3246,
    type = "provider",
    provider = "joins",
    name = "2-hop from Employees to Regions via Department and Division",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Divisions",
          documentation_contains = "via Departments",
        },
      },
    },
  },

  {
    id = 3247,
    type = "provider",
    provider = "joins",
    name = "2-hop with multi-column FK",
    input = "SELECT * FROM OrderDetails od JOIN |",
    cursor = { line = 1, col = 36 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "OrderDetails", alias = "od", schema = "dbo" }
      },
      aliases = { od = "OrderDetails" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Customers",
          documentation_contains = "via Orders",
        },
      },
    },
  },

  {
    id = 3248,
    type = "provider",
    provider = "joins",
    name = "2-hop shows complete join path in insertText",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          insertText = "Customers c ON o.CustomerID = c.CustomerID JOIN Countries co ON c.CountryID = co.CountryID",
        },
      },
    },
  },

  {
    id = 3249,
    type = "provider",
    provider = "joins",
    name = "2-hop from different starting tables",
    input = "SELECT * FROM Products p JOIN |",
    cursor = { line = 1, col = 31 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Products", alias = "p", schema = "dbo" }
      },
      aliases = { p = "Products" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Customers",
          documentation_contains = "via Orders",
        },
      },
    },
  },

  {
    id = 3250,
    type = "provider",
    provider = "joins",
    name = "2-hop with bidirectional FK",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Orders" }, -- 2-hop via Departments and back
      },
    },
  },

  {
    id = 3251,
    type = "provider",
    provider = "joins",
    name = "2-hop handles cycle detection",
    input = "SELECT * FROM Employees e JOIN Departments d JOIN |",
    cursor = { line = 1, col = 51 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" }
      },
      aliases = { e = "Employees", d = "Departments" },
    },
    expected = {
      type = "join",
      items = {
        excludes = { "Departments" }, -- No cycle back
      },
    },
  },

  {
    id = 3252,
    type = "provider",
    provider = "joins",
    name = "2-hop with nullable intermediate FK",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
      nullable_intermediate = true,
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          documentation_contains = "nullable",
        },
      },
    },
  },

  {
    id = 3253,
    type = "provider",
    provider = "joins",
    name = "2-hop with LEFT JOIN intermediate",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          insertText_contains = "LEFT JOIN Customers",
        },
      },
    },
  },

  {
    id = 3254,
    type = "provider",
    provider = "joins",
    name = "2-hop shortest path selection",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          documentation_contains = "via Customers", -- Shortest path
        },
      },
    },
  },

  {
    id = 3255,
    type = "provider",
    provider = "joins",
    name = "2-hop with intermediate table already in scope",
    input = "SELECT * FROM Orders o, Customers c JOIN |",
    cursor = { line = 1, col = 42 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" },
        { name = "Customers", alias = "c", schema = "dbo" }
      },
      aliases = { o = "Orders", c = "Customers" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          insertText = "Countries co ON c.CountryID = co.CountryID", -- Uses existing c
        },
      },
    },
  },

  {
    id = 3256,
    type = "provider",
    provider = "joins",
    name = "2-hop with complex FK graph",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        count_gte = 5, -- Multiple 2-hop targets available
      },
    },
  },

  {
    id = 3257,
    type = "provider",
    provider = "joins",
    name = "2-hop cross-schema FK",
    input = "SELECT * FROM Sales.Orders o JOIN |",
    cursor = { line = 1, col = 35 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "Sales" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "Sales" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          insertText_contains = "Geography.Countries",
        },
      },
    },
  },

  {
    id = 3258,
    type = "provider",
    provider = "joins",
    name = "2-hop with view as intermediate",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        excludes = { "CustomerCountryView" }, -- Views not in FK graph
      },
    },
  },

  {
    id = 3259,
    type = "provider",
    provider = "joins",
    name = "2-hop performance limit on large graph",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
      large_fk_graph = true,
    },
    expected = {
      type = "join",
      items = {
        count_lte = 50, -- Limited results for performance
      },
    },
  },

  {
    id = 3260,
    type = "provider",
    provider = "joins",
    name = "2-hop with composite join path documentation",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Countries",
          documentation_contains = "Orders -> Customers -> Countries",
        },
      },
    },
  },

  -- ========================================
  -- Alias Generation (3261-3280)
  -- ========================================

  {
    id = 3261,
    type = "provider",
    provider = "joins",
    name = "First letter alias - Employees -> e",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees",
          insertText_contains = "Employees e ",
        },
      },
    },
  },

  {
    id = 3262,
    type = "provider",
    provider = "joins",
    name = "Two letter alias when conflict - e exists, use em",
    input = "SELECT * FROM Events e JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Events", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Events" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees",
          insertText_contains = "Employees em ",
        },
      },
    },
  },

  {
    id = 3263,
    type = "provider",
    provider = "joins",
    name = "Three letter alias when conflict",
    input = "SELECT * FROM Events e JOIN Emails em JOIN |",
    cursor = { line = 1, col = 44 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Events", alias = "e", schema = "dbo" },
        { name = "Emails", alias = "em", schema = "dbo" }
      },
      aliases = { e = "Events", em = "Emails" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees",
          insertText_contains = "Employees emp ",
        },
      },
    },
  },

  {
    id = 3264,
    type = "provider",
    provider = "joins",
    name = "Full name fallback when all prefixes taken",
    input = "SELECT * FROM Events e JOIN Emails em JOIN Employers emp JOIN |",
    cursor = { line = 1, col = 63 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Events", alias = "e", schema = "dbo" },
        { name = "Emails", alias = "em", schema = "dbo" },
        { name = "Employers", alias = "emp", schema = "dbo" }
      },
      aliases = { e = "Events", em = "Emails", emp = "Employers" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees",
          insertText_contains = "Employees Employees ",
        },
      },
    },
  },

  {
    id = 3265,
    type = "provider",
    provider = "joins",
    name = "Case-insensitive conflict detection",
    input = "SELECT * FROM Events E JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Events", alias = "E", schema = "dbo" }
      },
      aliases = { E = "Events" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees",
          insertText_contains = "Employees em ", -- Not "e" (conflict with E)
        },
      },
    },
  },

  {
    id = 3266,
    type = "provider",
    provider = "joins",
    name = "Numeric suffix when needed",
    input = "SELECT * FROM Departments d JOIN Divisions d2 JOIN |",
    cursor = { line = 1, col = 51 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Departments", alias = "d", schema = "dbo" },
        { name = "Divisions", alias = "d2", schema = "dbo" }
      },
      aliases = { d = "Departments", d2 = "Divisions" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Districts",
          insertText_contains = "Districts d3 ",
        },
      },
    },
  },

  {
    id = 3267,
    type = "provider",
    provider = "joins",
    name = "Reserved word avoidance",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Select", -- Hypothetical reserved word table
          insertText_contains = "Select s ", -- Not conflicting with SQL keyword
        },
      },
    },
  },

  {
    id = 3268,
    type = "provider",
    provider = "joins",
    name = "Schema prefix stripping for alias",
    input = "SELECT * FROM dbo.Orders o JOIN |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Customers",
          insertText_contains = "Customers c ", -- Not "dbo.Customers dbo.c"
        },
      },
    },
  },

  {
    id = 3269,
    type = "provider",
    provider = "joins",
    name = "Underscore table name alias",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Order_Details",
          insertText_contains = "Order_Details od ",
        },
      },
    },
  },

  {
    id = 3270,
    type = "provider",
    provider = "joins",
    name = "Camel case table name alias",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "OrderDetails",
          insertText_contains = "OrderDetails od ",
        },
      },
    },
  },

  {
    id = 3271,
    type = "provider",
    provider = "joins",
    name = "Single letter table name keeps full name",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "X", -- Hypothetical single-letter table
          insertText_contains = "X X ",
        },
      },
    },
  },

  {
    id = 3272,
    type = "provider",
    provider = "joins",
    name = "Two letter table name uses full name",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "US", -- Hypothetical two-letter table
          insertText_contains = "US US ",
        },
      },
    },
  },

  {
    id = 3273,
    type = "provider",
    provider = "joins",
    name = "Numeric table name prefix handling",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "2023_Sales",
          insertText_contains = "2023_Sales s ",
        },
      },
    },
  },

  {
    id = 3274,
    type = "provider",
    provider = "joins",
    name = "Alias preserves case of table name",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "CUSTOMERS",
          insertText_contains = "CUSTOMERS c ",
        },
      },
    },
  },

  {
    id = 3275,
    type = "provider",
    provider = "joins",
    name = "Multiple same-prefix tables get sequential aliases",
    input = "SELECT * FROM Events e JOIN Emails em JOIN |",
    cursor = { line = 1, col = 44 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Events", alias = "e", schema = "dbo" },
        { name = "Emails", alias = "em", schema = "dbo" }
      },
      aliases = { e = "Events", em = "Emails" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees",
          insertText_contains = "Employees emp ",
        },
        {
          label = "Equipment",
          insertText_contains = "Equipment eq ",
        },
      },
    },
  },

  {
    id = 3276,
    type = "provider",
    provider = "joins",
    name = "Alias conflict with table name",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "e", -- Hypothetical table named "e"
          insertText_contains = "e e2 ", -- Must avoid conflict
        },
      },
    },
  },

  {
    id = 3277,
    type = "provider",
    provider = "joins",
    name = "Plural table name singularized for alias",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Categories",
          insertText_contains = "Categories c ", -- Not "Categories ca"
        },
      },
    },
  },

  {
    id = 3278,
    type = "provider",
    provider = "joins",
    name = "Vowel-only table name alias",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Area",
          insertText_contains = "Area a ",
        },
      },
    },
  },

  {
    id = 3279,
    type = "provider",
    provider = "joins",
    name = "Special character table name alias",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Order$Details",
          insertText_contains = "Order$Details od ",
        },
      },
    },
  },

  {
    id = 3280,
    type = "provider",
    provider = "joins",
    name = "Very long table name abbreviated alias",
    input = "SELECT * FROM Orders o JOIN |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "VeryLongTableNameForCustomerOrderDetails",
          insertText_contains = "VeryLongTableNameForCustomerOrderDetails v ",
        },
      },
    },
  },

  -- ========================================
  -- Fallback Tables (3281-3295)
  -- ========================================

  {
    id = 3281,
    type = "provider",
    provider = "joins",
    name = "Fallback when no FK exists",
    input = "SELECT * FROM StandaloneTable s JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Employees", "Departments", "Orders" }, -- All tables suggested
      },
    },
  },

  {
    id = 3282,
    type = "provider",
    provider = "joins",
    name = "Fallback includes all tables",
    input = "SELECT * FROM StandaloneTable s JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        count_gte = 10, -- Many tables available
      },
    },
  },

  {
    id = 3283,
    type = "provider",
    provider = "joins",
    name = "Fallback includes views",
    input = "SELECT * FROM StandaloneTable s JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "EmployeeView", "CustomerView" },
      },
    },
  },

  {
    id = 3284,
    type = "provider",
    provider = "joins",
    name = "Fallback excludes already joined",
    input = "SELECT * FROM StandaloneTable s JOIN Employees e JOIN |",
    cursor = { line = 1, col = 55 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" },
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable", e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        excludes = { "Employees", "StandaloneTable" },
      },
    },
  },

  {
    id = 3285,
    type = "provider",
    provider = "joins",
    name = "Fallback lower priority than FK",
    input = "SELECT * FROM Employees e JOIN |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      priority_order = {
        "Departments",      -- FK (highest priority)
        "Orders",           -- FK
        "StandaloneTable",  -- Fallback (lowest priority)
      },
    },
  },

  {
    id = 3286,
    type = "provider",
    provider = "joins",
    name = "Fallback with alias generation",
    input = "SELECT * FROM StandaloneTable s JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees",
          insertText_contains = "Employees e",
        },
      },
    },
  },

  {
    id = 3287,
    type = "provider",
    provider = "joins",
    name = "Fallback schema qualification",
    input = "SELECT * FROM dbo.StandaloneTable s JOIN |",
    cursor = { line = 1, col = 42 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees",
          insertText_contains = "dbo.Employees",
        },
      },
    },
  },

  {
    id = 3288,
    type = "provider",
    provider = "joins",
    name = "Fallback no ON clause auto-generated",
    input = "SELECT * FROM StandaloneTable s JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Employees",
          insertText = "Employees e", -- No ON clause
        },
      },
    },
  },

  {
    id = 3289,
    type = "provider",
    provider = "joins",
    name = "Fallback sorted alphabetically",
    input = "SELECT * FROM StandaloneTable s JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        sort_order = "alphabetical",
      },
    },
  },

  {
    id = 3290,
    type = "provider",
    provider = "joins",
    name = "Fallback includes system tables",
    input = "SELECT * FROM StandaloneTable s JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        excludes = { "sysdiagrams", "dtproperties" }, -- System tables excluded
      },
    },
  },

  {
    id = 3291,
    type = "provider",
    provider = "joins",
    name = "Fallback cross-schema tables",
    input = "SELECT * FROM dbo.StandaloneTable s JOIN |",
    cursor = { line = 1, col = 42 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "Sales.Orders", "HR.Employees" },
      },
    },
  },

  {
    id = 3292,
    type = "provider",
    provider = "joins",
    name = "Fallback table type indication",
    input = "SELECT * FROM StandaloneTable s JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "EmployeeView",
          kind = "View",
        },
      },
    },
  },

  {
    id = 3293,
    type = "provider",
    provider = "joins",
    name = "Fallback limited result count",
    input = "SELECT * FROM StandaloneTable s JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        count_lte = 100, -- Reasonable limit
      },
    },
  },

  {
    id = 3294,
    type = "provider",
    provider = "joins",
    name = "Fallback with partial text filtering",
    input = "SELECT * FROM StandaloneTable s JOIN Emp|",
    cursor = { line = 1, col = 41 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
      partial_text = "Emp",
    },
    expected = {
      type = "join",
      items = {
        includes = { "Employees" },
        excludes = { "Customers", "Orders" },
      },
    },
  },

  {
    id = 3295,
    type = "provider",
    provider = "joins",
    name = "Fallback includes TVFs",
    input = "SELECT * FROM StandaloneTable s JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "StandaloneTable", alias = "s", schema = "dbo" }
      },
      aliases = { s = "StandaloneTable" },
    },
    expected = {
      type = "join",
      items = {
        includes = { "GetEmployeesByDept" }, -- Table-valued function
      },
    },
  },

  -- ========================================
  -- Edge Cases (3296-3300)
  -- ========================================

  {
    id = 3296,
    type = "provider",
    provider = "joins",
    name = "Empty query - no FROM clause yet",
    input = "SELECT * |",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {},
      aliases = {},
    },
    expected = {
      type = "join",
      items = {
        count = 0, -- No suggestions without FROM
      },
    },
  },

  {
    id = 3297,
    type = "provider",
    provider = "joins",
    name = "CROSS JOIN - no ON clause needed",
    input = "SELECT * FROM Employees e CROSS JOIN |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" }
      },
      aliases = { e = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Departments",
          insertText = "Departments d", -- No ON clause for CROSS JOIN
        },
      },
    },
  },

  {
    id = 3298,
    type = "provider",
    provider = "joins",
    name = "Circular FK handling",
    input = "SELECT * FROM Employees e JOIN Departments d JOIN |",
    cursor = { line = 1, col = 51 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" }
      },
      aliases = { e = "Employees", d = "Departments" },
      circular_fk = { Employees = "Departments", Departments = "Employees" },
    },
    expected = {
      type = "join",
      items = {
        excludes = { "Employees", "Departments" }, -- No circular suggestion
      },
    },
  },

  {
    id = 3299,
    type = "provider",
    provider = "joins",
    name = "Very long table names",
    input = "SELECT * FROM VeryLongTableNameThatExceedsNormalLength v JOIN |",
    cursor = { line = 1, col = 62 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "VeryLongTableNameThatExceedsNormalLength", alias = "v", schema = "dbo" }
      },
      aliases = { v = "VeryLongTableNameThatExceedsNormalLength" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "AnotherVeryLongTableNameForJoining",
          insertText_contains = "AnotherVeryLongTableNameForJoining a ",
        },
      },
    },
  },

  {
    id = 3300,
    type = "provider",
    provider = "joins",
    name = "Tables from different schemas",
    input = "SELECT * FROM dbo.Orders o JOIN |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "join",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Orders", alias = "o", schema = "dbo" }
      },
      aliases = { o = "Orders" },
    },
    expected = {
      type = "join",
      items = {
        {
          label = "Customers",
          insertText = "dbo.Customers c ON o.CustomerID = c.CustomerID",
        },
        {
          label = "Sales.Products",
          insertText = "Sales.Products p ON o.ProductID = p.ProductID",
        },
      },
    },
  },
}
