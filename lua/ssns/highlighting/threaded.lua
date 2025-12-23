---@class ThreadedHighlighting
---Async highlighting coordinator that offloads tokenization/classification to worker threads
---Prevents UI blocking on large SQL files
---Falls back to sync highlighting if threading unavailable
local ThreadedHighlighting = {}

local Coordinator = require('ssns.async.thread.coordinator')

---Active highlighting tasks per buffer
---@type table<number, string>
local active_tasks = {}

---Check if threaded highlighting is available
---@return boolean
function ThreadedHighlighting.is_available()
  return Coordinator.is_available()
end

---Cancel any active threaded highlighting for a buffer
---@param bufnr number Buffer number
function ThreadedHighlighting.cancel(bufnr)
  local task_id = active_tasks[bufnr]
  if task_id then
    Coordinator.cancel(task_id, "Buffer changed")
    active_tasks[bufnr] = nil
  end
end

---Get classified tokens asynchronously using worker thread
---@param bufnr number Buffer number
---@param text string SQL text to tokenize and classify
---@param on_complete fun(tokens: table[]?, error: string?) Callback with classified tokens
---@param on_progress fun(pct: number, message: string?)? Optional progress callback
---@return boolean started True if threaded tokenization was started
function ThreadedHighlighting.tokenize_async(bufnr, text, on_complete, on_progress)
  -- Cancel any existing task for this buffer
  ThreadedHighlighting.cancel(bufnr)

  -- Check if threading is available
  if not ThreadedHighlighting.is_available() then
    return false
  end

  -- Start threaded tokenization
  local task_id, err = Coordinator.start({
    worker = "sql_highlighting",
    input = {
      text = text,
      options = {
        batch_interval_ms = 50,
        progress_interval = 10,
      },
    },
    on_progress = function(pct, message)
      if on_progress then
        on_progress(pct, message)
      end
    end,
    on_complete = function(result, error_msg)
      -- Clear active task
      active_tasks[bufnr] = nil

      if error_msg then
        on_complete(nil, error_msg)
      elseif result and result.tokens then
        on_complete(result.tokens, nil)
      elseif result and result.cancelled then
        -- Cancelled, don't call callback
      else
        on_complete(nil, "No tokens returned")
      end
    end,
    timeout_ms = 30000, -- 30 second timeout for highlighting
  })

  if not task_id then
    return false
  end

  active_tasks[bufnr] = task_id
  return true
end

---Perform threaded highlighting update
---@param bufnr number Buffer number
---@param on_complete fun(success: boolean, error: string?)? Optional callback on completion
function ThreadedHighlighting.update(bufnr, on_complete)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    if on_complete then on_complete(false, "Invalid buffer") end
    return
  end

  local Config = require('ssns.config')
  local config = Config.get_semantic_highlighting()

  if not config.enabled then
    if on_complete then on_complete(false, "Highlighting disabled") end
    return
  end

  -- Get buffer text
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, '\n')

  if text == "" then
    if on_complete then on_complete(true, nil) end
    return
  end

  -- Try threaded tokenization
  local started = ThreadedHighlighting.tokenize_async(bufnr, text, function(tokens, err)
    if err then
      if on_complete then on_complete(false, err) end
      return
    end

    if not tokens or #tokens == 0 then
      if on_complete then on_complete(true, nil) end
      return
    end

    -- Apply highlights on main thread
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        if on_complete then on_complete(false, "Buffer became invalid") end
        return
      end

      local SemanticHighlighter = require('ssns.highlighting.semantic')
      SemanticHighlighter._apply_highlights(bufnr, tokens, lines)

      if on_complete then on_complete(true, nil) end
    end)
  end)

  if not started then
    -- Fall back to sync highlighting
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        local SemanticHighlighter = require('ssns.highlighting.semantic')
        SemanticHighlighter.update(bufnr)
      end
      if on_complete then on_complete(true, nil) end
    end)
  end
end

---Check if a buffer has an active threaded highlighting task
---@param bufnr number Buffer number
---@return boolean
function ThreadedHighlighting.is_active(bufnr)
  return active_tasks[bufnr] ~= nil
end

---Clean up all active tasks (for shutdown)
function ThreadedHighlighting.cleanup_all()
  for bufnr, _ in pairs(active_tasks) do
    ThreadedHighlighting.cancel(bufnr)
  end
end

return ThreadedHighlighting
