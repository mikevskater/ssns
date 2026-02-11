-- Dracula Theme
-- Dark theme with vibrant purple and pink accents
-- One of the most popular dark themes
return {
  name = "Dracula",
  description = "Dark theme with vibrant purple and pink accents",
  author = "SSNS",

  colors = {
    -- Server types
    server_sqlserver = { fg = "#8BE9FD", bold = true },
    server_postgres = { fg = "#50FA7B", bold = true },
    server_mysql = { fg = "#FFB86C", bold = true },
    server_sqlite = { fg = "#F1FA8C", bold = true },
    server_bigquery = { fg = "#BD93F9", bold = true },
    server = { fg = "#6272A4", bold = true },

    -- Database objects
    database = { fg = "#8BE9FD" },
    schema = { fg = "#BD93F9" },
    table = { fg = "#50FA7B" },
    temp_table = { fg = "#FFB86C", italic = true },       -- Orange italic (#temp, ##global)
    view = { fg = "#F1FA8C" },
    procedure = { fg = "#FFB86C" },
    ["function"] = { fg = "#8BE9FD" },
    column = { fg = "#F8F8F2" },
    index = { fg = "#F1FA8C" },
    key = { fg = "#FF79C6" },
    parameter = { fg = "#FFB86C", italic = true },
    sequence = { fg = "#50FA7B" },
    synonym = { fg = "#6272A4" },
    action = { fg = "#FF79C6" },
    group = { fg = "#6272A4", bold = true },
    server_group = { fg = "#F1FA8C", bold = true },

    -- Status
    status_connected = { fg = "#50FA7B", bold = true },
    status_disconnected = { fg = "#6272A4" },
    status_connecting = { fg = "#F1FA8C" },
    status_error = { fg = "#FF5555", bold = true },

    -- Tree
    expanded = { fg = "#6272A4" },
    collapsed = { fg = "#6272A4" },

    -- SQL Keywords
    keyword = { fg = "#FF79C6", bold = true },
    keyword_statement = { fg = "#FF79C6", bold = true },
    keyword_clause = { fg = "#FF79C6", bold = true },
    keyword_function = { fg = "#8BE9FD" },
    keyword_datatype = { fg = "#8BE9FD", italic = true },
    keyword_operator = { fg = "#FF79C6" },
    keyword_constraint = { fg = "#FFB86C" },
    keyword_modifier = { fg = "#BD93F9" },
    keyword_misc = { fg = "#6272A4" },
    keyword_global_variable = { fg = "#FF5555" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#F1FA8C" },        -- Yellow (sp_*, xp_*)

    -- Literals & misc
    operator = { fg = "#FF79C6" },
    string = { fg = "#F1FA8C" },
    number = { fg = "#BD93F9" },
    alias = { fg = "#50FA7B", italic = true },
    unresolved = { fg = "#6272A4" },
    comment = { fg = "#6272A4", italic = true },

    -- UI-specific colors for floating windows
    ui_border = { fg = "#BD93F9" },                       -- Purple border
    ui_title = { fg = "#FF79C6", bold = true },           -- Pink bold title
    ui_selected = { fg = "#F8F8F2", bg = "#44475A" },     -- Foreground on current line selection
    ui_hint = { fg = "#6272A4" },                         -- Comment gray hints

    -- Result buffer highlights
    result_header = { fg = "#8BE9FD", bold = true },      -- Cyan
    result_border = { fg = "#44475A" },                   -- Current line
    result_null = { fg = "#6272A4", italic = true },      -- Comment gray italic
    result_message = { fg = "#50FA7B", italic = true },   -- Green italic
    result_date = { fg = "#F1FA8C" },                     -- Yellow
    result_bool = { fg = "#BD93F9" },                     -- Purple
    result_binary = { fg = "#6272A4" },                   -- Comment gray
    result_guid = { fg = "#FFB86C" },                     -- Orange

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#BD93F9" },                 -- Purple
    scrollbar_track = { fg = "#44475A" },                 -- Current line
    scrollbar_arrow = { fg = "#6272A4" },                 -- Comment gray
  },
}
