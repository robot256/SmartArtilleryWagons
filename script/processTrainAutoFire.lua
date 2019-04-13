--[[ Copyright (c) 2019 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: processTrainAutoFire.lua
 * Description: Reads a train and changes all manual artillery wagons to auto-firing.
--]]


function processTrainAutoFire(t)

	-- Change all normal wagons to auto-firing
	local replace_wagons = {}
	for i,c in ipairs(t.carriages) do
		if c.type == "artillery-wagon" then
			if global.upgrade_pairs[c.name] then
				game.print("AutoFire found manual wagon, queued "..t.id)
				table.insert(replace_wagons,{c,global.upgrade_pairs[c.name]})
			elseif global.downgrade_pairs[c.name] then
				game.print("AutoFire found auto wagon, not queued "..t.id)
			end
		end
	end

	return replace_wagons

end

return processTrainAutoFire
