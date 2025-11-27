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
---@field start_col number 1-indexed start column
---@field end_col number 1-indexed end column
---@field go_batch_index number Which GO batch this belongs to (1-indexed)
---@field clause_positions table<string, ClausePosition>? Positions of each clause (select, from, where, etc.)

---@class TempTableInfo
---@field name string Temp table name
---@field columns ColumnInfo[] Columns in the temp table
---@field created_in_batch number GO batch index where it was created
---@field is_global boolean Whether it's a global temp table (##)

local StatementParser = {}

--- Resolve parent_table for columns using the aliases map
---@param columns ColumnInfo[]? The columns to resolve
---@param aliases table<string, TableReference> The alias mapping
---@param tables TableReference[] The tables in the FROM clause
local function resolve_column_parents(columns, aliases, tables)
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

-- Statement-starting keywords
local STATEMENT_STARTERS = {
  SELECT = true,
  INSERT = true,
  UPDATE = true,
  DELETE = true,
  MERGE = true,
  CREATE = true,
  ALTER = true,
  DROP = true,
  TRUNCATE = true,
  WITH = true,
  EXEC = true,
  EXECUTE = true,
  DECLARE = true,
  SET = true,
}

-- Keywords that indicate we're in a FROM/JOIN context
local FROM_KEYWORDS = {
  FROM = true,
  JOIN = true,
  INNER = true,
  LEFT = true,
  RIGHT = true,
  FULL = true,
  CROSS = true,
  OUTER = true,
}

-- Keywords that can appear after JOIN
local JOIN_MODIFIERS = {
  INNER = true,
  LEFT = true,
  RIGHT = true,
  FULL = true,
  CROSS = true,
  OUTER = true,
}

-- Keywords that terminate FROM/JOIN clause parsing
local FROM_TERMINATORS = {
  WHERE = true,
  GROUP = true,
  HAVING = true,
  ORDER = true,
  LIMIT = true,
  OFFSET = true,
  FETCH = true,
  FOR = true,       -- FOR UPDATE, FOR XML, etc.
  OPTION = true,    -- Query hints
}

---Check if keyword starts a new statement at statement position
---@param keyword string
---@return boolean
local function is_statement_starter(keyword)
  return STATEMENT_STARTERS[keyword:upper()] == true
end

---Check if keyword is FROM or JOIN related
---@param keyword string
---@return boolean
local function is_from_keyword(keyword)
  return FROM_KEYWORDS[keyword:upper()] == true
end

---Strip brackets from identifier
---@param text string
---@return string
local function strip_brackets(text)
  if text:sub(1, 1) == '[' and text:sub(-1) == ']' then
    return text:sub(2, -2)
  end
  return text
end

---Check if identifier is a temp table
---@param name string
---@return boolean
local function is_temp_table(name)
  return name:sub(1, 1) == '#'
end

---Check if identifier is a global temp table (##)
---@param name string
---@return boolean
local function is_global_temp_table(name)
  return name:sub(1, 2) == '##'
end

---Check if identifier is a table variable (@TableVar)
---@param name string
---@return boolean
local function is_table_variable(name)
  return name:sub(1, 1) == '@'
end

---Parser state
---@class ParserState
---@field tokens table[] Token array
---@field pos number Current token position (1-indexed)
---@field go_batch_index number Current GO batch (0-indexed)
local ParserState = {}
ParserState.__index = ParserState

---Create new parser state
---@param tokens table[]
---@return ParserState
function ParserState.new(tokens)
  return setmetatable({
    tokens = tokens,
    pos = 1,
    go_batch_index = 0,  -- 0-indexed: first batch is 0, incremented after GO
  }, ParserState)
end

---Get current token
---@return table?
function ParserState:current()
  if self.pos > #self.tokens then
    return nil
  end
  return self.tokens[self.pos]
end

---Peek ahead n tokens
---@param offset number
---@return table?
function ParserState:peek(offset)
  offset = offset or 1
  local new_pos = self.pos + offset
  if new_pos > #self.tokens then
    return nil
  end
  return self.tokens[new_pos]
end

---Advance to next token
function ParserState:advance()
  self.pos = self.pos + 1
end

---Check if current token matches type
---@param token_type string
---@return boolean
function ParserState:is_type(token_type)
  local token = self:current()
  return token and token.type == token_type
end

---Check if current token is keyword (case-insensitive)
---@param keyword string
---@return boolean
function ParserState:is_keyword(keyword)
  local token = self:current()
  return token and token.type == "keyword" and token.text:upper() == keyword:upper()
end

---Check if current token is any of the given keywords
---@param keywords string[]
---@return boolean
function ParserState:is_any_keyword(keywords)
  for _, kw in ipairs(keywords) do
    if self:is_keyword(kw) then
      return true
    end
  end
  return false
end

---Consume token if it matches keyword
---@param keyword string
---@return boolean
function ParserState:consume_keyword(keyword)
  if self:is_keyword(keyword) then
    self:advance()
    return true
  end
  return false
end

---Skip tokens until we find a keyword or reach end
---@param keyword string
function ParserState:skip_until_keyword(keyword)
  while self:current() and not self:is_keyword(keyword) do
    self:advance()
  end
end

---Consume tokens until we hit a statement terminator (for DECLARE/SET/OTHER statements)
---@param paren_depth number? Current parenthesis depth (default 0)
function ParserState:consume_until_statement_end(paren_depth)
  paren_depth = paren_depth or 0
  while self:current() do
    local token = self:current()

    -- Stop at GO batch separator
    if token.type == "go" or (token.type == "identifier" and token.text:upper() == "GO") then
      break
    end

    -- Stop at semicolon
    if token.type == "semicolon" then
      break
    end

    -- Track paren depth
    if token.type == "paren_open" then
      paren_depth = paren_depth + 1
    elseif token.type == "paren_close" then
      paren_depth = paren_depth - 1
    end

    -- Stop at new statement starter (only at paren_depth 0)
    if paren_depth == 0 and is_statement_starter(token.text) then
      break
    end

    self:advance()
  end
end

---Parse a parameter/variable (@name or @@system_var)
---@return ParameterInfo?
function ParserState:parse_parameter()
  if not self:is_type("at") then
    return nil
  end

  local at_token = self:current()
  local at_line = at_token.line
  local at_col = at_token.col
  local is_system = false

  self:advance()  -- consume first @

  -- Check for second @ (system variable like @@ROWCOUNT)
  if self:is_type("at") then
    is_system = true
    self:advance()  -- consume second @
  end

  -- Next should be identifier
  local token = self:current()
  if not token or token.type ~= "identifier" then
    return nil
  end

  local name = token.text
  local full_name = (is_system and "@@" or "@") .. name
  self:advance()

  return {
    name = name,
    full_name = full_name,
    line = at_line,
    col = at_col,
    is_system = is_system,
  }
end

---Post-parse parameter extraction from token range
---Scans all tokens in range for @ symbols and extracts parameter info
---@param start_idx number Starting token index (1-indexed, inclusive)
---@param end_idx number Ending token index (1-indexed, inclusive)
---@param target_array ParameterInfo[] Array to append parameters to
function ParserState:extract_all_parameters_from_tokens(start_idx, end_idx, target_array)
  local seen = {}
  local i = start_idx
  while i <= end_idx and i <= #self.tokens do
    local token = self.tokens[i]
    if token.type == "at" then
      -- Look at next token(s) to build parameter
      local is_system = false
      local name_idx = i + 1

      -- Check for @@ (system variable)
      if self.tokens[name_idx] and self.tokens[name_idx].type == "at" then
        is_system = true
        name_idx = name_idx + 1
      end

      -- Get parameter name
      if self.tokens[name_idx] and self.tokens[name_idx].type == "identifier" then
        local name = self.tokens[name_idx].text
        local full_name = (is_system and "@@" or "@") .. name
        local key = full_name:lower()

        -- Check if this is a table variable (in FROM/JOIN context)
        -- We need to skip @TableVar used as table references
        -- Simple heuristic: if previous token is FROM/JOIN or comma in FROM context, it's a table variable
        local is_table_ref = false
        if i > 1 then
          local prev_idx = i - 1
          -- Skip whitespace/comments backward if needed
          while prev_idx > 0 and self.tokens[prev_idx].type == "whitespace" do
            prev_idx = prev_idx - 1
          end
          if prev_idx > 0 then
            local prev = self.tokens[prev_idx]
            if prev.type == "keyword" then
              local kw = prev.text:upper()
              if kw == "FROM" or kw == "JOIN" or kw == "INTO" then
                is_table_ref = true
              end
            elseif prev.type == "comma" then
              -- Could be comma-separated FROM list, check further back
              -- This is a simple heuristic, may need refinement
              -- For now, we'll let table variables through and rely on existing logic
            end
          end
        end

        if not seen[key] and not is_table_ref then
          seen[key] = true
          table.insert(target_array, {
            name = name,
            full_name = full_name,
            is_system = is_system,
            line = token.line,
            col = token.col,
          })
        end

        i = name_idx + 1
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end
end

---Parse qualified identifier (server.db.schema.table or db.schema.table or schema.table or table)
---@return {server: string?, database: string?, schema: string?, name: string}?
function ParserState:parse_qualified_identifier()
  local parts = {}
  local prefix = ""  -- For # or ## temp table prefixes, or @ for table variables

  -- Check for temp table prefix (# or ##)
  if self:is_type("hash") then
    prefix = "#"
    self:advance()
    -- Check for second # (global temp table)
    if self:is_type("hash") then
      prefix = "##"
      self:advance()
    end
  -- Check for table variable prefix (@)
  elseif self:is_type("at") then
    prefix = "@"
    self:advance()
  end

  -- Read first part
  local token = self:current()
  if not token then
    return nil
  end

  if token.type == "identifier" or token.type == "bracket_id" then
    local name = strip_brackets(token.text)
    -- Prepend prefix if present (temp table or table variable)
    if prefix ~= "" then
      name = prefix .. name
    end
    table.insert(parts, name)
    self:advance()
  else
    -- If we consumed a prefix but no identifier follows, return nil
    if prefix ~= "" then
      return nil
    end
    return nil
  end

  -- Read additional parts separated by dots
  while self:is_type("dot") do
    self:advance()
    token = self:current()
    if token and (token.type == "identifier" or token.type == "bracket_id") then
      table.insert(parts, strip_brackets(token.text))
      self:advance()
    else
      break
    end
  end

  -- Map parts to server.database.schema.name
  if #parts == 1 then
    return { server = nil, database = nil, schema = nil, name = parts[1] }
  elseif #parts == 2 then
    return { server = nil, database = nil, schema = parts[1], name = parts[2] }
  elseif #parts == 3 then
    return { server = nil, database = parts[1], schema = parts[2], name = parts[3] }
  elseif #parts == 4 then
    return { server = parts[1], database = parts[2], schema = parts[3], name = parts[4] }
  else
    -- More than 4 parts - use last 4
    local n = #parts
    return { server = parts[n-3], database = parts[n-2], schema = parts[n-1], name = parts[n] }
  end
end

---Try to parse an alias (AS alias or just alias)
---@return string?
function ParserState:parse_alias()
  -- Check for AS keyword
  local has_as = self:consume_keyword("AS")

  -- Next token should be identifier (but not GO batch separator)
  local token = self:current()
  if token and (token.type == "identifier" or token.type == "bracket_id") then
    -- Don't treat GO as an alias
    if token.text:upper() == "GO" then
      return nil
    end
    local alias = strip_brackets(token.text)
    self:advance()
    return alias
  end

  return nil
end

---Parse a table reference with optional alias
---@param known_ctes table<string, boolean>
---@return TableReference?
function ParserState:parse_table_reference(known_ctes)
  local qualified = self:parse_qualified_identifier()
  if not qualified then
    return nil
  end

  local alias = self:parse_alias()

  -- Handle table hints: WITH (NOLOCK, READPAST, etc.)
  -- SQL Server allows hints between table name and alias
  if not alias and self:is_keyword("WITH") then
    self:advance()  -- consume WITH
    if self:is_type("paren_open") then
      local hint_depth = 1
      self:advance()  -- consume (
      while self:current() and hint_depth > 0 do
        if self:is_type("paren_open") then
          hint_depth = hint_depth + 1
        elseif self:is_type("paren_close") then
          hint_depth = hint_depth - 1
        end
        self:advance()
      end
    end
    -- Try to parse alias after the hint
    alias = self:parse_alias()
  end

  return {
    server = qualified.server,
    database = qualified.database,
    schema = qualified.schema,
    name = qualified.name,
    alias = alias,
    is_temp = is_temp_table(qualified.name),
    is_global_temp = is_global_temp_table(qualified.name),
    is_table_variable = is_table_variable(qualified.name),
    is_cte = known_ctes[qualified.name] == true,
  }
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
        if alias_token and (alias_token.type == "identifier" or alias_token.type == "bracket_id") then
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
    else
      -- Other tokens (keywords, operators, etc.) - keep parsing
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

  -- Update clause end position to the last token processed (before FROM/INTO)
  if clause_pos then
    local last_token = self.pos > 1 and self.tokens[self.pos - 1] or select_start_token
    if last_token then
      clause_pos.end_line = last_token.line
      clause_pos.end_col = last_token.col + #last_token.text - 1
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

      -- Check for subquery
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
          end
        else
          -- Table-valued function without subquery: CROSS APPLY dbo.GetOrders(e.Id) AS o
          -- Skip the function name
          self:parse_qualified_identifier()
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
        end
        -- Skip optional alias
        self:parse_alias()
        -- Don't add to tables - APPLY is handled, continue to next token
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
  }

  -- We're at SELECT keyword
  self:advance()

  local paren_depth = 0

  -- Parse SELECT list (no position tracking for subqueries)
  subquery.columns = self:parse_select_columns(paren_depth, known_ctes, subquery.subqueries, nil)

  -- Parse FROM clause (no position tracking for subqueries)
  if self:is_keyword("FROM") then
    subquery.tables = self:parse_from_clause(known_ctes, paren_depth, subquery.subqueries, nil)
  end

  -- Handle set operations (UNION, INTERSECT, EXCEPT) to capture tables from all members
  -- Also capture nested subqueries in WHERE/HAVING clauses along the way
  while self:current() do
    -- Skip until we hit UNION/INTERSECT/EXCEPT or end of subquery, parsing nested subqueries
    local set_op_paren_depth = 0
    while self:current() do
      local token = self:current()
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
            self:advance()
          end
          set_op_paren_depth = set_op_paren_depth - 1
        end
      elseif token.type == "paren_close" then
        if set_op_paren_depth == 0 then
          -- End of subquery
          break
        end
        set_op_paren_depth = set_op_paren_depth - 1
        self:advance()
      elseif set_op_paren_depth == 0 and (self:is_keyword("UNION") or self:is_keyword("INTERSECT") or self:is_keyword("EXCEPT")) then
        -- Found set operation
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
    local cte_name_token = self:current()
    if not cte_name_token or (cte_name_token.type ~= "identifier" and cte_name_token.type ~= "bracket_id") then
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
      end
    end

    -- Continue to find SELECT or VALUES for INSERT...SELECT
    while self:current() and not self:is_keyword("SELECT") and not self:is_keyword("VALUES") do
      self:advance()
    end

    -- If INSERT...VALUES, reset in_insert flag (VALUES ends the INSERT, next SELECT is new statement)
    if self:is_keyword("VALUES") then
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

    -- Extract UPDATE target (could be table in simple UPDATE, or alias in extended UPDATE with FROM)
    -- We'll hold onto it temporarily and only add it if there's no FROM clause
    local update_target = self:parse_table_reference(known_ctes)
    chunk.update_target = update_target
  elseif self:is_keyword("DELETE") then
    chunk.statement_type = "DELETE"
    self:advance()

    -- Extract DELETE FROM table
    if self:is_keyword("FROM") then
      self:advance()
      local table_ref = self:parse_table_reference(known_ctes)
      if table_ref then
        table.insert(chunk.tables, table_ref)
      end
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
    self:consume_until_statement_end()
  elseif self:is_keyword("SET") then
    chunk.statement_type = "SET"
    self:advance()
    self:consume_until_statement_end()
  else
    -- OTHER statement type (CREATE, ALTER, DROP, etc.)
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
---@param chunks StatementChunk[] The parsed chunks
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return StatementChunk? chunk The chunk at position, or nil
function StatementParser.get_chunk_at_position(chunks, line, col)
  for _, chunk in ipairs(chunks) do
    if line >= chunk.start_line and line <= chunk.end_line then
      -- Check column boundaries for first/last line
      if line == chunk.start_line and col < chunk.start_col then
        goto continue
      end
      if line == chunk.end_line and col > chunk.end_col then
        goto continue
      end
      return chunk
    end
    ::continue::
  end
  return nil
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
---@param chunk StatementChunk
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return string? clause_name "select", "from", "where", "group_by", "having", "order_by", "set", "into", "join", "on", or nil
function StatementParser.get_clause_at_position(chunk, line, col)
  if not chunk or not chunk.clause_positions then
    return nil
  end

  -- Check each clause position to find which one contains this position
  -- A position is "in" a clause if it's >= start and <= end
  for clause_name, pos in pairs(chunk.clause_positions) do
    if line > pos.start_line or (line == pos.start_line and col >= pos.start_col) then
      if line < pos.end_line or (line == pos.end_line and col <= pos.end_col) then
        -- Normalize join_N and on_N to just "join" and "on"
        if clause_name:match("^join_%d+$") then
          return "join"
        elseif clause_name:match("^on_%d+$") then
          return "on"
        end
        return clause_name
      end
    end
  end

  return nil
end

return StatementParser
