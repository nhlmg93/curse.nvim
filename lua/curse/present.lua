local interaction = require("curse.interaction")

local M = {}

---@param line string
---@return string
local function normalize_quickfix_line(line)
  line = line:gsub("^%s*[-*]%s+", "")
  line = line:gsub("^%s*`?", "")
  line = line:gsub("`?%s*$", "")
  return line
end

---@param line string
---@return table?
function M.parse_quickfix_line(line)
  line = normalize_quickfix_line(line)

  local filename, lnum_raw, rest = line:match("^(.-):(%d+):(.+)$")
  if not filename or not lnum_raw or not rest then
    return nil
  end

  local col_raw, line_count_raw, notes = rest:match("^(%d+),(%d+),?(.*)$")
  if not col_raw or not line_count_raw then
    return nil
  end

  local lnum = tonumber(lnum_raw) or 1
  local line_count = math.max(tonumber(line_count_raw) or 1, 1)

  return {
    filename = vim.fn.fnamemodify(filename, ":p"),
    lnum = lnum,
    end_lnum = lnum + line_count - 1,
    col = tonumber(col_raw) or 1,
    text = notes or "",
  }
end

---@param text string
---@return table[]
function M.parse_quickfix_lines(text)
  local items = {}
  for _, line in ipairs(vim.split(text or "", "\n")) do
    if line:match("%S") then
      local item = M.parse_quickfix_line(line)
      if item then
        items[#items + 1] = item
      end
    end
  end
  return items
end

---@param content string
function M.open_markdown(content)
  if not content or vim.trim(content) == "" then
    interaction.notify("curse: no content to display", vim.log.levels.INFO)
    return
  end

  vim.cmd("vsplit")
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_name(bufnr, string.format("curse://%s", tostring(vim.uv.hrtime())))
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "markdown"
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.wo[winnr].wrap = true
  vim.wo[winnr].linebreak = true

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n", { plain = true }))
  vim.bo[bufnr].modifiable = false
end

---@param items table[]
---@param title string
---@param notify_prefix string
function M.open_quickfix(items, title, notify_prefix)
  vim.fn.setqflist({}, "r", { title = title, items = items })
  if #items == 0 then
    interaction.notify(notify_prefix .. ": no results found", vim.log.levels.INFO)
    return
  end

  vim.cmd("copen")
  interaction.notify(
    string.format("%s: %d result%s", notify_prefix, #items, #items == 1 and "" or "s"),
    vim.log.levels.INFO
  )
end

return M
