---SQL snippet definitions for completion
---@class SnippetData
local Snippets = {}

---Common SQL snippets (all databases)
Snippets.common = {
  {
    label = "select",
    description = "SELECT statement",
    insertText = "SELECT ${1:columns}\nFROM ${2:table}\nWHERE ${3:condition}",
  },
  {
    label = "insert",
    description = "INSERT statement",
    insertText = "INSERT INTO ${1:table} (${2:columns})\nVALUES (${3:values})",
  },
  {
    label = "update",
    description = "UPDATE statement",
    insertText = "UPDATE ${1:table}\nSET ${2:column} = ${3:value}\nWHERE ${4:condition}",
  },
  {
    label = "delete",
    description = "DELETE statement",
    insertText = "DELETE FROM ${1:table}\nWHERE ${2:condition}",
  },
  {
    label = "join",
    description = "INNER JOIN",
    insertText = "INNER JOIN ${1:table} ON ${2:condition}",
  },
  {
    label = "leftjoin",
    description = "LEFT JOIN",
    insertText = "LEFT JOIN ${1:table} ON ${2:condition}",
  },
  {
    label = "case",
    description = "CASE expression",
    insertText = "CASE\n\tWHEN ${1:condition} THEN ${2:result}\n\tELSE ${3:default}\nEND",
  },
  {
    label = "createtable",
    description = "CREATE TABLE statement",
    insertText = "CREATE TABLE ${1:table_name} (\n\t${2:column_name} ${3:data_type}\n)",
  },
}

---SQL Server specific snippets
Snippets.sqlserver = {
  {
    label = "selecttop",
    description = "SELECT TOP N",
    insertText = "SELECT TOP ${1:10} ${2:columns}\nFROM ${3:table}",
  },
  {
    label = "trycatch",
    description = "TRY...CATCH block",
    insertText = "BEGIN TRY\n\t${1:-- code}\nEND TRY\nBEGIN CATCH\n\t${2:-- error handling}\nEND CATCH",
  },
  {
    label = "ifexists",
    description = "IF EXISTS statement",
    insertText = "IF EXISTS (SELECT 1 FROM ${1:table} WHERE ${2:condition})\nBEGIN\n\t${3:-- code}\nEND",
  },
}

---PostgreSQL specific snippets
Snippets.postgres = {
  {
    label = "selectlimit",
    description = "SELECT with LIMIT",
    insertText = "SELECT ${1:columns}\nFROM ${2:table}\nLIMIT ${3:10}",
  },
  {
    label = "returning",
    description = "INSERT with RETURNING",
    insertText = "INSERT INTO ${1:table} (${2:columns})\nVALUES (${3:values})\nRETURNING ${4:id}",
  },
}

---MySQL specific snippets
Snippets.mysql = {
  {
    label = "selectlimit",
    description = "SELECT with LIMIT",
    insertText = "SELECT ${1:columns}\nFROM ${2:table}\nLIMIT ${3:10}",
  },
}

---SQLite specific snippets
Snippets.sqlite = {
  {
    label = "selectlimit",
    description = "SELECT with LIMIT",
    insertText = "SELECT ${1:columns}\nFROM ${2:table}\nLIMIT ${3:10}",
  },
}

---Get snippets for specific database type
---@param db_type string Database type
---@return table[] snippets Combined snippet list
function Snippets.get_for_database(db_type)
  local result = vim.deepcopy(Snippets.common)

  if db_type == "sqlserver" then
    vim.list_extend(result, Snippets.sqlserver)
  elseif db_type == "postgres" or db_type == "postgresql" then
    vim.list_extend(result, Snippets.postgres)
  elseif db_type == "mysql" then
    vim.list_extend(result, Snippets.mysql)
  elseif db_type == "sqlite" then
    vim.list_extend(result, Snippets.sqlite)
  end

  return result
end

---Load user-defined snippets from file
---@return table[] snippets User snippet list
function Snippets.load_user_snippets()
  local data_path = vim.fn.stdpath('data')
  local snippets_file = data_path .. '/ssns/snippets.json'

  -- Check if file exists
  if vim.fn.filereadable(snippets_file) == 0 then
    return {}
  end

  -- Read and parse JSON
  local content = vim.fn.readfile(snippets_file)
  local json_str = table.concat(content, '\n')

  local success, snippets = pcall(vim.json.decode, json_str)
  if not success then
    return {}
  end

  return snippets or {}
end

return Snippets
