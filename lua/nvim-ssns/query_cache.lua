---@class QueryCache
---Query result cache with TTL (Time To Live) support
---Caches query results to improve performance
local QueryCache = {}

---@type table<string, {result: table, timestamp: number}>
QueryCache.cache = {}

---Default TTL in seconds (5 minutes)
QueryCache.default_ttl = 300

---Generate a cache key from connection key and query
---@param connection_key string Connection key (from Connections.generate_connection_key)
---@param query string
---@return string key
local function generate_key(connection_key, query)
  -- Normalize query (trim whitespace, convert to lowercase for case-insensitive matching)
  local normalized_query = vim.trim(query):lower()

  -- Create a simple hash-like key
  return connection_key .. ":" .. normalized_query
end

---Check if a cached result is still valid (not expired)
---@param cached_entry {result: table, timestamp: number}
---@param ttl number? TTL in seconds (default: QueryCache.default_ttl)
---@return boolean valid
local function is_valid(cached_entry, ttl)
  ttl = ttl or QueryCache.default_ttl
  local current_time = os.time()
  local age = current_time - cached_entry.timestamp

  return age < ttl
end

---Get a cached query result if it exists and is still valid
---@param connection_key string Connection key
---@param query string
---@param ttl number? TTL in seconds (default: QueryCache.default_ttl)
---@return table? result The cached result or nil if not found/expired
function QueryCache.get(connection_key, query, ttl)
  local key = generate_key(connection_key, query)
  local cached = QueryCache.cache[key]

  if not cached then
    return nil
  end

  if not is_valid(cached, ttl) then
    -- Expired - remove from cache
    QueryCache.cache[key] = nil
    return nil
  end

  return cached.result
end

---Store a query result in the cache
---@param connection_key string Connection key
---@param query string
---@param result table The query result to cache
function QueryCache.set(connection_key, query, result)
  local key = generate_key(connection_key, query)

  QueryCache.cache[key] = {
    result = result,
    timestamp = os.time()
  }
end

---Invalidate (remove) a specific cached query
---@param connection_key string Connection key
---@param query string
---@return boolean removed True if entry was removed
function QueryCache.invalidate(connection_key, query)
  local key = generate_key(connection_key, query)
  local existed = QueryCache.cache[key] ~= nil
  QueryCache.cache[key] = nil
  return existed
end

---Invalidate all cached results for a specific connection
---@param connection_key string Connection key
---@return number count Number of entries removed
function QueryCache.invalidate_connection(connection_key)
  local count = 0
  local prefix = connection_key .. ":"

  for key, _ in pairs(QueryCache.cache) do
    if key:sub(1, #prefix) == prefix then
      QueryCache.cache[key] = nil
      count = count + 1
    end
  end

  return count
end

---Clear all cached query results
function QueryCache.clear_all()
  QueryCache.cache = {}
end

---Remove all expired entries from the cache
---@param ttl number? TTL in seconds (default: QueryCache.default_ttl)
---@return number count Number of expired entries removed
function QueryCache.cleanup_expired(ttl)
  ttl = ttl or QueryCache.default_ttl
  local count = 0

  for key, cached in pairs(QueryCache.cache) do
    if not is_valid(cached, ttl) then
      QueryCache.cache[key] = nil
      count = count + 1
    end
  end

  return count
end

---Get cache statistics
---@return table stats {total_entries: number, valid_entries: number, expired_entries: number}
function QueryCache.get_stats()
  local stats = {
    total_entries = 0,
    valid_entries = 0,
    expired_entries = 0,
    oldest_entry = nil,
    newest_entry = nil
  }

  local current_time = os.time()

  for _, cached in pairs(QueryCache.cache) do
    stats.total_entries = stats.total_entries + 1

    if is_valid(cached) then
      stats.valid_entries = stats.valid_entries + 1
    else
      stats.expired_entries = stats.expired_entries + 1
    end

    if not stats.oldest_entry or cached.timestamp < stats.oldest_entry then
      stats.oldest_entry = cached.timestamp
    end

    if not stats.newest_entry or cached.timestamp > stats.newest_entry then
      stats.newest_entry = cached.timestamp
    end
  end

  -- Convert timestamps to age in seconds
  if stats.oldest_entry then
    stats.oldest_age = current_time - stats.oldest_entry
  end
  if stats.newest_entry then
    stats.newest_age = current_time - stats.newest_entry
  end

  return stats
end

---Debug: Print cache contents
function QueryCache.debug_print()
  print("=== SSNS Query Cache ===")
  local stats = QueryCache.get_stats()
  print(string.format("Total entries: %d", stats.total_entries))
  print(string.format("Valid entries: %d", stats.valid_entries))
  print(string.format("Expired entries: %d", stats.expired_entries))

  if stats.oldest_age then
    print(string.format("Oldest entry age: %d seconds", stats.oldest_age))
  end
  if stats.newest_age then
    print(string.format("Newest entry age: %d seconds", stats.newest_age))
  end

  print("========================")
end

return QueryCache
