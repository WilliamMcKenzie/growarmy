-- A local, asset-free classic R6 body: no face, clothing, accessories, or account lookup.
local NeutralAvatar = {}
function NeutralAvatar.build()
 local rig = Instance.new("Model")
 rig.Name = "Neutral"
 rig:SetAttribute("RigType", "R6")
 rig:SetAttribute("RootHeight", 3)
 local function part(name, size, position)
  local p = Instance.new("Part")
  p.Name = name; p.Size = size; p.CFrame = CFrame.new(position)
  p.Color = Color3.new(1, 1, 1); p.Material = Enum.Material.SmoothPlastic
  p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
  p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.Massless = true
  p.Parent = rig
  return p
 end
 local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
 root.Anchored = true; root.Transparency = 1; rig.PrimaryPart = root
 local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
 local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0))
 local mesh = Instance.new("SpecialMesh", head)
 mesh.MeshType = Enum.MeshType.Head; mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
 local leftArm = part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0))
 local rightArm = part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0))
 local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0))
 local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0))
 local function joint(name, parent, child, c0, c1)
  local motor = Instance.new("Motor6D")
  motor.Name = name; motor.Part0 = parent; motor.Part1 = child
  motor.C0 = c0; motor.C1 = c1; motor.Parent = parent
 end
 joint("RootJoint", root, torso, CFrame.new(), CFrame.new())
 joint("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
 joint("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
 joint("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
 joint("Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
 joint("Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))
 for _, entry in ipairs({{leftArm, "LeftGripAttachment"}, {rightArm, "RightGripAttachment"}}) do
  local grip = Instance.new("Attachment")
  grip.Name = entry[2]; grip.CFrame = CFrame.new(0, -1, 0); grip.Parent = entry[1]
 end
 return rig
end
return NeutralAvatar
