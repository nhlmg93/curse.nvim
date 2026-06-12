local logger = require("curse.logger")

local M = {}

--- cursor-agent stream-json events (stdout, one JSON object per line):
---   handled: thinking (delta|completed), tool_call (started|completed), result (success|error)
---   ignored: system, user, assistant, unknown types

---@param line string
---@return table?
local function decode_event(line)
  local ok, decoded = pcall(vim.json.decode, line)
  if not ok then return nil end
  return decoded
end

---@param line string
---@param on_event fun(event: table)
---@param on_error? fun(line: string)
local function process_line(line, on_event, on_error)
  if line == "" then return end
  local event = decode_event(line)
  if event then
    on_event(event)
  elseif on_error then
    on_error(line)
  end
end

---@param session CurseSession
---@param key "stdout_tail"|"stderr_tail"
---@param chunk string
---@param on_event fun(event: table)
---@param on_error? fun(line: string)
local function feed_stream(session, key, chunk, on_event, on_error)
  if session.cancelled or not chunk or chunk == "" then return end

  session[key] = (session[key] or "") .. chunk

  while true do
    local newline = session[key]:find("\n", 1, true)
    if not newline then break end

    local line = session[key]:sub(1, newline - 1)
    session[key] = session[key]:sub(newline + 1)
    process_line(line, on_event, on_error)
  end
end

---@class RunnerHandlers
---@field on_event fun(event: table)
---@field on_error fun(err: string)
---@field on_stderr fun(data: string)
---@field on_exit fun(result: vim.SystemCompleted)

---@param session CurseSession
---@param cmd string[]
---@param handlers RunnerHandlers
---@return vim.SystemObj?, string?
function M.start(session, cmd, handlers)
  session.stdout_tail = ""
  session.stderr_tail = ""

  logger.debug("starting process cmd=%s", table.concat(cmd, " "))

  local ok, sys_or_err = pcall(vim.system, cmd, {
    text = true,
    stdout = vim.schedule_wrap(function(err, data)
      if err then handlers.on_error(err); return end
      feed_stream(session, "stdout_tail", data, handlers.on_event, nil)
    end),
    stderr = vim.schedule_wrap(function(err, data)
      if err then handlers.on_error(err); return end
      feed_stream(session, "stderr_tail", data, function() end, handlers.on_stderr)
    end),
  }, vim.schedule_wrap(function(result)
    if session.stdout_tail and session.stdout_tail ~= "" then
      process_line(session.stdout_tail, handlers.on_event, nil)
    end
    session.stdout_tail = ""

    if session.stderr_tail and session.stderr_tail ~= "" then
      handlers.on_stderr(session.stderr_tail)
    end
    session.stderr_tail = ""

    handlers.on_exit(result)
  end))

  if not ok then
    logger.info("vim.system failed: %s", tostring(sys_or_err))
    return nil, tostring(sys_or_err)
  end

  return sys_or_err, nil
end

---@param session CurseSession
function M.finish(session)
  if not session or not session.process then return end
  if session.process:is_closing() then return end
  pcall(session.process.write, session.process, nil)
end

---@param session CurseSession
function M.cancel(session)
  if session.process and not session.process:is_closing() then
    pcall(session.process.kill, session.process, 15)
  end
end

return M
