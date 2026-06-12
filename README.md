# curse.nvim

Neovim integration for the [cursor-agent](https://cursor.com) CLI. Send prompts from your editor, stream agent status, reload changed buffers on success, and run read-only search and tutorial tasks.

Inspired by and adapted from [pi.nvim](https://github.com/pablopunk/pi.nvim) by [pablopunk](https://github.com/pablopunk). Thank you for the original architecture and patterns.

## Requirements

- Neovim 0.10+
- `cursor-agent` installed and on your `PATH`
- `sqlite3` on your `PATH` (for the session picker)

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
| `:CurseNew` | Start a new cursor-agent chat on the next ask |
| `:CurseSessions` | Pick a previous cursor-agent chat session |
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
  chat = {
    -- storage_path = nil,       -- default: ~/.config/cursor/chats or ~/.cursor/chats
    -- all_workspaces = false,   -- picker lists current workspace only by default
  },
  ui = {
    -- optional; omit to use plain Neovim vim.ui.input / vim.notify / vim.ui.select
  },
})
```

Set `log = { enabled = false }` to disable file logging entirely.

Set `vim.g.curse_debug = true` to enable debug output regardless of config.

## API reference

The public surface is `require("curse")` only. Submodules (`curse.config`, `curse.task`, etc.) are internal and not supported for downstream use.

### Stable API

| Function | Purpose |
|----------|---------|
| `curse.setup(opts?)` | Initialize plugin and register commands |
| `curse.prompt(range?)` | Prompt for a message and run ask (file-backed buffer required) |
| `curse.cancel()` | Cancel the active request |
| `curse.show_log()` | Open the session log buffer |
| `curse.list_chats(opts?, callback)` | List stored chats; `callback(chats, err?)` |
| `curse.get_active_chat()` | Active chat or nil |
| `curse.set_active_chat(id)` | Set active chat for next ask |
| `curse.select_chat(opts?)` | Built-in session picker |
| `curse.new_chat()` | Clear active chat |
| `curse.list_models(callback)` | Async fetch; `callback(models, err?)` |
| `curse.get_model()` | Current session model slug |
| `curse.set_model(slug)` | Set session model slug |
| `curse.select_model()` | Built-in model picker |

### Extension API

For custom cursor-agent integrations (similar to built-in search/tutorial). May evolve between releases.

| Function | Purpose |
|----------|---------|
| `curse.run(opts)` | Run cursor-agent with custom options (see `CurseRunOpts`) |
| `curse.get_cmd(bufnr?, opts?)` | Build CLI argv; pass to `run({ cmd = ... })` |
| `curse.visual_range()` | Current visual selection as `{ start, end }` line range |
| `curse.is_running()` | Whether a request is active |
| `curse.queue_size()` | Number of queued requests |

```lua
require("curse").run({
  message = "Summarize this file",
  capture_output = true,
  on_complete = function(result)
    if result.status == "done" then
      print(result.output)
    end
  end,
})
```

### Types

**`CurseConfig`** — passed to `setup()` (see [Configuration](#configuration) above).

**`CurseChat`** — chat record from `list_chats` / `get_active_chat`:

`{ id, name?, workspace?, workspace_hash?, created_at?, model?, last_used_at? }`

**`CurseModelEntry`** — model from `list_models`:

`{ id, name, default?, current? }`

**`CurseRunOpts`** — extension run options:

| Field | Description |
|-------|-------------|
| `message` | Prompt text (required) |
| `bufnr?` | Source buffer (defaults to current) |
| `range?` | Line range for context |
| `cmd?` | CLI argv override (from `get_cmd`) |
| `build_context?` | Custom context builder |
| `reload?` | Reload source buffer on success (default true for ask) |
| `skip_system_prompt?` | Omit curse system prompt |
| `reuse_chat?` | Resume active chat (default true) |
| `capture_output?` | Collect assistant output |
| `require_file_backed?` | Require file-backed buffer when queued |
| `on_complete?` | Callback with `CurseRunResult` on success |

**`CurseRunResult`** — passed to `on_complete`:

`{ status, output, error?, cancelled }` where `status` is a `CurseStatus` string.

## Chat sessions

Ask commands reuse the same **cursor-agent chat** until `:CurseNew` or Neovim exit:

- First `:CurseAsk` in a chat sends the curse system prompt, your message, and buffer context
- Follow-up asks send **only your message** and resume via `--resume`
- `:CurseNew` clears the active chat; the next ask starts fresh
- `:CurseSearch` and `:CurseTutorial` do not reuse or affect the ask chat

Session list comes from cursor-agent's on-disk storage (`~/.config/cursor/chats/…`), not an in-memory registry — so you can pick up prior sessions after restarting Neovim.

### Custom session picker

```lua
vim.keymap.set("n", "<leader>cs", function()
  require("curse").list_chats({ workspace = vim.fn.getcwd() }, function(chats)
    require("mini.pick").ui_select(chats, {
      prompt = "Curse session: ",
      format_item = function(c) return c.name end,
    }, function(choice)
      if choice then require("curse").set_active_chat(choice.id) end
    end)
  end)
end)
```

## Model switching

- Default model is `composer-2.5-fast`
- `setup({ model = "..." })` sets the default used on each Neovim start
- `:CurseModel` or `curse.select_model()` switches the model for the current session only (in-memory; restart restores your setup default)
- Model list is fetched from `cursor-agent models` (account-specific)
- `:CurseModel` uses plain Neovim `vim.ui.select` by default (via `ui.select` hook when configured)

## Custom UI (optional)

By default, curse uses plain Neovim UI for prompts, notifications, and pickers. Override hooks in config:

```lua
require("curse").setup({
  ui = {
    -- input = function(opts, on_confirm) ... end,
    -- notify = function(msg, level, opts) ... end,
    -- select = function(items, opts, on_choice) ... end,
  },
})
```

`:CurseModel` and `:CurseSessions` respect `ui.select` when set.

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
