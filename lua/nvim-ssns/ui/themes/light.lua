-- Light Theme (VS Code Light+ inspired)
-- A bright theme for light backgrounds

return {
  name = "Light",
  description = "VS Code Light+ inspired theme for light backgrounds",
  author = "SSNS",

  colors = {
    -- Server type highlights
    server_sqlserver = { fg = "#0000FF", bold = true },   -- Blue
    server_postgres = { fg = "#008080", bold = true },    -- Teal
    server_mysql = { fg = "#B35900", bold = true },       -- Orange-Brown
    server_sqlite = { fg = "#008000", bold = true },      -- Green
    server_bigquery = { fg = "#800080", bold = true },    -- Purple
    server = { fg = "#505050", bold = true },             -- Dark Gray (default)

    -- Object type highlights
    database = { fg = "#001080" },                        -- Dark Blue
    schema = { fg = "#800080" },                          -- Purple
    table = { fg = "#0070C1" },                           -- Blue
    temp_table = { fg = "#A31515", italic = true },       -- Red italic (#temp, ##global)
    view = { fg = "#795E26" },                            -- Brown
    procedure = { fg = "#B35900" },                       -- Orange
    ["function"] = { fg = "#008080" },                    -- Teal
    column = { fg = "#001080" },                          -- Dark Blue
    index = { fg = "#AF8700" },                           -- Gold
    key = { fg = "#0000FF" },                             -- Blue
    parameter = { fg = "#795E26" },                       -- Brown
    sequence = { fg = "#008000" },                        -- Green
    synonym = { fg = "#505050" },                         -- Gray
    action = { fg = "#800080" },                          -- Purple
    group = { fg = "#505050", bold = true },              -- Gray bold
    server_group = { fg = "#B07D2B", bold = true },

    -- Status highlights
    status_connected = { fg = "#008000", bold = true },   -- Green
    status_disconnected = { fg = "#808080" },             -- Gray
    status_connecting = { fg = "#795E26" },               -- Brown
    status_error = { fg = "#C72E29", bold = true },       -- Red

    -- Tree indicators
    expanded = { fg = "#505050" },
    collapsed = { fg = "#505050" },

    -- Semantic highlighting (query buffers)
    keyword = { fg = "#0000FF", bold = true },            -- Blue
    keyword_statement = { fg = "#AF00DB", bold = true },  -- Magenta (SELECT, INSERT, etc.)
    keyword_clause = { fg = "#0000FF", bold = true },     -- Blue (FROM, WHERE, etc.)
    keyword_function = { fg = "#795E26" },                -- Brown (COUNT, SUM, etc.)
    keyword_datatype = { fg = "#008080" },                -- Teal (INT, VARCHAR, etc.)
    keyword_operator = { fg = "#0000FF" },                -- Blue (AND, OR, etc.)
    keyword_constraint = { fg = "#B35900" },              -- Orange (PRIMARY, KEY, etc.)
    keyword_modifier = { fg = "#001080" },                -- Dark Blue (ASC, DESC, etc.)
    keyword_misc = { fg = "#808080" },                    -- Gray
    keyword_global_variable = { fg = "#C72E29" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#AF8700" },        -- Gold (sp_*, xp_*)

    -- Other semantic highlights
    operator = { fg = "#000000" },                        -- Black
    string = { fg = "#A31515" },                          -- Red
    number = { fg = "#098658" },                          -- Green
    alias = { fg = "#008080", italic = true },            -- Teal italic
    unresolved = { fg = "#808080" },                      -- Gray
    comment = { fg = "#008000", italic = true },          -- Green italic
    -- UI-specific colors for floating windows
    ui_border = { fg = "#0070C1" },                       -- Blue border
    ui_title = { fg = "#AF00DB", bold = true },           -- Purple bold title
    ui_selected = { fg = "#FFFFFF", bg = "#0078D7" },     -- White on blue selection
    ui_hint = { fg = "#707070" },                         -- Gray hints

    -- Result buffer highlights
    result_header = { fg = "#001080", bold = true },      -- Dark Blue
    result_border = { fg = "#D0D0D0" },                   -- Light gray
    result_null = { fg = "#A0A0A0", italic = true },      -- Gray italic
    result_message = { fg = "#008000", italic = true },   -- Green italic
    result_date = { fg = "#AF8700" },                     -- Gold
    result_bool = { fg = "#0000FF" },                     -- Blue
    result_binary = { fg = "#808080" },                   -- Gray
    result_guid = { fg = "#A31515" },                     -- Red

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#0070C1" },                 -- Blue
    scrollbar_track = { fg = "#E0E0E0" },                 -- Light gray
    scrollbar_arrow = { fg = "#707070" },                 -- Gray
  },
}
