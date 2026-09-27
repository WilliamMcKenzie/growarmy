-- Minimal horizontal-movement/marker doubles, not a replacement for Studio tests.
local Vector3 = {}
local vectorMeta = {}
function Vector3.new(x, y, z) return setmetatable({X=x, Y=y, Z=z}, vectorMeta) end
function vectorMeta.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vectorMeta.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vectorMeta.__mul(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
function vectorMeta.__index(v,key)
 if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if key=="Unit" then return v*(1/v.Magnitude) end
 error("Unexpected vector property: "..key)
end
local CFrame = {lookAt=function(position,target) return {Position=position,Target=target} end}
function CFrame.new(x,y,z)
 return {Position=type(x)=="table" and x or Vector3.new(x or 0,y or 0,z or 0)}
end
local Color3 = {fromRGB=function(r,g,b) return {r,g,b} end}
function Color3.new(r,g,b) return {r,g,b} end
local UDim2={fromScale=function(x,y) return {X=x,Y=y} end}
local Enum={Material={SmoothPlastic="SmoothPlastic"},SurfaceType={Smooth="Smooth"},MeshType={Head="Head"}}
local Instance={}
local instanceMethods={}
function instanceMethods:SetAttribute(key,value) self.attributes[key]=value end
function instanceMethods:GetAttribute(key) return self.attributes[key] end
function instanceMethods:GetDescendants()
 local result={}
 local function visit(node)
  for _,child in ipairs(node.children) do table.insert(result,child);visit(child) end
 end
 visit(self)
 return result
end
function instanceMethods:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
function instanceMethods:FindFirstChild(name)
 for _,child in ipairs(self.children) do if child.Name==name then return child end end
end
function Instance.new(class,parent)
 local object=setmetatable({ClassName=class,children={},attributes={}}, {
  __index=function(self,key)
   if key=="Parent" then return rawget(self,"_parent") end
   return instanceMethods[key]
  end,
  __newindex=function(self,key,value)
   if key=="Parent" then
    rawset(self,"_parent",value)
    if value then table.insert(value.children,self) end
   else rawset(self,key,value) end
  end,
 })
 object.Parent=parent
 return object
end
local Random = {}
function Random.new(seed)
 local state=seed or 314159
 return {NextNumber=function(_,low,high)
  state=(state*16807)%2147483647
  low=low or 0;high=high or 1
  return low+(high-low)*(state/2147483647)
 end}
end
local modules = {}
local function require(name) return assert(modules[name],"Missing module: "..name) end
local container={WaitForChild=function(_,name) return name end}
local script={Parent=container}
local game={GetService=function() return container end}
