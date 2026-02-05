---Fuzzy string matching utility for SSNS IntelliSense
---Used for matching column names across tables in JOIN suggestions
---@class FuzzyMatcher
local FuzzyMatcher = {}

---Normalize a string for comparison
---Converts to lowercase, removes underscores, and strips common prefixes
---@param s string The string to normalize
---@return string normalized The normalized string
function FuzzyMatcher.normalize(s)
  if not s then return "" end
  local result = s:lower()
  result = result:gsub("_", "")  -- Remove underscores
  result = result:gsub("^fk", "")  -- Remove FK prefix
  result = result:gsub("^pk", "")  -- Remove PK prefix
  return result
end

---Calculate Levenshtein distance between two strings
---@param s1 string First string
---@param s2 string Second string
---@return number distance The edit distance
local function levenshtein_distance(s1, s2)
  local len1, len2 = #s1, #s2

  -- Handle edge cases
  if len1 == 0 then return len2 end
  if len2 == 0 then return len1 end
  if s1 == s2 then return 0 end

  -- Create distance matrix
  local matrix = {}
  for i = 0, len1 do
    matrix[i] = { [0] = i }
  end
  for j = 0, len2 do
    matrix[0][j] = j
  end

  -- Fill in the matrix
  for i = 1, len1 do
    for j = 1, len2 do
      local cost = (s1:sub(i, i) == s2:sub(j, j)) and 0 or 1
      matrix[i][j] = math.min(
        matrix[i - 1][j] + 1,       -- deletion
        matrix[i][j - 1] + 1,       -- insertion
        matrix[i - 1][j - 1] + cost -- substitution
      )
    end
  end

  return matrix[len1][len2]
end

---Calculate similarity score between two strings (0.0 to 1.0)
---1.0 means identical (after normalization), 0.0 means completely different
---@param s1 string First string
---@param s2 string Second string
---@return number score Similarity score between 0 and 1
function FuzzyMatcher.similarity(s1, s2)
  if not s1 or not s2 then return 0 end

  -- Normalize both strings
  local norm1 = FuzzyMatcher.normalize(s1)
  local norm2 = FuzzyMatcher.normalize(s2)

  -- Empty strings after normalization
  if #norm1 == 0 or #norm2 == 0 then
    return (#norm1 == #norm2) and 1.0 or 0.0
  end

  -- Identical after normalization = perfect match
  if norm1 == norm2 then
    return 1.0
  end

  -- Calculate Levenshtein distance
  local distance = levenshtein_distance(norm1, norm2)
  local max_len = math.max(#norm1, #norm2)

  -- Convert distance to similarity (0 distance = 1.0 similarity)
  return 1.0 - (distance / max_len)
end

---Check if two strings are a fuzzy match above a threshold
---@param s1 string First string
---@param s2 string Second string
---@param threshold number? Minimum similarity score (default 0.85)
---@return boolean is_match True if similarity >= threshold
---@return number score The actual similarity score
function FuzzyMatcher.is_match(s1, s2, threshold)
  threshold = threshold or 0.85
  local score = FuzzyMatcher.similarity(s1, s2)
  return score >= threshold, score
end

---Find all fuzzy matches for a string in a list
---@param needle string The string to match
---@param haystack string[] List of strings to search
---@param threshold number? Minimum similarity score (default 0.85)
---@return table[] matches Array of {value, score} sorted by score descending
function FuzzyMatcher.find_matches(needle, haystack, threshold)
  threshold = threshold or 0.85
  local matches = {}

  for _, value in ipairs(haystack) do
    local score = FuzzyMatcher.similarity(needle, value)
    if score >= threshold then
      table.insert(matches, {
        value = value,
        score = score,
      })
    end
  end

  -- Sort by score descending
  table.sort(matches, function(a, b)
    return a.score > b.score
  end)

  return matches
end

---Extract common suffix from column name (ID, Name, Date, etc.)
---@param name string Column name
---@return string base Base name without suffix
---@return string? suffix The suffix if found
local function extract_suffix(name)
  local suffixes = { "id", "name", "date", "time", "code", "num", "no", "key", "ref", "type" }
  local lower = name:lower()

  for _, suffix in ipairs(suffixes) do
    if lower:sub(-#suffix) == suffix and #lower > #suffix then
      return name:sub(1, -#suffix - 1), suffix
    end
  end

  return name, nil
end

---Check if one string is an abbreviation of another
---E.g., "Emp" is abbreviation of "Employee", "CustID" of "CustomerID"
---@param short string Potential abbreviation
---@param long string Full string
---@return boolean is_abbrev True if short is likely an abbreviation of long
---@return number score Confidence score (0.8-0.95)
local function is_abbreviation(short, long)
  if #short >= #long then
    return false, 0
  end

  local short_lower = short:lower()
  local long_lower = long:lower()

  -- Must start with the same character
  if short_lower:sub(1, 1) ~= long_lower:sub(1, 1) then
    return false, 0
  end

  -- Check if short is a prefix of long
  if long_lower:sub(1, #short_lower) == short_lower then
    -- Exact prefix match (e.g., "Emp" prefix of "Employee")
    local ratio = #short / #long
    if ratio >= 0.5 then
      return true, 0.92  -- High confidence for 50%+ prefix
    elseif ratio >= 0.3 then
      return true, 0.88  -- Medium confidence for 30%+ prefix
    end
    return false, 0
  end

  -- Check for consonant-based abbreviation (e.g., "Cust" from "Customer")
  -- Extract consonants from long string and see if short matches the start
  local consonants = long_lower:gsub("[aeiou]", "")
  if #consonants >= 2 and consonants:sub(1, math.min(#short_lower, #consonants)) == short_lower:sub(1, math.min(#short_lower, #consonants)) then
    local ratio = #short / #long
    if ratio >= 0.4 then
      return true, 0.85
    end
  end

  return false, 0
end

---Compare column names for JOIN matching
---Special handling for common column naming patterns
---@param col1_name string First column name
---@param col2_name string Second column name
---@param threshold number? Minimum similarity score (default 0.85)
---@return boolean is_match True if columns likely refer to same concept
---@return number score The similarity score
function FuzzyMatcher.match_columns(col1_name, col2_name, threshold)
  threshold = threshold or 0.85

  -- First check: exact match (case-insensitive)
  if col1_name:lower() == col2_name:lower() then
    return true, 1.0
  end

  -- Second check: normalized match (handles Employee_ID vs EmployeeId)
  local norm1 = FuzzyMatcher.normalize(col1_name)
  local norm2 = FuzzyMatcher.normalize(col2_name)

  if norm1 == norm2 then
    return true, 1.0
  end

  -- Third check: suffix-based matching
  -- Extract common suffixes (ID, Name, etc.) and compare bases
  local base1, suffix1 = extract_suffix(norm1)
  local base2, suffix2 = extract_suffix(norm2)

  -- If both have the same suffix, compare the bases
  if suffix1 and suffix2 and suffix1 == suffix2 then
    -- Check if bases are similar or one is abbreviation of other
    if base1 == base2 then
      return true, 0.98
    end

    -- Check abbreviation (shorter is abbrev of longer)
    local is_abbrev, abbrev_score
    if #base1 < #base2 then
      is_abbrev, abbrev_score = is_abbreviation(base1, base2)
    else
      is_abbrev, abbrev_score = is_abbreviation(base2, base1)
    end

    if is_abbrev and abbrev_score >= threshold then
      return true, abbrev_score
    end

    -- Check base similarity
    local base_similarity = FuzzyMatcher.similarity(base1, base2)
    if base_similarity >= threshold then
      return true, base_similarity
    end
  end

  -- Fourth check: abbreviation matching (without suffix extraction)
  local is_abbrev, abbrev_score
  if #norm1 < #norm2 then
    is_abbrev, abbrev_score = is_abbreviation(norm1, norm2)
  else
    is_abbrev, abbrev_score = is_abbreviation(norm2, norm1)
  end

  if is_abbrev and abbrev_score >= threshold then
    return true, abbrev_score
  end

  -- Fifth check: general fuzzy match
  local score = FuzzyMatcher.similarity(col1_name, col2_name)
  return score >= threshold, score
end

return FuzzyMatcher
