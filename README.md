# Grow an Army — prototype

A Roblox PvE army prototype. Move with standard desktop/mobile controls; your troops wander around you and follow when left behind. Scattered neutral PvE troops are enabled by default. The troop inventory is visible; legacy economy controls/prompts and CoreGui remain hidden. Restart Play after syncing script changes.

Fresh squads contain **two Swordsmen, one Archer, and one Giant** so all three types are visible immediately. Owned troops wear their owner's cached avatar appearance. Unowned troops use a completely white, faceless R6 body with no clothes or accessories, plus their class weapon. There are no individual troop circles. A thin white circle around the local player shows the navigation radius and turns red when the server sets `InBattle`.

## Troop behaviour and tuning

| Type | Size relative to owner | Health | Damage | Attack range | Cooldown | Combat speed | Wander speed | Behaviour |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Swordsman | 0.8× | 75 | 15 | 6 | 0.75 s | 23 | 4–6 | Charge straight into melee reach |
| Archer | 0.8× | 42 | 12 | 32 | 1.05 s | 10.5 running; stationary aiming | 1.9–2.85 | Hold at 30–32 studs, draw, shoot, or flee |
| Giant | 1.2× | 180 | 30 | 7 | 1.6 s | 19 | 3.2–4.8 | Advance into melee with a club |

The table shows Tier 1 stats. Distances are studs; speeds are studs per second. Archers hold position anywhere in a two-stud attack band (30–32 studs), face their target, and draw for 0.65 seconds before firing. Below 30 studs they cancel the shot, lower the bow, and run away facing their escape direction at 10.5 studs/second; beyond 32 they advance with the bow lowered. A new closest target restarts the draw. After firing, the 1.05-second cooldown must finish before the next draw starts. `Combat.RangeLeeway` and `Combat.DrawTime` in the Archer definition control the band and draw duration. They remain slower than Swordsmen, so pursuers can close the gap. Giants share the frontline melee behaviour with their own stats and slower movement.

Every troop independently selects its nearest living hostile from all encounters currently engaged by its owner, reconsidering each server tick. Approaching another neutral adds it to the ongoing fight instead of locking the army to the first enemy; troops can split naturally across nearer opponents. Each encounter remains exclusive to one player. Winning or retreating from one encounter leaves the others active, and the player circle stays red until the last active encounter ends.

Outside combat, troops independently choose world-space destinations inside the master's **18-stud radius**, walk there, and choose another point on arrival, including while the master is AFK. Sampling uses an even disk distribution within 85% of the radius to leave some room at the boundary. A destination persists until reached or until the master moves far enough that it falls outside the radius.

Crossing outside the radius switches a troop into return mode with a fresh destination. Return mode stays active until arrival. Swordsmen and Giants use the master's current `Humanoid.WalkSpeed`; Archers use half that speed via `Movement.ReturnSpeedMultiplier = 0.5`. Archer combat and wander speeds are also half their previous values. Tier upgrades do not change movement speeds. The player's initial speed is 23. Equal speed means a trailing troop cannot gain on a player running straight away at full speed; it closes the gap when the player slows, stops, or changes direction. Combat takes priority over roaming and can take troops beyond the circle.

`ArmyConfig.Roaming.Radius` is the single source for both navigation and the player circle. The circle is a thin, non-glowing outline of 48 dashes at 50% opacity, projected onto the floor below the player and visible only to that player; it hides during death or when no ground is found. Red follows the authoritative `InBattle` attribute, not nearby visual effects. `ArmyConfig.SpawnEnemies` enables the scattered neutral population and is on by default.

## Merging and tiers

Drag one troop icon onto another matching icon in the bottom-centre inventory. Two living troops of the same class and tier become one troop of the next tier, freeing one field slot. Merging is optional, free, and available anywhere, including during combat. Matching targets highlight green; incompatible hovered targets highlight red. The server validates the exact source/destination marker instances against the player's live roster, rejects stale/foreign/self/mismatched/max-tier pairs, and rate-limits requests. It never substitutes another pair or trusts client stats.

There are three tiers initially. `src/shared/TroopTiers.lua` owns all progression rules independently of behaviour definitions:

| Tier | Health/damage multiplier | Size multiplier relative to Tier 1 | Swordsman/Archer size vs owner | Giant size vs owner |
| --- | --- | --- | --- | --- |
| 1 | 1× | 1× | 0.8× | 1.2× |
| 2 | 2.2× | 1.2× | 0.96× | 1.44× |
| 3 | 4.84× | 1.44× | 1.152× | 1.728× |

Health and damage are rounded to the nearest integer after scaling the base stat. Attack range, cooldown, draw duration, targeting, and movement rules do not change by tier. Combat, healing, capture, replication, and visuals all resolve stats/scales through `TroopTiers`; handlers should use `Tiers.stats(unit.class, unit.tier)` rather than the class's base `Stats` directly.

The drop-target troop survives and keeps its position; the dragged source is consumed. Its health percentage is the average of the pair's health percentages, applied to its new maximum; merging injured troops is not a full heal. It retains the later attack cooldown, clears pending targeting/wander state, and inherits the sum of the pair's earned cash-in values. Starter troops still contribute zero cash value. The consumed troop is removed once, and ownership/tier changes rebuild the client rig from the original template so size never compounds accidentally.

Merges apply to the **current field army**. As with other field troops, they reset on army loss, character reset, cash-in/re-equipping, or rejoining; permanent starter counts are unchanged and equip Tier 1 troops. Saved gold/starter formats remain compatible. Neutrals currently spawn at Tier 1; if higher-tier neutrals are added later, their capture value uses the configured `Value` multiplier (2× per tier), while merging always preserves existing earned value.

To add Tier 4 and beyond, change `TroopTiers.MaxTier`; the formulas, server validation, tier counts, inventory matching, and nameplates all extend automatically. `SizeMultiplier` is 1.2 and `StatMultipliers` controls stat growth. Tune those at source and restart Play; resolved stat tables are cached and read-only during a session. `CampMinTier` is legacy encounter-difficulty filtering and is unrelated to unit progression tiers.

## Neutral PvE population

`ArmyConfig.NeutralSpawns` controls a population of 60 individual encounters, with one randomly selected Swordsman, Archer, or Giant per spawn. Positions cover the current `Map.Field` bounds, with at least 24 studs between spawn centres, 24 studs of edge clearance, 48 studs from player characters, and enough distance from the central safe zone for idle wandering. The old fixed `Camp_*` map markers are no longer used. The current sampler assumes the flat, axis-aligned field.

Unengaged troops wander around their own spawn centres. Coming within 29 studs of an available neutral starts or extends the battle/capture loop. Leaving 52 studs from an encounter's spawn centre releases that encounter; returning to base releases all of them. After defeat, a replacement spawns at a new random location after 35 seconds; it never duplicates the captured troop. When no safe position is found in 80 attempts, spawning retries after 5 seconds. Retreat, army defeat, death, and disconnect release the encounter too.

The neutral template is constructed locally from plain white R6 parts and joints, without avatar-service requests, decals, clothing, or accessories. Class weapons remain attached so types are recognizable. R6 gets its own procedural movement/attack poses and arm grip attachments. Capture changes `OwnerId`, rebuilding the visual from the owner's R15 template while preserving class, stats, and value. All newly spawned or equipped troops start at Tier 1.

## Troop inventory and nameplates

The custom inventory shows one rendered weapon icon for each living owned troop, with no count rows or merge buttons. It sits at the bottom centre, fills eight columns left-to-right, then adds the ninth icon on a new row above. More rows continue upward with no inventory row cap. The panel scrolls vertically after reaching 45% of the available screen height; the gameplay army cap remains a separate rule. Slot sizes adapt to the screen width.

Tier borders are pale grey, blue, and gold for Tiers 1–3, with generated colours for future tiers. Mouse users drag icons directly; touch users hold for 0.18 seconds to start dragging, while quick swipes scroll. Dragging near the panel edges automatically scrolls to other rows. Invalid drops restore the icon. Escape, focus loss, screen resizing, and roster changes cancel an active drag.

Inventory entries follow replicated troop markers (ownership, class, tier, health, and lifetime), not culled visual clones or aggregate counts. Stable spawn ordering keeps icons from constantly reshuffling. Recruitment adds an icon, loss removes it, and a successful merge updates the selected destination while removing the source. Server responses appear as brief Fredoka One notices above the inventory.

Both owned and neutral troops have a title and tier above their heads (for example `Sword · T2`, `Archer · T1`, or `Giant · T3`) and a thin 8-pixel health bar underneath. Larger 25-pixel `current / maximum` health text sits over the centre of the bar. The bar changes from green to amber to red as health falls. All new text uses [Fredoka One](https://create.roblox.com/docs/reference/engine/datatypes/Font) and a custom black `UIStroke` with a 4-pixel thickness. Nameplates use a bottom anchor to stay above the head at different zoom levels and disappear beyond 140 studs.

The server initializes `Health`/`MaxHealth` on each troop marker and publishes changed health after combat, capture, and healing each tick. Nameplates use those attributes; they do not simulate health on the client. `TroopUI` supplies shared text styling and weapon icons, and nameplates are destroyed with their client rig on capture/culling.

## Troop architecture

The structure separates **what a troop is**, **its changing state**, **how it acts**, and **how it looks**. The server owns positions, health, targeting, attacks, and ownership. Clients render the server's result. Behaviour code is shared by capability, so a new melee troop can reuse melee combat without adding another class-name branch.

| File | Responsibility |
| --- | --- |
| `src/shared/TroopDefinitions.lua` | Type catalog: stable IDs, stats, movement/combat handler names, avatar scale, weapon, animations, recruitment weights, and starter counts |
| `src/shared/TroopTiers.lua` | Tier cap, stat growth, size growth, and tier-count attribute names; shared by server and client |
| `src/server/TroopMerge.lua` | Validate and consume matching owned pairs, apply tier upgrades, preserve injury/cash value/cooldown |
| `src/shared/ArmyConfig.lua` | Global rules, ordered catalog traversal, weighted roster selection, pricing, and starter-save migration |
| `src/server/ArmyServer.server.lua` | Unit creation/destruction, individual encounters, capture, health replication, player profiles, economy, and persistence |
| `src/server/NeutralSpawns.lua` | Random individual spawn positions, spacing/safe-zone/player clearance, and population retries |
| `src/server/NeutralAvatar.lua` | Asset-free, completely white R6 neutral template with six body parts and no face or clothing |
| `src/server/TroopMovement.lua` | Movement primitives and passive movement handler registry; owns wander/return state |
| `src/server/TroopCombat.lua` | Combat handler registry, per-troop nearest targets, melee charge, archer draw/run phases, cooldowns, and damage |
| `src/server/BattleEncounters.lua` | Engage multiple nearby encounters, preserve player exclusivity, release distant encounters, and collect the combined hostile roster |
| `src/server/AvatarTemplates.lua` | Publish the immediate neutral R6 template and cache full-size owned R15 appearances |
| `src/client/TroopVisuals.client.lua` | Clone/scale templates, interpolate server markers, play movement and attack animations, and cull distant rigs |
| `src/client/TroopWeapons.lua` | Weapon builder registry (`Sword`, `Bow`, `Club`), shared independently of troop IDs |
| `src/client/TroopRadius.client.lua` | Local player navigation circle and combat colour |
| `src/client/ArmyClient.client.lua` | Camera, hidden legacy economy HUD setup, and transient attack effects |
| `src/client/R6TroopAnimation.lua` | Procedural R6 walking, aiming, and melee poses; owned R15 rigs retain their asset animations |
| `src/client/TroopHUD.client.lua` | Individual troop inventory, roster tracking, mouse/touch dragging, matching feedback, and scrolling |
| `src/client/TroopInventoryLayout.lua` | Eight-column upward layout, responsive dimensions, and merge compatibility |
| `src/client/TroopUI.lua` | Shared Fredoka One/4 px text style, weapon icons, and title/health nameplates |
| `default.project.json` | Explicit Rojo mapping for every script/module |

### Definitions and state

A catalog entry has these independent groups:

- `DisplayName`: player-facing troop title (`Sword`, `Archer`, `Giant`).
- `Order`, `StarterCount`, `RecruitWeight`, `CampMinTier`: deterministic ordering and availability. Recruitment and neutral spawns use relative weights. `CampMinTier` remains available to tier-filtered roster callers; individual neutral spawns currently use all types.
- `Stats`: `Health`, `Damage`, `Range`, `Cooldown`, and captured recruit `Value`.
- `Movement`: passive `Behavior`, `CombatSpeed`, `WanderMultiplier`, and optional `ReturnSpeedMultiplier` (defaults to 1).
- `Combat`: `Behavior` (`Melee` or `Ranged` today), plus ranged `DrawTime` and `RangeLeeway`.
- `Visual`: relative `Scale`, weapon builder name, effect colour/width, and animation asset IDs. These do not control damage or movement authority.

Treat shared definitions as read-only. Each server unit owns `class`, `tier`, `model`, `pos`, `hp`, `nextAttack`, `earned`, `owner`, `movementState`, and `combatState`. Handler-specific timers and targets belong in that unit's state table, never in the shared definition. Entering combat clears passive destinations; leaving combat clears combat state; capture resets both. Only persistent gold and starter counts are saved, not transient behaviour state.

The client receives invisible markers with `Class`, `Tier`, `OwnerId`, `AttackSequence`, `CombatMode`, `Health`, and `MaxHealth`, plus their server-owned transforms. `CombatMode` is `Idle`, `Melee`, `Advance`, `Retreat`, `Aim`, or `Recover`; it drives both R15 animation tracks and R6 procedural poses. Ranged aim/fire poses are stopped while running or wandering. Attack effects use the existing `ArmyEffect` remote. Clients never choose hits or submit troop positions. Appearance templates retain the owner's body proportions; each clone applies the type's scale multiplied by tier growth and scales its root-to-floor offset too. [Roblox `Model:ScaleTo`](https://create.roblox.com/docs/reference/engine/classes/Model#ScaleTo) scales rig geometry and animation joint offsets together.

### Adding a troop or behaviour

1. Add a stable ID to `TroopDefinitions.lua` by copying the nearest existing definition. Give it a unique `Order`, its own stats/visuals, and normally `StarterCount = 0`. Use an existing movement, combat, and weapon handler where possible. Catalog ordering, inventory icons, titles, recruitment, neutral spawns, and fresh/save-loaded starter tables discover it automatically. Guaranteed training via the `Upgrade` action intentionally remains a Swordsman rule.
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

The runner compiles every production script, verifies Rojo source mappings, and executes unmodified definition/movement/combat modules with minimal Roblox API doubles. Checks cover catch-up speed changes, wandering, return transitions, ranged spacing/retreat, fractional range boundaries, melee pursuit, cooldowns, dead targets, save migration, neutral spawn spacing/respawn retries, blank R6 construction, health overlay updates, multi-encounter targeting/exclusivity/retreat, archer draw interruption, the two-stud attack band, tier scaling, invalid/foreign merge rejection, cash-value/health preservation, tiered damage, extending the tier cap, exact drag-pair validation, upward wrapping at 8/9/16/17 icons, and a 4,097-icon uncapped layout. They do not simulate Roblox rendering, animation, replication, or physics.

Studio playtest checklist: compare all three troop sizes with the owner; verify weapons and feet stay aligned; idle and run through turns; change the player's `WalkSpeed`; die/respawn; approach neutral troops and verify melee charges, archer retreat/pursuit, and white/red circle transitions. Engage an Archer, then approach another neutral and verify troops split by proximity while both encounters remain active. Check bow lowering during retreat and stationary drawing anywhere in the 30–32-stud band. Check that inventory icons appear/disappear with owned troops and that title/HP text stays above both rig types during damage and healing. Test capture, respawning at a new location, different player appearances in a multiplayer session, and merging through Tiers 2/3 while both idle and fighting. Verify the enlarged body, weapons, grounded feet, health text, and inventory icons on desktop and touch controls. Drag specific injured matching troops to verify selection, reject invalid/max-tier pairs, add a ninth/seventeenth icon to check upward wrapping, scroll/auto-scroll through a large roster, and confirm loss/capture/resize during a drag cancels it cleanly.

## Gameplay and limits

With enemies enabled, up to 60 individual neutral troops spawn across the field. Approach one to auto-battle; defeated troops join your army. Return to the barracks to bank captured recruits, train a permanent Swordsman, or roll a permanent troop (60% Swordsman, 30% Archer, 10% Giant). The economy HUD/prompts remain hidden; the troop inventory and overhead health UI are visible.

The field cap is 60; the permanent starter cap is 12. Only captured troops have cash-in value. Retreat resets each encounter that is left behind; returning to base releases every active encounter. Losing the army or resetting the character loses field troops while keeping banked gold and starter upgrades. Each neutral encounter engages one player at a time; there is no PvP.

Studio progress is session-only. Published servers use DataStore storage, without production-grade cross-server session locking. Units use flat direct movement, with no obstacle pathfinding, collision avoidance, or line of sight. The server updates around 10 Hz and has not been load-tested for large multiplayer sessions.

Animations are Roblox-owned placeholders: idle 507766666, walk 507777826, hold 507768375, slash 522635514, aim 4713633512, fire 4713811763. Aim/fire come from the official [Soldier NPC kit](https://create.roblox.com/store/asset/3924234975) and are temporary Archer animations. Giants reuse the melee swing. No third-party model scripts were imported. Neutral R6 bodies use local procedural limb poses instead of those R15 asset tracks. Standalone checks cannot verify visual quality; rigs, HUD, nameplates, circle, and live combat still need Studio playtesting.

## Reference lighting pass

The field uses subtle alternating greens in 25-stud squares with aligned tiled [stud textures](https://create.roblox.com/store/asset/10455712373). Lighting uses Realistic lighting, a 09:00 sun at latitude 0, blue ambient fill, warm highlights, Retro tone mapping, and restrained bloom. A custom cloud-free cyan-to-pale-cyan sky replaces the distant backdrop walls. Settings live in `default.project.json`; use serialized `TimeOfDay` for reliable Rojo syncing. Player graphics settings affect detail and shadows.

`python3 tools/build_sky.py` regenerates the sky-face PNGs in `assets/sky`. Changed sky images must be uploaded to Roblox and their asset IDs updated in `ClearSky`; Rojo does not upload PNGs automatically.
