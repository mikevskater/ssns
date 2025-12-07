-- Dark Theme (VS Code Dark+ inspired)
-- The default SSNS color scheme

return {
  name = "Dark",
  description = "VS Code Dark+ inspired theme (default)",
  author = "SSNS",

  colors = {
    -- Server type highlights
    server_sqlserver = { fg = "#569CD6", bold = true },   -- Blue
    server_postgres = { fg = "#4EC9B0", bold = true },    -- Cyan
    server_mysql = { fg = "#CE9178", bold = true },       -- Orange
    server_sqlite = { fg = "#B5CEA8", bold = true },      -- Green
    server_bigquery = { fg = "#C586C0", bold = true },    -- Purple
    server = { fg = "#808080", bold = true },             -- Gray (default)

    -- Object type highlights
    database = { fg = "#9CDCFE" },                        -- Light Blue
    schema = { fg = "#C586C0" },                          -- Purple
    table = { fg = "#4FC1FF" },                           -- Bright Blue
    view = { fg = "#DCDCAA" },                            -- Yellow
    procedure = { fg = "#CE9178" },                       -- Orange
    ["function"] = { fg = "#4EC9B0" },                    -- Cyan
    column = { fg = "#9CDCFE" },                          -- Light Blue
    index = { fg = "#D7BA7D" },                           -- Gold
    key = { fg = "#569CD6" },                             -- Blue
    parameter = { fg = "#DCDCAA" },                       -- Yellow
    sequence = { fg = "#B5CEA8" },                        -- Green
    synonym = { fg = "#808080" },                         -- Gray
    action = { fg = "#C586C0" },                          -- Purple
    group = { fg = "#858585", bold = true },              -- Gray bold

    -- Status highlights
    status_connected = { fg = "#4EC9B0", bold = true },   -- Green/Cyan
    status_disconnected = { fg = "#808080" },             -- Gray
    status_connecting = { fg = "#DCDCAA" },               -- Yellow
    status_error = { fg = "#F48771", bold = true },       -- Red

    -- Tree indicators
    expanded = { fg = "#808080" },
    collapsed = { fg = "#808080" },

    -- Semantic highlighting (query buffers)
    keyword = { fg = "#569CD6", bold = true },            -- Blue
    keyword_statement = { fg = "#C586C0", bold = true },  -- Purple (SELECT, INSERT, etc.)
    keyword_clause = { fg = "#569CD6", bold = true },     -- Blue (FROM, WHERE, etc.)
    keyword_function = { fg = "#DCDCAA" },                -- Yellow (COUNT, SUM, etc.)
    keyword_datatype = { fg = "#4EC9B0" },                -- Cyan (INT, VARCHAR, etc.)
    keyword_operator = { fg = "#569CD6" },                -- Blue (AND, OR, etc.)
    keyword_constraint = { fg = "#CE9178" },              -- Orange (PRIMARY, KEY, etc.)
    keyword_modifier = { fg = "#9CDCFE" },                -- Light Blue (ASC, DESC, etc.)
    keyword_misc = { fg = "#808080" },                    -- Gray
    keyword_global_variable = { fg = "#FF6B6B" },         -- Coral (@@ROWCOUNT, @@VERSION, etc.)

    -- Other semantic highlights
    operator = { fg = "#D4D4D4" },                        -- Light gray
    string = { fg = "#CE9178" },                          -- Orange
    number = { fg = "#B5CEA8" },                          -- Green
    alias = { fg = "#4EC9B0", italic = true },            -- Cyan italic
    unresolved = { fg = "#808080" },                      -- Gray
    comment = { fg = "#6A9955", italic = true },          -- Green italic
  },
}
