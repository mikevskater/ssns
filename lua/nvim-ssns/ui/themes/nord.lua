-- Nord Theme
-- Arctic, north-bluish color palette
-- Inspired by the beauty of the arctic
return {
  name = "Nord",
  description = "Arctic, north-bluish color palette",
  author = "SSNS",

  colors = {
    -- Server types
    server_sqlserver = { fg = "#81A1C1", bold = true },
    server_postgres = { fg = "#A3BE8C", bold = true },
    server_mysql = { fg = "#EBCB8B", bold = true },
    server_sqlite = { fg = "#B48EAD", bold = true },
    server_bigquery = { fg = "#88C0D0", bold = true },
    server = { fg = "#4C566A", bold = true },

    -- Database objects
    database = { fg = "#88C0D0" },
    schema = { fg = "#B48EAD" },
    table = { fg = "#81A1C1" },
    temp_table = { fg = "#D08770", italic = true },       -- Orange italic (#temp, ##global)
    view = { fg = "#EBCB8B" },
    procedure = { fg = "#D08770" },
    ["function"] = { fg = "#A3BE8C" },
    column = { fg = "#ECEFF4" },
    index = { fg = "#EBCB8B" },
    key = { fg = "#BF616A" },
    parameter = { fg = "#D08770", italic = true },
    sequence = { fg = "#A3BE8C" },
    synonym = { fg = "#4C566A" },
    action = { fg = "#B48EAD" },
    group = { fg = "#4C566A", bold = true },

    -- Status
    status_connected = { fg = "#A3BE8C", bold = true },
    status_disconnected = { fg = "#4C566A" },
    status_connecting = { fg = "#EBCB8B" },
    status_error = { fg = "#BF616A", bold = true },

    -- Tree
    expanded = { fg = "#4C566A" },
    collapsed = { fg = "#4C566A" },

    -- SQL Keywords
    keyword = { fg = "#81A1C1", bold = true },
    keyword_statement = { fg = "#81A1C1", bold = true },
    keyword_clause = { fg = "#81A1C1", bold = true },
    keyword_function = { fg = "#88C0D0" },
    keyword_datatype = { fg = "#8FBCBB" },
    keyword_operator = { fg = "#81A1C1" },
    keyword_constraint = { fg = "#D08770" },
    keyword_modifier = { fg = "#B48EAD" },
    keyword_misc = { fg = "#4C566A" },
    keyword_global_variable = { fg = "#BF616A" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#EBCB8B" },        -- Yellow (sp_*, xp_*)

    -- Literals & misc
    operator = { fg = "#ECEFF4" },
    string = { fg = "#A3BE8C" },
    number = { fg = "#B48EAD" },
    alias = { fg = "#8FBCBB", italic = true },
    unresolved = { fg = "#4C566A" },
    comment = { fg = "#616E88", italic = true },

    -- UI-specific colors for floating windows
    ui_border = { fg = "#88C0D0" },                       -- Frost blue border
    ui_title = { fg = "#B48EAD", bold = true },           -- Aurora purple bold title
    ui_selected = { fg = "#ECEFF4", bg = "#434C5E" },     -- Snow on polar selection
    ui_hint = { fg = "#4C566A" },                         -- Polar night hints

    -- Result buffer highlights
    result_header = { fg = "#88C0D0", bold = true },      -- Frost cyan
    result_border = { fg = "#3B4252" },                   -- Polar night
    result_null = { fg = "#4C566A", italic = true },      -- Polar night gray italic
    result_message = { fg = "#A3BE8C", italic = true },   -- Aurora green italic
    result_date = { fg = "#EBCB8B" },                     -- Aurora yellow
    result_bool = { fg = "#81A1C1" },                     -- Frost blue
    result_binary = { fg = "#4C566A" },                   -- Polar night gray
    result_guid = { fg = "#D08770" },                     -- Aurora orange

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#88C0D0" },                 -- Frost cyan
    scrollbar_track = { fg = "#3B4252" },                 -- Polar night
    scrollbar_arrow = { fg = "#4C566A" },                 -- Polar night gray
  },
}
