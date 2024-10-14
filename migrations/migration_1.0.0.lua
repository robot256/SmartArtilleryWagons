
-- Step 0: Make a new storage table
local newstorage = {}

-- Step 1: Check all the wagons listed in wagon_manual that they are valid and register_on_object_destroyed
newstorage.wagon_manual = {}
if storage.wagon_manual and next(storage.wagon_manual) then
  for uid,_ in pairs(storage.wagon_manual) do
    local wagon = game.get_entity_by_unit_number(uid)
    if wagon and wagon.valid and wagon.type == "artillery-wagon" then
      newstorage.wagon_manual[wagon.unit_number] = true
      script.register_on_object_destroyed(wagon)
    end
  end
end

-- Step 2: Check all the trains listed in stopped_trains that they are at stations with circuit networks, and reset the circuit timers so wagons are re-enabled if the signal is still there.
newstorage.stopped_trains = {}
local artillery_wagon_prototypes = {}
for name,_ in pairs(prototypes.get_entity_filtered{{filter="type", type="artillery-wagon"}}) do
  table.insert(artillery_wagon_prototypes, name)
end
for _,train in pairs(game.train_manager.get_trains{stock=artillery_wagon_prototypes}) do
  if (train.state == defines.train_state.wait_station) then
    -- Train newly stopped at station
    if train.station and (train.station.get_circuit_network(defines.wire_connector_id.circuit_red) or train.station.get_circuit_network(defines.wire_connector_id.circuit_green)) then
      -- Station is connected to at least one circuit network. Circuits will be ignored if player wires the station while the train is stopped there.
      -- This train has at least one artillery wagon, add it to scanning list
      newstorage.stopped_trains[train.id] = {train=train}
      script.register_on_object_destroyed(train)
    end
  end
end

-- Step 3: Set all artillery wagons to disable auto targeting
for _,train in pairs(game.train_manager.get_trains{stock=artillery_wagon_prototypes}) do
  for _,carriage in pairs(train.carriages) do
    if carriage.type == "artillery-wagon" then
      carriage.artillery_auto_targeting = false
    end
  end
end

-- Step 4: Save the new storage table
storage = newstorage
