local M = {}

---@param bufnr integer
---@return boolean
function M.buffer_is_file_backed(bufnr)
  if vim.bo[bufnr].buftype ~= "" then return false end
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= nil and name ~= ""
end

---@param bufnr integer
---@return string[], string
local function header(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype ~= "" and vim.bo[bufnr].filetype or "text"
  return {
    ("File: %s"):format(filename),
    ("Cwd: %s"):format(vim.fn.getcwd()),
    ("Filetype: %s"):format(filetype),
  }, filetype
end

---@param range CurseLineRange
---@return boolean
local function is_char_visual(range)
  return range.start_col ~= nil
end

---@param range? CurseLineRange
---@return CurseLineRange?
function M.normalize_range(range)
  if not range then
    return nil
  end
  if is_char_visual(range) then
    return range
  end
  return { start = range.start, ["end"] = range["end"] }
end

local function selection_label(range)
  if range.start_col then
    if range.start == range["end"] then
      return ("Selected: line %d, columns %d-%d"):format(range.start, range.start_col, range.end_col)
    end
    return ("Selected: lines %d-%d, columns %d:%d through %d:%d"):format(
      range.start,
      range["end"],
      range.start,
      range.start_col,
      range["end"],
      range.end_col
    )
  end
  return ("Selected lines: %d-%d"):format(range.start, range["end"])
end

---@param bufnr integer
---@param range CurseLineRange
---@return string?
local function selected_text(bufnr, range)
  local line_end = range["end"]
  local lines = vim.api.nvim_buf_get_lines(bufnr, range.start - 1, line_end, false)
  if #lines == 0 then
    return nil
  end

  if range.start_col then
    if range.start == range["end"] then
      return (lines[1] or ""):sub(range.start_col, range.end_col)
    end

    local parts = { (lines[1] or ""):sub(range.start_col) }
    for i = 2, #lines - 1 do
      parts[#parts + 1] = lines[i]
    end
    if #lines > 1 then
      parts[#parts + 1] = (lines[#lines] or ""):sub(1, range.end_col)
    end
    return table.concat(parts, "\n")
  end

  return table.concat(lines, "\n")
end

---@param text string
---@return string
local function format_selected_text(text)
  if text:find("\n", 1, true) then
    return "Selected text:\n" .. text
  end
  return ("Selected text: %q"):format(text)
end

local function selection_prompt_suffix(range)
  if range.start_col then
    if range.start == range["end"] then
      return ("%d:%d-%d"):format(range.start, range.start_col, range.end_col)
    end
    return ("%d:%d-%d:%d"):format(range.start, range.start_col, range["end"], range.end_col)
  end
  return ("%d-%d"):format(range.start, range["end"])
end

---@param bufnr integer
---@param label? string
---@return string
local function format_metadata(bufnr, label)
  local hdr = header(bufnr)
  local parts = {}
  vim.list_extend(parts, hdr)
  if label then
    parts[#parts + 1] = label
  end
  return table.concat(parts, "\n\n")
end

---@param bufnr integer
---@param _cfg CurseConfig
---@param range? CurseLineRange
---@return string
function M.get_context(bufnr, _cfg, range)
  range = M.normalize_range(range)
  if not range then
    return format_metadata(bufnr)
  end
  local parts = { selection_label(range) }
  local text = selected_text(bufnr, range)
  if text and text ~= "" then
    parts[#parts + 1] = format_selected_text(text)
  end
  return format_metadata(bufnr, table.concat(parts, "\n\n"))
end

---@param bufnr integer
---@param _cfg CurseConfig
---@return string
function M.get_workspace_context(bufnr, _cfg)
  if M.buffer_is_file_backed(bufnr) then
    return format_metadata(bufnr)
  end
  return ("Cwd: %s"):format(vim.fn.getcwd())
end

---@param bufnr integer
---@param range? CurseLineRange
---@return string
function M.format_prompt_label(bufnr, range)
  range = M.normalize_range(range)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local name = filename ~= "" and vim.fn.fnamemodify(filename, ":t") or nil
  if range then
    return ("curse ask (%s:%s): "):format(name or "?", selection_prompt_suffix(range))
  end
  return ("curse ask (%s): "):format(name or "?")
end

return M
