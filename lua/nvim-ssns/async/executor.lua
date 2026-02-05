---Async task executor with spinner and cancellation support
---@class ExecutorModule
local Executor = {}

local Cancellation = require('nvim-ssns.async.cancellation')
local Spinner = require('nvim-ssns.async.spinner')
local Progress = require('nvim-ssns.async.progress')

---@class AsyncTask
---@field id string Unique task identifier
---@field name string Human-readable task name
---@field status "pending"|"running"|"completed"|"cancelled"|"error" Task status
---@field progress number? Progress 0-100 for trackable operations
---@field result any? Task result when completed
---@field error string? Error message if failed
---@field cancel_token CancellationToken Cancellation token
---@field started_at number? Start timestamp (vim.loop.hrtime)
---@field completed_at number? Completion timestamp
---@field spinner_id string? Associated spinner ID
---@field bufnr number? Associated buffer number

---Active tasks indexed by ID
---@type table<string, AsyncTask>
local active_tasks = {}

---Generate unique task ID
---@return string
local function generate_task_id()
  return string.format("task_%s_%d", os.time(), math.random(10000, 99999))
end

---@class TaskContext
---@field is_cancelled fun(): boolean Check if task is cancelled
---@field throw_if_cancelled fun() Throw if cancelled
---@field report_progress fun(pct: number, message: string?) Report progress
---@field cancel_token CancellationToken The cancellation token

---@class ExecutorOpts
---@field name string? Human-readable task name
---@field timeout_ms number? Timeout in milliseconds (default: 30000)
---@field on_progress fun(pct: number, message: string?)? Progress callback
---@field on_complete fun(result: any, error: string?)? Completion callback
---@field cancel_token CancellationToken? External cancellation token
---@field spinner boolean? Show spinner (default: false for headless)
---@field spinner_text string? Spinner display text

---Run a function asynchronously with optional spinner
---@param fn fun(ctx: TaskContext): any, string? Function to execute, returns (result, error?)
---@param opts ExecutorOpts? Options
---@return string task_id Task ID for tracking/cancellation
function Executor.run(fn, opts)
  opts = opts or {}

  local task_id = generate_task_id()
  local cancel_token = opts.cancel_token or Cancellation.create_token()

  ---@type AsyncTask
  local task = {
    id = task_id,
    name = opts.name or "Async Task",
    status = "pending",
    progress = nil,
    result = nil,
    error = nil,
    cancel_token = cancel_token,
    started_at = nil,
    completed_at = nil,
    spinner_id = nil,
    bufnr = nil,
  }

  active_tasks[task_id] = task

  -- Create task context for the function
  ---@type TaskContext
  local ctx = {
    is_cancelled = function()
      return cancel_token.is_cancelled
    end,
    throw_if_cancelled = function()
      cancel_token:throw_if_cancelled()
    end,
    report_progress = function(pct, message)
      task.progress = pct
      if opts.on_progress then
        opts.on_progress(pct, message)
      end
    end,
    cancel_token = cancel_token,
  }

  -- Set up timeout if specified
  local timeout_timer = nil
  if opts.timeout_ms and opts.timeout_ms > 0 then
    timeout_timer = vim.loop.new_timer()
    timeout_timer:start(opts.timeout_ms, 0, vim.schedule_wrap(function()
      if task.status == "running" then
        cancel_token:cancel("Operation timed out")
      end
      if timeout_timer then
        timeout_timer:stop()
        timeout_timer:close()
        timeout_timer = nil
      end
    end))
  end

  -- Use vim.schedule to run asynchronously
  vim.schedule(function()
    -- Check if already cancelled before starting
    if cancel_token.is_cancelled then
      task.status = "cancelled"
      task.error = cancel_token.reason
      task.completed_at = vim.loop.hrtime()

      if timeout_timer then
        timeout_timer:stop()
        timeout_timer:close()
      end

      if opts.on_complete then
        vim.schedule(function()
          opts.on_complete(nil, task.error)
        end)
      end

      -- Cleanup after delay
      vim.defer_fn(function()
        active_tasks[task_id] = nil
      end, 1000)

      return
    end

    task.status = "running"
    task.started_at = vim.loop.hrtime()

    -- Execute the function
    local success, result, err = pcall(fn, ctx)

    -- Stop timeout timer
    if timeout_timer then
      timeout_timer:stop()
      timeout_timer:close()
      timeout_timer = nil
    end

    task.completed_at = vim.loop.hrtime()

    if cancel_token.is_cancelled then
      task.status = "cancelled"
      task.error = cancel_token.reason or "Operation cancelled"
    elseif not success then
      -- pcall caught an error
      task.status = "error"
      if Cancellation.is_cancellation_error(result) then
        task.status = "cancelled"
        task.error = "Operation cancelled"
      else
        task.error = tostring(result)
      end
    elseif err then
      -- Function returned an error
      task.status = "error"
      task.error = tostring(err)
    else
      task.status = "completed"
      task.result = result
    end

    -- Invoke completion callback
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(task.result, task.error)
      end)
    end

    -- Cleanup after delay
    vim.defer_fn(function()
      active_tasks[task_id] = nil
    end, 5000)
  end)

  return task_id
end

---@class BufferExecutorOpts : ExecutorOpts
---@field line number? Line to show spinner on (default: 0)
---@field spinner_style string? Spinner animation style
---@field show_runtime boolean? Show runtime in spinner (default: true)
---@field hl_group string? Highlight group for spinner

---Run a function with a spinner displayed in a buffer
---@param bufnr number Buffer number to show spinner in
---@param fn fun(ctx: TaskContext): any, string? Function to execute
---@param opts BufferExecutorOpts? Options
---@return string task_id Task ID for tracking/cancellation
function Executor.run_in_buffer(bufnr, fn, opts)
  opts = opts or {}

  local task_id = generate_task_id()
  local cancel_token = opts.cancel_token or Cancellation.create_token()

  ---@type AsyncTask
  local task = {
    id = task_id,
    name = opts.name or "Async Task",
    status = "pending",
    progress = nil,
    result = nil,
    error = nil,
    cancel_token = cancel_token,
    started_at = nil,
    completed_at = nil,
    spinner_id = nil,
    bufnr = bufnr,
  }

  active_tasks[task_id] = task

  -- Start spinner in buffer
  local spinner_id = Spinner.start_in_buffer(bufnr, {
    text = opts.spinner_text or opts.name or "Loading...",
    style = opts.spinner_style or "braille",
    show_runtime = opts.show_runtime ~= false,
    line = opts.line or 0,
    hl_group = opts.hl_group or "Comment",
  })
  task.spinner_id = spinner_id

  -- Create task context
  ---@type TaskContext
  local ctx = {
    is_cancelled = function()
      return cancel_token.is_cancelled
    end,
    throw_if_cancelled = function()
      cancel_token:throw_if_cancelled()
    end,
    report_progress = function(pct, message)
      task.progress = pct
      if message then
        Spinner.update(spinner_id, message)
      end
      if opts.on_progress then
        opts.on_progress(pct, message)
      end
    end,
    cancel_token = cancel_token,
  }

  -- Set up timeout
  local timeout_timer = nil
  local timeout_ms = opts.timeout_ms or 30000
  if timeout_ms > 0 then
    timeout_timer = vim.loop.new_timer()
    timeout_timer:start(timeout_ms, 0, vim.schedule_wrap(function()
      if task.status == "running" then
        cancel_token:cancel("Operation timed out")
      end
      if timeout_timer then
        timeout_timer:stop()
        timeout_timer:close()
        timeout_timer = nil
      end
    end))
  end

  -- Execute asynchronously
  vim.schedule(function()
    -- Check if cancelled before starting
    if cancel_token.is_cancelled then
      Spinner.stop(spinner_id)
      task.status = "cancelled"
      task.error = cancel_token.reason
      task.completed_at = vim.loop.hrtime()

      if timeout_timer then
        timeout_timer:stop()
        timeout_timer:close()
      end

      if opts.on_complete then
        vim.schedule(function()
          opts.on_complete(nil, task.error)
        end)
      end

      vim.defer_fn(function()
        active_tasks[task_id] = nil
      end, 1000)

      return
    end

    task.status = "running"
    task.started_at = vim.loop.hrtime()

    -- Execute function
    local success, result, err = pcall(fn, ctx)

    -- Stop timeout timer
    if timeout_timer then
      timeout_timer:stop()
      timeout_timer:close()
      timeout_timer = nil
    end

    -- Stop spinner
    Spinner.stop(spinner_id)
    task.spinner_id = nil

    task.completed_at = vim.loop.hrtime()

    if cancel_token.is_cancelled then
      task.status = "cancelled"
      task.error = cancel_token.reason or "Operation cancelled"
    elseif not success then
      task.status = "error"
      if Cancellation.is_cancellation_error(result) then
        task.status = "cancelled"
        task.error = "Operation cancelled"
      else
        task.error = tostring(result)
      end
    elseif err then
      task.status = "error"
      task.error = tostring(err)
    else
      task.status = "completed"
      task.result = result
    end

    -- Invoke completion callback
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(task.result, task.error)
      end)
    end

    -- Cleanup after delay
    vim.defer_fn(function()
      active_tasks[task_id] = nil
    end, 5000)
  end)

  return task_id
end

---Cancel a running task
---@param task_id string Task ID
---@param reason string? Cancellation reason
---@return boolean success True if task was found and cancelled
function Executor.cancel(task_id, reason)
  local task = active_tasks[task_id]
  if not task then
    return false
  end

  if task.status ~= "pending" and task.status ~= "running" then
    return false -- Already completed/cancelled
  end

  task.cancel_token:cancel(reason or "Cancelled by user")

  -- Stop spinner if active
  if task.spinner_id then
    Spinner.stop(task.spinner_id)
    task.spinner_id = nil
  end

  return true
end

---Get task status
---@param task_id string Task ID
---@return AsyncTask? task Task object or nil if not found
function Executor.get_task(task_id)
  return active_tasks[task_id]
end

---Get all active tasks
---@return AsyncTask[] tasks
function Executor.get_active_tasks()
  local tasks = {}
  for _, task in pairs(active_tasks) do
    if task.status == "pending" or task.status == "running" then
      table.insert(tasks, task)
    end
  end
  return tasks
end

---Cancel all tasks in a buffer
---@param bufnr number Buffer number
---@param reason string? Cancellation reason
---@return number count Number of tasks cancelled
function Executor.cancel_all_in_buffer(bufnr, reason)
  local count = 0
  for task_id, task in pairs(active_tasks) do
    if task.bufnr == bufnr and (task.status == "pending" or task.status == "running") then
      if Executor.cancel(task_id, reason) then
        count = count + 1
      end
    end
  end
  return count
end

---Cancel all active tasks
---@param reason string? Cancellation reason
---@return number count Number of tasks cancelled
function Executor.cancel_all(reason)
  local count = 0
  for task_id, task in pairs(active_tasks) do
    if task.status == "pending" or task.status == "running" then
      if Executor.cancel(task_id, reason) then
        count = count + 1
      end
    end
  end
  return count
end

---Wait for a task to complete (blocking with timeout)
---Use sparingly - prefer callbacks for async patterns
---@param task_id string Task ID
---@param timeout_ms number? Timeout in milliseconds (default: 30000)
---@return any? result Task result
---@return string? error Error message if failed/cancelled/timeout
function Executor.wait(task_id, timeout_ms)
  timeout_ms = timeout_ms or 30000
  local task = active_tasks[task_id]

  if not task then
    return nil, "Task not found"
  end

  local start = vim.loop.hrtime()

  -- Poll for completion
  while task.status == "pending" or task.status == "running" do
    local elapsed = (vim.loop.hrtime() - start) / 1e6
    if elapsed > timeout_ms then
      return nil, "Wait timeout"
    end

    -- Small delay to avoid busy-waiting
    vim.wait(10, function()
      return task.status ~= "pending" and task.status ~= "running"
    end, 10)
  end

  if task.status == "completed" then
    return task.result, nil
  else
    return nil, task.error or task.status
  end
end

-- Re-export utilities for convenience
Executor.Cancellation = Cancellation
Executor.Spinner = Spinner
Executor.Progress = Progress

return Executor
