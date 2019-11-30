--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Multiple Unit Train Control
 * File: createManualWagonItemPrototype.lua
 * Description: Copies a locomotive item and creates the "-mu" version with:
 *   - MU localization text is added to name and description fields.
--]]


function createManualWagonItemPrototype(item_type,name,newName,hasDescription)
	-- Check that source exists
	if not data.raw[item_type][name] then
		error("artillery-wagon item " .. name .. " doesn't exist")
	end
	
	-- Copy source locomotive prototype
	local newItem = copy_prototype(data.raw[item_type][name], newName)
	
	newItem.order = "a[train-system]-fz[artillery-wagon-auto]" -- this doesn't get copied??
	
	-- Fix the localization
	newItem.localised_name = {'template.saw-auto-name',{'entity-name.'..name}}
	if hasDescription then
		newItem.localised_description = {'template.saw-auto-item-description',{'entity-name.'..name}}
	else
		newItem.localised_description = {'template.saw-auto-item-description'}
	end
	return newItem
end
return createManualWagonItemPrototype