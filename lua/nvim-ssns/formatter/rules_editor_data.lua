---@class FormatterRulesEditorData
---Rule definitions and preview SQL for the formatter rules editor
local M = {}

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

-- Rule definitions organized by category
M.RULE_DEFINITIONS = {
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
M.PREVIEW_SQL = [[
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

return M
