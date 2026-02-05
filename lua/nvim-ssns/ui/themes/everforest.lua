-- Everforest Theme
-- Comfortable and pleasant green-based color scheme
-- Designed to be easy on the eyes
return {
  name = "Everforest",
  description = "Green nature-inspired comfortable theme",
  author = "SSNS",

  colors = {
    -- Server types
    server_sqlserver = { fg = "#7FBBB3", bold = true },
    server_postgres = { fg = "#A7C080", bold = true },
    server_mysql = { fg = "#E69875", bold = true },
    server_sqlite = { fg = "#DBBC7F", bold = true },
    server_bigquery = { fg = "#D699B6", bold = true },
    server = { fg = "#859289", bold = true },

    -- Database objects
    database = { fg = "#7FBBB3" },
    schema = { fg = "#D699B6" },
    table = { fg = "#A7C080" },
    temp_table = { fg = "#E69875", italic = true },       -- Orange italic (#temp, ##global)
    view = { fg = "#DBBC7F" },
    procedure = { fg = "#E69875" },
    ["function"] = { fg = "#83C092" },
    column = { fg = "#D3C6AA" },
    index = { fg = "#DBBC7F" },
    key = { fg = "#E67E80" },
    parameter = { fg = "#E69875", italic = true },
    sequence = { fg = "#A7C080" },
    synonym = { fg = "#859289" },
    action = { fg = "#D699B6" },
    group = { fg = "#859289", bold = true },

    -- Status
    status_connected = { fg = "#A7C080", bold = true },
    status_disconnected = { fg = "#859289" },
    status_connecting = { fg = "#DBBC7F" },
    status_error = { fg = "#E67E80", bold = true },

    -- Tree
    expanded = { fg = "#859289" },
    collapsed = { fg = "#859289" },

    -- SQL Keywords
    keyword = { fg = "#E67E80", bold = true },
    keyword_statement = { fg = "#E67E80", bold = true },
    keyword_clause = { fg = "#7FBBB3", bold = true },
    keyword_function = { fg = "#83C092" },
    keyword_datatype = { fg = "#7FBBB3" },
    keyword_operator = { fg = "#E67E80" },
    keyword_constraint = { fg = "#E69875" },
    keyword_modifier = { fg = "#D699B6" },
    keyword_misc = { fg = "#859289" },
    keyword_global_variable = { fg = "#E67E80" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#DBBC7F" },        -- Yellow (sp_*, xp_*)

    -- Literals & misc
    operator = { fg = "#E67E80" },
    string = { fg = "#A7C080" },
    number = { fg = "#D699B6" },
    alias = { fg = "#83C092", italic = true },
    unresolved = { fg = "#859289" },
    comment = { fg = "#859289", italic = true },

    -- UI-specific colors for floating windows
    ui_border = { fg = "#7FBBB3" },                       -- Aqua border
    ui_title = { fg = "#D699B6", bold = true },           -- Purple bold title
    ui_selected = { fg = "#D3C6AA", bg = "#3D484D" },    -- Foreground on selection
    ui_hint = { fg = "#859289" },                         -- Gray hints

    -- Result buffer highlights
    result_header = { fg = "#7FBBB3", bold = true },      -- Aqua
    result_border = { fg = "#3D484D" },                   -- Dark bg
    result_null = { fg = "#859289", italic = true },      -- Gray italic
    result_message = { fg = "#A7C080", italic = true },   -- Green italic
    result_date = { fg = "#DBBC7F" },                     -- Yellow
    result_bool = { fg = "#83C092" },                     -- Aqua green
    result_binary = { fg = "#859289" },                   -- Gray
    result_guid = { fg = "#E69875" },                     -- Orange

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#7FBBB3" },                 -- Aqua
    scrollbar_track = { fg = "#3D484D" },                 -- Dark bg
    scrollbar_arrow = { fg = "#859289" },                 -- Gray
  },
}
