local api = require "aha.api"
local AhaBuffer = require("aha.buffer").AhaBuffer
local Job = require "plenary.job"

local M = {}

_G.aha_buffers = {}

function M.configure_aha_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local buffer = aha_buffers[bufnr]

  if buffer then
    buffer:configure()
  end
end

function M.setup_buffer(ref, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_buf(bufnr)
  vim.cmd(string.format("file aha://%s", ref))
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { ref .. " ... loading ..." })

  vim.defer_fn(function()
    local record = api.get_record(ref)

    local aha_buffer = AhaBuffer:new {
      bufnr = bufnr,
      ref = ref,
      record = record,
    }

    aha_buffer:configure()
    aha_buffer:render_record()
  end, 10)
end

function M.create_buffer(ref)
  local bufnr = vim.api.nvim_create_buf(true, false)
  M.setup_buffer(ref, bufnr)
end

local function ref_from_branch()
  local j = Job:new {
    command = "git",
    args = { "rev-parse", "--abbrev-ref", "HEAD" },
    enable_recording = true,
  }
  local output = j:sync(1000)
  local branch = output[1]
  local ref

  if branch then
    ref = api.get_ref(branch)
  end

  if ref then
    M.create_buffer(ref)
  else
    print "No Aha! reference found in current branch"
  end
end

function M.aha(ref, ...)
  if ref then
    M.create_buffer(ref)
  else
    ref = ref_from_branch()
    if ref then
      M.create_buffer(ref)
    end
  end
end

return M
