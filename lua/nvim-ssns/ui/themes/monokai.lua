-- Monokai Theme (Monokai Pro inspired)
-- Classic Monokai color scheme

return {
  name = "Monokai",
  description = "Classic Monokai Pro inspired theme",
  author = "SSNS",

  colors = {
    -- Server type highlights
    server_sqlserver = { fg = "#66D9EF", bold = true },   -- Cyan
    server_postgres = { fg = "#A6E22E", bold = true },    -- Green
    server_mysql = { fg = "#FD971F", bold = true },       -- Orange
    server_sqlite = { fg = "#E6DB74", bold = true },      -- Yellow
    server_bigquery = { fg = "#AE81FF", bold = true },    -- Purple
    server = { fg = "#75715E", bold = true },             -- Gray (default)

    -- Object type highlights
    database = { fg = "#66D9EF" },                        -- Cyan
    schema = { fg = "#AE81FF" },                          -- Purple
    table = { fg = "#A6E22E" },                           -- Green
    temp_table = { fg = "#FD971F", italic = true },       -- Orange italic (#temp, ##global)
    view = { fg = "#E6DB74" },                            -- Yellow
    procedure = { fg = "#FD971F" },                       -- Orange
    ["function"] = { fg = "#66D9EF" },                    -- Cyan
    column = { fg = "#F8F8F2" },                          -- White
    index = { fg = "#E6DB74" },                           -- Yellow
    key = { fg = "#F92672" },                             -- Pink/Red
    parameter = { fg = "#FD971F", italic = true },        -- Orange italic
    sequence = { fg = "#A6E22E" },                        -- Green
    synonym = { fg = "#75715E" },                         -- Gray
    action = { fg = "#F92672" },                          -- Pink/Red
    group = { fg = "#75715E", bold = true },              -- Gray bold

    -- Status highlights
    status_connected = { fg = "#A6E22E", bold = true },   -- Green
    status_disconnected = { fg = "#75715E" },             -- Gray
    status_connecting = { fg = "#E6DB74" },               -- Yellow
    status_error = { fg = "#F92672", bold = true },       -- Pink/Red

    -- Tree indicators
    expanded = { fg = "#75715E" },
    collapsed = { fg = "#75715E" },

    -- Semantic highlighting (query buffers)
    keyword = { fg = "#F92672", bold = true },            -- Pink/Red
    keyword_statement = { fg = "#F92672", bold = true },  -- Pink/Red (SELECT, INSERT, etc.)
    keyword_clause = { fg = "#F92672", bold = true },     -- Pink/Red (FROM, WHERE, etc.)
    keyword_function = { fg = "#66D9EF" },                -- Cyan (COUNT, SUM, etc.)
    keyword_datatype = { fg = "#66D9EF", italic = true }, -- Cyan italic (INT, VARCHAR, etc.)
    keyword_operator = { fg = "#F92672" },                -- Pink/Red (AND, OR, etc.)
    keyword_constraint = { fg = "#FD971F" },              -- Orange (PRIMARY, KEY, etc.)
    keyword_modifier = { fg = "#AE81FF" },                -- Purple (ASC, DESC, etc.)
    keyword_misc = { fg = "#75715E" },                    -- Gray
    keyword_global_variable = { fg = "#F92672" },         -- Pink/Magenta (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#E6DB74" },        -- Yellow (sp_*, xp_*)

    -- Other semantic highlights
    operator = { fg = "#F92672" },                        -- Pink/Red
    string = { fg = "#E6DB74" },                          -- Yellow
    number = { fg = "#AE81FF" },                          -- Purple
    alias = { fg = "#A6E22E", italic = true },            -- Green italic
    unresolved = { fg = "#75715E" },                      -- Gray
    comment = { fg = "#75715E", italic = true },          -- Gray italic

    -- UI-specific colors for floating windows
    ui_border = { fg = "#66D9EF" },                       -- Cyan border
    ui_title = { fg = "#F92672", bold = true },           -- Pink bold title
    ui_selected = { fg = "#F8F8F2", bg = "#49483E" },     -- Foreground on highlight selection
    ui_hint = { fg = "#75715E" },                         -- Comment gray hints

    -- Result buffer highlights
    result_header = { fg = "#66D9EF", bold = true },      -- Cyan
    result_border = { fg = "#49483E" },                   -- Dark gray
    result_null = { fg = "#75715E", italic = true },      -- Comment gray italic
    result_message = { fg = "#A6E22E", italic = true },   -- Green italic
    result_date = { fg = "#E6DB74" },                     -- Yellow
    result_bool = { fg = "#AE81FF" },                     -- Purple
    result_binary = { fg = "#75715E" },                   -- Comment gray
    result_guid = { fg = "#FD971F" },                     -- Orange

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#66D9EF" },                 -- Cyan
    scrollbar_track = { fg = "#49483E" },                 -- Dark gray
    scrollbar_arrow = { fg = "#75715E" },                 -- Comment gray
  },
}
