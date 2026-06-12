local config = require("curse.config")

local M = {}

---@class CursePickerOpts
---@field prompt? string
---@field active? string
---@field items CurseModelEntry[]

---@param entry CurseModelEntry
---@param active? string
---@return string
function M.format_model_item(entry, active)
  local label = entry.name
  if entry.id ~= entry.name then
    label = label .. " (" .. entry.id .. ")"
  end
  if active and entry.id == active then
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

---@param items CurseModelEntry[]
---@param opts CursePickerOpts
---@param on_choice fun(choice?: CurseModelEntry)
local function default_backend(items, opts, on_choice)
  vim.ui.select(items, {
    prompt = opts.prompt or "Curse model: ",
    format_item = function(entry)
      return M.format_model_item(entry, opts.active)
    end,
  }, function(choice)
    on_choice(choice)
  end)
end

---@return fun(items: CurseModelEntry[], opts: CursePickerOpts, on_choice: fun(choice?: CurseModelEntry))
local function resolve_backend()
  local picker = config.get().picker
  if picker and picker.backend then
    return picker.backend
  end
  return default_backend
end

---@param opts CursePickerOpts
---@param on_choice fun(choice?: CurseModelEntry)
function M.open_model_picker(opts, on_choice)
  opts = opts or { items = {} }
  local active = opts.active or config.get_model()
  opts.active = active

  local items = vim.deepcopy(opts.items or {})
  sort_models(items, active)

  resolve_backend()(items, opts, on_choice)
end

return M
