--[[
	SwordData  (ModuleScript)  ->  put in ReplicatedStorage and NAME IT exactly: SwordData
	Shared by the server and the client:
	  * 14 original anime weapons with distinct silhouettes; no external model assets
	  * stages, enemy HP formula, eggs/pets, auras, rebirth cost, number formatting
]]

local M = {}

M.GROUP_ID = 0 -- put your Roblox group id here for a +10% group bonus (0 = off)
M.STAGE_MINIONS = 5
M.SWING_COOLDOWN = 0.42
M.ATTACK_RANGE = 13
M.MAX_MASTERY = 100

-- Rewards belong to completed rooms, never to a client-supplied amount.
function M.roomTrophies(stage)
	return math.floor(5 * 1.65 ^ (math.clamp(stage, 1, 15) - 1))
end

function M.roomReward(stage)
	return math.floor(200 * 2.5 ^ (math.clamp(stage, 1, 15) - 1))
end

function M.masteryNeed(level)
	return math.floor(35 * 1.18 ^ math.clamp(level, 0, M.MAX_MASTERY))
end

function M.masteryMultiplier(level)
	return 1 + 0.08 * math.clamp(level, 0, M.MAX_MASTERY)
end

---------------------------------------------------------------- HELPERS
local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function M.fmt(n)
	n = math.floor(n or 0)
	if n < 1000 then return tostring(n) end
	local i = 1
	while n >= 1000 and i < #SUFFIX do
		n /= 1000
		i += 1
	end
	return string.format("%.2f%s", n, SUFFIX[i])
end

function M.enemyHp(stage, boss)
	local base = 30 * 1.9 ^ (stage - 1)
	return math.floor(boss and base * 6 or base)
end

function M.rebirthCost(rebirths)
	return 100000 * 3 ^ rebirths
end

---------------------------------------------------------------- SWORDS
local c = Color3.fromRGB
local mat = Enum.Material

-- cost = Spirit price, mult = how much it multiplies your Spirit per click and your damage
M.SWORDS = {
	{ name = "Rusty Katana", cost = 0, mult = 1, length = 3.6, width = 0.55,
		blade = c(150, 150, 155), material = mat.Metal, guard = "disc", guardColor = c(60, 60, 60),
		handle = c(90, 60, 40), wrap = c(35, 28, 24), trail = c(210, 210, 210) },

	{ name = "Jade Wind Blade", cost = 250, mult = 2, length = 3.8, width = 0.55,
		blade = c(90, 200, 150), material = mat.SmoothPlastic, edge = c(170, 255, 210), guard = "disc", guardColor = c(230, 200, 90),
		handle = c(30, 90, 60), wrap = c(20, 60, 40), trail = c(140, 255, 190), fx = "wind" },

	{ name = "Crimson Fang", cost = 1500, mult = 4, length = 4.0, width = 0.6, serrated = true,
		blade = c(120, 20, 30), material = mat.Metal, edge = c(255, 50, 60), guard = "cross", guardColor = c(30, 30, 30),
		handle = c(40, 20, 20), wrap = c(150, 20, 30), trail = c(255, 60, 70), fx = "ember" },

	{ name = "Frost Saber", cost = 8000, mult = 7, length = 4.2, width = 0.6,
		blade = c(190, 235, 255), material = mat.Ice, edge = c(255, 255, 255), guard = "wings", guardColor = c(140, 200, 255),
		handle = c(60, 90, 130), wrap = c(220, 240, 255), trail = c(170, 230, 255), fx = "snow" },

	{ name = "Thunder Tachi", cost = 30000, mult = 12, length = 4.6, width = 0.5,
		blade = c(255, 235, 90), material = mat.Neon, guard = "disc", guardColor = c(50, 50, 60),
		handle = c(30, 30, 40), wrap = c(255, 220, 60), trail = c(255, 240, 120), fx = "spark" },

	{ name = "Shadow Wakizashi", cost = 100000, mult = 20, length = 3.8, width = 0.5,
		blade = c(30, 20, 40), material = mat.Metal, edge = c(170, 80, 255), guard = "cross", guardColor = c(20, 20, 30),
		handle = c(20, 15, 30), wrap = c(110, 40, 190), trail = c(170, 90, 255), fx = "smoke" },

	{ name = "Solar Claymore", cost = 350000, mult = 35, length = 5.2, width = 1.0,
		blade = c(255, 200, 60), material = mat.Metal, edge = c(255, 120, 20), guard = "wings", guardColor = c(255, 190, 40),
		handle = c(120, 60, 20), wrap = c(255, 140, 30), trail = c(255, 180, 50), fx = "fire" },

	{ name = "Sakura Edge", cost = 1000000, mult = 60, length = 4.4, width = 0.55,
		blade = c(255, 205, 225), material = mat.SmoothPlastic, edge = c(255, 120, 170), guard = "disc", guardColor = c(255, 150, 190),
		handle = c(120, 50, 80), wrap = c(255, 170, 200), trail = c(255, 160, 200), fx = "petals" },

	{ name = "Void Reaper", cost = 3000000, mult = 100, length = 5.0, width = 0.7, hook = true,
		blade = c(25, 10, 45), material = mat.Neon, edge = c(200, 60, 255), guard = "cross", guardColor = c(15, 10, 25),
		handle = c(15, 10, 25), wrap = c(130, 30, 200), trail = c(190, 70, 255), fx = "void" },

	{ name = "Twin Dragon Glaive", cost = 9000000, mult = 170, length = 3.6, width = 0.6, double = true,
		blade = c(60, 180, 120), material = mat.Metal, edge = c(255, 230, 100), guard = "disc", guardColor = c(230, 190, 60),
		handle = c(70, 40, 20), wrap = c(30, 110, 70), trail = c(120, 255, 170), fx = "ember" },

	{ name = "Celestial Blade", cost = 25000000, mult = 300, length = 5.4, width = 0.7, halo = true,
		blade = c(250, 250, 255), material = mat.SmoothPlastic, edge = c(255, 230, 130), guard = "wings", guardColor = c(255, 215, 90),
		handle = c(200, 180, 120), wrap = c(255, 255, 255), trail = c(255, 240, 170), fx = "stars" },

	{ name = "Phoenix Saber", cost = 70000000, mult = 520, length = 5.2, width = 0.7,
		blade = c(255, 120, 40), material = mat.Neon, edge = c(255, 230, 90), guard = "wings", guardColor = c(200, 50, 20),
		handle = c(90, 20, 10), wrap = c(255, 150, 40), trail = c(255, 150, 40), fx = "fire" },

	{ name = "Abyss Cleaver", cost = 200000000, mult = 900, length = 6.0, width = 1.3, serrated = true,
		blade = c(15, 15, 20), material = mat.Slate, edge = c(255, 40, 40), guard = "cross", guardColor = c(40, 10, 10),
		handle = c(20, 10, 10), wrap = c(200, 20, 20), trail = c(255, 50, 50), fx = "smoke" },

	{ name = "Astral Sovereign", cost = 600000000, mult = 1600, length = 6.4, width = 0.8, halo = true,
		blade = c(190, 170, 255), material = mat.Neon, edge = c(255, 255, 255), guard = "wings", guardColor = c(255, 225, 120),
		handle = c(60, 40, 110), wrap = c(255, 225, 120), trail = c(210, 190, 255), fx = "stars" },
}

-- Design is geometry, not just a palette swap. Each family has a separate profile.
local DESIGNS = {
	{ "ronin", "Worn / I", "Common", "An heirloom blade with a chipped steel edge." },
	{ "leaf", "Gale / II", "Uncommon", "A leaf-forged split tip and jade crescent guard." },
	{ "fang", "Bloodmoon / III", "Rare", "Five crimson teeth tear across a blackened spine." },
	{ "crystal", "Glacier / IV", "Rare", "A crystalline rapier crowned by six ice shards." },
	{ "lightning", "Raijin / V", "Epic", "An angular lightning blade held in a storm wheel." },
	{ "shadow", "Nightfall / VI", "Epic", "An offset twin-edge shortblade with a chain tassel." },
	{ "sun", "Daybreak / VII", "Legendary", "A broad sun cleaver with a radiant disc guard." },
	{ "sakura", "Bloom / VIII", "Legendary", "A curved blossom katana with a petal tsuba." },
	{ "reaper", "Eclipse / IX", "Mythic", "A crescent hook catches the light of a dying star." },
	{ "dragon", "Jade Oath / X", "Mythic", "Twin dragon heads guard opposing gilded blades." },
	{ "celestial", "Seraph / XI", "Mythic", "An open-center angel blade between floating wings." },
	{ "phoenix", "Ashfall / XII", "Secret", "A fan of flame feathers rises from a molten core." },
	{ "cleaver", "Oblivion / XIII", "Secret", "An immense executioner's slab with a broken spine." },
	{ "astral", "Sovereign / XIV", "Celestial", "Four floating starsteel segments orbit a royal seal." },
}
for i, design in DESIGNS do
	local def = M.SWORDS[i]
	def.design, def.title, def.rarity, def.description = table.unpack(design)
end

local TEX = {
	sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}

-- All components are welded to Handle; works as a Tool and in a ViewportFrame.
-- Blade points along local -Z, thickness X and cutting profile Y.
function M.buildSword(def, container)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.32, 0.32, 1.5)
	handle.Color = def.handle
	handle.Material = mat.Fabric
	handle.CanCollide, handle.CanTouch, handle.CanQuery = false, false, false
	handle.Massless = true
	handle.Parent = container
	if container:IsA("Model") then container.PrimaryPart = handle end
	local edge = def.edge or def.trail
	local design = def.design or "ronin"
	local length, width = def.length, def.width
	local function part(name, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Name, p.Size = name, size
		p.Color, p.Material = color, material or mat.Metal
		if shape then p.Shape = shape end
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.Massless, p.CastShadow = true, false
		p.CFrame = handle.CFrame * cf
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = handle, p, p
		p.Parent = container
		return p
	end
	local function bar(name, y, z, wide, long, color, angle, thickness, material)
		return part(name, Vector3.new(thickness or 0.15, wide, long),
			CFrame.new(0, y, z) * CFrame.Angles(math.rad(angle or 0), 0, 0), color, material)
	end
	local function gem(y, z, scale, color)
		return part("SpiritGem", Vector3.one * scale, CFrame.new(0, y, z)
			* CFrame.Angles(math.rad(45), math.rad(45), 0), color, mat.Neon)
	end
	-- An actual open ring: unlike a solid cylinder, the silhouette has a clear void.
	local function ring(name, y, z, radius, count, color, roll)
		for i = 1, count do
			local a = (i / count) * math.pi * 2 + (roll or 0)
			part(name, Vector3.new(0.17, 2 * radius * math.sin(math.pi / count) + 0.035, 0.13),
				CFrame.new(0, y + math.cos(a) * radius, z + math.sin(a) * radius)
				* CFrame.Angles(a + math.pi / 2, 0, 0), color, mat.Neon)
		end
	end
	local function feather(y, z, size, angle, color)
		bar("Feather", y, z, size * 0.26, size, color, angle)
		bar("FeatherVein", y, z, 0.05, size * 0.85, edge, angle, 0.18, mat.Neon)
	end
	local function katana(curve, broad, dir)
		dir = dir or -1
		local segments = 8
		for i = 1, segments do
			local t = (i - 0.5) / segments
			local taper = i == segments and 0.45 or (1 - t * 0.22)
			local y = curve * t * t
			local z = dir * (0.96 + length * t)
			local angle = -dir * math.deg(math.atan(2 * curve * t / length))
			bar("BladeSegment", y, z, broad * taper, length / segments + 0.07, def.blade, angle, 0.15, def.material)
			bar("HamonEdge", y - broad * taper * 0.43, z, 0.055, length / segments + 0.055, edge, angle, 0.18, mat.Neon)
		end
	end
	-- Braided grip, metal collars, jewel pommel, and a hand guard on every design.
	for i = 1, 7 do
		part("GripBraid", Vector3.new(0.37, 0.37, 0.08), CFrame.new(0, 0, -0.62 + i * 0.17)
			* CFrame.Angles(0, 0, math.rad(i % 2 == 0 and 35 or -35)), def.wrap, mat.Fabric)
	end
	bar("Fuchi", 0, -0.72, 0.46, 0.12, def.guardColor, 0, 0.44)
	bar("Pommel", 0, 0.8, 0.46, 0.2, def.guardColor, 0, 0.44)
	gem(0, 0.96, 0.24, edge)
	bar("Guard", 0, -0.9, 1.4, 0.18, def.guardColor, 0, 0.35)

	if design == "ronin" then
		katana(0.22, width)
		for i = 1, 3 do bar("SteelNotch", width * 0.25, -1.25 - i * 0.55, 0.06, 0.14, def.wrap, 35) end
		bar("LeatherTie", -0.26, 1.13, 0.12, 0.6, def.wrap, -25, 0.1, mat.Fabric)
	elseif design == "leaf" then
		katana(0.55, width)
		for sign = -1, 1, 2 do
			feather(sign * 0.52, -0.92, 1.15, sign * 45, def.guardColor)
			feather(sign * 0.19 + 0.5, -0.95 - length * 0.84, 1.1, sign * 19, def.blade)
		end
		gem(0, -1.15, 0.34, edge)
	elseif design == "fang" then
		bar("BlackSpine", 0, -1 - length / 2, width, length, def.blade)
		for i = 1, 5 do
			local z = -1.1 - i * length / 5.7
			bar("BloodTooth", -width * 0.42, z, 0.35, 0.65, edge, -34, 0.18, mat.Neon)
		end
		bar("PiercingTip", 0, -1.1 - length, width * 0.6, 0.8, def.blade, -28)
		bar("FangGuard", 0.72, -0.85, 0.2, 0.7, edge, 40)
	elseif design == "crystal" then
		bar("IceCore", 0, -1 - length / 2, width * 0.5, length, def.blade, 0, 0.22, mat.Glass)
		for i = 1, 6 do
			local sign = i % 2 == 0 and 1 or -1
			feather(sign * 0.32, -1.1 - i * length / 7, 1.25, sign * 22, def.blade)
		end
		ring("FrostCrown", 0, -0.95, 0.72, 6, edge)
		gem(0, -1 - length, 0.42, edge)
	elseif design == "lightning" then
		local seg = length / 7
		for i = 1, 7 do
			local y = i % 2 == 0 and 0.17 or -0.17
			bar("Bolt", y, -1 - (i - 0.5) * seg, 0.25, seg + 0.22, edge, i % 2 == 0 and 28 or -28, 0.18, mat.Neon)
			bar("StormSpine", y + 0.18, -1 - (i - 0.5) * seg, 0.18, seg + 0.22, def.guardColor, i % 2 == 0 and 28 or -28)
		end
		ring("StormWheel", 0, -0.9, 0.85, 8, edge)
		for i = 1, 3 do bar("PommelBolt", i * 0.16, 0.8 + i * 0.28, 0.08, 0.4, edge, -28, 0.1, mat.Neon) end
	elseif design == "shadow" then
		katana(-0.28, width)
		bar("OffhandEdge", 0.7, -2.1, 0.25, 2.2, def.blade, 12)
		bar("OffhandGlow", 0.55, -2.1, 0.045, 2.2, edge, 12, 0.18, mat.Neon)
		for i = 1, 5 do ring("ChainLink", 0, 0.9 + i * 0.18, 0.14, 6, def.guardColor, i % 2) end
		gem(0, 2.05, 0.4, edge)
	elseif design == "sun" then
		katana(0, width * 1.6)
		ring("SunSeal", 0, -1, 1.05, 14, edge)
		for i = 1, 8 do
			local a = i * math.pi / 4
			bar("SolarRay", math.cos(a) * 1.25, -1 + math.sin(a) * 1.25, 0.17, 0.5, def.guardColor, math.deg(a) + 90)
		end
		bar("SolarRune", 0, -2.7, 0.18, 2.4, edge, 0, 0.2, mat.Neon)
	elseif design == "sakura" then
		katana(0.85, width * 0.8)
		for i = 1, 5 do
			local a = i * math.pi * 2 / 5
			feather(math.cos(a) * 0.52, -0.9 + math.sin(a) * 0.52, 0.74, math.deg(a) + 90, def.guardColor)
		end
		bar("SilkRibbon", 0.16, 1.4, 0.17, 1.1, edge, -24, 0.07, mat.Fabric)
		bar("SilkRibbon", -0.16, 1.4, 0.17, 1.1, def.wrap, 24, 0.07, mat.Fabric)
	elseif design == "reaper" then
		bar("ReaperSpine", 0, -1 - length / 2, width * 0.6, length, def.blade)
		-- Five angled pieces form a visible sickle rather than a recolored katana.
		for i = 1, 5 do
			local a = math.rad(-70 + i * 29)
			local y = 1 + math.cos(a) * 1.1
			local z = -length + math.sin(a) * 1.1
			bar("EclipseHook", y, z, 0.35, 0.7, def.blade, math.deg(a), 0.23)
			bar("EclipseRim", y - 0.14, z, 0.06, 0.7, edge, math.deg(a), 0.26, mat.Neon)
		end
		gem(0, -1.2, 0.5, edge)
	elseif design == "dragon" then
		katana(0.35, width, -1)
		katana(-0.35, width, 1)
		bar("RearGuard", 0, 0.9, 1.4, 0.18, def.guardColor)
		for sign = -1, 1, 2 do
			bar("DragonJaw", sign * 0.53, sign * 1.2, 0.35, 0.9, def.guardColor, sign * 25)
			bar("DragonHorn", sign * 0.73, sign * 0.85, 0.15, 0.8, def.blade, sign * -35)
			gem(sign * 0.53, sign * 1.5, 0.18, edge)
		end
	elseif design == "celestial" then
		for sign = -1, 1, 2 do
			bar("SeraphEdge", sign * 0.32, -1 - length / 2, 0.23, length, def.blade, sign * -3)
			bar("SeraphLight", sign * 0.45, -1 - length / 2, 0.05, length, edge, sign * -3, 0.18, mat.Neon)
			for i = 1, 3 do feather(sign * (0.45 + i * 0.3), -0.8 - i * 0.15, 1.2 - i * 0.12, sign * 55, def.guardColor) end
		end
		ring("AngelHalo", 0, -1.1, 1.05, 16, edge)
		gem(0, -1 - length, 0.45, edge)
	elseif design == "phoenix" then
		katana(0.3, width)
		for i = 1, 7 do
			feather(0.25 + i * 0.065, -1.15 - i * length / 8, 1.2, -25 - i * 3, i % 2 == 0 and edge or def.blade)
		end
		for sign = -1, 1, 2 do
			for i = 1, 3 do feather(sign * (0.3 + i * 0.28), -0.72 + i * 0.12, 0.9, sign * 60, def.guardColor) end
		end
	elseif design == "cleaver" then
		bar("ExecutionerSlab", 0, -1 - length / 2, width * 1.4, length, def.blade, 0, 0.35, mat.Slate)
		bar("OblivionEdge", -width * 0.68, -1 - length / 2, 0.1, length, edge, 0, 0.38, mat.Neon)
		for i = 1, 5 do bar("BrokenSpine", width * 0.78, -1.4 - i * length / 6, 0.45, 0.55, def.blade, -35, 0.35) end
		ring("ExecutionSeal", 0, -2, 0.55, 8, edge)
		bar("IronCrossguard", 0, -0.85, 2.5, 0.36, def.guardColor, 0, 0.5)
	elseif design == "astral" then
		for i = 1, 4 do
			local z = -1.15 - (i - 0.5) * length / 4
			local w = width * (1.3 - i * 0.17)
			bar("FloatingStarsteel", 0, z, w, length / 4 - 0.18, def.blade, i % 2 == 0 and 7 or -7, 0.2, mat.Metal)
			bar("AstralCore", 0, z, 0.1, length / 4 - 0.1, edge, 0, 0.24, mat.Neon)
			gem(0, z + length / 8, 0.16, edge)
		end
		ring("RoyalOrbit", 0, -1, 1.15, 18, def.guardColor)
		ring("InnerOrbit", 0, -1, 0.75, 12, edge, 0.3)
		for sign = -1, 1, 2 do feather(sign * 1.1, -1, 1.4, sign * 65, def.guardColor) end
	end

	-- A stable attachment at each end of the striking edge; only enabled during strikes.
	local a0 = Instance.new("Attachment")
	a0.Name, a0.Position, a0.Parent = "TrailBase", Vector3.new(0, 0, -1), handle
	local a1 = Instance.new("Attachment")
	a1.Name, a1.Position, a1.Parent = "TrailTip", Vector3.new(0, 0, -1 - length), handle
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime, trail.MinLength = 0.16, 0.05
	trail.Color = ColorSequence.new(edge, def.trail)
	trail.Transparency = NumberSequence.new(0.12, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.LightEmission, trail.Enabled = 1, false
	trail.Parent = handle
	if def.fx then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "BladeMotes"
		emitter.Texture = TEX[def.fx == "fire" and "fire" or "sparkles"]
		emitter.Color = ColorSequence.new(def.trail)
		emitter.Size = NumberSequence.new(0.13, 0)
		emitter.Transparency = NumberSequence.new(0.3, 1)
		emitter.Lifetime, emitter.Speed = NumberRange.new(0.25, 0.6), NumberRange.new(0.2, 0.8)
		emitter.Rate, emitter.LightEmission = 4, 0.9
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.Parent = a1
	end
	container:SetAttribute("Design", design)
	container:SetAttribute("TrailColor", def.trail)
	return handle
end

M.TRAINING = {
	{ name = "Bamboo Fundamentals", requiredTrophies = 0, mult = 1.5, xp = 2,
		color = c(104, 227, 155), description = "Practice on a wrapped bamboo dummy. 1.5x Spirit / 2 mastery XP per swing." },
	{ name = "Stone Resolve", requiredTrophies = 25, mult = 3, xp = 4,
		color = c(98, 186, 255), description = "Split the engraved stone monument. 3x Spirit / 4 mastery XP per swing." },
	{ name = "Storm Meditation", requiredTrophies = 250, mult = 8, xp = 8,
		color = c(195, 142, 255), description = "Channel a suspended lightning core. 8x Spirit / 8 mastery XP per swing." },
	{ name = "Solar Ascension", requiredTrophies = 2000, mult = 20, xp = 16,
		color = c(255, 190, 70), description = "Master the floating solar blade shrine. 20x Spirit / 16 mastery XP per swing." },
}

---------------------------------------------------------------- STAGES
M.STAGES = {
	{ name = "Training Grounds", minion = "Dojo Dummy", boss = "Sensei Golem", color = c(170, 130, 90) },
	{ name = "Bamboo Forest", minion = "Bamboo Bandit", boss = "Bandit Chief", color = c(90, 170, 90) },
	{ name = "Misty Village", minion = "Mist Ronin", boss = "Ronin Captain", color = c(150, 170, 190) },
	{ name = "Frozen Peak", minion = "Frost Wraith", boss = "Ice Warden", color = c(120, 200, 240) },
	{ name = "Thunder Plains", minion = "Storm Ninja", boss = "Thunder Daimyo", color = c(230, 210, 70) },
	{ name = "Crimson Temple", minion = "Blood Monk", boss = "Crimson Abbot", color = c(190, 40, 50) },
	{ name = "Shadow Valley", minion = "Shade Assassin", boss = "Shadow Lord", color = c(80, 55, 120) },
	{ name = "Sunken Ruins", minion = "Drowned Samurai", boss = "Tide Shogun", color = c(50, 140, 160) },
	{ name = "Sky Citadel", minion = "Cloud Guard", boss = "Sky General", color = c(210, 225, 245) },
	{ name = "Lava Caverns", minion = "Magma Brute", boss = "Magma Titan", color = c(230, 100, 30) },
	{ name = "Spirit Realm", minion = "Lost Spirit", boss = "Soul Reaper", color = c(150, 120, 230) },
	{ name = "Dragon Nest", minion = "Drake Cultist", boss = "Elder Drake", color = c(60, 170, 120) },
	{ name = "Void Rift", minion = "Void Stalker", boss = "Rift Tyrant", color = c(100, 35, 150) },
	{ name = "Celestial Gate", minion = "Star Sentinel", boss = "Gate Archon", color = c(250, 230, 150) },
	{ name = "Throne of Swords", minion = "Blade Phantom", boss = "The Sword Emperor", color = c(200, 200, 215) },
}

-- Each room gets physical scenery and an increasingly valuable boss chest.
local themes = { "dojo", "bamboo", "village", "snow", "storm", "temple", "shadow", "ruins", "sky", "lava", "spirit", "dragon", "void", "celestial", "throne" }
for i, stage in M.STAGES do
	stage.theme = themes[i]
	stage.trophies = M.roomTrophies(i)
	stage.reward = M.roomReward(i)
end

---------------------------------------------------------------- EGGS + PETS
-- bonus = extra multiplier (0.10 = +10%). The best 3 pets you own are active.
M.EGGS = {
	{ name = "Bamboo Egg", cost = 1500 },
	{ name = "Celestial Egg", cost = 250000 },
}

M.PETS = {
	{ name = "Fox Spirit", rarity = "Common", bonus = 0.10, egg = 1, weight = 40 },
	{ name = "Paper Crane", rarity = "Common", bonus = 0.10, egg = 1, weight = 30 },
	{ name = "Tiny Oni", rarity = "Uncommon", bonus = 0.25, egg = 1, weight = 15 },
	{ name = "Koi Wisp", rarity = "Rare", bonus = 0.60, egg = 1, weight = 10 },
	{ name = "Lantern Cat", rarity = "Epic", bonus = 1.5, egg = 1, weight = 4 },
	{ name = "Golden Kirin", rarity = "Legendary", bonus = 4, egg = 1, weight = 1 },

	{ name = "Moon Rabbit", rarity = "Uncommon", bonus = 1.0, egg = 2, weight = 40 },
	{ name = "Storm Fox", rarity = "Rare", bonus = 2.5, egg = 2, weight = 30 },
	{ name = "Jade Tiger", rarity = "Epic", bonus = 6, egg = 2, weight = 20 },
	{ name = "Phoenix Chick", rarity = "Legendary", bonus = 20, egg = 2, weight = 8 },
	{ name = "Celestial Dragon", rarity = "Mythic", bonus = 60, egg = 2, weight = 2 },
}

M.PET_BY_NAME = {}
for _, pet in M.PETS do
	M.PET_BY_NAME[pet.name] = pet
end

---------------------------------------------------------------- AURAS
M.AURAS = {
	{ name = "Ember Glow", cost = 5000, bonus = 0.25, color = c(255, 140, 60) },
	{ name = "Frost Veil", cost = 120000, bonus = 0.75, color = c(140, 210, 255) },
	{ name = "Storm Crown", cost = 2500000, bonus = 2, color = c(255, 235, 90) },
	{ name = "Shadow Mantle", cost = 50000000, bonus = 5, color = c(150, 70, 230) },
	{ name = "Sakura Storm", cost = 1000000000, bonus = 12, color = c(255, 150, 190) },
	{ name = "Celestial Radiance", cost = 30000000000, bonus = 30, color = c(255, 240, 170) },
}

---------------------------------------------------------------- CODES
-- Add your own codes here (spirit = reward). Each player can redeem a code once.
M.CODES = {
	WELCOME = { spirit = 1000 },
	SWORDS = { spirit = 25000 },
	LAUNCH = { spirit = 100000 },
}

return M
