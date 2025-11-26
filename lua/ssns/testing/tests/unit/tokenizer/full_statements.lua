-- Test file: full_statements.lua
-- IDs: 1501-1600
-- Tests: Complete SQL statement tokenization

return {
    -- Simple SELECT statements
    {
        id = 1501,
        type = "tokenizer",
        name = "SELECT * FROM table",
        input = "SELECT * FROM Employees",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Employees", line = 1, col = 15}
        }
    },
    {
        id = 1502,
        type = "tokenizer",
        name = "SELECT with alias",
        input = "SELECT e.FirstName FROM Employees e",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "e", line = 1, col = 8},
            {type = "dot", text = ".", line = 1, col = 9},
            {type = "identifier", text = "FirstName", line = 1, col = 10},
            {type = "keyword", text = "FROM", line = 1, col = 20},
            {type = "identifier", text = "Employees", line = 1, col = 25},
            {type = "identifier", text = "e", line = 1, col = 35}
        }
    },
    {
        id = 1503,
        type = "tokenizer",
        name = "SELECT with schema qualified table",
        input = "SELECT * FROM dbo.Employees",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "dbo", line = 1, col = 15},
            {type = "dot", text = ".", line = 1, col = 18},
            {type = "identifier", text = "Employees", line = 1, col = 19}
        }
    },
    {
        id = 1504,
        type = "tokenizer",
        name = "SELECT with bracketed identifiers",
        input = "SELECT * FROM [My Schema].[My Table]",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "bracket_id", text = "[My Schema]", line = 1, col = 15},
            {type = "dot", text = ".", line = 1, col = 26},
            {type = "bracket_id", text = "[My Table]", line = 1, col = 27}
        }
    },
    {
        id = 1505,
        type = "tokenizer",
        name = "SELECT with column list",
        input = "SELECT a, b, c FROM t",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "a", line = 1, col = 8},
            {type = "comma", text = ",", line = 1, col = 9},
            {type = "identifier", text = "b", line = 1, col = 11},
            {type = "comma", text = ",", line = 1, col = 12},
            {type = "identifier", text = "c", line = 1, col = 14},
            {type = "keyword", text = "FROM", line = 1, col = 16},
            {type = "identifier", text = "t", line = 1, col = 21}
        }
    },
    {
        id = 1506,
        type = "tokenizer",
        name = "SELECT with WHERE clause",
        input = "SELECT * FROM t WHERE x = 1",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "t", line = 1, col = 15},
            {type = "keyword", text = "WHERE", line = 1, col = 17},
            {type = "identifier", text = "x", line = 1, col = 23},
            {type = "operator", text = "=", line = 1, col = 25},
            {type = "number", text = "1", line = 1, col = 27}
        }
    },

    -- JOIN statements
    {
        id = 1507,
        type = "tokenizer",
        name = "INNER JOIN",
        input = "SELECT * FROM a JOIN b ON a.id = b.id",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "a", line = 1, col = 15},
            {type = "keyword", text = "JOIN", line = 1, col = 17},
            {type = "identifier", text = "b", line = 1, col = 22},
            {type = "keyword", text = "ON", line = 1, col = 24},
            {type = "identifier", text = "a", line = 1, col = 27},
            {type = "dot", text = ".", line = 1, col = 28},
            {type = "identifier", text = "id", line = 1, col = 29},
            {type = "operator", text = "=", line = 1, col = 32},
            {type = "identifier", text = "b", line = 1, col = 34},
            {type = "dot", text = ".", line = 1, col = 35},
            {type = "identifier", text = "id", line = 1, col = 36}
        }
    },
    {
        id = 1508,
        type = "tokenizer",
        name = "LEFT JOIN",
        input = "SELECT * FROM a LEFT JOIN b ON a.id = b.id",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "a", line = 1, col = 15},
            {type = "keyword", text = "LEFT", line = 1, col = 17},
            {type = "keyword", text = "JOIN", line = 1, col = 22},
            {type = "identifier", text = "b", line = 1, col = 27},
            {type = "keyword", text = "ON", line = 1, col = 29},
            {type = "identifier", text = "a", line = 1, col = 32},
            {type = "dot", text = ".", line = 1, col = 33},
            {type = "identifier", text = "id", line = 1, col = 34},
            {type = "operator", text = "=", line = 1, col = 37},
            {type = "identifier", text = "b", line = 1, col = 39},
            {type = "dot", text = ".", line = 1, col = 40},
            {type = "identifier", text = "id", line = 1, col = 41}
        }
    },
    {
        id = 1509,
        type = "tokenizer",
        name = "Multiple JOINs",
        input = "SELECT * FROM a JOIN b ON a.id = b.aid JOIN c ON b.id = c.bid",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "a", line = 1, col = 15},
            {type = "keyword", text = "JOIN", line = 1, col = 17},
            {type = "identifier", text = "b", line = 1, col = 22},
            {type = "keyword", text = "ON", line = 1, col = 24},
            {type = "identifier", text = "a", line = 1, col = 27},
            {type = "dot", text = ".", line = 1, col = 28},
            {type = "identifier", text = "id", line = 1, col = 29},
            {type = "operator", text = "=", line = 1, col = 32},
            {type = "identifier", text = "b", line = 1, col = 34},
            {type = "dot", text = ".", line = 1, col = 35},
            {type = "identifier", text = "aid", line = 1, col = 36},
            {type = "keyword", text = "JOIN", line = 1, col = 40},
            {type = "identifier", text = "c", line = 1, col = 45},
            {type = "keyword", text = "ON", line = 1, col = 47},
            {type = "identifier", text = "b", line = 1, col = 50},
            {type = "dot", text = ".", line = 1, col = 51},
            {type = "identifier", text = "id", line = 1, col = 52},
            {type = "operator", text = "=", line = 1, col = 55},
            {type = "identifier", text = "c", line = 1, col = 57},
            {type = "dot", text = ".", line = 1, col = 58},
            {type = "identifier", text = "bid", line = 1, col = 59}
        }
    },

    -- INSERT statements
    {
        id = 1510,
        type = "tokenizer",
        name = "INSERT with VALUES",
        input = "INSERT INTO Users (Name) VALUES ('John')",
        expected = {
            {type = "keyword", text = "INSERT", line = 1, col = 1},
            {type = "keyword", text = "INTO", line = 1, col = 8},
            {type = "identifier", text = "Users", line = 1, col = 13},
            {type = "paren_open", text = "(", line = 1, col = 19},
            {type = "identifier", text = "Name", line = 1, col = 20},
            {type = "paren_close", text = ")", line = 1, col = 24},
            {type = "keyword", text = "VALUES", line = 1, col = 26},
            {type = "paren_open", text = "(", line = 1, col = 33},
            {type = "string", text = "'John'", line = 1, col = 34},
            {type = "paren_close", text = ")", line = 1, col = 40}
        }
    },
    {
        id = 1511,
        type = "tokenizer",
        name = "INSERT multiple columns",
        input = "INSERT INTO Users (Id, Name, Age) VALUES (1, 'John', 30)",
        expected = {
            {type = "keyword", text = "INSERT", line = 1, col = 1},
            {type = "keyword", text = "INTO", line = 1, col = 8},
            {type = "identifier", text = "Users", line = 1, col = 13},
            {type = "paren_open", text = "(", line = 1, col = 19},
            {type = "identifier", text = "Id", line = 1, col = 20},
            {type = "comma", text = ",", line = 1, col = 22},
            {type = "identifier", text = "Name", line = 1, col = 24},
            {type = "comma", text = ",", line = 1, col = 28},
            {type = "identifier", text = "Age", line = 1, col = 30},
            {type = "paren_close", text = ")", line = 1, col = 33},
            {type = "keyword", text = "VALUES", line = 1, col = 35},
            {type = "paren_open", text = "(", line = 1, col = 42},
            {type = "number", text = "1", line = 1, col = 43},
            {type = "comma", text = ",", line = 1, col = 44},
            {type = "string", text = "'John'", line = 1, col = 46},
            {type = "comma", text = ",", line = 1, col = 52},
            {type = "number", text = "30", line = 1, col = 54},
            {type = "paren_close", text = ")", line = 1, col = 56}
        }
    },

    -- UPDATE statements
    {
        id = 1512,
        type = "tokenizer",
        name = "UPDATE with SET",
        input = "UPDATE Users SET Name = 'Jane' WHERE Id = 1",
        expected = {
            {type = "keyword", text = "UPDATE", line = 1, col = 1},
            {type = "identifier", text = "Users", line = 1, col = 8},
            {type = "keyword", text = "SET", line = 1, col = 14},
            {type = "identifier", text = "Name", line = 1, col = 18},
            {type = "operator", text = "=", line = 1, col = 23},
            {type = "string", text = "'Jane'", line = 1, col = 25},
            {type = "keyword", text = "WHERE", line = 1, col = 32},
            {type = "identifier", text = "Id", line = 1, col = 38},
            {type = "operator", text = "=", line = 1, col = 41},
            {type = "number", text = "1", line = 1, col = 43}
        }
    },
    {
        id = 1513,
        type = "tokenizer",
        name = "UPDATE multiple columns",
        input = "UPDATE Users SET Name = 'Jane', Age = 25",
        expected = {
            {type = "keyword", text = "UPDATE", line = 1, col = 1},
            {type = "identifier", text = "Users", line = 1, col = 8},
            {type = "keyword", text = "SET", line = 1, col = 14},
            {type = "identifier", text = "Name", line = 1, col = 18},
            {type = "operator", text = "=", line = 1, col = 23},
            {type = "string", text = "'Jane'", line = 1, col = 25},
            {type = "comma", text = ",", line = 1, col = 31},
            {type = "identifier", text = "Age", line = 1, col = 33},
            {type = "operator", text = "=", line = 1, col = 37},
            {type = "number", text = "25", line = 1, col = 39}
        }
    },

    -- DELETE statements
    {
        id = 1514,
        type = "tokenizer",
        name = "DELETE with WHERE",
        input = "DELETE FROM Users WHERE Id = 1",
        expected = {
            {type = "keyword", text = "DELETE", line = 1, col = 1},
            {type = "keyword", text = "FROM", line = 1, col = 8},
            {type = "identifier", text = "Users", line = 1, col = 13},
            {type = "keyword", text = "WHERE", line = 1, col = 19},
            {type = "identifier", text = "Id", line = 1, col = 25},
            {type = "operator", text = "=", line = 1, col = 28},
            {type = "number", text = "1", line = 1, col = 30}
        }
    },

    -- Aggregate functions
    {
        id = 1515,
        type = "tokenizer",
        name = "COUNT(*)",
        input = "SELECT COUNT(*) FROM Users",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "COUNT", line = 1, col = 8},
            {type = "paren_open", text = "(", line = 1, col = 13},
            {type = "star", text = "*", line = 1, col = 14},
            {type = "paren_close", text = ")", line = 1, col = 15},
            {type = "keyword", text = "FROM", line = 1, col = 17},
            {type = "identifier", text = "Users", line = 1, col = 22}
        }
    },
    {
        id = 1516,
        type = "tokenizer",
        name = "Multiple aggregate functions",
        input = "SELECT COUNT(*), MAX(Age), MIN(Age) FROM Users",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "COUNT", line = 1, col = 8},
            {type = "paren_open", text = "(", line = 1, col = 13},
            {type = "star", text = "*", line = 1, col = 14},
            {type = "paren_close", text = ")", line = 1, col = 15},
            {type = "comma", text = ",", line = 1, col = 16},
            {type = "identifier", text = "MAX", line = 1, col = 18},
            {type = "paren_open", text = "(", line = 1, col = 21},
            {type = "identifier", text = "Age", line = 1, col = 22},
            {type = "paren_close", text = ")", line = 1, col = 25},
            {type = "comma", text = ",", line = 1, col = 26},
            {type = "identifier", text = "MIN", line = 1, col = 28},
            {type = "paren_open", text = "(", line = 1, col = 31},
            {type = "identifier", text = "Age", line = 1, col = 32},
            {type = "paren_close", text = ")", line = 1, col = 35},
            {type = "keyword", text = "FROM", line = 1, col = 37},
            {type = "identifier", text = "Users", line = 1, col = 42}
        }
    },

    -- ORDER BY and GROUP BY
    {
        id = 1517,
        type = "tokenizer",
        name = "ORDER BY",
        input = "SELECT * FROM Users ORDER BY Name",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "keyword", text = "ORDER", line = 1, col = 21},
            {type = "keyword", text = "BY", line = 1, col = 27},
            {type = "identifier", text = "Name", line = 1, col = 30}
        }
    },
    {
        id = 1518,
        type = "tokenizer",
        name = "GROUP BY with HAVING",
        input = "SELECT Age, COUNT(*) FROM Users GROUP BY Age HAVING COUNT(*) > 1",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "Age", line = 1, col = 8},
            {type = "comma", text = ",", line = 1, col = 11},
            {type = "identifier", text = "COUNT", line = 1, col = 13},
            {type = "paren_open", text = "(", line = 1, col = 18},
            {type = "star", text = "*", line = 1, col = 19},
            {type = "paren_close", text = ")", line = 1, col = 20},
            {type = "keyword", text = "FROM", line = 1, col = 22},
            {type = "identifier", text = "Users", line = 1, col = 27},
            {type = "keyword", text = "GROUP", line = 1, col = 33},
            {type = "keyword", text = "BY", line = 1, col = 39},
            {type = "identifier", text = "Age", line = 1, col = 42},
            {type = "keyword", text = "HAVING", line = 1, col = 46},
            {type = "identifier", text = "COUNT", line = 1, col = 53},
            {type = "paren_open", text = "(", line = 1, col = 58},
            {type = "star", text = "*", line = 1, col = 59},
            {type = "paren_close", text = ")", line = 1, col = 60},
            {type = "operator", text = ">", line = 1, col = 62},
            {type = "number", text = "1", line = 1, col = 64}
        }
    },

    -- TOP and DISTINCT
    {
        id = 1519,
        type = "tokenizer",
        name = "SELECT TOP",
        input = "SELECT TOP 10 * FROM Users",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "keyword", text = "TOP", line = 1, col = 8},
            {type = "number", text = "10", line = 1, col = 12},
            {type = "star", text = "*", line = 1, col = 15},
            {type = "keyword", text = "FROM", line = 1, col = 17},
            {type = "identifier", text = "Users", line = 1, col = 22}
        }
    },
    {
        id = 1520,
        type = "tokenizer",
        name = "SELECT DISTINCT",
        input = "SELECT DISTINCT Name FROM Users",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "keyword", text = "DISTINCT", line = 1, col = 8},
            {type = "identifier", text = "Name", line = 1, col = 17},
            {type = "keyword", text = "FROM", line = 1, col = 22},
            {type = "identifier", text = "Users", line = 1, col = 27}
        }
    },

    -- Multi-line statements with line/col tracking
    {
        id = 1521,
        type = "tokenizer",
        name = "Multi-line SELECT",
        input = "SELECT\n  Name,\n  Age\nFROM Users",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "Name", line = 2, col = 3},
            {type = "comma", text = ",", line = 2, col = 7},
            {type = "identifier", text = "Age", line = 3, col = 3},
            {type = "keyword", text = "FROM", line = 4, col = 1},
            {type = "identifier", text = "Users", line = 4, col = 6}
        }
    },
    {
        id = 1522,
        type = "tokenizer",
        name = "Multi-line JOIN",
        input = "SELECT *\nFROM a\nJOIN b ON a.id = b.id",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 2, col = 1},
            {type = "identifier", text = "a", line = 2, col = 6},
            {type = "keyword", text = "JOIN", line = 3, col = 1},
            {type = "identifier", text = "b", line = 3, col = 6},
            {type = "keyword", text = "ON", line = 3, col = 8},
            {type = "identifier", text = "a", line = 3, col = 11},
            {type = "dot", text = ".", line = 3, col = 12},
            {type = "identifier", text = "id", line = 3, col = 13},
            {type = "operator", text = "=", line = 3, col = 16},
            {type = "identifier", text = "b", line = 3, col = 18},
            {type = "dot", text = ".", line = 3, col = 19},
            {type = "identifier", text = "id", line = 3, col = 20}
        }
    },

    -- Statements with comments
    {
        id = 1523,
        type = "tokenizer",
        name = "SELECT with inline comment",
        input = "SELECT * /* all columns */ FROM Users",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 28},
            {type = "identifier", text = "Users", line = 1, col = 33}
        }
    },
    {
        id = 1524,
        type = "tokenizer",
        name = "SELECT with end-of-line comment",
        input = "SELECT Name -- user name\nFROM Users",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "Name", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 2, col = 1},
            {type = "identifier", text = "Users", line = 2, col = 6}
        }
    },

    -- Complex WHERE clauses
    {
        id = 1525,
        type = "tokenizer",
        name = "WHERE with AND",
        input = "SELECT * FROM Users WHERE Age > 18 AND Active = 1",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "keyword", text = "WHERE", line = 1, col = 21},
            {type = "identifier", text = "Age", line = 1, col = 27},
            {type = "operator", text = ">", line = 1, col = 31},
            {type = "number", text = "18", line = 1, col = 33},
            {type = "keyword", text = "AND", line = 1, col = 36},
            {type = "identifier", text = "Active", line = 1, col = 40},
            {type = "operator", text = "=", line = 1, col = 47},
            {type = "number", text = "1", line = 1, col = 49}
        }
    },
    {
        id = 1526,
        type = "tokenizer",
        name = "WHERE with OR",
        input = "SELECT * FROM Users WHERE Age < 18 OR Age > 65",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "keyword", text = "WHERE", line = 1, col = 21},
            {type = "identifier", text = "Age", line = 1, col = 27},
            {type = "operator", text = "<", line = 1, col = 31},
            {type = "number", text = "18", line = 1, col = 33},
            {type = "keyword", text = "OR", line = 1, col = 36},
            {type = "identifier", text = "Age", line = 1, col = 39},
            {type = "operator", text = ">", line = 1, col = 43},
            {type = "number", text = "65", line = 1, col = 45}
        }
    },
    {
        id = 1527,
        type = "tokenizer",
        name = "WHERE with IN",
        input = "SELECT * FROM Users WHERE Id IN (1, 2, 3)",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "keyword", text = "WHERE", line = 1, col = 21},
            {type = "identifier", text = "Id", line = 1, col = 27},
            {type = "keyword", text = "IN", line = 1, col = 30},
            {type = "paren_open", text = "(", line = 1, col = 33},
            {type = "number", text = "1", line = 1, col = 34},
            {type = "comma", text = ",", line = 1, col = 35},
            {type = "number", text = "2", line = 1, col = 37},
            {type = "comma", text = ",", line = 1, col = 38},
            {type = "number", text = "3", line = 1, col = 40},
            {type = "paren_close", text = ")", line = 1, col = 41}
        }
    },
    {
        id = 1528,
        type = "tokenizer",
        name = "WHERE with LIKE",
        input = "SELECT * FROM Users WHERE Name LIKE 'John%'",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "keyword", text = "WHERE", line = 1, col = 21},
            {type = "identifier", text = "Name", line = 1, col = 27},
            {type = "keyword", text = "LIKE", line = 1, col = 32},
            {type = "string", text = "'John%'", line = 1, col = 37}
        }
    },
    {
        id = 1529,
        type = "tokenizer",
        name = "WHERE with BETWEEN",
        input = "SELECT * FROM Users WHERE Age BETWEEN 18 AND 65",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "keyword", text = "WHERE", line = 1, col = 21},
            {type = "identifier", text = "Age", line = 1, col = 27},
            {type = "keyword", text = "BETWEEN", line = 1, col = 31},
            {type = "number", text = "18", line = 1, col = 39},
            {type = "keyword", text = "AND", line = 1, col = 42},
            {type = "number", text = "65", line = 1, col = 46}
        }
    },
    {
        id = 1530,
        type = "tokenizer",
        name = "WHERE with IS NULL",
        input = "SELECT * FROM Users WHERE Email IS NULL",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "keyword", text = "WHERE", line = 1, col = 21},
            {type = "identifier", text = "Email", line = 1, col = 27},
            {type = "keyword", text = "IS", line = 1, col = 33},
            {type = "keyword", text = "NULL", line = 1, col = 36}
        }
    },
    {
        id = 1531,
        type = "tokenizer",
        name = "WHERE with IS NOT NULL",
        input = "SELECT * FROM Users WHERE Email IS NOT NULL",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "keyword", text = "WHERE", line = 1, col = 21},
            {type = "identifier", text = "Email", line = 1, col = 27},
            {type = "keyword", text = "IS", line = 1, col = 33},
            {type = "keyword", text = "NOT", line = 1, col = 36},
            {type = "keyword", text = "NULL", line = 1, col = 40}
        }
    },

    -- Subqueries
    {
        id = 1532,
        type = "tokenizer",
        name = "Subquery in WHERE",
        input = "SELECT * FROM Users WHERE Id IN (SELECT UserId FROM Orders)",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "keyword", text = "WHERE", line = 1, col = 21},
            {type = "identifier", text = "Id", line = 1, col = 27},
            {type = "keyword", text = "IN", line = 1, col = 30},
            {type = "paren_open", text = "(", line = 1, col = 33},
            {type = "keyword", text = "SELECT", line = 1, col = 34},
            {type = "identifier", text = "UserId", line = 1, col = 41},
            {type = "keyword", text = "FROM", line = 1, col = 48},
            {type = "identifier", text = "Orders", line = 1, col = 53},
            {type = "paren_close", text = ")", line = 1, col = 59}
        }
    },

    -- CASE expressions
    {
        id = 1533,
        type = "tokenizer",
        name = "CASE expression",
        input = "SELECT CASE WHEN Age < 18 THEN 'Minor' ELSE 'Adult' END FROM Users",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "keyword", text = "CASE", line = 1, col = 8},
            {type = "keyword", text = "WHEN", line = 1, col = 13},
            {type = "identifier", text = "Age", line = 1, col = 18},
            {type = "operator", text = "<", line = 1, col = 22},
            {type = "number", text = "18", line = 1, col = 24},
            {type = "keyword", text = "THEN", line = 1, col = 27},
            {type = "string", text = "'Minor'", line = 1, col = 32},
            {type = "keyword", text = "ELSE", line = 1, col = 40},
            {type = "string", text = "'Adult'", line = 1, col = 45},
            {type = "keyword", text = "END", line = 1, col = 53},
            {type = "keyword", text = "FROM", line = 1, col = 57},
            {type = "identifier", text = "Users", line = 1, col = 62}
        }
    },

    -- CTE (Common Table Expression)
    {
        id = 1534,
        type = "tokenizer",
        name = "CTE with WITH",
        input = "WITH CTE AS (SELECT * FROM Users) SELECT * FROM CTE",
        expected = {
            {type = "keyword", text = "WITH", line = 1, col = 1},
            {type = "identifier", text = "CTE", line = 1, col = 6},
            {type = "keyword", text = "AS", line = 1, col = 10},
            {type = "paren_open", text = "(", line = 1, col = 13},
            {type = "keyword", text = "SELECT", line = 1, col = 14},
            {type = "star", text = "*", line = 1, col = 21},
            {type = "keyword", text = "FROM", line = 1, col = 23},
            {type = "identifier", text = "Users", line = 1, col = 28},
            {type = "paren_close", text = ")", line = 1, col = 33},
            {type = "keyword", text = "SELECT", line = 1, col = 35},
            {type = "star", text = "*", line = 1, col = 42},
            {type = "keyword", text = "FROM", line = 1, col = 44},
            {type = "identifier", text = "CTE", line = 1, col = 49}
        }
    },

    -- UNION
    {
        id = 1535,
        type = "tokenizer",
        name = "UNION statement",
        input = "SELECT Id FROM Users UNION SELECT Id FROM Admins",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "Id", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 11},
            {type = "identifier", text = "Users", line = 1, col = 16},
            {type = "keyword", text = "UNION", line = 1, col = 22},
            {type = "keyword", text = "SELECT", line = 1, col = 28},
            {type = "identifier", text = "Id", line = 1, col = 35},
            {type = "keyword", text = "FROM", line = 1, col = 38},
            {type = "identifier", text = "Admins", line = 1, col = 43}
        }
    },

    -- CREATE TABLE
    {
        id = 1536,
        type = "tokenizer",
        name = "CREATE TABLE",
        input = "CREATE TABLE Users (Id INT, Name VARCHAR(100))",
        expected = {
            {type = "keyword", text = "CREATE", line = 1, col = 1},
            {type = "keyword", text = "TABLE", line = 1, col = 8},
            {type = "identifier", text = "Users", line = 1, col = 14},
            {type = "paren_open", text = "(", line = 1, col = 20},
            {type = "identifier", text = "Id", line = 1, col = 21},
            {type = "identifier", text = "INT", line = 1, col = 24},
            {type = "comma", text = ",", line = 1, col = 27},
            {type = "identifier", text = "Name", line = 1, col = 29},
            {type = "identifier", text = "VARCHAR", line = 1, col = 34},
            {type = "paren_open", text = "(", line = 1, col = 41},
            {type = "number", text = "100", line = 1, col = 42},
            {type = "paren_close", text = ")", line = 1, col = 45},
            {type = "paren_close", text = ")", line = 1, col = 46}
        }
    },

    -- Temp tables
    {
        id = 1537,
        type = "tokenizer",
        name = "SELECT INTO temp table",
        input = "SELECT * INTO #TempUsers FROM Users",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "INTO", line = 1, col = 10},
            {type = "hash", text = "#", line = 1, col = 15},
            {type = "identifier", text = "TempUsers", line = 1, col = 16},
            {type = "keyword", text = "FROM", line = 1, col = 26},
            {type = "identifier", text = "Users", line = 1, col = 31}
        }
    },

    -- Variables
    {
        id = 1538,
        type = "tokenizer",
        name = "DECLARE and SET variable",
        input = "DECLARE @name VARCHAR(50); SET @name = 'John'",
        expected = {
            {type = "keyword", text = "DECLARE", line = 1, col = 1},
            {type = "at", text = "@", line = 1, col = 9},
            {type = "identifier", text = "name", line = 1, col = 10},
            {type = "identifier", text = "VARCHAR", line = 1, col = 15},
            {type = "paren_open", text = "(", line = 1, col = 22},
            {type = "number", text = "50", line = 1, col = 23},
            {type = "paren_close", text = ")", line = 1, col = 25},
            {type = "semicolon", text = ";", line = 1, col = 26},
            {type = "keyword", text = "SET", line = 1, col = 28},
            {type = "at", text = "@", line = 1, col = 32},
            {type = "identifier", text = "name", line = 1, col = 33},
            {type = "operator", text = "=", line = 1, col = 38},
            {type = "string", text = "'John'", line = 1, col = 40}
        }
    },

    -- Statement terminator
    {
        id = 1539,
        type = "tokenizer",
        name = "Statement with semicolon",
        input = "SELECT * FROM Users;",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "semicolon", text = ";", line = 1, col = 20}
        }
    },

    -- Complex real-world example
    {
        id = 1540,
        type = "tokenizer",
        name = "Complex query with JOIN, WHERE, ORDER BY",
        input = "SELECT u.Name, o.OrderDate FROM Users u LEFT JOIN Orders o ON u.Id = o.UserId WHERE o.Total > 100 ORDER BY o.OrderDate DESC",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "u", line = 1, col = 8},
            {type = "dot", text = ".", line = 1, col = 9},
            {type = "identifier", text = "Name", line = 1, col = 10},
            {type = "comma", text = ",", line = 1, col = 14},
            {type = "identifier", text = "o", line = 1, col = 16},
            {type = "dot", text = ".", line = 1, col = 17},
            {type = "identifier", text = "OrderDate", line = 1, col = 18},
            {type = "keyword", text = "FROM", line = 1, col = 28},
            {type = "identifier", text = "Users", line = 1, col = 33},
            {type = "identifier", text = "u", line = 1, col = 39},
            {type = "keyword", text = "LEFT", line = 1, col = 41},
            {type = "keyword", text = "JOIN", line = 1, col = 46},
            {type = "identifier", text = "Orders", line = 1, col = 51},
            {type = "identifier", text = "o", line = 1, col = 58},
            {type = "keyword", text = "ON", line = 1, col = 60},
            {type = "identifier", text = "u", line = 1, col = 63},
            {type = "dot", text = ".", line = 1, col = 64},
            {type = "identifier", text = "Id", line = 1, col = 65},
            {type = "operator", text = "=", line = 1, col = 68},
            {type = "identifier", text = "o", line = 1, col = 70},
            {type = "dot", text = ".", line = 1, col = 71},
            {type = "identifier", text = "UserId", line = 1, col = 72},
            {type = "keyword", text = "WHERE", line = 1, col = 79},
            {type = "identifier", text = "o", line = 1, col = 85},
            {type = "dot", text = ".", line = 1, col = 86},
            {type = "identifier", text = "Total", line = 1, col = 87},
            {type = "operator", text = ">", line = 1, col = 93},
            {type = "number", text = "100", line = 1, col = 95},
            {type = "keyword", text = "ORDER", line = 1, col = 99},
            {type = "keyword", text = "BY", line = 1, col = 105},
            {type = "identifier", text = "o", line = 1, col = 108},
            {type = "dot", text = ".", line = 1, col = 109},
            {type = "identifier", text = "OrderDate", line = 1, col = 110},
            {type = "keyword", text = "DESC", line = 1, col = 120}
        }
    },
}
