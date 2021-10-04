local constants = require "aha.constants"

local M = {}

local NameMetadata = {}
NameMetadata.__index = NameMetadata

function NameMetadata:new(opts)
  opts = opts or {}
  local this = {
    savedBody = opts.savedBody or "",
    body = opts.body or "",
    dirty = opts.dirty or false,
    extmark = opts.extmark or nil,
  }

  setmetatable(this, self)
  return this
end

function M.write_block(bufnr, lines, line, mark)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  line = line or vim.api.nvim_buf_line_count(bufnr) + 1
  mark = mark or false

  if type(lines) == "string" then
    lines = vim.split(lines, "\n", true)
  end

  -- write content lines
  vim.api.nvim_buf_set_lines(bufnr, line - 1, line - 1 + #lines, false, lines)

  -- set extmarks
  if mark then
    -- (empty line) start ext mark at 0
    -- start line
    -- ...
    -- end line
    -- (empty line)
    -- (empty line) end ext mark at 0
    --
    -- (except for title where we cant place initial mark on line -1)

    local start_line = line
    local end_line = line
    local count = start_line + #lines
    for i = count, start_line, -1 do
      local text = vim.fn.getline(i) or ""
      if "" ~= text then
        end_line = i
        break
      end
    end

    return vim.api.nvim_buf_set_extmark(bufnr, constants.AHA_COMMENT_NS, math.max(0, start_line - 1 - 1), 0, {
      end_line = math.min(end_line + 2 - 1, vim.api.nvim_buf_line_count(bufnr)),
      end_col = 0,
    })
  end
end

function M.write_name(bufnr, record, line)
  local name = string.format("%s %s", record.referenceNum, record.name)
  local name_mark = M.write_block(bufnr, { name, "" }, line, true)
  vim.api.nvim_buf_add_highlight(bufnr, -1, "AhaRecordName", 0, 0, -1)
  local buffer = aha_buffers[bufnr]
  if buffer then
    buffer.nameMetadata = NameMetadata:new {
      savedBody = record.name,
      body = record.name,
      dirty = false,
      extmark = tonumber(name_mark),
    }
  end
end

function M.write_desc(bufnr, record, line)
  local desc = vim.fn.trim(record.description.htmlBody)
  local lines = vim.split(desc:gsub("\r\n", "\n"), "\n", true)
  vim.list_extend(lines, { "" })
  local desc_mark = M.write_block(bufnr, lines, line, true)
end

return M
