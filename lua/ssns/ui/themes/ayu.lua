-- Ayu Dark Theme
-- Simple, bright colors on a dark background
-- Modern and elegant color scheme
return {
  name = "Ayu",
  description = "Simple and elegant dark theme",
  author = "SSNS",

  colors = {
    -- Server types
    server_sqlserver = { fg = "#59C2FF", bold = true },
    server_postgres = { fg = "#AAD94C", bold = true },
    server_mysql = { fg = "#FF8F40", bold = true },
    server_sqlite = { fg = "#FFB454", bold = true },
    server_bigquery = { fg = "#D2A6FF", bold = true },
    server = { fg = "#565B66", bold = true },

    -- Database objects
    database = { fg = "#59C2FF" },
    schema = { fg = "#D2A6FF" },
    table = { fg = "#95E6CB" },
    view = { fg = "#FFB454" },
    procedure = { fg = "#FF8F40" },
    ["function"] = { fg = "#59C2FF" },
    column = { fg = "#BFBDB6" },
    index = { fg = "#FFB454" },
    key = { fg = "#F07178" },
    parameter = { fg = "#FF8F40", italic = true },
    sequence = { fg = "#AAD94C" },
    synonym = { fg = "#565B66" },
    action = { fg = "#D2A6FF" },
    group = { fg = "#565B66", bold = true },

    -- Status
    status_connected = { fg = "#AAD94C", bold = true },
    status_disconnected = { fg = "#565B66" },
    status_connecting = { fg = "#FFB454" },
    status_error = { fg = "#F07178", bold = true },

    -- Tree
    expanded = { fg = "#565B66" },
    collapsed = { fg = "#565B66" },

    -- SQL Keywords
    keyword = { fg = "#FF8F40", bold = true },
    keyword_statement = { fg = "#FF8F40", bold = true },
    keyword_clause = { fg = "#FF8F40", bold = true },
    keyword_function = { fg = "#FFB454" },
    keyword_datatype = { fg = "#59C2FF" },
    keyword_operator = { fg = "#F29668" },
    keyword_constraint = { fg = "#FF8F40" },
    keyword_modifier = { fg = "#D2A6FF" },
    keyword_misc = { fg = "#565B66" },
    keyword_global_variable = { fg = "#F07178" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)

    -- Literals & misc
    operator = { fg = "#F29668" },
    string = { fg = "#AAD94C" },
    number = { fg = "#D2A6FF" },
    alias = { fg = "#95E6CB", italic = true },
    unresolved = { fg = "#565B66" },
    comment = { fg = "#565B66", italic = true },
  },
}
