---@class UiHighlights
---Syntax highlighting and icons for SSNS UI
local UiHighlights = {}

---Setup highlight groups
function UiHighlights.setup()
  local Config = require('ssns.config')
  local hl = Config.get_ui().highlights

  -- Server type-specific highlights (by database type)
  vim.api.nvim_set_hl(0, "SsnsServerSqlServer", hl.server_sqlserver)
  vim.api.nvim_set_hl(0, "SsnsServerPostgres", hl.server_postgres)
  vim.api.nvim_set_hl(0, "SsnsServerMysql", hl.server_mysql)
  vim.api.nvim_set_hl(0, "SsnsServerSqlite", hl.server_sqlite)
  vim.api.nvim_set_hl(0, "SsnsServerBigQuery", hl.server_bigquery)
  vim.api.nvim_set_hl(0, "SsnsServer", hl.server)

  -- Object type highlights
  vim.api.nvim_set_hl(0, "SsnsDatabase", hl.database)
  vim.api.nvim_set_hl(0, "SsnsSchema", hl.schema)
  vim.api.nvim_set_hl(0, "SsnsTable", hl.table)
  vim.api.nvim_set_hl(0, "SsnsView", hl.view)
  vim.api.nvim_set_hl(0, "SsnsProcedure", hl.procedure)
  vim.api.nvim_set_hl(0, "SsnsFunction", hl["function"])
  vim.api.nvim_set_hl(0, "SsnsColumn", hl.column)
  vim.api.nvim_set_hl(0, "SsnsIndex", hl.index)
  vim.api.nvim_set_hl(0, "SsnsKey", hl.key)
  vim.api.nvim_set_hl(0, "SsnsParameter", hl.parameter)
  vim.api.nvim_set_hl(0, "SsnsSequence", hl.sequence)
  vim.api.nvim_set_hl(0, "SsnsSynonym", hl.synonym)
  vim.api.nvim_set_hl(0, "SsnsAction", hl.action)
  vim.api.nvim_set_hl(0, "SsnsGroup", hl.group)

  -- Icon highlights (for the icon characters themselves) - use default = true for optional styling
  vim.api.nvim_set_hl(0, "SsnsIcon", { link = "SpecialChar", default = true })
  vim.api.nvim_set_hl(0, "SsnsIconServer", vim.tbl_extend("force", hl.server, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconDatabase", vim.tbl_extend("force", hl.database, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconSchema", vim.tbl_extend("force", hl.schema, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconTable", vim.tbl_extend("force", hl.table, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconView", vim.tbl_extend("force", hl.view, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconProcedure", vim.tbl_extend("force", hl.procedure, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconFunction", vim.tbl_extend("force", hl["function"], { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconColumn", vim.tbl_extend("force", hl.column, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconIndex", vim.tbl_extend("force", hl.index, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconKey", vim.tbl_extend("force", hl.key, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconSequence", vim.tbl_extend("force", hl.sequence, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsIconSynonym", vim.tbl_extend("force", hl.synonym, { default = true }))

  -- Status highlights
  vim.api.nvim_set_hl(0, "SsnsStatusConnected", vim.tbl_extend("force", hl.status_connected, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsStatusDisconnected", vim.tbl_extend("force", hl.status_disconnected, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsStatusConnecting", vim.tbl_extend("force", hl.status_connecting, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsStatusError", vim.tbl_extend("force", hl.status_error, { default = true }))

  -- Tree expand/collapse indicators
  vim.api.nvim_set_hl(0, "SsnsExpanded", vim.tbl_extend("force", hl.expanded, { default = true }))
  vim.api.nvim_set_hl(0, "SsnsCollapsed", vim.tbl_extend("force", hl.collapsed, { default = true }))

  -- Semantic highlighting for query buffers
  vim.api.nvim_set_hl(0, "SsnsKeyword", hl.keyword or { fg = "#569CD6", bold = true })
  vim.api.nvim_set_hl(0, "SsnsOperator", hl.operator or { fg = "#D4D4D4" })
  vim.api.nvim_set_hl(0, "SsnsString", hl.string or { fg = "#CE9178" })
  vim.api.nvim_set_hl(0, "SsnsNumber", hl.number or { fg = "#B5CEA8" })
  vim.api.nvim_set_hl(0, "SsnsAlias", hl.alias or { fg = "#4EC9B0", italic = true })
  vim.api.nvim_set_hl(0, "SsnsUnresolved", hl.unresolved or { fg = "#808080" })
  vim.api.nvim_set_hl(0, "SsnsComment", hl.comment or { fg = "#6A9955", italic = true })
end

---Apply highlights to buffer
---@param line_map table<number, BaseDbObject>? Optional line map from tree
function UiHighlights.apply(line_map)
  local Buffer = require('ssns.ui.buffer')

  if not Buffer.exists() then
    return
  end

  local bufnr = Buffer.bufnr
  local ns = vim.api.nvim_create_namespace('ssns_highlights')

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- If no line_map provided, try to get it from tree
  if not line_map then
    local Tree = require('ssns.ui.tree')
    line_map = Tree.line_map
  end

  if not line_map then
    return
  end

  -- Apply highlights based on object types
  for line_number, obj in pairs(line_map) do
    if obj and obj.object_type then
      local hl_group = UiHighlights.get_highlight_group(obj)
      if hl_group then
        -- Highlight the entire line
        vim.api.nvim_buf_add_highlight(bufnr, ns, hl_group, line_number - 1, 0, -1)
      end
    end
  end
end

---Get highlight group for object
---@param obj BaseDbObject
---@return string?
function UiHighlights.get_highlight_group(obj)
  local object_type = obj.object_type

  -- Special handling for servers - use database-type specific colors
  if object_type == "server" then
    -- Get database type, handling cases where method might not exist
    local db_type = nil
    if obj.get_db_type then
      db_type = obj:get_db_type()
    elseif obj.adapter and obj.adapter.db_type then
      db_type = obj.adapter.db_type
    end

    if db_type == "sqlserver" then
      return "SsnsServerSqlServer"
    elseif db_type == "postgres" or db_type == "postgresql" then
      return "SsnsServerPostgres"
    elseif db_type == "mysql" then
      return "SsnsServerMysql"
    elseif db_type == "sqlite" then
      return "SsnsServerSqlite"
    elseif db_type == "bigquery" then
      return "SsnsServerBigQuery"
    else
      return "SsnsServer"  -- Default/unknown
    end
  end

  -- Special handling for object references - use the referenced object's type
  if object_type == "object_reference" and obj.referenced_object then
    object_type = obj.referenced_object.object_type
  end

  -- Standard object type mapping
  local hl_map = {
    database = "SsnsDatabase",
    schema = "SsnsSchema",
    table = "SsnsTable",
    view = "SsnsView",
    procedure = "SsnsProcedure",
    ["function"] = "SsnsFunction",
    column = "SsnsColumn",
    index = "SsnsIndex",
    key = "SsnsKey",
    parameter = "SsnsParameter",
    sequence = "SsnsSequence",
    synonym = "SsnsSynonym",
    action = "SsnsAction",
    -- Groups
    databases_group = "SsnsGroup",
    tables_group = "SsnsGroup",
    views_group = "SsnsGroup",
    procedures_group = "SsnsGroup",
    functions_group = "SsnsGroup",
    sequences_group = "SsnsGroup",
    synonyms_group = "SsnsGroup",
    schemas_group = "SsnsGroup",
    column_group = "SsnsGroup",
    index_group = "SsnsGroup",
    key_group = "SsnsGroup",
    parameter_group = "SsnsGroup",
    actions_group = "SsnsGroup",
    -- Schema nodes
    schema_view = "SsnsSchema",
  }

  return hl_map[object_type]
end

---Setup filetype detection
function UiHighlights.setup_filetype()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "ssns",
    callback = function()
      UiHighlights.setup()
      UiHighlights.apply()
    end,
  })
end

return UiHighlights
