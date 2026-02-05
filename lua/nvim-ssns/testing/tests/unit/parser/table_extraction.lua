-- Test file: table_extraction.lua
-- IDs: 2501-2550
-- Tests: Focus on accurate table reference extraction with all field variations

return {
    -- Table without qualification or alias
    {
        id = 2501,
        type = "parser",
        name = "Simple table name only",
        input = "SELECT * FROM Employees",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = nil, schema = nil, database = nil }
                    }
                }
            }
        }
    },

    -- Table with alias (no AS)
    {
        id = 2502,
        type = "parser",
        name = "Table with simple alias",
        input = "SELECT * FROM Employees e",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = "e", schema = nil, database = nil }
                    }
                }
            }
        }
    },

    -- Table with alias (with AS)
    {
        id = 2503,
        type = "parser",
        name = "Table with AS alias",
        input = "SELECT * FROM Employees AS emp",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = "emp", schema = nil, database = nil }
                    }
                }
            }
        }
    },

    -- Schema.Table
    {
        id = 2504,
        type = "parser",
        name = "Schema qualified table",
        input = "SELECT * FROM dbo.Employees",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", schema = "dbo", alias = nil, database = nil }
                    }
                }
            }
        }
    },
    {
        id = 2505,
        type = "parser",
        name = "Schema qualified table with alias",
        input = "SELECT * FROM dbo.Employees e",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", schema = "dbo", alias = "e", database = nil }
                    }
                }
            }
        }
    },
    {
        id = 2506,
        type = "parser",
        name = "Non-dbo schema",
        input = "SELECT * FROM hr.Employees",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", schema = "hr", alias = nil, database = nil }
                    }
                }
            }
        }
    },

    -- Database.Schema.Table
    {
        id = 2507,
        type = "parser",
        name = "Database.schema.table",
        input = "SELECT * FROM MyDB.dbo.Employees",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", schema = "dbo", database = "MyDB", alias = nil }
                    }
                }
            }
        }
    },
    {
        id = 2508,
        type = "parser",
        name = "Database.schema.table with alias",
        input = "SELECT * FROM MyDB.dbo.Employees e",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", schema = "dbo", database = "MyDB", alias = "e" }
                    }
                }
            }
        }
    },
    {
        id = 2509,
        type = "parser",
        name = "Different database and schema",
        input = "SELECT * FROM SalesDB.sales.Orders",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Orders", schema = "sales", database = "SalesDB", alias = nil }
                    }
                }
            }
        }
    },

    -- Temp tables
    {
        id = 2510,
        type = "parser",
        name = "Temp table with # prefix",
        input = "SELECT * FROM #TempEmployees",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "#TempEmployees", is_temp = true, alias = nil }
                    }
                }
            }
        }
    },
    {
        id = 2511,
        type = "parser",
        name = "Temp table with alias",
        input = "SELECT * FROM #TempEmployees t",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "#TempEmployees", is_temp = true, alias = "t" }
                    }
                }
            }
        }
    },
    {
        id = 2512,
        type = "parser",
        name = "Global temp table",
        input = "SELECT * FROM ##GlobalTemp",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "##GlobalTemp", is_temp = true, alias = nil }
                    }
                }
            }
        }
    },
    {
        id = 2513,
        type = "parser",
        name = "Global temp table with alias",
        input = "SELECT * FROM ##GlobalTemp g",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "##GlobalTemp", is_temp = true, alias = "g" }
                    }
                }
            }
        }
    },

    -- Bracketed identifiers
    {
        id = 2514,
        type = "parser",
        name = "Bracketed table name",
        input = "SELECT * FROM [Employees]",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = nil, schema = nil }
                    }
                }
            }
        }
    },
    {
        id = 2515,
        type = "parser",
        name = "Bracketed schema and table",
        input = "SELECT * FROM [dbo].[Employees]",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", schema = "dbo", alias = nil }
                    }
                }
            }
        }
    },
    {
        id = 2516,
        type = "parser",
        name = "Bracketed database, schema, and table",
        input = "SELECT * FROM [MyDB].[dbo].[Employees]",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", schema = "dbo", database = "MyDB", alias = nil }
                    }
                }
            }
        }
    },
    {
        id = 2517,
        type = "parser",
        name = "Bracketed identifiers with spaces",
        input = "SELECT * FROM [My Database].[My Schema].[My Table]",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "My Table", schema = "My Schema", database = "My Database", alias = nil }
                    }
                }
            }
        }
    },
    {
        id = 2518,
        type = "parser",
        name = "Bracketed with spaces and alias",
        input = "SELECT * FROM [My Schema].[My Table] t",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "My Table", schema = "My Schema", alias = "t" }
                    }
                }
            }
        }
    },

    -- Mixed qualified and unqualified
    {
        id = 2519,
        type = "parser",
        name = "Mix of qualified and unqualified tables",
        input = "SELECT * FROM Employees e JOIN dbo.Departments d ON e.DeptId = d.Id",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = "e", schema = nil },
                        { name = "Departments", alias = "d", schema = "dbo" }
                    }
                }
            }
        }
    },
    {
        id = 2520,
        type = "parser",
        name = "Mix of database qualified tables",
        input = "SELECT * FROM DB1.dbo.Orders o JOIN DB2.dbo.Customers c ON o.CustomerId = c.Id",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Orders", schema = "dbo", database = "DB1", alias = "o" },
                        { name = "Customers", schema = "dbo", database = "DB2", alias = "c" }
                    }
                }
            }
        }
    },

    -- Table variables
    {
        id = 2521,
        type = "parser",
        name = "Table variable",
        input = "SELECT * FROM @TableVar",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "@TableVar", alias = nil }
                    }
                }
            }
        }
    },
    {
        id = 2522,
        type = "parser",
        name = "Table variable with alias",
        input = "SELECT * FROM @TableVar tv",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "@TableVar", alias = "tv" }
                    }
                }
            }
        }
    },

    -- Special characters in names
    {
        id = 2523,
        type = "parser",
        name = "Table with underscore",
        input = "SELECT * FROM Employee_Details",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employee_Details", alias = nil }
                    }
                }
            }
        }
    },
    {
        id = 2524,
        type = "parser",
        name = "Table with numbers",
        input = "SELECT * FROM Employees2023",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees2023", alias = nil }
                    }
                }
            }
        }
    },
    {
        id = 2525,
        type = "parser",
        name = "Schema with underscore",
        input = "SELECT * FROM sales_archive.Orders",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Orders", schema = "sales_archive", alias = nil }
                    }
                }
            }
        }
    },

    -- Long alias names
    {
        id = 2526,
        type = "parser",
        name = "Long descriptive alias",
        input = "SELECT * FROM Employees employee_records",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = "employee_records" }
                    }
                }
            }
        }
    },

    -- Single character aliases
    {
        id = 2527,
        type = "parser",
        name = "Single character alias",
        input = "SELECT * FROM Employees e",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    -- Multiple tables with various qualification levels
    {
        id = 2528,
        type = "parser",
        name = "Four tables with different qualification levels",
        input = "SELECT * FROM T1, dbo.T2, DB1.dbo.T3, [My Schema].T4",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "T1", schema = nil, database = nil },
                        { name = "T2", schema = "dbo", database = nil },
                        { name = "T3", schema = "dbo", database = "DB1" },
                        { name = "T4", schema = "My Schema", database = nil }
                    }
                }
            }
        }
    },

    -- Verify no extra fields
    {
        id = 2529,
        type = "parser",
        name = "Table fields are clean (no extra fields)",
        input = "SELECT * FROM dbo.Employees e",
        expected = {
            chunks = {
                {
                    tables = {
                        {
                            name = "Employees",
                            schema = "dbo",
                            alias = "e",
                            database = nil
                        }
                    }
                }
            }
        }
    },

    -- Case sensitivity preservation
    {
        id = 2530,
        type = "parser",
        name = "Mixed case table name",
        input = "SELECT * FROM MyTable",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "MyTable" }
                    }
                }
            }
        }
    },
    {
        id = 2531,
        type = "parser",
        name = "Mixed case schema",
        input = "SELECT * FROM MySchema.MyTable",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "MyTable", schema = "MySchema" }
                    }
                }
            }
        }
    },

    -- Whitespace handling
    {
        id = 2532,
        type = "parser",
        name = "Extra whitespace before alias",
        input = "SELECT * FROM Employees    e",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },
    {
        id = 2533,
        type = "parser",
        name = "Tab before alias",
        input = "SELECT * FROM Employees\te",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    -- Cross-database queries
    {
        id = 2534,
        type = "parser",
        name = "Three different databases",
        input = "SELECT * FROM DB1.dbo.T1 JOIN DB2.dbo.T2 ON T1.Id = T2.Id JOIN DB3.dbo.T3 ON T2.Id = T3.Id",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "T1", schema = "dbo", database = "DB1" },
                        { name = "T2", schema = "dbo", database = "DB2" },
                        { name = "T3", schema = "dbo", database = "DB3" }
                    }
                }
            }
        }
    },

    -- Server.Database.Schema.Table (linked server)
    {
        id = 2535,
        type = "parser",
        name = "Linked server four-part name",
        input = "SELECT * FROM [SERVER1].[MyDB].[dbo].[Employees]",
        expected = {
            chunks = {
                {
                    tables = {
                        {
                            name = "Employees",
                            schema = "dbo",
                            database = "MyDB",
                            server = "SERVER1"
                        }
                    }
                }
            }
        }
    },
    {
        id = 2536,
        type = "parser",
        name = "Linked server with alias",
        input = "SELECT * FROM [SERVER1].[MyDB].[dbo].[Employees] e",
        expected = {
            chunks = {
                {
                    tables = {
                        {
                            name = "Employees",
                            schema = "dbo",
                            database = "MyDB",
                            server = "SERVER1",
                            alias = "e"
                        }
                    }
                }
            }
        }
    },

    -- Real-world table names
    {
        id = 2537,
        type = "parser",
        name = "Realistic table name with prefix",
        input = "SELECT * FROM tbl_Employees",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "tbl_Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2538,
        type = "parser",
        name = "Table with date suffix",
        input = "SELECT * FROM Orders_2023_12",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Orders_2023_12" }
                    }
                }
            }
        }
    },

    -- Mixed temp and permanent tables
    {
        id = 2539,
        type = "parser",
        name = "JOIN temp table with permanent table",
        input = "SELECT * FROM #TempData t JOIN dbo.Employees e ON t.EmployeeId = e.Id",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "#TempData", is_temp = true, alias = "t" },
                        { name = "Employees", schema = "dbo", alias = "e" }
                    }
                }
            }
        }
    },

    -- Verification of all fields present
    {
        id = 2540,
        type = "parser",
        name = "All fields present - full qualification",
        input = "SELECT * FROM [MyDB].[dbo].[Employees] e",
        expected = {
            chunks = {
                {
                    tables = {
                        {
                            name = "Employees",
                            schema = "dbo",
                            database = "MyDB",
                            alias = "e"
                        }
                    }
                }
            }
        }
    },
    {
        id = 2541,
        type = "parser",
        name = "All fields present - linked server",
        input = "SELECT * FROM [SERVER1].[MyDB].[dbo].[Employees] e",
        expected = {
            chunks = {
                {
                    tables = {
                        {
                            name = "Employees",
                            schema = "dbo",
                            database = "MyDB",
                            server = "SERVER1",
                            alias = "e"
                        }
                    }
                }
            }
        }
    },

    -- Bracketed alias (non-standard but sometimes used)
    {
        id = 2542,
        type = "parser",
        name = "Bracketed alias",
        input = "SELECT * FROM Employees [e]",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    -- Unicode characters in brackets
    {
        id = 2543,
        type = "parser",
        name = "Unicode in bracketed identifier",
        input = "SELECT * FROM [Employees™]",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees™" }
                    }
                }
            }
        }
    },

    -- Very long names
    {
        id = 2544,
        type = "parser",
        name = "Very long table name",
        input = "SELECT * FROM VeryLongTableNameThatDescribesExactlyWhatItContains",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "VeryLongTableNameThatDescribesExactlyWhatItContains" }
                    }
                }
            }
        }
    },

    -- Empty alias should be nil, not empty string
    {
        id = 2545,
        type = "parser",
        name = "No alias means nil, not empty string",
        input = "SELECT * FROM Employees",
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = nil }
                    }
                }
            }
        }
    },

    -- All variations in one query
    {
        id = 2546,
        type = "parser",
        name = "All table reference variations in one query",
        input = [[SELECT *
FROM Employees e
JOIN dbo.Departments d ON e.DeptId = d.Id
JOIN DB1.dbo.Locations l ON d.LocationId = l.Id
JOIN #TempData t ON e.Id = t.EmployeeId
JOIN @TableVar tv ON e.Id = tv.EmployeeId
JOIN [My Schema].[My Table] mt ON e.Id = mt.EmployeeId]],
        expected = {
            chunks = {
                {
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", schema = "dbo", alias = "d" },
                        { name = "Locations", schema = "dbo", database = "DB1", alias = "l" },
                        { name = "#TempData", is_temp = true, alias = "t" },
                        { name = "@TableVar", alias = "tv" },
                        { name = "My Table", schema = "My Schema", alias = "mt" }
                    }
                }
            }
        }
    },
}
