local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")
local C = require(RS:WaitForChild("ArmyConfig"))
local remote = Instance.new("RemoteEvent", RS)
remote.Name = "ArmyAction"
local fx = Instance.new("RemoteEvent", RS)
fx.Name = "ArmyEffect"
local troops = Instance.new("Folder", workspace)
troops.Name = "Troops"
local profiles, camps = {}, {}
local store = not RunService:IsStudio() and DataStoreService:GetDataStore("GrowArmyPrototype_v1") or nil
local uid = 0
local Avatars = require(script.Parent:WaitForChild("AvatarTemplates"))

local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function root(player) return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function atBase(player)
 local r = root(player)
 return r and flat(r.Position).Magnitude < C.SafeRadius
end
local function paint(u, friendly)
 u.model:SetAttribute("OwnerId", friendly and friendly.UserId or 0)
end
local function move(u, position, face)
 u.pos = position
 local target = face or position + Vector3.new(0,0,-1)
 if flat(target-position).Magnitude < 0.01 then target = position+Vector3.new(0,0,-1) end
 u.model.PrimaryPart.CFrame = CFrame.lookAt(position, Vector3.new(target.X,position.Y,target.Z))
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
 local u={class=class,model=model,pos=pos,hp=C.Classes[class].Health,nextAttack=0,earned=earned or 0,owner=owner}
 paint(u,owner);move(u,pos);model.Parent=troops
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
local function spawnCamp(camp)
 clear(camp.units)
 camp.owner=nil
 for i,class in ipairs(camp.roster) do
  local pos=camp.pos+Vector3.new(((i-1)%4-1.5)*3,0,math.floor((i-1)/4)*3)
  table.insert(camp.units,createUnit(class,pos))
 end
 camp.respawn=nil
end
if C.SpawnEnemies then
for _,p in ipairs(workspace.Map:GetChildren()) do
 local ring,index = p.Name:match("^Camp_(%d+)_(%d+)$")
 if ring then
  ring,index=tonumber(ring),tonumber(index)
  local roster={}
  local n=ring==1 and 3 or ring==2 and 7 or 12
  for i=1,n do
   roster[i]=(ring>=2 and i%5==0) and "Rocketeer" or (index%2==0 and i%3==0 or ring==3 and i%2==0) and "Archer" or "Swordsman"
  end
  local camp={pos=Vector3.new(p.Position.X,0.3,p.Position.Z),roster=roster,units={},ring=ring}
  table.insert(camps,camp)
  local board=Instance.new("BillboardGui",p)
  board.Size=UDim2.fromOffset(180,46);board.StudsOffset=Vector3.new(0,9,0);board.AlwaysOnTop=true;board.MaxDistance=110
  local text=Instance.new("TextLabel",board)
  text.Size=UDim2.fromScale(1,1);text.BackgroundColor3=Color3.fromRGB(30,35,40);text.BackgroundTransparency=0.2
  text.TextColor3=Color3.fromRGB(255,228,173);text.Font=Enum.Font.GothamBold;text.TextSize=14
  camp.label=text
  spawnCamp(camp)
 end
end
end
local function release(player)
 for _,camp in ipairs(camps) do
  if camp.owner==player then spawnCamp(camp) end
 end
end
local function action(player,verb)
 local p=profiles[player]
 if not p or not atBase(player) or os.clock()-(p.lastAction or 0)<0.5 then return end
 p.lastAction=os.clock()
 if verb=="CashIn" then
  local amount=value(p)
  if amount==0 then announce(player,"Defeat a camp first — recruited troops are worth gold.");return end
  p.gold+=amount
  release(player)
  equip(player)
  announce(player,"Banked "..amount.." gold! Your starting squad is ready.")
 elseif verb=="Upgrade" or verb=="Recruit" then
  if C.starterCount(p.starter)>=C.StarterCap then announce(player,"Prototype starter squad maxed: 12 troops.");return end
  local cost=verb=="Upgrade" and C.upgradeCost(p.starter) or C.rollCost(p.starter)
  if p.gold<cost then announce(player,"You need "..cost.." gold.");return end
  local class="Swordsman"
  if verb=="Recruit" then
   local roll=math.random(100)
   class=roll<=60 and "Swordsman" or roll<=90 and "Archer" or "Rocketeer"
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

local function nearest(u,enemies)
 local best,dist=nil,math.huge
 for _,v in ipairs(enemies) do
  if v.hp>0 then local d=(v.pos-u.pos).Magnitude;if d<dist then best,dist=v,d end end
 end
 return best,dist
end
local function stepToward(u,target,dt,face)
 local d=flat(target-u.pos)
 local pos=u.pos
 if d.Magnitude>0.1 then pos+=d.Unit*math.min(d.Magnitude,C.Classes[u.class].Speed*dt) end
 move(u,pos,face or target)
end
local function fight(units,enemies,now,dt)
 for _,u in ipairs(units) do
  if u.hp<=0 then continue end
  local target,d=nearest(u,enemies)
  if not target then continue end
  local s=C.Classes[u.class]
  if d>s.Range then stepToward(u,target.pos,dt)
  else
   move(u,u.pos,target.pos)
   if now>=u.nextAttack then
    u.nextAttack=now+s.Cooldown
    u.model:SetAttribute("AttackSequence",u.model:GetAttribute("AttackSequence")+1)
    target.hp-=s.Damage
    if s.Splash then
     for _,v in ipairs(enemies) do if v~=target and (v.pos-target.pos).Magnitude<s.Splash then v.hp-=s.Damage*0.6 end end
    end
    fx:FireAllClients(u.pos+Vector3.new(0,2,0),target.pos+Vector3.new(0,2,0),u.class)
   end
  end
 end
end
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt
 if elapsed<0.1 then return end
 dt=math.min(elapsed,0.25);elapsed=0
 local now=os.clock()
 for _,camp in ipairs(camps) do
  if camp.respawn and now>=camp.respawn then spawnCamp(camp) end
  camp.label.Text=camp.respawn and ("REFORMING • "..math.ceil(camp.respawn-now).."s") or ("TIER "..camp.ring.." • "..#camp.units.." TROOPS")
 end
 for player,p in pairs(profiles) do
  local r=root(player)
  local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if not r or not humanoid or humanoid.Health<=0 then continue end
  local active=nil
  for _,camp in ipairs(camps) do if camp.owner==player then active=camp;break end end
  if active and ((flat(r.Position-active.pos)).Magnitude>52 or atBase(player)) then
   spawnCamp(active);active=nil;announce(player,"Retreated — that camp has regrouped.")
  end
  if not active and not atBase(player) and #p.units>0 then
   local best=29
   for _,camp in ipairs(camps) do
    local d=flat(r.Position-camp.pos).Magnitude
    if not camp.owner and not camp.respawn and d<best then active=camp;best=d end
   end
   if active then active.owner=player end
  end
  player:SetAttribute("InBattle",active~=nil)
  if active then
   fight(p.units,active.units,now,dt)
   fight(active.units,p.units,now,dt)
   for i=#p.units,1,-1 do
    local u=p.units[i]
    if u.hp<=0 then u.model:Destroy();table.remove(p.units,i) end
   end
   for i=#active.units,1,-1 do
    local u=active.units[i]
    if u.hp<=0 then
     table.remove(active.units,i)
     if #p.units<C.ArmyCap and #p.units>0 then
      u.hp=C.Classes[u.class].Health;u.owner=player;u.earned=C.Classes[u.class].Value;u.nextAttack=now+0.6
      paint(u,player);table.insert(p.units,u)
     else u.model:Destroy() end
    end
   end
   if #p.units==0 then
    spawnCamp(active)
    r.CFrame=CFrame.new(0,5,12)
    equip(player);announce(player,"Army lost! Banked gold and starter upgrades are safe.")
   elseif #active.units==0 then
    active.owner=nil;active.respawn=now+35
    announce(player,"Camp captured! Recruits joined your army — bank them or push farther.")
   end
  else
   local n=0
   for _,class in ipairs(C.Order) do
    for _,u in ipairs(p.units) do
     if u.class~=class then continue end
     n+=1
     local row=math.floor((n-1)/6)
     local localPos=Vector3.new(((n-1)%6-2.5)*3,0,7+row*3)
     local target=r.CFrame:PointToWorldSpace(localPos)
     stepToward(u,Vector3.new(target.X,0.3,target.Z),dt)
     if atBase(player) then u.hp=C.Classes[u.class].Health end
    end
   end
  end
  sync(player)
 end
end)
local function joined(player)
 local data=nil
 if store then
  local ok,result=pcall(function() return store:GetAsync(tostring(player.UserId)) end)
  if not ok then player:Kick("Progress could not load. Please rejoin to protect your save.");return end
  data=result
 end
 if not player.Parent then return end
 local starter={Swordsman=4,Archer=0,Rocketeer=0}
 if type(data)=="table" and type(data.starter)=="table" then
  local remaining=C.StarterCap
  for _,class in ipairs(C.Order) do
   local n=math.clamp(math.floor(tonumber(data.starter[class]) or starter[class]),class=="Swordsman" and 4 or 0,remaining)
   starter[class]=n;remaining-=n
  end
 end
 profiles[player]={gold=type(data)=="table" and math.max(0,tonumber(data.gold) or 0) or 0,starter=starter,units={}}
 player:SetAttribute("SaveMode",store and "Progress saves" or "Studio • session-only progress")
 local function spawned(character)
  local humanoid=character:WaitForChild("Humanoid")
  character:WaitForChild("HumanoidRootPart")
  humanoid.WalkSpeed=23
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
print("Grow an Army ready: "..#camps.." camps, 3 classes, server-authoritative PvE.")
