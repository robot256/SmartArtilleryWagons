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

-- Signal names
local SIGNAL_NAME = "signal-smart-artillery-control"

-- GUI element names
local ENABLE_FRAME = "saw-upgrade-frame"
local ENABLE_BUTTON = "saw-upgrade-button"
local DISABLE_BUTTON = "saw-downgrade-button"
local ENABLE_CHECKBOX = "saw-upgrade-checkbox"
local ENABLED_DISPLAY = "saw-enabled-display"
local TRAIN_DISPLAY = "saw-train-display"

local ENABLE_DELAY = 60  -- Ticks before train will switch from manual to automatic
local DISABLE_DELAY = 30  -- Ticks before train will switch from automatic to manual
local ENABLE_DONE = ENABLE_DELAY + 1
local DISABLE_DONE = DISABLE_DELAY + 1

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


-- Update GUI Checkboxes for a particular wagon
local function UpdateCheckbox(wagon)
  -- do it for all players
  for _,player in pairs(game.players) do
    if player.opened and player.opened == wagon and player.gui.relative[ENABLE_FRAME] then
      if storage.circuit_wagons[wagon.unit_number] then
        player.gui.relative[ENABLE_FRAME][ENABLE_CHECKBOX].state = true
      else
        player.gui.relative[ENABLE_FRAME][ENABLE_CHECKBOX].state = false
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
      if wagon.artillery_auto_targeting then
        active = active + 1
      end
    end
  end
  return active, total
end


-- Find every player with a GUI opened for an artillery wagon in this train and update their statistics
local function UpdateCountDisplay(train)
  local active, total = CountArtillery(train)
  for _,wagon in pairs(train.carriages) do
    if wagon.type == "artillery-wagon" then
      for _,player in pairs(game.players) do
        if player.opened and player.opened == wagon and player.gui.relative[ENABLE_FRAME] then
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
      -- Update circuit_wagons state for this artillery wagon
      if element.state == false then
        storage.circuit_wagons[open_wagon.unit_number] = nil
      else
        storage.circuit_wagons[open_wagon.unit_number] = true
        script.register_on_object_destroyed(open_wagon)
      end
      -- Update wagon state display for all players with this wagon's GUI opened
      UpdateCheckbox(open_wagon)
      
      -- Refresh train state immediately if we just switched it to enable circuit control
      if element.state == true then
        if storage.stopped_trains[train.id] then
          storage.stopped_trains[train.id].enable_counter = nil
          storage.stopped_trains[train.id].disable_counter = nil
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


------------------------- WAGON MODE CHANGE CODE -------------------------------
local function EnableTrain(train)
  -- Enable all the checkboxes according to the settings
  for _,c in pairs(train.carriages) do
    -- Enable this wagon if manual control is disabled
    if c.type == "artillery-wagon" and storage.circuit_wagons[c.unit_number] then
      c.artillery_auto_targeting = true
    end
  end
  UpdateCountDisplay(train)
end

local function DisableTrain(train)
  -- Disable all the checkboxes according to the settings
  for _,c in pairs(train.carriages) do
    -- Disable this wagon if manual control is disabled
    if c.type == "artillery-wagon" and storage.circuit_wagons[c.unit_number] then
      c.artillery_auto_targeting = false
    end
  end
  UpdateCountDisplay(train)
end

local function EnableTrainManual(train)
  -- Enable all the checkboxes according to the settings
  local circuit_disable_active = (storage.stopped_trains[train.id] and 
                                  storage.stopped_trains[train.id].disable_counter and 
                                  storage.stopped_trains[train.id].disable_counter > 0)
  for _,c in pairs(train.carriages) do
    -- Enable this wagon if manual control is enabled or no circuit disable signal is present
    if c.type == "artillery-wagon" and ((not storage.circuit_wagons[c.unit_number]) or (not circuit_disable_active)) then
      c.artillery_auto_targeting = true
    end
  end
  UpdateCountDisplay(train)
end

local function DisableTrainManual(train)
  -- Disable all the checkboxes according to the settings
  local circuit_enable_active = (storage.stopped_trains[train.id] and 
                                 storage.stopped_trains[train.id].enable_counter and 
                                 storage.stopped_trains[train.id].enable_counter > 0)
  for _,c in pairs(train.carriages) do
    -- Disable this wagon if manual control is enabled or no circuit enable signal is present
    if c.type == "artillery-wagon" and ((not storage.circuit_wagons[c.unit_number]) or (not circuit_enable_active)) then
      c.artillery_auto_targeting = false
    end
  end
  UpdateCountDisplay(train)
end

------------------------- CIRCUIT CONTROL CODE -------------------------------


-- Check the list of trains at stops to see if the circuits have changed
local function OnTick()
  -- For each train in the list, make sure it's still valid and at a train stop
  -- storage.stopped_trains[train_id] = {train=train}

  for id,data in pairs(storage.stopped_trains) do
    local train = data.train
    if train and train.valid and train.station and train.station.valid then
      -- This train was previously identified as having an artillery wagon
      -- It is stopped at a station, check circuit conditions

      -- Retrieve the control signal value
      local signal_mode = train.station.get_signal({type="virtual", name=SIGNAL_NAME}, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)

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
      storage.stopped_trains[id] = nil
    end
  end

  if not next(storage.stopped_trains) then
    script.on_event(defines.events.on_tick, nil)
  end

end


-- Check if this train is stopped at a station and has artillery, then add to global list
local function ProcessTrain(train, has_artillery)
  if (train.state == defines.train_state.wait_station) then
    -- Train newly stopped at station
    if train.station and train.station.get_control_behavior() then
      -- Station is connected to at least one circuit network. Circuits will be ignored if player wires the station while the train is stopped there.
      for _,c in pairs(train.carriages) do
        if has_artillery or c.type == "artillery-wagon" then
          -- This train has at least one artillery wagon, add it to scanning list
          storage.stopped_trains[train.id] = {train=train}
          script.register_on_object_destroyed(train)
          script.on_event(defines.events.on_tick, OnTick)
          break
        end
      end
    end
  end
end


-- Rebuild list of artillery trains stopped at stations
local function RefreshTrainList()
  storage.stopped_trains = {}
  local artillery_wagon_prototypes = {}
  for name,_ in pairs(prototypes.get_entity_filtered{{filter="type", type="artillery-wagon"}}) do
    table.insert(artillery_wagon_prototypes, name)
  end
  for _,train in pairs(game.train_manager.get_trains{stock=artillery_wagon_prototypes}) do
    ProcessTrain(train, true)
  end
end

-- Check that saved entries still correspond to real wagons
local function PurgeWagonSettingList()
  for uid,_ in pairs(storage.circuit_wagons) do
    local wagon = game.get_entity_by_unit_number(uid)
    if not (wagon and wagon.valid and wagon.type == "artillery-wagon") then
      storage.circuit_wagons[uid] = nil
    end
  end
end


--== ON_GUI_CLICKED EVENT ==--
-- Handle when player clicks on our GUI buttons
local function OnGuiClick(event)
  local player = game.players[event.player_index]
  local element = event.element

  if element.name == ENABLE_BUTTON then
    local wagon = player.opened
    if wagon and wagon.valid then
      local train = wagon.train
      EnableTrainManual(train)
    end

  elseif element.name == DISABLE_BUTTON then
    local wagon = player.opened
    if wagon and wagon.valid then
      local train = wagon.train
      DisableTrainManual(train)
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


--== ON_OBJECT_DESTROYED ==--
-- Purge the setting list of dead wagons or trains (that were registered when we added them to the table)
local function OnObjectDestroyed(event)
  if event.type == defines.target_type.entity then
    storage.circuit_wagons[event.useful_id] = nil
  elseif event.type == defines.target_type.train then
    storage.stopped_trains[event.useful_id] = nil
  end
end
script.on_event(defines.events.on_object_destroyed, OnObjectDestroyed)


--== BLUEPRINT ==--
local function OnPlayerSetupBlueprint(event)
  local bp = event.stack
  if not (bp and bp.valid_for_read and bp.is_blueprint) then return end
  local entities = bp.get_blueprint_entities()
  local mapping = event.mapping.get()
  -- Add tags for artillery wagons with the circuit controlled feature
  for index, record in pairs(entities) do
    local entity = mapping[index]
    if entity and entity.valid and entity.type=="artillery-wagon" then
      if storage.circuit_wagons[entity.unit_number] then
        --game.print("Blueprinting artillery wagon "..tostring(entity.unit_number).." with circuit control enabled.")
        bp.set_blueprint_entity_tag(index, "circuit-artillery-enabled", true)
      else
        bp.set_blueprint_entity_tag(index, "circuit-artillery-enabled", nil)
      end
    end
  end 
end
script.on_event(defines.events.on_player_setup_blueprint, OnPlayerSetupBlueprint)

-- When a ghost with a tag is created, add it to list of circuit-controlled wagons
local function OnEntityBuilt(event)
  if event.tags and event.tags["circuit-artillery-enabled"] then
    storage.circuit_wagons[event.entity.unit_number] = true
    script.register_on_object_destroyed(event.entity)
  end
end
script.on_event(defines.events.on_built_entity, OnEntityBuilt, {{filter="type", type="artillery-wagon"}})
script.on_event(defines.events.on_robot_built_entity, OnEntityBuilt, {{filter="type", type="artillery-wagon"}})
script.on_event(defines.events.script_raised_built, OnEntityBuilt, {{filter="type", type="artillery-wagon"}})
script.on_event(defines.events.script_raised_revive, OnEntityBuilt, {{filter="type", type="artillery-wagon"}})

-- When a circuit-controlled wagon is cloned, copy the circuit-controlled flag for the new wagon
local function OnEntityCloned(event)
  if storage.circuit_wagons[event.source.unit_number] then
    storage.circuit_wagons[event.destination.unit_number] = true
    script.register_on_object_destroyed(event.destination)
  end
end
script.on_event(defines.events.on_entity_cloned, OnEntityCloned, {{filter="type", type="artillery-wagon"}})

---- Bootstrap ----
local function OnLoad()
  if storage.stopped_trains and next(storage.stopped_trains) then
    script.on_event(defines.events.on_tick, OnTick)
  end
end
script.on_load(OnLoad)

local function OnInit()
  InitPlayerGuis()
  RefreshTrainList()
  storage.circuit_wagons = storage.circuit_wagons or {}
end
script.on_init(OnInit)

local function OnConfigurationChanged(event)
  InitPlayerGuis()
  RefreshTrainList()
  storage.circuit_wagons = storage.circuit_wagons or {}
  PurgeWagonSettingList()
end
script.on_configuration_changed(OnConfigurationChanged)


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
    for v, data in pairs(storage) do
      print_game(v, ": ", data)
    end
  elseif cmd == "dumplog" then
    for v, data in pairs(storage) do
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

