local M = {}

---@class QueueItem
---@field message string
---@field bufnr integer
---@field range? CurseLineRange
---@field build_context? fun(): string
---@field cmd? string[]
---@field reload? boolean
---@field skip_system_prompt? boolean
---@field capture_output? boolean
---@field require_file_backed? boolean
---@field on_complete? fun(session: CurseSession, output: string)

---@type QueueItem[]
local items = {}

---@param item QueueItem
---@return integer position
function M.enqueue(item)
  items[#items + 1] = item
  return #items
end

---@return QueueItem?
function M.dequeue()
  if #items == 0 then return nil end
  return table.remove(items, 1)
end

---@return integer
function M.size()
  return #items
end

---@return integer cleared
function M.clear()
  local n = #items
  items = {}
  return n
end

return M
