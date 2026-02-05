-- Test file: keywords_provider.lua
-- IDs: 3301-3350
-- Tests: KeywordsProvider completion for SQL keywords by context
--
-- Test categories:
-- - 3301-3310: Statement start keywords
-- - 3311-3320: After SELECT keywords
-- - 3321-3330: After FROM keywords
-- - 3331-3340: After WHERE keywords
-- - 3341-3350: After JOIN keywords

return {
  -- ============================================================================
  -- Statement Start Keywords (3301-3310) - 10 tests
  -- ============================================================================

  {
    id = 3301,
    type = "provider",
    provider = "keywords",
    name = "Statement starters (SELECT, INSERT, UPDATE, DELETE)",
    input = "|",
    cursor = { line = 1, col = 1 },
    context = {
      mode = "default",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "SELECT", "INSERT", "UPDATE", "DELETE", "WITH" },
      },
    },
  },

  {
    id = 3302,
    type = "provider",
    provider = "keywords",
    name = "DDL keywords at statement start (CREATE, ALTER, DROP)",
    input = "|",
    cursor = { line = 1, col = 1 },
    context = {
      mode = "default",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "CREATE", "ALTER", "DROP", "TRUNCATE" },
      },
    },
  },

  {
    id = 3303,
    type = "provider",
    provider = "keywords",
    name = "Transaction keywords at start (BEGIN, COMMIT, ROLLBACK)",
    input = "|",
    cursor = { line = 1, col = 1 },
    context = {
      mode = "default",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT" },
      },
    },
  },

  {
    id = 3304,
    type = "provider",
    provider = "keywords",
    name = "SQL Server specific keywords (EXEC, GO, USE)",
    input = "|",
    cursor = { line = 1, col = 1 },
    context = {
      mode = "default",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "EXEC", "EXECUTE", "USE", "GO", "PRINT", "DECLARE" },
      },
    },
  },

  {
    id = 3305,
    type = "provider",
    provider = "keywords",
    name = "Empty buffer start - all statement keywords available",
    input = "|",
    cursor = { line = 1, col = 1 },
    context = {
      mode = "default",
      connection = { database = "vim_dadbod_test", db_type = "postgres" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "DROP" },
      },
    },
  },

  {
    id = 3306,
    type = "provider",
    provider = "keywords",
    name = "After GO statement - new statement context",
    input = "SELECT 1\nGO\n|",
    cursor = { line = 3, col = 1 },
    context = {
      mode = "default",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "SELECT", "INSERT", "UPDATE", "DELETE" },
      },
    },
  },

  {
    id = 3307,
    type = "provider",
    provider = "keywords",
    name = "After semicolon - new statement context",
    input = "SELECT 1;|",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "default",
      connection = { database = "vim_dadbod_test", db_type = "postgres" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "SELECT", "INSERT", "UPDATE", "DELETE" },
      },
    },
  },

  {
    id = 3308,
    type = "provider",
    provider = "keywords",
    name = "Case insensitivity - lowercase prefix matches uppercase keywords",
    input = "sel|",
    cursor = { line = 1, col = 4 },
    context = {
      mode = "default",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "SELECT" },
        excludes = { "INSERT", "UPDATE" },
      },
    },
  },

  {
    id = 3309,
    type = "provider",
    provider = "keywords",
    name = "Partial prefix 'SEL' matches SELECT",
    input = "SEL|",
    cursor = { line = 1, col = 4 },
    context = {
      mode = "default",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "SELECT" },
        excludes = { "DELETE", "UPDATE" },
      },
    },
  },

  {
    id = 3310,
    type = "provider",
    provider = "keywords",
    name = "Multiple word keyword prefix 'CREATE TAB'",
    input = "CREATE TAB|",
    cursor = { line = 1, col = 11 },
    context = {
      mode = "default",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "TABLE" },
      },
    },
  },

  -- ============================================================================
  -- After SELECT Keywords (3311-3320) - 10 tests
  -- ============================================================================

  {
    id = 3311,
    type = "provider",
    provider = "keywords",
    name = "After SELECT - DISTINCT, ALL, TOP (SQL Server)",
    input = "SELECT |",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "after_select",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "DISTINCT", "ALL", "TOP" },
      },
    },
  },

  {
    id = 3312,
    type = "provider",
    provider = "keywords",
    name = "After SELECT - TOP N syntax suggestion",
    input = "SELECT TOP|",
    cursor = { line = 1, col = 11 },
    context = {
      mode = "after_select",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "TOP" },
      },
    },
  },

  {
    id = 3313,
    type = "provider",
    provider = "keywords",
    name = "After SELECT - No TOP for PostgreSQL",
    input = "SELECT |",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "after_select",
      connection = { database = "vim_dadbod_test", db_type = "postgres" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "DISTINCT", "ALL" },
        excludes = { "TOP" },
      },
    },
  },

  {
    id = 3314,
    type = "provider",
    provider = "keywords",
    name = "After SELECT - Asterisk suggestion available",
    input = "SELECT |",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "after_select",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "*" },
      },
    },
  },

  {
    id = 3315,
    type = "provider",
    provider = "keywords",
    name = "After SELECT DISTINCT - column context",
    input = "SELECT DISTINCT |",
    cursor = { line = 1, col = 17 },
    context = {
      mode = "after_select",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        excludes = { "DISTINCT", "ALL" },
      },
    },
  },

  {
    id = 3316,
    type = "provider",
    provider = "keywords",
    name = "After SELECT expression - continuation keywords",
    input = "SELECT column1 |",
    cursor = { line = 1, col = 16 },
    context = {
      mode = "after_select",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "FROM", "AS", "," },
      },
    },
  },

  {
    id = 3317,
    type = "provider",
    provider = "keywords",
    name = "After SELECT - Aggregate keywords (COUNT, SUM, AVG)",
    input = "SELECT |",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "after_select",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "COUNT", "SUM", "AVG", "MIN", "MAX" },
      },
    },
  },

  {
    id = 3318,
    type = "provider",
    provider = "keywords",
    name = "After SELECT - CASE keyword available",
    input = "SELECT |",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "after_select",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "CASE" },
      },
    },
  },

  {
    id = 3319,
    type = "provider",
    provider = "keywords",
    name = "After SELECT in subquery context",
    input = "SELECT * FROM (SELECT |",
    cursor = { line = 1, col = 23 },
    context = {
      mode = "after_select",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "DISTINCT", "ALL", "TOP", "*" },
      },
    },
  },

  {
    id = 3320,
    type = "provider",
    provider = "keywords",
    name = "After SELECT for PostgreSQL - LIMIT context awareness",
    input = "SELECT |",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "after_select",
      connection = { database = "vim_dadbod_test", db_type = "postgres" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "DISTINCT", "ALL" },
        excludes = { "TOP", "LIMIT" },
      },
    },
  },

  -- ============================================================================
  -- After FROM Keywords (3321-3330) - 10 tests
  -- ============================================================================

  {
    id = 3321,
    type = "provider",
    provider = "keywords",
    name = "After FROM table - clause continuations (WHERE, JOIN, etc.)",
    input = "SELECT * FROM users |",
    cursor = { line = 1, col = 21 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "WHERE", "JOIN", "INNER JOIN", "LEFT JOIN", "ORDER BY", "GROUP BY" },
      },
    },
  },

  {
    id = 3322,
    type = "provider",
    provider = "keywords",
    name = "After FROM - All JOIN types available",
    input = "SELECT * FROM users |",
    cursor = { line = 1, col = 21 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "JOIN", "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "FULL OUTER JOIN", "CROSS JOIN" },
      },
    },
  },

  {
    id = 3323,
    type = "provider",
    provider = "keywords",
    name = "After FROM - Set operations (UNION, INTERSECT, EXCEPT)",
    input = "SELECT * FROM users |",
    cursor = { line = 1, col = 21 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "UNION", "INTERSECT", "EXCEPT" },
      },
    },
  },

  {
    id = 3324,
    type = "provider",
    provider = "keywords",
    name = "After FROM - ORDER BY, GROUP BY available",
    input = "SELECT * FROM users |",
    cursor = { line = 1, col = 21 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "ORDER BY", "GROUP BY" },
      },
    },
  },

  {
    id = 3325,
    type = "provider",
    provider = "keywords",
    name = "After FROM - HAVING keyword (with GROUP BY)",
    input = "SELECT * FROM users |",
    cursor = { line = 1, col = 21 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "HAVING" },
      },
    },
  },

  {
    id = 3326,
    type = "provider",
    provider = "keywords",
    name = "After FROM with alias - continuation keywords",
    input = "SELECT * FROM users u |",
    cursor = { line = 1, col = 23 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "WHERE", "JOIN", "ORDER BY" },
      },
    },
  },

  {
    id = 3327,
    type = "provider",
    provider = "keywords",
    name = "After FROM with multiple tables - continuation keywords",
    input = "SELECT * FROM users, orders |",
    cursor = { line = 1, col = 29 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "WHERE", "ORDER BY", "GROUP BY" },
      },
    },
  },

  {
    id = 3328,
    type = "provider",
    provider = "keywords",
    name = "After FROM - SQL Server hints (NOLOCK, READUNCOMMITTED)",
    input = "SELECT * FROM users WITH (|",
    cursor = { line = 1, col = 27 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "NOLOCK", "READUNCOMMITTED", "ROWLOCK", "UPDLOCK" },
      },
    },
  },

  {
    id = 3329,
    type = "provider",
    provider = "keywords",
    name = "After FROM - PostgreSQL LATERAL keyword",
    input = "SELECT * FROM users, |",
    cursor = { line = 1, col = 22 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "postgres" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "LATERAL" },
      },
    },
  },

  {
    id = 3330,
    type = "provider",
    provider = "keywords",
    name = "After FROM subquery - continuation keywords",
    input = "SELECT * FROM (SELECT * FROM users) u |",
    cursor = { line = 1, col = 39 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "WHERE", "JOIN", "ORDER BY" },
      },
    },
  },

  -- ============================================================================
  -- After WHERE Keywords (3331-3340) - 10 tests
  -- ============================================================================

  {
    id = 3331,
    type = "provider",
    provider = "keywords",
    name = "After WHERE condition - logical operators (AND, OR, NOT)",
    input = "SELECT * FROM users WHERE id = 1 |",
    cursor = { line = 1, col = 34 },
    context = {
      mode = "after_where",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "AND", "OR" },
      },
    },
  },

  {
    id = 3332,
    type = "provider",
    provider = "keywords",
    name = "After WHERE - comparison keywords (IN, EXISTS, BETWEEN)",
    input = "SELECT * FROM users WHERE id |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "after_where",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "IN", "EXISTS", "BETWEEN", "LIKE", "NOT IN" },
      },
    },
  },

  {
    id = 3333,
    type = "provider",
    provider = "keywords",
    name = "After WHERE - NULL checks (IS NULL, IS NOT NULL)",
    input = "SELECT * FROM users WHERE name |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "after_where",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "IS NULL", "IS NOT NULL" },
      },
    },
  },

  {
    id = 3334,
    type = "provider",
    provider = "keywords",
    name = "After WHERE - LIKE keyword available",
    input = "SELECT * FROM users WHERE name |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "after_where",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "LIKE", "NOT LIKE" },
      },
    },
  },

  {
    id = 3335,
    type = "provider",
    provider = "keywords",
    name = "After WHERE comparison operator - no operator keywords",
    input = "SELECT * FROM users WHERE id = |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "after_where",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        excludes = { "IN", "LIKE", "BETWEEN" },
      },
    },
  },

  {
    id = 3336,
    type = "provider",
    provider = "keywords",
    name = "After WHERE...AND - new condition context",
    input = "SELECT * FROM users WHERE id = 1 AND |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "after_where",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "NOT", "EXISTS" },
        excludes = { "AND", "OR" },
      },
    },
  },

  {
    id = 3337,
    type = "provider",
    provider = "keywords",
    name = "After WHERE - nested conditions with parentheses",
    input = "SELECT * FROM users WHERE (id = 1 |",
    cursor = { line = 1, col = 35 },
    context = {
      mode = "after_where",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "AND", "OR" },
      },
    },
  },

  {
    id = 3338,
    type = "provider",
    provider = "keywords",
    name = "After WHERE - CASE keyword available",
    input = "SELECT * FROM users WHERE |",
    cursor = { line = 1, col = 27 },
    context = {
      mode = "after_where",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "CASE" },
      },
    },
  },

  {
    id = 3339,
    type = "provider",
    provider = "keywords",
    name = "After WHERE - subquery keywords (EXISTS, IN)",
    input = "SELECT * FROM users WHERE |",
    cursor = { line = 1, col = 27 },
    context = {
      mode = "after_where",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "EXISTS", "NOT EXISTS" },
      },
    },
  },

  {
    id = 3340,
    type = "provider",
    provider = "keywords",
    name = "After WHERE - PostgreSQL ILIKE and SIMILAR TO",
    input = "SELECT * FROM users WHERE name |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "after_where",
      connection = { database = "vim_dadbod_test", db_type = "postgres" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "ILIKE", "SIMILAR TO" },
      },
    },
  },

  -- ============================================================================
  -- After JOIN Keywords (3341-3350) - 10 tests
  -- ============================================================================

  {
    id = 3341,
    type = "provider",
    provider = "keywords",
    name = "After JOIN table - ON keyword",
    input = "SELECT * FROM users JOIN orders |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "after_join",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "ON" },
      },
    },
  },

  {
    id = 3342,
    type = "provider",
    provider = "keywords",
    name = "After FROM - JOIN types (INNER, LEFT, RIGHT)",
    input = "SELECT * FROM users |",
    cursor = { line = 1, col = 21 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "INNER JOIN", "LEFT JOIN", "RIGHT JOIN" },
      },
    },
  },

  {
    id = 3343,
    type = "provider",
    provider = "keywords",
    name = "After FROM - FULL OUTER JOIN keyword",
    input = "SELECT * FROM users |",
    cursor = { line = 1, col = 21 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "FULL OUTER JOIN", "FULL JOIN" },
      },
    },
  },

  {
    id = 3344,
    type = "provider",
    provider = "keywords",
    name = "After CROSS JOIN - no ON keyword (cartesian product)",
    input = "SELECT * FROM users CROSS JOIN orders |",
    cursor = { line = 1, col = 40 },
    context = {
      mode = "after_join",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        excludes = { "ON" },
        includes = { "WHERE", "JOIN" },
      },
    },
  },

  {
    id = 3345,
    type = "provider",
    provider = "keywords",
    name = "After JOIN ON condition - AND for multiple conditions",
    input = "SELECT * FROM users JOIN orders ON users.id = orders.user_id |",
    cursor = { line = 1, col = 62 },
    context = {
      mode = "after_join",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "AND" },
      },
    },
  },

  {
    id = 3346,
    type = "provider",
    provider = "keywords",
    name = "After JOIN ON clause - continuation keywords",
    input = "SELECT * FROM users JOIN orders ON users.id = orders.user_id |",
    cursor = { line = 1, col = 62 },
    context = {
      mode = "after_join",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "WHERE", "JOIN", "ORDER BY", "AND" },
      },
    },
  },

  {
    id = 3347,
    type = "provider",
    provider = "keywords",
    name = "After self-join - ON keyword with alias context",
    input = "SELECT * FROM users u1 JOIN users u2 |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "after_join",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "ON" },
      },
    },
  },

  {
    id = 3348,
    type = "provider",
    provider = "keywords",
    name = "PostgreSQL LATERAL JOIN support",
    input = "SELECT * FROM users u JOIN LATERAL |",
    cursor = { line = 1, col = 36 },
    context = {
      mode = "after_join",
      connection = { database = "vim_dadbod_test", db_type = "postgres" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "LATERAL" },
      },
    },
  },

  {
    id = 3349,
    type = "provider",
    provider = "keywords",
    name = "MySQL STRAIGHT_JOIN support",
    input = "SELECT * FROM users |",
    cursor = { line = 1, col = 21 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "mysql" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "STRAIGHT_JOIN" },
      },
    },
  },

  {
    id = 3350,
    type = "provider",
    provider = "keywords",
    name = "Edge case - partial JOIN keyword matching",
    input = "SELECT * FROM users LEF|",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "after_from",
      connection = { database = "vim_dadbod_test", db_type = "sqlserver" },
    },
    expected = {
      type = "keyword",
      items = {
        includes = { "LEFT JOIN" },
        excludes = { "RIGHT JOIN", "INNER JOIN" },
      },
    },
  },
}
