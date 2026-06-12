local config = require("curse.config")
local interaction = require("curse.interaction")
local present = require("curse.present")
local task = require("curse.task")

local M = {}

local INSTRUCTIONS = [[You are running inside curse.nvim. The user wants semantic project search results, not a conversational answer.

INSTRUCTIONS:
1. Inspect files as needed to find locations relevant to the user's query.
2. Do not modify project files.
3. Respond with only quickfix result lines in your final output.
4. Every non-empty line must match exactly:
   /absolute/path/to/file:lnum:cnum,line_count,notes
5. lnum and cnum are 1-based. line_count is how many lines the result spans.
6. notes must be one line and should explain why the location matters.
7. Do not write markdown fences, bullets, headings, JSON, or conversational text.
8. If there are no matches, respond with an empty output.]]

---@param output string
local function present_output(output)
  local items = present.parse_quickfix_lines(output)
  if #items > 0 then
    present.open_quickfix(items, "Curse Search Results", "curse search")
    return
  end

  if output and vim.trim(output) ~= "" then
    present.open_markdown(
      "# Search results could not be parsed\n\n"
        .. "_Expected quickfix lines (`path:lnum:col,line_count,notes`). Raw output:_\n\n"
        .. output
    )
    interaction.notify("curse search: could not parse results; showing raw output", vim.log.levels.WARN)
    return
  end

  present.open_quickfix({}, "Curse Search Results", "curse search")
end

---@param query string
function M.run(query)
  task.run({
    instructions = INSTRUCTIONS,
    query = query,
    task_cfg = config.get().search,
    on_output = present_output,
  })
end

function M.prompt()
  task.prompt("curse search: ", function(query)
    M.run(query)
  end)
end

return M
