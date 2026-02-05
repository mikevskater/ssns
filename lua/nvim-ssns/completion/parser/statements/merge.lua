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
    state:advance()  -- consume INTO
    local target = state:parse_table_reference(known_ctes)
    if target then
      table.insert(chunk.tables, target)
      scope:add_table(target)
    end
  end

  -- Parse USING source (table or subquery)
  if state:is_keyword("USING") then
    MergeStatement._parse_using(state, chunk, scope, known_ctes)
  end

  -- Skip rest of MERGE (ON condition, WHEN clauses with UPDATE/DELETE/INSERT)
  MergeStatement._skip_merge_body(state, chunk)

  -- Finalize: build aliases, resolve column parents, copy subqueries
  BaseStatement.finalize_chunk(chunk, scope, state)

  return chunk
end

---Parse USING clause (source table or subquery)
---@param state ParserState
---@param chunk StatementChunk
---@param scope ScopeContext
---@param known_ctes table<string, boolean>
function MergeStatement._parse_using(state, chunk, scope, known_ctes)
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
end

---Skip the rest of MERGE body (ON, WHEN clauses) and track end position
---MERGE body contains UPDATE/DELETE/INSERT which are NOT new statements
---@param state ParserState
---@param chunk StatementChunk Chunk to update end position
function MergeStatement._skip_merge_body(state, chunk)
  local merge_depth = 0
  local last_token = nil

  while state:current() do
    local tok = state:current()
    if not tok then break end

    local upper = tok.text:upper()

    if state:is_type("paren_open") then
      merge_depth = merge_depth + 1
    elseif state:is_type("paren_close") then
      merge_depth = merge_depth - 1
    end

    if merge_depth == 0 then
      if tok.type == "semicolon" or upper == "GO" then
        -- Include the semicolon in the range
        last_token = tok
        break
      end
      -- Break on new statements (NOT UPDATE/DELETE/INSERT - they're part of WHEN)
      if upper == "SELECT" or upper == "CREATE" or upper == "ALTER" or
         upper == "DROP" or upper == "TRUNCATE" or upper == "WITH" or
         upper == "EXEC" or upper == "EXECUTE" or upper == "DECLARE" or
         upper == "MERGE" then
        break
      end
    end

    last_token = tok
    state:advance()
  end

  -- Update chunk end position to last token in MERGE body
  if last_token then
    BaseStatement.update_end_position(chunk, last_token)
  end
end

return MergeStatement
