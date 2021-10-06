local api = require "aha.api"
local writers = require "aha.writers"
local previewers = require "telescope.previewers"
local ts_utils = require "telescope.utils"
local defaulter = ts_utils.make_default_callable

local M = {}

local render_preview = function(bufnr, record)
  if vim.api.nvim_buf_is_valid(bufnr) then
    writers.write_name(bufnr, record, 1)
    writers.write_desc(bufnr, record, 3)

    vim.api.nvim_buf_set_option(bufnr, "filetype", "aha")
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd [[setlocal wrap]]
      vim.cmd [[normal! zR]]
    end)
  end
end

M.record = defaulter(function(opts)
  return previewers.new_buffer_previewer {
    title = opts.preview_title,
    get_buffer_by_name = function(_, entry)
      return entry.value
    end,
    define_preview = function(self, entry)
      local bufnr = self.state.bufnr
      if entry and entry.record and (self.state.bufname ~= entry.value or vim.api.nvim_buf_line_count(bufnr) == 1) then
        local ref = entry.record.reference_num

        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { ref .. " ... loading ... " })

        api.get_record(ref, {
          callback = function(record)
            render_preview(bufnr, record)
          end,
        })
      end
    end,
  }
end)

return M
