--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: createManualWagon.lua
 * Description: Creates new prototypes for a manual- and auto-fire artillery wagon.
--]]

require ("data.createManualWagonEntityPrototype")
require ("data.createManualWagonItemPrototype")
require ("data.createManualWagonRecipePrototype")

function createManualWagon(oldName, newName, itemType, hasDescription)
	-- Check that source exists
	if not data.raw["artillery-wagon"][oldName] then
		error("Entity artillery-wagon " .. oldName .. " doesn't exist")
	end
  
  log("Creating artillery wagon \""..newName.."\"")
	
	data:extend{
		createManualWagonItemPrototype(itemType, oldName, newName),
		createManualWagonEntityPrototype(oldName, newName, hasDescription),
		createManualWagonRecipePrototype(oldName, newName)
	}
	table.insert(data.raw.technology["smart-artillery-wagons-list"].effects, {type = "unlock-recipe", recipe = newName})
	
end

return createManualWagon

