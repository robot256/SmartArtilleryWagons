--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: createManualWagonEntityPrototype.lua
 * Description: Copies an artillery-wagon entity prototype and creates the "-auto" version.
 *   The original entity has its "disable_automatic_firing" property set to true.
--]]


function createManualWagonEntityPrototype(name, newName, has_description)
	-- Copy source wagonmotive prototype
	local oldWagon = data.raw["artillery-wagon"][name]
	local wagon = table.deepcopy(oldWagon)
	
	-- Change the flag of the original wagon
	data.raw["artillery-wagon"][name].disable_automatic_firing = true
	
	-- Change name of prototype
	wagon.name = newName
	-- Make this entity non-placeable (you're not allowed to have -mu items in your inventory), doesn't really work?
	if(wagon.flags["placeable-neutral"]) then
		wagon.flags["placeable-neutral"] = nil
	end
	if(wagon.flags["placeable-player"]) then
		wagon.flags["placeable-player"] = nil
	end
	if(wagon.flags["placeable-enemy"]) then
		wagon.flags["placeable-enemy"] = nil
	end
	
	-- Make it so a normal wagonmotive can be pasted on this blueprint, doesn't really work?
	wagon.additional_pastable_entities = {name}
	
	-- Concatenate the localized name and description string of the source wagon with our template.
	wagon.localised_name = {'template.saw-auto-name',{'entity-name.'..name}}
	if has_description==true then
		wagon.localised_description = {'template.saw-auto-description',{'entity-description.'..name}}
	else
		wagon.localised_description = {'template.plain-saw-auto-description'}
	end
	return wagon
end

return createManualWagonEntityPrototype
