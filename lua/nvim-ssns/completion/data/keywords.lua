---SQL keyword definitions for completion
---@class KeywordData
local Keywords = {}

---Common SQL keywords (all databases)
Keywords.common = {
  -- Statement starters (DML)
  "SELECT", "INSERT", "UPDATE", "DELETE",

  -- Statement starters (DDL)
  "CREATE", "ALTER", "DROP", "TRUNCATE",

  -- Statement starters (DCL)
  "GRANT", "REVOKE",

  -- Statement starters (TCL)
  "BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT",

  -- Clauses
  "FROM", "WHERE", "JOIN", "ON", "GROUP BY", "HAVING", "ORDER BY",
  "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "FULL JOIN", "CROSS JOIN",

  -- Operators
  "AND", "OR", "NOT", "IN", "EXISTS", "LIKE", "BETWEEN", "IS NULL", "IS NOT NULL",

  -- Modifiers
  "DISTINCT", "ALL", "AS", "ASC", "DESC",

  -- Set operations
  "UNION", "UNION ALL", "INTERSECT", "EXCEPT",

  -- Other
  "CASE", "WHEN", "THEN", "ELSE", "END",
  "IF", "WHILE", "RETURN", "DECLARE", "SET",
}

---SQL Server specific keywords
Keywords.sqlserver = {
  "TOP", "WITH", "NOLOCK", "ROWLOCK", "UPDLOCK",
  "EXEC", "EXECUTE", "GO", "USE",
  "IDENTITY", "UNIQUEIDENTIFIER", "NEWID", "NEWSEQUENTIALID",
  "TRY", "CATCH", "THROW", "RAISERROR",
  "OUTPUT", "INSERTED", "DELETED",
  "MERGE", "OVER", "PARTITION BY", "ROW_NUMBER",
}

---PostgreSQL specific keywords
Keywords.postgres = {
  "LIMIT", "OFFSET", "RETURNING",
  "ILIKE", "SIMILAR TO", "REGEXP",
  "SERIAL", "BIGSERIAL", "UUID", "JSONB",
  "LATERAL", "TABLESAMPLE",
  "NULLS FIRST", "NULLS LAST",
  "ON CONFLICT", "DO NOTHING", "DO UPDATE",
}

---MySQL specific keywords
Keywords.mysql = {
  "LIMIT", "AUTO_INCREMENT",
  "ENUM", "SET", "JSON",
  "REPLACE", "INSERT IGNORE",
  "ON DUPLICATE KEY UPDATE",
  "SHOW", "DESCRIBE", "EXPLAIN",
}

---SQLite specific keywords
Keywords.sqlite = {
  "LIMIT", "AUTOINCREMENT",
  "PRAGMA", "VACUUM", "ANALYZE",
  "ATTACH", "DETACH",
  "EXPLAIN QUERY PLAN",
}

---Get keywords for specific database type
---@param db_type string Database type (sqlserver, postgres, mysql, sqlite)
---@return string[] keywords Combined keyword list
function Keywords.get_for_database(db_type)
  local result = vim.deepcopy(Keywords.common)

  if db_type == "sqlserver" then
    vim.list_extend(result, Keywords.sqlserver)
  elseif db_type == "postgres" or db_type == "postgresql" then
    vim.list_extend(result, Keywords.postgres)
  elseif db_type == "mysql" then
    vim.list_extend(result, Keywords.mysql)
  elseif db_type == "sqlite" then
    vim.list_extend(result, Keywords.sqlite)
  end

  return result
end

---Get keywords appropriate for context
---@param context string Context type: "start", "after_select", "after_from", "after_where", "after_join"
---@param db_type string? Database type (optional)
---@return string[] keywords Filtered keyword list
function Keywords.get_for_context(context, db_type)
  if context == "start" then
    -- Statement starters
    return {
      "SELECT", "INSERT", "UPDATE", "DELETE",
      "CREATE", "ALTER", "DROP", "TRUNCATE",
      "BEGIN", "COMMIT", "ROLLBACK",
      "EXEC", "EXECUTE", "USE", "GO",
    }
  elseif context == "after_select" then
    -- After SELECT keyword
    local result = { "DISTINCT", "ALL", "*" }
    if db_type == "sqlserver" then
      table.insert(result, "TOP")
    end
    return result
  elseif context == "after_from" then
    -- After FROM clause
    return {
      "WHERE", "JOIN", "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "FULL JOIN", "CROSS JOIN",
      "ORDER BY", "GROUP BY", "HAVING",
      "UNION", "UNION ALL", "INTERSECT", "EXCEPT",
    }
  elseif context == "after_where" then
    -- After WHERE clause
    return {
      "AND", "OR", "NOT", "IN", "EXISTS", "LIKE", "BETWEEN",
      "IS NULL", "IS NOT NULL",
      "ORDER BY", "GROUP BY",
    }
  elseif context == "after_join" then
    -- After JOIN keyword
    return {
      "ON", "INNER", "LEFT", "RIGHT", "FULL", "CROSS",
    }
  else
    -- Default: all keywords
    return Keywords.get_for_database(db_type or "sqlserver")
  end
end

return Keywords
