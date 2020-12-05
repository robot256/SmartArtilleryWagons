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


local SIGNAL_NAME = "signal-smart-artillery-control"
local ENABLE_BUTTON = "saw-upgrade-button"
local DISABLE_BUTTON = "saw-downgrade-button"
local ENABLE_CHECKBOX = "saw-upgrade-checkbox"
local DISABLE_CHECKBOX = "saw-downgrade-checkbox"
local ENABLE_FRAME = "saw-upgrade-frame"
local DISABLE_FRAME = "saw-downgrade-frame"

local ENABLE_DELAY = 60  -- Ticks before train will switch from manual to automatic
local DISABLE_DELAY = 5  -- TIcks before train will switch from automatic to manual
local ENABLE_DONE = ENABLE_DELAY + 1
local DISABLE_DONE = DISABLE_DELAY + 1


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
            names=global.upgrade_names}
  }
  local button1 = frame1.add{
    type="button",
    name=ENABLE_BUTTON,
    caption={"gui-text.saw-enable-button"}
  }
  button1.style.font = "saw-button"
  local check1 = frame1.add{
    type="checkbox",
    name=ENABLE_CHECKBOX,
    caption={"gui-text.saw-circuit-checkbox"},
    state=true
  }


  local frame2 = gui.relative.add{
    type="frame",
    name=DISABLE_FRAME,
    caption={"gui-text.saw-frame-heading"},
    direction="vertical",
    anchor={gui=defines.relative_gui_type.container_gui,
            position=defines.relative_gui_position.left,
            names=global.downgrade_names}
  }
  local two = frame2.add{
    type="button",
    name=DISABLE_BUTTON,
    caption={"gui-text.saw-disable-button"}
  }
  two.style.font = "saw-button"
  local check2 = frame2.add{
    type="checkbox",
    name=DISABLE_CHECKBOX,
    caption={"gui-text.saw-circuit-checkbox"},
    state=true
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
      if global.wagon_manual and global.wagon_manual[wagon.unit_number] == true then
        player.gui.relative[ENABLE_FRAME][ENABLE_CHECKBOX].state = false
        player.gui.relative[DISABLE_FRAME][DISABLE_CHECKBOX].state = false
      else
        player.gui.relative[ENABLE_FRAME][ENABLE_CHECKBOX].state = true
        player.gui.relative[DISABLE_FRAME][DISABLE_CHECKBOX].state = true
      end
    end
  end
end


--== ON_GUI_CLICKED EVENT ==--
-- Handle when player clicks on our GUI buttons
local function OnGuiClick(event)
  local player = game.players[event.player_index]
  local element = event.element

  if element.name == ENABLE_BUTTON then
    --game.print("Player clicked to upgrade wagon "..tostring(player.opened.unit_number))
    local wagon = player.opened
    if global.upgrade_pairs[wagon.name] then
      local old_id = wagon.unit_number
      
      -- Make sure the circuit control doesn't take priority
      if (not global.wagon_manual or not global.wagon_manual[old_id]) and wagon.train.station and wagon.train.station.get_merged_signal{type="virtual", name=SIGNAL_NAME} ~= 0 then
        -- Nonzero signal present 
        player.print("Cannot change autofire state while circuit network control is engaged.")
      else
        local new_wagon = replaceCarriage(wagon, global.upgrade_pairs[wagon.name])
        if new_wagon then
          global.wagon_manual[new_wagon.unit_number] = global.wagon_manual[old_id]
          UpdateCheckbox(new_wagon)
        end
        global.wagon_manual[old_id] = nil
      end
    end

  elseif element.name == DISABLE_BUTTON then
    --game.print("Player clicked to downgrade which wagon "..tostring(player.opened.unit_number))
    local wagon = player.opened
    if global.downgrade_pairs[wagon.name] then
      local old_id = wagon.unit_number
      
      -- Make sure the circuit control doesn't take priority
      if (not global.wagon_manual or not global.wagon_manual[old_id]) and wagon.train.station and wagon.train.station.get_merged_signal{type="virtual", name=SIGNAL_NAME} ~= 0 then
        -- Nonzero signal present 
        player.print("Cannot change autofire state while circuit network control is engaged.")
      else
        local new_wagon = replaceCarriage(wagon, global.downgrade_pairs[wagon.name])
        if new_wagon then
          global.wagon_manual[new_wagon.unit_number] = global.wagon_manual[old_id]
          UpdateCheckbox(new_wagon)
        end
        global.wagon_manual[old_id] = nil
      end
    end

  end

end
script.on_event(defines.events.on_gui_click, OnGuiClick)


--== ON_GUI_CHECKED_STATE_CHANGED EVENT ==--
-- Handle when player clicks on our GUI checkboxes
local function OnGuiCheckedStateChanged(event)
  local player = game.players[event.player_index]
  local element = event.element

  if element.name == ENABLE_CHECKBOX or element.name == DISABLE_CHECKBOX then
    local wagon = player.opened
    if wagon and wagon.valid then
      local id = wagon.unit_number

      -- Update saved wagon_manual state for this wagon
      global.wagon_manual = global.wagon_manual or {}
      if element.state == false then
        global.wagon_manual[id] = true
      else
        global.wagon_manual[id] = nil
      end
      -- Update wagon state display for all players with this GUI opened
      UpdateCheckbox(wagon)

      -- Refresh train state immediately if we just switched it to enable
      if element.state == true then
        if global.stopped_trains[wagon.train.id] then
          global.stopped_trains[wagon.train.id].enable_counter = nil
          global.stopped_trains[wagon.train.id].disable_counter = nil
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
      if global.upgrade_pairs[entity.name] or global.downgrade_pairs[entity.name] then
        -- Update state of checkbox to match this particular wagon
        UpdateCheckbox(entity)
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


local function EnableTrain(t)
  local replace_wagons = {}
  -- Look for normal wagons to upgrade to auto
  for _,c in pairs(t.carriages) do
    if global.upgrade_pairs[c.name] and (not global.wagon_manual or not global.wagon_manual[c.unit_number]) then
      table.insert(replace_wagons,{c,global.upgrade_pairs[c.name]})
    end
  end
  if next(replace_wagons) then
    game.print{"message-template.saw-enable-train-message",t.id}
  end
  -- Execute replacements
  for _,r in pairs(replace_wagons) do
    -- Replace the wagon if it is not set to manual mode

    --game.print("Smart Artillery is replacing ".. r[1].name .. "' with " .. r[2])
    --game.print({"debug-message.saw-replacement-message",r[1].name,r[1].backer_name,r[2]})
    local old_id = r[1].unit_number
    local new_wagon = replaceCarriage(r[1], r[2])
    if new_wagon then
      global.wagon_manual[new_wagon.unit_number] = global.wagon_manual[old_id]
    end
    global.wagon_manual[old_id] = nil
  end
end

local function DisableTrain(t)
  local replace_wagons = {}
  -- Look for auto wagons to downgrade to normal
  for _,c in pairs(t.carriages) do
    if global.downgrade_pairs[c.name] and (not global.wagon_manual or not global.wagon_manual[c.unit_number]) then
      table.insert(replace_wagons,{c,global.downgrade_pairs[c.name]})
    end
  end
  if next(replace_wagons) then
    game.print{"message-template.saw-disable-train-message",t.id}
  end
  -- Execute replacements
  for _,r in pairs(replace_wagons) do
    -- Replace the wagon if it is not set to manual mode

    --game.print("Smart Artillery is replacing ".. r[1].name .. "' with " .. r[2])
    --game.print({"debug-message.saw-replacement-message",r[1].name,r[1].backer_name,r[2]})
    local old_id = r[1].unit_number
    local new_wagon = replaceCarriage(r[1], r[2])
    if new_wagon then
      global.wagon_manual[new_wagon.unit_number] = global.wagon_manual[old_id]
    end
    global.wagon_manual[old_id] = nil
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


----------------------------------------------
------ EVENT HANDLING ---

--== ON_TRAIN_CHANGED_STATE EVENT ==--
-- Every time a train arrives at a station, check if we need to replace wagons.
local function OnTrainChangedState(event)
  -- Event contains train, old_state
  ProcessTrain(event.train)
end
script.on_event(defines.events.on_train_changed_state, OnTrainChangedState)




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
end
script.on_init(OnInit)

local function OnConfigurationChanged(event)
  InitEntityMaps()
  InitPlayerGuis()
  RefreshTrainList()
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

