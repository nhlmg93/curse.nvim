local config = require("curse.config")

local M = {}

---@return CurseUiConfig
local function ui_hooks()
  return config.get().ui or {}
end

---@param msg string
---@param level? integer
---@param opts? table
function M.notify(msg, level, opts)
  local hook = ui_hooks().notify
  if hook then
    hook(msg, level, opts)
    return
  end
  vim.notify(msg, level or vim.log.levels.INFO, opts)
end

---@param opts table
---@param on_confirm fun(input?: string)
function M.input(opts, on_confirm)
  local hook = ui_hooks().input
  if hook then
    hook(opts, on_confirm)
    return
  end
  vim.ui.input(opts, on_confirm)
end

---@param items table[]
---@param opts table
---@param on_choice fun(choice?: any, idx?: integer)
function M.select(items, opts, on_choice)
  local hook = ui_hooks().select
  if hook then
    hook(items, opts, on_choice)
    return
  end
  vim.ui.select(items, opts, on_choice)
end

return M
