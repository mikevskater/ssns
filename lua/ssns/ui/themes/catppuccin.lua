-- Catppuccin Theme (Catppuccin Mocha inspired)
-- Soothing pastel theme for the high-spirited

return {
  name = "Catppuccin",
  description = "Soothing pastel Catppuccin Mocha theme",
  author = "SSNS",

  colors = {
    -- Server type highlights (using Catppuccin Mocha palette)
    server_sqlserver = { fg = "#89B4FA", bold = true },   -- Blue
    server_postgres = { fg = "#94E2D5", bold = true },    -- Teal
    server_mysql = { fg = "#FAB387", bold = true },       -- Peach
    server_sqlite = { fg = "#A6E3A1", bold = true },      -- Green
    server_bigquery = { fg = "#CBA6F7", bold = true },    -- Mauve
    server = { fg = "#6C7086", bold = true },             -- Overlay0 (default)

    -- Object type highlights
    database = { fg = "#89B4FA" },                        -- Blue
    schema = { fg = "#CBA6F7" },                          -- Mauve
    table = { fg = "#94E2D5" },                           -- Teal
    view = { fg = "#F9E2AF" },                            -- Yellow
    procedure = { fg = "#FAB387" },                       -- Peach
    ["function"] = { fg = "#94E2D5" },                    -- Teal
    column = { fg = "#CDD6F4" },                          -- Text
    index = { fg = "#F9E2AF" },                           -- Yellow
    key = { fg = "#F38BA8" },                             -- Red
    parameter = { fg = "#FAB387", italic = true },        -- Peach italic
    sequence = { fg = "#A6E3A1" },                        -- Green
    synonym = { fg = "#6C7086" },                         -- Overlay0
    action = { fg = "#F5C2E7" },                          -- Pink
    group = { fg = "#6C7086", bold = true },              -- Overlay0 bold

    -- Status highlights
    status_connected = { fg = "#A6E3A1", bold = true },   -- Green
    status_disconnected = { fg = "#6C7086" },             -- Overlay0
    status_connecting = { fg = "#F9E2AF" },               -- Yellow
    status_error = { fg = "#F38BA8", bold = true },       -- Red

    -- Tree indicators
    expanded = { fg = "#6C7086" },
    collapsed = { fg = "#6C7086" },

    -- Semantic highlighting (query buffers)
    keyword = { fg = "#CBA6F7", bold = true },            -- Mauve
    keyword_statement = { fg = "#CBA6F7", bold = true },  -- Mauve (SELECT, INSERT, etc.)
    keyword_clause = { fg = "#89B4FA", bold = true },     -- Blue (FROM, WHERE, etc.)
    keyword_function = { fg = "#F9E2AF" },                -- Yellow (COUNT, SUM, etc.)
    keyword_datatype = { fg = "#94E2D5" },                -- Teal (INT, VARCHAR, etc.)
    keyword_operator = { fg = "#89DCEB" },                -- Sky (AND, OR, etc.)
    keyword_constraint = { fg = "#FAB387" },              -- Peach (PRIMARY, KEY, etc.)
    keyword_modifier = { fg = "#F5C2E7" },                -- Pink (ASC, DESC, etc.)
    keyword_misc = { fg = "#6C7086" },                    -- Overlay0
    keyword_global_variable = { fg = "#F38BA8" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#F9E2AF" },        -- Yellow (sp_*, xp_*)

    -- Other semantic highlights
    operator = { fg = "#89DCEB" },                        -- Sky
    string = { fg = "#A6E3A1" },                          -- Green
    number = { fg = "#FAB387" },                          -- Peach
    alias = { fg = "#74C7EC", italic = true },            -- Sapphire italic
    unresolved = { fg = "#6C7086" },                      -- Overlay0
    comment = { fg = "#6C7086", italic = true },          -- Overlay0 italic
  },
}
