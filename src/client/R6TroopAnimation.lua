-- Procedural poses for the blank R6 template; R15 asset tracks cannot animate these joints.
local Animation = {}
function Animation.create(rig, ranged)
 local joints = {}
 for _, name in ipairs({"Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip"}) do
  local motor = rig:FindFirstChild(name, true)
  joints[name] = {motor = motor, base = motor.C0}
 end
 return {joints = joints, phase = 0, attackUntil = 0, ranged = ranged, scale = rig:GetScale()}
end
function Animation.update(state, speed, now, dt, combatMode)
 state.phase += dt * speed / state.scale * 0.8
 local swing = math.sin(state.phase) * math.clamp(speed / 8, 0, 1) * 0.6
 local attack = math.clamp((state.attackUntil - now) / 0.35, 0, 1)
 local function pose(name, angle)
  local joint = state.joints[name]
  joint.motor.C0 = joint.base * CFrame.Angles(angle, 0, 0)
 end
 pose("Left Hip", swing)
 pose("Right Hip", -swing)
 if state.ranged and (combatMode == "Aim" or (combatMode == "Recover" and attack > 0)) then
  pose("Left Shoulder", math.pi / 2)
  pose("Right Shoulder", math.pi / 2 - attack * 0.4)
 else
  pose("Left Shoulder", -swing * 0.65)
  pose("Right Shoulder", swing * 0.65 + (state.ranged and 0 or math.sin(attack * math.pi) * 1.8))
 end
end
return Animation
