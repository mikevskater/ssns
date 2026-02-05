-- Test file: subqueries.lua
-- IDs: 2301-2350
-- Tests: Subquery parsing including nested subqueries and correlated subqueries

return {
    -- Subquery in FROM clause
    {
        id = 2301,
        type = "parser",
        name = "Subquery in FROM with alias",
        input = "SELECT * FROM (SELECT Id, Name FROM Employees) e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "e"
                        }
                    }
                }
            }
        }
    },
    {
        id = 2302,
        type = "parser",
        name = "Subquery in FROM with AS alias",
        input = "SELECT * FROM (SELECT Id, Name FROM Employees) AS e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "e"
                        }
                    }
                }
            }
        }
    },
    {
        id = 2303,
        type = "parser",
        name = "Subquery accessing real table",
        input = "SELECT * FROM (SELECT * FROM Employees WHERE Active = 1) e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "e",
                            tables = {
                                { name = "Employees" }
                            }
                        }
                    }
                }
            }
        }
    },
    {
        id = 2304,
        type = "parser",
        name = "Subquery with schema qualified table",
        input = "SELECT * FROM (SELECT * FROM dbo.Employees) e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "e",
                            tables = {
                                { name = "Employees", schema = "dbo" }
                            }
                        }
                    }
                }
            }
        }
    },

    -- Multiple subqueries in FROM
    {
        id = 2305,
        type = "parser",
        name = "Two subqueries in FROM with JOIN",
        input = "SELECT * FROM (SELECT * FROM Employees) e JOIN (SELECT * FROM Departments) d ON e.DeptId = d.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "e",
                            tables = {{ name = "Employees" }}
                        },
                        {
                            alias = "d",
                            tables = {{ name = "Departments" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2306,
        type = "parser",
        name = "Subquery and real table JOIN",
        input = "SELECT * FROM (SELECT * FROM Employees WHERE Active = 1) e JOIN Departments d ON e.DeptId = d.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Departments", alias = "d" }
                    },
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

    -- Nested subqueries (2 levels)
    {
        id = 2307,
        type = "parser",
        name = "Nested subquery - 2 levels",
        input = "SELECT * FROM (SELECT * FROM (SELECT Id FROM Employees) inner_sub) outer_sub",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "outer_sub",
                            subqueries = {
                                {
                                    alias = "inner_sub",
                                    tables = {{ name = "Employees" }}
                                }
                            }
                        }
                    }
                }
            }
        }
    },
    {
        id = 2308,
        type = "parser",
        name = "Nested subquery with real tables at each level",
        input = "SELECT * FROM (SELECT * FROM (SELECT * FROM Employees) e WHERE e.Active = 1) active_emps",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "active_emps",
                            subqueries = {
                                {
                                    alias = "e",
                                    tables = {{ name = "Employees" }}
                                }
                            }
                        }
                    }
                }
            }
        }
    },

    -- Nested subqueries (3 levels)
    {
        id = 2309,
        type = "parser",
        name = "Nested subquery - 3 levels",
        input = "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT Id FROM Employees) level3) level2) level1",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "level1",
                            subqueries = {
                                {
                                    alias = "level2",
                                    subqueries = {
                                        {
                                            alias = "level3",
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
    },

    -- Subquery in WHERE clause
    {
        id = 2310,
        type = "parser",
        name = "Subquery in WHERE with IN",
        input = "SELECT * FROM Employees WHERE DeptId IN (SELECT Id FROM Departments WHERE Active = 1)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        {
                            tables = {{ name = "Departments" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2311,
        type = "parser",
        name = "Subquery in WHERE with comparison",
        input = "SELECT * FROM Employees WHERE Salary > (SELECT AVG(Salary) FROM Employees)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        {
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2312,
        type = "parser",
        name = "Subquery in WHERE with EXISTS",
        input = "SELECT * FROM Employees e WHERE EXISTS (SELECT 1 FROM Orders o WHERE o.EmployeeId = e.Id)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    },
                    subqueries = {
                        {
                            tables = {{ name = "Orders", alias = "o" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2313,
        type = "parser",
        name = "Subquery in WHERE with NOT EXISTS",
        input = "SELECT * FROM Employees e WHERE NOT EXISTS (SELECT 1 FROM Orders o WHERE o.EmployeeId = e.Id)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    },
                    subqueries = {
                        {
                            tables = {{ name = "Orders", alias = "o" }}
                        }
                    }
                }
            }
        }
    },

    -- Correlated subquery
    {
        id = 2314,
        type = "parser",
        name = "Correlated subquery",
        input = "SELECT * FROM Employees e WHERE Salary > (SELECT AVG(Salary) FROM Employees e2 WHERE e2.DeptId = e.DeptId)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    },
                    subqueries = {
                        {
                            tables = {{ name = "Employees", alias = "e2" }}
                        }
                    }
                }
            }
        }
    },

    -- Multiple subqueries in WHERE
    {
        id = 2315,
        type = "parser",
        name = "Multiple subqueries in WHERE",
        input = "SELECT * FROM Employees WHERE DeptId IN (SELECT Id FROM Departments) AND ManagerId IN (SELECT Id FROM Managers)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        { tables = {{ name = "Departments" }} },
                        { tables = {{ name = "Managers" }} }
                    }
                }
            }
        }
    },

    -- Subquery in SELECT list
    {
        id = 2316,
        type = "parser",
        name = "Subquery in SELECT list",
        input = "SELECT Id, Name, (SELECT COUNT(*) FROM Orders WHERE EmployeeId = Employees.Id) FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        {
                            tables = {{ name = "Orders" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2317,
        type = "parser",
        name = "Multiple subqueries in SELECT list",
        input = "SELECT Id, (SELECT COUNT(*) FROM Orders WHERE EmployeeId = Employees.Id), (SELECT SUM(Amount) FROM Sales WHERE EmployeeId = Employees.Id) FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        { tables = {{ name = "Orders" }} },
                        { tables = {{ name = "Sales" }} }
                    }
                }
            }
        }
    },

    -- Subquery with JOIN inside
    {
        id = 2318,
        type = "parser",
        name = "Subquery containing JOIN",
        input = "SELECT * FROM (SELECT e.*, d.Name AS DeptName FROM Employees e JOIN Departments d ON e.DeptId = d.Id) sub",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "sub",
                            tables = {
                                { name = "Employees", alias = "e" },
                                { name = "Departments", alias = "d" }
                            }
                        }
                    }
                }
            }
        }
    },

    -- Subquery in HAVING clause
    {
        id = 2319,
        type = "parser",
        name = "Subquery in HAVING clause",
        input = "SELECT DeptId, COUNT(*) FROM Employees GROUP BY DeptId HAVING COUNT(*) > (SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM Employees GROUP BY DeptId) sub)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        {
                            subqueries = {
                                {
                                    alias = "sub",
                                    tables = {{ name = "Employees" }}
                                }
                            }
                        }
                    }
                }
            }
        }
    },

    -- Subquery in JOIN
    {
        id = 2320,
        type = "parser",
        name = "Subquery in JOIN",
        input = "SELECT * FROM Employees e JOIN (SELECT DeptId, COUNT(*) AS EmpCount FROM Employees GROUP BY DeptId) dept_counts ON e.DeptId = dept_counts.DeptId",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    },
                    subqueries = {
                        {
                            alias = "dept_counts",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2321,
        type = "parser",
        name = "Multiple subqueries in multiple JOINs",
        input = "SELECT * FROM Employees e JOIN (SELECT * FROM Departments) d ON e.DeptId = d.Id LEFT JOIN (SELECT * FROM Locations) loc ON d.LocationId = loc.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    },
                    subqueries = {
                        {
                            alias = "d",
                            tables = {{ name = "Departments" }}
                        },
                        {
                            alias = "loc",
                            tables = {{ name = "Locations" }}
                        }
                    }
                }
            }
        }
    },

    -- Subquery with UNION
    {
        id = 2322,
        type = "parser",
        name = "Subquery containing UNION",
        input = "SELECT * FROM (SELECT Id FROM Employees UNION SELECT Id FROM Contractors) all_workers",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "all_workers",
                            tables = {
                                { name = "Employees" },
                                { name = "Contractors" }
                            }
                        }
                    }
                }
            }
        }
    },

    -- Subquery with aggregate functions
    {
        id = 2323,
        type = "parser",
        name = "Subquery with aggregates",
        input = "SELECT * FROM (SELECT DeptId, AVG(Salary) AS AvgSalary, COUNT(*) AS EmpCount FROM Employees GROUP BY DeptId) dept_stats",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "dept_stats",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },

    -- Complex nested scenario
    {
        id = 2324,
        type = "parser",
        name = "Complex nested subquery scenario",
        input = [[SELECT *
FROM (
    SELECT e.*, d.Name AS DeptName
    FROM Employees e
    JOIN (
        SELECT Id, Name FROM Departments WHERE Active = 1
    ) d ON e.DeptId = d.Id
    WHERE e.Salary > (SELECT AVG(Salary) FROM Employees)
) active_emp_with_dept]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "active_emp_with_dept",
                            tables = {
                                { name = "Employees", alias = "e" }
                            },
                            subqueries = {
                                {
                                    alias = "d",
                                    tables = {{ name = "Departments" }}
                                },
                                {
                                    tables = {{ name = "Employees" }}
                                }
                            }
                        }
                    }
                }
            }
        }
    },

    -- Subquery with ORDER BY and TOP
    {
        id = 2325,
        type = "parser",
        name = "Subquery with TOP",
        input = "SELECT * FROM (SELECT TOP 10 * FROM Employees ORDER BY Salary DESC) top_earners",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "top_earners",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },

    -- Subquery with temp table
    {
        id = 2326,
        type = "parser",
        name = "Subquery accessing temp table",
        input = "SELECT * FROM (SELECT * FROM #TempData) t",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "t",
                            tables = {{ name = "#TempData", is_temp = true }}
                        }
                    }
                }
            }
        }
    },

    -- Verify start_pos and end_pos are set
    {
        id = 2327,
        type = "parser",
        name = "Subquery position tracking",
        input = "SELECT * FROM (SELECT Id FROM Employees) e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "e",
                            start_pos = { line = 1, col = 16 },  -- Position of opening (
                            end_pos = { line = 1, col = 40 }     -- Position of closing )
                        }
                    }
                }
            }
        }
    },

    -- Subquery in UPDATE statement
    {
        id = 2328,
        type = "parser",
        name = "Subquery in UPDATE",
        input = "UPDATE Employees SET Salary = Salary * 1.1 WHERE DeptId IN (SELECT Id FROM Departments WHERE Region = 'US')",
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        {
                            tables = {{ name = "Departments" }}
                        }
                    }
                }
            }
        }
    },

    -- Subquery in DELETE statement
    {
        id = 2329,
        type = "parser",
        name = "Subquery in DELETE",
        input = "DELETE FROM Employees WHERE DeptId IN (SELECT Id FROM Departments WHERE Active = 0)",
        expected = {
            chunks = {
                {
                    statement_type = "DELETE",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        {
                            tables = {{ name = "Departments" }}
                        }
                    }
                }
            }
        }
    },

    -- Subquery with DISTINCT
    {
        id = 2330,
        type = "parser",
        name = "Subquery with DISTINCT",
        input = "SELECT * FROM (SELECT DISTINCT DeptId FROM Employees) unique_depts",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    subqueries = {
                        {
                            alias = "unique_depts",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },

    -- Subquery in SET statement (variable assignment)
    {
        id = 2331,
        type = "parser",
        name = "Subquery in SET variable assignment",
        input = "SET @Count = (SELECT COUNT(*) FROM Employees)",
        expected = {
            chunks = {
                {
                    statement_type = "SET",
                    subqueries = {
                        {
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2332,
        type = "parser",
        name = "SET with subquery and schema qualified table",
        input = "SET @Result = (SELECT TOP 1 Id FROM dbo.Customers WHERE Active = 1)",
        expected = {
            chunks = {
                {
                    statement_type = "SET",
                    subqueries = {
                        {
                            tables = {{ name = "Customers", schema = "dbo" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2333,
        type = "parser",
        name = "SET with nested subquery",
        input = "SET @MaxSalary = (SELECT MAX(Salary) FROM (SELECT Salary FROM Employees WHERE DeptId = 1) e)",
        expected = {
            chunks = {
                {
                    statement_type = "SET",
                    subqueries = {
                        {
                            subqueries = {
                                {
                                    alias = "e",
                                    tables = {{ name = "Employees" }}
                                }
                            }
                        }
                    }
                }
            }
        }
    },

    -- Subquery in UPDATE SET clause
    {
        id = 2334,
        type = "parser",
        name = "Subquery in UPDATE SET clause",
        input = "UPDATE Employees SET Salary = (SELECT AVG(Salary) FROM Employees)",
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        {
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2335,
        type = "parser",
        name = "UPDATE SET with multiple subqueries",
        input = "UPDATE Employees SET Salary = (SELECT AVG(Salary) FROM Employees), DeptId = (SELECT Id FROM Departments WHERE Name = 'IT')",
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        { tables = {{ name = "Employees" }} },
                        { tables = {{ name = "Departments" }} }
                    }
                }
            }
        }
    },
    {
        id = 2336,
        type = "parser",
        name = "UPDATE SET with subquery and WHERE with subquery",
        input = "UPDATE Employees SET Salary = (SELECT AVG(Salary) FROM Employees) WHERE DeptId IN (SELECT Id FROM Departments WHERE Active = 1)",
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    tables = {
                        { name = "Employees" }
                    },
                    subqueries = {
                        { tables = {{ name = "Employees" }} },
                        { tables = {{ name = "Departments" }} }
                    }
                }
            }
        }
    },
    {
        id = 2337,
        type = "parser",
        name = "SET with scalar subquery and arithmetic",
        input = "SET @Total = (SELECT SUM(Amount) FROM Orders) + (SELECT SUM(Amount) FROM Returns)",
        expected = {
            chunks = {
                {
                    statement_type = "SET",
                    subqueries = {
                        { tables = {{ name = "Orders" }} },
                        { tables = {{ name = "Returns" }} }
                    }
                }
            }
        }
    },
}
