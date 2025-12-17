---SQL Server built-in function completion provider
---Provides completions for aggregate, string, date/time, mathematical, and other built-in functions
---@class FunctionsProvider
local FunctionsProvider = {}

local BaseProvider = require('ssns.completion.providers.base_provider')

-- Use BaseProvider.create_safe_wrapper for standardized error handling
FunctionsProvider.get_completions = BaseProvider.create_safe_wrapper(FunctionsProvider, "Functions", true)

---Internal implementation of function completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function FunctionsProvider._get_completions_impl(ctx)
  local FunctionsData = require('ssns.completion.data.functions')
  local Utils = require('ssns.completion.utils')
  local sql_context = ctx.sql_context
  local connection = ctx.connection

  -- Determine database type
  local db_type = "sqlserver" -- Default
  if connection and connection.server then
    db_type = connection.server:get_db_type() or "sqlserver"
  end

  -- Get all functions for the database type
  local functions = FunctionsData.get_for_database(db_type)

  -- Optionally filter by context (e.g., only aggregate functions in GROUP BY context)
  local context_hint = FunctionsProvider._get_context_hint(sql_context)
  if context_hint then
    functions = FunctionsProvider._filter_by_context(functions, context_hint)
  end

  -- Format as CompletionItems
  local items = {}
  for _, func in ipairs(functions) do
    local item = Utils.format_builtin_function(func, {
      priority = 7, -- Built-in functions priority (before keywords=9, after db objects)
    })
    table.insert(items, item)
  end

  return items
end

---Determine context hint for function filtering
---@param sql_context table SQL context from context.lua
---@return string|nil context_hint Context hint for filtering, or nil for all functions
function FunctionsProvider._get_context_hint(sql_context)
  if not sql_context then
    return nil
  end

  local mode = sql_context.mode

  -- Context-aware function suggestions
  if mode == "select" then
    -- In SELECT clause: suggest all functions
    return nil
  elseif mode == "where" then
    -- In WHERE clause: suggest comparison/logical functions
    return "where"
  elseif mode == "group_by" or mode == "having" then
    -- In GROUP BY/HAVING: prioritize aggregate functions
    return "aggregate"
  elseif mode == "order_by" then
    -- In ORDER BY: suggest ranking functions
    return "ranking"
  end

  return nil
end

---Filter functions based on context hint
---@param functions table[] All functions
---@param context_hint string Context hint
---@return table[] filtered Filtered functions
function FunctionsProvider._filter_by_context(functions, context_hint)
  if context_hint == "aggregate" then
    -- Prioritize aggregate functions but include others
    local aggregates = {}
    local others = {}
    for _, func in ipairs(functions) do
      if func.category == "aggregate" then
        table.insert(aggregates, func)
      else
        table.insert(others, func)
      end
    end
    -- Return aggregates first, then others
    vim.list_extend(aggregates, others)
    return aggregates
  elseif context_hint == "ranking" then
    -- Prioritize ranking/analytic functions
    local ranking = {}
    local others = {}
    for _, func in ipairs(functions) do
      if func.category == "ranking" or func.category == "analytic" then
        table.insert(ranking, func)
      else
        table.insert(others, func)
      end
    end
    vim.list_extend(ranking, others)
    return ranking
  end

  -- Default: return all functions
  return functions
end

---Get functions by specific category
---@param category string Category name (aggregate, string, datetime, etc.)
---@param callback function Callback(items)
function FunctionsProvider.get_by_category(category, callback)
  local success, result = pcall(function()
    local FunctionsData = require('ssns.completion.data.functions')
    local Utils = require('ssns.completion.utils')

    local functions = FunctionsData.get_by_category(category)
    local items = {}

    for _, func in ipairs(functions) do
      local item = Utils.format_builtin_function(func, { priority = 7 })
      table.insert(items, item)
    end

    return items
  end)

  vim.schedule(function()
    if success then
      callback(result or {})
    else
      callback({})
    end
  end)
end

return FunctionsProvider
