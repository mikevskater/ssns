-- Test file: aliases.lua
-- IDs: 2531-2550
-- Tests: Alias dictionary mapping for table resolution

return {
    -- ========================================
    -- 2531-2535: Basic Alias Mapping
    -- ========================================

    {
        id = 2531,
        type = "parser",
        name = "Single table with alias",
        input = "SELECT * FROM Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        e = { name = "Employees", alias = "e" }
                    },
                    tables = {{ name = "Employees", alias = "e" }}
                }
            }
        }
    },

    {
        id = 2532,
        type = "parser",
        name = "Multiple table aliases",
        input = "SELECT * FROM Employees e, Departments d WHERE e.DepartmentID = d.DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        e = { name = "Employees", alias = "e" },
                        d = { name = "Departments", alias = "d" }
                    },
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },

    {
        id = 2533,
        type = "parser",
        name = "Schema-qualified table with alias",
        input = "SELECT * FROM dbo.Employees e JOIN hr.Benefits b ON e.EmployeeID = b.EmployeeID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        e = { name = "Employees", schema = "dbo", alias = "e" },
                        b = { name = "Benefits", schema = "hr", alias = "b" }
                    },
                    tables = {
                        { name = "Employees", schema = "dbo", alias = "e" },
                        { name = "Benefits", schema = "hr", alias = "b" }
                    }
                }
            }
        }
    },

    {
        id = 2534,
        type = "parser",
        name = "Database.schema.table with alias",
        input = "SELECT * FROM TestDB.dbo.Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        e = { name = "Employees", schema = "dbo", database = "TestDB", alias = "e" }
                    },
                    tables = {{ name = "Employees", schema = "dbo", database = "TestDB", alias = "e" }}
                }
            }
        }
    },

    {
        id = 2535,
        type = "parser",
        name = "Three-part name with alias",
        input = "SELECT * FROM [OtherDB].[sales].[Orders] o JOIN [TestDB].[dbo].[Customers] c ON o.CustomerID = c.CustomerID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        o = { name = "Orders", schema = "sales", database = "OtherDB", alias = "o" },
                        c = { name = "Customers", schema = "dbo", database = "TestDB", alias = "c" }
                    }
                }
            }
        }
    },

    -- ========================================
    -- 2536-2540: Special Table Types with Aliases
    -- ========================================

    {
        id = 2536,
        type = "parser",
        name = "Temp table with alias",
        input = "SELECT * FROM #TempEmployees t WHERE t.Salary > 50000",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        t = { name = "#TempEmployees", alias = "t", is_temp = true }
                    },
                    tables = {{ name = "#TempEmployees", alias = "t", is_temp = true }}
                }
            }
        }
    },

    {
        id = 2537,
        type = "parser",
        name = "Global temp table with alias",
        input = "SELECT * FROM ##GlobalTemp g JOIN Employees e ON g.EmployeeID = e.EmployeeID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        g = { name = "##GlobalTemp", alias = "g", is_temp = true },
                        e = { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    {
        id = 2538,
        type = "parser",
        name = "Table variable with alias",
        input = "SELECT * FROM @EmployeeTable et WHERE et.DepartmentID = 5",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        et = { name = "@EmployeeTable", alias = "et", is_table_variable = true }
                    },
                    tables = {{ name = "@EmployeeTable", alias = "et", is_table_variable = true }}
                }
            }
        }
    },

    {
        id = 2539,
        type = "parser",
        name = "CTE reference with alias",
        input = "WITH EmployeeCTE AS (SELECT * FROM Employees) SELECT * FROM EmployeeCTE ec WHERE ec.Salary > 60000",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        ec = { name = "EmployeeCTE", alias = "ec", is_cte = true }
                    },
                    ctes = {
                        { name = "EmployeeCTE" }
                    },
                    tables = {{ name = "EmployeeCTE", alias = "ec", is_cte = true }}
                }
            }
        }
    },

    {
        id = 2540,
        type = "parser",
        name = "Mixed types - regular, temp, and CTE",
        input = "WITH TopEmployees AS (SELECT * FROM Employees WHERE Salary > 80000) SELECT * FROM TopEmployees te JOIN #TempDepts td ON te.DepartmentID = td.DepartmentID JOIN Departments d ON td.DepartmentID = d.DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        te = { name = "TopEmployees", alias = "te", is_cte = true },
                        td = { name = "#TempDepts", alias = "td", is_temp = true },
                        d = { name = "Departments", alias = "d" }
                    },
                    ctes = {
                        { name = "TopEmployees" }
                    }
                }
            }
        }
    },

    -- ========================================
    -- 2541-2545: JOIN Scenarios
    -- ========================================

    {
        id = 2541,
        type = "parser",
        name = "INNER JOIN with aliases",
        input = "SELECT * FROM Employees e INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        e = { name = "Employees", alias = "e" },
                        d = { name = "Departments", alias = "d" }
                    },
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },

    {
        id = 2542,
        type = "parser",
        name = "LEFT/RIGHT JOIN with aliases",
        input = "SELECT * FROM Employees e LEFT JOIN Departments d ON e.DepartmentID = d.DepartmentID RIGHT JOIN Benefits b ON e.EmployeeID = b.EmployeeID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        e = { name = "Employees", alias = "e" },
                        d = { name = "Departments", alias = "d" },
                        b = { name = "Benefits", alias = "b" }
                    }
                }
            }
        }
    },

    {
        id = 2543,
        type = "parser",
        name = "Multiple JOINs with aliases",
        input = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Orders o ON e.EmployeeID = o.EmployeeID JOIN Customers c ON o.CustomerID = c.CustomerID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        e = { name = "Employees", alias = "e" },
                        d = { name = "Departments", alias = "d" },
                        o = { name = "Orders", alias = "o" },
                        c = { name = "Customers", alias = "c" }
                    }
                }
            }
        }
    },

    {
        id = 2544,
        type = "parser",
        name = "Self-join - same table, different aliases",
        input = "SELECT * FROM Employees e1 JOIN Employees e2 ON e1.ManagerID = e2.EmployeeID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        e1 = { name = "Employees", alias = "e1" },
                        e2 = { name = "Employees", alias = "e2" }
                    },
                    tables = {
                        { name = "Employees", alias = "e1" },
                        { name = "Employees", alias = "e2" }
                    }
                }
            }
        }
    },

    {
        id = 2545,
        type = "parser",
        name = "Cross-database JOIN with aliases",
        input = "SELECT * FROM DB1.dbo.Employees e JOIN DB2.sales.Orders o ON e.EmployeeID = o.EmployeeID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        e = { name = "Employees", schema = "dbo", database = "DB1", alias = "e" },
                        o = { name = "Orders", schema = "sales", database = "DB2", alias = "o" }
                    }
                }
            }
        }
    },

    -- ========================================
    -- 2546-2550: Edge Cases
    -- ========================================

    {
        id = 2546,
        type = "parser",
        name = "Table without alias - no entry in aliases dict",
        input = "SELECT * FROM Employees JOIN Departments d ON Employees.DepartmentID = d.DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        d = { name = "Departments", alias = "d" }
                        -- Note: Employees has NO alias, so it should NOT be in aliases dict
                    },
                    tables = {
                        { name = "Employees" }, -- No alias field
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },

    {
        id = 2547,
        type = "parser",
        name = "Subquery with alias - subquery alias NOT in aliases",
        input = "SELECT * FROM (SELECT EmployeeID, FirstName FROM Employees) emp WHERE emp.EmployeeID > 100",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        -- Subquery alias 'emp' should NOT be in aliases dict
                        -- It's in subqueries[].alias instead
                    },
                    subqueries = {
                        { alias = "emp" }
                    }
                }
            }
        }
    },

    {
        id = 2548,
        type = "parser",
        name = "Case sensitivity - aliases stored lowercase",
        input = "SELECT * FROM Employees E JOIN Departments D ON E.DepartmentID = D.DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        -- Aliases should be lowercase keys even though input uses uppercase E and D
                        e = { name = "Employees", alias = "E" }, -- Key is lowercase, value preserves original case
                        d = { name = "Departments", alias = "D" }
                    }
                }
            }
        }
    },

    {
        id = 2549,
        type = "parser",
        name = "Reserved word as alias - bracketed",
        input = "SELECT * FROM Employees [select] JOIN Departments [where] ON [select].DepartmentID = [where].DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        select = { name = "Employees", alias = "select" },
                        where = { name = "Departments", alias = "where" }
                    }
                }
            }
        }
    },

    {
        id = 2550,
        type = "parser",
        name = "Multi-statement - same alias in different contexts",
        input = [[
SELECT * FROM Employees e WHERE e.Salary > 50000;
SELECT * FROM Departments e WHERE e.Budget > 100000;
        ]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    aliases = {
                        e = { name = "Employees", alias = "e" }
                    },
                    tables = {{ name = "Employees", alias = "e" }}
                },
                {
                    statement_type = "SELECT",
                    aliases = {
                        e = { name = "Departments", alias = "e" } -- Same alias 'e' but different table
                    },
                    tables = {{ name = "Departments", alias = "e" }}
                }
            }
        }
    }
}
