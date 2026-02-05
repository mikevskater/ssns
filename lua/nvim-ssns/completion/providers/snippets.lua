---SQL snippet completion provider
---@class SnippetsProvider
local SnippetsProvider = {}

local BaseProvider = require('nvim-ssns.completion.providers.base_provider')

-- Use BaseProvider.create_safe_wrapper for standardized error handling
SnippetsProvider.get_completions = BaseProvider.create_safe_wrapper(SnippetsProvider, "Snippets", true)

---Internal implementation of snippet completion
---@param ctx table Context { bufnr, connection, sql_context }
---@return table[] items Array of CompletionItems
function SnippetsProvider._get_completions_impl(ctx)
  local SnippetData = require('nvim-ssns.completion.data.snippets')
  local Utils = require('nvim-ssns.completion.utils')
  local connection = ctx.connection

  -- Determine database type
  local db_type = "sqlserver" -- Default
  if connection and connection.server then
    db_type = connection.server:get_db_type() or "sqlserver"
  end

  -- Get built-in snippets
  local built_in_snippets = SnippetData.get_for_database(db_type)

  -- Get user-defined snippets
  local user_snippets = SnippetData.load_user_snippets()

  -- Combine snippets
  local all_snippets = vim.deepcopy(built_in_snippets)
  vim.list_extend(all_snippets, user_snippets)

  -- Format as CompletionItems
  local items = {}
  for _, snippet in ipairs(all_snippets) do
    local item = {
      label = snippet.label,
      kind = Utils.CompletionItemKind.Snippet, -- 15
      detail = snippet.description or "SQL Snippet",
      documentation = {
        kind = "markdown",
        value = string.format("```sql\n%s\n```", snippet.insertText),
      },
      insertText = snippet.insertText,
      insertTextFormat = 2, -- Snippet format (LSP spec)
      filterText = snippet.label,
      sortText = Utils.generate_sort_text(8, snippet.label), -- Snippets priority 8
    }
    table.insert(items, item)
  end

  return items
end

return SnippetsProvider
