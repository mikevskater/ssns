---Thread communication channel using Unix socket pipes
---Provides streaming bidirectional communication between main thread and worker threads
---Uses mpack serialization for efficient data transfer
---@class ThreadChannelModule
local Channel = {}

---@class ThreadChannel
---@field id string Unique channel identifier
---@field socket_path string Path to Unix socket
---@field client userdata? Pipe client handle (main thread side)
---@field on_message fun(message: table) Message handler (runs on main thread)
---@field is_closed boolean Whether the channel has been closed
---@field buffer string Incomplete message buffer for streaming
---@field is_connected boolean Whether client is connected to server
local ThreadChannel = {}
ThreadChannel.__index = ThreadChannel

-- Message delimiter for streaming (length-prefixed framing)
local HEADER_SIZE = 4

---Generate unique channel ID
---@return string
local function generate_id()
  return string.format("channel_%s_%d", os.time(), math.random(10000, 99999))
end

---Get temp directory for socket
---@return string
local function get_temp_dir()
  local temp = os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
  return temp
end

---Encode a 4-byte length header (big-endian)
---@param len number
---@return string
local function encode_length(len)
  return string.char(
    bit.band(bit.rshift(len, 24), 0xFF),
    bit.band(bit.rshift(len, 16), 0xFF),
    bit.band(bit.rshift(len, 8), 0xFF),
    bit.band(len, 0xFF)
  )
end

---Decode a 4-byte length header (big-endian)
---@param data string
---@return number
local function decode_length(data)
  if #data < 4 then return 0 end
  local b1, b2, b3, b4 = data:byte(1, 4)
  return bit.lshift(b1, 24) + bit.lshift(b2, 16) + bit.lshift(b3, 8) + b4
end

---Create a new thread communication channel
---@param on_message fun(message: table) Message handler called on main thread
---@return ThreadChannel
function Channel.create(on_message)
  local id = generate_id()
  local temp_dir = get_temp_dir()

  -- Use a unique socket path
  -- On Windows, use a named pipe path format
  local socket_path
  if vim.fn.has('win32') == 1 then
    socket_path = string.format("\\\\.\\pipe\\ssns_thread_%s", id)
  else
    socket_path = string.format("%s/ssns_thread_%s.sock", temp_dir, id)
  end

  local channel = setmetatable({
    id = id,
    socket_path = socket_path,
    client = nil,
    on_message = on_message,
    is_closed = false,
    buffer = "",
    is_connected = false,
  }, ThreadChannel)

  return channel
end

---Connect to the thread's server (called after thread starts)
---@param timeout_ms number? Connection timeout (default 5000ms)
---@param callback fun(success: boolean, err: string?)? Called when connected
function ThreadChannel:connect(timeout_ms, callback)
  timeout_ms = timeout_ms or 5000

  local start_time = vim.uv.hrtime()
  local retry_timer = vim.uv.new_timer()
  local connected = false
  local current_client = nil
  local timer_closed = false  -- Track if timer has been closed

  -- Helper to safely close the retry timer
  local function close_retry_timer()
    if timer_closed then return end
    timer_closed = true
    if retry_timer and not retry_timer:is_closing() then
      retry_timer:stop()
      retry_timer:close()
    end
  end

  local function try_connect()
    if self.is_closed or connected then
      close_retry_timer()
      if not connected and callback then callback(false, "Channel closed") end
      return
    end

    -- Check timeout
    local elapsed = (vim.uv.hrtime() - start_time) / 1000000
    if elapsed > timeout_ms then
      close_retry_timer()
      -- Clean up any pending client
      if current_client and not current_client:is_closing() then
        current_client:close()
      end
      if callback then callback(false, "Connection timeout") end
      return
    end

    -- Create a NEW pipe handle for each attempt (Windows requires this)
    current_client = vim.uv.new_pipe(false)

    current_client:connect(self.socket_path, function(err)
      if err then
        -- Close failed pipe and let timer retry with a new handle
        if current_client and not current_client:is_closing() then
          current_client:close()
        end
        current_client = nil
        return
      end

      -- Connected successfully
      connected = true
      close_retry_timer()
      self.client = current_client
      self.is_connected = true

      -- Start reading responses
      self.client:read_start(function(read_err, data)
        if read_err then
          self:_handle_error(read_err)
          return
        end

        if data then
          self:_handle_data(data)
        else
          -- EOF - server closed
          self:close()
        end
      end)

      if callback then callback(true, nil) end
    end)
  end

  -- Try connecting with retries (server needs time to start)
  -- Each attempt uses a fresh pipe handle (Windows invalidates handles on failed connect)
  retry_timer:start(0, 50, vim.schedule_wrap(try_connect))
end

---Handle incoming data from the pipe
---@param data string
function ThreadChannel:_handle_data(data)
  -- Append to buffer
  self.buffer = self.buffer .. data

  -- Process complete messages (length-prefixed framing)
  while #self.buffer >= HEADER_SIZE do
    local msg_len = decode_length(self.buffer)

    if msg_len <= 0 or msg_len > 10000000 then
      -- Invalid length, clear buffer
      self.buffer = ""
      return
    end

    local total_len = HEADER_SIZE + msg_len
    if #self.buffer < total_len then
      -- Wait for more data
      return
    end

    -- Extract message
    local msg_data = self.buffer:sub(HEADER_SIZE + 1, total_len)
    self.buffer = self.buffer:sub(total_len + 1)

    -- Decode mpack message
    local ok, message = pcall(vim.mpack.decode, msg_data)
    if ok and message then
      -- IMPORTANT: Schedule handler to run on main Neovim event loop
      -- libuv callbacks run in "fast event context" where vim.* APIs are forbidden
      local on_message = self.on_message
      vim.schedule(function()
        local handler_ok, handler_err = pcall(on_message, message)
        if not handler_ok then
          vim.notify(
            string.format("SSNS Thread: Message handler error: %s", tostring(handler_err)),
            vim.log.levels.ERROR
          )
        end
      end)
    end
  end
end

---Handle pipe errors
---@param err string
function ThreadChannel:_handle_error(err)
  vim.schedule(function()
    vim.notify(
      string.format("SSNS Thread: Pipe error: %s", tostring(err)),
      vim.log.levels.WARN
    )
  end)
  self:close()
end

---Get socket path for passing to worker thread
---@return string
function ThreadChannel:get_socket_path()
  return self.socket_path
end

---Send a message to the worker thread (if bidirectional needed)
---@param message table
function ThreadChannel:send(message)
  if not self.client or not self.is_connected then return end

  local ok, encoded = pcall(vim.mpack.encode, message)
  if not ok then return end

  local header = encode_length(#encoded)
  self.client:write(header .. encoded)
end

---Close the channel and clean up resources
function ThreadChannel:close()
  if self.is_closed then return end

  self.is_closed = true
  self.is_connected = false

  if self.client then
    if not self.client:is_closing() then
      self.client:read_stop()
      self.client:close()
    end
    self.client = nil
  end

  -- Clear buffer and callback references for garbage collection
  self.buffer = ""
  self.on_message = nil

  -- Clean up socket file on Unix
  if vim.fn.has('win32') ~= 1 then
    pcall(os.remove, self.socket_path)
  end
end

---Check if channel is still open
---@return boolean
function ThreadChannel:is_open()
  return not self.is_closed and self.is_connected
end

---@class ChannelMessage
---@field type "batch"|"progress"|"complete"|"error"|"cancelled" Message type
---@field items table[]? Batch items (for type="batch")
---@field pct number? Progress percentage (for type="progress")
---@field message string? Progress/error message
---@field result table? Final result (for type="complete")
---@field error string? Error message (for type="error")
---@field processed number? Items processed before cancellation

---Create a message handler that routes to typed callbacks
---@param opts {on_batch: fun(items: table[], progress: number?)?, on_progress: fun(pct: number, message: string?)?, on_complete: fun(result: table?)?, on_error: fun(error: string)?, on_cancelled: fun(processed: number?)?}
---@return fun(message: ChannelMessage)
function Channel.create_router(opts)
  return function(message)
    local msg_type = message.type

    if msg_type == "batch" and opts.on_batch then
      opts.on_batch(message.items or {}, message.progress)
    elseif msg_type == "progress" and opts.on_progress then
      opts.on_progress(message.pct or 0, message.message)
    elseif msg_type == "complete" and opts.on_complete then
      opts.on_complete(message.result)
    elseif msg_type == "error" and opts.on_error then
      opts.on_error(message.error or "Unknown error")
    elseif msg_type == "cancelled" and opts.on_cancelled then
      opts.on_cancelled(message.processed)
    end
  end
end

---Get the worker server code that should be prepended to worker scripts
---This creates the server side of the pipe in the worker thread
---@return string
function Channel.get_worker_server_code()
  return [[
-- Worker thread server setup
local uv = require('luv')

local HEADER_SIZE = 4

local function encode_length(len)
  return string.char(
    bit.band(bit.rshift(len, 24), 0xFF),
    bit.band(bit.rshift(len, 16), 0xFF),
    bit.band(bit.rshift(len, 8), 0xFF),
    bit.band(len, 0xFF)
  )
end

-- Create pipe server
local server = uv.new_pipe(false)
local client_pipe = nil

local function send_message(msg)
  if not client_pipe then return end
  local encoded = mpack_encode(msg)
  local header = encode_length(#encoded)
  client_pipe:write(header .. encoded)
end

-- Bind and listen
server:bind(_SOCKET_PATH)
server:listen(1, function(err)
  if err then return end

  client_pipe = uv.new_pipe(false)
  server:accept(client_pipe)

  -- Signal ready and start processing
  _WORKER_MAIN(send_message)

  -- Close when done
  if client_pipe and not client_pipe:is_closing() then
    client_pipe:close()
  end
  if server and not server:is_closing() then
    server:close()
  end
end)

-- Run event loop briefly to accept connection
uv.run('once')

-- Give main thread time to connect, then run worker
uv.run('default')
]]
end

return Channel
