local config = require("curse.config")
local chat_sqlite = require("curse.chat_sqlite")

local M = {}

---@class CurseChatEntry
---@field id string
---@field name string
---@field workspace string
---@field workspace_hash string
---@field created_at integer
---@field model? string

---@param path string
---@return string?
local function md5_hex(path)
  local result = vim.system({ "md5sum" }, { stdin = path, text = true }):wait()
  if result.code ~= 0 then return nil end
  return vim.trim(result.stdout):match("^(%x+)")
end

---@return string?
local function storage_root()
  local cfg = config.get().chat or {}
  if cfg.storage_path and cfg.storage_path ~= "" then
    return vim.fn.expand(cfg.storage_path)
  end

  for _, candidate in ipairs({ "~/.config/cursor/chats", "~/.cursor/chats" }) do
    local path = vim.fn.expand(candidate)
    if vim.fn.isdirectory(path) == 1 then
      return path
    end
  end

  return nil
end

---@param root string
---@param workspace_hash? string
---@return string[]
local function find_store_dbs(root, workspace_hash)
  local pattern
  if workspace_hash then
    pattern = root .. "/" .. workspace_hash .. "/*/store.db"
  else
    pattern = root .. "/*/*/store.db"
  end

  local files = vim.fn.glob(pattern, true, true)
  if type(files) == "string" then
    return files == "" and {} or { files }
  end
  return files
end

---@param db_path string
---@param workspace_paths table<string, string>
---@return CurseChatEntry?
local function parse_store_db(db_path, workspace_paths)
  local meta = chat_sqlite.read_meta(db_path)
  if not meta then return nil end

  local chat_id = vim.fn.fnamemodify(db_path, ":h:t")
  local workspace_hash = vim.fn.fnamemodify(vim.fn.fnamemodify(db_path, ":h"), ":t")
  local name = meta.name or meta.agentId or chat_id
  if type(name) ~= "string" or name == "" then
    name = chat_id
  end

  return {
    id = chat_id,
    name = name,
    workspace = workspace_paths[workspace_hash] or workspace_hash,
    workspace_hash = workspace_hash,
    created_at = meta.createdAt or 0,
    model = meta.lastUsedModel,
  }
end

---@param opts? { workspace?: string, all_workspaces?: boolean }
---@return CurseChatEntry[], string?
function M.list_sync(opts)
  opts = opts or {}
  local root = storage_root()
  if not root then
    return {}, "cursor-agent chat storage not found"
  end

  if not chat_sqlite.available() then
    return {}, chat_sqlite.unavailable_message()
  end

  local workspace_paths = {}
  local workspace_hash = nil
  if not opts.all_workspaces and opts.workspace then
    workspace_hash = md5_hex(opts.workspace)
    if not workspace_hash then
      return {}, "failed to hash workspace path"
    end
    workspace_paths[workspace_hash] = opts.workspace
  end

  local dbs = find_store_dbs(root, workspace_hash)
  local chats = {}
  for _, db_path in ipairs(dbs) do
    local entry = parse_store_db(db_path, workspace_paths)
    if entry then
      chats[#chats + 1] = entry
    end
  end

  table.sort(chats, function(a, b)
    return a.created_at > b.created_at
  end)

  return chats
end

---@param opts? { workspace?: string, all_workspaces?: boolean }
---@param callback fun(chats: CurseChatEntry[], err?: string)
function M.list(opts, callback)
  vim.system({ "true" }, {}, function()
    vim.schedule(function()
      local chats, err = M.list_sync(opts)
      callback(chats, err)
    end)
  end)
end

---@param workspace string
---@return string?
function M.workspace_hash(workspace)
  return md5_hex(workspace)
end

return M
