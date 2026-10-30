"""Exercise actual sword/world builders with construction doubles in Luau.

Usage: python3 tests/check_world.py /path/to/luau
This checks builder paths, dimensions, hierarchy and exposed gameplay contracts.
It cannot establish Roblox runtime compatibility or visual/physics correctness.
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
    elseif object:IsA("Model") then models += 1 end
end
check(parts < 3500,"Static map exceeds intended part budget")
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
for i,station in world.training do
    check(station.id==i,"Training identity mismatch")
    check((station.prompt.Parent.Position-station.center-vector(0,3,0)).Magnitude < station.prompt.MaxActivationDistance,"Training prompt unreachable")
    for j,other in world.training do
        if i~=j then check((station.center-other.center).Magnitude > station.radius+other.radius,"Training zones overlap") end
    end
end
local originalFolder = world.folder
local replacement = W.build(SD)
check(originalFolder.Parent == nil,"Rebuilding must remove the old map")
check(workspace:FindFirstChild("AnimeSwordWorld") == replacement.folder,"Rebuild must expose the replacement map")
print(string.format("PASS: %d construction assertions; 14 sword builders; map %d parts / %d models, 15 connected room contracts, 4 training contracts, repeat build",checks,parts,models))
"""

chunk = (ROOT / "tests/roblox_stubs.luau").read_text()
chunk += "\nlocal SD = (function()\n" + (ROOT / "SwordData.lua").read_text() + "\nend)()\n"
chunk += "\nlocal W = (function()\n" + (ROOT / "WorldBuilder.lua").read_text() + "\nend)()\n"
chunk += CHECKS
with tempfile.TemporaryDirectory(prefix="bladebound-world-") as temp:
    path = Path(temp) / "check_world.luau"
    path.write_text(chunk)
    raise SystemExit(subprocess.run([str(LUAU),str(path)],check=False).returncode)
