-- Test file: chunked_rendering.lua
-- IDs: 9500-9550
-- Tests: Chunked buffer writes and batched highlights
-- Tests the UiBuffer.set_lines_chunked and UiHighlights.apply_batched functions

return {
  -- ============================================================================
  -- UiBuffer.set_lines_chunked - small content (sync path)
  -- ============================================================================
  {
    id = 9501,
    type = "async",
    name = "Chunked write - small content uses sync path",
    module = "ssns.ui.chunked",
    method = "set_lines_chunked_small",
    input = {
      line_count = 50, -- Below default chunk_size of 100
    },
    expected = {
      sync_path = true,
      lines_written = 50,
      on_complete_called = true,
    },
  },
  {
    id = 9502,
    type = "async",
    name = "Chunked write - exactly chunk_size uses sync path",
    module = "ssns.ui.chunked",
    method = "set_lines_chunked_exact",
    input = {
      line_count = 100,
      chunk_size = 100,
    },
    expected = {
      sync_path = true,
      lines_written = 100,
      on_complete_called = true,
    },
  },

  -- ============================================================================
  -- UiBuffer.set_lines_chunked - large content (async path)
  -- ============================================================================
  {
    id = 9510,
    type = "async",
    name = "Chunked write - large content uses async path",
    module = "ssns.ui.chunked",
    method = "set_lines_chunked_large",
    input = {
      line_count = 250,
      chunk_size = 100,
    },
    expected = {
      async_path = true,
      lines_written = 250,
      on_complete_called = true,
      min_progress_calls = 2, -- At least 2 progress callbacks (not counting final)
    },
  },
  {
    id = 9511,
    type = "async",
    name = "Chunked write - custom chunk size",
    module = "ssns.ui.chunked",
    method = "set_lines_chunked_custom_size",
    input = {
      line_count = 150,
      chunk_size = 50,
    },
    expected = {
      async_path = true,
      lines_written = 150,
      on_complete_called = true,
      min_progress_calls = 2,
    },
  },
  {
    id = 9512,
    type = "async",
    name = "Chunked write - progress callback receives correct values",
    module = "ssns.ui.chunked",
    method = "set_lines_chunked_progress",
    input = {
      line_count = 200,
      chunk_size = 100,
    },
    expected = {
      progress_increases = true,
      final_progress_equals_total = true,
    },
  },

  -- ============================================================================
  -- UiBuffer.set_lines_chunked - cancellation
  -- ============================================================================
  {
    id = 9520,
    type = "async",
    name = "Chunked write - cancel stops further writes",
    module = "ssns.ui.chunked",
    method = "set_lines_chunked_cancel",
    input = {
      line_count = 500,
      chunk_size = 50,
      cancel_after_chunks = 2,
    },
    expected = {
      cancelled = true,
      partial_write = true, -- Less than total lines written
    },
  },
  {
    id = 9521,
    type = "async",
    name = "Chunked write - is_chunked_write_active returns true during write",
    module = "ssns.ui.chunked",
    method = "set_lines_chunked_active_check",
    input = {
      line_count = 300,
      chunk_size = 50,
    },
    expected = {
      active_during_write = true,
      inactive_after_complete = true,
    },
  },
  {
    id = 9522,
    type = "async",
    name = "Chunked write - new write cancels previous",
    module = "ssns.ui.chunked",
    method = "set_lines_chunked_replace",
    input = {
      first_line_count = 500,
      second_line_count = 100,
      chunk_size = 50,
    },
    expected = {
      first_cancelled = true,
      second_completed = true,
    },
  },

  -- ============================================================================
  -- UiHighlights.apply_batched - small content (sync path)
  -- ============================================================================
  {
    id = 9530,
    type = "async",
    name = "Batched highlights - small content uses sync path",
    module = "ssns.ui.chunked",
    method = "apply_batched_small",
    input = {
      line_count = 50,
    },
    expected = {
      sync_path = true,
      on_complete_called = true,
    },
  },
  {
    id = 9531,
    type = "async",
    name = "Batched highlights - exactly batch_size uses sync path",
    module = "ssns.ui.chunked",
    method = "apply_batched_exact",
    input = {
      line_count = 100,
      batch_size = 100,
    },
    expected = {
      sync_path = true,
      on_complete_called = true,
    },
  },

  -- ============================================================================
  -- UiHighlights.apply_batched - large content (async path)
  -- ============================================================================
  {
    id = 9540,
    type = "async",
    name = "Batched highlights - large content uses async path",
    module = "ssns.ui.chunked",
    method = "apply_batched_large",
    input = {
      line_count = 250,
      batch_size = 100,
    },
    expected = {
      async_path = true,
      on_complete_called = true,
      min_progress_calls = 2,
    },
  },
  {
    id = 9541,
    type = "async",
    name = "Batched highlights - progress callback receives correct values",
    module = "ssns.ui.chunked",
    method = "apply_batched_progress",
    input = {
      line_count = 200,
      batch_size = 100,
    },
    expected = {
      progress_increases = true,
      final_progress_equals_total = true,
    },
  },

  -- ============================================================================
  -- UiHighlights.apply_batched - cancellation
  -- ============================================================================
  {
    id = 9545,
    type = "async",
    name = "Batched highlights - cancel stops further batches",
    module = "ssns.ui.chunked",
    method = "apply_batched_cancel",
    input = {
      line_count = 500,
      batch_size = 50,
      cancel_after_batches = 2,
    },
    expected = {
      cancelled = true,
    },
  },
  {
    id = 9546,
    type = "async",
    name = "Batched highlights - is_batched_active returns true during apply",
    module = "ssns.ui.chunked",
    method = "apply_batched_active_check",
    input = {
      line_count = 300,
      batch_size = 50,
    },
    expected = {
      active_during_apply = true,
      inactive_after_complete = true,
    },
  },
  {
    id = 9547,
    type = "async",
    name = "Batched highlights - new apply cancels previous",
    module = "ssns.ui.chunked",
    method = "apply_batched_replace",
    input = {
      first_line_count = 500,
      second_line_count = 100,
      batch_size = 50,
    },
    expected = {
      first_cancelled = true,
      second_completed = true,
    },
  },

  -- ============================================================================
  -- Edge cases
  -- ============================================================================
  {
    id = 9550,
    type = "async",
    name = "Chunked write - empty lines array",
    module = "ssns.ui.chunked",
    method = "set_lines_chunked_empty",
    expected = {
      on_complete_called = true,
      lines_written = 0,
    },
  },
}
