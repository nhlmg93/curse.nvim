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

---@param on_line fun(line: string)
---@return fun(chunk: string), fun(): string
local function make_stream_feeder(on_line)
  local parts = {}

  local function feed(chunk)
    if not chunk or chunk == "" then return end
    parts[#parts + 1] = chunk

    local data = table.concat(parts)
    local from = 1
    local nl = data:find("\n", from, true)
    while nl do
      on_line(data:sub(from, nl - 1))
      from = nl + 1
      nl = data:find("\n", from, true)
    end

    if from == 1 then
      return
    end

    parts = { data:sub(from) }
  end

  local function tail()
    if #parts == 0 then return "" end
    return table.concat(parts)
  end

  return feed, tail
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
  local feed_stdout, stdout_tail = make_stream_feeder(function(line)
    process_line(line, handlers.on_event, nil)
  end)
  local feed_stderr, stderr_tail = make_stream_feeder(function(line)
    process_line(line, function() end, handlers.on_stderr)
  end)

  logger.debug("starting process cmd=%s", table.concat(cmd, " "))

  local ok, sys_or_err = pcall(vim.system, cmd, {
    text = true,
    stdout = vim.schedule_wrap(function(err, data)
      if err then handlers.on_error(err); return end
      if session.cancelled then return end
      feed_stdout(data)
    end),
    stderr = vim.schedule_wrap(function(err, data)
      if err then handlers.on_error(err); return end
      if session.cancelled then return end
      feed_stderr(data)
    end),
  }, vim.schedule_wrap(function(result)
    local remaining_stdout = stdout_tail()
    if remaining_stdout ~= "" then
      process_line(remaining_stdout, handlers.on_event, nil)
    end

    local remaining_stderr = stderr_tail()
    if remaining_stderr ~= "" then
      handlers.on_stderr(remaining_stderr)
    end

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
