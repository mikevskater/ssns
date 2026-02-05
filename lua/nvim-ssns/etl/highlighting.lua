---@class EtlHighlighting
---Applies SSNS semantic highlighting to SQL blocks in .ssns ETL files
---Each SQL block uses its own server/database connection for full schema resolution
local EtlHighlighting = {}

local NAMESPACE = "ssns_etl_semantic"
local ns_id = nil

-- Track pending update timers per buffer (for debouncing)
local pending_timers = {}

-- Track which buffers have ETL highlighting enabled
local enabled_buffers = {}

-- Cached parsed scripts per buffer (invalidated on text change)
---@type table<number, EtlScript>
local script_cache = {}

-- Default debounce delay in ms
local DEFAULT_DEBOUNCE_MS = 100

---Get the debounce delay from config
---@return number
local function get_debounce_ms()
  local ok, Config = pcall(require, 'nvim-ssns.config')
  if ok then
    local config = Config.get_semantic_highlighting()
    return config.debounce_ms or DEFAULT_DEBOUNCE_MS
  end
  return DEFAULT_DEBOUNCE_MS
end

---Initialize the namespace
local function ensure_namespace()
  if not ns_id then
    ns_id = vim.api.nvim_create_namespace(NAMESPACE)
  end
  return ns_id
end

---Get cached script or parse fresh
---@param bufnr number Buffer number
---@return EtlScript? script Parsed script or nil
local function get_or_parse_script(bufnr)
  if script_cache[bufnr] then
    return script_cache[bufnr]
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  local ok, EtlParser = pcall(require, 'nvim-ssns.etl.parser')
  if not ok then
    return nil
  end

  local script = EtlParser.parse(content)
  script_cache[bufnr] = script
  return script
end

---Invalidate script cache for buffer
---@param bufnr number Buffer number
local function invalidate_cache(bufnr)
  script_cache[bufnr] = nil
end

---Resolve server/database connection from block directives
---@param block EtlBlock Block with server/database fields
---@return table? connection Connection context {server, database, connection_config}
local function resolve_block_connection(block)
  if not block.server then
    return nil
  end

  local ok, Cache = pcall(require, 'nvim-ssns.cache')
  if not ok then
    return nil
  end

  local server = Cache.find_server(block.server)
  if not server then
    return nil
  end

  local database = nil
  if block.database then
    database = server:find_database(block.database)
  end

  return {
    server = server,
    database = database,
    connection_config = server.connection_config,
  }
end

---Find the line number where SQL content actually starts (after directives)
---@param block EtlBlock Block to check
---@param lines string[] Buffer lines
---@return number content_start_line 1-indexed line where SQL content starts
local function find_content_start_line(block, lines)
  -- block.start_line is where --@block directive is
  -- We need to skip past all directive lines to find where SQL content begins

  local content_start = block.start_line

  -- Walk through lines from block start to find first non-directive line
  for i = block.start_line, block.end_line do
    local line = lines[i]
    if line then
      -- Check if line is a directive (starts with --@ after optional whitespace)
      local is_directive = line:match("^%s*%-%-@[%w_]+")
      -- Check if line is empty or whitespace
      local is_empty = line:match("^%s*$")

      if not is_directive and not is_empty then
        content_start = i
        break
      elseif is_directive then
        content_start = i + 1  -- Content starts after this directive
      end
    end
  end

  return content_start
end

---Apply semantic highlights for a single SQL block
---@param bufnr number Buffer number
---@param block EtlBlock Block to highlight
---@param lines string[] Buffer lines
---@param config table Semantic highlighting config
local function highlight_sql_block(bufnr, block, lines, config)
  local connection = resolve_block_connection(block)

  -- Find where SQL content starts (line number in buffer, 1-indexed)
  local content_start_line = find_content_start_line(block, lines)

  -- Get block content for tokenization
  local block_content = block.content
  if not block_content or block_content == "" then
    return
  end

  -- Tokenize the SQL content
  local ok_tok, Tokenizer = pcall(require, 'nvim-ssns.completion.tokenizer')
  if not ok_tok then
    return
  end

  local tokens = Tokenizer.tokenize(block_content)
  if not tokens or #tokens == 0 then
    return
  end

  -- Classify tokens with connection context (for schema resolution)
  local ok_class, Classifier = pcall(require, 'nvim-ssns.highlighting.classifier')
  if not ok_class then
    return
  end

  -- We don't have statement chunks for ETL blocks, pass nil
  local classified = Classifier.classify(tokens, nil, connection, config)

  -- Apply highlights with line offset
  -- Token positions are relative to block content (1-indexed starting at line 1)
  -- We need to offset them to buffer coordinates
  local line_offset = content_start_line - 1  -- Convert to buffer 0-indexed base

  for _, item in ipairs(classified) do
    if item.highlight_group and item.token then
      -- Token line is 1-indexed relative to block content
      -- Buffer line = token.line - 1 (0-indexed) + content_start_line - 1 (offset)
      local buf_line = item.token.line - 1 + line_offset
      local col_start = item.token.col - 1
      local col_end = col_start + #item.token.text

      -- Bounds check
      if buf_line >= 0 and buf_line < #lines then
        local line_len = #lines[buf_line + 1]
        if col_start >= 0 and col_end <= line_len then
          vim.api.nvim_buf_add_highlight(bufnr, ns_id, item.highlight_group, buf_line, col_start, col_end)
        end
      end
    end
  end
end

---Update semantic highlights for all SQL blocks in buffer
---@param bufnr number Buffer number
function EtlHighlighting.update(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  ensure_namespace()

  -- Get config
  local ok_cfg, Config = pcall(require, 'nvim-ssns.config')
  local config = {}
  if ok_cfg then
    config = Config.get_semantic_highlighting()
    if not config.enabled then
      return
    end
  end

  -- Parse script
  local script = get_or_parse_script(bufnr)
  if not script or not script.blocks then
    return
  end

  -- Get buffer lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Clear existing semantic highlights (preserve syntax highlights)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  -- Highlight each SQL block
  for _, block in ipairs(script.blocks) do
    if block.type == "sql" then
      highlight_sql_block(bufnr, block, lines, config)
    end
    -- Lua blocks use default treesitter highlighting - no action needed
  end
end

---Schedule a highlight update with debounce
---@param bufnr number Buffer number
local function schedule_update(bufnr)
  -- Cancel existing timer
  if pending_timers[bufnr] then
    vim.fn.timer_stop(pending_timers[bufnr])
    pending_timers[bufnr] = nil
  end

  -- Invalidate cache since content changed
  invalidate_cache(bufnr)

  -- Schedule new update
  local debounce_ms = get_debounce_ms()
  pending_timers[bufnr] = vim.fn.timer_start(debounce_ms, function()
    pending_timers[bufnr] = nil
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) and enabled_buffers[bufnr] then
        EtlHighlighting.update(bufnr)
      end
    end)
  end)
end

---Setup ETL highlighting for a buffer
---@param bufnr number Buffer number
function EtlHighlighting.setup_buffer(bufnr)
  -- Check if semantic highlighting is enabled
  local ok_cfg, Config = pcall(require, 'nvim-ssns.config')
  if ok_cfg then
    local config = Config.get_semantic_highlighting()
    if not config.enabled then
      return
    end
  end

  -- Already enabled for this buffer
  if enabled_buffers[bufnr] then
    return
  end

  enabled_buffers[bufnr] = true
  ensure_namespace()

  -- Attach to buffer for text change events
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf, _, _, _, _)
      if enabled_buffers[buf] then
        schedule_update(buf)
      end
    end,
    on_detach = function(_, buf)
      -- Cleanup
      enabled_buffers[buf] = nil
      script_cache[buf] = nil
      if pending_timers[buf] then
        vim.fn.timer_stop(pending_timers[buf])
        pending_timers[buf] = nil
      end
    end,
  })

  -- Trigger initial highlight
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      EtlHighlighting.update(bufnr)
    end
  end)
end

---Disable ETL highlighting for a buffer
---@param bufnr number Buffer number
function EtlHighlighting.disable_buffer(bufnr)
  enabled_buffers[bufnr] = nil
  script_cache[bufnr] = nil
  if pending_timers[bufnr] then
    vim.fn.timer_stop(pending_timers[bufnr])
    pending_timers[bufnr] = nil
  end
  EtlHighlighting.clear(bufnr)
end

---Clear ETL semantic highlights for a buffer
---@param bufnr number Buffer number
function EtlHighlighting.clear(bufnr)
  if ns_id and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end
end

---Check if ETL highlighting is enabled for a buffer
---@param bufnr number Buffer number
---@return boolean
function EtlHighlighting.is_enabled(bufnr)
  return enabled_buffers[bufnr] == true
end

---Get the block at current cursor position
---@param bufnr number Buffer number
---@return EtlBlock? block Block at cursor or nil
function EtlHighlighting.get_block_at_cursor(bufnr)
  local script = get_or_parse_script(bufnr)
  if not script or not script.blocks then
    return nil
  end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]  -- 1-indexed

  for _, block in ipairs(script.blocks) do
    if cursor_line >= block.start_line and cursor_line <= block.end_line then
      return block
    end
  end

  return nil
end

---Get connection context for the block at cursor position
---Returns the connection for the SQL block the cursor is currently in
---@param bufnr number Buffer number
---@return table? connection Connection context {server, database, connection_config}
function EtlHighlighting.get_connection_at_cursor(bufnr)
  local block = EtlHighlighting.get_block_at_cursor(bufnr)
  if not block then
    return nil
  end

  -- Only SQL blocks have meaningful connections for completion
  if block.type ~= "sql" then
    return nil
  end

  return resolve_block_connection(block)
end

---Get parsed script for a buffer (for external use)
---@param bufnr number Buffer number
---@return EtlScript? script Parsed script or nil
function EtlHighlighting.get_script(bufnr)
  return get_or_parse_script(bufnr)
end

---Get the namespace ID
---@return number? namespace_id
function EtlHighlighting.get_namespace()
  return ns_id
end

return EtlHighlighting
