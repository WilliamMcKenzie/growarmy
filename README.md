# Grow an Army — prototype

Open `Grow-an-Army.rbxlx` in Roblox Studio and press Play. Move with Roblox's standard desktop/mobile controls. Approach an enemy camp to auto-battle; defeated troops switch sides. Return to the central barracks and use the HUD buttons to cash in recruits, train a permanent starting swordsman, or roll a permanent starting troop.

- Plain bright-green studded baseplate; no scenery or visible base structures.
- 24 enemy squads across three difficulty bands; swordsmen, archers, and splash-damage rocketeers.
- 60 field troops maximum; 12 permanent starting troops maximum.
- Only captured troops have cash-in value. Starting troops cannot be cashed in for free gold.
- Retreating resets the active enemy camp. Losing your army or resetting your character loses field troops, while banked gold and starting upgrades survive for the session.
- Recruitment uses earned gold only: 60% swordsman, 30% archer, 10% rocketeer.
- PvE only. Each active camp engages one player; no PvP.

## Development

Local files are the source of truth. Rojo syncs them into Studio's edit-mode place; restart Play to run changed scripts.

```sh
rojo serve default.project.json --port 34873
```

In Studio: Plugins → Rojo → connect to `localhost:34873`. The server was started during setup, but the Studio plugin connection has not been verified. Avoid editing Rojo-managed scripts or map parts directly in Studio: those changes do not automatically sync back to disk.

| File | Purpose |
| --- | --- |
| `src/server/ArmyServer.server.lua` | Server-owned combat, squads, camp respawns, gold, recruitment, save/load |
| `src/client/ArmyClient.client.lua` | HUD, barracks buttons, camera setup, combat effects |
| `src/shared/ArmyConfig.lua` | Class stats, capacities, and upgrade prices |
| `tools/build_map.py` | Editable generator for the prototype map |
| `map.model.json` | Generated map, synced by Rojo |
| `default.project.json` | Maps local files to Roblox services |

Rebuild after map-generator changes:

```sh
python3 tools/build_map.py
rojo build default.project.json -o Grow-an-Army.rbxlx
```

## Status and limits

Rojo build passes. Studio launched the server/client scripts without reported runtime errors and initialized 24 camps and a four-swordsman starting squad. An initial map-position export bug was fixed; the corrected edit-mode camp/spawn positions were checked. Full gameplay and balance testing is left to the user as requested.

Studio progress is deliberately session-only and resets on Stop/Play. Published servers use DataStore storage for banked gold and starting troops; that cross-session path is not live-verified. This is a prototype, not production-hardened persistence (no cross-server session locking). No publishing was performed.

Visuals are primitive blocks. Units use simple direct movement rather than obstacle pathfinding; no line-of-sight, manual formations, or polished animations yet. Combat has a fixed server update rate and is not load-tested for large multiplayer servers.

## Current minimal visual test

Enemy spawning is disabled (`ArmyConfig.SpawnEnemies = false`) and the game HUD, prompts, overhead player name, and standard CoreGui panels are hidden. Start Play to walk with four starter swordsmen; upgrade UI and enemy camps are intentionally unavailable in this mode. Roblox may retain its platform menu button.

Troops now use miniature R15 avatar rigs. Neutral troops use plain Roblox bodies; owned troops clone a cached version of their owner's appearance, with class weapons attached to the hands. The server simulates invisible troop markers; clients render nearby animated rigs and interpolate movement. Only the visual model changes on capture, preserving combat stats and class.

`AvatarTemplates.lua` caches avatar models; `TroopVisuals.client.lua` builds weapons and plays animations. Animations are Roblox-owned assets: idle 507766666, walk 507777826, tool hold 507768375, sword slash 522635514, soldier aim 4713633512, soldier fire 4713811763. Aim/fire were sourced from the official [Soldier NPC kit](https://create.roblox.com/store/asset/3924234975); they are temporary placeholders for both ranged classes, not custom bow/rocket animations. No third-party model scripts were imported.

Scripts compile in Studio and the place builds with Rojo. Full motion, combat, and multiplayer playtesting remains with the user.
