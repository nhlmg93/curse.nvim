---@alias CurseStatus "collecting_context"|"starting"|"thinking"|"running_tool"|"done"|"error"|"cancelled"

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

---@class CurseUiConfig
---@field notify? fun(msg: string, level?: integer, opts?: table)
---@field input? fun(opts: table, on_confirm: fun(input?: string))
---@field select? fun(items: table[], opts: table, on_choice: fun(choice?: any, idx?: integer))

---@class CursePickerOpts
---@field prompt? string
---@field active? string
---@field items? CurseModelEntry[]

---@class CursePickerConfig
---@field backend? fun(items: CurseModelEntry[], opts: CursePickerOpts, on_choice: fun(choice?: CurseModelEntry))

---@class CurseConfig
---@field mode? "plan"|"ask"|nil
---@field model? string
---@field append_system_prompt? string
---@field context? { max_bytes?: integer, ask?: { surrounding_lines?: integer } }
---@field log? CurseLogConfig
---@field search? CurseTaskConfig
---@field tutorial? CurseTaskConfig
---@field ui? CurseUiConfig
---@field picker? CursePickerConfig

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
