---Cancellation token for cooperative async cancellation
---@class CancellationModule
local Cancellation = {}

---@class CancellationToken
---@field is_cancelled boolean Whether cancellation has been requested
---@field reason string? Reason for cancellation
---@field _callbacks function[] Internal callback list
local CancellationToken = {}
CancellationToken.__index = CancellationToken

---Create a new cancellation token
---@return CancellationToken
function Cancellation.create_token()
  local token = setmetatable({
    is_cancelled = false,
    reason = nil,
    _callbacks = {},
  }, CancellationToken)
  return token
end

---Request cancellation of the operation
---@param reason string? Optional reason for cancellation
function CancellationToken:cancel(reason)
  if self.is_cancelled then
    return -- Already cancelled
  end

  self.is_cancelled = true
  self.reason = reason or "Operation cancelled"

  -- Invoke all registered callbacks
  for _, callback in ipairs(self._callbacks) do
    local ok, err = pcall(callback, self.reason)
    if not ok then
      vim.schedule(function()
        vim.notify("SSNS: Cancellation callback error: " .. tostring(err), vim.log.levels.WARN)
      end)
    end
  end

  -- Clear callbacks after invocation
  self._callbacks = {}
end

---Check if cancelled and throw error if so
---Use this for cooperative cancellation checkpoints
---@return nil
---@throws string Error with cancellation reason if cancelled
function CancellationToken:throw_if_cancelled()
  if self.is_cancelled then
    error("OperationCancelled: " .. (self.reason or "cancelled"), 2)
  end
end

---Register a callback to be called when cancellation is requested
---If already cancelled, callback is invoked immediately
---@param callback fun(reason: string) Callback function
---@return fun() unregister Function to unregister the callback
function CancellationToken:on_cancel(callback)
  if self.is_cancelled then
    -- Already cancelled, invoke immediately
    vim.schedule(function()
      pcall(callback, self.reason)
    end)
    return function() end -- No-op unregister
  end

  table.insert(self._callbacks, callback)

  -- Return unregister function
  local callbacks = self._callbacks
  return function()
    for i, cb in ipairs(callbacks) do
      if cb == callback then
        table.remove(callbacks, i)
        break
      end
    end
  end
end

---Check if an error is a cancellation error
---@param err any The error to check
---@return boolean is_cancellation True if error is from cancellation
function Cancellation.is_cancellation_error(err)
  if type(err) == "string" then
    return err:match("^OperationCancelled:") ~= nil
  end
  return false
end

---Create a linked token that cancels when any parent cancels
---@param ... CancellationToken Parent tokens
---@return CancellationToken linked_token
function Cancellation.create_linked_token(...)
  local linked = Cancellation.create_token()
  local parents = { ... }
  local unregisters = {}

  for _, parent in ipairs(parents) do
    if parent.is_cancelled then
      linked:cancel(parent.reason)
      break
    end

    local unregister = parent:on_cancel(function(reason)
      linked:cancel(reason)
    end)
    table.insert(unregisters, unregister)
  end

  -- Store unregisters for cleanup
  linked._parent_unregisters = unregisters

  return linked
end

return Cancellation
