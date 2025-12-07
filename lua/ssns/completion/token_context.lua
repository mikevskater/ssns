---@class TokenContext
---Token-based context detection utilities for IntelliSense
---Replaces regex-based parsing with accurate token stream analysis
---
---NOTE: This module now re-exports from modular sub-modules:
---  - tokens/ - Navigation and identifier utilities
---  - context/ - Context detection by type
---
---This maintains backward compatibility while providing cleaner internal structure.
---@module ssns.completion.token_context
local TokenContext = {}

-- Import modular components
local Tokens = require('ssns.completion.tokens')
local Context = require('ssns.completion.context')
local QualifiedNames = require('ssns.completion.context.common.qualified_names')
local TableContext = require('ssns.completion.context.table_context')
local ColumnContext = require('ssns.completion.context.column_context')
local SpecialContexts = require('ssns.completion.context.special_contexts')

-- ============================================================================
-- Re-export QualifiedName type (for type annotations)
-- ============================================================================

---@class QualifiedName
---@field database string? Database name (for db.schema.table)
---@field schema string? Schema name (for schema.table or db.schema.table)
---@field table string? Table/view/object name
---@field column string? Column name (for table.column)
---@field alias string? Could be alias or identifier
---@field parts string[] All parts in order (first to last)
---@field has_trailing_dot boolean Whether there's a dot at the end (schema. triggers completion)

-- ============================================================================
-- Navigation functions (from tokens/navigation.lua)
-- ============================================================================

TokenContext.get_token_at_position = Tokens.get_token_at_position
TokenContext.get_tokens_before_cursor = Tokens.get_tokens_before_cursor
TokenContext.get_token_after_cursor = Tokens.get_token_after_cursor
TokenContext.find_previous_token_of_type = Tokens.find_previous_token_of_type
TokenContext.find_previous_keyword = Tokens.find_previous_keyword
TokenContext.is_in_string_or_comment = Tokens.is_in_string_or_comment
TokenContext.extract_prefix = Tokens.extract_prefix

-- ============================================================================
-- Tokenization (from tokens/init.lua)
-- ============================================================================

TokenContext.tokenize = Tokens.tokenize
TokenContext.get_buffer_tokens = Tokens.get_buffer_tokens

-- ============================================================================
-- Qualified name parsing (from context/common/qualified_names.lua)
-- ============================================================================

TokenContext.parse_qualified_name_from_tokens = QualifiedNames.parse_from_tokens
TokenContext.is_dot_triggered = QualifiedNames.is_dot_triggered
TokenContext.get_reference_before_dot = QualifiedNames.get_reference_before_dot
TokenContext.extract_left_side_column = QualifiedNames.extract_left_side_column
TokenContext.extract_prefix_and_trigger = QualifiedNames.extract_prefix_and_trigger

-- ============================================================================
-- Table context detection (from context/table_context.lua)
-- ============================================================================

TokenContext.detect_table_context_from_tokens = TableContext.detect

-- ============================================================================
-- Column context detection (from context/column_context.lua)
-- ============================================================================

TokenContext.detect_column_context_from_tokens = ColumnContext.detect
TokenContext.detect_values_context_from_tokens = ColumnContext.detect_values
TokenContext.detect_insert_columns_from_tokens = ColumnContext.detect_insert_columns
TokenContext.detect_merge_insert_from_tokens = ColumnContext.detect_merge_insert
TokenContext.detect_on_clause_from_tokens = ColumnContext.detect_on_clause
TokenContext.is_in_subquery_select = ColumnContext.is_in_subquery_select

-- ============================================================================
-- Special context detection (from context/special_contexts.lua)
-- ============================================================================

TokenContext.detect_other_context_from_tokens = SpecialContexts.detect_other
TokenContext.detect_output_into_from_tokens = SpecialContexts.detect_output_into

-- ============================================================================
-- Unified context detection (from context/init.lua)
-- ============================================================================

TokenContext.detect_context = Context.detect

-- ============================================================================
-- Debug utilities
-- ============================================================================

TokenContext.debug_print_context = Context.debug_print

-- ============================================================================
-- Identifier utilities (from tokens/init.lua)
-- ============================================================================

TokenContext.is_temp_table = Tokens.is_temp_table
TokenContext.is_global_temp_table = Tokens.is_global_temp_table
TokenContext.strip_identifier_quotes = Tokens.strip_identifier_quotes
TokenContext.get_last_name_part = Tokens.get_last_name_part
TokenContext.starts_with = Tokens.starts_with
TokenContext.extract_trailing_bracketed = Tokens.extract_trailing_bracketed
TokenContext.extract_trailing_identifier = Tokens.extract_trailing_identifier

return TokenContext
