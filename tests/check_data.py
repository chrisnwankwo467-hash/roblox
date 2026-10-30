"""Run progression invariants using the real SwordData source in standalone Luau.

Usage: python3 tests/check_data.py /path/to/luau
This intentionally does not simulate Roblox services, geometry, animation, or UI.
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

# The constructors below only allow the data table to load. Model-building
# functions are never called, so this test cannot establish Roblox compatibility.
PRELUDE = r"""
local function color(r, g, b)
    return {R = r / 255, G = g / 255, B = b / 255}
end
local Color3 = {fromRGB = color, new = function(r, g, b) return {R=r,G=g,B=b} end}
local enum = setmetatable({}, {__index = function(_, name) return name end})
local Enum = setmetatable({}, {__index = function() return enum end})
local SD = (function()
"""

CHECKS = r"""
end)()
local checks = 0
local function check(condition, description)
    checks += 1
    assert(condition, description)
end
local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
check(#SD.STAGES == 15, "The complete run must contain 15 rooms")
check(#SD.SWORDS >= 14, "At least 14 sword designs must be available")
check(#SD.TRAINING == 4, "Four physical training tiers must be configured")
check(SD.STAGE_MINIONS == 5, "Each room must support the five-minion boss sequence")
local oldHP, oldTrophies, oldReward = 0, 0, 0
local roomNames = {}
for i, stage in SD.STAGES do
    check(type(stage.name) == "string" and not roomNames[stage.name], "Room names must be unique")
    roomNames[stage.name] = true
    check(type(stage.minion) == "string" and type(stage.boss) == "string", "Every room needs both enemy types")
    local hp, bossHP = SD.enemyHp(i, false), SD.enemyHp(i, true)
    local trophies, reward = SD.roomTrophies(i), SD.roomReward(i)
    check(finite(hp) and hp > oldHP, "Minion HP must rise each room")
    check(finite(bossHP) and bossHP > hp, "Boss must have more HP than its minions")
    check(finite(trophies) and trophies % 1 == 0 and trophies > oldTrophies, "Room trophy rewards must strictly rise")
    check(finite(reward) and reward > oldReward, "Room Spirit rewards must strictly rise")
    oldHP, oldTrophies, oldReward = hp, trophies, reward
end
local swordNames, designs = {}, {}
local oldCost, oldMult = -1, 0
for _, sword in SD.SWORDS do
    check(type(sword.name) == "string" and not swordNames[sword.name], "Sword names must be unique")
    swordNames[sword.name] = true
    check(finite(sword.cost) and sword.cost > oldCost, "Sword costs must strictly rise")
    check(finite(sword.mult) and sword.mult > oldMult, "Sword upgrades must improve power")
    check(finite(sword.length) and sword.length > 0 and finite(sword.width) and sword.width > 0, "Sword dimensions must be positive")
    check(type(sword.design) == "string" and not designs[sword.design], "Each sword needs its own geometry family")
    designs[sword.design] = true
    oldCost, oldMult = sword.cost, sword.mult
end
check(SD.SWORDS[1].cost == 0, "Starter sword must be free")
local oldRequirement, oldTraining, oldXP = -1, 0, 0
for _, station in SD.TRAINING do
    check(finite(station.requiredTrophies) and station.requiredTrophies > oldRequirement, "Training tiers must have increasing unlocks")
    check(finite(station.mult) and station.mult >= 1 and station.mult > oldTraining, "Training tiers must improve swing gains")
    check(finite(station.xp) and station.xp > oldXP, "Training tiers must improve mastery XP")
    check(type(station.description) == "string" and #station.description > 0, "Training must explain its effect")
    oldRequirement, oldTraining, oldXP = station.requiredTrophies, station.mult, station.xp
end
check(SD.TRAINING[1].requiredTrophies == 0, "New players need an accessible training station")
local completeRunTrophies = 0
for i = 1, #SD.STAGES do completeRunTrophies += SD.roomTrophies(i) end
check(completeRunTrophies >= SD.TRAINING[#SD.TRAINING].requiredTrophies, "The training unlock track must be reachable during the room run")
for level = 0, (SD.MAX_MASTERY or 100) do
    check(finite(SD.masteryNeed(level)) and SD.masteryNeed(level) > 0, "Mastery XP requirements must remain valid")
    check(finite(SD.masteryMultiplier(level)) and SD.masteryMultiplier(level) >= 1, "Mastery must not reduce power")
    if level > 0 then
        check(SD.masteryMultiplier(level) > SD.masteryMultiplier(level - 1), "Each mastery level must improve power")
    end
end
check(SD.masteryMultiplier(0) == 1, "Fresh characters must start at the baseline multiplier")
for rebirth = 0, 20 do
    check(finite(SD.rebirthCost(rebirth)) and SD.rebirthCost(rebirth) > 0, "Rebirth costs must be usable")
    if rebirth > 0 then check(SD.rebirthCost(rebirth) > SD.rebirthCost(rebirth - 1), "Rebirth costs must increase") end
end
for _, pet in SD.PETS do
    check(SD.PET_BY_NAME[pet.name] == pet, "Pet lookup must resolve the actual definition")
    check(SD.EGGS[pet.egg] ~= nil and pet.weight > 0 and pet.bonus >= 0, "Pet drop pools must be usable")
end
print(string.format("PASS: %d progression/data assertions; %d rooms, %d swords, %d training tiers", checks, #SD.STAGES, #SD.SWORDS, #SD.TRAINING))
"""

with tempfile.TemporaryDirectory(prefix="bladebound-data-") as temp:
    chunk = Path(temp) / "check_data.luau"
    chunk.write_text(PRELUDE + (ROOT / "SwordData.lua").read_text() + CHECKS)
    result = subprocess.run([str(LUAU), str(chunk)], check=False)
    raise SystemExit(result.returncode)
