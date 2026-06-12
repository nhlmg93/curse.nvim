---@alias CurseStatus "idle"|"collecting_context"|"starting"|"thinking"|"running_tool"|"done"|"error"|"cancelled"

---@class CurseLineRange
---@field start integer
---@field ["end"] integer

---@class CurseLogConfig
---@field enabled? boolean
---@field path? string
---@field debug? boolean

---@class CurseTaskConfig
---@field model? string
---@field mode? "ask"|"plan"

---@class CurseConfig
---@field mode? "plan"|"ask"|nil
---@field model? string
---@field append_system_prompt? string
---@field context? { max_bytes?: integer, ask?: { surrounding_lines?: integer } }
---@field log? CurseLogConfig
---@field search? CurseTaskConfig
---@field tutorial? CurseTaskConfig

local M = {}

---@type CurseConfig
M.defaults = {
  mode = nil,
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

return M
