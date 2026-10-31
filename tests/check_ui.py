"""Exercise the actual responsive layout and objective selection with UI doubles.
These tests check geometry/state decisions, not Studio rendering or input APIs.
"""
from pathlib import Path
import subprocess,sys,tempfile,shutil
ROOT=Path(__file__).resolve().parents[1]
runner=sys.argv[1] if len(sys.argv)>1 else shutil.which('luau')
source=(ROOT/'GameClient.lua').read_text()
layout=source[source.index('local function layout()'):source.index('gui:GetPropertyChangedSignal("AbsoluteSize")')]
a=source.index('    if s.fight then\n        questTitle.Text=')
b=source.index('    local level, xp, needed =',a)
objective=source[a:b]
chunk=(ROOT/'tests/roblox_stubs.luau').read_text()+r'''
local checks=0
local function check(c,m)checks+=1;assert(c,m)end
local names={"spiritCard","trophyCard","powerCard","route","rebirthTag","nav","quest","fightBar","savingLabel","hubButton","stopButton","mastery","trainingTag","comboFlash","swingButton","autoButton","controls","panel","toastLabel"}
local gui,root,uiScale,shade,portrait={AbsoluteSize=Vector2.new(1280,720)},{},{},{Visible=false},false
local spiritCard,trophyCard,powerCard,route,rebirthTag,nav,quest,fightBar,savingLabel,hubButton,stopButton,mastery,trainingTag,comboFlash,swingButton,autoButton,controls,panel,toastLabel={},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}
local objects={spiritCard,trophyCard,powerCard,route,rebirthTag,nav,quest,fightBar,savingLabel,hubButton,stopButton,mastery,trainingTag,comboFlash,swingButton,autoButton,controls,panel,toastLabel}
rebirthTag.Size=UDim2.fromOffset(200,25)
trainingTag.Size=UDim2.fromOffset(490,28)
controls.Size=UDim2.fromOffset(650,22)
local navButtons,navTitles,navIcons={},{},{}
for i=1,7 do navButtons[i]={};navTitles[i]={};navIcons[i]={} end
'''+layout+r'''
local function bounds(o)return o.Position.X.Offset,o.Position.Y.Offset,o.Size.X.Offset,o.Size.Y.Offset end
local function separated(a,b)
 local ax,ay,aw,ah=bounds(a);local bx,by,bw,bh=bounds(b)
 return ax+aw<=bx or bx+bw<=ax or ay+ah<=by or by+bh<=ay
end
for _,screen in {Vector2.new(1280,720),Vector2.new(720,1120),Vector2.new(390,844),Vector2.new(1920,1080)}do
 gui.AbsoluteSize=screen;layout()
 local w,h=root.Size.X.Offset,root.Size.Y.Offset
 check(uiScale.Scale>0 and w*uiScale.Scale<=screen.X+0.01 and h*uiScale.Scale<=screen.Y+0.01,"Canvas must fit the screen")
 for i,o in objects do
  if names[i]~="panel"then
   local x,y,ow,oh=bounds(o)
   check(x>=0 and y>=0 and x+ow<=w and y+oh<=h,"HUD element outside canvas: "..names[i])
  end
 end
 for i,b in navButtons do
  local x,y,bw,bh=bounds(b)
  check(x>=0 and y>=0 and x+bw<=nav.Size.X.Offset and y+bh<=nav.Size.Y.Offset,"Menu tile outside navigation")
  for j,other in navButtons do if i~=j then check(separated(b,other),"Menu tiles overlap")end end
 end
 check(separated(spiritCard,trophyCard)and separated(mastery,swingButton),"Primary HUD controls overlap")
 check(separated(quest,fightBar)and separated(fightBar,comboFlash),"Quest/combat feedback overlap")
 check(separated(comboFlash,savingLabel),"Save warning and combo feedback overlap")
end
local questTitle,questDetail,questButton,upgradeBadge={},{},{},{}
local SD={SWORDS={{cost=0},{cost=250},{cost=1500}}}
local function selectObjective(s)
'''+objective+r'''
end
selectObjective({stage=1,mastery=0,spirit=0,owned={['1']=true}})
check(questButton.Text=="SHOW TRAINING"and not upgradeBadge.Visible,"New players need the training objective without a false upgrade badge")
selectObjective({stage=2,mastery=1,spirit=250,owned={['1']=true}})
check(questButton.Text=="ENTER ROOM 2"and upgradeBadge.Visible,"Unlocked room and affordable upgrade must follow server state")
selectObjective({stage=2,mastery=2,spirit=0,owned={['1']=true},fight={step=3,total=6,boss=false}})
check(questTitle.Text=="CLEAR THE GUARDIANS"and string.find(questDetail.Text,"2 / 6"),"Fight objective must show actual cleared opponents")
selectObjective({stage=2,mastery=2,spirit=0,owned={['1']=true},fight={step=6,total=6,boss=true}})
check(questTitle.Text=="DEFEAT THE BOSS","Boss objective must follow boss state")
print("PASS: "..checks.." UI layout/objective assertions; four viewport sizes, real server-state decisions")
'''
with tempfile.TemporaryDirectory() as temp:
 path=Path(temp)/'ui.luau';path.write_text(chunk)
 raise SystemExit(subprocess.run([runner,str(path)]).returncode)
