---@meta
--- Public type definitions for curse.nvim (LuaCATS only; not loaded at runtime).

---@alias CurseStatus "collecting_context"|"starting"|"thinking"|"running_tool"|"done"|"error"|"cancelled"

---@class CurseLineRange
---@field start integer
---@field ["end"] integer
---@field start_col? integer
---@field end_col? integer

---@class CurseLogConfig
---@field enabled? boolean
---@field path? string
---@field debug? boolean

---@class CurseTaskConfig
---@field mode? "ask"|"plan"

---@class CurseUiConfig
---@field notify? fun(msg: string, level?: integer, opts?: table)
---@field input? fun(opts: table, on_confirm: fun(input?: string))
---@field select? fun(items: table[], opts: table, on_choice: fun(choice?: any, idx?: integer))

---@class CurseChatConfig
---@field storage_path? string
---@field all_workspaces? boolean
---@field height? number

---@class CurseConfig
---@field binary? string|string[]
---@field skills? boolean
---@field mode? "plan"|"ask"|nil
---@field log? CurseLogConfig
---@field search? CurseTaskConfig
---@field tutorial? CurseTaskConfig
---@field chat? CurseChatConfig
---@field ui? CurseUiConfig

---@class CurseChat
---@field id string
---@field name? string
---@field workspace? string
---@field workspace_hash? string
---@field path? string
---@field dir? string
---@field model? string
---@field created_at? integer
---@field last_used_at? integer

---@class CurseRunResult
---@field status CurseStatus
---@field output string
---@field error? string
---@field cancelled boolean

---@class CurseRunOpts
---@field message string
---@field build_context? fun(): string
---@field bufnr? integer
---@field range? CurseLineRange
---@field cmd? string[]
---@field cwd? string
---@field reload? boolean
---@field skip_system_prompt? boolean
---@field reuse_chat? boolean
---@field capture_output? boolean
---@field require_file_backed? boolean
---@field on_complete? fun(result: CurseRunResult)

---@class CurseListChatsOpts
---@field workspace? string
---@field workspaces? string[]
---@field all_workspaces? boolean

---@class CurseGetCmdOpts
---@field reuse_chat? boolean
---@field skip_system_prompt_cli? boolean
---@field interactive? boolean

---@class CurseSession
---@field id integer
---@field status CurseStatus
---@field process vim.SystemObj?
---@field source_bufnr integer?
---@field cwd string?
---@field started_at integer
---@field ended_at integer?
---@field active_tool string?
---@field last_error string?
---@field closing boolean
---@field cancelled boolean
---@field saw_terminal_event boolean
---@field history string[]
---@field last_notified_signature string?
---@field reload? boolean
---@field capture_output? boolean
---@field on_complete? fun(result: CurseRunResult)
---@field output_parts? string[]
---@field output? string

---@class CurseUiRenderOpts
---@field queued? integer

---@module 'curse'
---@class curse
---@field setup fun(opts?: CurseConfig)
---@field prompt fun(range?: CurseLineRange)
---@field ask_visual fun()
---@field cancel fun()
---@field show_log fun()
---@field list_chats fun(opts?: CurseListChatsOpts, callback: fun(chats: CurseChat[], err?: string))
---@field get_active_chat fun(): CurseChat?
---@overload fun(chat: string)
---@overload fun(chat: CurseChat)
---@field set_active_chat fun(chat: CurseChat|string)
---@field select_chat fun(opts?: CurseListChatsOpts)
---@field new_chat fun()
---@field run fun(opts: CurseRunOpts)
---@field get_cmd fun(bufnr?: integer, opts?: CurseGetCmdOpts): string[]
---@field get_chat_cmd fun(bufnr?: integer, opts?: CurseGetCmdOpts): string[]
---@field sync_active_chat fun(): CurseChat?
---@field get_cwd fun(bufnr?: integer, opts?: { cwd?: string }): string
---@field visual_range fun(): CurseLineRange?
---@field is_running fun(): boolean
---@field queue_size fun(): integer
