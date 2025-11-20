---@class QueryParser
---Comprehensive SQL query parser with full context awareness
---Handles: comments, strings, brackets, USE statements, GO separators
local QueryParser = {}

---Remove all SQL comments from query
---Properly handles strings, brackets, and nested comments
---Removes -- comments FIRST, then /* */ to handle --/* correctly
---@param query string The SQL query
---@return string cleaned Query with comments removed
---@return table debug_info Debug information about what was removed
function QueryParser.remove_comments(query)
  local result = {}
  local i = 1
  local len = #query

  -- State tracking
  local state = {
    in_string = false,
    string_delimiter = nil,
    in_bracket = false,
    in_line_comment = false,
    in_block_comment = false,
    block_comment_depth = 0
  }

  -- Debug info
  local debug = {
    line_comments_removed = 0,
    block_comments_removed = 0,
    nested_depth_max = 0
  }

  while i <= len do
    local char = query:sub(i, i)
    local next_char = query:sub(i + 1, i + 1)

    -- ====================
    -- PHASE 1: Handle Line Comments (-- ... \n)
    -- Process FIRST to handle --/* case
    -- ====================

    if state.in_line_comment then
      -- We're in a line comment, skip until newline
      if char == "\n" or char == "\r" then
        -- End of line comment
        state.in_line_comment = false
        -- Preserve the newline
        table.insert(result, char)
      end
      -- Skip all other characters in line comment
      i = i + 1
      goto continue
    end

    -- Check for start of line comment
    -- Only if NOT in string, bracket, or block comment
    if not state.in_string
       and not state.in_bracket
       and not state.in_block_comment
       and char == "-"
       and next_char == "-" then
      -- Start of line comment
      state.in_line_comment = true
      debug.line_comments_removed = debug.line_comments_removed + 1
      i = i + 2  -- Skip both dashes
      goto continue
    end

    -- ====================
    -- PHASE 2: Handle Block Comments (/* ... */)
    -- Process AFTER line comments
    -- ====================

    if state.in_block_comment then
      -- We're inside a block comment

      -- Check for nested /* (SQL Server supports this!)
      if char == "/" and next_char == "*" then
        state.block_comment_depth = state.block_comment_depth + 1
        debug.nested_depth_max = math.max(debug.nested_depth_max, state.block_comment_depth)
        i = i + 2
        goto continue
      end

      -- Check for closing */
      if char == "*" and next_char == "/" then
        state.block_comment_depth = state.block_comment_depth - 1

        if state.block_comment_depth == 0 then
          -- Completely out of block comment
          state.in_block_comment = false
        end

        i = i + 2
        goto continue
      end

      -- Inside comment, skip character
      i = i + 1
      goto continue
    end

    -- Check for start of block comment
    -- Only if NOT in string, bracket, or line comment
    if not state.in_string
       and not state.in_bracket
       and char == "/"
       and next_char == "*" then
      -- Start of block comment
      state.in_block_comment = true
      state.block_comment_depth = 1
      debug.block_comments_removed = debug.block_comments_removed + 1
      i = i + 2
      goto continue
    end

    -- ====================
    -- PHASE 3: Handle String Literals ('...' and "...")
    -- Must handle escaped quotes ('' and "")
    -- ====================

    if state.in_string then
      -- We're inside a string literal
      table.insert(result, char)

      -- Check for end of string or escaped quote
      if char == state.string_delimiter then
        if next_char == state.string_delimiter then
          -- Escaped quote (doubled) - stay in string
          -- Add the next quote too
          table.insert(result, next_char)
          i = i + 2
          goto continue
        else
          -- End of string
          state.in_string = false
          state.string_delimiter = nil
        end
      end

      i = i + 1
      goto continue
    end

    -- Check for start of string (only if not in bracket or comment)
    if not state.in_bracket
       and (char == "'" or char == '"') then
      -- Start of string literal
      state.in_string = true
      state.string_delimiter = char
      table.insert(result, char)
      i = i + 1
      goto continue
    end

    -- ====================
    -- PHASE 4: Handle Bracketed Identifiers ([...])
    -- For object names with special characters
    -- ====================

    if state.in_bracket then
      -- We're inside a bracketed identifier
      table.insert(result, char)

      if char == "]" then
        -- Check for escaped bracket (]])
        if next_char == "]" then
          -- Escaped bracket - stay in bracket mode
          table.insert(result, next_char)
          i = i + 2
          goto continue
        else
          -- End of bracketed identifier
          state.in_bracket = false
        end
      end

      i = i + 1
      goto continue
    end

    -- Check for start of bracketed identifier
    if char == "[" then
      state.in_bracket = true
      table.insert(result, char)
      i = i + 1
      goto continue
    end

    -- ====================
    -- PHASE 5: Regular Character (not in any special context)
    -- ====================

    table.insert(result, char)
    i = i + 1

    ::continue::
  end

  return table.concat(result), debug
end

---Extract database name after USE keyword
---Handles: USE DB, USE [DB], USE DB;
---@param query string Full query
---@param start_pos number Position after USE keyword
---@return string|nil db_name Database name if found
---@return number end_pos Position after USE statement
function QueryParser.extract_database_name(query, start_pos)
  local i = start_pos
  local len = #query

  -- Skip whitespace after USE
  while i <= len and query:sub(i, i):match("%s") do
    i = i + 1
  end

  if i > len then
    return nil, start_pos
  end

  local db_name = {}
  local in_bracket = false

  -- Parse database name
  while i <= len do
    local char = query:sub(i, i)
    local next_char = query:sub(i + 1, i + 1)

    if in_bracket then
      -- Inside [DatabaseName]
      if char == "]" then
        if next_char == "]" then
          -- Escaped bracket
          table.insert(db_name, char)
          i = i + 2
        else
          -- End of bracketed name
          in_bracket = false
          i = i + 1
          break
        end
      else
        table.insert(db_name, char)
        i = i + 1
      end
    else
      -- Not in bracket
      if char == "[" then
        -- Start of bracketed name
        in_bracket = true
        i = i + 1
      elseif char:match("[%w_]") then
        -- Regular identifier character
        table.insert(db_name, char)
        i = i + 1
      elseif char == ";" or char:match("%s") then
        -- End of database name
        break
      else
        -- Invalid character
        return nil, start_pos
      end
    end
  end

  -- Skip optional semicolon and whitespace
  while i <= len and query:sub(i, i):match("%s") do
    i = i + 1
  end
  if i <= len and query:sub(i, i) == ";" then
    i = i + 1
  end

  if #db_name == 0 then
    return nil, start_pos
  end

  return table.concat(db_name), i
end

---Parse USE statements from query, respecting context
---Only detects USE statements outside of strings, comments, and brackets
---Splits query into chunks at USE boundaries, tracking line numbers accurately
---@param query string The SQL query (WITH comments preserved!)
---@return table chunks Array of {database: string|nil, sql: string, has_use: boolean, start_line: number}
function QueryParser.parse_use_statements(query)
  -- PASS 1: Find all USE statements and their positions
  local use_positions = {}  -- Array of {start_pos, end_pos, database, line_num}

  local i = 1
  local len = #query
  local current_line = 1

  -- State tracking
  local state = {
    in_string = false,
    string_delimiter = nil,
    in_bracket = false,
    in_line_comment = false,
    in_block_comment = false,
    block_comment_depth = 0
  }

  -- Track current word
  local word_start = nil
  local word_chars = {}

  while i <= len do
    local char = query:sub(i, i)
    local next_char = query:sub(i + 1, i + 1)

    -- Track line numbers
    if char == "\n" then
      current_line = current_line + 1
    end

    -- Handle comments (skip them)
    if state.in_line_comment then
      if char == "\n" or char == "\r" then
        state.in_line_comment = false
      end
      i = i + 1
      goto continue
    end

    if state.in_block_comment then
      if char == "/" and next_char == "*" then
        state.block_comment_depth = state.block_comment_depth + 1
        i = i + 2
        goto continue
      end
      if char == "*" and next_char == "/" then
        state.block_comment_depth = state.block_comment_depth - 1
        if state.block_comment_depth == 0 then
          state.in_block_comment = false
        end
        i = i + 2
        goto continue
      end
      i = i + 1
      goto continue
    end

    if not state.in_string and not state.in_bracket and char == "-" and next_char == "-" then
      state.in_line_comment = true
      i = i + 2
      goto continue
    end

    if not state.in_string and not state.in_bracket and char == "/" and next_char == "*" then
      state.in_block_comment = true
      state.block_comment_depth = 1
      i = i + 2
      goto continue
    end

    -- Handle strings
    if state.in_string then
      if char == state.string_delimiter then
        if next_char == state.string_delimiter then
          i = i + 2
          goto continue
        else
          state.in_string = false
          state.string_delimiter = nil
        end
      end
      i = i + 1
      goto continue
    end

    if not state.in_bracket and (char == "'" or char == '"') then
      state.in_string = true
      state.string_delimiter = char
      i = i + 1
      goto continue
    end

    -- Handle brackets
    if state.in_bracket then
      if char == "]" then
        if next_char == "]" then
          i = i + 2
          goto continue
        else
          state.in_bracket = false
        end
      end
      i = i + 1
      goto continue
    end

    if char == "[" then
      state.in_bracket = true
      i = i + 1
      goto continue
    end

    -- Detect USE statements (only when not in string/comment/bracket)
    local is_word_char = char:match("[%w_]") ~= nil

    if is_word_char then
      if not word_start then
        word_start = i
      end
      table.insert(word_chars, char:upper())
    else
      if word_start then
        local word = table.concat(word_chars)
        if word == "USE" then
          -- Found USE! Extract database name
          local db_name, use_end_pos = QueryParser.extract_database_name(query, i)
          if db_name then
            table.insert(use_positions, {
              start_pos = word_start,
              end_pos = use_end_pos,
              database = db_name,
              line_num = current_line
            })
            i = use_end_pos
            word_start = nil
            word_chars = {}
            goto continue
          end
        end
        word_start = nil
        word_chars = {}
      end
    end

    i = i + 1
    ::continue::
  end

  -- PASS 2: Split query into chunks at USE positions
  return QueryParser.split_query_at_use_statements(query, use_positions)
end

---Split query into chunks based on USE statement positions
---@param query string Original query
---@param use_positions table Array of USE statement positions
---@return table chunks Array of chunks with start_line tracking
function QueryParser.split_query_at_use_statements(query, use_positions)
  local chunks = {}

  -- If no USE statements, return entire query as one chunk
  if #use_positions == 0 then
    return {{
      sql = query,
      database = nil,
      has_use = false,
      start_line = 1
    }}
  end

  -- Track current position and line
  local current_pos = 1
  local current_line = 1
  local current_database = nil

  for _, use_info in ipairs(use_positions) do
    -- Add chunk before this USE statement (if any content)
    if use_info.start_pos > current_pos then
      local chunk_sql = query:sub(current_pos, use_info.start_pos - 1)
      local trimmed = chunk_sql:match("^%s*(.-)%s*$")

      if trimmed and trimmed ~= "" then
        table.insert(chunks, {
          sql = chunk_sql,  -- Keep original with whitespace for line numbers
          database = current_database,
          has_use = false,
          start_line = current_line
        })
      end
    end

    -- Add database switch chunk
    table.insert(chunks, {
      sql = "",
      database = use_info.database,
      has_use = true,
      start_line = use_info.line_num
    })

    current_database = use_info.database

    -- Count lines from current_pos to end of USE statement
    for i = current_pos, use_info.end_pos - 1 do
      if query:sub(i, i) == "\n" then
        current_line = current_line + 1
      end
    end

    current_pos = use_info.end_pos
  end

  -- Add final chunk after last USE statement
  if current_pos <= #query then
    local chunk_sql = query:sub(current_pos)
    local trimmed = chunk_sql:match("^%s*(.-)%s*$")

    if trimmed and trimmed ~= "" then
      table.insert(chunks, {
        sql = chunk_sql,  -- Keep original with whitespace
        database = current_database,
        has_use = false,
        start_line = current_line
      })
    end
  end

  return chunks
end

---OLD FUNCTION BELOW - TO BE DELETED
function QueryParser.OLD_parse_use_statements_DELETE_ME(query)
  local i = 1
  local len = #query

  -- State tracking (same as remove_comments but we DON'T remove)
  local state = {
    in_string = false,
    string_delimiter = nil,
    in_bracket = false,
    in_line_comment = false,
    in_block_comment = false,
    block_comment_depth = 0
  }

  -- Track current word for USE detection
  local word_start = nil
  local current_word = {}

  while i <= len do
    local char = query:sub(i, i)
    local next_char = query:sub(i + 1, i + 1)

    -- ====================
    -- Track Line Comments (don't remove, just skip parsing)
    -- ====================
    if state.in_line_comment then
      if char == "\n" or char == "\r" then
        state.in_line_comment = false
      end
      i = i + 1
      goto continue
    end

    if not state.in_string and not state.in_bracket and not state.in_block_comment
       and char == "-" and next_char == "-" then
      state.in_line_comment = true
      i = i + 2
      goto continue
    end

    -- ====================
    -- Track Block Comments (don't remove, just skip parsing)
    -- ====================
    if state.in_block_comment then
      if char == "/" and next_char == "*" then
        state.block_comment_depth = state.block_comment_depth + 1
        i = i + 2
        goto continue
      end
      if char == "*" and next_char == "/" then
        state.block_comment_depth = state.block_comment_depth - 1
        if state.block_comment_depth == 0 then
          state.in_block_comment = false
        end
        i = i + 2
        goto continue
      end
      i = i + 1
      goto continue
    end

    if not state.in_string and not state.in_bracket
       and char == "/" and next_char == "*" then
      state.in_block_comment = true
      state.block_comment_depth = 1
      i = i + 2
      goto continue
    end

    -- ====================
    -- Handle String Literals
    -- ====================

    if state.in_string then

      if char == state.string_delimiter then
        if next_char == state.string_delimiter then
          -- Escaped quote
          table.insert(current_chunk, next_char)
          i = i + 2
          goto continue
        else
          -- End of string
          state.in_string = false
          state.string_delimiter = nil
        end
      end

      i = i + 1
      goto continue
    end

    if not state.in_bracket and (char == "'" or char == '"') then
      -- Start of string
      state.in_string = true
      state.string_delimiter = char
      table.insert(current_chunk, char)
      i = i + 1
      goto continue
    end

    -- ====================
    -- Handle Bracketed Identifiers
    -- ====================

    if state.in_bracket then
      table.insert(current_chunk, char)

      if char == "]" then
        if next_char == "]" then
          -- Escaped bracket
          table.insert(current_chunk, next_char)
          i = i + 2
          goto continue
        else
          state.in_bracket = false
        end
      end

      i = i + 1
      goto continue
    end

    if char == "[" then
      state.in_bracket = true
      table.insert(current_chunk, char)
      i = i + 1
      goto continue
    end

    -- ====================
    -- Detect USE Statements
    -- Must be at word boundary (start of line or after whitespace)
    -- ====================

    -- Check if we're at a potential word boundary
    local is_word_char = char:match("[%w_]") ~= nil

    if is_word_char then
      -- Building a word
      if not word_start then
        word_start = i
      end
      table.insert(current_word, char:upper())  -- Case insensitive
    else
      -- End of word (or not in word)
      if word_start then
        -- We just finished a word
        local word = table.concat(current_word)

        -- Check if it's USE
        if word == "USE" then
          -- Found USE statement!
          -- Extract database name
          local db_name, use_end_pos = QueryParser.extract_database_name(query, i)

          if db_name then
            -- Save current chunk (before USE)
            local chunk_text = table.concat(current_chunk):match("^%s*(.-)%s*$")
            if chunk_text and chunk_text ~= "" then
              table.insert(chunks, {
                database = nil,
                sql = chunk_text,
                has_use = false,
                start_line = chunk_start_line or 1
              })
            end
            current_chunk = {}

            -- Create chunk for database switch
            table.insert(chunks, {
              database = db_name,
              sql = "",
              has_use = true,
              start_line = current_line
            })

            -- Next chunk will start on the next line (or later if there are empty lines)
            -- We'll update chunk_start_line when we encounter the first non-whitespace
            chunk_start_line = nil  -- Mark as "needs to be set"

            -- Count newlines in the skipped portion (from current i to use_end_pos)
            for skip_i = i, use_end_pos - 1 do
              if query:sub(skip_i, skip_i) == "\n" then
                current_line = current_line + 1
              end
            end

            -- Skip to after USE statement
            i = use_end_pos
            word_start = nil
            current_word = {}
            goto continue
          end
        end

        -- Not USE, or failed to parse - add word to chunk
        for j = word_start, i - 1 do
          table.insert(current_chunk, query:sub(j, j))
        end

        word_start = nil
        current_word = {}
      end

      -- Add current character to chunk
      table.insert(current_chunk, char)

      -- Set chunk_start_line on first non-whitespace character
      if chunk_start_line == nil and char:match("%S") then
        chunk_start_line = current_line
      end
    end

    -- Track line numbers
    if char == "\n" then
      current_line = current_line + 1
    end

    i = i + 1

    ::continue::
  end

  -- Add final chunk
  local final_text = table.concat(current_chunk):match("^%s*(.-)%s*$")
  if final_text and final_text ~= "" then
    table.insert(chunks, {
      database = nil,
      sql = final_text,
      has_use = false,
      start_line = chunk_start_line or 1
    })
  end

  return chunks
end

---Split query by GO separators (SSMS-specific)
---GO must be on its own line (with optional whitespace)
---@param query string The SQL query
---@return table batches Array of {sql: string, start_line: number}
function QueryParser.split_by_go(query)
  local batches = {}
  local current_batch = {}
  local current_line = 1
  local batch_start_line = 1

  -- Split into lines
  for line in query:gmatch("[^\r\n]+") do
    -- Check if line is just GO (case-insensitive, optional whitespace)
    if line:match("^%s*[Gg][Oo]%s*$") then
      -- This is a GO separator
      if #current_batch > 0 then
        table.insert(batches, {
          sql = table.concat(current_batch, "\n"),
          start_line = batch_start_line
        })
        current_batch = {}
      end
      -- Next batch starts on the next line
      batch_start_line = current_line + 1
    else
      -- Regular line
      table.insert(current_batch, line)
    end
    current_line = current_line + 1
  end

  -- Add final batch
  if #current_batch > 0 then
    table.insert(batches, {
      sql = table.concat(current_batch, "\n"),
      start_line = batch_start_line
    })
  end

  -- If no GO found, return entire query
  if #batches == 0 then
    return {{sql = query, start_line = 1}}
  end

  return batches
end

---Complete query preprocessing and parsing
---@param query string Raw SQL query
---@param buffer_database string|nil Current buffer database context
---@return table chunks Array of execution chunks with database context
---@return table debug_info Debug information
function QueryParser.parse_query(query, buffer_database)
  -- Step 1: Split by GO separators (keep comments for line number accuracy)
  local go_batches = QueryParser.split_by_go(query)

  -- Step 2: Parse USE statements in each batch (context-aware, preserves comments)
  local all_chunks = {}
  local current_database = buffer_database

  for batch_idx, batch in ipairs(go_batches) do
    local use_chunks = QueryParser.parse_use_statements(batch.sql)
    local batch_start_line = batch.start_line or 1

    for _, chunk in ipairs(use_chunks) do
      if chunk.has_use then
        -- This chunk is a database switch
        current_database = chunk.database
      else
        -- Regular SQL chunk
        if chunk.sql and chunk.sql ~= "" then
          -- Adjust chunk start_line to account for batch offset in original query
          local absolute_start_line = (chunk.start_line or 1) + batch_start_line - 1

          -- DEBUG: Log chunk creation
          vim.notify(string.format("DEBUG: Creating chunk - batch_start=%d, chunk_start=%d, absolute=%d, sql=%s",
            batch_start_line, chunk.start_line or 1, absolute_start_line,
            chunk.sql:sub(1, 50):gsub("\n", " ")), vim.log.levels.INFO)

          table.insert(all_chunks, {
            sql = chunk.sql,
            database = current_database,
            original_had_use = chunk.has_use,
            batch_number = batch_idx,
            start_line = absolute_start_line
          })
        end
      end
    end
  end

  return all_chunks, {
    comments_removed = comment_debug,
    go_batches = #go_batches,
    total_chunks = #all_chunks
  }
end

return QueryParser
