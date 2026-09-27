-- Stable IDs are used in saves and replicated markers. Behaviour/weapon names
-- select reusable handlers; adding a type should not add class-name branches.
return {
 Swordsman = {
  DisplayName = "Sword",
  Order = 1, StarterCount = 2, RecruitWeight = 60, CampMinTier = 1,
  Stats = {Health = 75, Damage = 15, Range = 6, Cooldown = 0.75, Value = 12},
  Movement = {Behavior = "Wander", CombatSpeed = 23, WanderMultiplier = 1},
  Combat = {Behavior = "Melee"},
  Visual = {
   Scale = 0.8, Weapon = "Sword", Color = Color3.fromRGB(89, 182, 255),
   Animations = {Idle = 507766666, Walk = 507777826, Hold = 507768375, Attack = 522635514},
   Effect = {Width = 0.15},
  },
 },
 Archer = {
  DisplayName = "Archer",
  Order = 2, StarterCount = 1, RecruitWeight = 30, CampMinTier = 1,
  Stats = {Health = 42, Damage = 12, Range = 32, Cooldown = 1.05, Value = 22},
  Movement = {Behavior = "Wander", CombatSpeed = 21, WanderMultiplier = 0.95},
  Combat = {Behavior = "Ranged"},
  Visual = {
   Scale = 0.8, Weapon = "Bow", Color = Color3.fromRGB(112, 228, 149),
   Animations = {Idle = 507766666, Walk = 507777826, Hold = 4713633512, Attack = 4713811763},
   Effect = {Width = 0.15},
  },
 },
 Giant = {
  DisplayName = "Giant",
  Order = 3, StarterCount = 1, RecruitWeight = 10, CampMinTier = 2,
  Stats = {Health = 180, Damage = 30, Range = 7, Cooldown = 1.6, Value = 40},
  Movement = {Behavior = "Wander", CombatSpeed = 19, WanderMultiplier = 0.8},
  Combat = {Behavior = "Melee"},
  Visual = {
   Scale = 1.2, Weapon = "Club", Color = Color3.fromRGB(255, 190, 82),
   Animations = {Idle = 507766666, Walk = 507777826, Hold = 507768375, Attack = 522635514},
   Effect = {Width = 0.4},
  },
 },
}
