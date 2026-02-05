-- Test file: positions.lua
-- IDs: 2881-2920
-- Tests: Parser position tracking (start_line, end_line, start_col, end_col, go_batch_index)

return {
    -- ========================================
    -- 2881-2885: Single Line Statements
    -- ========================================

    {
        id = 2881,
        type = "parser",
        name = "Simple SELECT on one line",
        input = "SELECT * FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 23,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2882,
        type = "parser",
        name = "Short statement - SELECT 1",
        input = "SELECT 1",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 8,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2883,
        type = "parser",
        name = "Long single-line SELECT with WHERE",
        input = "SELECT EmployeeID, FirstName, LastName FROM Employees WHERE DepartmentID = 5 AND Salary > 50000",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 95,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2884,
        type = "parser",
        name = "Single line with trailing semicolon",
        input = "SELECT * FROM Departments;",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 26,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2885,
        type = "parser",
        name = "UPDATE on single line",
        input = "UPDATE Employees SET Salary = 60000 WHERE EmployeeID = 123",
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 58,
                    go_batch_index = 0
                }
            }
        }
    },

    -- ========================================
    -- 2886-2890: Multi-line Statements
    -- ========================================

    {
        id = 2886,
        type = "parser",
        name = "SELECT across three lines",
        input = [[SELECT EmployeeID, FirstName, LastName
FROM Employees
WHERE DepartmentID = 5]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 3,
                    start_col = 1,
                    end_col = 22,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2887,
        type = "parser",
        name = "Multi-line with JOIN",
        input = [[SELECT e.EmployeeID, e.FirstName, d.DepartmentName
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.Salary > 50000]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 4,
                    start_col = 1,
                    end_col = 22,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2888,
        type = "parser",
        name = "Multi-line with leading whitespace",
        input = [[    SELECT *
    FROM Employees
    WHERE Salary > 60000]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 3,
                    start_col = 5,
                    end_col = 24,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2889,
        type = "parser",
        name = "Multi-line CTE",
        input = [[WITH EmployeeCTE AS (
    SELECT * FROM Employees WHERE Salary > 80000
)
SELECT * FROM EmployeeCTE]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 4,
                    start_col = 1,
                    end_col = 25,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2890,
        type = "parser",
        name = "Multi-line INSERT with VALUES",
        input = [[INSERT INTO Employees (EmployeeID, FirstName, LastName)
VALUES
(101, 'John', 'Doe'),
(102, 'Jane', 'Smith')]],
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    start_line = 1,
                    end_line = 4,
                    start_col = 1,
                    end_col = 22,
                    go_batch_index = 0
                }
            }
        }
    },

    -- ========================================
    -- 2891-2895: Multiple Statements
    -- ========================================

    {
        id = 2891,
        type = "parser",
        name = "Two statements on separate lines with semicolon",
        input = [[SELECT * FROM Employees;
SELECT * FROM Departments]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 24,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 2,
                    end_line = 2,
                    start_col = 1,
                    end_col = 25,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2892,
        type = "parser",
        name = "Two statements on same line with semicolon",
        input = "SELECT * FROM Employees; SELECT * FROM Departments",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 24,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 26,
                    end_col = 50,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2893,
        type = "parser",
        name = "Three statements with mixed formatting",
        input = [[SELECT * FROM Employees;
SELECT * FROM Departments; SELECT * FROM Orders]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 24,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 2,
                    end_line = 2,
                    start_col = 1,
                    end_col = 26,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 2,
                    end_line = 2,
                    start_col = 28,
                    end_col = 47,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2894,
        type = "parser",
        name = "Multi-line statements separated by semicolon",
        input = [[SELECT EmployeeID, FirstName
FROM Employees
WHERE Salary > 50000;
SELECT DepartmentID, DepartmentName
FROM Departments]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 3,
                    start_col = 1,
                    end_col = 21,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 4,
                    end_line = 5,
                    start_col = 1,
                    end_col = 16,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2895,
        type = "parser",
        name = "Statement starting mid-line after semicolon",
        input = [[SELECT * FROM Employees; SELECT * FROM Departments
WHERE Budget > 100000]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 24,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 2,
                    start_col = 26,
                    end_col = 21,
                    go_batch_index = 0
                }
            }
        }
    },

    -- ========================================
    -- 2896-2900: GO Batch Indexing
    -- ========================================

    {
        id = 2896,
        type = "parser",
        name = "Single batch - go_batch_index = 0",
        input = "SELECT * FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 23,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2897,
        type = "parser",
        name = "Two batches separated by GO",
        input = [[SELECT * FROM Employees
GO
SELECT * FROM Departments]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 23,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 3,
                    end_line = 3,
                    start_col = 1,
                    end_col = 25,
                    go_batch_index = 1
                }
            }
        }
    },

    {
        id = 2898,
        type = "parser",
        name = "Three batches with GO separators",
        input = [[SELECT * FROM Employees
GO
SELECT * FROM Departments
GO
SELECT * FROM Orders]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 23,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 3,
                    end_line = 3,
                    start_col = 1,
                    end_col = 25,
                    go_batch_index = 1
                },
                {
                    statement_type = "SELECT",
                    start_line = 5,
                    end_line = 5,
                    start_col = 1,
                    end_col = 20,
                    go_batch_index = 2
                }
            }
        }
    },

    {
        id = 2899,
        type = "parser",
        name = "Multiple statements in single batch (same go_batch_index)",
        input = [[SELECT * FROM Employees;
SELECT * FROM Departments;
GO
SELECT * FROM Orders]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 24,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 2,
                    end_line = 2,
                    start_col = 1,
                    end_col = 26,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 4,
                    end_line = 4,
                    start_col = 1,
                    end_col = 20,
                    go_batch_index = 1
                }
            }
        }
    },

    {
        id = 2900,
        type = "parser",
        name = "Multi-line statements across batches",
        input = [[SELECT EmployeeID, FirstName
FROM Employees
WHERE Salary > 50000
GO
SELECT DepartmentID, DepartmentName
FROM Departments
WHERE Budget > 100000]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 3,
                    start_col = 1,
                    end_col = 20,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 5,
                    end_line = 7,
                    start_col = 1,
                    end_col = 21,
                    go_batch_index = 1
                }
            }
        }
    },

    -- ========================================
    -- 2901-2905: Edge Cases
    -- ========================================

    {
        id = 2901,
        type = "parser",
        name = "Empty lines before statement",
        input = [[

SELECT * FROM Employees]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 2,
                    end_line = 2,
                    start_col = 1,
                    end_col = 23,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2902,
        type = "parser",
        name = "Statement with leading tabs",
        input = "\t\tSELECT * FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 3,
                    end_col = 25,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2903,
        type = "parser",
        name = "Mixed GO and semicolon separators",
        input = [[SELECT * FROM Employees; SELECT * FROM Departments
GO
SELECT * FROM Orders]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 24,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 26,
                    end_col = 50,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 3,
                    end_line = 3,
                    start_col = 1,
                    end_col = 20,
                    go_batch_index = 1
                }
            }
        }
    },

    {
        id = 2904,
        type = "parser",
        name = "Empty lines between batches",
        input = [[SELECT * FROM Employees

GO

SELECT * FROM Departments]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 23,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 5,
                    end_line = 5,
                    start_col = 1,
                    end_col = 25,
                    go_batch_index = 1
                }
            }
        }
    },

    {
        id = 2905,
        type = "parser",
        name = "Complex multi-line with indentation",
        input = [[    SELECT
        e.EmployeeID,
        e.FirstName,
        d.DepartmentName
    FROM
        Employees e
    INNER JOIN
        Departments d
    ON
        e.DepartmentID = d.DepartmentID
    WHERE
        e.Salary > 50000]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 12,
                    start_col = 5,
                    end_col = 24,
                    go_batch_index = 0
                }
            }
        }
    },

    -- ========================================
    -- 2906-2910: Position Tracking with CTEs
    -- ========================================

    {
        id = 2906,
        type = "parser",
        name = "Simple CTE position tracking",
        input = [[WITH EmployeeCTE AS (SELECT * FROM Employees)
SELECT * FROM EmployeeCTE]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 2,
                    start_col = 1,
                    end_col = 25,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2907,
        type = "parser",
        name = "Multi-line CTE with formatted query",
        input = [[WITH EmployeeCTE AS (
    SELECT
        EmployeeID,
        FirstName,
        LastName
    FROM Employees
    WHERE Salary > 80000
)
SELECT * FROM EmployeeCTE WHERE EmployeeID > 100]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 9,
                    start_col = 1,
                    end_col = 48,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2908,
        type = "parser",
        name = "Multiple CTEs position tracking",
        input = [[WITH
    EmployeeCTE AS (SELECT * FROM Employees),
    DeptCTE AS (SELECT * FROM Departments)
SELECT * FROM EmployeeCTE e JOIN DeptCTE d ON e.DepartmentID = d.DepartmentID]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 4,
                    start_col = 1,
                    end_col = 77,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2909,
        type = "parser",
        name = "RECURSIVE CTE position tracking",
        input = [[WITH RECURSIVE ManagerHierarchy AS (
    SELECT EmployeeID, ManagerID, 1 AS Level FROM Employees WHERE ManagerID IS NULL
    UNION ALL
    SELECT e.EmployeeID, e.ManagerID, mh.Level + 1
    FROM Employees e
    INNER JOIN ManagerHierarchy mh ON e.ManagerID = mh.EmployeeID
)
SELECT * FROM ManagerHierarchy]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 8,
                    start_col = 1,
                    end_col = 30,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2910,
        type = "parser",
        name = "CTE followed by GO batch",
        input = [[WITH EmployeeCTE AS (SELECT * FROM Employees WHERE Salary > 80000)
SELECT * FROM EmployeeCTE
GO
SELECT * FROM Departments]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 2,
                    start_col = 1,
                    end_col = 25,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 4,
                    end_line = 4,
                    start_col = 1,
                    end_col = 25,
                    go_batch_index = 1
                }
            }
        }
    },

    -- ========================================
    -- 2911-2915: Position Tracking with Subqueries
    -- ========================================

    {
        id = 2911,
        type = "parser",
        name = "Subquery in FROM clause",
        input = "SELECT * FROM (SELECT EmployeeID, FirstName FROM Employees) emp",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 63,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2912,
        type = "parser",
        name = "Multi-line subquery",
        input = [[SELECT * FROM (
    SELECT EmployeeID, FirstName, LastName
    FROM Employees
    WHERE Salary > 50000
) emp WHERE emp.EmployeeID > 100]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 5,
                    start_col = 1,
                    end_col = 32,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2913,
        type = "parser",
        name = "Subquery in WHERE clause",
        input = [[SELECT * FROM Employees
WHERE DepartmentID IN (SELECT DepartmentID FROM Departments WHERE Budget > 100000)]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 2,
                    start_col = 1,
                    end_col = 82,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2914,
        type = "parser",
        name = "Nested subqueries",
        input = [[SELECT * FROM (
    SELECT * FROM (
        SELECT EmployeeID, FirstName FROM Employees
    ) inner_sub
) outer_sub]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 5,
                    start_col = 1,
                    end_col = 11,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2915,
        type = "parser",
        name = "Multiple subqueries in JOIN",
        input = [[SELECT * FROM
    (SELECT * FROM Employees) e
JOIN
    (SELECT * FROM Departments) d
ON e.DepartmentID = d.DepartmentID]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 5,
                    start_col = 1,
                    end_col = 34,
                    go_batch_index = 0
                }
            }
        }
    },

    -- ========================================
    -- 2916-2920: Position Tracking with SET Operations
    -- ========================================

    {
        id = 2916,
        type = "parser",
        name = "Simple UNION position tracking",
        input = [[SELECT EmployeeID FROM Employees
UNION
SELECT DepartmentID FROM Departments]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 32,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 3,
                    end_line = 3,
                    start_col = 1,
                    end_col = 36,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2917,
        type = "parser",
        name = "UNION ALL position tracking",
        input = [[SELECT FirstName, LastName FROM Employees
UNION ALL
SELECT FirstName, LastName FROM Customers]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 41,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 3,
                    end_line = 3,
                    start_col = 1,
                    end_col = 41,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2918,
        type = "parser",
        name = "Multiple UNION operations",
        input = [[SELECT EmployeeID FROM Employees
UNION
SELECT DepartmentID FROM Departments
UNION
SELECT OrderID FROM Orders]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 32,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 3,
                    end_line = 3,
                    start_col = 1,
                    end_col = 36,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 5,
                    end_line = 5,
                    start_col = 1,
                    end_col = 26,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2919,
        type = "parser",
        name = "INTERSECT and EXCEPT position tracking",
        input = [[SELECT EmployeeID FROM Employees
INTERSECT
SELECT ManagerID FROM Employees
EXCEPT
SELECT EmployeeID FROM Terminated]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 1,
                    start_col = 1,
                    end_col = 32,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 3,
                    end_line = 3,
                    start_col = 1,
                    end_col = 31,
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    start_line = 5,
                    end_line = 5,
                    start_col = 1,
                    end_col = 33,
                    go_batch_index = 0
                }
            }
        }
    },

    {
        id = 2920,
        type = "parser",
        name = "Set operations with subqueries",
        input = [[SELECT * FROM (
    SELECT EmployeeID FROM Employees
    UNION
    SELECT DepartmentID FROM Departments
) combined WHERE combined.EmployeeID > 100]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    start_line = 1,
                    end_line = 5,
                    start_col = 1,
                    end_col = 42,
                    go_batch_index = 0
                }
            }
        }
    }
}
