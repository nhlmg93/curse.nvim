local config = require("curse.config")
local context = require("curse.context")
local interaction = require("curse.interaction")

local M = {}

---@param cmd string[]
---@param flag string
---@param value string
local function override_flag(cmd, flag, value)
  for i = 1, #cmd - 1 do
    if cmd[i] == flag then
      cmd[i + 1] = value
      return
    end
  end
  table.insert(cmd, flag)
  table.insert(cmd, value)
end

---@param bufnr integer
---@param task_cfg? CurseTaskConfig
---@return string[]
function M.cmd_for(bufnr, task_cfg)
  local curse = require("curse")
  local cmd = curse.get_cmd(bufnr, { reuse_chat = false })

  local mode = (task_cfg and task_cfg.mode) or "ask"
  override_flag(cmd, "--mode", mode)

  local model = (task_cfg and task_cfg.model) or config.get_model()
  override_flag(cmd, "--model", model)

  return cmd
end

---@param instructions string
---@param query string
---@return string
function M.build_message(instructions, query)
  return table.concat({
    instructions,
    "",
    "USER REQUEST (answer this exact request):",
    query,
    "",
    string.format("Cwd: %s", vim.fn.getcwd()),
    "",
    "Reminder: answer USER REQUEST exactly:",
    query,
  }, "\n")
end

---@class CurseTaskRunOpts
---@field instructions string
---@field query string
---@field task_cfg? CurseTaskConfig
---@field on_output fun(output: string)

---@param opts CurseTaskRunOpts
function M.run(opts)
  local curse = require("curse")
  local cfg = config.get()
  local bufnr = vim.api.nvim_get_current_buf()

  curse.run({
    message = M.build_message(opts.instructions, opts.query),
    bufnr = bufnr,
    cmd = M.cmd_for(bufnr, opts.task_cfg),
    build_context = function()
      return context.get_workspace_context(bufnr, cfg)
    end,
    reload = false,
    reuse_chat = false,
    skip_system_prompt = true,
    capture_output = true,
    require_file_backed = false,
    on_complete = function(_, output)
      opts.on_output(output or "")
    end,
  })
end

---@param prompt string
---@param run fun(query: string)
function M.prompt(prompt, run)
  interaction.input({ prompt = prompt }, function(input)
    if input and input ~= "" then
      run(input)
    end
  end)
end

return M
