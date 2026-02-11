-- Anderson Theme (Matrix inspired)
-- Follow the white rabbit... into the green code cascade

return {
  name = "M Anderson",
  description = "Matrix-inspired theme with cascading green shades",
  author = "User",

  colors = {
    -- Server type highlights (bright greens for different servers)
    server_sqlserver = { fg = "#00FF41", bold = true },   -- Bright Matrix green
    server_postgres = { fg = "#39FF14", bold = true },    -- Neon green
    server_mysql = { fg = "#0FFF50", bold = true },       -- Electric green
    server_sqlite = { fg = "#7FFF00", bold = true },      -- Chartreuse
    server_bigquery = { fg = "#00FF7F", bold = true },    -- Spring green
    server = { fg = "#008F11", bold = true },             -- Dark green (default)

    -- Object type highlights (varying green shades)
    database = { fg = "#00FF41" },                        -- Bright Matrix green
    schema = { fg = "#39FF14" },                          -- Neon green
    table = { fg = "#7FFF00" },                           -- Chartreuse
    temp_table = { fg = "#9ACD32", italic = true },       -- Yellow green italic (#temp, ##global)
    view = { fg = "#ADFF2F" },                            -- Yellow-green
    procedure = { fg = "#00FA9A" },                       -- Medium spring green
    ["function"] = { fg = "#00FF7F" },                    -- Spring green
    column = { fg = "#90EE90" },                          -- Light green
    index = { fg = "#98FB98" },                           -- Pale green
    key = { fg = "#00FF41", bold = true },                -- Bright Matrix green bold
    parameter = { fg = "#7CFC00", italic = true },        -- Lawn green italic
    sequence = { fg = "#32CD32" },                        -- Lime green
    synonym = { fg = "#228B22" },                         -- Forest green
    action = { fg = "#00FF00" },                          -- Pure green
    group = { fg = "#006400", bold = true },              -- Dark green bold
    server_group = { fg = "#D4A959", bold = true },

    -- Status highlights (green status indicators)
    status_connected = { fg = "#00FF41", bold = true },   -- Bright Matrix green
    status_disconnected = { fg = "#1B5E20" },             -- Very dark green
    status_connecting = { fg = "#ADFF2F" },               -- Yellow-green (warning)
    status_error = { fg = "#FF0000", bold = true },       -- Red (need contrast for errors)

    -- Tree indicators
    expanded = { fg = "#2E7D32" },                        -- Medium dark green
    collapsed = { fg = "#2E7D32" },                       -- Medium dark green

    -- Semantic highlighting (query buffers with green cascade)
    keyword = { fg = "#00FF41", bold = true },            -- Bright Matrix green
    keyword_statement = { fg = "#39FF14", bold = true },  -- Neon green (SELECT, INSERT, etc.)
    keyword_clause = { fg = "#00FF7F", bold = true },     -- Spring green (FROM, WHERE, etc.)
    keyword_function = { fg = "#ADFF2F" },                -- Yellow-green (COUNT, SUM, etc.)
    keyword_datatype = { fg = "#7FFF00" },                -- Chartreuse (INT, VARCHAR, etc.)
    keyword_operator = { fg = "#00FA9A" },                -- Medium spring green (AND, OR, etc.)
    keyword_constraint = { fg = "#32CD32" },              -- Lime green (PRIMARY, KEY, etc.)
    keyword_modifier = { fg = "#98FB98" },                -- Pale green (ASC, DESC, etc.)
    keyword_misc = { fg = "#228B22" },                    -- Forest green
    keyword_global_variable = { fg = "#00FF41" },         -- Bright Matrix green (@@ROWCOUNT, @@VERSION, etc.)
    keyword_system_procedure = { fg = "#ADFF2F" },        -- Yellow-green (sp_*, xp_*)

    -- Other semantic highlights
    operator = { fg = "#00FF7F" },                        -- Spring green
    string = { fg = "#90EE90" },                          -- Light green
    number = { fg = "#7CFC00" },                          -- Lawn green
    alias = { fg = "#00FA9A", italic = true },            -- Medium spring green italic
    unresolved = { fg = "#2E7D32" },                      -- Medium dark green
    comment = { fg = "#1B5E20", italic = true },          -- Very dark green italic

    -- UI-specific colors for floating windows
    ui_border = { fg = "#00FF41" },                       -- Bright Matrix green
    ui_title = { fg = "#39FF14", bold = true },           -- Neon green bold
    ui_selected = { fg = "#000000", bg = "#00FF41" },     -- Black on bright green
    ui_hint = { fg = "#2E7D32" },                         -- Medium dark green

    -- Result buffer highlights
    result_header = { fg = "#00FF41", bold = true },      -- Bright Matrix green
    result_border = { fg = "#1B5E20" },                   -- Very dark green
    result_null = { fg = "#2E7D32", italic = true },      -- Medium dark green italic
    result_message = { fg = "#39FF14", italic = true },   -- Neon green italic
    result_date = { fg = "#ADFF2F" },                     -- Yellow-green
    result_bool = { fg = "#00FF7F" },                     -- Spring green
    result_binary = { fg = "#228B22" },                   -- Forest green
    result_guid = { fg = "#7CFC00" },                     -- Lawn green

    -- Scrollbar
    scrollbar = { bg = "NONE" },
    scrollbar_thumb = { fg = "#00FF41" },                 -- Bright Matrix green
    scrollbar_track = { fg = "#1B5E20" },                 -- Very dark green
    scrollbar_arrow = { fg = "#2E7D32" },                 -- Medium dark green
  },
}
