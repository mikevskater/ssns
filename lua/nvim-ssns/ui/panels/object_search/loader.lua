---@class ObjectSearchLoader
---Object loading functions for the object search module
local M = {}

local State = require('nvim-ssns.ui.panels.object_search.state')
local Helpers = require('nvim-ssns.ui.panels.object_search.helpers')
local Cancellation = require('nvim-ssns.async.cancellation')

---Forward reference for apply_search_async (injected by init.lua)
---@type fun(term: string, callback: fun()?)?
local apply_search_async_fn = nil

---Inject the apply_search_async function (called by init.lua)
---@param fn fun(term: string, callback: fun()?)
function M.set_apply_search_async_fn(fn)
  apply_search_async_fn = fn
end

-- ============================================================================
-- Searchable Object Creation
-- ============================================================================

---Create a SearchableObject from a database object
---@param obj BaseDbObject
---@param object_type string
---@param database DbClass
---@param server ServerClass
---@param parent_schema SchemaClass? Optional parent schema for non-schema objects
---@return SearchableObject
function M.create_searchable(obj, object_type, database, server, parent_schema)
  -- For schema objects, schema_name should be nil (they don't belong to another schema)
  -- For other objects, use the parent schema name
  local schema_name = nil
  if object_type ~= "schema" then
    if parent_schema then
      schema_name = parent_schema.name
    elseif obj.schema_name then
      schema_name = obj.schema_name
    elseif obj.parent and obj.parent.object_type == "schema" then
      schema_name = obj.parent.name
    end
  end

  local searchable = {
    object = obj,
    object_type = object_type,
    name = obj.name,
    schema_name = schema_name,
    database_name = database.db_name,
    server_name = server.name,
    definition = nil,
    definition_loaded = false,
    metadata_text = nil,
    metadata_loaded = false,
    unique_id = Helpers.generate_unique_id(server.name, database.db_name, schema_name, object_type, obj.name),
  }

  return searchable
end

---Flatten all objects from a database into searchable list
---@param database DbClass
---@param server ServerClass
---@return SearchableObject[]
function M.flatten_database_objects(database, server)
  local searchables = {}

  -- Check if this is a schema-based database (SQL Server, PostgreSQL)
  local schemas = database:get_schemas({ skip_load = true })

  if schemas and #schemas > 0 then
    -- Schema-based database
    for _, schema in ipairs(schemas) do
      -- Add schema itself as searchable (pass nil for parent_schema since schemas don't have parent schemas)
      table.insert(searchables, M.create_searchable(schema, "schema", database, server, nil))

      -- Add tables (pass schema as parent)
      local tables = schema:get_tables({ skip_load = true })
      if tables then
        for _, tbl in ipairs(tables) do
          table.insert(searchables, M.create_searchable(tbl, "table", database, server, schema))
        end
      end

      -- Add views (pass schema as parent)
      local views = schema:get_views({ skip_load = true })
      if views then
        for _, view in ipairs(views) do
          table.insert(searchables, M.create_searchable(view, "view", database, server, schema))
        end
      end

      -- Add procedures (pass schema as parent)
      local procedures = schema:get_procedures({ skip_load = true })
      if procedures then
        for _, proc in ipairs(procedures) do
          table.insert(searchables, M.create_searchable(proc, "procedure", database, server, schema))
        end
      end

      -- Add functions (pass schema as parent)
      local functions = schema:get_functions({ skip_load = true })
      if functions then
        for _, func in ipairs(functions) do
          table.insert(searchables, M.create_searchable(func, "function", database, server, schema))
        end
      end

      -- Add synonyms (pass schema as parent)
      local synonyms = schema:get_synonyms({ skip_load = true })
      if synonyms then
        for _, syn in ipairs(synonyms) do
          table.insert(searchables, M.create_searchable(syn, "synonym", database, server, schema))
        end
      end
    end
  else
    -- Non-schema database (MySQL, SQLite) - no parent schema
    local tables = database:get_tables({ skip_load = true })
    if tables then
      for _, tbl in ipairs(tables) do
        table.insert(searchables, M.create_searchable(tbl, "table", database, server, nil))
      end
    end

    local views = database:get_views({ skip_load = true })
    if views then
      for _, view in ipairs(views) do
        table.insert(searchables, M.create_searchable(view, "view", database, server, nil))
      end
    end

    local procedures = database:get_procedures({ skip_load = true })
    if procedures then
      for _, proc in ipairs(procedures) do
        table.insert(searchables, M.create_searchable(proc, "procedure", database, server, nil))
      end
    end

    local functions = database:get_functions({ skip_load = true })
    if functions then
      for _, func in ipairs(functions) do
        table.insert(searchables, M.create_searchable(func, "function", database, server, nil))
      end
    end
  end

  return searchables
end

-- ============================================================================
-- Loading Control
-- ============================================================================

---Cancel any active object loading operation
function M.cancel_object_loading()
  local loading_cancel_token = State.get_loading_cancel_token()
  if loading_cancel_token then
    loading_cancel_token:cancel("User cancelled")
  end
end

-- ============================================================================
-- Synonym Reference Loading
-- ============================================================================

---Discover and load databases referenced by cross-database synonyms
---This enables synonym resolution to work for objects in other databases
---@param callback fun()? Called when loading is complete
function M.load_synonym_referenced_databases_async(callback)
  local ui_state = State.get_ui_state()
  local multi_panel = State.get_multi_panel()
  local objects = ui_state.loaded_objects
  local server = ui_state.selected_server

  if not server then
    if callback then callback() end
    return
  end

  -- Collect unique cross-database references from synonyms
  local referenced_dbs = {}  -- db_name -> true
  local already_loaded = {}  -- db_name -> true (already in selected_databases)

  for db_name, _ in pairs(ui_state.selected_databases) do
    already_loaded[db_name] = true
  end

  for _, searchable in ipairs(objects) do
    if searchable.object_type == "synonym" and searchable.object then
      local syn = searchable.object
      if syn.parse_base_object_name and syn.base_object_name then
        local parts = syn:parse_base_object_name()
        -- Check if this is a cross-database reference (not linked server)
        if parts.database and not parts.server then
          local db_name = parts.database
          if not already_loaded[db_name] and not referenced_dbs[db_name] then
            referenced_dbs[db_name] = true
          end
        end
      end
    end
  end

  -- Count references
  local ref_count = 0
  for _ in pairs(referenced_dbs) do
    ref_count = ref_count + 1
  end

  if ref_count == 0 then
    -- No cross-database references, continue
    if callback then callback() end
    return
  end

  -- Update loading status
  ui_state.loading_message = string.format("Loading %d referenced databases...", ref_count)
  State.refresh_panels()

  -- Find and load referenced databases
  local databases = server:get_databases() or {}
  local dbs_to_load = {}

  for _, db in ipairs(databases) do
    if referenced_dbs[db.db_name] then
      table.insert(dbs_to_load, db)
    end
  end

  if #dbs_to_load == 0 then
    -- Referenced databases not found on server
    if callback then callback() end
    return
  end

  -- Load databases sequentially
  local db_idx = 1
  local cancel_token = State.get_loading_cancel_token()

  local function load_next_ref_db()
    if cancel_token and cancel_token.is_cancelled then
      if callback then callback() end
      return
    end

    if db_idx > #dbs_to_load then
      if callback then callback() end
      return
    end

    local db = dbs_to_load[db_idx]
    ui_state.loading_message = string.format("Loading referenced: %s (%d/%d)",
      db.db_name, db_idx, #dbs_to_load)

    State.refresh_panels()

    -- Load the database's full structure (schemas, tables, views, procedures, functions)
    -- This enables synonym resolution to find target objects
    -- We need the full async chain, not just load_async()
    local function load_ref_db_chain()
      local chain_ops = {
        function(next) db:load_async({ on_complete = function() next() end, on_error = function() next() end }) end,
        function(next) db:load_tables_async({ on_complete = function() next() end, on_error = function() next() end }) end,
        function(next) db:load_views_async({ on_complete = function() next() end, on_error = function() next() end }) end,
        function(next) db:load_procedures_async({ on_complete = function() next() end, on_error = function() next() end }) end,
        function(next) db:load_functions_async({ on_complete = function() next() end, on_error = function() next() end }) end,
      }

      local op_idx = 1
      local function run_next_op()
        if cancel_token and cancel_token.is_cancelled then
          -- Referenced database loading cancelled - move to next
          -- Note: We don't add to selected_databases or loaded_objects
          -- These databases are only loaded into cache for synonym resolution
          db_idx = db_idx + 1
          vim.schedule(load_next_ref_db)
          return
        end

        if op_idx > #chain_ops then
          -- All operations complete for this database
          -- Note: We don't add to selected_databases or loaded_objects
          -- These databases are only loaded into cache for synonym resolution,
          -- not shown in search results
          db_idx = db_idx + 1
          vim.schedule(load_next_ref_db)
          return
        end

        chain_ops[op_idx](function()
          op_idx = op_idx + 1
          vim.schedule(run_next_op)
        end)
      end

      run_next_op()
    end

    load_ref_db_chain()
  end

  load_next_ref_db()
end

-- ============================================================================
-- Metadata Preloading
-- ============================================================================

---Preload metadata (columns/parameters) and definitions for all objects asynchronously
---Uses bulk loading per database for efficiency (single query per database)
---@param callback fun()? Called when preloading is complete
function M.preload_metadata_async(callback)
  local ui_state = State.get_ui_state()
  local multi_panel = State.get_multi_panel()
  local objects = ui_state.loaded_objects
  local total = #objects

  if total == 0 then
    ui_state.search_ready = true
    ui_state.loading_status = "ready"
    ui_state.loading_message = "Ready to search"
    if callback then callback() end
    return
  end

  -- Update loading state
  ui_state.loading_status = "loading_metadata"
  ui_state.loading_progress = 0
  ui_state.loading_message = "Preloading metadata for search..."
  ui_state.search_ready = false

  -- Keep spinner running
  State.start_spinner_animation()
  State.refresh_panels()

  -- Get list of databases to load metadata for
  local databases = {}
  for _, db in pairs(ui_state.selected_databases) do
    table.insert(databases, db)
  end

  local total_dbs = #databases
  local completed_dbs = 0
  local all_metadata = {}  -- "db:schema.object" -> metadata text
  local all_definitions = {}  -- "db:schema.object" -> definition text
  local cancel_token = State.get_loading_cancel_token()

  ---Apply loaded metadata/definitions to searchable objects
  ---Since bulk loaders now populate actual objects, we derive from objects directly
  ---IMPORTANT: Only use pre-loaded data (check *_loaded flags), never trigger sync loads
  local function apply_to_objects()
    for _, searchable in ipairs(objects) do
      local obj = searchable.object

      -- Derive metadata from actual object (ONLY if pre-loaded by bulk loader)
      -- Do NOT call get_columns()/get_parameters() as they trigger sync loads
      if obj and not searchable.metadata_loaded then
        local parts = {}

        -- For tables and views: use pre-loaded columns (direct access, no getter)
        if (searchable.object_type == "table" or searchable.object_type == "view") then
          if obj.columns_loaded and obj.columns then
            for _, col in ipairs(obj.columns) do
              table.insert(parts, col.name or col.column_name)
              if col.data_type then
                table.insert(parts, col.data_type)
              end
            end
          end
        end

        -- For procedures and functions: use pre-loaded parameters (direct access)
        if (searchable.object_type == "procedure" or searchable.object_type == "function") then
          if obj.parameters_loaded and obj.parameters then
            for _, param in ipairs(obj.parameters) do
              table.insert(parts, param.name or param.parameter_name)
              if param.data_type then
                table.insert(parts, param.data_type)
              end
            end
          end
        end

        -- For functions (TVFs): also use pre-loaded columns (direct access)
        if searchable.object_type == "function" then
          if obj.columns_loaded and obj.columns then
            for _, col in ipairs(obj.columns) do
              table.insert(parts, col.name or col.column_name)
              if col.data_type then
                table.insert(parts, col.data_type)
              end
            end
          end
        end

        searchable.metadata_text = table.concat(parts, " ")
        searchable.metadata_loaded = true
      end

      -- Derive definition from actual object (ONLY if pre-loaded by bulk loader)
      -- Do NOT call get_definition() as it triggers sync load
      if obj and not searchable.definition_loaded then
        if obj.definition_loaded and obj.definition then
          searchable.definition = obj.definition
          searchable.definition_loaded = true
          ui_state.definitions_cache[searchable.unique_id] = obj.definition
        end
        -- Note: Do NOT set searchable.definition_loaded = true if no definition found
        -- This allows load_definition() to try again later
      end
    end

    -- Done
    State.stop_spinner_animation()
    ui_state.loading_status = "ready"
    ui_state.loading_message = string.format("Ready - %d objects loaded", total)
    ui_state.search_ready = true

    if multi_panel then
      multi_panel:render_all()
    end

    if callback then callback() end
  end

  ---Load metadata and definitions for a single database (sequentially)
  local function load_database(db, db_callback)
    if cancel_token and cancel_token.is_cancelled then
      db_callback()
      return
    end

    -- Step 1: Load all metadata (columns/parameters) in bulk
    local function load_metadata(next_step)
      if not db.load_all_metadata_bulk_async then
        next_step()
        return
      end

      db:load_all_metadata_bulk_async({
        on_complete = function(metadata, err)
          if metadata then
            -- Store with database prefix for lookup
            for key, value in pairs(metadata) do
              local full_key = string.format("%s:%s", db.db_name, key):lower()
              all_metadata[full_key] = value
            end
          end
          next_step()
        end,
        on_error = function(err)
          -- Continue even on error
          next_step()
        end,
      })
    end

    -- Step 2: Load all definitions in bulk
    local function load_definitions(next_step)
      if not db.load_all_definitions_bulk_async then
        next_step()
        return
      end

      db:load_all_definitions_bulk_async({
        on_complete = function(definitions, err)
          if definitions then
            -- Store with database prefix for lookup
            for key, value in pairs(definitions) do
              local full_key = string.format("%s:%s", db.db_name, key):lower()
              all_definitions[full_key] = value
            end
          end
          next_step()
        end,
        on_error = function(err)
          -- Continue even on error
          next_step()
        end,
      })
    end

    -- Run sequentially: metadata -> definitions -> callback
    load_metadata(function()
      load_definitions(function()
        db_callback()
      end)
    end)
  end

  -- Load databases sequentially to avoid overloading the server
  if total_dbs == 0 then
    apply_to_objects()
    return
  end

  local db_idx = 1

  local function load_next_database()
    if cancel_token and cancel_token.is_cancelled then
      State.stop_spinner_animation()
      ui_state.loading_status = "cancelled"
      ui_state.loading_message = "Metadata loading cancelled"
      if callback then callback() end
      return
    end

    if db_idx > total_dbs then
      -- All databases loaded, apply to objects
      apply_to_objects()
      return
    end

    local db = databases[db_idx]
    ui_state.loading_message = string.format("Loading metadata for %s (%d/%d)", db.db_name, db_idx, total_dbs)
    State.refresh_panels()

    load_database(db, function()
      completed_dbs = completed_dbs + 1
      ui_state.loading_progress = math.floor((completed_dbs / total_dbs) * 100)
      State.refresh_panels()

      db_idx = db_idx + 1
      vim.schedule(load_next_database)
    end)
  end

  load_next_database()
end

-- ============================================================================
-- Main Object Loading
-- ============================================================================

---Load all objects for selected databases with async support and cancellation
---@param callback function? Callback when complete
function M.load_objects_for_databases(callback)
  local ui_state = State.get_ui_state()
  local multi_panel = State.get_multi_panel()

  if not ui_state.selected_server then
    vim.notify("No server selected", vim.log.levels.WARN)
    return
  end

  -- Cancel any existing loading operation
  M.cancel_object_loading()

  local server = ui_state.selected_server
  local databases = {}

  -- Collect selected databases
  for _, db in pairs(ui_state.selected_databases) do
    table.insert(databases, db)
  end

  if #databases == 0 then
    vim.notify("No databases selected", vim.log.levels.WARN)
    return
  end

  -- Initialize loading state
  local loading_cancel_token = Cancellation.create_token()
  State.set_loading_cancel_token(loading_cancel_token)
  ui_state.loading_status = "loading"
  ui_state.loading_progress = 0
  ui_state.loading_message = "Loading objects..."
  ui_state.loading_detail = nil
  -- Reset selection to top when loading new databases
  ui_state.selected_result_idx = 1
  ui_state.loaded_objects = {}

  -- Invalidate caches since loaded_objects is being reset
  State.invalidate_pre_filtered_cache()

  -- Start spinner animation
  State.start_spinner_animation()
  State.refresh_panels()

  -- Process databases in sequence using vim.schedule to avoid blocking
  local db_idx = 1
  local total_dbs = #databases
  local cancel_token = loading_cancel_token  -- Capture for closure

  ---Finalize loading (success or cancel)
  local function finalize_loading(status, message)
    ui_state.loading_detail = nil

    if status == "loaded" then
      ui_state.loading_progress = 100
      ui_state.loading_message = message or string.format("Loaded %d objects - loading references...", #ui_state.loaded_objects)

      -- Don't stop spinner yet - we're starting multi-pass loading:
      -- 1. Load databases referenced by cross-database synonyms
      -- 2. Preload metadata/definitions for all objects
      -- 3. Enable search
      M.load_synonym_referenced_databases_async(function()
        -- Now preload metadata for all databases (including newly loaded ones)
        ui_state.loading_message = string.format("Loaded %d objects - preloading metadata...", #ui_state.loaded_objects)
        State.refresh_panels()

        M.preload_metadata_async(function()
          -- Now search is ready - apply initial search filter
          if apply_search_async_fn then
            apply_search_async_fn(ui_state.search_term, function()
              if multi_panel then
                multi_panel:render_all()
              end
              if callback then callback(status) end
            end)
          else
            if multi_panel then
              multi_panel:render_all()
            end
            if callback then callback(status) end
          end
        end)
      end)
      return
    elseif status == "cancelled" then
      State.stop_spinner_animation()
      State.set_loading_cancel_token(nil)
      ui_state.loading_status = status
      ui_state.loading_message = "Loading cancelled"
      ui_state.search_ready = false

      -- Apply search to partial results if any (async handles its own rendering)
      if #ui_state.loaded_objects > 0 then
        -- Mark search as ready for partial results
        ui_state.search_ready = true
        if apply_search_async_fn then
          apply_search_async_fn(ui_state.search_term, function()
            if multi_panel then
              multi_panel:render_all()
            end
            if callback then callback(status) end
          end)
        else
          if multi_panel then
            multi_panel:render_all()
          end
          if callback then callback(status) end
        end
        return
      end
    else
      State.stop_spinner_animation()
      State.set_loading_cancel_token(nil)
      ui_state.loading_status = status
    end

    if multi_panel then
      multi_panel:render_all()
    end

    if callback then callback(status) end
  end

  ---Update loading detail and re-render
  local function update_detail(detail)
    ui_state.loading_detail = detail
    -- Note: Results panel is re-rendered by spinner timer
  end

  local function process_next_database()
    -- Check cancellation
    if cancel_token.is_cancelled then
      finalize_loading("cancelled")
      return
    end

    if db_idx > total_dbs then
      -- Done loading all databases
      finalize_loading("loaded")
      return
    end

    local db = databases[db_idx]
    ui_state.loading_message = string.format("Loading %s (%d/%d)", db.db_name, db_idx, total_dbs)
    ui_state.loading_progress = math.floor((db_idx - 1) / total_dbs * 100)
    State.refresh_panels()

    ---Finalize this database and move to next
    local function finalize_db_and_continue()
      -- Check cancellation
      if cancel_token.is_cancelled then
        finalize_loading("cancelled")
        return
      end

      -- Flatten objects from this database
      update_detail("Processing objects...")
      local db_objects = M.flatten_database_objects(db, server)
      for _, obj in ipairs(db_objects) do
        table.insert(ui_state.loaded_objects, obj)
      end

      -- Invalidate caches since loaded_objects has changed
      State.invalidate_pre_filtered_cache()

      -- Apply search filter incrementally to show results as they load (async handles rendering)
      if apply_search_async_fn then
        apply_search_async_fn(ui_state.search_term, function()
          -- Force display update so results are visible immediately
          vim.cmd('redraw')

          -- Move to next database
          db_idx = db_idx + 1
          vim.schedule(process_next_database)
        end)
      else
        -- Move to next database
        db_idx = db_idx + 1
        vim.schedule(process_next_database)
      end
    end

    ---Chain async operations with callbacks
    ---@param operations { name: string, fn: fun(on_done: fun(result: any)) }[]
    ---@param on_all_done fun()
    local function run_async_chain(operations, on_all_done)
      local op_idx = 1

      local function run_next()
        if cancel_token.is_cancelled then
          finalize_loading("cancelled")
          return
        end

        if op_idx > #operations then
          on_all_done()
          return
        end

        local op = operations[op_idx]
        update_detail(op.name)
        State.refresh_panels()

        op.fn(function(result)
          op_idx = op_idx + 1
          vim.schedule(run_next)
        end)
      end

      vim.schedule(run_next)
    end

    -- Build async operation chain for this database
    -- Uses true non-blocking RPC async methods
    local operations = {
      {
        name = "Loading schemas...",
        fn = function(on_done)
          db:load_async({
            on_complete = function() on_done() end,
          })
        end,
      },
      {
        name = "Loading tables...",
        fn = function(on_done)
          db:load_tables_async({
            on_complete = function() on_done() end,
          })
        end,
      },
      {
        name = "Loading views...",
        fn = function(on_done)
          db:load_views_async({
            on_complete = function() on_done() end,
          })
        end,
      },
      {
        name = "Loading procedures...",
        fn = function(on_done)
          db:load_procedures_async({
            on_complete = function() on_done() end,
          })
        end,
      },
      {
        name = "Loading functions...",
        fn = function(on_done)
          db:load_functions_async({
            on_complete = function() on_done() end,
          })
        end,
      },
    }

    -- Add synonyms if supported
    if db.load_synonyms_async then
      table.insert(operations, {
        name = "Loading synonyms...",
        fn = function(on_done)
          db:load_synonyms_async({
            on_complete = function() on_done() end,
          })
        end,
      })
    end

    -- Start the async chain
    run_async_chain(operations, finalize_db_and_continue)
  end

  -- Start processing
  vim.schedule(process_next_database)
end

-- ============================================================================
-- On-Demand Loading
-- ============================================================================

---Load definition for a searchable object
---@param searchable SearchableObject
---@return string? definition
function M.load_definition(searchable)
  local ui_state = State.get_ui_state()

  if searchable.definition_loaded then
    return searchable.definition
  end

  -- Check cache first
  if ui_state.definitions_cache[searchable.unique_id] then
    searchable.definition = ui_state.definitions_cache[searchable.unique_id]
    searchable.definition_loaded = true
    return searchable.definition
  end

  local obj = searchable.object
  if not obj then
    searchable.definition_loaded = true
    return nil
  end

  -- First try to get pre-loaded definition directly (no sync load)
  if obj.definition_loaded and obj.definition then
    searchable.definition = obj.definition
    searchable.definition_loaded = true
    ui_state.definitions_cache[searchable.unique_id] = obj.definition
    return obj.definition
  end

  -- For synonyms, try to get the base object's definition
  if searchable.object_type == "synonym" and obj.resolve then
    local ok, base_obj = pcall(function()
      return obj:resolve()
    end)
    if ok and base_obj and base_obj.definition_loaded and base_obj.definition then
      searchable.definition = base_obj.definition
      searchable.definition_loaded = true
      ui_state.definitions_cache[searchable.unique_id] = base_obj.definition
      return base_obj.definition
    end
  end

  -- Fallback: call get_definition() which may trigger a sync load
  -- Only do this for objects that weren't processed by bulk loaders
  if obj.get_definition then
    local ok, def = pcall(function()
      return obj:get_definition()
    end)

    if ok and def then
      searchable.definition = def
      searchable.definition_loaded = true
      ui_state.definitions_cache[searchable.unique_id] = def
      return def
    end
  end

  searchable.definition_loaded = true
  return nil
end

---Load metadata text for a searchable object (columns/parameters)
---@param searchable SearchableObject
---@return string? metadata_text
function M.load_metadata_text(searchable)
  if searchable.metadata_loaded then
    return searchable.metadata_text
  end

  local obj = searchable.object
  local parts = {}

  -- For tables and views: get column names
  if searchable.object_type == "table" or searchable.object_type == "view" then
    if obj.get_columns then
      local ok, columns = pcall(function()
        return obj:get_columns()
      end)
      if ok and columns then
        for _, col in ipairs(columns) do
          table.insert(parts, col.name)
          if col.data_type then
            table.insert(parts, col.data_type)
          end
        end
      end
    end
  end

  -- For procedures and functions: get parameter names
  if searchable.object_type == "procedure" or searchable.object_type == "function" then
    if obj.get_parameters then
      local ok, params = pcall(function()
        return obj:get_parameters()
      end)
      if ok and params then
        for _, param in ipairs(params) do
          table.insert(parts, param.name)
          if param.data_type then
            table.insert(parts, param.data_type)
          end
        end
      end
    end
  end

  searchable.metadata_text = table.concat(parts, " ")
  searchable.metadata_loaded = true
  return searchable.metadata_text
end

return M
