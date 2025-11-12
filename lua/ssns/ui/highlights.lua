---@class UiHighlights
---Syntax highlighting and icons for SSNS UI
local UiHighlights = {}

---Setup highlight groups
function UiHighlights.setup()
  -- Define highlight groups
  vim.api.nvim_set_hl(0, "SsnsServer", { link = "Directory", default = true })
  vim.api.nvim_set_hl(0, "SsnsDatabase", { link = "String", default = true })
  vim.api.nvim_set_hl(0, "SsnsSchema", { link = "Type", default = true })
  vim.api.nvim_set_hl(0, "SsnsTable", { link = "Identifier", default = true })
  vim.api.nvim_set_hl(0, "SsnsView", { link = "Function", default = true })
  vim.api.nvim_set_hl(0, "SsnsProcedure", { link = "Function", default = true })
  vim.api.nvim_set_hl(0, "SsnsFunction", { link = "Function", default = true })
  vim.api.nvim_set_hl(0, "SsnsColumn", { link = "Variable", default = true })
  vim.api.nvim_set_hl(0, "SsnsAction", { link = "Keyword", default = true })
  vim.api.nvim_set_hl(0, "SsnsGroup", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "SsnsIcon", { link = "SpecialChar", default = true })
  vim.api.nvim_set_hl(0, "SsnsStatusConnected", { fg = "green", default = true })
  vim.api.nvim_set_hl(0, "SsnsStatusDisconnected", { fg = "gray", default = true })
  vim.api.nvim_set_hl(0, "SsnsStatusError", { fg = "red", default = true })
end

---Apply highlights to buffer
function UiHighlights.apply()
  local Buffer = require('ssns.ui.buffer')

  if not Buffer.exists() then
    return
  end

  local bufnr = Buffer.bufnr

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)

  -- TODO: Apply highlights based on line content
  -- This would be more sophisticated in a real implementation
end

---Setup filetype detection
function UiHighlights.setup_filetype()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "ssns",
    callback = function()
      UiHighlights.setup()
      UiHighlights.apply()
    end,
  })
end

return UiHighlights
