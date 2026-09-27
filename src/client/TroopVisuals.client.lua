local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local C = require(RS:WaitForChild("ArmyConfig"))
local Weapons = require(script.Parent:WaitForChild("TroopWeapons"))
local templates = RS:WaitForChild("ArmyAvatars")
local troops = workspace:WaitForChild("Troops")
local visuals = Instance.new("Folder", workspace)
visuals.Name = "ArmyVisuals"
local states = {}
-- Roblox-owned catalog animations; aim/fire come from the official Soldier NPC kit:
-- https://create.roblox.com/store/asset/3924234975
local animations = {}
local warned = {}
local function track(animator,id,priority,looped)
 if not id then return nil end
 if not animations[id] then
  local animation=Instance.new("Animation")
  animation.AnimationId="rbxassetid://"..id
  animations[id]=animation
 end
 local ok,t=pcall(function() return animator:LoadAnimation(animations[id]) end)
 if not ok then
  if not warned[id] then warned[id]=true;warn("Troop animation failed: "..id.." "..tostring(t)) end
  return nil
 end
 t.Priority=priority;t.Looped=looped
 return t
end
local function dispose(state)
 for _,t in pairs(state.tracks) do t:Stop(0);t:Destroy() end
 state.rig:Destroy()
end
local function create(marker,template)
 local rig=template:Clone()
 rig.Name=marker.Name
 local class=marker:GetAttribute("Class")
 local appearance=C.Classes[class].Visual
 Weapons.attach(rig,appearance.Weapon)
 rig:ScaleTo(rig:GetScale()*appearance.Scale)
 rig:SetAttribute("RootHeight",template:GetAttribute("RootHeight")*appearance.Scale)
 rig.Parent=visuals
 local animator=rig:FindFirstChildOfClass("AnimationController"):FindFirstChildOfClass("Animator")
 local tracks={
  idle=track(animator,appearance.Animations.Idle,Enum.AnimationPriority.Idle,true),
  walk=track(animator,appearance.Animations.Walk,Enum.AnimationPriority.Movement,true),
  hold=track(animator,appearance.Animations.Hold,Enum.AnimationPriority.Action,true),
  attack=track(animator,appearance.Animations.Attack,Enum.AnimationPriority.Action2,false),
 }
 if tracks.idle then tracks.idle:Play(.15) end
 if tracks.hold then tracks.hold:Play(.15) end
 local cf=marker.PrimaryPart.CFrame
 rig.PrimaryPart.CFrame=cf*CFrame.new(0,rig:GetAttribute("RootHeight"),0)
 return {rig=rig,template=template,class=class,owner=marker:GetAttribute("OwnerId"),tracks=tracks,cf=cf,lastTarget=cf.Position,lastSample=os.clock(),speed=0,attack=marker:GetAttribute("AttackSequence")}
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
  if state and (state.owner~=owner or state.template~=template or state.class~=marker:GetAttribute("Class")) then dispose(state);states[marker]=nil;state=nil end
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
     walk:AdjustSpeed(math.clamp(state.speed/(10*state.rig:GetScale()),.5,2.5))
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
 end
 for marker,state in pairs(states) do
  if marker.Parent~=troops then dispose(state);states[marker]=nil end
 end
end)
