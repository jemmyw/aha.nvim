local constants = require "aha.constants"
local writers = require "aha.writers"

local M = {}

local AhaBuffer = {}
AhaBuffer.__index = AhaBuffer

function AhaBuffer:new(opts)
  local this = {
    bufnr = opts.bufnr or vim.api.nvim_get_current_buf(),
    ref = opts.ref,
    record = opts.record,
  }

  setmetatable(this, self)
  aha_buffers[this.bufnr] = this
  return this
end

M.AhaBuffer = AhaBuffer

function AhaBuffer:clear()
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})

  local extmarks = vim.api.nvim_buf_get_extmarks(self.bufnr, constants.AHA_COMMENT_NS, 0, -1, {})
  for _, m in ipairs(extmarks) do
    vim.api.nvim_buf_del_extmark(self.bufnr, M.AHA_COMMENT_NS, m[1])
  end
end

function AhaBuffer:render_record()
  self:clear()

  writers.write_name(self.bufnr, self.record, 1)
  writers.write_desc(self.bufnr, self.record, 3)
end

function AhaBuffer:configure()
  vim.api.nvim_buf_call(self.bufnr, function()
    vim.cmd [[setlocal filetype=aha]]
    vim.cmd [[setlocal buftype=acwrite]]
    vim.cmd [[setlocal omnifunc=v:lua.aha_omnifunc]]
    vim.cmd [[setlocal conceallevel=2]]
    vim.cmd [[setlocal signcolumn=yes]]
    vim.cmd [[setlocal nonumber norelativenumber nocursorline wrap]]
  end)
end

function AhaBuffer:save() end

return M
