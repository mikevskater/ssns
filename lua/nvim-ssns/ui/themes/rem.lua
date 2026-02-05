-- Rem Theme (Re:Zero inspired)
-- Who's Rem? The best maid with blue hair and unwavering dedication

return {
  name = "Rem",
  description = "Re:Zero's Rem inspired theme with blues and purples",
  author = "User",

  colors = {
    -- Server type highlights (using Rem's color palette)
    server_sqlserver = { fg = "#428EC5", bold = true },   -- Deep Blue (Rem's hair)
    server_postgres = { fg = "#90BFF9", bold = true },    -- Light Blue
    server_mysql = { fg = "#8D5FAE", bold = true },       -- Purple (her dress)
    server_sqlite = { fg = "#C193BF", bold = true },      -- Light Purple
    server_bigquery = { fg = "#F6E8DC", bold = true },    -- Light Tan (her skin tone)
    server = { fg = "#49494B", bold = true },             -- Dark Grey Purple

    -- Object type highlights (rotating through Rem's palette)
    database = { fg = "#428EC5" },                        -- Deep Blue
    schema = { fg = "#8D5FAE" },                          -- Purple
    table = { fg = "#90BFF9" },                           -- Light Blue
    temp_table = { fg = "#B4D5FE", italic = true },       -- Lighter blue italic (#temp, ##global)
    view = { fg = "#CF71AB" },                            -- Light Purple
    procedure = { fg = "#428EC5" },                       -- Deep Blue
    ["function"] = { fg = "#90BFF9" },                    -- Light Blue
    column = { fg = "#EBFBFC" },                          -- White
    index = { fg = "#F6E8DC" },                           -- Light Tan
    key = { fg = "#428EC5", bold = true },                -- Deep Blue bold
    parameter = { fg = "#C193BF", italic = true },        -- Light Purple italic
    sequence = { fg = "#8D5FAE" },                        -- Purple
    synonym = { fg = "#7979B4" },                         -- Dark Grey Purple
    action = { fg = "#C193BF" },                          -- Light Purple
    group = { fg = "#8ED3D8", bold = true },              -- Dark Grey Purple bold

    -- Status highlights
    status_connected = { fg = "#428EC5", bold = true },   -- Deep Blue (loyal connection)
    status_disconnected = { fg = "#49494B" },             -- Dark Grey Purple
    status_connecting = { fg = "#90BFF9" },               -- Light Blue
    status_error = { fg = "#FF0000", bold = true },       -- Red (need contrast for errors)

    -- Tree indicators
    expanded = { fg = "#49494B" },
    collapsed = { fg = "#49494B" },

    -- Semantic highlighting (query buffers with Rem's colors)
    keyword = { fg = "#428EC5", bold = true },            -- Deep Blue
    keyword_statement = { fg = "#8D5FAE", bold = true },  -- Purple (SELECT, INSERT, etc.)
    keyword_clause = { fg = "#428EC5", bold = true },     -- Deep Blue (FROM, WHERE, etc.)
    keyword_function = { fg = "#90BFF9" },                -- Light Blue (COUNT, SUM, etc.)
    keyword_datatype = { fg = "#C193BF" },                -- Light Purple (INT, VARCHAR, etc.)
    keyword_operator = { fg = "#90BFF9" },                -- Light Blue (AND, OR, etc.)
    keyword_constraint = { fg = "#8D5FAE" },              -- Purple (PRIMARY, KEY, etc.)
    keyword_modifier = { fg = "#C193BF" },                -- Light Purple (ASC, DESC, etc.)
    keyword_misc = { fg = "#67677C" },                    -- Dark Grey Purple
    keyword_global_variable = { fg = "#428EC5" },         -- Deep Blue (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#90BFF9" },        -- Light Blue (sp_*, xp_*)

    -- Other semantic highlights
    operator = { fg = "#90BFF9" },                        -- Light Blue
    string = { fg = "#F6E8DC" },                          -- Light Tan
    number = { fg = "#C193BF" },                          -- Light Purple
    alias = { fg = "#90BFF9", italic = true },            -- Light Blue italic
    unresolved = { fg = "#9A569C" },                      -- Dark Grey Purple
    comment = { fg = "#767686", italic = true },          -- Dark Grey Purple italic

    -- UI-specific colors for floating windows
    ui_border = { fg = "#428EC5" },                       -- Deep Blue border
    ui_title = { fg = "#8D5FAE", bold = true },           -- Purple title
    ui_selected = { fg = "#EBFBFC", bg = "#428EC5" },     -- White on deep blue
    ui_hint = { fg = "#49494B" },                         -- Dark Grey Purple hints

    -- Result buffer highlights
    result_header = { fg = "#428EC5", bold = true },      -- Deep Blue
    result_border = { fg = "#49494B" },                   -- Dark Grey Purple
    result_null = { fg = "#67677C", italic = true },      -- Dark Grey italic
    result_message = { fg = "#90BFF9", italic = true },   -- Light Blue italic
    result_date = { fg = "#F6E8DC" },                     -- Light Tan
    result_bool = { fg = "#90BFF9" },                     -- Light Blue
    result_binary = { fg = "#49494B" },                   -- Dark Grey Purple
    result_guid = { fg = "#C193BF" },                     -- Light Purple

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#428EC5" },                 -- Deep Blue
    scrollbar_track = { fg = "#49494B" },                 -- Dark Grey Purple
    scrollbar_arrow = { fg = "#67677C" },                 -- Dark Grey
  },
}
