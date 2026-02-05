-- Hello Theme (Hello Kitty inspired)
-- Kawaii database navigation with Hello Kitty's iconic colors

return {
  name = "Hello",
  description = "Hello Kitty inspired theme with red, yellow, blue accents",
  author = "User",

  colors = {
    -- Server type highlights (using Hello Kitty palette)
    server_sqlserver = { fg = "#0054ae", bold = true },   -- Hello Kitty Blue
    server_postgres = { fg = "#f90013", bold = true },    -- Hello Kitty Red
    server_mysql = { fg = "#ffe700", bold = true },       -- Hello Kitty Yellow
    server_sqlite = { fg = "#ffffff", bold = true },      -- Hello Kitty White
    server_bigquery = { fg = "#ff69b4", bold = true },    -- Pink (Hello Kitty's bow)
    server = { fg = "#808080", bold = true },             -- Gray (default)

    -- Object type highlights (rotating through the palette)
    database = { fg = "#f90013" },                        -- Red
    schema = { fg = "#0054ae" },                          -- Blue
    table = { fg = "#ffe700" },                           -- Yellow
    temp_table = { fg = "#ffed4e", italic = true },       -- Lighter yellow italic (#temp, ##global)
    view = { fg = "#ff69b4" },                            -- Pink
    procedure = { fg = "#f90013" },                       -- Red
    ["function"] = { fg = "#0054ae" },                    -- Blue
    column = { fg = "#ffffff" },                          -- White
    index = { fg = "#ffe700" },                           -- Yellow
    key = { fg = "#f90013", bold = true },                -- Red bold
    parameter = { fg = "#ff69b4", italic = true },        -- Pink italic
    sequence = { fg = "#0054ae" },                        -- Blue
    synonym = { fg = "#808080" },                         -- Gray
    action = { fg = "#ff69b4" },                          -- Pink
    group = { fg = "#251815", bold = true },              -- Black bold

    -- Status highlights
    status_connected = { fg = "#f90013", bold = true },   -- Red (Hello Kitty's bow)
    status_disconnected = { fg = "#808080" },             -- Gray
    status_connecting = { fg = "#ffe700" },               -- Yellow (warning)
    status_error = { fg = "#f90013", bold = true },       -- Red

    -- Tree indicators
    expanded = { fg = "#808080" },
    collapsed = { fg = "#808080" },

    -- Semantic highlighting (query buffers)
    keyword = { fg = "#f90013", bold = true },            -- Red
    keyword_statement = { fg = "#f90013", bold = true },  -- Red (SELECT, INSERT, etc.)
    keyword_clause = { fg = "#0054ae", bold = true },     -- Blue (FROM, WHERE, etc.)
    keyword_function = { fg = "#ffe700" },                -- Yellow (COUNT, SUM, etc.)
    keyword_datatype = { fg = "#0054ae" },                -- Blue (INT, VARCHAR, etc.)
    keyword_operator = { fg = "#ff69b4" },                -- Pink (AND, OR, etc.)
    keyword_constraint = { fg = "#f90013" },              -- Red (PRIMARY, KEY, etc.)
    keyword_modifier = { fg = "#ffe700" },                -- Yellow (ASC, DESC, etc.)
    keyword_misc = { fg = "#808080" },                    -- Gray
    keyword_global_variable = { fg = "#f90013" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#ffe700" },        -- Yellow (sp_*, xp_*)

    -- Other semantic highlights
    operator = { fg = "#ff69b4" },                        -- Pink
    string = { fg = "#ffe700" },                          -- Yellow
    number = { fg = "#0054ae" },                          -- Blue
    alias = { fg = "#ff69b4", italic = true },            -- Pink italic
    unresolved = { fg = "#808080" },                      -- Gray
    comment = { fg = "#808080", italic = true },          -- Gray italic

    -- UI-specific colors for floating windows
    ui_border = { fg = "#f90013" },                       -- Red border (like her bow)
    ui_title = { fg = "#f90013", bold = true },           -- Red title
    ui_selected = { fg = "#251815", bg = "#ffe700" },   -- Black on yellow
    ui_hint = { fg = "#808080" },                         -- Gray hints

    -- Result buffer highlights
    result_header = { fg = "#0054ae", bold = true },      -- Blue
    result_border = { fg = "#404040" },                   -- Dark gray
    result_null = { fg = "#808080", italic = true },      -- Gray italic
    result_message = { fg = "#f90013", italic = true },   -- Red italic
    result_date = { fg = "#ffe700" },                     -- Yellow
    result_bool = { fg = "#0054ae" },                     -- Blue
    result_binary = { fg = "#808080" },                   -- Gray
    result_guid = { fg = "#ff69b4" },                     -- Pink

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#f90013" },                 -- Red
    scrollbar_track = { fg = "#404040" },                 -- Dark gray
    scrollbar_arrow = { fg = "#808080" },                 -- Gray
  },
}
