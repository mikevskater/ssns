-- Night Owl Theme
-- A theme for the night owls out there
-- Deep blue background with vibrant highlights
return {
  name = "Night Owl",
  description = "Deep blue theme for the night owls",
  author = "SSNS",

  colors = {
    -- Server types
    server_sqlserver = { fg = "#82AAFF", bold = true },
    server_postgres = { fg = "#ADDB67", bold = true },
    server_mysql = { fg = "#F78C6C", bold = true },
    server_sqlite = { fg = "#FFCB8B", bold = true },
    server_bigquery = { fg = "#C792EA", bold = true },
    server = { fg = "#637777", bold = true },

    -- Database objects
    database = { fg = "#82AAFF" },
    schema = { fg = "#C792EA" },
    table = { fg = "#7FDBCA" },
    view = { fg = "#FFCB8B" },
    procedure = { fg = "#F78C6C" },
    ["function"] = { fg = "#82AAFF" },
    column = { fg = "#D6DEEB" },
    index = { fg = "#FFCB8B" },
    key = { fg = "#FF5874" },
    parameter = { fg = "#F78C6C", italic = true },
    sequence = { fg = "#ADDB67" },
    synonym = { fg = "#637777" },
    action = { fg = "#C792EA" },
    group = { fg = "#637777", bold = true },

    -- Status
    status_connected = { fg = "#ADDB67", bold = true },
    status_disconnected = { fg = "#637777" },
    status_connecting = { fg = "#FFCB8B" },
    status_error = { fg = "#FF5874", bold = true },

    -- Tree
    expanded = { fg = "#637777" },
    collapsed = { fg = "#637777" },

    -- SQL Keywords
    keyword = { fg = "#C792EA", bold = true },
    keyword_statement = { fg = "#C792EA", bold = true },
    keyword_clause = { fg = "#C792EA", bold = true },
    keyword_function = { fg = "#82AAFF" },
    keyword_datatype = { fg = "#7FDBCA" },
    keyword_operator = { fg = "#7FDBCA" },
    keyword_constraint = { fg = "#F78C6C" },
    keyword_modifier = { fg = "#FFCB8B" },
    keyword_misc = { fg = "#637777" },

    -- Literals & misc
    operator = { fg = "#7FDBCA" },
    string = { fg = "#ECC48D" },
    number = { fg = "#F78C6C" },
    alias = { fg = "#ADDB67", italic = true },
    unresolved = { fg = "#637777" },
    comment = { fg = "#637777", italic = true },
  },
}
