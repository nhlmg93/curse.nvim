local M = {}

---@type table<CurseStatus, string>
local labels = {
  collecting_context = "Curse collecting context...",
  starting = "Curse starting...",
  thinking = "Curse thinking...",
  running_tool = "Curse calling tool...",
  done = "Curse done",
  cancelled = "Curse cancelled",
}

---@class UiOpts
---@field queued? integer

---@param session CurseSession
---@return string
local function title_for(session)
  return session.status == "error" and "curse error" or "curse"
end

---@param session CurseSession
---@param opts? UiOpts
---@return string?
local function status_line(session, opts)
  local message
  if session.status == "running_tool" and session.active_tool then
    message = "Curse calling tool: " .. session.active_tool
  else
    local label = labels[session.status]
    if label then
      message = label
    elseif session.status == "error" then
      message = session.last_error or "curse failed"
    end
  end

  if not message then return nil end

  local queued = opts and opts.queued or 0
  if queued > 0 then
    message = message .. (" (%d queued)"):format(queued)
  end

  return message
end

---@param session CurseSession
---@param opts? UiOpts
local function render(session, opts)
  local message = status_line(session, opts)
  if not message then return end

  local queued = opts and opts.queued or 0
  local signature = session.status
    .. "|"
    .. (session.active_tool or "")
    .. "|"
    .. (session.last_error or "")
    .. "|"
    .. queued
  if session.last_notified_signature == signature then return end
  session.last_notified_signature = signature

  local level = session.status == "error" and vim.log.levels.ERROR
    or session.status == "cancelled" and vim.log.levels.WARN
    or vim.log.levels.INFO
  vim.notify(message, level, { title = title_for(session) })
end

---@param session CurseSession
---@param opts? UiOpts
function M.open(session, opts)
  render(session, opts)
end

---@param session CurseSession
---@param opts? UiOpts
function M.update(session, opts)
  render(session, opts)
end

---@param session CurseSession
---@param opts? UiOpts
function M.close(session, opts)
  render(session, opts)
end

return M
