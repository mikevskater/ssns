---@module ssns.ui.panels.theme_preview_sql
---Preview SQL with pre-defined highlighting for theme picker
---Uses ContentBuilder for consistent styling throughout the plugin
---
---NOTE: SQL-specific styles are registered in ssns/init.lua via nvim_float.register_styles()
---This allows ContentBuilder to resolve style names like "statement" to "SsnsKeywordStatement"

local M = {}

local ContentBuilder = require('nvim-float.content')

---Build preview SQL content with highlights using ContentBuilder
---@return string[] lines, table[] highlights
function M.build()
  local cb = ContentBuilder.new()

  -- Helper to create a styled span (uses registered styles from init.lua)
  local function s(text, style)
    return { text = text, style = style }
  end

  -- ============================================
  -- Header comments
  -- ============================================
  cb:styled("-- ============================================", "comment")
  cb:styled("-- SSNS Theme Preview", "comment")
  cb:styled("-- This query showcases all highlight groups", "comment")
  cb:styled("-- ============================================", "comment")
  cb:blank()

  -- ============================================
  -- Database & Schema References
  -- ============================================
  cb:styled("-- Database & Schema References", "comment")
  cb:spans({
    s("USE", "statement"), { text = " " },
    s("master", "sql_database"), { text = ";" },
  })
  cb:spans({ s("GO", "statement") })
  cb:blank()

  -- ============================================
  -- SELECT Statement
  -- ============================================
  cb:styled("-- Statement Keywords (SELECT, INSERT, CREATE, etc.)", "comment")
  cb:spans({ s("SELECT", "statement") })

  cb:styled("    -- Column References", "comment")
  cb:spans({
    { text = "    " },
    s("u", "sql_alias"), { text = "." },
    s("id", "sql_column"), { text = "," },
  })
  cb:spans({
    { text = "    " },
    s("u", "sql_alias"), { text = "." },
    s("username", "sql_column"), { text = "," },
  })
  cb:spans({
    { text = "    " },
    s("u", "sql_alias"), { text = "." },
    s("email", "sql_column"), { text = "," },
  })
  cb:spans({
    { text = "    " },
    s("u", "sql_alias"), { text = "." },
    s("created_at", "sql_column"), { text = "," },
  })

  cb:styled("    -- Alias References", "comment")
  cb:spans({
    { text = "    " },
    s("o", "sql_alias"), { text = "." },
    s("order_total", "sql_column"), { text = " " },
    s("AS", "clause"), { text = " " },
    s("total", "sql_alias"), { text = "," },
  })

  cb:styled("    -- Function Keywords (COUNT, SUM, GETDATE, etc.)", "comment")
  cb:spans({
    { text = "    " },
    s("COUNT", "sql_function"), { text = "(*) " },
    s("AS", "clause"), { text = " " },
    s("order_count", "sql_alias"), { text = "," },
  })
  cb:spans({
    { text = "    " },
    s("SUM", "sql_function"), { text = "(" },
    s("o", "sql_alias"), { text = "." },
    s("amount", "sql_column"), { text = ") " },
    s("AS", "clause"), { text = " " },
    s("total_amount", "sql_alias"), { text = "," },
  })
  cb:spans({
    { text = "    " },
    s("GETDATE", "sql_function"), { text = "() " },
    s("AS", "clause"), { text = " " },
    s("current_date", "sql_alias"), { text = "," },
  })
  cb:spans({
    { text = "    " },
    s("CAST", "sql_function"), { text = "(" },
    s("u", "sql_alias"), { text = "." },
    s("balance", "sql_column"), { text = " " },
    s("AS", "clause"), { text = " " },
    s("DECIMAL", "datatype"), { text = "(" },
    s("10", "number"), { text = "," },
    s("2", "number"), { text = ")) " },
    s("AS", "clause"), { text = " " },
    s("balance", "sql_alias"), { text = "," },
  })
  cb:spans({
    { text = "    " },
    s("COALESCE", "sql_function"), { text = "(" },
    s("u", "sql_alias"), { text = "." },
    s("nickname", "sql_column"), { text = ", " },
    s("'N/A'", "string"), { text = ") " },
    s("AS", "clause"), { text = " " },
    s("display_name", "sql_alias"),
  })

  -- ============================================
  -- FROM clause with JOINs
  -- ============================================
  cb:styled("-- Clause Keywords (FROM, WHERE, JOIN, etc.)", "comment")
  cb:spans({
    s("FROM", "clause"), { text = " " },
    s("dbo", "sql_schema"), { text = "." },
    s("Users", "sql_table"), { text = " " },
    s("u", "sql_alias"),
  })

  cb:styled("-- Table & View References", "comment")
  cb:spans({
    s("INNER JOIN", "clause"), { text = " " },
    s("dbo", "sql_schema"), { text = "." },
    s("Orders", "sql_table"), { text = " " },
    s("o", "sql_alias"), { text = " " },
    s("ON", "clause"), { text = " " },
    s("u", "sql_alias"), { text = "." },
    s("id", "sql_column"), { text = " = " },
    s("o", "sql_alias"), { text = "." },
    s("user_id", "sql_column"),
  })
  cb:spans({
    s("LEFT JOIN", "clause"), { text = " " },
    s("dbo", "sql_schema"), { text = "." },
    s("UserProfiles", "sql_table"), { text = " " },
    s("up", "sql_alias"), { text = " " },
    s("ON", "clause"), { text = " " },
    s("u", "sql_alias"), { text = "." },
    s("id", "sql_column"), { text = " = " },
    s("up", "sql_alias"), { text = "." },
    s("user_id", "sql_column"),
  })

  -- ============================================
  -- WHERE clause with operators
  -- ============================================
  cb:styled("-- Operator Keywords (AND, OR, NOT, IN, BETWEEN)", "comment")
  cb:spans({
    s("WHERE", "clause"), { text = " " },
    s("u", "sql_alias"), { text = "." },
    s("status", "sql_column"), { text = " = " },
    s("'active'", "string"),
  })
  cb:spans({
    { text = "    " },
    s("AND", "sql_operator"), { text = " " },
    s("o", "sql_alias"), { text = "." },
    s("created_at", "sql_column"), { text = " " },
    s("BETWEEN", "sql_operator"), { text = " " },
    s("'2024-01-01'", "string"), { text = " " },
    s("AND", "sql_operator"), { text = " " },
    s("'2024-12-31'", "string"),
  })
  cb:spans({
    { text = "    " },
    s("AND", "sql_operator"), { text = " " },
    s("u", "sql_alias"), { text = "." },
    s("role", "sql_column"), { text = " " },
    s("IN", "sql_operator"), { text = " (" },
    s("'admin'", "string"), { text = ", " },
    s("'user'", "string"), { text = ", " },
    s("'moderator'", "string"), { text = ")" },
  })
  cb:spans({
    { text = "    " },
    s("OR", "sql_operator"), { text = " " },
    s("NOT", "sql_operator"), { text = " " },
    s("u", "sql_alias"), { text = "." },
    s("is_deleted", "sql_column"), { text = " = " },
    s("1", "number"),
  })

  cb:styled("-- Modifier Keywords (ASC, DESC, NOLOCK, etc.)", "comment")
  cb:spans({
    s("ORDER BY", "clause"), { text = " " },
    s("u", "sql_alias"), { text = "." },
    s("created_at", "sql_column"), { text = " " },
    s("DESC", "modifier"), { text = ", " },
    s("u", "sql_alias"), { text = "." },
    s("username", "sql_column"), { text = " " },
    s("ASC", "modifier"), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- Literals
  -- ============================================
  cb:styled("-- Number Literals", "comment")
  cb:spans({
    s("SELECT", "statement"), { text = " " },
    s("42", "number"), { text = ", " },
    s("3.14159", "number"), { text = ", " },
    s("-100", "number"), { text = ", " },
    s("0x1F", "number"), { text = ";" },
  })
  cb:blank()

  cb:styled("-- String Literals", "comment")
  cb:spans({
    s("SELECT", "statement"), { text = " " },
    s("'Hello World'", "string"), { text = ", " },
    s("N'Unicode String'", "string"), { text = ", " },
    s("'It''s escaped'", "string"), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- Parameters
  -- ============================================
  cb:styled("-- Parameter References (@params and @@system)", "comment")
  cb:spans({
    s("DECLARE", "statement"), { text = " " },
    s("@UserId", "sql_parameter"), { text = " " },
    s("INT", "datatype"), { text = " = " },
    s("1", "number"), { text = ";" },
  })
  cb:spans({
    s("DECLARE", "statement"), { text = " " },
    s("@SearchTerm", "sql_parameter"), { text = " " },
    s("NVARCHAR", "datatype"), { text = "(" },
    s("100", "number"), { text = ") = " },
    s("'%test%'", "string"), { text = ";" },
  })
  cb:spans({
    s("SELECT", "statement"), { text = " " },
    s("@@VERSION", "globalvar"), { text = ", " },
    s("@@ROWCOUNT", "globalvar"), { text = ", " },
    s("@@IDENTITY", "globalvar"), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- Procedures
  -- ============================================
  cb:styled("-- Procedure & Function Calls", "comment")
  cb:spans({
    s("EXEC", "statement"), { text = " " },
    s("dbo", "sql_schema"), { text = "." },
    s("GetUserById", "sql_procedure"), { text = " " },
    s("@UserId", "sql_parameter"), { text = " = " },
    s("@UserId", "sql_parameter"), { text = ";" },
  })
  cb:spans({
    s("EXEC", "statement"), { text = " " },
    s("sp_help", "sysproc"), { text = " " },
    s("'dbo.Users'", "string"), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- CREATE TABLE with datatypes
  -- ============================================
  cb:styled("-- Datatype Keywords (INT, VARCHAR, DATETIME, etc.)", "comment")
  cb:spans({
    s("CREATE TABLE", "statement"), { text = " " },
    s("#TempUsers", "sql_table"), { text = " (" },
  })
  cb:spans({
    { text = "    " },
    s("id", "sql_column"), { text = " " },
    s("INT", "datatype"), { text = " " },
    s("PRIMARY", "constraint"), { text = " " },
    s("KEY", "constraint"), { text = "," },
  })
  cb:spans({
    { text = "    " },
    s("name", "sql_column"), { text = " " },
    s("VARCHAR", "datatype"), { text = "(" },
    s("100", "number"), { text = ") " },
    s("NOT", "sql_operator"), { text = " " },
    s("NULL", "constraint"), { text = "," },
  })
  cb:spans({
    { text = "    " },
    s("email", "sql_column"), { text = " " },
    s("NVARCHAR", "datatype"), { text = "(" },
    s("255", "number"), { text = ") " },
    s("UNIQUE", "constraint"), { text = "," },
  })
  cb:spans({
    { text = "    " },
    s("balance", "sql_column"), { text = " " },
    s("DECIMAL", "datatype"), { text = "(" },
    s("18", "number"), { text = "," },
    s("2", "number"), { text = ") " },
    s("DEFAULT", "constraint"), { text = " " },
    s("0.00", "number"), { text = "," },
  })
  cb:spans({
    { text = "    " },
    s("created_at", "sql_column"), { text = " " },
    s("DATETIME", "datatype"), { text = " " },
    s("DEFAULT", "constraint"), { text = " " },
    s("GETDATE", "sql_function"), { text = "()," },
  })
  cb:spans({
    { text = "    " },
    s("metadata", "sql_column"), { text = " " },
    s("XML", "datatype"), { text = " " },
    s("NULL", "constraint"),
  })
  cb:line(");")
  cb:blank()

  -- ============================================
  -- Constraints
  -- ============================================
  cb:styled("-- Constraint Keywords (PRIMARY, KEY, FOREIGN, etc.)", "comment")
  cb:spans({
    s("ALTER TABLE", "statement"), { text = " " },
    s("dbo", "sql_schema"), { text = "." },
    s("Orders", "sql_table"),
  })
  cb:spans({
    s("ADD", "statement"), { text = " " },
    s("CONSTRAINT", "constraint"), { text = " " },
    s("FK_Orders_Users", "sql_index"),
  })
  cb:spans({
    { text = "    " },
    s("FOREIGN KEY", "constraint"), { text = " (" },
    s("user_id", "sql_column"), { text = ") " },
    s("REFERENCES", "constraint"), { text = " " },
    s("dbo", "sql_schema"), { text = "." },
    s("Users", "sql_table"), { text = "(" },
    s("id", "sql_column"), { text = ")" },
  })
  cb:spans({
    { text = "    " },
    s("ON", "clause"), { text = " " },
    s("DELETE", "statement"), { text = " " },
    s("CASCADE", "modifier"),
  })
  cb:spans({
    { text = "    " },
    s("ON", "clause"), { text = " " },
    s("UPDATE", "statement"), { text = " " },
    s("NO", "sql_operator"), { text = " " },
    s("ACTION", "modifier"), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- Index
  -- ============================================
  cb:styled("-- Index Reference", "comment")
  cb:spans({
    s("CREATE", "statement"), { text = " " },
    s("NONCLUSTERED", "modifier"), { text = " " },
    s("INDEX", "statement"), { text = " " },
    s("IX_Users_Email", "sql_index"),
  })
  cb:spans({
    s("ON", "clause"), { text = " " },
    s("dbo", "sql_schema"), { text = "." },
    s("Users", "sql_table"), { text = " (" },
    s("email", "sql_column"), { text = ")" },
  })
  cb:spans({
    s("INCLUDE", "clause"), { text = " (" },
    s("username", "sql_column"), { text = ", " },
    s("created_at", "sql_column"), { text = ");" },
  })
  cb:blank()

  -- ============================================
  -- CTE
  -- ============================================
  cb:styled("-- CTE (Common Table Expression)", "comment")
  cb:spans({
    s("WITH", "clause"), { text = " " },
    s("ActiveUsers", "sql_alias"), { text = " " },
    s("AS", "clause"), { text = " (" },
  })
  cb:spans({
    { text = "    " },
    s("SELECT", "statement"), { text = " " },
    s("id", "sql_column"), { text = ", " },
    s("username", "sql_column"), { text = ", " },
    s("email", "sql_column"),
  })
  cb:spans({
    { text = "    " },
    s("FROM", "clause"), { text = " " },
    s("dbo", "sql_schema"), { text = "." },
    s("Users", "sql_table"),
  })
  cb:spans({
    { text = "    " },
    s("WHERE", "clause"), { text = " " },
    s("status", "sql_column"), { text = " = " },
    s("'active'", "string"),
  })
  cb:line("),")
  cb:spans({
    s("RecentOrders", "sql_alias"), { text = " " },
    s("AS", "clause"), { text = " (" },
  })
  cb:spans({
    { text = "    " },
    s("SELECT", "statement"), { text = " " },
    s("user_id", "sql_column"), { text = ", " },
    s("COUNT", "sql_function"), { text = "(*) " },
    s("AS", "clause"), { text = " " },
    s("cnt", "sql_alias"),
  })
  cb:spans({
    { text = "    " },
    s("FROM", "clause"), { text = " " },
    s("dbo", "sql_schema"), { text = "." },
    s("Orders", "sql_table"),
  })
  cb:spans({
    { text = "    " },
    s("WHERE", "clause"), { text = " " },
    s("created_at", "sql_column"), { text = " > " },
    s("DATEADD", "sql_function"), { text = "(" },
    s("DAY", "modifier"), { text = ", " },
    s("-30", "number"), { text = ", " },
    s("GETDATE", "sql_function"), { text = "())" },
  })
  cb:spans({
    { text = "    " },
    s("GROUP BY", "clause"), { text = " " },
    s("user_id", "sql_column"),
  })
  cb:line(")")
  cb:spans({
    s("SELECT", "statement"), { text = " * " },
    s("FROM", "clause"), { text = " " },
    s("ActiveUsers", "sql_table"), { text = " " },
    s("au", "sql_alias"),
  })
  cb:spans({
    s("JOIN", "clause"), { text = " " },
    s("RecentOrders", "sql_table"), { text = " " },
    s("ro", "sql_alias"), { text = " " },
    s("ON", "clause"), { text = " " },
    s("au", "sql_alias"), { text = "." },
    s("id", "sql_column"), { text = " = " },
    s("ro", "sql_alias"), { text = "." },
    s("user_id", "sql_column"), { text = ";" },
  })
  cb:blank()

  -- ============================================
  -- Unresolved (not in database)
  -- ============================================
  cb:styled("-- Unresolved (gray - not in database)", "comment")
  cb:spans({
    s("SELECT", "statement"), { text = " * " },
    s("FROM", "clause"), { text = " " },
    s("dbo", "sql_schema"), { text = "." },
    s("UnknownTable", "unresolved"), { text = " " },
    s("WHERE", "clause"), { text = " " },
    s("unknown_col", "unresolved"), { text = " = " },
    s("1", "number"), { text = ";" },
  })

  return cb:build_lines(), cb:build_raw_highlights()
end

return M
