---Async RPC handler for non-blocking database queries
---Works with Node.js SSNSExecuteQueryAsync function
---@class AsyncRPC
local AsyncRPC = {}

---Pending callbacks indexed by callback ID
---@type table<string, { on_complete: function, on_error: function?, started_at: number }>
local pending_callbacks = {}

---Generate unique callback ID
---@return string
local function generate_callback_id()
  return string.format("rpc_%s_%d", os.time(), math.random(10000, 99999))
end

---Handle callback from Node.js
---This function is called by Node.js via plugin.nvim.call('luaeval', ...)
---@param callback_id string The callback ID
---@param result table? The query result
---@param err string? Error message if failed
function AsyncRPC.handle_callback(callback_id, result, err)
  local callback = pending_callbacks[callback_id]
  if not callback then
    -- Callback already handled or timed out
    return
  end

  -- Remove from pending
  pending_callbacks[callback_id] = nil

  -- Normalize the result to match Connection.execute format
  -- Node.js returns { resultSets, metadata, error } but Lua adapters expect { success, resultSets, metadata, error }
  local normalized_result = result
  if result and type(result) == "table" then
    -- Check if there was a SQL error in the result
    local error_obj = result.error
    if type(error_obj) == "table" and error_obj.message then
      normalized_result = {
        success = false,
        resultSets = {},
        metadata = result.metadata or {},
        error = {
          message = tostring(error_obj.message),
          code = error_obj.code,
          lineNumber = error_obj.lineNumber,
          procName = error_obj.procName
        }
      }
    else
      -- Success - add success = true to match Connection.execute format
      normalized_result = {
        success = true,
        resultSets = result.resultSets or {},
        metadata = result.metadata or {},
        error = nil
      }
    end
  end

  -- Call the appropriate handler
  vim.schedule(function()
    if err and callback.on_error then
      callback.on_error(err)
    elseif callback.on_complete then
      callback.on_complete(normalized_result, err)
    end
  end)
end

---@class AsyncRPCOpts
---@field on_complete fun(result: table, error: string?)? Completion callback
---@field on_error fun(error: string)? Error callback
---@field timeout_ms number? Timeout in milliseconds (default: 60000)
---@field use_cache boolean? Use query cache (default: true)
---@field ttl number? Cache TTL

---Track if we've shown the unavailable warning
local shown_unavailable_warning = false

---Track if we've verified the function works
local verified_available = nil

---Check if the async RPC function is available
---Remote plugin functions aren't detected by vim.fn.exists until the host starts
---@return boolean available True if SSNSExecuteQueryAsync is registered
function AsyncRPC.is_available()
  -- Return cached result if already verified
  if verified_available ~= nil then
    return verified_available
  end

  -- Try calling SSNSExecuteQueryAsync directly with minimal args
  -- The function is registered in rplugin.vim, but vim.fn.exists doesn't detect
  -- remote plugin functions reliably until they're actually called
  local ok, result = pcall(function()
    -- Call with empty/invalid args - it will return { started: false, error: ... }
    -- but that proves the function exists and the host is running
    return vim.fn.SSNSExecuteQueryAsync({ '{}', '', 'test_availability_check' })
  end)

  if ok and type(result) == "table" then
    -- Function exists and responded (even if with an error about missing params)
    verified_available = true
    return true
  end

  -- Check the error - if it's "Unknown function" then it's not available
  -- If it's any other error, the function exists but had an issue
  if not ok and result then
    local err_str = tostring(result)
    if err_str:match("Unknown function") or err_str:match("E117") then
      verified_available = false
      return false
    else
      -- Some other error means the function exists
      verified_available = true
      return true
    end
  end

  -- Not available
  verified_available = false
  return false
end

---Reset the availability cache (useful after UpdateRemotePlugins)
function AsyncRPC.reset_availability_cache()
  verified_available = nil
end

---Check availability and show instructions if not available (once per session)
---@param silent boolean? If true, don't show notification
---@return boolean available
function AsyncRPC.check_and_notify(silent)
  local available = AsyncRPC.is_available()
  if not available and not shown_unavailable_warning and not silent then
    shown_unavailable_warning = true
    vim.defer_fn(function()
      vim.notify(
        "SSNS: Non-blocking async not available. Run :UpdateRemotePlugins and restart Neovim for best performance.",
        vim.log.levels.INFO
      )
    end, 100)
  end
  return available
end

---Get status information about RPC async
---@return table status { available: boolean, pending_count: number, message: string }
function AsyncRPC.get_status()
  local available = AsyncRPC.is_available()
  local pending = AsyncRPC.get_pending_count()
  local message
  if available then
    message = "Non-blocking RPC async is enabled"
  else
    message = "RPC async not available - run :UpdateRemotePlugins and restart"
  end
  return {
    available = available,
    pending_count = pending,
    message = message,
  }
end

---Execute a query asynchronously via RPC (non-blocking)
---The query runs in the Node.js process and calls back when complete
---@param connection_config table The connection configuration
---@param query string The SQL query
---@param opts AsyncRPCOpts? Options
---@return string callback_id Callback ID for tracking/cancellation
function AsyncRPC.execute_async(connection_config, query, opts)
  opts = opts or {}

  local callback_id = generate_callback_id()

  -- Store callback handlers
  pending_callbacks[callback_id] = {
    on_complete = opts.on_complete,
    on_error = opts.on_error,
    started_at = vim.loop.hrtime(),
  }

  -- Set up timeout if specified
  local timeout_ms = opts.timeout_ms or 60000
  if timeout_ms > 0 then
    vim.defer_fn(function()
      local callback = pending_callbacks[callback_id]
      if callback then
        -- Still pending - timed out
        pending_callbacks[callback_id] = nil
        vim.schedule(function()
          if callback.on_error then
            callback.on_error("Query timed out after " .. (timeout_ms / 1000) .. " seconds")
          elseif callback.on_complete then
            callback.on_complete(nil, "Query timed out")
          end
        end)
      end
    end, timeout_ms)
  end

  -- Serialize connection config to JSON
  local config_json = vim.fn.json_encode(connection_config)

  -- Call Node.js async function (returns immediately)
  local success, result = pcall(function()
    return vim.fn.SSNSExecuteQueryAsync({ config_json, query, callback_id })
  end)

  if not success then
    -- RPC call itself failed
    pending_callbacks[callback_id] = nil
    vim.schedule(function()
      local err_msg = "Failed to start async query: " .. tostring(result)
      if opts.on_error then
        opts.on_error(err_msg)
      elseif opts.on_complete then
        opts.on_complete(nil, err_msg)
      end
    end)
  elseif result and not result.started then
    -- Node.js returned an error
    pending_callbacks[callback_id] = nil
    vim.schedule(function()
      local err_msg = result.error or "Failed to start async query"
      if opts.on_error then
        opts.on_error(err_msg)
      elseif opts.on_complete then
        opts.on_complete(nil, err_msg)
      end
    end)
  end

  return callback_id
end

---Cancel a pending async query
---@param callback_id string The callback ID
---@return boolean cancelled True if callback was pending and cancelled
function AsyncRPC.cancel(callback_id)
  local callback = pending_callbacks[callback_id]
  if callback then
    pending_callbacks[callback_id] = nil
    -- Note: The query will still complete in Node.js, but the callback won't be invoked
    return true
  end
  return false
end

---Get number of pending callbacks
---@return number count
function AsyncRPC.get_pending_count()
  local count = 0
  for _ in pairs(pending_callbacks) do
    count = count + 1
  end
  return count
end

---Check if a callback is pending
---@param callback_id string
---@return boolean is_pending
function AsyncRPC.is_pending(callback_id)
  return pending_callbacks[callback_id] ~= nil
end

---Clear all pending callbacks (for cleanup)
function AsyncRPC.clear_all()
  pending_callbacks = {}
end

return AsyncRPC
