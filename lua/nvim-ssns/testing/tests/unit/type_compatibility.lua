-- Test file: type_compatibility.lua
-- IDs: 3801-3900
-- Tests: TypeCompatibility utility module for SQL type checking
--
-- Test categories:
-- - 3801-3820: Type normalization
-- - 3821-3845: Category detection
-- - 3846-3865: Same category compatibility
-- - 3866-3885: Cross-category compatibility
-- - 3886-3900: Info and helper functions

return {
  -- ========================================
  -- Type Normalization Tests (3801-3820)
  -- ========================================
  {
    id = 3801,
    type = "type_compatibility",
    name = "Normalize removes size parameter from varchar",
    input = { type_name = "varchar(50)" },
    expected = {
      normalized = "varchar",
    },
  },
  {
    id = 3802,
    type = "type_compatibility",
    name = "Normalize removes precision from decimal",
    input = { type_name = "decimal(18,2)" },
    expected = {
      normalized = "decimal",
    },
  },
  {
    id = 3803,
    type = "type_compatibility",
    name = "Normalize converts to lowercase",
    input = { type_name = "VARCHAR" },
    expected = {
      normalized = "varchar",
    },
  },
  {
    id = 3804,
    type = "type_compatibility",
    name = "Normalize handles multiple spaces",
    input = { type_name = "  VARCHAR  (  50  )  " },
    expected = {
      normalized = "varchar",
    },
  },
  {
    id = 3805,
    type = "type_compatibility",
    name = "Normalize type without parameters",
    input = { type_name = "int" },
    expected = {
      normalized = "int",
    },
  },
  {
    id = 3806,
    type = "type_compatibility",
    name = "Normalize handles nil input",
    input = { type_name = nil },
    expected = {
      normalized = nil,
    },
  },
  {
    id = 3807,
    type = "type_compatibility",
    name = "Normalize handles empty string",
    input = { type_name = "" },
    expected = {
      normalized = "",
    },
  },
  {
    id = 3808,
    type = "type_compatibility",
    name = "Normalize complex type nvarchar(max)",
    input = { type_name = "nvarchar(max)" },
    expected = {
      normalized = "nvarchar",
    },
  },
  {
    id = 3809,
    type = "type_compatibility",
    name = "Normalize SQL Server datetime2 with precision",
    input = { type_name = "datetime2(7)" },
    expected = {
      normalized = "datetime2",
    },
  },
  {
    id = 3810,
    type = "type_compatibility",
    name = "Normalize PostgreSQL character varying",
    input = { type_name = "character varying(100)" },
    expected = {
      normalized = "character varying",
    },
  },
  {
    id = 3811,
    type = "type_compatibility",
    name = "Normalize MySQL int with display width",
    input = { type_name = "int(11)" },
    expected = {
      normalized = "int",
    },
  },
  {
    id = 3812,
    type = "type_compatibility",
    name = "Normalize SQLite integer type",
    input = { type_name = "INTEGER" },
    expected = {
      normalized = "integer",
    },
  },
  {
    id = 3813,
    type = "type_compatibility",
    name = "Normalize removes trailing spaces",
    input = { type_name = "varchar    " },
    expected = {
      normalized = "varchar",
    },
  },
  {
    id = 3814,
    type = "type_compatibility",
    name = "Normalize removes leading spaces",
    input = { type_name = "    varchar" },
    expected = {
      normalized = "varchar",
    },
  },
  {
    id = 3815,
    type = "type_compatibility",
    name = "Normalize handles mixed case",
    input = { type_name = "VarChar(50)" },
    expected = {
      normalized = "varchar",
    },
  },
  {
    id = 3816,
    type = "type_compatibility",
    name = "Normalize numeric with precision and scale",
    input = { type_name = "numeric(10,5)" },
    expected = {
      normalized = "numeric",
    },
  },
  {
    id = 3817,
    type = "type_compatibility",
    name = "Normalize time with precision",
    input = { type_name = "time(3)" },
    expected = {
      normalized = "time",
    },
  },
  {
    id = 3818,
    type = "type_compatibility",
    name = "Normalize varbinary with size",
    input = { type_name = "varbinary(8000)" },
    expected = {
      normalized = "varbinary",
    },
  },
  {
    id = 3819,
    type = "type_compatibility",
    name = "Normalize char with size",
    input = { type_name = "char(10)" },
    expected = {
      normalized = "char",
    },
  },
  {
    id = 3820,
    type = "type_compatibility",
    name = "Normalize float with precision",
    input = { type_name = "float(53)" },
    expected = {
      normalized = "float",
    },
  },

  -- ========================================
  -- Category Detection Tests (3821-3845)
  -- ========================================
  {
    id = 3821,
    type = "type_compatibility",
    name = "INT is numeric category",
    input = { type_name = "int" },
    expected = {
      category = "numeric",
    },
  },
  {
    id = 3822,
    type = "type_compatibility",
    name = "BIGINT is numeric category",
    input = { type_name = "bigint" },
    expected = {
      category = "numeric",
    },
  },
  {
    id = 3823,
    type = "type_compatibility",
    name = "DECIMAL is numeric category",
    input = { type_name = "decimal" },
    expected = {
      category = "numeric",
    },
  },
  {
    id = 3824,
    type = "type_compatibility",
    name = "FLOAT is numeric category",
    input = { type_name = "float" },
    expected = {
      category = "numeric",
    },
  },
  {
    id = 3825,
    type = "type_compatibility",
    name = "VARCHAR is string category",
    input = { type_name = "varchar" },
    expected = {
      category = "string",
    },
  },
  {
    id = 3826,
    type = "type_compatibility",
    name = "NVARCHAR is string category",
    input = { type_name = "nvarchar" },
    expected = {
      category = "string",
    },
  },
  {
    id = 3827,
    type = "type_compatibility",
    name = "TEXT is string category",
    input = { type_name = "text" },
    expected = {
      category = "string",
    },
  },
  {
    id = 3828,
    type = "type_compatibility",
    name = "DATE is temporal category",
    input = { type_name = "date" },
    expected = {
      category = "temporal",
    },
  },
  {
    id = 3829,
    type = "type_compatibility",
    name = "DATETIME is temporal category",
    input = { type_name = "datetime" },
    expected = {
      category = "temporal",
    },
  },
  {
    id = 3830,
    type = "type_compatibility",
    name = "TIMESTAMP is temporal category",
    input = { type_name = "timestamp" },
    expected = {
      category = "temporal",
    },
  },
  {
    id = 3831,
    type = "type_compatibility",
    name = "BINARY is binary category",
    input = { type_name = "binary" },
    expected = {
      category = "binary",
    },
  },
  {
    id = 3832,
    type = "type_compatibility",
    name = "VARBINARY is binary category",
    input = { type_name = "varbinary" },
    expected = {
      category = "binary",
    },
  },
  {
    id = 3833,
    type = "type_compatibility",
    name = "BIT is boolean category",
    input = { type_name = "bit" },
    expected = {
      category = "boolean",
    },
  },
  {
    id = 3834,
    type = "type_compatibility",
    name = "BOOLEAN is boolean category",
    input = { type_name = "boolean" },
    expected = {
      category = "boolean",
    },
  },
  {
    id = 3835,
    type = "type_compatibility",
    name = "UNIQUEIDENTIFIER is uuid category",
    input = { type_name = "uniqueidentifier" },
    expected = {
      category = "uuid",
    },
  },
  {
    id = 3836,
    type = "type_compatibility",
    name = "JSON is json category",
    input = { type_name = "json" },
    expected = {
      category = "json",
    },
  },
  {
    id = 3837,
    type = "type_compatibility",
    name = "JSONB is json category",
    input = { type_name = "jsonb" },
    expected = {
      category = "json",
    },
  },
  {
    id = 3838,
    type = "type_compatibility",
    name = "XML is xml category",
    input = { type_name = "xml" },
    expected = {
      category = "xml",
    },
  },
  {
    id = 3839,
    type = "type_compatibility",
    name = "Unknown type returns nil category",
    input = { type_name = "customtype" },
    expected = {
      category = nil,
    },
  },
  {
    id = 3840,
    type = "type_compatibility",
    name = "PostgreSQL SERIAL is numeric",
    input = { type_name = "serial" },
    expected = {
      category = "numeric",
    },
  },
  {
    id = 3841,
    type = "type_compatibility",
    name = "MySQL TINYINT is numeric",
    input = { type_name = "tinyint" },
    expected = {
      category = "numeric",
    },
  },
  {
    id = 3842,
    type = "type_compatibility",
    name = "SQLite REAL is numeric",
    input = { type_name = "real" },
    expected = {
      category = "numeric",
    },
  },
  {
    id = 3843,
    type = "type_compatibility",
    name = "CHAR is string category",
    input = { type_name = "char" },
    expected = {
      category = "string",
    },
  },
  {
    id = 3844,
    type = "type_compatibility",
    name = "SMALLINT is numeric category",
    input = { type_name = "smallint" },
    expected = {
      category = "numeric",
    },
  },
  {
    id = 3845,
    type = "type_compatibility",
    name = "DATETIME2 is temporal category",
    input = { type_name = "datetime2" },
    expected = {
      category = "temporal",
    },
  },

  -- ========================================
  -- Same Category Compatibility (3846-3865)
  -- ========================================
  {
    id = 3846,
    type = "type_compatibility",
    name = "INT and BIGINT are compatible (numeric)",
    input = { type1 = "int", type2 = "bigint" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3847,
    type = "type_compatibility",
    name = "INT and DECIMAL are compatible (numeric)",
    input = { type1 = "int", type2 = "decimal" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3848,
    type = "type_compatibility",
    name = "VARCHAR and NVARCHAR are compatible (string)",
    input = { type1 = "varchar", type2 = "nvarchar" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3849,
    type = "type_compatibility",
    name = "VARCHAR and TEXT are compatible (string)",
    input = { type1 = "varchar", type2 = "text" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3850,
    type = "type_compatibility",
    name = "DATE and DATETIME are compatible (temporal)",
    input = { type1 = "date", type2 = "datetime" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3851,
    type = "type_compatibility",
    name = "DATE and DATETIME2 are compatible (temporal)",
    input = { type1 = "date", type2 = "datetime2" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3852,
    type = "type_compatibility",
    name = "BINARY and VARBINARY are compatible (binary)",
    input = { type1 = "binary", type2 = "varbinary" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3853,
    type = "type_compatibility",
    name = "BIT and BOOLEAN are compatible (boolean)",
    input = { type1 = "bit", type2 = "boolean" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3854,
    type = "type_compatibility",
    name = "Same type exactly is compatible",
    input = { type1 = "int", type2 = "int" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3855,
    type = "type_compatibility",
    name = "Same type different case is compatible",
    input = { type1 = "VARCHAR", type2 = "varchar" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3856,
    type = "type_compatibility",
    name = "Same type different size is compatible",
    input = { type1 = "varchar(50)", type2 = "varchar(100)" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3857,
    type = "type_compatibility",
    name = "FLOAT and REAL are compatible (numeric)",
    input = { type1 = "float", type2 = "real" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3858,
    type = "type_compatibility",
    name = "SMALLINT and INT are compatible (numeric)",
    input = { type1 = "smallint", type2 = "int" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3859,
    type = "type_compatibility",
    name = "CHAR and VARCHAR are compatible (string)",
    input = { type1 = "char", type2 = "varchar" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3860,
    type = "type_compatibility",
    name = "TIME and DATETIME are compatible (temporal)",
    input = { type1 = "time", type2 = "datetime" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3861,
    type = "type_compatibility",
    name = "NUMERIC and DECIMAL are compatible (numeric)",
    input = { type1 = "numeric", type2 = "decimal" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3862,
    type = "type_compatibility",
    name = "NCHAR and NVARCHAR are compatible (string)",
    input = { type1 = "nchar", type2 = "nvarchar" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3863,
    type = "type_compatibility",
    name = "TINYINT and SMALLINT are compatible (numeric)",
    input = { type1 = "tinyint", type2 = "smallint" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3864,
    type = "type_compatibility",
    name = "MONEY and DECIMAL are compatible (numeric)",
    input = { type1 = "money", type2 = "decimal" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3865,
    type = "type_compatibility",
    name = "TIMESTAMP and DATETIME are compatible (temporal)",
    input = { type1 = "timestamp", type2 = "datetime" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },

  -- ========================================
  -- Cross-Category Compatibility (3866-3885)
  -- ========================================
  {
    id = 3866,
    type = "type_compatibility",
    name = "INT and VARCHAR are incompatible (numeric vs string)",
    input = { type1 = "int", type2 = "varchar" },
    expected = {
      compatible = false,
      warning = "Type mismatch: int (numeric) vs varchar (string)",
    },
  },
  {
    id = 3867,
    type = "type_compatibility",
    name = "VARCHAR and INT are incompatible (string vs numeric)",
    input = { type1 = "varchar", type2 = "int" },
    expected = {
      compatible = false,
      warning = "Type mismatch: varchar (string) vs int (numeric)",
    },
  },
  {
    id = 3868,
    type = "type_compatibility",
    name = "DATE and INT are incompatible (temporal vs numeric)",
    input = { type1 = "date", type2 = "int" },
    expected = {
      compatible = false,
      warning = "Type mismatch: date (temporal) vs int (numeric)",
    },
  },
  {
    id = 3869,
    type = "type_compatibility",
    name = "DATE and VARCHAR implicit conversion warning (temporal vs string)",
    input = { type1 = "date", type2 = "varchar" },
    expected = {
      compatible = true,
      warning = "Implicit conversion: date (temporal) to varchar (string)",
    },
  },
  {
    id = 3870,
    type = "type_compatibility",
    name = "INT and BIT implicit conversion warning (numeric vs boolean)",
    input = { type1 = "int", type2 = "bit" },
    expected = {
      compatible = true,
      warning = "Implicit conversion: int (numeric) to bit (boolean)",
    },
  },
  {
    id = 3871,
    type = "type_compatibility",
    name = "DECIMAL and VARCHAR are incompatible (numeric vs string)",
    input = { type1 = "decimal", type2 = "varchar" },
    expected = {
      compatible = false,
      warning = "Type mismatch: decimal (numeric) vs varchar (string)",
    },
  },
  {
    id = 3872,
    type = "type_compatibility",
    name = "BINARY and VARCHAR are incompatible (binary vs string)",
    input = { type1 = "binary", type2 = "varchar" },
    expected = {
      compatible = false,
      warning = "Type mismatch: binary (binary) vs varchar (string)",
    },
  },
  {
    id = 3873,
    type = "type_compatibility",
    name = "JSON and VARCHAR are compatible (unknown category)",
    input = { type1 = "json", type2 = "varchar" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3874,
    type = "type_compatibility",
    name = "XML and VARCHAR are incompatible (xml vs string)",
    input = { type1 = "xml", type2 = "varchar" },
    expected = {
      compatible = false,
      warning = "Type mismatch: xml (xml) vs varchar (string)",
    },
  },
  {
    id = 3875,
    type = "type_compatibility",
    name = "UNIQUEIDENTIFIER and VARCHAR are incompatible (uuid vs string)",
    input = { type1 = "uniqueidentifier", type2 = "varchar" },
    expected = {
      compatible = false,
      warning = "Type mismatch: uniqueidentifier (uuid) vs varchar (string)",
    },
  },
  {
    id = 3876,
    type = "type_compatibility",
    name = "Unknown types are compatible",
    input = { type1 = "customtype1", type2 = "customtype2" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3877,
    type = "type_compatibility",
    name = "Known type and unknown type are compatible",
    input = { type1 = "int", type2 = "customtype" },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3878,
    type = "type_compatibility",
    name = "Nil inputs are compatible",
    input = { type1 = nil, type2 = nil },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3879,
    type = "type_compatibility",
    name = "DATETIME and VARCHAR implicit conversion (temporal vs string)",
    input = { type1 = "datetime", type2 = "varchar" },
    expected = {
      compatible = true,
      warning = "Implicit conversion: datetime (temporal) to varchar (string)",
    },
  },
  {
    id = 3880,
    type = "type_compatibility",
    name = "BIT and VARCHAR are incompatible (boolean vs string)",
    input = { type1 = "bit", type2 = "varchar" },
    expected = {
      compatible = false,
      warning = "Type mismatch: bit (boolean) vs varchar (string)",
    },
  },
  {
    id = 3881,
    type = "type_compatibility",
    name = "FLOAT and VARCHAR are incompatible (numeric vs string)",
    input = { type1 = "float", type2 = "varchar" },
    expected = {
      compatible = false,
      warning = "Type mismatch: float (numeric) vs varchar (string)",
    },
  },
  {
    id = 3882,
    type = "type_compatibility",
    name = "BINARY and INT are incompatible (binary vs numeric)",
    input = { type1 = "binary", type2 = "int" },
    expected = {
      compatible = false,
      warning = "Type mismatch: binary (binary) vs int (numeric)",
    },
  },
  {
    id = 3883,
    type = "type_compatibility",
    name = "BOOLEAN and VARCHAR are incompatible (boolean vs string)",
    input = { type1 = "boolean", type2 = "varchar" },
    expected = {
      compatible = false,
      warning = "Type mismatch: boolean (boolean) vs varchar (string)",
    },
  },
  {
    id = 3884,
    type = "type_compatibility",
    name = "UUID and INT are incompatible (uuid vs numeric)",
    input = { type1 = "uniqueidentifier", type2 = "int" },
    expected = {
      compatible = false,
      warning = "Type mismatch: uniqueidentifier (uuid) vs int (numeric)",
    },
  },
  {
    id = 3885,
    type = "type_compatibility",
    name = "XML and INT are incompatible (xml vs numeric)",
    input = { type1 = "xml", type2 = "int" },
    expected = {
      compatible = false,
      warning = "Type mismatch: xml (xml) vs int (numeric)",
    },
  },

  -- ========================================
  -- Info and Helper Function Tests (3886-3900)
  -- ========================================
  {
    id = 3886,
    type = "type_compatibility",
    name = "get_info for compatible types returns checkmark icon",
    input = { type1 = "int", type2 = "bigint", method = "get_info" },
    expected = {
      compatible = true,
      warning = nil,
      icon = "✓",
    },
  },
  {
    id = 3887,
    type = "type_compatibility",
    name = "get_info for incompatible types returns warning icon",
    input = { type1 = "int", type2 = "varchar", method = "get_info" },
    expected = {
      compatible = false,
      warning = "Type mismatch: int (numeric) vs varchar (string)",
      icon = "⚠",
    },
  },
  {
    id = 3888,
    type = "type_compatibility",
    name = "get_info for implicit conversion returns lightning icon",
    input = { type1 = "date", type2 = "varchar", method = "get_info" },
    expected = {
      compatible = true,
      warning = "Implicit conversion: date (temporal) to varchar (string)",
      icon = "⚡",
    },
  },
  {
    id = 3889,
    type = "type_compatibility",
    name = "is_string_type returns true for VARCHAR",
    input = { type_name = "varchar", method = "is_string_type" },
    expected = {
      result = true,
    },
  },
  {
    id = 3890,
    type = "type_compatibility",
    name = "is_string_type returns false for INT",
    input = { type_name = "int", method = "is_string_type" },
    expected = {
      result = false,
    },
  },
  {
    id = 3891,
    type = "type_compatibility",
    name = "is_numeric_type returns true for INT",
    input = { type_name = "int", method = "is_numeric_type" },
    expected = {
      result = true,
    },
  },
  {
    id = 3892,
    type = "type_compatibility",
    name = "is_numeric_type returns false for VARCHAR",
    input = { type_name = "varchar", method = "is_numeric_type" },
    expected = {
      result = false,
    },
  },
  {
    id = 3893,
    type = "type_compatibility",
    name = "is_temporal_type returns true for DATE",
    input = { type_name = "date", method = "is_temporal_type" },
    expected = {
      result = true,
    },
  },
  {
    id = 3894,
    type = "type_compatibility",
    name = "is_temporal_type returns false for INT",
    input = { type_name = "int", method = "is_temporal_type" },
    expected = {
      result = false,
    },
  },
  {
    id = 3895,
    type = "type_compatibility",
    name = "PostgreSQL character varying is string type",
    input = { type_name = "character varying", method = "is_string_type" },
    expected = {
      result = true,
    },
  },
  {
    id = 3896,
    type = "type_compatibility",
    name = "Warning message contains both type names",
    input = { type1 = "int", type2 = "varchar" },
    expected = {
      compatible = false,
      warning_contains = { "int", "varchar" },
    },
  },
  {
    id = 3897,
    type = "type_compatibility",
    name = "Warning message contains category names",
    input = { type1 = "int", type2 = "varchar" },
    expected = {
      compatible = false,
      warning_contains = { "numeric", "string" },
    },
  },
  {
    id = 3898,
    type = "type_compatibility",
    name = "Empty string type name returns nil category",
    input = { type_name = "", method = "get_category" },
    expected = {
      category = nil,
    },
  },
  {
    id = 3899,
    type = "type_compatibility",
    name = "Nil type in compatibility check is compatible",
    input = { type1 = "int", type2 = nil },
    expected = {
      compatible = true,
      warning = nil,
    },
  },
  {
    id = 3900,
    type = "type_compatibility",
    name = "is_string_type for TEXT returns true",
    input = { type_name = "text", method = "is_string_type" },
    expected = {
      result = true,
    },
  },
}
