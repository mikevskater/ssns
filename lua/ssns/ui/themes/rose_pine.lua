-- Rose Pine Theme
-- All natural pine, faux fur and a bit of soho vibes
-- Elegant theme with rose gold accents
return {
  name = "Rose Pine",
  description = "Elegant theme with rose gold accents",
  author = "SSNS",

  colors = {
    -- Server types
    server_sqlserver = { fg = "#9CCFD8", bold = true },
    server_postgres = { fg = "#31748F", bold = true },
    server_mysql = { fg = "#EA9A97", bold = true },
    server_sqlite = { fg = "#F6C177", bold = true },
    server_bigquery = { fg = "#C4A7E7", bold = true },
    server = { fg = "#6E6A86", bold = true },

    -- Database objects
    database = { fg = "#9CCFD8" },
    schema = { fg = "#C4A7E7" },
    table = { fg = "#31748F" },
    view = { fg = "#F6C177" },
    procedure = { fg = "#EA9A97" },
    ["function"] = { fg = "#9CCFD8" },
    column = { fg = "#E0DEF4" },
    index = { fg = "#F6C177" },
    key = { fg = "#EB6F92" },
    parameter = { fg = "#EA9A97", italic = true },
    sequence = { fg = "#31748F" },
    synonym = { fg = "#6E6A86" },
    action = { fg = "#EBBCBA" },
    group = { fg = "#6E6A86", bold = true },

    -- Status
    status_connected = { fg = "#31748F", bold = true },
    status_disconnected = { fg = "#6E6A86" },
    status_connecting = { fg = "#F6C177" },
    status_error = { fg = "#EB6F92", bold = true },

    -- Tree
    expanded = { fg = "#6E6A86" },
    collapsed = { fg = "#6E6A86" },

    -- SQL Keywords
    keyword = { fg = "#31748F", bold = true },
    keyword_statement = { fg = "#31748F", bold = true },
    keyword_clause = { fg = "#9CCFD8", bold = true },
    keyword_function = { fg = "#EBBCBA" },
    keyword_datatype = { fg = "#9CCFD8" },
    keyword_operator = { fg = "#31748F" },
    keyword_constraint = { fg = "#EA9A97" },
    keyword_modifier = { fg = "#C4A7E7" },
    keyword_misc = { fg = "#6E6A86" },
    keyword_global_variable = { fg = "#EB6F92" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#F6C177" },        -- Gold (sp_*, xp_*)

    -- Literals & misc
    operator = { fg = "#908CAA" },
    string = { fg = "#F6C177" },
    number = { fg = "#EA9A97" },
    alias = { fg = "#9CCFD8", italic = true },
    unresolved = { fg = "#6E6A86" },
    comment = { fg = "#6E6A86", italic = true },
  },
}
