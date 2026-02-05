-- Test file: debug_logger.lua
-- IDs: 9200-9220
-- Tests: Buffered async debug logging
-- These tests verify the Debug module's buffered write behavior

return {
  -- ============================================================================
  -- Buffer behavior tests
  -- ============================================================================
  {
    id = 9201,
    type = "async",
    name = "Log message adds to buffer",
    module = "ssns.debug",
    method = "log",
    input = {
      message = "Test log message",
    },
    expected = {
      buffer_increased = true,
    },
  },
  {
    id = 9202,
    type = "async",
    name = "Multiple logs accumulate in buffer",
    module = "ssns.debug",
    method = "log_multiple",
    input = {
      messages = { "First message", "Second message", "Third message" },
    },
    expected = {
      min_buffer_size = 3,
    },
  },
  {
    id = 9203,
    type = "async",
    name = "Flush clears buffer",
    module = "ssns.debug",
    method = "flush_test",
    setup = {
      pre_log = { "Message 1", "Message 2" },
    },
    expected = {
      buffer_cleared = true,
    },
  },
  {
    id = 9204,
    type = "async",
    name = "Flush sync writes immediately",
    module = "ssns.debug",
    method = "flush_sync_test",
    setup = {
      pre_log = { "Sync test message" },
    },
    expected = {
      buffer_cleared = true,
      file_contains = "Sync test message",
    },
  },
  {
    id = 9205,
    type = "async",
    name = "Get log path returns valid path",
    module = "ssns.debug",
    method = "get_log_path",
    expected = {
      has_path = true,
      path_contains = "ssns_debug.log",
    },
  },
  {
    id = 9206,
    type = "async",
    name = "Get buffer size returns correct count",
    module = "ssns.debug",
    method = "get_buffer_size_test",
    setup = {
      pre_log = { "A", "B", "C", "D", "E" },
    },
    expected = {
      min_buffer_size = 5,
    },
  },
}
