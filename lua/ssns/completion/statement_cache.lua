---@class TempTableInfo
---@field name string The temp table name (including #)
---@field columns ColumnInfo[] Columns (from SELECT INTO or CREATE TABLE)
---@field is_global boolean Whether ## global temp
---@field created_in_batch number GO batch index where created
---@field source_tables TableReference[]? For SELECT INTO - source tables

---@class BufferStatementCache
---@field chunks StatementChunk[] All statement chunks in order
---@field temp_tables table<string, TempTableInfo> Temp tables created in buffer
---@field go_boundaries number[] Line numbers of GO statements
---@field last_update number Timestamp of last update (os.clock())
---@field buffer_tick number Buffer changedtick at last update

local StatementCache = {}

-- Private cache storage: bufnr -> BufferStatementCache
local _cache = {}

---Expand star columns in a column array to actual columns from source table
---@param columns ColumnInfo[] Array of column info objects
---@param connection table? Database connection for lookups
---@return ColumnInfo[] Expanded columns with stars replaced by actual columns
local function expand_star_columns(columns, connection)
  if not columns or #columns == 0 then
    return columns or {}
  end

  -- If no connection, can't expand - return as-is
  if not connection or not connection.database then
    return columns
  end

  local expanded = {}
  local Resolver = require('ssns.completion.metadata.resolver')

  for _, col in ipairs(columns) do
    if col.is_star and col.parent_table then
      -- This is a star column that needs expansion
      -- Try to resolve the parent table and get its columns
      local success, table_obj = pcall(function()
        local ref = {
          name = col.parent_table,
          schema = col.parent_schema,
        }
        return Resolver.resolve_table(col.parent_table, connection, {})
      end)

      if success and table_obj then
        -- Get columns from the resolved table
        local col_success, table_cols = pcall(function()
          return Resolver.get_columns(table_obj, connection)
        end)

        if col_success and table_cols and #table_cols > 0 then
          -- Add each actual column, preserving source info
          for _, tc in ipairs(table_cols) do
            table.insert(expanded, {
              name = tc.name or tc.column_name,
              source_table = col.source_table,
              parent_table = col.parent_table,
              parent_schema = col.parent_schema,
              data_type = tc.data_type,
              is_star = false,
            })
          end
        else
          -- Couldn't get columns, keep the star as-is
          table.insert(expanded, col)
        end
      else
        -- Couldn't resolve table, keep the star as-is
        table.insert(expanded, col)
      end
    else
      -- Regular column, keep as-is
      table.insert(expanded, col)
    end
  end

  return expanded
end

-- Pending update timers: bufnr -> timer_id
local pending_timers = {}

-- Autocmd group for change listeners
local augroup = nil

---Initialize the cache system (call once on plugin setup)
function StatementCache.setup()
  -- Create augroup for autocmds
  augroup = vim.api.nvim_create_augroup('SSNSStatementCache', { clear = true })

  -- Listen to text changes in SQL buffers
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = augroup,
    pattern = { '*.sql' },
    callback = function(args)
      StatementCache._schedule_update(args.buf)
    end,
  })

  -- Also listen to BufEnter to handle buffers that may not have .sql extension
  -- but are SQL query buffers created by SSNS
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function(args)
      local bufnr = args.buf
      -- Check if this is an SSNS query buffer by checking buffer name pattern
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      if bufname:match('SSNS Query') or bufname:match('%.sql$') then
        -- Mark this buffer as eligible for caching
        vim.b[bufnr].ssns_sql_buffer = true
      end
    end,
  })

  -- Clean up on buffer delete
  vim.api.nvim_create_autocmd('BufDelete', {
    group = augroup,
    callback = function(args)
      local bufnr = args.buf
      _cache[bufnr] = nil
      if pending_timers[bufnr] then
        vim.fn.timer_stop(pending_timers[bufnr])
        pending_timers[bufnr] = nil
      end
    end,
  })
end

---Check if a buffer is a SQL buffer eligible for caching
---@param bufnr number Buffer number
---@return boolean
local function is_sql_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  -- Check if marked as SSNS SQL buffer
  if vim.b[bufnr].ssns_sql_buffer then
    return true
  end

  -- Check file extension
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname:match('%.sql$') or bufname:match('SSNS Query') then
    return true
  end

  -- Check filetype
  local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  return ft == 'sql'
end

---Schedule a cache update with debouncing
---@param bufnr number Buffer number
function StatementCache._schedule_update(bufnr)
  -- Only schedule for SQL buffers
  if not is_sql_buffer(bufnr) then
    return
  end

  -- Cancel existing timer
  if pending_timers[bufnr] then
    vim.fn.timer_stop(pending_timers[bufnr])
  end

  -- Schedule new update after 150ms of inactivity
  pending_timers[bufnr] = vim.fn.timer_start(150, function()
    pending_timers[bufnr] = nil
    StatementCache._update_cache(bufnr)
  end)
end

---Update the cache for a buffer (internal)
---@param bufnr number Buffer number
function StatementCache._update_cache(bufnr)
  -- Check if buffer still exists
  if not vim.api.nvim_buf_is_valid(bufnr) then
    _cache[bufnr] = nil
    return
  end

  -- Check changedtick to avoid redundant parsing
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  if _cache[bufnr] and _cache[bufnr].buffer_tick == tick then
    return -- No changes since last update
  end

  -- Get buffer text
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, '\n')

  -- Parse the buffer
  local StatementParser = require('ssns.completion.statement_parser')
  local chunks, temp_tables = StatementParser.parse(text)

  -- Extract GO boundaries (line numbers where GO batch index changes)
  local go_boundaries = {}
  local last_batch = 0
  for _, chunk in ipairs(chunks) do
    if chunk.go_batch_index and chunk.go_batch_index ~= last_batch then
      -- This chunk starts a new batch
      table.insert(go_boundaries, chunk.start_line)
      last_batch = chunk.go_batch_index
    end
  end

  -- Store cache
  _cache[bufnr] = {
    chunks = chunks,
    temp_tables = temp_tables,
    go_boundaries = go_boundaries,
    last_update = os.clock(),
    buffer_tick = tick,
  }
end

---Get or build cache for a buffer
---@param bufnr number Buffer number
---@return BufferStatementCache? cache The cache, or nil if not a SQL buffer
function StatementCache.get_or_build_cache(bufnr)
  -- Check if this is a SQL buffer
  if not is_sql_buffer(bufnr) then
    return nil
  end

  -- Check if we have a valid cache
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  if _cache[bufnr] and _cache[bufnr].buffer_tick == tick then
    return _cache[bufnr]
  end

  -- Build cache synchronously
  StatementCache._update_cache(bufnr)
  return _cache[bufnr]
end

---Get temp tables visible at the given position
---@param bufnr number Buffer number
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return table<string, TempTableInfo> Visible temp tables
function StatementCache.get_visible_temp_tables(bufnr, line, col)
  local cache = StatementCache.get_or_build_cache(bufnr)
  if not cache then
    return {}
  end

  -- Find which GO batch the position is in
  local StatementParser = require('ssns.completion.statement_parser')
  local chunk = StatementParser.get_chunk_at_position(cache.chunks, line, col)
  local current_batch = chunk and chunk.go_batch_index or 1

  local visible = {}
  for name, info in pairs(cache.temp_tables) do
    if info.is_global then
      -- Global temps (##) visible everywhere
      visible[name] = info
    elseif info.created_in_batch == current_batch then
      -- Local temps (#) visible only in same batch
      visible[name] = info
    end
  end

  return visible
end

---Get context at cursor position for completion
---@param bufnr number Buffer number
---@param line number 1-indexed line
---@param col number 1-indexed column
---@param connection table? Optional database connection for star column expansion
---@return table? context Context with tables, aliases, temp_tables, ctes, subquery, chunk
function StatementCache.get_context_at_position(bufnr, line, col, connection)
  local cache = StatementCache.get_or_build_cache(bufnr)
  if not cache then
    return nil
  end

  local StatementParser = require('ssns.completion.statement_parser')
  local chunk = StatementParser.get_chunk_at_position(cache.chunks, line, col)
  if not chunk then
    return nil
  end

  -- Check if inside a subquery
  local subquery = StatementParser.get_subquery_at_position(chunk, line, col)

  -- Build available tables/aliases based on scope
  local tables = {}
  local aliases = {}

  if subquery then
    -- Inside subquery: use subquery's tables
    tables = vim.deepcopy(subquery.tables or {})
    for _, t in ipairs(subquery.tables or {}) do
      if t.alias then
        aliases[t.alias] = t
      end
    end
    -- Also add subquery's own nested subqueries as available aliases (with star expansion)
    for _, sq in ipairs(subquery.subqueries or {}) do
      if sq.alias then
        local expanded_sq_cols = expand_star_columns(sq.columns, connection)
        aliases[sq.alias] = {
          name = sq.alias,
          alias = sq.alias,
          is_subquery = true,
          columns = expanded_sq_cols,
        }
        -- Add to tables array like CTEs for consistent handling
        table.insert(tables, {
          name = sq.alias,
          alias = sq.alias,
          is_subquery = true,
          columns = expanded_sq_cols,
        })
      end
    end

    -- Include outer query tables/aliases for correlated subquery support
    -- Add parent chunk's tables (subquery tables take precedence)
    for _, t in ipairs(chunk.tables or {}) do
      if t.alias and not aliases[t.alias] then
        aliases[t.alias] = t
      end
      -- Add to tables array if not already present
      local found = false
      for _, existing in ipairs(tables) do
        if existing.name == t.name and existing.alias == t.alias then
          found = true
          break
        end
      end
      if not found then
        table.insert(tables, t)
      end
    end

    -- Also add chunk.aliases for outer scope references
    for alias_name, table_ref in pairs(chunk.aliases or {}) do
      if not aliases[alias_name] then
        aliases[alias_name] = table_ref
      end
    end
  else
    -- At statement level: use chunk's tables
    tables = vim.deepcopy(chunk.tables or {})
    aliases = vim.deepcopy(chunk.aliases or {})
    -- Add subqueries as available aliases (with star expansion)
    for _, sq in ipairs(chunk.subqueries or {}) do
      if sq.alias then
        local expanded_sq_cols = expand_star_columns(sq.columns, connection)
        aliases[sq.alias] = {
          name = sq.alias,
          alias = sq.alias,
          is_subquery = true,
          columns = expanded_sq_cols,
        }
        -- Add to tables array like CTEs for consistent handling
        table.insert(tables, {
          name = sq.alias,
          alias = sq.alias,
          is_subquery = true,
          columns = expanded_sq_cols,
        })
      end
    end
  end

  -- Add CTEs as available references (with star column expansion)
  local ctes = {}
  for _, cte in ipairs(chunk.ctes or {}) do
    -- Expand star columns if connection is available
    local expanded_columns = expand_star_columns(cte.columns, connection)
    local cte_with_expanded = {
      name = cte.name,
      columns = expanded_columns,
      tables = cte.tables,
    }
    ctes[cte.name] = cte_with_expanded
    -- CTEs can be referenced like tables
    table.insert(tables, {
      name = cte.name,
      is_cte = true,
      columns = expanded_columns,
    })
  end

  -- Get visible temp tables (with star expansion)
  local temp_tables = StatementCache.get_visible_temp_tables(bufnr, line, col)

  -- Add temp tables to available tables
  for name, temp_info in pairs(temp_tables) do
    local expanded_temp_cols = expand_star_columns(temp_info.columns, connection)
    table.insert(tables, {
      name = name,
      is_temp_table = true,
      is_global = temp_info.is_global,
      columns = expanded_temp_cols,
    })
  end

  return {
    chunk = chunk,
    subquery = subquery,
    tables = tables,
    aliases = aliases,
    ctes = ctes,
    temp_tables = temp_tables,
  }
end

---Invalidate cache for a buffer (force rebuild on next access)
---@param bufnr number Buffer number
function StatementCache.invalidate(bufnr)
  _cache[bufnr] = nil
  if pending_timers[bufnr] then
    vim.fn.timer_stop(pending_timers[bufnr])
    pending_timers[bufnr] = nil
  end
end

---Clear all caches
function StatementCache.clear_all()
  -- Stop all pending timers
  for bufnr, timer_id in pairs(pending_timers) do
    vim.fn.timer_stop(timer_id)
  end
  pending_timers = {}
  _cache = {}
end

---Get cache statistics (for debugging)
---@return table stats Cache statistics
function StatementCache.get_stats()
  local stats = {
    cached_buffers = 0,
    total_chunks = 0,
    total_temp_tables = 0,
    pending_updates = 0,
  }

  for _, cache in pairs(_cache) do
    stats.cached_buffers = stats.cached_buffers + 1
    stats.total_chunks = stats.total_chunks + #cache.chunks
    for _ in pairs(cache.temp_tables) do
      stats.total_temp_tables = stats.total_temp_tables + 1
    end
  end

  for _ in pairs(pending_timers) do
    stats.pending_updates = stats.pending_updates + 1
  end

  return stats
end

---Export expand_star_columns for use by column provider
---@param columns ColumnInfo[] Array of column info objects
---@param connection table? Database connection for lookups
---@return ColumnInfo[] Expanded columns with stars replaced by actual columns
function StatementCache.expand_star_columns(columns, connection)
  return expand_star_columns(columns, connection)
end

return StatementCache
