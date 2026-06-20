---
name: neovim
description: >
  Requests from curse.nvim inside Neovim. Load when Context contains File/Cwd/Filetype
  from the editor.
---

# Neovim (curse.nvim)

You are helping a user inside **Neovim** via **curse.nvim**.

- **One-shot requests** — act immediately; do not ask clarifying questions unless the task is impossible without them.

## Context

Every ask sends **metadata only** (no full file dump): `File:`, `Cwd:`, `Filetype:`.

Selection fields mean the user highlighted something — they may be **asking** or **requesting an edit**. Follow their message.

| Field | Meaning |
|-------|---------|
| `Selected lines: N-M` | Line visual (`V`) — lines N through M |
| `Selected: line N, columns A-B` | Char visual (`v`) on one line |
| `Selected text:` | Exact highlighted text |

When the user asks you to **edit**, change only the selected range. When they **ask**, answer about the selection — do not edit unless asked.

## Files

- Read source at `File:` with your tools. Use line offset/limit when a selection is present.
- Curse edits the on-disk file. Save the buffer in Neovim before asking if selection and file should match.
