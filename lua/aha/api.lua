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

function M.get_features()
  local query = [[
    query GetFeatures(
  ]]
end

function M.ref_type(ref)
  if string.match(ref, "^(%w+)-(%d+)$") then
    return "feature"
  elseif string.match(ref, "^(%w+)-(%d+)-(%d+)$") then
    return "requirement"
  elseif string.match(ref, "^(%w+)-E-") then
    return "epic"
  end
end

function M.get_record(ref)
  local type = M.ref_type(ref)
  if not type then
    errmsg = string.format("Invalid type %s", ref)
    error(errmsg)
  end

  local query = [[
    query GetRecord($id: ID!) {
      $$type(id: $id) {
        id
        referenceNum
        name
        description { htmlBody }
      }
    }
  ]]
  query = query:gsub("$$type", type)

  local record = M.query(query, {
    variables = {
      id = ref,
    },
  })
  return record[type]
end

function M.query(query, opts)
  opts = opts or {}
  local variables = opts.variables or nil

  local json = {
    query = query,
    variables = variables,
  }

  local parse_response = function(response)
    local status, t = pcall(lunajson.decode, response.body)

    if status then
      return t.data
    else
      return nil
    end
  end

  local callback = function(response)
    opts.callback(parse_response(response))
  end

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
    return parse_response(response)
  end
end

function M.search(query, opts)
  opts = opts or {}
  local params = opts.params or {}
  params.q = query

  local callback = function(response)
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
  end

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
