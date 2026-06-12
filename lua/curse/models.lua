local config = require("curse.config")

local M = {}

---@class CurseModelEntry
---@field id string
---@field name string
---@field default? boolean
---@field current? boolean

---@type CurseModelEntry[]?
local cache = nil

---@param line string
---@return CurseModelEntry?
local function parse_line(line)
  if line == "" or line:match("^Available models") then
    return nil
  end

  local slug, rest = line:match("^(%S+)%s+%-%s+(.+)$")
  if not slug or not rest then
    return nil
  end

  local default = rest:find("%(default%)", 1, true) ~= nil
  local current = rest:find("%(current%)", 1, true) ~= nil
  local name = rest:gsub("%s+%([^)]+%)", ""):gsub("%s+$", "")

  return {
    id = slug,
    name = name,
    default = default or nil,
    current = current or nil,
  }
end

---@param text string
---@return CurseModelEntry[]
local function parse_output(text)
  local models = {}
  for _, line in ipairs(vim.split(text or "", "\n", { plain = true })) do
    local entry = parse_line(vim.trim(line))
    if entry then
      models[#models + 1] = entry
    end
  end
  return models
end

---@return CurseModelEntry[]
function M.fallback()
  local current = config.get_model()
  local models = {
    { id = current, name = current },
    { id = config.default_model, name = "Composer 2.5 Fast" },
  }

  local seen = {}
  local unique = {}
  for _, entry in ipairs(models) do
    if not seen[entry.id] then
      seen[entry.id] = true
      unique[#unique + 1] = entry
    end
  end
  return unique
end

---@param callback fun(models: CurseModelEntry[], err?: string)
function M.list(callback)
  if cache then
    callback(cache)
    return
  end

  vim.system({ "cursor-agent", "models" }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local err = result.stderr ~= "" and result.stderr or ("cursor-agent models exited with code " .. result.code)
        callback(M.fallback(), vim.trim(err))
        return
      end

      local models = parse_output(result.stdout)
      if #models == 0 then
        callback(M.fallback(), "no models returned from cursor-agent")
        return
      end

      cache = models
      callback(models)
    end)
  end)
end

return M
