local Config = {}
Config.SpawnEnemies = true
Config.NeutralSpawns = {
	Population = 60,
	EdgeMargin = 24,
	MinSpacing = 24,
	PlayerClearance = 48,
	Attempts = 80,
	RespawnDelay = 35,
	RetryDelay = 5,
	EngageDistance = 29,
	RetreatDistance = 52,
}
Config.SafeRadius = 36
Config.ArmyCap = 60
Config.StarterCap = 12
Config.PlayerWalkSpeed = 23
Config.Roaming = {
	Radius = 18,
	ArrivalDistance = 0.6,
	WalkSpeedMin = 4,
	WalkSpeedMax = 6,
}
Config.Classes = require(script.Parent:WaitForChild("TroopDefinitions"))
Config.Order = {}
for class in pairs(Config.Classes) do table.insert(Config.Order, class) end
table.sort(Config.Order, function(a, b) return Config.Classes[a].Order < Config.Classes[b].Order end)
function Config.starterCount(starter)
	local count = 0
	for _, class in ipairs(Config.Order) do count += starter[class] or 0 end
	return count
end
function Config.newStarter()
	local starter = {}
	for _, class in ipairs(Config.Order) do starter[class] = Config.Classes[class].StarterCount end
	return starter
end
Config.BaseStarterCount = Config.starterCount(Config.newStarter())
-- Preserve old permanent recruits when replacing a retired type.
Config.LegacyClasses = {Rocketeer = "Giant"}
local function validCount(value)
	local n = tonumber(value)
	if not n or n ~= n then return 0 end
	return math.clamp(math.floor(n), 0, Config.StarterCap)
end
function Config.restoreStarter(saved)
	if type(saved) ~= "table" then return Config.newStarter() end
	local starter = {}
	for _, class in ipairs(Config.Order) do starter[class] = validCount(saved[class]) end
	for old, class in pairs(Config.LegacyClasses) do starter[class] += validCount(saved[old]) end
	local remaining = Config.StarterCap
	for _, class in ipairs(Config.Order) do
		starter[class] = math.min(starter[class], remaining)
		remaining -= starter[class]
	end
	-- Old squads keep their composition; repair incomplete saves to the starter minimum.
	local missing = Config.BaseStarterCount - Config.starterCount(starter)
	if missing > 0 then starter[Config.Order[1]] += missing end
	return starter
end
function Config.rollClass(random, campTier)
	local total = 0
	for _, class in ipairs(Config.Order) do
		local def = Config.Classes[class]
		if not campTier or def.CampMinTier <= campTier then total += def.RecruitWeight end
	end
	assert(total > 0, "No eligible troops for this roster")
	local roll = random:NextNumber() * total
	local lastEligible
	for _, class in ipairs(Config.Order) do
		local def = Config.Classes[class]
		if not campTier or def.CampMinTier <= campTier then
			if def.RecruitWeight > 0 then lastEligible = class end
			roll -= def.RecruitWeight
			if roll < 0 then return class end
		end
	end
	return lastEligible -- Also handles an inclusive upper endpoint from the RNG.
end
function Config.upgradeCost(starter)
	return 45 + (Config.starterCount(starter) - Config.BaseStarterCount) * 25
end
function Config.rollCost(starter)
	return 65 + (Config.starterCount(starter) - Config.BaseStarterCount) * 30
end
return Config
