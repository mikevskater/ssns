-- Test file: ctes.lua
-- IDs: 2401-2450
-- Tests: Common Table Expression (CTE / WITH clause) parsing

return {
    -- Simple CTE
    {
        id = 2401,
        type = "parser",
        name = "Simple CTE",
        input = "WITH cte AS (SELECT * FROM Employees) SELECT * FROM cte",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "cte"
                        }
                    }
                }
            }
        }
    },
    {
        id = 2402,
        type = "parser",
        name = "CTE accessing table",
        input = "WITH EmployeeCTE AS (SELECT Id, Name FROM Employees WHERE Active = 1) SELECT * FROM EmployeeCTE",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "EmployeeCTE",
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
        id = 2403,
        type = "parser",
        name = "CTE with schema qualified table",
        input = "WITH cte AS (SELECT * FROM dbo.Employees) SELECT * FROM cte",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "cte",
                            tables = {
                                { name = "Employees", schema = "dbo" }
                            }
                        }
                    }
                }
            }
        }
    },

    -- Multiple CTEs
    {
        id = 2404,
        type = "parser",
        name = "Two CTEs",
        input = "WITH cte1 AS (SELECT * FROM Employees), cte2 AS (SELECT * FROM Departments) SELECT * FROM cte1 JOIN cte2 ON cte1.DeptId = cte2.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "cte1",
                            tables = {{ name = "Employees" }}
                        },
                        {
                            name = "cte2",
                            tables = {{ name = "Departments" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2405,
        type = "parser",
        name = "Three CTEs",
        input = "WITH cte1 AS (SELECT * FROM Employees), cte2 AS (SELECT * FROM Departments), cte3 AS (SELECT * FROM Locations) SELECT * FROM cte1",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "cte1", tables = {{ name = "Employees" }} },
                        { name = "cte2", tables = {{ name = "Departments" }} },
                        { name = "cte3", tables = {{ name = "Locations" }} }
                    }
                }
            }
        }
    },

    -- CTE with column list
    {
        id = 2406,
        type = "parser",
        name = "CTE with column list",
        input = "WITH EmployeeCTE (Id, Name, Department) AS (SELECT EmployeeId, FullName, DeptName FROM Employees) SELECT * FROM EmployeeCTE",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",  -- CTE queries still report as SELECT for completion
                    ctes = {
                        {
                            name = "EmployeeCTE",
                            columns = { "Id", "Name", "Department" },
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2407,
        type = "parser",
        name = "Multiple CTEs with column lists",
        input = "WITH cte1 (Id, Name) AS (SELECT * FROM Employees), cte2 (DeptId, DeptName) AS (SELECT * FROM Departments) SELECT * FROM cte1",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",  -- CTE queries still report as SELECT for completion
                    ctes = {
                        {
                            name = "cte1",
                            columns = { "Id", "Name" },
                            tables = {{ name = "Employees" }}
                        },
                        {
                            name = "cte2",
                            columns = { "DeptId", "DeptName" },
                            tables = {{ name = "Departments" }}
                        }
                    }
                }
            }
        }
    },

    -- Recursive CTE
    {
        id = 2408,
        type = "parser",
        name = "Recursive CTE - self reference",
        input = "WITH EmployeeHierarchy AS (SELECT Id, Name, ManagerId FROM Employees WHERE ManagerId IS NULL UNION ALL SELECT e.Id, e.Name, e.ManagerId FROM Employees e JOIN EmployeeHierarchy eh ON e.ManagerId = eh.Id) SELECT * FROM EmployeeHierarchy",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "EmployeeHierarchy",
                            tables = {
                                { name = "Employees" },
                                { name = "Employees", alias = "e" }
                            }
                        }
                    }
                }
            }
        }
    },
    {
        id = 2409,
        type = "parser",
        name = "Recursive CTE with column list",
        input = "WITH OrgChart (EmpId, EmpName, Level) AS (SELECT Id, Name, 0 FROM Employees WHERE ManagerId IS NULL UNION ALL SELECT e.Id, e.Name, oc.Level + 1 FROM Employees e JOIN OrgChart oc ON e.ManagerId = oc.EmpId) SELECT * FROM OrgChart",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",  -- CTE queries still report as SELECT for completion
                    ctes = {
                        {
                            name = "OrgChart",
                            columns = { "EmpId", "EmpName", "Level" },
                            tables = {
                                { name = "Employees" },
                                { name = "Employees", alias = "e" }
                            }
                        }
                    }
                }
            }
        }
    },

    -- CTE used in JOIN
    {
        id = 2410,
        type = "parser",
        name = "CTE used in JOIN with real table",
        input = "WITH ActiveEmployees AS (SELECT * FROM Employees WHERE Active = 1) SELECT * FROM ActiveEmployees ae JOIN Departments d ON ae.DeptId = d.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "ActiveEmployees",
                            tables = {{ name = "Employees" }}
                        }
                    },
                    tables = {
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },
    {
        id = 2411,
        type = "parser",
        name = "Two CTEs both used in JOIN",
        input = "WITH EmpCTE AS (SELECT * FROM Employees), DeptCTE AS (SELECT * FROM Departments) SELECT * FROM EmpCTE e JOIN DeptCTE d ON e.DeptId = d.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "EmpCTE", tables = {{ name = "Employees" }} },
                        { name = "DeptCTE", tables = {{ name = "Departments" }} }
                    }
                }
            }
        }
    },

    -- CTE used multiple times
    {
        id = 2412,
        type = "parser",
        name = "CTE referenced twice (self-join)",
        input = "WITH EmployeeCTE AS (SELECT * FROM Employees) SELECT * FROM EmployeeCTE e1 JOIN EmployeeCTE e2 ON e1.ManagerId = e2.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "EmployeeCTE",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },

    -- CTE with JOIN inside
    {
        id = 2413,
        type = "parser",
        name = "CTE containing JOIN",
        input = "WITH EmpDept AS (SELECT e.*, d.Name AS DeptName FROM Employees e JOIN Departments d ON e.DeptId = d.Id) SELECT * FROM EmpDept",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "EmpDept",
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
    {
        id = 2414,
        type = "parser",
        name = "CTE with multiple JOINs",
        input = "WITH ComplexCTE AS (SELECT * FROM Employees e JOIN Departments d ON e.DeptId = d.Id JOIN Locations l ON d.LocationId = l.Id) SELECT * FROM ComplexCTE",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "ComplexCTE",
                            tables = {
                                { name = "Employees", alias = "e" },
                                { name = "Departments", alias = "d" },
                                { name = "Locations", alias = "l" }
                            }
                        }
                    }
                }
            }
        }
    },

    -- CTE with subquery
    {
        id = 2415,
        type = "parser",
        name = "CTE containing subquery",
        input = "WITH CTE AS (SELECT * FROM Employees WHERE DeptId IN (SELECT Id FROM Departments WHERE Active = 1)) SELECT * FROM CTE",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",  -- CTE queries still report as SELECT for completion
                    ctes = {
                        {
                            name = "CTE",
                            tables = {{ name = "Employees" }},
                            subqueries = {
                                { tables = {{ name = "Departments" }} }
                            }
                        }
                    }
                }
            }
        }
    },

    -- CTE with aggregate functions
    {
        id = 2416,
        type = "parser",
        name = "CTE with aggregates and GROUP BY",
        input = "WITH DeptStats AS (SELECT DeptId, COUNT(*) AS EmpCount, AVG(Salary) AS AvgSalary FROM Employees GROUP BY DeptId) SELECT * FROM DeptStats",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "DeptStats",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },

    -- Multiline formatted CTE
    {
        id = 2417,
        type = "parser",
        name = "Multiline formatted CTE",
        input = [[WITH EmployeeCTE AS (
    SELECT Id, Name, DeptId
    FROM Employees
    WHERE Active = 1
)
SELECT * FROM EmployeeCTE]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "EmployeeCTE",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },
    {
        id = 2418,
        type = "parser",
        name = "Multiple CTEs multiline",
        input = [[WITH
    EmployeeCTE AS (
        SELECT * FROM Employees WHERE Active = 1
    ),
    DeptCTE AS (
        SELECT * FROM Departments WHERE Active = 1
    )
SELECT * FROM EmployeeCTE e JOIN DeptCTE d ON e.DeptId = d.Id]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "EmployeeCTE", tables = {{ name = "Employees" }} },
                        { name = "DeptCTE", tables = {{ name = "Departments" }} }
                    }
                }
            }
        }
    },

    -- CTE with UNION
    {
        id = 2419,
        type = "parser",
        name = "CTE with UNION",
        input = "WITH AllWorkers AS (SELECT Id, Name FROM Employees UNION SELECT Id, Name FROM Contractors) SELECT * FROM AllWorkers",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "AllWorkers",
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

    -- CTE with ORDER BY and TOP
    {
        id = 2420,
        type = "parser",
        name = "CTE with TOP",
        input = "WITH TopEarners AS (SELECT TOP 10 * FROM Employees ORDER BY Salary DESC) SELECT * FROM TopEarners",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "TopEarners",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },

    -- CTE referencing another CTE
    {
        id = 2421,
        type = "parser",
        name = "CTE referencing another CTE",
        input = "WITH CTE1 AS (SELECT * FROM Employees), CTE2 AS (SELECT * FROM CTE1 WHERE Active = 1) SELECT * FROM CTE2",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "CTE1", tables = {{ name = "Employees" }} },
                        { name = "CTE2" }  -- References CTE1, not a real table
                    }
                }
            }
        }
    },
    {
        id = 2422,
        type = "parser",
        name = "Three CTEs with chained references",
        input = "WITH CTE1 AS (SELECT * FROM Employees), CTE2 AS (SELECT * FROM CTE1), CTE3 AS (SELECT * FROM CTE2) SELECT * FROM CTE3",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "CTE1", tables = {{ name = "Employees" }} },
                        { name = "CTE2" },
                        { name = "CTE3" }
                    }
                }
            }
        }
    },

    -- CTE in INSERT statement
    {
        id = 2423,
        type = "parser",
        name = "CTE in INSERT",
        input = "WITH SourceData AS (SELECT * FROM Employees WHERE Active = 1) INSERT INTO EmployeeBackup SELECT * FROM SourceData",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    ctes = {
                        {
                            name = "SourceData",
                            tables = {{ name = "Employees" }}
                        }
                    },
                    tables = {
                        { name = "EmployeeBackup" }
                    }
                }
            }
        }
    },

    -- CTE in UPDATE statement
    {
        id = 2424,
        type = "parser",
        name = "CTE in UPDATE",
        input = "WITH InactiveDepts AS (SELECT Id FROM Departments WHERE Active = 0) UPDATE Employees SET Active = 0 WHERE DeptId IN (SELECT Id FROM InactiveDepts)",
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    ctes = {
                        {
                            name = "InactiveDepts",
                            tables = {{ name = "Departments" }}
                        }
                    },
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- CTE in DELETE statement
    {
        id = 2425,
        type = "parser",
        name = "CTE in DELETE",
        input = "WITH OldRecords AS (SELECT Id FROM Employees WHERE LastLoginDate < '2020-01-01') DELETE FROM Employees WHERE Id IN (SELECT Id FROM OldRecords)",
        expected = {
            chunks = {
                {
                    statement_type = "DELETE",
                    ctes = {
                        {
                            name = "OldRecords",
                            tables = {{ name = "Employees" }}
                        }
                    },
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },

    -- CTE with temp table
    {
        id = 2426,
        type = "parser",
        name = "CTE accessing temp table",
        input = "WITH TempCTE AS (SELECT * FROM #TempData) SELECT * FROM TempCTE",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "TempCTE",
                            tables = {{ name = "#TempData", is_temp = true }}
                        }
                    }
                }
            }
        }
    },

    -- CTE with schema qualification
    {
        id = 2427,
        type = "parser",
        name = "CTE with different schemas",
        input = "WITH SalesCTE AS (SELECT * FROM sales.Orders), HrCTE AS (SELECT * FROM hr.Employees) SELECT * FROM SalesCTE s JOIN HrCTE h ON s.EmployeeId = h.Id",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        { name = "SalesCTE", tables = {{ name = "Orders", schema = "sales" }} },
                        { name = "HrCTE", tables = {{ name = "Employees", schema = "hr" }} }
                    }
                }
            }
        }
    },

    -- CTE with WHERE and complex conditions
    {
        id = 2428,
        type = "parser",
        name = "CTE with complex WHERE",
        input = "WITH FilteredData AS (SELECT * FROM Employees WHERE Age > 30 AND Department = 'IT' AND Salary > 50000) SELECT * FROM FilteredData",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "FilteredData",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },

    -- CTE with HAVING
    {
        id = 2429,
        type = "parser",
        name = "CTE with GROUP BY and HAVING",
        input = "WITH LargeDepts AS (SELECT DeptId, COUNT(*) AS EmpCount FROM Employees GROUP BY DeptId HAVING COUNT(*) > 10) SELECT * FROM LargeDepts",
        expected = {
            chunks = {
                {
                    statement_type = "WITH",
                    ctes = {
                        {
                            name = "LargeDepts",
                            tables = {{ name = "Employees" }}
                        }
                    }
                }
            }
        }
    },

    -- Complex nested CTE scenario
    {
        id = 2430,
        type = "parser",
        name = "Complex CTE with nested queries",
        input = [[WITH
    ActiveEmps AS (
        SELECT * FROM Employees WHERE Active = 1
    ),
    DeptStats AS (
        SELECT
            e.DeptId,
            COUNT(*) AS EmpCount,
            AVG(e.Salary) AS AvgSalary
        FROM ActiveEmps e
        WHERE e.Salary > (SELECT AVG(Salary) FROM Employees)
        GROUP BY e.DeptId
    )
SELECT
    d.Name,
    ds.EmpCount,
    ds.AvgSalary
FROM DeptStats ds
JOIN Departments d ON ds.DeptId = d.Id]],
        expected = {
            chunks = {
                {
                    statement_type = "WITH",
                    ctes = {
                        { name = "ActiveEmps", tables = {{ name = "Employees" }} },
                        {
                            name = "DeptStats",
                            subqueries = {
                                { tables = {{ name = "Employees" }} }
                            }
                        }
                    },
                    tables = {
                        { name = "Departments", alias = "d" }
                    }
                }
            }
        }
    },
}
