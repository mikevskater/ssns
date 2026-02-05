---@class SemanticHighlighter
---Main coordinator for semantic highlighting of SQL query buffers
---Highlights SQL identifiers (tables, columns, schemas, databases, keywords) using SSNS colors
local SemanticHighlighter = {}

local NAMESPACE = "ssns_semantic"
local ns_id = nil

-- Track which buffers have semantic highlighting enabled
local enabled_buffers = {}

-- Pending highlight timers per buffer (for minimal debounce)
local pending_timers = {}

-- Track active threaded highlighting tasks per buffer
local threaded_tasks = {}

-- Default debounce delay in ms (fallback if config not available)
local DEFAULT_DEBOUNCE_MS = 50

---Get the debounce delay from config
---@return number
local function get_debounce_ms()
  local ok, Config = pcall(require, 'ssns.config')
  if ok then
    local config = Config.get_semantic_highlighting()
    return config.debounce_ms or DEFAULT_DEBOUNCE_MS
  end
  return DEFAULT_DEBOUNCE_MS
end

---Setup the semantic highlighter (call once during plugin init)
function SemanticHighlighter.setup()
  -- Create namespace for our highlights
  ns_id = vim.api.nvim_create_namespace(NAMESPACE)
end

---Schedule a highlight update with minimal debounce
---@param bufnr number Buffer number
local function schedule_update(bufnr)
  -- Cancel existing timer
  if pending_timers[bufnr] then
    vim.fn.timer_stop(pending_timers[bufnr])
    pending_timers[bufnr] = nil
  end

  -- Schedule new update with configurable debounce
  local debounce_ms = get_debounce_ms()
  pending_timers[bufnr] = vim.fn.timer_start(debounce_ms, function()
    pending_timers[bufnr] = nil
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) and enabled_buffers[bufnr] then
        SemanticHighlighter.update_threaded(bufnr)
      end
    end)
  end)
end

---Update semantic highlights using threaded worker when available
---Falls back to sync update if threading unavailable
---@param bufnr number Buffer number
function SemanticHighlighter.update_threaded(bufnr)
  local ThreadedHighlighting = require('nvim-ssns.highlighting.threaded')

  if ThreadedHighlighting.is_available() then
    threaded_tasks[bufnr] = true
    ThreadedHighlighting.update(bufnr, function(success, err)
      threaded_tasks[bufnr] = nil
      -- Errors are silently ignored, highlighting will just use sync fallback next time
    end)
  else
    -- Fall back to sync update
    SemanticHighlighter.update(bufnr)
  end
end

---Apply highlights from classified tokens (used by threaded worker)
---@param bufnr number Buffer number
---@param tokens table[] Classified tokens with highlight_group
---@param lines string[] Buffer lines for bounds checking
function SemanticHighlighter._apply_highlights(bufnr, tokens, lines)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Ensure namespace exists
  if not ns_id then
    ns_id = vim.api.nvim_create_namespace(NAMESPACE)
  end

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Apply token highlights
  for _, item in ipairs(tokens) do
    if item.highlight_group then
      -- Convert 1-indexed (tokenizer) to 0-indexed (nvim API)
      local line = item.line - 1
      local col_start = item.col - 1
      local col_end = col_start + #item.text

      -- Ensure we don't go past buffer bounds
      if line >= 0 and line < #lines then
        local line_len = #lines[line + 1]
        if col_start >= 0 and col_end <= line_len then
          vim.api.nvim_buf_add_highlight(bufnr, ns_id, item.highlight_group, line, col_start, col_end)
        end
      end
    end
  end
end

---Enable semantic highlighting for a buffer
---@param bufnr number Buffer number
function SemanticHighlighter.setup_buffer(bufnr)
  local Config = require('nvim-ssns.config')
  local config = Config.get_semantic_highlighting()

  if not config.enabled then
    return
  end

  -- Skip if buffer has requested to skip semantic highlighting
  -- (e.g., theme preview uses pre-defined highlights)
  local skip = vim.b[bufnr].ssns_skip_semantic_highlight
  if skip then
    return
  end

  -- Already enabled for this buffer
  if enabled_buffers[bufnr] then
    return
  end

  -- Mark buffer as enabled
  enabled_buffers[bufnr] = true

  -- Attach to buffer for text change events
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf, _, _, _, _)
      -- Trigger highlight update on any text change
      if enabled_buffers[buf] then
        schedule_update(buf)
      end
    end,
    on_detach = function(_, buf)
      -- Clean up on buffer detach
      enabled_buffers[buf] = nil
      if pending_timers[buf] then
        vim.fn.timer_stop(pending_timers[buf])
        pending_timers[buf] = nil
      end
      -- Cancel any active threaded highlighting
      if threaded_tasks[buf] then
        local ThreadedHighlighting = require('nvim-ssns.highlighting.threaded')
        ThreadedHighlighting.cancel(buf)
        threaded_tasks[buf] = nil
      end
    end,
  })

  -- Trigger initial highlight immediately (use threaded when available)
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      SemanticHighlighter.update_threaded(bufnr)
    end
  end)
end

---Disable semantic highlighting for a buffer
---@param bufnr number Buffer number
function SemanticHighlighter.disable_buffer(bufnr)
  enabled_buffers[bufnr] = nil
  if pending_timers[bufnr] then
    vim.fn.timer_stop(pending_timers[bufnr])
    pending_timers[bufnr] = nil
  end
  SemanticHighlighter.clear(bufnr)
end

---Check if semantic highlighting is attached to a buffer
---@param bufnr number Buffer number
---@return boolean is_attached True if semantic highlighting is enabled for this buffer
function SemanticHighlighter.is_attached(bufnr)
  return enabled_buffers[bufnr] == true
end

---Update semantic highlights for a buffer
---@param bufnr number Buffer number
---@param cache BufferStatementCache? Cached statement chunks (optional, will fetch if not provided)
function SemanticHighlighter.update(bufnr, cache)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local Config = require('nvim-ssns.config')
  local config = Config.get_semantic_highlighting()

  if not config.enabled then
    return
  end

  -- Ensure namespace exists
  if not ns_id then
    ns_id = vim.api.nvim_create_namespace(NAMESPACE)
  end

  -- Get cache if not provided
  if not cache then
    local StatementCache = require('nvim-ssns.completion.statement_cache')
    cache = StatementCache.get_or_build_cache(bufnr)
    if not cache then
      return
    end
  end

  -- Get buffer lines for bounds checking
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Use cached tokens from StatementCache (avoids redundant tokenization)
  local tokens = cache.tokens
  if not tokens or #tokens == 0 then
    -- Fallback to direct tokenization if cache doesn't have tokens
    local Tokenizer = require('nvim-ssns.completion.tokenizer')
    local text = table.concat(lines, '\n')
    tokens = Tokenizer.tokenize(text)
  end

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  if #tokens > 0 then
    -- Get connection context for this buffer
    local connection = SemanticHighlighter._get_connection(bufnr)

    -- Classify tokens
    local Classifier = require('nvim-ssns.highlighting.classifier')
    local classified = Classifier.classify(tokens, cache.chunks, connection, config)

    -- Apply token highlights first
    for _, item in ipairs(classified) do
      if item.highlight_group then
        -- Convert 1-indexed (tokenizer) to 0-indexed (nvim API)
        local line = item.token.line - 1
        local col_start = item.token.col - 1
        local col_end = col_start + #item.token.text

        -- Ensure we don't go past buffer bounds
        if line >= 0 and line < #lines then
          local line_len = #lines[line + 1]
          if col_start >= 0 and col_end <= line_len then
            vim.api.nvim_buf_add_highlight(bufnr, ns_id, item.highlight_group, line, col_start, col_end)
          end
        end
      end
    end
  end
  -- Comments are now handled via tokenizer → classifier → highlight flow (no manual detection)
end

---Clear semantic highlights for a buffer
---@param bufnr number Buffer number
function SemanticHighlighter.clear(bufnr)
  if ns_id and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end
end

---Get connection context for a buffer
---@param bufnr number Buffer number
---@return table? connection Connection with {server, database, connection_config}
function SemanticHighlighter._get_connection(bufnr)
  local Cache = require('nvim-ssns.cache')

  -- Try to get from UiQuery.query_buffers first
  local success, UiQuery = pcall(require, 'ssns.ui.query')
  if success and UiQuery.query_buffers[bufnr] then
    local buffer_info = UiQuery.query_buffers[bufnr]
    if buffer_info.server and buffer_info.database then
      return {
        server = buffer_info.server,
        database = buffer_info.database,
        connection_config = buffer_info.server.connection_config,
      }
    elseif buffer_info.server then
      return {
        server = buffer_info.server,
        database = nil,
        connection_config = buffer_info.server.connection_config,
      }
    end
  end

  -- Fallback: Try to get from ssns_db_key buffer variable (like completion source does)
  local db_key = vim.b[bufnr].ssns_db_key
  if db_key then
    -- Parse db_key format: "server_name:database_name"
    local server_name, db_name = db_key:match("^([^:]+):(.+)$")
    if server_name and db_name then
      local server = Cache.find_server(server_name)
      if server then
        local database = server:find_database(db_name)
        return {
          server = server,
          database = database,
          connection_config = server.connection_config,
        }
      end
    elseif db_key and not db_key:match(":") then
      -- Server-only key (no database)
      local server = Cache.find_server(db_key)
      if server then
        return {
          server = server,
          database = nil,
          connection_config = server.connection_config,
        }
      end
    end
  end

  -- Fallback to active database from cache
  local active_db = Cache.get_active_database()
  if active_db then
    local server = active_db:get_server()
    if server then
      return {
        server = server,
        database = active_db,
        connection_config = server.connection_config,
      }
    end
  end

  return nil
end

---Check if a buffer has semantic highlighting enabled
---@param bufnr number Buffer number
---@return boolean
function SemanticHighlighter.is_enabled(bufnr)
  return enabled_buffers[bufnr] == true
end

---Get the namespace ID
---@return number? namespace_id
function SemanticHighlighter.get_namespace()
  return ns_id
end

-- ============================================================================
-- Basic Highlighting (No Database Connection)
-- For read-only preview buffers like history preview, theme preview, etc.
-- Only highlights based on tokenization - no schema/object lookups
-- ============================================================================

-- Map token types and keyword categories to highlight groups (no DB lookups)
local BASIC_HIGHLIGHT_MAP = {
  -- Keywords by category
  keyword_statement = "SsnsKeywordStatement",
  keyword_clause = "SsnsKeywordClause",
  keyword_function = "SsnsKeywordFunction",
  keyword_datatype = "SsnsKeywordDatatype",
  keyword_operator = "SsnsKeywordOperator",
  keyword_constraint = "SsnsKeywordConstraint",
  keyword_modifier = "SsnsKeywordModifier",
  keyword_misc = "SsnsKeywordMisc",
  keyword_global_variable = "SsnsKeywordGlobalVariable",
  keyword_system_procedure = "SsnsKeywordSystemProcedure",
  -- Token types
  string = "SsnsString",
  number = "SsnsNumber",
  operator = "SsnsOperator",
  comment = "SsnsComment",
  line_comment = "SsnsComment",
  variable = "SsnsParameter",
  global_variable = "SsnsKeywordGlobalVariable",
  system_procedure = "SsnsKeywordSystemProcedure",
  temp_table = "SsnsTempTable",
}

---Apply basic keyword/token highlighting to a buffer without any database lookups
---This is used for read-only preview buffers (history preview, etc.) where we don't
---want to trigger database connections or schema loading
---@param bufnr number Buffer number
function SemanticHighlighter.apply_basic_highlighting(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Ensure namespace exists
  if not ns_id then
    ns_id = vim.api.nvim_create_namespace(NAMESPACE)
  end

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Get buffer content and tokenize
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, '\n')

  local Tokenizer = require('nvim-ssns.completion.tokenizer')
  local tokens = Tokenizer.tokenize(text)

  -- Apply highlights based purely on token type (no classifier/database)
  for _, token in ipairs(tokens) do
    local highlight_group = nil

    if token.type == "keyword" or token.type == "go" then
      -- Use keyword category for granular highlighting
      local category = token.keyword_category or "misc"
      highlight_group = BASIC_HIGHLIGHT_MAP["keyword_" .. category]
    elseif token.type == "string" then
      highlight_group = BASIC_HIGHLIGHT_MAP.string
    elseif token.type == "number" then
      highlight_group = BASIC_HIGHLIGHT_MAP.number
    elseif token.type == "operator" then
      highlight_group = BASIC_HIGHLIGHT_MAP.operator
    elseif token.type == "comment" then
      highlight_group = BASIC_HIGHLIGHT_MAP.comment
    elseif token.type == "line_comment" then
      highlight_group = BASIC_HIGHLIGHT_MAP.line_comment
    elseif token.type == "variable" then
      highlight_group = BASIC_HIGHLIGHT_MAP.variable
    elseif token.type == "global_variable" then
      highlight_group = BASIC_HIGHLIGHT_MAP.global_variable
    elseif token.type == "system_procedure" then
      highlight_group = BASIC_HIGHLIGHT_MAP.system_procedure
    elseif token.type == "temp_table" then
      highlight_group = BASIC_HIGHLIGHT_MAP.temp_table
    end

    if highlight_group then
      -- Convert 1-indexed (tokenizer) to 0-indexed (nvim API)
      local line = token.line - 1
      local col_start = token.col - 1
      local col_end = col_start + #token.text

      -- Ensure we don't go past buffer bounds
      if line >= 0 and line < #lines then
        local line_len = #lines[line + 1]
        if col_start >= 0 and col_end <= line_len then
          vim.api.nvim_buf_add_highlight(bufnr, ns_id, highlight_group, line, col_start, col_end)
        end
      end
    end
  end
end

return SemanticHighlighter
