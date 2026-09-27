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
  class=class,tier=1,pos=Vector3.new(x or 0,0.3,z or 0),hp=C.Classes[class].Stats.Health,
  nextAttack=0,movementState={},combatState={},
  model={PrimaryPart={},GetAttribute=function(_,key) return attrs[key] end,
   SetAttribute=function(_,key,value) attrs[key]=value end,Destroy=function(self) self.destroyed=true end},
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
 close(C.Classes.Archer.Movement.CombatSpeed,10.5)
 close(C.Classes.Archer.Movement.WanderMultiplier,0.475)
 close(C.Classes.Archer.Movement.ReturnSpeedMultiplier,0.5)
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
test("return speeds follow the live master speed with the Archer slowdown",function()
 for _,class in ipairs(C.Order) do
  local u=unit(class,100)
  for _,speed in ipairs({23,11,35,0}) do
   local before=u.pos
   Movement.update(u,{center=Vector3.new(0,8,0),walkSpeed=speed},0.1)
   close((u.pos-before).Magnitude,speed*0.1*(class=="Archer" and 0.5 or 1))
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
 close(u.pos.X,-1.05)
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
 close(u.pos.X,1.05)
 assert(u.model:GetAttribute("CombatMode")=="Advance")
 for i=2,8 do fight(u,target,i*0.1) end
 close((target.pos-u.pos).Magnitude,32)
 close(target.hp,180)
 for i=9,16 do fight(u,target,i*0.1) end
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
 close(u.pos.X,1.05)
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
local Tiers=modules.TroopTiers
local Merge=modules.TroopMerge
local function owned(class,tier,owner)
 local troop=unit(class)
 troop.tier=tier;troop.owner=owner;troop.earned=0
 troop.hp=Tiers.stats(class,tier).Health
 return troop
end
test("tier scaling improves health and damage and grows by 1.2 each rank",function()
 for _,class in ipairs(C.Order) do
  for tier=2,Tiers.MaxTier do
   local previous,current=Tiers.stats(class,tier-1),Tiers.stats(class,tier)
   assert(current.Health>previous.Health and current.Damage>previous.Damage)
   close(Tiers.scale(class,tier)/Tiers.scale(class,tier-1),1.2)
   close(current.Range,previous.Range);close(current.Cooldown,previous.Cooldown)
  end
 end
 close(Tiers.scale("Swordsman",3),1.152)
 close(Tiers.scale("Giant",3),1.728)
end)
test("merge consumes exactly two owned matches and preserves injury and cash value",function()
 local owner={}
 local first,second,other=owned("Swordsman",1,owner),owned("Swordsman",1,owner),owned("Archer",1,owner)
 first.hp=75;second.hp=37.5
 first.earned=0;second.earned=12
 first.nextAttack=4;second.nextAttack=7
 first.combatState={aimTarget=other};first.movementState={returning=true}
 local units={first,other,second}
 local merged=Merge.apply(units,owner,"Swordsman",1,1)
 assert(merged==first and #units==2 and units[2]==other)
 assert(first.tier==2 and second.model.destroyed and second.hp==0)
 close(first.hp,Tiers.stats("Swordsman",2).Health*0.75)
 close(first.earned,12);close(first.nextAttack,7)
 assert(first.combatState.aimTarget==nil and first.movementState.returning==nil)
 assert(first.model:GetAttribute("Tier")==2 and first.model:GetAttribute("CombatMode")=="Idle")
 close(first.model:GetAttribute("MaxHealth"),165)
 close(first.model:GetAttribute("Health"),first.hp)
end)
test("four tier-one troops merge through two ranks without minting gold",function()
 local owner={}
 local units={}
 for _=1,4 do table.insert(units,owned("Swordsman",1,owner)) end
 assert(Merge.apply(units,owner,"Swordsman",1,0))
 assert(Merge.apply(units,owner,"Swordsman",1,0))
 assert(Merge.apply(units,owner,"Swordsman",2,0))
 assert(#units==1 and units[1].tier==3 and units[1].earned==0)
 close(units[1].hp,Tiers.stats("Swordsman",3).Health)
end)
test("merge rejects mismatches, dead troops, foreign owners, and invalid tier requests",function()
 local owner,other={},{}
 local first=owned("Swordsman",1,owner)
 local dead=owned("Swordsman",1,owner);dead.hp=0
 local units={first,owned("Swordsman",1,other),owned("Archer",1,owner),owned("Swordsman",2,owner),dead}
 assert(not Merge.apply(units,owner,"Swordsman",1,0))
 assert(not Merge.apply(units,owner,"Archer",1,0))
 for _,tier in ipairs({0,-1,1.5,4,math.huge,0/0,"1",{}}) do
  assert(not Merge.apply(units,owner,"Swordsman",tier,0))
 end
 assert(not Merge.apply(units,owner,"Unknown",1,0))
 assert(not Merge.apply(units,owner,{},1,0))
 assert(not Merge.apply(units,owner,"Swordsman",nil,0))
 assert(#units==5 and first.tier==1 and not first.model.destroyed)
end)
test("top tier is capped and increasing MaxTier enables the next merge",function()
 local owner={}
 local units={owned("Giant",3,owner),owned("Giant",3,owner)}
 assert(not Merge.apply(units,owner,"Giant",3,0))
 local previousCap=Tiers.MaxTier
 Tiers.MaxTier=4
 local merged=Merge.apply(units,owner,"Giant",3,0)
 assert(merged and merged.tier==4 and #units==1)
 close(Tiers.scale("Giant",4)/Tiers.scale("Giant",3),1.2)
 assert(merged.hp>Tiers.stats("Giant",3).Health)
 Tiers.MaxTier=previousCap
end)
test("tiered melee and archer attacks use improved damage with unchanged behaviours",function()
 for _,class in ipairs({"Swordsman","Archer"}) do
  local troop=owned(class,2,{})
  local enemy=unit("Giant",class=="Archer" and 31 or 5)
  fight(troop,enemy,0)
  if class=="Archer" then
   assert(troop.model:GetAttribute("CombatMode")=="Aim")
   close(enemy.hp,180)
   fight(troop,enemy,0.7)
  end
  close(enemy.hp,180-Tiers.stats(class,2).Damage)
 end
end)
test("Archer wandering is half its previous speed at every tier",function()
 for tier=1,Tiers.MaxTier do
  local troop=owned("Archer",tier,{})
  Movement.update(troop,{center=Vector3.new(0,0.3,0),walkSpeed=23},0.1)
  assert(troop.movementState.speed>=1.9 and troop.movementState.speed<=2.85)
 end
end)
test("drag merge upgrades the exact destination and consumes only the selected source",function()
 local owner={}
 local untouched,source,target=owned("Swordsman",1,owner),owned("Swordsman",1,owner),owned("Swordsman",1,owner)
 source.hp=30;target.hp=60;source.earned=12;target.earned=24
 local units={untouched,source,target}
 local result=Merge.applyPair(units,owner,source.model,target.model,2)
 assert(result==target and #units==2 and units[1]==untouched and units[2]==target)
 assert(untouched.tier==1 and target.tier==2 and source.model.destroyed)
 close(target.hp,Tiers.stats("Swordsman",2).Health*0.6)
 close(target.earned,36)
 assert(not Merge.applyPair(units,owner,source.model,untouched.model,3))
 assert(#units==2 and untouched.tier==1)
end)
test("drag merge rejects forged, dead, foreign, mismatched, self, and maximum-tier targets",function()
 local owner,other={},{}
 local source,target=owned("Swordsman",1,owner),owned("Swordsman",1,owner)
 local foreign=owned("Swordsman",1,other)
 local archer=owned("Archer",1,owner)
 local higher=owned("Swordsman",2,owner)
 local dead=owned("Swordsman",1,owner);dead.hp=0
 local topA,topB=owned("Giant",Tiers.MaxTier,owner),owned("Giant",Tiers.MaxTier,owner)
 local units={source,target,foreign,archer,higher,dead,topA,topB}
 for _,model in ipairs({{},"Swordsman",2,source.model,foreign.model,archer.model,higher.model,dead.model}) do
  assert(not Merge.applyPair(units,owner,source.model,model,0))
 end
 assert(not Merge.applyPair(units,owner,nil,target.model,0))
 assert(not Merge.applyPair(units,owner,topA.model,topB.model,0))
 assert(#units==8 and source.tier==1 and target.tier==1)
end)
test("inventory wraps after eight icons and grows upward",function()
 local Layout=modules.TroopInventoryLayout
 local eight=Layout.metrics(8,600,500)
 assert(eight.rows==1)
 local x1,y1=Layout.position(1,eight)
 local x8,y8=Layout.position(8,eight)
 close(y1,y8);assert(x8>x1)
 local nine=Layout.metrics(9,600,500)
 local x9,y9=Layout.position(9,nine)
 local firstX,firstY=Layout.position(1,nine)
 close(x9,firstX);assert(y9<firstY and nine.rows==2)
 local seventeen=Layout.metrics(17,600,500)
 local _,top=Layout.position(17,seventeen)
 local _,middle=Layout.position(9,seventeen)
 local _,bottom=Layout.position(1,seventeen)
 assert(top<middle and middle<bottom and seventeen.rows==3)
end)
test("inventory has no row cap and scrolls instead of hiding large rosters",function()
 local Layout=modules.TroopInventoryLayout
 local empty=Layout.metrics(0,350,200)
 assert(empty.rows==0 and empty.contentHeight==0)
 local metrics=Layout.metrics(4097,350,200)
 assert(metrics.rows==513 and metrics.width<=350 and metrics.viewHeight<=200)
 assert(metrics.contentHeight>metrics.viewHeight)
 local occupied={}
 for index=1,4097 do
  local x,y=Layout.position(index,metrics)
  assert(x>=0 and x+metrics.cell<=metrics.width)
  assert(y>=0 and y+metrics.cell<=metrics.contentHeight)
  local key=tostring(x)..":"..tostring(y)
  assert(not occupied[key]);occupied[key]=true
 end
end)
test("inventory highlights only matching non-max-tier pairs",function()
 local Layout=modules.TroopInventoryLayout
 local a={class="Archer",tier=1}
 assert(Layout.canMerge(a,{class="Archer",tier=1},Tiers.MaxTier))
 assert(not Layout.canMerge(a,a,Tiers.MaxTier))
 assert(not Layout.canMerge(a,{class="Archer",tier=2},Tiers.MaxTier))
 assert(not Layout.canMerge(a,{class="Swordsman",tier=1},Tiers.MaxTier))
 assert(not Layout.canMerge({class="Archer",tier=3},{class="Archer",tier=3},3))
end)
print("Passed "..passed.." troop tests")
