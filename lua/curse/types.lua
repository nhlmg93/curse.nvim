--- Public type definitions for require("curse").
--- Internal modules should not redefine these types.

---@alias CurseStatus "collecting_context"|"starting"|"thinking"|"running_tool"|"done"|"error"|"cancelled"

---@class CurseLineRange
---@field start integer
---@field ["end"] integer

---@class CurseLogConfig
---@field enabled? boolean
---@field path? string
---@field debug? boolean

---@class CurseTaskConfig
---@field model? string
---@field mode? "ask"|"plan"

---@class CurseUiConfig
---@field notify? fun(msg: string, level?: integer, opts?: table)
---@field input? fun(opts: table, on_confirm: fun(input?: string))
---@field select? fun(items: table[], opts: table, on_choice: fun(choice?: any, idx?: integer))

---@class CurseChatConfig
---@field storage_path? string
---@field all_workspaces? boolean

---@class CurseConfig
---@field mode? "plan"|"ask"|nil
---@field model? string
---@field append_system_prompt? string
---@field context? { max_bytes?: integer, ask?: { surrounding_lines?: integer } }
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
---@field model? string
---@field created_at? integer
---@field last_used_at? integer

---@alias CurseChatEntry CurseChat

---@class CurseModelEntry
---@field id string Model slug passed to cursor-agent via --model
---@field name string Human-readable display name
---@field default? boolean Present when cursor-agent marks account default
---@field current? boolean Present when cursor-agent marks CLI current model

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
---@field reload? boolean
---@field skip_system_prompt? boolean
---@field reuse_chat? boolean
---@field capture_output? boolean
---@field require_file_backed? boolean
---@field on_complete? fun(result: CurseRunResult)

---@class CurseListChatsOpts
---@field workspace? string
---@field all_workspaces? boolean

---@class CurseGetCmdOpts
---@field reuse_chat? boolean

---@module curse
---@class curse
---@field setup fun(opts?: CurseConfig)
---@field prompt fun(range?: CurseLineRange)
---@field cancel fun()
---@field show_log fun()
---@field list_chats fun(opts?: CurseListChatsOpts, callback: fun(chats: CurseChat[], err?: string))
---@field get_active_chat fun(): CurseChat?
---@field set_active_chat fun(id: string)
---@field select_chat fun(opts?: CurseListChatsOpts)
---@field new_chat fun()
---@field list_models fun(callback: fun(models: CurseModelEntry[], err?: string))
---@field get_model fun(): string
---@field set_model fun(slug: string)
---@field select_model fun()
---@field run fun(opts: CurseRunOpts)
---@field get_cmd fun(bufnr?: integer, opts?: CurseGetCmdOpts): string[]
---@field visual_range fun(): CurseLineRange?
---@field is_running fun(): boolean
---@field queue_size fun(): integer

return {}
