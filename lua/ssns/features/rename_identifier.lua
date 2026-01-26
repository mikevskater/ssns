---Rename identifier module for SSNS
---Provides SSMS-style F2 rename functionality that highlights all instances
---of an identifier and updates them in real-time as the user edits.
---@class RenameIdentifier
local RenameIdentifier = {}

local StatementCache = require('ssns.completion.statement_cache')
local Navigation = require('ssns.completion.tokens.navigation')

-- Namespace for extmarks
local ns_id = vim.api.nvim_create_namespace('ssns_rename_identifier')

-- Highlight groups
local HIGHLIGHT_GROUP = 'SSNSRename'
local HIGHLIGHT_GROUP_EDITING = 'SSNSRenameEditing'

---@alias IdentifierType "parameter"|"temp_table"|"table_alias"|"column_alias"|"column"

---@class RenameOccurrence
---@field line number 1-indexed line
---@field start_col number 1-indexed start column
---@field end_col number 1-indexed end column (inclusive)
---@field is_bracketed boolean Whether this occurrence is bracketed

---@class RenameSession
---@field bufnr number Buffer number
---@field winid number Window ID
---@field identifier string Original identifier text (without brackets)
---@field identifier_type IdentifierType Type of identifier
---@field scope "buffer"|"statement"|"subquery" Scope for renaming
---@field scope_start_line number? For statement/subquery scope
---@field scope_end_line number? For statement/subquery scope
---@field occurrences RenameOccurrence[] Array of occurrences
---@field editing_idx number Which occurrence is being edited (1-indexed)
---@field edit_line number Line being edited (1-indexed)
---@field edit_start_col number Start column of editing word (1-indexed)
---@field original_texts table<number, string> Original line texts for rollback
---@field original_cursor table {row, col} Original cursor position
---@field is_active boolean Whether session is active
---@field is_syncing boolean Flag to prevent recursive sync
---@field last_text string Last known text at editing position
---@field augroup number? Autocmd group ID
---@field saved_keymaps table? Saved keymaps to restore

---@type RenameSession?
local active_session = nil

-- ============================================================================
-- Highlight Setup
-- ============================================================================

local function setup_highlights()
  if vim.fn.hlexists(HIGHLIGHT_GROUP) == 0 then
    vim.api.nvim_set_hl(0, HIGHLIGHT_GROUP, { link = 'Search' })
  end
  if vim.fn.hlexists(HIGHLIGHT_GROUP_EDITING) == 0 then
    vim.api.nvim_set_hl(0, HIGHLIGHT_GROUP_EDITING, { link = 'IncSearch' })
  end
end

-- ============================================================================
-- Identifier Helpers
-- ============================================================================

---@param token Token
---@return string
local function extract_identifier_text(token)
  local text = token.text
  if token.type == "bracket_id" then
    text = text:sub(2, -2)
  end
  return text
end

---@param token Token
---@param bufnr number
---@param line number
---@param col number
---@return IdentifierType?, string?, number?, number?
local function classify_identifier(token, bufnr, line, col)
  local identifier_text = extract_identifier_text(token)
  local identifier_lower = identifier_text:lower()

  if token.type == "variable" then
    return "parameter", "buffer", nil, nil
  end

  if token.type == "temp_table" then
    return "temp_table", "buffer", nil, nil
  end

  if token.type ~= "identifier" and token.type ~= "bracket_id" then
    return nil, nil, nil, nil
  end

  local context = StatementCache.get_context_at_position(bufnr, line, col)
  if not context then
    return "column", "buffer", nil, nil
  end

  local chunk = context.chunk
  local subquery = context.subquery

  if context.aliases then
    for alias_name, _ in pairs(context.aliases) do
      if alias_name:lower() == identifier_lower then
        if subquery then
          local start_line = subquery.start_pos and subquery.start_pos.line
          local end_line = subquery.end_pos and subquery.end_pos.line
          return "table_alias", "subquery", start_line, end_line
        elseif chunk then
          return "table_alias", "statement", chunk.start_line, chunk.end_line
        end
        return "table_alias", "buffer", nil, nil
      end
    end
  end

  if chunk and chunk.columns then
    for _, col_info in ipairs(chunk.columns) do
      if col_info.alias and col_info.alias:lower() == identifier_lower then
        return "column_alias", "buffer", nil, nil
      end
    end
  end

  return "column", "buffer", nil, nil
end

---@param tokens Token[]
---@param identifier string
---@param token_types table<string, boolean>
---@param scope_start number?
---@param scope_end number?
---@return RenameOccurrence[]
local function find_matching_tokens(tokens, identifier, token_types, scope_start, scope_end)
  local occurrences = {}
  local identifier_lower = identifier:lower()

  for _, token in ipairs(tokens) do
    if not token_types[token.type] then goto continue end
    if scope_start and token.line < scope_start then goto continue end
    if scope_end and token.line > scope_end then goto continue end

    local token_text = extract_identifier_text(token)
    if token_text:lower() == identifier_lower then
      table.insert(occurrences, {
        line = token.line,
        start_col = token.col,
        end_col = token.col + #token.text - 1,
        is_bracketed = token.type == "bracket_id",
      })
    end
    ::continue::
  end

  return occurrences
end

---@param identifier_type IdentifierType
---@return table<string, boolean>
local function get_token_types_for_identifier(identifier_type)
  if identifier_type == "parameter" then
    return { variable = true }
  elseif identifier_type == "temp_table" then
    return { temp_table = true }
  else
    return { identifier = true, bracket_id = true }
  end
end

-- ============================================================================
-- Extmark Management
-- ============================================================================

---@param session RenameSession
local function update_extmarks(session)
  vim.api.nvim_buf_clear_namespace(session.bufnr, ns_id, 0, -1)

  local current_text = session.last_text

  for i, occ in ipairs(session.occurrences) do
    local hl = (i == session.editing_idx) and HIGHLIGHT_GROUP_EDITING or HIGHLIGHT_GROUP
    local display_text = occ.is_bracketed and ("[" .. current_text .. "]") or current_text
    local end_col = occ.start_col + #display_text - 1

    pcall(vim.api.nvim_buf_set_extmark, session.bufnr, ns_id, occ.line - 1, occ.start_col - 1, {
      end_row = occ.line - 1,
      end_col = end_col,
      hl_group = hl,
      priority = 1000,
    })
  end
end

---@param session RenameSession
local function clear_extmarks(session)
  pcall(vim.api.nvim_buf_clear_namespace, session.bufnr, ns_id, 0, -1)
end

-- ============================================================================
-- Text Operations
-- ============================================================================

---@param session RenameSession
---@return string?
local function get_current_editing_text(session)
  local lines = vim.api.nvim_buf_get_lines(session.bufnr, session.edit_line - 1, session.edit_line, false)
  if not lines or not lines[1] then return nil end

  local line = lines[1]
  local editing_occ = session.occurrences[session.editing_idx]
  local start_col = session.edit_start_col

  if editing_occ.is_bracketed then
    local text_start = start_col + 1
    local bracket_end = line:find("%]", text_start)
    if bracket_end then
      return line:sub(text_start, bracket_end - 1)
    end
    local cursor = vim.api.nvim_win_get_cursor(0)
    return line:sub(text_start, cursor[2])
  else
    local text = ""
    local i = start_col
    while i <= #line do
      local char = line:sub(i, i)
      if char:match("[%w_@#]") then
        text = text .. char
        i = i + 1
      else
        break
      end
    end
    return text
  end
end

---@param session RenameSession
---@param new_text string
local function sync_to_others(session, new_text)
  if session.is_syncing then return end
  session.is_syncing = true

  local to_update = {}
  for i, occ in ipairs(session.occurrences) do
    if i ~= session.editing_idx then
      table.insert(to_update, { idx = i, occ = occ })
    end
  end

  table.sort(to_update, function(a, b)
    if a.occ.line ~= b.occ.line then
      return a.occ.line > b.occ.line
    end
    return a.occ.start_col > b.occ.start_col
  end)

  for _, item in ipairs(to_update) do
    local occ = item.occ
    local formatted = occ.is_bracketed and ("[" .. new_text .. "]") or new_text

    local lines = vim.api.nvim_buf_get_lines(session.bufnr, occ.line - 1, occ.line, false)
    if lines and lines[1] then
      local line_text = lines[1]
      local new_line = line_text:sub(1, occ.start_col - 1) .. formatted .. line_text:sub(occ.end_col + 1)
      vim.api.nvim_buf_set_lines(session.bufnr, occ.line - 1, occ.line, false, { new_line })
      occ.end_col = occ.start_col + #formatted - 1
    end
  end

  session.last_text = new_text
  session.is_syncing = false
end

-- ============================================================================
-- Completion Control
-- ============================================================================

---Disable completion plugins during rename
---@param bufnr number
local function disable_completion(bufnr)
  -- Set buffer-local flag (SSNS completion checks this)
  vim.b[bufnr].ssns_rename_active = true

  -- Try to disable blink.cmp if available
  local ok, blink = pcall(require, 'blink.cmp')
  if ok and blink then
    -- blink.cmp v0.5+ has a way to check enabled state
    -- We'll use buffer-local variable that blink respects
    vim.b[bufnr].completion = false
  end

  -- Also disable nvim-cmp if present
  local cmp_ok, cmp = pcall(require, 'cmp')
  if cmp_ok and cmp then
    pcall(function()
      cmp.setup.buffer({ enabled = false })
    end)
  end
end

---Re-enable completion plugins after rename
---@param bufnr number
local function enable_completion(bufnr)
  vim.b[bufnr].ssns_rename_active = nil
  vim.b[bufnr].completion = nil

  -- Re-enable nvim-cmp if present
  local cmp_ok, cmp = pcall(require, 'cmp')
  if cmp_ok and cmp then
    pcall(function()
      cmp.setup.buffer({ enabled = true })
    end)
  end
end

-- ============================================================================
-- Session Lifecycle
-- ============================================================================

-- Forward declaration
local end_session

---@param session RenameSession
---@return boolean
local function is_cursor_out_of_bounds(session)
  local ok, cursor = pcall(vim.api.nvim_win_get_cursor, session.winid)
  if not ok then return true end

  local cursor_line = cursor[1]
  local cursor_col = cursor[2] + 1

  if cursor_line ~= session.edit_line then
    return true
  end

  local editing_occ = session.occurrences[session.editing_idx]
  local current_text = session.last_text
  local display_len = editing_occ.is_bracketed and (#current_text + 2) or #current_text
  local word_start = session.edit_start_col
  local word_end = word_start + display_len - 1

  local min_col = word_start - 2
  local max_col = word_end + 2

  return cursor_col < min_col or cursor_col > max_col
end

---@param session RenameSession
local function on_text_changed(session)
  if not session.is_active or session.is_syncing then return end

  local new_text = get_current_editing_text(session)
  if new_text and new_text ~= session.last_text then
    sync_to_others(session, new_text)
    update_extmarks(session)
  end
end

---@param session RenameSession
local function on_cursor_moved(session)
  if not session.is_active then return end

  if is_cursor_out_of_bounds(session) then
    end_session(session, false)
  end
end

---@param session RenameSession
local function restore_keymaps(session)
  if session.saved_keymaps then
    for _, km in ipairs(session.saved_keymaps) do
      if km.rhs then
        vim.keymap.set(km.mode, km.lhs, km.rhs, {
          buffer = session.bufnr,
          silent = km.silent,
          expr = km.expr,
          nowait = km.nowait,
        })
      else
        pcall(vim.keymap.del, km.mode, km.lhs, { buffer = session.bufnr })
      end
    end
    session.saved_keymaps = nil
  end
end

---@param session RenameSession
---@param cancelled boolean
end_session = function(session, cancelled)
  if not session.is_active then return end
  session.is_active = false

  -- Remove autocmds
  if session.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, session.augroup)
    session.augroup = nil
  end

  -- Clear extmarks
  clear_extmarks(session)

  -- Restore keymaps
  restore_keymaps(session)

  -- Re-enable completion
  enable_completion(session.bufnr)

  -- Exit insert mode
  local mode = vim.api.nvim_get_mode().mode
  if mode:match('^i') or mode:match('^R') then
    -- Use feedkeys to properly exit insert mode
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-\\><C-n>', true, false, true), 'n', false)
  end

  if cancelled then
    -- Restore original texts
    if session.original_texts then
      local lines_to_restore = {}
      for line_num, _ in pairs(session.original_texts) do
        table.insert(lines_to_restore, line_num)
      end
      table.sort(lines_to_restore, function(a, b) return a > b end)

      for _, line_num in ipairs(lines_to_restore) do
        local original = session.original_texts[line_num]
        vim.api.nvim_buf_set_lines(session.bufnr, line_num - 1, line_num, false, { original })
      end
    end

    pcall(vim.api.nvim_win_set_cursor, 0, session.original_cursor)
    vim.notify("Rename cancelled", vim.log.levels.INFO)
  else
    local count = #session.occurrences
    local final_text = session.last_text
    if final_text and final_text ~= "" and final_text ~= session.identifier then
      vim.notify(string.format("Renamed '%s' → '%s' (%d occurrences)",
        session.identifier, final_text, count), vim.log.levels.INFO)
    else
      vim.notify(string.format("Rename completed (%d occurrences)", count), vim.log.levels.INFO)
    end
  end

  active_session = nil
end

---@param session RenameSession
local function setup_keymaps(session)
  -- Save existing keymaps
  session.saved_keymaps = {}

  local keys_to_override = { '<Esc>', '<CR>' }
  for _, key in ipairs(keys_to_override) do
    local existing = vim.fn.maparg(key, 'i', false, true)
    if existing and existing.buffer == 1 then
      table.insert(session.saved_keymaps, {
        mode = 'i',
        lhs = key,
        rhs = existing.rhs or existing.callback,
        silent = existing.silent == 1,
        expr = existing.expr == 1,
        nowait = existing.nowait == 1,
      })
    else
      table.insert(session.saved_keymaps, { mode = 'i', lhs = key, rhs = nil })
    end
  end

  -- Set our keymaps
  vim.keymap.set('i', '<Esc>', function()
    end_session(session, true)
  end, { buffer = session.bufnr, silent = true, nowait = true })

  vim.keymap.set('i', '<CR>', function()
    end_session(session, false)
  end, { buffer = session.bufnr, silent = true, nowait = true })
end

---@param session RenameSession
local function setup_autocmds(session)
  session.augroup = vim.api.nvim_create_augroup('ssns_rename_' .. session.bufnr .. '_' .. os.time(), { clear = true })

  -- Text changes
  vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChangedP' }, {
    group = session.augroup,
    buffer = session.bufnr,
    callback = function()
      on_text_changed(session)
    end,
  })

  -- Cursor movement (with small delay to avoid triggering on initial cursor placement)
  local cursor_check_enabled = false
  vim.defer_fn(function()
    cursor_check_enabled = true
  end, 50)

  vim.api.nvim_create_autocmd('CursorMovedI', {
    group = session.augroup,
    buffer = session.bufnr,
    callback = function()
      if not cursor_check_enabled then return end
      vim.schedule(function()
        on_cursor_moved(session)
      end)
    end,
  })

  -- Buffer leave
  vim.api.nvim_create_autocmd('BufLeave', {
    group = session.augroup,
    buffer = session.bufnr,
    callback = function()
      if session.is_active then
        end_session(session, false)
      end
    end,
  })

  -- Mode change (leaving insert mode by other means)
  vim.api.nvim_create_autocmd('ModeChanged', {
    group = session.augroup,
    pattern = 'i:*',
    callback = function()
      -- Check if we're still in the right buffer
      if vim.api.nvim_get_current_buf() ~= session.bufnr then return end
      vim.schedule(function()
        if session.is_active then
          end_session(session, false)
        end
      end)
    end,
  })
end

---@param session RenameSession
local function enter_rename_mode(session)
  setup_highlights()

  -- Disable completion during rename
  disable_completion(session.bufnr)

  -- Store original texts
  session.original_texts = {}
  local seen_lines = {}
  for _, occ in ipairs(session.occurrences) do
    if not seen_lines[occ.line] then
      local lines = vim.api.nvim_buf_get_lines(session.bufnr, occ.line - 1, occ.line, false)
      if lines and lines[1] then
        session.original_texts[occ.line] = lines[1]
      end
      seen_lines[occ.line] = true
    end
  end

  -- Find editing occurrence
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1]
  local cursor_col = cursor[2] + 1

  session.editing_idx = 1
  for i, occ in ipairs(session.occurrences) do
    if occ.line == cursor_line and cursor_col >= occ.start_col and cursor_col <= occ.end_col then
      session.editing_idx = i
      break
    end
  end

  local editing_occ = session.occurrences[session.editing_idx]
  session.edit_line = editing_occ.line
  session.edit_start_col = editing_occ.start_col
  session.last_text = session.identifier
  session.winid = vim.api.nvim_get_current_win()

  -- Create extmarks
  update_extmarks(session)

  session.is_active = true
  active_session = session

  -- Setup keymaps BEFORE entering insert mode
  setup_keymaps(session)
  setup_autocmds(session)

  -- Position cursor at end of identifier and enter insert mode
  -- end_col is 1-indexed inclusive, nvim_win_set_cursor uses 0-indexed column
  -- So end_col as 0-indexed puts cursor right AFTER the word
  local cursor_col = editing_occ.end_col
  if editing_occ.is_bracketed then
    cursor_col = cursor_col - 1  -- Before the closing ]
  end
  vim.api.nvim_win_set_cursor(0, { editing_occ.line, cursor_col })

  -- Enter insert mode AT cursor position (not append mode)
  vim.cmd('startinsert')

  local scope_desc = session.scope == "buffer" and "buffer-wide" or
    string.format("lines %d-%d", session.scope_start_line or 0, session.scope_end_line or 0)
  vim.notify(string.format("Renaming '%s' (%d occurrences, %s) - Enter to confirm, Esc to cancel",
    session.identifier, #session.occurrences, scope_desc), vim.log.levels.INFO)
end

-- ============================================================================
-- Public API
-- ============================================================================

function RenameIdentifier.start_rename()
  if active_session and active_session.is_active then
    end_session(active_session, true)
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2] + 1

  local tokens = StatementCache.get_tokens(bufnr)
  if not tokens or #tokens == 0 then
    vim.notify("No tokens found in buffer", vim.log.levels.WARN)
    return
  end

  local token, _ = Navigation.get_token_at_position(tokens, line, col)
  if not token then
    vim.notify("No identifier under cursor", vim.log.levels.WARN)
    return
  end

  local valid_types = {
    identifier = true,
    bracket_id = true,
    variable = true,
    temp_table = true,
  }
  if not valid_types[token.type] then
    vim.notify(string.format("Cannot rename token type: %s", token.type), vim.log.levels.WARN)
    return
  end

  local identifier_text = extract_identifier_text(token)
  local identifier_type, scope, scope_start, scope_end = classify_identifier(token, bufnr, line, col)
  if not identifier_type then
    vim.notify("Cannot determine identifier type", vim.log.levels.WARN)
    return
  end

  local token_types = get_token_types_for_identifier(identifier_type)
  local occurrences = find_matching_tokens(tokens, identifier_text, token_types, scope_start, scope_end)

  if #occurrences == 0 then
    vim.notify("No occurrences found", vim.log.levels.WARN)
    return
  end

  ---@type RenameSession
  local session = {
    bufnr = bufnr,
    winid = vim.api.nvim_get_current_win(),
    identifier = identifier_text,
    identifier_type = identifier_type,
    scope = scope,
    scope_start_line = scope_start,
    scope_end_line = scope_end,
    occurrences = occurrences,
    editing_idx = 1,
    edit_line = 0,
    edit_start_col = 0,
    original_texts = {},
    original_cursor = cursor,
    is_active = false,
    is_syncing = false,
    last_text = identifier_text,
  }

  enter_rename_mode(session)
end

---@return boolean
function RenameIdentifier.is_active()
  return active_session ~= nil and active_session.is_active
end

function RenameIdentifier.cancel()
  if active_session and active_session.is_active then
    end_session(active_session, true)
  end
end

function RenameIdentifier.confirm()
  if active_session and active_session.is_active then
    end_session(active_session, false)
  end
end

return RenameIdentifier
