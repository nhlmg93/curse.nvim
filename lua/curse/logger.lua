-- Logging tiers (log.enabled gates file writes for info and error):
--   info  — file only when log.enabled; never prints to :messages
--   debug — :messages + file when log.debug
--   error — always vim.notify (ERROR); file when log.enabled (default on)

local config = require("curse.config")

local M = {}

M.DEFAULT_PATH = "/tmp/curse.log"

---@return string
local function format_time()
  return os.date("%Y-%m-%d %H:%M:%S")
end

---@return table
local function log_cfg()
  return config.get().log or {}
end

---@return boolean
local function debug_enabled()
  local cfg = log_cfg()
  return cfg.debug == true or vim.g.curse_debug == true
end

---@return boolean
local function file_enabled()
  local cfg = log_cfg()
  return cfg.enabled ~= false
end

---@return string
local function log_path()
  return log_cfg().path or M.DEFAULT_PATH
end

---@param msg string
---@param ... string|number
---@return string
local function format_msg(msg, ...)
  if select("#", ...) > 0 then
    return string.format(msg, ...)
  end
  return msg
end

---@param lines string[]
local function write_lines(lines)
  if not file_enabled() then
    return
  end

  local ok, err = pcall(function()
    local file = io.open(log_path(), "a")
    if not file then
      return
    end
    for _, line in ipairs(lines) do
      file:write(line .. "\n")
    end
    file:close()
  end)

  if not ok then
    vim.notify("Failed to write curse log: " .. tostring(err), vim.log.levels.WARN)
  end
end

---@param text string
local function write_line(text)
  write_lines({ text })
end

---@param msg string
---@param ... string|number
function M.info(msg, ...)
  if not file_enabled() then
    return
  end

  local line = format_msg(msg, ...)
  write_line("[" .. format_time() .. "] [info] " .. line)
end

---@param msg string
---@param ... string|number
function M.debug(msg, ...)
  if not debug_enabled() then
    return
  end

  local line = format_msg(msg, ...)
  print("[curse] " .. line)
  if file_enabled() then
    write_line("[" .. format_time() .. "] [debug] " .. line)
  end
end

---@param msg string
---@param ... string|number
function M.error(msg, ...)
  local line = format_msg(msg, ...)
  vim.notify(line, vim.log.levels.ERROR, { title = "curse" })
  if file_enabled() then
    write_line("[" .. format_time() .. "] [error] " .. line)
  end
end

---@param session CurseSession
---@param opts? { message?: string, source_path?: string, cmd?: string, context_bytes?: integer }
function M.session_begin(session, opts)
  if not file_enabled() then
    return
  end

  opts = opts or {}
  local lines = {
    "",
    "=" .. string.rep("=", 78),
    string.format("[%s] [info] SESSION #%d START", format_time(), session.id),
    "=" .. string.rep("=", 78),
    "Prompt: " .. (opts.message or "(empty)"),
    "File: " .. (opts.source_path or "(no file)"),
    "Cmd: " .. (opts.cmd or "(unknown)"),
  }

  if opts.context_bytes then
    table.insert(lines, "Context: " .. opts.context_bytes .. " bytes")
  end

  write_lines(lines)
end

---@param session CurseSession
---@param opts? { status?: string, exit_code?: integer, cancelled?: boolean }
function M.session_end(session, opts)
  if not file_enabled() then
    return
  end

  opts = opts or {}
  local status = opts.status or session.status
  local duration = ""
  if session.started_at and session.ended_at then
    duration = string.format(" (%.1fs)", (session.ended_at - session.started_at) / 1e9)
  end

  local lines = {}

  if session.last_error then
    lines[#lines + 1] = "Error: " .. session.last_error
  end

  if #session.history > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "--- Session History ---"
    for _, entry in ipairs(session.history) do
      lines[#lines + 1] = entry
    end
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "=" .. string.rep("=", 78)
  lines[#lines + 1] = string.format("[%s] [info] SESSION #%d END — %s%s", format_time(), session.id, status, duration)
  if opts.exit_code ~= nil then
    lines[#lines + 1] = "Exit code: " .. tostring(opts.exit_code)
  end
  if opts.cancelled then
    lines[#lines + 1] = "Cancelled: true"
  end
  lines[#lines + 1] = "=" .. string.rep("=", 78)

  write_lines(lines)
end

function M.show()
  local path = log_path()
  if vim.fn.filereadable(path) == 0 then
    vim.notify("curse: log file not found at " .. path, vim.log.levels.INFO)
    return
  end

  vim.cmd("new")
  vim.cmd("read " .. vim.fn.fnameescape(path))
  vim.cmd("1d")
  vim.bo.modifiable = false
  vim.bo.buftype = "nofile"
  vim.bo.filetype = "log"
  vim.cmd("normal! G")
end

return M
