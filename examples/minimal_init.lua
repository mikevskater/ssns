-- Minimal SSNS setup
-- Add this to your init.lua or a plugin config file

require('ssns').setup({
  connections = {
    -- Your SQL Server Express instance
    local_sqlserver = "sqlserver://.\\SQLEXPRESS/master",

    -- Your MySQL instance (uncomment if you want to use it)
    -- local_mysql = "mysql://root:password@localhost:3306/mysql",
  },

  ui = {
    position = "left",
    width = 40,
  },
})

-- After this, you can use:
-- :SSNS           - Toggle tree
-- :SSNSConnect local_sqlserver
-- :SSNSStats
