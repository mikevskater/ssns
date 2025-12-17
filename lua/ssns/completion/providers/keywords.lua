---SQL keyword completion provider
---@class KeywordsProvider
local KeywordsProvider = {}

local BaseProvider = require('ssns.completion.providers.base_provider')

-- Use BaseProvider.create_safe_wrapper for standardized error handling
KeywordsProvider.get_completions = BaseProvider.create_safe_wrapper(KeywordsProvider, "Keywords", true)

---Internal implementation of keyword completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function KeywordsProvider._get_completions_impl(ctx)
  local KeywordData = require('ssns.completion.data.keywords')
  local Utils = require('ssns.completion.utils')
  local sql_context = ctx.sql_context
  local connection = ctx.connection

  -- Determine database type
  local db_type = "sqlserver" -- Default
  if connection and connection.server then
    db_type = connection.server:get_db_type() or "sqlserver"
  end

  -- Determine context for keyword filtering
  local keyword_context = KeywordsProvider._determine_keyword_context(sql_context)

  -- Get keywords for context and database type
  local keywords = KeywordData.get_for_context(keyword_context, db_type)

  -- Format as CompletionItems
  local items = {}
  for _, keyword in ipairs(keywords) do
    local item = Utils.format_keyword(keyword, {
      priority = 9, -- Keywords have lowest priority
    })
    table.insert(items, item)
  end

  return items
end

---Determine keyword context from SQL context
---@param sql_context table SQL context from context.lua
---@return string context Keyword context type
function KeywordsProvider._determine_keyword_context(sql_context)
  local mode = sql_context.mode

  if mode == "default" or not mode then
    return "start"
  elseif mode == "select" then
    return "after_select"
  elseif mode == "from" or mode == "from_qualified" then
    return "after_from"
  elseif mode == "where" then
    return "after_where"
  elseif mode == "join" or mode == "join_qualified" then
    return "after_join"
  else
    return "default"
  end
end

return KeywordsProvider
