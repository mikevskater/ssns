-- Gruvbox Theme (Gruvbox Dark inspired)
-- Retro groove color scheme

return {
  name = "Gruvbox",
  description = "Retro groove Gruvbox Dark theme",
  author = "SSNS",

  colors = {
    -- Server type highlights (using Gruvbox palette)
    server_sqlserver = { fg = "#83A598", bold = true },   -- Blue
    server_postgres = { fg = "#8EC07C", bold = true },    -- Aqua
    server_mysql = { fg = "#FE8019", bold = true },       -- Orange
    server_sqlite = { fg = "#B8BB26", bold = true },      -- Green
    server_bigquery = { fg = "#D3869B", bold = true },    -- Purple
    server = { fg = "#928374", bold = true },             -- Gray (default)

    -- Object type highlights
    database = { fg = "#83A598" },                        -- Blue
    schema = { fg = "#D3869B" },                          -- Purple
    table = { fg = "#8EC07C" },                           -- Aqua
    temp_table = { fg = "#FE8019", italic = true },       -- Orange italic (#temp, ##global)
    view = { fg = "#FABD2F" },                            -- Yellow
    procedure = { fg = "#FE8019" },                       -- Orange
    ["function"] = { fg = "#8EC07C" },                    -- Aqua
    column = { fg = "#EBDBB2" },                          -- Foreground
    index = { fg = "#FABD2F" },                           -- Yellow
    key = { fg = "#FB4934" },                             -- Red
    parameter = { fg = "#FE8019", italic = true },        -- Orange italic
    sequence = { fg = "#B8BB26" },                        -- Green
    synonym = { fg = "#928374" },                         -- Gray
    action = { fg = "#FB4934" },                          -- Red
    group = { fg = "#928374", bold = true },              -- Gray bold
    server_group = { fg = "#D79921", bold = true },

    -- Status highlights
    status_connected = { fg = "#B8BB26", bold = true },   -- Green
    status_disconnected = { fg = "#928374" },             -- Gray
    status_connecting = { fg = "#FABD2F" },               -- Yellow
    status_error = { fg = "#FB4934", bold = true },       -- Red

    -- Tree indicators
    expanded = { fg = "#928374" },
    collapsed = { fg = "#928374" },

    -- Semantic highlighting (query buffers)
    keyword = { fg = "#FB4934", bold = true },            -- Red
    keyword_statement = { fg = "#FB4934", bold = true },  -- Red (SELECT, INSERT, etc.)
    keyword_clause = { fg = "#83A598", bold = true },     -- Blue (FROM, WHERE, etc.)
    keyword_function = { fg = "#FABD2F" },                -- Yellow (COUNT, SUM, etc.)
    keyword_datatype = { fg = "#8EC07C" },                -- Aqua (INT, VARCHAR, etc.)
    keyword_operator = { fg = "#FB4934" },                -- Red (AND, OR, etc.)
    keyword_constraint = { fg = "#FE8019" },              -- Orange (PRIMARY, KEY, etc.)
    keyword_modifier = { fg = "#D3869B" },                -- Purple (ASC, DESC, etc.)
    keyword_misc = { fg = "#928374" },                    -- Gray
    keyword_global_variable = { fg = "#FB4934" },         -- Red (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#FABD2F" },        -- Yellow (sp_*, xp_*)

    -- Other semantic highlights
    operator = { fg = "#EBDBB2" },                        -- Foreground
    string = { fg = "#B8BB26" },                          -- Green
    number = { fg = "#D3869B" },                          -- Purple
    alias = { fg = "#8EC07C", italic = true },            -- Aqua italic
    unresolved = { fg = "#928374" },                      -- Gray
    comment = { fg = "#928374", italic = true },          -- Gray italic

    -- UI-specific colors for floating windows
    ui_border = { fg = "#FABD2F" },                       -- Yellow border
    ui_title = { fg = "#D3869B", bold = true },           -- Purple bold title
    ui_selected = { fg = "#EBDBB2", bg = "#504945" },     -- Foreground on gray selection
    ui_hint = { fg = "#928374" },                         -- Gray hints

    -- Result buffer highlights
    result_header = { fg = "#83A598", bold = true },      -- Blue
    result_border = { fg = "#504945" },                   -- Dark gray
    result_null = { fg = "#928374", italic = true },      -- Gray italic
    result_message = { fg = "#B8BB26", italic = true },   -- Green italic
    result_date = { fg = "#FABD2F" },                     -- Yellow
    result_bool = { fg = "#83A598" },                     -- Blue
    result_binary = { fg = "#928374" },                   -- Gray
    result_guid = { fg = "#FE8019" },                     -- Orange

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#FABD2F" },                 -- Yellow
    scrollbar_track = { fg = "#504945" },                 -- Dark gray
    scrollbar_arrow = { fg = "#928374" },                 -- Gray
  },
}
