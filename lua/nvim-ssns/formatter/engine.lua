---@class FormatterState
---@field indent_level number Current indentation depth
---@field line_length number Characters on current line
---@field paren_depth number Parenthesis nesting depth
---@field in_subquery boolean Currently inside subquery
---@field clause_stack string[] Stack of active clauses
---@field last_token Token? Previous token processed
---@field current_clause string? Current clause being processed
---@field join_modifier string? Pending join modifier (INNER, LEFT, RIGHT, etc.)

---@class FormatterEngine
---Core formatting engine that processes token streams and applies transformation rules.
---Uses best-effort error handling - formats what it can, preserves the rest.
local Engine = {}

local Tokenizer = require('nvim-ssns.completion.tokenizer')
local Output = require('nvim-ssns.formatter.output')
local Stats = require('nvim-ssns.formatter.stats')
local Passes = require('nvim-ssns.formatter.passes')
local EngineCache = require('nvim-ssns.formatter.engine_cache')
local EngineConfig = require('nvim-ssns.formatter.engine_config')
local Helpers = require('nvim-ssns.formatter.engine_helpers')
local Processor = require('nvim-ssns.formatter.engine_processor')

-- High-resolution timer
local hrtime = vim.loop.hrtime

-- Export cache for external use
Engine.cache = EngineCache

-- Local aliases for frequently used helper functions
local create_state = Helpers.create_state
local is_join_modifier = Helpers.is_join_modifier
local is_major_clause = Helpers.is_major_clause

---@class FormatAsyncOpts
---@field dialect string? SQL dialect
---@field skip_stats boolean? Skip stats recording
---@field on_progress fun(stage: string, progress: number, total: number)? Progress callback
---@field on_complete fun(formatted: string)? Completion callback (required)
---@field chunk_size number? Tokenizer chunk size (default 5000)
---@field batch_size number? Token processor batch size (default 500)

---Active async formatting state
---@type { cancelled: boolean, timer: number? }?
Engine._async_state = nil

---Format SQL text asynchronously with progress callbacks
---Uses sync formatting for small files, async pipeline for large files
---@param sql string The SQL text to format
---@param config FormatterConfig The formatter configuration
---@param opts FormatAsyncOpts Options for async formatting
function Engine.format_async(sql, config, opts)
  opts = opts or {}
  local on_progress = opts.on_progress
  local on_complete = opts.on_complete
  local chunk_size = opts.chunk_size or 5000
  local batch_size = opts.batch_size or 500

  -- Cancel any existing async formatting
  Engine.cancel_async_formatting()

  -- Merge config with defaults
  config = EngineConfig.merge_with_defaults(config)

  -- Handle empty input
  if not sql or sql == "" then
    if on_complete then on_complete(sql) end
    return
  end

  local input_size = #sql
  local async_threshold = config.async_threshold_bytes or 50000

  -- For small files, use sync formatting wrapped in schedule
  if input_size <= async_threshold then
    vim.schedule(function()
      local result = Engine.format(sql, config, { skip_stats = opts.skip_stats })
      if on_complete then on_complete(result) end
    end)
    return
  end

  -- Initialize async state
  Engine._async_state = {
    cancelled = false,
    timer = nil,
  }

  local async_state = Engine._async_state
  local total_start = hrtime()

  -- Report progress helper
  local function report_progress(stage, progress, total)
    if on_progress and not async_state.cancelled then
      on_progress(stage, progress, total)
    end
  end

  -- Stage 1: Check cache first
  local cached_tokens = EngineCache.get(sql)
  if cached_tokens then
    report_progress("cache", 1, 1)

    -- Skip directly to processing with cached tokens
    local state = create_state()
    report_progress("processing", 0, #cached_tokens)

    Processor.process_tokens_async(cached_tokens, config, state, {
      batch_size = batch_size,
      on_progress = function(processed, total)
        report_progress("processing", processed, total)
      end,
      on_complete = function(processed_tokens)
        if async_state.cancelled then return end

        -- Run passes async
        report_progress("passes", 0, 9)

        Passes.run_all_async(processed_tokens, config, {
          on_progress = function(pass_name, idx, total)
            report_progress("passes", idx, total)
          end,
          on_complete = function(annotated_tokens)
            if async_state.cancelled then return end

            -- Generate output (sync, usually fast)
            report_progress("output", 0, 1)

            local output_ok, output_or_error = pcall(Output.generate, annotated_tokens, config)
            local result = output_ok and output_or_error or sql

            report_progress("output", 1, 1)

            -- Record stats
            if not opts.skip_stats then
              Stats.record({
                total_ns = hrtime() - total_start,
                input_size = input_size,
                token_count = #cached_tokens,
                cache_hit = true,
              })
            end

            Engine._async_state = nil
            if on_complete then on_complete(result) end
          end,
        })
      end,
    })
    return
  end

  -- Stage 1: Tokenize asynchronously
  report_progress("tokenizing", 0, input_size)

  local tokenize_start = hrtime()

  Tokenizer.tokenize_async(sql, {
    on_progress = function(pct, _message)
      -- Convert percentage to processed/total for consistency with report_progress
      local processed = math.floor(input_size * pct / 100)
      report_progress("tokenizing", processed, input_size)
    end,
    on_complete = function(tokens)
      if async_state.cancelled then return end

      local tokenization_time = hrtime() - tokenize_start

      if not tokens or #tokens == 0 then
        -- Tokenization failed, return original
        if not opts.skip_stats then
          Stats.record({
            total_ns = hrtime() - total_start,
            input_size = input_size,
            cache_hit = false,
          })
        end
        Engine._async_state = nil
        if on_complete then on_complete(sql) end
        return
      end

      -- Cache the tokens
      EngineCache.set(sql, tokens)

      -- Stage 2: Process tokens asynchronously
      local state = create_state()
      local process_start = hrtime()

      report_progress("processing", 0, #tokens)

      Processor.process_tokens_async(tokens, config, state, {
        batch_size = batch_size,
        on_progress = function(processed, total)
          report_progress("processing", processed, total)
        end,
        on_complete = function(processed_tokens)
          if async_state.cancelled then return end

          local processing_time = hrtime() - process_start

          -- Stage 3: Run passes asynchronously
          report_progress("passes", 0, 9)

          Passes.run_all_async(processed_tokens, config, {
            on_progress = function(pass_name, idx, total)
              report_progress("passes", idx, total)
            end,
            on_complete = function(annotated_tokens)
              if async_state.cancelled then return end

              -- Stage 4: Generate output (sync, usually fast)
              report_progress("output", 0, 1)

              local output_start = hrtime()
              local output_ok, output_or_error = pcall(Output.generate, annotated_tokens, config)
              local output_time = hrtime() - output_start

              local result = output_ok and output_or_error or sql

              report_progress("output", 1, 1)

              -- Record stats
              if not opts.skip_stats then
                Stats.record({
                  tokenization_ns = tokenization_time,
                  processing_ns = processing_time,
                  output_ns = output_time,
                  total_ns = hrtime() - total_start,
                  input_size = input_size,
                  token_count = #tokens,
                  cache_hit = false,
                })
              end

              Engine._async_state = nil
              if on_complete then on_complete(result) end
            end,
          })
        end,
      })
    end,
  })
end

---Cancel any in-progress async formatting
function Engine.cancel_async_formatting()
  if Engine._async_state then
    Engine._async_state.cancelled = true
    if Engine._async_state.timer then
      vim.fn.timer_stop(Engine._async_state.timer)
      Engine._async_state.timer = nil
    end
    Engine._async_state = nil
  end

  -- Also cancel any child async operations
  Tokenizer.cancel_chunked_tokenize()
  Processor.cancel_async_processing()
  Passes.cancel_async()
end

---Check if async formatting is currently in progress
---@return boolean
function Engine.is_async_formatting_active()
  return Engine._async_state ~= nil and not Engine._async_state.cancelled
end

---Format SQL text with error recovery
---@param sql string The SQL text to format
---@param config FormatterConfig The formatter configuration
---@param opts? {dialect?: string, skip_stats?: boolean} Optional formatting options
---@return string formatted The formatted SQL text
function Engine.format(sql, config, opts)
  opts = opts or {}
  local skip_stats = opts.skip_stats

  -- Merge config with defaults to ensure all values are present
  config = EngineConfig.merge_with_defaults(config)

  -- Handle empty input
  if not sql or sql == "" then
    return sql
  end

  local total_start = hrtime()
  local tokenization_time = 0
  local processing_time = 0
  local output_time = 0
  local cache_hit = false
  local token_count = 0

  -- Try cache first
  local tokens = EngineCache.get(sql)
  if tokens then
    cache_hit = true
  else
    -- Safe tokenization - return original on failure
    local tokenize_start = hrtime()
    local err
    tokens, err = Helpers.safe_tokenize(Tokenizer, sql)
    tokenization_time = hrtime() - tokenize_start

    if not tokens or #tokens == 0 then
      -- Best effort: return original SQL if tokenization fails
      if not skip_stats then
        Stats.record({
          total_ns = hrtime() - total_start,
          input_size = #sql,
          cache_hit = false,
        })
      end
      return sql
    end

    -- Cache the tokens
    EngineCache.set(sql, tokens)
  end

  token_count = #tokens

  -- Create formatter state
  local state = create_state()

  -- Process tokens with error recovery
  local process_start = hrtime()
  local ok, processed_or_error = pcall(Processor.process_tokens, tokens, config, state)
  processing_time = hrtime() - process_start

  if not ok then
    -- Error during token processing - return original
    if not skip_stats then
      Stats.record({
        tokenization_ns = tokenization_time,
        processing_ns = processing_time,
        total_ns = hrtime() - total_start,
        input_size = #sql,
        token_count = token_count,
        cache_hit = cache_hit,
      })
    end
    return sql
  end

  -- Run all annotation passes in sequence
  -- Passes: clauses -> subqueries -> expressions -> structure -> spacing -> casing
  -- Each pass annotates tokens, building up context for output generation
  local passes_ok, passes_result = pcall(Passes.run_all, processed_or_error, config)
  if passes_ok then
    processed_or_error = passes_result
  end
  -- If passes fail, continue with unannotated tokens (graceful degradation)

  -- Generate output with error recovery
  local output_start = hrtime()
  local output_ok, output_or_error = pcall(Output.generate, processed_or_error, config)
  output_time = hrtime() - output_start

  -- Record stats
  if not skip_stats then
    Stats.record({
      tokenization_ns = tokenization_time,
      processing_ns = processing_time,
      output_ns = output_time,
      total_ns = hrtime() - total_start,
      input_size = #sql,
      token_count = token_count,
      cache_hit = cache_hit,
    })
  end

  if not output_ok then
    -- Error during output generation - return original
    return sql
  end

  return output_or_error
end

return Engine
