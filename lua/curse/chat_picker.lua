require("curse.types")

local chats = require("curse.chats")
local chat_store = require("curse.chat_store")
local interaction = require("curse.interaction")

local M = {}

local ID_SEP = "\t"

---@param entry CurseChat
---@return string
local function display_name(entry)
  return entry.name or entry.id
end

---@param entry CurseChat
---@return string
local function editor_line(entry)
  return display_name(entry) .. ID_SEP .. entry.id
end

---@param line string
---@return string? name
---@return string? id
local function parse_editor_line(line)
  line = vim.trim(line)
  if line == "" then
    return nil, nil
  end
  local name, id = line:match("^(.-)\t(.+)$")
  if not id then
    return line, nil
  end
  return vim.trim(name), vim.trim(id)
end

---@param entry CurseChat
---@param active? CurseChat
---@param show_workspace? boolean
---@return string
local function format_item(entry, active, show_workspace)
  local label = display_name(entry)
  if entry.model and entry.model ~= "" then
    label = label .. " (" .. entry.model .. ")"
  end
  if show_workspace and entry.workspace and entry.workspace ~= "" then
    label = label .. " @ " .. vim.fn.fnamemodify(entry.workspace, ":t")
  end
  if active and entry.id == active.id then
    label = label .. " [active]"
  end
  return label
end

---@param items CurseChat[]
---@param active? CurseChat
local function sort_items(items, active)
  table.sort(items, function(a, b)
    if active and a.id == active.id then return true end
    if active and b.id == active.id then return false end
    return (a.created_at or 0) > (b.created_at or 0)
  end)
end

---@param choice CurseChat
---@param on_done? fun(choice?: CurseChat)
local function activate_session(choice, on_done)
  chats.set_active({
    id = choice.id,
    name = choice.name,
    workspace = choice.workspace,
    workspace_hash = choice.workspace_hash,
    path = choice.path,
    dir = choice.dir,
    model = choice.model,
    created_at = choice.created_at,
  })
  interaction.notify("curse: session set to " .. (choice.name or choice.id), vim.log.levels.INFO, { title = "curse" })
  if on_done then
    on_done(choice)
  end
end

---@param sessions CurseChat[]
---@param edited_lines string[]
---@return integer deleted, integer renamed, string? err
local function apply_session_edits(sessions, edited_lines)
  local by_id = {}
  for _, chat in ipairs(sessions) do
    by_id[chat.id] = chat
  end

  local seen_ids = {}
  local deleted = 0
  local renamed = 0
  local active = chats.get_active()

  local function remove_session(chat)
    local ok, delete_err = chat_store.delete(chat)
    if not ok then
      return delete_err
    end
    deleted = deleted + 1
    if active and active.id == chat.id then
      chats.clear_active()
      active = nil
    end
    return nil
  end

  for _, line in ipairs(edited_lines) do
    local name, id = parse_editor_line(line)
    if not name then
      goto continue
    end

    local chat = id and by_id[id] or nil
    if not chat then
      for _, candidate in ipairs(sessions) do
        if not seen_ids[candidate.id] and display_name(candidate) == name then
          chat = candidate
          break
        end
      end
    end
    if not chat then
      goto continue
    end

    seen_ids[chat.id] = true
    local old_name = display_name(chat)
    if name ~= old_name then
      local ok, rename_err = chat_store.rename(chat, name)
      if not ok then
        return deleted, renamed, rename_err
      end
      renamed = renamed + 1
      if active and active.id == chat.id then
        active.name = name
      end
    end

    ::continue::
  end

  for _, chat in ipairs(sessions) do
    if not seen_ids[chat.id] then
      local err = remove_session(chat)
      if err then
        return deleted, renamed, err
      end
    end
  end

  return deleted, renamed, nil
end

---@param sessions CurseChat[]
---@param opts? CurseListChatsOpts
---@param on_done? fun(choice?: CurseChat)
local function open_session_editor(sessions, opts, on_done)
  if #sessions == 0 then
    interaction.notify("curse: no sessions to edit", vim.log.levels.INFO, { title = "curse" })
    return
  end

  local bufname = "curse-sessions://edit"
  local buf = vim.fn.bufnr(bufname)
  if buf ~= -1 then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, bufname)

  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "curse-sessions"

  vim.b[buf].curse_sessions = vim.deepcopy(sessions)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.tbl_map(editor_line, sessions))

  vim.cmd("split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_height(win, math.min(#sessions + 2, 12))

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    once = true,
    callback = function()
      local edited_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local stored = vim.b[buf].curse_sessions or sessions
      local deleted, renamed, err = apply_session_edits(stored, edited_lines)
      if err then
        interaction.notify("curse: " .. err, vim.log.levels.ERROR, { title = "curse" })
        return
      end

      local parts = {}
      if deleted > 0 then
        parts[#parts + 1] = deleted .. " deleted"
      end
      if renamed > 0 then
        parts[#parts + 1] = renamed .. " renamed"
      end
      local summary = #parts > 0 and table.concat(parts, ", ") or "no changes"
      interaction.notify("curse: sessions updated (" .. summary .. ")", vim.log.levels.INFO, { title = "curse" })

      vim.bo[buf].modified = false
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end

      if on_done then
        on_done(nil)
      end
    end,
  })
end

---@param items CurseChat[]
---@param active? CurseChat
---@param show_workspace? boolean
---@param list_opts? CurseListChatsOpts
---@param on_done? fun(choice?: CurseChat)
local function open_minipick_picker(items, active, show_workspace, list_opts, on_done)
  local MiniPick = require("mini.pick")

  MiniPick.start({
    source = {
      items = items,
      name = "Curse sessions (<CR> select, <C-e> edit)",
      show = function(buf_id, picker_items, query)
        local display = vim.tbl_map(function(entry)
          return format_item(entry, active, show_workspace)
        end, picker_items)
        MiniPick.default_show(buf_id, display, query, { show_icons = true })
      end,
      choose = function(choice)
        activate_session(choice, on_done)
      end,
    },
    mappings = {
      editor = {
        char = "<C-e>",
        func = function()
          MiniPick.stop()
          vim.schedule(function()
            open_session_editor(items, list_opts, on_done)
          end)
        end,
      },
    },
  })
end

---@param items CurseChat[]
---@param active? CurseChat
---@param show_workspace? boolean
---@param list_opts? CurseListChatsOpts
---@param on_done? fun(choice?: CurseChat)
local function open_picker(items, active, show_workspace, list_opts, on_done)
  local ok = pcall(require, "mini.pick")
  if ok then
    open_minipick_picker(items, active, show_workspace, list_opts, on_done)
    return
  end

  interaction.select(items, {
    prompt = "Curse session: ",
    format_item = function(entry)
      return format_item(entry, active, show_workspace)
    end,
  }, function(choice)
    if not choice then
      if on_done then
        on_done(nil)
      end
      return
    end
    activate_session(choice, on_done)
  end)
end

---@param opts? CurseListChatsOpts
---@param on_done? fun(choice?: CurseChat)
function M.prompt(opts, on_done)
  opts = opts or {}

  local function show_list(list, err, show_workspace)
    if err then
      interaction.notify("curse: " .. err, vim.log.levels.WARN)
    end

    if #list == 0 then
      interaction.notify("curse: no sessions found", vim.log.levels.INFO, { title = "curse" })
      if on_done then
        on_done(nil)
      end
      return
    end

    local active = chats.get_active()
    local items = vim.list_extend({}, list)
    sort_items(items, active)
    open_picker(items, active, show_workspace, opts, on_done)
  end

  chat_store.list(opts, function(list, err)
    if #list == 0 and not opts.all_workspaces and (opts.workspace or opts.workspaces) then
      local fallback = vim.tbl_deep_extend("force", {}, opts, { all_workspaces = true })
      chat_store.list(fallback, function(all_list, err2)
        show_list(all_list, err2, true)
      end)
      return
    end

    show_list(list, err, opts.all_workspaces == true)
  end)
end

return M
