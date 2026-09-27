local C=modules.ArmyConfig
local Movement=modules.TroopMovement
local Combat=modules.TroopCombat
local passed=0
local function test(name,fn)
 fn();passed+=1;print("PASS "..name)
end
local function close(a,b)
 assert(math.abs(a-b)<0.00001,"Expected "..tostring(b)..", got "..tostring(a))
end
local function unit(class,x,z)
 local attrs={AttackSequence=0}
 return {
  class=class,pos=Vector3.new(x or 0,0.3,z or 0),hp=C.Classes[class].Stats.Health,
  nextAttack=0,movementState={},combatState={},
  model={PrimaryPart={},GetAttribute=function(_,key) return attrs[key] end,
   SetAttribute=function(_,key,value) attrs[key]=value end},
 }
end
local function fight(u,target,now,dt)
 Combat.update({u},{target},now or 0,dt or 0.1,function() end)
end

test("catalog handlers and weapons resolve; sizes and speed ordering",function()
 for _,class in ipairs(C.Order) do
  local def=C.Classes[class]
  assert(Movement.Behaviors[def.Movement.Behavior])
  assert(Combat.Behaviors[def.Combat.Behavior])
  assert(modules.TroopWeapons.Builders[def.Visual.Weapon])
  assert(def.Stats.Health>0 and def.Stats.Cooldown>0 and def.Stats.Range>0)
 end
 close(C.Classes.Swordsman.Visual.Scale,0.8)
 close(C.Classes.Archer.Visual.Scale,0.8)
 close(C.Classes.Giant.Visual.Scale,1.2)
 assert(C.Classes.Swordsman.Movement.CombatSpeed>C.Classes.Archer.Movement.CombatSpeed)
 assert(C.Classes.Archer.Movement.CombatSpeed>C.Classes.Giant.Movement.CombatSpeed)
end)
test("fresh mixed starter and legacy recruit migration",function()
 local fresh=C.restoreStarter(nil)
 assert(fresh.Swordsman==2 and fresh.Archer==1 and fresh.Giant==1)
 local old=C.restoreStarter({Swordsman=4,Archer=2,Rocketeer=3})
 assert(old.Swordsman==4 and old.Archer==2 and old.Giant==3 and old.Rocketeer==nil)
 assert(C.starterCount(old)==9)
 local roundtrip=C.restoreStarter(old)
 assert(roundtrip.Giant==3 and C.starterCount(roundtrip)==9)
end)
test("saved counts respect caps and invalid values",function()
 assert(C.starterCount(C.restoreStarter({Swordsman=100,Giant=100}))==C.StarterCap)
 assert(C.starterCount(C.restoreStarter({Swordsman=0/0,Archer=-5,Giant="invalid"}))==C.BaseStarterCount)
 assert(C.starterCount(C.restoreStarter({Swordsman=4,Unknown=100}))==4)
end)
test("weighted recruitment boundaries and camp eligibility",function()
 for _,case in ipairs({{0,"Swordsman"},{0.599,"Swordsman"},{0.6,"Archer"},{0.9,"Giant"},{1,"Giant"}}) do
  assert(C.rollClass({NextNumber=function() return case[1] end})==case[2])
 end
 local random=Random.new(123)
 for _=1,1000 do assert(C.rollClass(random,1)~="Giant") end
end)
test("every type matches changing master speeds while returning",function()
 for _,class in ipairs(C.Order) do
  local u=unit(class,100)
  for _,speed in ipairs({23,11,35,0}) do
   local before=u.pos
   Movement.update(u,{center=Vector3.new(0,8,0),walkSpeed=speed},0.1)
   close((u.pos-before).Magnitude,speed*0.1)
   close(u.pos.Y,0.3)
   assert(u.movementState.returning)
  end
 end
end)
test("return stays latched inside radius and resumes wandering on arrival",function()
 local u=unit("Giant",19)
 local context={center=Vector3.new(0,0.3,0),walkSpeed=23}
 Movement.update(u,context,0.1)
 u.pos=Vector3.new(17,0.3,0)
 u.movementState.target=Vector3.new(0,0.3,0)
 Movement.update(u,context,0.1)
 close(u.pos.X,14.7)
 assert(u.movementState.returning)
 u.pos=u.movementState.target
 Movement.update(u,context,0.1)
 assert(not u.movementState.returning)
 assert(u.movementState.speed>=3.2 and u.movementState.speed<=4.8)
end)
test("AFK wandering stays in radius and picks fresh destinations",function()
 local u=unit("Swordsman")
 local context={center=Vector3.new(0,0.3,0),walkSpeed=23}
 local previous,changes=nil,0
 for _=1,1000 do
  Movement.update(u,context,0.1)
  local target=u.movementState.target
  assert((target-context.center).Magnitude<=C.Roaming.Radius)
  assert((u.pos-context.center).Magnitude<=C.Roaming.Radius)
  if target~=previous then changes+=1;previous=target end
 end
 assert(changes>10)
end)
test("moving master invalidates destinations without vertical drift",function()
 local u=unit("Archer")
 Movement.update(u,{center=Vector3.new(0,0.3,0),walkSpeed=23},0.1)
 local previous=u.movementState.target
 Movement.update(u,{center=Vector3.new(100,20,0),walkSpeed=23},0.1)
 assert(u.movementState.target~=previous)
 assert((u.movementState.target-Vector3.new(100,0.3,0)).Magnitude<=C.Roaming.Radius)
 assert(u.movementState.returning)
 close(u.pos.Y,0.3)
end)
test("swordsman and giant charge straight ahead without attacking out of range",function()
 for _,class in ipairs({"Swordsman","Giant"}) do
  local u,target=unit(class),unit("Swordsman",50)
  local hp=target.hp
  fight(u,target)
  close(u.pos.X,C.Classes[class].Movement.CombatSpeed*0.1)
  close(u.pos.Z,0)
  assert(target.hp==hp)
 end
end)
test("melee closes fractional range gaps and respects cooldown",function()
 local u,target=unit("Swordsman"),unit("Giant",6.05)
 fight(u,target,0)
 close((target.pos-u.pos).Magnitude,6)
 close(target.hp,165)
 fight(u,target,0.1)
 close(target.hp,165)
 fight(u,target,0.75)
 close(target.hp,150)
 assert(u.model:GetAttribute("AttackSequence")==2)
end)
test("archer retreats at running speed without aiming or firing",function()
 local u,target=unit("Archer"),unit("Giant",10)
 fight(u,target)
 close(u.pos.X,-2.1)
 close(target.hp,180)
 assert(u.model:GetAttribute("CombatMode")=="Retreat")
 assert(u.model.PrimaryPart.CFrame.Target.X<u.pos.X)
 assert(u.model:GetAttribute("AttackSequence")==0)
end)
test("archer holds position while drawing and only fires after the draw completes",function()
 local u,target=unit("Archer"),unit("Giant",30)
 fight(u,target,0)
 close(u.pos.X,0)
 assert(u.model:GetAttribute("CombatMode")=="Aim")
 close(target.hp,180)
 fight(u,target,0.6)
 close(target.hp,180)
 fight(u,target,0.7)
 close(target.hp,168)
 assert(u.model:GetAttribute("CombatMode")=="Recover")
 fight(u,target,0.8)
 close(target.hp,168)
end)
test("archer approaches distant targets before drawing at exact range",function()
 local u,target=unit("Archer"),unit("Giant",40)
 fight(u,target)
 close(u.pos.X,2.1)
 assert(u.model:GetAttribute("CombatMode")=="Advance")
 for i=2,4 do fight(u,target,i*0.1) end
 close((target.pos-u.pos).Magnitude,32)
 close(target.hp,180)
 for i=5,12 do fight(u,target,i*0.1) end
 close(target.hp,168)
 close((target.pos-u.pos).Magnitude,32)
end)
test("danger cancels drawing and retreat stops inside the comfortable band",function()
 local u,target=unit("Archer"),unit("Giant",32)
 fight(u,target,0)
 target.pos=Vector3.new(20,0.3,0)
 fight(u,target,0.7)
 assert(u.model:GetAttribute("CombatMode")=="Retreat")
 close(target.hp,180)
 assert(u.combatState.aimTarget==nil)
 -- At the lower edge of the two-stud band, stop running and start a fresh draw.
 u.pos=Vector3.new(-10,0.3,0)
 fight(u,target,0.8)
 close(u.pos.X,-10)
 assert(u.model:GetAttribute("CombatMode")=="Aim")
 fight(u,target,0.9)
 assert(u.model:GetAttribute("CombatMode")=="Aim")
 close(target.hp,180)
 fight(u,target,1.6)
 close(target.hp,168)
end)
test("archer handles overlapping targets and sub-stud range corrections",function()
 local u,target=unit("Archer"),unit("Giant")
 fight(u,target)
 close(u.pos.X,2.1)
 u.pos=Vector3.new(-32.05,0.3,0)
 fight(u,target,0.1)
 close((target.pos-u.pos).Magnitude,32)
 close(target.hp,180)
end)
test("archer changes to closest enemy and restarts drawing",function()
 local u,first,closer=unit("Archer"),unit("Giant",32),unit("Giant",31)
 fight(u,first,0)
 Combat.update({u},{first,closer},0.6,0.1,function() end)
 assert(u.combatState.aimTarget==closer)
 Combat.update({u},{first,closer},0.8,0.1,function() end)
 close(first.hp,180);close(closer.hp,180)
 Combat.update({u},{first,closer},1.3,0.1,function() end)
 close(first.hp,180);close(closer.hp,168)
end)
test("two-stud attack band tolerates target movement without repositioning",function()
 local u,target=unit("Archer"),unit("Giant",32)
 for i,distance in ipairs({32,31,30,31.5,30.5}) do
  target.pos=Vector3.new(distance,0.3,0)
  fight(u,target,i*0.1)
  close(u.pos.X,0)
  assert(u.model:GetAttribute("CombatMode")=="Aim")
 end
 target.pos=Vector3.new(29.9,0.3,0)
 fight(u,target,0.6)
 assert(u.model:GetAttribute("CombatMode")=="Retreat")
 assert(u.pos.X<0)
 u.pos=Vector3.new(0,0.3,0)
 target.pos=Vector3.new(32.1,0.3,0)
 fight(u,target,0.7)
 assert(u.model:GetAttribute("CombatMode")=="Advance")
 close(u.pos.X,0.1)
 close(target.hp,180)
end)
test("faster swordsman closes distance on a kiting archer",function()
 local swordsman,archer=unit("Swordsman"),unit("Archer",32)
 -- Isolate pursuit speed from damage by giving both ample HP.
 swordsman.hp=10000;archer.hp=10000
 local initial=(archer.pos-swordsman.pos).Magnitude
 for i=1,20 do
  fight(swordsman,archer,i*0.1)
  fight(archer,swordsman,i*0.1)
 end
 assert((archer.pos-swordsman.pos).Magnitude<initial)
end)
test("combat discards wandering destination and ignores dead targets",function()
 local u,dead,alive=unit("Swordsman"),unit("Archer",2),unit("Archer",20)
 dead.hp=0
 u.movementState={returning=true,target=Vector3.new(-30,0.3,0)}
 Combat.update({u},{dead,alive},0,0.1,function() end)
 assert(u.movementState.target==nil and u.pos.X>0 and dead.hp==0)
 local before=u.pos
 u.hp=0
 fight(u,alive,1)
 close((u.pos-before).Magnitude,0)
end)
test("new encounters join an existing fight and each troop attacks its nearest enemy",function()
 local player={}
 local archer,sword=unit("Archer",65),unit("Swordsman",85)
 local first={owner=player,pos=archer.pos,units={archer}}
 local second={pos=sword.pos,units={sword}}
 local active,enemies=modules.BattleEncounters.update(player,Vector3.new(70,0.3,0),true,{first,second},function() error("Unexpected retreat") end)
 assert(#active==2 and #enemies==2 and second.owner==player)
 local left,right=unit("Swordsman",60),unit("Swordsman",90)
 Combat.update({left,right},enemies,0,0.1,function() end)
 close(archer.hp,27);close(sword.hp,60)
 -- Reposition the second target: the left troop switches without waiting for its old target to die.
 sword.pos=Vector3.new(61,0.3,0)
 Combat.update({left},enemies,1,0.1,function() end)
 close(archer.hp,27);close(sword.hp,45)
end)
test("encounters belonging to another player and distant idle neutrals stay out of combat",function()
 local player,other={},{}
 local owned={owner=other,pos=Vector3.new(80,0.3,0),units={unit("Archer",80)}}
 local near={pos=Vector3.new(85,0.3,0),units={unit("Swordsman",85)}}
 local far={pos=Vector3.new(200,0.3,0),units={unit("Giant",200)}}
 local active,enemies=modules.BattleEncounters.update(player,Vector3.new(75,0.3,0),true,{owned,near,far},function() error("Unexpected retreat") end)
 assert(#active==1 and #enemies==1 and enemies[1]==near.units[1])
 assert(owned.owner==other and near.owner==player and far.owner==nil)
end)
test("retreat releases distant encounters while retaining nearby enemies",function()
 local player={}
 local far={owner=player,pos=Vector3.new(60,0.3,0),units={unit("Archer",60)}}
 local near={owner=player,pos=Vector3.new(120,0.3,0),units={unit("Swordsman",120)}}
 local reset=0
 local active,enemies,retreated=modules.BattleEncounters.update(player,Vector3.new(125,0.3,0),true,{far,near},function(encounter)
  reset+=1;encounter.owner=nil;encounter.units={};encounter.respawn=35
 end)
 assert(reset==1 and retreated and #active==1 and #enemies==1 and near.owner==player)
 assert(far.owner==nil and far.respawn==35)
end)
test("returning to safety releases every active encounter",function()
 local player={}
 local encounters={
  {owner=player,pos=Vector3.new(60,0.3,0),units={unit("Archer",60)}},
  {owner=player,pos=Vector3.new(70,0.3,0),units={unit("Swordsman",70)}},
 }
 local reset=0
 local active,enemies=modules.BattleEncounters.update(player,Vector3.new(0,0.3,0),false,encounters,function(encounter)
  reset+=1;encounter.owner=nil;encounter.units={};encounter.respawn=35
 end)
 assert(reset==2 and #active==0 and #enemies==0)
end)
test("neutral population is scattered across the field, clear of base and players",function()
 local Spawns=modules.NeutralSpawns
 local field={Position=Vector3.new(0,-1,0),Size=Vector3.new(600,2,600)}
 local random=Random.new(421)
 local encounters={}
 local players={Vector3.new(100,0.3,100),Vector3.new(-100,0.3,-100)}
 local quadrants={}
 for _=1,C.NeutralSpawns.Population do
  local encounter={units={}}
  table.insert(encounters,encounter)
  assert(Spawns.populate(encounter,random,field,encounters,players,0,function(class,pos)
   local troop=unit(class,pos.X,pos.Z)
   assert(troop.owner==nil)
   return troop
  end))
  assert(#encounter.units==1 and encounter.respawn==nil)
  local pos=encounter.pos
  close(pos.Y,0.3)
  assert(math.abs(pos.X)<=276 and math.abs(pos.Z)<=276)
  assert(Vector3.new(pos.X,0,pos.Z).Magnitude>=C.SafeRadius+C.Roaming.Radius+6)
  quadrants[(pos.X>0 and "east" or "west")..(pos.Z>0 and "north" or "south")]=true
  for _,other in ipairs(encounters) do
   if other~=encounter then assert((other.pos-pos).Magnitude>=C.NeutralSpawns.MinSpacing) end
  end
  for _,player in ipairs(players) do assert((player-pos).Magnitude>=C.NeutralSpawns.PlayerClearance) end
 end
 local count=0
 for _ in pairs(quadrants) do count+=1 end
 assert(count==4)
end)
test("blocked neutral spawns retry without producing an unsafe troop",function()
 local encounter={units={}}
 local field={Position=Vector3.new(0,-1,0),Size=Vector3.new(40,2,40)}
 local created=0
 assert(not modules.NeutralSpawns.populate(encounter,Random.new(),field,{encounter},{},10,function()
  created+=1
 end))
 assert(created==0 and #encounter.units==0)
 assert(encounter.respawn==10+C.NeutralSpawns.RetryDelay)
end)
test("neutral respawn uses a fresh position and resets its deadline",function()
 local encounter={units={},pos=Vector3.new(100,0.3,100),respawn=35}
 local field={Position=Vector3.new(0,-1,0),Size=Vector3.new(600,2,600)}
 local previous=encounter.pos
 assert(modules.NeutralSpawns.populate(encounter,Random.new(),field,{encounter},{previous},35,function(class,pos)
  return unit(class,pos.X,pos.Z)
 end))
 assert((encounter.pos-previous).Magnitude>=C.NeutralSpawns.PlayerClearance)
 assert(encounter.respawn==nil and #encounter.units==1)
end)
test("blank neutral template has six white body parts, no face or clothes, and grounded R6 joints",function()
 local rig=modules.NeutralAvatar.build()
 assert(rig:GetAttribute("RigType")=="R6")
 assert(rig.PrimaryPart.Name=="HumanoidRootPart" and rig.PrimaryPart.Anchored)
 local parts,joints=0,0
 for _,object in ipairs(rig:GetDescendants()) do
  assert(object.ClassName~="Decal" and object.ClassName~="Texture" and object.ClassName~="Shirt")
  assert(object.ClassName~="Pants" and object.ClassName~="Accessory")
  if object:IsA("BasePart") and object~=rig.PrimaryPart then
   parts+=1
   assert(object.Color[1]==1 and object.Color[2]==1 and object.Color[3]==1)
   assert(not object.CanCollide and not object.CanQuery)
  elseif object:IsA("Motor6D") then
   joints+=1
   assert(object.Part0 and object.Part1)
   local from=object.Part0.CFrame.Position+object.C0.Position
   local to=object.Part1.CFrame.Position+object.C1.Position
   close((from-to).Magnitude,0)
  end
 end
 assert(parts==6 and joints==6)
 local leg=rig:FindFirstChild("Left Leg")
 close(leg.CFrame.Position.Y-leg.Size.Y/2,0)
 close(rig.PrimaryPart.CFrame.Position.Y,rig:GetAttribute("RootHeight"))
end)
test("health overlay follows replicated damage, healing, and empty health",function()
 local attrs={Health=75,MaxHealth=75}
 local marker={GetAttribute=function(_,key) return attrs[key] end}
 local tag={fill={},health={}}
 modules.TroopUI.updateTag(tag,marker)
 assert(tag.health.Text=="75 / 75");close(tag.fill.Size.X,1)
 attrs.Health=30
 modules.TroopUI.updateTag(tag,marker)
 assert(tag.health.Text=="30 / 75");close(tag.fill.Size.X,0.4)
 attrs.Health=75
 modules.TroopUI.updateTag(tag,marker)
 close(tag.fill.Size.X,1)
 attrs.Health=-10
 modules.TroopUI.updateTag(tag,marker)
 assert(tag.health.Text=="0 / 75");close(tag.fill.Size.X,0)
end)
print("Passed "..passed.." troop tests")
