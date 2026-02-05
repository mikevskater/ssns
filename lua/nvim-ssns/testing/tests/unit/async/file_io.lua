-- Test file: file_io.lua
-- IDs: 9001-9050
-- Tests: Async file I/O operations using libuv
-- These tests verify the FileIO module's async read/write/exists operations

return {
  -- ============================================================================
  -- Basic async read tests
  -- ============================================================================
  {
    id = 9001,
    type = "async",
    name = "Read existing file asynchronously",
    module = "ssns.async.file_io",
    method = "read_async",
    setup = {
      -- Create a temp file with known content
      create_file = true,
      content = "Hello, async world!",
    },
    expected = {
      success = true,
      data = "Hello, async world!",
    },
  },
  {
    id = 9002,
    type = "async",
    name = "Read non-existent file returns error",
    module = "ssns.async.file_io",
    method = "read_async",
    input = {
      path = "__nonexistent_test_file_12345.txt",
    },
    expected = {
      success = false,
      has_error = true,
    },
  },
  {
    id = 9003,
    type = "async",
    name = "Read empty file returns empty string",
    module = "ssns.async.file_io",
    method = "read_async",
    setup = {
      create_file = true,
      content = "",
    },
    expected = {
      success = true,
      data = "",
    },
  },
  {
    id = 9004,
    type = "async",
    name = "Read file with multiple lines",
    module = "ssns.async.file_io",
    method = "read_async",
    setup = {
      create_file = true,
      content = "Line 1\nLine 2\nLine 3",
    },
    expected = {
      success = true,
      data = "Line 1\nLine 2\nLine 3",
    },
  },
  {
    id = 9005,
    type = "async",
    name = "Read file with unicode content",
    module = "ssns.async.file_io",
    method = "read_async",
    setup = {
      create_file = true,
      content = "Hello 世界 🚀",
    },
    expected = {
      success = true,
      data = "Hello 世界 🚀",
    },
  },

  -- ============================================================================
  -- Basic async write tests
  -- ============================================================================
  {
    id = 9010,
    type = "async",
    name = "Write file asynchronously",
    module = "ssns.async.file_io",
    method = "write_async",
    input = {
      data = "Test content to write",
    },
    expected = {
      success = true,
      verify_content = "Test content to write",
    },
  },
  {
    id = 9011,
    type = "async",
    name = "Write file with unicode content",
    module = "ssns.async.file_io",
    method = "write_async",
    input = {
      data = "Unicode: 日本語テスト 🎉",
    },
    expected = {
      success = true,
      verify_content = "Unicode: 日本語テスト 🎉",
    },
  },
  {
    id = 9012,
    type = "async",
    name = "Write overwrites existing file",
    module = "ssns.async.file_io",
    method = "write_async",
    setup = {
      create_file = true,
      content = "Old content",
    },
    input = {
      data = "New content",
    },
    expected = {
      success = true,
      verify_content = "New content",
    },
  },
  {
    id = 9013,
    type = "async",
    name = "Write empty content creates empty file",
    module = "ssns.async.file_io",
    method = "write_async",
    input = {
      data = "",
    },
    expected = {
      success = true,
      verify_content = "",
    },
  },

  -- ============================================================================
  -- Async append tests
  -- ============================================================================
  {
    id = 9020,
    type = "async",
    name = "Append to existing file",
    module = "ssns.async.file_io",
    method = "append_async",
    setup = {
      create_file = true,
      content = "Original content\n",
    },
    input = {
      data = "Appended content",
    },
    expected = {
      success = true,
      verify_content = "Original content\nAppended content",
    },
  },
  {
    id = 9021,
    type = "async",
    name = "Append to non-existent file creates it",
    module = "ssns.async.file_io",
    method = "append_async",
    input = {
      data = "New file content",
    },
    expected = {
      success = true,
      verify_content = "New file content",
    },
  },

  -- ============================================================================
  -- Async exists tests
  -- ============================================================================
  {
    id = 9030,
    type = "async",
    name = "Check existing file returns true",
    module = "ssns.async.file_io",
    method = "exists_async",
    setup = {
      create_file = true,
      content = "test",
    },
    expected = {
      exists = true,
    },
  },
  {
    id = 9031,
    type = "async",
    name = "Check non-existent file returns false",
    module = "ssns.async.file_io",
    method = "exists_async",
    input = {
      path = "__nonexistent_file_test_99999.txt",
    },
    expected = {
      exists = false,
    },
  },

  -- ============================================================================
  -- Async stat tests
  -- ============================================================================
  {
    id = 9035,
    type = "async",
    name = "Stat existing file returns stats",
    module = "ssns.async.file_io",
    method = "stat_async",
    setup = {
      create_file = true,
      content = "12345678901234567890", -- 20 bytes
    },
    expected = {
      has_stat = true,
      min_size = 20,
    },
  },
  {
    id = 9036,
    type = "async",
    name = "Stat non-existent file returns error",
    module = "ssns.async.file_io",
    method = "stat_async",
    input = {
      path = "__nonexistent_stat_test_12345.txt",
    },
    expected = {
      has_stat = false,
      has_error = true,
    },
  },

  -- ============================================================================
  -- Async JSON read/write tests
  -- ============================================================================
  {
    id = 9040,
    type = "async",
    name = "Read JSON file asynchronously",
    module = "ssns.async.file_io",
    method = "read_json_async",
    setup = {
      create_file = true,
      content = '{"name":"test","value":42}',
    },
    expected = {
      success = true,
      data = { name = "test", value = 42 },
    },
  },
  {
    id = 9041,
    type = "async",
    name = "Read invalid JSON returns error",
    module = "ssns.async.file_io",
    method = "read_json_async",
    setup = {
      create_file = true,
      content = "{invalid json}",
    },
    expected = {
      success = false,
      has_error = true,
    },
  },
  {
    id = 9042,
    type = "async",
    name = "Write JSON file asynchronously",
    module = "ssns.async.file_io",
    method = "write_json_async",
    input = {
      data = { key = "value", number = 123 },
    },
    expected = {
      success = true,
      -- We don't verify exact content since JSON key order may vary
    },
  },

  -- ============================================================================
  -- Async read/write lines tests
  -- ============================================================================
  {
    id = 9045,
    type = "async",
    name = "Read lines asynchronously",
    module = "ssns.async.file_io",
    method = "read_lines_async",
    setup = {
      create_file = true,
      content = "Line 1\nLine 2\nLine 3",
    },
    expected = {
      success = true,
      lines = { "Line 1", "Line 2", "Line 3" },
    },
  },
  {
    id = 9046,
    type = "async",
    name = "Write lines asynchronously",
    module = "ssns.async.file_io",
    method = "write_lines_async",
    input = {
      lines = { "First", "Second", "Third" },
    },
    expected = {
      success = true,
      verify_content = "First\nSecond\nThird",
    },
  },

  -- ============================================================================
  -- Directory operations tests
  -- ============================================================================
  {
    id = 9050,
    type = "async",
    name = "Create directory asynchronously",
    module = "ssns.async.file_io",
    method = "mkdir_async",
    input = {
      -- Path will be generated with temp dir
      create_subdir = true,
    },
    expected = {
      success = true,
      dir_exists = true,
    },
  },
}
