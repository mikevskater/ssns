---SSNS Async Module
---Provides non-blocking execution with spinners, progress tracking, and cancellation
---
---Usage:
---  local Async = require('nvim-ssns.async')
---
---  -- Run async with spinner in buffer
---  Async.run_in_buffer(bufnr, function(ctx)
---    ctx.report_progress(50, "Loading...")
---    if ctx.is_cancelled() then return nil end
---    return some_blocking_operation()
---  end, {
---    spinner_text = "Executing query...",
---    on_complete = function(result, err)
---      if err then print("Error:", err) end
---    end,
---  })
---
---  -- Create cancellation token
---  local token = Async.Cancellation.create_token()
---  token:on_cancel(function(reason) print("Cancelled:", reason) end)
---  token:cancel("User requested")
---
---@class AsyncModule
local Async = {}

-- Load submodules
local Cancellation = require('nvim-ssns.async.cancellation')
local Spinner = require('nvim-ssns.async.spinner')
local Progress = require('nvim-ssns.async.progress')
local Executor = require('nvim-ssns.async.executor')
local FileIO = require('nvim-ssns.async.file_io')
local RPC = require('nvim-ssns.async.rpc')
local Thread = require('nvim-ssns.async.thread')

-- Export submodules
Async.Cancellation = Cancellation
Async.Spinner = Spinner
Async.Progress = Progress
Async.Executor = Executor
Async.FileIO = FileIO
Async.RPC = RPC
Async.Thread = Thread

-- Re-export common functions at top level for convenience

---Run a function asynchronously
---@param fn fun(ctx: TaskContext): any, string? Function to execute
---@param opts ExecutorOpts? Options
---@return string task_id Task ID for tracking/cancellation
function Async.run(fn, opts)
  return Executor.run(fn, opts)
end

---Run a function with spinner displayed in a buffer
---@param bufnr number Buffer number
---@param fn fun(ctx: TaskContext): any, string? Function to execute
---@param opts BufferExecutorOpts? Options
---@return string task_id Task ID for tracking/cancellation
function Async.run_in_buffer(bufnr, fn, opts)
  return Executor.run_in_buffer(bufnr, fn, opts)
end

---Cancel a running task
---@param task_id string Task ID
---@param reason string? Cancellation reason
---@return boolean success
function Async.cancel(task_id, reason)
  return Executor.cancel(task_id, reason)
end

---Cancel all tasks in a buffer
---@param bufnr number Buffer number
---@param reason string? Cancellation reason
---@return number count Number cancelled
function Async.cancel_all_in_buffer(bufnr, reason)
  return Executor.cancel_all_in_buffer(bufnr, reason)
end

---Get task by ID
---@param task_id string Task ID
---@return AsyncTask? task
function Async.get_task(task_id)
  return Executor.get_task(task_id)
end

---Get all active tasks
---@return AsyncTask[] tasks
function Async.get_active_tasks()
  return Executor.get_active_tasks()
end

---Create a cancellation token
---@return CancellationToken
function Async.create_cancel_token()
  return Cancellation.create_token()
end

---Create a progress tracker
---@param total number Total items
---@param opts ProgressOpts? Options
---@return ProgressTracker
function Async.create_progress(total, opts)
  return Progress.create(total, opts)
end

---Start a spinner in a buffer
---@param bufnr number Buffer number
---@param opts SpinnerOpts? Options
---@return string spinner_id
function Async.start_spinner(bufnr, opts)
  return Spinner.start_in_buffer(bufnr, opts)
end

---Stop a spinner
---@param spinner_id string Spinner ID
function Async.stop_spinner(spinner_id)
  Spinner.stop(spinner_id)
end

-- Async file operations

---Read file asynchronously
---@param path string File path
---@param callback fun(result: FileIOResult) Callback
function Async.read_file(path, callback)
  FileIO.read_async(path, callback)
end

---Write file asynchronously
---@param path string File path
---@param data string Data to write
---@param callback fun(result: FileIOResult) Callback
function Async.write_file(path, data, callback)
  FileIO.write_async(path, data, callback)
end

---Read JSON file asynchronously
---@param path string File path
---@param callback fun(data: table?, error: string?) Callback
function Async.read_json(path, callback)
  FileIO.read_json_async(path, callback)
end

---Write JSON file asynchronously
---@param path string File path
---@param data table Data to write
---@param callback fun(success: boolean, error: string?) Callback
function Async.write_json(path, data, callback)
  FileIO.write_json_async(path, data, callback)
end

return Async
