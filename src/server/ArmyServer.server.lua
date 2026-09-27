local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local C = require(RS:WaitForChild("ArmyConfig"))
local Tiers = require(RS:WaitForChild("TroopTiers"))
local Merge = require(script.Parent:WaitForChild("TroopMerge"))
local Movement = require(script.Parent:WaitForChild("TroopMovement"))
local Combat = require(script.Parent:WaitForChild("TroopCombat"))
local Battles = require(script.Parent:WaitForChild("BattleEncounters"))
local NeutralSpawns = require(script.Parent:WaitForChild("NeutralSpawns"))
local field = workspace:WaitForChild("Map"):WaitForChild("Field")
local remote = Instance.new("RemoteEvent", RS)
remote.Name = "ArmyAction"
local fx = Instance.new("RemoteEvent", RS)
fx.Name = "ArmyEffect"
local troops = Instance.new("Folder", workspace)
troops.Name = "Troops"
local profiles, encounters = {}, {}
local store = not RunService:IsStudio() and DataStoreService:GetDataStore("GrowArmyPrototype_v1") or nil
local uid = 0
local Avatars = require(script.Parent:WaitForChild("AvatarTemplates"))
local rosterRandom = Random.new()

local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function root(player) return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function atBase(player)
 local r = root(player)
 return r and flat(r.Position).Magnitude < C.SafeRadius
end
local function paint(u, friendly)
 u.model:SetAttribute("OwnerId", friendly and friendly.UserId or 0)
end
local function syncHealth(units)
 for _,u in ipairs(units) do
  local health=math.clamp(u.hp,0,Tiers.stats(u.class,u.tier).Health)
  if u.model:GetAttribute("Health")~=health then u.model:SetAttribute("Health",health) end
 end
end
local function createUnit(class, pos, owner, earned, tier)
 tier=tier or 1
 local stats=Tiers.stats(class,tier)
 uid += 1
 local model = Instance.new("Model")
 model.Name = class.."_"..uid
 local marker = Instance.new("Part",model)
 marker.Name="Root";marker.Size=Vector3.new(1,1,1);marker.Transparency=1
 marker.Anchored=true;marker.CanCollide=false;marker.CanTouch=false;marker.CanQuery=false
 model.PrimaryPart=marker
 model:SetAttribute("Class",class)
 model:SetAttribute("Tier",tier)
 model:SetAttribute("AttackSequence",0)
 model:SetAttribute("CombatMode","Idle")
 model:SetAttribute("Health",stats.Health)
 model:SetAttribute("MaxHealth",stats.Health)
 local u={class=class,tier=tier,model=model,pos=pos,hp=stats.Health,nextAttack=0,earned=earned or 0,owner=owner,movementState={},combatState={}}
 paint(u,owner);Movement.place(u,pos);model.Parent=troops
 return u
end
local function clear(units)
 for _,u in ipairs(units) do u.model:Destroy() end
 table.clear(units)
end
local function value(p)
 local amount = 0
 for _,u in ipairs(p.units) do amount += u.earned end
 return amount
end
local function announce(player,message) remote:FireClient(player,"Message",message) end
local function sync(player)
 local p=profiles[player]
 if not p then return end
 player:SetAttribute("Gold",p.gold)
 player:SetAttribute("ArmySize",#p.units)
 player:SetAttribute("CashValue",value(p))
 player:SetAttribute("StarterSize",C.starterCount(p.starter))
 player:SetAttribute("UpgradeCost",C.upgradeCost(p.starter))
 player:SetAttribute("RollCost",C.rollCost(p.starter))
 for _,class in ipairs(C.Order) do
  local n=0
  local tierCounts=table.create(Tiers.MaxTier,0)
  for _,u in ipairs(p.units) do if u.class==class then n+=1;tierCounts[u.tier]+=1 end end
  player:SetAttribute(class,n)
  for tier=1,Tiers.MaxTier do player:SetAttribute(Tiers.countAttribute(class,tier),tierCounts[tier]) end
  player:SetAttribute("Starter"..class,p.starter[class])
 end
end
local function equip(player)
 local p=profiles[player]
 if not p then return end
 clear(p.units)
 local r=root(player)
 if not r then return end
 for _,class in ipairs(C.Order) do
  for i=1,p.starter[class] do
   table.insert(p.units,createUnit(class,Vector3.new(r.Position.X+(#p.units%4)*3,0.3,r.Position.Z+6+math.floor(#p.units/4)*3),player))
  end
 end
 sync(player)
end
local function save(player)
 local p=profiles[player]
 if not p or not store or p.saving then return end
 p.saving=true
 local data={gold=p.gold,starter=table.clone(p.starter)}
 local ok,err=pcall(function() store:UpdateAsync(tostring(player.UserId),function() return data end) end)
 p.saving=false
 if not ok then warn("Army progress save failed: "..tostring(err)); player:SetAttribute("SaveMode","Save failed • retrying")
 else player:SetAttribute("SaveMode","Progress saves") end
end
local function playerPositions()
 local positions={}
 for _,player in ipairs(Players:GetPlayers()) do
  local r=root(player)
  if r then table.insert(positions,r.Position) end
 end
 return positions
end
local function spawnEncounter(encounter)
 clear(encounter.units)
 encounter.owner=nil
 NeutralSpawns.populate(encounter,rosterRandom,field,encounters,playerPositions(),os.clock(),createUnit)
end
if C.SpawnEnemies then
 for _=1,C.NeutralSpawns.Population do
  local encounter={units={}}
  table.insert(encounters,encounter)
  spawnEncounter(encounter)
 end
end
local function release(player)
 for _,encounter in ipairs(encounters) do
  if encounter.owner==player then spawnEncounter(encounter) end
 end
 player:SetAttribute("InBattle",false)
end
local function action(player,verb,sourceModel,targetModel)
 local p=profiles[player]
 if verb=="Merge" then
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if not p or not root(player) or not humanoid or humanoid.Health<=0 or os.clock()-(p.lastMerge or -math.huge)<0.3 then return end
  p.lastMerge=os.clock()
  local merged,message=Merge.applyPair(p.units,player,sourceModel,targetModel,os.clock())
  if not merged then remote:FireClient(player,"MergeResult",message);return end
  sync(player)
  remote:FireClient(player,"MergeResult",(C.Classes[merged.class].DisplayName or merged.class).." merged to Tier "..merged.tier.."!")
  return
 end
 if not p or not atBase(player) or os.clock()-(p.lastAction or 0)<0.5 then return end
 p.lastAction=os.clock()
 if verb=="CashIn" then
  local amount=value(p)
  if amount==0 then announce(player,"Defeat a neutral troop first — recruited troops are worth gold.");return end
  p.gold+=amount
  release(player)
  equip(player)
  announce(player,"Banked "..amount.." gold! Your starting squad is ready.")
 elseif verb=="Upgrade" or verb=="Recruit" then
  if C.starterCount(p.starter)>=C.StarterCap then announce(player,"Prototype starter squad maxed: "..C.StarterCap.." troops.");return end
  local cost=verb=="Upgrade" and C.upgradeCost(p.starter) or C.rollCost(p.starter)
  if p.gold<cost then announce(player,"You need "..cost.." gold.");return end
  local class="Swordsman"
  if verb=="Recruit" then
   class=C.rollClass(rosterRandom)
  end
  p.gold-=cost;p.starter[class]+=1
  local r=root(player)
  if #p.units<C.ArmyCap then table.insert(p.units,createUnit(class,Vector3.new(r.Position.X+3,0.3,r.Position.Z+5),player)) end
  announce(player,"Permanent +1 "..class.."! Included in every starting squad.")
 else return end
 sync(player)
 task.spawn(save,player)
end
remote.OnServerEvent:Connect(function(player,verb,sourceModel,targetModel) if typeof(verb)=="string" then action(player,verb,sourceModel,targetModel) end end)
for _,verb in ipairs({"CashIn","Upgrade","Recruit"}) do
 workspace.Map[verb].Prompt.Triggered:Connect(function(player) action(player,verb) end)
end

local function emitEffect(unit,target)
 fx:FireAllClients(unit.pos+Vector3.new(0,2,0),target.pos+Vector3.new(0,2,0),unit.class)
end
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed<0.1 then return end
 dt=math.min(elapsed,0.25);elapsed=0
 local now=os.clock()
 for _,encounter in ipairs(encounters) do
  if encounter.respawn and now>=encounter.respawn then spawnEncounter(encounter) end
  if not encounter.owner and not encounter.respawn then
   for _,u in ipairs(encounter.units) do
    Movement.update(u,{center=encounter.pos,walkSpeed=C.Classes[u.class].Movement.CombatSpeed},dt)
   end
  end
 end
 for player,p in pairs(profiles) do
  local r=root(player)
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if not r or not humanoid or humanoid.Health<=0 then continue end
  local active,enemies,retreated=Battles.update(player,r.Position,not atBase(player) and #p.units>0,encounters,spawnEncounter)
  if retreated then announce(player,"Retreated — distant neutral troops have reset.") end
  player:SetAttribute("InBattle",#enemies>0)
  if #enemies>0 then
   -- Every troop chooses its own nearest opponent across all of this player's encounters.
   Combat.update(p.units,enemies,now,dt,emitEffect)
   Combat.update(enemies,p.units,now,dt,emitEffect)
   for i=#p.units,1,-1 do
    local u=p.units[i]
    if u.hp<=0 then u.model:Destroy();table.remove(p.units,i) end
   end
   if #p.units==0 then
    release(player)
    r.CFrame=CFrame.new(0,5,12)
    equip(player);announce(player,"Army lost! Banked gold and starter upgrades are safe.")
   else
    local remaining,recruited=0,0
    for _,encounter in ipairs(active) do
     for i=#encounter.units,1,-1 do
      local u=encounter.units[i]
      if u.hp<=0 then
       table.remove(encounter.units,i)
       if #p.units<C.ArmyCap then
        local stats=Tiers.stats(u.class,u.tier)
        u.hp=stats.Health;u.owner=player;u.earned=stats.Value;u.nextAttack=now+0.6
        Movement.reset(u);Combat.reset(u)
        paint(u,player);table.insert(p.units,u);recruited+=1
       else u.model:Destroy() end
      end
     end
     if #encounter.units==0 then
      encounter.owner=nil;encounter.respawn=now+C.NeutralSpawns.RespawnDelay
     else remaining+=1 end
    end
    player:SetAttribute("InBattle",remaining>0)
    if recruited>0 then announce(player,"Recruited "..recruited.." troop(s)! Bank them or push farther.") end
   end
  else
   local healing=atBase(player)
   local movementContext={center=r.Position,walkSpeed=humanoid.WalkSpeed}
   for _,u in ipairs(p.units) do
    Combat.reset(u)
    Movement.update(u,movementContext,dt)
    if healing then u.hp=Tiers.stats(u.class,u.tier).Health end
   end
  end
  sync(player)
 end
 -- Publish after all combat/capture/healing, so every behaviour uses the same health channel.
 for _,p in pairs(profiles) do syncHealth(p.units) end
 for _,encounter in ipairs(encounters) do syncHealth(encounter.units) end
end)
local function joined(player)
 local data=nil
 if store then
  local ok,result=pcall(function() return store:GetAsync(tostring(player.UserId)) end)
  if not ok then player:Kick("Progress could not load. Please rejoin to protect your save.");return end
  data=result
 end
 if not player.Parent then return end
 local starter=C.restoreStarter(type(data)=="table" and data.starter or nil)
 profiles[player]={gold=type(data)=="table" and math.max(0,tonumber(data.gold) or 0) or 0,starter=starter,units={}}
 player:SetAttribute("SaveMode",store and "Progress saves" or "Studio • session-only progress")
 local function spawned(character)
  local humanoid=character:WaitForChild("Humanoid")
  character:WaitForChild("HumanoidRootPart")
  humanoid.WalkSpeed=C.PlayerWalkSpeed
  humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
  task.spawn(Avatars.load,player,character)
  release(player);equip(player)
  humanoid.Died:Connect(function()
   local p=profiles[player]
   if p then clear(p.units);release(player);sync(player) end
  end)
 end
 player.CharacterAdded:Connect(spawned)
 if player.Character then task.spawn(spawned,player.Character) end
 sync(player)
end
Players.PlayerAdded:Connect(joined)
for _,p in ipairs(Players:GetPlayers()) do task.spawn(joined,p) end
Players.PlayerRemoving:Connect(function(player)
 save(player)
 local p=profiles[player]
 if p then clear(p.units) end
 release(player);Avatars.remove(player);profiles[player]=nil
end)
task.spawn(function() while task.wait(60) do for p in pairs(profiles) do task.spawn(save,p) end end end)
game:BindToClose(function()
 for player in pairs(profiles) do task.spawn(save,player) end
 local deadline=os.clock()+20
 repeat
  local busy=false
  for _,p in pairs(profiles) do if p.saving then busy=true end end
  if not busy then break end
  task.wait(0.1)
 until os.clock()>deadline
end)
print("Grow an Army ready: "..#encounters.." encounters, "..#C.Order.." classes, server-authoritative PvE.")
