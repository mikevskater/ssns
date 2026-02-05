-- Solarized Dark Theme
-- Precision colors for machines and people
-- Designed for readability and reduced eye strain
return {
  name = "Solarized",
  description = "Precision colors designed for readability",
  author = "SSNS",

  colors = {
    -- Server types
    server_sqlserver = { fg = "#268BD2", bold = true },
    server_postgres = { fg = "#859900", bold = true },
    server_mysql = { fg = "#CB4B16", bold = true },
    server_sqlite = { fg = "#B58900", bold = true },
    server_bigquery = { fg = "#6C71C4", bold = true },
    server = { fg = "#586E75", bold = true },

    -- Database objects
    database = { fg = "#268BD2" },
    schema = { fg = "#6C71C4" },
    table = { fg = "#2AA198" },
    temp_table = { fg = "#CB4B16", italic = true },       -- Orange italic (#temp, ##global)
    view = { fg = "#B58900" },
    procedure = { fg = "#CB4B16" },
    ["function"] = { fg = "#859900" },
    column = { fg = "#93A1A1" },
    index = { fg = "#B58900" },
    key = { fg = "#DC322F" },
    parameter = { fg = "#CB4B16", italic = true },
    sequence = { fg = "#859900" },
    synonym = { fg = "#586E75" },
    action = { fg = "#D33682" },
    group = { fg = "#586E75", bold = true },

    -- Status
    status_connected = { fg = "#859900", bold = true },
    status_disconnected = { fg = "#586E75" },
    status_connecting = { fg = "#B58900" },
    status_error = { fg = "#DC322F", bold = true },

    -- Tree
    expanded = { fg = "#586E75" },
    collapsed = { fg = "#586E75" },

    -- SQL Keywords
    keyword = { fg = "#859900", bold = true },
    keyword_statement = { fg = "#859900", bold = true },
    keyword_clause = { fg = "#268BD2", bold = true },
    keyword_function = { fg = "#B58900" },
    keyword_datatype = { fg = "#2AA198" },
    keyword_operator = { fg = "#859900" },
    keyword_constraint = { fg = "#CB4B16" },
    keyword_modifier = { fg = "#6C71C4" },
    keyword_misc = { fg = "#586E75" },
    keyword_global_variable = { fg = "#DC322F" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#B58900" },        -- Yellow (sp_*, xp_*)

    -- Literals & misc
    operator = { fg = "#93A1A1" },
    string = { fg = "#2AA198" },
    number = { fg = "#D33682" },
    alias = { fg = "#268BD2", italic = true },
    unresolved = { fg = "#586E75" },
    comment = { fg = "#586E75", italic = true },

    -- UI-specific colors for floating windows
    ui_border = { fg = "#268BD2" },                       -- Blue border
    ui_title = { fg = "#D33682", bold = true },           -- Magenta bold title
    ui_selected = { fg = "#FDF6E3", bg = "#073642" },     -- Base3 on base02 selection
    ui_hint = { fg = "#586E75" },                         -- Base01 hints

    -- Result buffer highlights
    result_header = { fg = "#268BD2", bold = true },      -- Blue
    result_border = { fg = "#073642" },                   -- Base02
    result_null = { fg = "#586E75", italic = true },      -- Base01 italic
    result_message = { fg = "#859900", italic = true },   -- Green italic
    result_date = { fg = "#B58900" },                     -- Yellow
    result_bool = { fg = "#2AA198" },                     -- Cyan
    result_binary = { fg = "#586E75" },                   -- Base01
    result_guid = { fg = "#CB4B16" },                     -- Orange

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#268BD2" },                 -- Blue
    scrollbar_track = { fg = "#073642" },                 -- Base02
    scrollbar_arrow = { fg = "#586E75" },                 -- Base01
  },
}
