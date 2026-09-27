local Config = {}
Config.SpawnEnemies = false
Config.SafeRadius = 36
Config.ArmyCap = 60
Config.StarterCap = 12
Config.Roaming = {
	Radius = 18,
	ArrivalDistance = 0.6,
	WalkSpeedMin = 4,
	WalkSpeedMax = 6,
	ReturnSpeed = 32, -- Faster than the master's 23-stud walking speed.
}
Config.Classes = {
	Swordsman = {Health = 75, Damage = 15, Range = 6, Cooldown = 0.75, Speed = 23, Value = 12, Color = Color3.fromRGB(89, 182, 255)},
	Archer = {Health = 42, Damage = 12, Range = 32, Cooldown = 1.05, Speed = 22, Value = 22, Color = Color3.fromRGB(112, 228, 149)},
	Rocketeer = {Health = 55, Damage = 22, Range = 27, Cooldown = 2.4, Speed = 20, Value = 40, Splash = 9, Color = Color3.fromRGB(255, 190, 82)},
}
Config.Order = {"Swordsman", "Archer", "Rocketeer"}
function Config.starterCount(starter)
	return starter.Swordsman + starter.Archer + starter.Rocketeer
end
function Config.upgradeCost(starter)
	return 45 + (Config.starterCount(starter) - 4) * 25
end
function Config.rollCost(starter)
	return 65 + (Config.starterCount(starter) - 4) * 30
end
return Config
