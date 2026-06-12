local component = require("curse.component")
local config = require("curse.config")
local interaction = require("curse.interaction")
local models = require("curse.models")

local M = {}

function M.prompt()
  models.list(function(list, err)
    if err then
      interaction.notify("curse: " .. err .. "; showing fallback models", vim.log.levels.WARN)
    end

    component.open_model_picker({
      items = list,
      active = config.get_model(),
      prompt = "Curse model: ",
    }, function(choice)
      if not choice then return end
      config.set_model(choice.id)
      interaction.notify("curse: model set to " .. choice.name, vim.log.levels.INFO, { title = "curse" })
    end)
  end)
end

return M
