---@class TempTableInfo
---@field name string The temp table name (including #)
---@field columns ColumnInfo[] Columns (from SELECT INTO or CREATE TABLE)
---@field is_global boolean Whether ## global temp
---@field created_in_batch number GO batch index where created
---@field source_tables TableReference[]? For SELECT INTO - source tables
---@field dropped_at_line number? Line number where dropped (nil if not dropped)

---@class BufferStatementCache
---@field chunks StatementChunk[] All statement chunks in order
---@field tokens Token[] Full token array from parsing (for token caching)
---@field temp_tables table<string, TempTableInfo> Temp tables created in buffer
---@field go_boundaries number[] Line numbers of GO statements
---@field last_update number Timestamp of last update (os.clock())
---@field buffer_tick number Buffer changedtick at last update

local StatementCache = {}

local Debug = require('ssns.debug')

-- Private cache storage: bufnr -> BufferStatementCache
local _cache = {}

-- Callbacks to invoke after cache update: array of functions(bufnr, cache)
local _update_callbacks = {}

-- Forward declaration for mutual recursion
local expand_subquery_columns

---Expand star columns from a subquery by looking at its tables and nested subqueries
---@param subquery table Subquery with columns, tables, subqueries
---@param connection table? Database connection for lookups
---@param depth number? Current recursion depth (to prevent infinite loops)
---@return ColumnInfo[] Expanded columns
expand_subquery_columns = function(subquery, connection, depth)
  depth = depth or 0
  if depth > 10 then
    -- Prevent infinite recursion
    return subquery.columns or {}
  end

  local columns = subquery.columns or {}
  if #columns == 0 then
    return {}
  end

  -- Check if there's a star that needs expansion from nested sources
  local has_unqualified_star = false
  for _, col in ipairs(columns) do
    if col.is_star and not col.source_table then
      has_unqualified_star = true
      break
    end
  end

  if not has_unqualified_star then
    -- No stars to expand from nested subqueries
    return columns
  end

  -- Build a map of available sources (tables and nested subqueries)
  local source_columns = {}

  -- Add columns from nested subqueries (these are derived tables in FROM clause)
  for _, nested_sq in ipairs(subquery.subqueries or {}) do
    if nested_sq.alias then
      -- Recursively expand the nested subquery's columns
      local nested_cols = expand_subquery_columns(nested_sq, connection, depth + 1)
      source_columns[nested_sq.alias:lower()] = nested_cols
    end
  end

  -- Add columns from regular tables (will be expanded via database later)
  for _, tbl in ipairs(subquery.tables or {}) do
    local tbl_name = tbl.alias or tbl.name
    if tbl_name and not source_columns[tbl_name:lower()] then
      -- Mark as a database table source (columns will be expanded via Resolver)
      source_columns[tbl_name:lower()] = { _is_db_table = true, _table_ref = tbl }
    end
  end

  -- Now expand star columns
  local expanded = {}
  for _, col in ipairs(columns) do
    if col.is_star then
      if col.source_table then
        -- Qualified star (e.g., alias.*)
        local source_key = col.source_table:lower()
        local source = source_columns[source_key]
        if source then
          if source._is_db_table then
            -- Will be expanded from database later, keep star
            table.insert(expanded, col)
          else
            -- Expand from nested subquery columns
            for _, src_col in ipairs(source) do
              if not src_col.is_star or src_col.name ~= "*" then
                table.insert(expanded, {
                  name = src_col.name,
                  source_table = col.source_table,
                  is_star = false,
                })
              end
            end
          end
        else
          table.insert(expanded, col)
        end
      else
        -- Unqualified star (SELECT *) - expand from all sources
        local added_any = false
        for source_name, source in pairs(source_columns) do
          if source._is_db_table then
            -- Expand from database table using Resolver
            local tbl_ref = source._table_ref
            if connection and connection.database then
              local Resolver = require('ssns.completion.metadata.resolver')
              local table_name = tbl_ref.name
              if tbl_ref.schema then
                table_name = tbl_ref.schema .. "." .. table_name
              end
              local success, table_obj = pcall(function()
                return Resolver.resolve_table(table_name, connection, {})
              end)
              if success and table_obj then
                local col_success, table_cols = pcall(function()
                  return Resolver.get_columns(table_obj, connection)
                end)
                if col_success and table_cols and #table_cols > 0 then
                  for _, tc in ipairs(table_cols) do
                    table.insert(expanded, {
                      name = tc.name or tc.column_name,
                      source_table = source_name,
                      parent_table = tbl_ref.name,
                      parent_schema = tbl_ref.schema,
                      data_type = tc.data_type,
                      is_star = false,
                    })
                    added_any = true
                  end
                end
              end
            else
              -- No connection - keep star but set parent_table for later expansion
              table.insert(expanded, {
                name = "*",
                source_table = source_name,
                parent_table = tbl_ref.name,
                parent_schema = tbl_ref.schema,
                is_star = true,
              })
              added_any = true
            end
          else
            -- Expand from nested subquery columns
            for _, src_col in ipairs(source) do
              if not src_col.is_star or src_col.name ~= "*" then
                table.insert(expanded, {
                  name = src_col.name,
                  source_table = source_name,
                  is_star = false,
                })
                added_any = true
              end
            end
          end
        end
        if not added_any then
          -- Keep star for database table expansion later
          table.insert(expanded, col)
        end
      end
    else
      -- Regular column, keep as-is
      table.insert(expanded, col)
    end
  end

  return expanded
end

---Expand star columns in a column array to actual columns from source table
---@param columns ColumnInfo[] Array of column info objects
---@param connection table? Database connection for lookups
---@param known_ctes table<string, table>? Previously processed CTEs for CTE-to-CTE references
---@param cte_tables TableReference[]? Tables in the CTE's FROM clause for alias resolution
---@return ColumnInfo[] Expanded columns with stars replaced by actual columns
local function expand_star_columns(columns, connection, known_ctes, cte_tables)
  if not columns or #columns == 0 then
    return columns or {}
  end

  local expanded = {}
  local Resolver = require('ssns.completion.metadata.resolver')

  for _, col in ipairs(columns) do
    if col.is_star then
      -- This is a star column that needs expansion
      local parent = col.parent_table
      local source = col.source_table

      -- For qualified stars (e.g., e.*), try to resolve the source alias
      -- to find if it points to a CTE
      local resolved_cte_name = nil
      if source and cte_tables then
        local source_lower = source:lower()
        for _, tbl in ipairs(cte_tables) do
          local alias = tbl.alias and tbl.alias:lower()
          local name = tbl.name and tbl.name:lower()
          if alias == source_lower or name == source_lower then
            -- Check if this table is a CTE reference
            if tbl.is_cte and tbl.name then
              resolved_cte_name = tbl.name
            elseif tbl.name then
              -- Check if the table name matches a known CTE
              local tbl_lower = tbl.name:lower()
              if known_ctes then
                for cte_name, _ in pairs(known_ctes) do
                  if cte_name:lower() == tbl_lower then
                    resolved_cte_name = cte_name
                    break
                  end
                end
              end
            end
            break
          end
        end
      end

      -- Also check if parent_table directly matches a CTE
      if not resolved_cte_name and parent and known_ctes then
        local parent_lower = parent:lower()
        for cte_name, _ in pairs(known_ctes) do
          if cte_name:lower() == parent_lower then
            resolved_cte_name = cte_name
            break
          end
        end
      end

      -- If this star refers to a CTE, expand from CTE columns
      if resolved_cte_name and known_ctes then
        local cte_info = known_ctes[resolved_cte_name]
        if cte_info and cte_info.columns and #cte_info.columns > 0 then
          -- Add each CTE column, preserving source info
          for _, cte_col in ipairs(cte_info.columns) do
            -- Only add non-star columns (stars should already be expanded)
            if not cte_col.is_star then
              table.insert(expanded, {
                name = cte_col.name,
                source_table = source or resolved_cte_name,
                parent_table = resolved_cte_name,
                parent_schema = nil, -- CTEs don't have schemas
                data_type = cte_col.data_type,
                is_star = false,
              })
            end
          end
          goto continue_col
        end
      end

      -- Fall back to database table resolution
      if parent and connection and connection.database then
        local success, table_obj = pcall(function()
          return Resolver.resolve_table(parent, connection, {})
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
            goto continue_col
          end
        end
      end

      -- Couldn't expand, keep the star as-is
      table.insert(expanded, col)
    else
      -- Regular column, keep as-is
      table.insert(expanded, col)
    end
    ::continue_col::
  end

  return expanded
end

-- Pending update timers: bufnr -> timer_id
local pending_timers = {}

-- Autocmd group for change listeners
local augroup = nil

---Register a callback to be called after cache updates
---@param callback fun(bufnr: number, cache: BufferStatementCache) Callback function
function StatementCache.on_update(callback)
  table.insert(_update_callbacks, callback)
end

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

  -- Parse the buffer (now returns tokens as third value)
  local StatementParser = require('ssns.completion.statement_parser')
  local chunks, temp_tables, tokens = StatementParser.parse(text)

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

  -- Store cache (now includes tokens for token caching optimization)
  _cache[bufnr] = {
    chunks = chunks,
    tokens = tokens,
    temp_tables = temp_tables,
    go_boundaries = go_boundaries,
    last_update = os.clock(),
    buffer_tick = tick,
  }

  -- Notify registered callbacks
  for _, callback in ipairs(_update_callbacks) do
    local success, err = pcall(callback, bufnr, _cache[bufnr])
    if not success then
      -- Log error but don't break other callbacks
      Debug.log(string.format("[SSNS] StatementCache callback error: %s", tostring(err)))
    end
  end
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
    -- Check if dropped before current position
    if info.dropped_at_line and info.dropped_at_line < line then
      -- Temp table was dropped before current line, skip it
      goto continue
    end

    if info.is_global then
      -- Global temps (##) visible everywhere (unless dropped)
      visible[name] = info
    elseif info.created_in_batch == current_batch then
      -- Local temps (#) visible only in same batch (unless dropped)
      visible[name] = info
    end

    ::continue::
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
        -- Use expand_subquery_columns to handle nested subquery star expansion
        local expanded_sq_cols = expand_subquery_columns(sq, connection)
        -- Then expand any remaining stars from database tables
        expanded_sq_cols = expand_star_columns(expanded_sq_cols, connection)
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
        -- Use expand_subquery_columns to handle nested subquery star expansion
        local expanded_sq_cols = expand_subquery_columns(sq, connection)
        -- Then expand any remaining stars from database tables
        expanded_sq_cols = expand_star_columns(expanded_sq_cols, connection)
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
  -- Build set of CTE names already referenced in chunk.tables and their indices
  local ctes_in_tables = {}
  for i, tbl in ipairs(tables) do
    if tbl.is_cte and tbl.name then
      ctes_in_tables[tbl.name:lower()] = i
    end
  end

  local ctes = {}
  for _, cte in ipairs(chunk.ctes or {}) do
    -- Expand star columns - pass previously processed CTEs for CTE-to-CTE references
    -- and the CTE's own tables for alias resolution
    local expanded_columns = expand_star_columns(cte.columns, connection, ctes, cte.tables)
    local cte_with_expanded = {
      name = cte.name,
      columns = expanded_columns,
      tables = cte.tables,
    }
    ctes[cte.name] = cte_with_expanded
    -- Check if this CTE is already referenced in tables (from FROM clause)
    local existing_idx = ctes_in_tables[cte.name:lower()]
    if existing_idx then
      -- Update the existing entry with expanded columns from CTE definition
      tables[existing_idx].columns = expanded_columns
    end
    -- Don't add unreferenced CTEs to tables - they shouldn't contribute columns
    -- to unqualified column completion
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
---@param known_ctes table<string, table>? Previously processed CTEs for CTE-to-CTE references
---@param cte_tables TableReference[]? Tables in the CTE's FROM clause for alias resolution
---@return ColumnInfo[] Expanded columns with stars replaced by actual columns
function StatementCache.expand_star_columns(columns, connection, known_ctes, cte_tables)
  return expand_star_columns(columns, connection, known_ctes, cte_tables)
end

---Get cached tokens for a buffer
---Returns the full token array from the last parse, avoiding re-tokenization
---@param bufnr number Buffer number
---@return Token[]? tokens Cached tokens or nil if not cached
function StatementCache.get_tokens(bufnr)
  local cache = StatementCache.get_or_build_cache(bufnr)
  return cache and cache.tokens or nil
end

---Get tokens for a specific chunk
---Returns only the tokens within the chunk's token range
---@param bufnr number Buffer number
---@param chunk StatementChunk The chunk to get tokens for
---@return Token[] tokens Tokens for this chunk (empty if not available)
function StatementCache.get_chunk_tokens(bufnr, chunk)
  local cache = StatementCache.get_or_build_cache(bufnr)
  if not cache or not cache.tokens then
    return {}
  end

  -- Use token indices if available
  if chunk.token_start_idx and chunk.token_end_idx then
    local result = {}
    for i = chunk.token_start_idx, chunk.token_end_idx do
      if cache.tokens[i] then
        table.insert(result, cache.tokens[i])
      end
    end
    return result
  end

  -- Fallback: return all tokens (caller should filter by position)
  return cache.tokens
end

return StatementCache
