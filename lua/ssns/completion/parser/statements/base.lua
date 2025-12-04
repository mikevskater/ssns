--- Base statement utilities for SQL statement parsing
--- Provides shared functions for creating and finalizing statement chunks
---
---@module ssns.completion.parser.statements.base

require('ssns.completion.parser.types')

local BaseStatement = {}

---Create initial chunk structure for a statement
---@param statement_type string The type of statement (SELECT, INSERT, UPDATE, etc.)
---@param start_token table The token at which the statement begins
---@param go_batch_index number Which GO batch this statement belongs to
---@return StatementChunk
function BaseStatement.create_chunk(statement_type, start_token, go_batch_index)
  return {
    statement_type = statement_type,
    tables = {},
    aliases = {},
    columns = nil,
    subqueries = {},
    ctes = {},
    parameters = {},
    temp_table_name = nil,
    is_global_temp = nil,
    insert_columns = nil,
    start_line = start_token.line,
    end_line = start_token.line,
    start_col = start_token.col,
    end_col = start_token.col,
    go_batch_index = go_batch_index,
    clause_positions = {},
  }
end

---Finalize chunk after parsing (build aliases, resolve columns, copy subqueries)
---@param chunk StatementChunk The chunk to finalize
---@param scope ScopeContext The scope context with parsed data
function BaseStatement.finalize_chunk(chunk, scope)
  -- Build alias mapping from tables
  for _, table_ref in ipairs(chunk.tables) do
    if table_ref.alias then
      chunk.aliases[table_ref.alias:lower()] = table_ref
    end
  end

  -- Copy subqueries from scope
  chunk.subqueries = scope.subqueries

  -- Resolve column parent tables using aliases
  local Helpers = require('ssns.completion.parser.utils.helpers')
  Helpers.resolve_column_parents(chunk.columns, chunk.aliases, chunk.tables)
end

---Update chunk end position from a token
---@param chunk StatementChunk The chunk to update
---@param token table The token with line and col fields
function BaseStatement.update_end_position(chunk, token)
  if token then
    chunk.end_line = token.line
    chunk.end_col = token.col + (token.text and #token.text or 0)
  end
end

---Add a clause position to the chunk
---@param chunk StatementChunk The chunk to update
---@param clause_name string Name of the clause (select, from, where, etc.)
---@param start_token table Token at start of clause
---@param end_token table? Optional token at end of clause
function BaseStatement.add_clause_position(chunk, clause_name, start_token, end_token)
  end_token = end_token or start_token
  chunk.clause_positions[clause_name] = {
    start_line = start_token.line,
    start_col = start_token.col,
    end_line = end_token.line,
    end_col = end_token.col + (end_token.text and #end_token.text or 0),
  }
end

---Process FROM clause result and update chunk/scope
---Consolidates the common pattern used across SELECT, INSERT, UPDATE, DELETE handlers
---
---@param chunk StatementChunk The chunk to update
---@param scope ScopeContext The scope context
---@param result FromClauseResult The result from FromClauseParser.parse()
---@param options? {append_tables?: boolean, set_has_from?: boolean} Processing options
function BaseStatement.process_from_result(chunk, scope, result, options)
  options = options or {}

  -- Copy tables from result
  if options.append_tables then
    -- Append mode: preserve existing tables (e.g., INSERT target)
    for _, t in ipairs(result.tables) do
      table.insert(chunk.tables, t)
    end
  else
    -- Replace mode: replace any existing tables
    chunk.tables = result.tables
  end

  -- Store clause positions
  if result.clause_position then
    chunk.clause_positions["from"] = result.clause_position
  end

  -- Store individual JOIN positions
  if result.join_positions then
    for i, pos in ipairs(result.join_positions) do
      chunk.clause_positions["join_" .. i] = pos
    end
  end

  -- Store individual ON positions
  if result.on_positions then
    for i, pos in ipairs(result.on_positions) do
      chunk.clause_positions["on_" .. i] = pos
    end
  end

  -- Mark that we found a FROM clause (for UPDATE/DELETE extended syntax)
  if options.set_has_from then
    chunk.has_from_clause = true
  end

  -- Add tables to scope for visibility in subqueries
  for _, table_ref in ipairs(result.tables) do
    scope:add_table(table_ref)
  end
end

return BaseStatement
