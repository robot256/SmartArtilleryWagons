--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: technology.lua
 * Description: Adds dummy technology for wagon mapping
--]]


data:extend{

  -----------------
  -- Add dummy technology to catalog the Artillery Wagon conversions
  {
    type = "technology",
	name = "smart-artillery-wagons-list",
	icon = "__SmartArtilleryWagons__/graphics/smart-artillery-control.png",
	icon_size = 32,
	enabled = false,
	effects = 
	{
      
    },
    unit =
    {
      count = 8,
      ingredients = {{"automation-science-pack", 1}},
      time = 1
    },
    order = "c-a"
  },
}
