-- Test file: select_into.lua
-- IDs: 2551-2600
-- Tests: SELECT INTO temp table parsing

return {
    -- Basic SELECT INTO
    {
        id = 2551,
        type = "parser",
        name = "Simple SELECT INTO temp table",
        input = "SELECT * INTO #TempTable FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempTable",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2552,
        type = "parser",
        name = "SELECT columns INTO temp table",
        input = "SELECT Id, Name, Email INTO #TempEmployees FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempEmployees",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- Global temp table
    {
        id = 2553,
        type = "parser",
        name = "SELECT INTO global temp table",
        input = "SELECT * INTO ##GlobalTemp FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "##GlobalTemp",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- With WHERE clause
    {
        id = 2554,
        type = "parser",
        name = "SELECT INTO with WHERE",
        input = "SELECT * INTO #ActiveEmployees FROM Employees WHERE Active = 1",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#ActiveEmployees",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2555,
        type = "parser",
        name = "SELECT INTO with complex WHERE",
        input = "SELECT * INTO #FilteredData FROM Employees WHERE Age > 30 AND Department = 'IT'",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#FilteredData",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- With source table alias
    {
        id = 2556,
        type = "parser",
        name = "SELECT INTO with source table alias",
        input = "SELECT * INTO #TempData FROM Employees e WHERE e.Active = 1",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempData",
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    -- With schema qualified source
    {
        id = 2557,
        type = "parser",
        name = "SELECT INTO from schema qualified table",
        input = "SELECT * INTO #TempData FROM dbo.Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempData",
                    tables = {
                        { name = "Employees", schema = "dbo" }
                    }
                }
            }
        }
    },
    {
        id = 2558,
        type = "parser",
        name = "SELECT INTO from database.schema.table",
        input = "SELECT * INTO #TempData FROM MyDB.dbo.Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempData",
                    tables = {
                        { name = "Employees", schema = "dbo", database = "MyDB" }
                    }
                }
            }
        }
    },

    -- With JOIN
    {
        id = 2559,
        type = "parser",
        name = "SELECT INTO from JOIN",
        input = "SELECT e.*, d.Name AS DeptName INTO #TempData FROM Employees e JOIN Departments d ON e.DeptId = d.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempData",
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },
    {
        id = 2560,
        type = "parser",
        name = "SELECT INTO from multiple JOINs",
        input = "SELECT * INTO #TempData FROM Employees e JOIN Departments d ON e.DeptId = d.Id JOIN Locations l ON d.LocationId = l.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempData",
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" },
                        { name = "Locations", alias = "l" }
                    }
                }
            }
        }
    },

    -- With TOP
    {
        id = 2561,
        type = "parser",
        name = "SELECT TOP INTO",
        input = "SELECT TOP 100 * INTO #Top100 FROM Employees ORDER BY Salary DESC",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#Top100",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2562,
        type = "parser",
        name = "SELECT TOP PERCENT INTO",
        input = "SELECT TOP 10 PERCENT * INTO #TopEarners FROM Employees ORDER BY Salary DESC",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TopEarners",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- With DISTINCT
    {
        id = 2563,
        type = "parser",
        name = "SELECT DISTINCT INTO",
        input = "SELECT DISTINCT DeptId INTO #UniqueDepts FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#UniqueDepts",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- With ORDER BY
    {
        id = 2564,
        type = "parser",
        name = "SELECT INTO with ORDER BY",
        input = "SELECT * INTO #SortedData FROM Employees ORDER BY Name",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#SortedData",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- With GROUP BY
    {
        id = 2565,
        type = "parser",
        name = "SELECT INTO with GROUP BY",
        input = "SELECT DeptId, COUNT(*) AS EmpCount INTO #DeptCounts FROM Employees GROUP BY DeptId",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#DeptCounts",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2566,
        type = "parser",
        name = "SELECT INTO with GROUP BY and HAVING",
        input = "SELECT DeptId, COUNT(*) AS EmpCount INTO #LargeDepts FROM Employees GROUP BY DeptId HAVING COUNT(*) > 10",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#LargeDepts",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- With subquery
    {
        id = 2567,
        type = "parser",
        name = "SELECT INTO from subquery",
        input = "SELECT * INTO #TempData FROM (SELECT * FROM Employees WHERE Active = 1) e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempData",
                    subqueries = {
                        {
                            alias = "e",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },

    -- With CTE
    {
        id = 2568,
        type = "parser",
        name = "SELECT INTO with CTE",
        input = "WITH ActiveEmps AS (SELECT * FROM Employees WHERE Active = 1) SELECT * INTO #TempData FROM ActiveEmps",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",  -- CTE queries still report as SELECT for completion
                    temp_table_name = "#TempData",
                    ctes = {
                        {
                            name = "ActiveEmps",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },

    -- Multiline formatting
    {
        id = 2569,
        type = "parser",
        name = "SELECT INTO multiline",
        input = [[SELECT
    Id,
    Name,
    Email
INTO #TempEmployees
FROM Employees
WHERE Active = 1]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempEmployees",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- With aggregate functions
    {
        id = 2570,
        type = "parser",
        name = "SELECT INTO with aggregates",
        input = "SELECT DeptId, AVG(Salary) AS AvgSalary, MAX(Salary) AS MaxSalary INTO #DeptStats FROM Employees GROUP BY DeptId",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#DeptStats",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- With CASE expression
    {
        id = 2571,
        type = "parser",
        name = "SELECT INTO with CASE",
        input = "SELECT Id, CASE WHEN Age > 30 THEN 'Senior' ELSE 'Junior' END AS Category INTO #Categorized FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#Categorized",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- From another temp table
    {
        id = 2572,
        type = "parser",
        name = "SELECT INTO from temp table",
        input = "SELECT * INTO #TempCopy FROM #TempOriginal",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempCopy",
                    tables = {
                        { name = "#TempOriginal", is_temp = true }
                    }
                }
            }
        }
    },

    -- Into permanent table (non-temp)
    {
        id = 2573,
        type = "parser",
        name = "SELECT INTO permanent table",
        input = "SELECT * INTO EmployeeBackup FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "EmployeeBackup",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2574,
        type = "parser",
        name = "SELECT INTO schema qualified permanent table",
        input = "SELECT * INTO dbo.EmployeeBackup FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "dbo.EmployeeBackup",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2575,
        type = "parser",
        name = "SELECT INTO database.schema.table",
        input = "SELECT * INTO ArchiveDB.dbo.EmployeeHistory FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "ArchiveDB.dbo.EmployeeHistory",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- With UNION
    -- Each SELECT in UNION is its own chunk for autocompletion scoping
    -- SELECT INTO with UNION: the INTO must be in the first SELECT (SQL Server syntax)
    {
        id = 2576,
        type = "parser",
        name = "SELECT INTO from UNION",
        input = "SELECT Id, Name INTO #AllWorkers FROM Employees UNION SELECT Id, Name FROM Contractors",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#AllWorkers",
                    tables = {
                        { name = "Employees" }
                    }
                },
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Contractors" }
                    }
                }
            }
        }
    },

    -- Complex real-world example
    {
        id = 2577,
        type = "parser",
        name = "Complex SELECT INTO",
        input = [[SELECT
    e.Id,
    e.Name,
    e.Email,
    d.Name AS DepartmentName,
    l.City AS LocationCity,
    CASE WHEN e.Salary > 100000 THEN 'High' ELSE 'Normal' END AS SalaryBand
INTO #EmployeeReport
FROM Employees e
INNER JOIN Departments d ON e.DeptId = d.Id
LEFT JOIN Locations l ON d.LocationId = l.Id
WHERE e.Active = 1
    AND e.HireDate > '2020-01-01'
ORDER BY e.Name]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#EmployeeReport",
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" },
                        { name = "Locations", alias = "l" }
                    }
                }
            }
        }
    },

    -- Verify columns are extracted if possible
    {
        id = 2578,
        type = "parser",
        name = "Verify columns extracted",
        input = "SELECT Id, Name, Email INTO #TempEmployees FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempEmployees",
                    columns = {
                        { name = "Id", source_table = nil, is_star = false },
                        { name = "Name", source_table = nil, is_star = false },
                        { name = "Email", source_table = nil, is_star = false }
                    },
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- With qualified column names
    {
        id = 2579,
        type = "parser",
        name = "SELECT INTO with qualified columns",
        input = "SELECT e.Id, e.Name, e.Email INTO #TempEmployees FROM Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempEmployees",
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    -- With column aliases
    {
        id = 2580,
        type = "parser",
        name = "SELECT INTO with column aliases",
        input = "SELECT Id AS EmployeeId, Name AS FullName INTO #TempEmployees FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempEmployees",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- With WHERE IN subquery
    {
        id = 2581,
        type = "parser",
        name = "SELECT INTO with WHERE IN subquery",
        input = "SELECT * INTO #TempEmployees FROM Employees WHERE DeptId IN (SELECT Id FROM Departments WHERE Active = 1)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempEmployees",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        { tables = {{ name = "Departments" }} }
                    }
                }
            }
        }
    },

    -- Cross-database SELECT INTO
    {
        id = 2582,
        type = "parser",
        name = "Cross-database SELECT INTO",
        input = "SELECT * INTO ArchiveDB.dbo.OldEmployees FROM ProductionDB.dbo.Employees WHERE LastLoginDate < '2020-01-01'",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "ArchiveDB.dbo.OldEmployees",
                    tables = {
                        { name = "Employees", schema = "dbo", database = "ProductionDB" }
                    }
                }
            }
        }
    },

    -- With table variable source
    {
        id = 2583,
        type = "parser",
        name = "SELECT INTO from table variable",
        input = "SELECT * INTO #TempData FROM @TableVar",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempData",
                    tables = {
                        { name = "@TableVar" }
                    }
                }
            }
        }
    },

    -- Edge case: Star with table prefix
    {
        id = 2584,
        type = "parser",
        name = "SELECT qualified star INTO",
        input = "SELECT e.* INTO #TempData FROM Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempData",
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    -- Multiple qualified stars
    {
        id = 2585,
        type = "parser",
        name = "SELECT multiple qualified stars INTO",
        input = "SELECT e.*, d.* INTO #TempData FROM Employees e JOIN Departments d ON e.DeptId = d.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    temp_table_name = "#TempData",
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },
}
