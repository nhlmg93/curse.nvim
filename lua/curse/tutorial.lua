local config = require("curse.config")
local interaction = require("curse.interaction")
local present = require("curse.present")
local task = require("curse.task")

local M = {}

local INSTRUCTIONS = [[You are running inside curse.nvim. The user is asking for a tutorial, not code edits.

You are given a prompt and context and you must craft a tutorial. If the context contains links, inspect the relevant ones before writing.

<Rule>The response format must be valid Markdown.</Rule>
<Rule>The first line of the response must be the title of the tutorial.</Rule>
<Rule>Do not modify project files.</Rule>
<Rule>Write the completed tutorial as your final response output only.</Rule>
<Rule>Do not include conversational preamble or postscript outside the tutorial.</Rule>

Use project context only as background. Keep the tutorial focused on the user's prompt, explain concepts step by step, include examples when useful, and call out relevant syntax or pitfalls.]]

---@param output string
local function present_output(output)
  if not output or vim.trim(output) == "" then
    interaction.notify("curse tutorial: no content found", vim.log.levels.INFO)
    return
  end
  present.open_markdown(output)
end

---@param query string
function M.run(query)
  task.run({
    instructions = INSTRUCTIONS,
    query = query,
    task_cfg = config.get().tutorial,
    on_output = present_output,
  })
end

function M.prompt()
  task.prompt("curse tutorial: ", function(query)
    M.run(query)
  end)
end

return M
