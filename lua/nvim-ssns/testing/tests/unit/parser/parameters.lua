-- Test file: parameters.lua
-- IDs: 2851-2880
-- Tests: Parameter tracking for IntelliSense (user parameters and system variables)

return {
    -- ========================================
    -- 2851-2855: Basic Parameters
    -- ========================================

    {
        id = 2851,
        type = "parser",
        name = "Single parameter in WHERE",
        input = "SELECT * FROM Employees WHERE DepartmentID = @DeptId",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "DeptId", full_name = "@DeptId", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2852,
        type = "parser",
        name = "Multiple parameters in WHERE",
        input = "SELECT * FROM Employees WHERE DepartmentID = @DeptId AND Salary > @MinSalary AND Status = @Status",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "DeptId", full_name = "@DeptId", is_system = false },
                        { name = "MinSalary", full_name = "@MinSalary", is_system = false },
                        { name = "Status", full_name = "@Status", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2853,
        type = "parser",
        name = "System variable (@@ROWCOUNT)",
        input = "SELECT @@ROWCOUNT AS AffectedRows",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "ROWCOUNT", full_name = "@@ROWCOUNT", is_system = true }
                    }
                }
            }
        }
    },

    {
        id = 2854,
        type = "parser",
        name = "Mixed user params and system vars",
        input = "SELECT EmployeeID, @@IDENTITY AS NewId FROM Employees WHERE DepartmentID = @DeptId",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "IDENTITY", full_name = "@@IDENTITY", is_system = true },
                        { name = "DeptId", full_name = "@DeptId", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2855,
        type = "parser",
        name = "Parameter in SELECT clause",
        input = "SELECT @EmployeeName AS EmpName, EmployeeID FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "EmployeeName", full_name = "@EmployeeName", is_system = false }
                    }
                }
            }
        }
    },

    -- ========================================
    -- 2856-2860: Parameters in Different Statements
    -- ========================================

    {
        id = 2856,
        type = "parser",
        name = "INSERT with parameters",
        input = "INSERT INTO Employees (FirstName, LastName, DepartmentID) VALUES (@FirstName, @LastName, @DeptId)",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    parameters = {
                        { name = "FirstName", full_name = "@FirstName", is_system = false },
                        { name = "LastName", full_name = "@LastName", is_system = false },
                        { name = "DeptId", full_name = "@DeptId", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2857,
        type = "parser",
        name = "UPDATE with parameters",
        input = "UPDATE Employees SET Salary = @NewSalary, Status = @Status WHERE EmployeeID = @EmpId",
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    parameters = {
                        { name = "NewSalary", full_name = "@NewSalary", is_system = false },
                        { name = "Status", full_name = "@Status", is_system = false },
                        { name = "EmpId", full_name = "@EmpId", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2858,
        type = "parser",
        name = "DELETE with parameter",
        input = "DELETE FROM Employees WHERE DepartmentID = @DeptId",
        expected = {
            chunks = {
                {
                    statement_type = "DELETE",
                    parameters = {
                        { name = "DeptId", full_name = "@DeptId", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2859,
        type = "parser",
        name = "EXEC with parameters",
        input = "EXEC sp_GetEmployees @DeptId, @Status",
        expected = {
            chunks = {
                {
                    statement_type = "EXEC",
                    parameters = {
                        { name = "DeptId", full_name = "@DeptId", is_system = false },
                        { name = "Status", full_name = "@Status", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2860,
        type = "parser",
        name = "MERGE with parameters",
        input = "MERGE INTO Employees AS target USING EmployeeUpdates AS source ON target.EmployeeID = source.EmployeeID WHEN MATCHED THEN UPDATE SET Salary = @NewSalary",
        expected = {
            chunks = {
                {
                    statement_type = "MERGE",
                    parameters = {
                        { name = "NewSalary", full_name = "@NewSalary", is_system = false }
                    }
                }
            }
        }
    },

    -- ========================================
    -- 2861-2865: DECLARE and SET
    -- ========================================

    {
        id = 2861,
        type = "parser",
        name = "DECLARE statement",
        input = "DECLARE @EmpId INT",
        expected = {
            chunks = {
                {
                    statement_type = "DECLARE",
                    parameters = {
                        { name = "EmpId", full_name = "@EmpId", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2862,
        type = "parser",
        name = "SET statement with parameter",
        input = "SET @EmpId = 123",
        expected = {
            chunks = {
                {
                    statement_type = "SET",
                    parameters = {
                        { name = "EmpId", full_name = "@EmpId", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2863,
        type = "parser",
        name = "Multiple DECLARE",
        input = "DECLARE @EmpId INT, @DeptId INT, @Status VARCHAR(50)",
        expected = {
            chunks = {
                {
                    statement_type = "DECLARE",
                    parameters = {
                        { name = "EmpId", full_name = "@EmpId", is_system = false },
                        { name = "DeptId", full_name = "@DeptId", is_system = false },
                        { name = "Status", full_name = "@Status", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2864,
        type = "parser",
        name = "SET with expression",
        input = "SET @Total = @Price * @Quantity",
        expected = {
            chunks = {
                {
                    statement_type = "SET",
                    parameters = {
                        { name = "Total", full_name = "@Total", is_system = false },
                        { name = "Price", full_name = "@Price", is_system = false },
                        { name = "Quantity", full_name = "@Quantity", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2865,
        type = "parser",
        name = "DECLARE with initial value",
        input = "DECLARE @EmpId INT = 123",
        expected = {
            chunks = {
                {
                    statement_type = "DECLARE",
                    parameters = {
                        { name = "EmpId", full_name = "@EmpId", is_system = false }
                    }
                }
            }
        }
    },

    -- ========================================
    -- 2866-2870: Table Variables
    -- ========================================

    {
        id = 2866,
        type = "parser",
        name = "Table variable in FROM",
        input = "SELECT * FROM @EmployeeTable",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "@EmployeeTable", is_table_variable = true }
                    }
                }
            }
        }
    },

    {
        id = 2867,
        type = "parser",
        name = "Table variable with alias",
        input = "SELECT e.EmployeeID FROM @EmployeeTable e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "@EmployeeTable", alias = "e", is_table_variable = true }
                    }
                }
            }
        }
    },

    {
        id = 2868,
        type = "parser",
        name = "INSERT INTO table variable",
        input = "INSERT INTO @EmployeeTable (EmployeeID, FirstName) VALUES (1, 'John')",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "@EmployeeTable", is_table_variable = true }
                    }
                }
            }
        }
    },

    {
        id = 2869,
        type = "parser",
        name = "Table variable in JOIN",
        input = "SELECT e.EmployeeID, t.FirstName FROM Employees e JOIN @EmployeeTable t ON e.EmployeeID = t.EmployeeID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" },
                        { name = "@EmployeeTable", alias = "t", is_table_variable = true }
                    }
                }
            }
        }
    },

    {
        id = 2870,
        type = "parser",
        name = "Multiple table variables",
        input = "SELECT * FROM @EmployeeTable e JOIN @DepartmentTable d ON e.DepartmentID = d.DepartmentID",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "@EmployeeTable", alias = "e", is_table_variable = true },
                        { name = "@DepartmentTable", alias = "d", is_table_variable = true }
                    }
                }
            }
        }
    },

    -- ========================================
    -- 2871-2875: Parameters in Subqueries/CTEs
    -- ========================================

    {
        id = 2871,
        type = "parser",
        name = "Parameter in subquery",
        input = "SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM Departments WHERE Budget > @MinBudget)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "MinBudget", full_name = "@MinBudget", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2872,
        type = "parser",
        name = "Parameter in CTE definition",
        input = "WITH EmployeeCTE AS (SELECT * FROM Employees WHERE DepartmentID = @DeptId) SELECT * FROM EmployeeCTE",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    ctes = {
                        {
                            name = "EmployeeCTE",
                            parameters = {
                                { name = "DeptId", full_name = "@DeptId", is_system = false }
                            }
                        }
                    }
                }
            }
        }
    },

    {
        id = 2873,
        type = "parser",
        name = "Parameter in correlated subquery",
        input = "SELECT EmployeeID, (SELECT COUNT(*) FROM Orders WHERE EmployeeId = @EmpId) AS OrderCount FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "EmpId", full_name = "@EmpId", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2874,
        type = "parser",
        name = "Multiple parameters in different scopes",
        input = "SELECT * FROM Employees WHERE DepartmentID = @DeptId AND EmployeeID IN (SELECT EmployeeID FROM Orders WHERE OrderDate > @StartDate)",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "DeptId", full_name = "@DeptId", is_system = false },
                        { name = "StartDate", full_name = "@StartDate", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2875,
        type = "parser",
        name = "Nested subqueries with params",
        input = "SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM Departments WHERE Budget > (SELECT AVG(Budget) FROM Departments WHERE Region = @Region))",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "Region", full_name = "@Region", is_system = false }
                    }
                }
            }
        }
    },

    -- ========================================
    -- 2876-2880: Edge Cases
    -- ========================================

    {
        id = 2876,
        type = "parser",
        name = "Same parameter used multiple times (track first occurrence)",
        input = "SELECT * FROM Employees WHERE DepartmentID = @DeptId OR ManagerDepartmentID = @DeptId",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "DeptId", full_name = "@DeptId", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2877,
        type = "parser",
        name = "Parameter in function call",
        input = "SELECT CONCAT(@FirstName, ' ', @LastName) AS FullName FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "FirstName", full_name = "@FirstName", is_system = false },
                        { name = "LastName", full_name = "@LastName", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2878,
        type = "parser",
        name = "Parameter in CASE expression",
        input = "SELECT CASE WHEN Salary > @Threshold THEN 'High' ELSE 'Low' END AS SalaryRange FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "Threshold", full_name = "@Threshold", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2879,
        type = "parser",
        name = "Unicode parameter name",
        input = "SELECT * FROM Employees WHERE FirstName = @ИмяСотрудника",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "ИмяСотрудника", full_name = "@ИмяСотрудника", is_system = false }
                    }
                }
            }
        }
    },

    {
        id = 2880,
        type = "parser",
        name = "Many parameters (10+)",
        input = "SELECT * FROM Employees WHERE DeptId = @P1 AND Status = @P2 AND Level = @P3 AND Location = @P4 AND Manager = @P5 AND Salary > @P6 AND StartDate > @P7 AND EndDate < @P8 AND Type = @P9 AND Grade = @P10",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    parameters = {
                        { name = "P1", full_name = "@P1", is_system = false },
                        { name = "P2", full_name = "@P2", is_system = false },
                        { name = "P3", full_name = "@P3", is_system = false },
                        { name = "P4", full_name = "@P4", is_system = false },
                        { name = "P5", full_name = "@P5", is_system = false },
                        { name = "P6", full_name = "@P6", is_system = false },
                        { name = "P7", full_name = "@P7", is_system = false },
                        { name = "P8", full_name = "@P8", is_system = false },
                        { name = "P9", full_name = "@P9", is_system = false },
                        { name = "P10", full_name = "@P10", is_system = false }
                    }
                }
            }
        }
    }
}
