require("curse.types")

local M = {}

M.default_model = "composer-2.5-fast"

---@type CurseConfig
M.defaults = {
  mode = nil,
  model = M.default_model,
  context = {
    max_bytes = 24000,
    ask = { surrounding_lines = 80 },
  },
  -- Disable file logging with log = { enabled = false }.
  -- log = nil cannot work in Lua (nil removes the key); use enabled = false instead.
  log = {
    enabled = true,
    path = "/tmp/curse.log",
    debug = false,
  },
}

---@type CurseConfig
local values = vim.deepcopy(M.defaults)

---@param opts? CurseConfig
---@return CurseConfig
function M.setup(opts)
  opts = opts or {}
  values = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  return values
end

---@return CurseConfig
function M.get()
  return values
end

---@return string
function M.get_model()
  return values.model or M.default_model
end

---@param slug string
function M.set_model(slug)
  values.model = slug
end

return M
