local C = require(game:GetService("ReplicatedStorage"):WaitForChild("ArmyConfig"))
local random = Random.new()
local Movement = {}
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

function Movement.place(unit, position, face)
 unit.pos = position
 local target = face or position + Vector3.new(0, 0, -1)
 if flat(target - position).Magnitude < 0.01 then target = position + Vector3.new(0, 0, -1) end
 unit.model.PrimaryPart.CFrame = CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z))
end

function Movement.stepToward(unit, target, dt, speed, face)
 local delta = flat(target - unit.pos)
 local position = unit.pos
 if delta.Magnitude > 0.001 then position += delta.Unit * math.min(delta.Magnitude, speed * dt) end
 Movement.place(unit, position, face or target)
end

function Movement.reset(unit)
 unit.movementState = {}
end

local function pickTarget(unit, center, state)
 local angle = random:NextNumber(0, math.pi * 2)
 local radius = math.sqrt(random:NextNumber()) * C.Roaming.Radius * 0.85
 state.target = Vector3.new(center.X + math.cos(angle) * radius, unit.pos.Y, center.Z + math.sin(angle) * radius)
 state.speed = random:NextNumber(C.Roaming.WalkSpeedMin, C.Roaming.WalkSpeedMax)
  * C.Classes[unit.class].Movement.WanderMultiplier
end

Movement.Behaviors = {}
function Movement.Behaviors.Wander(unit, context, dt)
 local state = unit.movementState
 local center = context.center
 local outside = flat(unit.pos - center).Magnitude > C.Roaming.Radius
 if state.target and flat(state.target - unit.pos).Magnitude <= C.Roaming.ArrivalDistance then
  state.returning = false
  state.target = nil
 end
 if outside and not state.returning then
  state.returning = true
  state.target = nil
 end
 -- Keep world-space destinations until reached or left outside the master's radius.
 if not state.target or flat(state.target - center).Magnitude > C.Roaming.Radius then
  pickTarget(unit, center, state)
 end
 -- All classes match the current master WalkSpeed; class penalties apply only to wandering/combat.
 Movement.stepToward(unit, state.target, dt, state.returning and context.walkSpeed or state.speed)
end

function Movement.update(unit, context, dt)
 local name = C.Classes[unit.class].Movement.Behavior
 local behavior = assert(Movement.Behaviors[name], "Unknown movement behavior: " .. name)
 behavior(unit, context, dt)
end

return Movement
