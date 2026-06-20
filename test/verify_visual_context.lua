#!/usr/bin/env -S nvim --headless -l

package.path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h") .. "/lua/?.lua;" .. package.path

local context = require("curse.context")

local failures = {}

local function assert_true(cond, msg)
  if not cond then
    failures[#failures + 1] = msg
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    failures[#failures + 1] = string.format("%s: expected %q, got %q", msg, expected, actual)
  end
end

local function assert_contains(haystack, needle, msg)
  if not haystack:find(needle, 1, true) then
    failures[#failures + 1] = string.format("%s: %q not found in context", msg, needle)
  end
end

local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buf, "/tmp/curse_visual_test.lua")
vim.bo[buf].filetype = "lua"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "function hello()",
  "  return 'world'",
  "end",
})

local cfg = {}

local line_range = { start = 1, ["end"] = 2 }
local line_ctx = context.get_context(buf, cfg, line_range)
assert_contains(line_ctx, "Selected lines: 1-2", "line visual label")
assert_contains(line_ctx, "Selected text:", "line visual text")
assert_contains(line_ctx, "function hello()", "line visual content")
assert_contains(line_ctx, "File: /tmp/curse_visual_test.lua", "metadata file")
assert_not_scope = not line_ctx:find("Scope:", 1, true)
assert_true(assert_not_scope, "no Scope field")

local char_range = { start = 2, ["end"] = 2, start_col = 3, end_col = 8 }
local char_ctx = context.get_context(buf, cfg, char_range)
assert_contains(char_ctx, "Selected: line 2, columns 3-8", "char visual label")
assert_contains(char_ctx, "Selected text:", "char visual text marker")
assert_contains(char_ctx, "return", "char visual content")

local normalized = context.normalize_range({ start = 1, ["end"] = 1, start_col = 1, end_col = 5 })
assert_eq(normalized.start_col, 1, "normalize keeps columns")

local label = context.format_prompt_label(buf, char_range)
assert_true(not label:find("%[", 1, true), "prompt label has no model bracket")
assert_contains(label, "curse ask (curse_visual_test.lua:2:3-8)", "prompt label range suffix")

vim.api.nvim_buf_delete(buf, { force = true })

if #failures > 0 then
  for _, err in ipairs(failures) do
    io.stderr:write("FAIL: " .. err .. "\n")
  end
  os.exit(1)
end

print("verify_visual_context: ok")
os.exit(0)
