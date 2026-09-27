local RS = game:GetService("ReplicatedStorage")
local C = require(RS:WaitForChild("ArmyConfig"))
local Tiers = require(RS:WaitForChild("TroopTiers"))
local Movement = require(script.Parent:WaitForChild("TroopMovement"))
local Combat = require(script.Parent:WaitForChild("TroopCombat"))
local Merge = {}

-- Never trust client troop IDs/counts; select two living, owned members of the server roster.
function Merge.apply(units, owner, class, tier, now)
 if type(class) ~= "string" or not C.Classes[class] or not Tiers.isValid(tier) or tier >= Tiers.MaxTier then
  return nil, "That troop tier cannot be merged."
 end
 local first, second, secondIndex
 for index, unit in ipairs(units) do
  if unit.owner == owner and unit.class == class and unit.tier == tier and unit.hp > 0 then
   if not first then first = unit
   else second = unit; secondIndex = index; break end
  end
 end
 if not second then return nil, "You need two living troops of the same type and tier." end
 local oldStats = Tiers.stats(class, tier)
 local newStats = Tiers.stats(class, tier + 1)
 local healthFraction = (math.clamp(first.hp, 0, oldStats.Health) + math.clamp(second.hp, 0, oldStats.Health)) / (2 * oldStats.Health)
 first.tier = tier + 1
 first.hp = newStats.Health * healthFraction
 first.earned = (first.earned or 0) + (second.earned or 0)
 first.nextAttack = math.max(first.nextAttack, second.nextAttack, now)
 Movement.reset(first); Combat.reset(first)
 first.model:SetAttribute("Tier", first.tier)
 first.model:SetAttribute("MaxHealth", newStats.Health)
 first.model:SetAttribute("Health", first.hp)
 table.remove(units, secondIndex)
 second.hp = 0 -- Invalidate any old target reference before destroying its marker.
 second.model:Destroy()
 return first
end

return Merge
