---@class SsnsConfig
---@field connections table<string, string> Map of connection names to connection strings
---@field ui UiConfig UI configuration
---@field cache CacheConfig Cache configuration
---@field query QueryConfig Query execution configuration
---@field query_history QueryHistoryConfig Query history configuration
---@field keymaps KeymapsConfig Keymap configuration
---@field table_helpers TableHelpersConfig Table helper templates per database type
---@field performance PerformanceConfig Performance tuning options
---@field lualine LualineConfig Lualine statusline integration
---@field completion CompletionConfig IntelliSense completion configuration
---@field semantic_highlighting SemanticHighlightingConfig Semantic highlighting configuration
---@field formatter FormatterConfig SQL formatter configuration

---@class UiConfig
---@field position string Window position: "left", "right", "float"
---@field width number Window width (columns for split, or 0-1 for percentage in float mode)
---@field height number? Window height (for float - rows or 0-1 for percentage)
---@field float_border string|table? Border style for float: "none", "single", "double", "rounded", "solid", or custom table
---@field float_title boolean? Show title in float mode (default: true)
---@field float_title_text string? Custom title text for float window (default: " SSNS ")
---@field float_zindex number? Window z-index for float layering (default: 50)
---@field tree_auto_expand boolean? Auto-expand tree width to fit content (default: false)
---@field ssms_style boolean Use SSMS-style UI
---@field show_schema_prefix boolean Show schema prefix in object names
---@field auto_expand_depth number? Auto-expand tree to this depth on load
---@field smart_cursor_positioning boolean Enable smart cursor positioning on j/k movement (default: true)
---@field result_set_divider string? Format for divider between multiple result sets (default: "")
---@field show_result_set_info boolean Show divider/info before first result set and single result sets (default: false)
---@field show_help boolean Show help text at top of tree buffer (default: true)
---@field icons IconsConfig Icon configuration
---@field filters FiltersConfig Default filter configuration

---@class FiltersConfig
---@field hide_system_schemas boolean Hide system schemas by default (sys, INFORMATION_SCHEMA, etc.)
---@field system_schemas string[] List of schema names to consider as "system" schemas

---@class IconsConfig
---@field server string Server icon
---@field database string Database icon
---@field schema string Schema/folder icon
---@field table string Table icon
---@field view string View icon
---@field procedure string Procedure icon
---@field function string Function icon
---@field column string Column icon
---@field index string Index icon
---@field key string Key/constraint icon
---@field action string Action icon
---@field sequence string Sequence icon
---@field synonym string Synonym icon
---@field connected string Connected status icon
---@field disconnected string Disconnected status icon
---@field connecting string Connecting/loading status icon
---@field error string Error status icon
---@field expanded string Expanded tree node icon
---@field collapsed string Collapsed tree node icon

---@class CacheConfig
---@field ttl number Time to live in seconds for cached data
---@field enabled boolean Enable query result caching (default: true)

---@class QueryConfig
---@field default_limit number Default LIMIT for SELECT queries (0 = no limit)
---@field timeout number Query timeout in milliseconds (0 = no timeout)
---@field auto_execute_on_open boolean Auto-execute query when opening action (default: false)

---@class QueryHistoryConfig
---@field enabled boolean Enable query history tracking (default: true)
---@field max_buffers number Maximum buffer histories to keep (default: 100)
---@field max_entries_per_buffer number Maximum entries per buffer (default: 100)
---@field auto_persist boolean Auto-save history to file (default: true)
---@field persist_file string Path to history file
---@field exclude_patterns string[] Queries to exclude from history (default: {"SELECT 1", "SELECT @@"})

---@class KeymapsConfig
---@field common CommonKeymaps Common keymaps shared across multiple UIs
---@field tree TreeKeymaps Tree buffer keymaps
---@field query QueryKeymaps Query buffer keymaps
---@field history HistoryKeymaps History UI keymaps
---@field filter FilterKeymaps Filter UI keymaps
---@field param ParamKeymaps Parameter input keymaps
---@field add_server AddServerKeymaps Add server UI keymaps
---@field formatter FormatterKeymaps SQL formatter keymaps

---@class CommonKeymaps Common keymaps shared across multiple UIs
---@field close string Close window (default: "q")
---@field cancel string Cancel/escape (default: "<Esc>")
---@field confirm string Confirm/apply (default: "<CR>")
---@field nav_down string Navigate down (default: "j")
---@field nav_up string Navigate up (default: "k")
---@field nav_down_alt string Navigate down alternate (default: "<Down>")
---@field nav_up_alt string Navigate up alternate (default: "<Up>")
---@field next_field string Next field (default: "<Tab>")
---@field prev_field string Previous field (default: "<S-Tab>")
---@field edit string Edit/insert mode (default: "i")

---@class TreeKeymaps Tree buffer specific keymaps
---@field toggle string Toggle expand/collapse (default: "<CR>")
---@field toggle_alt string Alternate toggle key (default: "o")
---@field refresh string Refresh current node (default: "r")
---@field refresh_all string Refresh all servers (default: "R")
---@field filter string Open filter UI (default: "f")
---@field filter_clear string Clear all filters (default: "F")
---@field toggle_connection string Toggle server connection (default: "d")
---@field set_lualine_color string Set lualine color (default: "<Leader>c")
---@field help string Show help (default: "?")
---@field new_query string New query buffer (default: "<C-n>")
---@field goto_first_child string Go to first child (default: "<C-[>")
---@field goto_last_child string Go to last child (default: "<C-]>")
---@field toggle_group string Toggle parent group (default: "g")
---@field add_server string Open add server UI (default: "a")
---@field toggle_favorite string Toggle favorite (default: "*")
---@field show_history string Show query history (default: "<Leader>@")

---@class QueryKeymaps Query buffer specific keymaps
---@field execute string Execute query (default: "<Leader>r")
---@field execute_selection string Execute visual selection (default: "<Leader>r")
---@field execute_statement string Execute statement under cursor (default: "<Leader>R")
---@field save_query string Save query to file (default: "<Leader>s")
---@field expand_asterisk string Expand asterisk to columns (default: "<Leader>ce")
---@field go_to string Go to object in tree (default: "gd")
---@field view_definition string View object definition (default: "K")
---@field view_metadata string View object metadata (default: "M")
---@field new_query string New query buffer (default: "<C-n>")
---@field show_history string Show query history (default: "<Leader>@")
---@field attach_connection string Attach buffer to connection (default: "<Leader>cs")
---@field change_connection string Change connection (hierarchical picker) (default: "<Leader>cA")
---@field change_database string Change database only (default: "<Leader>cd")

---@class HistoryKeymaps History UI specific keymaps
---@field switch_panel string Switch between panels (default: "<Tab>")
---@field toggle_preview string Toggle preview panel (default: "<S-Tab>")
---@field load_query string Load selected query (default: "<CR>")
---@field delete string Delete entry (default: "d")
---@field clear_all string Clear all entries (default: "c")
---@field export string Export history (default: "x")
---@field search string Search history (default: "/")

---@class FilterKeymaps Filter UI specific keymaps
---@field apply string Apply filters (default: "<CR>")
---@field clear string Clear all filters (default: "F")
---@field toggle_checkbox string Toggle checkbox (default: "<Space>")

---@class ParamKeymaps Parameter input specific keymaps
---@field execute string Execute with parameters (default: "<CR>")

---@class AddServerKeymaps Add server UI specific keymaps
---@field add string Add to tree (default: "a")
---@field new string New connection (default: "n")
---@field delete string Delete connection (default: "d")
---@field edit_connection string Edit connection (default: "e")
---@field toggle_favorite string Toggle favorite (default: "f")
---@field toggle_favorite_alt string Toggle favorite alternate (default: "*")
---@field db_type string Change database type (default: "t")
---@field set_name string Set connection name (default: "n")
---@field set_path string Set server path (default: "p")
---@field save string Save connection (default: "s")
---@field test string Test connection (default: "T")
---@field back string Go back (default: "b")
---@field toggle_auto_connect string Toggle auto-connect (default: "a")

---@class FormatterKeymaps SQL formatter keymaps
---@field format_buffer string Format entire buffer (default: "<Leader>sf")
---@field format_statement string Format statement under cursor (default: "<Leader>ss")
---@field open_config string Open formatter config UI (default: "<Leader>sc")

---@class TableHelpersConfig
---@field sqlserver table<string, string>? SQL Server helper templates
---@field postgres table<string, string>? PostgreSQL helper templates
---@field mysql table<string, string>? MySQL helper templates
---@field sqlite table<string, string>? SQLite helper templates

---@class PerformanceConfig
---@field lazy_load boolean Enable lazy loading (default: true)
---@field page_size number Number of items to load per page (0 = load all)
---@field async boolean Use async operations where possible (default: true)

---@class LualineConfig
---@field enabled boolean Enable lualine integration (default: true)
---@field colors table<string, table> Color map for database connections { fg, bg, gui }
---@field default_color table? Default color { fg, bg, gui }
---@field save_colors boolean Save color customizations to file (default: true)

---@class CompletionConfig
---@field enabled boolean Enable/disable completion globally (default: true)
---@field timeout_ms number Completion timeout in milliseconds (default: 200)
---@field cache_ttl number Cache TTL in seconds (default: 300)
---@field max_items number Maximum completion items to return (default: 100, 0 = unlimited)
---@field show_documentation boolean Show documentation in completion popup (default: true)
---@field eager_load boolean Eagerly load tables/views/procedures on connection (default: true)
---@field min_keyword_length number Minimum keyword length for completion (default: 2)
---@field debug boolean Enable debug logging for completion (default: false)
---@field track_usage boolean Track usage from executed queries (default: true)
---@field usage_weight_increment number Weight increment per selection (default: 1)
---@field usage_weight_decay number? Time-based decay factor (default: nil, 0-1 range)
---@field usage_auto_save boolean Auto-save usage data (default: true)
---@field usage_save_interval number Auto-save interval in seconds (default: 30)
---@field usage_max_items number Maximum items to track per type (default: 10000, 0 = unlimited)
---@field always_quote_identifiers boolean Always quote identifiers regardless of special characters (default: false)

---@class SemanticHighlightingConfig
---@field enabled boolean Enable/disable semantic highlighting (default: true)
---@field highlight_keywords boolean Highlight SQL keywords (default: true)
---@field highlight_columns boolean Highlight column names (default: true)
---@field highlight_tables boolean Highlight table names (default: true)
---@field highlight_schemas boolean Highlight schema names (default: true)
---@field highlight_databases boolean Highlight database names (default: true)
---@field highlight_parameters boolean Highlight @parameters and @@system_variables (default: true)
---@field highlight_unresolved boolean Highlight unresolved identifiers (default: true)

---@class FormatterConfig
---@field enabled boolean Enable/disable formatter (default: true)
---@field indent_size number Spaces per indent level (default: 4)
---@field indent_style string "space" or "tab" (default: "space")
---@field keyword_case string "upper"|"lower"|"preserve" (default: "upper")
---@field max_line_length number Soft limit for line wrapping (default: 120, 0=disable)
---@field newline_before_clause boolean Start major clauses on new line (default: true)
---@field align_aliases boolean Align AS keywords in SELECT (default: false)
---@field align_columns boolean Align columns vertically (default: false)
---@field comma_position string "leading"|"trailing" (default: "trailing")
---@field join_on_same_line boolean Keep ON clause with JOIN (default: false)
---@field subquery_indent number Extra indent for subqueries (default: 1)
---@field case_indent number Indent for CASE/WHEN blocks (default: 1)
---@field and_or_position string "leading"|"trailing" for WHERE conditions (default: "leading")
---@field parenthesis_spacing boolean Add space inside parentheses (default: false)
---@field operator_spacing boolean Add space around operators (default: true)
---@field preserve_comments boolean Keep comments in place (default: true)
---@field format_on_save boolean Auto-format on buffer save (default: false)
-- SELECT clause rules (Phase 1)
---@field select_list_style string "inline"|"stacked"|"stacked_indent" - Columns layout: inline=all on one line, stacked=one per line with first on SELECT line, stacked_indent=one per line with first on new line (default: "stacked")
---@field select_star_expand boolean Auto-expand SELECT * to column list (default: false)
---@field select_distinct_newline boolean Put DISTINCT on new line after SELECT (default: false)
---@field select_top_newline boolean Put TOP clause on new line after SELECT (default: false)
---@field select_into_newline boolean Put INTO clause on new line (default: true)
---@field select_column_align string "left"|"keyword" - Align columns to left or keyword (default: "left")
---@field use_as_keyword boolean Always use AS for column aliases (default: true)
-- FROM clause rules (Phase 1)
---@field from_newline boolean FROM on new line (default: true)
---@field from_table_style string "inline"|"stacked" - Tables inline or one per line (default: "stacked")
---@field from_alias_align boolean Align table aliases (default: false)
---@field from_schema_qualify string "always"|"never"|"preserve" - Schema qualification (default: "preserve")
---@field from_table_hints_newline boolean Table hints on new line (default: false)
---@field derived_table_style string "inline"|"newline" - Derived table opening paren position (default: "newline")
-- WHERE clause rules (Phase 1)
---@field where_newline boolean WHERE on new line (default: true)
---@field where_condition_style string "inline"|"stacked"|"stacked_indent" - Conditions layout: inline=all on one line, stacked=AND/OR on new lines, stacked_indent=first condition on new line after WHERE (default: "stacked")
---@field where_and_or_indent number AND/OR indent level (default: 1)
---@field where_in_list_style string "inline"|"stacked"|"stacked_indent" - IN list layout (default: "inline")
---@field where_between_style string "inline"|"stacked" - BETWEEN values layout (default: "inline")
---@field where_exists_style string "inline"|"newline" - EXISTS subquery layout (default: "newline")
-- JOIN clause rules (Phase 1)
---@field join_newline boolean JOIN on new line (default: true)
---@field join_keyword_style string "full"|"short" - INNER JOIN vs JOIN (default: "full")
---@field join_indent_style string "align"|"indent" - JOIN alignment style (default: "indent")
---@field on_condition_style string "inline"|"stacked"|"stacked_indent" - ON conditions layout (default: "inline")
---@field on_and_position string "leading"|"trailing" - AND in ON clause position (default: "leading")
---@field cross_apply_newline boolean CROSS/OUTER APPLY on new line (default: true)
---@field empty_line_before_join boolean Empty line before JOIN (default: false)
-- INSERT/UPDATE/DELETE rules (Phase 2)
---@field insert_columns_style string "inline"|"stacked" - INSERT column list layout (default: "inline")
---@field insert_values_style string "inline"|"stacked" - VALUES layout (default: "inline")
---@field insert_into_keyword boolean Always use INTO keyword (default: true)
---@field insert_multi_row_style string "inline"|"stacked" - Multiple VALUES rows (default: "stacked")
---@field update_set_style string "inline"|"stacked" - SET assignments layout (default: "stacked")
---@field update_set_align boolean Align = in SET clause (default: false)
---@field delete_from_keyword boolean Always use FROM keyword (default: true)
---@field output_clause_newline boolean OUTPUT clause on new line (default: true)
---@field merge_style string "compact"|"expanded" - MERGE statement style (default: "expanded")
---@field merge_when_newline boolean WHEN clauses on new lines (default: true)
-- GROUP BY/ORDER BY rules (Phase 2)
---@field group_by_newline boolean GROUP BY on new line (default: true)
---@field group_by_style string "inline"|"stacked" - GROUP BY columns layout (default: "inline")
---@field having_newline boolean HAVING on new line (default: true)
---@field order_by_newline boolean ORDER BY on new line (default: true)
---@field order_by_style string "inline"|"stacked" - ORDER BY columns layout (default: "inline")
---@field order_direction_style string "always"|"explicit"|"never" - ASC/DESC display (default: "explicit")
-- CTE rules (Phase 2)
---@field cte_style string "compact"|"expanded" - CTE layout style (default: "expanded")
---@field cte_as_position string "same_line"|"new_line" - AS keyword position (default: "same_line")
---@field cte_parenthesis_style string "same_line"|"new_line" - Opening paren position (default: "new_line")
---@field cte_columns_style string "inline"|"stacked" - CTE column list layout (default: "inline")
---@field cte_separator_newline boolean Comma between CTEs on new line (default: false)
-- Casing rules (Phase 3)
---@field function_case string "upper"|"lower"|"preserve" - Built-in functions casing (default: "upper")
---@field datatype_case string "upper"|"lower"|"preserve" - Data types casing (default: "upper")
---@field identifier_case string "upper"|"lower"|"preserve" - Table/column names casing (default: "preserve")
---@field alias_case string "upper"|"lower"|"preserve" - Alias names casing (default: "preserve")
-- Spacing rules (Phase 3)
---@field comma_spacing string "before"|"after"|"both"|"none" - Spaces around commas (default: "after")
---@field semicolon_spacing boolean Space before semicolon (default: false)
---@field bracket_spacing boolean Spaces inside brackets [] (default: false)
---@field equals_spacing boolean Spaces around = in SET (default: true)
---@field concatenation_spacing boolean Spaces around + concat operator (default: true)
---@field comparison_spacing boolean Spaces around comparison operators (default: true)
-- Blank lines rules (Phase 3)
---@field blank_line_before_clause boolean Blank line before major clauses (default: false)
---@field blank_line_after_go number Blank lines after GO batch separator (default: 1)
---@field blank_line_between_statements number Blank lines between statements (default: 1)
---@field blank_line_before_comment boolean Blank line before block comments (default: false)
---@field collapse_blank_lines boolean Collapse multiple consecutive blank lines (default: true)
---@field max_consecutive_blank_lines number Maximum consecutive blank lines allowed (default: 2)
-- Comments rules (Phase 3)
---@field comment_position string "preserve"|"above"|"inline" - Comment placement (default: "preserve")
---@field block_comment_style string "preserve"|"reformat" - Block comment formatting (default: "preserve")
---@field inline_comment_align boolean Align inline comments (default: false)
-- DDL rules (Phase 4)
---@field create_table_column_newline boolean Each column definition on new line (default: true)
---@field create_table_constraint_newline boolean Constraints on new lines (default: true)
---@field alter_table_style string "compact"|"expanded" - ALTER TABLE layout (default: "expanded")
---@field drop_if_exists_style string "inline"|"separate" - DROP IF EXISTS style (default: "inline")
---@field index_column_style string "inline"|"stacked" - Index column list layout (default: "inline")
---@field view_body_indent number Indent level for view body (default: 1)
---@field procedure_param_style string "inline"|"stacked" - Procedure parameter layout (default: "stacked")
---@field function_param_style string "inline"|"stacked" - Function parameter layout (default: "stacked")
-- Expression rules (Phase 4)
---@field case_style string "inline"|"stacked" - CASE expression layout (default: "stacked")
---@field case_when_indent number WHEN clause indent level (default: 1)
---@field case_then_position string "same_line"|"new_line" - THEN position relative to WHEN (default: "same_line")
---@field subquery_paren_style string "same_line"|"new_line" - Subquery opening paren position (default: "same_line")
---@field function_arg_style string "inline"|"stacked" - Function argument layout (default: "inline")
---@field in_list_style string "inline"|"stacked"|"stacked_indent" - IN clause value list layout (default: "inline")
---@field boolean_operator_newline boolean Put AND/OR on new lines in expressions (default: false)
-- Indentation expansion (Phase 5)
---@field continuation_indent number Wrapped line continuation indent (default: 1)
---@field cte_indent number CTE body indent level (default: 1)
---@field union_indent number UNION statement indent (default: 0)
---@field nested_join_indent number Nested JOIN indent level (default: 1)
-- Advanced options (Phase 5)
---@field keyword_right_align boolean Right-align keywords for river style (default: false)
---@field format_only_selection boolean Format selection only vs whole buffer (default: false)
---@field batch_separator_style string "go"|"semicolon" - Batch separator preference (default: "go")
---@field rules FormatterRulesConfig Per-clause rule overrides

---@class FormatterRulesConfig
---@field select? FormatterSelectRules SELECT-specific rules
---@field from? FormatterFromRules FROM/JOIN-specific rules
---@field where? FormatterWhereRules WHERE-specific rules
---@field insert? FormatterInsertRules INSERT-specific rules
---@field update? FormatterUpdateRules UPDATE-specific rules

---@class FormatterSelectRules
---@field one_column_per_line? boolean Put each column on its own line

---@class FormatterFromRules
---@field one_table_per_line? boolean Put each table on its own line

---@class FormatterWhereRules
---@field one_condition_per_line? boolean Put each condition on its own line

---@class FormatterInsertRules
---@field columns_inline? boolean Keep column list inline

---@class FormatterUpdateRules
---@field set_inline? boolean Keep SET clause inline

---Default configuration
---@type SsnsConfig
local default_config = {
  connections = {
    -- Example:
    -- dev = "sqlserver://localhost/DevDB",
    -- prod = "sqlserver://user:pass@server\\SQLEXPRESS/ProductionDB",
    -- postgres_local = "postgres://postgres:password@localhost:5432/mydb",
    -- mysql_local = "mysql://root@localhost/mydb",
    -- sqlite_local = "sqlite://./data/app.db",
  },

  ui = {
    position = "left",  -- "left", "right", "float"
    width = 40,         -- Width in columns (or 0-1 for percentage in float mode)
    height = 30,        -- Height in rows for float mode (or 0-1 for percentage)

    -- Float-specific options (only used when position = "float")
    float_border = "rounded",     -- Border style: "none", "single", "double", "rounded", "solid", or custom table
    float_title = true,           -- Show title bar
    float_title_text = " SSNS ",  -- Title text
    float_zindex = 50,            -- Window z-index (layering)
    tree_auto_expand = false,     -- Auto-expand tree width to fit content

    ssms_style = true,
    show_schema_prefix = true,
    auto_expand_depth = nil,  -- nil = don't auto-expand
    smart_cursor_positioning = true,  -- Enable smart cursor positioning on j/k
    show_help = true,  -- Show help text at top of tree
    -- Divider between multiple result sets
    -- Format: supports repeat patterns (N<char>), raw strings, variables, and auto-width
    -- Repeat: "20#" = 20 hashes, "10-" = 10 dashes
    -- Auto-width: "%fit%" = matches longest line width
    -- Multi-line: use \n (newline character, e.g., "20#\n20#\n20#")
    -- Variables: %row_count%, %col_count%, %run_time%, %total_time%, %result_set_num%, %total_result_sets%, %chunk_number%, %batch_number%, %date%, %time%, %fit%, %fit_results%
    -- Special width patterns:
    --   %fit% = Auto-width matching the longest divider text line
    --   %fit_results% = Auto-width matching the result table width (columns + separators)
    -- Examples:
    --   "5-(%row_count% rows)5-" → "-----(11 rows)-----"
    --   "%fit%=\n---- Result Set %result_set_num% (%row_count% rows, %run_time%) ----\n%fit%="
    --   "%fit_results%-\n---- Result %result_set_num% (%row_count% rows) ----\n%fit_results%-"
    --   "%fit%-\n---- Batch %batch_number% (%row_count% rows in %run_time%, total: %total_time%) ----\n%fit%-"
    result_set_divider = "",
    show_result_set_info = false,  -- Show divider/info before first result set and single result sets

    -- Default filter settings for tree groups
    filters = {
      hide_system_schemas = true,  -- Hide system schemas by default (sys, INFORMATION_SCHEMA, etc.)
      system_schemas = {           -- Schemas considered as "system" (case-insensitive matching)
        "sys",
        "INFORMATION_SCHEMA",
        "guest",
        "db_owner",
        "db_accessadmin",
        "db_securityadmin",
        "db_ddladmin",
        "db_backupoperator",
        "db_datareader",
        "db_datawriter",
        "db_denydatareader",
        "db_denydatawriter",
      },
      system_databases = {         -- Databases considered as "system" (case-insensitive matching)
        "master",
        "model",
        "msdb",
        "tempdb",
      },
    },

    icons = {
      -- Nerd Font icons (safe Unicode encoding)
      server = "\u{f233}",      --  (default/unknown)

      -- Database-type specific server icons
      server_sqlserver = "\u{e272}",   --  (SQL Server)
      server_postgres = "\u{e76e}",    --  (PostgreSQL)
      server_mysql = "\u{e704}",       --  (MySQL)
      server_sqlite = "\u{e7c4}",      --  (SQLite)
      server_bigquery = "\u{e7b2}",    --  (BigQuery)

      database = "\u{f1c0}",    --
      schema = "\u{f07b}",      --
      table = "\u{f0ce}",       --
      view = "\u{f06e}",        --
      procedure = "\u{f013}",   --
      ["function"] = "\u{0192}", -- ƒ
      column = "\u{f0ca}",      --
      index = "\u{f0e7}",       --
      key = "\u{f084}",         --
      parameter = "\u{f12e}",   --
      action = "\u{f04b}",      --
      sequence = "\u{f292}",    --
      synonym = "\u{f0c1}",     --

      -- Status indicators
      connected = "\u{f00c}",      --
      disconnected = "\u{f00d}",   --
      connecting = "\u{f110}",     --
      error = "\u{f026}",          --

      -- Tree expand/collapse
      expanded = "\u{f078}",    --
      collapsed = "\u{f054}",   --
    },

    highlights = {
      -- Server type-specific highlights (by database type)
      server_sqlserver = { fg = "#569CD6", bold = true },  -- Blue (SQL Server)
      server_postgres = { fg = "#4EC9B0", bold = true },   -- Cyan (PostgreSQL)
      server_mysql = { fg = "#CE9178", bold = true },      -- Orange (MySQL)
      server_sqlite = { fg = "#B5CEA8", bold = true },     -- Green (SQLite)
      server_bigquery = { fg = "#C586C0", bold = true },   -- Purple (BigQuery)
      server = { fg = "#808080", bold = true },            -- Gray (unknown/default)

      -- Object type highlights
      database = { fg = "#9CDCFE" },                       -- Light Blue (databases)
      schema = { fg = "#C586C0" },                         -- Purple (schemas)
      table = { fg = "#4FC1FF" },                          -- Bright Blue (tables)
      temp_table = { fg = "#CE9178", italic = true },      -- Orange italic (temp tables #temp, ##global)
      view = { fg = "#DCDCAA" },                           -- Yellow (views)
      procedure = { fg = "#CE9178" },                      -- Orange (procedures)
      ["function"] = { fg = "#4EC9B0" },                   -- Cyan (functions)
      column = { fg = "#9CDCFE" },                         -- Light Blue (columns)
      index = { fg = "#D7BA7D" },                          -- Gold (indexes)
      key = { fg = "#569CD6" },                            -- Blue (keys)
      parameter = { fg = "#DCDCAA" },                      -- Yellow (parameters)
      sequence = { fg = "#B5CEA8" },                       -- Green (sequences)
      synonym = { fg = "#808080" },                        -- Gray (synonyms)
      action = { fg = "#C586C0" },                         -- Purple (actions)
      group = { fg = "#858585", bold = true },             -- Gray bold (groups)

      -- Status highlights
      status_connected = { fg = "#4EC9B0", bold = true },  -- Green/cyan
      status_disconnected = { fg = "#808080" },            -- Gray
      status_connecting = { fg = "#DCDCAA" },              -- Yellow
      status_error = { fg = "#F48771", bold = true },      -- Red

      -- Tree expand/collapse indicators
      expanded = { fg = "#808080" },                       -- Gray
      collapsed = { fg = "#808080" },                      -- Gray

      -- Semantic highlighting (query buffers)
      keyword = { fg = "#56cdd6", bold = true },           -- Blue (SQL keywords - legacy fallback)

      -- Categorized keyword highlighting
      keyword_statement = { fg = "#C586C0", bold = true }, -- Purple (SELECT, INSERT, CREATE, IF, BEGIN, etc.)
      keyword_clause = { fg = "#569CD6", bold = true },    -- Blue (FROM, WHERE, JOIN, GROUP BY, etc.)
      keyword_function = { fg = "#DCDCAA" },               -- Yellow (COUNT, SUM, GETDATE, CAST, etc.)
      keyword_datatype = { fg = "#4EC9B0" },               -- Cyan (INT, VARCHAR, DATETIME, etc.)
      keyword_operator = { fg = "#569CD6" },               -- Blue (AND, OR, NOT, IN, BETWEEN, etc.)
      keyword_constraint = { fg = "#CE9178" },             -- Orange (PRIMARY, KEY, FOREIGN, INDEX, etc.)
      keyword_modifier = { fg = "#9CDCFE" },               -- Light Blue (ASC, DESC, NOLOCK, etc.)
      keyword_misc = { fg = "#808080" },                   -- Gray (reserved/misc keywords)
      keyword_global_variable = { fg = "#FF6B6B" },        -- Red/coral (@@ROWCOUNT, @@VERSION, etc.)
      keyword_system_procedure = { fg = "#D7BA7D" },        -- Gold/amber (sp_*, xp_*)

      -- Other semantic highlights
      operator = { fg = "#D4D4D4" },                       -- Light gray (operators)
      string = { fg = "#CE9178" },                         -- Orange (string literals)
      number = { fg = "#81ca59" },                         -- Green (numeric literals)
      alias = { fg = "#0affce", italic = true },           -- Cyan italic (table aliases)
      unresolved = { fg = "#808080" },                     -- Gray (unresolved identifiers)
      comment = { fg = "#6A9955", italic = true },         -- Green italic (comments)
    },
  },

  cache = {
    ttl = 300,  -- 5 minutes
    enabled = true,  -- Enable query result caching
  },

  query = {
    default_limit = 100,  -- Default LIMIT for SELECT queries (0 = no limit)
    timeout = 30000,  -- Query timeout in milliseconds (30 seconds, 0 = no timeout)
    auto_execute_on_open = false,  -- Auto-execute query when opening action
  },

  query_history = {
    enabled = true,  -- Enable query history tracking
    max_buffers = 100,  -- Maximum buffer histories to keep (RedGate-style per-file tracking)
    max_entries_per_buffer = 100,  -- Maximum entries per buffer (100 changes per file)
    auto_persist = true,  -- Auto-save history to file after each query
    persist_file = vim.fn.stdpath('data') .. '/ssns/query_history.json',
    exclude_patterns = {
      "SELECT 1",  -- Health check queries
      "SELECT @@",  -- Server variable queries
    },
  },

  keymaps = {
    -- Common keymaps shared across multiple UIs
    common = {
      close = "q",           -- Close window
      cancel = "<Esc>",      -- Cancel/escape
      confirm = "<CR>",      -- Confirm/apply
      nav_down = "j",        -- Navigate down
      nav_up = "k",          -- Navigate up
      nav_down_alt = "<Down>",  -- Navigate down alternate
      nav_up_alt = "<Up>",   -- Navigate up alternate
      next_field = "<Tab>",  -- Next field
      prev_field = "<S-Tab>", -- Previous field
      edit = "i",            -- Edit/insert mode
    },

    -- Tree buffer keymaps
    tree = {
      toggle = "<CR>",       -- Toggle expand/collapse or execute action
      toggle_alt = "o",      -- Alternate toggle key
      refresh = "r",         -- Refresh current node
      refresh_all = "R",     -- Refresh all servers
      filter = "f",          -- Open filter UI for group
      filter_clear = "F",    -- Clear all filters on group
      toggle_connection = "d", -- Toggle server connection
      set_lualine_color = "<Leader>c", -- Set lualine color
      help = "?",            -- Show help
      new_query = "<C-n>",   -- New query buffer
      goto_first_child = "<C-[>", -- Go to first child
      goto_last_child = "<C-]>",  -- Go to last child
      toggle_group = "g",    -- Toggle parent group
      add_server = "a",      -- Open add server UI
      toggle_favorite = "*", -- Toggle favorite
      show_history = "<Leader>@", -- Show query history
      view_definition = "K", -- View object definition (ALTER script)
      view_metadata = "M",   -- View object metadata
    },

    -- Query buffer keymaps
    query = {
      execute = "<Leader>r", -- Execute query
      execute_selection = "<Leader>r", -- Execute visual selection
      execute_statement = "<Leader>R", -- Execute statement under cursor
      toggle_results = "<C-r>", -- Toggle results window (show/hide)
      save_query = "<Leader>s", -- Save query to file
      expand_asterisk = "<Leader>ce", -- Expand asterisk to columns
      go_to = "gd",          -- Go to object in tree
      view_definition = "K", -- View object definition
      view_metadata = "M",   -- View object metadata
      new_query = "<C-n>",   -- New query buffer
      show_history = "<Leader>@", -- Show query history
      attach_connection = "<Leader>cs", -- Attach buffer to connection
      change_connection = "<Leader>cA", -- Change connection (hierarchical picker)
      change_database = "<Leader>cd", -- Change database only
    },

    -- History UI keymaps
    history = {
      switch_panel = "<Tab>",    -- Switch between panels
      toggle_preview = "<S-Tab>", -- Toggle preview panel
      load_query = "<CR>",       -- Load selected query
      delete = "d",              -- Delete entry
      clear_all = "c",           -- Clear all entries
      export = "x",              -- Export history
      search = "/",              -- Search history
    },

    -- Filter UI keymaps
    filter = {
      apply = "<CR>",        -- Apply filters
      clear = "F",           -- Clear all filters
      toggle_checkbox = "<Space>", -- Toggle checkbox
    },

    -- Parameter input keymaps
    param = {
      execute = "<CR>",      -- Execute with parameters
    },

    -- Add server UI keymaps
    add_server = {
      add = "a",             -- Add to tree (list view)
      new = "n",             -- New connection
      delete = "d",          -- Delete connection
      edit_connection = "e", -- Edit connection
      toggle_favorite = "f", -- Toggle favorite
      toggle_favorite_alt = "*", -- Toggle favorite alternate
      db_type = "t",         -- Change database type
      set_name = "n",        -- Set connection name (form view)
      set_path = "p",        -- Set server path
      save = "s",            -- Save connection
      test = "T",            -- Test connection
      back = "b",            -- Go back
      toggle_auto_connect = "a", -- Toggle auto-connect (form view)
    },

    -- SQL formatter keymaps
    formatter = {
      format_buffer = "<Leader>sf",     -- Format entire buffer (also works for visual selection)
      format_statement = "<Leader>ss",  -- Format statement under cursor
      open_config = "<Leader>sc",       -- Open formatter configuration UI
    },
  },

  table_helpers = {
    sqlserver = {
      ["SELECT Top 100"] = "SELECT TOP 100 * FROM {table};",
      ["SELECT Top 1000"] = "SELECT TOP 1000 * FROM {table};",
      ["Count"] = "SELECT COUNT(*) AS row_count FROM {table};",
      ["Describe"] = "EXEC sp_help '{table}';",
      ["INSERT Template"] = "INSERT INTO {table} ({columns})\nVALUES ({values});",
      ["UPDATE Template"] = "UPDATE {table}\nSET {column} = {value}\nWHERE {condition};",
      ["DELETE Template"] = "DELETE FROM {table}\nWHERE {condition};",
    },
    postgres = {
      ["SELECT Limit 100"] = "SELECT * FROM {table} LIMIT 100;",
      ["SELECT Limit 1000"] = "SELECT * FROM {table} LIMIT 1000;",
      ["Count"] = "SELECT COUNT(*) AS row_count FROM {table};",
      ["Describe"] = "\\d+ {table}",
      ["INSERT Template"] = "INSERT INTO {table} ({columns})\nVALUES ({values})\nRETURNING *;",
      ["UPDATE Template"] = "UPDATE {table}\nSET {column} = {value}\nWHERE {condition}\nRETURNING *;",
      ["DELETE Template"] = "DELETE FROM {table}\nWHERE {condition};",
    },
    mysql = {
      ["SELECT Limit 100"] = "SELECT * FROM {table} LIMIT 100;",
      ["SELECT Limit 1000"] = "SELECT * FROM {table} LIMIT 1000;",
      ["Count"] = "SELECT COUNT(*) AS row_count FROM {table};",
      ["Describe"] = "DESCRIBE {table};",
      ["INSERT Template"] = "INSERT INTO {table} ({columns})\nVALUES ({values});",
      ["UPDATE Template"] = "UPDATE {table}\nSET {column} = {value}\nWHERE {condition};",
      ["DELETE Template"] = "DELETE FROM {table}\nWHERE {condition};",
    },
    sqlite = {
      ["SELECT Limit 100"] = "SELECT * FROM {table} LIMIT 100;",
      ["SELECT Limit 1000"] = "SELECT * FROM {table} LIMIT 1000;",
      ["Count"] = "SELECT COUNT(*) AS row_count FROM {table};",
      ["Describe"] = "PRAGMA table_info({table});",
      ["INSERT Template"] = "INSERT INTO {table} ({columns})\nVALUES ({values});",
      ["UPDATE Template"] = "UPDATE {table}\nSET {column} = {value}\nWHERE {condition};",
      ["DELETE Template"] = "DELETE FROM {table}\nWHERE {condition};",
    },
  },

  performance = {
    lazy_load = true,  -- Enable lazy loading
    page_size = 0,  -- Number of items per page (0 = load all)
    async = true,  -- Use async operations
  },

  -- Lualine statusline integration
  lualine = {
    enabled = true,  -- Enable lualine component
    save_colors = true,  -- Save color customizations to file
    colors = {
      -- Color configuration (similar to Redgate SSMS color-coding)
      -- For server-level connections (no database in connection string):
      --   Use server name: ['localhost'] = { fg = '#ffffff', bg = '#0066cc' }
      -- For database-level connections (database in connection string):
      --   Use database name: ['ProductionDB'] = { fg = '#ffffff', bg = '#ff0000' }
      -- Pattern matching supported:
      --   ['*prod*'] = { fg = '#ffffff', bg = '#ff0000' },  -- Any server/DB with "prod"
      --   ['*dev*'] = { fg = '#000000', bg = '#00ff00' },   -- Any server/DB with "dev"
    },
    default_color = nil,  -- Default color (nil = use lualine theme)
  },

  -- IntelliSense completion configuration
  completion = {
    enabled = true,              -- Enable/disable completion globally
    timeout_ms = 200,            -- Completion timeout in milliseconds
    cache_ttl = 300,             -- Cache TTL in seconds (5 minutes)
    max_items = 0,               -- Maximum completion items to return (0 = unlimited)
    show_documentation = true,   -- Show documentation in completion popup
    eager_load = false,           -- Eagerly load tables/views/procedures on connection
    min_keyword_length = 2,      -- Minimum keyword length for completion
    debug = false,               -- Enable debug logging for completion
    track_usage = true,          -- Track usage from executed queries (default: true)
    usage_weight_increment = 1,  -- Weight increment per selection
    usage_weight_decay = nil,    -- Time-based decay factor (nil = no decay, 0-1 = decay rate)
    usage_auto_save = true,      -- Auto-save usage data to file
    usage_save_interval = 30,    -- Auto-save interval in seconds
    usage_max_items = 10000,     -- Maximum items to track per type (0 = unlimited)
    always_quote_identifiers = false, -- Always quote identifiers (true) or only when needed (false)
  },

  -- Semantic highlighting for SQL query buffers
  semantic_highlighting = {
    enabled = true,              -- Enable/disable semantic highlighting
    highlight_keywords = true,   -- Highlight SQL keywords (SELECT, FROM, etc.)
    highlight_columns = true,    -- Highlight column names
    highlight_tables = true,     -- Highlight table names
    highlight_schemas = true,    -- Highlight schema names
    highlight_databases = true,  -- Highlight database names
    highlight_parameters = true, -- Highlight @parameters and @@system_variables
    highlight_unresolved = true, -- Highlight unresolved identifiers in gray
  },

  -- SQL formatter configuration
  formatter = {
    enabled = true,              -- Enable/disable formatter
    indent_size = 4,             -- Spaces per indent level
    indent_style = "space",      -- "space" or "tab"
    keyword_case = "upper",      -- "upper"|"lower"|"preserve"
    max_line_length = 120,       -- Soft limit for line wrapping (0 = disable)
    newline_before_clause = true, -- Start major clauses on new line
    align_aliases = false,       -- Align AS keywords in SELECT
    align_columns = false,       -- Align columns vertically
    comma_position = "trailing", -- "leading"|"trailing"
    join_on_same_line = false,   -- Keep ON clause with JOIN
    subquery_indent = 1,         -- Extra indent for subqueries
    case_indent = 1,             -- Indent for CASE/WHEN blocks
    and_or_position = "leading", -- "leading"|"trailing" for WHERE conditions
    parenthesis_spacing = false, -- Add space inside parentheses
    operator_spacing = true,     -- Add space around operators
    preserve_comments = true,    -- Keep comments in place
    format_on_save = false,      -- Auto-format on buffer save

    -- SELECT clause rules (Phase 1)
    select_list_style = "stacked",       -- "inline"|"stacked" - Columns layout
    select_star_expand = false,          -- Auto-expand SELECT * to column list
    select_distinct_newline = false,     -- DISTINCT on new line after SELECT
    select_top_newline = false,          -- TOP clause on new line after SELECT
    select_into_newline = true,          -- INTO clause on new line
    select_column_align = "left",        -- "left"|"keyword" - Column alignment
    use_as_keyword = true,               -- Always use AS for column aliases

    -- FROM clause rules (Phase 1)
    from_newline = true,                 -- FROM on new line
    from_table_style = "stacked",        -- "inline"|"stacked" - Tables layout
    from_alias_align = false,            -- Align table aliases
    from_schema_qualify = "preserve",    -- "always"|"never"|"preserve"
    from_table_hints_newline = false,    -- Table hints on new line
    derived_table_style = "newline",     -- "inline"|"newline" - Derived table paren

    -- WHERE clause rules (Phase 1)
    where_newline = true,                -- WHERE on new line
    where_condition_style = "stacked",   -- "inline"|"stacked" - Conditions layout
    where_and_or_indent = 1,             -- AND/OR indent level
    where_in_list_style = "inline",      -- "inline"|"stacked"|"stacked_indent" - IN list layout
    where_between_style = "inline",      -- "inline"|"stacked" - BETWEEN layout
    where_exists_style = "newline",      -- "inline"|"newline" - EXISTS subquery

    -- JOIN clause rules (Phase 1)
    join_newline = true,                 -- JOIN on new line
    join_keyword_style = "full",         -- "full"|"short" - INNER JOIN vs JOIN
    join_indent_style = "indent",        -- "align"|"indent" - JOIN alignment
    on_condition_style = "inline",       -- "inline"|"stacked" - ON conditions
    on_and_position = "leading",         -- "leading"|"trailing" - AND in ON clause
    cross_apply_newline = true,          -- CROSS/OUTER APPLY on new line
    empty_line_before_join = false,      -- Empty line before JOIN

    -- INSERT/UPDATE/DELETE rules (Phase 2)
    insert_columns_style = "inline",     -- "inline"|"stacked" - INSERT column list
    insert_values_style = "inline",      -- "inline"|"stacked" - VALUES layout
    insert_into_keyword = true,          -- Always use INTO keyword
    insert_multi_row_style = "stacked",  -- "inline"|"stacked" - Multiple VALUES rows
    update_set_style = "stacked",        -- "inline"|"stacked" - SET assignments
    update_set_align = false,            -- Align = in SET clause
    delete_from_keyword = true,          -- Always use FROM keyword
    output_clause_newline = true,        -- OUTPUT clause on new line
    merge_style = "expanded",            -- "compact"|"expanded" - MERGE style
    merge_when_newline = true,           -- WHEN clauses on new lines

    -- GROUP BY/ORDER BY rules (Phase 2)
    group_by_newline = true,             -- GROUP BY on new line
    group_by_style = "inline",           -- "inline"|"stacked" - GROUP BY columns
    having_newline = true,               -- HAVING on new line
    order_by_newline = true,             -- ORDER BY on new line
    order_by_style = "inline",           -- "inline"|"stacked" - ORDER BY columns
    order_direction_style = "explicit",  -- "always"|"explicit"|"never" - ASC/DESC

    -- CTE rules (Phase 2)
    cte_style = "expanded",              -- "compact"|"expanded" - CTE layout
    cte_as_position = "same_line",       -- "same_line"|"new_line" - AS position
    cte_parenthesis_style = "new_line",  -- "same_line"|"new_line" - Opening paren
    cte_columns_style = "inline",        -- "inline"|"stacked" - CTE column list
    cte_separator_newline = false,       -- Comma between CTEs on new line

    -- Casing rules (Phase 3)
    function_case = "upper",             -- "upper"|"lower"|"preserve" - Functions
    datatype_case = "upper",             -- "upper"|"lower"|"preserve" - Data types
    identifier_case = "preserve",        -- "upper"|"lower"|"preserve" - Identifiers
    alias_case = "preserve",             -- "upper"|"lower"|"preserve" - Aliases

    -- Spacing rules (Phase 3)
    comma_spacing = "after",             -- "before"|"after"|"both"|"none"
    semicolon_spacing = false,           -- Space before semicolon
    bracket_spacing = false,             -- Spaces inside brackets []
    equals_spacing = true,               -- Spaces around = in SET
    concatenation_spacing = true,        -- Spaces around + concat
    comparison_spacing = true,           -- Spaces around <, >, etc.

    -- Blank lines rules (Phase 3)
    blank_line_before_clause = false,    -- Blank line before major clauses
    blank_line_after_go = 1,             -- Blank lines after GO
    blank_line_between_statements = 1,   -- Blank lines between statements
    blank_line_before_comment = false,   -- Blank line before block comments
    collapse_blank_lines = true,         -- Collapse multiple blank lines
    max_consecutive_blank_lines = 2,     -- Max consecutive blank lines

    -- Comments rules (Phase 3)
    comment_position = "preserve",       -- "preserve"|"above"|"inline"
    block_comment_style = "preserve",    -- "preserve"|"reformat"
    inline_comment_align = false,        -- Align inline comments

    -- DDL rules (Phase 4)
    create_table_column_newline = true,  -- Each column on new line
    create_table_constraint_newline = true, -- Constraints on new lines
    alter_table_style = "expanded",      -- "compact"|"expanded"
    drop_if_exists_style = "inline",     -- "inline"|"separate"
    index_column_style = "inline",       -- "inline"|"stacked"
    view_body_indent = 1,                -- Indent level for view body
    procedure_param_style = "stacked",   -- "inline"|"stacked"
    function_param_style = "stacked",    -- "inline"|"stacked"

    -- Expression rules (Phase 4)
    case_style = "stacked",              -- "inline"|"stacked"
    case_when_indent = 1,                -- WHEN indent level
    case_then_position = "same_line",    -- "same_line"|"new_line"
    subquery_paren_style = "same_line",  -- "same_line"|"new_line"
    function_arg_style = "inline",       -- "inline"|"stacked"
    in_list_style = "inline",            -- "inline"|"stacked"|"stacked_indent"
    boolean_operator_newline = false,    -- AND/OR on new lines

    -- Indentation expansion (Phase 5)
    continuation_indent = 1,             -- Wrapped line continuation indent
    cte_indent = 1,                      -- CTE body indent level
    union_indent = 0,                    -- UNION statement indent
    nested_join_indent = 1,              -- Nested JOIN indent level

    -- Advanced options (Phase 5)
    keyword_right_align = false,         -- Right-align keywords (river style)
    format_only_selection = false,       -- Format selection vs whole buffer
    batch_separator_style = "go",        -- "go"|"semicolon"

    rules = {
      -- Per-clause rule overrides (optional)
      -- select = { one_column_per_line = true },
      -- from = { one_table_per_line = true },
      -- where = { one_condition_per_line = true },
    },
  },
}

---@class Config
local Config = {}

---Current configuration (starts with defaults)
---@type SsnsConfig
Config.current = vim.deepcopy(default_config)

---Setup configuration
---@param user_config SsnsConfig? User configuration (merged with defaults)
function Config.setup(user_config)
  if user_config then
    Config.current = vim.tbl_deep_extend("force", default_config, user_config)
  else
    Config.current = vim.deepcopy(default_config)
  end

  -- Update cache TTL
  local Cache = require('ssns.cache')
  Cache.default_ttl = Config.current.cache.ttl
end

---Get current configuration
---@return SsnsConfig
function Config.get()
  return Config.current
end

---Get UI configuration
---@return UiConfig
function Config.get_ui()
  return Config.current.ui
end

---Get cache configuration
---@return CacheConfig
function Config.get_cache()
  return Config.current.cache
end

---Get connections configuration
---@return table<string, string>
function Config.get_connections()
  return Config.current.connections
end

---Add a connection
---@param name string Connection name
---@param connection_config ConnectionData Connection configuration
function Config.add_connection(name, connection_config)
  Config.current.connections[name] = connection_config
end

---Remove a connection
---@param name string Connection name
function Config.remove_connection(name)
  Config.current.connections[name] = nil
end

---Get a specific icon
---@param icon_name string Icon name (server, database, table, etc.)
---@return string icon The icon character
function Config.get_icon(icon_name)
  return Config.current.ui.icons[icon_name] or ""
end

---Get query configuration
---@return QueryConfig
function Config.get_query()
  return Config.current.query
end

---Get keymaps configuration
---@return KeymapsConfig
function Config.get_keymaps()
  return Config.current.keymaps
end

---Get table helpers configuration for a specific database type
---@param db_type string Database type (sqlserver, postgres, mysql, sqlite)
---@return table<string, string>?
function Config.get_table_helpers(db_type)
  return Config.current.table_helpers[db_type]
end

---Get performance configuration
---@return PerformanceConfig
function Config.get_performance()
  return Config.current.performance
end

---Get completion configuration
---@return CompletionConfig
function Config.get_completion()
  return Config.current.completion
end

---Get filter configuration
---@return FiltersConfig
function Config.get_filters()
  return Config.current.ui.filters
end

---Get semantic highlighting configuration
---@return SemanticHighlightingConfig
function Config.get_semantic_highlighting()
  return Config.current.semantic_highlighting
end

---Get formatter configuration
---@return FormatterConfig
function Config.get_formatter()
  return Config.current.formatter
end

---Validate configuration
---@param config SsnsConfig
---@return boolean valid
---@return string? error_message
function Config.validate(config)
  -- Validation only checks fields that are PROVIDED by the user
  -- Missing fields will use defaults after merge, so they're not required here

  -- Validate UI configuration (if provided)
  if config.ui then
    -- Validate position (if provided)
    if config.ui.position then
      local valid_positions = { left = true, right = true, float = true }
      if not valid_positions[config.ui.position] then
        return false, string.format("Invalid ui.position: %s (must be 'left', 'right', or 'float')", config.ui.position)
      end
    end

    -- Validate width (if provided) - allow percentages (0-1) or columns (>= 10)
    if config.ui.width then
      if type(config.ui.width) ~= "number" then
        return false, "ui.width must be a number"
      end
      -- Valid: 0 < width <= 1 (percentage) OR width >= 10 (columns)
      local is_percentage = config.ui.width > 0 and config.ui.width <= 1
      local is_columns = config.ui.width >= 10
      if not is_percentage and not is_columns then
        return false, "ui.width must be a percentage (0-1) or at least 10 columns"
      end
    end

    -- Validate height (if provided) - allow percentages (0-1) or rows (>= 5)
    if config.ui.height then
      if type(config.ui.height) ~= "number" then
        return false, "ui.height must be a number"
      end
      local is_percentage = config.ui.height > 0 and config.ui.height <= 1
      local is_rows = config.ui.height >= 5
      if not is_percentage and not is_rows then
        return false, "ui.height must be a percentage (0-1) or at least 5 rows"
      end
    end
  end

  -- Validate cache configuration (if provided)
  if config.cache and config.cache.ttl then
    if config.cache.ttl < 0 then
      return false, "cache.ttl must be a positive number"
    end
  end

  -- Validate query configuration (if provided)
  if config.query then
    if config.query.default_limit and config.query.default_limit < 0 then
      return false, "query.default_limit must be non-negative"
    end
    if config.query.timeout and config.query.timeout < 0 then
      return false, "query.timeout must be non-negative"
    end
  end

  -- Validate performance configuration (if provided)
  if config.performance then
    if config.performance.page_size and config.performance.page_size < 0 then
      return false, "performance.page_size must be non-negative"
    end
  end

  -- Validate completion configuration
  if config.completion then
    if config.completion.enabled ~= nil and type(config.completion.enabled) ~= "boolean" then
      return false, "completion.enabled must be a boolean"
    end
    if config.completion.timeout_ms and (type(config.completion.timeout_ms) ~= "number" or config.completion.timeout_ms <= 0 or config.completion.timeout_ms > 10000) then
      return false, "completion.timeout_ms must be a number between 1 and 10000"
    end
    if config.completion.cache_ttl and (type(config.completion.cache_ttl) ~= "number" or config.completion.cache_ttl < 0) then
      return false, "completion.cache_ttl must be a non-negative number"
    end
    if config.completion.max_items and (type(config.completion.max_items) ~= "number" or config.completion.max_items < 0) then
      return false, "completion.max_items must be a non-negative number"
    end
    if config.completion.show_documentation ~= nil and type(config.completion.show_documentation) ~= "boolean" then
      return false, "completion.show_documentation must be a boolean"
    end
    if config.completion.eager_load ~= nil and type(config.completion.eager_load) ~= "boolean" then
      return false, "completion.eager_load must be a boolean"
    end
    if config.completion.min_keyword_length and (type(config.completion.min_keyword_length) ~= "number" or config.completion.min_keyword_length < 0) then
      return false, "completion.min_keyword_length must be a non-negative number"
    end
    if config.completion.debug ~= nil and type(config.completion.debug) ~= "boolean" then
      return false, "completion.debug must be a boolean"
    end
    if config.completion.track_usage ~= nil and type(config.completion.track_usage) ~= "boolean" then
      return false, "completion.track_usage must be a boolean"
    end
    if config.completion.usage_weight_increment and (type(config.completion.usage_weight_increment) ~= "number" or config.completion.usage_weight_increment <= 0) then
      return false, "completion.usage_weight_increment must be a positive number"
    end
    if config.completion.usage_weight_decay and (type(config.completion.usage_weight_decay) ~= "number" or config.completion.usage_weight_decay <= 0 or config.completion.usage_weight_decay >= 1) then
      return false, "completion.usage_weight_decay must be a number between 0 and 1 (exclusive)"
    end
    if config.completion.usage_auto_save ~= nil and type(config.completion.usage_auto_save) ~= "boolean" then
      return false, "completion.usage_auto_save must be a boolean"
    end
    if config.completion.usage_save_interval and (type(config.completion.usage_save_interval) ~= "number" or config.completion.usage_save_interval <= 0) then
      return false, "completion.usage_save_interval must be a positive number"
    end
    if config.completion.usage_max_items and (type(config.completion.usage_max_items) ~= "number" or config.completion.usage_max_items < 0) then
      return false, "completion.usage_max_items must be a non-negative number"
    end
  end

  -- Validate formatter configuration
  if config.formatter then
    if config.formatter.enabled ~= nil and type(config.formatter.enabled) ~= "boolean" then
      return false, "formatter.enabled must be a boolean"
    end
    if config.formatter.indent_size and (type(config.formatter.indent_size) ~= "number" or config.formatter.indent_size < 1 or config.formatter.indent_size > 16) then
      return false, "formatter.indent_size must be a number between 1 and 16"
    end
    if config.formatter.indent_style then
      local valid_styles = { space = true, tab = true }
      if not valid_styles[config.formatter.indent_style] then
        return false, "formatter.indent_style must be 'space' or 'tab'"
      end
    end
    if config.formatter.keyword_case then
      local valid_cases = { upper = true, lower = true, preserve = true }
      if not valid_cases[config.formatter.keyword_case] then
        return false, "formatter.keyword_case must be 'upper', 'lower', or 'preserve'"
      end
    end
    if config.formatter.max_line_length and (type(config.formatter.max_line_length) ~= "number" or config.formatter.max_line_length < 0) then
      return false, "formatter.max_line_length must be a non-negative number"
    end
    if config.formatter.newline_before_clause ~= nil and type(config.formatter.newline_before_clause) ~= "boolean" then
      return false, "formatter.newline_before_clause must be a boolean"
    end
    if config.formatter.align_aliases ~= nil and type(config.formatter.align_aliases) ~= "boolean" then
      return false, "formatter.align_aliases must be a boolean"
    end
    if config.formatter.align_columns ~= nil and type(config.formatter.align_columns) ~= "boolean" then
      return false, "formatter.align_columns must be a boolean"
    end
    if config.formatter.comma_position then
      local valid_positions = { leading = true, trailing = true }
      if not valid_positions[config.formatter.comma_position] then
        return false, "formatter.comma_position must be 'leading' or 'trailing'"
      end
    end
    if config.formatter.join_on_same_line ~= nil and type(config.formatter.join_on_same_line) ~= "boolean" then
      return false, "formatter.join_on_same_line must be a boolean"
    end
    if config.formatter.subquery_indent and (type(config.formatter.subquery_indent) ~= "number" or config.formatter.subquery_indent < 0) then
      return false, "formatter.subquery_indent must be a non-negative number"
    end
    if config.formatter.case_indent and (type(config.formatter.case_indent) ~= "number" or config.formatter.case_indent < 0) then
      return false, "formatter.case_indent must be a non-negative number"
    end
    if config.formatter.and_or_position then
      local valid_positions = { leading = true, trailing = true }
      if not valid_positions[config.formatter.and_or_position] then
        return false, "formatter.and_or_position must be 'leading' or 'trailing'"
      end
    end
    if config.formatter.parenthesis_spacing ~= nil and type(config.formatter.parenthesis_spacing) ~= "boolean" then
      return false, "formatter.parenthesis_spacing must be a boolean"
    end
    if config.formatter.operator_spacing ~= nil and type(config.formatter.operator_spacing) ~= "boolean" then
      return false, "formatter.operator_spacing must be a boolean"
    end
    if config.formatter.preserve_comments ~= nil and type(config.formatter.preserve_comments) ~= "boolean" then
      return false, "formatter.preserve_comments must be a boolean"
    end
    if config.formatter.format_on_save ~= nil and type(config.formatter.format_on_save) ~= "boolean" then
      return false, "formatter.format_on_save must be a boolean"
    end
  end

  return true, nil
end

---Reset to default configuration
function Config.reset()
  Config.current = vim.deepcopy(default_config)
end

---Get default configuration (for documentation)
---@return SsnsConfig
function Config.get_default()
  return vim.deepcopy(default_config)
end

return Config
