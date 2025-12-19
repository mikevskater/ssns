-- Test file: cancellation.lua
-- IDs: 9300-9330
-- Tests: CancellationToken cooperative async cancellation
-- Tests the cancellation module's token creation, cancellation, and linked tokens

return {
  -- ============================================================================
  -- Token creation and basic state
  -- ============================================================================
  {
    id = 9301,
    type = "async",
    name = "Create cancellation token - initial state is not cancelled",
    module = "ssns.async.cancellation",
    method = "create_token",
    expected = {
      is_cancelled = false,
      has_token = true,
    },
  },
  {
    id = 9302,
    type = "async",
    name = "Cancel token - sets is_cancelled to true",
    module = "ssns.async.cancellation",
    method = "cancel_token",
    expected = {
      is_cancelled = true,
    },
  },
  {
    id = 9303,
    type = "async",
    name = "Cancel token with reason - stores reason",
    module = "ssns.async.cancellation",
    method = "cancel_with_reason",
    input = {
      reason = "User requested cancellation",
    },
    expected = {
      is_cancelled = true,
      reason = "User requested cancellation",
    },
  },
  {
    id = 9304,
    type = "async",
    name = "Cancel token without reason - uses default reason",
    module = "ssns.async.cancellation",
    method = "cancel_without_reason",
    expected = {
      is_cancelled = true,
      has_reason = true,
    },
  },
  {
    id = 9305,
    type = "async",
    name = "Double cancel - second cancel is no-op",
    module = "ssns.async.cancellation",
    method = "double_cancel",
    expected = {
      is_cancelled = true,
      first_reason_preserved = true,
    },
  },

  -- ============================================================================
  -- Callback registration and invocation
  -- ============================================================================
  {
    id = 9310,
    type = "async",
    name = "on_cancel callback - invoked when cancelled",
    module = "ssns.async.cancellation",
    method = "on_cancel_invoked",
    expected = {
      callback_invoked = true,
    },
  },
  {
    id = 9311,
    type = "async",
    name = "on_cancel callback - receives reason",
    module = "ssns.async.cancellation",
    method = "on_cancel_receives_reason",
    input = {
      reason = "Test cancellation reason",
    },
    expected = {
      received_reason = "Test cancellation reason",
    },
  },
  {
    id = 9312,
    type = "async",
    name = "Multiple callbacks - all invoked on cancel",
    module = "ssns.async.cancellation",
    method = "multiple_callbacks",
    expected = {
      all_invoked = true,
      invoke_count = 3,
    },
  },
  {
    id = 9313,
    type = "async",
    name = "on_cancel on already cancelled token - invoked immediately",
    module = "ssns.async.cancellation",
    method = "on_cancel_already_cancelled",
    expected = {
      callback_invoked = true,
    },
  },
  {
    id = 9314,
    type = "async",
    name = "Unregister callback - not invoked after unregister",
    module = "ssns.async.cancellation",
    method = "unregister_callback",
    expected = {
      callback_not_invoked = true,
    },
  },

  -- ============================================================================
  -- throw_if_cancelled
  -- ============================================================================
  {
    id = 9320,
    type = "async",
    name = "throw_if_cancelled - does not throw when not cancelled",
    module = "ssns.async.cancellation",
    method = "throw_not_cancelled",
    expected = {
      no_error = true,
    },
  },
  {
    id = 9321,
    type = "async",
    name = "throw_if_cancelled - throws when cancelled",
    module = "ssns.async.cancellation",
    method = "throw_when_cancelled",
    expected = {
      threw_error = true,
      is_cancellation_error = true,
    },
  },

  -- ============================================================================
  -- Linked tokens
  -- ============================================================================
  {
    id = 9325,
    type = "async",
    name = "Linked token - cancels when parent cancels",
    module = "ssns.async.cancellation",
    method = "linked_token_parent_cancel",
    expected = {
      linked_cancelled = true,
    },
  },
  {
    id = 9326,
    type = "async",
    name = "Linked token - not cancelled if parent not cancelled",
    module = "ssns.async.cancellation",
    method = "linked_token_parent_not_cancelled",
    expected = {
      linked_not_cancelled = true,
    },
  },
  {
    id = 9327,
    type = "async",
    name = "Linked token from already cancelled parent - immediately cancelled",
    module = "ssns.async.cancellation",
    method = "linked_token_already_cancelled_parent",
    expected = {
      linked_cancelled = true,
    },
  },
  {
    id = 9328,
    type = "async",
    name = "Linked token with multiple parents - cancels when any parent cancels",
    module = "ssns.async.cancellation",
    method = "linked_token_multiple_parents",
    expected = {
      linked_cancelled = true,
      reason_from_cancelled_parent = true,
    },
  },

  -- ============================================================================
  -- is_cancellation_error helper
  -- ============================================================================
  {
    id = 9330,
    type = "async",
    name = "is_cancellation_error - detects cancellation errors",
    module = "ssns.async.cancellation",
    method = "is_cancellation_error_test",
    expected = {
      detects_cancellation_error = true,
      ignores_other_errors = true,
    },
  },
}
