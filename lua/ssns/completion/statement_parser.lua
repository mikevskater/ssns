---@class TableReference
---@field server string? Linked server name (four-part name)
---@field database string? Database name (cross-db reference)
---@field schema string? Schema name
---@field name string Table/view/synonym name
---@field alias string? Alias if any
---@field is_temp boolean Whether it's a temp table (#temp or ##temp)
---@field is_global_temp boolean Whether it's a global temp table (##temp)
---@field is_table_variable boolean Whether it's a table variable (@TableVar)
---@field is_cte boolean Whether it references a CTE

---@class ParameterInfo
---@field name string Parameter name (without @)
---@field full_name string Full parameter name (with @)
---@field line number Line where parameter appears
---@field col number Column where parameter appears
---@field is_system boolean Whether it's a system variable (@@)

---@class ColumnInfo
---@field name string Column name or alias
---@field source_table string? Table/alias prefix used in the query
---@field parent_table string? Actual base table name (resolved from alias)
---@field parent_schema string? Schema of the parent table
---@field is_star boolean Whether this is a * or alias.*

---@class ClausePosition
---@field start_line number 1-indexed start line
---@field start_col number 1-indexed start column
---@field end_line number 1-indexed end line
---@field end_col number 1-indexed end column

---@class SubqueryInfo
---@field alias string? The alias after closing paren
---@field columns ColumnInfo[] Columns from SELECT list
---@field tables TableReference[] Tables in FROM clause
---@field subqueries SubqueryInfo[] Nested subqueries (recursive)
---@field parameters ParameterInfo[] Parameters used in this subquery
---@field start_pos {line: number, col: number}
---@field end_pos {line: number, col: number}
---@field clause_positions table<string, ClausePosition>? Clause positions within subquery

---@class CTEInfo
---@field name string CTE name
---@field columns ColumnInfo[] Columns from SELECT list
---@field tables TableReference[] Tables referenced
---@field subqueries SubqueryInfo[] Any nested subqueries
---@field parameters ParameterInfo[] Parameters used in this CTE

---@class StatementChunk
---@field statement_type string "SELECT"|"SELECT_INTO"|"INSERT"|"UPDATE"|"DELETE"|"WITH"|"EXEC"|"OTHER"
---@field tables TableReference[] Tables from FROM/JOIN clauses
---@field aliases table<string, TableReference> Alias -> table mapping
---@field columns ColumnInfo[]? For SELECT - columns in SELECT list
---@field subqueries SubqueryInfo[] Subqueries with aliases (recursive)
---@field ctes CTEInfo[] CTEs defined in WITH clause
---@field parameters ParameterInfo[] Parameters/variables used in this chunk
---@field temp_table_name string? For SELECT INTO / CREATE TABLE #temp
---@field is_global_temp boolean? Whether temp_table_name is a global temp (##)
---@field insert_columns string[]? Column names in INSERT INTO table (col1, col2, ...)
---@field start_line number 1-indexed start line
---@field end_line number 1-indexed end line
---@field start_col number 1-indexed start column (only relevant on start_line)
---@field end_col number 1-indexed end column (only relevant on end_line)
---@field go_batch_index number Which GO batch this belongs to (1-indexed)
---@field clause_positions table<string, ClausePosition>? Positions of each clause (select, from, where, values, insert_columns, etc.)

---@class TempTableInfo
---@field name string Temp table name
---@field columns ColumnInfo[] Columns in the temp table
---@field created_in_batch number GO batch index where it was created
---@field is_global boolean Whether it's a global temp table (##)
---@field dropped_at_line number? Line number where dropped (nil if not dropped)

-- Load type annotations (for LuaLS type checking)
require('ssns.completion.parser.types')

-- Import ParserState from parser module
local ParserState = require('ssns.completion.parser.state')

-- Import utility modules (Phase 1 refactoring)
local Keywords = require('ssns.completion.parser.utils.keywords')
local Helpers = require('ssns.completion.parser.utils.helpers')
local QualifiedName = require('ssns.completion.parser.utils.qualified_name')
local AliasParser = require('ssns.completion.parser.utils.alias')
local TableReferenceParser = require('ssns.completion.parser.utils.table_reference')

local StatementParser = {}

-- Local aliases for module functions (for convenience and backward compatibility)
local resolve_column_parents = Helpers.resolve_column_parents
local strip_brackets = Helpers.strip_brackets
local is_temp_table = Helpers.is_temp_table
local is_global_temp_table = Helpers.is_global_temp_table
local is_table_variable = Helpers.is_table_variable
local is_from_keyword = Keywords.is_from_keyword
local is_statement_starter = Keywords.is_statement_starter
local JOIN_MODIFIERS = Keywords.JOIN_MODIFIERS
local FROM_TERMINATORS = Keywords.FROM_TERMINATORS

-- ParserState method wrappers that delegate to utility modules
-- These maintain the method-style interface while using the extracted modules

---Parse qualified identifier (server.db.schema.table or db.schema.table or schema.table or table)
---@return {server: string?, database: string?, schema: string?, name: string}?
function ParserState:parse_qualified_identifier()
  return QualifiedName.parse(self)
end

---Try to parse an alias (AS alias or just alias)
---@return string?
function ParserState:parse_alias()
  return AliasParser.parse(self)
end

---Parse a table reference with optional alias
---@param known_ctes table<string, boolean>
---@return TableReference?
function ParserState:parse_table_reference(known_ctes)
  return TableReferenceParser.parse_legacy(self, known_ctes)
end

---Parse columns in SELECT list (between SELECT and FROM)
---@param paren_depth number
---@param known_ctes table<string, boolean>?
---@param subqueries SubqueryInfo[]?
---@param select_start_token table? The SELECT keyword token (for position tracking)
---@return ColumnInfo[], ClausePosition?
function ParserState:parse_select_columns(paren_depth, known_ctes, subqueries, select_start_token)
  local columns = {}
  local current_col = nil
  local current_source_table = nil

  -- Track SELECT clause position
  local clause_pos = nil
  if select_start_token then
    clause_pos = {
      start_line = select_start_token.line,
      start_col = select_start_token.col,
      end_line = select_start_token.line,
      end_col = select_start_token.col,
    }
  end

  while self:current() do
    local token = self:current()

    -- Stop at FROM or INTO keyword at same paren depth
    -- INTO is needed for SELECT...INTO table patterns
    if paren_depth == 0 and (self:is_keyword("FROM") or self:is_keyword("INTO")) then
      break
    end

    -- Handle nested parens
    if token.type == "paren_open" then
      -- Check for subquery: (SELECT ...)
      local next_pos = self.pos + 1
      local next_token = self.tokens[next_pos]
      if next_token and next_token.type == "keyword" and next_token.text:upper() == "SELECT" then
        -- This is a subquery in SELECT list
        self:advance()  -- consume (
        if subqueries then
          local subquery = self:parse_subquery(known_ctes or {})
          if subquery then
            table.insert(subqueries, subquery)
            -- Expect closing paren
            if self:is_type("paren_close") then
              self:advance()  -- consume )
            end
          end
        else
          -- Skip if no subqueries table
          local depth = 1
          while self:current() and depth > 0 do
            if self:is_type("paren_open") then depth = depth + 1
            elseif self:is_type("paren_close") then depth = depth - 1
            end
            self:advance()
          end
        end
      else
        -- Regular parenthesized expression
        paren_depth = paren_depth + 1
        self:advance()
      end
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        break
      end
      self:advance()
    elseif token.type == "star" then
      -- Check context: is this SELECT * or arithmetic *?
      if current_col and paren_depth == 0 then
        -- Arithmetic operator at column level (e.g., "Salary * 12")
        -- Skip the * and continue - the expression result will be
        -- captured when we hit AS (alias) or comma/FROM (no alias)
        self:advance()
        -- Continue consuming the expression until AS, comma, or FROM
        while self.pos <= #self.tokens do
          local next_tok = self:current()
          if not next_tok then break end
          if next_tok.type == "comma" then break end
          if self:is_keyword("AS") then break end
          if self:is_keyword("FROM") then break end
          if self:is_keyword("INTO") then break end
          if self:is_keyword("WHERE") then break end
          self:advance()
        end
        -- Now current_col still has the first identifier (e.g., "Salary")
        -- If there's an AS next, it will be handled and create a proper column
        -- If not, we'll flush "Salary" as the column name at comma/FROM
      elseif current_source_table and paren_depth == 0 then
        -- alias.* pattern (e.g., "t.*")
        table.insert(columns, {
          name = "*",
          source_table = current_source_table,
          is_star = true,
        })
        current_source_table = nil
        current_col = nil
        self:advance()
      elseif paren_depth == 0 then
        -- Standalone * (SELECT *) at column level
        table.insert(columns, {
          name = "*",
          source_table = nil,
          is_star = true,
        })
        current_col = nil
        self:advance()
      else
        -- Star inside parentheses (e.g., COUNT(*)) - just skip it
        self:advance()
      end
    elseif token.type == "dot" then
      -- Previous identifier is a table qualifier
      if current_col then
        current_source_table = current_col
        current_col = nil
      end
      self:advance()
    elseif token.type == "identifier" or token.type == "bracket_id" then
      current_col = strip_brackets(token.text)
      self:advance()

      -- Check for AS keyword for alias
      if self:is_keyword("AS") then
        self:advance()
        local alias_token = self:current()
        -- Accept identifiers, bracket_ids, and keywords as aliases (SQL keywords can be valid aliases)
        if alias_token and (alias_token.type == "identifier" or alias_token.type == "bracket_id" or alias_token.type == "keyword") then
          current_col = strip_brackets(alias_token.text)
          -- Don't clear current_source_table - preserve the table reference for the alias
          self:advance()
        end
      end
    elseif token.type == "comma" then
      -- End of current column
      if current_col then
        table.insert(columns, {
          name = current_col,
          source_table = current_source_table,
          is_star = false,
        })
        current_col = nil
        current_source_table = nil
      end
      self:advance()
    elseif self:is_keyword("AS") then
      -- Handle AS keyword for expressions (e.g., "1 AS Level", "GETDATE() AS Today")
      -- This captures aliased expressions where the expression itself isn't tracked
      self:advance()
      local alias_token = self:current()
      -- Accept identifiers, bracket_ids, and keywords as aliases
      if alias_token and (alias_token.type == "identifier" or alias_token.type == "bracket_id" or alias_token.type == "keyword") then
        current_col = strip_brackets(alias_token.text)
        self:advance()
      end
    else
      -- Other tokens (numbers, operators, etc.) - keep parsing
      self:advance()
    end
  end

  -- Add last column if any
  if current_col then
    table.insert(columns, {
      name = current_col,
      source_table = current_source_table,
      is_star = false,
    })
  end

  -- Update clause end position to just before FROM/INTO keyword
  -- This ensures cursor at "SELECT █ FROM" is still in SELECT clause
  if clause_pos then
    local next_keyword_token = self:current()  -- FROM or INTO token
    if next_keyword_token then
      -- Set end to just before the FROM/INTO token
      clause_pos.end_line = next_keyword_token.line
      clause_pos.end_col = next_keyword_token.col - 1
    else
      -- No FROM/INTO found, use last token processed
      local last_token = self.pos > 1 and self.tokens[self.pos - 1] or select_start_token
      if last_token then
        clause_pos.end_line = last_token.line
        clause_pos.end_col = last_token.col + #last_token.text - 1
      end
    end
  end

  return columns, clause_pos
end

---Parse FROM/JOIN clauses to extract tables
---@param known_ctes table<string, boolean>
---@param paren_depth number
---@param subqueries? SubqueryInfo[] Optional collection to add subqueries to
---@param from_start_token table? The FROM keyword token (for position tracking)
---@return TableReference[], ClausePosition?, table, table
function ParserState:parse_from_clause(known_ctes, paren_depth, subqueries, from_start_token)
  local tables = {}

  -- Track FROM clause position
  local clause_pos = nil
  if from_start_token then
    clause_pos = {
      start_line = from_start_token.line,
      start_col = from_start_token.col,
      end_line = from_start_token.line,
      end_col = from_start_token.col,
    }
  end

  -- Track individual JOIN and ON positions
  local join_positions = {}  -- Array of {start_line, start_col, end_line, end_col}
  local on_positions = {}    -- Array of {start_line, start_col, end_line, end_col}
  local current_join_start = nil
  local current_on_start = nil
  local join_count = 0

  while self:current() do
    local token = self:current()

    -- Handle parens
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      self:advance()

      -- Check for subquery or VALUES table constructor
      if self:is_keyword("SELECT") then
        -- Parse the subquery
        local subquery = self:parse_subquery(known_ctes)
        if subquery then
          -- Find closing paren and alias
          if self:is_type("paren_close") then
            paren_depth = paren_depth - 1
            self:advance()
            subquery.alias = self:parse_alias()
          end
          -- Add to subqueries collection if provided
          if subqueries then
            table.insert(subqueries, subquery)
          end
        end
        -- Continue parsing FROM clause (may have more tables/subqueries)
      elseif self:is_keyword("VALUES") then
        -- Parse VALUES table constructor: (VALUES (row1), (row2), ...) AS alias(col1, col2)
        self:advance() -- consume VALUES

        -- Skip value rows - count parens to find end
        local values_depth = 0
        while self:current() do
          local vtok = self:current()
          if vtok.type == "paren_open" then
            values_depth = values_depth + 1
          elseif vtok.type == "paren_close" then
            if values_depth == 0 then
              break -- Found the closing ) for (VALUES ...)
            end
            values_depth = values_depth - 1
          end
          self:advance()
        end

        -- Consume closing paren
        if self:is_type("paren_close") then
          paren_depth = paren_depth - 1
          self:advance()
        end

        -- Parse alias with column list: AS v(ID, Letter)
        local values_alias = self:parse_alias()
        if values_alias then
          -- Check for column list
          local column_list = {}
          if self:is_type("paren_open") then
            self:advance() -- consume (
            while self:current() do
              local col_tok = self:current()
              if col_tok.type == "paren_close" then
                self:advance()
                break
              elseif col_tok.type == "comma" then
                self:advance()
              elseif col_tok.type == "identifier" or col_tok.type == "bracket_id" or col_tok.type == "keyword" then
                table.insert(column_list, strip_brackets(col_tok.text))
                self:advance()
              else
                self:advance()
              end
            end
          end

          -- Create a virtual subquery for the VALUES table
          local values_subquery = {
            alias = values_alias,
            columns = {},
            tables = {},
            subqueries = {},
            parameters = {},
            is_values = true,
            start_pos = { line = token.line, col = token.col },
            end_pos = { line = token.line, col = token.col },
            clause_positions = {},
          }

          -- Add columns from column list
          for _, col_name in ipairs(column_list) do
            table.insert(values_subquery.columns, {
              name = col_name,
              source_table = values_alias,
              is_star = false,
            })
          end

          -- Add to subqueries collection
          if subqueries then
            table.insert(subqueries, values_subquery)
          end
        end
      end
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      if paren_depth < 0 then
        break
      end
      self:advance()
    elseif is_from_keyword(token.text) then
      local upper_text = token.text:upper()

      -- Track JOIN/ON positions
      -- When we detect a JOIN keyword (not FROM), track its position
      if upper_text ~= "FROM" then
        -- If there was a previous ON clause, end it here
        if current_on_start then
          local prev_token = self.tokens[self.pos - 1]
          if prev_token then
            table.insert(on_positions, {
              start_line = current_on_start.line,
              start_col = current_on_start.col,
              end_line = prev_token.line,
              end_col = prev_token.col + #prev_token.text - 1,
            })
          end
          current_on_start = nil
        end

        -- Track new JOIN start (use the first modifier token as start)
        if upper_text ~= "JOIN" and JOIN_MODIFIERS[upper_text] then
          current_join_start = token  -- INNER, LEFT, etc.
        elseif upper_text == "JOIN" then
          -- Plain JOIN keyword (not preceded by modifier)
          -- Must track it here before advancing past it
          current_join_start = token
          join_count = join_count + 1
        end
      end

      self:advance()

      -- Skip JOIN modifiers
      while self:current() and JOIN_MODIFIERS[self:current().text:upper()] do
        self:advance()
      end

      -- Skip the JOIN keyword itself (if present after modifiers)
      if self:is_keyword("JOIN") then
        if not current_join_start then
          current_join_start = self:current()
        end
        join_count = join_count + 1
        self:advance()
      end

      -- Handle APPLY (CROSS APPLY, OUTER APPLY) - T-SQL specific
      -- APPLY takes a table-valued function or subquery, not a regular table
      if self:is_keyword("APPLY") then
        self:advance()  -- consume APPLY

        -- Check for subquery: CROSS APPLY (SELECT ...)
        if self:is_type("paren_open") then
          self:advance()  -- consume (
          if self:is_keyword("SELECT") then
            -- Parse as subquery
            local subquery = self:parse_subquery(known_ctes)
            if subquery then
              -- parse_subquery stops AT the closing ) - consume it
              if self:is_type("paren_close") then
                self:advance()
              end
              -- Parse the alias BEFORE adding to subqueries, so we can assign it
              local apply_alias = self:parse_alias()
              if apply_alias then
                subquery.alias = apply_alias
              end
              table.insert(subqueries, subquery)
            end
          else
            -- Skip parenthesized function call: CROSS APPLY dbo.fn(...) or CROSS APPLY (VALUES...)
            local paren_depth_apply = 1
            while self:current() and paren_depth_apply > 0 do
              if self:is_type("paren_open") then
                paren_depth_apply = paren_depth_apply + 1
              elseif self:is_type("paren_close") then
                paren_depth_apply = paren_depth_apply - 1
              end
              self:advance()
            end
            -- Skip optional alias for VALUES/function
            self:parse_alias()
          end
        else
          -- Table-valued function without subquery: CROSS APPLY dbo.GetOrders(e.Id) AS o
          -- Parse the function name and track it as a TVF
          local tvf_qualified = self:parse_qualified_identifier()
          -- Skip function arguments if present
          if self:is_type("paren_open") then
            local paren_depth_apply = 1
            self:advance()
            while self:current() and paren_depth_apply > 0 do
              if self:is_type("paren_open") then
                paren_depth_apply = paren_depth_apply + 1
              elseif self:is_type("paren_close") then
                paren_depth_apply = paren_depth_apply - 1
              end
              self:advance()
            end
          end
          -- Parse alias for table-valued function
          local tvf_alias = self:parse_alias()
          -- Track TVF as a table reference (columns will be looked up from metadata)
          if tvf_qualified then
            local tvf_ref = {
              name = tvf_qualified.name,
              schema = tvf_qualified.schema or "dbo",
              database = tvf_qualified.database,
              alias = tvf_alias or tvf_qualified.name,
              is_tvf = true,
              function_name = tvf_qualified.name,
            }
            table.insert(tables, tvf_ref)
          end
        end
        -- TVF is handled, continue to next token
        goto continue_from_loop
      end

      -- Check for ON keyword before table reference
      if self:is_keyword("ON") then
        -- End the current JOIN position (JOIN ends at ON)
        if current_join_start then
          local prev_token = self.tokens[self.pos - 1]
          if prev_token then
            table.insert(join_positions, {
              start_line = current_join_start.line,
              start_col = current_join_start.col,
              end_line = prev_token.line,
              end_col = prev_token.col + #prev_token.text - 1,
            })
          end
          current_join_start = nil
        end

        -- Start tracking ON clause
        current_on_start = self:current()
        self:advance()  -- Move past ON
        -- Continue loop - ON condition will be consumed until next JOIN/terminator
        goto continue_from_loop
      end

      -- Parse table reference
      local table_ref = self:parse_table_reference(known_ctes)
      if table_ref then
        table.insert(tables, table_ref)
      end

      -- Handle comma-separated tables (FROM A, B, C)
      while self:is_type("comma") do
        self:advance()
        table_ref = self:parse_table_reference(known_ctes)
        if table_ref then
          table.insert(tables, table_ref)
        end
      end

      ::continue_from_loop::
    elseif token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      -- GO batch separator - stop parsing FROM clause
      break
    elseif paren_depth == 0 and is_statement_starter(token.text) then
      -- New statement starting
      -- BUT: WITH in FROM clause context is a table hint, not a CTE starter
      if token.text:upper() == "WITH" then
        -- This is a table hint (WITH NOLOCK), not a new statement
        -- Skip it and continue parsing
        self:advance()  -- consume WITH
        if self:is_type("paren_open") then
          -- Skip parenthesized hints like (NOLOCK, INDEX(...))
          local hint_depth = 1
          self:advance() -- consume (
          while self:current() and hint_depth > 0 do
            if self:is_type("paren_open") then
              hint_depth = hint_depth + 1
            elseif self:is_type("paren_close") then
              hint_depth = hint_depth - 1
            end
            self:advance()
          end
        end
      else
        break
      end
    elseif paren_depth == 0 and (token.text:upper() == "UNION" or token.text:upper() == "INTERSECT" or token.text:upper() == "EXCEPT") then
      -- Set operations - stop parsing FROM clause, let caller handle
      break
    elseif paren_depth == 0 and token.type == "keyword" and FROM_TERMINATORS[token.text:upper()] then
      -- FROM clause terminators (WHERE, GROUP BY, ORDER BY, etc.)
      -- Stop parsing FROM clause, let caller handle the rest of the statement
      break
    elseif paren_depth == 0 and self:is_keyword("ON") then
      -- ON keyword after table reference (standard SQL: JOIN Table ON condition)
      -- End any current JOIN position
      if current_join_start then
        local prev_token = self.tokens[self.pos - 1]
        if prev_token then
          table.insert(join_positions, {
            start_line = current_join_start.line,
            start_col = current_join_start.col,
            end_line = prev_token.line,
            end_col = prev_token.col + #prev_token.text - 1,
          })
        end
        current_join_start = nil
      end

      -- If there was a previous ON clause, end it here
      if current_on_start then
        local prev_token = self.tokens[self.pos - 1]
        if prev_token then
          table.insert(on_positions, {
            start_line = current_on_start.line,
            start_col = current_on_start.col,
            end_line = prev_token.line,
            end_col = prev_token.col + #prev_token.text - 1,
          })
        end
      end

      -- Start tracking new ON clause
      current_on_start = self:current()
      self:advance()  -- Move past ON
    else
      self:advance()
    end
  end

  -- Update clause end position to the last token processed (before WHERE/GROUP/ORDER/etc.)
  if clause_pos then
    local last_token = self.pos > 1 and self.tokens[self.pos - 1] or from_start_token
    if last_token then
      clause_pos.end_line = last_token.line
      clause_pos.end_col = last_token.col + #last_token.text - 1
    end
  end

  -- Finalize any open JOIN clause
  if current_join_start then
    local end_token = self.tokens[self.pos - 1] or current_join_start
    table.insert(join_positions, {
      start_line = current_join_start.line,
      start_col = current_join_start.col,
      end_line = end_token.line,
      end_col = end_token.col + #end_token.text - 1,
    })
  end

  -- Finalize any open ON clause
  if current_on_start then
    local end_token = self.tokens[self.pos - 1] or current_on_start
    table.insert(on_positions, {
      start_line = current_on_start.line,
      start_col = current_on_start.col,
      end_line = end_token.line,
      end_col = end_token.col + #end_token.text - 1,
    })
  end

  return tables, clause_pos, join_positions, on_positions
end

---Parse a subquery recursively
---@param known_ctes table<string, boolean>
---@return SubqueryInfo?
function ParserState:parse_subquery(known_ctes)
  local start_token = self:current()
  if not start_token then
    return nil
  end

  -- Track token range for parameter extraction
  local start_token_idx = self.pos

  local subquery = {
    alias = nil,
    columns = {},
    tables = {},
    subqueries = {},
    parameters = {},
    start_pos = { line = start_token.line, col = start_token.col },
    end_pos = { line = start_token.line, col = start_token.col },
    clause_positions = {},
  }

  -- We're at SELECT keyword - save it for position tracking
  local select_token = self:current()
  self:advance()

  local paren_depth = 0

  -- Parse SELECT list with position tracking
  local select_clause_pos
  subquery.columns, select_clause_pos = self:parse_select_columns(paren_depth, known_ctes, subquery.subqueries, select_token)
  if select_clause_pos then
    subquery.clause_positions["select"] = select_clause_pos
  end

  -- Parse FROM clause with position tracking
  if self:is_keyword("FROM") then
    local from_token = self:current()
    local from_clause_pos, join_positions, on_positions
    subquery.tables, from_clause_pos, join_positions, on_positions = self:parse_from_clause(known_ctes, paren_depth, subquery.subqueries, from_token)
    if from_clause_pos then
      subquery.clause_positions["from"] = from_clause_pos
    end
    -- Add join and on positions
    if join_positions then
      for i, pos in ipairs(join_positions) do
        subquery.clause_positions["join_" .. i] = pos
      end
    end
    if on_positions then
      for i, pos in ipairs(on_positions) do
        subquery.clause_positions["on_" .. i] = pos
      end
    end
  end

  -- Handle set operations (UNION, INTERSECT, EXCEPT) to capture tables from all members
  -- Also capture nested subqueries in WHERE/HAVING clauses along the way
  -- Track WHERE clause position for subquery context detection
  local where_start = nil
  local last_token_before_end = nil

  while self:current() do
    -- Skip until we hit UNION/INTERSECT/EXCEPT or end of subquery, parsing nested subqueries
    local set_op_paren_depth = 0
    while self:current() do
      local token = self:current()

      -- Track WHERE clause start
      if set_op_paren_depth == 0 and self:is_keyword("WHERE") and not where_start then
        where_start = token
      end

      -- Track last token for WHERE clause end position
      last_token_before_end = token

      if token.type == "paren_open" then
        set_op_paren_depth = set_op_paren_depth + 1
        self:advance()
        -- Check for nested subquery: (SELECT ...
        if self:is_keyword("SELECT") then
          local nested = self:parse_subquery(known_ctes)
          if nested then
            table.insert(subquery.subqueries, nested)
          end
          -- After parse_subquery, parser is AT the closing ) - consume it and decrement depth
          if self:is_type("paren_close") then
            last_token_before_end = self:current()
            self:advance()
          end
          set_op_paren_depth = set_op_paren_depth - 1
        end
      elseif token.type == "paren_close" then
        if set_op_paren_depth == 0 then
          -- End of subquery - record WHERE clause position if we found one
          if where_start and last_token_before_end then
            subquery.clause_positions["where"] = {
              start_line = where_start.line,
              start_col = where_start.col,
              end_line = last_token_before_end.line,
              end_col = last_token_before_end.col + #last_token_before_end.text - 1,
            }
          end
          break
        end
        set_op_paren_depth = set_op_paren_depth - 1
        self:advance()
      elseif set_op_paren_depth == 0 and (self:is_keyword("UNION") or self:is_keyword("INTERSECT") or self:is_keyword("EXCEPT")) then
        -- Found set operation - record WHERE clause position if we found one
        if where_start and last_token_before_end then
          subquery.clause_positions["where"] = {
            start_line = where_start.line,
            start_col = where_start.col,
            end_line = last_token_before_end.line,
            end_col = last_token_before_end.col + #last_token_before_end.text - 1,
          }
        end
        break
      else
        self:advance()
      end
    end

    local is_set_op = self:is_keyword("UNION") or self:is_keyword("INTERSECT") or self:is_keyword("EXCEPT")
    if not is_set_op then
      break
    end

    self:advance()  -- consume UNION/INTERSECT/EXCEPT

    -- Handle ALL or DISTINCT modifier
    if self:is_keyword("ALL") or self:is_keyword("DISTINCT") then
      self:advance()
    end

    -- Expect SELECT
    if not self:is_keyword("SELECT") then
      break
    end
    self:advance()  -- consume SELECT

    -- Skip SELECT list until FROM (handle nested parens for expressions)
    local select_paren_depth = 0
    while self:current() do
      if self:is_type("paren_open") then
        select_paren_depth = select_paren_depth + 1
      elseif self:is_type("paren_close") then
        if select_paren_depth > 0 then
          select_paren_depth = select_paren_depth - 1
        else
          break  -- End of subquery
        end
      elseif select_paren_depth == 0 and self:is_keyword("FROM") then
        break  -- Found FROM clause
      end
      self:advance()
    end

    -- Parse FROM clause if found (no position tracking for subqueries)
    if self:is_keyword("FROM") then
      local union_tables = self:parse_from_clause(known_ctes, paren_depth, subquery.subqueries, nil)
      for _, tbl in ipairs(union_tables) do
        table.insert(subquery.tables, tbl)
      end
    end
  end

  -- Parse nested subqueries (look for "( SELECT") while tracking paren depth
  -- This scans remaining tokens in this subquery for nested subqueries in WHERE, CASE, etc.
  -- We track paren depth to know when we've exited this subquery's scope
  local scan_depth = 0
  while self:current() do
    if self:is_type("paren_open") then
      scan_depth = scan_depth + 1
      self:advance()
      if self:is_keyword("SELECT") then
        local nested = self:parse_subquery(known_ctes)
        if nested then
          table.insert(subquery.subqueries, nested)
        end
        -- After parse_subquery, we should be at or past the closing ) of that nested subquery
        -- Decrement depth since we consumed that subquery
        scan_depth = scan_depth - 1
      end
    elseif self:is_type("paren_close") then
      if scan_depth <= 0 then
        -- This is the closing ) of the current subquery - don't consume it
        break
      end
      scan_depth = scan_depth - 1
      self:advance()
    else
      self:advance()
    end
  end

  -- Record end position
  local end_token = self:current()
  if end_token then
    subquery.end_pos = { line = end_token.line, col = end_token.col }
  end

  -- Build alias mapping for this subquery
  local subquery_aliases = {}
  for _, table_ref in ipairs(subquery.tables) do
    if table_ref.alias then
      subquery_aliases[table_ref.alias:lower()] = table_ref
    end
  end

  -- Resolve parent_table for columns using aliases
  resolve_column_parents(subquery.columns, subquery_aliases, subquery.tables)

  -- Post-parse parameter extraction: scan all tokens in subquery for @ symbols
  local end_token_idx = self.pos - 1
  if end_token_idx >= start_token_idx then
    self:extract_all_parameters_from_tokens(start_token_idx, end_token_idx, subquery.parameters)
  end

  return subquery
end

---Parse a WITH (CTE) clause
---@return CTEInfo[], table<string, boolean>
function ParserState:parse_with_clause()
  local ctes = {}
  local cte_names = {}

  -- Skip WITH keyword
  self:advance()

  -- Skip optional RECURSIVE keyword (PostgreSQL syntax)
  -- Note: RECURSIVE may be tokenized as identifier, not keyword
  local token = self:current()
  if token and token.text:upper() == "RECURSIVE" then
    self:advance()
  end

  while self:current() do
    -- Parse CTE name
    -- CTE names can be identifiers, bracket_ids, or keywords (since keywords can be valid CTE names)
    local cte_name_token = self:current()
    if not cte_name_token or (cte_name_token.type ~= "identifier" and cte_name_token.type ~= "bracket_id" and cte_name_token.type ~= "keyword") then
      break
    end
    -- Skip actual SQL keywords that wouldn't be valid CTE names
    local upper_text = cte_name_token.text:upper()
    if upper_text == "SELECT" or upper_text == "INSERT" or upper_text == "UPDATE" or
       upper_text == "DELETE" or upper_text == "FROM" or upper_text == "WHERE" then
      break
    end

    local cte_name = strip_brackets(cte_name_token.text)
    self:advance()

    -- Parse optional column list: WITH cte (col1, col2) AS (...)
    local column_list = {}
    if self:is_type("paren_open") then
      self:advance()
      -- Parse column names
      while self:current() do
        local col_token = self:current()
        if col_token.type == "paren_close" then
          self:advance()
          break
        elseif col_token.type == "comma" then
          self:advance()
        elseif col_token.type == "identifier" or col_token.type == "bracket_id" then
          table.insert(column_list, strip_brackets(col_token.text))
          self:advance()
        else
          self:advance()
        end
      end
    end

    -- Expect AS
    if not self:consume_keyword("AS") then
      break
    end

    -- Expect (
    if not self:is_type("paren_open") then
      break
    end
    self:advance()

    -- Parse CTE query
    local cte = {
      name = cte_name,
      columns = {},
      tables = {},
      subqueries = {},
      parameters = {},
    }

    -- Register CTE name BEFORE parsing body so recursive self-references are filtered
    cte_names[cte_name] = true

    if self:is_keyword("SELECT") then
      local subquery = self:parse_subquery(cte_names)
      if subquery then
        if #column_list == 0 then
          -- No explicit column list - use subquery columns directly
          cte.columns = subquery.columns
        else
          -- Convert explicit column list to ColumnInfo array
          for i, col_name in ipairs(column_list) do
            local col_info = {
              name = col_name,
              source_table = nil,
              parent_table = nil,
              parent_schema = nil,
              is_star = false,
            }
            -- If subquery has matching column, inherit parent info
            if subquery.columns and subquery.columns[i] then
              col_info.parent_table = subquery.columns[i].parent_table
              col_info.parent_schema = subquery.columns[i].parent_schema
              col_info.source_table = subquery.columns[i].source_table
            end
            table.insert(cte.columns, col_info)
          end
        end
        cte.tables = subquery.tables
        cte.subqueries = subquery.subqueries
        cte.parameters = subquery.parameters
      end
    elseif #column_list > 0 then
      -- No SELECT subquery but we have explicit column list - convert to ColumnInfo
      for _, col_name in ipairs(column_list) do
        table.insert(cte.columns, {
          name = col_name,
          source_table = nil,
          parent_table = nil,
          parent_schema = nil,
          is_star = false,
        })
      end
    end

    -- Expect )
    if self:is_type("paren_close") then
      self:advance()
    end

    table.insert(ctes, cte)

    -- Check for comma (multiple CTEs)
    if self:is_type("comma") then
      self:advance()
    else
      break
    end
  end

  return ctes, cte_names
end

---Parse a single statement chunk
---@param known_ctes table<string, boolean>
---@param temp_tables table<string, TempTableInfo>
---@return StatementChunk?
function ParserState:parse_statement(known_ctes, temp_tables)
  local start_token = self:current()
  if not start_token then
    return nil
  end

  -- Track token range for parameter extraction
  local start_token_idx = self.pos

  local chunk = {
    statement_type = "OTHER",
    tables = {},
    aliases = {},
    columns = nil,
    subqueries = {},
    ctes = {},
    parameters = {},
    temp_table_name = nil,
    is_global_temp = nil,
    start_line = start_token.line,
    end_line = start_token.line,
    start_col = start_token.col,
    end_col = start_token.col,
    go_batch_index = self.go_batch_index,
    clause_positions = {},
  }

  local paren_depth = 0
  local in_select = false
  local in_from = false
  local in_insert = false

  -- Check for WITH clause
  if self:is_keyword("WITH") then
    chunk.statement_type = "WITH"
    local ctes, cte_names_map = self:parse_with_clause()
    chunk.ctes = ctes

    -- Merge CTE names into known_ctes
    for name, _ in pairs(cte_names_map) do
      known_ctes[name] = true
    end
  end

  -- Detect statement type
  if self:is_keyword("SELECT") then
    chunk.statement_type = "SELECT"
    in_select = true
    local select_token = self:current()
    self:advance()

    -- Parse SELECT list
    local select_clause_pos
    chunk.columns, select_clause_pos = self:parse_select_columns(paren_depth, known_ctes, chunk.subqueries, select_token)
    if select_clause_pos then
      chunk.clause_positions["select"] = select_clause_pos
    end

    -- Check for INTO
    if self:is_keyword("INTO") then
      -- Don't change statement_type, keep as "SELECT"
      -- The temp_table_name field indicates this is SELECT INTO
      local into_token = self:current()
      self:advance()

      local qualified = self:parse_qualified_identifier()
      if qualified then
        -- Build full qualified name for temp_table_name
        local full_name = qualified.name
        if qualified.schema then
          full_name = qualified.schema .. "." .. full_name
        end
        if qualified.database then
          full_name = qualified.database .. "." .. full_name
        end
        chunk.temp_table_name = full_name
        chunk.is_global_temp = is_global_temp_table(qualified.name)

        -- Store temp table info
        if is_temp_table(qualified.name) and chunk.columns then
          temp_tables[qualified.name] = {
            name = qualified.name,
            columns = chunk.columns,
            created_in_batch = self.go_batch_index,
            is_global = is_global_temp_table(qualified.name),
          }
        end
      end

      -- Track INTO clause position
      local last_token = self.pos > 1 and self.tokens[self.pos - 1] or into_token
      chunk.clause_positions["into"] = {
        start_line = into_token.line,
        start_col = into_token.col,
        end_line = last_token.line,
        end_col = last_token.col + #last_token.text - 1,
      }
    end

    -- Parse FROM clause
    if self:is_keyword("FROM") then
      in_from = true
      local from_token = self:current()
      local from_clause_pos, join_positions, on_positions
      chunk.tables, from_clause_pos, join_positions, on_positions = self:parse_from_clause(known_ctes, paren_depth, chunk.subqueries, from_token)
      if from_clause_pos then
        chunk.clause_positions["from"] = from_clause_pos
      end

      -- Store individual JOIN positions
      if join_positions then
        for i, pos in ipairs(join_positions) do
          chunk.clause_positions["join_" .. i] = pos
        end
      end

      -- Store individual ON positions
      if on_positions then
        for i, pos in ipairs(on_positions) do
          chunk.clause_positions["on_" .. i] = pos
        end
      end
    end
  elseif self:is_keyword("INSERT") then
    chunk.statement_type = "INSERT"
    in_insert = true
    self:advance()

    -- Extract INSERT INTO table
    if self:is_keyword("INTO") then
      local into_token = self:current()
      self:advance()
      local table_ref = self:parse_table_reference(known_ctes)
      if table_ref then
        table.insert(chunk.tables, table_ref)
      end

      -- Track INTO clause position
      local last_token = self.pos > 1 and self.tokens[self.pos - 1] or into_token
      chunk.clause_positions["into"] = {
        start_line = into_token.line,
        start_col = into_token.col,
        end_line = last_token.line,
        end_col = last_token.col + #last_token.text - 1,
      }
    end

    -- Parse INSERT column list if present: INSERT INTO table (col1, col2, ...)
    if self:is_type("paren_open") then
      local col_start = self:current()
      local insert_columns = {}
      local last_token = col_start
      self:advance()  -- consume (

      while self:current() and not self:is_type("paren_close") do
        local tok = self:current()
        if tok.type == "identifier" or tok.type == "bracket_id" then
          -- Extract column name (strip brackets if needed)
          local col_name = tok.text
          if tok.type == "bracket_id" then
            col_name = col_name:match("^%[(.-)%]$") or col_name
          end
          table.insert(insert_columns, col_name)
        end
        last_token = tok
        self:advance()
      end

      if self:is_type("paren_close") then
        local col_end = self:current()

        -- Track column list position for context detection
        chunk.clause_positions["insert_columns"] = {
          start_line = col_start.line,
          start_col = col_start.col,
          end_line = col_end.line,
          end_col = col_end.col,
        }

        -- Store parsed columns (useful for validation/hints)
        chunk.insert_columns = insert_columns

        self:advance()  -- consume )
      else
        -- Incomplete column list (no closing paren yet)
        -- Still track position for context detection during typing
        -- Use a very high end position to include cursor after last token
        chunk.clause_positions["insert_columns"] = {
          start_line = col_start.line,
          start_col = col_start.col,
          end_line = last_token.line,
          end_col = last_token.col + #last_token.text + 1000,  -- Include cursor position
        }
        chunk.insert_columns = insert_columns
      end
    end

    -- Continue to find SELECT or VALUES for INSERT...SELECT
    while self:current() and not self:is_keyword("SELECT") and not self:is_keyword("VALUES") do
      self:advance()
    end

    -- Parse VALUES clause if present: INSERT INTO table (...) VALUES (...)
    if self:is_keyword("VALUES") then
      local values_token = self:current()
      self:advance()  -- consume VALUES

      -- VALUES can have multiple row sets: VALUES (...), (...)
      local first_values_paren = nil
      local last_values_token = values_token

      while self:current() do
        if self:is_type("paren_open") then
          if not first_values_paren then
            first_values_paren = self:current()
          end

          -- Skip this VALUES row
          local paren_depth_values = 1
          self:advance()  -- consume (

          while self:current() and paren_depth_values > 0 do
            if self:is_type("paren_open") then
              paren_depth_values = paren_depth_values + 1
            elseif self:is_type("paren_close") then
              paren_depth_values = paren_depth_values - 1
            end
            last_values_token = self:current()
            self:advance()
          end
        elseif self:is_type("comma") then
          -- Multi-row VALUES: VALUES (...), (...)
          self:advance()
        else
          break  -- Not part of VALUES clause
        end
      end

      -- Track VALUES clause position (from VALUES keyword to last closing paren)
      if first_values_paren then
        chunk.clause_positions["values"] = {
          start_line = values_token.line,
          start_col = values_token.col,
          end_line = last_values_token.line,
          end_col = last_values_token.col + #last_values_token.text - 1,
        }
      end

      -- Reset in_insert flag (VALUES ends the INSERT, next SELECT is new statement)
      in_insert = false
    end

    -- If INSERT...SELECT, parse the SELECT
    if self:is_keyword("SELECT") then
      in_select = true
      local select_token = self:current()
      self:advance()

      local select_clause_pos
      chunk.columns, select_clause_pos = self:parse_select_columns(paren_depth, known_ctes, chunk.subqueries, select_token)
      if select_clause_pos then
        chunk.clause_positions["select"] = select_clause_pos
      end

      if self:is_keyword("FROM") then
        in_from = true
        local from_token = self:current()
        -- Add FROM clause tables to existing tables (preserve INSERT target)
        local from_tables, from_clause_pos, join_positions, on_positions = self:parse_from_clause(known_ctes, paren_depth, chunk.subqueries, from_token)
        for _, t in ipairs(from_tables) do
          table.insert(chunk.tables, t)
        end
        if from_clause_pos then
          chunk.clause_positions["from"] = from_clause_pos
        end

        -- Store individual JOIN positions
        if join_positions then
          for i, pos in ipairs(join_positions) do
            chunk.clause_positions["join_" .. i] = pos
          end
        end

        -- Store individual ON positions
        if on_positions then
          for i, pos in ipairs(on_positions) do
            chunk.clause_positions["on_" .. i] = pos
          end
        end
      end
    end
  elseif self:is_keyword("UPDATE") then
    chunk.statement_type = "UPDATE"
    self:advance()

    -- Handle UPDATE TOP (n) clause
    if self:is_keyword("TOP") then
      self:advance()  -- consume TOP
      -- Skip the (n) or (n) PERCENT
      if self:is_type("paren_open") then
        local top_depth = 1
        self:advance()
        while self:current() and top_depth > 0 do
          if self:is_type("paren_open") then
            top_depth = top_depth + 1
          elseif self:is_type("paren_close") then
            top_depth = top_depth - 1
          end
          self:advance()
        end
      end
      -- Skip optional PERCENT keyword
      if self:is_keyword("PERCENT") then
        self:advance()
      end
    end

    -- Extract UPDATE target (could be table in simple UPDATE, or alias in extended UPDATE with FROM)
    -- We'll hold onto it temporarily and only add it if there's no FROM clause
    local update_target = self:parse_table_reference(known_ctes)
    chunk.update_target = update_target
  elseif self:is_keyword("DELETE") then
    chunk.statement_type = "DELETE"
    self:advance()

    -- Handle DELETE TOP (n) clause
    if self:is_keyword("TOP") then
      self:advance()  -- consume TOP
      -- Skip the (n) or (n) PERCENT
      if self:is_type("paren_open") then
        local top_depth = 1
        self:advance()
        while self:current() and top_depth > 0 do
          if self:is_type("paren_open") then
            top_depth = top_depth + 1
          elseif self:is_type("paren_close") then
            top_depth = top_depth - 1
          end
          self:advance()
        end
      end
      -- Skip optional PERCENT keyword
      if self:is_keyword("PERCENT") then
        self:advance()
      end
    end

    -- Handle DELETE syntax variants:
    -- 1. DELETE FROM table WHERE ... (simple)
    -- 2. DELETE alias FROM table alias WHERE ... (extended with alias)
    -- 3. DELETE table FROM table alias WHERE ... (table name as target)
    if self:is_keyword("FROM") then
      -- Simple DELETE FROM table
      self:advance()
      local table_ref = self:parse_table_reference(known_ctes)
      if table_ref then
        table.insert(chunk.tables, table_ref)
      end
    elseif self:current() and self:current().type == "identifier" then
      -- Extended DELETE: DELETE alias/table FROM table alias
      -- Parse the delete target (could be alias or table name)
      local delete_target = self:parse_table_reference(known_ctes)
      chunk.delete_target = delete_target
      -- The FROM clause will be parsed later in the main loop (like UPDATE)
    end
  elseif self:is_keyword("MERGE") then
    chunk.statement_type = "MERGE"
    self:advance()  -- consume MERGE

    -- Parse MERGE INTO target_table [AS alias]
    if self:is_keyword("INTO") then
      self:advance()
      local target = self:parse_table_reference(known_ctes)
      if target then
        table.insert(chunk.tables, target)
      end
    end

    -- Parse USING source (table or subquery)
    if self:is_keyword("USING") then
      self:advance()

      -- Check for subquery: USING (SELECT ...)
      if self:is_type("paren_open") then
        self:advance()  -- consume (
        if self:is_keyword("SELECT") then
          local subquery = self:parse_subquery(known_ctes)
          if subquery then
            if self:is_type("paren_close") then
              self:advance()
              subquery.alias = self:parse_alias()
            end
            table.insert(chunk.subqueries, subquery)
          end
        else
          -- Skip non-SELECT content (VALUES, etc.)
          local pd = 1
          while self:current() and pd > 0 do
            if self:is_type("paren_open") then pd = pd + 1
            elseif self:is_type("paren_close") then pd = pd - 1
            end
            self:advance()
          end
          self:parse_alias()
        end
      else
        -- Simple table reference: USING SourceTable s
        local source = self:parse_table_reference(known_ctes)
        if source then
          table.insert(chunk.tables, source)
        end
      end
    end

    -- Skip rest of MERGE (ON condition, WHEN clauses with UPDATE/DELETE/INSERT)
    local merge_depth = 0
    while self:current() do
      local tok = self:current()
      if not tok then break end

      local upper = tok.text:upper()

      if self:is_type("paren_open") then
        merge_depth = merge_depth + 1
      elseif self:is_type("paren_close") then
        merge_depth = merge_depth - 1
      end

      if merge_depth == 0 then
        if tok.type == "semicolon" or upper == "GO" then
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

      self:advance()
    end
  elseif self:is_keyword("EXEC") or self:is_keyword("EXECUTE") then
    chunk.statement_type = "EXEC"
    self:advance()
  elseif self:is_keyword("TRUNCATE") then
    chunk.statement_type = "TRUNCATE"
    self:advance()
    -- Skip TABLE keyword
    if self:is_keyword("TABLE") then
      self:advance()
    end
    -- Extract table name
    local table_ref = self:parse_table_reference(known_ctes)
    if table_ref then
      table.insert(chunk.tables, table_ref)
    end
  elseif self:is_keyword("DECLARE") then
    chunk.statement_type = "DECLARE"
    self:advance()

    -- Check for table variable declaration: DECLARE @var TABLE (col1 type, ...)
    -- Note: Tokenizer splits @var into two tokens: @ (type=at) and var (type=identifier)
    local token = self:current()
    local var_name = nil
    if token and token.type == "at" then
      self:advance()  -- consume @
      local name_token = self:current()
      if name_token and name_token.type == "identifier" then
        var_name = "@" .. name_token.text
        self:advance()  -- consume variable name
      end
    end

    -- Check for TABLE keyword (only if we found a valid variable name)
    if var_name and self:is_keyword("TABLE") then
        self:advance()  -- consume TABLE

        -- Check for column definitions: DECLARE @var TABLE (col1 type, col2 type, ...)
        if self:is_type("paren_open") then
          self:advance()  -- consume (
          local var_columns = {}

          while self:current() and not self:is_type("paren_close") do
            local col_token = self:current()

            -- Skip keywords like PRIMARY, KEY, CONSTRAINT, etc. that define constraints
            if col_token.type == "keyword" then
              local kw = col_token.text:upper()
              if kw == "PRIMARY" or kw == "FOREIGN" or kw == "UNIQUE" or
                 kw == "CHECK" or kw == "CONSTRAINT" or kw == "INDEX" or
                 kw == "CLUSTERED" or kw == "NONCLUSTERED" then
                -- Skip constraint definition until comma or closing paren
                while self:current() and not self:is_type("comma") and not self:is_type("paren_close") do
                  if self:is_type("paren_open") then
                    local pd = 1
                    self:advance()
                    while self:current() and pd > 0 do
                      if self:is_type("paren_open") then pd = pd + 1
                      elseif self:is_type("paren_close") then pd = pd - 1
                      end
                      self:advance()
                    end
                  else
                    self:advance()
                  end
                end
                if self:is_type("comma") then
                  self:advance()
                end
                goto continue_var_col
              end
            end

            -- Parse column name
            if col_token.type == "identifier" or col_token.type == "bracket_id" then
              local col_name = strip_brackets(col_token.text)
              self:advance()

              -- Parse data type
              local data_type = nil
              local type_token = self:current()
              if type_token and (type_token.type == "keyword" or type_token.type == "identifier") then
                data_type = type_token.text:upper()
                self:advance()

                -- Handle parameterized types like VARCHAR(50), DECIMAL(10,2)
                if self:is_type("paren_open") then
                  self:advance()  -- consume (
                  local type_pd = 1
                  while self:current() and type_pd > 0 do
                    if self:is_type("paren_open") then type_pd = type_pd + 1
                    elseif self:is_type("paren_close") then type_pd = type_pd - 1
                    end
                    self:advance()
                  end
                end
              end

              -- Add column to list
              table.insert(var_columns, {
                name = col_name,
                data_type = data_type,
                is_star = false,
              })

              -- Skip remaining column modifiers (NULL, NOT NULL, DEFAULT, IDENTITY, etc.)
              while self:current() and not self:is_type("comma") and not self:is_type("paren_close") do
                if self:is_type("paren_open") then
                  local mod_pd = 1
                  self:advance()
                  while self:current() and mod_pd > 0 do
                    if self:is_type("paren_open") then mod_pd = mod_pd + 1
                    elseif self:is_type("paren_close") then mod_pd = mod_pd - 1
                    end
                    self:advance()
                  end
                else
                  self:advance()
                end
              end

              -- Skip comma if present
              if self:is_type("comma") then
                self:advance()
              end
            else
              -- Unknown token, skip it
              self:advance()
            end

            ::continue_var_col::
          end

          -- Consume closing paren
          if self:is_type("paren_close") then
            self:advance()
          end

          -- Store table variable info
          if #var_columns > 0 then
            temp_tables[var_name] = {
              name = var_name,
              columns = var_columns,
              created_in_batch = self.go_batch_index,
              is_table_variable = true,
            }
          end
        end
    end

    self:consume_until_statement_end()
  elseif self:is_keyword("SET") then
    chunk.statement_type = "SET"
    self:advance()
    self:consume_until_statement_end()
  elseif self:is_keyword("CREATE") then
    chunk.statement_type = "CREATE"
    self:advance()

    -- Check for CREATE TABLE
    if self:is_keyword("TABLE") then
      self:advance()  -- consume TABLE

      -- Parse table name (could be temp table #name or ##name)
      local qualified = self:parse_qualified_identifier()
      if qualified and is_temp_table(qualified.name) then
        chunk.temp_table_name = qualified.name
        chunk.is_global_temp = is_global_temp_table(qualified.name)

        -- Check for column definitions: CREATE TABLE #temp (col1 type, col2 type, ...)
        if self:is_type("paren_open") then
          self:advance()  -- consume (
          local temp_columns = {}

          while self:current() and not self:is_type("paren_close") do
            local token = self:current()

            -- Skip keywords like PRIMARY, KEY, CONSTRAINT, etc. that define constraints
            if token.type == "keyword" then
              local kw = token.text:upper()
              if kw == "PRIMARY" or kw == "FOREIGN" or kw == "UNIQUE" or
                 kw == "CHECK" or kw == "CONSTRAINT" or kw == "INDEX" or
                 kw == "CLUSTERED" or kw == "NONCLUSTERED" then
                -- Skip constraint definition until comma or closing paren
                while self:current() and not self:is_type("comma") and not self:is_type("paren_close") do
                  if self:is_type("paren_open") then
                    -- Skip parenthesized content (column list, etc.)
                    local pd = 1
                    self:advance()
                    while self:current() and pd > 0 do
                      if self:is_type("paren_open") then pd = pd + 1
                      elseif self:is_type("paren_close") then pd = pd - 1
                      end
                      self:advance()
                    end
                  else
                    self:advance()
                  end
                end
                -- Skip comma if present
                if self:is_type("comma") then
                  self:advance()
                end
                goto continue_create_col
              end
            end

            -- Parse column name
            if token.type == "identifier" or token.type == "bracket_id" then
              local col_name = strip_brackets(token.text)
              self:advance()

              -- Parse data type (next token should be type keyword or identifier)
              local data_type = nil
              local type_token = self:current()
              if type_token and (type_token.type == "keyword" or type_token.type == "identifier") then
                data_type = type_token.text:upper()
                self:advance()

                -- Handle parameterized types like VARCHAR(50), DECIMAL(10,2)
                if self:is_type("paren_open") then
                  self:advance()  -- consume (
                  -- Skip until closing paren
                  local type_pd = 1
                  while self:current() and type_pd > 0 do
                    if self:is_type("paren_open") then type_pd = type_pd + 1
                    elseif self:is_type("paren_close") then type_pd = type_pd - 1
                    end
                    self:advance()
                  end
                end
              end

              -- Add column to list
              table.insert(temp_columns, {
                name = col_name,
                data_type = data_type,
                is_star = false,
              })

              -- Skip remaining column modifiers (NULL, NOT NULL, DEFAULT, IDENTITY, etc.)
              while self:current() and not self:is_type("comma") and not self:is_type("paren_close") do
                if self:is_type("paren_open") then
                  -- Skip parenthesized content (DEFAULT value, etc.)
                  local mod_pd = 1
                  self:advance()
                  while self:current() and mod_pd > 0 do
                    if self:is_type("paren_open") then mod_pd = mod_pd + 1
                    elseif self:is_type("paren_close") then mod_pd = mod_pd - 1
                    end
                    self:advance()
                  end
                else
                  self:advance()
                end
              end

              -- Skip comma if present
              if self:is_type("comma") then
                self:advance()
              end
            else
              -- Unknown token, skip it
              self:advance()
            end

            ::continue_create_col::
          end

          -- Consume closing paren
          if self:is_type("paren_close") then
            self:advance()
          end

          -- Store temp table info with parsed columns
          if #temp_columns > 0 then
            temp_tables[qualified.name] = {
              name = qualified.name,
              columns = temp_columns,
              created_in_batch = self.go_batch_index,
              is_global = is_global_temp_table(qualified.name),
            }
          end
        end
      end
    end

    -- Consume rest of CREATE statement
    self:consume_until_statement_end()
  elseif self:is_keyword("DROP") then
    -- DROP statement - track DROP TABLE for temp tables
    chunk.statement_type = "DROP"
    self:advance() -- consume DROP

    if self:is_keyword("TABLE") then
      self:advance() -- consume TABLE

      -- Check for IF EXISTS
      if self:is_keyword("IF") then
        self:advance()
        if self:is_keyword("EXISTS") then
          self:advance()
        end
      end

      -- Parse the table name
      local drop_line = self:current() and self:current().line or start_token.line
      local qualified = self:parse_qualified_identifier()
      if qualified and is_temp_table(qualified.name) then
        -- Mark this temp table as dropped
        if temp_tables[qualified.name] then
          temp_tables[qualified.name].dropped_at_line = drop_line
        end
      end
    end

    self:consume_until_statement_end()
  elseif self:is_keyword("ALTER") then
    -- ALTER statement - track ALTER TABLE ADD for temp tables
    chunk.statement_type = "ALTER"
    self:advance() -- consume ALTER

    if self:is_keyword("TABLE") then
      self:advance() -- consume TABLE

      -- Parse the table name
      local qualified = self:parse_qualified_identifier()
      if qualified and is_temp_table(qualified.name) then
        -- Check if temp table exists
        if temp_tables[qualified.name] then
          -- Check for ADD keyword
          if self:is_keyword("ADD") then
            self:advance() -- consume ADD

            -- Parse new column definition(s)
            while self:current() do
              local token = self:current()

              -- Stop at statement terminators
              if token.type == "semicolon" or token.type == "go" or
                 (token.type == "keyword" and
                  (token.text:upper() == "GO" or token.text:upper() == "SELECT" or
                   token.text:upper() == "INSERT" or token.text:upper() == "UPDATE" or
                   token.text:upper() == "DELETE" or token.text:upper() == "CREATE" or
                   token.text:upper() == "DROP" or token.text:upper() == "ALTER")) then
                break
              end

              -- Skip CONSTRAINT keyword and constraint definitions
              if token.type == "keyword" then
                local kw = token.text:upper()
                if kw == "CONSTRAINT" or kw == "PRIMARY" or kw == "FOREIGN" or
                   kw == "UNIQUE" or kw == "CHECK" or kw == "DEFAULT" or kw == "INDEX" then
                  -- Skip until next comma or end of statement
                  while self:current() and not self:is_type("comma") do
                    local t = self:current()
                    if t.type == "semicolon" or t.type == "go" then break end
                    if self:is_type("paren_open") then
                      -- Skip parenthesized content
                      local pd = 1
                      self:advance()
                      while self:current() and pd > 0 do
                        if self:is_type("paren_open") then pd = pd + 1
                        elseif self:is_type("paren_close") then pd = pd - 1
                        end
                        self:advance()
                      end
                    else
                      self:advance()
                    end
                  end
                  -- Skip comma if present
                  if self:is_type("comma") then
                    self:advance()
                  end
                  goto continue_alter_col
                end
              end

              -- Parse column name
              if token.type == "identifier" or token.type == "bracket_id" then
                local col_name = strip_brackets(token.text)
                self:advance()

                -- Parse data type
                local data_type = nil
                local type_token = self:current()
                if type_token and (type_token.type == "keyword" or type_token.type == "identifier") then
                  data_type = type_token.text:upper()
                  self:advance()

                  -- Handle parameterized types like VARCHAR(50)
                  if self:is_type("paren_open") then
                    self:advance()
                    local type_pd = 1
                    while self:current() and type_pd > 0 do
                      if self:is_type("paren_open") then type_pd = type_pd + 1
                      elseif self:is_type("paren_close") then type_pd = type_pd - 1
                      end
                      self:advance()
                    end
                  end
                end

                -- Add column to temp table
                table.insert(temp_tables[qualified.name].columns, {
                  name = col_name,
                  data_type = data_type,
                  is_star = false,
                })

                -- Skip remaining column modifiers (NULL, NOT NULL, DEFAULT, etc.)
                while self:current() and not self:is_type("comma") do
                  local t = self:current()
                  if t.type == "semicolon" or t.type == "go" then break end
                  if t.type == "keyword" then
                    local kw = t.text:upper()
                    if kw == "SELECT" or kw == "INSERT" or kw == "UPDATE" or
                       kw == "DELETE" or kw == "CREATE" or kw == "DROP" or kw == "ALTER" then
                      break
                    end
                  end
                  if self:is_type("paren_open") then
                    local mod_pd = 1
                    self:advance()
                    while self:current() and mod_pd > 0 do
                      if self:is_type("paren_open") then mod_pd = mod_pd + 1
                      elseif self:is_type("paren_close") then mod_pd = mod_pd - 1
                      end
                      self:advance()
                    end
                  else
                    self:advance()
                  end
                end

                -- Skip comma if present (for multiple columns)
                if self:is_type("comma") then
                  self:advance()
                end
              else
                -- Unknown token, skip it
                self:advance()
              end

              ::continue_alter_col::
            end
          end
        end
      end
    end

    self:consume_until_statement_end()
  else
    -- OTHER statement type
    self:advance()
    self:consume_until_statement_end()
  end

  -- Build alias mapping
  for _, table_ref in ipairs(chunk.tables) do
    if table_ref.alias then
      chunk.aliases[table_ref.alias:lower()] = table_ref
    end
  end

  -- Resolve parent_table for columns using aliases
  resolve_column_parents(chunk.columns, chunk.aliases, chunk.tables)

  -- Find subqueries in the rest of the statement
  -- Track the last token that belongs to this statement for end position
  -- Initialize to previous token (what we last consumed before this loop)
  local last_statement_token = self.pos > 1 and self.tokens[self.pos - 1] or start_token

  -- Track clause start positions
  local where_start = nil
  local group_by_start = nil
  local having_start = nil
  local order_by_start = nil
  local set_start = nil

  while self:current() do
    local token = self:current()

    -- Check for GO batch separator (can be "go" type or identifier "GO")
    if token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      break
    end

    -- Check for new statement starting
    local upper_text = token.text:upper()

    -- Track clause positions at paren_depth 0
    if paren_depth == 0 then
      if upper_text == "WHERE" and not where_start then
        where_start = token
      elseif upper_text == "GROUP" then
        -- Check if next is BY
        local next_tok = self:peek(1)
        if next_tok and next_tok.text:upper() == "BY" and not group_by_start then
          group_by_start = token
        end
      elseif upper_text == "HAVING" and not having_start then
        having_start = token
      elseif upper_text == "ORDER" then
        -- Check if next is BY
        local next_tok = self:peek(1)
        if next_tok and next_tok.text:upper() == "BY" and not order_by_start then
          order_by_start = token
        end
      elseif upper_text == "SET" and chunk.statement_type == "UPDATE" and not set_start then
        set_start = token
      end
    end

    -- UNION/INTERSECT/EXCEPT end the current SELECT statement
    -- Each SELECT in a UNION should be its own chunk for proper autocompletion scoping
    -- (you don't want tables from other UNIONed SELECTs polluting your completion context)
    if paren_depth == 0 and (upper_text == "UNION" or upper_text == "INTERSECT" or upper_text == "EXCEPT") then
      -- End this chunk - the SELECT after UNION will be parsed as a new statement
      break
    end

    -- Handle FROM clause in UPDATE statements (extended UPDATE syntax)
    if paren_depth == 0 and upper_text == "FROM" and chunk.statement_type == "UPDATE" then
      -- Extended UPDATE syntax: UPDATE alias SET ... FROM table alias
      -- Parse FROM clause to get the actual tables
      local from_token = self:current()
      local from_clause_pos, join_positions, on_positions
      chunk.tables, from_clause_pos, join_positions, on_positions = self:parse_from_clause(known_ctes, paren_depth, chunk.subqueries, from_token)
      if from_clause_pos then
        chunk.clause_positions["from"] = from_clause_pos
      end

      -- Store individual JOIN positions
      if join_positions then
        for i, pos in ipairs(join_positions) do
          chunk.clause_positions["join_" .. i] = pos
        end
      end

      -- Store individual ON positions
      if on_positions then
        for i, pos in ipairs(on_positions) do
          chunk.clause_positions["on_" .. i] = pos
        end
      end

      -- Mark that we found a FROM clause so we don't add update_target later
      chunk.has_from_clause = true
      goto continue_loop
    end

    -- Handle FROM clause in DELETE statements (extended DELETE syntax)
    if paren_depth == 0 and upper_text == "FROM" and chunk.statement_type == "DELETE" and chunk.delete_target then
      -- Extended DELETE syntax: DELETE alias FROM table alias WHERE ...
      -- Parse FROM clause to get the actual tables
      local from_token = self:current()
      local from_clause_pos, join_positions, on_positions
      chunk.tables, from_clause_pos, join_positions, on_positions = self:parse_from_clause(known_ctes, paren_depth, chunk.subqueries, from_token)
      if from_clause_pos then
        chunk.clause_positions["from"] = from_clause_pos
      end

      -- Store individual JOIN positions
      if join_positions then
        for i, pos in ipairs(join_positions) do
          chunk.clause_positions["join_" .. i] = pos
        end
      end

      -- Store individual ON positions
      if on_positions then
        for i, pos in ipairs(on_positions) do
          chunk.clause_positions["on_" .. i] = pos
        end
      end

      -- Mark that we found a FROM clause
      chunk.has_from_clause = true
      goto continue_loop
    end

    if paren_depth == 0 and is_statement_starter(token.text) then
      -- SET is part of UPDATE syntax, not a new statement
      if upper_text == "SET" and chunk.statement_type == "UPDATE" then
        -- Continue parsing UPDATE
      -- SELECT is part of INSERT ... SELECT syntax, not a new statement
      elseif upper_text == "SELECT" and in_insert then
        -- Continue parsing INSERT ... SELECT
      -- WITH can be table hints (WITH NOLOCK), not a new CTE statement
      -- Only treat WITH as new statement if NOT in a SELECT/INSERT/UPDATE/DELETE
      elseif upper_text == "WITH" and (in_select or in_insert or in_from or chunk.statement_type == "UPDATE" or chunk.statement_type == "DELETE") then
        -- Table hint WITH (NOLOCK), skip the hint
        self:advance()
        if self:is_type("paren_open") then
          -- Skip parenthesized hints like (NOLOCK, INDEX(...))
          local hint_depth = 1
          self:advance() -- consume (
          while self:current() and hint_depth > 0 do
            if self:is_type("paren_open") then
              hint_depth = hint_depth + 1
            elseif self:is_type("paren_close") then
              hint_depth = hint_depth - 1
            end
            self:advance()
          end
        end
      else
        -- New statement starting
        break
      end
    end

    -- Update last_statement_token before we advance
    last_statement_token = token

    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
      self:advance()

      -- Check for subquery
      if self:is_keyword("SELECT") then
        local subquery = self:parse_subquery(known_ctes)
        if subquery then
          -- Try to find alias after closing paren
          if self:is_type("paren_close") then
            self:advance()
            subquery.alias = self:parse_alias()
          end
          table.insert(chunk.subqueries, subquery)
          -- Update last_statement_token to reflect tokens consumed by subquery
          last_statement_token = self.pos > 1 and self.tokens[self.pos - 1] or last_statement_token
        end
      end
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
      self:advance()
    else
      self:advance()
    end

    ::continue_loop::
  end

  -- For UPDATE statements: if no FROM clause was found, the update_target is the actual table
  if chunk.statement_type == "UPDATE" and chunk.update_target and not chunk.has_from_clause then
    table.insert(chunk.tables, chunk.update_target)
  end

  -- Record end position using the last token that was part of this statement
  if last_statement_token then
    chunk.end_line = last_statement_token.line
    chunk.end_col = last_statement_token.col + #last_statement_token.text - 1
  end

  -- Build clause positions for WHERE, GROUP BY, HAVING, ORDER BY, SET
  -- Each clause ends at the start of the next clause, or at statement end
  if where_start then
    local where_end = group_by_start or having_start or order_by_start or last_statement_token
    chunk.clause_positions["where"] = {
      start_line = where_start.line,
      start_col = where_start.col,
      end_line = where_end.line,
      end_col = (where_end == last_statement_token) and (where_end.col + #where_end.text - 1) or (where_end.col - 1),
    }
  end

  if group_by_start then
    local group_by_end = having_start or order_by_start or last_statement_token
    chunk.clause_positions["group_by"] = {
      start_line = group_by_start.line,
      start_col = group_by_start.col,
      end_line = group_by_end.line,
      end_col = (group_by_end == last_statement_token) and (group_by_end.col + #group_by_end.text - 1) or (group_by_end.col - 1),
    }
  end

  if having_start then
    local having_end = order_by_start or last_statement_token
    chunk.clause_positions["having"] = {
      start_line = having_start.line,
      start_col = having_start.col,
      end_line = having_end.line,
      end_col = (having_end == last_statement_token) and (having_end.col + #having_end.text - 1) or (having_end.col - 1),
    }
  end

  if order_by_start then
    chunk.clause_positions["order_by"] = {
      start_line = order_by_start.line,
      start_col = order_by_start.col,
      end_line = last_statement_token.line,
      end_col = last_statement_token.col + #last_statement_token.text - 1,
    }
  end

  if set_start then
    local set_end = where_start or last_statement_token
    chunk.clause_positions["set"] = {
      start_line = set_start.line,
      start_col = set_start.col,
      end_line = set_end.line,
      end_col = (set_end == last_statement_token) and (set_end.col + #set_end.text - 1) or (set_end.col - 1),
    }
  end

  -- Rebuild alias mapping after all parsing (UPDATE/DELETE FROM may have added tables)
  -- This ensures aliases from FROM clause in UPDATE/DELETE statements are captured
  for _, table_ref in ipairs(chunk.tables) do
    if table_ref.alias and not chunk.aliases[table_ref.alias:lower()] then
      chunk.aliases[table_ref.alias:lower()] = table_ref
    end
  end

  -- Post-parse parameter extraction: scan all tokens in statement for @ symbols
  -- This catches parameters in SELECT clause, DECLARE/SET, subqueries, functions, CASE, etc.
  local end_token_idx = self.pos - 1
  if end_token_idx >= start_token_idx then
    self:extract_all_parameters_from_tokens(start_token_idx, end_token_idx, chunk.parameters)
  end

  return chunk
end

---Parse SQL text into statement chunks
---@param text string The SQL text to parse
---@return StatementChunk[] chunks Array of statement chunks
---@return table<string, TempTableInfo> temp_tables Temp tables found (keyed by name)
function StatementParser.parse(text)
  local Tokenizer = require('ssns.completion.tokenizer')
  local tokens = Tokenizer.tokenize(text)

  local state = ParserState.new(tokens)
  local chunks = {}
  local temp_tables = {}
  local known_ctes = {} -- Reset per statement

  while state:current() do
    local token = state:current()

    -- Handle GO batch separator (can be "go" type or identifier "GO")
    if token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      state.go_batch_index = state.go_batch_index + 1
      known_ctes = {} -- Reset CTEs after GO
      state:advance()
      goto continue
    end

    -- Skip semicolons (they don't start statements)
    if token.type == "semicolon" then
      state:advance()
      goto continue
    end

    -- Check for statement starter
    if is_statement_starter(token.text) then
      local chunk = state:parse_statement(known_ctes, temp_tables)
      if chunk then
        table.insert(chunks, chunk)
      end
    else
      -- Unknown token at statement position, skip it
      state:advance()
    end

    ::continue::
  end

  return chunks, temp_tables
end

---Find which chunk contains the given position
---Optimized: Early termination when chunks are ordered by start_line
---@param chunks StatementChunk[] The parsed chunks
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return StatementChunk? chunk The chunk at position, or nil
function StatementParser.get_chunk_at_position(chunks, line, col)
  local best_match = nil
  local best_end_line = -1

  for _, chunk in ipairs(chunks) do
    -- Quick line check: skip chunks that start after cursor line
    -- Since chunks are ordered by start_line, we can potentially stop early
    if line < chunk.start_line then
      -- If we already have a continuation match, we can stop
      -- (future chunks start even later)
      if best_match then
        break
      end
      goto continue
    end

    -- Check if cursor is within chunk line boundaries
    if line >= chunk.start_line and line <= chunk.end_line then
      -- Column bounds check only matters on boundary lines:
      -- - First line: cursor must be at or after start_col
      -- - Last line: allow tolerance for typing continuation
      -- - Middle lines: any column is valid (statement spans entire line)

      if line == chunk.start_line and col < chunk.start_col then
        goto continue
      end

      -- For completion purposes, allow cursor to be past the end_col on the last line
      -- This handles the case where user is typing at the end of a statement (e.g., "dbo.█")
      -- Allow up to 50 chars past end_col to still be considered part of this chunk
      if line == chunk.end_line and col > chunk.end_col + 50 then
        goto continue
      end

      return chunk
    end

    -- Also check if cursor is on lines AFTER chunk.end_line (within 5 lines)
    -- This handles multiline continuation like "FROM Table,\n  █" where the cursor
    -- is on a new line but still logically part of the previous statement
    if line > chunk.end_line and line <= chunk.end_line + 5 then
      -- Track the chunk that ends closest to the cursor line
      if chunk.end_line > best_end_line then
        best_end_line = chunk.end_line
        best_match = chunk
      end
    end

    ::continue::
  end

  -- Return the best match from "continuation" chunks (if no direct match was found)
  return best_match
end

---Check if position is within bounds
---@param line number
---@param col number
---@param start_pos {line: number, col: number}
---@param end_pos {line: number, col: number}
---@return boolean
local function is_position_in_bounds(line, col, start_pos, end_pos)
  if line < start_pos.line or line > end_pos.line then
    return false
  end
  if line == start_pos.line and col < start_pos.col then
    return false
  end
  if line == end_pos.line and col > end_pos.col then
    return false
  end
  return true
end

---Recursively search for subquery containing position
---@param subquery SubqueryInfo
---@param line number
---@param col number
---@return SubqueryInfo?
local function find_subquery_recursive(subquery, line, col)
  -- Check nested subqueries first (innermost wins)
  for _, nested in ipairs(subquery.subqueries) do
    if is_position_in_bounds(line, col, nested.start_pos, nested.end_pos) then
      local result = find_subquery_recursive(nested, line, col)
      if result then
        return result
      end
      return nested
    end
  end

  -- Check if position is in this subquery
  if is_position_in_bounds(line, col, subquery.start_pos, subquery.end_pos) then
    return subquery
  end

  return nil
end

---Find if position is inside a subquery (recursive search)
---@param chunk StatementChunk The chunk to search
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return SubqueryInfo? subquery The innermost subquery containing position, or nil
function StatementParser.get_subquery_at_position(chunk, line, col)
  for _, subquery in ipairs(chunk.subqueries) do
    local result = find_subquery_recursive(subquery, line, col)
    if result then
      return result
    end
  end
  return nil
end

---Get which clause the cursor is in
---Optimized: Uses end_line/end_col bounds for early filtering and tracks
---clauses starting on cursor line for potential early exit
---@param chunk StatementChunk
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? clause_name "select", "from", "where", "group_by", "having", "order_by", "set", "into", "join", "on", "values", "insert_columns", or nil
function StatementParser.get_clause_at_position(chunk, line, col)
  if not chunk or not chunk.clause_positions then
    return nil
  end

  -- Quick bounds check: if cursor is outside chunk bounds, no clause match
  if line < chunk.start_line or line > chunk.end_line then
    return nil
  end
  if line == chunk.start_line and col < chunk.start_col then
    return nil
  end

  -- Find the last clause that started before (or at) the cursor position
  -- This handles trailing spaces, newlines, and incomplete statements naturally
  -- The cursor is considered to be in a clause until a new clause starts
  local best_match = nil
  local best_start_line = -1
  local best_start_col = -1

  -- Track if we find a clause starting on the cursor line for early exit opportunity
  local found_on_cursor_line = false
  local cursor_line_clause = nil
  local cursor_line_start_col = -1

  for clause_name, pos in pairs(chunk.clause_positions) do
    -- Optimization: Skip clauses that start AFTER the cursor (they can't be the answer)
    -- This is a quick filter before doing more checks
    if pos.start_line > line or (pos.start_line == line and pos.start_col > col) then
      goto continue
    end

    -- At this point, clause started before or at cursor
    -- Check if this is the latest-starting clause we've found
    local is_later = (pos.start_line > best_start_line) or
                     (pos.start_line == best_start_line and pos.start_col > best_start_col)

    if is_later then
      best_start_line = pos.start_line
      best_start_col = pos.start_col
      best_match = clause_name

      -- Track clause on cursor line for potential early exit
      if pos.start_line == line then
        found_on_cursor_line = true
        cursor_line_clause = clause_name
        cursor_line_start_col = pos.start_col
      end
    end

    ::continue::
  end

  -- Early exit optimization: If we found a clause starting on the cursor line,
  -- and the cursor is within a reasonable distance from its start, this is likely
  -- the correct clause (no need to re-verify against all clauses)
  if found_on_cursor_line and cursor_line_clause == best_match then
    -- The best match is on the cursor line - good match
  end

  if best_match then
    -- Normalize join_N and on_N to just "join" and "on"
    if best_match:match("^join_%d+$") then
      return "join"
    elseif best_match:match("^on_%d+$") then
      return "on"
    end
    return best_match
  end

  return nil
end

return StatementParser
