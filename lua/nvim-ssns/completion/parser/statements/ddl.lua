--- DDL statement handlers
--- Parses DDL statements: CREATE TABLE, ALTER TABLE, DROP TABLE, DECLARE, TRUNCATE
---
--- Primarily tracks temp tables (#temp, ##temp) and table variables (@var) for
--- autocomplete context. Also tracks clause positions for context detection.
---
---@module ssns.completion.parser.statements.ddl

require('nvim-ssns.completion.parser.types')
local BaseStatement = require('nvim-ssns.completion.parser.statements.base')
local ColumnDefsParser = require('nvim-ssns.completion.parser.clauses.column_defs')
local QualifiedName = require('nvim-ssns.completion.parser.utils.qualified_name')
local Helpers = require('nvim-ssns.completion.parser.utils.helpers')
local Keywords = require('nvim-ssns.completion.parser.utils.keywords')

local DdlStatement = {}

---Parse a CREATE statement
---
---@param state ParserState Token navigation state (positioned at CREATE keyword)
---@param scope ScopeContext Scope context
---@param temp_tables table<string, TempTableInfo> Temp tables collection to update
---@return StatementChunk chunk The parsed statement chunk
function DdlStatement.parse_create(state, scope, temp_tables)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("CREATE", start_token, state.go_batch_index, state)

  scope.statement_type = "CREATE"
  state:advance()  -- consume CREATE

  -- Check for CREATE TABLE
  if state:is_keyword("TABLE") then
    state:advance()  -- consume TABLE

    -- Parse table name (could be temp table #name or ##name, or regular table)
    local name_start = state:current()
    local qualified = QualifiedName.parse(state)
    local name_end = state.pos > 1 and state.tokens[state.pos - 1] or name_start

    -- Track create_table clause position (covers table name)
    if qualified then
      BaseStatement.add_clause_position(chunk, "create_table", start_token, name_end)
    end

    if qualified and Helpers.is_temp_table(qualified.name) then
      chunk.temp_table_name = qualified.name
      chunk.is_global_temp = Helpers.is_global_temp_table(qualified.name)

      -- Parse column definitions if present
      if state:is_type("paren_open") then
        local col_start = state:current()
        local columns = ColumnDefsParser.parse(state)
        local col_end = state.pos > 1 and state.tokens[state.pos - 1] or col_start

        -- Track column_definitions clause position
        BaseStatement.add_clause_position(chunk, "column_definitions", col_start, col_end)

        -- Store temp table info with parsed columns
        if #columns > 0 then
          temp_tables[qualified.name] = {
            name = qualified.name,
            columns = columns,
            created_in_batch = state.go_batch_index,
            is_global = Helpers.is_global_temp_table(qualified.name),
          }
        end
      end
    elseif qualified then
      -- Non-temp table: still track column definitions if present
      if state:is_type("paren_open") then
        local col_start = state:current()
        local columns = ColumnDefsParser.parse(state)
        local col_end = state.pos > 1 and state.tokens[state.pos - 1] or col_start
        BaseStatement.add_clause_position(chunk, "column_definitions", col_start, col_end)
      end
    end

  -- Handle CREATE VIEW/PROCEDURE/FUNCTION
  elseif state:current() and state:current().type == "keyword" then
    local obj_type = state:current().text:upper()
    if obj_type == "VIEW" or obj_type == "PROC" or obj_type == "PROCEDURE" or obj_type == "FUNCTION" then
      state:advance()  -- consume object type keyword
      local qualified = QualifiedName.parse(state)
      if qualified then
        chunk.ddl_object_name = qualified.name
        chunk.ddl_object_schema = qualified.schema
        chunk.ddl_object_type = obj_type
      end
    end
  end

  -- Consume rest of CREATE statement
  state:consume_until_statement_end()

  -- Set token_end_idx and extract parameters
  if chunk.token_start_idx then
    chunk.token_end_idx = state.pos > 1 and state.pos - 1 or state.pos
    state:extract_all_parameters_from_tokens(chunk.token_start_idx, chunk.token_end_idx, chunk.parameters)
  end

  return chunk
end

---Parse an ALTER statement
---
---@param state ParserState Token navigation state (positioned at ALTER keyword)
---@param scope ScopeContext Scope context
---@param temp_tables table<string, TempTableInfo> Temp tables collection to update
---@return StatementChunk chunk The parsed statement chunk
function DdlStatement.parse_alter(state, scope, temp_tables)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("ALTER", start_token, state.go_batch_index, state)

  scope.statement_type = "ALTER"
  state:advance()  -- consume ALTER

  if state:is_keyword("TABLE") then
    state:advance()  -- consume TABLE

    -- Parse the table name
    local name_start = state:current()
    local qualified = QualifiedName.parse(state)
    local name_end = state.pos > 1 and state.tokens[state.pos - 1] or name_start

    -- Track alter_table clause position
    if qualified then
      BaseStatement.add_clause_position(chunk, "alter_table", start_token, name_end)
    end

    if qualified and Helpers.is_temp_table(qualified.name) then
      -- Check if temp table exists
      if temp_tables[qualified.name] then
        -- Check for ADD keyword
        if state:is_keyword("ADD") then
          local add_token = state:current()
          state:advance()  -- consume ADD

          -- Track alter_add clause position
          BaseStatement.add_clause_position(chunk, "alter_add", add_token, add_token)

          -- Parse new column definition(s) and update position
          DdlStatement._parse_alter_add_columns(state, temp_tables[qualified.name])

          -- Update alter_add end position
          local last = state.pos > 1 and state.tokens[state.pos - 1] or add_token
          chunk.clause_positions["alter_add"].end_line = last.line
          chunk.clause_positions["alter_add"].end_col = last.col + #last.text - 1
        end
      end
    else
      -- Non-temp table: still track ADD position
      if state:is_keyword("ADD") then
        local add_token = state:current()
        state:advance()  -- consume ADD
        BaseStatement.add_clause_position(chunk, "alter_add", add_token, add_token)
      end
    end
  end

  state:consume_until_statement_end()

  -- Set token_end_idx and extract parameters
  if chunk.token_start_idx then
    chunk.token_end_idx = state.pos > 1 and state.pos - 1 or state.pos
    state:extract_all_parameters_from_tokens(chunk.token_start_idx, chunk.token_end_idx, chunk.parameters)
  end

  return chunk
end

---Parse a DROP statement
---
---@param state ParserState Token navigation state (positioned at DROP keyword)
---@param scope ScopeContext Scope context
---@param temp_tables table<string, TempTableInfo> Temp tables collection to update
---@return StatementChunk chunk The parsed statement chunk
function DdlStatement.parse_drop(state, scope, temp_tables)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("DROP", start_token, state.go_batch_index, state)

  scope.statement_type = "DROP"
  state:advance()  -- consume DROP

  if state:is_keyword("TABLE") then
    state:advance()  -- consume TABLE

    -- Check for IF EXISTS
    if state:is_keyword("IF") then
      state:advance()
      if state:is_keyword("EXISTS") then
        state:advance()
      end
    end

    -- Parse the table name
    local drop_line = state:current() and state:current().line or start_token.line
    local name_start = state:current()
    local qualified = QualifiedName.parse(state)
    local name_end = state.pos > 1 and state.tokens[state.pos - 1] or name_start

    -- Track drop_table clause position
    if qualified then
      BaseStatement.add_clause_position(chunk, "drop_table", start_token, name_end)
    end

    if qualified and Helpers.is_temp_table(qualified.name) then
      -- Mark this temp table as dropped
      if temp_tables[qualified.name] then
        temp_tables[qualified.name].dropped_at_line = drop_line
      end
    end
  end

  state:consume_until_statement_end()

  -- Set token_end_idx and extract parameters
  if chunk.token_start_idx then
    chunk.token_end_idx = state.pos > 1 and state.pos - 1 or state.pos
    state:extract_all_parameters_from_tokens(chunk.token_start_idx, chunk.token_end_idx, chunk.parameters)
  end

  return chunk
end

---Parse a DECLARE statement
---
---@param state ParserState Token navigation state (positioned at DECLARE keyword)
---@param scope ScopeContext Scope context
---@param temp_tables table<string, TempTableInfo> Temp tables collection to update
---@return StatementChunk chunk The parsed statement chunk
function DdlStatement.parse_declare(state, scope, temp_tables)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("DECLARE", start_token, state.go_batch_index, state)

  scope.statement_type = "DECLARE"
  state:advance()  -- consume DECLARE

  -- Track declare clause position
  BaseStatement.add_clause_position(chunk, "declare", start_token, start_token)

  -- Check for table variable declaration: DECLARE @var TABLE (col1 type, ...)
  -- Handle both unified "variable" token (@var as single token) and legacy "at" + "identifier"
  local token = state:current()
  local var_name = nil

  -- New unified variable token type
  if token and token.type == "variable" then
    var_name = token.text  -- Already includes @
    state:advance()
  -- Legacy handling: @ (type=at) followed by identifier
  elseif token and token.type == "at" then
    state:advance()  -- consume @
    local name_token = state:current()
    if name_token and name_token.type == "identifier" then
      var_name = "@" .. name_token.text
      state:advance()  -- consume variable name
    end
  end

  -- Check for TABLE keyword (only if we found a valid variable name)
  if var_name and state:is_keyword("TABLE") then
    state:advance()  -- consume TABLE

    -- Parse column definitions
    if state:is_type("paren_open") then
      local col_start = state:current()
      local columns = ColumnDefsParser.parse(state)
      local col_end = state.pos > 1 and state.tokens[state.pos - 1] or col_start

      -- Track column_definitions clause position
      BaseStatement.add_clause_position(chunk, "column_definitions", col_start, col_end)

      -- Store table variable info
      if #columns > 0 then
        temp_tables[var_name] = {
          name = var_name,
          columns = columns,
          created_in_batch = state.go_batch_index,
          is_table_variable = true,
        }
      end
    end
  end

  state:consume_until_statement_end()

  -- Update declare clause end position
  local last = state.pos > 1 and state.tokens[state.pos - 1] or start_token
  chunk.clause_positions["declare"].end_line = last.line
  chunk.clause_positions["declare"].end_col = last.col + #last.text - 1

  -- Set token_end_idx and extract parameters
  if chunk.token_start_idx then
    chunk.token_end_idx = state.pos > 1 and state.pos - 1 or state.pos
    state:extract_all_parameters_from_tokens(chunk.token_start_idx, chunk.token_end_idx, chunk.parameters)
  end

  return chunk
end

---Parse a TRUNCATE statement
---
---@param state ParserState Token navigation state (positioned at TRUNCATE keyword)
---@param scope ScopeContext Scope context
---@param temp_tables table<string, TempTableInfo> Temp tables collection (unused)
---@return StatementChunk chunk The parsed statement chunk
function DdlStatement.parse_truncate(state, scope, temp_tables)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("TRUNCATE", start_token, state.go_batch_index, state)

  scope.statement_type = "TRUNCATE"
  state:advance()  -- consume TRUNCATE

  -- Skip TABLE keyword
  if state:is_keyword("TABLE") then
    state:advance()
  end

  -- Build known_ctes for table reference parsing
  local known_ctes = scope:get_known_ctes_table()

  -- Extract table name
  local table_ref = state:parse_table_reference(known_ctes)
  if table_ref then
    table.insert(chunk.tables, table_ref)
  end

  -- Set token_end_idx and extract parameters
  if chunk.token_start_idx then
    chunk.token_end_idx = state.pos > 1 and state.pos - 1 or state.pos
    state:extract_all_parameters_from_tokens(chunk.token_start_idx, chunk.token_end_idx, chunk.parameters)
  end

  return chunk
end

---Parse columns being added via ALTER TABLE ADD
---@param state ParserState
---@param temp_table TempTableInfo The temp table to add columns to
function DdlStatement._parse_alter_add_columns(state, temp_table)
  while state:current() do
    local token = state:current()

    -- Stop at statement terminators or new statements
    if token.type == "semicolon" or token.type == "go" then
      break
    end
    if token.type == "keyword" then
      local kw = token.text:upper()
      if kw == "GO" or Keywords.is_statement_starter(kw) then
        break
      end
    end

    -- Skip CONSTRAINT keyword and constraint definitions
    if token.type == "keyword" then
      local kw = token.text:upper()
      if kw == "CONSTRAINT" or kw == "PRIMARY" or kw == "FOREIGN" or
         kw == "UNIQUE" or kw == "CHECK" or kw == "DEFAULT" or kw == "INDEX" then
        DdlStatement._skip_until_comma_or_end(state)
        if state:is_type("comma") then
          state:advance()
        end
        goto continue_alter
      end
    end

    -- Parse column name
    if token.type == "identifier" or token.type == "bracket_id" then
      local col_name = Helpers.strip_brackets(token.text)
      state:advance()

      -- Parse data type
      local data_type = nil
      local type_token = state:current()
      if type_token and (type_token.type == "keyword" or type_token.type == "identifier") then
        data_type = type_token.text:upper()
        state:advance()

        -- Handle parameterized types like VARCHAR(50)
        if state:is_type("paren_open") then
          state:skip_paren_contents()
        end
      end

      -- Add column to temp table
      table.insert(temp_table.columns, {
        name = col_name,
        data_type = data_type,
        is_star = false,
      })

      -- Skip remaining column modifiers
      DdlStatement._skip_until_comma_or_end(state)

      -- Skip comma if present
      if state:is_type("comma") then
        state:advance()
      end
    else
      -- Unknown token, skip it
      state:advance()
    end

    ::continue_alter::
  end
end

---Skip until comma or end of statement
---@param state ParserState
function DdlStatement._skip_until_comma_or_end(state)
  while state:current() and not state:is_type("comma") do
    local t = state:current()
    if t.type == "semicolon" or t.type == "go" then break end
    if t.type == "keyword" then
      if Keywords.is_statement_starter(t.text) then
        break
      end
    end
    if state:is_type("paren_open") then
      state:skip_paren_contents()
    else
      state:advance()
    end
  end
end

return DdlStatement
