---Type compatibility checking for SSNS IntelliSense
---Used to warn users when comparing incompatible column types in WHERE/ON clauses
---@class TypeCompatibility
local TypeCompatibility = {}

---Type categories for compatibility checking
---Types within the same category are generally compatible
TypeCompatibility.categories = {
  numeric = {
    -- SQL Server
    "int", "bigint", "smallint", "tinyint",
    "decimal", "numeric", "float", "real",
    "money", "smallmoney",
    -- PostgreSQL
    "integer", "smallserial", "bigserial", "serial",
    "double precision",
    -- MySQL
    "mediumint",
    -- SQLite
    "integer", "real",
  },

  string = {
    -- SQL Server
    "varchar", "nvarchar", "char", "nchar",
    "text", "ntext",
    -- PostgreSQL
    "character varying", "character",
    -- MySQL/SQLite
    "text", "longtext", "mediumtext", "tinytext",
  },

  temporal = {
    -- SQL Server
    "date", "time", "datetime", "datetime2",
    "datetimeoffset", "smalldatetime",
    -- PostgreSQL
    "timestamp", "timestamp without time zone",
    "timestamp with time zone", "interval",
    -- MySQL
    "year",
  },

  binary = {
    -- SQL Server
    "binary", "varbinary", "image",
    -- PostgreSQL
    "bytea",
    -- MySQL
    "blob", "longblob", "mediumblob", "tinyblob",
  },

  boolean = {
    "bit", "bool", "boolean",
  },

  uuid = {
    "uniqueidentifier", "uuid",
  },

  json = {
    "json", "jsonb",
  },

  xml = {
    "xml",
  },
}

---Normalize a type name for comparison
---Removes size parameters, converts to lowercase
---@param type_name string The type name (e.g., "varchar(50)")
---@return string normalized The normalized type (e.g., "varchar")
function TypeCompatibility.normalize_type(type_name)
  if not type_name then return "" end
  local result = type_name:lower()
  -- Remove size/precision parameters: varchar(50) -> varchar
  result = result:gsub("%s*%([^)]*%)", "")
  -- Remove trailing spaces
  result = result:gsub("%s+$", "")
  return result
end

---Get the category of a type
---@param type_name string The type name
---@return string|nil category The category name, or nil if unknown
function TypeCompatibility.get_category(type_name)
  local normalized = TypeCompatibility.normalize_type(type_name)

  for category, types in pairs(TypeCompatibility.categories) do
    for _, t in ipairs(types) do
      if t == normalized then
        return category
      end
    end
  end

  return nil
end

---Check if two types are compatible for comparison
---@param type1 string First type (e.g., "int")
---@param type2 string Second type (e.g., "bigint")
---@return boolean compatible True if types are compatible
---@return string|nil warning Warning message if not fully compatible
function TypeCompatibility.are_compatible(type1, type2)
  if not type1 or not type2 then
    return true, nil  -- Can't determine, assume compatible
  end

  local norm1 = TypeCompatibility.normalize_type(type1)
  local norm2 = TypeCompatibility.normalize_type(type2)

  -- Exact match after normalization
  if norm1 == norm2 then
    return true, nil
  end

  -- Get categories
  local cat1 = TypeCompatibility.get_category(norm1)
  local cat2 = TypeCompatibility.get_category(norm2)

  -- Unknown types - assume compatible
  if not cat1 or not cat2 then
    return true, nil
  end

  -- Same category = compatible
  if cat1 == cat2 then
    return true, nil
  end

  -- Special cases: some cross-category comparisons work but should warn

  -- Numeric to boolean (bit) - works but may not be intentional
  if (cat1 == "numeric" and cat2 == "boolean") or
     (cat1 == "boolean" and cat2 == "numeric") then
    return true, string.format("Implicit conversion: %s to %s", type1, type2)
  end

  -- String to numeric - usually an error
  if (cat1 == "string" and cat2 == "numeric") or
     (cat1 == "numeric" and cat2 == "string") then
    return false, string.format("Type mismatch: %s vs %s (may cause conversion error)", type1, type2)
  end

  -- String to temporal - common but can fail
  if (cat1 == "string" and cat2 == "temporal") or
     (cat1 == "temporal" and cat2 == "string") then
    return true, string.format("Implicit conversion: %s to %s (format must match)", type1, type2)
  end

  -- Different categories - incompatible
  return false, string.format("Type mismatch: %s vs %s", type1, type2)
end

---Get compatibility info for display
---@param type1 string First type
---@param type2 string Second type
---@return table info {compatible: boolean, warning: string|nil, icon: string}
function TypeCompatibility.get_info(type1, type2)
  local compatible, warning = TypeCompatibility.are_compatible(type1, type2)

  local icon = "✓"
  if not compatible then
    icon = "⚠️"
  elseif warning then
    icon = "⚡"  -- implicit conversion
  end

  return {
    compatible = compatible,
    warning = warning,
    icon = icon,
  }
end

---Check if a type is a string type
---@param type_name string The type name
---@return boolean is_string
function TypeCompatibility.is_string_type(type_name)
  return TypeCompatibility.get_category(type_name) == "string"
end

---Check if a type is a numeric type
---@param type_name string The type name
---@return boolean is_numeric
function TypeCompatibility.is_numeric_type(type_name)
  return TypeCompatibility.get_category(type_name) == "numeric"
end

---Check if a type is a temporal/date type
---@param type_name string The type name
---@return boolean is_temporal
function TypeCompatibility.is_temporal_type(type_name)
  return TypeCompatibility.get_category(type_name) == "temporal"
end

return TypeCompatibility
