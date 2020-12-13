--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Smart Artillery Wagons
 * File: senpaisdora_add_saw.lua
 * Description: Integration with Senpais Dora mod
--]]


if mods["Senpais_Dora"] then
  log("Trying to create manual wagon for Senpais Dor")
	createManualWagon("Senpais-Dora","Senpais-Dora-auto","item-with-entity-data",false)

end
