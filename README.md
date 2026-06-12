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
| `:CurseModel` | Select cursor-agent model for this session |
| `:CurseSearch` | Semantic project search → quickfix list |
| `:CurseTutorial` | Generate a markdown tutorial in a split |

## Configuration

```lua
require("curse").setup({
  mode = nil,           -- "plan" | "ask" | nil
  model = "composer-2.5-fast",  -- default model; override at runtime with :CurseModel
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
  picker = {
    -- optional; omit to use plain Neovim vim.ui.select for :CurseModel
  },
  ui = {
    -- optional; omit to use plain Neovim vim.ui.input / vim.notify
  },
})
```

Set `log = { enabled = false }` to disable file logging entirely.

Set `vim.g.curse_debug = true` to enable debug output regardless of config.

## Model switching

- Default model is `composer-2.5-fast`
- `setup({ model = "..." })` sets the default used on each Neovim start
- `:CurseModel` or `curse.select_model()` switches the model for the current session only (in-memory; restart restores your setup default)
- Model list is fetched from `cursor-agent models` (account-specific)
- Model picker uses plain Neovim `vim.ui.select` by default via the `component` module
- Public API: `curse.get_model()`, `curse.set_model(slug)`, `curse.select_model()`, `curse.component`

## Model picker (optional)

The model picker lives in `curse.component`. Override `picker.backend` to use mini.pick, snacks, telescope, or another UI:

```lua
local component = require("curse.component")

require("curse").setup({
  picker = {
    backend = function(items, opts, on_choice)
      require("mini.pick").ui_select()(items, {
        prompt = opts.prompt,
        format_item = function(entry)
          return component.format_model_item(entry, opts.active)
        end,
      }, on_choice)
    end,
  },
})
```

**snacks.nvim:**

```lua
local component = require("curse.component")

require("curse").setup({
  picker = {
    backend = function(items, opts, on_choice)
      require("snacks.picker").select(items, {
        prompt = opts.prompt,
        format_item = function(entry)
          return component.format_model_item(entry, opts.active)
        end,
      }, on_choice)
    end,
  },
})
```

**telescope.nvim** (Neovim 0.11+ built-in picker or telescope extension):

```lua
local component = require("curse.component")

require("curse").setup({
  picker = {
    backend = function(items, opts, on_choice)
      vim.pick.select(items, {
        prompt = opts.prompt,
        format_item = function(entry)
          return component.format_model_item(entry, opts.active)
        end,
      }, on_choice)
    end,
  },
})
```

Backend signature: `function(items: CurseModelEntry[], opts: { prompt?, active? }, on_choice: fun(choice?))`. Use `component.format_model_item(entry, opts.active)` for consistent labels.

## Custom UI (optional)

By default, curse uses plain Neovim UI for prompts and notifications. Override hooks in config:

```lua
require("curse").setup({
  ui = {
    -- input = function(opts, on_confirm) ... end,
    -- notify = function(msg, level, opts) ... end,
  },
})
```

Note: model selection uses `picker.backend`, not `ui.select`.

## Behavior

- Runs `cursor-agent` asynchronously via `vim.system`
- Passes the active model to every run via `--model` (task-specific `search.model` / `tutorial.model` overrides still apply when configured)
- Shows status with `vim.notify` (or your `ui.notify` hook)
- Queues additional requests while one is active
- Reloads the source buffer after a successful ask
- Search and tutorial run in read-only `ask` mode and present output via quickfix or a markdown split
- Treats unsaved buffer content as newer than disk when building context

## License

MIT — see [LICENSE](LICENSE).
