local C = require(game:GetService("ReplicatedStorage"):WaitForChild("ArmyConfig"))
local Spawns = {}
local function distance(a, b)
 local delta = a - b
 return math.sqrt(delta.X * delta.X + delta.Z * delta.Z)
end

-- Bounded rejection sampling: no groups, safe-zone spawns, edge spawns, or spawning on players.
function Spawns.pickPosition(random, field, encounters, playerPositions, ignored)
 local settings = C.NeutralSpawns
 local margin = math.max(settings.EdgeMargin, C.Roaming.Radius + 6)
 local halfX, halfZ = field.Size.X / 2 - margin, field.Size.Z / 2 - margin
 if halfX <= 0 or halfZ <= 0 then return nil end
 for _ = 1, settings.Attempts do
  local position = Vector3.new(
   field.Position.X + random:NextNumber(-halfX, halfX),
   field.Position.Y + field.Size.Y / 2 + 0.3,
   field.Position.Z + random:NextNumber(-halfZ, halfZ)
  )
  local allowed = distance(position, Vector3.new(0, 0, 0)) >= C.SafeRadius + C.Roaming.Radius + 6
  for _, encounter in ipairs(encounters) do
   if encounter ~= ignored and encounter.pos and #encounter.units > 0
    and distance(position, encounter.pos) < settings.MinSpacing then allowed = false; break end
  end
  for _, playerPosition in ipairs(playerPositions) do
   if distance(position, playerPosition) < settings.PlayerClearance then allowed = false; break end
  end
  if allowed then return position end
 end
 return nil -- Retry later rather than violate spacing when the field is crowded.
end

function Spawns.populate(encounter, random, field, encounters, playerPositions, now, createUnit)
 local position = Spawns.pickPosition(random, field, encounters, playerPositions, encounter)
 if not position then
  encounter.respawn = now + C.NeutralSpawns.RetryDelay
  return false
 end
 encounter.pos = position
 encounter.units = {createUnit(C.rollClass(random), position)}
 encounter.respawn = nil
 return true
end

return Spawns
