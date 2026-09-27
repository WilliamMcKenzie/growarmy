-- Progression is independent of troop behaviour. Raise MaxTier to unlock more ranks.
local Definitions = require(script.Parent:WaitForChild("TroopDefinitions"))
local Tiers = {
 MaxTier = 3,
 SizeMultiplier = 1.2,
 StatMultipliers = {Health = 2.2, Damage = 2.2, Value = 2},
}
local cache = {}
function Tiers.isValid(tier)
 return type(tier) == "number" and tier == math.floor(tier) and tier >= 1 and tier <= Tiers.MaxTier
end
function Tiers.stats(class, tier)
 tier = tier or 1
 assert(Tiers.isValid(tier), "Invalid troop tier")
 local definition = assert(Definitions[class], "Unknown troop class")
 cache[class] = cache[class] or {}
 if not cache[class][tier] then
  local stats = table.clone(definition.Stats)
  for name, multiplier in pairs(Tiers.StatMultipliers) do
   stats[name] = math.floor(stats[name] * multiplier ^ (tier - 1) + 0.5)
  end
  cache[class][tier] = table.freeze(stats)
 end
 return cache[class][tier]
end
function Tiers.scale(class, tier)
 tier = tier or 1
 assert(Tiers.isValid(tier), "Invalid troop tier")
 return Definitions[class].Visual.Scale * Tiers.SizeMultiplier ^ (tier - 1)
end
function Tiers.countAttribute(class, tier)
 return class .. "_Tier" .. tier
end
return Tiers
