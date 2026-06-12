require("curse.types")

local M = {}

---@type CurseChat?
local active = nil

---@return CurseChat?
function M.get_active()
  return active
end

---@param chat CurseChat
function M.set_active(chat)
  active = chat
  if active then
    active.last_used_at = vim.loop.hrtime()
  end
end

function M.clear_active()
  active = nil
end

---@param id string
---@param meta? { name?: string, workspace?: string, workspace_hash?: string, model?: string, created_at?: integer }
function M.touch(id, meta)
  if active and active.id == id then
    if meta then
      for key, value in pairs(meta) do
        if value ~= nil then
          active[key] = value
        end
      end
    end
    active.last_used_at = vim.loop.hrtime()
    return
  end

  active = vim.tbl_extend("force", { id = id, last_used_at = vim.loop.hrtime() }, meta or {})
end

return M
