local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local C = require(RS:WaitForChild("ArmyConfig"))
local templates = RS:WaitForChild("ArmyAvatars")
local troops = workspace:WaitForChild("Troops")
local visuals = Instance.new("Folder", workspace)
visuals.Name = "ArmyVisuals"
local states = {}
-- Roblox-owned catalog animations; aim/fire come from the official Soldier NPC kit:
-- https://create.roblox.com/store/asset/3924234975
local animations = {}
for name,id in pairs({Idle=507766666,Walk=507777826,Hold=507768375,Slash=522635514,Aim=4713633512,Fire=4713811763}) do
 local animation=Instance.new("Animation")
 animation.Name=name;animation.AnimationId="rbxassetid://"..id
 animations[name]=animation
end
local warned = {}
local function track(animator,name,priority,looped)
 local ok,t=pcall(function() return animator:LoadAnimation(animations[name]) end)
 if not ok then
  if not warned[name] then warned[name]=true;warn("Troop animation failed: "..name.." "..tostring(t)) end
  return nil
 end
 t.Priority=priority;t.Looped=looped
 return t
end
local function weapon(rig,class)
 local hand=rig:FindFirstChild(class=="Archer" and "LeftHand" or "RightHand")
 if not hand then return end
 local grip=hand:FindFirstChild(class=="Archer" and "LeftGripAttachment" or "RightGripAttachment")
 local base=hand.CFrame*(grip and grip.CFrame or CFrame.new())
 local folder=Instance.new("Model",rig);folder.Name=class.."Weapon"
 local function piece(name,size,color,offset)
  local p=Instance.new("Part")
  p.Name=name;p.Size=size;p.Color=color;p.Material=Enum.Material.SmoothPlastic
  p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true
  p.CFrame=base*offset;p.Parent=folder
  local weld=Instance.new("WeldConstraint",p);weld.Part0=hand;weld.Part1=p
  return p
 end
 if class=="Swordsman" then
  piece("Grip",Vector3.new(.18,.65,.18),Color3.fromRGB(88,57,34),CFrame.new())
  piece("Guard",Vector3.new(.8,.12,.25),Color3.fromRGB(255,195,65),CFrame.new(0,.35,0))
  piece("Blade",Vector3.new(.25,1.7,.1),Color3.fromRGB(216,237,255),CFrame.new(0,1.25,0))
 elseif class=="Archer" then
  local wood=Color3.fromRGB(139,86,41)
  piece("BowGrip",Vector3.new(.14,.7,.18),wood,CFrame.new())
  piece("UpperLimb",Vector3.new(.14,.8,.15),wood,CFrame.new(0,.65,.18)*CFrame.Angles(math.rad(28),0,0))
  piece("LowerLimb",Vector3.new(.14,.8,.15),wood,CFrame.new(0,-.65,.18)*CFrame.Angles(math.rad(-28),0,0))
  piece("String",Vector3.new(.035,2,.035),Color3.fromRGB(245,235,190),CFrame.new(0,0,.36))
  piece("Arrow",Vector3.new(.055,.055,1.6),Color3.fromRGB(218,200,145),CFrame.new(0,0,-.4))
 else
  piece("Launcher",Vector3.new(.65,.65,2),Color3.fromRGB(56,77,48),CFrame.new(0,.25,-.3))
  piece("Muzzle",Vector3.new(.8,.8,.2),Color3.fromRGB(29,35,33),CFrame.new(0,.25,-1.3))
  piece("Warhead",Vector3.new(.4,.4,.28),Color3.fromRGB(245,178,67),CFrame.new(0,.25,-1.43))
 end
end
local function dispose(state)
 for _,t in pairs(state.tracks) do t:Stop(0);t:Destroy() end
 state.rig:Destroy()
end
local function create(marker,template)
 local rig=template:Clone()
 rig.Name=marker.Name;rig.Parent=visuals
 local class=marker:GetAttribute("Class")
 weapon(rig,class)
 local animator=rig:FindFirstChildOfClass("AnimationController"):FindFirstChildOfClass("Animator")
 local tracks={
  idle=track(animator,"Idle",Enum.AnimationPriority.Idle,true),
  walk=track(animator,"Walk",Enum.AnimationPriority.Movement,true),
  hold=track(animator,class=="Swordsman" and "Hold" or "Aim",Enum.AnimationPriority.Action,true),
  attack=track(animator,class=="Swordsman" and "Slash" or "Fire",Enum.AnimationPriority.Action2,false),
 }
 if tracks.idle then tracks.idle:Play(.15) end
 if tracks.hold then tracks.hold:Play(.15) end
 -- Team marker is separate from the avatar; captured troops keep their clothing colors.
 local disk=Instance.new("Part",rig)
 disk.Name="TeamMarker";disk.Shape=Enum.PartType.Cylinder;disk.Size=Vector3.new(.06,2.3,2.3)
 disk.Anchored=true;disk.CanCollide=false;disk.CanTouch=false;disk.CanQuery=false
 disk.Material=Enum.Material.Neon;disk.Transparency=.35
 disk.Color=marker:GetAttribute("OwnerId")==0 and Color3.fromRGB(240,85,85) or Color3.fromRGB(75,165,255)
 local cf=marker.PrimaryPart.CFrame
 rig.PrimaryPart.CFrame=cf*CFrame.new(0,rig:GetAttribute("RootHeight"),0)
 return {rig=rig,template=template,owner=marker:GetAttribute("OwnerId"),tracks=tracks,disk=disk,cf=cf,lastTarget=cf.Position,lastSample=os.clock(),speed=0,attack=marker:GetAttribute("AttackSequence")}
end
RunService.RenderStepped:Connect(function(dt)
 local camera=workspace.CurrentCamera
 if not camera then return end
 local now=os.clock()
 local built=0
 for _,marker in ipairs(troops:GetChildren()) do
  local root=marker.PrimaryPart
  if not root then continue end
  local state=states[marker]
  local visible=(root.Position-camera.CFrame.Position).Magnitude<300
  if not visible then
   if state then dispose(state);states[marker]=nil end
   continue
  end
  local owner=marker:GetAttribute("OwnerId")
  local template=templates:FindFirstChild(tostring(owner)) or templates:FindFirstChild("Default")
  if state and (state.owner~=owner or state.template~=template) then dispose(state);states[marker]=nil;state=nil end
  if not state and template and built<3 then
   state=create(marker,template);states[marker]=state;built+=1
  end
  if not state then continue end
  local target=root.CFrame
  if now-state.lastSample>=.1 then
   state.speed=(target.Position-state.lastTarget).Magnitude/(now-state.lastSample)
   state.lastTarget=target.Position;state.lastSample=now
   local walk=state.tracks.walk
   if walk then
    if state.speed>.4 then
     if not walk.IsPlaying then walk:Play(.15) end
     walk:AdjustSpeed(math.clamp(state.speed/10,.5,2.5))
    elseif walk.IsPlaying then walk:Stop(.15) end
   end
  end
  local attack=marker:GetAttribute("AttackSequence")
  if attack~=state.attack then
   state.attack=attack
   if state.tracks.attack then
    state.tracks.attack:Stop(0)
    state.tracks.attack:Play(.06,1,1)
   end
  end
  state.cf=(state.cf.Position-target.Position).Magnitude>45 and target or state.cf:Lerp(target,1-math.exp(-18*dt))
  state.rig.PrimaryPart.CFrame=state.cf*CFrame.new(0,state.rig:GetAttribute("RootHeight"),0)
  state.disk.CFrame=CFrame.new(state.cf.Position+Vector3.new(0,-.16,0))*CFrame.Angles(0,0,math.pi/2)
 end
 for marker,state in pairs(states) do
  if marker.Parent~=troops then dispose(state);states[marker]=nil end
 end
end)
