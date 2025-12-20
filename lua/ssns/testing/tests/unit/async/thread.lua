-- Test file: thread.lua
-- IDs: 11000-11050
-- Tests: Thread module for CPU-intensive operations using vim.uv.new_thread()
-- Tests thread creation, communication, serialization, and lifecycle management

return {
  -- ============================================================================
  -- Thread availability and basic functionality
  -- ============================================================================
  {
    id = 11001,
    type = "async",
    name = "Thread is_available - returns boolean",
    module = "ssns.async.thread",
    method = "is_available",
    expected = {
      returns_boolean = true,
    },
  },
  {
    id = 11002,
    type = "async",
    name = "Thread module - exports submodules",
    module = "ssns.async.thread",
    method = "exports_check",
    expected = {
      has_coordinator = true,
      has_serializer = true,
      has_channel = true,
    },
  },

  -- ============================================================================
  -- Serializer tests
  -- ============================================================================
  {
    id = 11010,
    type = "async",
    name = "Serializer.encode - encodes simple table",
    module = "ssns.async.thread",
    method = "serializer_encode_simple",
    input = {
      data = { name = "test", value = 123 },
    },
    expected = {
      is_string = true,
      contains_name = true,
      contains_value = true,
    },
  },
  {
    id = 11011,
    type = "async",
    name = "Serializer.decode - decodes valid JSON",
    module = "ssns.async.thread",
    method = "serializer_decode",
    input = {
      json = '{"name":"test","value":123}',
    },
    expected = {
      is_table = true,
      name = "test",
      value = 123,
    },
  },
  {
    id = 11012,
    type = "async",
    name = "Serializer.decode - handles empty JSON",
    module = "ssns.async.thread",
    method = "serializer_decode_empty",
    expected = {
      returns_nil = true,
      has_error = true,
    },
  },
  {
    id = 11013,
    type = "async",
    name = "Serializer.serialize_searchables - strips non-serializable fields",
    module = "ssns.async.thread",
    method = "serializer_searchables",
    expected = {
      is_string = true,
      preserves_name = true,
      preserves_schema = true,
    },
  },
  {
    id = 11014,
    type = "async",
    name = "Serializer.get_worker_json_encoder - returns valid Lua code",
    module = "ssns.async.thread",
    method = "serializer_worker_encoder",
    expected = {
      is_string = true,
      defines_json_encode = true,
    },
  },
  {
    id = 11015,
    type = "async",
    name = "Serializer.get_worker_json_decoder - returns valid Lua code",
    module = "ssns.async.thread",
    method = "serializer_worker_decoder",
    expected = {
      is_string = true,
      defines_json_decode = true,
    },
  },

  -- ============================================================================
  -- Channel tests
  -- ============================================================================
  {
    id = 11020,
    type = "async",
    name = "Channel.create - creates channel with async handle",
    module = "ssns.async.thread",
    method = "channel_create",
    expected = {
      has_channel = true,
      has_id = true,
      is_open = true,
    },
  },
  {
    id = 11021,
    type = "async",
    name = "Channel.close - closes channel",
    module = "ssns.async.thread",
    method = "channel_close",
    expected = {
      was_open = true,
      is_closed = true,
    },
  },
  {
    id = 11022,
    type = "async",
    name = "Channel.create_router - routes messages by type",
    module = "ssns.async.thread",
    method = "channel_router",
    expected = {
      routes_batch = true,
      routes_progress = true,
      routes_complete = true,
      routes_error = true,
    },
  },

  -- ============================================================================
  -- Coordinator tests
  -- ============================================================================
  {
    id = 11030,
    type = "async",
    name = "Coordinator.is_available - returns boolean",
    module = "ssns.async.thread",
    method = "coordinator_is_available",
    expected = {
      returns_boolean = true,
    },
  },
  {
    id = 11031,
    type = "async",
    name = "Coordinator.get_active_count - returns count",
    module = "ssns.async.thread",
    method = "coordinator_active_count",
    expected = {
      returns_number = true,
      initial_count_zero = true,
    },
  },
  {
    id = 11032,
    type = "async",
    name = "Coordinator.register_worker - registers named worker",
    module = "ssns.async.thread",
    method = "coordinator_register_worker",
    expected = {
      registration_succeeds = true,
    },
  },

  -- ============================================================================
  -- Built-in worker registration tests
  -- ============================================================================
  {
    id = 11040,
    type = "async",
    name = "Built-in workers - search worker registered",
    module = "ssns.async.thread",
    method = "builtin_worker_search",
    expected = {
      worker_exists = true,
    },
  },
  {
    id = 11041,
    type = "async",
    name = "Built-in workers - sort worker registered",
    module = "ssns.async.thread",
    method = "builtin_worker_sort",
    expected = {
      worker_exists = true,
    },
  },
  {
    id = 11042,
    type = "async",
    name = "Built-in workers - dedupe_sort worker registered",
    module = "ssns.async.thread",
    method = "builtin_worker_dedupe_sort",
    expected = {
      worker_exists = true,
    },
  },
  {
    id = 11043,
    type = "async",
    name = "Built-in workers - fk_graph worker registered",
    module = "ssns.async.thread",
    method = "builtin_worker_fk_graph",
    expected = {
      worker_exists = true,
    },
  },

  -- ============================================================================
  -- Thread start/cancel tests (if threading available)
  -- ============================================================================
  {
    id = 11050,
    type = "async",
    name = "Thread.start - returns task_id when threading available",
    module = "ssns.async.thread",
    method = "thread_start_basic",
    expected = {
      returns_task_id_or_error = true,
    },
  },
}
