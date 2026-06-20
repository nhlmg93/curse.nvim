local M = {}

---@return boolean
function M.available()
  return vim.fn.executable("sqlite3") == 1
end

---@return string
function M.unavailable_message()
  return "sqlite3 not found on PATH (required for session picker)"
end

---@param hex string
---@return table?
function M.decode_meta_hex(hex)
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

---@param db_path string
---@return string?
function M.read_meta_hex(db_path)
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

---@param db_path string
---@return table?
function M.read_meta(db_path)
  local meta_hex = M.read_meta_hex(db_path)
  if not meta_hex then return nil end
  return M.decode_meta_hex(meta_hex)
end

---@param meta table
---@return string?
function M.encode_meta_hex(meta)
  local ok, json = pcall(vim.json.encode, meta)
  if not ok or not json then return nil end

  local hex = {}
  for i = 1, #json do
    hex[#hex + 1] = string.format("%02x", json:byte(i))
  end
  return table.concat(hex)
end

---@param db_path string
---@param meta table
---@return boolean, string?
function M.write_meta(db_path, meta)
  if not M.available() then
    return false, M.unavailable_message()
  end

  local hex = M.encode_meta_hex(meta)
  if not hex then
    return false, "failed to encode session metadata"
  end

  local sql = string.format("UPDATE meta SET value=x'%s' WHERE key=0;", hex)
  local result = vim.system({ "sqlite3", "-batch", db_path, sql }, { text = true }):wait()
  if result.code ~= 0 then
    return false, vim.trim(result.stderr or "failed to write session metadata")
  end
  return true
end

return M
