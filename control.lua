--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: control.lua
 * Description: Runtime operation script for replacing artillery wagons.
 * Functions:
 *  => OnTrainChangedState
 *  ==> If train is stopped at station and signal is present, change wagons as needed.
 *
 --]]

replaceCarriage = require("__Robot256Lib__/script/carriage_replacement").replaceCarriage
blueprintLib = require("__Robot256Lib__/script/blueprint_replacement")


------------------------- GLOBAL TABLE INITIALIZATION ---------------------------------------

-- Set up the mapping between normal and MU locomotives
-- Extract from the game prototypes list what MU locomotives are enabled
local function InitEntityMaps()

	global.upgrade_pairs = {}
	global.downgrade_pairs = {}
	
	-- Retrieve entity names from dummy technology, store in global variable
	for _,effect in pairs(game.technology_prototypes["smart-artillery-wagons-list"].effects) do
		if effect.type == "unlock-recipe" then
			local recipe = game.recipe_prototypes[effect.recipe]
			local std = recipe.products[1].name
			local auto = recipe.ingredients[1].name
			global.upgrade_pairs[std] = auto
			global.downgrade_pairs[auto] = std
			--game.print("Registered SAW mapping "..std.." to "..auto)
		end
	end
	
end


------------------------- WAGON REPLACEMENT CODE -------------------------------

-- Process up to one valid train from the queue per tick
--   The queue prevents us from processing another train until we finish with the first one.
--   That way we don't process "intermediate" trains created while replacing a locomotive by the script.
local function ProcessTrain(t)

	local replace_wagons = {}
	local signal_mode = 0
	
	if t and t.valid then
		--game.print("SAW processing train "..t.id)
		
		-- Check if the train is at a stop and the firing signal is present
		if t.station and t.station.valid then
			-- We are at a station, check circuit conditions
			local signals = t.station.get_merged_signals()
			--game.print("At valid station "..t.id)
			if signals then 
				--game.print("with valid signal list "..t.id)
				for _,v in pairs(signals) do
					--game.print("found signal. "..tostring(v.signal.name).." count="..tostring(v.count).." "..t.id)
					if v.signal.name == "signal-smart-artillery-control" then
						if v.count > 0 then
							signal_mode = 1
						elseif v.count < 0 then
							signal_mode = -1
						end
						break
					end
				end
			end
		else
			--game.print("Not at station "..t.id)
		end
		
		-- Replace artillery wagons according to signal
		if signal_mode == 1 then
			-- Look for normal wagons to upgrade to auto
			for _,c in pairs(t.carriages) do
				if c.type == "artillery-wagon" then
					if global.upgrade_pairs[c.name] then
						table.insert(replace_wagons,{c,global.upgrade_pairs[c.name]})
					end
				end
			end
			if next(replace_wagons) then
				game.print("Enabling Artillery on Train " .. t.id)
			end
			
		elseif signal_mode == -1 then
			-- Look for auto wagons to downgrade to normal
			for _,c in pairs(t.carriages) do
				if c.type == "artillery-wagon" then
					if global.downgrade_pairs[c.name] then
						table.insert(replace_wagons,{c,global.downgrade_pairs[c.name]})
					end
				end
			end
			if next(replace_wagons) then
				game.print("Disabling Artillery on Train " .. t.id)
			end
		end
		
		-- Execute replacements
		for _,r in pairs(replace_wagons) do
			-- Replace the wagon
			--game.print("Smart Artillery is replacing ".. r[1].name .. "' with " .. r[2])
			--game.print({"debug-message.saw-replacement-message",r[1].name,r[1].backer_name,r[2]})
			
			replaceCarriage(r[1], r[2])
			
		end
		
	end
end


----------------------------------------------
------ EVENT HANDLING ---

--== ON_TRAIN_CHANGED_STATE EVENT ==--
-- Every time a train arrives at a station, check if we need to replace wagons. 
local function OnTrainChangedState(event)
	-- Event contains train, old_state
	
	if (event.train.state == defines.train_state.wait_station) then
	    
		ProcessTrain(event.train)
		
	end

end


---== ON_PLAYER_CONFIGURED_BLUEPRINT EVENT ==--
-- ID 70, fires when you select a blueprint to place
--== ON_PLAYER_SETUP_BLUEPRINT EVENT ==--
-- ID 68, fires when you select an area to make a blueprint or copy
local function OnPlayerSetupBlueprint(event)
	blueprintLib.mapBlueprint(event,global.downgrade_pairs)
end


--== ON_PLAYER_PIPETTE ==--
-- Fires when player presses 'Q'.  We need to sneakily grab the correct item from inventory if it exists,
--  or sneakily give the correct item in cheat mode.
local function OnPlayerPipette(event)
	blueprintLib.mapPipette(event,global.downgrade_pairs)
end


---- Bootstrap ----
local function init_events()

	-- Subscribe to Blueprint activity always
	script.on_event({defines.events.on_player_setup_blueprint,defines.events.on_player_configured_blueprint}, OnPlayerSetupBlueprint)
	script.on_event(defines.events.on_player_pipette, OnPlayerPipette)

	-- Subscribe to On_Train_Created according to mod enabled setting
	script.on_event(defines.events.on_train_changed_state, OnTrainChangedState)
end

local function OnLoad()
  init_events()
end
script.on_load(OnLoad)

local function OnInit()
  InitEntityMaps()
	init_events()
end
script.on_init(OnInit)

local function OnConfigurationChanged(event)
  InitEntityMaps()
	-- On config change, scrub the list of trains
	init_events()
end
script.on_configuration_changed(OnConfigurationChanged)
