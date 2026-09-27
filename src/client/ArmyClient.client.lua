local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local StarterGui=game:GetService("StarterGui")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local player=Players.LocalPlayer
local C=require(RS:WaitForChild("ArmyConfig"))
local effect=RS:WaitForChild("ArmyEffect")
-- No game HUD while testing movement and troop visuals.
local old=player:WaitForChild("PlayerGui"):FindFirstChild("ArmyHUD")
if old then old:Destroy() end
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false)
task.spawn(function()
 for _=1,20 do
  if pcall(function() StarterGui:SetCore("TopbarEnabled",false) end) then break end
  task.wait(.25)
 end
end)
effect.OnClientEvent:Connect(function(from,to,class)
 local camera=workspace.CurrentCamera
 if (camera.CFrame.Position-from).Magnitude>180 then return end
 local beam=Instance.new("Part")
 beam.Anchored=true;beam.CanCollide=false;beam.CanTouch=false;beam.CanQuery=false;beam.Material=Enum.Material.Neon
 beam.Color=C.Classes[class].Color
 local distance=(to-from).Magnitude
 beam.Size=Vector3.new(class=="Rocketeer" and 0.5 or 0.15,0.15,math.max(0.1,distance))
 beam.CFrame=CFrame.lookAt((from+to)/2,to);beam.Parent=workspace
 TweenService:Create(beam,TweenInfo.new(0.16),{Transparency=1}):Play();Debris:AddItem(beam,0.2)
 if class=="Rocketeer" then
  local blast=Instance.new("Part");blast.Shape=Enum.PartType.Ball;blast.Size=Vector3.new(1,1,1);blast.Position=to
  blast.Color=C.Classes[class].Color;blast.Anchored=true;blast.CanCollide=false;blast.CanTouch=false;blast.CanQuery=false;blast.Material=Enum.Material.Neon;blast.Transparency=0.4;blast.Parent=workspace
  TweenService:Create(blast,TweenInfo.new(0.3),{Size=Vector3.new(12,12,12),Transparency=1}):Play();Debris:AddItem(blast,0.35)
 end
end)
player.CameraMinZoomDistance=35
player.CameraMaxZoomDistance=85
local function cameraSetup()
 task.wait(0.3)
 local r=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if r then workspace.CurrentCamera.CFrame=CFrame.lookAt(r.Position+Vector3.new(0,48,42),r.Position) end
end
player.CharacterAdded:Connect(cameraSetup)
if player.Character then task.spawn(cameraSetup) end
