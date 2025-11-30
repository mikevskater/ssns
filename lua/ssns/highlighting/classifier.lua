---@class ClassifiedToken
---@field token Token The original token
---@field semantic_type string? Semantic type: "table", "view", "column", "schema", "database", "keyword", "procedure", "function", "alias", "cte", "temp_table", "unresolved"
---@field highlight_group string? Highlight group to use (e.g., "SsnsTable")

---@class Classifier
---Token classification logic for semantic highlighting
local Classifier = {}

-- Token types from tokenizer.lua
local TOKEN_TYPES = {
  KEYWORD = "keyword",
  IDENTIFIER = "identifier",
  BRACKET_ID = "bracket_id",
  STRING = "string",
  NUMBER = "number",
  OPERATOR = "operator",
  PAREN_OPEN = "paren_open",
  PAREN_CLOSE = "paren_close",
  COMMA = "comma",
  DOT = "dot",
  SEMICOLON = "semicolon",
  STAR = "star",
  GO = "go",
  AT = "at",
  HASH = "hash",
}

-- Map semantic types to highlight groups
local HIGHLIGHT_MAP = {
  keyword = "SsnsKeyword",
  database = "SsnsDatabase",
  schema = "SsnsSchema",
  table = "SsnsTable",
  view = "SsnsView",
  procedure = "SsnsProcedure",
  ["function"] = "SsnsFunction",
  synonym = "SsnsSynonym",
  column = "SsnsColumn",
  alias = "SsnsAlias",
  cte = "SsnsTable",      -- CTEs use table color
  temp_table = "SsnsTable", -- Temp tables use table color
  operator = "SsnsOperator",
  string = "SsnsString",
  number = "SsnsNumber",
  unresolved = "SsnsUnresolved",
}

-- Keywords that indicate the next identifier is a database name
local DATABASE_CONTEXT_KEYWORDS = {
  USE = true,
}

---Classify all tokens in the buffer
---@param tokens Token[] Array of tokens from tokenizer
---@param chunks StatementChunk[] Parsed statement chunks
---@param connection table? Connection context for database lookups
---@param config SemanticHighlightingConfig Highlighting configuration
---@return ClassifiedToken[] classified Array of classified tokens
function Classifier.classify(tokens, chunks, connection, config)
  local classified = {}

  -- Build index for quick chunk lookup by position
  local chunk_index = Classifier._build_chunk_index(chunks)

  -- Track the last keyword for context (only for USE database detection)
  local last_keyword = nil

  -- Gather multi-part identifiers (sequences of IDENTIFIER/BRACKET_ID separated by DOT)
  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    local result = nil

    if token.type == TOKEN_TYPES.KEYWORD or token.type == TOKEN_TYPES.GO then
      -- SQL keyword
      local keyword_upper = token.text:upper()
      last_keyword = keyword_upper

      if config.highlight_keywords then
        result = {
          token = token,
          semantic_type = "keyword",
          highlight_group = HIGHLIGHT_MAP.keyword,
        }
      end
      i = i + 1

    elseif token.type == TOKEN_TYPES.STRING then
      -- String literal
      result = {
        token = token,
        semantic_type = "string",
        highlight_group = HIGHLIGHT_MAP.string,
      }
      i = i + 1

    elseif token.type == TOKEN_TYPES.NUMBER then
      -- Number literal
      result = {
        token = token,
        semantic_type = "number",
        highlight_group = HIGHLIGHT_MAP.number,
      }
      i = i + 1

    elseif token.type == TOKEN_TYPES.OPERATOR then
      -- Operator
      result = {
        token = token,
        semantic_type = "operator",
        highlight_group = HIGHLIGHT_MAP.operator,
      }
      i = i + 1

    elseif token.type == TOKEN_TYPES.IDENTIFIER or token.type == TOKEN_TYPES.BRACKET_ID then
      -- Identifier - check if part of multi-part identifier
      local parts, consumed = Classifier._gather_multipart(tokens, i)
      local chunk = Classifier._find_chunk_at_position(chunk_index, token.line, token.col)

      -- Build keyword context (only for USE database detection)
      local keyword_context = {
        is_database_context = last_keyword and DATABASE_CONTEXT_KEYWORDS[last_keyword],
      }

      -- Classify each part by resolving against cache
      local part_results = Classifier._classify_multipart(parts, chunk, connection, config, keyword_context)
      for _, part_result in ipairs(part_results) do
        table.insert(classified, part_result)
      end

      -- Reset last_keyword after consuming identifier
      last_keyword = nil

      i = i + consumed
      -- Skip adding result since we added directly
      result = nil

    elseif token.type == TOKEN_TYPES.HASH then
      -- Hash token (start of temp table name)
      -- Look ahead for identifier
      if i + 1 <= #tokens then
        local next_token = tokens[i + 1]
        if next_token.type == TOKEN_TYPES.IDENTIFIER or next_token.type == TOKEN_TYPES.BRACKET_ID then
          -- Highlight the hash as temp table
          result = {
            token = token,
            semantic_type = "temp_table",
            highlight_group = HIGHLIGHT_MAP.temp_table,
          }
        end
      end
      i = i + 1

    elseif token.type == TOKEN_TYPES.AT then
      -- Variable/parameter - skip for now (could add SsnsVariable highlight)
      i = i + 1

    elseif token.type == TOKEN_TYPES.SEMICOLON then
      -- Semicolon resets keyword context (new statement)
      last_keyword = nil
      i = i + 1

    else
      -- Other tokens (DOT, COMMA, PAREN, STAR) - skip
      i = i + 1
    end

    if result then
      table.insert(classified, result)
    end
  end

  return classified
end

---Gather a multi-part identifier (e.g., database.schema.table.column)
---@param tokens Token[] All tokens
---@param start_idx number Starting index
---@return Token[] parts Array of identifier tokens
---@return number consumed Number of tokens consumed
function Classifier._gather_multipart(tokens, start_idx)
  local parts = {}
  local i = start_idx

  while i <= #tokens do
    local token = tokens[i]

    if token.type == TOKEN_TYPES.IDENTIFIER or token.type == TOKEN_TYPES.BRACKET_ID then
      table.insert(parts, token)
      i = i + 1

      -- Check for DOT
      if i <= #tokens and tokens[i].type == TOKEN_TYPES.DOT then
        i = i + 1 -- consume dot
        -- Continue to next identifier
      else
        break -- No more parts
      end
    elseif token.type == TOKEN_TYPES.HASH then
      -- Hash prefix for temp tables
      i = i + 1
      -- Continue to get the identifier
    else
      break
    end
  end

  return parts, i - start_idx
end

---Classify a multi-part identifier by resolving each part against the cache
---@param parts Token[] Array of identifier tokens
---@param chunk StatementChunk? The statement chunk containing this identifier
---@param connection table? Connection context
---@param config SemanticHighlightingConfig Configuration
---@param keyword_context table? Context from previous keywords {last_keyword, in_table_context, is_database_context}
---@return ClassifiedToken[] results Classified tokens for each part
function Classifier._classify_multipart(parts, chunk, connection, config, keyword_context)
  local results = {}
  keyword_context = keyword_context or {}

  if #parts == 0 then
    return results
  end

  -- Extract names from tokens (strip brackets if present)
  local names = {}
  for _, part in ipairs(parts) do
    local name = Classifier._strip_brackets(part.text)
    table.insert(names, name)
  end

  -- Build context for resolution (aliases, CTEs, temp tables from chunk)
  local sql_context = Classifier._build_context(chunk)

  -- Resolve each part against the cache, building context as we go
  local resolved_types = Classifier._resolve_multipart_from_cache(names, sql_context, connection, keyword_context)

  -- Build results from resolved types
  for i, part in ipairs(parts) do
    local semantic_type = resolved_types[i] or "unresolved"
    local highlight_group = nil

    -- Map semantic type to highlight group based on config
    if semantic_type == "database" and config.highlight_databases then
      highlight_group = HIGHLIGHT_MAP.database
    elseif semantic_type == "schema" and config.highlight_schemas then
      highlight_group = HIGHLIGHT_MAP.schema
    elseif semantic_type == "table" and config.highlight_tables then
      highlight_group = HIGHLIGHT_MAP.table
    elseif semantic_type == "view" and config.highlight_tables then
      highlight_group = HIGHLIGHT_MAP.view
    elseif semantic_type == "column" and config.highlight_columns then
      highlight_group = HIGHLIGHT_MAP.column
    elseif semantic_type == "alias" and config.highlight_tables then
      highlight_group = HIGHLIGHT_MAP.alias
    elseif semantic_type == "cte" and config.highlight_tables then
      highlight_group = HIGHLIGHT_MAP.cte
    elseif semantic_type == "temp_table" and config.highlight_tables then
      highlight_group = HIGHLIGHT_MAP.temp_table
    elseif semantic_type == "procedure" then
      highlight_group = HIGHLIGHT_MAP.procedure
    elseif semantic_type == "function" then
      highlight_group = HIGHLIGHT_MAP["function"]
    elseif semantic_type == "synonym" then
      highlight_group = HIGHLIGHT_MAP.synonym
    elseif semantic_type == "unresolved" and config.highlight_unresolved then
      highlight_group = HIGHLIGHT_MAP.unresolved
    end

    table.insert(results, {
      token = part,
      semantic_type = semantic_type,
      highlight_group = highlight_group,
    })
  end

  return results
end

---Scan the UI tree cache for an object by name
---Returns the object type if found: "database", "schema", "table", "view", "procedure", "function"
---@param name string Object name to search for (case-insensitive)
---@return string? object_type The type if found, nil otherwise
---@return table? object The found object (for database/table/view/etc) or parent database (for schema)
---@return table? parent The parent object
function Classifier._find_in_tree_cache(name)
  local Cache = require('ssns.cache')
  local name_lower = name:lower()

  -- Scan all servers
  for _, server in ipairs(Cache.servers or {}) do
    -- Find databases_group
    if server.children then
      for _, server_child in ipairs(server.children) do
        if server_child.object_type == "databases_group" and server_child.children then
          -- Check each database
          for _, db in ipairs(server_child.children) do
            if db.object_type == "database" then
              local db_name = db.db_name or db.name
              if db_name and db_name:lower() == name_lower then
                return "database", db, server
              end

              -- Check inside database for tables/views/procedures/functions
              if db.children then
                for _, db_child in ipairs(db.children) do
                  -- Check tables_group
                  if db_child.object_type == "tables_group" and db_child.children then
                    for _, tbl in ipairs(db_child.children) do
                      local tbl_name = tbl.table_name or tbl.name
                      if tbl_name and tbl_name:lower() == name_lower then
                        return "table", tbl, db
                      end
                      -- Also check if name matches a schema_name (schema is a property, not an object)
                      local schema_name = tbl.schema_name
                      if schema_name and schema_name:lower() == name_lower then
                        return "schema", db, server  -- Return db as the object for schema context
                      end
                    end
                  -- Check views_group
                  elseif db_child.object_type == "views_group" and db_child.children then
                    for _, view in ipairs(db_child.children) do
                      local view_name = view.view_name or view.name
                      if view_name and view_name:lower() == name_lower then
                        return "view", view, db
                      end
                      local schema_name = view.schema_name
                      if schema_name and schema_name:lower() == name_lower then
                        return "schema", db, server
                      end
                    end
                  -- Check procedures_group
                  elseif db_child.object_type == "procedures_group" and db_child.children then
                    for _, proc in ipairs(db_child.children) do
                      local proc_name = proc.procedure_name or proc.name
                      if proc_name and proc_name:lower() == name_lower then
                        return "procedure", proc, db
                      end
                      local schema_name = proc.schema_name
                      if schema_name and schema_name:lower() == name_lower then
                        return "schema", db, server
                      end
                    end
                  -- Check functions_group
                  elseif db_child.object_type == "functions_group" and db_child.children then
                    for _, func in ipairs(db_child.children) do
                      local func_name = func.function_name or func.name
                      if func_name and func_name:lower() == name_lower then
                        return "function", func, db
                      end
                      local schema_name = func.schema_name
                      if schema_name and schema_name:lower() == name_lower then
                        return "schema", db, server
                      end
                    end
                  -- Check synonyms_group
                  elseif db_child.object_type == "synonyms_group" and db_child.children then
                    for _, syn in ipairs(db_child.children) do
                      local syn_name = syn.synonym_name or syn.name
                      if syn_name and syn_name:lower() == name_lower then
                        return "synonym", syn, db
                      end
                      local schema_name = syn.schema_name
                      if schema_name and schema_name:lower() == name_lower then
                        return "schema", db, server
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  return nil, nil, nil
end

---Scan for schema in a specific database (checks schema_name property on tables/views/etc)
---@param db table Database object
---@param name string Schema name
---@return boolean found True if schema exists in this database
function Classifier._find_schema_in_db(db, name)
  local name_lower = name:lower()
  if db.children then
    for _, db_child in ipairs(db.children) do
      if db_child.object_type == "tables_group" and db_child.children then
        for _, tbl in ipairs(db_child.children) do
          if tbl.schema_name and tbl.schema_name:lower() == name_lower then
            return true
          end
        end
      elseif db_child.object_type == "views_group" and db_child.children then
        for _, view in ipairs(db_child.children) do
          if view.schema_name and view.schema_name:lower() == name_lower then
            return true
          end
        end
      elseif db_child.object_type == "procedures_group" and db_child.children then
        for _, proc in ipairs(db_child.children) do
          if proc.schema_name and proc.schema_name:lower() == name_lower then
            return true
          end
        end
      elseif db_child.object_type == "functions_group" and db_child.children then
        for _, func in ipairs(db_child.children) do
          if func.schema_name and func.schema_name:lower() == name_lower then
            return true
          end
        end
      elseif db_child.object_type == "synonyms_group" and db_child.children then
        for _, syn in ipairs(db_child.children) do
          if syn.schema_name and syn.schema_name:lower() == name_lower then
            return true
          end
        end
      end
    end
  end
  return false
end

---Scan for table/view in a specific database with optional schema filter
---@param db table Database object
---@param name string Table/view name
---@param schema_name string? Optional schema name to filter by
---@return string? type "table" or "view"
---@return table? object The table/view if found
function Classifier._find_table_in_db(db, name, schema_name)
  local name_lower = name:lower()
  local schema_lower = schema_name and schema_name:lower()

  if db.children then
    for _, db_child in ipairs(db.children) do
      if db_child.object_type == "tables_group" and db_child.children then
        for _, tbl in ipairs(db_child.children) do
          local tbl_name = tbl.table_name or tbl.name
          if tbl_name and tbl_name:lower() == name_lower then
            -- If schema filter provided, check it matches
            if not schema_lower or (tbl.schema_name and tbl.schema_name:lower() == schema_lower) then
              return "table", tbl
            end
          end
        end
      elseif db_child.object_type == "views_group" and db_child.children then
        for _, view in ipairs(db_child.children) do
          local view_name = view.view_name or view.name
          if view_name and view_name:lower() == name_lower then
            if not schema_lower or (view.schema_name and view.schema_name:lower() == schema_lower) then
              return "view", view
            end
          end
        end
      end
    end
  end
  return nil, nil
end

---Scan for procedure/function in a specific database with optional schema filter
---@param db table Database object
---@param name string Procedure/function name
---@param schema_name string? Optional schema name to filter by
---@return string? type "procedure" or "function"
---@return table? object The procedure/function if found
function Classifier._find_routine_in_db(db, name, schema_name)
  local name_lower = name:lower()
  local schema_lower = schema_name and schema_name:lower()

  if db.children then
    for _, db_child in ipairs(db.children) do
      if db_child.object_type == "procedures_group" and db_child.children then
        for _, proc in ipairs(db_child.children) do
          local proc_name = proc.procedure_name or proc.name
          if proc_name and proc_name:lower() == name_lower then
            if not schema_lower or (proc.schema_name and proc.schema_name:lower() == schema_lower) then
              return "procedure", proc
            end
          end
        end
      elseif db_child.object_type == "functions_group" and db_child.children then
        for _, func in ipairs(db_child.children) do
          local func_name = func.function_name or func.name
          if func_name and func_name:lower() == name_lower then
            if not schema_lower or (func.schema_name and func.schema_name:lower() == schema_lower) then
              return "function", func
            end
          end
        end
      end
    end
  end
  return nil, nil
end

---Scan for synonym in a specific database with optional schema filter
---@param db table Database object
---@param name string Synonym name
---@param schema_name string? Optional schema name to filter by
---@return table? object The synonym if found
function Classifier._find_synonym_in_db(db, name, schema_name)
  local name_lower = name:lower()
  local schema_lower = schema_name and schema_name:lower()

  if db.children then
    for _, db_child in ipairs(db.children) do
      if db_child.object_type == "synonyms_group" and db_child.children then
        for _, syn in ipairs(db_child.children) do
          local syn_name = syn.synonym_name or syn.name
          if syn_name and syn_name:lower() == name_lower then
            if not schema_lower or (syn.schema_name and syn.schema_name:lower() == schema_lower) then
              return syn
            end
          end
        end
      end
    end
  end
  return nil
end

---Check if a column exists in a table/view object
---@param obj table Table or view object
---@param column_name string Column name to find
---@return boolean found True if column exists
function Classifier._find_column_in_object(obj, column_name)
  if not obj then
    return false
  end

  local name_lower = column_name:lower()

  -- Check columns array (may need to be loaded)
  if obj.columns then
    for _, col in ipairs(obj.columns) do
      local col_name = col.column_name or col.name
      if col_name and col_name:lower() == name_lower then
        return true
      end
    end
  end

  -- Check children for column_group containing columns
  if obj.children then
    for _, child in ipairs(obj.children) do
      if child.object_type == "column_group" and child.children then
        for _, col in ipairs(child.children) do
          local col_name = col.column_name or col.name
          if col_name and col_name:lower() == name_lower then
            return true
          end
        end
      elseif child.object_type == "column" then
        local col_name = child.column_name or child.name
        if col_name and col_name:lower() == name_lower then
          return true
        end
      end
    end
  end

  return false
end

---Find all columns across all loaded tables/views in the cache
---@param column_name string Column name to search for
---@return boolean found True if column exists anywhere
function Classifier._find_column_in_cache(column_name)
  local Cache = require('ssns.cache')
  local name_lower = column_name:lower()

  for _, server in ipairs(Cache.servers or {}) do
    if server.children then
      for _, server_child in ipairs(server.children) do
        if server_child.object_type == "databases_group" and server_child.children then
          for _, db in ipairs(server_child.children) do
            if db.object_type == "database" and db.children then
              for _, db_child in ipairs(db.children) do
                -- Check tables
                if db_child.object_type == "tables_group" and db_child.children then
                  for _, tbl in ipairs(db_child.children) do
                    if Classifier._find_column_in_object(tbl, column_name) then
                      return true
                    end
                  end
                -- Check views
                elseif db_child.object_type == "views_group" and db_child.children then
                  for _, view in ipairs(db_child.children) do
                    if Classifier._find_column_in_object(view, column_name) then
                      return true
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  return false
end

---Resolve multi-part identifier by scanning the UI tree cache
---@param names string[] Array of identifier names (without brackets)
---@param sql_context table Context with aliases, CTEs, temp tables
---@param connection table? Connection context
---@param keyword_context table? Keyword context
---@return string[] types Array of semantic types for each part
function Classifier._resolve_multipart_from_cache(names, sql_context, connection, keyword_context)
  local types = {}
  keyword_context = keyword_context or {}

  if #names == 0 then
    return types
  end

  local name1 = names[1]
  local name1_lower = name1:lower()

  -- Special case: after USE keyword, first part is always database
  if keyword_context.is_database_context and #names == 1 then
    return { "database" }
  end

  -- Check local SQL context first (aliases, CTEs, temp tables)
  -- These take precedence over database objects

  -- Check if first part is an alias
  if sql_context.aliases[name1_lower] then
    types[1] = "alias"
    for i = 2, #names do
      types[i] = "column"
    end
    return types
  end

  -- Check if first part is a CTE
  if sql_context.ctes[name1_lower] then
    types[1] = "cte"
    for i = 2, #names do
      types[i] = "column"
    end
    return types
  end

  -- Check if first part is a temp table
  if name1:match("^#") or sql_context.temp_tables[name1_lower] then
    types[1] = "temp_table"
    for i = 2, #names do
      types[i] = "column"
    end
    return types
  end

  -- Scan the UI tree cache for the first part
  local obj_type, obj, parent = Classifier._find_in_tree_cache(name1)

  if obj_type == "database" then
    types[1] = "database"

    if #names >= 2 then
      -- Second part: look for schema in this database
      local schema_found = Classifier._find_schema_in_db(obj, names[2])
      if schema_found then
        types[2] = "schema"

        if #names >= 3 then
          -- Third part: look for table/view in this database with schema filter
          local tbl_type, tbl_obj = Classifier._find_table_in_db(obj, names[3], names[2])
          if tbl_type then
            types[3] = tbl_type

            -- Verify columns exist
            if #names >= 4 and tbl_obj then
              for i = 4, #names do
                if Classifier._find_column_in_object(tbl_obj, names[i]) then
                  types[i] = "column"
                else
                  types[i] = "unresolved"
                end
              end
            elseif #names >= 4 then
              for i = 4, #names do
                types[i] = "column"  -- Can't verify, assume column
              end
            end
          else
            -- Check for procedure/function/synonym
            local routine_type, _ = Classifier._find_routine_in_db(obj, names[3], names[2])
            if routine_type then
              types[3] = routine_type
            else
              local syn = Classifier._find_synonym_in_db(obj, names[3], names[2])
              types[3] = syn and "synonym" or "unresolved"
            end
            for i = 4, #names do
              types[i] = "unresolved"
            end
          end
        end
      else
        -- Schema not found, mark as unresolved
        types[2] = "unresolved"
        for i = 3, #names do
          types[i] = "unresolved"
        end
      end
    end
    return types

  elseif obj_type == "schema" then
    -- obj is the database containing this schema
    types[1] = "schema"

    if #names >= 2 then
      -- Second part: look for table/view in the database with this schema
      local tbl_type, tbl_obj = Classifier._find_table_in_db(obj, names[2], name1)
      if tbl_type then
        types[2] = tbl_type

        -- Verify columns exist in this table/view
        if #names >= 3 and tbl_obj then
          for i = 3, #names do
            if Classifier._find_column_in_object(tbl_obj, names[i]) then
              types[i] = "column"
            else
              types[i] = "unresolved"
            end
          end
        elseif #names >= 3 then
          for i = 3, #names do
            types[i] = "column"  -- Can't verify, assume column
          end
        end
      else
        -- Check procedures/functions
        local routine_type, _ = Classifier._find_routine_in_db(obj, names[2], name1)
        if routine_type then
          types[2] = routine_type
          for i = 3, #names do
            types[i] = "unresolved"  -- Procedures/functions don't have columns
          end
        else
          -- Check synonyms
          local syn = Classifier._find_synonym_in_db(obj, names[2], name1)
          if syn then
            types[2] = "synonym"
            for i = 3, #names do
              types[i] = "column"  -- Synonyms might have columns
            end
          else
            types[2] = "unresolved"
            for i = 3, #names do
              types[i] = "unresolved"
            end
          end
        end
      end
    end
    return types

  elseif obj_type == "synonym" then
    types[1] = "synonym"
    -- For synonyms, we can't easily check columns without resolving the base object
    -- Mark remaining parts as column (they might be valid)
    for i = 2, #names do
      types[i] = "column"
    end
    return types

  elseif obj_type == "table" or obj_type == "view" then
    types[1] = obj_type
    -- Verify columns exist in this table/view
    for i = 2, #names do
      if Classifier._find_column_in_object(obj, names[i]) then
        types[i] = "column"
      else
        -- Column not found - mark as unresolved
        types[i] = "unresolved"
      end
    end
    return types

  elseif obj_type == "procedure" then
    types[1] = "procedure"
    for i = 2, #names do
      types[i] = "unresolved"
    end
    return types

  elseif obj_type == "function" then
    types[1] = "function"
    for i = 2, #names do
      types[i] = "unresolved"
    end
    return types
  end

  -- Check if first part is a table from the SQL chunk's tables list
  for _, tbl in ipairs(sql_context.tables or {}) do
    local tbl_name = tbl.name or tbl.table
    if tbl_name then
      local simple_name = tbl_name:match("%.([^%.]+)$") or tbl_name
      if simple_name:lower() == name1_lower then
        types[1] = "table"
        for i = 2, #names do
          types[i] = "column"
        end
        return types
      end
    end
  end

  -- Check if first part is a column name in any loaded table
  if #names == 1 and Classifier._find_column_in_cache(name1) then
    types[1] = "column"
    return types
  end

  -- Nothing matched in tree or context - mark all as unresolved
  for i = 1, #names do
    types[i] = "unresolved"
  end

  return types
end

---Build context from statement chunk
---@param chunk StatementChunk? Statement chunk
---@return table context Context with aliases, ctes, temp_tables, tables
function Classifier._build_context(chunk)
  local context = {
    aliases = {},
    ctes = {},
    temp_tables = {},
    tables = {},
  }

  if not chunk then
    return context
  end

  -- Extract aliases
  if chunk.aliases then
    for alias_name, table_ref in pairs(chunk.aliases) do
      context.aliases[alias_name:lower()] = table_ref
    end
  end

  -- Extract CTEs
  if chunk.ctes then
    for _, cte in ipairs(chunk.ctes) do
      if cte.name then
        context.ctes[cte.name:lower()] = cte
      end
    end
  end

  -- Extract tables
  if chunk.tables then
    for _, tbl in ipairs(chunk.tables) do
      table.insert(context.tables, tbl)
      -- Also add alias if present
      if tbl.alias then
        context.aliases[tbl.alias:lower()] = tbl.name or tbl.table
      end
    end
  end

  return context
end

---Build index for quick chunk lookup by line
---@param chunks StatementChunk[] Statement chunks
---@return table index Lookup table
function Classifier._build_chunk_index(chunks)
  local index = {}
  for _, chunk in ipairs(chunks or {}) do
    -- Index chunks by their line range
    if chunk.start_line and chunk.end_line then
      for line = chunk.start_line, chunk.end_line do
        index[line] = index[line] or chunk
      end
    end
  end
  return index
end

---Find chunk at position
---@param index table Chunk index
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return StatementChunk? chunk
function Classifier._find_chunk_at_position(index, line, col)
  return index[line]
end

---Strip brackets from identifier
---@param text string Token text
---@return string name Identifier without brackets
function Classifier._strip_brackets(text)
  -- Remove [brackets] or "quotes" or `backticks`
  local name = text
  name = name:gsub("^%[(.-)%]$", "%1")
  name = name:gsub('^"(.-)"$', "%1")
  name = name:gsub("^`(.-)`$", "%1")
  return name
end

return Classifier
