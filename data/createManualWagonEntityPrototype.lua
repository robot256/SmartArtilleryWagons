--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: createManualWagonEntityPrototype.lua
 * Description: Copies an artillery-wagon entity prototype and creates the "-auto" version.
 *   The original entity has its "disable_automatic_firing" property set to true.
--]]


function createManualWagonEntityPrototype(name, newName, has_description)
	-- Copy source wagon prototype
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
	
	-- Make it so a normal wagon can be pasted on this blueprint, doesn't really work?
	wagon.additional_pastable_entities = {name}
	
	-- Concatenate the localized name and description string of the source wagon with our template.
	if wagon.localised_name then
    wagon.localised_name = {'template.saw-auto-name',table.deepcopy(wagon.localised_name)}
  else
    wagon.localised_name = {'template.saw-auto-name',{'entity-name.'..name}}
  end
  
  if wagon.localised_description then
    wagon.localised_description = {'template.saw-auto-description',table.deepcopy(wagon.localised_description)}
		oldWagon.localised_description = {'template.saw-manual-description',table.deepcopy(wagon.localised_description)}
	elseif has_description==true then
		wagon.localised_description = {'template.saw-auto-description',{'entity-description.'..name}}
		oldWagon.localised_description = {'template.saw-manual-description',{'entity-description.'..name}}
	else
		wagon.localised_description = {'template.plain-saw-auto-description'}
		oldWagon.localised_description = {'template.plain-saw-manual-description'}
	end
	return wagon
end

return createManualWagonEntityPrototype
