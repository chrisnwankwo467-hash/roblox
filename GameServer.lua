-- GameServer (Script) -> ServerScriptService
-- Requires SwordData in ReplicatedStorage and WorldBuilder beside this script.
-- All currency, training, room access, melee range, rewards and saves are server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local SD = require(ReplicatedStorage:WaitForChild("SwordData"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local world = WorldBuilder.build(SD)
local store = DataStoreService:GetDataStore("AnimeSwordSim_v1") -- preserves existing saves
local function remote(name)
	local event = ReplicatedStorage:FindFirstChild(name)
	assert(not event or event:IsA("RemoteEvent"), name .. " must be a RemoteEvent")
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
	end
	return event
end
local actionRemote = remote("GameAction")
local syncRemote = remote("GameSync")
local fxFolder = Instance.new("Folder")
fxFolder.Name = "SwordEncounters"
fxFolder.Parent = workspace

local GOLD = Color3.fromRGB(255, 213, 95)
local CYAN = Color3.fromRGB(113, 236, 255)
local RED = Color3.fromRGB(255, 113, 126)
local LIMIT = 1e100 -- finite DataStore-safe economy ceiling
local data, dirty, versions = {}, {}, {}
local fights, lastRoom, training = {}, {}, {}
local lastSwing, combos, lastAction, lastRequest = {}, {}, {}, {}
local inGroup, noSave, saveHealthy, saving, loaded = {}, {}, {}, {}, {}
local closing = false
local SESSION_ID = game.JobId .. ":" .. HttpService:GenerateGUID(false)
local SESSION_LEASE = 180 -- refreshed every 60s; expired crashed-server claims may be reclaimed
local released, sessionBlocked = {}, {}

local function finite(n)
	return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
local function number(n, fallback, maximum)
	return finite(n) and math.clamp(n, 0, maximum or LIMIT) or fallback
end
local function index(n, maximum)
	return finite(n) and n % 1 == 0 and n >= 1 and n <= maximum and n or nil
end
local function defaultData()
	return {
		spirit = 0, trophies = 0, rebirths = 0, stage = 1,
		owned = { ["1"] = true }, equipped = 1,
		pets = {}, auras = {}, aura = 0, codes = {},
		mastery = 0, masteryXP = 0, lastSeen = os.time(),
	}
end
local function sanitize(raw)
	local d = defaultData()
	if type(raw) ~= "table" then return d end
	d.spirit = number(raw.spirit, 0)
	d.trophies = math.floor(number(raw.trophies, 0, 1e12))
	d.rebirths = math.floor(number(raw.rebirths, 0, 100))
	d.stage = index(raw.stage, #SD.STAGES) or 1
	d.mastery = math.floor(number(raw.mastery, 0, SD.MAX_MASTERY or 1000))
	d.masteryXP = number(raw.masteryXP, 0, SD.masteryNeed(d.mastery) - 1)
	d.lastSeen = math.floor(number(raw.lastSeen, os.time(), os.time()))
	if type(raw.owned) == "table" then
		for i = 1, #SD.SWORDS do
			if raw.owned[tostring(i)] == true then d.owned[tostring(i)] = true end
		end
	end
	local equipped = index(raw.equipped, #SD.SWORDS)
	if equipped and d.owned[tostring(equipped)] then d.equipped = equipped end
	if type(raw.auras) == "table" then
		for i = 1, #SD.AURAS do
			if raw.auras[tostring(i)] == true then d.auras[tostring(i)] = true end
		end
	end
	local aura = index(raw.aura, #SD.AURAS)
	if aura and d.auras[tostring(aura)] then d.aura = aura end
	if type(raw.pets) == "table" then
		for name in SD.PET_BY_NAME do
			d.pets[name] = math.floor(number(raw.pets[name], 0, 100000))
		end
	end
	if type(raw.codes) == "table" then
		for code in SD.CODES do
			if raw.codes[code] == true then d.codes[code] = true end
		end
	end
	return d
end
local function copySave(d)
	local copy = {}
	for k, v in d do
		copy[k] = type(v) == "table" and table.clone(v) or v
	end
	copy.lastSeen = os.time()
	return copy
end
local function bump(p)
	versions[p] = (versions[p] or 0) + 1
	dirty[p] = true
end
local function toast(p, text, color)
	if p.Parent == Players then syncRemote:FireClient(p, "Toast", text, color or CYAN) end
end
local function getChar(p)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and hum and hum.Health > 0 then return char, hum, root end
end
local function near(p, position, radius)
	local _, _, root = getChar(p)
	return root and (root.Position - position).Magnitude <= radius
end
local function stopTraining(p)
	if training[p] then training[p] = nil; bump(p) end
end
local function currentTraining(p)
	local id = training[p]
	local station = id and world.training[id]
	local def = id and SD.TRAINING[id]
	if station and def and data[p] and data[p].trophies >= def.requiredTrophies
		and near(p, station.center, station.radius + 3) and not fights[p] then
		return id, def
	end
	stopTraining(p)
	return 0, nil
end
local function petBonus(d)
	local entries = {}
	for name, count in d.pets do
		local pet = SD.PET_BY_NAME[name]
		if pet and count > 0 then table.insert(entries, {pet.bonus, count}) end
	end
	table.sort(entries, function(a, b) return a[1] > b[1] end)
	local sum, slots = 0, 3
	for _, entry in entries do
		local n = math.min(slots, entry[2])
		sum += entry[1] * n
		slots -= n
		if slots <= 0 then break end
	end
	return sum
end
local function getMult(p)
	local d = data[p]
	if not d then return 1 end
	local m = SD.SWORDS[d.equipped].mult * SD.masteryMultiplier(d.mastery)
	m *= 1 + petBonus(d)
	m *= 1 + (d.aura > 0 and SD.AURAS[d.aura].bonus or 0)
	m *= 1 + d.rebirths * 0.5
	m *= 1 + d.trophies * 0.01
	if inGroup[p] then m *= 1.1 end
	return math.min(m, LIMIT / 100)
end
local function addSpirit(p, amount)
	local d = data[p]
	if d then d.spirit = math.min(LIMIT, d.spirit + amount); dirty[p] = true end
end
local function updateLeaderstats(p)
	local ls = p:FindFirstChild("leaderstats")
	local d = data[p]
	if not ls or not d then return end
	ls.Power.Value = math.floor(getMult(p))
	ls.Trophies.Value = d.trophies
	ls.Rebirths.Value = d.rebirths
end
local function snapshot(p)
	local d = data[p]
	local id, def = currentTraining(p)
	local mult = getMult(p)
	local run = fights[p]
	local enemy = run and run.enemy
	local fight = run and {
		stage = run.stage, step = run.step, total = SD.STAGE_MINIONS + 1,
		boss = run.step == SD.STAGE_MINIONS + 1,
		hp = enemy and enemy.hp or 0, maxHp = enemy and enemy.maxHp or 1,
		position = enemy and enemy.root.Position or world.rooms[run.stage].center,
		name = enemy and enemy.model.Name or "Next opponent...",
	} or nil
	return {
		spirit = d.spirit, trophies = d.trophies, rebirths = d.rebirths, stage = d.stage,
		owned = d.owned, equipped = d.equipped, pets = d.pets, auras = d.auras, aura = d.aura,
		mult = mult, damage = math.floor(mult * 4), swingGain = math.max(1, math.floor(mult * (def and def.mult or 1))),
		mastery = d.mastery, masteryXP = d.masteryXP, masteryNeed = SD.masteryNeed(d.mastery),
		masteryMult = SD.masteryMultiplier(d.mastery), training = id, trainingMult = def and def.mult or 1,
		rebirthCost = SD.rebirthCost(d.rebirths), fight = fight, ver = versions[p] or 0,
		saving = noSave[p] ~= true and saveHealthy[p] ~= false,
	}
end

---------------------------------------------------------------- EQUIPMENT
local function giveSword(p)
	local d = data[p]
	local char, hum = getChar(p)
	local backpack = p:FindFirstChildOfClass("Backpack")
	if not d or not hum or not backpack then return end
	for _, container in {backpack, char} do
		for _, tool in container:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("IsSword") then tool:Destroy() end
		end
	end
	local def = SD.SWORDS[d.equipped]
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.ToolTip = "Swing • " .. def.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("IsSword", true)
	tool:SetAttribute("SwordIndex", d.equipped)
	SD.buildSword(def, tool)
	-- Tool.Activated is handled by GameClient. Never award both here and in the remote.
	tool.Parent = backpack
	hum:EquipTool(tool)
end
local function applyAura(p)
	local d = data[p]
	local _, _, root = getChar(p)
	if not d or not root then return end
	for _, item in root:GetChildren() do
		if item:GetAttribute("AuraFx") then item:Destroy() end
	end
	if d.aura == 0 then return end
	local def = SD.AURAS[d.aura]
	local emitter = Instance.new("ParticleEmitter")
	emitter:SetAttribute("AuraFx", true)
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(def.color)
	emitter.Size = NumberSequence.new(0.55, 0)
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Rate = 16
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Parent = root
	local light = Instance.new("PointLight")
	light:SetAttribute("AuraFx", true)
	light.Color, light.Range, light.Brightness = def.color, 9, 0.7
	light.Parent = root
end

---------------------------------------------------------------- ENEMY MODELS / FEEDBACK
local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.Massless = true
	p.Parent = parent
	return p
end
local function buildEnemy(p, stage, boss, cf)
	local def = SD.STAGES[stage]
	local scale = boss and 1.6 or 1
	local model = Instance.new("Model")
	model.Name = boss and def.boss or def.minion
	model:SetAttribute("OwnerUserId", p.UserId)
	model:SetAttribute("IsEnemy", true)
	local dark = Color3.fromRGB(25, 27, 43)
	local metal = Color3.fromRGB(189, 200, 219)
	local root = part(model, "Root", Vector3.new(2, 2.4, 1) * scale, cf, def.color)
	root.Anchored = true
	model.PrimaryPart = root
	local function add(name, size, position, color, material, rotation)
		local offset = CFrame.new(position * scale) * (rotation or CFrame.identity)
		local item = part(model, name, size * scale, cf * offset, color, material)
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1, weld.C0 = root, item, offset
		weld.Parent = item
		return item
	end
	add("Mask", Vector3.new(1.5, 1.4, 1.3), Vector3.new(0, 1.9, 0), dark)
	for _, x in {-0.36, 0.36} do
		add("Eye", Vector3.new(0.38, 0.14, 0.12), Vector3.new(x, 1.94, -0.67), boss and GOLD or RED, Enum.Material.Neon)
	end
	add("Headband", Vector3.new(1.65, 0.24, 1.4), Vector3.new(0, 2.28, 0), def.color, Enum.Material.Metal)
	add("Belt", Vector3.new(2.15, 0.35, 1.15), Vector3.new(0, -0.85, 0), dark)
	add("ChestRune", Vector3.new(0.38, 0.7, 0.08), Vector3.new(0, 0.2, -0.56), def.color:Lerp(Color3.new(1, 1, 1), 0.5), Enum.Material.Neon,
		CFrame.Angles(0, 0, math.rad(35)))
	for _, x in {-1, 1} do
		add("Arm", Vector3.new(0.7, 2, 0.8), Vector3.new(x * 1.4, -0.05, 0), dark)
		add("Shoulder", Vector3.new(1.15, 0.6, 1.2), Vector3.new(x * 1.45, 0.9, 0), def.color, Enum.Material.Metal,
			CFrame.Angles(0, 0, math.rad(x * -15)))
		add("Leg", Vector3.new(0.85, 2, 0.9), Vector3.new(x * 0.55, -2.2, 0), dark)
		add("Boot", Vector3.new(0.95, 0.5, 1.2), Vector3.new(x * 0.55, -3, -0.1), metal, Enum.Material.Metal)
	end
	add("EnemyBlade", Vector3.new(0.12, 0.45, boss and 4.8 or 3.4), Vector3.new(-1.45, -0.8, -1.6), metal, Enum.Material.Metal)
	add("EnemyEdge", Vector3.new(0.15, 0.09, boss and 4.8 or 3.4), Vector3.new(-1.45, -1.03, -1.6), def.color, Enum.Material.Neon)
	if boss then
		for _, x in {-0.6, 0.6} do
			add("OniHorn", Vector3.new(0.25, 1.45, 0.25), Vector3.new(x, 2.9, 0), GOLD, Enum.Material.Metal,
				CFrame.Angles(0, 0, math.rad(-x * 25)))
		end
		add("Mantle", Vector3.new(2.7, 3.4, 0.2), Vector3.new(0, -0.35, 0.65), def.color:Lerp(dark, 0.35))
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(215, 66)
	gui.StudsOffset = Vector3.new(0, 3.8 * scale, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 100
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 0.65)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = boss and GOLD or Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = (boss and "BOSS • " or "") .. model.Name .. "\n" .. p.DisplayName .. "'s opponent"
	nameLabel.Parent = gui
	local back = Instance.new("Frame")
	back.Position, back.Size = UDim2.fromScale(0, 0.75), UDim2.fromScale(1, 0.18)
	back.BackgroundColor3, back.BorderSizePixel = dark, 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size, fill.BackgroundColor3, fill.BorderSizePixel = UDim2.fromScale(1, 1), boss and GOLD or RED, 0
	fill.Parent = back
	gui.Parent = root
	model.Parent = fxFolder
	return model, root, fill
end
local function hitBurst(root, color, count)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(0.7, 0)
	emitter.Lifetime = NumberRange.new(0.2, 0.45)
	emitter.Speed = NumberRange.new(8, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission, emitter.Rate = 1, 0
	emitter.Parent = root
	emitter:Emit(count or 12)
	Debris:AddItem(emitter, 0.8)
end
local function damageNumber(root, amount)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 38)
	gui.StudsOffset, gui.AlwaysOnTop = Vector3.new(math.random(-8, 8) / 10, 3, 0), true
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Font, label.TextSize = Enum.Font.GothamBlack, 25
	label.TextColor3, label.TextStrokeTransparency = GOLD, 0.1
	label.Text = "−" .. SD.fmt(amount)
	label.Parent, gui.Parent = gui, root
	TweenService:Create(gui, TweenInfo.new(0.65), {StudsOffset = gui.StudsOffset + Vector3.new(0, 3, 0)}):Play()
	TweenService:Create(label, TweenInfo.new(0.65), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	Debris:AddItem(gui, 0.7)
end
local function retireEnemy(enemy, defeated)
	if not enemy or not enemy.model.Parent then return end
	if not defeated then enemy.model:Destroy(); return end
	hitBurst(enemy.root, GOLD, 24)
	for _, object in enemy.model:GetDescendants() do
		if object:IsA("BasePart") then
			TweenService:Create(object, TweenInfo.new(0.3), {Transparency = 1}):Play()
		elseif object:IsA("BillboardGui") then object.Enabled = false end
	end
	Debris:AddItem(enemy.model, 0.55)
end

---------------------------------------------------------------- ROOM RUNS
local function stopFight(p, message)
	local run = fights[p]
	if not run then return end
	fights[p] = nil -- invalidates every delayed damage/spawn/retaliation callback
	retireEnemy(run.enemy, false)
	bump(p)
	if message then toast(p, message, GOLD) end
end
local function teleport(p, cf)
	local char, _, root = getChar(p)
	if not root then return false end
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	char:PivotTo(cf)
	return true
end
local spawnOpponent
spawnOpponent = function(p, run)
	if fights[p] ~= run or not data[p] or not getChar(p) then return end
	local boss = run.step == SD.STAGE_MINIONS + 1
	local spawnCF = world.rooms[run.stage].enemySpawns[run.step]
	-- World spawn positions locate a regular enemy's torso. Lift the boss to keep its boots above the floor.
	if boss then spawnCF += Vector3.new(0, 2, 0) end
	local model, root, fill = buildEnemy(p, run.stage, boss, spawnCF)
	local maxHp = SD.enemyHp(run.stage, boss)
	run.enemy = {model = model, root = root, fill = fill, hp = maxHp, maxHp = maxHp, boss = boss,
		home = spawnCF.Position, nextAttack = os.clock() + 1.4, winding = false}
	bump(p)
end
local function startFight(p, roomIndex, movePlayer)
	local d = data[p]
	roomIndex = index(roomIndex, #SD.STAGES)
	if not d or not roomIndex or not getChar(p) then return end
	if roomIndex > d.stage then
		toast(p, "Defeat the previous room's boss to open this gate.", RED)
		return
	end
	stopFight(p)
	stopTraining(p)
	if movePlayer then teleport(p, world.rooms[roomIndex].spawn) end
	lastRoom[p] = roomIndex
	local run = {stage = roomIndex, step = 1}
	fights[p] = run
	spawnOpponent(p, run)
	toast(p, "ROOM " .. roomIndex .. " • " .. SD.STAGES[roomIndex].name .. " — approach and swing!", CYAN)
end
local function returnHub(p)
	stopFight(p)
	stopTraining(p)
	lastRoom[p] = nil
	teleport(p, world.spawn)
	local _, hum = getChar(p)
	if hum then hum.Health = hum.MaxHealth end
	bump(p)
end
local function defeat(p, run, enemy)
	if fights[p] ~= run or run.enemy ~= enemy or not data[p] then return end
	run.enemy = nil -- exactly one reward path per opponent
	retireEnemy(enemy, true)
	local d = data[p]
	local _, hum = getChar(p)
	if hum then hum.Health = math.min(hum.MaxHealth, hum.Health + 15) end
	local reward = enemy.boss and 0 or math.max(1, math.floor(SD.roomReward(run.stage) * 0.08))
	if reward > 0 then
		addSpirit(p, reward)
		syncRemote:FireClient(p, "Gain", reward)
	end
	if enemy.boss then
		local room, trophies, spirit = run.stage, SD.roomTrophies(run.stage), SD.roomReward(run.stage)
		d.trophies = math.min(1e12, d.trophies + trophies)
		addSpirit(p, spirit)
		if d.stage == room and room < #SD.STAGES then d.stage = room + 1 end
		fights[p] = nil
		if hum then hum.Health = hum.MaxHealth end
		bump(p)
		toast(p, "ROOM CLEAR! +" .. SD.fmt(trophies) .. " Trophies • +" .. SD.fmt(spirit) .. " Spirit", GOLD)
		syncRemote:FireClient(p, "RoomClear", {stage = room, trophies = trophies, spirit = spirit, nextStage = room < #SD.STAGES and room + 1 or nil})
	else
		run.step += 1
		bump(p)
		task.delay(0.55, function() spawnOpponent(p, run) end)
	end
end
local function awardMastery(p, xp)
	local d = data[p]
	local maximum = SD.MAX_MASTERY or 1000
	if d.mastery >= maximum then return end
	d.masteryXP += xp
	local old = d.mastery
	while d.mastery < maximum and d.masteryXP >= SD.masteryNeed(d.mastery) do
		d.masteryXP -= SD.masteryNeed(d.mastery)
		d.mastery += 1
	end
	if d.mastery >= maximum then d.masteryXP = 0 end
	if d.mastery > old then
		bump(p)
		toast(p, "MASTERY " .. d.mastery .. " • permanent x" .. string.format("%.2f", SD.masteryMultiplier(d.mastery)) .. " gain & damage", CYAN)
	end
	dirty[p] = true
end
local function swing(p)
	local now = os.clock()
	if now - (lastSwing[p] or -100) < SD.SWING_COOLDOWN then return end
	local d = data[p]
	local char, _, root = getChar(p)
	if not d or not char then return end
	local tool = char:FindFirstChildWhichIsA("Tool")
	if not tool or not tool:GetAttribute("IsSword") or tool:GetAttribute("SwordIndex") ~= d.equipped then return end
	local combo = now - (lastSwing[p] or -100) < 1.15 and ((combos[p] or 0) % 3 + 1) or 1
	lastSwing[p], combos[p] = now, combo
	local _, station = currentTraining(p)
	local gain = math.max(1, math.floor(getMult(p) * (station and station.mult or 1)))
	addSpirit(p, gain)
	awardMastery(p, station and station.xp or 1)
	syncRemote:FireClient(p, "Gain", gain)
	syncRemote:FireAllClients("Swing", p.UserId, combo)
	if station then
		local stationModel = world.training[training[p]]
		if stationModel and stationModel.prompt and stationModel.prompt.Parent:IsA("BasePart") then
			hitBurst(stationModel.prompt.Parent, station.color, 5)
		end
	end
	local run = fights[p]
	local enemy = run and run.enemy
	if not enemy or enemy.hp <= 0 then return end
	-- Impact happens during the blade's forward phase, not when the input arrives.
	task.delay(0.12, function()
		local c, _, r = getChar(p)
		if not c or c ~= char or tool.Parent ~= c or fights[p] ~= run or run.enemy ~= enemy or enemy.hp <= 0 then return end
		local delta = enemy.root.Position - r.Position
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local forward = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
		local range = SD.ATTACK_RANGE + (enemy.boss and 3 or 0)
		if delta.Magnitude > range or (flat.Magnitude > 0.1 and forward:Dot(flat.Unit) < 0.05) then return end
		local damage = math.max(1, math.floor(getMult(p) * 4 * (combo == 3 and 1.35 or 1)))
		enemy.hp = math.max(0, enemy.hp - damage)
		hitBurst(enemy.root, SD.SWORDS[d.equipped].trail)
		damageNumber(enemy.root, damage)
		TweenService:Create(enemy.fill, TweenInfo.new(0.12), {Size = UDim2.fromScale(enemy.hp / enemy.maxHp, 1)}):Play()
		dirty[p] = true
		if enemy.hp <= 0 then defeat(p, run, enemy) end
	end)
end
local function beginTraining(p, id)
	id = index(id, #SD.TRAINING)
	local d = data[p]
	if not d or not id then return end
	local station, def = world.training[id], SD.TRAINING[id]
	if not station or not near(p, station.center, station.radius + 3) then
		toast(p, "Walk onto the training platform first.", GOLD)
		return
	end
	if d.trophies < def.requiredTrophies then
		toast(p, "Requires " .. SD.fmt(def.requiredTrophies) .. " trophies. Clear more rooms!", RED)
		return
	end
	if training[p] == id then stopTraining(p); return end
	stopFight(p)
	training[p] = id
	bump(p)
	toast(p, def.name .. " • swing for x" .. def.mult .. " Spirit and " .. def.xp .. " mastery XP", CYAN)
end

---------------------------------------------------------------- SHOPS / EXISTING PROGRESSION
local function buySword(p, id)
	local d = data[p]
	id = index(id, #SD.SWORDS)
	if not d or not id or d.owned[tostring(id)] then return end
	local def = SD.SWORDS[id]
	if d.spirit < def.cost then toast(p, "Not enough Spirit.", RED); return end
	d.spirit -= def.cost
	d.owned[tostring(id)], d.equipped = true, id
	giveSword(p)
	bump(p)
	toast(p, "Forged " .. def.name .. "!", CYAN)
end
local function equipSword(p, id)
	local d = data[p]
	id = index(id, #SD.SWORDS)
	if d and id and d.owned[tostring(id)] then
		d.equipped = id
		giveSword(p)
		bump(p)
	end
end
local function hatch(p, id)
	local d = data[p]
	id = index(id, #SD.EGGS)
	if not d or not id then return end
	local egg = SD.EGGS[id]
	if d.spirit < egg.cost then toast(p, "Not enough Spirit.", RED); return end
	local pool, total = {}, 0
	for _, pet in SD.PETS do
		if pet.egg == id then table.insert(pool, pet); total += pet.weight end
	end
	if total <= 0 then return end
	local roll, result = math.random() * total, pool[#pool]
	for _, pet in pool do
		roll -= pet.weight
		if roll <= 0 then result = pet; break end
	end
	d.spirit -= egg.cost
	d.pets[result.name] = (d.pets[result.name] or 0) + 1
	bump(p)
	syncRemote:FireClient(p, "Hatch", result.name, result.rarity)
end
local function auraAction(p, id)
	local d = data[p]
	id = index(id, #SD.AURAS)
	if not d or not id then return end
	local def = SD.AURAS[id]
	if not d.auras[tostring(id)] then
		if d.spirit < def.cost then toast(p, "Not enough Spirit.", RED); return end
		d.spirit -= def.cost
		d.auras[tostring(id)] = true
	end
	d.aura = d.aura == id and 0 or id
	applyAura(p)
	bump(p)
end
local function rebirth(p)
	local d = data[p]
	local cost = SD.rebirthCost(d.rebirths)
	if d.spirit < cost then toast(p, "Rebirth requires " .. SD.fmt(cost) .. " Spirit.", RED); return end
	if d.rebirths >= 100 then toast(p, "Maximum rebirth reached.", GOLD); return end
	stopFight(p)
	d.rebirths += 1
	d.spirit, d.owned, d.equipped = 0, {["1"] = true}, 1
	giveSword(p)
	bump(p)
	toast(p, "REBIRTH " .. d.rebirths .. " • +50% permanent bonus. Mastery, rooms and trophies kept!", GOLD)
end
local function redeem(p, code)
	if type(code) ~= "string" or #code > 64 then return end
	code = string.upper((string.gsub(code, "%s", "")))
	local d, def = data[p], SD.CODES[code]
	if not def then toast(p, "Unknown code.", RED)
	elseif d.codes[code] then toast(p, "Already redeemed.", GOLD)
	else
		d.codes[code] = true
		addSpirit(p, def.spirit or 0)
		bump(p)
		toast(p, "Code redeemed! +" .. SD.fmt(def.spirit or 0) .. " Spirit", CYAN)
	end
end

actionRemote.OnServerEvent:Connect(function(p, action, arg)
	if not data[p] or type(action) ~= "string" then return end
	local now = os.clock()
	if action == "Swing" then swing(p); return end
	if action == "RequestState" then
		if now - (lastRequest[p] or -100) >= 1 then
			lastRequest[p] = now
			syncRemote:FireClient(p, "State", snapshot(p))
		end
		return
	end
	if now - (lastAction[p] or -100) < 0.15 then return end
	lastAction[p] = now
	if action == "BuySword" then buySword(p, arg)
	elseif action == "EquipSword" then equipSword(p, arg)
	elseif action == "Hatch" then hatch(p, arg)
	elseif action == "Aura" then auraAction(p, arg)
	elseif action == "Rebirth" then rebirth(p)
	elseif action == "Redeem" then redeem(p, arg)
	elseif action == "Fight" or action == "Travel" then startFight(p, arg, true)
	elseif action == "StopFight" then stopFight(p, "Run stopped. Use the room sign to retry.")
	elseif action == "ReturnHub" then returnHub(p)
	elseif action == "Train" then beginTraining(p, arg)
	elseif action == "StopTraining" then stopTraining(p) end
end)

---------------------------------------------------------------- PROXIMITY PROMPTS
local function promptPosition(prompt)
	local parent = prompt.Parent
	if parent:IsA("Attachment") then return parent.WorldPosition end
	if parent:IsA("BasePart") then return parent.Position end
	if parent:IsA("Model") then return parent:GetPivot().Position end
	return nil
end
local function bindPrompt(prompt, callback)
	if not prompt then return end
	prompt.Triggered:Connect(function(p)
		if not data[p] then return end
		local position = promptPosition(prompt)
		if position and near(p, position, prompt.MaxActivationDistance + 3) then
			local now = os.clock()
			if now - (lastAction[p] or -100) < 0.15 then return end
			lastAction[p] = now
			callback(p)
		end
	end)
end
for id, station in world.training do
	bindPrompt(station.prompt, function(p) beginTraining(p, id) end)
end
for id, prompt in world.roomPrompts do
	bindPrompt(prompt, function(p) startFight(p, id, true) end)
end
for _, prompt in world.returnPrompts do
	bindPrompt(prompt, returnHub)
end
for tab, prompt in world.hubPrompts do
	bindPrompt(prompt, function(p) syncRemote:FireClient(p, "Open", tab) end)
end

---------------------------------------------------------------- SAVE / LOAD (never overwrite after a failed read)
local function loadPlayer(p)
	local ok, result
	for attempt = 1, 3 do
		local blocked = false
		ok, result = pcall(function()
			return store:UpdateAsync("p_" .. p.UserId, function(previous)
				local value = type(previous) == "table" and table.clone(previous) or defaultData()
				local lease = value._session
				if type(lease) == "table" and type(lease.id) == "string" and lease.id ~= SESSION_ID
					and finite(lease.updated) and os.time() - lease.updated < SESSION_LEASE then
					blocked = true
					return nil -- cancel: another live server owns this save
				end
				blocked = false
				value._session = {id = SESSION_ID, updated = os.time()}
				return value
			end)
		end)
		if ok and blocked then
			sessionBlocked[p] = true
			ok = false
			break
		end
		if ok then break end
		warn("Sword save read/claim failed for " .. p.UserId .. " (attempt " .. attempt .. ").")
		if attempt < 3 then task.wait(attempt) end
	end
	if not ok then noSave[p], saveHealthy[p] = true, false end
	return sanitize(ok and result or nil)
end
local function savePlayer(p, release)
	if not data[p] or noSave[p] or released[p] then return end
	-- Serialize saves for this player; departure must wait for an in-flight autosave.
	while saving[p] do task.wait(0.1) end
	if not data[p] or noSave[p] or released[p] then return end
	saving[p] = true
	local value = copySave(data[p])
	local ok, ownershipLost
	for attempt = 1, 3 do
		ownershipLost = false
		ok = pcall(function()
			store:UpdateAsync("p_" .. p.UserId, function(previous)
				local lease = type(previous) == "table" and previous._session
				if type(lease) ~= "table" or lease.id ~= SESSION_ID then
					ownershipLost = true
					return nil -- never overwrite a save claimed by another server
				end
				ownershipLost = false
				if release then
					value._session = nil
				else
					value._session = {id = SESSION_ID, updated = os.time()}
				end
				return value
			end)
		end)
		if ok and ownershipLost then
			noSave[p] = true
			ok = false
			warn("Sword save ownership changed for " .. p.UserId .. "; further writes disabled.")
			break
		end
		if ok then break end
		warn("Sword save write failed for " .. p.UserId .. " (attempt " .. attempt .. ").")
		if attempt < 3 then task.wait(attempt) end
	end
	saveHealthy[p], saving[p] = ok == true, nil
	if ok and release then released[p] = true end
	if data[p] then dirty[p] = true end
	if not ok then toast(p, "Saving is unavailable. Keep this session open and check Studio API access.", RED) end
end
local function onCharacter(p, char)
	local hum = char:WaitForChild("Humanoid", 15)
	local root = char:WaitForChild("HumanoidRootPart", 15)
	local backpack = p:WaitForChild("Backpack", 15)
	if not hum or not root or not backpack or not data[p] or p.Character ~= char then return end
	stopFight(p)
	stopTraining(p)
	lastRoom[p] = nil
	teleport(p, world.spawn)
	hum.WalkSpeed = 24
	giveSword(p)
	applyAura(p)
	hum.Died:Connect(function()
		if p.Character ~= char then return end
		stopFight(p)
		stopTraining(p)
		lastRoom[p] = nil
		toast(p, "Defeated — returning to the sanctuary. Your progress is safe.", GOLD)
	end)
	bump(p)
end
local function onPlayer(p)
	if loaded[p] then return end
	loaded[p] = true
	local d = loadPlayer(p)
	if p.Parent ~= Players then
		-- A player can leave during the yielding load. Release only the claim we acquired.
		if not noSave[p] then
			data[p] = d
			savePlayer(p, true)
			data[p] = nil
		end
		loaded[p], noSave[p], saveHealthy[p], released[p], sessionBlocked[p] = nil, nil, nil, nil, nil
		return
	end
	data[p], versions[p] = d, 1
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in {"Power", "Trophies", "Rebirths"} do
		local value = Instance.new("NumberValue")
		value.Name, value.Parent = name, stats
	end
	stats.Parent = p
	p.CharacterAdded:Connect(function(char) task.spawn(onCharacter, p, char) end)
	if p.Character then task.spawn(onCharacter, p, p.Character) end
	if SD.GROUP_ID > 0 then
		local success, member = pcall(function() return p:IsInGroup(SD.GROUP_ID) end)
		inGroup[p] = success and member == true
	end
	local elapsed = math.clamp(os.time() - d.lastSeen, 0, 8 * 3600)
	local offlineGain = math.floor(elapsed * getMult(p) * 0.25)
	d.lastSeen = os.time()
	if offlineGain > 0 then addSpirit(p, offlineGain) end
	bump(p)
	task.delay(4, function()
		if not data[p] then return end
		if sessionBlocked[p] then
			toast(p, "Another server owns your save. This is a temporary practice session; rejoin after leaving the other session.", GOLD)
		elseif noSave[p] then
			toast(p, "Practice session: saving unavailable. Publish and enable Studio API access to test saves.", GOLD)
		elseif offlineGain > 0 then
			toast(p, "Welcome back! +" .. SD.fmt(offlineGain) .. " offline Spirit", CYAN)
		end
	end)
end
Players.PlayerAdded:Connect(function(p) task.spawn(onPlayer, p) end)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p)
	stopFight(p)
	stopTraining(p)
	savePlayer(p, true)
	data[p], dirty[p], versions[p], loaded[p], lastRoom[p] = nil, nil, nil, nil, nil
	lastSwing[p], combos[p], lastAction[p], lastRequest[p] = nil, nil, nil, nil
	inGroup[p], noSave[p], saveHealthy[p], released[p], sessionBlocked[p] = nil, nil, nil, nil, nil
end)
game:BindToClose(function()
	closing = true
	local pending = 0
	for p in data do
		pending += 1
		task.spawn(function() savePlayer(p, true); pending -= 1 end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end)

---------------------------------------------------------------- MOVEMENT / ENEMY TELEGRAPHS / SYNC
local function roomAt(pos)
	if math.abs(pos.X) > 55 or pos.Y < -8 or pos.Y > 35 then return nil end
	for i, room in world.rooms do
		if math.abs(pos.Z - room.center.Z) <= 64 then return i end
	end
	return nil
end
local function checkMovement(p)
	local _, _, root = getChar(p)
	if not root then return end
	if root.Position.Y < -25 then returnHub(p); return end
	local room = roomAt(root.Position)
	local d = data[p]
	-- Also guard the connecting bridge before an unopened room, not just the arena.
	if root.Position.Z < world.rooms[d.stage].center.Z - 65 and d.stage < #SD.STAGES then
		stopFight(p)
		teleport(p, world.rooms[d.stage].spawn)
		lastRoom[p] = nil
		toast(p, "Gate sealed. Defeat your current room's boss first.", RED)
		return
	end
	if room and room > d.stage then
		stopFight(p)
		teleport(p, world.rooms[d.stage].spawn)
		lastRoom[p] = nil
		return
	end
	if room ~= lastRoom[p] then
		local run = fights[p]
		if run and run.stage ~= room then stopFight(p) end
		lastRoom[p] = room
		if room then startFight(p, room, false) end
	end
	currentTraining(p)
end
local function updateEnemy(p, dt)
	local run = fights[p]
	local enemy = run and run.enemy
	if not enemy or enemy.hp <= 0 or not enemy.root.Parent then return end
	local _, hum, root = getChar(p)
	if not root then stopFight(p); return end
	local now = os.clock()
	local delta = root.Position - enemy.root.Position
	local flat = Vector3.new(delta.X, 0, delta.Z)
	-- A small advance gives each opponent presence without dragging it out of its room.
	if flat.Magnitude > 5 and flat.Magnitude < 24 and not enemy.winding then
		local nextPos = enemy.root.Position + flat.Unit * math.min(dt * 5, flat.Magnitude - 5)
		if (nextPos - enemy.home).Magnitude <= 13 then
			enemy.root.CFrame = CFrame.lookAt(nextPos, Vector3.new(root.Position.X, nextPos.Y, root.Position.Z))
		end
	elseif flat.Magnitude > 0.2 and not enemy.winding then
		enemy.root.CFrame = CFrame.lookAt(enemy.root.Position, Vector3.new(root.Position.X, enemy.root.Position.Y, root.Position.Z))
	end
	if flat.Magnitude > 10 or math.abs(delta.Y) > 9 or enemy.winding or now < enemy.nextAttack then return end
	enemy.winding, enemy.nextAttack = true, now + (enemy.boss and 1.8 or 2.2)
	local flash = Instance.new("Highlight")
	flash.FillColor, flash.OutlineColor = RED, RED
	flash.FillTransparency, flash.OutlineTransparency = 0.55, 0.1
	flash.Parent = enemy.model
	Debris:AddItem(flash, 0.5)
	-- Telegraph grants time to move away; damage is checked again at impact.
	task.delay(0.45, function()
		if fights[p] ~= run or run.enemy ~= enemy or enemy.hp <= 0 then return end
		enemy.winding = false
		local _, currentHum, currentRoot = getChar(p)
		if not currentRoot then return end
		if (currentRoot.Position - enemy.root.Position).Magnitude <= (enemy.boss and 12 or 10) then
			currentHum:TakeDamage((7 + run.stage * 1.1) * (enemy.boss and 1.6 or 1))
			hitBurst(currentRoot, RED, 7)
		end
	end)
end
task.spawn(function()
	local previous, lastSave = os.clock(), os.clock()
	while not closing do
		task.wait(0.15)
		local now = os.clock()
		local dt = math.min(0.3, now - previous)
		previous = now
		for p in data do
			if p.Parent == Players then checkMovement(p); updateEnemy(p, dt) end
		end
		for p in dirty do
			dirty[p] = nil
			if data[p] and p.Parent == Players then
				updateLeaderstats(p)
				syncRemote:FireClient(p, "State", snapshot(p))
			end
		end
		if now - lastSave >= 60 then
			lastSave = now
			for p in data do
				if not saving[p] then task.spawn(savePlayer, p) end
			end
		end
	end
end)
