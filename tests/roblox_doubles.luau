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
local Color3 = {fromRGB=function(r,g,b) return {r,g,b} end}
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
