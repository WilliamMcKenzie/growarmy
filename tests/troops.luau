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
test("archer retreats when crowded and faces enemy while firing",function()
 local u,target=unit("Archer"),unit("Giant",10)
 fight(u,target)
 close(u.pos.X,-2.1)
 close(target.hp,168)
 close(u.model.PrimaryPart.CFrame.Target.X,target.pos.X)
end)
test("archer approaches distant target and settles at exact range",function()
 local u,target=unit("Archer"),unit("Giant",40)
 fight(u,target)
 close(u.pos.X,2.1)
 close(target.hp,180)
 for i=2,10 do fight(u,target,i*0.1) end
 close((target.pos-u.pos).Magnitude,32)
 close(target.hp,168)
 local before=u.pos
 fight(u,target,1.01)
 close((u.pos-before).Magnitude,0)
 target.pos+=Vector3.new(1,0,0)
 fight(u,target,1.02)
 close((target.pos-u.pos).Magnitude,32)
 target.pos-=Vector3.new(1,0,0)
 fight(u,target,1.03)
 close((target.pos-u.pos).Magnitude,32)
end)
test("archer handles overlapping enemies and sub-stud range corrections",function()
 local u,target=unit("Archer"),unit("Giant")
 fight(u,target)
 close(u.pos.X,2.1)
 u.pos=Vector3.new(-32.05,0.3,0)
 u.nextAttack=0
 local before=target.hp
 fight(u,target)
 close((target.pos-u.pos).Magnitude,32)
 close(target.hp,before-12)
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
print("Passed "..passed.." troop tests")
