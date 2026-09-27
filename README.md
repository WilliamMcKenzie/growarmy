# Grow an Army — prototype

A Roblox PvE army prototype. Move with standard desktop/mobile controls; your troops wander around you and follow when left behind. The current visual test disables enemy camps and hides the game HUD/prompts/CoreGui. Restart Play after syncing script changes.

Fresh squads contain **two Swordsmen, one Archer, and one Giant** so all three types are visible immediately. Each wears its owner's cached avatar appearance. There are no individual troop circles. A thin white circle around the local player shows the navigation radius and turns red when the server sets `InBattle`.

## Troop behaviour and tuning

| Type | Size relative to owner | Health | Damage | Attack range | Cooldown | Combat speed | Wander speed | Behaviour |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Swordsman | 0.8× | 75 | 15 | 6 | 0.75 s | 23 | 4–6 | Charge straight into melee reach |
| Archer | 0.8× | 42 | 12 | 32 | 1.05 s | 21 | 3.8–5.7 | Advance or backpedal to stay at bow range |
| Giant | 1.2× | 180 | 30 | 7 | 1.6 s | 19 | 3.2–4.8 | Advance into melee with a club |

Distances are studs; speeds are studs per second. Archers face their target while retreating and can attack during movement if in range and off cooldown. They are slower than Swordsmen, so a pursuing Swordsman can close the gap. Giants share the frontline melee behaviour, with their own stats and slower movement. Troops currently select the nearest living enemy.

Outside combat, troops independently choose world-space destinations inside the master's **18-stud radius**, walk there, and choose another point on arrival, including while the master is AFK. Sampling uses an even disk distribution within 85% of the radius to leave some room at the boundary. A destination persists until reached or until the master moves far enough that it falls outside the radius.

Crossing outside the radius switches a troop into return mode with a fresh destination. Return mode stays active until arrival and uses the master's **current `Humanoid.WalkSpeed` exactly**, including changes to it; class speed penalties do not apply. The player's initial speed is 23. Equal speed means a trailing troop cannot gain on a player running straight away at full speed; it closes the gap when the player slows, stops, or changes direction. Combat takes priority over roaming and can take troops beyond the circle.

`ArmyConfig.Roaming.Radius` is the single source for both navigation and the player circle. The circle is a thin 96-segment outline projected onto the floor below the player, visible only to that player; it hides during death or when no ground is found. Red follows the authoritative `InBattle` attribute, not nearby visual effects. Enable `ArmyConfig.SpawnEnemies` to exercise combat and the red state.

## Troop architecture

The structure separates **what a troop is**, **its changing state**, **how it acts**, and **how it looks**. The server owns positions, health, targeting, attacks, and ownership. Clients render the server's result. Behaviour code is shared by capability, so a new melee troop can reuse melee combat without adding another class-name branch.

| File | Responsibility |
| --- | --- |
| `src/shared/TroopDefinitions.lua` | Type catalog: stable IDs, stats, movement/combat handler names, avatar scale, weapon, animations, recruitment weights, and starter counts |
| `src/shared/ArmyConfig.lua` | Global rules, ordered catalog traversal, weighted roster selection, pricing, and starter-save migration |
| `src/server/ArmyServer.server.lua` | Unit creation/destruction, battle lifecycle, capture, camps, player profiles, economy, and persistence |
| `src/server/TroopMovement.lua` | Movement primitives and passive movement handler registry; owns wander/return state |
| `src/server/TroopCombat.lua` | Combat handler registry, nearest-target selection, melee charge, ranged spacing, cooldowns, and damage |
| `src/server/AvatarTemplates.lua` | One sanitized, full-size R15 appearance template per owner; neutral fallback template |
| `src/client/TroopVisuals.client.lua` | Clone/scale templates, interpolate server markers, play movement and attack animations, and cull distant rigs |
| `src/client/TroopWeapons.lua` | Weapon builder registry (`Sword`, `Bow`, `Club`), shared independently of troop IDs |
| `src/client/TroopRadius.client.lua` | Local player navigation circle and combat colour |
| `src/client/ArmyClient.client.lua` | Camera, hidden HUD setup, and transient attack effects |
| `default.project.json` | Explicit Rojo mapping for every script/module |

### Definitions and state

A catalog entry has these independent groups:

- `Order`, `StarterCount`, `RecruitWeight`, `CampMinTier`: deterministic ordering and availability. Recruitment uses relative weights; camp selection uses those weights filtered by minimum tier.
- `Stats`: `Health`, `Damage`, `Range`, `Cooldown`, and captured recruit `Value`.
- `Movement`: passive `Behavior`, `CombatSpeed`, and `WanderMultiplier`.
- `Combat`: `Behavior` (`Melee` or `Ranged` today).
- `Visual`: relative `Scale`, weapon builder name, effect colour/width, and animation asset IDs. These do not control damage or movement authority.

Treat shared definitions as read-only. Each server unit owns `class`, `model`, `pos`, `hp`, `nextAttack`, `earned`, `owner`, `movementState`, and `combatState`. Handler-specific timers and targets belong in that unit's state table, never in the shared definition. Entering combat clears passive destinations; leaving combat clears combat state; capture resets both. Only persistent gold and starter counts are saved, not transient behaviour state.

The client receives invisible markers with `Class`, `OwnerId`, and `AttackSequence`, plus their server-owned transforms. Attack effects use the existing `ArmyEffect` remote. Clients never choose hits or submit troop positions. Appearance templates retain the owner's body proportions; each clone applies the type's scale and scales its root-to-floor offset too. [Roblox `Model:ScaleTo`](https://create.roblox.com/docs/reference/engine/classes/Model#ScaleTo) scales rig geometry and animation joint offsets together.

### Adding a troop or behaviour

1. Add a stable ID to `TroopDefinitions.lua` by copying the nearest existing definition. Give it a unique `Order`, its own stats/visuals, and normally `StarterCount = 0`. Use an existing movement, combat, and weapon handler where possible. Catalog ordering, counts, recruitment, camps, and fresh/save-loaded starter tables discover it automatically. Guaranteed training via the `Upgrade` action intentionally remains a Swordsman rule.
2. For new passive behaviour, add `Movement.Behaviors.Name(unit, context, dt)` and select it in the definition. Context supplies the master's `center` and live `walkSpeed`; use `Movement.stepToward`/`place` to keep the marker and state position synchronized. Keep temporary state in `unit.movementState`.
3. For new combat behaviour (for example a healer or flanker), add `Combat.Behaviors.Name(unit, enemies, now, dt, emitEffect)` and select it in the definition. It owns target selection and positioning, and must enforce its range, cooldown, damage/support rules, and `AttackSequence` updates. Use `unit.combatState` for persistent combat decisions. Handlers run once per server tick and must not yield. If a future behaviour needs allies or navigation queries, extend the handler context explicitly; do not reach into profile internals or make the client authoritative.
4. For a new weapon, add a named entry to `Weapons.Builders` with `Hand`, `Grip`, and `Build(piece)`. Animation IDs are definition data; new animation combinations do not require new class branches. Extend the effect renderer if a new effect needs more than the current beam width/colour.
5. If adding a module, include it in `default.project.json`. Add behavioural tests for new mechanics and playtest the appearance and animation in Studio.

Stable IDs are save keys: do not rename them without migration. Existing `Rocketeer` permanent counts migrate to `Giant`; old squads retain their existing composition and total, subject to the starter cap. Newly added types default to zero in existing saves, avoiding unearned upgrades. Fresh profiles use the catalog's starter counts. Keep the configured starter total within `StarterCap`.

This is deliberately a small registry-based system. The next scaling steps, when needed, are a shared spatial query service for targeting (currently a linear scan per troop), obstacle navigation behind the movement API, and budgeted simulation updates. Those can replace specific services without moving stats into behaviour code or giving the client authority. Split large handler registries into individual modules as their complexity grows.

## Development and validation

Local files are the source of truth. Rojo syncs into Studio's edit-mode place; restart Play to run changes. Avoid editing Rojo-managed scripts or map parts directly in Studio.

```sh
rojo serve default.project.json --port 34872
```

In Studio: Plugins → Rojo → connect to `localhost:34872`. On this Mac, Control+Option+R also connects Rojo. To build a place:

```sh
rojo build default.project.json -o Grow-an-Army.rbxlx
```

After changing the map generator, run `python3 tools/build_map.py` before building.

Run the troop checks with the official standalone Luau CLI (`luau` and `luau-compile` in the same directory):

```sh
python3 tools/test_troops.py --luau /path/to/luau
```

The runner compiles every production script, verifies Rojo source mappings, and executes unmodified definition/movement/combat modules with minimal Roblox API doubles. Checks cover catch-up speed changes, wandering, return transitions, ranged spacing/retreat, fractional range boundaries, melee pursuit, cooldowns, dead targets, and save migration. They do not simulate Roblox rendering, animation, replication, or physics.

Studio playtest checklist: compare all three troop sizes with the owner; verify weapons and feet stay aligned; idle and run through turns; change the player's `WalkSpeed`; die/respawn; enable enemies and verify melee charges, archer retreat/pursuit, and white/red circle transitions. Test capture and different player appearances in a multiplayer session.

## Gameplay and limits

With enemies enabled, 24 camps span three tiers. Approach a camp to auto-battle; defeated troops join your army. Return to the barracks to bank captured recruits, train a permanent Swordsman, or roll a permanent troop (60% Swordsman, 30% Archer, 10% Giant). The prototype HUD/prompts are currently hidden for the visual test.

The field cap is 60; the permanent starter cap is 12. Only captured troops have cash-in value. Retreat resets the active camp. Losing the army or resetting the character loses field troops while keeping banked gold and starter upgrades. Camps engage one player at a time; there is no PvP.

Studio progress is session-only. Published servers use DataStore storage, without production-grade cross-server session locking. Units use flat direct movement, with no obstacle pathfinding, collision avoidance, or line of sight. The server updates around 10 Hz and has not been load-tested for large multiplayer sessions.

Animations are Roblox-owned placeholders: idle 507766666, walk 507777826, hold 507768375, slash 522635514, aim 4713633512, fire 4713811763. Aim/fire come from the official [Soldier NPC kit](https://create.roblox.com/store/asset/3924234975) and are temporary Archer animations. Giants reuse the melee swing. No third-party model scripts were imported. Standalone checks cannot verify visual quality; the updated rigs, circle, and live combat still need Studio playtesting.

## Reference lighting pass

The field uses subtle alternating greens in 25-stud squares with aligned tiled [stud textures](https://create.roblox.com/store/asset/10455712373). Lighting enables shadows with blue ambient fill, warm sunlight, modest saturation/contrast and bloom. A custom cloud-free cyan sky replaces the distant backdrop walls. Player graphics settings affect detail and shadows.
