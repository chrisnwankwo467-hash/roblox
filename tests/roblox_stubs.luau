-- Deliberately small construction doubles for standalone Luau tests.
-- CFrames retain translation only: these tests do NOT validate rendering,
-- orientation, physics, animation, Roblox property permissions, or live services.
local function vector(x, y, z)
    return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, {
        __add = function(a, b) return vector(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end,
        __sub = function(a, b) return vector(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end,
        __mul = function(a, b)
            if type(a) == "number" then return vector(a*b.X, a*b.Y, a*b.Z) end
            if type(b) == "number" then return vector(a.X*b, a.Y*b, a.Z*b) end
            return vector(a.X*b.X, a.Y*b.Y, a.Z*b.Z)
        end,
        __index = function(v, key)
            if key == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
        end,
    })
end
local Vector3 = {new = vector, one = vector(1,1,1), zero = vector()}
local function cf(x, y, z)
    local pos = type(x) == "table" and x or vector(x,y,z)
    return setmetatable({Position = pos}, {
        __mul = function(a,b) return cf(a.Position+b.Position) end,
    })
end
local CFrame = {new = cf, identity = cf(), Angles = function() return cf() end}
local function color(r,g,b)
    return {R=r, G=g, B=b, Lerp = function(a,other,t)
        return color(a.R+(other.R-a.R)*t, a.G+(other.G-a.G)*t, a.B+(other.B-a.B)*t)
    end}
end
local Color3 = {fromRGB=function(r,g,b)return color(r/255,g/255,b/255)end,new=color}
local function tuple(...) return {...} end
local ColorSequence = {new=tuple}
local NumberSequence = {new=tuple}
local NumberRange = {new=tuple}
local Vector2 = {new=tuple}
local UDim = {new=tuple}
local UDim2 = {new=tuple,fromScale=tuple,fromOffset=tuple}
local Enum = setmetatable({}, {__index = function(t,key)
    local enum = setmetatable({}, {__index=function(_,value)return key.."."..value end})
    rawset(t,key,enum)
    return enum
end})
local methods = {}
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants()
    local result = {}
    local function visit(object)
        for _,child in object.children do table.insert(result,child);visit(child) end
    end
    visit(self)
    return result
end
function methods:IsA(class)
    return self.ClassName == class or class == "BasePart" and (self.ClassName == "Part" or self.ClassName == "SpawnLocation")
end
function methods:FindFirstChild(name)
    for _,child in self.children do if child.Name == name then return child end end
end
function methods:SetAttribute(key,value) self.attributes[key]=value end
function methods:GetAttribute(key) return self.attributes[key] end
function methods:Destroy()
    for _,child in self:GetChildren() do child:Destroy() end
    self.Parent = nil
end
function methods:PivotTo(transform) self.pivot=transform end
local Instance = {new=function(class)
    return setmetatable({ClassName=class,children={},attributes={},values={Name=class,CFrame=cf()}}, {
        __index=function(self,key)
            if methods[key] then return methods[key] end
            if key == "Position" then return self.values.CFrame.Position end
            return self.values[key]
        end,
        __newindex=function(self,key,value)
            if key == "Parent" then
                local old = self.values.Parent
                if old then
                    local index=table.find(old.children,self)
                    if index then table.remove(old.children,index) end
                end
                if value then table.insert(value.children,self) end
            end
            self.values[key]=value
        end,
    })
end}
local workspace = Instance.new("Workspace")
local lighting = Instance.new("Lighting")
local game = {GetService=function(_,name)
    assert(name == "Lighting", "Unexpected service: "..name)
    return lighting
end}
