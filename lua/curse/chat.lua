local config = require("curse.config")

local M = {}

---@type integer?
local term_win = nil

---@class CurseChatOpenOpts
---@field height? number
---@field cwd? string
---@field focus? boolean

---@param opts? CurseChatOpenOpts
---@param chat_cfg CurseChatConfig
---@return integer
local function split_height(opts, chat_cfg)
  local pct = (opts and opts.height) or chat_cfg.height or 35
  if pct > 0 and pct <= 1 then
    pct = pct * 100
  end
  return math.max(8, math.floor(vim.o.lines * pct / 100))
end

---@param opts? CurseChatOpenOpts
function M.open(opts)
  opts = opts or {}
  local chat_cfg = config.get().chat or {}

  if term_win and vim.api.nvim_win_is_valid(term_win) then
    if opts.focus ~= false then
      vim.api.nvim_set_current_win(term_win)
    end
    return
  end

  local curse = require("curse")
  local bufnr = vim.api.nvim_get_current_buf()
  local cmd = curse.get_chat_cmd(bufnr)
  local cwd = curse.get_cwd(bufnr, opts)
  local height = split_height(opts, chat_cfg)

  vim.cmd("belowright " .. height .. "split")
  local win = vim.api.nvim_get_current_win()
  term_win = win
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.bo[buf].bufhidden = "hide"
  vim.fn.jobstart(cmd, { term = true, cwd = cwd })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      term_win = nil
    end,
  })
end

return M
