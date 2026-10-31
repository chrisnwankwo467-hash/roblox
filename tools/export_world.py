"""Execute actual map builders in standalone Luau and export typed instance data.

Usage: python3 tools/export_world.py /path/to/luau /path/to/world.json
The construction doubles implement rigid transforms and hierarchy; this creates
edit-time geometry data and is not a Roblox runtime, physics or rendering test.
"""
from pathlib import Path
import json
import math
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUAU = sys.argv[1] if len(sys.argv) > 1 else shutil.which("luau")
OUT = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "dist/world.json"
if not LUAU:
    raise SystemExit("Pass the path to the official Luau CLI as the first argument.")

EXPORT = r"""
local built=W.build(SD)
built.folder:SetAttribute("BakedWorldVersion",W.BAKED_VERSION)
local objects,ids={},{}
local function visit(object)
    objects[#objects+1]=object
    ids[object]="WORLD_"..#objects
    for _,child in object:GetChildren()do visit(child)end
end
visit(workspace);visit(lighting)
local function plain(value)
    if type(value)~="table"then return value end
    if value.ClassName and value.values then return {__type="Ref",id=ids[value]} end
    if value.__type=="CFrame"then
        return {__type="CFrame",components={value:GetComponents()}}
    end
    local result={}
    for key,item in value do if type(item)~="function"then result[key]=plain(item)end end
    return result
end
local records={}
for _,object in objects do
    local properties={}
    for key,value in object.values do
        if key~="Parent"and key~="Name"and string.sub(key,1,1)~="_"and type(value)~="function"then
            properties[key]=plain(value)
        end
    end
    records[#records+1]={id=ids[object],className=object.ClassName,name=object.Name,
        parent=object.Parent and ids[object.Parent]or nil,properties=properties,attributes=plain(object.attributes)}
end
local function quote(value)
    local escapes={["\""]="\\\"",["\\"]="\\\\",["\n"]="\\n",["\r"]="\\r",["\t"]="\\t"}
    return '"'..string.gsub(value,'[%z\1-\31\\"]',function(char)
        return escapes[char]or string.format("\\u%04x",string.byte(char))
    end)..'"'
end
local encode
encode=function(value)
    local kind=type(value)
    if kind=="nil"then return "null"end
    if kind=="boolean"then return value and"true"or"false"end
    if kind=="string"then return quote(value)end
    if kind=="number"then assert(value==value and math.abs(value)<math.huge,"Cannot export nonfinite value");return tostring(value)end
    assert(kind=="table","Unsupported export value "..kind)
    local array=value[1]~=nil
    local parts={}
    if array then
        for _,item in value do parts[#parts+1]=encode(item)end
        return"["..table.concat(parts,",").."]"
    end
    local keys={}
    for key in value do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in keys do parts[#parts+1]=quote(tostring(key))..":"..encode(value[key])end
    return"{"..table.concat(parts,",").."}"
end
print(encode({formatVersion=1,records=records,metadata={roomCount=#built.rooms,trainingCount=#built.training,
    swordPromptCount=built.swordPrompts and #built.swordPrompts or 0,eggPromptCount=built.eggPrompts and #built.eggPrompts or 0}}))
"""

chunk = (ROOT / "tests/roblox_stubs.luau").read_text()
chunk += "\nlocal SD=(function()\n" + (ROOT / "SwordData.lua").read_text() + "\nend)()\n"
chunk += "\nlocal W=(function()\n" + (ROOT / "WorldBuilder.lua").read_text() + "\nend)()\n"
chunk += EXPORT
with tempfile.TemporaryDirectory(prefix="bladebound-export-") as temp:
    path = Path(temp) / "export_world.luau"
    path.write_text(chunk)
    result = subprocess.run([str(LUAU), str(path)], capture_output=True, text=True, check=False)
    if result.returncode:
        raise SystemExit(result.stderr)
    payload = json.loads(result.stdout)
    assert payload["formatVersion"] == 1
    records = payload["records"]
    ids = {node["id"] for node in records}
    assert len(ids) == len(records), "Duplicate instance identifiers"

    def validate_value(value):
        if isinstance(value, list):
            for child in value:
                validate_value(child)
        elif isinstance(value, dict):
            if value.get("__type") == "Ref":
                assert value["id"] in ids, "Instance reference points outside the exported hierarchy"
            elif value.get("__type") == "CFrame":
                components = value["components"]
                assert len(components) == 12 and all(math.isfinite(n) for n in components)
                matrix = components[3:]
                for row in range(3):
                    for other in range(3):
                        dot = sum(matrix[row * 3 + col] * matrix[other * 3 + col] for col in range(3))
                        assert abs(dot - (1 if row == other else 0)) < 1e-6, "Non-rigid exported CFrame"
            for child in value.values():
                validate_value(child)

    for node in records:
        assert node.get("parent") is None or node["parent"] in ids, node
        validate_value(node["properties"])
        validate_value(node["attributes"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    parts = sum(node["className"] in ("Part", "SpawnLocation", "WedgePart") for node in records)
    print(f"Exported {len(records):,} instances / {parts:,} base parts to {OUT}")
