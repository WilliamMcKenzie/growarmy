local RS = game:GetService("ReplicatedStorage")
local C = require(RS:WaitForChild("ArmyConfig"))
local Tiers = require(RS:WaitForChild("TroopTiers"))
local Movement = require(script.Parent:WaitForChild("TroopMovement"))
local Combat = require(script.Parent:WaitForChild("TroopCombat"))
local Merge = {}
local function combine(units, first, second, secondIndex, now)
 local class, tier = first.class, first.tier
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
 second.hp = 0
 second.model:Destroy()
 return first
end

-- Dragging selects actual troops, not an arbitrary pair of the same class.
-- Membership in this player's server roster is the authority, even for forged/stale Instances.
function Merge.applyPair(units, owner, sourceModel, targetModel, now)
 if not sourceModel or not targetModel or sourceModel == targetModel then
  return nil, "Drop onto another matching troop."
 end
 local source, target, sourceIndex
 for index, unit in ipairs(units) do
  if unit.owner == owner and unit.hp > 0 then
   if unit.model == sourceModel then source = unit; sourceIndex = index end
   if unit.model == targetModel then target = unit end
  end
 end
 if not source or not target then return nil, "One of those troops is no longer available." end
 if source.class ~= target.class or source.tier ~= target.tier then
  return nil, "Match the same troop type and tier."
 end
 if not Tiers.isValid(target.tier) or target.tier >= Tiers.MaxTier then
  return nil, "This troop is already at the highest tier."
 end
 return combine(units, target, source, sourceIndex, now)
end

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
 return combine(units, first, second, secondIndex, now)
end

return Merge
