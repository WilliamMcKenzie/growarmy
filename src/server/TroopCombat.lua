local C = require(game:GetService("ReplicatedStorage"):WaitForChild("ArmyConfig"))
local Movement = require(script.Parent:WaitForChild("TroopMovement"))
local Combat = {}
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function nearest(unit, enemies)
 local best, distance = nil, math.huge
 for _, enemy in ipairs(enemies) do
  if enemy.hp > 0 then
   local d = flat(enemy.pos - unit.pos).Magnitude
   if d < distance then best, distance = enemy, d end
  end
 end
 return best, distance
end

local function attack(unit, target, stats, now, emitEffect)
 -- Check range after movement. Tiny tolerance absorbs floating-point roundoff only.
 if flat(target.pos - unit.pos).Magnitude <= stats.Range + 0.001 then
  if now >= unit.nextAttack then
   unit.nextAttack = now + stats.Cooldown
   unit.model:SetAttribute("AttackSequence", unit.model:GetAttribute("AttackSequence") + 1)
   target.hp -= stats.Damage
   emitEffect(unit, target)
  end
 end
end

-- Handlers own targeting and positioning; damage/cooldown rules are shared.
Combat.Behaviors = {}
function Combat.Behaviors.Melee(unit, enemies, now, dt, emitEffect)
 local target, distance = nearest(unit, enemies)
 if not target then return end
 local def = C.Classes[unit.class]
 if distance > def.Stats.Range then
  local direction = flat(target.pos - unit.pos).Unit
  -- Charge directly to melee reach, without running through the target on a long tick.
  local destination = target.pos - direction * def.Stats.Range
  Movement.stepToward(unit, destination, dt, def.Movement.CombatSpeed, target.pos)
 else
  Movement.place(unit, unit.pos, target.pos)
 end
 attack(unit, target, def.Stats, now, emitEffect)
end

function Combat.Behaviors.Ranged(unit, enemies, now, dt, emitEffect)
 local target = nearest(unit, enemies)
 if not target then return end
 local def = C.Classes[unit.class]
 local away = flat(unit.pos - target.pos)
 -- Coincident spawns still need a finite escape direction.
 local direction = away.Magnitude > 0.001 and away.Unit or Vector3.new(1, 0, 0)
 local destination = target.pos + direction * def.Stats.Range
 Movement.stepToward(unit, destination, dt, def.Movement.CombatSpeed, target.pos)
 attack(unit, target, def.Stats, now, emitEffect)
end

function Combat.update(units, enemies, now, dt, emitEffect)
 for _, unit in ipairs(units) do
  if unit.hp <= 0 then continue end
  Movement.reset(unit)
  local name = C.Classes[unit.class].Combat.Behavior
  local behavior = assert(Combat.Behaviors[name], "Unknown combat behavior: " .. name)
  behavior(unit, enemies, now, dt, emitEffect)
 end
end

return Combat
