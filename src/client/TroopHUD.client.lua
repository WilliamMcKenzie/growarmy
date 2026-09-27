local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS:WaitForChild("ArmyConfig"))
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
list.Size = UDim2.fromOffset(156, 0)
list.AutomaticSize = Enum.AutomaticSize.Y
list.BackgroundTransparency = 1
list.Parent = screen
local layout = Instance.new("UIListLayout", list)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
for index, class in ipairs(C.Order) do
 local row = Instance.new("Frame")
 row.Name = class
 row.Size = UDim2.fromOffset(156, 56)
 row.BackgroundTransparency = 1
 row.LayoutOrder = index
 row.Visible = false
 row.Parent = list
 UI.weaponIcon(row, C.Classes[class].Visual.Weapon)
 local count = UI.text(row, "Count", 32)
 count.Position = UDim2.fromOffset(64, 0)
 count.Size = UDim2.fromOffset(88, 56)
 count.TextXAlignment = Enum.TextXAlignment.Left
 local function update()
  local amount = player:GetAttribute(class) or 0
  row.Visible = amount > 0
  count.Text = "x" .. amount
 end
 player:GetAttributeChangedSignal(class):Connect(update)
 update()
end
