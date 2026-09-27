-- Reusable weapon builders selected by Visual.Weapon, independent of troop type.
local Weapons = {}
Weapons.Builders = {
 Sword = {
  Hand = "RightHand", Grip = "RightGripAttachment",
  Build = function(piece)
   piece("Grip",Vector3.new(.18,.65,.18),Color3.fromRGB(88,57,34),CFrame.new())
   piece("Guard",Vector3.new(.8,.12,.25),Color3.fromRGB(255,195,65),CFrame.new(0,.35,0))
   piece("Blade",Vector3.new(.25,1.7,.1),Color3.fromRGB(216,237,255),CFrame.new(0,1.25,0))
  end,
 },
 Bow = {
  Hand = "LeftHand", Grip = "LeftGripAttachment",
  Build = function(piece)
   local wood=Color3.fromRGB(139,86,41)
   piece("BowGrip",Vector3.new(.14,.7,.18),wood,CFrame.new())
   piece("UpperLimb",Vector3.new(.14,.8,.15),wood,CFrame.new(0,.65,.18)*CFrame.Angles(math.rad(28),0,0))
   piece("LowerLimb",Vector3.new(.14,.8,.15),wood,CFrame.new(0,-.65,.18)*CFrame.Angles(math.rad(-28),0,0))
   piece("String",Vector3.new(.035,2,.035),Color3.fromRGB(245,235,190),CFrame.new(0,0,.36))
   piece("Arrow",Vector3.new(.055,.055,1.6),Color3.fromRGB(218,200,145),CFrame.new(0,0,-.4))
  end,
 },
 Club = {
  Hand = "RightHand", Grip = "RightGripAttachment",
  Build = function(piece)
   piece("Handle",Vector3.new(.3,1.1,.3),Color3.fromRGB(104,69,39),CFrame.new(0,.15,0))
   piece("Head",Vector3.new(.85,1,.85),Color3.fromRGB(116,91,64),CFrame.new(0,1.1,0))
   piece("Band",Vector3.new(.9,.18,.9),Color3.fromRGB(92,99,106),CFrame.new(0,1.35,0))
  end,
 },
}

function Weapons.attach(rig, name)
 if not name then return end
 local builder=assert(Weapons.Builders[name],"Unknown weapon: "..name)
 local hand=rig:FindFirstChild(builder.Hand)
 if not hand and rig:GetAttribute("RigType")=="R6" then
  hand=rig:FindFirstChild(builder.Hand=="LeftHand" and "Left Arm" or "Right Arm")
 end
 if not hand then return end
 local grip=hand:FindFirstChild(builder.Grip)
 local base=hand.CFrame*(grip and grip.CFrame or CFrame.new())
 local folder=Instance.new("Model",rig);folder.Name=name
 local scale=rig:GetScale()
 builder.Build(function(partName,size,color,offset)
  local p=Instance.new("Part")
  p.Name=partName;p.Size=size*scale;p.Color=color;p.Material=Enum.Material.SmoothPlastic
  p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true
  p.CFrame=base*(CFrame.new(offset.Position*scale)*offset.Rotation);p.Parent=folder
  local weld=Instance.new("WeldConstraint",p);weld.Part0=hand;weld.Part1=p
 end)
end

return Weapons
