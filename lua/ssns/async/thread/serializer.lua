---Thread-safe serialization utilities
---Handles conversion of complex objects for thread communication
---Uses mpack for efficient binary serialization
---@class ThreadSerializerModule
local Serializer = {}

---Serialize a value to mpack
---@param value any Value to serialize
---@return string mpack
function Serializer.encode(value)
  local ok, encoded = pcall(vim.mpack.encode, value)
  if ok then
    return encoded
  end
  -- Fallback for problematic values
  return vim.mpack.encode({})
end

---Deserialize mpack to Lua value
---@param data string mpack data
---@return any? value
---@return string? error
function Serializer.decode(data)
  if not data or data == "" then
    return nil, "Empty data"
  end

  local ok, value = pcall(vim.mpack.decode, data)
  if ok then
    return value, nil
  end
  return nil, tostring(value)
end

---Serialize searchable objects for object search threading
---Strips non-serializable data (functions, metatables, circular refs)
---@param objects table[] Array of searchable objects
---@return string mpack
function Serializer.serialize_searchables(objects)
  local simplified = {}

  for i, obj in ipairs(objects) do
    -- Extract only serializable fields needed for search
    simplified[i] = {
      idx = i,  -- Original index for reconstruction
      unique_id = obj.unique_id,
      name = obj.name,
      schema_name = obj.schema_name,
      database_name = obj.database_name,
      server_name = obj.server_name,
      object_type = obj.object_type,
      -- Only include already-loaded data (no lazy loading in thread)
      definition = obj.definition_loaded and obj.definition or nil,
      metadata_text = obj.metadata_loaded and obj.metadata_text or nil,
      -- Include display info
      display_name = obj.display_name,
      full_name = obj.full_name,
    }
  end

  return Serializer.encode(simplified)
end

---Get pure Lua mpack encoder for worker threads
---Workers can't use vim.mpack, so we need a pure Lua version
---This is a simplified mpack encoder that handles common types
---@return string lua_code Lua code string for mpack encoding
function Serializer.get_worker_mpack_encoder()
  return [[
-- Simplified mpack encoder for worker threads
-- Handles: nil, boolean, number, string, array, map
local function mpack_encode(value)
  local t = type(value)

  if value == nil then
    return string.char(0xc0)  -- nil
  elseif t == "boolean" then
    return string.char(value and 0xc3 or 0xc2)  -- true/false
  elseif t == "number" then
    if value == math.floor(value) then
      -- Integer
      if value >= 0 then
        if value <= 127 then
          return string.char(value)  -- positive fixint
        elseif value <= 0xFF then
          return string.char(0xcc, value)  -- uint8
        elseif value <= 0xFFFF then
          return string.char(0xcd, bit.rshift(value, 8), bit.band(value, 0xFF))  -- uint16
        elseif value <= 0xFFFFFFFF then
          return string.char(0xce,
            bit.band(bit.rshift(value, 24), 0xFF),
            bit.band(bit.rshift(value, 16), 0xFF),
            bit.band(bit.rshift(value, 8), 0xFF),
            bit.band(value, 0xFF))  -- uint32
        end
      else
        if value >= -32 then
          return string.char(0xe0 + (value + 32))  -- negative fixint
        elseif value >= -128 then
          return string.char(0xd0, value + 256)  -- int8
        elseif value >= -32768 then
          local v = value + 65536
          return string.char(0xd1, bit.rshift(v, 8), bit.band(v, 0xFF))  -- int16
        end
      end
    end
    -- Float (double)
    local function pack_double(n)
      local sign = 0
      if n < 0 then sign = 1; n = -n end
      local mantissa, exponent = math.frexp(n)
      if n == 0 then
        return string.char(0xcb, 0, 0, 0, 0, 0, 0, 0, 0)
      end
      exponent = exponent + 1022
      mantissa = (mantissa * 2 - 1) * 2^52
      local bytes = {}
      for i = 1, 6 do
        bytes[7-i] = math.floor(mantissa) % 256
        mantissa = mantissa / 256
      end
      bytes[1] = sign * 128 + math.floor(exponent / 16)
      bytes[2] = (exponent % 16) * 16 + math.floor(mantissa)
      return string.char(0xcb, unpack(bytes))
    end
    return pack_double(value)
  elseif t == "string" then
    local len = #value
    if len <= 31 then
      return string.char(0xa0 + len) .. value  -- fixstr
    elseif len <= 0xFF then
      return string.char(0xd9, len) .. value  -- str8
    elseif len <= 0xFFFF then
      return string.char(0xda, bit.rshift(len, 8), bit.band(len, 0xFF)) .. value  -- str16
    else
      return string.char(0xdb,
        bit.band(bit.rshift(len, 24), 0xFF),
        bit.band(bit.rshift(len, 16), 0xFF),
        bit.band(bit.rshift(len, 8), 0xFF),
        bit.band(len, 0xFF)) .. value  -- str32
    end
  elseif t == "table" then
    -- Check if array or map
    local is_array = true
    local max_idx = 0
    local count = 0
    for k, _ in pairs(value) do
      count = count + 1
      if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
        is_array = false
      elseif k > max_idx then
        max_idx = k
      end
    end

    if is_array and max_idx == count and count > 0 then
      -- Encode as array
      local header
      if count <= 15 then
        header = string.char(0x90 + count)  -- fixarray
      elseif count <= 0xFFFF then
        header = string.char(0xdc, bit.rshift(count, 8), bit.band(count, 0xFF))  -- array16
      else
        header = string.char(0xdd,
          bit.band(bit.rshift(count, 24), 0xFF),
          bit.band(bit.rshift(count, 16), 0xFF),
          bit.band(bit.rshift(count, 8), 0xFF),
          bit.band(count, 0xFF))  -- array32
      end
      local parts = {header}
      for i = 1, count do
        parts[#parts + 1] = mpack_encode(value[i])
      end
      return table.concat(parts)
    else
      -- Encode as map
      local header
      if count <= 15 then
        header = string.char(0x80 + count)  -- fixmap
      elseif count <= 0xFFFF then
        header = string.char(0xde, bit.rshift(count, 8), bit.band(count, 0xFF))  -- map16
      else
        header = string.char(0xdf,
          bit.band(bit.rshift(count, 24), 0xFF),
          bit.band(bit.rshift(count, 16), 0xFF),
          bit.band(bit.rshift(count, 8), 0xFF),
          bit.band(count, 0xFF))  -- map32
      end
      local parts = {header}
      for k, v in pairs(value) do
        parts[#parts + 1] = mpack_encode(tostring(k))
        parts[#parts + 1] = mpack_encode(v)
      end
      return table.concat(parts)
    end
  end

  return string.char(0xc0)  -- nil for unsupported types
end
]]
end

---Get pure Lua mpack decoder for worker threads (if needed for bidirectional)
---@return string lua_code Lua code string for mpack decoding
function Serializer.get_worker_mpack_decoder()
  return [[
-- Simplified mpack decoder for worker threads
local function mpack_decode(data)
  local pos = 1

  local function read_bytes(n)
    local result = data:sub(pos, pos + n - 1)
    pos = pos + n
    return result
  end

  local function read_byte()
    local b = data:byte(pos)
    pos = pos + 1
    return b
  end

  local function decode_value()
    local b = read_byte()
    if not b then return nil end

    -- nil
    if b == 0xc0 then return nil end
    -- false/true
    if b == 0xc2 then return false end
    if b == 0xc3 then return true end

    -- positive fixint (0x00 - 0x7f)
    if b <= 0x7f then return b end

    -- negative fixint (0xe0 - 0xff)
    if b >= 0xe0 then return b - 256 end

    -- fixstr (0xa0 - 0xbf)
    if b >= 0xa0 and b <= 0xbf then
      local len = b - 0xa0
      return read_bytes(len)
    end

    -- fixarray (0x90 - 0x9f)
    if b >= 0x90 and b <= 0x9f then
      local len = b - 0x90
      local arr = {}
      for i = 1, len do arr[i] = decode_value() end
      return arr
    end

    -- fixmap (0x80 - 0x8f)
    if b >= 0x80 and b <= 0x8f then
      local len = b - 0x80
      local map = {}
      for _ = 1, len do
        local k = decode_value()
        local v = decode_value()
        map[k] = v
      end
      return map
    end

    -- uint8
    if b == 0xcc then return read_byte() end

    -- uint16
    if b == 0xcd then
      local b1, b2 = read_byte(), read_byte()
      return b1 * 256 + b2
    end

    -- uint32
    if b == 0xce then
      local b1, b2, b3, b4 = read_byte(), read_byte(), read_byte(), read_byte()
      return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
    end

    -- int8
    if b == 0xd0 then
      local v = read_byte()
      return v < 128 and v or v - 256
    end

    -- int16
    if b == 0xd1 then
      local b1, b2 = read_byte(), read_byte()
      local v = b1 * 256 + b2
      return v < 32768 and v or v - 65536
    end

    -- str8
    if b == 0xd9 then
      local len = read_byte()
      return read_bytes(len)
    end

    -- str16
    if b == 0xda then
      local b1, b2 = read_byte(), read_byte()
      local len = b1 * 256 + b2
      return read_bytes(len)
    end

    -- str32
    if b == 0xdb then
      local b1, b2, b3, b4 = read_byte(), read_byte(), read_byte(), read_byte()
      local len = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
      return read_bytes(len)
    end

    -- array16
    if b == 0xdc then
      local b1, b2 = read_byte(), read_byte()
      local len = b1 * 256 + b2
      local arr = {}
      for i = 1, len do arr[i] = decode_value() end
      return arr
    end

    -- array32
    if b == 0xdd then
      local b1, b2, b3, b4 = read_byte(), read_byte(), read_byte(), read_byte()
      local len = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
      local arr = {}
      for i = 1, len do arr[i] = decode_value() end
      return arr
    end

    -- map16
    if b == 0xde then
      local b1, b2 = read_byte(), read_byte()
      local len = b1 * 256 + b2
      local map = {}
      for _ = 1, len do
        local k = decode_value()
        local v = decode_value()
        map[k] = v
      end
      return map
    end

    -- map32
    if b == 0xdf then
      local b1, b2, b3, b4 = read_byte(), read_byte(), read_byte(), read_byte()
      local len = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
      local map = {}
      for _ = 1, len do
        local k = decode_value()
        local v = decode_value()
        map[k] = v
      end
      return map
    end

    -- float64 (double)
    if b == 0xcb then
      local bytes = {read_byte(), read_byte(), read_byte(), read_byte(),
                     read_byte(), read_byte(), read_byte(), read_byte()}
      local sign = bytes[1] >= 128 and -1 or 1
      local exp = (bytes[1] % 128) * 16 + math.floor(bytes[2] / 16)
      local mantissa = (bytes[2] % 16) * 2^48
      for i = 3, 8 do
        mantissa = mantissa + bytes[i] * 2^((8-i)*8)
      end
      if exp == 0 then return 0 end
      return sign * 2^(exp - 1023) * (1 + mantissa / 2^52)
    end

    return nil
  end

  return decode_value()
end
]]
end

return Serializer
