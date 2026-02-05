-- Test file: clause_detection.lua
-- IDs: 3501-3550
-- Tests: Clause position detection in statement_context.lua
--
-- Test categories:
-- - 3501-3510: SELECT clause detection
-- - 3511-3520: FROM clause detection
-- - 3521-3530: JOIN/ON clause detection
-- - 3531-3540: WHERE clause detection
-- - 3541-3550: Other clauses (GROUP BY, ORDER BY, INSERT, etc.)

return {
  -- ============================================================================
  -- SELECT Clause Detection (3501-3510)
  -- ============================================================================

  {
    id = 3501,
    type = "context",
    subtype = "clause",
    name = "Basic SELECT clause",
    input = "SELECT |",
    cursor = { line = 1, col = 8 },
    expected = {
      type = "column",
      mode = "select",
    },
  },

  {
    id = 3502,
    type = "context",
    subtype = "clause",
    name = "SELECT after whitespace",
    input = "SELECT    |",
    cursor = { line = 1, col = 11 },
    expected = {
      type = "column",
      mode = "select",
    },
  },

  {
    id = 3503,
    type = "context",
    subtype = "clause",
    name = "SELECT DISTINCT context",
    input = "SELECT DISTINCT |",
    cursor = { line = 1, col = 17 },
    expected = {
      type = "column",
      mode = "select",
    },
  },

  {
    id = 3504,
    type = "context",
    subtype = "clause",
    name = "SELECT TOP N context",
    input = "SELECT TOP 10 |",
    cursor = { line = 1, col = 15 },
    expected = {
      type = "column",
      mode = "select",
    },
  },

  {
    id = 3505,
    type = "context",
    subtype = "clause",
    name = "SELECT with columns (after comma)",
    input = "SELECT col1, |",
    cursor = { line = 1, col = 14 },
    expected = {
      type = "column",
      mode = "select",
    },
  },

  {
    id = 3506,
    type = "context",
    subtype = "clause",
    name = "SELECT subquery context",
    input = "SELECT * FROM (SELECT |",
    cursor = { line = 1, col = 23 },
    expected = {
      type = "column",
      mode = "select",
    },
  },

  {
    id = 3507,
    type = "context",
    subtype = "clause",
    name = "SELECT in CTE",
    input = "WITH cte AS (SELECT |)",
    cursor = { line = 1, col = 21 },
    expected = {
      type = "column",
      mode = "select",
    },
  },

  {
    id = 3508,
    type = "context",
    subtype = "clause",
    name = "SELECT after AS",
    input = "SELECT col1 AS |",
    cursor = { line = 1, col = 16 },
    expected = {
      type = "alias",
      mode = "column_alias",
    },
  },

  {
    id = 3509,
    type = "context",
    subtype = "clause",
    name = "SELECT expression context",
    input = "SELECT COUNT(|)",
    cursor = { line = 1, col = 14 },
    expected = {
      type = "column",
      mode = "expression",
    },
  },

  {
    id = 3510,
    type = "context",
    subtype = "clause",
    name = "SELECT case-insensitive",
    input = "select |",
    cursor = { line = 1, col = 8 },
    expected = {
      type = "column",
      mode = "select",
    },
  },

  -- ============================================================================
  -- FROM Clause Detection (3511-3520)
  -- ============================================================================

  {
    id = 3511,
    type = "context",
    subtype = "clause",
    name = "Basic FROM clause",
    input = "SELECT * FROM |",
    cursor = { line = 1, col = 15 },
    expected = {
      type = "table",
      mode = "from",
    },
  },

  {
    id = 3512,
    type = "context",
    subtype = "clause",
    name = "FROM after SELECT",
    input = "SELECT col1, col2 FROM |",
    cursor = { line = 1, col = 24 },
    expected = {
      type = "table",
      mode = "from",
    },
  },

  {
    id = 3513,
    type = "context",
    subtype = "clause",
    name = "FROM with schema prefix",
    input = "SELECT * FROM dbo.|",
    cursor = { line = 1, col = 19 },
    expected = {
      type = "table",
      mode = "from",
      schema = "dbo",
    },
  },

  {
    id = 3514,
    type = "context",
    subtype = "clause",
    name = "FROM with database.schema prefix",
    input = "SELECT * FROM MyDB.dbo.|",
    cursor = { line = 1, col = 24 },
    expected = {
      type = "table",
      mode = "from",
      database = "MyDB",
      schema = "dbo",
    },
  },

  {
    id = 3515,
    type = "context",
    subtype = "clause",
    name = "FROM after comma (multiple tables)",
    input = "SELECT * FROM table1, |",
    cursor = { line = 1, col = 23 },
    expected = {
      type = "table",
      mode = "from",
    },
  },

  {
    id = 3516,
    type = "context",
    subtype = "clause",
    name = "FROM subquery",
    input = "SELECT * FROM (SELECT * FROM |)",
    cursor = { line = 1, col = 30 },
    expected = {
      type = "table",
      mode = "from",
    },
  },

  {
    id = 3517,
    type = "context",
    subtype = "clause",
    name = "FROM after JOIN table",
    input = "SELECT * FROM table1 JOIN table2 ON table1.id = table2.id FROM |",
    cursor = { line = 1, col = 64 },
    expected = {
      type = "table",
      mode = "from",
    },
  },

  {
    id = 3518,
    type = "context",
    subtype = "clause",
    name = "FROM case-insensitive",
    input = "select * from |",
    cursor = { line = 1, col = 15 },
    expected = {
      type = "table",
      mode = "from",
    },
  },

  {
    id = 3519,
    type = "context",
    subtype = "clause",
    name = "FROM with brackets",
    input = "SELECT * FROM [|",
    cursor = { line = 1, col = 16 },
    expected = {
      type = "table",
      mode = "from",
    },
  },

  {
    id = 3520,
    type = "context",
    subtype = "clause",
    name = "FROM with alias context",
    input = "SELECT * FROM Users u|",
    cursor = { line = 1, col = 22 },
    expected = {
      type = "alias",
      mode = "table_alias",
    },
  },

  -- ============================================================================
  -- JOIN/ON Clause Detection (3521-3530)
  -- ============================================================================

  {
    id = 3521,
    type = "context",
    subtype = "clause",
    name = "Basic JOIN clause",
    input = "SELECT * FROM table1 JOIN |",
    cursor = { line = 1, col = 27 },
    expected = {
      type = "table",
      mode = "join",
    },
  },

  {
    id = 3522,
    type = "context",
    subtype = "clause",
    name = "INNER JOIN clause",
    input = "SELECT * FROM table1 INNER JOIN |",
    cursor = { line = 1, col = 33 },
    expected = {
      type = "table",
      mode = "join",
      join_type = "INNER",
    },
  },

  {
    id = 3523,
    type = "context",
    subtype = "clause",
    name = "LEFT JOIN clause",
    input = "SELECT * FROM table1 LEFT JOIN |",
    cursor = { line = 1, col = 32 },
    expected = {
      type = "table",
      mode = "join",
      join_type = "LEFT",
    },
  },

  {
    id = 3524,
    type = "context",
    subtype = "clause",
    name = "RIGHT JOIN clause",
    input = "SELECT * FROM table1 RIGHT JOIN |",
    cursor = { line = 1, col = 33 },
    expected = {
      type = "table",
      mode = "join",
      join_type = "RIGHT",
    },
  },

  {
    id = 3525,
    type = "context",
    subtype = "clause",
    name = "FULL OUTER JOIN clause",
    input = "SELECT * FROM table1 FULL OUTER JOIN |",
    cursor = { line = 1, col = 38 },
    expected = {
      type = "table",
      mode = "join",
      join_type = "FULL OUTER",
    },
  },

  {
    id = 3526,
    type = "context",
    subtype = "clause",
    name = "CROSS JOIN clause",
    input = "SELECT * FROM table1 CROSS JOIN |",
    cursor = { line = 1, col = 33 },
    expected = {
      type = "table",
      mode = "join",
      join_type = "CROSS",
    },
  },

  {
    id = 3527,
    type = "context",
    subtype = "clause",
    name = "ON clause after table",
    input = "SELECT * FROM table1 JOIN table2 ON |",
    cursor = { line = 1, col = 37 },
    expected = {
      type = "column",
      mode = "on_condition",
    },
  },

  {
    id = 3528,
    type = "context",
    subtype = "clause",
    name = "ON clause after alias",
    input = "SELECT * FROM Users u JOIN Orders o ON u.|",
    cursor = { line = 1, col = 42 },
    expected = {
      type = "column",
      mode = "on_condition",
      table_alias = "u",
    },
  },

  {
    id = 3529,
    type = "context",
    subtype = "clause",
    name = "Multiple JOIN detection",
    input = "SELECT * FROM t1 JOIN t2 ON t1.id = t2.id JOIN |",
    cursor = { line = 1, col = 48 },
    expected = {
      type = "table",
      mode = "join",
    },
  },

  {
    id = 3530,
    type = "context",
    subtype = "clause",
    name = "ON with AND condition",
    input = "SELECT * FROM t1 JOIN t2 ON t1.id = t2.id AND |",
    cursor = { line = 1, col = 47 },
    expected = {
      type = "column",
      mode = "on_condition",
    },
  },

  -- ============================================================================
  -- WHERE Clause Detection (3531-3540)
  -- ============================================================================

  {
    id = 3531,
    type = "context",
    subtype = "clause",
    name = "Basic WHERE clause",
    input = "SELECT * FROM Users WHERE |",
    cursor = { line = 1, col = 27 },
    expected = {
      type = "column",
      mode = "where",
    },
  },

  {
    id = 3532,
    type = "context",
    subtype = "clause",
    name = "WHERE after FROM",
    input = "SELECT col1, col2 FROM table1 WHERE |",
    cursor = { line = 1, col = 37 },
    expected = {
      type = "column",
      mode = "where",
    },
  },

  {
    id = 3533,
    type = "context",
    subtype = "clause",
    name = "WHERE after AND",
    input = "SELECT * FROM Users WHERE status = 1 AND |",
    cursor = { line = 1, col = 42 },
    expected = {
      type = "column",
      mode = "where",
    },
  },

  {
    id = 3534,
    type = "context",
    subtype = "clause",
    name = "WHERE after OR",
    input = "SELECT * FROM Users WHERE status = 1 OR |",
    cursor = { line = 1, col = 41 },
    expected = {
      type = "column",
      mode = "where",
    },
  },

  {
    id = 3535,
    type = "context",
    subtype = "clause",
    name = "WHERE comparison context",
    input = "SELECT * FROM Users WHERE name = |",
    cursor = { line = 1, col = 34 },
    expected = {
      type = "value",
      mode = "comparison",
      column = "name",
    },
  },

  {
    id = 3536,
    type = "context",
    subtype = "clause",
    name = "WHERE IN subquery",
    input = "SELECT * FROM Users WHERE id IN (SELECT |)",
    cursor = { line = 1, col = 41 },
    expected = {
      type = "column",
      mode = "select",
    },
  },

  {
    id = 3537,
    type = "context",
    subtype = "clause",
    name = "WHERE EXISTS",
    input = "SELECT * FROM Users WHERE EXISTS (SELECT |)",
    cursor = { line = 1, col = 42 },
    expected = {
      type = "column",
      mode = "select",
    },
  },

  {
    id = 3538,
    type = "context",
    subtype = "clause",
    name = "WHERE BETWEEN",
    input = "SELECT * FROM Orders WHERE price BETWEEN 10 AND |",
    cursor = { line = 1, col = 49 },
    expected = {
      type = "value",
      mode = "between",
      column = "price",
    },
  },

  {
    id = 3539,
    type = "context",
    subtype = "clause",
    name = "WHERE LIKE",
    input = "SELECT * FROM Users WHERE name LIKE |",
    cursor = { line = 1, col = 37 },
    expected = {
      type = "value",
      mode = "pattern",
      column = "name",
    },
  },

  {
    id = 3540,
    type = "context",
    subtype = "clause",
    name = "WHERE nested parentheses",
    input = "SELECT * FROM Users WHERE (status = 1 AND (|))",
    cursor = { line = 1, col = 44 },
    expected = {
      type = "column",
      mode = "where",
    },
  },

  -- ============================================================================
  -- Other Clauses (3541-3550)
  -- ============================================================================

  {
    id = 3541,
    type = "context",
    subtype = "clause",
    name = "GROUP BY clause",
    input = "SELECT col1, COUNT(*) FROM table1 GROUP BY |",
    cursor = { line = 1, col = 44 },
    expected = {
      type = "column",
      mode = "group_by",
    },
  },

  {
    id = 3542,
    type = "context",
    subtype = "clause",
    name = "HAVING clause",
    input = "SELECT col1, COUNT(*) FROM table1 GROUP BY col1 HAVING |",
    cursor = { line = 1, col = 56 },
    expected = {
      type = "column",
      mode = "having",
    },
  },

  {
    id = 3543,
    type = "context",
    subtype = "clause",
    name = "ORDER BY clause",
    input = "SELECT * FROM Users ORDER BY |",
    cursor = { line = 1, col = 30 },
    expected = {
      type = "column",
      mode = "order_by",
    },
  },

  {
    id = 3544,
    type = "context",
    subtype = "clause",
    name = "UPDATE SET clause",
    input = "UPDATE Users SET |",
    cursor = { line = 1, col = 18 },
    expected = {
      type = "column",
      mode = "update_set",
    },
  },

  {
    id = 3545,
    type = "context",
    subtype = "clause",
    name = "INSERT INTO clause",
    input = "INSERT INTO |",
    cursor = { line = 1, col = 13 },
    expected = {
      type = "table",
      mode = "insert",
    },
  },

  {
    id = 3546,
    type = "context",
    subtype = "clause",
    name = "INSERT column list",
    input = "INSERT INTO Users (|)",
    cursor = { line = 1, col = 20 },
    expected = {
      type = "column",
      mode = "insert_columns",
      table = "Users",
    },
  },

  {
    id = 3547,
    type = "context",
    subtype = "clause",
    name = "VALUES clause",
    input = "INSERT INTO Users (name, email) VALUES (|)",
    cursor = { line = 1, col = 41 },
    expected = {
      type = "value",
      mode = "insert_values",
      column_index = 1,
    },
  },

  {
    id = 3548,
    type = "context",
    subtype = "clause",
    name = "VALUES position tracking",
    input = "INSERT INTO Users (name, email) VALUES ('John', |)",
    cursor = { line = 1, col = 49 },
    expected = {
      type = "value",
      mode = "insert_values",
      column_index = 2,
    },
  },

  {
    id = 3549,
    type = "context",
    subtype = "clause",
    name = "EXEC clause",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    expected = {
      type = "procedure",
      mode = "execute",
    },
  },

  {
    id = 3550,
    type = "context",
    subtype = "clause",
    name = "USE clause",
    input = "USE |",
    cursor = { line = 1, col = 5 },
    expected = {
      type = "database",
      mode = "use",
    },
  },
}
