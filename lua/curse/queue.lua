local M = {}

---@alias QueueItem CurseRunOpts

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

return M
