local BaseDbObject = require('ssns.classes.base')

---@class SynonymClass : BaseDbObject
---@field synonym_name string The synonym name
---@field schema_name string The schema name
---@field base_object_name string The base object name (what the synonym points to)
---@field base_object_type string? The type of base object (TABLE, VIEW, PROCEDURE, FUNCTION, SYNONYM)
---@field parent SchemaClass The parent schema object
---@field resolved_object any? The resolved base object (cached)
---@field resolution_loaded boolean Whether resolution has been attempted
local SynonymClass = setmetatable({}, { __index = BaseDbObject })
SynonymClass.__index = SynonymClass

---Create a new Synonym instance
---@param opts {name: string, schema_name: string, base_object_name: string, base_object_type: string?, parent: SchemaClass}
---@return SynonymClass
function SynonymClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), SynonymClass)

  self.object_type = "synonym"
  self.synonym_name = opts.name
  self.schema_name = opts.schema_name
  self.base_object_name = opts.base_object_name
  self.base_object_type = opts.base_object_type
  self.resolved_object = nil
  self.resolution_loaded = false

  return self
end

---Get display name with schema prefix (e.g., [dbo].[SynonymName])
---@return string display_name
function SynonymClass:get_display_name()
  if self.schema_name then
    return string.format("[%s].[%s]", self.schema_name, self.synonym_name)
  end
  return self.synonym_name
end

---Get the base object type label for display
---@return string type_label
function SynonymClass:get_base_type_label()
  if not self.base_object_type then
    return "Unknown"
  end

  local type_map = {
    TABLE = "Table",
    VIEW = "View",
    PROCEDURE = "Procedure",
    FUNCTION = "Function",
    SYNONYM = "Synonym"
  }

  return type_map[self.base_object_type] or self.base_object_type
end

---Parse base_object_name into parts (server, database, schema, object)
---@return table parts {server: string?, database: string?, schema: string?, object: string}
function SynonymClass:parse_base_object_name()
  local name = self.base_object_name
  local parts = {}

  -- Remove brackets and split by dots
  local segments = {}
  for segment in name:gmatch("[^%.]+") do
    local clean = segment:gsub("^%[", ""):gsub("%]$", "")
    table.insert(segments, clean)
  end

  -- Parse based on number of parts (right to left, like PARSENAME)
  if #segments == 1 then
    -- Just object name
    parts.object = segments[1]
    parts.schema = self.schema_name  -- Default to synonym's schema
  elseif #segments == 2 then
    -- schema.object
    parts.schema = segments[1]
    parts.object = segments[2]
  elseif #segments == 3 then
    -- database.schema.object
    parts.database = segments[1]
    parts.schema = segments[2]
    parts.object = segments[3]
  elseif #segments == 4 then
    -- server.database.schema.object
    parts.server = segments[1]
    parts.database = segments[2]
    parts.schema = segments[3]
    parts.object = segments[4]
  end

  return parts
end

---Check if this synonym references an external database or server
---@return boolean is_external True if linked server reference (cross-database on same server is resolvable)
---@return string? reference_type "linked-server", or nil (cross-database on same server returns false)
function SynonymClass:is_external_reference()
  local parts = self:parse_base_object_name()

  if parts.server then
    -- Linked server reference - truly external, cannot resolve
    return true, "linked-server"
  end

  -- Cross-database on same server is resolvable, not considered external
  return false, nil
end

---Resolve synonym to its base object
---Handles synonym chains (synonym → synonym → table)
---Supports cross-database resolution on the same server (loads target database if needed)
---@return any? base_object The resolved base object (TableClass, ViewClass, ProcedureClass, etc.)
---@return string? error_message Error message if resolution failed
function SynonymClass:resolve()
  if self.resolution_loaded and self.resolved_object then
    return self.resolved_object, nil
  end

  -- Check if this is a linked server synonym (truly external)
  local is_external, ref_type = self:is_external_reference()
  if is_external then
    self.base_object_type = "EXTERNAL"
    self.resolved_object = nil
    self.resolution_loaded = true
    return nil, string.format("%s reference (cannot load into tree)", ref_type:gsub("-", " "):gsub("^%l", string.upper))
  end

  -- Track visited synonyms to detect circular references
  local visited = {}
  local current = self
  local max_depth = 10  -- Prevent infinite loops

  while current and current.object_type == "synonym" do
    -- Check for circular reference
    if visited[current:get_full_path()] then
      return nil, string.format("Circular synonym reference detected: %s", current:get_full_path())
    end

    visited[current:get_full_path()] = true

    -- Safety check for max depth
    if vim.tbl_count(visited) > max_depth then
      return nil, string.format("Synonym chain too deep (> %d levels)", max_depth)
    end

    -- Parse base object name
    local parts = current:parse_base_object_name()

    if not parts.object then
      return nil, string.format("Could not parse base object name: %s", current.base_object_name)
    end

    -- Get target database (may be different from current synonym's database for cross-DB refs)
    local database

    if parts.database then
      -- Cross-database reference - need to find target database on same server
      local server = current:get_server()
      if not server then
        return nil, "Could not find parent server"
      end

      -- Ensure server is loaded
      if not server.is_loaded then
        server:load()
      end

      -- Find target database using accessor
      local databases = server:get_databases()
      for _, db in ipairs(databases) do
        if db.db_name == parts.database then
          database = db
          break
        end
      end

      if not database then
        return nil, string.format("Target database not found: %s (ensure server is loaded)", parts.database)
      end

      -- Ensure target database is loaded
      if not database.is_loaded then
        database:load()
      end
    else
      -- Same database reference - get parent database (handle both flat and schema-based structures)
      if current.parent and current.parent.object_type == "database" then
        -- Flat structure: synonym → database
        database = current.parent
      elseif current.parent and current.parent.parent then
        -- Schema-based structure: synonym → schema → database
        database = current.parent.parent
      end

      if not database then
        return nil, "Could not find parent database"
      end
    end

    -- Get objects using database accessor methods
    local tables = database:get_tables()
    local views = database:get_views()
    local procedures = database:get_procedures()
    local functions = database:get_functions()
    local synonyms = database:get_synonyms()

    -- Try to find base object matching both schema and name
    -- Check tables first
    for _, table in ipairs(tables) do
      if table.schema_name == parts.schema and table.table_name == parts.object then
        self.resolved_object = table
        self.base_object_type = "TABLE"
        self.resolution_loaded = true
        return table, nil
      end
    end

    -- Check views
    for _, view in ipairs(views) do
      if view.schema_name == parts.schema and view.view_name == parts.object then
        self.resolved_object = view
        self.base_object_type = "VIEW"
        self.resolution_loaded = true
        return view, nil
      end
    end

    -- Check procedures
    for _, proc in ipairs(procedures) do
      if proc.schema_name == parts.schema and proc.procedure_name == parts.object then
        self.resolved_object = proc
        self.base_object_type = "PROCEDURE"
        self.resolution_loaded = true
        return proc, nil
      end
    end

    -- Check functions
    for _, func in ipairs(functions) do
      if func.schema_name == parts.schema and func.function_name == parts.object then
        self.resolved_object = func
        self.base_object_type = "FUNCTION"
        self.resolution_loaded = true
        return func, nil
      end
    end

    -- Check other synonyms (for chaining)
    for _, syn in ipairs(synonyms) do
      if syn.schema_name == parts.schema and syn.synonym_name == parts.object and syn ~= current then
        -- Found another synonym - continue chain
        current = syn
        goto continue
      end
    end

    ::continue::  -- Label must be before any returns in the while loop

    -- Base object not found (only reached if no synonym match found)
    if current.object_type == "synonym" then
      return nil, string.format("Base object not found: %s.%s", parts.schema, parts.object)
    end
  end  -- End of while loop

  -- If we get here, current is the final base object (not a synonym)
  self.resolved_object = current
  self.resolution_loaded = true
  return current, nil
end

---Load synonym children (shows the base object's structure)
---@return boolean success
function SynonymClass:load()
  if self.is_loaded then
    return true
  end

  -- Create action nodes and show what this synonym points to
  self:create_action_nodes()

  self.is_loaded = true
  return true
end

---Create action nodes for UI
function SynonymClass:create_action_nodes()
  self:clear_children()

  -- Try to resolve synonym to base object (handles cross-database on same server)
  local base_object, error_msg = self:resolve()

  -- Check if this is a linked server reference (truly external)
  local is_external, ref_type = self:is_external_reference()
  local parts = self:parse_base_object_name()

  if error_msg then
    -- Show error as a child node
    local error_node = BaseDbObject.new({
      name = string.format("⚠ %s", error_msg),
      parent = self,
    })
    error_node.object_type = "error"
    error_node.is_loaded = true
    table.insert(self.children, error_node)
    return
  end

  if not base_object then
    local not_found_node = BaseDbObject.new({
      name = string.format("⚠ Base object not found: %s", self.base_object_name),
      parent = self,
    })
    not_found_node.object_type = "error"
    not_found_node.is_loaded = true
    table.insert(self.children, not_found_node)
    return
  end

  -- Add info node showing what this synonym points to
  local type_label = self:get_base_type_label()
  local ref_info = ""

  -- Add cross-database indicator if applicable
  if parts.database then
    ref_info = " [Cross-DB]"
  elseif is_external then
    ref_info = " [Linked Server]"
  end

  local info_node = BaseDbObject.new({
    name = string.format("→ %s (%s%s)", self.base_object_name, type_label, ref_info),
    parent = self,
  })
  info_node.object_type = "info"
  info_node.is_loaded = true
  table.insert(self.children, info_node)

  -- Add GO-TO action (navigate to base object in tree)
  if base_object and not is_external then
    local goto_action = BaseDbObject.new({
      name = "GO-TO",
      parent = self,
    })
    goto_action.object_type = "action"
    goto_action.action_type = "goto"
    goto_action.is_loaded = true
    table.insert(self.children, goto_action)
  end

  -- If base object is a table or view, show columns group
  if base_object.object_type == "table" or base_object.object_type == "view" then
    -- Add SELECT action
    local select_action = BaseDbObject.new({
      name = "SELECT",
      parent = self,
    })
    select_action.object_type = "action"
    select_action.action_type = "select"
    select_action.is_loaded = true
    table.insert(self.children, select_action)

    -- Add Columns group (lazy loaded from base object)
    local columns_group = BaseDbObject.new({
      name = "Columns",
      parent = self,
    })
    columns_group.object_type = "column_group"

    -- Override load for columns group to get columns from base object
    columns_group.load = function(group)
      if group.is_loaded then
        return true
      end

      group:clear_children()

      -- Get columns from base object
      local columns = base_object:get_columns()
      if columns then
        for _, col in ipairs(columns) do
          -- Create a copy of column with this synonym as parent
          local col_copy = BaseDbObject.new({
            name = col.column_name,
            parent = group,
          })
          col_copy.object_type = "column"
          col_copy.column_name = col.column_name
          col_copy.data_type = col.data_type
          col_copy.is_nullable = col.is_nullable
          col_copy.is_primary_key = col.is_primary_key
          col_copy.is_foreign_key = col.is_foreign_key
          col_copy.ordinal_position = col.ordinal_position
          col_copy.is_loaded = true
          table.insert(group.children, col_copy)
        end
      end

      group.is_loaded = true
      return true
    end
    table.insert(self.children, columns_group)

    -- Add Indexes group (lazy loaded from base object)
    if base_object.object_type == "table" then
      local indexes_group = BaseDbObject.new({
        name = "Indexes",
        parent = self,
      })
      indexes_group.object_type = "index_group"

      indexes_group.load = function(group)
        if group.is_loaded then
          return true
        end

        group:clear_children()

        local indexes = base_object:get_indexes()
        if indexes then
          for _, idx in ipairs(indexes) do
            local idx_copy = BaseDbObject.new({
              name = idx.index_name,
              parent = group,
            })
            idx_copy.object_type = "index"
            idx_copy.index_name = idx.index_name
            idx_copy.is_unique = idx.is_unique
            idx_copy.is_primary_key = idx.is_primary_key
            idx_copy.index_type = idx.index_type
            idx_copy.is_loaded = true
            table.insert(group.children, idx_copy)
          end
        end

        group.is_loaded = true
        return true
      end
      table.insert(self.children, indexes_group)
    end
  elseif base_object.object_type == "procedure" or base_object.object_type == "function" then
    -- For procedures/functions, show parameters
    local execute_action = BaseDbObject.new({
      name = base_object.object_type == "procedure" and "EXECUTE" or "SELECT",
      parent = self,
    })
    execute_action.object_type = "action"
    execute_action.action_type = base_object.object_type == "procedure" and "exec" or "select"
    execute_action.is_loaded = true
    table.insert(self.children, execute_action)

    -- Add Parameters group (lazy loaded from base object)
    local params_group = BaseDbObject.new({
      name = "Parameters",
      parent = self,
    })
    params_group.object_type = "parameter_group"

    params_group.load = function(group)
      if group.is_loaded then
        return true
      end

      group:clear_children()

      local parameters = base_object:get_parameters()
      if parameters then
        for _, param in ipairs(parameters) do
          local param_copy = BaseDbObject.new({
            name = param.parameter_name,
            parent = group,
          })
          param_copy.object_type = "parameter"
          param_copy.parameter_name = param.parameter_name
          param_copy.data_type = param.data_type
          param_copy.is_output = param.is_output
          param_copy.ordinal_position = param.ordinal_position
          param_copy.is_loaded = true
          table.insert(group.children, param_copy)
        end
      end

      group.is_loaded = true
      return true
    end
    table.insert(self.children, params_group)
  end
end

---Get columns from this synonym (resolves to base object's columns)
---@return ColumnClass[]? columns
function SynonymClass:get_columns()
  local base_object, error_msg = self:resolve()

  if error_msg or not base_object then
    return nil
  end

  -- Get columns from base object if it's a table or view
  if base_object.get_columns and (base_object.object_type == "table" or base_object.object_type == "view") then
    return base_object:get_columns()
  end

  return nil
end

---Generate SELECT query for this synonym
---@param limit number? The row limit (default 100)
---@return string query The SELECT query
function SynonymClass:generate_select(limit)
  limit = limit or 100
  -- Use the synonym name directly in query (database will resolve it)
  return string.format("SELECT TOP %d * FROM [%s].[%s];", limit, self.schema_name, self.synonym_name)
end

---Generate EXEC statement for procedure synonyms
---@return string query The EXEC statement
function SynonymClass:generate_exec()
  -- Resolve to get base object and its parameters
  local base_object = self:resolve()

  if base_object and base_object.generate_exec then
    -- Get the base procedure's exec template
    local base_exec = base_object:generate_exec()
    -- Replace the base procedure name with the synonym name
    local base_name = string.format("[%s].[%s]", base_object.schema_name, base_object.procedure_name)
    local synonym_name = string.format("[%s].[%s]", self.schema_name, self.synonym_name)
    return base_exec:gsub(vim.pesc(base_name), synonym_name)
  end

  -- Fallback: basic EXEC statement
  return string.format("EXEC [%s].[%s];", self.schema_name, self.synonym_name)
end

---Get metadata info for display in floating window
---@return table metadata Standardized metadata structure with sections
function SynonymClass:get_metadata_info()
  local sections = {}

  -- Synonym target info section
  table.insert(sections, {
    title = "SYNONYM TARGET",
    headers = {"Property", "Value"},
    rows = {
      {"Base Object", self.base_object_name or "(unknown)"},
      {"Object Type", self.base_object_type or "(unknown)"},
    },
  })

  -- Try to resolve to base object and get its metadata
  if self.resolve then
    local base_object, error_msg = self:resolve()
    if base_object and base_object.get_metadata_info then
      local base_metadata = base_object:get_metadata_info()
      if base_metadata and base_metadata.sections then
        -- Add base object sections with modified titles
        for _, section in ipairs(base_metadata.sections) do
          table.insert(sections, {
            title = "BASE: " .. section.title,
            headers = section.headers,
            rows = section.rows,
          })
        end
      end
    elseif error_msg then
      table.insert(sections, {
        title = "RESOLUTION ERROR",
        headers = {"Message"},
        rows = {{error_msg}},
      })
    end
  end

  return {
    sections = sections,
  }
end

---Generate the CREATE SYNONYM DDL statement
---Includes the base object definition if resolvable
---@return string definition The CREATE SYNONYM statement with optional base object definition
function SynonymClass:get_definition()
  local adapter = self:get_adapter()

  -- Use adapter to format the qualified synonym name
  local synonym_qualified = adapter:get_qualified_name(
    nil,  -- database (use connection context)
    self.schema_name,
    self.synonym_name
  )

  -- Base object name is already fully qualified in the metadata
  local base_name = self.base_object_name

  -- Generate the CREATE SYNONYM statement
  local definition = string.format("CREATE SYNONYM %s\n  FOR %s;", synonym_qualified, base_name)

  -- Try to resolve and get the base object's definition
  local base_object, error_msg = self:resolve()

  if base_object and base_object.get_definition then
    -- Get the base object's definition
    local base_definition = base_object:get_definition()

    if base_definition and base_definition ~= "" then
      -- Parse the base object name to get the database for USE statement
      local parts = self:parse_base_object_name()
      local use_statement = ""

      if parts.database then
        use_statement = string.format("USE [%s];\nGO\n\n", parts.database)
      end

      -- Append base object definition with a separator
      definition = definition .. "\n\n/*" .. string.rep("=", 77) .. "*\\\n** BASE OBJECT DEFINITION\n\\*" .. string.rep("=", 77) .. "*/\n"

      if use_statement ~= "" then
        definition = definition .. "\n" .. use_statement
      end

      definition = definition .. base_definition
    end
  elseif error_msg then
    -- Add a comment explaining why the base object couldn't be loaded
    definition = definition .. string.format("\n\n/*" .. string.rep("=", 77) .. "\n** BASE OBJECT DEFINITION\n** Unable to load: %s\n" .. string.rep("=", 77) .. "*/", error_msg)
  end

  return definition
end

return SynonymClass
