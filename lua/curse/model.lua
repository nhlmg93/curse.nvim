local config = require("curse.config")
local interaction = require("curse.interaction")
local models = require("curse.models")

local M = {}

---@param entry CurseModelEntry
---@param active string
---@return string
local function format_item(entry, active)
  local label = entry.name
  if entry.id ~= entry.name then
    label = label .. " (" .. entry.id .. ")"
  end
  if entry.id == active then
    label = label .. " [active]"
  end
  return label
end

---@param items CurseModelEntry[]
---@param active string
local function sort_models(items, active)
  ---@param a CurseModelEntry
  ---@param b CurseModelEntry
  ---@return boolean
  local function cmp(a, b)
    if a.id == active then return true end
    if b.id == active then return false end
    if a.default and not b.default then return true end
    if b.default and not a.default then return false end
    if a.current and not b.current then return true end
    if b.current and not a.current then return false end
    return a.name < b.name
  end
  table.sort(items, cmp)
end

function M.prompt()
  models.list(function(list, err)
    if err then
      interaction.notify("curse: " .. err .. "; showing fallback models", vim.log.levels.WARN)
    end

    local active = config.get_model()
    local items = vim.list_extend({}, list)
    sort_models(items, active)

    interaction.select(items, {
      prompt = "Curse model: ",
      format_item = function(entry)
        return format_item(entry, active)
      end,
    }, function(choice)
      if not choice then return end
      config.set_model(choice.id)
      interaction.notify("curse: model set to " .. choice.name, vim.log.levels.INFO, { title = "curse" })
    end)
  end)
end

return M
