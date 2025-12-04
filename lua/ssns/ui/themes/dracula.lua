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

    -- Literals & misc
    operator = { fg = "#FF79C6" },
    string = { fg = "#F1FA8C" },
    number = { fg = "#BD93F9" },
    alias = { fg = "#50FA7B", italic = true },
    unresolved = { fg = "#6272A4" },
    comment = { fg = "#6272A4", italic = true },
  },
}
