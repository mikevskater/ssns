--- MERGE statement handler
--- Parses MERGE statements including target table and USING source
---
--- Syntax: MERGE INTO target [AS alias] USING source [AS alias] ON condition
---         WHEN MATCHED THEN UPDATE/DELETE
---         WHEN NOT MATCHED THEN INSERT
---
---@module ssns.completion.parser.statements.merge

require('nvim-ssns.completion.parser.types')
local BaseStatement = require('nvim-ssns.completion.parser.statements.base')
local AliasParser = require('nvim-ssns.completion.parser.utils.alias')
local Keywords = require('nvim-ssns.completion.parser.utils.keywords')

local MergeStatement = {}

---Parse a MERGE statement
---
---@param state ParserState Token navigation state (positioned at MERGE keyword)
---@param scope ScopeContext Scope context for CTE/subquery tracking
---@param temp_tables table<string, TempTableInfo> Temp tables collection (unused)
---@return StatementChunk chunk The parsed statement chunk
function MergeStatement.parse(state, scope, temp_tables)
  state:mark_chunk_start()  -- Mark token position for this chunk
  local start_token = state:current()
  local chunk = BaseStatement.create_chunk("MERGE", start_token, state.go_batch_index, state)

  scope.statement_type = "MERGE"
  state:advance()  -- consume MERGE

  -- Build known_ctes for table reference parsing
  local known_ctes = scope:get_known_ctes_table()

  -- Parse MERGE INTO target_table [AS alias]
  if state:is_keyword("INTO") then
    local into_token = state:current()
    state:advance()  -- consume INTO
    local target = state:parse_table_reference(known_ctes)
    if target then
      table.insert(chunk.tables, target)
      scope:add_table(target)
    end
    local last = state.pos > 1 and state.tokens[state.pos - 1] or into_token
    BaseStatement.add_clause_position(chunk, "into", into_token, last)
  end

  -- Parse USING source (table or subquery)
  if state:is_keyword("USING") then
    MergeStatement._parse_using(state, chunk, scope, known_ctes)
  end

  -- Parse rest of MERGE body (ON condition, WHEN clauses with UPDATE/DELETE/INSERT)
  MergeStatement._parse_merge_body(state, chunk, scope)

  -- Finalize: build aliases, resolve column parents, copy subqueries
  BaseStatement.finalize_chunk(chunk, scope, state)

  return chunk
end

---Parse USING clause (source table or subquery) and track clause position
---@param state ParserState
---@param chunk StatementChunk
---@param scope ScopeContext
---@param known_ctes table<string, boolean>
function MergeStatement._parse_using(state, chunk, scope, known_ctes)
  local using_token = state:current()
  state:advance()  -- consume USING

  -- Check for subquery: USING (SELECT ...)
  if state:is_type("paren_open") then
    state:advance()  -- consume (

    if state:is_keyword("SELECT") then
      local subquery = state:parse_subquery(known_ctes)
      if subquery then
        if state:is_type("paren_close") then
          state:advance()  -- consume )
          subquery.alias = AliasParser.parse(state)
        end
        table.insert(chunk.subqueries, subquery)
        scope:add_subquery(subquery)
      end
    else
      -- Skip non-SELECT content (VALUES, etc.)
      local pd = 1
      while state:current() and pd > 0 do
        if state:is_type("paren_open") then
          pd = pd + 1
        elseif state:is_type("paren_close") then
          pd = pd - 1
        end
        state:advance()
      end
      AliasParser.parse(state)
    end
  else
    -- Simple table reference: USING SourceTable s
    local source = state:parse_table_reference(known_ctes)
    if source then
      table.insert(chunk.tables, source)
      scope:add_table(source)
    end
  end

  -- Track USING clause position
  local last = state.pos > 1 and state.tokens[state.pos - 1] or using_token
  BaseStatement.add_clause_position(chunk, "using", using_token, last)
end

---Parse the MERGE body: ON condition and WHEN clauses with clause position tracking
---MERGE body contains UPDATE/DELETE/INSERT which are NOT new statements
---@param state ParserState
---@param chunk StatementChunk Chunk to update
---@param scope ScopeContext Scope context
function MergeStatement._parse_merge_body(state, chunk, scope)
  local merge_depth = 0
  local when_count = 0

  -- Parse ON condition
  if state:is_keyword("ON") then
    local on_token = state:current()
    state:advance()  -- consume ON
    local last_token = on_token
    -- Skip ON condition until WHEN or statement end
    while state:current() do
      local t = state:current()
      if t.type == "paren_open" then merge_depth = merge_depth + 1 end
      if t.type == "paren_close" then merge_depth = merge_depth - 1 end
      if merge_depth == 0 then
        if t.type == "keyword" and t.text:upper() == "WHEN" then break end
        if t.type == "semicolon" or t.type == "go" then break end
        if t.type == "keyword" and MergeStatement._is_merge_terminator(t.text:upper()) then break end
      end
      last_token = t
      state:advance()
    end
    BaseStatement.add_clause_position(chunk, "on", on_token, last_token)
    merge_depth = 0
  end

  -- Parse WHEN clauses
  while state:current() and state:is_keyword("WHEN") do
    when_count = when_count + 1
    local when_token = state:current()
    state:advance()  -- consume WHEN

    -- Determine MATCHED vs NOT MATCHED
    local is_not_matched = false
    if state:is_keyword("NOT") then
      is_not_matched = true
      state:advance()
    end
    if state:is_keyword("MATCHED") then state:advance() end

    -- Optional BY SOURCE / BY TARGET
    if state:is_keyword("BY") then
      state:advance()
      if state:current() and (state:current().text:upper() == "SOURCE" or state:current().text:upper() == "TARGET") then
        state:advance()
      end
    end

    -- Optional AND condition — skip until THEN
    if state:is_keyword("AND") then
      while state:current() and not state:is_keyword("THEN") do
        local t = state:current()
        if t.type == "paren_open" then merge_depth = merge_depth + 1 end
        if t.type == "paren_close" then merge_depth = merge_depth - 1 end
        if t.type == "semicolon" or t.type == "go" then break end
        state:advance()
      end
      merge_depth = 0
    end

    if state:is_keyword("THEN") then state:advance() end

    -- Parse action: UPDATE SET / DELETE / INSERT
    local last_action_token = state:current() or when_token
    if state:is_keyword("UPDATE") then
      state:advance()  -- consume UPDATE
      if state:is_keyword("SET") then
        local set_token = state:current()
        state:advance()  -- consume SET
        -- Parse SET assignments until next WHEN, OUTPUT, semicolon, or statement end
        local last_set = set_token
        while state:current() do
          local t = state:current()
          if t.type == "paren_open" then merge_depth = merge_depth + 1 end
          if t.type == "paren_close" then merge_depth = merge_depth - 1 end
          if merge_depth == 0 then
            if t.type == "keyword" then
              local kw = t.text:upper()
              if kw == "WHEN" or kw == "OUTPUT" then break end
              if MergeStatement._is_merge_terminator(kw) then break end
            end
            if t.type == "semicolon" or t.type == "go" then break end
          end
          last_set = t
          state:advance()
        end
        merge_depth = 0
        BaseStatement.add_clause_position(chunk, "merge_set_" .. when_count, set_token, last_set)
        last_action_token = last_set
      end
    elseif state:is_keyword("DELETE") then
      last_action_token = state:current()
      state:advance()
    elseif state:is_keyword("INSERT") then
      state:advance()  -- consume INSERT
      -- Parse INSERT column list if present
      if state:is_type("paren_open") then
        local col_start = state:current()
        state:advance()  -- consume (
        while state:current() and not state:is_type("paren_close") do
          state:advance()
        end
        if state:is_type("paren_close") then
          local col_end = state:current()
          BaseStatement.add_clause_position(chunk, "merge_insert_cols_" .. when_count, col_start, col_end)
          state:advance()  -- consume )
        end
      end
      -- Parse VALUES
      if state:is_keyword("VALUES") then
        local val_token = state:current()
        state:advance()  -- consume VALUES
        if state:is_type("paren_open") then
          state:skip_paren_contents()
        end
        local last_val = state.pos > 1 and state.tokens[state.pos - 1] or val_token
        BaseStatement.add_clause_position(chunk, "merge_values_" .. when_count, val_token, last_val)
        last_action_token = last_val
      end
    else
      -- Unknown action — skip until next WHEN or end
      while state:current() do
        local t = state:current()
        if t.type == "keyword" and t.text:upper() == "WHEN" then break end
        if t.type == "semicolon" or t.type == "go" then break end
        if t.type == "keyword" and MergeStatement._is_merge_terminator(t.text:upper()) then break end
        last_action_token = t
        state:advance()
      end
    end

    -- Track WHEN clause position
    local clause_name = is_not_matched and ("when_not_matched_" .. when_count) or ("when_matched_" .. when_count)
    BaseStatement.add_clause_position(chunk, clause_name, when_token, last_action_token)
  end

  -- Parse OUTPUT clause if present
  if state:is_keyword("OUTPUT") then
    local output_token = state:current()
    state:advance()
    local last_output = output_token
    while state:current() do
      local t = state:current()
      if t.type == "semicolon" or t.type == "go" then break end
      if t.type == "keyword" and MergeStatement._is_merge_terminator(t.text:upper()) then break end
      last_output = t
      state:advance()
    end
    BaseStatement.add_clause_position(chunk, "output", output_token, last_output)
  end

  -- Update chunk end position
  if state.pos > 1 then
    BaseStatement.update_end_position(chunk, state.tokens[state.pos - 1])
  end
end

---Check if a keyword terminates the MERGE statement (is a new statement, but not MERGE actions)
---@param upper string Uppercased keyword
---@return boolean
function MergeStatement._is_merge_terminator(upper)
  return upper == "SELECT" or upper == "CREATE" or upper == "ALTER" or
         upper == "DROP" or upper == "TRUNCATE" or upper == "WITH" or
         upper == "EXEC" or upper == "EXECUTE" or upper == "DECLARE" or
         upper == "MERGE" or upper == "SET"
end

return MergeStatement
