--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: signals.lua
 * Description: Adds circuit signal to control artillery wagons
--]]


data:extend({
  --[[{
    type = "item-subgroup",
    name = "smart-artillery-signals",
    group = "signals",
    order = "g"
  },--]]
  {
    type = "virtual-signal",
    name = "signal-smart-artillery-control",
    icons =
    {
      {icon = "__SmartArtilleryWagons__/graphics/smart-artillery-control.png"}
    },
    icon_size = 32,
    subgroup = "virtual-signal-color",
    order = "z-z"
  },
})