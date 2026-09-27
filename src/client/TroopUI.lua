local RS = game:GetService("ReplicatedStorage")
local C = require(RS:WaitForChild("ArmyConfig"))
local Weapons = require(script.Parent:WaitForChild("TroopWeapons"))
local UI = {}

function UI.text(parent, name, size)
 local label = Instance.new("TextLabel")
 label.Name = name
 label.BackgroundTransparency = 1
 label.BorderSizePixel = 0
 label.Font = Enum.Font.FredokaOne
 label.TextSize = size
 label.TextColor3 = Color3.new(1, 1, 1)
 label.TextStrokeTransparency = 1
 label.Text = ""
 local outline = Instance.new("UIStroke")
 outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
 outline.Thickness = 4
 outline.Color = Color3.new(0, 0, 0)
 outline.LineJoinMode = Enum.LineJoinMode.Round
 outline.Parent = label
 label.Parent = parent
 return label
end

-- Render the same weapon used by the troop as an icon; no uploaded icon assets required.
function UI.weaponIcon(parent, weaponName)
 local viewport = Instance.new("ViewportFrame")
 viewport.Name = "WeaponIcon"
 viewport.BackgroundTransparency = 1
 viewport.Size = UDim2.fromOffset(56, 56)
 viewport.Ambient = Color3.new(1, 1, 1)
 viewport.LightColor = Color3.new(1, 1, 1)
 viewport.LightDirection = Vector3.new(-1, -1, -1)
 viewport.Parent = parent
 local world = Instance.new("WorldModel", viewport)
 local rig = Instance.new("Model", world)
 local hand = Instance.new("Part")
 hand.Name = Weapons.Builders[weaponName].Hand
 hand.Size = Vector3.new(0.01, 0.01, 0.01)
 hand.Transparency = 1; hand.Anchored = true; hand.CanCollide = false
 hand.CFrame = CFrame.new(); hand.Parent = rig; rig.PrimaryPart = hand
 Weapons.attach(rig, weaponName)
 local bounds, size = rig:GetBoundingBox()
 local camera = Instance.new("Camera")
 camera.FieldOfView = 30
 local distance = math.max(size.X, size.Y, size.Z) * 0.7 / math.tan(math.rad(15))
 camera.CFrame = CFrame.lookAt(bounds.Position + Vector3.new(0.2, 0.1, 1).Unit * distance, bounds.Position)
 camera.Parent = viewport; viewport.CurrentCamera = camera
 return viewport
end

function UI.createTag(rig, class)
 local head = rig:FindFirstChild("Head")
 if not head then return nil end
 local tag = Instance.new("BillboardGui")
 tag.Name = "TroopNameplate"
 tag.Adornee = head
 tag.Size = UDim2.fromOffset(160, 70)
 tag.SizeOffset = Vector2.new(0, 0.5)
 tag.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + 0.3, 0)
 tag.ClipsDescendants = false
 tag.AlwaysOnTop = true
 tag.MaxDistance = 140
 tag.LightInfluence = 0
 tag.Parent = rig
 local title = UI.text(tag, "Title", 23)
 title.Size = UDim2.new(1, 0, 0, 30)
 title.Position = UDim2.fromOffset(0, 3)
 title.Text = C.Classes[class].DisplayName or class
 local bar = Instance.new("Frame")
 bar.Name = "HealthBar"
 bar.AnchorPoint = Vector2.new(0.5, 0.5)
 bar.Position = UDim2.new(0.5, 0, 0, 48)
 bar.Size = UDim2.fromOffset(124, 8)
 bar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
 bar.BorderSizePixel = 0
 bar.Parent = tag
 local border = Instance.new("UIStroke", bar)
 border.Color = Color3.new(0, 0, 0); border.Thickness = 2
 local fill = Instance.new("Frame")
 fill.Name = "Fill"
 fill.Size = UDim2.fromScale(1, 1)
 fill.BorderSizePixel = 0
 fill.BackgroundColor3 = Color3.fromRGB(104, 232, 117)
 fill.Parent = bar
 local health = UI.text(tag, "Health", 25)
 health.AnchorPoint = Vector2.new(0.5, 0.5)
 health.Position = UDim2.new(0.5, 0, 0, 48)
 health.Size = UDim2.fromOffset(152, 34)
 health.ZIndex = 3
 return {gui = tag, fill = fill, health = health}
end

function UI.updateTag(tag, marker)
 if not tag then return end
 local maximum = marker:GetAttribute("MaxHealth") or 1
 local health = math.clamp(marker:GetAttribute("Health") or maximum, 0, maximum)
 if tag.lastHealth == health and tag.lastMaximum == maximum then return end
 tag.lastHealth = health; tag.lastMaximum = maximum
 local ratio = maximum > 0 and health / maximum or 0
 tag.fill.Size = UDim2.fromScale(ratio, 1)
 tag.fill.BackgroundColor3 = ratio > 0.5 and Color3.fromRGB(104, 232, 117)
  or ratio > 0.25 and Color3.fromRGB(255, 199, 73) or Color3.fromRGB(255, 82, 82)
 tag.health.Text = tostring(math.ceil(health)) .. " / " .. tostring(math.ceil(maximum))
end

return UI
