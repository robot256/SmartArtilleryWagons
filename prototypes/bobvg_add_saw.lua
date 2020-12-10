--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: bobvg_add_saw.lua
 * Description: Integration with Bob's Warfare
--]]

if data.raw["artillery-wagon"]["bob-artillery-wagon-2"] then
	createManualWagon("bob-artillery-wagon-2","bob-artillery-wagon-2-auto","item-with-entity-data",false)
end

if data.raw["artillery-wagon"]["bob-artillery-wagon-3"] then
	createManualWagon("bob-artillery-wagon-3","bob-artillery-wagon-3-auto","item-with-entity-data",false)
end
