# curse.nvim

Neovim integration for the [cursor-agent](https://cursor.com) CLI. Send prompts from your editor, stream agent status, reload changed buffers on success, open an interactive chat split, and run read-only search and tutorial tasks.

Inspired by and adapted from [pi.nvim](https://github.com/pablopunk/pi.nvim) by [pablopunk](https://github.com/pablopunk). Thank you for the original architecture and patterns.

## Demos

A quick walkthrough of Ask, Search, and Tutorial:

![Overview](demos/out/overview.gif)

<details>
<summary>Per-feature demos</summary>

### `:CurseAsk` — ask with buffer context, edits applied in place

![CurseAsk](demos/out/ask.gif)

### `:CurseAsk` over a visual selection

![CurseAsk visual range](demos/out/ask-visual.gif)

### `:CurseSearch` — semantic search into the quickfix list

![CurseSearch](demos/out/search.gif)

### `:CurseTutorial` — generate a markdown tutorial

![CurseTutorial](demos/out/tutorial.gif)

### `:CurseSessions` — reuse and pick chat sessions

![CurseSessions](demos/out/sessions.gif)

</details>

GIFs are recorded with [VHS](https://github.com/charmbracelet/vhs).

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
| `:CurseChat` | Open an interactive cursor-agent chat in a terminal split |
| `:CurseCancel` | Cancel the active request |
| `:CurseLog` | Open the session log |
| `:CurseNew` | Start a new cursor-agent chat on the next ask |
| `:CurseSessions` | Pick a previous cursor-agent chat session |
| `:CurseSearch` | Semantic project search → quickfix list |
| `:CurseTutorial` | Generate a markdown tutorial in a split |

## Configuration

```lua
require("curse").setup({
  binary = { "cursor-agent" },  -- string or argv prefix; paths are expanded
  skills = true,                -- pass bundled plugin dir for agent skills
  mode = nil,                   -- "plan" | "ask" | nil
  log = {
    enabled = true,
    path = "/tmp/curse.log",
    debug = false,              -- debug logs print to :messages and the log file
  },
  search = { mode = "ask" },
  tutorial = { mode = "ask" },
  chat = {
    height = 35,                -- split height as % of editor lines
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
| `curse.ask_visual()` | Ask from visual mode; captures selection before the input prompt |
| `curse.cancel()` | Cancel the active request |
| `curse.show_log()` | Open the session log buffer |
| `curse.list_chats(opts?, callback)` | List stored chats; `callback(chats, err?)` |
| `curse.get_active_chat()` | Active chat or nil |
| `curse.set_active_chat(chat)` | Set active chat by id string or full `CurseChat` record |
| `curse.select_chat(opts?)` | Built-in session picker |
| `curse.new_chat()` | Clear active chat |
| `curse.sync_active_chat()` | Resolve active chat metadata from disk |

### Extension API

For custom cursor-agent integrations (similar to built-in search/tutorial). May evolve between releases.

| Function | Purpose |
|----------|---------|
| `curse.run(opts)` | Run cursor-agent with custom options (see `CurseRunOpts`) |
| `curse.get_cmd(bufnr?, opts?)` | Build CLI argv for non-interactive runs |
| `curse.get_chat_cmd(bufnr?, opts?)` | Build CLI argv for interactive chat (`--continue` / `--resume`) |
| `curse.get_cwd(bufnr?, opts?)` | Workspace directory for a run |
| `curse.visual_range()` | Current visual selection as `{ start, end, start_col?, end_col? }` |
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

`{ id, name?, workspace?, workspace_hash?, path?, dir?, model?, created_at?, last_used_at? }`

**`CurseLineRange`** — line or character visual selection:

`{ start, end, start_col?, end_col? }` — column fields present for char-visual (`v`) selections.

**`CurseRunOpts`** — extension run options:

| Field | Description |
|-------|-------------|
| `message` | Prompt text (required) |
| `bufnr?` | Source buffer (defaults to current) |
| `range?` | Line or char range for context |
| `cmd?` | CLI argv override (from `get_cmd`) |
| `cwd?` | Working directory override |
| `build_context?` | Custom context builder |
| `reload?` | Reload source buffer on success (default true for ask) |
| `skip_system_prompt?` | Send message only (no context block) |
| `reuse_chat?` | Resume active chat (default true) |
| `capture_output?` | Collect assistant output |
| `require_file_backed?` | Require file-backed buffer when queued |
| `on_complete?` | Callback with `CurseRunResult` on success |

**`CurseRunResult`** — passed to `on_complete`:

`{ status, output, error?, cancelled }` where `status` is a `CurseStatus` string.

## Context and visual selection

Ask requests send **metadata only** — not a full file dump. Every ask includes `File:`, `Cwd:`, and `Filetype:` headers. The bundled [neovim skill](skills/neovim/SKILL.md) tells cursor-agent to read the file with its own tools.

With a visual selection, context also includes:

| Selection | Context fields |
|-----------|----------------|
| Line visual (`V`) | `Selected lines: N-M` |
| Char visual (`v`) | `Selected: line N, columns A-B` (or multi-line variant) |
| Any selection | `Selected text:` with the highlighted content |

`:CurseAsk` on a range preserves char-visual column bounds when invoked from visual mode. Map visual ask explicitly with `curse.ask_visual()` if you want to capture the selection before the input prompt clears visual mode.

## Skills

When `skills = true` (default), curse passes `--plugin-dir` pointing at the plugin root so cursor-agent loads bundled skills. The included **neovim** skill documents editor context fields and edit-vs-ask behavior for in-editor requests.

Set `skills = false` to omit the plugin directory from CLI invocations.

## Interactive chat

`:CurseChat` opens a terminal split running cursor-agent interactively:

- Resumes the active session when one exists (`--resume`), otherwise starts with `--continue`
- Runs in the active chat's workspace, or the current buffer's workspace
- Reuses an existing split when already open; split height defaults to 35% of editor lines (`chat.height`)

Use `:CurseSessions` or `:CurseNew` to switch or reset the session that chat resumes.

## Chat sessions

Ask commands reuse the same **cursor-agent chat** until `:CurseNew` or Neovim exit:

- Each ask sends your message plus buffer metadata (and selection when present), and resumes via `--resume` when a session is active
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
      if choice then require("curse").set_active_chat(choice) end
    end)
  end)
end)
```

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

`:CurseSessions` respects `ui.select` when set.

## Behavior

- Runs `cursor-agent` asynchronously via `vim.system`
- Uses `--model auto` for all runs
- Shows status with `vim.notify` (or your `ui.notify` hook)
- Queues additional requests while one is active
- Reloads the source buffer after a successful ask
- Search and tutorial run in read-only `ask` mode and present output via quickfix or a markdown split
- Treats unsaved buffer content as newer than disk when building selection text

## License

MIT — see [LICENSE](LICENSE).
