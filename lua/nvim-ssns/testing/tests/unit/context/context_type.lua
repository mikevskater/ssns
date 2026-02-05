-- Test file: context_type.lua
-- IDs: 3551-3600
-- Tests: Context type classification in statement_context.lua
--
-- Test categories:
-- - 3551-3565: TABLE context type
-- - 3566-3580: COLUMN context type
-- - 3581-3590: KEYWORD context type
-- - 3591-3600: Other context types (PROCEDURE, DATABASE, SCHEMA, UNKNOWN)

return {
  -- ========================================
  -- TABLE Context Type (3551-3565)
  -- ========================================

  {
    id = 3551,
    type = "context",
    subtype = "type",
    name = "TABLE type for FROM clause",
    input = "SELECT * FROM |",
    cursor = { line = 1, col = 15 },
    expected = {
      type = "table",
      mode = "from",
    },
  },

  {
    id = 3552,
    type = "context",
    subtype = "type",
    name = "TABLE type for JOIN clause",
    input = "SELECT * FROM users u JOIN |",
    cursor = { line = 1, col = 29 },
    expected = {
      type = "table",
      mode = "join",
    },
  },

  {
    id = 3553,
    type = "context",
    subtype = "type",
    name = "TABLE type for UPDATE",
    input = "UPDATE |",
    cursor = { line = 1, col = 8 },
    expected = {
      type = "table",
      mode = "update",
    },
  },

  {
    id = 3554,
    type = "context",
    subtype = "type",
    name = "TABLE type for DELETE FROM",
    input = "DELETE FROM |",
    cursor = { line = 1, col = 13 },
    expected = {
      type = "table",
      mode = "delete",
    },
  },

  {
    id = 3555,
    type = "context",
    subtype = "type",
    name = "TABLE type for INSERT INTO",
    input = "INSERT INTO |",
    cursor = { line = 1, col = 13 },
    expected = {
      type = "table",
      mode = "insert",
    },
  },

  {
    id = 3556,
    type = "context",
    subtype = "type",
    name = "TABLE type with schema prefix",
    input = "SELECT * FROM dbo.|",
    cursor = { line = 1, col = 19 },
    expected = {
      type = "table",
      mode = "from_qualified",
      schema = "dbo",
    },
  },

  {
    id = 3557,
    type = "context",
    subtype = "type",
    name = "TABLE type with database prefix",
    input = "SELECT * FROM MyDB.dbo.|",
    cursor = { line = 1, col = 24 },
    expected = {
      type = "table",
      mode = "from_cross_db_qualified",
      database = "MyDB",
      schema = "dbo",
    },
  },

  {
    id = 3558,
    type = "context",
    subtype = "type",
    name = "TABLE type after comma in FROM",
    input = "SELECT * FROM users, |",
    cursor = { line = 1, col = 22 },
    expected = {
      type = "table",
      mode = "from",
    },
  },

  {
    id = 3559,
    type = "context",
    subtype = "type",
    name = "TABLE type in subquery",
    input = "SELECT * FROM (SELECT * FROM |",
    cursor = { line = 1, col = 30 },
    expected = {
      type = "table",
      mode = "from",
    },
  },

  {
    id = 3560,
    type = "context",
    subtype = "type",
    name = "TABLE type join_qualified mode",
    input = "SELECT * FROM users u JOIN dbo.|",
    cursor = { line = 1, col = 32 },
    expected = {
      type = "table",
      mode = "join_qualified",
      schema = "dbo",
    },
  },

  {
    id = 3561,
    type = "context",
    subtype = "type",
    name = "TABLE type from_qualified mode",
    input = "SELECT * FROM schema.|",
    cursor = { line = 1, col = 22 },
    expected = {
      type = "table",
      mode = "from_qualified",
      schema = "schema",
    },
  },

  {
    id = 3562,
    type = "context",
    subtype = "type",
    name = "TABLE type update mode",
    input = "UPDATE users SET|",
    cursor = { line = 1, col = 17 },
    expected = {
      type = "column",
      mode = "set",
    },
  },

  {
    id = 3563,
    type = "context",
    subtype = "type",
    name = "TABLE type delete mode",
    input = "DELETE FROM users WHERE|",
    cursor = { line = 1, col = 24 },
    expected = {
      type = "column",
      mode = "where",
    },
  },

  {
    id = 3564,
    type = "context",
    subtype = "type",
    name = "TABLE type insert mode",
    input = "INSERT INTO users (|",
    cursor = { line = 1, col = 20 },
    expected = {
      type = "column",
      mode = "insert_columns",
    },
  },

  {
    id = 3565,
    type = "context",
    subtype = "type",
    name = "TABLE type from_cross_db_qualified",
    input = "SELECT * FROM OtherDB.sys.|",
    cursor = { line = 1, col = 27 },
    expected = {
      type = "table",
      mode = "from_cross_db_qualified",
      database = "OtherDB",
      schema = "sys",
    },
  },

  -- ========================================
  -- COLUMN Context Type (3566-3580)
  -- ========================================

  {
    id = 3566,
    type = "context",
    subtype = "type",
    name = "COLUMN type for SELECT",
    input = "SELECT | FROM users",
    cursor = { line = 1, col = 8 },
    expected = {
      type = "column",
      mode = "select",
    },
  },

  {
    id = 3567,
    type = "context",
    subtype = "type",
    name = "COLUMN type for WHERE",
    input = "SELECT * FROM users WHERE |",
    cursor = { line = 1, col = 27 },
    expected = {
      type = "column",
      mode = "where",
    },
  },

  {
    id = 3568,
    type = "context",
    subtype = "type",
    name = "COLUMN type for ON clause",
    input = "SELECT * FROM users u JOIN orders o ON u.|",
    cursor = { line = 1, col = 42 },
    expected = {
      type = "column",
      mode = "on",
      left_side = "u",
    },
  },

  {
    id = 3569,
    type = "context",
    subtype = "type",
    name = "COLUMN type for ORDER BY",
    input = "SELECT * FROM users ORDER BY |",
    cursor = { line = 1, col = 30 },
    expected = {
      type = "column",
      mode = "order_by",
    },
  },

  {
    id = 3570,
    type = "context",
    subtype = "type",
    name = "COLUMN type for GROUP BY",
    input = "SELECT * FROM users GROUP BY |",
    cursor = { line = 1, col = 30 },
    expected = {
      type = "column",
      mode = "group_by",
    },
  },

  {
    id = 3571,
    type = "context",
    subtype = "type",
    name = "COLUMN type for HAVING",
    input = "SELECT * FROM users GROUP BY id HAVING |",
    cursor = { line = 1, col = 40 },
    expected = {
      type = "column",
      mode = "having",
    },
  },

  {
    id = 3572,
    type = "context",
    subtype = "type",
    name = "COLUMN type for SET (UPDATE)",
    input = "UPDATE users SET |",
    cursor = { line = 1, col = 18 },
    expected = {
      type = "column",
      mode = "set",
    },
  },

  {
    id = 3573,
    type = "context",
    subtype = "type",
    name = "COLUMN type qualified mode",
    input = "SELECT u.| FROM users u",
    cursor = { line = 1, col = 10 },
    expected = {
      type = "column",
      mode = "select_qualified",
      table = "u",
    },
  },

  {
    id = 3574,
    type = "context",
    subtype = "type",
    name = "COLUMN type select_qualified",
    input = "SELECT users.| FROM users",
    cursor = { line = 1, col = 14 },
    expected = {
      type = "column",
      mode = "select_qualified",
      table = "users",
    },
  },

  {
    id = 3575,
    type = "context",
    subtype = "type",
    name = "COLUMN type where_qualified",
    input = "SELECT * FROM users u WHERE u.|",
    cursor = { line = 1, col = 31 },
    expected = {
      type = "column",
      mode = "where_qualified",
      table = "u",
    },
  },

  {
    id = 3576,
    type = "context",
    subtype = "type",
    name = "COLUMN type insert_columns",
    input = "INSERT INTO users (name, |",
    cursor = { line = 1, col = 26 },
    expected = {
      type = "column",
      mode = "insert_columns",
    },
  },

  {
    id = 3577,
    type = "context",
    subtype = "type",
    name = "COLUMN type values mode",
    input = "INSERT INTO users (id, name) VALUES (|",
    cursor = { line = 1, col = 38 },
    expected = {
      type = "unknown",
      mode = "values",
    },
  },

  {
    id = 3578,
    type = "context",
    subtype = "type",
    name = "COLUMN type with left_side",
    input = "SELECT * FROM users u WHERE u.id = |",
    cursor = { line = 1, col = 36 },
    expected = {
      type = "column",
      mode = "where",
      left_side = "id",
    },
  },

  {
    id = 3579,
    type = "context",
    subtype = "type",
    name = "COLUMN type on mode with left_side",
    input = "SELECT * FROM users u JOIN orders o ON u.id = o.|",
    cursor = { line = 1, col = 49 },
    expected = {
      type = "column",
      mode = "on_qualified",
      table = "o",
      left_side = "id",
    },
  },

  {
    id = 3580,
    type = "context",
    subtype = "type",
    name = "COLUMN type multi-table dedup",
    input = "SELECT * FROM users u, orders o WHERE |",
    cursor = { line = 1, col = 39 },
    expected = {
      type = "column",
      mode = "where",
    },
  },

  -- ========================================
  -- KEYWORD Context Type (3581-3590)
  -- ========================================

  {
    id = 3581,
    type = "context",
    subtype = "type",
    name = "KEYWORD at statement start",
    input = "|",
    cursor = { line = 1, col = 1 },
    expected = {
      type = "keyword",
      mode = "start",
    },
  },

  {
    id = 3582,
    type = "context",
    subtype = "type",
    name = "KEYWORD after semicolon",
    input = "SELECT * FROM users; |",
    cursor = { line = 1, col = 22 },
    expected = {
      type = "keyword",
      mode = "start",
    },
  },

  {
    id = 3583,
    type = "context",
    subtype = "type",
    name = "KEYWORD after GO",
    input = "SELECT * FROM users\nGO\n|",
    cursor = { line = 3, col = 1 },
    expected = {
      type = "keyword",
      mode = "start",
    },
  },

  {
    id = 3584,
    type = "context",
    subtype = "type",
    name = "KEYWORD general mode",
    input = "SELECT * FROM users |",
    cursor = { line = 1, col = 21 },
    expected = {
      type = "keyword",
      mode = "general",
    },
  },

  {
    id = 3585,
    type = "context",
    subtype = "type",
    name = "KEYWORD start mode",
    input = "  |",
    cursor = { line = 1, col = 3 },
    expected = {
      type = "keyword",
      mode = "start",
    },
  },

  {
    id = 3586,
    type = "context",
    subtype = "type",
    name = "KEYWORD in empty buffer",
    input = "",
    cursor = { line = 1, col = 1 },
    expected = {
      type = "keyword",
      mode = "start",
    },
  },

  {
    id = 3587,
    type = "context",
    subtype = "type",
    name = "KEYWORD after complete statement",
    input = "SELECT * FROM users;\n|",
    cursor = { line = 2, col = 1 },
    expected = {
      type = "keyword",
      mode = "start",
    },
  },

  {
    id = 3588,
    type = "context",
    subtype = "type",
    name = "KEYWORD after DECLARE",
    input = "DECLARE @var INT; |",
    cursor = { line = 1, col = 19 },
    expected = {
      type = "keyword",
      mode = "general",
    },
  },

  {
    id = 3589,
    type = "context",
    subtype = "type",
    name = "KEYWORD between statements",
    input = "SELECT 1\n|\nSELECT 2",
    cursor = { line = 2, col = 1 },
    expected = {
      type = "keyword",
      mode = "start",
    },
  },

  {
    id = 3590,
    type = "context",
    subtype = "type",
    name = "KEYWORD with whitespace only",
    input = "   \n  |  \n   ",
    cursor = { line = 2, col = 3 },
    expected = {
      type = "keyword",
      mode = "start",
    },
  },

  -- ========================================
  -- Other Context Types (3591-3600)
  -- ========================================

  {
    id = 3591,
    type = "context",
    subtype = "type",
    name = "PROCEDURE type for EXEC",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    expected = {
      type = "procedure",
      mode = "exec",
    },
  },

  {
    id = 3592,
    type = "context",
    subtype = "type",
    name = "PROCEDURE type for EXECUTE",
    input = "EXECUTE |",
    cursor = { line = 1, col = 9 },
    expected = {
      type = "procedure",
      mode = "exec",
    },
  },

  {
    id = 3593,
    type = "context",
    subtype = "type",
    name = "PROCEDURE type with schema",
    input = "EXEC dbo.|",
    cursor = { line = 1, col = 10 },
    expected = {
      type = "procedure",
      mode = "exec_qualified",
      schema = "dbo",
    },
  },

  {
    id = 3594,
    type = "context",
    subtype = "type",
    name = "DATABASE type for USE",
    input = "USE |",
    cursor = { line = 1, col = 5 },
    expected = {
      type = "database",
      mode = "use",
    },
  },

  {
    id = 3595,
    type = "context",
    subtype = "type",
    name = "SCHEMA type for USE db.",
    input = "USE MyDB.|",
    cursor = { line = 1, col = 10 },
    expected = {
      type = "schema",
      mode = "use_qualified",
      database = "MyDB",
    },
  },

  {
    id = 3596,
    type = "context",
    subtype = "type",
    name = "PARAMETER type (future)",
    input = "EXEC sp_test @|",
    cursor = { line = 1, col = 15 },
    expected = {
      type = "parameter",
      mode = "exec_param",
    },
  },

  {
    id = 3597,
    type = "context",
    subtype = "type",
    name = "ALIAS type (future)",
    input = "SELECT * FROM users AS |",
    cursor = { line = 1, col = 24 },
    expected = {
      type = "alias",
      mode = "table_alias",
    },
  },

  {
    id = 3598,
    type = "context",
    subtype = "type",
    name = "UNKNOWN type in comment",
    input = "-- This is a comment |\nSELECT * FROM users",
    cursor = { line = 1, col = 21 },
    expected = {
      type = "unknown",
      mode = "comment",
    },
  },

  {
    id = 3599,
    type = "context",
    subtype = "type",
    name = "UNKNOWN type in string",
    input = "SELECT '|' FROM users",
    cursor = { line = 1, col = 9 },
    expected = {
      type = "unknown",
      mode = "string",
    },
  },

  {
    id = 3600,
    type = "context",
    subtype = "type",
    name = "UNKNOWN type edge case",
    input = "SELECT * FROM users WHERE id IN (|",
    cursor = { line = 1, col = 34 },
    expected = {
      type = "unknown",
      mode = "in_list",
    },
  },
}
