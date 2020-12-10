--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Multiple Unit Train Control
 * File: createManualWagonRecipePrototype.lua
 * Description: Creates a new dummy recipe for the "-auto" version with:
 *   - Recipe is hidden from player.
 *   - name and ingredient[1].name are the MU version.
 *   - result is the standard version.
 --]]


function createManualWagonRecipePrototype(name, newName)
	-- Check that source exists
	if not data.raw["artillery-wagon"][name] then
		error("artillery-wagon " .. name .. " doesn't exist")
	end
	
	-- Don't copy anything, make it directly convertible
	local newRecipe = 
	{
		type = "recipe",
		name = newName,
		ingredients = {{newName, 1}},
		result = name,
		hidden = true
	}
	
	return newRecipe
end

return createManualWagonRecipePrototype