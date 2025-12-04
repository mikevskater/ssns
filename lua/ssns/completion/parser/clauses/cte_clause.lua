--- CTE (WITH clause) parser module
--- Parses Common Table Expressions in WITH clauses
---
--- Handles:
--- - Simple CTEs: WITH cte AS (SELECT ...)
--- - CTEs with column lists: WITH cte (col1, col2) AS (SELECT ...)
--- - Multiple CTEs: WITH cte1 AS (...), cte2 AS (...)
--- - Recursive CTEs (RECURSIVE keyword for PostgreSQL compatibility)
---
---@module ssns.completion.parser.clauses.cte_clause

local Helpers = require('ssns.completion.parser.utils.helpers')
local ColumnListParser = require('ssns.completion.parser.utils.column_list')
local Keywords = require('ssns.completion.parser.utils.keywords')

local CteClauseParser = {}

---Parse WITH clause containing one or more CTEs
---
---@param state ParserState Token navigation state
---@param scope ScopeContext Scope context for CTE tracking
---@return CTEInfo[] ctes The parsed CTEs
---@return table<string, boolean> cte_names_map Map of CTE names (for backward compatibility)
function CteClauseParser.parse(state, scope)
  local ctes = {}
  local cte_names = {}

  -- Skip WITH keyword
  state:advance()

  -- Skip optional RECURSIVE keyword (PostgreSQL syntax)
  -- Note: RECURSIVE may be tokenized as identifier, not keyword
  local token = state:current()
  if token and token.text:upper() == "RECURSIVE" then
    state:advance()
  end

  while state:current() do
    -- Parse CTE name
    -- CTE names can be identifiers, bracket_ids, or keywords (since keywords can be valid CTE names)
    local cte_name_token = state:current()
    if not cte_name_token or (cte_name_token.type ~= "identifier" and cte_name_token.type ~= "bracket_id" and cte_name_token.type ~= "keyword") then
      break
    end

    -- Skip actual SQL keywords that wouldn't be valid CTE names
    -- This includes statement starters and clause keywords
    local upper_text = cte_name_token.text:upper()
    if Keywords.is_statement_starter(upper_text) or upper_text == "FROM" or upper_text == "WHERE" then
      break
    end

    local cte_name = Helpers.strip_brackets(cte_name_token.text)
    state:advance()

    -- Parse optional column list: WITH cte (col1, col2) AS (...)
    local column_list = ColumnListParser.parse(state)

    -- Expect AS
    if not state:consume_keyword("AS") then
      break
    end

    -- Expect (
    if not state:is_type("paren_open") then
      break
    end
    state:advance()

    -- Parse CTE query
    ---@type CTEInfo
    local cte = {
      name = cte_name,
      columns = {},
      tables = {},
      subqueries = {},
      parameters = {},
    }

    -- Register CTE name BEFORE parsing body so recursive self-references are filtered
    cte_names[cte_name] = true

    -- Also add to scope so nested queries can reference it
    if scope then
      scope:add_cte(cte_name, cte)
    end

    if state:is_keyword("SELECT") then
      -- Build known_ctes table for parse_subquery (merge local cte_names with scope ctes)
      local known_ctes_map = scope and scope:get_known_ctes_table() or {}
      for name, _ in pairs(cte_names) do
        known_ctes_map[name] = true
      end

      local subquery = state:parse_subquery(known_ctes_map)
      if subquery then
        if #column_list == 0 then
          -- No explicit column list - use subquery columns directly
          cte.columns = subquery.columns
        else
          -- Convert explicit column list to ColumnInfo array
          for i, col_name in ipairs(column_list) do
            ---@type ColumnInfo
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
    if state:is_type("paren_close") then
      state:advance()
    end

    -- Update CTE in scope with full column/table info
    if scope then
      scope:add_cte(cte_name, cte)
    end

    table.insert(ctes, cte)

    -- Check for comma (multiple CTEs)
    if state:is_type("comma") then
      state:advance()
    else
      break
    end
  end

  return ctes, cte_names
end

return CteClauseParser
