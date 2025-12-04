-- One Dark Theme
-- Inspired by Atom's One Dark theme
-- Clean and modern dark color scheme
return {
  name = "One Dark",
  description = "Atom One Dark inspired theme",
  author = "SSNS",

  colors = {
    -- Server types
    server_sqlserver = { fg = "#61AFEF", bold = true },
    server_postgres = { fg = "#98C379", bold = true },
    server_mysql = { fg = "#D19A66", bold = true },
    server_sqlite = { fg = "#E5C07B", bold = true },
    server_bigquery = { fg = "#C678DD", bold = true },
    server = { fg = "#5C6370", bold = true },

    -- Database objects
    database = { fg = "#61AFEF" },
    schema = { fg = "#C678DD" },
    table = { fg = "#98C379" },
    view = { fg = "#E5C07B" },
    procedure = { fg = "#D19A66" },
    ["function"] = { fg = "#61AFEF" },
    column = { fg = "#ABB2BF" },
    index = { fg = "#E5C07B" },
    key = { fg = "#E06C75" },
    parameter = { fg = "#D19A66", italic = true },
    sequence = { fg = "#98C379" },
    synonym = { fg = "#5C6370" },
    action = { fg = "#C678DD" },
    group = { fg = "#5C6370", bold = true },

    -- Status
    status_connected = { fg = "#98C379", bold = true },
    status_disconnected = { fg = "#5C6370" },
    status_connecting = { fg = "#E5C07B" },
    status_error = { fg = "#E06C75", bold = true },

    -- Tree
    expanded = { fg = "#5C6370" },
    collapsed = { fg = "#5C6370" },

    -- SQL Keywords
    keyword = { fg = "#C678DD", bold = true },
    keyword_statement = { fg = "#C678DD", bold = true },
    keyword_clause = { fg = "#C678DD", bold = true },
    keyword_function = { fg = "#61AFEF" },
    keyword_datatype = { fg = "#56B6C2" },
    keyword_operator = { fg = "#C678DD" },
    keyword_constraint = { fg = "#D19A66" },
    keyword_modifier = { fg = "#E5C07B" },
    keyword_misc = { fg = "#5C6370" },

    -- Literals & misc
    operator = { fg = "#56B6C2" },
    string = { fg = "#98C379" },
    number = { fg = "#D19A66" },
    alias = { fg = "#E06C75", italic = true },
    unresolved = { fg = "#5C6370" },
    comment = { fg = "#5C6370", italic = true },
  },
}
