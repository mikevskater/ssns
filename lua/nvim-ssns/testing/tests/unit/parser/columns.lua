-- Test file: columns.lua
-- IDs: 2801-2830
-- Tests: Column tracking with parent_table lineage for IntelliSense

return {
    -- ========================================
    -- 2801-2805: Basic Column Lists
    -- ========================================

    {
        id = 2801,
        type = "parser",
        name = "Simple column list with single table",
        input = "SELECT EmployeeID, FirstName, LastName FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", parent_table = "Employees", is_star = false },
                        { name = "FirstName", parent_table = "Employees", is_star = false },
                        { name = "LastName", parent_table = "Employees", is_star = false }
                    },
                    tables = {{ name = "Employees" }}
                }
            }
        }
    },

    {
        id = 2802,
        type = "parser",
        name = "Qualified columns with table prefix",
        input = "SELECT Employees.EmployeeID, Employees.FirstName FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", source_table = "Employees", parent_table = "Employees", is_star = false },
                        { name = "FirstName", source_table = "Employees", parent_table = "Employees", is_star = false }
                    },
                    tables = {{ name = "Employees" }}
                }
            }
        }
    },

    {
        id = 2803,
        type = "parser",
        name = "Mixed qualified and unqualified columns",
        input = "SELECT EmployeeID, Employees.FirstName, LastName FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", parent_table = "Employees", is_star = false },
                        { name = "FirstName", source_table = "Employees", parent_table = "Employees", is_star = false },
                        { name = "LastName", parent_table = "Employees", is_star = false }
                    },
                    tables = {{ name = "Employees" }}
                }
            }
        }
    },

    {
        id = 2804,
        type = "parser",
        name = "Column with AS alias",
        input = "SELECT EmployeeID AS EmpId, FirstName AS FName FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmpId", parent_table = "Employees", is_star = false },
                        { name = "FName", parent_table = "Employees", is_star = false }
                    },
                    tables = {{ name = "Employees" }}
                }
            }
        }
    },

    {
        id = 2805,
        type = "parser",
        name = "Multiple columns with various aliases",
        input = "SELECT EmployeeID, FirstName AS FName, LastName LName, Email FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", parent_table = "Employees", is_star = false },
                        { name = "FName", parent_table = "Employees", is_star = false },
                        { name = "LName", parent_table = "Employees", is_star = false },
                        { name = "Email", parent_table = "Employees", is_star = false }
                    },
                    tables = {{ name = "Employees" }}
                }
            }
        }
    },

    -- ========================================
    -- 2806-2810: Star Expansion
    -- ========================================

    {
        id = 2806,
        type = "parser",
        name = "Simple SELECT *",
        input = "SELECT * FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "*", parent_table = "Employees", is_star = true }
                    },
                    tables = {{ name = "Employees" }}
                }
            }
        }
    },

    {
        id = 2807,
        type = "parser",
        name = "Qualified star with alias resolves parent_table",
        input = "SELECT e.* FROM Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "*", source_table = "e", parent_table = "Employees", is_star = true }
                    },
                    tables = {{ name = "Employees", alias = "e" }}
                }
            }
        }
    },

    {
        id = 2808,
        type = "parser",
        name = "Mixed star and columns",
        input = "SELECT e.*, d.DepartmentName FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "*", source_table = "e", parent_table = "Employees", is_star = true },
                        { name = "DepartmentName", source_table = "d", parent_table = "Departments", is_star = false }
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
        id = 2809,
        type = "parser",
        name = "Multiple qualified stars",
        input = "SELECT e.*, d.* FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "*", source_table = "e", parent_table = "Employees", is_star = true },
                        { name = "*", source_table = "d", parent_table = "Departments", is_star = true }
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
        id = 2810,
        type = "parser",
        name = "Star from schema-qualified table",
        input = "SELECT dbo.Employees.* FROM dbo.Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "*", source_table = "Employees", parent_table = "Employees", parent_schema = "dbo", is_star = true }
                    },
                    tables = {{ name = "Employees", schema = "dbo" }}
                }
            }
        }
    },

    -- ========================================
    -- 2811-2815: Parent Table Resolution via Aliases
    -- ========================================

    {
        id = 2811,
        type = "parser",
        name = "Single alias resolves to parent_table",
        input = "SELECT e.EmployeeID, e.FirstName FROM Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", source_table = "e", parent_table = "Employees", is_star = false },
                        { name = "FirstName", source_table = "e", parent_table = "Employees", is_star = false }
                    },
                    tables = {{ name = "Employees", alias = "e" }}
                }
            }
        }
    },

    {
        id = 2812,
        type = "parser",
        name = "Multiple aliases resolve correctly",
        input = "SELECT e.EmployeeID, d.DepartmentName FROM Employees e, Departments d",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", source_table = "e", parent_table = "Employees", is_star = false },
                        { name = "DepartmentName", source_table = "d", parent_table = "Departments", is_star = false }
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
        id = 2813,
        type = "parser",
        name = "Schema-qualified tables with aliases",
        input = "SELECT e.EmployeeID FROM dbo.Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", source_table = "e", parent_table = "Employees", parent_schema = "dbo", is_star = false }
                    },
                    tables = {{ name = "Employees", schema = "dbo", alias = "e" }}
                }
            }
        }
    },

    {
        id = 2814,
        type = "parser",
        name = "Database.schema.table with alias",
        input = "SELECT e.EmployeeID FROM TestDB.dbo.Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", source_table = "e", parent_table = "Employees", parent_schema = "dbo", is_star = false }
                    },
                    tables = {{ name = "Employees", schema = "dbo", database = "TestDB", alias = "e" }}
                }
            }
        }
    },

    {
        id = 2815,
        type = "parser",
        name = "No alias - direct table reference",
        input = "SELECT Employees.EmployeeID, Employees.FirstName FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", source_table = "Employees", parent_table = "Employees", is_star = false },
                        { name = "FirstName", source_table = "Employees", parent_table = "Employees", is_star = false }
                    },
                    tables = {{ name = "Employees" }}
                }
            }
        }
    },

    -- ========================================
    -- 2816-2820: JOINs with Multiple Tables
    -- ========================================

    {
        id = 2816,
        type = "parser",
        name = "Simple JOIN with both table aliases resolving",
        input = "SELECT e.EmployeeID, e.FirstName, d.DepartmentName FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", source_table = "e", parent_table = "Employees", is_star = false },
                        { name = "FirstName", source_table = "e", parent_table = "Employees", is_star = false },
                        { name = "DepartmentName", source_table = "d", parent_table = "Departments", is_star = false }
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
        id = 2817,
        type = "parser",
        name = "Multiple JOINs - all aliases resolve",
        input = "SELECT e.EmployeeID, d.DepartmentName, o.OrderId FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Orders o ON e.EmployeeID = o.EmployeeId",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", source_table = "e", parent_table = "Employees", is_star = false },
                        { name = "DepartmentName", source_table = "d", parent_table = "Departments", is_star = false },
                        { name = "OrderId", source_table = "o", parent_table = "Orders", is_star = false }
                    },
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" },
                        { name = "Orders", alias = "o" }
                    }
                }
            }
        }
    },

    {
        id = 2818,
        type = "parser",
        name = "Self-join with different aliases",
        input = "SELECT e1.FirstName AS Employee, e2.FirstName AS Manager FROM Employees e1 LEFT JOIN Employees e2 ON e1.EmployeeID = e2.EmployeeID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "Employee", source_table = "e1", parent_table = "Employees", is_star = false },
                        { name = "Manager", source_table = "e2", parent_table = "Employees", is_star = false }
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
        id = 2819,
        type = "parser",
        name = "Mix of aliased and non-aliased tables",
        input = "SELECT e.EmployeeID, Departments.DepartmentName FROM Employees e JOIN Departments ON e.DepartmentID = Departments.DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", source_table = "e", parent_table = "Employees", is_star = false },
                        { name = "DepartmentName", source_table = "Departments", parent_table = "Departments", is_star = false }
                    },
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments" }
                    }
                }
            }
        }
    },

    {
        id = 2820,
        type = "parser",
        name = "Columns from specific tables in complex JOIN",
        input = "SELECT c.Name, o.OrderId, p.Name AS ProductName FROM Customers c JOIN Orders o ON c.CustomerId = o.CustomerId JOIN Products p ON o.ProductId = p.ProductId",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "Name", source_table = "c", parent_table = "Customers", is_star = false },
                        { name = "OrderId", source_table = "o", parent_table = "Orders", is_star = false },
                        { name = "ProductName", source_table = "p", parent_table = "Products", is_star = false }
                    },
                    tables = {
                        { name = "Customers", alias = "c" },
                        { name = "Orders", alias = "o" },
                        { name = "Products", alias = "p" }
                    }
                }
            }
        }
    },

    -- ========================================
    -- 2821-2825: Expressions and Computed Columns
    -- ========================================

    {
        id = 2821,
        type = "parser",
        name = "Expression with alias",
        input = "SELECT Salary * 12 AS AnnualSalary FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "AnnualSalary", is_star = false }
                    },
                    tables = {{ name = "Employees" }}
                }
            }
        }
    },

    {
        id = 2822,
        type = "parser",
        name = "Aggregate functions",
        input = "SELECT COUNT(*) AS TotalEmployees, AVG(Salary) AS AvgSalary FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "TotalEmployees", is_star = false },
                        { name = "AvgSalary", is_star = false }
                    },
                    tables = {{ name = "Employees" }}
                }
            }
        }
    },

    {
        id = 2823,
        type = "parser",
        name = "CASE expression with alias",
        input = "SELECT CASE WHEN Salary > 50000 THEN 'High' ELSE 'Low' END AS SalaryRange FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "SalaryRange", is_star = false }
                    },
                    tables = {{ name = "Employees" }}
                }
            }
        }
    },

    {
        id = 2824,
        type = "parser",
        name = "Function call with column and alias",
        input = "SELECT UPPER(FirstName) AS UpperName, LOWER(e.LastName) AS LowerName FROM Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "UpperName", is_star = false },
                        { name = "LowerName", is_star = false }
                    },
                    tables = {{ name = "Employees", alias = "e" }}
                }
            }
        }
    },

    {
        id = 2825,
        type = "parser",
        name = "Computed from multiple tables",
        input = "SELECT e.Salary * 12 AS AnnualPay, d.Budget / 12 AS MonthlyBudget FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "AnnualPay", is_star = false },
                        { name = "MonthlyBudget", is_star = false }
                    },
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },

    -- ========================================
    -- 2826-2830: CTEs and Subqueries
    -- ========================================

    {
        id = 2826,
        type = "parser",
        name = "Columns in CTE definition inherit parent_table",
        input = "WITH EmployeeCTE AS (SELECT EmployeeID, FirstName FROM Employees) SELECT * FROM EmployeeCTE",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "EmployeeCTE",
                            columns = {
                                { name = "EmployeeID", parent_table = "Employees", is_star = false },
                                { name = "FirstName", parent_table = "Employees", is_star = false }
                            },
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },

    {
        id = 2827,
        type = "parser",
        name = "Columns from CTE reference",
        input = "WITH EmployeeCTE AS (SELECT EmployeeID, FirstName FROM Employees) SELECT e.EmployeeID, e.FirstName FROM EmployeeCTE e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", source_table = "e", parent_table = "EmployeeCTE", is_star = false },
                        { name = "FirstName", source_table = "e", parent_table = "EmployeeCTE", is_star = false }
                    },
                    ctes = {
                        {
                            name = "EmployeeCTE",
                            columns = {
                                { name = "EmployeeID", parent_table = "Employees", is_star = false },
                                { name = "FirstName", parent_table = "Employees", is_star = false }
                            },
                            tables = {{ name = "Employees" }}
                        }
                    },
                    tables = {{ name = "EmployeeCTE", alias = "e" }}
                }
            }
        }
    },

    {
        id = 2828,
        type = "parser",
        name = "Subquery columns with parent_table",
        input = "SELECT EmployeeID, (SELECT COUNT(*) FROM Orders o WHERE o.EmployeeId = e.EmployeeID) AS OrderCount FROM Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    columns = {
                        { name = "EmployeeID", parent_table = "Employees", is_star = false },
                        { name = "OrderCount", is_star = false }
                    },
                    tables = {{ name = "Employees", alias = "e" }}
                }
            }
        }
    },

    {
        id = 2829,
        type = "parser",
        name = "Nested CTEs - column lineage tracking",
        input = "WITH CTE1 AS (SELECT EmployeeID, FirstName FROM Employees), CTE2 AS (SELECT c.EmployeeID FROM CTE1 c) SELECT * FROM CTE2",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "CTE1",
                            columns = {
                                { name = "EmployeeID", parent_table = "Employees", is_star = false },
                                { name = "FirstName", parent_table = "Employees", is_star = false }
                            },
                            tables = {{ name = "Employees" }}
                        },
                        {
                            name = "CTE2",
                            columns = {
                                { name = "EmployeeID", source_table = "c", parent_table = "CTE1", is_star = false }
                            },
                            tables = {{ name = "CTE1", alias = "c" }}
                        }
                    }
                }
            }
        }
    },

    {
        id = 2830,
        type = "parser",
        name = "SELECT INTO temp table - columns get parent_table",
        input = "SELECT e.EmployeeID, e.FirstName INTO #TempEmployees FROM Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempEmployees",
                    columns = {
                        { name = "EmployeeID", source_table = "e", parent_table = "Employees", is_star = false },
                        { name = "FirstName", source_table = "e", parent_table = "Employees", is_star = false }
                    },
                    tables = {{ name = "Employees", alias = "e" }}
                }
            }
        }
    }
}
