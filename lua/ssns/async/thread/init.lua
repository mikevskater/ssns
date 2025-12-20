---Thread module for CPU-intensive operations
---Uses vim.uv.new_thread() for true parallel execution
---@class ThreadModule
local Thread = {}

local Coordinator = require('ssns.async.thread.coordinator')
local Serializer = require('ssns.async.thread.serializer')
local Channel = require('ssns.async.thread.channel')
local Workers = require('ssns.async.thread.workers')

-- Export submodules
Thread.Coordinator = Coordinator
Thread.Serializer = Serializer
Thread.Channel = Channel
Thread.Workers = Workers

-- Register built-in workers
Workers.register_all(Coordinator)

---Check if threading is available on this system
---@return boolean
function Thread.is_available()
  return Coordinator.is_available()
end

---Start a threaded task
---@param opts ThreadTask Task configuration
---@return string? task_id Task ID for cancellation
---@return string? error Error message if failed
function Thread.start(opts)
  return Coordinator.start(opts)
end

---Cancel a running task
---@param task_id string Task ID
---@param reason string? Cancellation reason
---@return boolean success
function Thread.cancel(task_id, reason)
  return Coordinator.cancel(task_id, reason)
end

---Get task status
---@param task_id string Task ID
---@return ThreadHandle?
function Thread.get_task(task_id)
  return Coordinator.get_task(task_id)
end

---Clean up all tasks (for shutdown)
function Thread.cleanup_all()
  Coordinator.cleanup_all()
end

---Register a custom worker
---@param name string Worker name
---@param code string Pure Lua code (no vim.* APIs)
function Thread.register_worker(name, code)
  Coordinator.register_worker(name, code)
end

---Get list of available workers
---@return string[]
function Thread.get_available_workers()
  return Workers.get_available()
end

return Thread
