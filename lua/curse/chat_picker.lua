local chats = require("curse.chats")
local chat_store = require("curse.chat_store")
local interaction = require("curse.interaction")

local M = {}

---@param entry CurseChatEntry
---@param active? CurseChat
---@return string
local function format_item(entry, active)
  local label = entry.name
  if entry.model and entry.model ~= "" then
    label = label .. " (" .. entry.model .. ")"
  end
  if active and entry.id == active.id then
    label = label .. " [active]"
  end
  return label
end

---@param items CurseChatEntry[]
---@param active? CurseChat
local function sort_items(items, active)
  ---@param a CurseChatEntry
  ---@param b CurseChatEntry
  ---@return boolean
  local function cmp(a, b)
    if active and a.id == active.id then return true end
    if active and b.id == active.id then return false end
    return a.created_at > b.created_at
  end
  table.sort(items, cmp)
end

---@param opts? { workspace?: string, all_workspaces?: boolean }
---@param on_done? fun(choice?: CurseChatEntry)
function M.prompt(opts, on_done)
  opts = opts or {}

  chat_store.list(opts, function(list, err)
    if err then
      interaction.notify("curse: " .. err, vim.log.levels.WARN)
    end

    if #list == 0 then
      interaction.notify("curse: no sessions found", vim.log.levels.INFO, { title = "curse" })
      if on_done then on_done(nil) end
      return
    end

    local active = chats.get_active()
    local items = vim.list_extend({}, list)
    sort_items(items, active)

    interaction.select(items, {
      prompt = "Curse session: ",
      format_item = function(entry)
        return format_item(entry, active)
      end,
    }, function(choice)
      if not choice then
        if on_done then on_done(nil) end
        return
      end

      chats.set_active({
        id = choice.id,
        name = choice.name,
        workspace = choice.workspace,
        workspace_hash = choice.workspace_hash,
        model = choice.model,
        created_at = choice.created_at,
      })
      interaction.notify("curse: session set to " .. choice.name, vim.log.levels.INFO, { title = "curse" })
      if on_done then on_done(choice) end
    end)
  end)
end

return M
