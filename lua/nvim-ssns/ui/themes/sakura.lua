-- Japanese cherry blossom theme for SSNS UI
-- Kawaii pink paradise

return {
  name = "Sakura",
  description = "Japanese cherry blossom theme for SSNS UI",
  author = "User",

  colors = {
    -- Server type highlights (pink and cute pastels)
    server_sqlserver = { fg = "#FF69B4", bold = true },   -- Hot pink
    server_postgres = { fg = "#FFB6C1", bold = true },    -- Light pink
    server_mysql = { fg = "#FF1493", bold = true },       -- Deep pink
    server_sqlite = { fg = "#FFC0CB", bold = true },      -- Classic pink
    server_bigquery = { fg = "#FF85C0", bold = true },    -- Rose pink
    server = { fg = "#DB7093", bold = true },             -- Pale violet red (default)

    -- Object type highlights (soft pastel palette)
    database = { fg = "#FF69B4" },                        -- Hot pink
    schema = { fg = "#FFB6D9" },                          -- Baby pink
    table = { fg = "#FF1493" },                           -- Deep pink
    temp_table = { fg = "#FF69D2", italic = true },       -- Medium pink italic (#temp, ##global)
    view = { fg = "#FFDDF4" },                            -- Pale pink
    procedure = { fg = "#FF85C0" },                       -- Rose pink
    ["function"] = { fg = "#FFB3D9" },                    -- Cotton candy pink
    column = { fg = "#FFC0CB" },                          -- Classic pink
    index = { fg = "#FFCCFF" },                           -- Lavender pink
    key = { fg = "#FF1493", bold = true },                -- Deep pink bold
    parameter = { fg = "#FFB6D9", italic = true },        -- Baby pink italic
    sequence = { fg = "#FF99CC" },                        -- Bubblegum pink
    synonym = { fg = "#C9647C" },                         -- Dusty rose
    action = { fg = "#FF6EC7" },                          -- Fuchsia pink
    group = { fg = "#B85C7A", bold = true },              -- Mauve bold
    server_group = { fg = "#D4A373", bold = true },

    -- Status highlights (cute status colors)
    status_connected = { fg = "#FF69B4", bold = true },   -- Hot pink (happy!)
    status_disconnected = { fg = "#8B4665" },             -- Dark pink
    status_connecting = { fg = "#FFD700" },               -- Gold (sparkle!)
    status_error = { fg = "#FF6B6B", bold = true },       -- Soft red (not too harsh)

    -- Tree indicators
    expanded = { fg = "#DB7093" },                        -- Pale violet red
    collapsed = { fg = "#DB7093" },                       -- Pale violet red

    -- Semantic highlighting (kawaii query colors)
    keyword = { fg = "#FF69B4", bold = true },            -- Hot pink
    keyword_statement = { fg = "#FF1493", bold = true },  -- Deep pink (SELECT, INSERT, etc.)
    keyword_clause = { fg = "#FF85C0", bold = true },     -- Rose pink (FROM, WHERE, etc.)
    keyword_function = { fg = "#FFB3D9" },                -- Cotton candy (COUNT, SUM, etc.)
    keyword_datatype = { fg = "#FFCCFF" },                -- Lavender pink (INT, VARCHAR, etc.)
    keyword_operator = { fg = "#FF99CC" },                -- Bubblegum (AND, OR, etc.)
    keyword_constraint = { fg = "#FF6EC7" },              -- Fuchsia (PRIMARY, KEY, etc.)
    keyword_modifier = { fg = "#FFB6D9" },                -- Baby pink (ASC, DESC, etc.)
    keyword_misc = { fg = "#C9647C" },                    -- Dusty rose
    keyword_global_variable = { fg = "#FF1493" },         -- Deep pink (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#FFB3D9" },        -- Cotton candy pink (sp_*, xp_*)

    -- Other semantic highlights
    operator = { fg = "#FF85C0" },                        -- Rose pink
    string = { fg = "#FFB3D9" },                          -- Cotton candy pink
    number = { fg = "#FF99CC" },                          -- Bubblegum pink
    alias = { fg = "#FF6EC7", italic = true },            -- Fuchsia italic
    unresolved = { fg = "#C9647C" },                      -- Dusty rose
    comment = { fg = "#8B4665", italic = true },          -- Dark pink italic

    -- UI-specific colors for floating windows
    ui_border = { fg = "#FF69B4" },                       -- Hot pink
    ui_title = { fg = "#FF1493", bold = true },           -- Deep pink bold
    ui_selected = { fg = "#FFFFFF", bg = "#FF69B4" },     -- White on hot pink
    ui_hint = { fg = "#FFB6D9" },                         -- Baby pink

    -- Result buffer highlights
    result_header = { fg = "#FF69B4", bold = true },      -- Hot pink
    result_border = { fg = "#8B4665" },                   -- Dark pink
    result_null = { fg = "#C9647C", italic = true },      -- Dusty rose italic
    result_message = { fg = "#FF85C0", italic = true },   -- Rose pink italic
    result_date = { fg = "#FFD700" },                     -- Gold
    result_bool = { fg = "#FFB3D9" },                     -- Cotton candy pink
    result_binary = { fg = "#8B4665" },                   -- Dark pink
    result_guid = { fg = "#FF6EC7" },                     -- Fuchsia pink

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#FF69B4" },                 -- Hot pink
    scrollbar_track = { fg = "#8B4665" },                 -- Dark pink
    scrollbar_arrow = { fg = "#DB7093" },                 -- Pale violet red
  },
}
