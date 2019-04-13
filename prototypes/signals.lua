--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: signals.lua
 * Description: Adds circuit signal to control artillery wagons
--]]


data:extend({
  {
    type = "item-subgroup",
    name = "smart-artillery-signals",
    group = "signals",
    order = "g"
  },
  {
    type = "virtual-signal",
    name = "smart-artillery-enable",
    icons =
    {
      {icon = "__base__/graphics/icons/artillery-targeting-remote.png"}
    },
    icon_size = 32,
    subgroup = "smart-artillery-signals",
    order = "a-a"
  },
})