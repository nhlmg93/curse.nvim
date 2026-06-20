---@meta
require("curse.types")

local M = {}

---@type CurseConfig
M.defaults = {
  binary = { "cursor-agent" },
  skills = true,
  mode = nil,
  log = {
    enabled = true,
    path = "/tmp/curse.log",
    debug = false,
  },
  search = {
    mode = "ask",
  },
  tutorial = {
    mode = "ask",
  },
  chat = {
    height = 35,
    all_workspaces = false,
  },
}

---@type CurseConfig
local values = vim.deepcopy(M.defaults)

---@param opts? CurseConfig
---@return CurseConfig
function M.setup(opts)
  opts = opts or {}
  values = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  if values.binary and type(values.binary) == "string" then
    values.binary = { values.binary }
  end
  return values
end

---@return string[]
function M.get_binary_cmd()
  local binary = values.binary or { "cursor-agent" }
  local cmd = vim.deepcopy(binary) ---@type string[]
  for i, part in ipairs(cmd) do
    cmd[i] = vim.fn.expand(part)
  end
  return cmd
end

---@return CurseConfig
function M.get()
  return values
end

return M
