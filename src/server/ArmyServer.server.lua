local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local C = require(RS:WaitForChild("ArmyConfig"))
local Movement = require(script.Parent:WaitForChild("TroopMovement"))
local Combat = require(script.Parent:WaitForChild("TroopCombat"))
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
  local health=math.clamp(u.hp,0,C.Classes[u.class].Stats.Health)
  if u.model:GetAttribute("Health")~=health then u.model:SetAttribute("Health",health) end
 end
end
local function createUnit(class, pos, owner, earned)
 uid += 1
 local model = Instance.new("Model")
 model.Name = class.."_"..uid
 local marker = Instance.new("Part",model)
 marker.Name="Root";marker.Size=Vector3.new(1,1,1);marker.Transparency=1
 marker.Anchored=true;marker.CanCollide=false;marker.CanTouch=false;marker.CanQuery=false
 model.PrimaryPart=marker
 model:SetAttribute("Class",class)
 model:SetAttribute("AttackSequence",0)
 model:SetAttribute("Health",C.Classes[class].Stats.Health)
 model:SetAttribute("MaxHealth",C.Classes[class].Stats.Health)
 local u={class=class,model=model,pos=pos,hp=C.Classes[class].Stats.Health,nextAttack=0,earned=earned or 0,owner=owner,movementState={},combatState={}}
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
  for _,u in ipairs(p.units) do if u.class==class then n+=1 end end
  player:SetAttribute(class,n)
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
local function action(player,verb)
 local p=profiles[player]
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
remote.OnServerEvent:Connect(function(player,verb) if typeof(verb)=="string" then action(player,verb) end end)
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
  local active=nil
  for _,encounter in ipairs(encounters) do if encounter.owner==player then active=encounter;break end end
  if active and ((flat(r.Position-active.pos)).Magnitude>C.NeutralSpawns.RetreatDistance or atBase(player)) then
   spawnEncounter(active);active=nil;announce(player,"Retreated — the neutral troop has reset.")
  end
  if not active and not atBase(player) and #p.units>0 then
   local best=C.NeutralSpawns.EngageDistance
   for _,encounter in ipairs(encounters) do
    if not encounter.owner and not encounter.respawn and #encounter.units>0 then
     local d=flat(r.Position-encounter.units[1].pos).Magnitude
     if d<best then active=encounter;best=d end
    end
   end
   if active then active.owner=player end
  end
  player:SetAttribute("InBattle",active~=nil)
  if active then
   Combat.update(p.units,active.units,now,dt,emitEffect)
   Combat.update(active.units,p.units,now,dt,emitEffect)
   for i=#p.units,1,-1 do
    local u=p.units[i]
    if u.hp<=0 then u.model:Destroy();table.remove(p.units,i) end
   end
   for i=#active.units,1,-1 do
    local u=active.units[i]
    if u.hp<=0 then
     table.remove(active.units,i)
     if #p.units<C.ArmyCap and #p.units>0 then
      u.hp=C.Classes[u.class].Stats.Health;u.owner=player;u.earned=C.Classes[u.class].Stats.Value;u.nextAttack=now+0.6
      Movement.reset(u);u.combatState={}
      paint(u,player);table.insert(p.units,u)
     else u.model:Destroy() end
    end
   end
   if #p.units==0 then
    spawnEncounter(active)
    player:SetAttribute("InBattle",false)
    r.CFrame=CFrame.new(0,5,12)
    equip(player);announce(player,"Army lost! Banked gold and starter upgrades are safe.")
   elseif #active.units==0 then
    active.owner=nil;active.respawn=now+C.NeutralSpawns.RespawnDelay
    player:SetAttribute("InBattle",false)
    announce(player,"Troop recruited! Bank your recruits or push farther.")
   end
  else
   local healing=atBase(player)
   local movementContext={center=r.Position,walkSpeed=humanoid.WalkSpeed}
   for _,u in ipairs(p.units) do
    u.combatState={}
    Movement.update(u,movementContext,dt)
    if healing then u.hp=C.Classes[u.class].Stats.Health end
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
