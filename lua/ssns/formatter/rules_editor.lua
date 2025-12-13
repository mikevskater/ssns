---@class FormatterRulesEditor
---Interactive formatter rules editor with three-panel layout using UiFloat:
---  Left: Preset list (built-in + user)
---  Middle: Settings for selected preset
---  Right: Live SQL preview
local RulesEditor = {}

local Config = require('ssns.config')
local KeymapManager = require('ssns.keymap_manager')
local Presets = require('ssns.formatter.presets')
local Formatter = require('ssns.formatter')
local UiFloat = require('ssns.ui.core.float')

---@class RuleDefinition
---@field key string Config key path
---@field name string Display name
---@field description string Rule description
---@field type string "boolean"|"number"|"enum"
---@field options? string[] For enum type, valid options
---@field min? number For number type, minimum value
---@field max? number For number type, maximum value
---@field step? number For number type, increment step
---@field category string Category for grouping

---@class RulesEditorState
---@field available_presets FormatterPreset[] All available presets
---@field selected_preset_idx number Currently selected preset index
---@field selected_rule_idx number Currently selected rule index
---@field current_config table Working copy of formatter config
---@field original_config table Original config for cancel/reset
---@field is_dirty boolean Whether config has been modified
---@field rule_definitions RuleDefinition[] All rule definitions
---@field editing_user_copy boolean Whether we auto-created a user copy

---@type MultiPanelState?
local multi_panel = nil

---@type RulesEditorState?
local state = nil

-- Rule definitions organized by category
local RULE_DEFINITIONS = {
  -- General
  { key = "enabled", name = "Enabled", description = "Enable/disable formatter globally", type = "boolean", category = "General" },
  { key = "keyword_case", name = "Keyword Case", description = "Transform keyword casing", type = "enum", options = {"upper", "lower", "preserve"}, category = "General" },
  { key = "max_line_length", name = "Max Line Length", description = "Soft limit for line wrapping (0=disable)", type = "number", min = 0, max = 500, step = 10, category = "General" },
  { key = "preserve_comments", name = "Preserve Comments", description = "Keep comments in formatted output", type = "boolean", category = "General" },
  { key = "format_on_save", name = "Format on Save", description = "Auto-format when saving SQL buffers", type = "boolean", category = "General" },

  -- Indentation
  { key = "indent_size", name = "Indent Size", description = "Spaces per indent level", type = "number", min = 1, max = 8, step = 1, category = "Indentation" },
  { key = "indent_style", name = "Indent Style", description = "Use spaces or tabs for indentation", type = "enum", options = {"space", "tab"}, category = "Indentation" },
  { key = "subquery_indent", name = "Subquery Indent", description = "Extra indent levels for subqueries", type = "number", min = 0, max = 4, step = 1, category = "Indentation" },
  { key = "case_indent", name = "CASE Indent", description = "Indent levels for CASE/WHEN blocks", type = "number", min = 0, max = 4, step = 1, category = "Indentation" },

  -- Clauses (legacy)
  { key = "newline_before_clause", name = "Newline Before Clause", description = "Start major clauses on new lines", type = "boolean", category = "Clauses" },
  { key = "comma_position", name = "Comma Position", description = "Place commas at start or end of line", type = "enum", options = {"trailing", "leading"}, category = "Clauses" },
  { key = "and_or_position", name = "AND/OR Position", description = "Place AND/OR at start or end of line", type = "enum", options = {"leading", "trailing"}, category = "Clauses" },

  -- SELECT Clause (Phase 1)
  { key = "select_list_style", name = "Select List Style", description = "Columns inline or one per line", type = "enum", options = {"inline", "stacked"}, category = "SELECT" },
  { key = "select_star_expand", name = "Expand SELECT *", description = "Auto-expand SELECT * to column list", type = "boolean", category = "SELECT" },
  { key = "select_distinct_newline", name = "DISTINCT Newline", description = "Put DISTINCT on new line after SELECT", type = "boolean", category = "SELECT" },
  { key = "select_top_newline", name = "TOP Newline", description = "Put TOP clause on new line after SELECT", type = "boolean", category = "SELECT" },
  { key = "select_into_newline", name = "INTO Newline", description = "Put INTO clause on new line", type = "boolean", category = "SELECT" },
  { key = "select_column_align", name = "Column Alignment", description = "Align columns to left or keyword", type = "enum", options = {"left", "keyword"}, category = "SELECT" },
  { key = "use_as_keyword", name = "Use AS Keyword", description = "Always use AS for column aliases", type = "boolean", category = "SELECT" },

  -- FROM Clause (Phase 1)
  { key = "from_newline", name = "FROM Newline", description = "FROM on new line", type = "boolean", category = "FROM" },
  { key = "from_table_style", name = "Table Style", description = "Tables inline or one per line", type = "enum", options = {"inline", "stacked"}, category = "FROM" },
  { key = "from_alias_align", name = "Alias Alignment", description = "Align table aliases", type = "boolean", category = "FROM" },
  { key = "from_schema_qualify", name = "Schema Qualify", description = "Schema qualification style", type = "enum", options = {"always", "never", "preserve"}, category = "FROM" },
  { key = "from_table_hints_newline", name = "Table Hints Newline", description = "Table hints on new line", type = "boolean", category = "FROM" },
  { key = "derived_table_style", name = "Derived Table Style", description = "Derived table opening paren position", type = "enum", options = {"inline", "newline"}, category = "FROM" },

  -- WHERE Clause (Phase 1)
  { key = "where_newline", name = "WHERE Newline", description = "WHERE on new line", type = "boolean", category = "WHERE" },
  { key = "where_condition_style", name = "Condition Style", description = "Conditions inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "WHERE" },
  { key = "where_and_or_indent", name = "AND/OR Indent", description = "AND/OR indent level", type = "number", min = 0, max = 4, step = 1, category = "WHERE" },
  { key = "where_in_list_style", name = "IN List Style", description = "IN list inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "WHERE" },
  { key = "where_between_style", name = "BETWEEN Style", description = "BETWEEN values inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "WHERE" },
  { key = "where_exists_style", name = "EXISTS Style", description = "EXISTS subquery inline or newline", type = "enum", options = {"inline", "newline"}, category = "WHERE" },

  -- JOIN Clause (Phase 1)
  { key = "join_on_same_line", name = "ON Same Line", description = "Keep ON clause on same line as JOIN", type = "boolean", category = "JOIN" },
  { key = "join_newline", name = "JOIN Newline", description = "JOIN on new line", type = "boolean", category = "JOIN" },
  { key = "join_keyword_style", name = "Keyword Style", description = "INNER JOIN vs JOIN", type = "enum", options = {"full", "short"}, category = "JOIN" },
  { key = "join_indent_style", name = "Indent Style", description = "JOIN alignment style", type = "enum", options = {"align", "indent"}, category = "JOIN" },
  { key = "on_condition_style", name = "ON Condition Style", description = "ON conditions inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "JOIN" },
  { key = "on_and_position", name = "ON AND Position", description = "AND in ON clause position", type = "enum", options = {"leading", "trailing"}, category = "JOIN" },
  { key = "cross_apply_newline", name = "CROSS APPLY Newline", description = "CROSS/OUTER APPLY on new line", type = "boolean", category = "JOIN" },
  { key = "empty_line_before_join", name = "Empty Line Before", description = "Empty line before JOIN", type = "boolean", category = "JOIN" },

  -- INSERT rules (Phase 2)
  { key = "insert_columns_style", name = "Columns Style", description = "INSERT column list inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "INSERT" },
  { key = "insert_values_style", name = "Values Style", description = "VALUES clause inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "INSERT" },
  { key = "insert_into_keyword", name = "INTO Keyword", description = "Always use INTO keyword", type = "boolean", category = "INSERT" },
  { key = "insert_multi_row_style", name = "Multi-Row Style", description = "Multiple VALUES rows inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "INSERT" },

  -- UPDATE rules (Phase 2)
  { key = "update_set_style", name = "SET Style", description = "SET assignments inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "UPDATE" },
  { key = "update_set_align", name = "Align SET", description = "Align = in SET clause", type = "boolean", category = "UPDATE" },

  -- DELETE rules (Phase 2)
  { key = "delete_from_keyword", name = "FROM Keyword", description = "Always use FROM keyword", type = "boolean", category = "DELETE" },

  -- OUTPUT/MERGE rules (Phase 2)
  { key = "output_clause_newline", name = "OUTPUT Newline", description = "OUTPUT clause on new line", type = "boolean", category = "DML" },
  { key = "merge_style", name = "MERGE Style", description = "MERGE statement style", type = "enum", options = {"compact", "expanded"}, category = "DML" },
  { key = "merge_when_newline", name = "WHEN Newline", description = "WHEN clauses on new lines", type = "boolean", category = "DML" },

  -- GROUP BY rules (Phase 2)
  { key = "group_by_newline", name = "Newline", description = "GROUP BY on new line", type = "boolean", category = "GROUP BY" },
  { key = "group_by_style", name = "Style", description = "GROUP BY columns inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "GROUP BY" },
  { key = "having_newline", name = "HAVING Newline", description = "HAVING on new line", type = "boolean", category = "GROUP BY" },

  -- ORDER BY rules (Phase 2)
  { key = "order_by_newline", name = "Newline", description = "ORDER BY on new line", type = "boolean", category = "ORDER BY" },
  { key = "order_by_style", name = "Style", description = "ORDER BY columns inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "ORDER BY" },
  { key = "order_direction_style", name = "Direction Style", description = "ASC/DESC display mode", type = "enum", options = {"always", "explicit", "never"}, category = "ORDER BY" },

  -- CTE rules (Phase 2)
  { key = "cte_style", name = "CTE Style", description = "CTE layout style", type = "enum", options = {"compact", "expanded"}, category = "CTE" },
  { key = "cte_as_position", name = "AS Position", description = "AS keyword on same or new line", type = "enum", options = {"same_line", "new_line"}, category = "CTE" },
  { key = "cte_parenthesis_style", name = "Paren Style", description = "Opening paren on same or new line", type = "enum", options = {"same_line", "new_line"}, category = "CTE" },
  { key = "cte_columns_style", name = "Columns Style", description = "CTE column list inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "CTE" },
  { key = "cte_separator_newline", name = "Separator Newline", description = "Comma between CTEs on new line", type = "boolean", category = "CTE" },

  -- Casing rules (Phase 3)
  { key = "function_case", name = "Function Case", description = "Built-in functions casing (COUNT, SUM, etc.)", type = "enum", options = {"upper", "lower", "preserve"}, category = "Casing" },
  { key = "datatype_case", name = "Datatype Case", description = "Data types casing (INT, VARCHAR, etc.)", type = "enum", options = {"upper", "lower", "preserve"}, category = "Casing" },
  { key = "identifier_case", name = "Identifier Case", description = "Table/column names casing", type = "enum", options = {"upper", "lower", "preserve"}, category = "Casing" },
  { key = "alias_case", name = "Alias Case", description = "Alias names casing", type = "enum", options = {"upper", "lower", "preserve"}, category = "Casing" },

  -- Alignment
  { key = "align_aliases", name = "Align Aliases", description = "Vertically align AS keywords in SELECT", type = "boolean", category = "Alignment" },
  { key = "align_columns", name = "Align Columns", description = "Vertically align column expressions", type = "boolean", category = "Alignment" },

  -- Spacing rules (Phase 3)
  { key = "operator_spacing", name = "Operator Spacing", description = "Add spaces around operators (=, +, etc.)", type = "boolean", category = "Spacing" },
  { key = "parenthesis_spacing", name = "Parenthesis Spacing", description = "Add spaces inside parentheses", type = "boolean", category = "Spacing" },
  { key = "comma_spacing", name = "Comma Spacing", description = "Spaces around commas", type = "enum", options = {"before", "after", "both", "none"}, category = "Spacing" },
  { key = "semicolon_spacing", name = "Semicolon Spacing", description = "Space before semicolon", type = "boolean", category = "Spacing" },
  { key = "bracket_spacing", name = "Bracket Spacing", description = "Spaces inside brackets []", type = "boolean", category = "Spacing" },
  { key = "equals_spacing", name = "Equals Spacing", description = "Spaces around = in SET", type = "boolean", category = "Spacing" },
  { key = "concatenation_spacing", name = "Concat Spacing", description = "Spaces around + concat operator", type = "boolean", category = "Spacing" },
  { key = "comparison_spacing", name = "Comparison Spacing", description = "Spaces around <, >, etc.", type = "boolean", category = "Spacing" },

  -- Blank lines rules (Phase 3)
  { key = "blank_line_before_clause", name = "Before Clause", description = "Blank line before major clauses", type = "boolean", category = "Blank Lines" },
  { key = "blank_line_after_go", name = "After GO", description = "Blank lines after GO batch separator", type = "number", min = 0, max = 3, category = "Blank Lines" },
  { key = "blank_line_between_statements", name = "Between Statements", description = "Blank lines between statements", type = "number", min = 0, max = 3, category = "Blank Lines" },
  { key = "blank_line_before_comment", name = "Before Comment", description = "Blank line before block comments", type = "boolean", category = "Blank Lines" },
  { key = "collapse_blank_lines", name = "Collapse Blanks", description = "Collapse multiple consecutive blank lines", type = "boolean", category = "Blank Lines" },
  { key = "max_consecutive_blank_lines", name = "Max Blanks", description = "Maximum consecutive blank lines allowed", type = "number", min = 1, max = 5, category = "Blank Lines" },

  -- Comments rules (Phase 3)
  { key = "comment_position", name = "Position", description = "Comment placement", type = "enum", options = {"preserve", "above", "inline"}, category = "Comments" },
  { key = "block_comment_style", name = "Block Style", description = "Block comment formatting", type = "enum", options = {"preserve", "reformat"}, category = "Comments" },
  { key = "inline_comment_align", name = "Align Inline", description = "Align inline comments", type = "boolean", category = "Comments" },

  -- DDL rules (Phase 4)
  { key = "create_table_column_newline", name = "Column Newline", description = "Each column definition on new line", type = "boolean", category = "DDL" },
  { key = "create_table_constraint_newline", name = "Constraint Newline", description = "Constraints on new lines", type = "boolean", category = "DDL" },
  { key = "alter_table_style", name = "ALTER Style", description = "ALTER TABLE statement layout", type = "enum", options = {"compact", "expanded"}, category = "DDL" },
  { key = "drop_if_exists_style", name = "DROP IF EXISTS", description = "DROP IF EXISTS style", type = "enum", options = {"inline", "separate"}, category = "DDL" },
  { key = "index_column_style", name = "Index Columns", description = "Index column list layout", type = "enum", options = {"inline", "stacked"}, category = "DDL" },
  { key = "view_body_indent", name = "View Body Indent", description = "Indent level for view body", type = "number", min = 0, max = 4, step = 1, category = "DDL" },
  { key = "procedure_param_style", name = "Proc Params", description = "Procedure parameter layout", type = "enum", options = {"inline", "stacked"}, category = "DDL" },
  { key = "function_param_style", name = "Func Params", description = "Function parameter layout", type = "enum", options = {"inline", "stacked"}, category = "DDL" },

  -- Expression rules (Phase 4)
  { key = "case_style", name = "CASE Style", description = "CASE expression layout", type = "enum", options = {"inline", "stacked"}, category = "Expressions" },
  { key = "case_when_indent", name = "WHEN Indent", description = "WHEN clause indent level", type = "number", min = 0, max = 4, step = 1, category = "Expressions" },
  { key = "case_then_position", name = "THEN Position", description = "THEN position relative to WHEN", type = "enum", options = {"same_line", "new_line"}, category = "Expressions" },
  { key = "subquery_paren_style", name = "Subquery Paren", description = "Subquery opening paren position", type = "enum", options = {"same_line", "new_line"}, category = "Expressions" },
  { key = "function_arg_style", name = "Function Args", description = "Function argument layout", type = "enum", options = {"inline", "stacked"}, category = "Expressions" },
  { key = "in_list_style", name = "IN List Style", description = "IN clause value list layout", type = "enum", options = {"inline", "stacked"}, category = "Expressions" },
  { key = "boolean_operator_newline", name = "Bool Op Newline", description = "Put AND/OR on new lines in expressions", type = "boolean", category = "Expressions" },

  -- Indentation expansion (Phase 5)
  { key = "continuation_indent", name = "Continuation", description = "Wrapped line continuation indent", type = "number", min = 0, max = 4, step = 1, category = "Indentation" },
  { key = "cte_indent", name = "CTE Indent", description = "CTE body indent level", type = "number", min = 0, max = 4, step = 1, category = "Indentation" },
  { key = "union_indent", name = "UNION Indent", description = "UNION statement indent", type = "number", min = 0, max = 4, step = 1, category = "Indentation" },
  { key = "nested_join_indent", name = "Nested JOIN", description = "Nested JOIN indent level", type = "number", min = 0, max = 4, step = 1, category = "Indentation" },

  -- Advanced options (Phase 5)
  { key = "keyword_right_align", name = "Right-Align Keywords", description = "Right-align keywords (river style)", type = "boolean", category = "Advanced" },
  { key = "format_only_selection", name = "Selection Only", description = "Format selection only vs whole buffer", type = "boolean", category = "Advanced" },
  { key = "batch_separator_style", name = "Batch Separator", description = "Batch separator preference", type = "enum", options = {"go", "semicolon"}, category = "Advanced" },
}

-- Sample SQL for live preview (covers ALL formatter rules)
local PREVIEW_SQL = [[
/*
 * Formatter Preview - Comprehensive SQL Sample
 * Tests all formatting rules
 */

-- CTE with multiple expressions (cte_style, cte_as_position, cte_columns_style, cte_separator_newline)
WITH ActiveUsers (id, username, email) AS (
    SELECT id, username, email
    FROM dbo.Users
    WHERE status = 'active'
),
RecentOrders AS (
    SELECT user_id, SUM(amount) AS total, COUNT(*) AS cnt
    FROM sales.Orders
    WHERE order_date BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY user_id
)

-- SELECT with DISTINCT, TOP, INTO, aliases (select_* rules, use_as_keyword)
SELECT DISTINCT TOP 100
    u.id AS user_id,
    u.username AS [User Name], -- inline comment alignment
    u.email,
    COALESCE(r.total, 0) AS total_spent,
    COUNT(o.id) AS order_count,
    AVG(o.amount) AS avg_order,
    MAX(o.order_date) AS last_order,
    u.first_name + ' ' + u.last_name AS full_name, -- concatenation spacing
    CASE -- case_style, case_when_indent, case_then_position
        WHEN r.total > 1000 THEN 'VIP'
        WHEN r.total > 500 THEN 'Regular'
        WHEN r.total IS NULL THEN 'Inactive'
        ELSE 'New'
    END AS customer_tier
INTO #TempResults
FROM ActiveUsers u WITH (NOLOCK) -- from_table_hints_newline
LEFT JOIN RecentOrders r ON u.id = r.user_id -- join_on_same_line, join_keyword_style
INNER JOIN dbo.Profiles p ON u.id = p.user_id
    AND p.is_verified = 1 -- on_condition_style, on_and_position
LEFT OUTER JOIN sales.OrderItems oi ON o.id = oi.order_id
CROSS APPLY ( -- cross_apply_newline, derived_table_style
    SELECT TOP 1 order_id, amount
    FROM sales.Orders sub
    WHERE sub.user_id = u.id
    ORDER BY order_date DESC
) AS latest
WHERE u.email LIKE '%@company.com' -- where_newline, where_condition_style
    AND u.created_at >= '2024-01-01'
    AND (o.amount > 100 OR o.is_priority = 1) -- boolean_operator_newline
    AND u.status IN ('active', 'pending', 'verified') -- where_in_list_style, in_list_style
    AND o.amount BETWEEN 50 AND 500 -- where_between_style
    AND EXISTS ( -- where_exists_style, subquery_paren_style
        SELECT 1
        FROM dbo.Subscriptions s
        WHERE s.user_id = u.id
            AND s.plan = 'premium'
    )
GROUP BY u.id, u.username, u.email, u.first_name, u.last_name, r.total -- group_by_style
HAVING COUNT(o.id) > 0 -- having_newline
    AND SUM(o.amount) >= 100
ORDER BY total_spent DESC, u.username ASC, u.id; -- order_by_style, order_direction_style

GO -- blank_line_after_go, batch_separator_style

-- UNION example (union_indent)
SELECT id, name, 'Customer' AS type FROM dbo.Customers
UNION ALL
SELECT id, name, 'Vendor' AS type FROM dbo.Vendors
ORDER BY name;

GO

-- INSERT with columns and multi-row VALUES (insert_* rules)
INSERT INTO dbo.AuditLog (action, user_id, timestamp, details)
VALUES
    ('LOGIN', 1, GETDATE(), 'User logged in'),
    ('VIEW', 1, GETDATE(), 'Viewed dashboard'),
    ('LOGOUT', 1, GETDATE(), 'User logged out');

-- UPDATE with SET alignment (update_set_style, update_set_align, equals_spacing)
UPDATE u
SET u.last_login = GETDATE(),
    u.login_count = u.login_count + 1,
    u.status = 'active',
    u.modified_by = SYSTEM_USER
FROM dbo.Users u
INNER JOIN #TempResults t ON u.id = t.user_id
WHERE u.is_enabled = 1;

-- DELETE with FROM keyword (delete_from_keyword)
DELETE FROM dbo.TempRecords
WHERE created_at < DATEADD(day, -30, GETDATE())
    AND status = 'expired';

-- OUTPUT clause (output_clause_newline)
DELETE FROM dbo.ExpiredSessions
OUTPUT deleted.session_id, deleted.user_id, GETDATE() AS deleted_at
INTO dbo.SessionArchive
WHERE expiry_date < GETDATE();

GO

-- MERGE statement (merge_style, merge_when_newline)
MERGE dbo.Products AS target
USING dbo.StagingProducts AS source
ON target.product_id = source.product_id
WHEN MATCHED AND source.is_deleted = 1 THEN
    DELETE
WHEN MATCHED THEN
    UPDATE SET
        target.name = source.name,
        target.price = source.price,
        target.modified_at = GETDATE()
WHEN NOT MATCHED BY TARGET THEN
    INSERT (product_id, name, price, created_at)
    VALUES (source.product_id, source.name, source.price, GETDATE())
WHEN NOT MATCHED BY SOURCE THEN
    DELETE;

GO

-- DDL: CREATE TABLE (create_table_column_newline, create_table_constraint_newline)
CREATE TABLE dbo.Orders (
    id INT IDENTITY(1,1) NOT NULL,
    user_id INT NOT NULL,
    amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    status VARCHAR(50) NOT NULL,
    order_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    notes NVARCHAR(MAX) NULL,
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (id),
    CONSTRAINT FK_Orders_Users FOREIGN KEY (user_id) REFERENCES dbo.Users(id),
    CONSTRAINT CK_Orders_Amount CHECK (amount >= 0)
);

-- CREATE INDEX (index_column_style)
CREATE NONCLUSTERED INDEX IX_Orders_UserDate
ON dbo.Orders (user_id, order_date DESC)
INCLUDE (amount, status)
WHERE status <> 'cancelled';

-- ALTER TABLE (alter_table_style)
ALTER TABLE dbo.Orders
ADD priority TINYINT NOT NULL DEFAULT 0,
    is_expedited BIT NOT NULL DEFAULT 0;

-- DROP IF EXISTS (drop_if_exists_style)
DROP TABLE IF EXISTS #TempResults;
DROP PROCEDURE IF EXISTS dbo.usp_OldProc;

GO

-- CREATE VIEW (view_body_indent)
CREATE VIEW dbo.vw_ActiveOrders
AS
    SELECT o.id, o.user_id, u.username, o.amount, o.status
    FROM dbo.Orders o
    INNER JOIN dbo.Users u ON o.user_id = u.id
    WHERE o.status IN ('pending', 'processing', 'shipped');

GO

-- CREATE PROCEDURE (procedure_param_style)
CREATE PROCEDURE dbo.usp_GetUserOrders
    @UserId INT,
    @StartDate DATETIME2 = NULL,
    @EndDate DATETIME2 = NULL,
    @Status VARCHAR(50) = 'active'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id, amount, status, order_date
    FROM dbo.Orders
    WHERE user_id = @UserId
        AND (@StartDate IS NULL OR order_date >= @StartDate)
        AND (@EndDate IS NULL OR order_date <= @EndDate)
        AND status = @Status
    ORDER BY order_date DESC;
END;

GO

-- CREATE FUNCTION (function_param_style, function_arg_style)
CREATE FUNCTION dbo.fn_CalculateDiscount (
    @Amount DECIMAL(18,2),
    @CustomerTier VARCHAR(20),
    @IsMember BIT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    RETURN CASE
        WHEN @CustomerTier = 'VIP' THEN @Amount * 0.20
        WHEN @CustomerTier = 'Regular' AND @IsMember = 1 THEN @Amount * 0.10
        WHEN @IsMember = 1 THEN @Amount * 0.05
        ELSE 0
    END;
END;

GO
]]

-- ============================================================================
-- Internal Helpers
-- ============================================================================

---Get value from config by key path
---@param config table
---@param key string
---@return any
local function get_config_value(config, key)
  local parts = vim.split(key, ".", { plain = true })
  local current = config
  for _, part in ipairs(parts) do
    if type(current) ~= "table" then return nil end
    current = current[part]
  end
  return current
end

---Set value in config by key path
---@param config table
---@param key string
---@param value any
local function set_config_value(config, key, value)
  local parts = vim.split(key, ".", { plain = true })
  local current = config
  for i = 1, #parts - 1 do
    if current[parts[i]] == nil then
      current[parts[i]] = {}
    end
    current = current[parts[i]]
  end
  current[parts[#parts]] = value
end

---Cycle value forward
---@param rule RuleDefinition
---@param current_value any
---@return any
local function cycle_forward(rule, current_value)
  if rule.type == "boolean" then
    return not current_value
  elseif rule.type == "enum" then
    local options = rule.options
    local current_idx = 1
    for i, opt in ipairs(options) do
      if opt == current_value then
        current_idx = i
        break
      end
    end
    return options[current_idx % #options + 1]
  elseif rule.type == "number" then
    local step = rule.step or 1
    local new_val = (current_value or 0) + step
    if rule.max and new_val > rule.max then
      new_val = rule.min or 0
    end
    return new_val
  end
  return current_value
end

---Cycle value backward
---@param rule RuleDefinition
---@param current_value any
---@return any
local function cycle_backward(rule, current_value)
  if rule.type == "boolean" then
    return not current_value
  elseif rule.type == "enum" then
    local options = rule.options
    local current_idx = 1
    for i, opt in ipairs(options) do
      if opt == current_value then
        current_idx = i
        break
      end
    end
    local prev_idx = current_idx - 1
    if prev_idx < 1 then prev_idx = #options end
    return options[prev_idx]
  elseif rule.type == "number" then
    local step = rule.step or 1
    local new_val = (current_value or 0) - step
    if rule.min and new_val < rule.min then
      new_val = rule.max or 999
    end
    return new_val
  end
  return current_value
end

---Format value for display
---@param rule RuleDefinition
---@param value any
---@return string
local function format_value(rule, value)
  if value == nil then
    return "nil"
  elseif rule.type == "boolean" then
    return value and "true" or "false"
  elseif rule.type == "number" then
    return tostring(value)
  else
    return tostring(value)
  end
end

-- ============================================================================
-- Public API
-- ============================================================================

---Close the rules editor
function RulesEditor.close()
  if multi_panel then
    -- Disable semantic highlighting on preview
    local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
    if ok and SemanticHighlighter.disable then
      local preview_buf = multi_panel:get_panel_buffer("preview")
      if preview_buf then
        pcall(SemanticHighlighter.disable, preview_buf)
      end
    end

    multi_panel:close()
    multi_panel = nil
  end
  state = nil
end

---Render the presets panel
---@param panel_state MultiPanelState
---@return string[] lines, table[] highlights
local function render_presets(panel_state)
  local lines = {}
  local highlights = {}

  if not state then return lines, highlights end

  -- Header
  table.insert(lines, "")

  local builtin_added = false
  local user_added = false

  for i, preset in ipairs(state.available_presets) do
    -- Add section headers
    if not preset.is_user and not builtin_added then
      table.insert(lines, " ─── Built-in ───")
      table.insert(highlights, {#lines - 1, 0, -1, "Comment"})
      table.insert(lines, "")
      builtin_added = true
    elseif preset.is_user and not user_added then
      if builtin_added then
        table.insert(lines, "")
      end
      table.insert(lines, " ─── User ───")
      table.insert(highlights, {#lines - 1, 0, -1, "Comment"})
      table.insert(lines, "")
      user_added = true
    end

    local prefix = i == state.selected_preset_idx and " ▶ " or "   "
    local line = string.format("%s%s", prefix, preset.name)
    table.insert(lines, line)

    local line_idx = #lines - 1
    if i == state.selected_preset_idx then
      table.insert(highlights, {line_idx, 0, -1, "SsnsFloatSelected"})
      table.insert(highlights, {line_idx, 1, 4, "Special"})
    end
  end

  table.insert(lines, "")

  return lines, highlights
end

---Render the rules panel
---@param panel_state MultiPanelState
---@return string[] lines, table[] highlights
local function render_rules(panel_state)
  local lines = {}
  local highlights = {}

  if not state then return lines, highlights end

  -- Header
  table.insert(lines, "")

  local current_category = nil

  for i, rule in ipairs(state.rule_definitions) do
    -- Add category header if new category
    if rule.category ~= current_category then
      if current_category ~= nil then
        table.insert(lines, "")
      end
      table.insert(lines, string.format(" ─── %s ───", rule.category))
      table.insert(highlights, {#lines - 1, 0, -1, "Comment"})
      table.insert(lines, "")
      current_category = rule.category
    end

    local value = get_config_value(state.current_config, rule.key)
    local display_value = format_value(rule, value)

    local prefix = i == state.selected_rule_idx and " ▶ " or "   "
    local line = string.format("%s%-20s [%s]", prefix, rule.name, display_value)
    table.insert(lines, line)

    local line_idx = #lines - 1
    if i == state.selected_rule_idx then
      table.insert(highlights, {line_idx, 0, -1, "SsnsFloatSelected"})
      table.insert(highlights, {line_idx, 1, 4, "Special"})
      local bracket_start = line:find("%[")
      if bracket_start then
        table.insert(highlights, {line_idx, bracket_start - 1, -1, "String"})
      end
    else
      local bracket_start = line:find("%[")
      if bracket_start then
        table.insert(highlights, {line_idx, bracket_start - 1, -1, "Number"})
      end
    end
  end

  table.insert(lines, "")

  return lines, highlights
end

---Render the preview panel
---@param panel_state MultiPanelState
---@return string[] lines, table[] highlights
local function render_preview(panel_state)
  if not state then return {}, {} end

  -- Format the preview SQL with current config
  local formatted = Formatter.format(PREVIEW_SQL, state.current_config)
  local lines = vim.split(formatted, '\n')

  return lines, {}
end

---Show the rules editor UI
function RulesEditor.show()
  -- Close existing editor if open
  RulesEditor.close()

  -- Load all presets
  local available_presets = Presets.list()

  -- Get current formatter config
  local current_config = vim.deepcopy(Config.get_formatter())

  -- Find which preset matches current config (if any)
  local selected_preset_idx = 1
  for i, preset in ipairs(available_presets) do
    local matches = true
    for key, val in pairs(preset.config) do
      if current_config[key] ~= val then
        matches = false
        break
      end
    end
    if matches then
      selected_preset_idx = i
      break
    end
  end

  -- Initialize state
  state = {
    available_presets = available_presets,
    selected_preset_idx = selected_preset_idx,
    selected_rule_idx = 1,
    current_config = current_config,
    original_config = vim.deepcopy(current_config),
    is_dirty = false,
    rule_definitions = RULE_DEFINITIONS,
    editing_user_copy = false,
  }

  -- Get keymaps from config
  local km = KeymapManager.get_group("common")

  -- Build preset title
  local preset = state.available_presets[state.selected_preset_idx]
  local preset_name = preset and preset.name or "None"
  if preset and preset.is_user then
    preset_name = preset_name .. " (user)"
  end

  -- Create multi-panel window using UiFloat nested layout
  -- Layout: 3 horizontal panels (presets | rules | preview)
  multi_panel = UiFloat.create_multi_panel({
    layout = {
      split = "horizontal",  -- Root split: 3 panels side by side
      children = {
        {
          name = "presets",
          title = "Presets",
          ratio = 0.18,
          on_render = render_presets,
          on_focus = function()
            if multi_panel and state then
              multi_panel:update_panel_title("presets", "Presets ●")
              multi_panel:update_panel_title("rules", RulesEditor._get_rules_title())
              -- Position cursor on selected preset
              local cursor_line = RulesEditor._get_preset_cursor_line(state.selected_preset_idx)
              multi_panel:set_cursor("presets", cursor_line, 0)
            end
          end,
        },
        {
          name = "rules",
          title = string.format("Settings [%s]", preset_name),
          ratio = 0.35,
          on_render = render_rules,
          on_focus = function()
            if multi_panel and state then
              multi_panel:update_panel_title("presets", "Presets")
              multi_panel:update_panel_title("rules", RulesEditor._get_rules_title() .. " ●")
              -- Position cursor on selected rule
              local cursor_line = RulesEditor._get_rule_cursor_line(state.selected_rule_idx)
              multi_panel:set_cursor("rules", cursor_line, 0)
            end
          end,
        },
        {
          name = "preview",
          title = "Preview",
          ratio = 0.47,
          filetype = "sql",
          focusable = true,
          cursorline = false,
          on_render = render_preview,
        },
      },
    },
    total_width_ratio = 0.90,
    total_height_ratio = 0.70,
    footer = " j/k=Nav  h/l=Change  <Tab>=Panel  s=Save  a=Apply  R=Reset  q=Cancel ",
    initial_focus = "presets",
    augroup_name = "SSNSFormatterRulesEditor",
    on_close = function()
      -- Disable semantic highlighting
      local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
      if ok and SemanticHighlighter.disable and multi_panel then
        local preview_buf = multi_panel:get_panel_buffer("preview")
        if preview_buf then
          pcall(SemanticHighlighter.disable, preview_buf)
        end
      end
      multi_panel = nil
      state = nil
    end,
  })

  if not multi_panel then
    return
  end

  -- Render all panels
  multi_panel:render_all()

  -- Apply semantic highlighting to preview
  RulesEditor._apply_preview_highlights()

  -- Setup keymaps
  RulesEditor._setup_keymaps()

  -- Mark initial focus
  multi_panel:update_panel_title("presets", "Presets ●")

  -- Position cursor on first preset (after render is complete)
  vim.schedule(function()
    if multi_panel and multi_panel:is_valid() and state then
      local cursor_line = RulesEditor._get_preset_cursor_line(state.selected_preset_idx)
      multi_panel:set_cursor("presets", cursor_line, 0)
    end
  end)
end

---Apply semantic highlighting to preview
function RulesEditor._apply_preview_highlights()
  if not multi_panel then return end
  local preview_buf = multi_panel:get_panel_buffer("preview")
  if not preview_buf then return end

  local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
  if ok and SemanticHighlighter.enable then
    pcall(SemanticHighlighter.enable, preview_buf)
    vim.defer_fn(function()
      if multi_panel and preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
        pcall(SemanticHighlighter.update, preview_buf)
      end
    end, 50)
  end
end

---Calculate cursor line for preset index
---@param preset_idx number The preset index
---@return number line The cursor line (1-indexed)
function RulesEditor._get_preset_cursor_line(preset_idx)
  if not state then return 1 end

  -- Start after header (line 1 is empty)
  local line = 2  -- "─── Built-in ───" header
  line = line + 1  -- Empty line after header
  line = line + 1  -- First preset starts here

  -- Count lines to reach the selected preset
  local builtin_added = false
  local user_added = false

  for i, preset in ipairs(state.available_presets) do
    -- Account for section headers
    if not preset.is_user and not builtin_added then
      builtin_added = true
      -- Already counted above for first preset
    elseif preset.is_user and not user_added then
      if builtin_added then
        line = line + 1  -- Empty line between sections
      end
      line = line + 1  -- "─── User ───" header
      line = line + 1  -- Empty line after header
      user_added = true
    end

    if i == preset_idx then
      return line
    end
    line = line + 1
  end

  return line
end

---Calculate cursor line for rule index
---@param rule_idx number The rule index
---@return number line The cursor line (1-indexed)
function RulesEditor._get_rule_cursor_line(rule_idx)
  if not state then return 1 end

  -- Start after header (line 1 is empty)
  local line = 2  -- First category header
  line = line + 1  -- Empty line after header
  line = line + 1  -- First rule starts here

  local current_category = nil

  for i, rule in ipairs(state.rule_definitions) do
    -- Account for category headers
    if rule.category ~= current_category then
      if current_category ~= nil then
        line = line + 1  -- Empty line before category
        line = line + 1  -- Category header
        line = line + 1  -- Empty line after header
      end
      current_category = rule.category
    end

    if i == rule_idx then
      return line
    end
    line = line + 1
  end

  return line
end

---Get dynamic title for rules panel
---@return string
function RulesEditor._get_rules_title()
  if not state then return "Settings" end
  local preset = state.available_presets[state.selected_preset_idx]
  local preset_name = preset and preset.name or "Custom"
  if preset and preset.is_user then
    preset_name = preset_name .. " (user)"
  end
  local dirty_indicator = state.is_dirty and " *" or ""
  return string.format("Settings [%s]%s", preset_name, dirty_indicator)
end

---Setup keymaps for all panels
function RulesEditor._setup_keymaps()
  if not multi_panel then return end

  local km = KeymapManager.get_group("common")

  -- Presets panel keymaps
  multi_panel:set_panel_keymaps("presets", {
    [km.cancel or "<Esc>"] = function() RulesEditor.close() end,
    [km.close or "q"] = function() RulesEditor.close() end,
    ["a"] = function() RulesEditor._apply() end,
    [km.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [km.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.nav_down or "j"] = function() RulesEditor._navigate_presets(1) end,
    [km.nav_up or "k"] = function() RulesEditor._navigate_presets(-1) end,
    [km.nav_down_alt or "<Down>"] = function() RulesEditor._navigate_presets(1) end,
    [km.nav_up_alt or "<Up>"] = function() RulesEditor._navigate_presets(-1) end,
    [km.confirm or "<CR>"] = function() RulesEditor._select_preset() end,
    ["d"] = function() RulesEditor._delete_preset() end,
    ["r"] = function() RulesEditor._rename_preset() end,
  })

  -- Rules panel keymaps
  multi_panel:set_panel_keymaps("rules", {
    [km.cancel or "<Esc>"] = function() RulesEditor.close() end,
    [km.close or "q"] = function() RulesEditor.close() end,
    ["a"] = function() RulesEditor._apply() end,
    [km.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [km.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.nav_down or "j"] = function() RulesEditor._navigate_rules(1) end,
    [km.nav_up or "k"] = function() RulesEditor._navigate_rules(-1) end,
    [km.nav_down_alt or "<Down>"] = function() RulesEditor._navigate_rules(1) end,
    [km.nav_up_alt or "<Up>"] = function() RulesEditor._navigate_rules(-1) end,
    ["l"] = function() RulesEditor._cycle_value(1) end,
    ["h"] = function() RulesEditor._cycle_value(-1) end,
    ["+"] = function() RulesEditor._cycle_value(1) end,
    ["-"] = function() RulesEditor._cycle_value(-1) end,
    ["<Right>"] = function() RulesEditor._cycle_value(1) end,
    ["<Left>"] = function() RulesEditor._cycle_value(-1) end,
    ["s"] = function() RulesEditor._save_preset() end,
    ["R"] = function() RulesEditor._reset() end,
  })

  -- Preview panel keymaps (just close and navigation)
  multi_panel:set_panel_keymaps("preview", {
    [km.cancel or "<Esc>"] = function() RulesEditor.close() end,
    [km.close or "q"] = function() RulesEditor.close() end,
    ["a"] = function() RulesEditor._apply() end,
    [km.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [km.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
  })
end

---Navigate through presets
---@param direction number 1 for down, -1 for up
function RulesEditor._navigate_presets(direction)
  if not state or not multi_panel then return end

  state.selected_preset_idx = state.selected_preset_idx + direction

  if state.selected_preset_idx < 1 then
    state.selected_preset_idx = #state.available_presets
  elseif state.selected_preset_idx > #state.available_presets then
    state.selected_preset_idx = 1
  end

  -- Load the preset config
  local preset = state.available_presets[state.selected_preset_idx]
  if preset then
    state.current_config = vim.tbl_deep_extend("force", Config.get_formatter(), preset.config)
    state.is_dirty = false
    state.editing_user_copy = false
  end

  multi_panel:render_all()
  multi_panel:update_panel_title("rules", RulesEditor._get_rules_title())

  -- Position cursor on selected preset
  local cursor_line = RulesEditor._get_preset_cursor_line(state.selected_preset_idx)
  multi_panel:set_cursor("presets", cursor_line, 0)

  -- Apply semantic highlighting to preview
  RulesEditor._apply_preview_highlights()
end

---Select current preset (same as navigate but explicit)
function RulesEditor._select_preset()
  if not state or not multi_panel then return end

  local preset = state.available_presets[state.selected_preset_idx]
  if preset then
    state.current_config = vim.tbl_deep_extend("force", Config.get_formatter(), preset.config)
    state.is_dirty = false
    state.editing_user_copy = false

    multi_panel:render_panel("rules")
    multi_panel:render_panel("preview")
    multi_panel:update_panel_title("rules", RulesEditor._get_rules_title())

    -- Apply semantic highlighting to preview
    RulesEditor._apply_preview_highlights()

    -- Move to rules panel and position cursor
    multi_panel:focus_panel("rules")
    local cursor_line = RulesEditor._get_rule_cursor_line(state.selected_rule_idx)
    multi_panel:set_cursor("rules", cursor_line, 0)
  end
end

---Navigate through rules
---@param direction number 1 for down, -1 for up
function RulesEditor._navigate_rules(direction)
  if not state or not multi_panel then return end

  state.selected_rule_idx = state.selected_rule_idx + direction

  if state.selected_rule_idx < 1 then
    state.selected_rule_idx = #state.rule_definitions
  elseif state.selected_rule_idx > #state.rule_definitions then
    state.selected_rule_idx = 1
  end

  multi_panel:render_panel("rules")

  -- Position cursor on selected rule
  local cursor_line = RulesEditor._get_rule_cursor_line(state.selected_rule_idx)
  multi_panel:set_cursor("rules", cursor_line, 0)
end

---Cycle the value of current rule
---@param direction number 1 for forward, -1 for backward
function RulesEditor._cycle_value(direction)
  if not state or not multi_panel then return end

  -- Check if we need to create a user copy first
  local preset = state.available_presets[state.selected_preset_idx]
  if preset and not preset.is_user and not state.editing_user_copy then
    -- Auto-create a user copy
    local copy_name = preset.name .. " - COPY"
    local file_name = (preset.file_name or preset.name:lower():gsub("%s+", "_")) .. "_copy"
    file_name = Presets.generate_unique_name(file_name, true)

    local ok, err = Presets.save(file_name, copy_name, state.current_config, "Auto-created copy of " .. preset.name)
    if ok then
      -- Reload presets and select the new copy
      Presets.clear_cache()
      state.available_presets = Presets.list()

      -- Find the new copy
      for i, p in ipairs(state.available_presets) do
        if p.name == copy_name or p.file_name == file_name then
          state.selected_preset_idx = i
          break
        end
      end

      state.editing_user_copy = true
      vim.notify("Created user copy: " .. copy_name, vim.log.levels.INFO)
      multi_panel:render_panel("presets")
    else
      vim.notify("Failed to create copy: " .. (err or "unknown"), vim.log.levels.ERROR)
      return
    end
  end

  local rule = state.rule_definitions[state.selected_rule_idx]
  if not rule then return end

  local current_value = get_config_value(state.current_config, rule.key)
  local new_value

  if direction > 0 then
    new_value = cycle_forward(rule, current_value)
  else
    new_value = cycle_backward(rule, current_value)
  end

  set_config_value(state.current_config, rule.key, new_value)
  state.is_dirty = true

  multi_panel:render_panel("rules")
  multi_panel:update_panel_title("rules", RulesEditor._get_rules_title() .. " ●")

  -- Debounced preview update
  vim.defer_fn(function()
    if multi_panel and state then
      multi_panel:render_panel("preview")
      RulesEditor._apply_preview_highlights()
    end
  end, 50)
end

---Apply changes
function RulesEditor._apply()
  if not state then return end

  Config.current.formatter = state.current_config

  -- If dirty, save to preset if it's a user preset
  if state.is_dirty then
    local preset = state.available_presets[state.selected_preset_idx]
    if preset and preset.is_user then
      Presets.save(preset.file_name, preset.name, state.current_config, preset.description)
    end
  end

  vim.notify("Formatter config applied", vim.log.levels.INFO)
  RulesEditor.close()
end

---Reset current preset to its original values
function RulesEditor._reset()
  if not state or not multi_panel then return end

  local preset = state.available_presets[state.selected_preset_idx]
  if preset then
    -- Reload preset from disk
    Presets.clear_cache()
    local fresh_preset = Presets.load(preset.file_name or preset.name)
    if fresh_preset then
      state.current_config = vim.tbl_deep_extend("force", Config.get_formatter(), fresh_preset.config)
      state.is_dirty = false

      multi_panel:render_panel("rules")
      multi_panel:render_panel("preview")
      multi_panel:update_panel_title("rules", RulesEditor._get_rules_title())
      RulesEditor._apply_preview_highlights()

      vim.notify("Reset to preset defaults", vim.log.levels.INFO)
    end
  end
end

---Save current config as a new preset
function RulesEditor._save_preset()
  if not state or not multi_panel then return end

  local current_preset = state.available_presets[state.selected_preset_idx]
  local default_name = current_preset and current_preset.is_user and current_preset.name or Presets.generate_unique_name("Custom")

  local save_win = UiFloat.create({
    title = "Save Preset",
    width = 55,
    height = 8,
    center = true,
    content_builder = true,
    enable_inputs = true,
    zindex = UiFloat.ZINDEX.MODAL,
  })

  if save_win then
    local cb = save_win:get_content_builder()
    cb:line("")
    cb:line("  Save current settings as preset:", "SsnsUiTitle")
    cb:line("")
    cb:labeled_input("name", "  Name", {
      value = default_name,
      placeholder = "(enter preset name)",
      width = 35,  -- Default width, expands for longer names
    })
    cb:line("")
    cb:line("  <Enter>=Save | <Esc>=Cancel", "SsnsUiHint")
    save_win:render()

    local function do_save()
      local name = save_win:get_input_value("name")
      save_win:close()

      if not name or name == "" then return end

      local file_name = name:gsub("[^%w_%-]", "_")
      local ok, err = Presets.save(file_name, name, state.current_config, "User-defined preset")

      if ok then
        -- Reload presets
        Presets.clear_cache()
        state.available_presets = Presets.list()

        -- Find and select the new preset
        for i, p in ipairs(state.available_presets) do
          if p.name == name then
            state.selected_preset_idx = i
            break
          end
        end

        state.is_dirty = false
        if multi_panel then
          multi_panel:render_panel("presets")
          multi_panel:update_panel_title("rules", RulesEditor._get_rules_title())
        end

        vim.notify("Preset saved: " .. name, vim.log.levels.INFO)
      else
        vim.notify("Failed to save: " .. (err or "unknown"), vim.log.levels.ERROR)
      end
    end

    vim.keymap.set("n", "<CR>", function()
      save_win:enter_input()
    end, { buffer = save_win.buf, nowait = true })

    vim.keymap.set("n", "<Esc>", function()
      save_win:close()
    end, { buffer = save_win.buf, nowait = true })

    vim.keymap.set("n", "q", function()
      save_win:close()
    end, { buffer = save_win.buf, nowait = true })

    save_win:on_input_submit(do_save)
  end
end

---Delete selected preset (user only)
function RulesEditor._delete_preset()
  if not state or not multi_panel then return end

  local preset = state.available_presets[state.selected_preset_idx]
  if not preset or not preset.is_user then
    vim.notify("Can only delete user presets", vim.log.levels.WARN)
    return
  end

  vim.ui.select({ "Yes", "No" }, {
    prompt = string.format("Delete '%s'?", preset.name),
  }, function(choice)
    if choice ~= "Yes" then return end

    local ok, err = Presets.delete(preset.file_name)
    if ok then
      Presets.clear_cache()
      state.available_presets = Presets.list()
      state.selected_preset_idx = math.min(state.selected_preset_idx, #state.available_presets)

      -- Load the now-selected preset
      local new_preset = state.available_presets[state.selected_preset_idx]
      if new_preset then
        state.current_config = vim.tbl_deep_extend("force", Config.get_formatter(), new_preset.config)
      end

      state.is_dirty = false
      if multi_panel then
        multi_panel:render_all()
        multi_panel:update_panel_title("rules", RulesEditor._get_rules_title())
        RulesEditor._apply_preview_highlights()
      end

      vim.notify("Preset deleted", vim.log.levels.INFO)
    else
      vim.notify("Failed to delete: " .. (err or "unknown"), vim.log.levels.ERROR)
    end
  end)
end

---Rename selected preset (user only)
function RulesEditor._rename_preset()
  if not state or not multi_panel then return end

  local preset = state.available_presets[state.selected_preset_idx]
  if not preset or not preset.is_user then
    vim.notify("Can only rename user presets", vim.log.levels.WARN)
    return
  end

  local rename_win = UiFloat.create({
    title = "Rename Preset",
    width = 55,
    height = 8,
    center = true,
    content_builder = true,
    enable_inputs = true,
    zindex = UiFloat.ZINDEX.MODAL,
  })

  if rename_win then
    local cb = rename_win:get_content_builder()
    cb:line("")
    cb:line(string.format("  Rename preset '%s':", preset.name), "SsnsUiTitle")
    cb:line("")
    cb:labeled_input("name", "  New name", {
      value = preset.name,
      placeholder = "(enter new name)",
      width = 32,  -- Default width, expands for longer names
    })
    cb:line("")
    cb:line("  <Enter>=Rename | <Esc>=Cancel", "SsnsUiHint")
    rename_win:render()

    local function do_rename()
      local new_name = rename_win:get_input_value("name")
      rename_win:close()

      if not new_name or new_name == "" then return end

      local ok, err = Presets.rename(preset.file_name, new_name)
      if ok then
        Presets.clear_cache()
        state.available_presets = Presets.list()

        -- Find the renamed preset
        for i, p in ipairs(state.available_presets) do
          if p.name == new_name then
            state.selected_preset_idx = i
            break
          end
        end

        if multi_panel then
          multi_panel:render_panel("presets")
          multi_panel:update_panel_title("rules", RulesEditor._get_rules_title())
        end

        vim.notify("Preset renamed", vim.log.levels.INFO)
      else
        vim.notify("Failed to rename: " .. (err or "unknown"), vim.log.levels.ERROR)
      end
    end

    vim.keymap.set("n", "<CR>", function()
      rename_win:enter_input()
    end, { buffer = rename_win.buf, nowait = true })

    vim.keymap.set("n", "<Esc>", function()
      rename_win:close()
    end, { buffer = rename_win.buf, nowait = true })

    vim.keymap.set("n", "q", function()
      rename_win:close()
    end, { buffer = rename_win.buf, nowait = true })

    rename_win:on_input_submit(do_rename)
  end
end

---Check if editor is open
---@return boolean
function RulesEditor.is_open()
  return multi_panel ~= nil
end

return RulesEditor
