-- Construction doubles for standalone Luau tests and edit-time map export.
-- CFrames use complete rigid transforms. Physics, rendering, property permissions,
-- animation, asynchronous services and Roblox engine behavior are not simulated.
local vectorMethods = {}
local function vector(x, y, z)
    return setmetatable({__type="Vector3", X=x or 0, Y=y or 0, Z=z or 0}, {
        __add=function(a,b)return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end,
        __sub=function(a,b)return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end,
        __unm=function(a)return vector(-a.X,-a.Y,-a.Z)end,
        __mul=function(a,b)
            if type(a)=="number" then return vector(a*b.X,a*b.Y,a*b.Z) end
            if type(b)=="number" then return vector(a.X*b,a.Y*b,a.Z*b) end
            return vector(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
        end,
        __div=function(a,b)return vector(a.X/b,a.Y/b,a.Z/b)end,
        __index=function(v,key)
            if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
            if key=="Unit" then local n=math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z);return vector(v.X/n,v.Y/n,v.Z/n) end
            return vectorMethods[key]
        end,
    })
end
function vectorMethods:Dot(b)return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function vectorMethods:Cross(b)return vector(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X)end
function vectorMethods:Lerp(b,t)return self+(b-self)*t end
local Vector3={new=vector,one=vector(1,1,1),zero=vector(),xAxis=vector(1,0,0),yAxis=vector(0,1,0),zAxis=vector(0,0,1)}
local identityMatrix={1,0,0,0,1,0,0,0,1}
local function multiplyMatrix(a,b)
    local out={}
    for row=0,2 do for col=0,2 do
        out[row*3+col+1]=a[row*3+1]*b[col+1]+a[row*3+2]*b[col+4]+a[row*3+3]*b[col+7]
    end end
    return out
end
local function rotate(m,v)return vector(m[1]*v.X+m[2]*v.Y+m[3]*v.Z,m[4]*v.X+m[5]*v.Y+m[6]*v.Z,m[7]*v.X+m[8]*v.Y+m[9]*v.Z)end
local cframeMethods={}
local frame
frame=function(position,matrix)
    local m=matrix or identityMatrix
    local p=position or vector()
    return setmetatable({__type="CFrame",Position=p,matrix=m}, {
        __mul=function(a,b)
            if b.__type=="Vector3" then return a.Position+rotate(a.matrix,b) end
            return frame(a.Position+rotate(a.matrix,b.Position),multiplyMatrix(a.matrix,b.matrix))
        end,
        __add=function(a,b)return frame(a.Position+b,a.matrix)end,
        __sub=function(a,b)return frame(a.Position-b,a.matrix)end,
        __index=function(a,key)
            if key=="Rotation" then return frame(vector(),a.matrix) end
            if key=="X" then return a.Position.X elseif key=="Y" then return a.Position.Y elseif key=="Z" then return a.Position.Z end
            if key=="RightVector" then return rotate(a.matrix,Vector3.xAxis) end
            if key=="UpVector" then return rotate(a.matrix,Vector3.yAxis) end
            if key=="LookVector" then return -rotate(a.matrix,Vector3.zAxis) end
            return cframeMethods[key]
        end,
    })
end
function cframeMethods:Inverse()
    local a=self.matrix
    local transpose={a[1],a[4],a[7],a[2],a[5],a[8],a[3],a[6],a[9]}
    return frame(rotate(transpose,-self.Position),transpose)
end
function cframeMethods:ToObjectSpace(other)return self:Inverse()*other end
function cframeMethods:ToWorldSpace(other)return self*other end
function cframeMethods:PointToObjectSpace(point)return self:Inverse()*point end
function cframeMethods:PointToWorldSpace(point)return self*point end
function cframeMethods:VectorToObjectSpace(value)return rotate(self:Inverse().matrix,value)end
function cframeMethods:VectorToWorldSpace(value)return rotate(self.matrix,value)end
function cframeMethods:GetComponents()return self.Position.X,self.Position.Y,self.Position.Z,table.unpack(self.matrix)end
local CFrame={}
function CFrame.new(x,y,z,...)
    if type(x)=="table" then return frame(x) end
    local extra={...}
    return frame(vector(x,y,z),#extra==9 and extra or nil)
end
function CFrame.Angles(x,y,z)
    local sx,cx,sy,cy,sz,cz=math.sin(x),math.cos(x),math.sin(y),math.cos(y),math.sin(z),math.cos(z)
    return frame(vector(),multiplyMatrix(multiplyMatrix({1,0,0,0,cx,-sx,0,sx,cx},{cy,0,sy,0,1,0,-sy,0,cy}),{cz,-sz,0,sz,cz,0,0,0,1}))
end
function CFrame.fromMatrix(pos,right,up,back)
    back=back or right:Cross(up)
    return frame(pos,{right.X,up.X,back.X,right.Y,up.Y,back.Y,right.Z,up.Z,back.Z})
end
function CFrame.lookAt(pos,target,up)
    local delta=pos-target
    if delta.Magnitude<1e-10 then return frame(pos) end
    local back=delta.Unit
    up=up or Vector3.yAxis
    -- Vertical beams have no unique roll. Select a perpendicular fallback axis,
    -- preserving a finite orthonormal frame just as the engine constructor does.
    if math.abs(up:Dot(back))>0.999999 then up=Vector3.zAxis end
    local right=up:Cross(back).Unit
    return CFrame.fromMatrix(pos,right,back:Cross(right),back)
end
CFrame.identity=frame()
local function color(r,g,b)
    return {__type="Color3",R=r,G=g,B=b,Lerp=function(a,other,t)
        return color(a.R+(other.R-a.R)*t,a.G+(other.G-a.G)*t,a.B+(other.B-a.B)*t)
    end}
end
local Color3={fromRGB=function(r,g,b)return color(r/255,g/255,b/255)end,new=color}
local NumberRange={new=function(low,high)return {__type="NumberRange",Min=low,Max=high or low}end}
local ColorSequenceKeypoint={new=function(t,value)return {Time=t,Value=value}end}
local NumberSequenceKeypoint={new=function(t,value,envelope)return {Time=t,Value=value,Envelope=envelope or 0}end}
local function sequence(kind,a,b)
    if type(a)=="table" and a[1] then return {__type=kind,Keypoints=a} end
    return {__type=kind,Keypoints={{Time=0,Value=a,Envelope=kind=="NumberSequence" and 0 or nil},{Time=1,Value=b or a,Envelope=kind=="NumberSequence" and 0 or nil}}}
end
local ColorSequence={new=function(a,b)return sequence("ColorSequence",a,b)end}
local NumberSequence={new=function(a,b)return sequence("NumberSequence",a,b)end}
local Vector2={new=function(x,y)return {__type="Vector2",X=x or 0,Y=y or 0}end}
local UDim={new=function(scale,offset)return {__type="UDim",Scale=scale or 0,Offset=offset or 0}end}
local UDim2={new=function(xs,xo,ys,yo)return {__type="UDim2",X=UDim.new(xs,xo),Y=UDim.new(ys,yo)}end}
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
local Enum=setmetatable({}, {__index=function(t,key)
    local enum=setmetatable({}, {__index=function(e,value)
        local item={__type="EnumItem",enum=key,name=value}
        rawset(e,value,item)
        return item
    end})
    rawset(t,key,enum)
    return enum
end})
local methods={}
function methods:GetChildren()return table.clone(self.children)end
function methods:GetDescendants()
    local result={}
    local function visit(object)for _,child in object.children do table.insert(result,child);visit(child)end end
    visit(self);return result
end
function methods:IsA(class)
    return self.ClassName==class or class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="SpawnLocation" or self.ClassName=="WedgePart")
end
function methods:FindFirstChild(name,recursive)
    for _,child in (recursive and self:GetDescendants() or self.children) do if child.Name==name then return child end end
end
function methods:FindFirstChildOfClass(class)
    for _,child in self.children do if child:IsA(class) then return child end end
end
function methods:SetAttribute(key,value)self.attributes[key]=value end
function methods:GetAttribute(key)return self.attributes[key]end
function methods:GetAttributes()return table.clone(self.attributes)end
function methods:Destroy()for _,child in self:GetChildren()do child:Destroy()end;self.Parent=nil end
local function corners(object,callback)
    local half=object.Size/2
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do callback(object.CFrame*vector(x*half.X,y*half.Y,z*half.Z))end end end
end
function methods:GetBoundingBox()
    local pivot=self.PrimaryPart and self.PrimaryPart.CFrame or self._pivot or CFrame.identity
    local inverse=pivot:Inverse()
    local low,high=vector(math.huge,math.huge,math.huge),vector(-math.huge,-math.huge,-math.huge)
    local count=0
    for _,object in self:GetDescendants() do if object:IsA("BasePart") then
        count+=1
        corners(object,function(point)
            local p=inverse*point
            low=vector(math.min(low.X,p.X),math.min(low.Y,p.Y),math.min(low.Z,p.Z))
            high=vector(math.max(high.X,p.X),math.max(high.Y,p.Y),math.max(high.Z,p.Z))
        end)
    end end
    if count==0 then return pivot,vector() end
    return pivot*CFrame.new((low+high)/2),high-low
end
function methods:GetPivot()
    if self:IsA("BasePart")then return self.CFrame end
    if self.PrimaryPart then return self.PrimaryPart.CFrame end
    if self._pivot then return self._pivot end
    local bounds=self:GetBoundingBox()
    return bounds
end
function methods:PivotTo(transform)
    if self:IsA("BasePart")then self.CFrame=transform;return end
    local delta=transform*self:GetPivot():Inverse()
    for _,child in self:GetDescendants()do
        if child:IsA("BasePart")then child.CFrame=delta*child.CFrame
        elseif child:IsA("Model")and child._pivot then child._pivot=delta*child._pivot end
    end
    self._pivot=transform
end
local Instance={new=function(class)
    local values={Name=class}
    if class=="Part"or class=="SpawnLocation"or class=="WedgePart"or class=="Attachment"then values.CFrame=CFrame.identity end
    return setmetatable({ClassName=class,children={},attributes={},values=values}, {
        __index=function(self,key)
            if methods[key]then return methods[key]end
            if key=="Position"then return self.values.CFrame.Position end
            return self.values[key]
        end,
        __newindex=function(self,key,value)
            if key=="Parent"then
                local old=self.values.Parent
                if old then local index=table.find(old.children,self);if index then table.remove(old.children,index)end end
                if value then table.insert(value.children,self)end
            elseif key=="Position"then
                self.values.CFrame=CFrame.new(value)*self.values.CFrame.Rotation;return
            end
            self.values[key]=value
        end,
    })
end}
local workspace=Instance.new("Workspace")
local lighting=Instance.new("Lighting")
local serverStorage=Instance.new("ServerStorage")
local game={GetService=function(_,name)
    if name=="Lighting"then return lighting end
    if name=="ServerStorage"then return serverStorage end
    error("Unexpected service: "..name)
end}
local function typeof(value)
    if type(value)=="table"then return value.__type or(value.ClassName and"Instance")or"table"end
    return type(value)
end
local stubWarnings={}
local function warn(message)stubWarnings[#stubWarnings+1]=message end
