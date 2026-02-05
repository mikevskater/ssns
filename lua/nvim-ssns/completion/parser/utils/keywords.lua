---Keywords module for SQL statement parsing
---Provides keyword tables and helper functions for identifying SQL keywords
---
---@module ssns.completion.parser.utils.keywords

local Keywords = {}

---Keywords that start a new SQL statement
Keywords.STATEMENT_STARTERS = {
  SELECT = true, INSERT = true, UPDATE = true, DELETE = true,
  MERGE = true, CREATE = true, ALTER = true, DROP = true,
  TRUNCATE = true, WITH = true, EXEC = true, EXECUTE = true,
  DECLARE = true, SET = true,
}

---Keywords that indicate we're in a FROM/JOIN context
Keywords.FROM_KEYWORDS = {
  FROM = true,
  JOIN = true,
  INNER = true,
  LEFT = true,
  RIGHT = true,
  FULL = true,
  CROSS = true,
  OUTER = true,
}

---Keywords that can appear as JOIN modifiers
Keywords.JOIN_MODIFIERS = {
  INNER = true,
  LEFT = true,
  RIGHT = true,
  FULL = true,
  CROSS = true,
  OUTER = true,
}

---Keywords that terminate FROM/JOIN clause parsing
Keywords.FROM_TERMINATORS = {
  WHERE = true,
  GROUP = true,
  HAVING = true,
  ORDER = true,
  LIMIT = true,
  OFFSET = true,
  FETCH = true,
  FOR = true,       -- FOR UPDATE, FOR XML, etc.
  OPTION = true,    -- Query hints
}

---Check if keyword starts a new statement
---@param keyword string
---@return boolean
function Keywords.is_statement_starter(keyword)
  return Keywords.STATEMENT_STARTERS[keyword:upper()] == true
end

---Check if keyword is FROM or JOIN related
---@param keyword string
---@return boolean
function Keywords.is_from_keyword(keyword)
  return Keywords.FROM_KEYWORDS[keyword:upper()] == true
end

---Check if keyword terminates FROM clause
---@param keyword string
---@return boolean
function Keywords.is_from_terminator(keyword)
  return Keywords.FROM_TERMINATORS[keyword:upper()] == true
end

---Check if keyword is a JOIN modifier
---@param keyword string
---@return boolean
function Keywords.is_join_modifier(keyword)
  return Keywords.JOIN_MODIFIERS[keyword:upper()] == true
end

return Keywords
