--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: processTrainManualFire.lua
 * Description: Reads a train and changes all auto-firing artillery wagons to manual-firing.
--]]


function processTrainManualFire(t)

	-- Change all auto-firing wagons to normal
	local replace_wagons = {}
	for i,c in ipairs(t.carriages) do
		if c.type == "artillery-wagon" then
			if global.downgrade_pairs[c.name] then
				game.print("ManualFire found auto wagon, queued "..t.id)
				table.insert(replace_wagons,{c,global.downgrade_pairs[c.name]})
			elseif global.upgrade_pairs[c.name] then
				game.print("ManualFire found manual wagon, not queued "..t.id)
			end
		end
	end

	return replace_wagons

end

return processTrainManualFire
