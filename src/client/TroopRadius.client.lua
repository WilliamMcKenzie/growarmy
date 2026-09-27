-- Local navigation guide. The server's InBattle attribute is the combat source of truth.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local C = require(RS:WaitForChild("ArmyConfig"))
local player = Players.LocalPlayer
local ring = Instance.new("Folder")
ring.Name = "TroopNavigationRadius"
local segments = {}
local count = 48
local dashFraction = 0.55
for i = 1, count do
 local a = (i - 1) * math.pi * 2 / count
 local b = (i - 1 + dashFraction) * math.pi * 2 / count
 local start = Vector3.new(math.cos(a), 0, math.sin(a)) * C.Roaming.Radius
 local finish = Vector3.new(math.cos(b), 0, math.sin(b)) * C.Roaming.Radius
 local offset = CFrame.lookAt((start + finish) / 2, finish)
 local part = Instance.new("Part")
 part.Name = "Dash"
 part.Size = Vector3.new(0.12, 0.04, (finish - start).Magnitude)
 part.Anchored = true
 part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
 part.CastShadow = false
 part.Material = Enum.Material.SmoothPlastic
 part.Transparency = 0.5
 part.Parent = ring
 segments[i] = {part = part, offset = offset}
end

local function updateColor()
 local color = player:GetAttribute("InBattle") and Color3.fromRGB(255, 55, 55) or Color3.new(1, 1, 1)
 for _, segment in ipairs(segments) do segment.part.Color = color end
end
player:GetAttributeChangedSignal("InBattle"):Connect(updateColor)
updateColor()

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
RunService.RenderStepped:Connect(function()
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if not root or not humanoid or humanoid.Health <= 0 then
  ring.Parent = nil
  return
 end
 rayParams.FilterDescendantsInstances = {character, ring}
 local hit = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayParams)
 if not hit then ring.Parent = nil; return end
 local center = CFrame.new(root.Position.X, hit.Position.Y + 0.05, root.Position.Z)
 for _, segment in ipairs(segments) do segment.part.CFrame = center * segment.offset end
 ring.Parent = workspace
end)
