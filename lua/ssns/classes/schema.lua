local BaseDbObject = require('ssns.classes.base')

---@class SchemaClass : BaseDbObject
---@field schema_name string The schema name
---@field parent DbClass The parent database object
---@field tables TableClass[]? Array of table objects
---@field views ViewClass[]? Array of view objects
---@field procedures ProcedureClass[]? Array of procedure objects
---@field functions FunctionClass[]? Array of function objects
---@field synonyms SynonymClass[]? Array of synonym objects
---@field object_groups table? Grouped objects for UI display
local SchemaClass = setmetatable({}, { __index = BaseDbObject })
SchemaClass.__index = SchemaClass

---Create a new Schema instance
---@param opts {name: string, parent: DbClass}
---@return SchemaClass
function SchemaClass.new(opts)
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = opts.parent,
  }), SchemaClass)

  self.object_type = "schema"
  self.schema_name = opts.name
  self.tables = nil
  self.views = nil
  self.procedures = nil
  self.functions = nil
  self.synonyms = nil

  return self
end

---Load all objects in this schema (tables, views, procedures, functions, synonyms)
---@return boolean success
function SchemaClass:load()
  if self.is_loaded then
    return true
  end

  -- Load all object types into typed arrays
  -- Note: These will each make individual queries, but for schema-based servers,
  -- it's better to use the database-level bulk loading (db:get_tables(), etc.)
  -- which loads all schemas at once
  self:load_tables()
  self:load_views()
  self:load_procedures()
  self:load_functions()
  self:load_synonyms()

  self.is_loaded = true
  return true
end

---Set tables from pre-loaded bulk data
---Preserves existing table objects to maintain loaded column data
---@param table_data_list table[] Array of parsed table data from adapter
function SchemaClass:set_tables(table_data_list)
  local adapter = self:get_adapter()

  -- If tables already exist, preserve them and their loaded data
  local existing_tables = {}
  if self.tables then
    for _, existing_table in ipairs(self.tables) do
      existing_tables[existing_table.name] = existing_table
    end
  end

  self.tables = {}
  for _, table_data in ipairs(table_data_list) do
    -- Check if this table already exists
    local existing = existing_tables[table_data.name]
    if existing then
      -- Reuse existing table object to preserve loaded column data
      table.insert(self.tables, existing)
    else
      -- Create new table object
      local table_obj = adapter:create_table(self, table_data)
      table.insert(self.tables, table_obj)
    end
  end
end

---Load tables in this schema
---@return boolean success
function SchemaClass:load_tables()
  local adapter = self:get_adapter()
  local db = self.parent

  -- Get tables query from adapter
  local query = adapter:get_tables_query(db.db_name, self.schema_name)

  -- Execute query
  local results = adapter:execute(db:_get_db_connection_config(), query)

  -- Parse results
  local tables = adapter:parse_tables(results)

  -- Use set method to create objects
  self:set_tables(tables)

  return true
end

---Set views from pre-loaded bulk data
---Preserves existing view objects to maintain loaded column data
---@param view_data_list table[] Array of parsed view data from adapter
function SchemaClass:set_views(view_data_list)
  local adapter = self:get_adapter()

  -- If views already exist, preserve them and their loaded data
  local existing_views = {}
  if self.views then
    for _, existing_view in ipairs(self.views) do
      existing_views[existing_view.name] = existing_view
    end
  end

  self.views = {}
  for _, view_data in ipairs(view_data_list) do
    -- Check if this view already exists
    local existing = existing_views[view_data.name]
    if existing then
      -- Reuse existing view object to preserve loaded column data
      table.insert(self.views, existing)
    else
      -- Create new view object
      local view_obj = adapter:create_view(self, view_data)
      table.insert(self.views, view_obj)
    end
  end
end

---Load views in this schema
---@return boolean success
function SchemaClass:load_views()
  local adapter = self:get_adapter()
  local db = self.parent

  if not adapter.features.views then
    self.views = {}
    return true
  end

  -- Get views query from adapter
  local query = adapter:get_views_query(db.db_name, self.schema_name)

  -- Execute query
  local results = adapter:execute(db:_get_db_connection_config(), query)

  -- Parse results
  local views = adapter:parse_views(results)

  -- Use set method to create objects
  self:set_views(views)

  return true
end

---Set procedures from pre-loaded bulk data
---Preserves existing procedure objects to maintain loaded parameter data
---@param proc_data_list table[] Array of parsed procedure data from adapter
function SchemaClass:set_procedures(proc_data_list)
  local ProcedureClass = require('ssns.classes.procedure')

  -- If procedures already exist, preserve them and their loaded data
  local existing_procs = {}
  if self.procedures then
    for _, existing_proc in ipairs(self.procedures) do
      existing_procs[existing_proc.name] = existing_proc
    end
  end

  self.procedures = {}
  for _, proc_data in ipairs(proc_data_list) do
    -- Check if this procedure already exists
    local existing = existing_procs[proc_data.name]
    if existing then
      -- Reuse existing procedure object to preserve loaded parameter data
      table.insert(self.procedures, existing)
    else
      -- Create new procedure object
      local proc_obj = ProcedureClass.new({
        name = proc_data.name,
        schema_name = proc_data.schema,
        parent = self,
      })
      table.insert(self.procedures, proc_obj)
    end
  end
end

---Load stored procedures in this schema
---@return boolean success
function SchemaClass:load_procedures()
  local adapter = self:get_adapter()
  local db = self.parent

  if not adapter.features.procedures then
    self.procedures = {}
    return true
  end

  -- Get procedures query from adapter
  local query = adapter:get_procedures_query(db.db_name, self.schema_name)

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(db:_get_db_connection_config(), query)

  -- Parse results
  local procedures = adapter:parse_procedures(results)

  -- Use set method to create objects
  self:set_procedures(procedures)

  return true
end

---Set functions from pre-loaded bulk data
---Preserves existing function objects to maintain loaded parameter data
---@param func_data_list table[] Array of parsed function data from adapter
function SchemaClass:set_functions(func_data_list)
  local FunctionClass = require('ssns.classes.function')

  -- If functions already exist, preserve them and their loaded data
  local existing_funcs = {}
  if self.functions then
    for _, existing_func in ipairs(self.functions) do
      existing_funcs[existing_func.name] = existing_func
    end
  end

  self.functions = {}
  for _, func_data in ipairs(func_data_list) do
    -- Check if this function already exists
    local existing = existing_funcs[func_data.name]
    if existing then
      -- Reuse existing function object to preserve loaded parameter data
      table.insert(self.functions, existing)
    else
      -- Create new function object
      local func_obj = FunctionClass.new({
        name = func_data.name,
        schema_name = func_data.schema,
        function_type = func_data.type,
        parent = self,
      })
      table.insert(self.functions, func_obj)
    end
  end
end

---Load functions in this schema
---@return boolean success
function SchemaClass:load_functions()
  local adapter = self:get_adapter()
  local db = self.parent

  if not adapter.features.functions then
    self.functions = {}
    return true
  end

  -- Get functions query from adapter
  local query = adapter:get_functions_query(db.db_name, self.schema_name)

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  local results = adapter:execute(db:_get_db_connection_config(), query)

  -- Parse results
  local functions = adapter:parse_functions(results)

  -- Use set method to create objects
  self:set_functions(functions)

  return true
end

---Set synonyms from pre-loaded bulk data
---Preserves existing synonym objects to maintain any cached resolution data
---@param syn_data_list table[] Array of parsed synonym data from adapter
function SchemaClass:set_synonyms(syn_data_list)
  local SynonymClass = require('ssns.classes.synonym')

  -- If synonyms already exist, preserve them and their loaded data
  local existing_syns = {}
  if self.synonyms then
    for _, existing_syn in ipairs(self.synonyms) do
      existing_syns[existing_syn.name] = existing_syn
    end
  end

  self.synonyms = {}
  for _, syn_data in ipairs(syn_data_list) do
    -- Check if this synonym already exists
    local existing = existing_syns[syn_data.name]
    if existing then
      -- Reuse existing synonym object to preserve any cached resolution data
      table.insert(self.synonyms, existing)
    else
      -- Create new synonym object
      local syn_obj = SynonymClass.new({
        name = syn_data.name,
        schema_name = syn_data.schema,
        base_object_name = syn_data.base_object_name,
        base_object_type = syn_data.base_object_type,
        parent = self,
      })
      table.insert(self.synonyms, syn_obj)
    end
  end
end

---Load synonyms in this schema
---@return boolean success
function SchemaClass:load_synonyms()
  local adapter = self:get_adapter()
  local db = self.parent

  if not adapter.features.synonyms then
    self.synonyms = {}
    return true
  end

  -- Get synonyms query from adapter
  local query = adapter:get_synonyms_query(db.db_name, self.schema_name)

  -- Execute query
  local results = adapter:execute(db:_get_db_connection_config(), query)

  -- Parse results
  local synonyms = adapter:parse_synonyms(results)

  -- Use set method to create objects
  self:set_synonyms(synonyms)

  return true
end

---Bulk load all columns for all tables and views in this schema
---This is more efficient than loading columns individually
---@return boolean success
function SchemaClass:load_all_columns_bulk()
  -- Check if already done
  if self._columns_bulk_loaded then
    return true
  end

  -- Ensure tables and views are loaded
  if not self.tables then
    self:load_tables()
  end
  if not self.views then
    self:load_views()
  end

  -- Check if any object already has columns loaded (skip if so)
  local already_loaded = false
  for _, table_obj in ipairs(self.tables or {}) do
    if table_obj.columns_loaded then
      already_loaded = true
      break
    end
  end
  if not already_loaded then
    for _, view_obj in ipairs(self.views or {}) do
      if view_obj.columns_loaded then
        already_loaded = true
        break
      end
    end
  end

  if already_loaded then
    self._columns_bulk_loaded = true
    return true
  end

  -- Check if adapter supports bulk column loading
  local adapter = self:get_adapter()
  if not adapter.get_columns_bulk_query then
    -- Fallback: load columns individually
    for _, table_obj in ipairs(self.tables or {}) do
      if not table_obj.columns_loaded then
        table_obj:load_columns()
      end
    end
    for _, view_obj in ipairs(self.views or {}) do
      if not view_obj.columns_loaded then
        view_obj:load_columns()
      end
    end
    self._columns_bulk_loaded = true
    return true
  end

  -- Execute bulk query
  local db = self.parent
  local query = adapter:get_columns_bulk_query(db.db_name, self.schema_name)
  local results = adapter:execute(db:_get_db_connection_config(), query)

  if not results or not results.rows then
    self._columns_bulk_loaded = true
    return false
  end

  -- Group columns by table name
  local columns_by_table = {}
  for _, row in ipairs(results.rows) do
    local table_name = row.table_name
    columns_by_table[table_name] = columns_by_table[table_name] or {}
    table.insert(columns_by_table[table_name], row)
  end

  -- Distribute to table objects
  for _, table_obj in ipairs(self.tables or {}) do
    if not table_obj.columns_loaded then
      local table_columns = columns_by_table[table_obj.table_name] or {}
      local parsed_columns = adapter:parse_columns({ rows = table_columns })

      table_obj.columns = {}
      for _, col_data in ipairs(parsed_columns) do
        local col_obj = adapter:create_column(table_obj, col_data)
        table.insert(table_obj.columns, col_obj)
      end
      table_obj.columns_loaded = true
    end
  end

  -- Distribute to view objects
  for _, view_obj in ipairs(self.views or {}) do
    if not view_obj.columns_loaded then
      local view_columns = columns_by_table[view_obj.view_name] or {}
      local parsed_columns = adapter:parse_columns({ rows = view_columns })

      view_obj.columns = {}
      for _, col_data in ipairs(parsed_columns) do
        local col_obj = adapter:create_column(view_obj, col_data)
        table.insert(view_obj.columns, col_obj)
      end
      view_obj.columns_loaded = true
    end
  end

  self._columns_bulk_loaded = true
  return true
end

---Reload all objects in this schema
---@return boolean success
function SchemaClass:reload()
  -- Invalidate query cache for this schema's server connection
  local Connection = require('ssns.connection')
  local server = self:get_server()
  if server and server.connection_config then
    Connection.invalidate_cache(server.connection_config)
  end

  -- Clear typed arrays
  self.tables = nil
  self.views = nil
  self.procedures = nil
  self.functions = nil
  self.synonyms = nil
  self._columns_bulk_loaded = false
  self.is_loaded = false
  return self:load()
end

---Find a table by name
---@param table_name string
---@return TableClass?
function SchemaClass:find_table(table_name)
  if not self.tables then
    self:load_tables()
  end

  for _, table_obj in ipairs(self.tables) do
    if table_obj.name == table_name then
      return table_obj
    end
  end

  return nil
end

---Find a view by name
---@param view_name string
---@return ViewClass?
function SchemaClass:find_view(view_name)
  if not self.views then
    self:load_views()
  end

  for _, view_obj in ipairs(self.views) do
    if view_obj.name == view_name then
      return view_obj
    end
  end

  return nil
end

---Find a synonym by name
---@param synonym_name string
---@return SynonymClass?
function SchemaClass:find_synonym(synonym_name)
  if not self.synonyms then
    self:load_synonyms()
  end

  for _, syn_obj in ipairs(self.synonyms) do
    if syn_obj.name == synonym_name then
      return syn_obj
    end
  end

  return nil
end

---Get all synonyms in this schema
---@param opts table? Options { skip_load: boolean? }
---@return SynonymClass[]
function SchemaClass:get_synonyms(opts)
  opts = opts or {}
  if not self.synonyms and not opts.skip_load then
    self:load_synonyms()
  end
  return self.synonyms or {}
end

---Get all tables in this schema
---@param opts table? Options { skip_load: boolean? }
---@return TableClass[]
function SchemaClass:get_tables(opts)
  opts = opts or {}
  if not self.tables and not opts.skip_load then
    self:load_tables()
  end
  return self.tables or {}
end

---Get all views in this schema
---@param opts table? Options { skip_load: boolean? }
---@return ViewClass[]
function SchemaClass:get_views(opts)
  opts = opts or {}
  if not self.views and not opts.skip_load then
    self:load_views()
  end
  return self.views or {}
end

---Get all procedures in this schema
---@param opts table? Options { skip_load: boolean? }
---@return ProcedureClass[]
function SchemaClass:get_procedures(opts)
  opts = opts or {}
  if not self.procedures and not opts.skip_load then
    self:load_procedures()
  end
  return self.procedures or {}
end

---Get all functions in this schema
---@param opts table? Options { skip_load: boolean? }
---@return FunctionClass[]
function SchemaClass:get_functions(opts)
  opts = opts or {}
  if not self.functions and not opts.skip_load then
    self:load_functions()
  end
  return self.functions or {}
end

---Get all objects of a specific type
---@param object_type string "table", "view", "procedure", "function", "synonym"
---@return BaseDbObject[]
function SchemaClass:get_objects_by_type(object_type)
  if object_type == "table" then
    return self:get_tables()
  elseif object_type == "view" then
    return self:get_views()
  elseif object_type == "procedure" then
    return self:get_procedures()
  elseif object_type == "function" then
    return self:get_functions()
  elseif object_type == "synonym" then
    return self:get_synonyms()
  end

  return {}
end

---Get count of all objects in this schema
---@return number
function SchemaClass:get_object_count()
  local count = 0
  count = count + (self.tables and #self.tables or 0)
  count = count + (self.views and #self.views or 0)
  count = count + (self.procedures and #self.procedures or 0)
  count = count + (self.functions and #self.functions or 0)
  count = count + (self.synonyms and #self.synonyms or 0)
  return count
end

---Get the full qualified name for this schema
---@return string
function SchemaClass:get_qualified_name()
  local adapter = self:get_adapter()
  local db = self.parent

  if adapter.features.schemas then
    return adapter:get_qualified_name(db.db_name, self.schema_name, nil)
  else
    return adapter:quote_identifier(db.db_name)
  end
end

---Get string representation for debugging
---@return string
function SchemaClass:to_string()
  return string.format(
    "SchemaClass{name=%s, tables=%d, views=%d, procs=%d, funcs=%d, synonyms=%d}",
    self.name,
    self.tables and #self.tables or 0,
    self.views and #self.views or 0,
    self.procedures and #self.procedures or 0,
    self.functions and #self.functions or 0,
    self.synonyms and #self.synonyms or 0
  )
end

-- ============================================================================
-- Async Methods
-- ============================================================================

---@class SchemaLoadAsyncOpts : ExecutorOpts
---@field on_complete fun(success: boolean, error: string?)? Completion callback

---Load all objects in this schema asynchronously
---@param opts SchemaLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function SchemaClass:load_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading schema...")
    local success = self:load()
    ctx.report_progress(100, "Schema loaded")
    return success
  end, {
    name = opts.name or string.format("Loading schema %s", self.schema_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load tables in this schema asynchronously
---@param opts SchemaLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function SchemaClass:load_tables_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading tables...")
    local success = self:load_tables()
    ctx.report_progress(100, "Tables loaded")
    return success
  end, {
    name = opts.name or string.format("Loading tables for %s", self.schema_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load views in this schema asynchronously
---@param opts SchemaLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function SchemaClass:load_views_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading views...")
    local success = self:load_views()
    ctx.report_progress(100, "Views loaded")
    return success
  end, {
    name = opts.name or string.format("Loading views for %s", self.schema_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load procedures in this schema asynchronously
---@param opts SchemaLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function SchemaClass:load_procedures_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading procedures...")
    local success = self:load_procedures()
    ctx.report_progress(100, "Procedures loaded")
    return success
  end, {
    name = opts.name or string.format("Loading procedures for %s", self.schema_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load functions in this schema asynchronously
---@param opts SchemaLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function SchemaClass:load_functions_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading functions...")
    local success = self:load_functions()
    ctx.report_progress(100, "Functions loaded")
    return success
  end, {
    name = opts.name or string.format("Loading functions for %s", self.schema_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load synonyms in this schema asynchronously
---@param opts SchemaLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function SchemaClass:load_synonyms_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading synonyms...")
    local success = self:load_synonyms()
    ctx.report_progress(100, "Synonyms loaded")
    return success
  end, {
    name = opts.name or string.format("Loading synonyms for %s", self.schema_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

---Load all columns for all tables and views in this schema asynchronously
---@param opts SchemaLoadAsyncOpts? Options
---@return string task_id Task ID for tracking/cancellation
function SchemaClass:load_all_columns_bulk_async(opts)
  opts = opts or {}
  local Executor = require('ssns.async.executor')

  return Executor.run(function(ctx)
    ctx.throw_if_cancelled()
    ctx.report_progress(0, "Loading columns...")
    local success = self:load_all_columns_bulk()
    ctx.report_progress(100, "Columns loaded")
    return success
  end, {
    name = opts.name or string.format("Loading columns for %s", self.schema_name),
    timeout_ms = opts.timeout_ms,
    cancel_token = opts.cancel_token,
    on_progress = opts.on_progress,
    on_complete = opts.on_complete,
  })
end

return SchemaClass
