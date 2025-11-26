-- Test file: edge_cases.lua
-- IDs: 2601-2650
-- Tests: Parser edge cases, error conditions, and boundary scenarios

return {
    -- Empty and whitespace inputs
    {
        id = 2601,
        type = "parser",
        name = "Empty input",
        input = "",
        expected = {
            chunks = {}
        }
    },
    {
        id = 2602,
        type = "parser",
        name = "Only whitespace",
        input = "   \n\t  \n   ",
        expected = {
            chunks = {}
        }
    },
    {
        id = 2603,
        type = "parser",
        name = "Only comments",
        input = "-- This is a comment\n/* Block comment */",
        expected = {
            chunks = {}
        }
    },

    -- Incomplete statements
    {
        id = 2604,
        type = "parser",
        name = "Incomplete SELECT - no FROM",
        input = "SELECT *",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {}  -- No tables because no FROM clause
                }
            }
        }
    },
    {
        id = 2605,
        type = "parser",
        name = "Incomplete SELECT - FROM but no table",
        input = "SELECT * FROM",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {}  -- Parser should handle gracefully
                }
            }
        }
    },
    {
        id = 2606,
        type = "parser",
        name = "Incomplete JOIN - no ON clause",
        input = "SELECT * FROM Employees JOIN Departments",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" },
                        { name = "Departments" }
                    }
                }
            }
        }
    },
    {
        id = 2607,
        type = "parser",
        name = "Incomplete WHERE clause",
        input = "SELECT * FROM Employees WHERE",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- Malformed subqueries
    {
        id = 2608,
        type = "parser",
        name = "Unclosed subquery",
        input = "SELECT * FROM (SELECT * FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT"
                    -- Should not crash, may have partial data
                }
            }
        }
    },
    {
        id = 2609,
        type = "parser",
        name = "Subquery without alias",
        input = "SELECT * FROM (SELECT * FROM Employees)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = nil,  -- No alias provided (SQL Server requires this but parser should handle)
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2610,
        type = "parser",
        name = "Extra closing parenthesis",
        input = "SELECT * FROM (SELECT * FROM Employees) e)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
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

    -- Very complex nested queries
    {
        id = 2611,
        type = "parser",
        name = "Deeply nested subqueries (5 levels)",
        input = "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM Employees) l5) l4) l3) l2) l1",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "l1",
                            subqueries = {
                                {
                                    alias = "l2",
                                    subqueries = {
                                        {
                                            alias = "l3",
                                            subqueries = {
                                                {
                                                    alias = "l4",
                                                    subqueries = {
                                                        {
                                                            alias = "l5",
                                                            tables = {{ name = "Employees" }}
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    },

    -- Many JOINs
    {
        id = 2612,
        type = "parser",
        name = "Ten tables with JOINs",
        input = "SELECT * FROM T1 JOIN T2 ON T1.Id = T2.Id JOIN T3 ON T2.Id = T3.Id JOIN T4 ON T3.Id = T4.Id JOIN T5 ON T4.Id = T5.Id JOIN T6 ON T5.Id = T6.Id JOIN T7 ON T6.Id = T7.Id JOIN T8 ON T7.Id = T8.Id JOIN T9 ON T8.Id = T9.Id JOIN T10 ON T9.Id = T10.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "T1" }, { name = "T2" }, { name = "T3" }, { name = "T4" }, { name = "T5" },
                        { name = "T6" }, { name = "T7" }, { name = "T8" }, { name = "T9" }, { name = "T10" }
                    }
                }
            }
        }
    },

    -- INSERT with SELECT (should be ONE statement)
    {
        id = 2613,
        type = "parser",
        name = "INSERT INTO with SELECT - single statement",
        input = "INSERT INTO Backup SELECT * FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "Backup" },
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2614,
        type = "parser",
        name = "INSERT INTO with complex SELECT",
        input = "INSERT INTO Backup SELECT e.* FROM Employees e JOIN Departments d ON e.DeptId = d.Id WHERE d.Active = 1",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "Backup" },
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },

    -- Multiple GO separators
    {
        id = 2615,
        type = "parser",
        name = "Multiple consecutive GO",
        input = "SELECT * FROM Employees\nGO\nGO\nSELECT * FROM Departments",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }}, go_batch_index = 0 },
                { statement_type = "SELECT", tables = {{ name = "Departments" }}, go_batch_index = 2 }
            }
        }
    },
    {
        id = 2616,
        type = "parser",
        name = "GO at start",
        input = "GO\nSELECT * FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {{ name = "Employees" }},
                    go_batch_index = 1
                }
            }
        }
    },
    {
        id = 2617,
        type = "parser",
        name = "GO at end",
        input = "SELECT * FROM Employees\nGO",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {{ name = "Employees" }},
                    go_batch_index = 0
                }
            }
        }
    },
    {
        id = 2618,
        type = "parser",
        name = "GO with count (GO 5)",
        input = "SELECT * FROM Employees\nGO 5",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {{ name = "Employees" }},
                    go_batch_index = 0
                }
            }
        }
    },

    -- Unusual whitespace
    {
        id = 2619,
        type = "parser",
        name = "No spaces - compact query",
        input = "SELECT*FROM Employees e JOIN Departments d ON e.DeptId=d.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },
    {
        id = 2620,
        type = "parser",
        name = "Excessive spacing",
        input = "SELECT    *    FROM    Employees    e    WHERE    e.Active   =   1",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },
    {
        id = 2621,
        type = "parser",
        name = "Mixed tabs and spaces",
        input = "SELECT\t*\tFROM\t\tEmployees\t  e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    -- Case variations
    {
        id = 2622,
        type = "parser",
        name = "Mixed case keywords",
        input = "SeLeCt * FrOm Employees WhErE Active = 1",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2623,
        type = "parser",
        name = "Lowercase everything",
        input = "select * from employees e join departments d on e.deptid = d.id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "employees", alias = "e" },
                        { name = "departments", alias = "d" }
                    }
                }
            }
        }
    },

    -- Comments in various positions
    {
        id = 2624,
        type = "parser",
        name = "Comment in middle of query",
        input = "SELECT * FROM Employees -- Get all employees\nWHERE Active = 1",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2625,
        type = "parser",
        name = "Block comment in SELECT list",
        input = "SELECT Id, /* Name, */ Email FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2626,
        type = "parser",
        name = "Comment between table and alias",
        input = "SELECT * FROM Employees /* table */ e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    -- Strings containing keywords
    {
        id = 2627,
        type = "parser",
        name = "String containing SELECT",
        input = "SELECT * FROM Employees WHERE Name = 'SELECT'",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2628,
        type = "parser",
        name = "String containing FROM",
        input = "SELECT * FROM Employees WHERE Note = 'Data FROM server'",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- Special characters in identifiers
    {
        id = 2629,
        type = "parser",
        name = "Dollar sign in identifier",
        input = "SELECT * FROM $Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "$Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2630,
        type = "parser",
        name = "Hash in permanent table name",
        input = "SELECT * FROM Test#Table",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Test#Table" }
                    }
                }
            }
        }
    },

    -- Very long identifiers
    {
        id = 2631,
        type = "parser",
        name = "Very long table name (128 chars)",
        input = "SELECT * FROM ThisIsAVeryLongTableNameThatGoesOnAndOnAndOnForAVeryLongTimeToTestTheParserHandlingOfExtremelyLongIdentifiersInSQLQueriesWhichShouldStillWork",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "ThisIsAVeryLongTableNameThatGoesOnAndOnAndOnForAVeryLongTimeToTestTheParserHandlingOfExtremelyLongIdentifiersInSQLQueriesWhichShouldStillWork" }
                    }
                }
            }
        }
    },

    -- UNION statements
    -- Each SELECT in a UNION is its own chunk for proper autocompletion scoping
    {
        id = 2632,
        type = "parser",
        name = "Simple UNION",
        input = "SELECT * FROM Employees UNION SELECT * FROM Contractors",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
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
    {
        id = 2633,
        type = "parser",
        name = "UNION ALL",
        input = "SELECT * FROM Employees UNION ALL SELECT * FROM Contractors",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
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
    {
        id = 2634,
        type = "parser",
        name = "Three-way UNION",
        input = "SELECT * FROM T1 UNION SELECT * FROM T2 UNION SELECT * FROM T3",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "T1" }
                    }
                },
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "T2" }
                    }
                },
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "T3" }
                    }
                }
            }
        }
    },

    -- INTERSECT and EXCEPT
    {
        id = 2635,
        type = "parser",
        name = "INTERSECT",
        input = "SELECT * FROM Employees INTERSECT SELECT * FROM Contractors",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
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
    {
        id = 2636,
        type = "parser",
        name = "EXCEPT",
        input = "SELECT * FROM Employees EXCEPT SELECT * FROM Contractors",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
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

    -- Table hints (WITH NOLOCK, etc.)
    {
        id = 2637,
        type = "parser",
        name = "Table with NOLOCK hint",
        input = "SELECT * FROM Employees WITH (NOLOCK)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2638,
        type = "parser",
        name = "Table with multiple hints",
        input = "SELECT * FROM Employees WITH (NOLOCK, READPAST) e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    -- APPLY operators
    {
        id = 2639,
        type = "parser",
        name = "CROSS APPLY",
        input = "SELECT * FROM Employees e CROSS APPLY fn_GetOrders(e.Id) o",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },
    {
        id = 2640,
        type = "parser",
        name = "OUTER APPLY",
        input = "SELECT * FROM Employees e OUTER APPLY fn_GetOrders(e.Id) o",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    -- PIVOT and UNPIVOT
    {
        id = 2641,
        type = "parser",
        name = "PIVOT operator",
        input = "SELECT * FROM (SELECT Year, Quarter, Amount FROM Sales) s PIVOT (SUM(Amount) FOR Quarter IN (Q1, Q2, Q3, Q4)) p",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "s",
                            tables = {{ name = "Sales" }}
                        }
                    }
                }
            }
        }
    },

    -- MERGE statement
    {
        id = 2642,
        type = "parser",
        name = "MERGE statement",
        input = "MERGE INTO Target t USING Source s ON t.Id = s.Id WHEN MATCHED THEN UPDATE SET t.Value = s.Value",
        expected = {
            chunks = {
                {
                    statement_type = "MERGE",
                    tables = {
                        { name = "Target", alias = "t" },
                        { name = "Source", alias = "s" }
                    }
                }
            }
        }
    },

    -- Semicolon handling
    {
        id = 2643,
        type = "parser",
        name = "Statement ending with semicolon",
        input = "SELECT * FROM Employees;",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2644,
        type = "parser",
        name = "Multiple statements with semicolons",
        input = "SELECT * FROM Employees; SELECT * FROM Departments;",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }} },
                { statement_type = "SELECT", tables = {{ name = "Departments" }} }
            }
        }
    },

    -- Window functions
    {
        id = 2645,
        type = "parser",
        name = "Query with window function",
        input = "SELECT Id, Name, ROW_NUMBER() OVER (PARTITION BY DeptId ORDER BY Salary DESC) FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- XML and JSON functions
    {
        id = 2646,
        type = "parser",
        name = "Query with FOR XML",
        input = "SELECT * FROM Employees FOR XML AUTO",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2647,
        type = "parser",
        name = "Query with FOR JSON",
        input = "SELECT * FROM Employees FOR JSON AUTO",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- DECLARE and variables
    {
        id = 2648,
        type = "parser",
        name = "DECLARE statement",
        input = "DECLARE @Name VARCHAR(50)",
        expected = {
            chunks = {
                {
                    statement_type = "DECLARE"
                }
            }
        }
    },
    {
        id = 2649,
        type = "parser",
        name = "SET variable statement",
        input = "SET @Name = 'John'",
        expected = {
            chunks = {
                {
                    statement_type = "SET"
                }
            }
        }
    },

    -- Very large query
    {
        id = 2650,
        type = "parser",
        name = "Large complex query with all features",
        input = [[
WITH ActiveEmployees AS (
    SELECT * FROM dbo.Employees WHERE Active = 1
),
DeptStats AS (
    SELECT
        DeptId,
        COUNT(*) AS EmpCount,
        AVG(Salary) AS AvgSalary
    FROM ActiveEmployees
    GROUP BY DeptId
    HAVING COUNT(*) > 5
)
SELECT
    e.Id,
    e.Name,
    e.Email,
    d.Name AS DepartmentName,
    l.City,
    ds.AvgSalary,
    CASE
        WHEN e.Salary > ds.AvgSalary THEN 'Above Average'
        WHEN e.Salary = ds.AvgSalary THEN 'Average'
        ELSE 'Below Average'
    END AS SalaryStatus,
    (SELECT COUNT(*) FROM Orders o WHERE o.EmployeeId = e.Id) AS OrderCount
INTO #EmployeeReport
FROM ActiveEmployees e
INNER JOIN Departments d WITH (NOLOCK) ON e.DeptId = d.Id
LEFT JOIN Locations l ON d.LocationId = l.Id
INNER JOIN DeptStats ds ON e.DeptId = ds.DeptId
WHERE e.HireDate > '2020-01-01'
    AND e.Salary > (SELECT AVG(Salary) FROM Employees)
    AND e.DeptId IN (SELECT Id FROM Departments WHERE Region = 'US')
ORDER BY e.Name
]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",  -- CTE queries still report as SELECT for completion
                    temp_table_name = "#EmployeeReport",
                    ctes = {
                        { name = "ActiveEmployees" },
                        { name = "DeptStats" }
                    },
                    tables = {
                        { name = "Departments", alias = "d" },
                        { name = "Locations", alias = "l" }
                    }
                }
            }
        }
    },
}
