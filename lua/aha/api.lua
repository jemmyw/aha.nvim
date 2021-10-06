local Job = require "plenary.job"
local curl = require "aha.curl"
local lunajson = require "lunajson"

local M = {}
M.config = {
  subdomain = "big",
}

local netrc_entries = nil
local function read_netrc()
  if netrc_entries then
    return netrc_entries
  end

  local home = os.getenv "HOME"
  local filename = home .. "/.netrc"
  local f = io.open(filename, "rb")
  local entries = {}
  if f then
    f:close()
    for line in io.lines(filename) do
      local entry = {}
      for k, v in string.gmatch(line, "([^%s]+)%s+([^%s]+)") do
        entry[k] = v
      end

      if entry.type == "aha" then
        entries[#entries + 1] = entry
      end
    end
  end

  netrc_entries = entries
  return entries
end

local function get_subdomain()
  if M.config.subdomain then
    return M.config.subdomain
  end

  local entries = read_netrc()
  if entries[0] then
    return entries[0].machine
  end
  return nil
end

local function get_netrc_entry()
  local subdomain = get_subdomain()
  local entries = read_netrc()
  for _, entry in ipairs(entries) do
    if entry.machine == subdomain then
      return entry
    end
  end
  return nil
end

local function get_token()
  local netrc_entry = get_netrc_entry()
  return netrc_entry and netrc_entry.token
end

local function get_url()
  local netrc_entry = get_netrc_entry()
  return netrc_entry and netrc_entry.url
end

local function html2md(html)
  local markdown = ""
  local job = Job:new {
    command = "html2md",
    writer = html,
    on_stdout = function(_, md, _)
      markdown = markdown .. "\n" .. md
    end,
  }

  job:sync(1000)
  return vim.trim(markdown)
end

function M.get_teams()
  local query = [[
    query {
      projects(filters: {teams: true}) {
        nodes {
          name
          isTeam
          referencePrefix
        }
      }
    }
  ]]

  local teams = M.query(query)
  return teams
end

local FEATURE_RE = "%w+-%d+"
local REQUIREMENT_RE = "%w+-%d+-%d+"
local EPIC_RE = "%w+-E-%d+"

function M.get_ref(str)
  local res = { EPIC_RE, REQUIREMENT_RE, FEATURE_RE }
  for _, re in ipairs(res) do
    local ref = string.match(str, re)
    if ref then
      return ref
    end
  end
end

function M.ref_type(ref)
  if string.match(ref, "^" .. FEATURE_RE .. "$") then
    return "feature"
  elseif string.match(ref, "^" .. REQUIREMENT_RE .. "$") then
    return "requirement"
  elseif string.match(ref, "^" .. EPIC_RE) then
    return "epic"
  end
end

function M.get_record(ref, opts)
  local type = M.ref_type(ref)
  if not type then
    errmsg = string.format("Invalid type %s", ref)
    error(errmsg)
  end

  local query = [[
    query GetRecord($id: ID!) {
      $$type(id: $id) {
        id
        path
        referenceNum
        name
        description { htmlBody }
        assignedToUser { name }
        teamWorkflowStatus {
          color
          name
        }
      }
    }
  ]]
  query = query:gsub("$$type", type)

  local transform = function(data)
    local record = data[type]
    record["subdomain"] = get_subdomain()
    local markdown = html2md(record.description.htmlBody)
    record.description["markdownBody"] = markdown
    return record
  end

  local data = M.query(
    query,
    vim.tbl_extend("force", {
      variables = {
        id = ref,
      },
      transform = transform,
    }, opts or {})
  )

  return data
end

function M.transform_response(response_body, transform)
  local status, t = pcall(lunajson.decode, response_body)

  if status and t and t.data then
    return transform(t.data)
  else
    return nil
  end
end

function M.query(query, opts)
  opts = opts or {}
  local variables = opts.variables or nil
  local transform = opts.transform or function(data)
    return data
  end

  local json = {
    query = query,
    variables = variables,
  }

  local callback = vim.schedule_wrap(function(response)
    local transformed_response = M.transform_response(response.body, transform)
    opts.callback(transformed_response)
  end)

  local response = curl.post(get_url() .. "/api/v2/graphql", {
    raw_body = vim.fn.json_encode(json),
    headers = {
      authorization = "Bearer " .. get_token(),
      content_type = "application/json",
    },
    callback = opts.callback and callback or nil,
  })

  if opts.callback then
    return response
  else
    return M.transform_response(response.body, transform)
  end
end

function M.search(query, opts)
  opts = opts or {}
  local params = opts.params or {}
  params.q = query

  local callback = vim.schedule_wrap(function(response)
    if response.body == nil or response.body == "" then
      print "no body"
      return
    end

    local status, t = pcall(lunajson.decode, response.body)

    if status == false then
      opts.callback(nil)
    else
      opts.callback(t.results)
    end
  end)

  local response = curl.get(get_url() .. "/api/v1/search", {
    query = params,
    headers = {
      authorization = "Bearer " .. get_token(),
      accepts = "application/json",
    },
    callback = opts.callback and callback or nil,
  })

  if opts.callback then
    return response
  else
    return vim.fn.json_decode(response.body).results
  end
end

return M
