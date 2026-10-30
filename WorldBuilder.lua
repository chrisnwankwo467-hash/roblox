--!strict
-- WorldBuilder (ModuleScript) -> ServerScriptService. All geometry is original,
-- built from Roblox primitives; no external assets or Studio plugins are needed.
-- This module only builds the world and exposes prompts. GameServer owns access,
-- combat, rewards and training. Decorative gates never block other players.

local Lighting = game:GetService("Lighting")
local W = {}
local C = Color3.fromRGB
local MAT = Enum.Material
local DARK = C(27, 31, 48)
local GOLD = C(255, 205, 108)
local WOOD = C(84, 52, 49)
local STONE = C(79, 87, 107)

local function part(parent, name, size, cf, color, material, shape, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or MAT.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide ~= false
	p.CanTouch = false
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function block(parent, name, size, pos, color, material, rotation, collide)
	return part(parent, name, size, CFrame.new(pos) * (rotation or CFrame.identity), color, material, nil, collide)
end

local function cylinder(parent, name, radius, height, pos, color, material, collide)
	return part(parent, name, Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder, collide)
end

local function ball(parent, name, size, pos, color, material, collide)
	return part(parent, name, size, CFrame.new(pos), color, material, Enum.PartType.Ball, collide)
end

local function sign(parent, text, pos, width, height, accent, fontSize)
	local backing = block(parent, "Sign", Vector3.new(width, height, 0.35), pos, DARK, MAT.SmoothPlastic, nil, false)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Lettering"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 35
		gui.LightInfluence = 0
		gui.Parent = backing
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = text
		label.TextColor3 = accent or GOLD
		label.Font = Enum.Font.GothamBold
		label.TextSize = fontSize or 28
		label.TextScaled = true
		label.TextWrapped = true
		label.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 12)
		padding.PaddingRight = UDim.new(0, 12)
		padding.PaddingTop = UDim.new(0, 6)
		padding.PaddingBottom = UDim.new(0, 6)
		padding.Parent = label
	end
	return backing
end

local function prompt(parent, text, object, distance)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = text
	p.ObjectText = object
	p.HoldDuration = 0.18
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.Parent = parent
	return p
end

local function lantern(parent, pos, accent, tall)
	local h = tall and 8 or 5
	local m = model(parent, "SpiritLantern")
	block(m, "Foot", Vector3.new(2, 0.5, 2), pos + Vector3.new(0, 0.25, 0), STONE, MAT.Slate)
	block(m, "Post", Vector3.new(0.45, h, 0.45), pos + Vector3.new(0, h / 2, 0), WOOD, MAT.Wood)
	local lamp = block(m, "PaperGlow", Vector3.new(1.65, 2.1, 1.65), pos + Vector3.new(0, h + 0.1, 0), accent, MAT.Neon, nil, false)
	block(m, "Cap", Vector3.new(2.2, 0.3, 2.2), pos + Vector3.new(0, h + 1.3, 0), DARK, MAT.Slate)
	block(m, "Base", Vector3.new(2.05, 0.22, 2.05), pos + Vector3.new(0, h - 1.05, 0), DARK, MAT.Slate)
	local light = Instance.new("PointLight")
	light.Color = accent
	light.Range = 17
	light.Brightness = 0.65
	light.Shadows = false
	light.Parent = lamp
end

local function torii(parent, pos, accent, width)
	width = width or 34
	local m = model(parent, "SpiritGate")
	for _, side in { -1, 1 } do
		block(m, "GatePillar", Vector3.new(1.9, 18, 1.9), pos + Vector3.new(side * width / 2, 9, 0), accent, MAT.Wood)
		block(m, "StoneFoot", Vector3.new(3.8, 1, 3.8), pos + Vector3.new(side * width / 2, 0.5, 0), DARK, MAT.Slate)
		block(m, "EaveTip", Vector3.new(7, 1.2, 3.5), pos + Vector3.new(side * (width / 2 + 1.5), 19.2, 0), DARK, MAT.Slate,
			CFrame.Angles(0, 0, math.rad(side * 12)))
	end
	block(m, "UpperBeam", Vector3.new(width + 7, 1.5, 3), pos + Vector3.new(0, 18.5, 0), DARK, MAT.Slate)
	block(m, "LowerBeam", Vector3.new(width + 4, 1, 1.6), pos + Vector3.new(0, 14.3, 0), accent, MAT.Wood)
	block(m, "Keystone", Vector3.new(2, 3.5, 0.7), pos + Vector3.new(0, 16.1, 0), GOLD, MAT.Metal, nil, false)
	return m
end

local function bridge(parent, zNear, zFar, accent)
	local length = math.abs(zNear - zFar)
	local z = (zNear + zFar) / 2
	block(parent, "BridgeDeck", Vector3.new(28, 1.5, length + 2), Vector3.new(0, -0.75, z), WOOD, MAT.WoodPlanks)
	for _, side in { -1, 1 } do
		block(parent, "BridgeRail", Vector3.new(0.5, 0.55, length), Vector3.new(side * 13, 4.2, z), accent, MAT.Wood)
		block(parent, "BridgeRail", Vector3.new(0.4, 0.4, length), Vector3.new(side * 13, 2.2, z), accent, MAT.Wood)
		for j = 0, 3 do
			block(parent, "BridgePost", Vector3.new(0.8, 4.5, 0.8), Vector3.new(side * 13, 2.25, zNear + (zFar - zNear) * j / 3), DARK, MAT.Wood)
		end
	end
	for j = 1, 6 do
		block(parent, "DeckSeam", Vector3.new(25, 0.04, 0.15), Vector3.new(0, 0.025, zNear + (zFar - zNear) * j / 7), C(153, 110, 79), MAT.Wood, nil, false)
	end
end

local function tree(parent, pos, foliage, scale, blossoms)
	scale = scale or 1
	local m = model(parent, blossoms and "SakuraTree" or "SpiritTree")
	block(m, "Trunk", Vector3.new(1.7, 9, 1.7) * scale, pos + Vector3.new(0, 4.5, 0) * scale, WOOD, MAT.Wood)
	for i = 1, 3 do
		local direction = i * math.pi * 2 / 3
		local off = Vector3.new(math.cos(direction) * 3.2, 9 + i * 0.8, math.sin(direction) * 3.2) * scale
		ball(m, "Canopy", Vector3.new(10, 6.8, 10) * scale, pos + off, foliage, MAT.Grass, false)
	end
	if blossoms then
		for i = 1, 3 do
			block(m, "FallenPetals", Vector3.new(3, 0.07, 2.2) * scale, pos + Vector3.new(-5 + i * 2.8, 0.07, i * 1.8), foliage, MAT.SmoothPlastic, nil, false)
		end
	end
end

local function bamboo(parent, pos, accent, count)
	local m = model(parent, "BambooGrove")
	for i = 1, count or 3 do
		local x, z = (i % 2) * 2.2, i * 1.5
		local h = 14 + (i % 3) * 2.5
		cylinder(m, "Bamboo", 0.48, h, pos + Vector3.new(x, h / 2, z), accent, MAT.Wood)
		for j = 1, 3 do
			cylinder(m, "Joint", 0.57, 0.22, pos + Vector3.new(x, j * h / 4, z), C(42, 88, 66), MAT.Wood)
		end
		block(m, "Leaves", Vector3.new(5, 0.3, 1), pos + Vector3.new(x + 1.4, h - 1.5, z), C(102, 179, 91), MAT.Grass,
			CFrame.Angles(0, 0, math.rad(25)), false)
	end
end

local function rock(parent, pos, size, color, crystal)
	local m = model(parent, crystal and "SpiritCrystal" or "RockOutcrop")
	block(m, "Stone", size, pos + Vector3.new(0, size.Y * 0.42, 0), color, crystal and MAT.Glass or MAT.Slate,
		CFrame.Angles(math.rad(9), math.rad(25), math.rad(11)))
	if crystal then
		local shard = block(m, "CrystalCore", size * Vector3.new(0.22, 1.18, 0.2), pos + Vector3.new(0, size.Y * 0.55, 0), color, MAT.Neon,
			CFrame.Angles(0, 0, math.rad(-12)), false)
		shard.Transparency = 0.18
	end
end

local function shrine(parent, pos, accent, scale)
	scale = scale or 1
	local m = model(parent, "WayfarerShrine")
	block(m, "Plinth", Vector3.new(15, 1, 13) * scale, pos + Vector3.new(0, 0.5, 0) * scale, STONE, MAT.Slate)
	block(m, "Floor", Vector3.new(12, 0.5, 10) * scale, pos + Vector3.new(0, 1.25, 0) * scale, WOOD, MAT.WoodPlanks)
	for _, x in { -5, 5 } do
		for _, z in { -4, 4 } do
			block(m, "Pillar", Vector3.new(0.9, 8, 0.9) * scale, pos + Vector3.new(x, 5.4, z) * scale, accent, MAT.Wood)
		end
	end
	block(m, "BackWall", Vector3.new(10, 6, 0.6) * scale, pos + Vector3.new(0, 4.5, 4) * scale, WOOD, MAT.Wood)
	for _, side in { -1, 1 } do
		block(m, "SlopedRoof", Vector3.new(9, 0.7, 13) * scale, pos + Vector3.new(side * 3.7, 10.5, 0) * scale, DARK, MAT.Slate,
			CFrame.Angles(0, 0, math.rad(side * -18)))
	end
	block(m, "Ridge", Vector3.new(1, 0.8, 14) * scale, pos + Vector3.new(0, 11.7, 0) * scale, GOLD, MAT.Metal)
end

local THEMES = {
	"dojo", "bamboo", "village", "ice", "thunder", "temple", "shadow", "water",
	"sky", "lava", "spirit", "dragon", "void", "celestial", "throne",
}

local function decorateRoom(parent, center, theme, accent, index)
	local floor = C(111, 130, 117)
	local floorMaterial = MAT.Grass
	if theme == "ice" then floor, floorMaterial = C(204, 226, 238), MAT.Snow
	elseif theme == "lava" or theme == "void" or theme == "shadow" then floor, floorMaterial = C(53, 46, 65), MAT.Basalt
	elseif theme == "sky" or theme == "celestial" or theme == "throne" then floor, floorMaterial = C(193, 205, 219), MAT.Marble
	elseif theme == "temple" or theme == "dojo" or theme == "village" then floor, floorMaterial = C(138, 123, 116), MAT.Cobblestone
	elseif theme == "water" then floor, floorMaterial = C(84, 121, 132), MAT.Slate
	elseif theme == "dragon" then floor, floorMaterial = C(92, 118, 100), MAT.Grass end

	block(parent, "IslandFoundation", Vector3.new(110, 8, 128), center + Vector3.new(0, -4, 0), floor, floorMaterial)
	block(parent, "LowerFoundation", Vector3.new(96, 10, 115), center + Vector3.new(0, -12, 0), DARK, MAT.Slate)
	block(parent, "CentralRoad", Vector3.new(24, 0.12, 128), center + Vector3.new(0, 0.06, 0), C(163, 160, 159), MAT.Cobblestone, nil, false)
	for _, side in { -1, 1 } do
		block(parent, "IslandRim", Vector3.new(1, 0.75, 128), center + Vector3.new(side * 54, 0.4, 0), accent, MAT.Slate)
		for j = 1, 4 do
			block(parent, "BoundaryPost", Vector3.new(1.2, 4.5, 1.2), center + Vector3.new(side * 52, 2.25, -70 + j * 28), DARK, MAT.Slate)
		end
		block(parent, "BoundaryRail", Vector3.new(0.45, 0.45, 112), center + Vector3.new(side * 52, 3.1, 0), STONE, MAT.Metal)
		for _, dz in { -41, 37 } do lantern(parent, center + Vector3.new(side * 25, 0, dz), accent, true) end
	end
	-- A pair of glyph-lined paths keeps the combat route readable in every biome.
	for j = 1, 5 do
		for _, side in { -1, 1 } do
			block(parent, "PathGlyph", Vector3.new(0.25, 0.04, 6), center + Vector3.new(side * 11.3, 0.15, -60 + j * 20), accent, MAT.Neon, nil, false)
		end
	end

	if theme == "dojo" then
		shrine(parent, center + Vector3.new(-38, 0, -25), accent, 1.1)
		shrine(parent, center + Vector3.new(38, 0, 22), accent, 1.1)
		for _, side in { -1, 1 } do
			for _, dz in { -46, 44 } do tree(parent, center + Vector3.new(side * 40, 0, dz), C(233, 147, 178), 0.8, true) end
		end
	elseif theme == "bamboo" then
		for _, side in { -1, 1 } do
			for j = 1, 4 do bamboo(parent, center + Vector3.new(side * (35 + j % 2 * 7), 0, -63 + j * 25), C(77, 142, 77), 3) end
		end
		rock(parent, center + Vector3.new(-35, 0, 3), Vector3.new(12, 7, 9), C(95, 113, 103))
	elseif theme == "village" then
		for _, side in { -1, 1 } do
			for _, dz in { -29, 28 } do
				shrine(parent, center + Vector3.new(side * 39, 0, dz), C(114, 148, 167), 1.1)
			end
		end
	elseif theme == "ice" then
		for _, side in { -1, 1 } do
			for j = 1, 4 do
				rock(parent, center + Vector3.new(side * (35 + (j % 2) * 7), 0, -65 + j * 25), Vector3.new(7, 9 + j * 2, 7), C(145, 216, 245), true)
			end
		end
		for _, side in { -1, 1 } do
			block(parent, "FrozenPool", Vector3.new(17, 0.12, 30), center + Vector3.new(side * 34, 0.09, 8), C(129, 206, 232), MAT.Ice, nil, false)
		end
	elseif theme == "thunder" then
		for _, side in { -1, 1 } do
			for _, dz in { -35, 29 } do
				local p = center + Vector3.new(side * 38, 0, dz)
				cylinder(parent, "StormPylon", 2, 13, p + Vector3.new(0, 6.5, 0), DARK, MAT.Metal)
				ball(parent, "StormOrb", Vector3.new(5, 5, 5), p + Vector3.new(0, 15, 0), accent, MAT.Neon, false)
				for j = 1, 3 do
					block(parent, "LightningRune", Vector3.new(0.3, 4.5, 0.5), p + Vector3.new(0, 9 + j * 3, -2.2), GOLD, MAT.Neon, CFrame.Angles(0, 0, math.rad(j % 2 == 0 and -35 or 35)), false)
				end
			end
		end
	elseif theme == "temple" then
		shrine(parent, center + Vector3.new(-38, 0, -24), C(184, 54, 65), 1.35)
		shrine(parent, center + Vector3.new(38, 0, 22), C(184, 54, 65), 1.35)
		for _, dz in { -40, 32 } do torii(parent, center + Vector3.new(0, 0, dz), accent, 37) end
	elseif theme == "shadow" or theme == "spirit" then
		for _, side in { -1, 1 } do
			for j = 1, 3 do
				tree(parent, center + Vector3.new(side * (38 + j % 2 * 5), 0, -63 + j * 33), theme == "shadow" and C(88, 59, 122) or C(159, 151, 216), 1.05)
				ball(parent, "SpiritWisp", Vector3.new(1.7, 1.7, 1.7), center + Vector3.new(side * 30, 5 + j, -65 + j * 33), accent, MAT.Neon, false)
			end
		end
	elseif theme == "water" then
		for _, side in { -1, 1 } do
			local water = block(parent, "TideCanal", Vector3.new(19, 0.18, 110), center + Vector3.new(side * 38, 0.12, 0), C(58, 167, 185), MAT.Glass, nil, false)
			water.Transparency = 0.22
			for j = 1, 4 do
				local p = center + Vector3.new(side * 39, 0, -65 + j * 27)
				cylinder(parent, "RuinedColumn", 1.7, 7 + j % 3 * 3, p + Vector3.new(0, 4, 0), C(135, 165, 168), MAT.Marble)
			end
		end
	elseif theme == "sky" or theme == "celestial" then
		for _, side in { -1, 1 } do
			for j = 1, 3 do
				local p = center + Vector3.new(side * 40, 0, -62 + j * 32)
				cylinder(parent, "MarbleColumn", 1.4, 15, p + Vector3.new(0, 7.5, 0), C(228, 232, 239), MAT.Marble)
				cylinder(parent, "Capital", 2.3, 0.6, p + Vector3.new(0, 15.2, 0), GOLD, MAT.Metal)
				ball(parent, "Cloud", Vector3.new(18, 7, 13), p + Vector3.new(side * 16, -5, 0), C(225, 231, 242), MAT.SmoothPlastic, false)
			end
		end
		if theme == "celestial" then
			for j = 1, 8 do
				local angle = j / 8 * math.pi * 2
				local pos = center + Vector3.new(math.cos(angle) * 22, 26 + math.sin(angle) * 13, -50)
				block(parent, "AstralRingSegment", Vector3.new(9, 0.65, 0.65), pos, GOLD, MAT.Neon, CFrame.Angles(0, 0, angle + math.pi / 2), false)
			end
		end
	elseif theme == "lava" then
		for _, side in { -1, 1 } do
			block(parent, "LavaChannel", Vector3.new(17, 0.14, 112), center + Vector3.new(side * 39, 0.1, 0), C(255, 93, 32), MAT.Neon, nil, false)
			for j = 1, 4 do
				rock(parent, center + Vector3.new(side * (33 + j % 2 * 10), 0, -67 + j * 25), Vector3.new(8, 8 + j * 2, 9), C(54, 48, 57))
			end
		end
	elseif theme == "dragon" then
		for _, side in { -1, 1 } do
			local p = center + Vector3.new(side * 37, 0, -19)
			rock(parent, p, Vector3.new(15, 12, 18), C(68, 100, 88))
			-- Stylized original guardian dragon: coiled plinth, angular head, twin antlers.
			ball(parent, "DragonHead", Vector3.new(7, 5, 9), p + Vector3.new(0, 13, -2), C(72, 149, 117), MAT.Slate)
			block(parent, "DragonJaw", Vector3.new(5, 2, 6), p + Vector3.new(0, 11, -6), C(88, 166, 130), MAT.Slate)
			for _, hornSide in { -1, 1 } do
				block(parent, "GoldenAntler", Vector3.new(0.8, 7, 0.8), p + Vector3.new(hornSide * 2, 18, 0), GOLD, MAT.Metal, CFrame.Angles(0, 0, math.rad(hornSide * -20)))
				ball(parent, "DragonEye", Vector3.new(0.8, 0.8, 0.8), p + Vector3.new(hornSide * 2, 13.7, -5.5), GOLD, MAT.Neon, false)
			end
		end
	elseif theme == "void" then
		for _, side in { -1, 1 } do
			for j = 1, 4 do
				local p = center + Vector3.new(side * (36 + j % 2 * 9), 3 + j % 2 * 3, -65 + j * 25)
				rock(parent, p, Vector3.new(5, 12, 5), accent, true)
			end
		end
		for j = 1, 7 do
			local angle = j / 7 * math.pi * 2
			block(parent, "RiftFrame", Vector3.new(8, 0.9, 2), center + Vector3.new(math.cos(angle) * 11, 15 + math.sin(angle) * 11, -54), accent, MAT.Neon, CFrame.Angles(0, 0, angle + math.pi / 2), false)
		end
	elseif theme == "throne" then
		for _, side in { -1, 1 } do
			for j = 1, 4 do
				local p = center + Vector3.new(side * 39, 0, -65 + j * 25)
				cylinder(parent, "ImperialPillar", 1.4, 18, p + Vector3.new(0, 9, 0), C(201, 204, 223), MAT.Marble)
				block(parent, "SwordMonumentBlade", Vector3.new(0.4, 9, 1.5), p + Vector3.new(-side * 7, 7, 0), C(230, 232, 243), MAT.Metal)
				block(parent, "SwordMonumentGuard", Vector3.new(0.7, 0.8, 5), p + Vector3.new(-side * 7, 11.5, 0), GOLD, MAT.Metal)
			end
		end
		block(parent, "ImperialThrone", Vector3.new(10, 13, 3), center + Vector3.new(0, 6.5, -60), GOLD, MAT.Metal)
		block(parent, "VelvetBack", Vector3.new(7, 9, 0.4), center + Vector3.new(0, 7.5, -58.3), C(92, 45, 124), MAT.Fabric)
		block(parent, "ThroneSeat", Vector3.new(10, 2, 6), center + Vector3.new(0, 2.5, -57), GOLD, MAT.Metal)
	end
	-- Each boss has a visible floor seal without interfering with movement.
	cylinder(parent, "BossSealOuter", 10, 0.08, center + Vector3.new(0, 0.1, -47), accent, MAT.Neon, false)
	cylinder(parent, "BossSealInner", 9.4, 0.09, center + Vector3.new(0, 0.15, -47), floor, floorMaterial, false)
	for j = 1, 4 do
		local angle = j * math.pi / 2
		block(parent, "BossSealRune", Vector3.new(2, 0.05, 2), center + Vector3.new(math.cos(angle) * 7.5, 0.22, -47 + math.sin(angle) * 7.5), accent, MAT.Neon, CFrame.Angles(0, math.rad(45), 0), false)
	end
end

local function trainingStation(parent, definition, id, x)
	local center = Vector3.new(x, 0, 35)
	local m = model(parent, "Training_" .. id)
	m:SetAttribute("TrainingId", id)
	local accent = definition.color or C(126, 218, 221)
	cylinder(m, "TrainingZone", 11.5, 0.12, center + Vector3.new(0, 0.08, 0), accent, MAT.Neon, false)
	cylinder(m, "Mat", 10.9, 0.14, center + Vector3.new(0, 0.12, 0), C(49, 55, 69), MAT.Slate, false)
	local station = center + Vector3.new(0, 0, -4)
	if id == 1 then
		block(m, "PracticePost", Vector3.new(1.5, 6.5, 1.5), station + Vector3.new(0, 3.25, 0), WOOD, MAT.Wood)
		block(m, "CrossArms", Vector3.new(7, 1.15, 1.15), station + Vector3.new(0, 4, 0), C(161, 120, 80), MAT.Wood)
		ball(m, "PracticeMask", Vector3.new(2.8, 2.8, 2.8), station + Vector3.new(0, 6.8, 0), C(235, 208, 161), MAT.Wood)
		for _, side in { -1, 1 } do block(m, "MaskEye", Vector3.new(0.4, 0.2, 0.1), station + Vector3.new(side * 0.6, 6.9, 1.34), DARK, MAT.SmoothPlastic, nil, false) end
	elseif id == 2 then
		cylinder(m, "BoulderBase", 4.2, 1.4, station + Vector3.new(0, 0.7, 0), STONE, MAT.Slate)
		rock(m, station + Vector3.new(0, 1.4, 0), Vector3.new(6, 5, 5), C(127, 151, 155))
		for j = 1, 3 do block(m, "CutMarks", Vector3.new(0.1, 3.6, 0.2), station + Vector3.new(-1.5 + j * 0.7, 3.8, 2.55), accent, MAT.Neon, CFrame.Angles(0, 0, math.rad(-23)), false) end
	elseif id == 3 then
		for _, side in { -1, 1 } do
			block(m, "FocusPillar", Vector3.new(1.3, 9, 1.3), station + Vector3.new(side * 4, 4.5, 0), DARK, MAT.Metal)
			ball(m, "FocusCrystal", Vector3.new(2.5, 3.5, 2.5), station + Vector3.new(side * 4, 10, 0), accent, MAT.Neon, false)
		end
		ball(m, "SuspendedCore", Vector3.new(4, 4, 4), station + Vector3.new(0, 6.3, 0), accent, MAT.Neon, false)
		for j = 1, 6 do
			local angle = j * math.pi / 3
			block(m, "FocusHalo", Vector3.new(2.6, 0.25, 0.25), station + Vector3.new(math.cos(angle) * 3.8, 6.3 + math.sin(angle) * 3.8, 0), GOLD, MAT.Metal, CFrame.Angles(0, 0, angle + math.pi / 2), false)
		end
	else
		cylinder(m, "AscensionPlinth", 4.5, 1.2, station + Vector3.new(0, 0.6, 0), DARK, MAT.Marble)
		for j = 1, 5 do
			local angle = j / 5 * math.pi * 2
			rock(m, station + Vector3.new(math.cos(angle) * 3.8, 2, math.sin(angle) * 3.8), Vector3.new(0.9, 4, 0.9), accent, true)
		end
		ball(m, "AscensionHeart", Vector3.new(3.6, 3.6, 3.6), station + Vector3.new(0, 5.5, 0), GOLD, MAT.Neon, false)
	end
	local text = definition.name .. "\nx" .. tostring(definition.mult or 1) .. " SPIRIT • " .. tostring(definition.xp or 1) .. " MASTERY XP"
	text ..= "\n" .. (definition.requiredTrophies == 0 and "FREE TRAINING" or tostring(definition.requiredTrophies) .. " TROPHIES REQUIRED")
	sign(m, text, center + Vector3.new(0, 11.8, -5), 17, 4.7, accent)
	-- Interaction stays at character height, reachable across the training mat.
	local interaction = block(m, "TrainingPrompt", Vector3.new(1, 1, 1), center + Vector3.new(0, 2, 0), accent, MAT.SmoothPlastic, nil, false)
	interaction.Transparency = 1
	interaction.CanQuery = false
	local p = prompt(interaction, "Start training", definition.name, 16)
	p:SetAttribute("TrainingId", id)
	return { id = id, center = center, radius = 12, prompt = p }
end

local function hubStand(parent, name, pos, color, subtitle)
	local m = model(parent, name .. "Stand")
	cylinder(m, "Plinth", 9, 0.7, pos + Vector3.new(0, 0.35, 0), STONE, MAT.Slate)
	cylinder(m, "Trim", 7.5, 0.74, pos + Vector3.new(0, 0.4, 0), color, MAT.Neon, false)
	cylinder(m, "Top", 7, 0.8, pos + Vector3.new(0, 0.45, 0), DARK, MAT.Slate)
	local plaque = sign(m, string.upper(name) .. "\n" .. subtitle, pos + Vector3.new(0, 10, -3.5), 17, 4, color)
	return m, prompt(plaque, "Open " .. name, "Bladebound Sanctuary", 18)
end

function W.build(SD)
	local previous = workspace:FindFirstChild("AnimeSwordWorld")
	if previous then previous:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "AnimeSwordWorld"
	folder.Parent = workspace
	local result = {
		folder = folder,
		spawn = CFrame.new(0, 4, 45),
		rooms = {}, training = {}, roomPrompts = {}, returnPrompts = {}, hubPrompts = {},
	}

	Lighting.ClockTime = 16.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = C(123, 128, 155)
	Lighting.OutdoorAmbient = C(146, 154, 180)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChild("SpiritbladeAtmosphere")
	if not atmosphere then atmosphere = Instance.new("Atmosphere"); atmosphere.Name = "SpiritbladeAtmosphere"; atmosphere.Parent = Lighting end
	atmosphere.Density = 0.24
	atmosphere.Offset = 0.15
	atmosphere.Color = C(193, 210, 236)
	atmosphere.Decay = C(114, 123, 153)
	atmosphere.Haze = 0.75
	local bloom = Lighting:FindFirstChild("SpiritbladeBloom")
	if not bloom then bloom = Instance.new("BloomEffect"); bloom.Name = "SpiritbladeBloom"; bloom.Parent = Lighting end
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.24, 22, 1.3

	local hub = model(folder, "SpiritbladeSanctuary")
	block(hub, "SanctuaryIsland", Vector3.new(142, 8, 160), Vector3.new(0, -4, 0), C(128, 142, 133), MAT.Grass)
	block(hub, "SanctuaryUnderside", Vector3.new(124, 14, 142), Vector3.new(0, -14, 0), DARK, MAT.Slate)
	block(hub, "SanctuaryPlaza", Vector3.new(126, 0.15, 125), Vector3.new(0, 0.075, 0), C(170, 166, 160), MAT.Cobblestone, nil, false)
	block(hub, "RoadToAdventure", Vector3.new(28, 0.18, 160), Vector3.new(0, 0.1, 0), C(207, 196, 178), MAT.Cobblestone, nil, false)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SanctuarySpawn"
	spawn.Size = Vector3.new(9, 0.25, 9)
	spawn.CFrame = CFrame.new(0, 0.28, 62)
	spawn.Transparency = 1
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.CanCollide = false
	spawn.Parent = hub
	torii(hub, Vector3.new(0, 0, -64), C(178, 66, 80), 38)
	sign(hub, "BLADEBOUND\nSPIRIT TRIALS • 15 realms. One sovereign.", Vector3.new(0, 24, -64), 43, 5, GOLD)
	sign(hub, "COMBAT ROOMS  ↑\nDefeat each guardian to unlock the next realm", Vector3.new(0, 10, -45), 26, 4.2, C(162, 226, 245))
	for _, side in { -1, 1 } do
		for _, z in { -63, 61 } do tree(hub, Vector3.new(side * 60, 0, z), C(244, 153, 186), 1.25, true) end
		for _, z in { -44, 5, 64 } do lantern(hub, Vector3.new(side * 63, 0, z), GOLD, true) end
		block(hub, "SanctuaryRail", Vector3.new(0.6, 0.8, 152), Vector3.new(side * 69, 3, 0), WOOD, MAT.Wood)
		for j = 1, 7 do block(hub, "SanctuaryPost", Vector3.new(1, 4.5, 1), Vector3.new(side * 69, 2.25, -87 + j * 22), WOOD, MAT.Wood) end
	end
	local trainingX = { -44, -16, 16, 44 }
	for i, def in SD.TRAINING do result.training[i] = trainingStation(hub, def, i, trainingX[i]) end

	local swords, swordsPrompt = hubStand(hub, "Swords", Vector3.new(-41, 0, -27), C(112, 214, 247), "FORGE YOUR LEGEND")
	result.hubPrompts.Swords = swordsPrompt
	for i, swordIndex in { 2, 7, 14 } do
		local def = SD.SWORDS[swordIndex]
		if def then
			local display = Instance.new("Model")
			display.Name = "Display_" .. def.name
			SD.buildSword(def, display)
			for _, obj in display:GetDescendants() do
				if obj:IsA("BasePart") then obj.Anchored = true; obj.CanCollide = false end
				if obj:IsA("ParticleEmitter") then obj.Rate = math.min(obj.Rate, 5) end
			end
			display.Parent = swords
			display:PivotTo(CFrame.new(-47 + i * 3, 4, -27) * CFrame.Angles(math.rad(-90), 0, math.rad(-20 + i * 10)))
		end
	end
	local pets, petsPrompt = hubStand(hub, "Pets", Vector3.new(41, 0, -27), C(245, 167, 214), "SPIRIT COMPANIONS")
	result.hubPrompts.Pets = petsPrompt
	for i = 1, 3 do
		local egg = ball(pets, "SpiritEgg", Vector3.new(2.7, 3.8, 2.7), Vector3.new(35 + i * 3, 3, -27), ({ C(156, 230, 191), C(243, 178, 218), GOLD })[i], MAT.Glass, false)
		block(pets, "EggBand", Vector3.new(2.8, 0.25, 2.8), egg.Position, GOLD, MAT.Metal, CFrame.Angles(0, math.rad(45), 0), false)
	end
	local auras, auraPrompt = hubStand(hub, "Auras", Vector3.new(41, 0, -3), C(185, 157, 249), "AWAKEN YOUR SPIRIT")
	result.hubPrompts.Auras = auraPrompt
	for j = 1, 8 do
		local angle = j / 8 * math.pi * 2
		ball(auras, "AuraMote", Vector3.new(0.7, 0.7, 0.7), Vector3.new(41 + math.cos(angle) * 4.2, 4.8 + math.sin(angle) * 3, -3), C(185, 157, 249), MAT.Neon, false)
	end
	sign(hub, "TRAINING COURT\nUse E at a station, then swing to gain Spirit and sword mastery.\nMastery permanently raises that sword's training increment.", Vector3.new(-41, 6, 0), 23, 5.5, C(157, 232, 208))

	bridge(folder, -80, -136, C(181, 75, 85))
	for i, def in SD.STAGES do
		local center = Vector3.new(0, 0, -(i * 160 + 40))
		local room = model(folder, ("Room_%02d_%s"):format(i, def.name))
		room:SetAttribute("RoomIndex", i)
		local theme = THEMES[i] -- Stable biome identity even when stage display names are customized.
		local accent = def.color
		decorateRoom(room, center, theme, accent, i)
		local entry = CFrame.new(center + Vector3.new(0, 4, 72))
		local gate = torii(room, center + Vector3.new(0, 0, 61), accent, 34)
		sign(gate, ("ROOM %02d • %s\n+%s TROPHIES • +%s SPIRIT / CLEAR"):format(i, string.upper(def.name), SD.fmt(SD.roomTrophies(i)), SD.fmt(SD.roomReward(i))), center + Vector3.new(0, 23, 61), 42, 4.8, accent)
		local marker = block(room, "EntrancePrompt", Vector3.new(1, 1, 1), center + Vector3.new(0, 3, 57), accent, MAT.SmoothPlastic, nil, false)
		marker.Transparency = 1
		local roomPrompt = prompt(marker, "Enter room", def.name, 18)
		roomPrompt:SetAttribute("RoomIndex", i)
		result.roomPrompts[i] = roomPrompt
		if i > 1 then sign(gate, "REQUIRES ROOM " .. (i - 1) .. " CLEAR", center + Vector3.new(0, 12.2, 61), 23, 1.5, C(221, 224, 235)) end
		local returnStone = cylinder(room, "SanctuaryRecall", 3.1, 0.3, center + Vector3.new(-33, 0.2, 51), C(121, 192, 231), MAT.Neon, false)
		sign(room, "RETURN\nSANCTUARY", center + Vector3.new(-33, 4.3, 49), 9, 3, C(155, 221, 249))
		result.returnPrompts[i] = prompt(returnStone, "Return to sanctuary", "Recall sigil", 10)
		local enemySpawns = {}
		for step, offset in { Vector3.new(-6, 3.2, 28), Vector3.new(6, 3.2, 12), Vector3.new(-6, 3.2, -4), Vector3.new(6, 3.2, -20), Vector3.new(-5, 3.2, -35), Vector3.new(0, 3.2, -49) } do
			enemySpawns[step] = CFrame.new(center + offset) * CFrame.Angles(0, math.pi, 0)
			if step < 6 then
				cylinder(room, "EnemySeal_" .. step, 3.2, 0.06, center + Vector3.new(offset.X, 0.12, offset.Z), accent, MAT.Neon, false)
			end
		end
		result.rooms[i] = {
			center = center, spawn = CFrame.new(center + Vector3.new(0, 4, 50)),
			enemySpawns = enemySpawns, entry = entry,
		}
		if i < #SD.STAGES then bridge(folder, center.Z - 64, center.Z - 96, accent) end
	end
	return result
end

return W
