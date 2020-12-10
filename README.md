# SmartArtilleryWagons
Factorio mod written in Lua.  Makes Artillery Wagons enable and disable according to train stop signals.


- Type: Mod
- Name: Smart Artillery Wagons
- Description: Artillery Wagons enable and disable according to train stop signals.
- License: MIT
- Source: GitHub
- Download: mods.factorio.com
- Version: 0.2.0
- Release: 2020-01-24
- Tested-With-Factorio-Version: 0.18.1
- Category: Helper, Train
- Tags: Train

Makes Artillery Wagons enable and disable according to train station signals.

## Summary
This mod changes artillery wagons so that they do not auto-fire when initially placed.  When a train containing artillery wagons stops at a train station, it looks for the Smart Artillery Control signal.  If the control signal is positive, artillery wagons are set to automatic targeting.  If the control signal is negative, artillery wagons are set to manual targeting only.  If the signal is zero or not present, no change is made.

The main use of this is mod is to disable artillery wagons when they park at your depot, and then enable them at well-defended outposts.  Also lets you use them as ammunition transport wagons that will not attack on their own, or as manual-targeting turrets to conserve ammunition.

Should work with any artillery wagons, vanilla or modded.
