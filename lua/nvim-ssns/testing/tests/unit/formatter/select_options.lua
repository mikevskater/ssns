-- Test file: select_options.lua
-- IDs: 8451-84620
-- Tests: SELECT clause options - DISTINCT, TOP, INTO, list_style, select_column_align

return {
    -- SELECT clause options
    {
        id = 8451,
        type = "formatter",
        name = "select_distinct_newline true",
        input = "SELECT DISTINCT name, email FROM users",
        opts = { select_distinct_newline = true },
        expected = {
            matches = { "SELECT\n.-DISTINCT" }
        }
    },
    {
        id = 8452,
        type = "formatter",
        name = "select_distinct_newline false (default)",
        input = "SELECT DISTINCT name FROM users",
        opts = { select_distinct_newline = false },
        expected = {
            contains = { "SELECT DISTINCT" }  -- On same line
        }
    },
    {
        id = 8453,
        type = "formatter",
        name = "select_top_newline true",
        input = "SELECT TOP 10 * FROM users",
        opts = { select_top_newline = true },
        expected = {
            matches = { "SELECT\n.-TOP 10" }
        }
    },
    {
        id = 8454,
        type = "formatter",
        name = "select_top_newline false (default)",
        input = "SELECT TOP 10 * FROM users",
        opts = { select_top_newline = false },
        expected = {
            contains = { "SELECT TOP 10" }  -- On same line
        }
    },
    {
        id = 8455,
        type = "formatter",
        name = "select_into_newline true",
        input = "SELECT * INTO #temp FROM users",
        opts = { select_into_newline = true },
        expected = {
            matches = { "SELECT %*\n.-INTO" }
        }
    },

    -- select_list_style tests
    {
        id = 8456,
        type = "formatter",
        name = "select_list_style stacked - each column on new line",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "stacked" },
        expected = {
            matches = { "SELECT id,\n.-name,\n.-email" }
        }
    },
    {
        id = 8457,
        type = "formatter",
        name = "select_list_style inline - all columns on one line",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "inline" },
        expected = {
            contains = { "SELECT id, name, email" }
        }
    },
    {
        id = 8458,
        type = "formatter",
        name = "select_list_style stacked with aliases",
        input = "SELECT u.id AS user_id, u.name AS user_name FROM users u",
        opts = { select_list_style = "stacked" },
        expected = {
            matches = { "SELECT u.id AS user_id,\n.-u.name AS user_name" }
        }
    },
    {
        id = 8459,
        type = "formatter",
        name = "select_list_style stacked - function calls stay on same line",
        input = "SELECT COUNT(*), SUM(amount), MAX(created_at) FROM orders",
        opts = { select_list_style = "stacked" },
        expected = {
            -- Function arguments should not trigger newlines (paren_depth > 0)
            contains = { "COUNT(*)", "SUM(amount)", "MAX(created_at)" },
            matches = { "SELECT COUNT%(%*%),\n.-SUM%(amount%),\n.-MAX%(created_at%)" }
        }
    },
    {
        id = 84591,
        type = "formatter",
        name = "select_list_style stacked_indent - first column on new line",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- First column should be on new line after SELECT
            matches = { "SELECT\n.-id,\n.-name,\n.-email" }
        }
    },
    {
        id = 84592,
        type = "formatter",
        name = "select_list_style stacked_indent - indented properly",
        input = "SELECT id, name FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- Columns should be indented (4 spaces default)
            matches = { "SELECT\n    id,\n    name" }
        }
    },
    {
        id = 84593,
        type = "formatter",
        name = "select_list_style stacked vs stacked_indent comparison",
        input = "SELECT a, b FROM t",
        opts = { select_list_style = "stacked" },
        expected = {
            -- stacked: first column on same line as SELECT
            contains = { "SELECT a," }
        }
    },
    {
        id = 84594,
        type = "formatter",
        name = "select_list_style stacked_indent with DISTINCT - DISTINCT stays on SELECT line",
        input = "SELECT DISTINCT id, name FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- DISTINCT should stay on same line as SELECT, columns on new lines
            contains = { "SELECT DISTINCT" },
            matches = { "SELECT DISTINCT\n    id,\n    name" }
        }
    },
    {
        id = 84595,
        type = "formatter",
        name = "select_list_style stacked_indent with TOP - TOP stays on SELECT line",
        input = "SELECT TOP 10 id, name FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- TOP 10 should stay on same line as SELECT, columns on new lines
            contains = { "SELECT TOP 10" },
            matches = { "SELECT TOP 10\n    id,\n    name" }
        }
    },

    -- select_column_align tests
    -- "left" (default): columns use standard indent (4 spaces)
    -- "keyword": columns align to start at position after "SELECT " (7 chars)
    {
        id = 84600,
        type = "formatter",
        name = "select_column_align left (default) - standard indent",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "stacked", select_column_align = "left" },
        expected = {
            -- Default 4-space indent for columns
            matches = { "SELECT id,\n    name,\n    email" }
        }
    },
    {
        id = 84601,
        type = "formatter",
        name = "select_column_align keyword - columns align to SELECT",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "stacked", select_column_align = "keyword" },
        expected = {
            -- Columns align to position after "SELECT " (7 spaces)
            matches = { "SELECT id,\n       name,\n       email" }
        }
    },
    {
        id = 84602,
        type = "formatter",
        name = "select_column_align keyword with stacked_indent",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "stacked_indent", select_column_align = "keyword" },
        expected = {
            -- First column on new line, all columns align to "SELECT " position
            matches = { "SELECT\n       id,\n       name,\n       email" }
        }
    },
    {
        id = 84603,
        type = "formatter",
        name = "select_column_align keyword with DISTINCT",
        input = "SELECT DISTINCT id, name FROM users",
        opts = { select_list_style = "stacked", select_column_align = "keyword" },
        expected = {
            -- Columns align to position after "SELECT " even with DISTINCT
            -- "SELECT DISTINCT id," - subsequent columns align to position 7
            matches = { "SELECT DISTINCT id,\n       name" }
        }
    },
    {
        id = 84604,
        type = "formatter",
        name = "select_column_align keyword with longer expressions",
        input = "SELECT user_id, first_name, last_name FROM users",
        opts = { select_list_style = "stacked", select_column_align = "keyword" },
        expected = {
            -- Columns align to position after "SELECT "
            matches = { "SELECT user_id,\n       first_name,\n       last_name" }
        }
    },
    {
        id = 84605,
        type = "formatter",
        name = "select_column_align keyword in subquery",
        input = "SELECT * FROM (SELECT id, name FROM users) AS sub",
        opts = { select_list_style = "stacked", select_column_align = "keyword" },
        expected = {
            -- Subquery columns should also align to their SELECT keyword
            -- Base indent for subquery is 4, so SELECT at 4, columns at 4+7=11 (but relative)
            matches = { "SELECT id,\n           name" }
        }
    },
    {
        id = 84606,
        type = "formatter",
        name = "select_column_align left in subquery - standard indent",
        input = "SELECT * FROM (SELECT id, name FROM users) AS sub",
        opts = { select_list_style = "stacked", select_column_align = "left" },
        expected = {
            -- Subquery columns use standard indent (base+1)
            matches = { "SELECT id,\n        name" }  -- 8 spaces = base(4) + indent(4)
        }
    },
    {
        id = 84607,
        type = "formatter",
        name = "select_column_align left with inline style - no effect",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "inline", select_column_align = "left" },
        expected = {
            -- inline style keeps all columns on one line, align has no effect
            contains = { "SELECT id, name, email" }
        }
    },
    {
        id = 84608,
        type = "formatter",
        name = "select_column_align keyword with inline style - no effect",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "inline", select_column_align = "keyword" },
        expected = {
            -- inline style keeps all columns on one line, align has no effect
            contains = { "SELECT id, name, email" }
        }
    },
    {
        id = 84609,
        type = "formatter",
        name = "select_column_align keyword with aliases",
        input = "SELECT u.id AS user_id, u.name AS user_name FROM users u",
        opts = { select_list_style = "stacked", select_column_align = "keyword" },
        expected = {
            -- Columns with aliases align to position after "SELECT "
            matches = { "SELECT u.id AS user_id,\n       u.name AS user_name" }
        }
    },
    {
        id = 84610,
        type = "formatter",
        name = "select_column_align keyword with functions",
        input = "SELECT COUNT(*), SUM(amount), MAX(created) FROM orders",
        opts = { select_list_style = "stacked", select_column_align = "keyword" },
        expected = {
            -- Function columns align to position after "SELECT "
            matches = { "SELECT COUNT%(%*%),\n       SUM%(amount%),\n       MAX%(created%)" }
        }
    },
}
