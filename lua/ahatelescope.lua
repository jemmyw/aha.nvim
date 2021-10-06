local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local finders = require "telescope.finders"
local debounce = require "telescope.debounce"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local action_set = require "telescope.actions.set"
local conf = require("telescope.config").values
local previewers = require "aha.previewers"
local popup = require "plenary.popup"
local api = require "aha.api"
local aha = require "aha"

local M = {}

local function msgLoadingPopup(msg, exec_fn, complete_fn)
  local row = math.floor((vim.o.lines - 5) / 2)
  local width = math.floor(vim.o.columns / 1.5)
  local col = math.floor((vim.o.columns - width) / 2)
  for _ = 1, (width - #msg) / 2, 1 do
    msg = " " .. msg
  end
  local prompt_win, prompt_opts = popup.create(msg, {
    border = {},
    borderchars = conf.borderchars,
    height = 5,
    col = col,
    line = row,
    width = width,
  })
  vim.api.nvim_win_set_option(prompt_win, "winhl", "Normal:TelescopeNormal")
  vim.api.nvim_win_set_option(prompt_win, "winblend", 0)
  local prompt_border_win = prompt_opts.border and prompt_opts.border.win_id
  if prompt_border_win then
    vim.api.nvim_win_set_option(prompt_border_win, "winhl", "Normal:TelescopePromptBorder")
  end
  vim.defer_fn(
    vim.schedule_wrap(function()
      local results = exec_fn()
      if not pcall(vim.api.nvim_win_close, prompt_win, true) then
        log.trace("Unable to close window: ", "ghcli", "/", prompt_win)
      end
      complete_fn(results)
    end),
    10
  )
end

local function open_in_browser(prompt_bufnr)
  local entry = action_state.get_selected_entry(prompt_buffnr)
  if not entry.record then
    return
  end

  local url = entry.record.url
  actions.close(prompt_bufnr)
  pcall(vim.cmd, "silent !xdg-open " .. url)
end

local function copy_url(prompt_bufnr)
  local entry = action_state.get_selected_entry(prompt_bufnr)
  if not entry.record then
    return
  end

  local url = entry.record.url
  vim.fn.setreg("+", url, "c")
  vim.notify("[Aha!] Copied '" .. url .. "' to the system clipboard (+ register)", 1)
end

local function open(prompt_bufnr, command)
  local entry = action_state.get_selected_entry(prompt_bufnr)
  if not entry.record then
    return
  end

  local ref = entry.record.reference_num
  actions.close(prompt_bufnr)
  aha.create_buffer(ref)
end

M.pick_team = function(telescope_opts, opts)
  telescope_opts = telescope_opts or {}

  msgLoadingPopup("Loading Aha! Develop teams", function()
    return api.get_teams().projects.nodes
  end, function(teams)
    local mlen = 0
    for _, team in ipairs(teams) do
      if string.len(team.referencePrefix) > mlen then
        mlen = string.len(team.referencePrefix)
      end
    end

    pickers.new(telescope_opts, {
      prompt_title = "Team",
      finder = finders.new_table {
        results = teams,
        entry_maker = function(entry)
          local ref = entry.referencePrefix .. string.rep(" ", mlen - string.len(entry.referencePrefix))

          return {
            value = entry.referencePrefix .. entry.name,
            display = ref .. " " .. entry.name,
            ordinal = entry.referencePrefix,
            record = entry,
          }
        end,
      },
      sorter = conf.generic_sorter(telescope_opts),
    }):find()
  end)
end

M.live_search = function(telescope_opts, opts)
  telescope_opts = telescope_opts or {}

  local entry_maker = function(entry)
    return {
      value = entry,
      display = entry.record.reference_num .. " " .. entry.record.name,
      ordinal = entry.record.reference_num,
      record = entry.record,
    }
  end

  local live_search_job
  local callable = debounce.debounce_trailing(function(_, prompt, process_result, process_complete)
    if live_search_job then
      pcall(function()
        live_search_job:shutdown()
      end)
    end

    if prompt == nil or prompt == "" or string.len(prompt) < 3 then
      process_result { value = prompt, display = "Type 3+ characters to search", ordinal = "" }
      process_complete()
      return
    end

    live_search_job = api.search(prompt, {
      params = {
        record_types = "feature,requirement,epic",
      },
      callback = function(results)
        if results then
          for _, item in ipairs(results) do
            if item and item.record and item.record.reference_num then
              process_result(entry_maker(item))
            end
          end

          process_complete()
        end
      end,
    })
  end, 250)

  local requester = function()
    return setmetatable({
      close = function()
        if live_search_job then
          pcall(function()
            live_search_job:shutdown()
          end)
        end
      end,
    }, {
      __call = callable,
    })
  end

  pickers.new(telescope_opts, {
    prompt_title = "Aha! Search",
    finder = requester(),
    sorter = sorters.highlighter_only(),
    previewer = previewers.record.new(telescope_opts),
    attach_mappings = function(_, map)
      action_set.select:replace(function(prompt_bufnr, type)
        open(prompt_bufnr, type)
      end)
      map("i", "<c-b>", open_in_browser)
      map("i", "<c-y>", copy_url)
      return true
    end,
  }):find()
end

return M
