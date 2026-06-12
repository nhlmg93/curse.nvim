local config = require("curse.config")
local context = require("curse.context")
local interaction = require("curse.interaction")
local logger = require("curse.logger")
local queue = require("curse.queue")
local runner = require("curse.runner")
local ui = require("curse.ui")

---@class curse
---@field setup fun(opts?: CurseConfig)
---@field run fun(opts: CurseRunOpts)
---@field prompt fun(range?: CurseLineRange)
---@field visual_range fun(): CurseLineRange?
---@field cancel fun()
---@field show_log fun()
---@field is_running fun(): boolean
---@field queue_size fun(): integer
---@field get_model fun(): string
---@field set_model fun(slug: string)
---@field select_model fun()
---@field get_cmd fun(bufnr?: integer): string[]
---@field component table

---@class CurseRunOpts
---@field message string
---@field build_context? fun(): string
---@field bufnr? integer
---@field range? CurseLineRange
---@field cmd? string[]
---@field reload? boolean
---@field skip_system_prompt? boolean
---@field capture_output? boolean
---@field require_file_backed? boolean
---@field on_complete? fun(session: CurseSession, output: string)

---@class CurseSession
---@field id integer
---@field status CurseStatus
---@field process vim.SystemObj?
---@field source_bufnr integer?
---@field started_at integer
---@field ended_at integer?
---@field active_tool string?
---@field last_error string?
---@field closing boolean
---@field cancelled boolean
---@field saw_terminal_event boolean
---@field history string[]
---@field last_notified_signature string?
---@field reload? boolean
---@field capture_output? boolean
---@field on_complete? fun(session: CurseSession, output: string)
---@field output_parts? string[]
---@field output? string

---@type curse
local M = {}

---@type CurseSession?
local active_session = nil
local next_session_id = 0

---@param source_bufnr integer
---@return CurseSession
local function new_session(source_bufnr)
  next_session_id = next_session_id + 1
  return {
    id = next_session_id,
    status = "collecting_context",
    process = nil,
    source_bufnr = source_bufnr,
    started_at = vim.loop.hrtime(),
    ended_at = nil,
    active_tool = nil,
    last_error = nil,
    closing = false,
    cancelled = false,
    saw_terminal_event = false,
    history = {},
  }
end

---@param session CurseSession
---@param message string
local function push_history(session, message)
  session.history[#session.history + 1] = message
end

---@param session CurseSession
---@return boolean
local function session_active(session)
  return active_session == session and not session.cancelled
end

---@param bufnr integer
---@return string?
local function source_path_for(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then return nil end
  return vim.fn.fnamemodify(name, ":p")
end

---@param bufnr integer
---@return string
local function workspace_for(bufnr)
  local path = source_path_for(bufnr)
  if not path then return vim.fn.getcwd() end

  local dir = vim.fn.fnamemodify(path, ":h:p")
  local git = vim.fs.find(".git", { upward = true, path = dir, type = "directory" })[1]
  if git then
    return vim.fn.fnamemodify(git, ":h:p")
  end
  return dir
end

local function ensure_file_backed_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  if not context.buffer_is_file_backed(bufnr) then
    interaction.notify("Curse requires a file-backed buffer", vim.log.levels.ERROR)
    return nil
  end
  return bufnr
end

---@param bufnr? integer
---@return string[]
function M.get_cmd(bufnr)
  local cfg = config.get()
  local cmd = {
    "cursor-agent",
    "--print",
    "--output-format",
    "stream-json",
    "--stream-partial-output",
    "--trust",
  }
  if bufnr then
    table.insert(cmd, "--workspace")
    table.insert(cmd, workspace_for(bufnr))
  end
  if cfg.mode == "plan" or cfg.mode == "ask" then
    table.insert(cmd, "--mode")
    table.insert(cmd, cfg.mode)
  end
  table.insert(cmd, "--model")
  table.insert(cmd, config.get_model())
  return cmd
end

---@param message string
---@param context_text string
---@param skip_system_prompt? boolean
---@return string
local function build_prompt(message, context_text, skip_system_prompt)
  local cfg = config.get()
  local parts = {}
  if not skip_system_prompt then
    parts[#parts + 1] = context.system_prompt
    if cfg.append_system_prompt and cfg.append_system_prompt ~= "" then
      parts[#parts + 1] = cfg.append_system_prompt
    end
  end
  parts[#parts + 1] = message
  parts[#parts + 1] = "Context:\n" .. context_text
  return table.concat(parts, "\n\n")
end

---@return { queued: integer }
local function ui_opts()
  return { queued = queue.size() }
end

---@param session CurseSession
---@param status CurseStatus
---@param message? string
local function set_status(session, status, message)
  if not session or session.closing then return end
  if session.status == status and not message then return end
  session.status = status
  if message then push_history(session, message) end
  ui.render(session, ui_opts())
end

-- Reload only the ask source buffer after a successful run. Context is scoped to
-- that file, so this is sufficient. Other open buffers are not scanned; revisit
-- pi-style multi-buffer reload only if multi-file stale-buffer bugs appear.
---@param session CurseSession
local function reload_source_buffer(session)
  local bufnr = session.source_bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end
  if not context.buffer_is_file_backed(bufnr) then return end

  local path = source_path_for(bufnr)
  if not path or vim.fn.filereadable(path) ~= 1 then return end

  local ok, err = pcall(function()
    vim.api.nvim_buf_call(bufnr, function()
      local view = vim.api.nvim_get_current_buf() == bufnr and vim.fn.winsaveview() or nil
      vim.cmd("silent edit!")
      if view then vim.fn.winrestview(view) end
    end)
  end)
  if not ok then
    logger.debug("buffer reload failed: %s", tostring(err))
  end
end

local start_session
local process_next

---@param session CurseSession
---@return string
local function session_output(session)
  if session.output then return session.output end
  if session.output_parts then return table.concat(session.output_parts) end
  return ""
end

---@param session CurseSession
---@param status CurseStatus
---@param opts? { error?: string, exit_code?: integer }
local function finish_session(session, status, opts)
  opts = opts or {}
  if not session or session.closing then return end

  session.closing = true
  session.status = status
  session.ended_at = vim.loop.hrtime()

  if opts.error then
    session.last_error = opts.error
    push_history(session, opts.error)
  end

  if status == "cancelled" then
    runner.cancel(session)
  elseif status ~= "error" then
    if session.capture_output and session.output_parts and not session.output then
      session.output = table.concat(session.output_parts)
    end
    if session.on_complete then
      local ok, err = pcall(session.on_complete, session, session_output(session))
      if not ok then
        interaction.notify("curse on_complete error: " .. tostring(err), vim.log.levels.ERROR)
      end
    end
    if not session.cancelled and session.reload ~= false then
      reload_source_buffer(session)
    end
  end

  ui.render(session, ui_opts())
  runner.finish(session)

  logger.session_end(session, {
    status = status,
    exit_code = opts.exit_code,
    cancelled = session.cancelled,
  })

  if active_session == session then active_session = nil end
  process_next()
end

local KNOWN_NOOP_EVENT_TYPES = {
  system = true,
  user = true,
  assistant = true,
}

---@param event table
---@return string?
local function event_subtype(event)
  return event.subtype or event.subType
end

---@param event table
---@return boolean
local function result_is_success(event)
  local sub = event_subtype(event)
  return sub == "success" or event.is_error == false
end

---@param event table
---@return boolean
local function result_is_error(event)
  local sub = event_subtype(event)
  return sub == "error" or event.is_error
end

---@param tool_call table?
---@return string
local function tool_name_from_call(tool_call)
  if not tool_call then return "unknown" end
  for name in pairs(tool_call) do
    if name:match("ToolCall$") then
      return name:gsub("ToolCall$", "")
    end
  end
  return "unknown"
end

---@param content table[]?
---@return string
local function text_from_content(content)
  if not content then return "" end
  local parts = {}
  for _, part in ipairs(content) do
    if part.type == "text" and part.text then
      parts[#parts + 1] = part.text
    end
  end
  return table.concat(parts, "")
end

---@param session CurseSession
---@param event table
local function capture_output_from_event(session, event)
  if not session.capture_output or not event then return end

  if event.type == "assistant" then
    local text = event.text
    if not text and event.message then
      text = text_from_content(event.message.content)
    end
    if text and text ~= "" then
      session.output_parts[#session.output_parts + 1] = text
    end
    return
  end

  if event.type == "result" and result_is_success(event) then
    if type(event.result) == "string" and event.result ~= "" then
      session.output = event.result
    end
  end
end

---@param session CurseSession
---@param event table
---@return boolean
local function handle_stream_event(session, event)
  if not event or not event.type then return false end

  capture_output_from_event(session, event)

  if event.type == "assistant" then
    return session.capture_output == true
  end

  if event.type == "thinking" then
    local sub = event_subtype(event)
    if sub == "delta" or sub == "completed" then
      set_status(session, "thinking")
      return true
    end
    return false
  end

  if event.type == "tool_call" then
    local sub = event_subtype(event)
    if sub == "started" then
      session.active_tool = tool_name_from_call(event.tool_call)
      set_status(session, "running_tool")
      return true
    end
    if sub == "completed" then
      session.active_tool = nil
      set_status(session, "thinking")
      return true
    end
    return false
  end

  if event.type == "result" then
    if result_is_success(event) then
      session.saw_terminal_event = true
      finish_session(session, "done")
      return true
    end
    if result_is_error(event) then
      session.saw_terminal_event = true
      finish_session(session, "error", { error = event.error or event.result or "unknown error" })
      return true
    end
    return false
  end

  return false
end

---@param opts CurseRunOpts
start_session = function(opts)
  local message = opts.message
  local bufnr = opts.bufnr
  local cmd = opts.cmd or M.get_cmd(bufnr)

  local build_context = opts.build_context
  if not build_context then
    local cfg = config.get()
    build_context = function()
      return context.get_context(bufnr, cfg, opts.range)
    end
  end

  local session = new_session(bufnr)
  session.reload = opts.reload
  session.capture_output = opts.capture_output
  session.on_complete = opts.on_complete
  if opts.capture_output then
    session.output_parts = {}
  end
  active_session = session

  ui.render(session, ui_opts())

  local ok, built_context = pcall(build_context)
  if not ok then
    logger.info("context build failed: %s", tostring(built_context))
    finish_session(session, "error", { error = built_context })
    return
  end

  local prompt = build_prompt(message, built_context, opts.skip_system_prompt)
  local run_cmd = vim.list_extend(vim.deepcopy(cmd), { prompt })

  logger.session_begin(session, {
    message = message,
    source_path = source_path_for(bufnr),
    cmd = table.concat(cmd, " "),
    context_bytes = #built_context,
  })

  set_status(session, "starting")

  local process, err = runner.start(session, run_cmd, {
    on_event = function(event)
      if not session_active(session) then return end
      if handle_stream_event(session, event) then return end
      if event and event.type and not KNOWN_NOOP_EVENT_TYPES[event.type] then
        logger.debug(
          "unhandled event type=%s subtype=%s",
          tostring(event.type),
          tostring(event_subtype(event))
        )
      end
    end,

    on_stderr = function(line)
      if not session_active(session) then return end
      push_history(session, line)
      ui.render(session, ui_opts())
    end,

    on_error = function(error_message)
      if not session_active(session) then return end
      logger.info("runner error: %s", tostring(error_message))
      finish_session(session, "error", { error = tostring(error_message) })
    end,

    on_exit = function(result)
      if session.cancelled or session.closing then return end
      if result.code ~= 0 and result.code ~= 143 and result.code ~= 124 then
        finish_session(session, "error", { error = "cursor-agent exited with code " .. result.code, exit_code = result.code })
        return
      end
      if not session.saw_terminal_event then
        finish_session(session, "error", {
          error = "cursor-agent exited before completing request",
          exit_code = result.code,
        })
        return
      end
      finish_session(session, "done", { exit_code = result.code })
    end,
  })

  if not process then
    finish_session(session, "error", { error = tostring(err) })
    return
  end

  session.process = process
end

process_next = function()
  while queue.size() > 0 do
    local item = queue.dequeue()
    if not item then return end

    local buf_ok = vim.api.nvim_buf_is_valid(item.bufnr)
    local file_ok = item.require_file_backed == false or context.buffer_is_file_backed(item.bufnr)
    if not buf_ok or not file_ok then
      interaction.notify("Skipped queued message: buffer no longer available", vim.log.levels.WARN)
    else
      start_session(item)
      return
    end
  end
end

---@param opts CurseRunOpts
function M.run(opts)
  opts = vim.deepcopy(opts or {})
  if not opts.message or opts.message == "" then
    interaction.notify("No message provided", vim.log.levels.ERROR)
    return
  end
  opts.bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  if active_session then
    local position = queue.enqueue(opts)
    interaction.notify(("Queued (position %d)"):format(position), vim.log.levels.INFO)
    ui.render(active_session, ui_opts())
    return
  end

  start_session(opts)
end

---@return CurseLineRange?
function M.visual_range()
  local mode = vim.api.nvim_get_mode().mode
  local bufnr = vim.api.nvim_get_current_buf()

  -- Active visual selection: marks are not set until after leaving visual mode.
  if mode == "v" or mode == "V" or mode == "\22" then
    local start_line = vim.fn.line("v")
    local end_line = vim.fn.line(".")
    if start_line > 0 and end_line > 0 then
      if start_line > end_line then start_line, end_line = end_line, start_line end
      return { start = start_line, ["end"] = end_line }
    end
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  if not start_pos or not end_pos then
    return nil
  end

  if start_pos[1] ~= 0 and start_pos[1] ~= bufnr then
    return nil
  end

  local start_line = start_pos[2]
  local end_line = end_pos[2]
  if start_line == 0 or end_line == 0 then
    return nil
  end
  if start_line > end_line then start_line, end_line = end_line, start_line end

  return { start = start_line, ["end"] = end_line }
end

---@param range? CurseLineRange
function M.prompt(range)
  local bufnr = ensure_file_backed_buffer()
  if not bufnr then return end

  interaction.input({ prompt = context.format_prompt_label(bufnr, range) }, function(input)
    if input and input ~= "" then
      M.run({
        message = input,
        bufnr = bufnr,
        range = range,
      })
    end
  end)
end

---@param opts? CurseConfig
function M.setup(opts)
  config.setup(opts)

  vim.api.nvim_create_user_command("CurseAsk", function(opts)
    local range
    if opts.line1 ~= opts.line2 then
      range = { start = opts.line1, ["end"] = opts.line2 }
    end
    M.prompt(range)
  end, { range = true, desc = "Ask curse (cursor-agent)" })

  vim.api.nvim_create_user_command("CurseCancel", function()
    M.cancel()
  end, { desc = "Cancel the active curse request" })

  vim.api.nvim_create_user_command("CurseLog", function()
    M.show_log()
  end, { desc = "Show curse session log" })

  local search = require("curse.search")
  local tutorial = require("curse.tutorial")

  vim.api.nvim_create_user_command("CurseSearch", function()
    search.prompt()
  end, { desc = "Semantic project search via curse" })

  vim.api.nvim_create_user_command("CurseTutorial", function()
    tutorial.prompt()
  end, { desc = "Generate a tutorial via curse" })

  vim.api.nvim_create_user_command("CurseModel", function()
    require("curse.model").prompt()
  end, { desc = "Select cursor-agent model" })
end

function M.cancel()
  if not active_session then return end
  local session = active_session
  session.cancelled = true
  finish_session(session, "cancelled")
end

function M.show_log()
  logger.show()
end

---@return boolean
function M.is_running()
  return active_session ~= nil
end

---@return integer
function M.queue_size()
  return queue.size()
end

---@return string
function M.get_model()
  return config.get_model()
end

---@param slug string
function M.set_model(slug)
  config.set_model(slug)
end

function M.select_model()
  require("curse.model").prompt()
end

M.component = require("curse.component")

return M
