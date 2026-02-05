-- Tokyo Night Theme
-- A clean, dark theme that celebrates the lights of Tokyo at night
-- Inspired by the Tokyo Night VSCode theme
return {
  name = "Tokyo Night",
  description = "Clean dark theme inspired by Tokyo city lights",
  author = "SSNS",

  colors = {
    -- Server types
    server_sqlserver = { fg = "#7AA2F7", bold = true },
    server_postgres = { fg = "#9ECE6A", bold = true },
    server_mysql = { fg = "#FF9E64", bold = true },
    server_sqlite = { fg = "#E0AF68", bold = true },
    server_bigquery = { fg = "#BB9AF7", bold = true },
    server = { fg = "#565F89", bold = true },

    -- Database objects
    database = { fg = "#7AA2F7" },
    schema = { fg = "#BB9AF7" },
    table = { fg = "#73DACA" },
    temp_table = { fg = "#FF9E64", italic = true },       -- Orange italic (#temp, ##global)
    view = { fg = "#E0AF68" },
    procedure = { fg = "#FF9E64" },
    ["function"] = { fg = "#7DCFFF" },
    column = { fg = "#C0CAF5" },
    index = { fg = "#E0AF68" },
    key = { fg = "#F7768E" },
    parameter = { fg = "#FF9E64", italic = true },
    sequence = { fg = "#9ECE6A" },
    synonym = { fg = "#565F89" },
    action = { fg = "#FF79C6" },
    group = { fg = "#565F89", bold = true },

    -- Status
    status_connected = { fg = "#9ECE6A", bold = true },
    status_disconnected = { fg = "#565F89" },
    status_connecting = { fg = "#E0AF68" },
    status_error = { fg = "#F7768E", bold = true },

    -- Tree
    expanded = { fg = "#565F89" },
    collapsed = { fg = "#565F89" },

    -- SQL Keywords
    keyword = { fg = "#BB9AF7", bold = true },
    keyword_statement = { fg = "#BB9AF7", bold = true },
    keyword_clause = { fg = "#7AA2F7", bold = true },
    keyword_function = { fg = "#7DCFFF" },
    keyword_datatype = { fg = "#2AC3DE" },
    keyword_operator = { fg = "#89DDFF" },
    keyword_constraint = { fg = "#FF9E64" },
    keyword_modifier = { fg = "#BB9AF7" },
    keyword_misc = { fg = "#565F89" },
    keyword_global_variable = { fg = "#F7768E" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#E0AF68" },        -- Yellow (sp_*, xp_*)

    -- Literals & misc
    operator = { fg = "#89DDFF" },
    string = { fg = "#9ECE6A" },
    number = { fg = "#FF9E64" },
    alias = { fg = "#73DACA", italic = true },
    unresolved = { fg = "#565F89" },
    comment = { fg = "#565F89", italic = true },

    -- UI-specific colors for floating windows
    ui_border = { fg = "#7AA2F7" },                       -- Blue border
    ui_title = { fg = "#BB9AF7", bold = true },           -- Purple bold title
    ui_selected = { fg = "#C0CAF5", bg = "#292E42" },     -- Foreground on selection
    ui_hint = { fg = "#565F89" },                         -- Comment hints

    -- Result buffer highlights
    result_header = { fg = "#7AA2F7", bold = true },      -- Blue
    result_border = { fg = "#292E42" },                   -- Dark selection
    result_null = { fg = "#565F89", italic = true },      -- Comment gray italic
    result_message = { fg = "#9ECE6A", italic = true },   -- Green italic
    result_date = { fg = "#E0AF68" },                     -- Yellow
    result_bool = { fg = "#2AC3DE" },                     -- Cyan
    result_binary = { fg = "#565F89" },                   -- Comment gray
    result_guid = { fg = "#FF9E64" },                     -- Orange

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#7AA2F7" },                 -- Blue
    scrollbar_track = { fg = "#292E42" },                 -- Dark selection
    scrollbar_arrow = { fg = "#565F89" },                 -- Comment gray
  },
}
