-- Synthwave '84 Theme
-- Retro 80s inspired neon theme
-- Vibrant neon colors on a dark background
return {
  name = "Synthwave",
  description = "Retro 80s neon synthwave theme",
  author = "SSNS",

  colors = {
    -- Server types
    server_sqlserver = { fg = "#36F9F6", bold = true },
    server_postgres = { fg = "#72F1B8", bold = true },
    server_mysql = { fg = "#FEDE5D", bold = true },
    server_sqlite = { fg = "#FF7EDB", bold = true },
    server_bigquery = { fg = "#F97E72", bold = true },
    server = { fg = "#848BBD", bold = true },

    -- Database objects
    database = { fg = "#36F9F6" },
    schema = { fg = "#FF7EDB" },
    table = { fg = "#72F1B8" },
    temp_table = { fg = "#F97E72", italic = true },       -- Coral italic (#temp, ##global)
    view = { fg = "#FEDE5D" },
    procedure = { fg = "#F97E72" },
    ["function"] = { fg = "#36F9F6" },
    column = { fg = "#FFFFFF" },
    index = { fg = "#FEDE5D" },
    key = { fg = "#FE4450" },
    parameter = { fg = "#F97E72", italic = true },
    sequence = { fg = "#72F1B8" },
    synonym = { fg = "#848BBD" },
    action = { fg = "#FF7EDB" },
    group = { fg = "#848BBD", bold = true },

    -- Status
    status_connected = { fg = "#72F1B8", bold = true },
    status_disconnected = { fg = "#848BBD" },
    status_connecting = { fg = "#FEDE5D" },
    status_error = { fg = "#FE4450", bold = true },

    -- Tree
    expanded = { fg = "#848BBD" },
    collapsed = { fg = "#848BBD" },

    -- SQL Keywords
    keyword = { fg = "#FE4450", bold = true },
    keyword_statement = { fg = "#FE4450", bold = true },
    keyword_clause = { fg = "#FF7EDB", bold = true },
    keyword_function = { fg = "#36F9F6" },
    keyword_datatype = { fg = "#36F9F6", italic = true },
    keyword_operator = { fg = "#FE4450" },
    keyword_constraint = { fg = "#F97E72" },
    keyword_modifier = { fg = "#FF7EDB" },
    keyword_misc = { fg = "#848BBD" },
    keyword_global_variable = { fg = "#FE4450" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#FEDE5D" },        -- Yellow (sp_*, xp_*)

    -- Literals & misc
    operator = { fg = "#FE4450" },
    string = { fg = "#FEDE5D" },
    number = { fg = "#F97E72" },
    alias = { fg = "#72F1B8", italic = true },
    unresolved = { fg = "#848BBD" },
    comment = { fg = "#848BBD", italic = true },

    -- UI-specific colors for floating windows
    ui_border = { fg = "#FE4450" },                       -- Neon red border
    ui_title = { fg = "#F97E72", bold = true },           -- Salmon bold title
    ui_selected = { fg = "#FFFFFF", bg = "#2A2139" },    -- White on dark selection
    ui_hint = { fg = "#848bbd" },                         -- Gray hints

    -- Result buffer highlights
    result_header = { fg = "#36F9F6", bold = true },      -- Cyan
    result_border = { fg = "#2A2139" },                   -- Dark bg
    result_null = { fg = "#848BBD", italic = true },      -- Gray italic
    result_message = { fg = "#72F1B8", italic = true },   -- Green italic
    result_date = { fg = "#FEDE5D" },                     -- Yellow
    result_bool = { fg = "#36F9F6" },                     -- Cyan
    result_binary = { fg = "#848BBD" },                   -- Gray
    result_guid = { fg = "#F97E72" },                     -- Salmon

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#FE4450" },                 -- Neon red
    scrollbar_track = { fg = "#2A2139" },                 -- Dark bg
    scrollbar_arrow = { fg = "#848BBD" },                 -- Gray
  },
}
