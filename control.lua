--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: control.lua
 * Description: Runtime operation script for replacing artillery wagons.
 * Functions:
 *  => OnTrainChangedState
 *       If train is stopped at station and signal is present, change wagons as needed.
 *  => OnPlayerCreated, OnInit, OnConfigurationChanged
 *       Sets up filtered GUI buttons for each player when they are created or when list of wagons changes.
 *  => OnGuiClick
 *       Changes wagon mode when player clicks GUI buttons.
 --]]

replaceCarriage = require("__Robot256Lib__/script/carriage_replacement").replaceCarriage
blueprintLib = require("__Robot256Lib__/script/blueprint_replacement")


------------------------- GLOBAL TABLE INITIALIZATION ---------------------------------------

-- Set up the mapping between normal and MU locomotives
-- Extract from the game prototypes list what MU locomotives are enabled
local function InitEntityMaps()

	global.upgrade_pairs = {}
	global.downgrade_pairs = {}
  global.upgrade_names = {}
  global.downgrade_names = {}
	
	-- Retrieve entity names from dummy technology, store in global variable
	for _,effect in pairs(game.technology_prototypes["smart-artillery-wagons-list"].effects) do
		if effect.type == "unlock-recipe" then
			local recipe = game.recipe_prototypes[effect.recipe]
			local std = recipe.products[1].name
			local auto = recipe.ingredients[1].name
			global.upgrade_pairs[std] = auto
			global.downgrade_pairs[auto] = std
      table.insert(global.upgrade_names, std)
      table.insert(global.downgrade_names, auto)
			--game.print("Registered SAW mapping "..std.." to "..auto)
		end
	end
	
end


------------------------- GUI CREATION CODE -------------------------------

-- Refresh the SAW GUI element for the given player
local function AddGuisForPlayer(player)
  local gui = player.gui
  
  -- Delete existing GUI elements (because they have old filter lists)
  if gui.relative["saw-upgrade-button"] then
    gui.relative["saw-upgrade-button"].destroy()
  end
  if gui.relative["saw-downgrade-button"] then
    gui.relative["saw-downgrade-button"].destroy()
  end
  
  -- Create new GUI elements with new filter lists
  local one = gui.relative.add{
    type="button", 
    name="saw-upgrade-button", 
    caption={"button-text.saw-enable-button"}, 
    anchor={gui=defines.relative_gui_type.container_gui, 
            position=defines.relative_gui_position.left, 
            names=global.upgrade_names}
  }
  one.style.font = "saw-button"
            
  local two = gui.relative.add{
    type="button", 
    name="saw-downgrade-button", 
    caption={"button-text.saw-disable-button"}, 
    anchor={gui=defines.relative_gui_type.container_gui, 
            position=defines.relative_gui_position.left, 
            names=global.downgrade_names}
  }
  two.style.font = "saw-button"
end

-- Refresh the SAW GUI elements for every player currently in the game
local function InitPlayerGuis()
  for _,player in pairs(game.players) do
    AddGuisForPlayer(player)
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
script.on_event(defines.events.on_train_changed_state, OnTrainChangedState)


--== ON_GUI_CLICKED EVENT ==--
-- Handle when player clicks on our GUI buttons
local function OnGuiClick(event)
  local player = game.players[event.player_index]
  local element = event.element
  
  if element.name == "saw-upgrade-button" then
    --game.print("Player clicked to upgrade wagon "..tostring(player.opened.unit_number))
    local wagon = player.opened
    if global.upgrade_pairs[wagon.name] then
      replaceCarriage(wagon, global.upgrade_pairs[wagon.name])
    end
    
  elseif element.name == "saw-downgrade-button" then
    --game.print("Player clicked to downgrade which wagon "..tostring(player.opened.unit_number))
    local wagon = player.opened
    if global.downgrade_pairs[wagon.name] then
      replaceCarriage(wagon, global.downgrade_pairs[wagon.name])
    end
  end

end
script.on_event(defines.events.on_gui_click, OnGuiClick)


--== ON_PLAYER_CREATED EVENT ==--
-- Add GUI buttons to each player when they join the game
local function OnPlayerCreated(event)
  local player = game.players[event.player_index]
  if player and player.valid then
    AddGuisForPlayer(player)
  end
end
script.on_event(defines.events.on_player_created, OnPlayerCreated)


---== ON_PLAYER_CONFIGURED_BLUEPRINT EVENT ==--
-- ID 70, fires when you select a blueprint to place
--== ON_PLAYER_SETUP_BLUEPRINT EVENT ==--
-- ID 68, fires when you select an area to make a blueprint or copy
local function OnPlayerSetupBlueprint(event)
	blueprintLib.mapBlueprint(event,global.downgrade_pairs)
end
script.on_event({defines.events.on_player_setup_blueprint,defines.events.on_player_configured_blueprint}, OnPlayerSetupBlueprint)


--== ON_PLAYER_PIPETTE ==--
-- Fires when player presses 'Q'.  We need to sneakily grab the correct item from inventory if it exists,
--  or sneakily give the correct item in cheat mode.
local function OnPlayerPipette(event)
	blueprintLib.mapPipette(event,global.downgrade_pairs)
end
script.on_event(defines.events.on_player_pipette, OnPlayerPipette)


---- Bootstrap ----
--local function OnLoad()  
--end
--script.on_load(OnLoad)

local function OnInit()
  InitEntityMaps()
  InitPlayerGuis()
end
script.on_init(OnInit)

local function OnConfigurationChanged(event)
  InitEntityMaps()
  InitPlayerGuis()
end
script.on_configuration_changed(OnConfigurationChanged)
