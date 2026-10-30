"""Test actual server sanitization and persistence functions with an in-memory store.

Usage: python3 tests/check_server.py /path/to/luau
Extracts the named pure/persistence function sections from GameServer. It does
not run Roblox services, concurrent servers, networking or live DataStores.
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
server = (ROOT / "GameServer.lua").read_text()


def section(start, stop):
    return server[server.index(start):server.index(stop)]


SETUP = r"""
local LIMIT, SESSION_ID, SESSION_LEASE = 1e100, "test-server", 180
local data, dirty, noSave, saveHealthy, saving, released, sessionBlocked = {},{},{},{},{},{},{}
local warnings = {}
local function warn(message) warnings[#warnings+1]=message end
local function toast() end
local task = {wait=function()end}
local function clone(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key,item in value do copy[key]=clone(item) end
    return copy
end
local store = {records={},calls=0,failures=0,retryCallback=false}
function store:UpdateAsync(key,callback)
    self.calls += 1
    if self.failures > 0 then self.failures -= 1;error("Injected store failure") end
    if self.retryCallback then callback(clone(self.records[key])) end
    local value=callback(clone(self.records[key]))
    if value ~= nil then self.records[key]=clone(value) end
    return clone(self.records[key])
end
"""

CHECKS = r"""
local checks=0
local function check(condition,message) checks+=1;assert(condition,message)end
local d=sanitize({spirit=0/0,trophies=math.huge,rebirths=-1,stage=99,equipped=99,
    owned={["99"]=true},mastery=math.huge,masteryXP=-1,aura=2,auras={},pets={['Fox Spirit']=-5}})
check(d.spirit==0 and d.trophies==0 and d.rebirths==0,"Nonfinite and negative economy values must be rejected")
check(d.stage==1 and d.equipped==1 and d.owned['1']==true,"Invalid progress/equipment must retain valid starter state")
check(d.mastery==0 and d.masteryXP==0 and d.aura==0,"Invalid mastery/unowned aura must be rejected")
check(d.pets['Fox Spirit']==0,"Negative pet counts must be rejected")
local capped=sanitize({mastery=1e8,trophies=1e20,rebirths=1e8})
check(capped.mastery==SD.MAX_MASTERY and capped.trophies==1e12 and capped.rebirths==100,"Loaded progression must obey limits")
local p={UserId=1001}
store.retryCallback=true
data[p]=loadPlayer(p)
check(not noSave[p] and store.records.p_1001._session.id==SESSION_ID,"New save must claim a lease atomically")
data[p].spirit=876
savePlayer(p)
check(store.records.p_1001.spirit==876 and store.records.p_1001._session.id==SESSION_ID,"Owned save must persist and refresh its lease")
savePlayer(p,true)
check(store.records.p_1001.spirit==876 and store.records.p_1001._session==nil and released[p],"Departure must save and release the lease")
local calls=store.calls
savePlayer(p)
check(store.calls==calls,"Released sessions must stop writing")

local blocked={UserId=1002}
store.records.p_1002={spirit=999,_session={id='other-server',updated=os.time()}}
data[blocked]=loadPlayer(blocked)
check(noSave[blocked] and sessionBlocked[blocked],"An unexpired foreign lease must decline the claim")
check(store.records.p_1002.spirit==999 and store.records.p_1002._session.id=='other-server',"Declined claim must preserve the foreign save")
calls=store.calls
savePlayer(blocked,true)
check(store.calls==calls,"Practice session must never overwrite the foreign save")

local expired={UserId=1003}
store.records.p_1003={spirit=555,_session={id='crashed-server',updated=os.time()-181}}
data[expired]=loadPlayer(expired)
check(not noSave[expired] and data[expired].spirit==555,"An expired lease must be reclaimable without discarding progress")
check(store.records.p_1003._session.id==SESSION_ID,"Reclaim must establish new ownership")
store.records.p_1003._session={id='new-owner',updated=os.time()}
data[expired].spirit=1234
savePlayer(expired)
check(noSave[expired] and saveHealthy[expired]==false,"Loss of ownership must disable subsequent writes")
check(store.records.p_1003.spirit==555 and store.records.p_1003._session.id=='new-owner',"Stale server must not overwrite a new owner's save")

local failing={UserId=1004}
store.failures=3
calls=store.calls
data[failing]=loadPlayer(failing)
check(store.calls==calls+3 and noSave[failing],"Three failed claims must enter practice mode")
calls=store.calls
savePlayer(failing)
check(store.calls==calls,"Failed read/claim must prohibit save writes")

local retrying={UserId=1005}
store.failures=2
calls=store.calls
data[retrying]=loadPlayer(retrying)
check(store.calls==calls+3 and not noSave[retrying],"Transient claim failures must retry and recover")
store.failures=2
data[retrying].spirit=120
calls=store.calls
savePlayer(retrying)
check(store.calls==calls+3 and saveHealthy[retrying] and store.records.p_1005.spirit==120,"Transient save failures must retry and recover")
print(string.format("PASS: %d server assertions; sanitize, claim/release, lease expiry/ownership, failed-read protection and retries",checks))
"""

chunk = (ROOT / "tests/roblox_stubs.luau").read_text()
chunk += "\nlocal SD=(function()\n"+(ROOT / "SwordData.lua").read_text()+"\nend)()\n"
chunk += SETUP
chunk += section("local function finite(n)", "local function bump(p)")
chunk += section("local function loadPlayer(p)", "local function onCharacter(p, char)")
chunk += CHECKS
with tempfile.TemporaryDirectory(prefix="bladebound-server-") as temp:
    path=Path(temp)/"check_server.luau"
    path.write_text(chunk)
    raise SystemExit(subprocess.run([str(LUAU),str(path)],check=False).returncode)
