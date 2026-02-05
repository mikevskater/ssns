---@class FormatterEngineCache
---Token caching for the formatter engine
local M = {}

-- High-resolution timer
local hrtime = vim.loop.hrtime

---@class TokenCacheEntry
---@field tokens Token[]
---@field timestamp number

---@class TokenCache
---@field entries table<string, TokenCacheEntry>
---@field max_entries number Maximum cache entries
---@field ttl_ns number Time-to-live in nanoseconds
M.cache = {
  entries = {},
  max_entries = 100,
  ttl_ns = 60 * 1000000000, -- 60 seconds
}

---Hash function for cache key using DJB2 algorithm
---DJB2 is a simple, fast hash with good distribution properties.
---It processes every character, avoiding the collision issues of sampling.
---@param sql string
---@return string
function M.hash_sql(sql)
  local len = #sql
  -- Short strings can use themselves as the key (faster lookup)
  if len <= 64 then
    return sql
  end

  -- DJB2 hash algorithm (processes all characters)
  -- Uses 32-bit arithmetic to avoid Lua number precision issues
  local hash = 5381
  for i = 1, len do
    local c = string.byte(sql, i)
    -- hash = hash * 33 + c (using bit operations for speed)
    -- We use modulo to keep it in 32-bit range
    hash = ((hash * 33) + c) % 0x100000000
  end

  -- Return as string with length prefix for extra collision resistance
  return string.format("%d:%x", len, hash)
end

---Get cached tokens or nil
---@param sql string
---@return Token[]|nil
function M.get(sql)
  local key = M.hash_sql(sql)
  local entry = M.cache.entries[key]
  if entry then
    local now = hrtime()
    if now - entry.timestamp < M.cache.ttl_ns then
      return entry.tokens
    end
    -- Expired
    M.cache.entries[key] = nil
  end
  return nil
end

---Cache tokens
---@param sql string
---@param tokens Token[]
function M.set(sql, tokens)
  local key = M.hash_sql(sql)
  M.cache.entries[key] = {
    tokens = tokens,
    timestamp = hrtime(),
  }

  -- Evict old entries if over limit
  local count = 0
  for _ in pairs(M.cache.entries) do
    count = count + 1
  end

  if count > M.cache.max_entries then
    -- Remove oldest entries
    local oldest_key, oldest_time = nil, math.huge
    for k, v in pairs(M.cache.entries) do
      if v.timestamp < oldest_time then
        oldest_key = k
        oldest_time = v.timestamp
      end
    end
    if oldest_key then
      M.cache.entries[oldest_key] = nil
    end
  end
end

---Clear the token cache
function M.clear()
  M.cache.entries = {}
end

return M
