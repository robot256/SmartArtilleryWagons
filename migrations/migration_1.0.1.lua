
local artillery_wagon_prototypes = {}
for name,_ in pairs(prototypes.get_entity_filtered{{filter="type", type="artillery-wagon"}}) do
  table.insert(artillery_wagon_prototypes, name)
end

-- Migration wagon_manual to circuit_wagons
storage.circuit_wagons = storage.circuit_wagons or {}
if storage.wagon_manual then
  for _,train in pairs(game.train_manager.get_trains{stock=artillery_wagon_prototypes}) do
    for _,carriage in pairs(train.carriages) do
      if carriage.type == "artillery-wagon" then
        if not storage.wagon_manual[carriage.unit_number] then
          storage.circuit_wagons[carriage.unit_number] = true
        end
      end
    end
  end
  storage.wagon_manual = nil
end
