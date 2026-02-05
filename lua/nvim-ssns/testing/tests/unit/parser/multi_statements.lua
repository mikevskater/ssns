-- Test file: multi_statements.lua
-- IDs: 2101-2150
-- Tests: Multi-statement isolation (THE CRITICAL TEST)
-- Purpose: Verify each statement chunk has ONLY its own tables, not tables from other statements

return {
    -- Two statements
    {
        id = 2101,
        type = "parser",
        name = "Two SELECTs on separate lines - first statement",
        input = "SELECT * FROM Employees e\nSELECT * FROM Departments d",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                },
                {}  -- Second chunk exists, but we only verify first chunk
            }
        }
    },
    {
        id = 2102,
        type = "parser",
        name = "Two SELECTs on separate lines - second statement",
        input = "SELECT * FROM Employees e\nSELECT * FROM Departments d",
        expected = {
            chunks = {
                {},  -- Skip first chunk
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Departments", alias = "d" }
                    }
                }
                -- Second chunk should NOT have Employees
            }
        }
    },
    {
        id = 2103,
        type = "parser",
        name = "Two SELECTs - verify chunk count",
        input = "SELECT * FROM Employees e\nSELECT * FROM Departments d",
        expected = {
            chunks = {
                {}, {}  -- Should have exactly 2 chunks
            }
        }
    },

    -- Three statements
    {
        id = 2104,
        type = "parser",
        name = "Three SELECTs - verify isolation",
        input = "SELECT * FROM Employees\nSELECT * FROM Departments\nSELECT * FROM Locations",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }} },
                { statement_type = "SELECT", tables = {{ name = "Departments" }} },
                { statement_type = "SELECT", tables = {{ name = "Locations" }} }
            }
        }
    },

    -- Mixed statement types
    {
        id = 2105,
        type = "parser",
        name = "SELECT then INSERT - first statement",
        input = "SELECT * FROM Employees\nINSERT INTO Departments VALUES (1, 'IT')",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees" }
                    }
                },
                {}  -- Second chunk exists, but we only verify first chunk
            }
        }
    },
    {
        id = 2106,
        type = "parser",
        name = "SELECT then INSERT - second statement",
        input = "SELECT * FROM Employees\nINSERT INTO Departments VALUES (1, 'IT')",
        expected = {
            chunks = {
                {},
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "Departments" }
                    }
                }
            }
        }
    },
    {
        id = 2107,
        type = "parser",
        name = "SELECT then UPDATE",
        input = "SELECT * FROM Employees\nUPDATE Departments SET Name = 'HR'",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }} },
                { statement_type = "UPDATE", tables = {{ name = "Departments" }} }
            }
        }
    },
    {
        id = 2108,
        type = "parser",
        name = "SELECT then DELETE",
        input = "SELECT * FROM Employees\nDELETE FROM Departments WHERE Id = 1",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }} },
                { statement_type = "DELETE", tables = {{ name = "Departments" }} }
            }
        }
    },
    {
        id = 2109,
        type = "parser",
        name = "INSERT then UPDATE then DELETE",
        input = "INSERT INTO Employees VALUES (1, 'John')\nUPDATE Employees SET Name = 'Jane'\nDELETE FROM Employees WHERE Id = 1",
        expected = {
            chunks = {
                { statement_type = "INSERT", tables = {{ name = "Employees" }} },
                { statement_type = "UPDATE", tables = {{ name = "Employees" }} },
                { statement_type = "DELETE", tables = {{ name = "Employees" }} }
            }
        }
    },

    -- GO batch separator tests
    {
        id = 2110,
        type = "parser",
        name = "Two SELECTs separated by GO",
        input = "SELECT * FROM Employees\nGO\nSELECT * FROM Departments",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }}, go_batch_index = 0 },
                { statement_type = "SELECT", tables = {{ name = "Departments" }}, go_batch_index = 1 }
            }
        }
    },
    {
        id = 2111,
        type = "parser",
        name = "Three batches with GO",
        input = "SELECT * FROM Employees\nGO\nSELECT * FROM Departments\nGO\nSELECT * FROM Locations",
        expected = {
            chunks = {
                { go_batch_index = 0 },
                { go_batch_index = 1 },
                { go_batch_index = 2 }
            }
        }
    },
    {
        id = 2112,
        type = "parser",
        name = "GO without space (lowercase)",
        input = "SELECT * FROM Employees\ngo\nSELECT * FROM Departments",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }}, go_batch_index = 0 },
                { statement_type = "SELECT", tables = {{ name = "Departments" }}, go_batch_index = 1 }
            }
        }
    },
    {
        id = 2113,
        type = "parser",
        name = "Multiple statements then GO then more statements",
        input = "SELECT * FROM A\nSELECT * FROM B\nGO\nSELECT * FROM C\nSELECT * FROM D",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "A" }}, go_batch_index = 0 },
                { statement_type = "SELECT", tables = {{ name = "B" }}, go_batch_index = 0 },
                { statement_type = "SELECT", tables = {{ name = "C" }}, go_batch_index = 1 },
                { statement_type = "SELECT", tables = {{ name = "D" }}, go_batch_index = 1 }
            }
        }
    },

    -- Statements with semicolons
    {
        id = 2114,
        type = "parser",
        name = "Two SELECTs with semicolons",
        input = "SELECT * FROM Employees; SELECT * FROM Departments;",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }} },
                { statement_type = "SELECT", tables = {{ name = "Departments" }} }
            }
        }
    },
    {
        id = 2115,
        type = "parser",
        name = "Mixed semicolons and newlines",
        input = "SELECT * FROM Employees;\nSELECT * FROM Departments",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }} },
                { statement_type = "SELECT", tables = {{ name = "Departments" }} }
            }
        }
    },

    -- Same table, different statements
    {
        id = 2116,
        type = "parser",
        name = "Same table in two statements - different aliases",
        input = "SELECT * FROM Employees e\nSELECT * FROM Employees emp",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees", alias = "e" }} },
                { statement_type = "SELECT", tables = {{ name = "Employees", alias = "emp" }} }
            }
        }
    },
    {
        id = 2117,
        type = "parser",
        name = "Same table in three statements",
        input = "SELECT * FROM Employees\nUPDATE Employees SET Name = 'X'\nDELETE FROM Employees",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }} },
                { statement_type = "UPDATE", tables = {{ name = "Employees" }} },
                { statement_type = "DELETE", tables = {{ name = "Employees" }} }
            }
        }
    },

    -- Multiline statements
    {
        id = 2118,
        type = "parser",
        name = "Two multiline SELECTs",
        input = [[SELECT *
FROM Employees
WHERE Age > 30

SELECT *
FROM Departments
WHERE Active = 1]],
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }} },
                { statement_type = "SELECT", tables = {{ name = "Departments" }} }
            }
        }
    },

    -- Complex mixed scenario
    {
        id = 2119,
        type = "parser",
        name = "Complex multi-statement batch",
        input = [[SELECT * FROM Employees e WHERE e.Active = 1
INSERT INTO AuditLog VALUES (1, 'Login')
UPDATE Employees SET LastLogin = GETDATE()
DELETE FROM TempData WHERE Created < GETDATE() - 7
SELECT * FROM Departments d]],
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees", alias = "e" }} },
                { statement_type = "INSERT", tables = {{ name = "AuditLog" }} },
                { statement_type = "UPDATE", tables = {{ name = "Employees" }} },
                { statement_type = "DELETE", tables = {{ name = "TempData" }} },
                { statement_type = "SELECT", tables = {{ name = "Departments", alias = "d" }} }
            }
        }
    },

    -- Statements with schema qualification
    {
        id = 2120,
        type = "parser",
        name = "Two SELECTs with different schemas",
        input = "SELECT * FROM dbo.Employees\nSELECT * FROM hr.Employees",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees", schema = "dbo" }} },
                { statement_type = "SELECT", tables = {{ name = "Employees", schema = "hr" }} }
            }
        }
    },

    -- Empty lines between statements
    {
        id = 2121,
        type = "parser",
        name = "Statements with empty lines",
        input = "SELECT * FROM Employees\n\n\nSELECT * FROM Departments",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }} },
                { statement_type = "SELECT", tables = {{ name = "Departments" }} }
            }
        }
    },

    -- Comments between statements
    {
        id = 2122,
        type = "parser",
        name = "Statements with comments between",
        input = "SELECT * FROM Employees\n-- This is a comment\nSELECT * FROM Departments",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }} },
                { statement_type = "SELECT", tables = {{ name = "Departments" }} }
            }
        }
    },
    {
        id = 2123,
        type = "parser",
        name = "Statements with block comments",
        input = "SELECT * FROM Employees\n/* Block comment */\nSELECT * FROM Departments",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "Employees" }} },
                { statement_type = "SELECT", tables = {{ name = "Departments" }} }
            }
        }
    },

    -- INSERT with SELECT source (should be ONE statement)
    {
        id = 2124,
        type = "parser",
        name = "INSERT INTO SELECT (single statement)",
        input = "INSERT INTO EmployeeBackup SELECT * FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "EmployeeBackup" },
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2125,
        type = "parser",
        name = "INSERT INTO SELECT with schemas",
        input = "INSERT INTO dbo.EmployeeBackup SELECT * FROM hr.Employees",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "EmployeeBackup", schema = "dbo" },
                        { name = "Employees", schema = "hr" }
                    }
                }
            }
        }
    },

    -- Five statements to test robustness
    {
        id = 2126,
        type = "parser",
        name = "Five different statement types",
        input = [[SELECT * FROM T1
INSERT INTO T2 VALUES (1)
UPDATE T3 SET X = 1
DELETE FROM T4
SELECT * FROM T5]],
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "T1" }} },
                { statement_type = "INSERT", tables = {{ name = "T2" }} },
                { statement_type = "UPDATE", tables = {{ name = "T3" }} },
                { statement_type = "DELETE", tables = {{ name = "T4" }} },
                { statement_type = "SELECT", tables = {{ name = "T5" }} }
            }
        }
    },

    -- WITH clause followed by another statement
    {
        id = 2127,
        type = "parser",
        name = "CTE then separate SELECT",
        input = "WITH cte AS (SELECT * FROM Employees) SELECT * FROM cte\nSELECT * FROM Departments",
        expected = {
            chunks = {
                { statement_type = "SELECT" },  -- CTE queries report as SELECT
                { statement_type = "SELECT", tables = {{ name = "Departments" }} }  -- Separate statement
            }
        }
    },

    -- Statements with table variables
    {
        id = 2128,
        type = "parser",
        name = "Two SELECTs with table variables",
        input = "SELECT * FROM @TableVar1\nSELECT * FROM @TableVar2",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "@TableVar1" }} },
                { statement_type = "SELECT", tables = {{ name = "@TableVar2" }} }
            }
        }
    },

    -- Statements with temp tables
    {
        id = 2129,
        type = "parser",
        name = "Two SELECTs with different temp tables",
        input = "SELECT * FROM #Temp1\nSELECT * FROM #Temp2",
        expected = {
            chunks = {
                { statement_type = "SELECT", tables = {{ name = "#Temp1", is_temp = true }} },
                { statement_type = "SELECT", tables = {{ name = "#Temp2", is_temp = true }} }
            }
        }
    },

    -- Verify no table leakage in complex scenario
    {
        id = 2130,
        type = "parser",
        name = "Verify no table leakage - complex",
        input = [[SELECT * FROM A JOIN B ON A.Id = B.Id
GO
SELECT * FROM C LEFT JOIN D ON C.Id = D.Id
GO
SELECT * FROM E]],
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "A" },
                        { name = "B" }
                    },
                    go_batch_index = 0
                },
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "C" },
                        { name = "D" }
                    },
                    go_batch_index = 1
                },
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "E" }
                    },
                    go_batch_index = 2
                }
            }
        }
    },
}
