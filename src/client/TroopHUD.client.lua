local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS:WaitForChild("ArmyConfig"))
local Tiers = require(RS:WaitForChild("TroopTiers"))
local remote = RS:WaitForChild("ArmyAction")
local UI = require(script.Parent:WaitForChild("TroopUI"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("TroopHUD")
if old then old:Destroy() end
local screen = Instance.new("ScreenGui")
screen.Name = "TroopHUD"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.DisplayOrder = 10
screen.Parent = playerGui
local list = Instance.new("Frame")
list.Name = "OwnedTroopCounts"
list.AnchorPoint = Vector2.new(0, 0.5)
list.Position = UDim2.new(0, 18, 0.5, 0)
list.Size = UDim2.fromOffset(260, 0)
list.AutomaticSize = Enum.AutomaticSize.Y
list.BackgroundTransparency = 1
list.Parent = screen
local layout = Instance.new("UIListLayout", list)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
for index, class in ipairs(C.Order) do
 local row = Instance.new("Frame")
 row.Name = class
 row.Size = UDim2.fromOffset(260, 0)
 row.AutomaticSize = Enum.AutomaticSize.Y
 row.BackgroundTransparency = 1
 row.LayoutOrder = index
 row.Visible = false
 row.Parent = list
 UI.weaponIcon(row, C.Classes[class].Visual.Weapon)
 local count = UI.text(row, "Count", 32)
 count.Position = UDim2.fromOffset(64, 0)
 count.Size = UDim2.fromOffset(88, 56)
 count.TextXAlignment = Enum.TextXAlignment.Left
 local tierList = Instance.new("Frame")
 tierList.Name = "Tiers"
 tierList.Position = UDim2.fromOffset(56, 56)
 tierList.Size = UDim2.fromOffset(204, 0)
 tierList.AutomaticSize = Enum.AutomaticSize.Y
 tierList.BackgroundTransparency = 1
 tierList.Parent = row
 local tierLayout = Instance.new("UIListLayout", tierList)
 tierLayout.SortOrder = Enum.SortOrder.LayoutOrder
 tierLayout.Padding = UDim.new(0, 4)
 for tier = 1, Tiers.MaxTier do
  local tierRow = Instance.new("Frame")
  tierRow.Name = "Tier" .. tier
  tierRow.Size = UDim2.fromOffset(204, 30)
  tierRow.LayoutOrder = tier
  tierRow.BackgroundTransparency = 1
  tierRow.Visible = false
  tierRow.Parent = tierList
  local tierCount = UI.text(tierRow, "Count", 19)
  tierCount.Size = UDim2.fromOffset(94, 30)
  tierCount.TextXAlignment = Enum.TextXAlignment.Left
  local merge = UI.text(tierRow, "Merge", 17, "TextButton")
  merge.Position = UDim2.fromOffset(96, 1)
  merge.Size = UDim2.fromOffset(108, 28)
  merge.BackgroundTransparency = 0.15
  merge.BackgroundColor3 = Color3.fromRGB(55, 151, 83)
  merge.Text = "Merge → T" .. (tier + 1)
  local corner = Instance.new("UICorner", merge)
  corner.CornerRadius = UDim.new(0, 6)
  local pendingUntil = 0
  local attribute = Tiers.countAttribute(class, tier)
  local function updateTier()
   local amount = player:GetAttribute(attribute) or 0
   tierRow.Visible = amount > 0
   tierCount.Text = "T" .. tier .. "  x" .. amount
   merge.Visible = tier < Tiers.MaxTier and amount >= 2
  end
  player:GetAttributeChangedSignal(attribute):Connect(updateTier)
  merge.Activated:Connect(function()
   if os.clock() < pendingUntil then return end
   pendingUntil = os.clock() + 0.35
   remote:FireServer("Merge", class, tier)
  end)
  updateTier()
 end
 local function update()
  local amount = player:GetAttribute(class) or 0
  row.Visible = amount > 0
  count.Text = "x" .. amount
 end
 player:GetAttributeChangedSignal(class):Connect(update)
 update()
end
-- Keep an expanded tier list within smaller screens while preserving the desktop text style.
local scale = Instance.new("UIScale", list)
local cameraConnection
local function resize()
 local camera = workspace.CurrentCamera
 local height = 0
 for _, class in ipairs(C.Order) do
  if (player:GetAttribute(class) or 0) > 0 then
   height += 62
   for tier = 1, Tiers.MaxTier do
    if (player:GetAttribute(Tiers.countAttribute(class, tier)) or 0) > 0 then height += 34 end
   end
  end
 end
 if camera then scale.Scale = math.clamp((camera.ViewportSize.Y - 100) / math.max(height, 1), 0.5, 1) end
end
local function watchCamera()
 if cameraConnection then cameraConnection:Disconnect() end
 if workspace.CurrentCamera then cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
 resize()
end
for _, class in ipairs(C.Order) do
 player:GetAttributeChangedSignal(class):Connect(resize)
 for tier = 1, Tiers.MaxTier do player:GetAttributeChangedSignal(Tiers.countAttribute(class, tier)):Connect(resize) end
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
local notice = UI.text(screen, "MergeNotice", 22)
notice.AnchorPoint = Vector2.new(0.5, 1)
notice.Position = UDim2.new(0.5, 0, 1, -20)
notice.Size = UDim2.new(1, -32, 0, 60)
notice.TextWrapped = true
local noticeVersion = 0
remote.OnClientEvent:Connect(function(kind, message)
 if kind ~= "MergeResult" then return end
 noticeVersion += 1
 local version = noticeVersion
 notice.Text = message
 task.delay(3, function() if noticeVersion == version then notice.Text = "" end end)
end)
