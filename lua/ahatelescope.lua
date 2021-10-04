local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local finders = require "telescope.finders"
local popup = require "plenary.popup"
local conf = require("telescope.config").values
local api = require "aha.api"

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
          }
        end,
      },
      sorter = conf.generic_sorter(telescope_opts),
    }):find()
  end)
end

--- Debounces a function on the trailing edge. Automatically
--- `schedule_wrap()`s.
---
--@param fn (function) Function to debounce
--@param timeout (number) Timeout in ms
--@param first (boolean, optional) Whether to use the arguments of the first
---call to `fn` within the timeframe. Default: Use arguments of the last call.
--@returns (function, timer) Debounced function and timer. Remember to call
---`timer:close()` at the end or you will leak memory!
function M.debounce_trailing(fn, ms, first)
  local timer = vim.loop.new_timer()
  local wrapped_fn

  if not first then
    function wrapped_fn(...)
      local argv = { ... }
      local argc = select("#", ...)

      timer:start(ms, 0, function()
        pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
      end)
    end
  else
    local argv, argc
    function wrapped_fn(...)
      argv = argv or { ... }
      argc = argc or select("#", ...)

      timer:start(ms, 0, function()
        pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
      end)
    end
  end
  return wrapped_fn, timer
end

M.live_search = function(telescope_opts, opts)
  telescope_opts = telescope_opts or {}

  local entry_maker = function(entry)
    return {
      value = entry,
      display = entry.record.reference_num .. " " .. entry.record.name,
      ordinal = entry.record.reference_num,
    }
  end

  local live_search_job
  local callable = M.debounce_trailing(function(_, prompt, process_result, process_complete)
    if live_search_job then
      pcall(function()
        live_search_job:shutdown()
      end)
    end

    if prompt == nil or prompt == "" or string.len(prompt) < 3 then
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
  }):find()
end

return M
