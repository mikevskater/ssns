---Utility functions for formatting LSP CompletionItems
---Used by completion providers to format database objects as LSP-compliant items
---@class CompletionUtils
local Utils = {}

---LSP CompletionItemKind enumeration
---@see https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItemKind
Utils.CompletionItemKind = {
  Text = 1,
  Method = 2,
  Function = 3,
  Constructor = 4,
  Field = 5,
  Variable = 6,
  Class = 7,
  Interface = 8,
  Module = 9,
  Property = 10,
  Unit = 11,
  Value = 12,
  Enum = 13,
  Keyword = 14,
  Snippet = 15,
  Color = 16,
  File = 17,
  Reference = 18,
  Folder = 19,
  EnumMember = 20,
  Constant = 21,
  Struct = 22,
  Event = 23,
  Operator = 24,
  TypeParameter = 25,
}

---Generate sort text with priority prefix
---@param priority number Priority level (1 = highest, 9 = lowest)
---@param name string Item name
---@return string sort_text Formatted sort text (e.g., "0001_EmployeeID")
function Utils.generate_sort_text(priority, name)
  return string.format("%04d_%s", priority, name)
end

---Format markdown documentation from key-value pairs
---@param title string Documentation title
---@param items table<string, any> Key-value pairs to format
---@return string markdown Formatted markdown string
function Utils.format_markdown_docs(title, items)
  local lines = { "### " .. title, "" }

  for key, value in pairs(items) do
    if value ~= nil and value ~= "" then
      table.insert(lines, string.format("**%s**: %s", key, tostring(value)))
    end
  end

  return table.concat(lines, "\n")
end

---Format a table/view as an LSP CompletionItem
---@param table_obj table Table object { name: string, schema: string, type?: string }
---@param opts table? Options { show_schema: boolean?, omit_schema: boolean?, adapter: BaseAdapter? }
---@return table completion_item LSP CompletionItem
function Utils.format_table(table_obj, opts)
  opts = opts or {}
  local show_schema = opts.show_schema ~= false -- Default true
  local omit_schema = opts.omit_schema or false -- Context override: if true, never include schema in insertText
  local adapter = opts.adapter -- Optional: used for proper identifier quoting

  local label = table_obj.name or table_obj.table_name
  local schema = table_obj.schema or table_obj.schema_name
  local obj_type = table_obj.type or "TABLE"

  -- Detail shows schema.table and type
  local detail
  if show_schema and schema then
    detail = string.format("%s.%s (%s)", schema, label, obj_type)
  else
    detail = string.format("%s (%s)", label, obj_type)
  end

  -- Sort priority: tables = 1, views = 2, others = 3
  local priority = 2
  if obj_type == "TABLE" then
    priority = 1
  elseif obj_type == "VIEW" then
    priority = 2
  else
    priority = 3
  end

  -- Build insertText with schema if configured
  -- Use adapter quoting if available (only quotes when needed)
  local insertText
  if adapter then
    local quoted_label = adapter:quote_identifier(label)
    if not omit_schema and show_schema and schema and schema ~= "" then
      local quoted_schema = adapter:quote_identifier(schema)
      insertText = quoted_schema .. "." .. quoted_label
    else
      insertText = quoted_label
    end
  else
    -- Fallback: no quoting
    insertText = label
    if not omit_schema and show_schema and schema and schema ~= "" then
      insertText = schema .. "." .. label
    end
  end

  return {
    label = label,
    kind = Utils.CompletionItemKind.Class,
    detail = detail,
    documentation = nil, -- Can be loaded lazily via resolve()
    insertText = insertText,
    filterText = label,
    sortText = Utils.generate_sort_text(priority, label),
    data = {
      type = "table",
      schema = schema,
      name = label,
      object_type = obj_type,
    }
  }
end

---Format a column as an LSP CompletionItem
---@param column_obj table Column object { name: string, data_type: string, nullable?: boolean, is_primary_key?: boolean, is_foreign_key?: boolean, default_value?: string, ordinal_position?: number }
---@param opts table? Options { show_type: boolean?, show_nullable: boolean?, adapter: BaseAdapter? }
---@return table completion_item LSP CompletionItem
function Utils.format_column(column_obj, opts)
  opts = opts or {}
  local show_type = opts.show_type ~= false -- Default true
  local show_nullable = opts.show_nullable ~= false -- Default true
  local adapter = opts.adapter -- Optional: used for proper identifier quoting

  local name = column_obj.name or column_obj.column_name
  local data_type = column_obj.data_type or column_obj.type or "unknown"
  local nullable = column_obj.nullable or column_obj.is_nullable
  local is_pk = column_obj.is_primary_key or column_obj.is_pk
  local is_fk = column_obj.is_foreign_key or column_obj.is_fk
  local is_identity = column_obj.is_identity
  local is_computed = column_obj.is_computed
  local default_value = column_obj.default_value or column_obj.column_default or column_obj.default
  local ordinal = column_obj.ordinal_position or 999

  -- Build detail string (type + nullable + constraints)
  local detail_parts = {}

  if show_type then
    table.insert(detail_parts, data_type)
  end

  if show_nullable then
    if nullable == false or nullable == "NO" then
      table.insert(detail_parts, "NOT NULL")
    end
  end

  if is_pk then
    table.insert(detail_parts, "PK")
  end

  if is_fk then
    table.insert(detail_parts, "FK")
  end

  if is_identity then
    table.insert(detail_parts, "[IDENTITY]")
  end

  if is_computed then
    table.insert(detail_parts, "[COMPUTED]")
  end

  local detail = table.concat(detail_parts, " ")

  -- Build documentation (markdown)
  local doc_items = {
    Type = string.format("`%s`", data_type),
  }

  if nullable ~= nil then
    doc_items.Nullable = (nullable == true or nullable == "YES") and "YES" or "NO"
  end

  if is_pk then
    doc_items["Primary Key"] = "✓"
  end

  if is_fk then
    doc_items["Foreign Key"] = "✓"
  end

  if default_value then
    doc_items.Default = string.format("`%s`", default_value)
  end

  -- Build warnings for identity and computed columns
  local warnings = {}
  if is_identity then
    table.insert(warnings, "⚠️ **IDENTITY** - Value is auto-generated by the database")
  end

  if is_computed then
    table.insert(warnings, "⚠️ **COMPUTED** - Cannot insert/update directly")
  end

  local doc_value = Utils.format_markdown_docs(name, doc_items)
  if #warnings > 0 then
    doc_value = doc_value .. "\n\n" .. table.concat(warnings, "\n\n")
  end

  local documentation = {
    kind = "markdown",
    value = doc_value
  }

  -- Sort priority: PK columns first (1), then FK (2), then regular (3)
  local priority = 3
  if is_pk then
    priority = 1
  elseif is_fk then
    priority = 2
  end

  -- Use adapter quoting if available (only quotes when needed)
  local insertText = adapter and adapter:quote_identifier(name) or name

  return {
    label = name,
    kind = Utils.CompletionItemKind.Field,
    detail = detail,
    documentation = documentation,
    insertText = insertText,
    filterText = name,
    sortText = Utils.generate_sort_text(priority, string.format("%04d_%s", ordinal, name)),
    data = {
      type = "column",
      name = name,
      data_type = data_type,
      is_primary_key = is_pk,
      is_foreign_key = is_fk,
    }
  }
end

---Format a stored procedure/function as an LSP CompletionItem
---@param proc_obj table Procedure object { name: string, type?: string, return_type?: string, schema?: string }
---@param opts table? Options { show_schema: boolean?, omit_schema: boolean?, priority: number?, adapter: BaseAdapter? }
---@return table completion_item LSP CompletionItem
function Utils.format_procedure(proc_obj, opts)
  opts = opts or {}
  local show_schema = opts.show_schema ~= false -- Default true
  local omit_schema = opts.omit_schema or false -- Context override: if true, never include schema in insertText
  local adapter = opts.adapter -- Optional: used for proper identifier quoting

  local name = proc_obj.name or proc_obj.procedure_name or proc_obj.function_name
  local schema = proc_obj.schema or proc_obj.schema_name
  local obj_type = proc_obj.type or proc_obj.object_type or "PROCEDURE"
  local return_type = proc_obj.return_type

  -- Detail shows schema.proc (TYPE) or schema.func → return_type
  local detail
  if show_schema and schema then
    if return_type and obj_type == "FUNCTION" then
      detail = string.format("%s.%s → %s", schema, name, return_type)
    else
      detail = string.format("%s.%s (%s)", schema, name, obj_type)
    end
  else
    if return_type and obj_type == "FUNCTION" then
      detail = string.format("%s → %s", name, return_type)
    else
      detail = string.format("%s (%s)", name, obj_type)
    end
  end

  -- Build documentation
  local doc_items = {
    Type = obj_type,
  }

  if return_type then
    doc_items["Return Type"] = string.format("`%s`", return_type)
  end

  if schema then
    doc_items.Schema = schema
  end

  local documentation = {
    kind = "markdown",
    value = Utils.format_markdown_docs(name, doc_items)
  }

  -- Sort priority: procedures/functions = 2 (can be overridden via opts)
  local priority = opts.priority or 2

  -- Build insertText with schema if configured
  -- Use adapter quoting if available (only quotes when needed)
  local insertText
  if adapter then
    local quoted_name = adapter:quote_identifier(name)
    if not omit_schema and show_schema and schema and schema ~= "" then
      local quoted_schema = adapter:quote_identifier(schema)
      insertText = quoted_schema .. "." .. quoted_name
    else
      insertText = quoted_name
    end
  else
    -- Fallback: no quoting
    insertText = name
    if not omit_schema and show_schema and schema and schema ~= "" then
      insertText = schema .. "." .. name
    end
  end

  -- Generate snippet with parameters if requested
  local insertTextFormat = nil  -- Default: plain text
  if opts.with_params then
    insertText = Utils.generate_parameter_snippet(proc_obj, schema, name)
    insertTextFormat = 2  -- LSP snippet format
  end

  return {
    label = name,
    kind = Utils.CompletionItemKind.Function,
    detail = detail,
    documentation = documentation,
    insertText = insertText,
    insertTextFormat = insertTextFormat,
    filterText = name,
    sortText = Utils.generate_sort_text(priority, name),
    data = {
      type = proc_obj.object_type == "procedure" and "procedure" or "function",
      schema = schema,
      name = name,
    }
  }
end

---Format a SQL keyword as an LSP CompletionItem
---@param keyword string The SQL keyword (e.g., "SELECT", "JOIN")
---@param opts table? Options { priority: number? }
---@return table completion_item LSP CompletionItem
function Utils.format_keyword(keyword, opts)
  opts = opts or {}
  local priority = opts.priority or 9 -- Keywords have lowest priority by default

  return {
    label = keyword,
    kind = Utils.CompletionItemKind.Keyword,
    detail = "SQL Keyword",
    documentation = nil,
    insertText = keyword,
    filterText = keyword,
    sortText = Utils.generate_sort_text(priority, keyword),
    data = {
      type = "keyword",
    }
  }
end

---Format a database as an LSP CompletionItem
---@param db_obj table Database object { name: string, server?: string }
---@param opts table? Options
---@return table completion_item LSP CompletionItem
function Utils.format_database(db_obj, opts)
  opts = opts or {}

  local name = db_obj.name or db_obj.db_name or db_obj.database_name
  local server = db_obj.server or db_obj.server_name

  local detail = server and string.format("Database on %s", server) or "Database"

  return {
    label = name,
    kind = Utils.CompletionItemKind.Folder,
    detail = detail,
    documentation = nil,
    insertText = name,
    filterText = name,
    sortText = Utils.generate_sort_text(1, name),
    data = {
      type = "database",
      name = name,
      server = server,
    }
  }
end

---Format a schema as an LSP CompletionItem
---@param schema_obj table Schema object { name: string, database?: string }
---@param opts table? Options
---@return table completion_item LSP CompletionItem
function Utils.format_schema(schema_obj, opts)
  opts = opts or {}

  local name = schema_obj.name or schema_obj.schema_name
  local database = schema_obj.database or schema_obj.database_name

  local detail = database and string.format("Schema in %s", database) or "Schema"

  return {
    label = name,
    kind = Utils.CompletionItemKind.Module,
    detail = detail,
    documentation = nil,
    insertText = name,
    filterText = name,
    sortText = Utils.generate_sort_text(1, name),
    data = {
      type = "schema",
      name = name,
      database = database,
    }
  }
end

---Format a parameter as an LSP CompletionItem
---@param param_obj table Parameter object { name: string, data_type: string, is_output?: boolean, default_value?: string }
---@param opts table? Options
---@return table completion_item LSP CompletionItem
function Utils.format_parameter(param_obj, opts)
  opts = opts or {}

  local name = param_obj.name or param_obj.parameter_name
  local data_type = param_obj.data_type or param_obj.type or "unknown"
  local is_output = param_obj.is_output or param_obj.is_out
  local default_value = param_obj.default_value

  -- Detail shows type and OUTPUT if applicable
  local detail_parts = { data_type }
  if is_output then
    table.insert(detail_parts, "OUTPUT")
  end
  local detail = table.concat(detail_parts, " ")

  -- Documentation
  local doc_items = {
    Type = string.format("`%s`", data_type),
    Mode = is_output and "OUTPUT" or "INPUT",
  }

  if default_value then
    doc_items.Default = string.format("`%s`", default_value)
  end

  local documentation = {
    kind = "markdown",
    value = Utils.format_markdown_docs(name, doc_items)
  }

  return {
    label = name,
    kind = Utils.CompletionItemKind.Variable,
    detail = detail,
    documentation = documentation,
    insertText = string.format("%s = ", name), -- Auto-add = for parameter assignment
    filterText = name,
    sortText = Utils.generate_sort_text(2, name),
    data = {
      type = "parameter",
      name = name,
      data_type = data_type,
      is_output = is_output,
    }
  }
end

--- Generate parameter snippet for procedure/function
---@param proc_or_func ProcedureClass|FunctionClass The procedure or function object
---@param schema string? Schema name
---@param name string The procedure/function name
---@return string insertText The snippet-formatted insertText
function Utils.generate_parameter_snippet(proc_or_func, schema, name)
  -- Build base name with schema
  local base = name
  if schema and schema ~= "" then
    base = schema .. "." .. name
  end

  -- Get parameters (lazy-loads if needed)
  local params = proc_or_func:get_parameters()

  -- If no parameters or failed to load, return simple insertText
  if not params or #params == 0 then
    return base
  end

  -- Filter out OUTPUT-only parameters (include IN and INOUT)
  local input_params = {}
  for _, param in ipairs(params) do
    local direction = param.direction or param.mode or "IN"
    if direction ~= "OUT" then
      table.insert(input_params, param)
    end
  end

  -- If no input parameters, return simple insertText
  if #input_params == 0 then
    return base
  end

  -- Build snippet with placeholders
  local placeholder_parts = {}
  for i, param in ipairs(input_params) do
    local param_name = param.parameter_name or param.name

    -- Build placeholder text
    local placeholder
    if param.has_default and param.default_value then
      -- Parameter has default: show as "@Name = default"
      placeholder = string.format("%s = %s", param_name, param.default_value)
    else
      -- No default: just show parameter name
      placeholder = param_name
    end

    -- Create LSP snippet placeholder: ${1:@EmployeeId}
    table.insert(placeholder_parts, string.format("${%d:%s}", i, placeholder))
  end

  -- Combine: dbo.sp_Name(${1:@Param1}, ${2:@Param2 = 1})
  return base .. "(" .. table.concat(placeholder_parts, ", ") .. ")"
end

---Format a view as an LSP CompletionItem
---@param view_obj table View object { name: string, schema: string, view_name?: string, schema_name?: string }
---@param opts table? Options { show_schema: boolean?, omit_schema: boolean?, adapter: BaseAdapter? }
---@return table completion_item LSP CompletionItem
function Utils.format_view(view_obj, opts)
  opts = opts or {}
  local show_schema = opts.show_schema ~= false -- Default true
  local omit_schema = opts.omit_schema or false -- Context override: if true, never include schema in insertText
  local adapter = opts.adapter -- Optional: used for proper identifier quoting

  local label = view_obj.name or view_obj.view_name
  local schema = view_obj.schema or view_obj.schema_name

  -- Detail shows schema.view and type
  local detail
  if show_schema and schema then
    detail = string.format("%s.%s (VIEW)", schema, label)
  else
    detail = string.format("%s (VIEW)", label)
  end

  -- Build documentation (markdown)
  local doc_items = {
    Type = "VIEW",
  }

  if schema then
    doc_items.Schema = schema
  end

  local documentation = {
    kind = "markdown",
    value = Utils.format_markdown_docs(label, doc_items)
  }

  -- Sort priority: views = 2 (after tables)
  local priority = 2

  -- Build insertText with schema if configured
  -- Use adapter quoting if available (only quotes when needed)
  local insertText
  if adapter then
    local quoted_label = adapter:quote_identifier(label)
    if not omit_schema and show_schema and schema and schema ~= "" then
      local quoted_schema = adapter:quote_identifier(schema)
      insertText = quoted_schema .. "." .. quoted_label
    else
      insertText = quoted_label
    end
  else
    -- Fallback: no quoting
    insertText = label
    if not omit_schema and show_schema and schema and schema ~= "" then
      insertText = schema .. "." .. label
    end
  end

  return {
    label = label,
    kind = Utils.CompletionItemKind.Class,
    detail = detail,
    documentation = documentation,
    insertText = insertText,
    filterText = label,
    sortText = Utils.generate_sort_text(priority, label),
    data = {
      type = "view",
      schema = schema,
      name = label,
    }
  }
end

---Format a synonym as an LSP CompletionItem
---@param synonym_obj table Synonym object { name: string, schema: string, synonym_name?: string, schema_name?: string, base_object_name?: string }
---@param opts table? Options { show_schema: boolean?, omit_schema: boolean?, adapter: BaseAdapter? }
---@return table completion_item LSP CompletionItem
function Utils.format_synonym(synonym_obj, opts)
  opts = opts or {}
  local show_schema = opts.show_schema ~= false -- Default true
  local omit_schema = opts.omit_schema or false -- Context override: if true, never include schema in insertText
  local adapter = opts.adapter -- Optional: used for proper identifier quoting

  local label = synonym_obj.name or synonym_obj.synonym_name
  local schema = synonym_obj.schema or synonym_obj.schema_name
  local base_object = synonym_obj.base_object_name

  -- Detail shows schema.synonym and target
  local detail
  if show_schema and schema then
    if base_object then
      detail = string.format("%s.%s → %s", schema, label, base_object)
    else
      detail = string.format("%s.%s (SYNONYM)", schema, label)
    end
  else
    if base_object then
      detail = string.format("%s → %s", label, base_object)
    else
      detail = string.format("%s (SYNONYM)", label)
    end
  end

  -- Build documentation (markdown)
  local doc_items = {
    Type = "SYNONYM",
  }

  if schema then
    doc_items.Schema = schema
  end

  if base_object then
    doc_items.Target = base_object
  end

  local documentation = {
    kind = "markdown",
    value = Utils.format_markdown_docs(label, doc_items)
  }

  -- Sort priority: synonyms = 3 (after tables and views)
  local priority = 3

  -- Build insertText with schema if configured
  -- Use adapter quoting if available (only quotes when needed)
  local insertText
  if adapter then
    local quoted_label = adapter:quote_identifier(label)
    if not omit_schema and show_schema and schema and schema ~= "" then
      local quoted_schema = adapter:quote_identifier(schema)
      insertText = quoted_schema .. "." .. quoted_label
    else
      insertText = quoted_label
    end
  else
    -- Fallback: no quoting
    insertText = label
    if not omit_schema and show_schema and schema and schema ~= "" then
      insertText = schema .. "." .. label
    end
  end

  return {
    label = label,
    kind = Utils.CompletionItemKind.Reference,
    detail = detail,
    documentation = documentation,
    insertText = insertText,
    filterText = label,
    sortText = Utils.generate_sort_text(priority, label),
    data = {
      type = "synonym",
      schema = schema,
      name = label,
      target = base_object,
    }
  }
end

---Format a SQL Server built-in function as an LSP CompletionItem
---@param func_obj table Function object { name: string, signature: string, description: string, category: string, returns?: string }
---@param opts table? Options { priority: number? }
---@return table completion_item LSP CompletionItem
function Utils.format_builtin_function(func_obj, opts)
  opts = opts or {}
  local priority = opts.priority or 7 -- Built-in functions priority (before keywords, after db objects)

  local name = func_obj.name
  local signature = func_obj.signature or name .. "()"
  local description = func_obj.description or "SQL Server built-in function"
  local category = func_obj.category or "function"
  local returns = func_obj.returns

  -- Build detail string
  local detail = string.format("%s (%s)", signature, category)

  -- Build documentation (markdown)
  local doc_lines = {
    "### " .. name,
    "",
    description,
    "",
    "**Signature:**",
    "```sql",
    signature,
    "```",
  }

  if returns then
    table.insert(doc_lines, "")
    table.insert(doc_lines, string.format("**Returns:** `%s`", returns))
  end

  table.insert(doc_lines, "")
  table.insert(doc_lines, string.format("**Category:** %s", category))

  local documentation = {
    kind = "markdown",
    value = table.concat(doc_lines, "\n")
  }

  -- Generate insert text based on function type
  -- System variables (@@...) don't need parentheses
  -- Regular functions get parentheses and placeholder
  local insertText = name
  local insertTextFormat = nil

  if name:match("^@@") then
    -- System variables: @@ROWCOUNT, @@ERROR, etc.
    insertText = name
  elseif name:match("%(%s*%)$") then
    -- Already has empty parens in name
    insertText = name
  elseif name == "CURRENT_TIMESTAMP" or name == "CURRENT_USER" or name == "SESSION_USER" or name == "SYSTEM_USER" or name == "CURRENT_DATE" then
    -- ANSI standard niladic functions (no parens)
    insertText = name
  else
    -- Regular functions: add () and placeholder
    insertText = name .. "($0)"
    insertTextFormat = 2 -- LSP snippet format
  end

  return {
    label = name,
    kind = Utils.CompletionItemKind.Function,
    detail = detail,
    documentation = documentation,
    insertText = insertText,
    insertTextFormat = insertTextFormat,
    filterText = name,
    sortText = Utils.generate_sort_text(priority, name),
    data = {
      type = "builtin_function",
      name = name,
      category = category,
    }
  }
end

return Utils
