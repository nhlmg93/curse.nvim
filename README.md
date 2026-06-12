# curse.nvim

Neovim integration for the [cursor-agent](https://cursor.com) CLI. Send prompts from your editor, stream agent status, reload changed buffers on success, and run read-only search and tutorial tasks.

Inspired by and adapted from [pi.nvim](https://github.com/pablopunk/pi.nvim) by [pablopunk](https://github.com/pablopunk). Thank you for the original architecture and patterns.

## Requirements

- Neovim 0.10+
- `cursor-agent` installed and on your `PATH`

## Installation

### lazy.nvim

```lua
{
  "nhlmg93/curse.nvim",
  config = function()
    require("curse").setup({
      -- model = "gpt-5",
      log = { debug = false },
    })
  end,
}
```

### vim.pack

```lua
vim.pack.add({ src = "https://github.com/nhlmg93/curse.nvim" })
require("curse").setup()
```

## Commands

| Command | Description |
|---------|-------------|
| `:CurseAsk` | Prompt cursor-agent with buffer context (supports a range) |
| `:CurseCancel` | Cancel the active request |
| `:CurseLog` | Open the session log |
| `:CurseSearch` | Semantic project search → quickfix list |
| `:CurseTutorial` | Generate a markdown tutorial in a split |

## Example keymaps

```lua
local curse = require("curse")

vim.keymap.set("n", "<leader>ca", "<cmd>CurseAsk<cr>", { desc = "Curse: Ask" })
vim.keymap.set("v", "<leader>ca", function()
  local range = curse.visual_range()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  vim.schedule(function() curse.prompt(range) end)
end, { desc = "Curse: Ask (visual)" })
vim.keymap.set("n", "<leader>cc", "<cmd>CurseCancel<cr>", { desc = "Curse: Cancel" })
```

## Configuration

```lua
require("curse").setup({
  mode = nil,           -- "plan" | "ask" | nil
  model = nil,          -- passed to cursor-agent --model
  append_system_prompt = nil,
  context = {
    max_bytes = 24000,
    ask = { surrounding_lines = 80 },
  },
  log = {
    enabled = true,
    path = "/tmp/curse.log",
    debug = false,      -- debug logs print to :messages and the log file
  },
  search = { mode = "ask" },    -- optional per-task overrides
  tutorial = { mode = "ask" },
})
```

Set `log = { enabled = false }` to disable file logging entirely.

Set `vim.g.curse_debug = true` to enable debug output regardless of config.

## Behavior

- Runs `cursor-agent` asynchronously via `vim.system`
- Shows status with `vim.notify`
- Queues additional requests while one is active
- Reloads the source buffer after a successful ask
- Search and tutorial run in read-only `ask` mode and present output via quickfix or a markdown split
- Treats unsaved buffer content as newer than disk when building context

## License

MIT — see [LICENSE](LICENSE).
