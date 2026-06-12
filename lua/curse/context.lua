local M = {}

M.system_prompt = [[You are running inside curse.nvim. The user has sent a request and will not be able to reply back. You must complete the task immediately without asking questions. Take action now and do what was asked.

IMPORTANT: Any file content included in the provided Context comes from the user's current Neovim buffer and may be newer than the on-disk file. Treat this context as the source of truth for that file content.]]

local BUFFER_NOTE = [[NOTE: The context below comes from the current Neovim buffer and may include unsaved changes that are newer than the on-disk file.]]

---@param bufnr integer
---@return boolean
function M.buffer_is_file_backed(bufnr)
  if vim.bo[bufnr].buftype ~= "" then return false end
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= nil and name ~= ""
end

---@param bufnr integer
---@return string, string, {[1]: string, [2]: string, [3]: string}
local function header(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype ~= "" and vim.bo[bufnr].filetype or "text"
  return filename, filetype, {
    ("File: %s"):format(filename),
    ("Cwd: %s"):format(vim.fn.getcwd()),
    ("Filetype: %s"):format(filetype),
  }
end

---@param text string
---@param max_bytes integer
---@return string, boolean
local function truncate_to_bytes(text, max_bytes)
  if #text <= max_bytes then return text, false end
  return text:sub(1, max_bytes), true
end

---@param bufnr integer
---@param label string
---@param code_label string
---@param lines string[]
---@param max_bytes? integer
---@return string
local function format_context(bufnr, label, code_label, lines, max_bytes)
  local _, filetype, hdr = header(bufnr)
  local parts = {}
  vim.list_extend(parts, hdr)
  vim.list_extend(parts, { label, BUFFER_NOTE })

  local code = table.concat(lines, "\n")
  if max_bytes then
    local trimmed
    code, trimmed = truncate_to_bytes(code, max_bytes)
    if trimmed then
      parts[#parts + 1] = ("NOTE: Context was trimmed (max_bytes=%d)."):format(max_bytes)
    end
  end
  parts[#parts + 1] = ("%s:\n```%s\n%s\n```"):format(code_label, filetype, code)
  return table.concat(parts, "\n\n")
end

---@param bufnr integer
---@param cfg CurseConfig
---@param range? {start: integer, end: integer}
---@return string
function M.get_context(bufnr, cfg, range)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local surrounding = cfg.context.ask.surrounding_lines
  local label, start, finish

  if range then
    start = math.max(1, range.start - surrounding)
    finish = math.min(line_count, range["end"] + surrounding)
    label = ("Selected lines: %d-%d"):format(range.start, range["end"])
  else
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    start = math.max(1, cursor_line - surrounding)
    finish = math.min(line_count, cursor_line + surrounding)
    label = ("Current line: %d"):format(cursor_line)
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start - 1, finish, false)
  return format_context(
    bufnr,
    label,
    ("Context (%d-%d)"):format(start, finish),
    lines,
    cfg.context.max_bytes
  )
end

---@param bufnr integer
---@param cfg CurseConfig
---@return string
function M.get_workspace_context(bufnr, cfg)
  if M.buffer_is_file_backed(bufnr) then
    return M.get_context(bufnr, cfg, nil)
  end
  return ("Cwd: %s"):format(vim.fn.getcwd())
end

---@param bufnr integer
---@param range? {start: integer, end: integer}
---@return string
function M.format_prompt_label(bufnr, range)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local name = filename ~= "" and vim.fn.fnamemodify(filename, ":t") or nil
  if range then
    return ("curse ask (%s:%d-%d): "):format(name or "?", range.start, range["end"])
  end
  return ("curse ask (%s): "):format(name or "?")
end

return M
