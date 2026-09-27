-- Build each appearance once; clients clone it for individual troops.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Templates = Instance.new("Folder")
Templates.Name = "ArmyAvatars"
Templates.Parent = RS
local AvatarTemplates = {}

local function build(description, name)
 description.HeightScale = 1
 description.WidthScale = 1
 description.DepthScale = 1
 description.HeadScale = 1
 local model = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
 model.Name = name
 local humanoid = model:FindFirstChildOfClass("Humanoid")
 local root = model:FindFirstChild("HumanoidRootPart")
 model.PrimaryPart = root
 -- New avatars can use physics animation constraints. Use lightweight motor joints
 -- so a visual-only AnimationController rig needs no ragdoll simulation.
 for _,joint in ipairs(model:GetDescendants()) do
  if joint:IsA("AnimationConstraint") then
   local a,b=joint.Attachment0,joint.Attachment1
   if a and b then
    local motor=Instance.new("Motor6D")
    motor.Name=joint.Name;motor.Part0=a.Parent;motor.Part1=b.Parent
    motor.C0=a.CFrame;motor.C1=b.CFrame;motor.Parent=joint.Parent
   end
   joint:Destroy()
  elseif joint:IsA("BallSocketConstraint") or joint:IsA("NoCollisionConstraint") then joint:Destroy() end
 end
 model:ScaleTo(0.65)
 model:SetAttribute("RootHeight", humanoid.HipHeight + root.Size.Y / 2)
 for _,v in ipairs(model:GetDescendants()) do
  if v:IsA("BaseScript") or v:IsA("ModuleScript") then v:Destroy()
  elseif v:IsA("BasePart") then
   v.Anchored = v == root
   v.CanCollide, v.CanTouch, v.CanQuery, v.Massless = false, false, false, true
  end
 end
 humanoid:Destroy()
 local controller = Instance.new("AnimationController", model)
 Instance.new("Animator", controller)
 local old = Templates:FindFirstChild(name)
 if old then old:Destroy() end
 model.Parent = Templates
 return model
end
function AvatarTemplates.load(player, character)
 local ok, err = pcall(function()
  if not player:HasAppearanceLoaded() then
   local deadline = os.clock() + 8
   repeat task.wait(0.1) until player:HasAppearanceLoaded() or not player.Parent or os.clock() > deadline
  end
  if not player.Parent or character ~= player.Character then return end
  local h = character:FindFirstChildOfClass("Humanoid")
  local description = h and h:GetAppliedDescription() or Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
  local model = build(description, tostring(player.UserId))
  if not player.Parent then model:Destroy() end
 end)
 if not ok then warn("Troop avatar unavailable; using default rig: " .. tostring(err)) end
end
function AvatarTemplates.remove(player)
 local model = Templates:FindFirstChild(tostring(player.UserId))
 if model then model:Destroy() end
end
task.spawn(function()
 local d = Instance.new("HumanoidDescription")
 d.HeadColor = Color3.fromRGB(230,230,230)
 d.TorsoColor = Color3.fromRGB(230,230,230)
 d.LeftArmColor = d.TorsoColor; d.RightArmColor = d.TorsoColor
 d.LeftLegColor = d.TorsoColor; d.RightLegColor = d.TorsoColor
 for attempt=1,3 do
  local ok,err = pcall(build,d,"Default")
  if ok then d:Destroy();return end
  warn("Default troop rig load failed: "..tostring(err))
  task.wait(2)
 end
 d:Destroy()
end)
return AvatarTemplates
