---@class SsnsCommandsDebug
---Debug and diagnostic commands
local M = {}

---Register debug commands
function M.register()
  -- :SSNSDebugStatementChunks - View parsed statement chunks
  vim.api.nvim_create_user_command("SSNSDebugStatementChunks", function()
    local StatementChunksViewer = require('nvim-ssns.features.statement_chunks')
    StatementChunksViewer.view_statement_chunks()
  end, {
    nargs = 0,
    desc = "View parsed statement chunks in floating window",
  })

  -- :SSNSDebugTokens - View tokenizer output
  vim.api.nvim_create_user_command("SSNSDebugTokens", function()
    local ViewTokens = require('nvim-ssns.features.view_tokens')
    ViewTokens.view_tokens()
  end, {
    nargs = 0,
    desc = "View tokenizer output in floating window",
  })

  -- :SSNSDebugContext - View statement context at cursor
  vim.api.nvim_create_user_command("SSNSDebugContext", function()
    local ViewContext = require('nvim-ssns.features.view_context')
    ViewContext.view_context()
  end, {
    nargs = 0,
    desc = "View statement context at cursor in floating window",
  })

  -- :SSNSDebugStatementCache - View statement cache for current buffer
  vim.api.nvim_create_user_command("SSNSDebugStatementCache", function()
    local ViewStatementCache = require('nvim-ssns.features.view_statement_cache')
    ViewStatementCache.view_cache()
  end, {
    nargs = 0,
    desc = "View statement cache in floating window",
  })

  -- :SSNSDebugLog - View debug log in floating window
  vim.api.nvim_create_user_command("SSNSDebugLog", function(opts)
    local ViewDebugLog = require('nvim-ssns.features.view_debug_log')
    ViewDebugLog.view_log(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    desc = "View debug log in floating window (optional filter argument)",
  })

  -- :SSNSDebugQueryCache - View query result cache
  vim.api.nvim_create_user_command("SSNSDebugQueryCache", function()
    local ViewQueryCache = require('nvim-ssns.features.view_query_cache')
    ViewQueryCache.view_cache()
  end, {
    nargs = 0,
    desc = "View query cache in floating window",
  })

  -- :SSNSDebugUsageWeights - View usage-based ranking weights
  vim.api.nvim_create_user_command("SSNSDebugUsageWeights", function()
    local ViewUsageWeights = require('nvim-ssns.features.view_usage_weights')
    ViewUsageWeights.view_weights()
  end, {
    nargs = 0,
    desc = "View usage-based ranking weights in floating window",
  })

  -- :SSNSDebugCompletionMetadata - View completion metadata resolution
  vim.api.nvim_create_user_command("SSNSDebugCompletionMetadata", function()
    local ViewCompletionMetadata = require('nvim-ssns.features.view_completion_metadata')
    ViewCompletionMetadata.view_metadata()
  end, {
    nargs = 0,
    desc = "View completion metadata resolution in floating window",
  })

  -- :SSNSDebugFuzzyMatcher - View fuzzy matcher algorithm details
  vim.api.nvim_create_user_command("SSNSDebugFuzzyMatcher", function()
    local ViewFuzzyMatcher = require('nvim-ssns.features.view_fuzzy_matcher')
    ViewFuzzyMatcher.view_matcher()
  end, {
    nargs = 0,
    desc = "View fuzzy matcher algorithm in floating window",
  })

  -- :SSNSDebugTypeCompatibility - View type compatibility rules
  vim.api.nvim_create_user_command("SSNSDebugTypeCompatibility", function()
    local ViewTypeCompatibility = require('nvim-ssns.features.view_type_compatibility')
    ViewTypeCompatibility.view_compatibility()
  end, {
    nargs = 0,
    desc = "View type compatibility rules in floating window",
  })

  -- :SSNSDebugFKGraph - View FK relationship graph
  vim.api.nvim_create_user_command("SSNSDebugFKGraph", function()
    local ViewFKGraph = require('nvim-ssns.features.view_fk_graph')
    ViewFKGraph.view_graph()
  end, {
    nargs = 0,
    desc = "View FK relationship graph in floating window",
  })

  -- :SSNSCompletionStats - Show completion performance statistics
  vim.api.nvim_create_user_command("SSNSCompletionStats", function()
    local Ssns = require('nvim-ssns')
    Ssns.show_completion_stats()
  end, {
    desc = "Show completion performance statistics",
  })

  -- :SSNSCompletionStatsReset - Reset completion performance statistics
  vim.api.nvim_create_user_command("SSNSCompletionStatsReset", function()
    local Ssns = require('nvim-ssns')
    Ssns.reset_completion_stats()
  end, {
    desc = "Reset completion performance statistics",
  })

  -- :SSNSAsyncStatus - Show async RPC status and instructions
  vim.api.nvim_create_user_command("SSNSAsyncStatus", function()
    local AsyncRPC = require('nvim-ssns.async.rpc')
    -- Reset cache to get fresh check
    AsyncRPC.reset_availability_cache()
    local status = AsyncRPC.get_status()

    local lines = {
      "SSNS Async RPC Status",
      "=====================",
      "",
      string.format("Status: %s", status.available and "ENABLED" or "NOT AVAILABLE"),
      string.format("Pending callbacks: %d", status.pending_count),
      "",
    }

    if status.available then
      table.insert(lines, "Non-blocking async is working correctly.")
      table.insert(lines, "UI should remain responsive during database queries.")
    else
      table.insert(lines, "Non-blocking async is NOT available.")
      table.insert(lines, "UI may freeze during database queries.")
      table.insert(lines, "")
      table.insert(lines, "To enable non-blocking async:")
      table.insert(lines, "  1. Run :UpdateRemotePlugins")
      table.insert(lines, "  2. Restart Neovim")
      table.insert(lines, "")
      table.insert(lines, "After restarting, run :SSNSAsyncStatus to verify.")
    end

    vim.notify(table.concat(lines, "\n"), status.available and vim.log.levels.INFO or vim.log.levels.WARN)
  end, {
    desc = "Show async RPC status and setup instructions",
  })
end

return M
