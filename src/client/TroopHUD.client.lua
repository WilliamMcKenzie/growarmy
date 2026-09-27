local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local C = require(RS:WaitForChild("ArmyConfig"))
local Tiers = require(RS:WaitForChild("TroopTiers"))
local UI = require(script.Parent:WaitForChild("TroopUI"))
local Layout = require(script.Parent:WaitForChild("TroopInventoryLayout"))
local remote = RS:WaitForChild("ArmyAction")
local troops = workspace:WaitForChild("Troops")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("TroopHUD")
if old then old:Destroy() end
local screen = Instance.new("ScreenGui")
screen.Name = "TroopHUD"
screen.ResetOnSpawn = false
-- Use screen coordinates for drag hit-testing; pad the root with the safe GUI insets below.
screen.ScreenInsets = Enum.ScreenInsets.None
screen.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
screen.DisplayOrder = 10
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui
local root = Instance.new("Frame", screen)
root.Name = "SafeArea"; root.BackgroundTransparency = 1
local inventory = Instance.new("ScrollingFrame", root)
inventory.Name = "TroopInventory"
inventory.AnchorPoint = Vector2.new(0.5, 1)
inventory.Position = UDim2.new(0.5, 0, 1, -20)
inventory.BackgroundTransparency = 1
inventory.BorderSizePixel = 0
inventory.ScrollBarThickness = 4
inventory.ScrollBarImageColor3 = Color3.fromRGB(220, 226, 240)
inventory.ScrollingDirection = Enum.ScrollingDirection.Y
inventory.ElasticBehavior = Enum.ElasticBehavior.Never
inventory.ClipsDescendants = true
inventory.Active = true
local notice = UI.text(root, "MergeNotice", 20)
notice.AnchorPoint = Vector2.new(0.5, 1)
notice.Size = UDim2.new(1, -24, 0, 44)
notice.TextWrapped = true
local noticeVersion = 0
local function showNotice(message)
 noticeVersion += 1
 local version = noticeVersion
 notice.Text = message
 task.delay(3, function() if noticeVersion == version then notice.Text = "" end end)
end
local entries, watched, ordered = {}, {}, {}
local drag, pending, metrics
local requestUntil = 0
local function tierColor(tier)
 if tier == 1 then return Color3.fromRGB(195, 207, 221) end
 if tier == 2 then return Color3.fromRGB(101, 183, 255) end
 if tier == 3 then return Color3.fromRGB(255, 204, 86) end
 return Color3.fromHSV((tier * 0.17) % 1, 0.65, 1)
end
local function pointer(input)
 if input.UserInputType == Enum.UserInputType.Touch then return Vector2.new(input.Position.X, input.Position.Y) end
 return Input:GetMouseLocation()
end
local function contains(gui, point)
 local p, size = gui.AbsolutePosition, gui.AbsoluteSize
 return point.X >= p.X and point.Y >= p.Y and point.X <= p.X + size.X and point.Y <= p.Y + size.Y
end
local function targetAt(point)
 if not contains(inventory, point) then return nil end
 for _, entry in ipairs(ordered) do
  if (not drag or entry ~= drag.entry) and contains(entry.button, point) then return entry end
 end
end
local function highlight(target)
 for _, entry in ipairs(ordered) do
  if entries[entry.marker] ~= entry then continue end
  local compatible = drag and Layout.canMerge(drag.entry, entry, Tiers.MaxTier)
  entry.border.Color = compatible and Color3.fromRGB(106, 245, 151) or tierColor(entry.tier)
  entry.border.Thickness = compatible and 3 or 2
  entry.button.BackgroundTransparency = drag and entry == drag.entry and 0.8 or 0.25
 end
 if drag and target and not Layout.canMerge(drag.entry, target, Tiers.MaxTier) then
  target.border.Color = Color3.fromRGB(255, 100, 100)
 end
end
local function cancelDrag()
 pending = nil
 if drag then drag.ghost:Destroy(); drag = nil end
 inventory.ScrollingEnabled = true
 highlight(nil)
end
local function startDrag(entry, input)
 if entries[entry.marker] ~= entry then return end
 if entry.tier >= Tiers.MaxTier then showNotice("This troop is already at the highest tier."); pending = nil; return end
 if os.clock() < requestUntil then pending = nil; return end
 local ghost = Instance.new("Frame", screen)
 ghost.Name = "DraggedTroop"
 ghost.AnchorPoint = Vector2.new(0.5, 0.5)
 ghost.Size = UDim2.fromOffset(metrics.cell, metrics.cell)
 ghost.BackgroundColor3 = Color3.fromRGB(34, 40, 51)
 ghost.BackgroundTransparency = 0.15
 ghost.BorderSizePixel = 0; ghost.ZIndex = 20
 local corner = Instance.new("UICorner", ghost); corner.CornerRadius = UDim.new(0, 9)
 local border = Instance.new("UIStroke", ghost); border.Color = tierColor(entry.tier); border.Thickness = 2
 local icon = UI.weaponIcon(ghost, C.Classes[entry.class].Visual.Weapon)
 icon.Size = UDim2.fromScale(1, 1)
 icon.ZIndex = 21
 local point = pointer(input)
 ghost.Position = UDim2.fromOffset(point.X, point.Y)
 drag = {entry = entry, input = input, ghost = ghost, point = point}
 pending = nil
 inventory.ScrollingEnabled = false
 highlight(targetAt(point))
end
local function begin(entry, input)
 if drag or pending then return end
 if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
 pending = {entry = entry, input = input, origin = pointer(input)}
 if input.UserInputType == Enum.UserInputType.Touch then
  -- Quick swipes scroll; holding an icon briefly starts a drag.
  local candidate = pending
  task.delay(0.18, function() if pending == candidate then startDrag(entry, input) end end)
 end
end
local function createEntry(marker, class, tier)
 local button = Instance.new("ImageButton", inventory)
 button.Name = marker.Name
 button.Image = ""; button.AutoButtonColor = false
 button.BackgroundColor3 = Color3.fromRGB(34, 40, 51)
 button.BackgroundTransparency = 0.25; button.BorderSizePixel = 0
 local corner = Instance.new("UICorner", button); corner.CornerRadius = UDim.new(0, 9)
 local border = Instance.new("UIStroke", button)
 border.Color = tierColor(tier); border.Thickness = 2
 local icon = UI.weaponIcon(button, C.Classes[class].Visual.Weapon)
 icon.Position = UDim2.fromOffset(3, 3)
 icon.Size = UDim2.new(1, -6, 1, -6)
 icon.Active = false
 local entry = {marker = marker, class = class, tier = tier, button = button, border = border}
 button.InputBegan:Connect(function(input) begin(entry, input) end)
 return entry
end
local function arrange()
 local previous = metrics
 local bottomDistance = previous and math.max(0, previous.contentHeight - previous.viewHeight - inventory.CanvasPosition.Y) or 0
 metrics = Layout.metrics(#ordered, math.max(1, root.AbsoluteSize.X - 40), math.max(54, math.floor(root.AbsoluteSize.Y * 0.45)))
 inventory.Size = UDim2.fromOffset(metrics.width, metrics.viewHeight)
 inventory.CanvasSize = UDim2.fromOffset(metrics.width, metrics.contentHeight)
 inventory.Visible = #ordered > 0
 for index, entry in ipairs(ordered) do
  local x, y = Layout.position(index, metrics)
  entry.button.Position = UDim2.fromOffset(x, y)
  entry.button.Size = UDim2.fromOffset(metrics.cell, metrics.cell)
 end
 inventory.CanvasPosition = Vector2.new(0, math.max(0, metrics.contentHeight - metrics.viewHeight - bottomDistance))
 notice.Position = UDim2.new(0.5, 0, 1, -metrics.viewHeight - 28)
end
local function reconcile()
 local changed = false
 for marker in pairs(watched) do
  local class, tier = marker:GetAttribute("Class"), marker:GetAttribute("Tier") or 1
  local owned = marker.Parent == troops and marker:GetAttribute("OwnerId") == player.UserId
   and C.Classes[class] ~= nil and Tiers.isValid(tier) and (marker:GetAttribute("Health") or 0) > 0
  local entry = entries[marker]
  if entry and (not owned or entry.class ~= class or entry.tier ~= tier) then
   if (drag and drag.entry == entry) or (pending and pending.entry == entry) then cancelDrag() end
   entry.button:Destroy(); entries[marker] = nil; entry = nil; changed = true
  end
  if owned and not entry then entries[marker] = createEntry(marker, class, tier); changed = true end
 end
 if changed then
  -- Do not let a roster reflow turn an in-flight drag into a drop on a different troop.
  cancelDrag()
  ordered = {}
  for _, entry in pairs(entries) do table.insert(ordered, entry) end
  table.sort(ordered, function(a, b)
   return (tonumber(a.marker.Name:match("_(%d+)$")) or 0) < (tonumber(b.marker.Name:match("_(%d+)$")) or 0)
  end)
  arrange()
 end
end
local queued = false
local function queueReconcile()
 if queued then return end
 queued = true
 task.defer(function() queued = false; reconcile() end)
end
local function watch(marker)
 if not marker:IsA("Model") or watched[marker] then return end
 local connections = {}
 for _, attribute in ipairs({"OwnerId", "Class", "Tier", "Health"}) do
  table.insert(connections, marker:GetAttributeChangedSignal(attribute):Connect(queueReconcile))
 end
 watched[marker] = connections
 queueReconcile()
end
troops.ChildAdded:Connect(watch)
troops.ChildRemoved:Connect(function(marker)
 local connections = watched[marker]
 if not connections then return end
 -- Reconcile once while still watched so its inventory entry is removed too.
 reconcile()
 for _, connection in ipairs(connections) do connection:Disconnect() end
 watched[marker] = nil
end)
for _, marker in ipairs(troops:GetChildren()) do watch(marker) end
Input.InputChanged:Connect(function(input)
 local current = drag or pending
 if not current then return end
 local touch = current.input.UserInputType == Enum.UserInputType.Touch
 if touch and input ~= current.input then return end
 if not touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
 local point = pointer(input)
 if pending then
  if (point - pending.origin).Magnitude < 6 then return end
  if touch then pending = nil; return end
  startDrag(pending.entry, pending.input)
 end
 if drag then
  drag.point = point
  drag.ghost.Position = UDim2.fromOffset(point.X, point.Y)
  highlight(targetAt(point))
 end
end)
Input.InputEnded:Connect(function(input)
 local current = drag or pending
 if not current then return end
 local touch = current.input.UserInputType == Enum.UserInputType.Touch
 if touch and input ~= current.input then return end
 if not touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
 if not drag then pending = nil; return end
 local source, target = drag.entry, targetAt(pointer(input))
 cancelDrag()
 if not target then return end
 if not Layout.canMerge(source, target, Tiers.MaxTier) then showNotice("Match the same troop type and tier."); return end
 requestUntil = os.clock() + 0.35
 remote:FireServer("Merge", source.marker, target.marker)
end)
Input.WindowFocusReleased:Connect(cancelDrag)
Input.InputBegan:Connect(function(input) if input.KeyCode == Enum.KeyCode.Escape then cancelDrag() end end)
RunService.RenderStepped:Connect(function(dt)
 if not drag or not metrics or not contains(inventory, drag.point) then return end
 -- Auto-scroll near the viewport edges to reach matching icons in any row.
 local top = inventory.AbsolutePosition.Y
 local bottom = top + inventory.AbsoluteSize.Y
 local direction = drag.point.Y < top + 22 and -1 or drag.point.Y > bottom - 22 and 1 or 0
 local limit = math.max(0, metrics.contentHeight - metrics.viewHeight)
 inventory.CanvasPosition = Vector2.new(0, math.clamp(inventory.CanvasPosition.Y + direction * 220 * dt, 0, limit))
 highlight(targetAt(drag.point))
end)
local cameraConnection
local function resize()
 cancelDrag()
 local camera = workspace.CurrentCamera
 if not camera then return end
 local topLeft, bottomRight = GuiService:GetGuiInset()
 root.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
 root.Size = UDim2.fromOffset(camera.ViewportSize.X - topLeft.X - bottomRight.X, camera.ViewportSize.Y - topLeft.Y - bottomRight.Y)
 arrange()
end
local function watchCamera()
 if cameraConnection then cameraConnection:Disconnect() end
 if workspace.CurrentCamera then cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
 resize()
end
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(resize)
watchCamera()
remote.OnClientEvent:Connect(function(kind, message) if kind == "MergeResult" then showNotice(message) end end)
