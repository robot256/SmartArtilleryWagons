--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: settings.lua
 * Description: Setting to control SAW operation.
--]]

data:extend{
  {
    type = "string-setting",
    name = "smart-artillery-wagons-debug",
    order = "ac",
    setting_type = "runtime-global",
    default_value = "info",
    allowed_values = {"none","error","info","debug"}
  },
}
