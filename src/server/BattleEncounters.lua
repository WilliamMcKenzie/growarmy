local C = require(game:GetService("ReplicatedStorage"):WaitForChild("ArmyConfig"))
local Battles = {}
local function distance(a, b)
 local d = a - b
 return math.sqrt(d.X * d.X + d.Z * d.Z)
end

-- Each encounter stays exclusive to one player, but a player can engage many at once.
function Battles.update(player, position, canEngage, encounters, resetEncounter)
 local active, enemies, retreated = {}, {}, false
 for _, encounter in ipairs(encounters) do
  local released = false
  if encounter.owner == player and (not canEngage
   or distance(position, encounter.pos) > C.NeutralSpawns.RetreatDistance) then
   resetEncounter(encounter)
   retreated = true; released = true
  end
  if canEngage and not released and not encounter.owner and not encounter.respawn then
   for _, unit in ipairs(encounter.units) do
    if unit.hp > 0 and distance(position, unit.pos) < C.NeutralSpawns.EngageDistance then
     encounter.owner = player
     break
    end
   end
  end
  if encounter.owner == player then
   table.insert(active, encounter)
   for _, unit in ipairs(encounter.units) do
    if unit.hp > 0 then table.insert(enemies, unit) end
   end
  end
 end
 return active, enemies, retreated
end

return Battles
