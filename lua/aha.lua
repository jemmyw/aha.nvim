local api = require "aha.api"
local AhaBuffer = require("aha.buffer").AhaBuffer

local M = {}

_G.aha_buffers = {}

function M.configure_aha_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local buffer = aha_buffers[bufnr]

  if buffer then
    buffer:configure()
  end
end

function M.create_buffer(ref)
  local record = api.get_record(ref)

  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(bufnr)
  vim.cmd(string.format("file aha://%s", ref))

  local aha_buffer = AhaBuffer:new {
    bufnr = bufnr,
    ref = ref,
    record = record,
  }

  aha_buffer:configure()
  aha_buffer:render_record()
end

function M.aha(ref, ...)
  M.create_buffer(ref)
end

return M
