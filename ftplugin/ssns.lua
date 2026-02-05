-- Filetype plugin for SSNS ETL scripts
-- Sets up buffer-local options and keymaps for .ssns files

-- Lazy-load ETL commands and macros on first .ssns file open
local Commands = require('nvim-ssns.commands')
Commands.setup_etl()

-- Set comment string for ETL directives
vim.bo.commentstring = "-- %s"

-- Enable SSNS semantic highlighting for SQL blocks in ETL files
-- Each SQL block gets highlighted using its own --@server and --@database connection
local ok, EtlHighlighting = pcall(require, 'nvim-ssns.etl.highlighting')
if ok then
  EtlHighlighting.setup_buffer(vim.api.nvim_get_current_buf())
end

-- Enable SQL-like indentation
vim.bo.tabstop = 2
vim.bo.shiftwidth = 2
vim.bo.expandtab = true

-- Set filetype options
vim.bo.formatoptions = vim.bo.formatoptions .. "r"  -- Continue comment on Enter

-- Buffer-local keymaps for ETL commands
local opts = { buffer = true, silent = true }

-- Execute ETL script
vim.keymap.set("n", "<leader>er", "<cmd>SSNSEtl<CR>", vim.tbl_extend("force", opts, {
  desc = "Execute ETL script",
}))

-- Execute block under cursor
vim.keymap.set("n", "<leader>eb", "<cmd>SSNSEtlBlock<CR>", vim.tbl_extend("force", opts, {
  desc = "Execute ETL block under cursor",
}))

-- Validate script
vim.keymap.set("n", "<leader>ev", "<cmd>SSNSEtlValidate<CR>", vim.tbl_extend("force", opts, {
  desc = "Validate ETL script",
}))

-- Dry run
vim.keymap.set("n", "<leader>ed", "<cmd>SSNSEtlDryRun<CR>", vim.tbl_extend("force", opts, {
  desc = "Show ETL execution plan",
}))

-- Cancel execution
vim.keymap.set("n", "<leader>ec", "<cmd>SSNSEtlCancel<CR>", vim.tbl_extend("force", opts, {
  desc = "Cancel ETL execution",
}))
