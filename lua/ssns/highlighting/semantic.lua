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

-- Debounce delay in ms (very short for responsiveness)
local DEBOUNCE_MS = 10

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

  -- Schedule new update with minimal debounce
  pending_timers[bufnr] = vim.fn.timer_start(DEBOUNCE_MS, function()
    pending_timers[bufnr] = nil
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) and enabled_buffers[bufnr] then
        SemanticHighlighter.update(bufnr)
      end
    end)
  end)
end

---Enable semantic highlighting for a buffer
---@param bufnr number Buffer number
function SemanticHighlighter.setup_buffer(bufnr)
  local Config = require('ssns.config')
  local config = Config.get_semantic_highlighting()

  if not config.enabled then
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
    end,
  })

  -- Trigger initial highlight immediately
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      SemanticHighlighter.update(bufnr)
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

  local Config = require('ssns.config')
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
    local StatementCache = require('ssns.completion.statement_cache')
    cache = StatementCache.get_or_build_cache(bufnr)
    if not cache then
      return
    end
  end

  -- Get buffer text and tokenize
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, '\n')

  local Tokenizer = require('ssns.completion.tokenizer')
  local tokens = Tokenizer.tokenize(text)

  if #tokens == 0 then
    SemanticHighlighter.clear(bufnr)
    return
  end

  -- Get connection context for this buffer
  local connection = SemanticHighlighter._get_connection(bufnr)

  -- Classify tokens
  local Classifier = require('ssns.highlighting.classifier')
  local classified = Classifier.classify(tokens, cache.chunks, connection, config)

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Apply highlights
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

---Clear semantic highlights for a buffer
---@param bufnr number Buffer number
function SemanticHighlighter.clear(bufnr)
  if ns_id and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end
end

---Get connection context for a buffer
---@param bufnr number Buffer number
---@return table? connection Connection with {server, database, connection_string}
function SemanticHighlighter._get_connection(bufnr)
  -- Try to get from UiQuery.query_buffers
  local success, UiQuery = pcall(require, 'ssns.ui.query')
  if success and UiQuery.query_buffers[bufnr] then
    local buffer_info = UiQuery.query_buffers[bufnr]
    if buffer_info.server and buffer_info.database then
      return {
        server = buffer_info.server,
        database = buffer_info.database,
        connection_string = buffer_info.server.connection_string,
      }
    elseif buffer_info.server then
      return {
        server = buffer_info.server,
        database = nil,
        connection_string = buffer_info.server.connection_string,
      }
    end
  end

  -- Fallback to active database from cache
  local Cache = require('ssns.cache')
  local active_db = Cache.get_active_database()
  if active_db then
    local server = active_db:get_server()
    if server then
      return {
        server = server,
        database = active_db,
        connection_string = server.connection_string,
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

return SemanticHighlighter
