local config = require("curse.config")

local M = {}

---@class CurseChatEntry
---@field id string
---@field name string
---@field workspace string
---@field workspace_hash string
---@field created_at integer
---@field model? string

---@param hex string
---@return table?
local function decode_meta_hex(hex)
  if not hex or hex == "" then return nil end
  hex = vim.trim(hex)

  local chars = {}
  for i = 1, #hex, 2 do
    local byte = tonumber(hex:sub(i, i + 1), 16)
    if not byte then return nil end
    chars[#chars + 1] = string.char(byte)
  end

  local ok, decoded = pcall(vim.json.decode, table.concat(chars))
  if ok then return decoded end
  return nil
end

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

---@param db_path string
---@return string?
local function read_meta_hex(db_path)
  local result = vim.system({
    "sqlite3",
    "-batch",
    "-noheader",
    db_path,
    "select value from meta where key=0",
  }, { text = true }):wait()
  if result.code ~= 0 then return nil end
  return vim.trim(result.stdout)
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
  local meta_hex = read_meta_hex(db_path)
  if not meta_hex then return nil end

  local meta = decode_meta_hex(meta_hex)
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

  if vim.fn.executable("sqlite3") ~= 1 then
    return {}, "sqlite3 not found on PATH (required for session picker)"
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
