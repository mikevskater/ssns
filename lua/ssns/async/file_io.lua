---Async file I/O operations using libuv
---@class FileIOModule
local FileIO = {}

local uv = vim.loop

---@class FileIOResult
---@field success boolean Whether operation succeeded
---@field data string? File content (for reads)
---@field error string? Error message if failed
---@field bytes_written number? Bytes written (for writes)

---Read a file asynchronously
---@param path string File path
---@param callback fun(result: FileIOResult) Callback with result
function FileIO.read_async(path, callback)
  -- Open file for reading
  uv.fs_open(path, "r", 438, function(open_err, fd)
    if open_err then
      vim.schedule(function()
        callback({
          success = false,
          data = nil,
          error = "Failed to open file: " .. tostring(open_err),
        })
      end)
      return
    end

    -- Get file size
    uv.fs_fstat(fd, function(stat_err, stat)
      if stat_err then
        uv.fs_close(fd)
        vim.schedule(function()
          callback({
            success = false,
            data = nil,
            error = "Failed to stat file: " .. tostring(stat_err),
          })
        end)
        return
      end

      local size = stat.size

      -- Handle empty files
      if size == 0 then
        uv.fs_close(fd)
        vim.schedule(function()
          callback({
            success = true,
            data = "",
            error = nil,
          })
        end)
        return
      end

      -- Read file content
      uv.fs_read(fd, size, 0, function(read_err, data)
        uv.fs_close(fd)

        if read_err then
          vim.schedule(function()
            callback({
              success = false,
              data = nil,
              error = "Failed to read file: " .. tostring(read_err),
            })
          end)
          return
        end

        vim.schedule(function()
          callback({
            success = true,
            data = data,
            error = nil,
          })
        end)
      end)
    end)
  end)
end

---Write data to a file asynchronously
---@param path string File path
---@param data string Data to write
---@param callback fun(result: FileIOResult) Callback with result
function FileIO.write_async(path, data, callback)
  -- Open file for writing (create if not exists, truncate if exists)
  -- Mode 438 = 0666 in octal (read/write for all)
  uv.fs_open(path, "w", 438, function(open_err, fd)
    if open_err then
      vim.schedule(function()
        callback({
          success = false,
          error = "Failed to open file for writing: " .. tostring(open_err),
          bytes_written = 0,
        })
      end)
      return
    end

    -- Write data
    uv.fs_write(fd, data, 0, function(write_err, bytes_written)
      uv.fs_close(fd)

      if write_err then
        vim.schedule(function()
          callback({
            success = false,
            error = "Failed to write file: " .. tostring(write_err),
            bytes_written = 0,
          })
        end)
        return
      end

      vim.schedule(function()
        callback({
          success = true,
          error = nil,
          bytes_written = bytes_written,
        })
      end)
    end)
  end)
end

---Append data to a file asynchronously
---@param path string File path
---@param data string Data to append
---@param callback fun(result: FileIOResult) Callback with result
function FileIO.append_async(path, data, callback)
  -- Open file for appending (create if not exists)
  uv.fs_open(path, "a", 438, function(open_err, fd)
    if open_err then
      vim.schedule(function()
        callback({
          success = false,
          error = "Failed to open file for appending: " .. tostring(open_err),
          bytes_written = 0,
        })
      end)
      return
    end

    -- Write data (offset -1 means append at end)
    uv.fs_write(fd, data, -1, function(write_err, bytes_written)
      uv.fs_close(fd)

      if write_err then
        vim.schedule(function()
          callback({
            success = false,
            error = "Failed to append to file: " .. tostring(write_err),
            bytes_written = 0,
          })
        end)
        return
      end

      vim.schedule(function()
        callback({
          success = true,
          error = nil,
          bytes_written = bytes_written,
        })
      end)
    end)
  end)
end

---Check if a file exists asynchronously
---@param path string File path
---@param callback fun(exists: boolean, error: string?) Callback
function FileIO.exists_async(path, callback)
  uv.fs_stat(path, function(err, stat)
    vim.schedule(function()
      if err then
        -- ENOENT means file doesn't exist (not an error)
        if err:match("ENOENT") then
          callback(false, nil)
        else
          callback(false, tostring(err))
        end
      else
        callback(stat ~= nil, nil)
      end
    end)
  end)
end

---Get file stats asynchronously
---@param path string File path
---@param callback fun(stat: table?, error: string?) Callback
function FileIO.stat_async(path, callback)
  uv.fs_stat(path, function(err, stat)
    vim.schedule(function()
      if err then
        callback(nil, tostring(err))
      else
        callback(stat, nil)
      end
    end)
  end)
end

---Create a directory asynchronously (including parents)
---@param path string Directory path
---@param callback fun(success: boolean, error: string?) Callback
function FileIO.mkdir_async(path, callback)
  -- First check if it exists
  uv.fs_stat(path, function(err, stat)
    if stat then
      -- Already exists
      vim.schedule(function()
        callback(true, nil)
      end)
      return
    end

    -- Try to create it
    uv.fs_mkdir(path, 493, function(mkdir_err)  -- 493 = 0755
      if mkdir_err then
        -- If it failed because parent doesn't exist, try creating parent first
        if mkdir_err:match("ENOENT") then
          local parent = vim.fn.fnamemodify(path, ":h")
          if parent ~= path then
            FileIO.mkdir_async(parent, function(parent_success, parent_err)
              if not parent_success then
                vim.schedule(function()
                  callback(false, parent_err)
                end)
                return
              end

              -- Try again after creating parent
              uv.fs_mkdir(path, 493, function(retry_err)
                vim.schedule(function()
                  if retry_err then
                    callback(false, tostring(retry_err))
                  else
                    callback(true, nil)
                  end
                end)
              end)
            end)
            return
          end
        end

        vim.schedule(function()
          callback(false, tostring(mkdir_err))
        end)
      else
        vim.schedule(function()
          callback(true, nil)
        end)
      end
    end)
  end)
end

---Delete a file asynchronously
---@param path string File path
---@param callback fun(success: boolean, error: string?) Callback
function FileIO.unlink_async(path, callback)
  uv.fs_unlink(path, function(err)
    vim.schedule(function()
      if err then
        callback(false, tostring(err))
      else
        callback(true, nil)
      end
    end)
  end)
end

---Rename/move a file asynchronously
---@param old_path string Current path
---@param new_path string New path
---@param callback fun(success: boolean, error: string?) Callback
function FileIO.rename_async(old_path, new_path, callback)
  uv.fs_rename(old_path, new_path, function(err)
    vim.schedule(function()
      if err then
        callback(false, tostring(err))
      else
        callback(true, nil)
      end
    end)
  end)
end

---Copy a file asynchronously
---@param src_path string Source path
---@param dst_path string Destination path
---@param callback fun(success: boolean, error: string?) Callback
function FileIO.copy_async(src_path, dst_path, callback)
  FileIO.read_async(src_path, function(read_result)
    if not read_result.success then
      callback(false, read_result.error)
      return
    end

    FileIO.write_async(dst_path, read_result.data, function(write_result)
      callback(write_result.success, write_result.error)
    end)
  end)
end

---Read a JSON file asynchronously
---@param path string File path
---@param callback fun(data: table?, error: string?) Callback
function FileIO.read_json_async(path, callback)
  FileIO.read_async(path, function(result)
    if not result.success then
      callback(nil, result.error)
      return
    end

    local ok, parsed = pcall(vim.fn.json_decode, result.data)
    if not ok then
      callback(nil, "Failed to parse JSON: " .. tostring(parsed))
      return
    end

    callback(parsed, nil)
  end)
end

---Write a JSON file asynchronously
---@param path string File path
---@param data table Data to write
---@param callback fun(success: boolean, error: string?) Callback
function FileIO.write_json_async(path, data, callback)
  local ok, json = pcall(vim.fn.json_encode, data)
  if not ok then
    vim.schedule(function()
      callback(false, "Failed to encode JSON: " .. tostring(json))
    end)
    return
  end

  FileIO.write_async(path, json, function(result)
    callback(result.success, result.error)
  end)
end

---Read file lines asynchronously
---@param path string File path
---@param callback fun(lines: string[]?, error: string?) Callback
function FileIO.read_lines_async(path, callback)
  FileIO.read_async(path, function(result)
    if not result.success then
      callback(nil, result.error)
      return
    end

    local lines = vim.split(result.data or "", "\n", { plain = true })
    callback(lines, nil)
  end)
end

---Write lines to file asynchronously
---@param path string File path
---@param lines string[] Lines to write
---@param callback fun(success: boolean, error: string?) Callback
function FileIO.write_lines_async(path, lines, callback)
  local data = table.concat(lines, "\n")
  FileIO.write_async(path, data, function(result)
    callback(result.success, result.error)
  end)
end

return FileIO
