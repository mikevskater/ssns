-- Test file: single_statements.lua
-- IDs: 2001-2050
-- Tests: Single statement parsing with various table qualification patterns

return {
    -- Simple SELECT statements
    {
        id = 2001,
        type = "parser",
        name = "Simple SELECT without alias",
        input = "SELECT * FROM Employees",
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
        id = 2002,
        type = "parser",
        name = "Simple SELECT with alias",
        input = "SELECT * FROM Employees e",
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
        id = 2003,
        type = "parser",
        name = "SELECT with AS alias",
        input = "SELECT * FROM Employees AS e",
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
        id = 2004,
        type = "parser",
        name = "SELECT with schema qualification",
        input = "SELECT * FROM dbo.Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", schema = "dbo" }
                    }
                }
            }
        }
    },
    {
        id = 2005,
        type = "parser",
        name = "SELECT with schema and alias",
        input = "SELECT * FROM dbo.Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", schema = "dbo", alias = "e" }
                    }
                }
            }
        }
    },
    {
        id = 2006,
        type = "parser",
        name = "SELECT with database.schema.table",
        input = "SELECT * FROM mydb.dbo.Employees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", schema = "dbo", database = "mydb" }
                    }
                }
            }
        }
    },
    {
        id = 2007,
        type = "parser",
        name = "SELECT with database.schema.table and alias",
        input = "SELECT * FROM mydb.dbo.Employees e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", schema = "dbo", database = "mydb", alias = "e" }
                    }
                }
            }
        }
    },
    {
        id = 2008,
        type = "parser",
        name = "SELECT with bracketed identifiers",
        input = "SELECT * FROM [dbo].[Employees]",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", schema = "dbo" }
                    }
                }
            }
        }
    },
    {
        id = 2009,
        type = "parser",
        name = "SELECT with bracketed identifiers with spaces",
        input = "SELECT * FROM [My Schema].[My Table]",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "My Table", schema = "My Schema" }
                    }
                }
            }
        }
    },
    {
        id = 2010,
        type = "parser",
        name = "SELECT with fully bracketed database.schema.table",
        input = "SELECT * FROM [MyDB].[dbo].[Employees] e",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "Employees", schema = "dbo", database = "MyDB", alias = "e" }
                    }
                }
            }
        }
    },

    -- INSERT statements
    {
        id = 2011,
        type = "parser",
        name = "Simple INSERT without column list",
        input = "INSERT INTO Employees VALUES (1, 'John')",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2012,
        type = "parser",
        name = "INSERT with column list",
        input = "INSERT INTO Employees (Id, Name) VALUES (1, 'John')",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2013,
        type = "parser",
        name = "INSERT with schema qualification",
        input = "INSERT INTO dbo.Employees (Id, Name) VALUES (1, 'John')",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "Employees", schema = "dbo" }
                    }
                }
            }
        }
    },
    {
        id = 2014,
        type = "parser",
        name = "INSERT with database.schema.table",
        input = "INSERT INTO mydb.dbo.Employees VALUES (1, 'John')",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "Employees", schema = "dbo", database = "mydb" }
                    }
                }
            }
        }
    },

    -- UPDATE statements
    {
        id = 2015,
        type = "parser",
        name = "Simple UPDATE",
        input = "UPDATE Employees SET Name = 'Jane'",
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2016,
        type = "parser",
        name = "UPDATE with WHERE clause",
        input = "UPDATE Employees SET Name = 'Jane' WHERE Id = 1",
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2017,
        type = "parser",
        name = "UPDATE with schema qualification",
        input = "UPDATE dbo.Employees SET Name = 'Jane'",
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    tables = {
                        { name = "Employees", schema = "dbo" }
                    }
                }
            }
        }
    },
    {
        id = 2018,
        type = "parser",
        name = "UPDATE with alias",
        input = "UPDATE e SET Name = 'Jane' FROM Employees e WHERE Id = 1",
        expected = {
            chunks = {
                {
                    statement_type = "UPDATE",
                    tables = {
                        { name = "Employees", alias = "e" }
                    }
                }
            }
        }
    },

    -- DELETE statements
    {
        id = 2019,
        type = "parser",
        name = "Simple DELETE",
        input = "DELETE FROM Employees",
        expected = {
            chunks = {
                {
                    statement_type = "DELETE",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2020,
        type = "parser",
        name = "DELETE with WHERE clause",
        input = "DELETE FROM Employees WHERE Id = 1",
        expected = {
            chunks = {
                {
                    statement_type = "DELETE",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2021,
        type = "parser",
        name = "DELETE with schema qualification",
        input = "DELETE FROM dbo.Employees WHERE Id = 1",
        expected = {
            chunks = {
                {
                    statement_type = "DELETE",
                    tables = {
                        { name = "Employees", schema = "dbo" }
                    }
                }
            }
        }
    },
    {
        id = 2022,
        type = "parser",
        name = "DELETE with database.schema.table",
        input = "DELETE FROM mydb.dbo.Employees",
        expected = {
            chunks = {
                {
                    statement_type = "DELETE",
                    tables = {
                        { name = "Employees", schema = "dbo", database = "mydb" }
                    }
                }
            }
        }
    },

    -- Temp tables
    {
        id = 2023,
        type = "parser",
        name = "SELECT from temp table",
        input = "SELECT * FROM #TempEmployees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "#TempEmployees", is_temp = true }
                    }
                }
            }
        }
    },
    {
        id = 2024,
        type = "parser",
        name = "SELECT from global temp table",
        input = "SELECT * FROM ##GlobalTempEmployees",
        expected = {
            chunks = {
                {
                    statement_type = "SELECT",
                    tables = {
                        { name = "##GlobalTempEmployees", is_temp = true }
                    }
                }
            }
        }
    },
    {
        id = 2025,
        type = "parser",
        name = "INSERT into temp table",
        input = "INSERT INTO #TempEmployees VALUES (1, 'John')",
        expected = {
            chunks = {
                {
                    statement_type = "INSERT",
                    tables = {
                        { name = "#TempEmployees", is_temp = true }
                    }
                }
            }
        }
    },

    -- Multiple columns in SELECT
    {
        id = 2026,
        type = "parser",
        name = "SELECT with multiple columns",
        input = "SELECT Id, Name, Email FROM Employees",
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
        id = 2027,
        type = "parser",
        name = "SELECT with qualified columns",
        input = "SELECT e.Id, e.Name FROM Employees e",
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

    -- TRUNCATE statement
    {
        id = 2028,
        type = "parser",
        name = "TRUNCATE TABLE",
        input = "TRUNCATE TABLE Employees",
        expected = {
            chunks = {
                {
                    statement_type = "TRUNCATE",
                    tables = {
                        { name = "Employees" }
                    }
                }
            }
        }
    },
    {
        id = 2029,
        type = "parser",
        name = "TRUNCATE TABLE with schema",
        input = "TRUNCATE TABLE dbo.Employees",
        expected = {
            chunks = {
                {
                    statement_type = "TRUNCATE",
                    tables = {
                        { name = "Employees", schema = "dbo" }
                    }
                }
            }
        }
    },

    -- WHERE clause variations
    {
        id = 2030,
        type = "parser",
        name = "SELECT with complex WHERE",
        input = "SELECT * FROM Employees WHERE Age > 30 AND Department = 'IT'",
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
        id = 2031,
        type = "parser",
        name = "SELECT with WHERE IN list",
        input = "SELECT * FROM Employees WHERE Id IN (1, 2, 3)",
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

    -- ORDER BY and GROUP BY
    {
        id = 2032,
        type = "parser",
        name = "SELECT with ORDER BY",
        input = "SELECT * FROM Employees ORDER BY Name",
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
        id = 2033,
        type = "parser",
        name = "SELECT with GROUP BY",
        input = "SELECT Department, COUNT(*) FROM Employees GROUP BY Department",
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
        id = 2034,
        type = "parser",
        name = "SELECT with GROUP BY and HAVING",
        input = "SELECT Department, COUNT(*) FROM Employees GROUP BY Department HAVING COUNT(*) > 5",
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

    -- TOP clause
    {
        id = 2035,
        type = "parser",
        name = "SELECT with TOP",
        input = "SELECT TOP 10 * FROM Employees",
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
        id = 2036,
        type = "parser",
        name = "SELECT with TOP PERCENT",
        input = "SELECT TOP 10 PERCENT * FROM Employees",
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

    -- DISTINCT
    {
        id = 2037,
        type = "parser",
        name = "SELECT DISTINCT",
        input = "SELECT DISTINCT Department FROM Employees",
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

    -- CASE expression
    {
        id = 2038,
        type = "parser",
        name = "SELECT with CASE expression",
        input = "SELECT CASE WHEN Age > 30 THEN 'Senior' ELSE 'Junior' END FROM Employees",
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

    -- Multiple tables without JOIN (old-style)
    {
        id = 2039,
        type = "parser",
        name = "SELECT with multiple tables in FROM (comma-separated)",
        input = "SELECT * FROM Employees, Departments WHERE Employees.DeptId = Departments.Id",
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
        id = 2040,
        type = "parser",
        name = "SELECT with multiple tables in FROM with aliases",
        input = "SELECT * FROM Employees e, Departments d WHERE e.DeptId = d.Id",
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
}
