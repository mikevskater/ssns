---Helper functions for SQL statement parsing
---Provides utility functions for identifier manipulation and table type detection
---
---@module ssns.completion.parser.utils.helpers

local Helpers = {}

---Strip brackets from identifier [name] -> name
---@param text string
---@return string
function Helpers.strip_brackets(text)
  if text:sub(1, 1) == '[' and text:sub(-1) == ']' then
    return text:sub(2, -2)
  end
  return text
end

---Get identifier text from token with brackets stripped
---Returns nil if token is not an identifier type
---@param token table? The token to extract identifier from
---@return string? identifier The identifier text (brackets stripped) or nil
function Helpers.get_identifier_text(token)
  if token and (token.type == "identifier" or token.type == "bracket_id") then
    return Helpers.strip_brackets(token.text)
  end
  return nil
end

---Check if identifier is a temp table (#temp or ##temp)
---@param name string
---@return boolean
function Helpers.is_temp_table(name)
  return name:sub(1, 1) == '#'
end

---Check if identifier is a global temp table (##temp)
---@param name string
---@return boolean
function Helpers.is_global_temp_table(name)
  return name:sub(1, 2) == '##'
end

---Check if identifier is a table variable (@TableVar)
---@param name string
---@return boolean
function Helpers.is_table_variable(name)
  return name:sub(1, 1) == '@'
end

---Resolve parent_table for columns using aliases
---@param columns ColumnInfo[]? The columns to resolve
---@param aliases table<string, TableReference> The alias mapping
---@param tables TableReference[] The tables in the FROM clause
function Helpers.resolve_column_parents(columns, aliases, tables)
  if not columns then return end

  for _, col in ipairs(columns) do
    if col.source_table then
      -- Try to resolve from aliases (case-insensitive)
      local source_lower = col.source_table:lower()
      local table_ref = aliases[source_lower]
      if table_ref then
        col.parent_table = table_ref.name
        col.parent_schema = table_ref.schema
      else
        -- Check if source_table is an actual table name (not alias)
        for _, tbl in ipairs(tables) do
          if tbl.name:lower() == source_lower then
            col.parent_table = tbl.name
            col.parent_schema = tbl.schema
            break
          end
        end
      end
    elseif #tables == 1 then
      -- Unqualified column/star with single table - can infer parent
      col.parent_table = tables[1].name
      col.parent_schema = tables[1].schema
    end
  end
end

return Helpers
