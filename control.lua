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


-- Signal names
local SIGNAL_NAME = "signal-smart-artillery-control"

-- GUI element names
local ENABLE_FRAME = "saw-upgrade-frame"
local ENABLE_BUTTON = "saw-upgrade-button"
local DISABLE_BUTTON = "saw-downgrade-button"
local ENABLE_CHECKBOX = "saw-upgrade-checkbox"
local ENABLED_DISPLAY = "saw-enabled-display"
local TRAIN_DISPLAY = "saw-train-display"
local DISABLE_FRAME = "saw-downgrade-frame"  -- Deprecated

local ENABLE_DELAY = 60  -- Ticks before train will switch from manual to automatic
local DISABLE_DELAY = 30  -- Ticks before train will switch from automatic to manual
local ENABLE_DONE = ENABLE_DELAY + 1
local DISABLE_DONE = DISABLE_DELAY + 1

-- Cached mod settings
local settings_debug = settings.global["smart-artillery-wagons-debug"].value


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
      if settings_debug == "info" then
        game.print{"message-template.saw-mapping-message", game.entity_prototypes[std].localised_name, game.entity_prototypes[auto].localised_name}
      elseif settings_debug == "debug" then
        game.print{"message-template.saw-mapping-message", std, auto}
      end
    end
  end

end


------------------------- GUI CREATION CODE -------------------------------

-- Refresh the SAW GUI element for the given player
local function AddGuisForPlayer(player)
  local gui = player.gui

  -- Delete existing GUI elements (because they have old filter lists)
  if gui.relative[ENABLE_BUTTON] then
    gui.relative[ENABLE_BUTTON].destroy()
  end
  if gui.relative[DISABLE_BUTTON] then
    gui.relative[DISABLE_BUTTON].destroy()
  end
  if gui.relative[ENABLE_FRAME] then
    gui.relative[ENABLE_FRAME].destroy()
  end
  if gui.relative[DISABLE_FRAME] then
    gui.relative[DISABLE_FRAME].destroy()
  end

  -- Create GUI frame with button for enable/disable, and checkbox for circuit control
  local frame1 = gui.relative.add{
    type="frame",
    name=ENABLE_FRAME,
    caption={"gui-text.saw-frame-heading"},
    direction="vertical",
    anchor={gui=defines.relative_gui_type.container_gui,
            position=defines.relative_gui_position.left,
            type="artillery-wagon"}
  }
  local button1 = frame1.add{
    type="button",
    name=ENABLE_BUTTON,
    caption={"gui-text.saw-enable-button"}
  }
  button1.style.font = "saw-button"
  button1.style.horizontally_stretchable = true
  local button2 = frame1.add{
    type="button",
    name=DISABLE_BUTTON,
    caption={"gui-text.saw-disable-button"}
  }
  button2.style.font = "saw-button"
  button2.style.horizontally_stretchable = true
  local check1 = frame1.add{
    type="checkbox",
    name=ENABLE_CHECKBOX,
    caption={"gui-text.saw-circuit-checkbox"},
    state=true
  }
  frame1.add{type="line"}
  local disp1 = frame1.add{
    type="label",
    name=TRAIN_DISPLAY,
    caption={"gui-text.saw-train-display",0}
  }
  local disp2 = frame1.add{
    type="label",
    name=ENABLED_DISPLAY,
    caption={"gui-text.saw-enabled-display",0,0}
  }
  
end

-- Refresh the SAW GUI elements for every player currently in the game
local function InitPlayerGuis()
  for _,player in pairs(game.players) do
    AddGuisForPlayer(player)
  end
end


-- Update Checkboxes for a particular wagon
local function UpdateCheckbox(wagon)
  -- do it for all players
  for _,player in pairs(game.players) do
    if player.opened and player.opened == wagon then
      if global.wagon_manual[wagon.unit_number] == true then
        player.gui.relative[ENABLE_FRAME][ENABLE_CHECKBOX].state = false
      else
        player.gui.relative[ENABLE_FRAME][ENABLE_CHECKBOX].state = true
      end
    end
  end
end


-- Count how many artillery are autofire & total
local function CountArtillery(train)
  local total = 0
  local active = 0
  for _,wagon in pairs(train.carriages) do
    if wagon.type == "artillery-wagon" then
      total = total + 1
      if global.downgrade_pairs[wagon.name] then
        active = active + 1
      end
    end
  end
  return active, total
end


-- Find every player with a GUI opened for an artillery wagon in this train and update their statistics
local function UpdateCountDisplay(train, active, total)
  for _,wagon in pairs(train.carriages) do
    if wagon.type == "artillery-wagon" then
      for _,player in pairs(game.players) do
        if player.opened and player.opened == wagon then
          player.gui.relative[ENABLE_FRAME][TRAIN_DISPLAY].caption = {"gui-text.saw-train-display",train.id}
          player.gui.relative[ENABLE_FRAME][ENABLED_DISPLAY].caption = {"gui-text.saw-enabled-display",active,total}
        end
      end
    end
  end
end


--== ON_GUI_CHECKED_STATE_CHANGED EVENT ==--
-- Handle when player clicks on our GUI checkboxes
-- Checkbox is synchronized throughout the entire train
local function OnGuiCheckedStateChanged(event)
  local player = game.players[event.player_index]
  local element = event.element

  if element.name == ENABLE_CHECKBOX then
    local open_wagon = player.opened
    if open_wagon and open_wagon.valid then
      local train = open_wagon.train
      -- For every artillery wagon in the same train as the wagon we opened
      for _,wagon in pairs(train.carriages) do
        if wagon.type == "artillery-wagon" then
          -- Update wagon_manual state for this artillery wagon
          if element.state == false then
            global.wagon_manual[wagon.unit_number] = true
          else
            global.wagon_manual[wagon.unit_number] = nil
          end
          -- Update wagon state display for all players with this wagon's GUI opened
          UpdateCheckbox(wagon)
        end
      end

      -- Refresh train state immediately if we just switched it to enable circuit control
      if element.state == true then
        if global.stopped_trains[train.id] then
          global.stopped_trains[train.id].enable_counter = nil
          global.stopped_trains[train.id].disable_counter = nil
        end
      end
    end
  end

end
script.on_event(defines.events.on_gui_checked_state_changed, OnGuiCheckedStateChanged)


--== ON_GUI_OPENED EVENT ==--
-- Handle when player opens a wagon GUI and update the checkboxes
local function OnGuiOpened(event)
  local player = game.players[event.player_index]
  if event.gui_type == defines.gui_type.entity then
    if event.entity and event.entity.valid then
      local entity = event.entity
      if entity.type == "artillery-wagon" then
        -- Update state of checkbox to match this particular wagon
        UpdateCheckbox(entity)
        -- Update the statistics to match this train
        local active, total = CountArtillery(entity.train)
        player.gui.relative[ENABLE_FRAME][TRAIN_DISPLAY].caption = {"gui-text.saw-train-display",entity.train.id}
        player.gui.relative[ENABLE_FRAME][ENABLED_DISPLAY].caption = {"gui-text.saw-enabled-display",active,total}
      end

    end
  end
end
script.on_event(defines.events.on_gui_opened, OnGuiOpened)


--== ON_PLAYER_CREATED EVENT ==--
-- Add GUI buttons to each player when they join the game
local function OnPlayerCreated(event)
  local player = game.players[event.player_index]
  if player and player.valid then
    AddGuisForPlayer(player)
  end
end
script.on_event(defines.events.on_player_created, OnPlayerCreated)



------------------------- WAGON REPLACEMENT CODE -------------------------------


local function EnableTrain(train, forced)
  local replace_wagons = {}
  -- Look for normal wagons to upgrade to auto
  for _,c in pairs(train.carriages) do
    if global.upgrade_pairs[c.name] and (forced or not global.wagon_manual[c.unit_number]) then
      table.insert(replace_wagons,{c,global.upgrade_pairs[c.name]})
    end
  end
  
  -- Execute replacements
  local num_replaced = 0
  local original_train_id = train.id
  local new_train = nil
  for _,r in pairs(replace_wagons) do
    -- Replace the wagon if it is not set to manual mode
    local old_state = global.wagon_manual[r[1].unit_number]
    local new_wagon = replaceCarriage(r[1], r[2])
    if new_wagon then
      global.wagon_manual[new_wagon.unit_number] = old_state
      UpdateCheckbox(new_wagon)
      num_replaced = num_replaced + 1
      new_train = new_wagon.train
    else
      if settings_debug ~= "none" then
        game.print({"message-template.saw-replacement-error-message", original_train_id})
      end
    end
  end
  if (settings_debug == "info" or settings_debug == "debug") then
    if num_replaced > 0 and new_train and new_train.valid then
      local active, total = CountArtillery(new_train)
      game.print{"message-template.saw-enable-train-message", original_train_id, active, total}
    end
  end
end

local function DisableTrain(train, forced)
  local replace_wagons = {}
  -- Look for auto wagons to downgrade to normal
  for _,c in pairs(train.carriages) do
    if global.downgrade_pairs[c.name] and (forced or not global.wagon_manual[c.unit_number]) then
      table.insert(replace_wagons,{c,global.downgrade_pairs[c.name]})
    end
  end
  
  -- Execute replacements
  local num_replaced = 0
  local original_train_id = train.id
  local new_train = nil
  for _,r in pairs(replace_wagons) do
    -- Replace the wagon if it is not set to manual mode
    local old_state = global.wagon_manual[r[1].unit_number]
    local new_wagon = replaceCarriage(r[1], r[2])
    if new_wagon then
      global.wagon_manual[new_wagon.unit_number] = old_state
      UpdateCheckbox(new_wagon)
      num_replaced = num_replaced + 1
      new_train = new_wagon.train
    else
      if settings_debug ~= "none" then
        game.print{"message-template.saw-replacement-error-message", original_train_id}
      end
    end
  end
  if (settings_debug == "info" or settings_debug == "debug") then
    if num_replaced > 0 and new_train and new_train.valid then
      local active, total = CountArtillery(new_train)
      game.print{"message-template.saw-disable-train-message", original_train_id, active, total}
    end
  end
end


------------------------- CIRCUIT CONTROL CODE -------------------------------


-- Check the list of trains at stops to see if the circuits have changed
local function OnTick()
  -- For each train in the list, make sure it's still valid and at a train stop
  -- global.stopped_trains[train_id] = {train=train}

  for id,data in pairs(global.stopped_trains) do
    local train = data.train
    if train and train.valid and train.station and train.station.valid then
      -- This train was previously identified as having an artillery wagon
      -- It is stopped at a station, check circuit conditions

      -- Retrieve the control signal value
      local signal_mode = train.station.get_merged_signal{type="virtual", name=SIGNAL_NAME}

      -- Accumulate enable or disable command ticks for this train/stop
      if signal_mode < 0 then
        if not data.disable_counter then
          -- Just arrived at stop, disable immediately
          data.disable_counter = DISABLE_DELAY
        elseif data.disable_counter < DISABLE_DELAY then
          -- Been sitting here, increment the hysteresis counter
          data.disable_counter = data.disable_counter + 1
        end
        -- Check if counter is full
        if data.disable_counter == DISABLE_DELAY then
          DisableTrain(train)  -- Disable the artillery in this train
          data.disable_counter = DISABLE_DONE  -- Set counter so it won't disable train again until the signal disappears and comes back
        end
        data.enable_counter = 0

      elseif signal_mode > 0 then
        if not data.enable_counter then
          -- Just arrived at stop, enable immediately
          data.enable_counter = ENABLE_DELAY
        elseif data.enable_counter < ENABLE_DELAY then
          -- Been sitting here, increment the hysteresis counter
          data.enable_counter = data.enable_counter + 1
        end
        -- Check if counter is full
        if data.enable_counter == ENABLE_DELAY then
          EnableTrain(train)  -- Enable the artillery in this train
          data.enable_counter = ENABLE_DONE  -- Set counter so it won't enable train again until the signal disappears and comes back
        end
        data.disable_counter = 0

      else
        -- If signal is removed, reset both hysteresis counters
        data.enable_counter = 0
        data.disable_counter = 0
      end

    else
      -- Train no longer exists or is no longer stopped at a station, remove from list
      global.stopped_trains[id] = nil
    end
  end

  if not next(global.stopped_trains) then
    script.on_event(defines.events.on_tick, nil)
  end

end


-- Check if this train is stopped at a station and has artillery, then add to global list
local function ProcessTrain(train)
  if (train.state == defines.train_state.wait_station) then
    -- Train newly stopped at station
    for _,c in pairs(train.carriages) do
      if c.type == "artillery-wagon" then
        -- This train has at least one artillery wagon, add it to scanning list
        global.stopped_trains[train.id] = {train=train}
        script.on_event(defines.events.on_tick, OnTick)
        break
      end
    end
  end
end


-- Rebuild list of artillery trains stopped at stations
local function RefreshTrainList()
  global.stopped_trains = {}
  for _,surface in pairs(game.surfaces) do
    for _,train in pairs(surface.get_trains()) do
      ProcessTrain(train)
    end
  end
end

-- Check that saved entries still correspond to real wagons
local function PurgeWagonSettingList()
  local list_of_valid = {}
  
  for _,surface in pairs(game.surfaces) do
    for _,train in pairs(surface.get_trains()) do
      for _,wagon in pairs(train.carriages) do
        if wagon.type == "artillery-wagon" and global.wagon_manual[wagon.unit_number] then
          list_of_valid[wagon.unit_number] = true
        end
      end
    end
  end
  
  global.wagon_manual = list_of_valid

end


--== ON_GUI_CLICKED EVENT ==--
-- Handle when player clicks on our GUI buttons
local function OnGuiClick(event)
  local player = game.players[event.player_index]
  local element = event.element

  if element.name == ENABLE_BUTTON then
    local wagon = player.opened
    -- Enable artillery on the whole train if circuit signal is not present
    if wagon and wagon.valid then
      local train = wagon.train
      -- Make sure the circuit control doesn't take priority. wagon_manual flag will be same for entire train.
      if not global.wagon_manual[wagon.unit_number] and train.station and train.station.get_merged_signal{type="virtual", name=SIGNAL_NAME} ~= 0 then
        -- Nonzero signal present 
        player.print({"message-template.saw-circuit-error-message"})
      else
        EnableTrain(train, true)
      end
    end

  elseif element.name == DISABLE_BUTTON then
    local wagon = player.opened
    -- Enable artillery on the whole train if circuit signal is not present
    if wagon and wagon.valid then
      local train = wagon.train
      -- Make sure the circuit control doesn't take priority. wagon_manual flag will be same for entire train.
      if not global.wagon_manual[wagon.unit_number] and train.station and train.station.get_merged_signal{type="virtual", name=SIGNAL_NAME} ~= 0 then
        -- Nonzero signal present 
        player.print({"message-template.saw-circuit-error-message"})
      else
        DisableTrain(train, true)
      end
    end

  end

end
script.on_event(defines.events.on_gui_click, OnGuiClick)


--== ON_TRAIN_CHANGED_STATE EVENT ==--
-- Every time a train arrives at a station, check if we need to replace wagons.
local function OnTrainChangedState(event)
  -- Event contains train, old_state
  ProcessTrain(event.train)
end
script.on_event(defines.events.on_train_changed_state, OnTrainChangedState)



-- When a train is created, that is the time to update GUIs
local function OnTrainCreated(event)
  local train = event.train
  -- Update statistics for all players with this train opened
  local active, total = CountArtillery(train)
  UpdateCountDisplay(train, active, total)
end
script.on_event(defines.events.on_train_created, OnTrainCreated)


--== ON_ENTITY_DIED (etc.) EVENTS ==--
-- Purge the setting list of dead wagons
local function OnEntityRemoved(event)
  -- Purge the setting list of dead wagons
  global.wagon_manual[event.entity.unit_number] = nil
end
script.on_event(defines.events.on_entity_died, OnEntityRemoved, {{filter="type",type="artillery-wagon"}})
script.on_event(defines.events.script_raised_destroy, OnEntityRemoved, {{filter="type",type="artillery-wagon"}})
script.on_event(defines.events.on_player_mined_entity, OnEntityRemoved, {{filter="type",type="artillery-wagon"}})
script.on_event(defines.events.on_robot_mined_entity, OnEntityRemoved, {{filter="type",type="artillery-wagon"}})


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
local function OnLoad()
  if global.stopped_trains and next(global.stopped_trains) then
    script.on_event(defines.events.on_tick, OnTick)
  end
end
script.on_load(OnLoad)

local function OnInit()
  InitEntityMaps()
  InitPlayerGuis()
  RefreshTrainList()
  global.wagon_manual = global.wagon_manual or {}
end
script.on_init(OnInit)

local function OnConfigurationChanged(event)
  InitEntityMaps()
  InitPlayerGuis()
  RefreshTrainList()
  global.wagon_manual = global.wagon_manual or {}
  PurgeWagonSettingList()
  global.upgrade_names = nil
  global.downgrade_names = nil
end
script.on_configuration_changed(OnConfigurationChanged)

local function OnRuntimeModSettingChanged(event)
  if event.setting == "smart-artillery-wagons-debug" then
    settings_debug = settings.global["smart-artillery-wagons-debug"].value
  end
end
script.on_event(defines.events.on_runtime_mod_setting_changed, OnRuntimeModSettingChanged)


------------------------------------------
-- Debug (print text to player console)
function print_game(...)
  local text = ""
  for _, v in ipairs{...} do
    if type(v) == "table" then
      text = text..serpent.block(v)
    else
      text = text..tostring(v)
    end
  end
  game.print(text)
end

function print_file(...)
  local text = ""
  for _, v in ipairs{...} do
    if type(v) == "table" then
      text = text..serpent.block(v)
    else
      text = text..tostring(v)
    end
  end
  log(text)
end

-- Debug command
function cmd_debug(params)
  local cmd = params.parameter
  if cmd == "dump" then
    for v, data in pairs(global) do
      print_game(v, ": ", data)
    end
  elseif cmd == "dumplog" then
    for v, data in pairs(global) do
      print_file(v, ": ", data)
    end
    print_game("Dump written to log file")
  end
end
commands.add_command("saw-debug", "Usage: saw-debug dump|dumplog", cmd_debug)

------------------------------------------------------------------------------------
--                    FIND LOCAL VARIABLES THAT ARE USED GLOBALLY                 --
--                              (Thanks to eradicator!)                           --
------------------------------------------------------------------------------------
setmetatable(_ENV,{
  __newindex=function (self,key,value) --locked_global_write
    error('\n\n[ER Global Lock] Forbidden global *write*:\n'
      .. serpent.line{key=key or '<nil>',value=value or '<nil>'}..'\n')
    end,
  __index   =function (self,key) --locked_global_read
    error('\n\n[ER Global Lock] Forbidden global *read*:\n'
      .. serpent.line{key=key or '<nil>'}..'\n')
    end ,
  })

