--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Multiple Unit Train Control
 * File: replaceArtilleryWagon.lua
 * Description: Replaces one Artillery Wagon Entity with a new one of a different entity-name.
 *    Preserves as many properties of the original as possible.
--]]


function replaceArtilleryWagon(wagon, newName)

	
	-- Save basic parameters
	local position = wagon.position
	local force = wagon.force
	local surface = wagon.surface
	local orientation = wagon.orientation
	--local backer_name = wagon.backer_name
	local color = wagon.color
	local health = wagon.health
	local to_be_deconstructed = wagon.to_be_deconstructed(force)
	local player_driving = wagon.get_driver()
	local kills = wagon.kills
	
	-- Save equipment grid contents
	local grid_equipment = saveGrid(wagon.grid)
	
	-- Save item requests left over from a blueprint
	local item_requests = saveItemRequestProxy(wagon)
	
	-- Save the ammunition inventory
	local inventory = wagon.get_inventory(defines.inventory.artillery_wagon_ammo).get_contents()
	
	-- Adjust the direction of the new wagon
	-- This mapping was determined by brute force because direction and orientation for trains are stupid.
	local newDirection = 0
	if orientation > 0 and orientation <= 0.5 then
		newDirection = 2
	end
	
	-- Save the train schedule.  If we are replacing a lone MU with a regular wagon, the train schedule will be lost when we delete it.
	local train_schedule = wagon.train.schedule
	
	-- Save automatic train mode
	local manual_mode = wagon.train.manual_mode
	
	-- Save its coupling state.  By default, created wagons couple to everything nearby, which we have to undo
	--   if we're replacing after intentional uncoupling.
	local disconnected_back = wagon.disconnect_rolling_stock(defines.rail_direction.back)
	local disconnected_front = wagon.disconnect_rolling_stock(defines.rail_direction.front)
	
	-- Destroy the old Locomotive so we have space to make the new one
	--wagon.destroy({raise_destroy=true})
	wagon.destroy()
	
	-- Create the new wagonmotive in the same spot and orientation
	local newWagon = surface.create_entity{name=newName, position=position, direction=newDirection, force=force, create_build_effect_smoke=false}
	
	-- Restore coupling state
	if not disconnected_back then
		newWagon.disconnect_rolling_stock(defines.rail_direction.back)
	end
	if not disconnected_front then
		newWagon.disconnect_rolling_stock(defines.rail_direction.front)
	end
	
	-- Restore parameters
	--newWagon.backer_name = backer_name
	if color then   -- color is nil if you never changed it!
		newWagon.color = color
	end
	newWagon.health = health
	newWagon.kills = kills
	if to_be_deconstructed == true then
		newWagon.order_deconstruction(force)
	end
	
	-- Restore item_request_proxy by creating a new one
	if item_requests then
		newProxy = surface.create_entity{name="item-request-proxy", position=position, force=force, target=newWagon, modules=item_requests}
	end
	
	-- Restore the inventory
	newInventory = newWagon.get_inventory(defines.inventory.artillery_wagon_ammo)
	for k,v in pairs(inventory) do
		newInventory.insert({name=k, count=v})
	end
	
	-- Restore the equipment grid
	if grid_equipment and newWagon.grid and newWagon.grid.valid then
		restoreGrid(newWagon.grid, grid_equipment)
	end
	
	-- Restore the player driving
	if player_driving then
		newWagon.set_driver(player_driving)
	end
	
	-- Restore the train schedule and mode
	newWagon.train.schedule = train_schedule
	newWagon.train.manual_mode = manual_mode
	
	-- After all that, fire an event so other scripts can reconnect to it
	script.raise_event(defines.events.script_raised_built, {entity = newWagon})
	
	
	--game.print("Finished replacing. Used direction "..newDirection..", new orientation: " .. newWagon.orientation)
	return newWagon
end

return replaceLocomotive
