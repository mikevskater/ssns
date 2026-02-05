---@class KeymapManager
---Centralized keymap management for SSNS plugin
---Handles saving/restoring conflicting keymaps and provides unified keymap API
local KeymapManager = {}

---@class SavedKeymap
---@field mode string The mode (n, v, i, etc.)
---@field lhs string The key sequence
---@field rhs string|function The mapping target
---@field opts table The mapping options
---@field is_global boolean Whether this was a global mapping

---@class BufferKeymapState
---@field saved_keymaps SavedKeymap[] Array of saved keymaps to restore
---@field active_groups string[] Array of active keymap group names

---Storage for saved keymaps per buffer
---@type table<number, BufferKeymapState>
local buffer_states = {}

---Storage for saved global keymaps (not buffer-specific)
---@type SavedKeymap[]
local saved_global_keymaps = {}

---Track which buffers have auto-restore setup
---@type table<number, boolean>
local auto_restore_setup = {}

-- ============================================================================
-- Internal Helpers
-- ============================================================================

---Get existing keymap for a buffer (or global if bufnr is nil/0)
---@param mode string The mode to check
---@param lhs string The key sequence
---@param bufnr number? Buffer number (nil or 0 for global)
---@return table? keymap The existing keymap or nil
local function get_existing_keymap(mode, lhs, bufnr)
  local keymaps
  if bufnr and bufnr > 0 then
    -- Buffer-local keymaps
    keymaps = vim.api.nvim_buf_get_keymap(bufnr, mode)
  else
    -- Global keymaps
    keymaps = vim.api.nvim_get_keymap(mode)
  end

  for _, km in ipairs(keymaps) do
    if km.lhs == lhs then
      return km
    end
  end
  return nil
end

---Convert nvim keymap table to SavedKeymap format
---@param km table The keymap from nvim API
---@param is_global boolean Whether this is a global keymap
---@return SavedKeymap
local function keymap_to_saved(km, is_global)
  return {
    mode = km.mode,
    lhs = km.lhs,
    rhs = km.rhs or km.callback,
    opts = {
      noremap = km.noremap == 1,
      silent = km.silent == 1,
      expr = km.expr == 1,
      nowait = km.nowait == 1,
      script = km.script == 1,
      desc = km.desc,
      callback = km.callback,
    },
    is_global = is_global,
  }
end

---Restore a single keymap
---@param saved SavedKeymap The saved keymap to restore
---@param bufnr number? Buffer number (nil for global)
local function restore_single_keymap(saved, bufnr)
  local opts = vim.tbl_extend("force", {}, saved.opts)

  -- Handle callback vs string rhs
  if opts.callback then
    opts.callback = saved.rhs
    if saved.is_global or not bufnr or bufnr == 0 then
      vim.keymap.set(saved.mode, saved.lhs, saved.rhs, opts)
    else
      opts.buffer = bufnr
      vim.keymap.set(saved.mode, saved.lhs, saved.rhs, opts)
    end
  else
    if saved.is_global or not bufnr or bufnr == 0 then
      vim.api.nvim_set_keymap(saved.mode, saved.lhs, saved.rhs or "", opts)
    else
      vim.api.nvim_buf_set_keymap(bufnr, saved.mode, saved.lhs, saved.rhs or "", opts)
    end
  end
end

---Delete a keymap
---@param mode string The mode
---@param lhs string The key sequence
---@param bufnr number? Buffer number (nil for global)
local function delete_keymap(mode, lhs, bufnr)
  local ok
  if bufnr and bufnr > 0 then
    ok = pcall(vim.api.nvim_buf_del_keymap, bufnr, mode, lhs)
  else
    ok = pcall(vim.api.nvim_del_keymap, mode, lhs)
  end
  return ok
end

-- ============================================================================
-- Public API
-- ============================================================================

---Initialize state for a buffer
---@param bufnr number Buffer number
function KeymapManager.init_buffer(bufnr)
  if not buffer_states[bufnr] then
    buffer_states[bufnr] = {
      saved_keymaps = {},
      active_groups = {},
    }
  end
end

---Save conflicting keymaps before overriding them
---@param bufnr number Buffer number
---@param keys table Array of {mode, lhs} pairs to check for conflicts
---@param check_global boolean? Also check and save global keymaps (default: true)
function KeymapManager.save_conflicts(bufnr, keys, check_global)
  if check_global == nil then
    check_global = true
  end

  KeymapManager.init_buffer(bufnr)
  local state = buffer_states[bufnr]

  for _, key in ipairs(keys) do
    local mode = key[1] or key.mode or "n"
    local lhs = key[2] or key.lhs

    -- Check buffer-local keymap first
    local existing = get_existing_keymap(mode, lhs, bufnr)
    if existing then
      table.insert(state.saved_keymaps, keymap_to_saved(existing, false))
    elseif check_global then
      -- Check global keymap
      local global_existing = get_existing_keymap(mode, lhs, nil)
      if global_existing then
        -- Save to global storage and buffer state
        local saved = keymap_to_saved(global_existing, true)
        table.insert(state.saved_keymaps, saved)
        table.insert(saved_global_keymaps, saved)
      end
    end
  end
end

---Restore all saved keymaps for a buffer
---@param bufnr number Buffer number
function KeymapManager.restore(bufnr)
  local state = buffer_states[bufnr]
  if not state then
    return
  end

  -- Restore saved keymaps
  for _, saved in ipairs(state.saved_keymaps) do
    if saved.is_global then
      -- Restore global keymap
      restore_single_keymap(saved, nil)
      -- Remove from global saved list
      for i, gsaved in ipairs(saved_global_keymaps) do
        if gsaved.mode == saved.mode and gsaved.lhs == saved.lhs then
          table.remove(saved_global_keymaps, i)
          break
        end
      end
    else
      -- Restore buffer-local keymap (only if buffer still valid)
      if vim.api.nvim_buf_is_valid(bufnr) then
        restore_single_keymap(saved, bufnr)
      end
    end
  end

  -- Clean up state
  buffer_states[bufnr] = nil
  auto_restore_setup[bufnr] = nil
end

---Setup autocmd to automatically restore keymaps when buffer is closed
---@param bufnr number Buffer number
function KeymapManager.setup_auto_restore(bufnr)
  if auto_restore_setup[bufnr] then
    return  -- Already setup
  end

  auto_restore_setup[bufnr] = true

  vim.api.nvim_create_autocmd({"BufWipeout", "BufDelete"}, {
    buffer = bufnr,
    once = true,
    callback = function()
      KeymapManager.restore(bufnr)
    end,
    desc = "SSNS: Restore keymaps on buffer close",
  })
end

---Set a single keymap with conflict handling
---@param bufnr number Buffer number
---@param mode string The mode (n, v, i, etc.)
---@param lhs string The key sequence
---@param rhs string|function The mapping target
---@param opts table? Additional options
---@param save_conflict boolean? Save conflicting keymap (default: true)
function KeymapManager.set(bufnr, mode, lhs, rhs, opts, save_conflict)
  opts = opts or {}
  if save_conflict == nil then
    save_conflict = true
  end

  -- Save conflict if requested
  if save_conflict then
    KeymapManager.save_conflicts(bufnr, {{mode, lhs}}, true)
  end

  -- Set the keymap
  local keymap_opts = vim.tbl_extend("force", {
    noremap = true,
    silent = true,
    buffer = bufnr,
  }, opts)

  vim.keymap.set(mode, lhs, rhs, keymap_opts)
end

---Set multiple keymaps from a definition table
---@param bufnr number Buffer number
---@param keymaps table Array of keymap definitions {mode, lhs, rhs, opts?, desc?}
---@param save_conflicts boolean? Save conflicting keymaps (default: true)
function KeymapManager.set_multiple(bufnr, keymaps, save_conflicts)
  if save_conflicts == nil then
    save_conflicts = true
  end

  -- Collect all keys for conflict saving
  if save_conflicts then
    local keys = {}
    for _, km in ipairs(keymaps) do
      table.insert(keys, {km.mode or "n", km.lhs or km[1]})
    end
    KeymapManager.save_conflicts(bufnr, keys, true)
  end

  -- Set all keymaps
  for _, km in ipairs(keymaps) do
    local mode = km.mode or "n"
    local lhs = km.lhs or km[1]
    local rhs = km.rhs or km[2]
    local opts = km.opts or {}

    if km.desc then
      opts.desc = km.desc
    end

    local keymap_opts = vim.tbl_extend("force", {
      noremap = true,
      silent = true,
      buffer = bufnr,
    }, opts)

    vim.keymap.set(mode, lhs, rhs, keymap_opts)
  end

  -- Setup auto-restore
  KeymapManager.setup_auto_restore(bufnr)
end

---Delete a keymap set by this manager (does not restore original)
---@param bufnr number Buffer number
---@param mode string The mode
---@param lhs string The key sequence
function KeymapManager.del(bufnr, mode, lhs)
  delete_keymap(mode, lhs, bufnr)
end

---Get a keymap value from config
---@param group string The keymap group (tree, query, history, filter, param, add_server, common)
---@param action string The action name within the group
---@param default string? Default value if not configured
---@return string key The configured key or default
function KeymapManager.get(group, action, default)
  local Config = require('nvim-ssns.config')
  local keymaps = Config.get_keymaps()

  -- Check group-specific keymaps first
  if keymaps[group] and keymaps[group][action] then
    return keymaps[group][action]
  end

  -- Check common keymaps as fallback
  if keymaps.common and keymaps.common[action] then
    return keymaps.common[action]
  end

  return default or ""
end

---Get all keymaps for a group
---@param group string The keymap group name
---@return table keymaps Table of action -> key mappings
function KeymapManager.get_group(group)
  local Config = require('nvim-ssns.config')
  local keymaps = Config.get_keymaps()

  -- Merge common keymaps with group-specific
  local result = {}

  -- Add common keymaps first
  if keymaps.common then
    for action, key in pairs(keymaps.common) do
      result[action] = key
    end
  end

  -- Override with group-specific
  if keymaps[group] then
    for action, key in pairs(keymaps[group]) do
      result[action] = key
    end
  end

  return result
end

---Check if a buffer has active SSNS keymaps
---@param bufnr number Buffer number
---@return boolean has_keymaps
function KeymapManager.has_keymaps(bufnr)
  return buffer_states[bufnr] ~= nil
end

---Get list of active keymap groups for a buffer
---@param bufnr number Buffer number
---@return string[] groups
function KeymapManager.get_active_groups(bufnr)
  local state = buffer_states[bufnr]
  if state then
    return state.active_groups
  end
  return {}
end

---Mark a keymap group as active for a buffer
---@param bufnr number Buffer number
---@param group string Group name
function KeymapManager.mark_group_active(bufnr, group)
  KeymapManager.init_buffer(bufnr)
  local state = buffer_states[bufnr]
  if not vim.tbl_contains(state.active_groups, group) then
    table.insert(state.active_groups, group)
  end
end

---Clean up all state (for plugin unload)
function KeymapManager.cleanup_all()
  -- Restore all buffer keymaps
  for bufnr, _ in pairs(buffer_states) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      KeymapManager.restore(bufnr)
    end
  end

  -- Restore any remaining global keymaps
  for _, saved in ipairs(saved_global_keymaps) do
    restore_single_keymap(saved, nil)
  end

  buffer_states = {}
  saved_global_keymaps = {}
  auto_restore_setup = {}
end

---Generate help text for a keymap group
---@param group string The keymap group name
---@param descriptions table? Optional table of action -> description
---@return string[] lines Help text lines
function KeymapManager.generate_help(group, descriptions)
  descriptions = descriptions or {}
  local keymaps = KeymapManager.get_group(group)
  local lines = {}

  -- Sort by action name
  local actions = {}
  for action, _ in pairs(keymaps) do
    table.insert(actions, action)
  end
  table.sort(actions)

  -- Generate help lines
  for _, action in ipairs(actions) do
    local key = keymaps[action]
    local desc = descriptions[action] or action:gsub("_", " ")
    table.insert(lines, string.format("  %-12s  %s", key, desc))
  end

  return lines
end

return KeymapManager
