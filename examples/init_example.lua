-- Example SSNS Configuration for your init.lua
-- Copy this into your Neovim configuration

-- Using lazy.nvim
return {
  "your-username/ssns",
  dependencies = {
    "tpope/vim-dadbod",  -- Required for database connections
  },
  config = function()
    require("ssns").setup({
      connections = {
        -- SQL Server Express (local instance with "." notation)
        sqlserver_local = "sqlserver://.\\SQLEXPRESS/master",

        -- MySQL with authentication
        mysql_local = "mysql://root:password@localhost:3306/mysql",

        -- Add your own databases here:
        -- my_database = "sqlserver://.\\SQLEXPRESS/MyDatabaseName",
        -- prod_mysql = "mysql://user:pass@server:3306/production_db",
      },

      ui = {
        position = "left",  -- "left", "right", "float"
        width = 40,
        ssms_style = true,
        show_schema_prefix = true,
      },

      cache = {
        ttl = 300,  -- 5 minutes
      },
    })
  end,
}

-- Alternative: using Packer
--[[
use {
  'your-username/ssns',
  requires = { 'tpope/vim-dadbod' },
  config = function()
    require('ssns').setup({
      -- Same configuration as above
    })
  end
}
]]

-- Alternative: using vim-plug
--[[
Plug 'tpope/vim-dadbod'
Plug 'your-username/ssns'

lua << EOF
require('ssns').setup({
  -- Same configuration as above
})
EOF
]]
