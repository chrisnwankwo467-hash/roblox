"""Exercise actual sword/world builders with construction doubles in Luau.

Usage: python3 tests/check_world.py /path/to/luau
This checks rigid transforms, builder paths, dimensions, hierarchy, interaction
contracts and sampled traversability using oriented boxes. It cannot establish
Roblox runtime compatibility, rendered appearance or physics correctness.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUAU = sys.argv[1] if len(sys.argv) > 1 else shutil.which("luau")
if not LUAU:
    raise SystemExit("Pass the path to the official Luau CLI as the first argument.")

CHECKS = r"""
local checks = 0
local function check(condition, message)
    checks += 1
    assert(condition,message)
end
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function close(a,b) return (a-b).Magnitude < 1e-7 end
local rotated = CFrame.new(10,2,3)*CFrame.Angles(0,math.pi/2,0)
check(close(rotated*vector(1,0,0),vector(10,2,2)),"Rotation must affect transformed points")
check(close(rotated:Inverse()*(rotated*vector(4,5,6)),vector(4,5,6)),"Rigid transform inverse must recover points")
local vertical=CFrame.lookAt(vector(),vector(0,5,0))
check(close(vertical.LookVector,vector(0,1,0)),"Vertical beam frames must remain finite and face the target")
local probe=Instance.new("Model")
local probePart=Instance.new("Part")
probePart.Size=vector(2,4,6);probePart.CFrame=CFrame.new(1,0,0);probePart.Parent=probe
probe.PrimaryPart=probePart
probe:PivotTo(rotated)
check(close(probePart.Position,rotated.Position),"Model PivotTo must move actual geometry")
local probeCF,probeSize=probe:GetBoundingBox()
check(close(probeCF.Position,rotated.Position)and close(probeSize,vector(2,4,6)),"Rotated model bounds must retain local dimensions")
local signatures = {}
for _,definition in SD.SWORDS do
    local model = Instance.new("Model")
    local handle = SD.buildSword(definition,model)
    check(model.PrimaryPart == handle and handle.Name == "Handle", "Sword must expose its handle")
    local parts, welded, trail = 0, 0, nil
    local signature = {}
    for _,object in model:GetDescendants() do
        if object:IsA("BasePart") then
            parts += 1
            check(object.CanCollide == false and object.Massless == true,"Equipped sword must not obstruct physics")
            check(object.Size.X>0 and object.Size.Y>0 and object.Size.Z>0,"Sword contains nonpositive dimensions")
            signature[#signature+1] = object.Name..":"..string.format("%.2f/%.2f/%.2f",object.Size.X,object.Size.Y,object.Size.Z)
        elseif object:IsA("WeldConstraint") then
            welded += 1
            check(object.Part0 == handle and object.Part1 ~= nil,"Every sword component must weld to its handle")
        elseif object:IsA("Trail") then trail = object end
    end
    check(parts >= 20,"Sword should have a modeled silhouette")
    check(welded == parts-1,"Sword has an unconnected component")
    check(trail and trail.Enabled == false,"Swing trail must start disabled")
    check(trail.Attachment0.Parent == handle and trail.Attachment1.Parent == handle,"Trail attachments must follow the held weapon")
    local joined = table.concat(signature,";")
    check(not signatures[joined],"Sword geometry must be distinct")
    signatures[joined] = true
end
local world = W.build(SD)
check(#world.rooms==15 and #world.roomPrompts==15 and #world.returnPrompts==15,"Every room needs entry and recall")
check(#world.training==4,"All training stations must be built")
check(world.hubPrompts.Swords and world.hubPrompts.Pets and world.hubPrompts.Auras,"Hub services missing")
local parts, models = 0, 0
for _,object in world.folder:GetDescendants() do
    if object:IsA("BasePart") then
        parts += 1
        local size = object.Size
        check(finite(size.X) and finite(size.Y) and finite(size.Z) and size.X>0 and size.Y>0 and size.Z>0,"Invalid world part dimensions")
        check(object.Anchored == true,"World geometry must remain anchored")
        local rigid=true
        for _,component in {object.CFrame:GetComponents()}do if not finite(component)then rigid=false end end
        check(rigid,"World part transform must remain finite")
    elseif object:IsA("Model") then models += 1 end
end
check(parts < 5000,"Static map exceeds intended part budget")
check(close(world.spawn.Position,vector(0,4,145)),"Spawn must arrive in the expanded sanctuary")
check(lighting.ClockTime==13.2 and lighting.Brightness>=2.5,"Map must use bright daylight")
local atmosphere=lighting:FindFirstChild("SpiritbladeAtmosphere")
check(atmosphere and atmosphere.Density<=0.2,"Thin atmosphere must preserve map visibility")
check(lighting:FindFirstChildOfClass("ColorCorrectionEffect")~=nil,"Daylight color grading missing")
check(lighting:FindFirstChildOfClass("SunRaysEffect")~=nil,"Daylight sun rays missing")
check(world.swordPrompts and #world.swordPrompts==#SD.SWORDS,"Every modeled sword display needs an interaction")
check(world.eggPrompts and #world.eggPrompts==#SD.EGGS,"Every modeled egg display needs an interaction")
for index,prompt in world.swordPrompts do
    check(prompt:GetAttribute("SwordIndex")==index,"Sword prompt must identify the correct purchase")
    check(prompt.Parent and prompt.Parent:IsA("BasePart") and prompt.MaxActivationDistance>=8,"Sword display interaction must be reachable")
end
for index,prompt in world.eggPrompts do
    check(prompt:GetAttribute("EggIndex")==index,"Egg prompt must identify the correct hatch")
    check(prompt.Parent and prompt.Parent:IsA("BasePart") and prompt.MaxActivationDistance>=8,"Egg display interaction must be reachable")
end
local priorZ = 0
for i,room in world.rooms do
    check(room.center.Z < priorZ,"Room sequence reversed")
    check(#room.enemySpawns == SD.STAGE_MINIONS+1,"Encounter count mismatch")
    local previous = room.spawn.Position.Z
    for _,spawn in room.enemySpawns do
        check(spawn.Position.Z < previous,"Encounter route must advance through the room")
        check(math.abs(spawn.Position.X)<=12,"Enemy is outside the combat road")
        previous=spawn.Position.Z
    end
    local entrance = world.roomPrompts[i]
    check((entrance.Parent.Position-room.entry.Position).Magnitude < entrance.MaxActivationDistance,"Entrance prompt unreachable")
    priorZ=room.center.Z
end
local trainingPositions={vector(-44,0,100),vector(44,0,100),vector(-44,0,45),vector(44,0,45)}
for i,station in world.training do
    check(station.id==i,"Training identity mismatch")
    check(close(station.center,trainingPositions[i]),"Training court must follow the expanded hub layout")
    check((station.prompt.Parent.Position-station.center-vector(0,3,0)).Magnitude < station.prompt.MaxActivationDistance,"Training prompt unreachable")
    for j,other in world.training do
        if i~=j then check((station.center-other.center).Magnitude > station.radius+other.radius,"Training zones overlap") end
    end
end
-- Sample the supported central path with oriented-box ray intersections. This
-- detects gaps and body-height boxes without pretending to simulate a Humanoid.
local collidable={}
for _,object in world.folder:GetDescendants()do
    if object:IsA("BasePart")and object.CanCollide then
        local r,h=object.CFrame.matrix,object.Size/2
        local extent=vector(math.abs(r[1])*h.X+math.abs(r[2])*h.Y+math.abs(r[3])*h.Z,
            math.abs(r[4])*h.X+math.abs(r[5])*h.Y+math.abs(r[6])*h.Z,
            math.abs(r[7])*h.X+math.abs(r[8])*h.Y+math.abs(r[9])*h.Z)
        collidable[#collidable+1]={object=object,low=object.Position-extent,high=object.Position+extent}
    end
end
local function overlapsXZ(box,x,z)return x>=box.low.X and x<=box.high.X and z>=box.low.Z and z<=box.high.Z end
local function rayBox(object,origin,direction)
    local o=object.CFrame:PointToObjectSpace(origin)
    local d=object.CFrame:VectorToObjectSpace(direction)
    local half=object.Size/2
    local lo,hi=0,math.huge
    for _,axis in {"X","Y","Z"}do
        if math.abs(d[axis])<1e-9 then
            if math.abs(o[axis])>half[axis] then return nil end
        else
            local a,b=(-half[axis]-o[axis])/d[axis],(half[axis]-o[axis])/d[axis]
            if a>b then a,b=b,a end
            lo,hi=math.max(lo,a),math.min(hi,b)
            if lo>hi then return nil end
        end
    end
    return lo
end
local function supportHeight(x,z,above)
    local best=-math.huge
    for _,box in collidable do
        if overlapsXZ(box,x,z)then
            local t=rayBox(box.object,vector(x,above,z),vector(0,-1,0))
            if t then best=math.max(best,above-t)end
        end
    end
    return best
end
for _,prompts in {world.swordPrompts,world.eggPrompts,world.roomPrompts,world.returnPrompts,world.hubPrompts}do
    for _,prompt in prompts do
        local position=prompt.Parent.Position
        local floor=supportHeight(position.X,position.Z,4)
        check(finite(floor)and floor>=-0.3,"Interaction has no ground support: "..prompt.Parent.Name)
        check((position-vector(position.X,floor+3,position.Z)).Magnitude<prompt.MaxActivationDistance,"Interaction is too high to reach from its standing surface")
    end
end
local samples=0
for z=world.spawn.Position.Z,world.rooms[#world.rooms].enemySpawns[SD.STAGE_MINIONS+1].Position.Z,-4 do
    local floor=supportHeight(0,z,1.0)
    check(finite(floor)and floor>=-0.3 and floor<=1.0,"Central route ground gap near Z="..z)
    samples+=1
    local blocker=nil
    for _,box in collidable do
        -- Checking a short upward ray from the ground rejects low obstructions;
        -- high roofs and gate beams remain above the player's body.
        if overlapsXZ(box,0,z)then
            local t=rayBox(box.object,vector(0,floor+0.25,z),vector(0,1,0))
            if t and t<=5.5 then blocker=box.object.Name;break end
        end
    end
    check(not blocker,"Central route body obstruction "..tostring(blocker).." near Z="..z)
end
local stairCount,stairGroups=0,{}
for _,object in world.folder:GetDescendants()do
    if object:IsA("BasePart")and(string.match(object.Name,"^DisplayStair_")or string.match(object.Name,"^EggStair_"))then
        stairCount+=1
        check(object.CanCollide,"Access stairs must provide physical support")
        check(math.min(object.Size.X,object.Size.Z)>=1.8 and math.max(object.Size.X,object.Size.Z)>=8,"Access steps need tread depth and standing width")
        local group,index=string.match(object.Name,"^(.-)_(%d+)$")
        check(group~=nil,"Access stair must expose a stable group and step order")
        if not stairGroups[group]then stairGroups[group]={}end
        stairGroups[group][tonumber(index)]=object
    end
end
check(stairCount>=12,"Tiered displays need physical access stairs")
for group,stairs in stairGroups do
    local lastTop,lastStep=0,nil
    for _,step in stairs do
        local top=step.Position.Y+step.Size.Y/2
        check(top>lastTop and top-lastTop<=0.55,"Stair rise discontinuity: "..group)
        check(math.abs(supportHeight(step.Position.X,step.Position.Z,top+0.1)-top)<0.05,"Stair surface must provide footing")
        if lastStep then
            local gapX=math.max(0,math.abs(step.Position.X-lastStep.Position.X)-(step.Size.X+lastStep.Size.X)/2)
            local gapZ=math.max(0,math.abs(step.Position.Z-lastStep.Position.Z)-(step.Size.Z+lastStep.Size.Z)/2)
            check(math.sqrt(gapX*gapX+gapZ*gapZ)<=0.25,"Access stairs contain a horizontal gap: "..group)
        end
        lastTop,lastStep=top,step
    end
end
-- The baked-map loader must reuse complete metadata, keep user edits, and
-- reconstruct gameplay coordinates without rebuilding static map geometry.
world.folder:SetAttribute("BakedWorldVersion","2")
local userEdit=Instance.new("Folder");userEdit.Name="UserAuthoredDetail";userEdit.Parent=world.folder
local loaded=W.load(SD)
check(loaded.folder==world.folder and userEdit.Parent==loaded.folder,"Baked load must preserve geometry and user edits")
check(close(loaded.spawn.Position,world.spawn.Position),"Baked spawn metadata must round-trip")
for i,room in loaded.rooms do
    check(close(room.center,world.rooms[i].center)and close(room.spawn.Position,world.rooms[i].spawn.Position),"Baked room coordinates must round-trip")
    for step,spawn in room.enemySpawns do check(close(spawn.Position,world.rooms[i].enemySpawns[step].Position),"Baked encounter markers must round-trip")end
    check(loaded.roomPrompts[i]==world.roomPrompts[i]and loaded.returnPrompts[i]==world.returnPrompts[i],"Baked room interactions must reuse their instances")
end
for i,station in loaded.training do
    check(close(station.center,world.training[i].center)and station.radius==world.training[i].radius and station.prompt==world.training[i].prompt,"Baked training contract must round-trip")
end
for i,prompt in loaded.swordPrompts do check(prompt==world.swordPrompts[i],"Baked sword interactions must round-trip")end
for i,prompt in loaded.eggPrompts do check(prompt==world.eggPrompts[i],"Baked hatch interactions must round-trip")end
-- Removing required metadata must preserve the original, then build a fallback.
local marker=world.folder:FindFirstChild("EncounterSpawn_1",true)
marker:SetAttribute("EncounterStep",nil)
local recovered=W.load(SD)
local backups=serverStorage:FindFirstChild("BladeboundWorldBackups")
check(recovered.folder~=world.folder and #recovered.rooms==15,"Incomplete baked metadata must trigger a usable fallback")
check(backups and world.folder.Parent==backups and userEdit.Parent==world.folder,"Recovery must preserve the original map and user edits")
local originalFolder = recovered.folder
local replacement = W.build(SD)
check(originalFolder.Parent == nil,"Rebuilding must remove the old map")
check(workspace:FindFirstChild("AnimeSwordWorld") == replacement.folder,"Rebuild must expose the replacement map")
replacement.folder:SetAttribute("BakedWorldVersion","obsolete")
local upgraded=W.load(SD)
check(upgraded.folder~=replacement.folder and replacement.folder.Parent==backups,"Version upgrade must preserve the old baked map")
print(string.format("PASS: %d construction assertions; 14 swords; map %d parts / %d models; %d route samples, %d access stairs, 15 rooms, 4 training courts, baked reload/recovery",checks,parts,models,samples,stairCount))
"""

chunk = (ROOT / "tests/roblox_stubs.luau").read_text()
chunk += "\nlocal SD = (function()\n" + (ROOT / "SwordData.lua").read_text() + "\nend)()\n"
chunk += "\nlocal W = (function()\n" + (ROOT / "WorldBuilder.lua").read_text() + "\nend)()\n"
chunk += CHECKS
with tempfile.TemporaryDirectory(prefix="bladebound-world-") as temp:
    path = Path(temp) / "check_world.luau"
    path.write_text(chunk)
    raise SystemExit(subprocess.run([str(LUAU),str(path)],check=False).returncode)
