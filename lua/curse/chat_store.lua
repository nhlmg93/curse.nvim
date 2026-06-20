require("curse.types")

local config = require("curse.config")
local chat_sqlite = require("curse.chat_sqlite")

local M = {}

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
---@return CurseChat?
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
    path = db_path,
    dir = vim.fn.fnamemodify(db_path, ":h"),
    created_at = meta.createdAt or 0,
    model = meta.lastUsedModel,
  }
end

---@param opts? CurseListChatsOpts
---@return CurseChat[], string?
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
    return (a.created_at or 0) > (b.created_at or 0)
  end)

  return chats
end

---@param id string
---@return CurseChat?
function M.find_by_id(id)
  if not id or id == "" then
    return nil
  end

  local partial
  for _, chat in ipairs(M.list_sync({ all_workspaces = true })) do
    if chat.id == id then
      return chat
    end
    if not partial and chat.id:find(id, 1, true) then
      partial = chat
    end
  end

  return partial
end

---@param chat CurseChat
---@return string?
function M.resolve_session_path(chat)
  if chat.path and chat.path ~= "" and vim.fn.filereadable(chat.path) == 1 then
    return chat.path
  end

  if not chat.id or chat.id == "" then
    return nil
  end

  local stored = M.find_by_id(chat.id)
  if stored and stored.path and stored.path ~= "" and vim.fn.filereadable(stored.path) == 1 then
    return stored.path
  end

  return nil
end

---@param chat CurseChat
---@return CurseChat?
function M.resolve_session(chat)
  local path = M.resolve_session_path(chat)
  if not path then
    return nil
  end

  local workspace_paths = {}
  if chat.workspace_hash and chat.workspace then
    workspace_paths[chat.workspace_hash] = chat.workspace
  end

  local stored = parse_store_db(path, workspace_paths)
  if not stored then
    return nil
  end

  return vim.tbl_extend("force", chat, stored)
end

---@param opts? CurseListChatsOpts
---@param callback fun(chats: CurseChat[], err?: string)
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

---@param chat CurseChat
---@param name string
---@return boolean, string?
function M.rename(chat, name)
  local path = M.resolve_session_path(chat)
  if not path then
    return false, "session store not found"
  end
  chat.path = path

  name = vim.trim(name)
  if name == "" then
    return false, "name is empty"
  end

  local meta = chat_sqlite.read_meta(path)
  if not meta then
    return false, "session metadata not found"
  end

  meta.name = name
  return chat_sqlite.write_meta(path, meta)
end

---@param chat CurseChat
---@return boolean, string?
function M.delete(chat)
  local path = M.resolve_session_path(chat)
  if not path then
    return false, "session store not found"
  end
  chat.path = path

  local dir = chat.dir or vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) ~= 1 then
    return false, "session directory not found"
  end

  local trashed = pcall(vim.fn.delete, dir, "trash")
  if trashed and vim.fn.isdirectory(dir) == 0 then
    return true
  end

  if vim.fn.executable("trash-put") == 1 then
    vim.fn.system({ "trash-put", dir })
    if vim.fn.isdirectory(dir) == 0 then
      return true
    end
  end

  local ok = pcall(vim.fn.delete, dir, "rf")
  if ok and vim.fn.isdirectory(dir) == 0 then
    return true
  end

  return false, "failed to delete session directory"
end

return M
