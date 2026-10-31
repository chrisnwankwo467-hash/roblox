--!strict
-- WorldBuilder (ModuleScript) -> ServerScriptService. All geometry is original,
-- built from Roblox primitives; no external assets or Studio plugins are needed.
-- This module only builds the world and exposes prompts. GameServer owns access,
-- combat, rewards and training. Decorative gates never block other players.

local Lighting = game:GetService("Lighting")
local W = {}
W.HUB_SCALE = 0.8
W.BAKED_VERSION = "3"
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
	p.CanCollide = collide == true
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
	block(parent, "BridgeDeck", Vector3.new(28, 1.5, length + 2), Vector3.new(0, -0.75, z), WOOD, MAT.WoodPlanks, nil, true)
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

	block(parent, "IslandFoundation", Vector3.new(110, 8, 128), center + Vector3.new(0, -4, 0), floor, floorMaterial, nil, true)
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

local function interactionMarker(parent, name, pos)
	local marker = block(parent, name, Vector3.new(1, 1, 1), pos, GOLD, MAT.SmoothPlastic, nil, false)
	marker.Transparency, marker.CanQuery = 1, false
	return marker
end

local function line(parent, name, a, b, width, color, material)
	return part(parent, name, Vector3.new(width, width, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b), color, material or MAT.Wood, nil, false)
end

local function polygonRing(parent, name, center, radius, thickness, color, segments, vertical)
	segments = segments or 12
	for i = 1, segments do
		local a, b = i * math.pi * 2 / segments, (i + 1) * math.pi * 2 / segments
		local function point(angle)
			return center + (vertical and Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
				or Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
		end
		line(parent, name, point(a), point(b), thickness, color, MAT.Neon)
	end
end

local function flowerBed(parent, center, length, color)
	block(parent, "GardenBed", Vector3.new(length, 0.28, 4), center + Vector3.new(0, 0.14, 0), C(67, 158, 84), MAT.Grass)
	for i = 1, math.max(3, math.floor(length / 3)) do
		local p = center + Vector3.new(-length / 2 + i * 2.7, 0, (i % 2 - 0.5) * 1.8)
		block(parent, "FlowerStem", Vector3.new(0.16, 0.85, 0.16), p + Vector3.new(0, 0.55, 0), C(49, 149, 82), MAT.Grass)
		for j = 1, 3 do
			local a = j * math.pi * 2 / 3
			ball(parent, "FlowerPetal", Vector3.new(0.7, 0.24, 0.7), p + Vector3.new(math.cos(a) * 0.32, 1, math.sin(a) * 0.32), color, MAT.SmoothPlastic, false)
		end
		ball(parent, "FlowerPollen", Vector3.new(0.3, 0.3, 0.3), p + Vector3.new(0, 1.08, 0), GOLD, MAT.SmoothPlastic, false)
	end
end

local function garland(parent, a, b, color)
	local count = 7
	local previous = a
	for i = 1, count do
		local t = i / count
		local current = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 2, 0)
		line(parent, "LanternCable", previous, current, 0.1, C(75, 67, 97), MAT.Fabric)
		local glow = ball(parent, "FestivalLantern", Vector3.new(1.4, 1.8, 1.4), current - Vector3.new(0, 0.9, 0), i % 2 == 0 and GOLD or color, MAT.SmoothPlastic, false)
		block(parent, "LanternTassel", Vector3.new(0.12, 0.6, 0.12), glow.Position - Vector3.new(0, 1.15, 0), GOLD, MAT.Fabric)
		previous = current
	end
end

local function ropePen(parent, center, accent)
	local fence = model(parent, "TrainingRopePen")
	for _, x in { -13, 13 } do
		for _, z in { -13, 0, 13 } do
			block(fence, "PenPost", Vector3.new(0.65, 4, 0.65), center + Vector3.new(x, 2, z), C(109, 78, 112), MAT.Wood)
			ball(fence, "PostCap", Vector3.new(0.95, 0.75, 0.95), center + Vector3.new(x, 4.15, z), GOLD, MAT.Metal, false)
		end
	end
	for _, x in { -6, 6 } do block(fence, "EntryPost", Vector3.new(0.65, 3.8, 0.65), center + Vector3.new(x, 1.9, 13), accent, MAT.Wood) end
	for _, y in { 1.7, 3.2 } do
		for _, x in { -13, 13 } do line(fence, "Rope", center + Vector3.new(x, y, -13), center + Vector3.new(x, y, 13), 0.16, C(237, 221, 176), MAT.Fabric) end
		line(fence, "BackRope", center + Vector3.new(-13, y, -13), center + Vector3.new(13, y, -13), 0.16, C(237, 221, 176), MAT.Fabric)
		for _, side in { -1, 1 } do line(fence, "EntryRope", center + Vector3.new(side * 6, y, 13), center + Vector3.new(side * 13, y, 13), 0.16, C(237, 221, 176), MAT.Fabric) end
	end
end

local function trainingStation(parent, definition, id, center)
	local m = model(parent, "Training_" .. id)
	m:SetAttribute("TrainingId", id)
	m:SetAttribute("TrainingCenter", center)
	m:SetAttribute("TrainingRadius", 12)
	local accent = definition.color or C(126, 218, 221)
	local base = block(m, "TrainingFoundation", Vector3.new(28, 0.3, 28), center + Vector3.new(0, 0.15, 0), accent, MAT.SmoothPlastic, nil, true)
	base.TopSurface = Enum.SurfaceType.Studs
	block(m, "Tatami", Vector3.new(25, 0.12, 25), center + Vector3.new(0, 0.36, 0), C(243, 220, 180), MAT.Fabric, nil, false)
	for _, x in { -8, 0, 8 } do block(m, "TatamiBorder", Vector3.new(0.3, 0.03, 25), center + Vector3.new(x, 0.44, 0), C(119, 88, 133), MAT.Fabric) end
	polygonRing(m, "TrainingSeal", center + Vector3.new(0, 0.48, 0), 10.5, 0.1, accent, 12, false)
	ropePen(m, center, accent)
	local station = center + Vector3.new(0, 0, -5)
	if id == 1 then
		cylinder(m, "DojoStump", 2.9, 0.5, station + Vector3.new(0, 0.75, 0), C(130, 91, 66), MAT.Wood)
		block(m, "PracticePost", Vector3.new(1.5, 6.5, 1.5), station + Vector3.new(0, 3.75, 0), WOOD, MAT.Wood)
		block(m, "CrossArms", Vector3.new(7, 1.15, 1.15), station + Vector3.new(0, 4.5, 0), C(184, 136, 88), MAT.Wood)
		ball(m, "PracticeMask", Vector3.new(2.8, 2.8, 2.8), station + Vector3.new(0, 7.3, 0), C(251, 224, 176), MAT.Wood, false)
		block(m, "Headband", Vector3.new(3, 0.42, 2.5), station + Vector3.new(0, 7.8, 0), accent, MAT.Fabric)
		for _, side in { -1, 1 } do block(m, "MaskEye", Vector3.new(0.4, 0.2, 0.1), station + Vector3.new(side * 0.6, 7.3, 1.34), DARK, MAT.SmoothPlastic) end
		for j = 1, 3 do block(m, "StrawBinding", Vector3.new(1.65, 0.14, 1.65), station + Vector3.new(0, 2.1 + j * 0.65, 0), GOLD, MAT.Fabric) end
	elseif id == 2 then
		cylinder(m, "BoulderBase", 4.2, 0.7, station + Vector3.new(0, 0.85, 0), STONE, MAT.Slate)
		rock(m, station + Vector3.new(0, 1.2, 0), Vector3.new(6.5, 5.5, 5.5), C(127, 172, 173))
		for j = 1, 3 do block(m, "CutMarks", Vector3.new(0.13, 3.6, 0.2), station + Vector3.new(-1.5 + j * 0.7, 4.2, 2.8), accent, MAT.Neon, CFrame.Angles(0, 0, math.rad(-23))) end
		block(m, "StoneBlade", Vector3.new(0.35, 6, 1.3), station + Vector3.new(0, 8.3, 0), C(237, 239, 255), MAT.Metal, CFrame.Angles(0, 0, math.rad(-10)))
		block(m, "StoneSwordGuard", Vector3.new(0.8, 0.55, 4), station + Vector3.new(0.45, 10.8, 0), GOLD, MAT.Metal)
	elseif id == 3 then
		for _, side in { -1, 1 } do
			block(m, "FocusPillar", Vector3.new(1.3, 8, 1.3), station + Vector3.new(side * 4, 4.5, 0), C(91, 98, 159), MAT.Metal)
			ball(m, "FocusCrystal", Vector3.new(2.2, 2.9, 2.2), station + Vector3.new(side * 4, 9, 0), accent, MAT.Glass, false)
		end
		ball(m, "SuspendedCore", Vector3.new(3.8, 3.8, 3.8), station + Vector3.new(0, 6, 0), accent, MAT.Neon, false)
		polygonRing(m, "FocusHalo", station + Vector3.new(0, 6, 0), 4.4, 0.18, GOLD, 10, true)
	else
		cylinder(m, "AscensionPlinth", 4.5, 0.6, station + Vector3.new(0, 0.8, 0), C(104, 86, 159), MAT.Marble)
		for j = 1, 5 do
			local a = j / 5 * math.pi * 2
			rock(m, station + Vector3.new(math.cos(a) * 3.8, 2, math.sin(a) * 3.8), Vector3.new(0.9, 4, 0.9), accent, true)
		end
		ball(m, "AscensionHeart", Vector3.new(3.6, 3.6, 3.6), station + Vector3.new(0, 6, 0), GOLD, MAT.Neon, false)
		polygonRing(m, "AscensionHalo", station + Vector3.new(0, 6, 0), 4.7, 0.16, accent, 12, true)
	end
	local text = string.upper(definition.name) .. "\nx" .. tostring(definition.mult or 1) .. " SPIRIT  •  " .. tostring(definition.xp or 1) .. " XP"
	text ..= "\n" .. (definition.requiredTrophies == 0 and "FREE TRAINING" or tostring(definition.requiredTrophies) .. " TROPHIES")
	sign(m, text, center + Vector3.new(0, 13.2, -12), 27, 5.8, accent)
	for _, x in { -13, 13 } do block(m, "TierSignPost", Vector3.new(0.7, 14, 0.7), center + Vector3.new(x, 7, -12), C(101, 77, 135), MAT.Wood) end
	local p = prompt(interactionMarker(m, "TrainingPrompt", center + Vector3.new(0, 2.5, 2)), "Start training", definition.name, 16)
	p:SetAttribute("TrainingId", id)
	return { id = id, center = center, radius = 12, prompt = p }
end

local function applyLighting()
	Lighting.ClockTime = 13.2
	Lighting.Brightness = 2.8
	Lighting.ExposureCompensation = 0.1
	Lighting.Ambient = C(140, 150, 180)
	Lighting.OutdoorAmbient = C(190, 200, 220)
	Lighting.EnvironmentDiffuseScale = 0.75
	Lighting.EnvironmentSpecularScale = 0.45
	Lighting.GlobalShadows = true
	local function effect(className, name)
		local existing = Lighting:FindFirstChild(name)
		if existing and not existing:IsA(className) then existing:Destroy(); existing = nil end
		if not existing then existing = Instance.new(className); existing.Name = name; existing.Parent = Lighting end
		return existing
	end
	local atmosphere = effect("Atmosphere", "SpiritbladeAtmosphere")
	atmosphere.Density, atmosphere.Offset, atmosphere.Haze = 0.16, 0.12, 0.3
	atmosphere.Color, atmosphere.Decay = C(208, 227, 255), C(164, 184, 219)
	local bloom = effect("BloomEffect", "SpiritbladeBloom")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.12, 18, 1.5
	local grade = effect("ColorCorrectionEffect", "SpiritbladeColorGrade")
	grade.Saturation, grade.Contrast, grade.Brightness = 0.1, 0.04, 0
	grade.TintColor = C(255, 250, 246)
	local rays = effect("SunRaysEffect", "SpiritbladeSunRays")
	rays.Intensity, rays.Spread = 0.025, 0.75
end

local function decorateDisplaySword(SD, parent, def, position)
	local display = model(parent, "Display_" .. def.name)
	SD.buildSword(def, display)
	local origin, scale = display:GetPivot(), 1.65
	for _, obj in display:GetDescendants() do
		if obj:IsA("BasePart") then
			local relative = { origin:ToObjectSpace(obj.CFrame):GetComponents() }
			obj.Size *= scale
			obj.CFrame = origin * CFrame.new(relative[1] * scale, relative[2] * scale, relative[3] * scale, table.unpack(relative, 4, 12))
		elseif obj:IsA("Attachment") then obj.Position *= scale end
		if obj:IsA("BasePart") then obj.Anchored, obj.CanCollide, obj.CanQuery = true, false, false end
		if obj:IsA("ParticleEmitter") then obj.Rate = math.min(obj.Rate, 1) end
	end
	display:SetAttribute("Showcase", true)
	display:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.pi / 2, 0, 0))
	return display
end

local function buildShowroom(SD, parent, result)
	local showroom = model(parent, "SwordAmphitheatre")
	local tierNames = { "ROOKIE ARSENAL", "ELEMENTAL FORGE", "MYTHIC RELIQUARY", "SOVEREIGN VAULT" }
	local colors = { C(129, 219, 222), C(244, 145, 180), C(176, 150, 249), GOLD }
	local cursor = 1
	for tier = 1, 4 do
		local z, top = 112 - (tier - 1) * 33, tier * 0.5
		local terrace = block(showroom, "ShowroomTerrace_" .. tier, Vector3.new(76, top, 31), Vector3.new(-105, top / 2, z), colors[tier], MAT.SmoothPlastic, nil, true)
		terrace.TopSurface = Enum.SurfaceType.Studs
		block(showroom, "TerraceInset", Vector3.new(73, 0.08, 28), Vector3.new(-105, top + 0.05, z), C(245, 235, 229), MAT.Marble)
		for step = 1, tier do
			block(showroom, "DisplayStair_" .. tier .. "_" .. step, Vector3.new(2, step * 0.5, 13),
				Vector3.new(-66 + (tier - step) * 2, step * 0.25, z + 9), colors[tier], MAT.SmoothPlastic, nil, true)
		end
		if tier > 1 then
			local connectorHeight = (tier - 1) * 0.5
			block(showroom, "ShowroomConnector_" .. tier, Vector3.new(76, connectorHeight, 2), Vector3.new(-105, connectorHeight / 2, z + 16.5), colors[tier], MAT.SmoothPlastic, nil, true)
		end
		local rowCount = tier <= 2 and 4 or 3
		for col = 1, rowCount do
			local i, def = cursor, SD.SWORDS[cursor]
			cursor += 1
			local x = rowCount == 4 and -133 + (col - 1) * 18 or -130 + (col - 1) * 25
			local position = Vector3.new(x, top, z)
			cylinder(showroom, "WeaponPlinth_" .. i, 5.6, 0.8, position + Vector3.new(0, 0.45, 0), C(103, 84, 138), MAT.Marble, false)
			cylinder(showroom, "WeaponPlinthRim", 5.1, 0.1, position + Vector3.new(0, 0.91, 0), colors[tier], MAT.Neon, false)
			decorateDisplaySword(SD, showroom, def, position + Vector3.new(0, 2.1, 0))
			sign(showroom, def.name .. "\nx" .. tostring(def.mult) .. "  •  " .. (def.cost == 0 and "FREE" or SD.fmt(def.cost) .. " SPIRIT"), position + Vector3.new(0, 2, 7), 15, 3.2, colors[tier])
			local p = prompt(interactionMarker(showroom, "SwordInteract_" .. i, position + Vector3.new(0, 2.5, 9)), "Buy / equip", def.name .. " • " .. (def.cost == 0 and "FREE" or SD.fmt(def.cost) .. " Spirit"), 10)
			p:SetAttribute("SwordIndex", i)
			result.swordPrompts[i] = p
		end
		sign(showroom, tierNames[tier], Vector3.new(-105, 12 + top, z - 12), 71, 2.5, colors[tier])
		for _, x in { -142, -68 } do block(showroom, "ShowroomPillar", Vector3.new(0.8, 13, 0.8), Vector3.new(x, 6.5, z - 12), C(116, 96, 155), MAT.Wood) end
	end
	sign(showroom, "SWORD GALLERY\n14 ORIGINAL ANIME WEAPONS", Vector3.new(-105, 17, 139), 74, 5.5, C(160, 231, 246))
	for _, x in { -143, -67 } do
		block(showroom, "GalleryBannerPole", Vector3.new(0.9, 18, 0.9), Vector3.new(x, 9, 139), C(104, 85, 137), MAT.Metal)
		block(showroom, "GalleryBanner", Vector3.new(4, 8, 0.2), Vector3.new(x + 3, 12, 139), C(151, 113, 210), MAT.Fabric)
	end
	local galleryPrompt = prompt(interactionMarker(showroom, "GalleryMenu", Vector3.new(-69, 3, 139)), "Open sword collection", "Sword Gallery", 14)
	galleryPrompt:SetAttribute("HubTab", "Swords")
	result.hubPrompts.Swords = galleryPrompt
end

local function tinyCompanion(parent, pos, color, fox)
	local m = model(parent, fox and "LanternFoxStatue" or "CloudKirinStatue")
	ball(m, "Body", Vector3.new(3.5, 2.5, 2.5), pos + Vector3.new(0, 1.6, 0), color, MAT.SmoothPlastic, false)
	ball(m, "Head", Vector3.new(2.5, 2.4, 2.2), pos + Vector3.new(0, 3.4, 0.4), color, MAT.SmoothPlastic, false)
	for _, side in { -1, 1 } do
		block(m, "Ear", Vector3.new(0.7, 1.8, 0.8), pos + Vector3.new(side * 0.75, 4.8, 0.3), color, MAT.SmoothPlastic, CFrame.Angles(0, 0, math.rad(side * -18)))
		ball(m, "Eye", Vector3.new(0.3, 0.4, 0.15), pos + Vector3.new(side * 0.55, 3.6, 1.45), C(53, 50, 90), MAT.SmoothPlastic, false)
		block(m, "Paw", Vector3.new(0.75, 0.8, 1), pos + Vector3.new(side * 1.2, 0.7, 0.5), color, MAT.SmoothPlastic)
	end
	for j = 1, fox and 3 or 1 do
		ball(m, "SpiritTail", Vector3.new(1.3, 2.4, 3.2), pos + Vector3.new((j - 2) * 1.1, 2, -2), color, MAT.SmoothPlastic, false)
	end
end

local function buildEggPromenade(SD, parent, result)
	local promenade = model(parent, "SpiritEggPromenade")
	for i, def in SD.EGGS do
		local center = Vector3.new(108, 0, 107 - (i - 1) * 62)
		local accent = i == 1 and C(119, 229, 180) or C(211, 173, 255)
		block(promenade, "EggPavilionFloor_" .. i, Vector3.new(57, 1.5, 44), center + Vector3.new(0, 0.75, 0), C(249, 226, 228), MAT.Marble, nil, true)
		for step = 1, 3 do
			block(promenade, "EggStair_" .. i .. "_" .. step, Vector3.new(22, step * 0.5, 2), center + Vector3.new(0, step * 0.25, 29 - step * 2), accent, MAT.SmoothPlastic, nil, true)
		end
		for _, side in { -1, 1 } do
			block(promenade, "EggPavilionPillar", Vector3.new(1.2, 17, 1.2), center + Vector3.new(side * 26, 8.5, -15), C(146, 112, 173), MAT.Wood)
			block(promenade, "EggCanopyEave", Vector3.new(15, 0.6, 12), center + Vector3.new(side * 22, 17.8, -13), C(117, 98, 182), MAT.Slate, CFrame.Angles(0, 0, math.rad(side * 12)))
		end
		block(promenade, "EggPavilionCanopy", Vector3.new(57, 1, 12), center + Vector3.new(0, 17.2, -13), C(147, 122, 205), MAT.Slate)
		local pedestal = center + Vector3.new(0, 1.5, -3)
		cylinder(promenade, "EggPedestal", 7.4, 1.1, pedestal + Vector3.new(0, 0.55, 0), C(164, 142, 211), MAT.Marble, false)
		cylinder(promenade, "EggOrbit", 7, 0.1, pedestal + Vector3.new(0, 1.15, 0), accent, MAT.Neon, false)
		local egg = ball(promenade, "SpiritEgg_" .. i, Vector3.new(8, 10.5, 8), pedestal + Vector3.new(0, 6.3, 0), accent, MAT.SmoothPlastic, false)
		egg:SetAttribute("AmbientFloat", true)
		egg:SetAttribute("AmbientRotate", true)
		for j = 1, 5 do
			local a = j * math.pi * 2 / 5
			block(promenade, "EggRune", Vector3.new(1.1, 2.4, 0.3), egg.Position + Vector3.new(math.cos(a) * 3.6, 0.5, math.sin(a) * 3.6), GOLD, MAT.Metal, CFrame.Angles(0, -a, math.rad(25)))
		end
		polygonRing(promenade, "EggHalo", egg.Position + Vector3.new(0, 0.7, 0), 6.2, 0.16, GOLD, 12, true)
		tinyCompanion(promenade, center + Vector3.new(-17, 1.5, -3), i == 1 and C(255, 201, 164) or C(191, 208, 255), i == 1)
		tinyCompanion(promenade, center + Vector3.new(17, 1.5, -3), i == 1 and C(255, 226, 177) or C(233, 206, 255), i == 1)
		sign(promenade, string.upper(def.name) .. "\n" .. SD.fmt(def.cost) .. " SPIRIT", center + Vector3.new(0, 15.7, -13), 40, 4.1, accent)
		local p = prompt(interactionMarker(promenade, "EggInteract_" .. i, center + Vector3.new(0, 3.8, 14)), "Hatch egg", def.name .. " • " .. SD.fmt(def.cost) .. " Spirit", 13)
		p:SetAttribute("EggIndex", i)
		result.eggPrompts[i] = p
	end
	local menu = prompt(interactionMarker(promenade, "PetCollectionMenu", Vector3.new(72, 3, 137)), "Open companions", "Spirit Egg Promenade", 14)
	menu:SetAttribute("HubTab", "Pets")
	result.hubPrompts.Pets = menu
	sign(promenade, "SPIRIT COMPANIONS\nHATCH • COLLECT • GROW STRONGER", Vector3.new(107, 22, 143), 66, 4.5, C(255, 190, 215))
end

local function guardianDragon(parent, pos, side)
	local m = model(parent, "DawnGuardianDragon")
	local mint, ivory = C(104, 203, 183), C(255, 231, 186)
	for j = 1, 5 do
		local a = j * math.pi / 4
		ball(m, "CoiledBody", Vector3.new(7, 7, 7), pos + Vector3.new(math.cos(a) * 4, 2 + j * 1.1, math.sin(a) * 4), mint, MAT.SmoothPlastic, false)
	end
	local head = pos + Vector3.new(-side * 1.5, 12, 2)
	ball(m, "GuardianHead", Vector3.new(8, 6, 8), head, mint, MAT.SmoothPlastic, false)
	block(m, "GuardianMuzzle", Vector3.new(5.5, 2.5, 7), head + Vector3.new(0, -1.8, 4), ivory, MAT.SmoothPlastic)
	for _, s in { -1, 1 } do
		ball(m, "GuardianEye", Vector3.new(0.8, 1, 0.5), head + Vector3.new(s * 2.4, 0.2, 3.8), GOLD, MAT.Neon, false)
		line(m, "GuardianHorn", head + Vector3.new(s * 2.3, 2, -1), head + Vector3.new(s * 3.6, 7.5, -3.5), 0.8, ivory, MAT.Metal)
		line(m, "GuardianHornFork", head + Vector3.new(s * 3, 5, -2.5), head + Vector3.new(s * 5.2, 5.8, -1), 0.45, ivory, MAT.Metal)
		line(m, "GuardianWhisker", head + Vector3.new(s * 2.8, -1, 5), head + Vector3.new(s * 6.5, -0.5, 6.5), 0.18, GOLD, MAT.Metal)
	end
	for j = 1, 4 do
		block(m, "DragonMane", Vector3.new(1.4, 4, 1.5), head + Vector3.new(0, 1.8, -2.2 + j * 0.8), C(248, 150, 171), MAT.SmoothPlastic, CFrame.Angles(math.rad(-24), 0, 0))
	end
end

local function buildGrandPortal(parent)
	local portal = model(parent, "CelestialTrialPortal")
	for _, side in { -1, 1 } do
		cylinder(portal, "GuardianPedestal", 9.5, 0.5, Vector3.new(side * 34, 0.25, -59), C(214, 180, 205), MAT.Marble, false)
		guardianDragon(portal, Vector3.new(side * 34, 0.5, -59), side)
		block(portal, "PortalPillar", Vector3.new(3, 29, 3), Vector3.new(side * 23, 14.5, -62), C(213, 99, 147), MAT.Wood)
		block(portal, "GoldenCollar", Vector3.new(3.5, 1.3, 3.5), Vector3.new(side * 23, 24, -62), GOLD, MAT.Metal)
		block(portal, "PortalWingEave", Vector3.new(15, 1.5, 6), Vector3.new(side * 23, 32, -62), C(104, 90, 163), MAT.Slate, CFrame.Angles(0, 0, math.rad(side * 14)))
	end
	block(portal, "PortalUpperEave", Vector3.new(51, 2.2, 5), Vector3.new(0, 30, -62), C(115, 95, 170), MAT.Slate)
	block(portal, "PortalLowerBeam", Vector3.new(51, 1.1, 2), Vector3.new(0, 23.3, -62), C(228, 122, 169), MAT.Wood)
	polygonRing(portal, "CelestialHalo", Vector3.new(0, 38, -67), 15, 0.4, GOLD, 16, true)
	local heart = ball(portal, "MonumentSpiritHeart", Vector3.new(2.4, 3.6, 1.6), Vector3.new(0, 32, -64), C(255, 210, 147), MAT.Glass, false)
	heart:SetAttribute("AmbientFloat", true)
	block(portal, "MonumentGrip", Vector3.new(1.2, 5, 1.2), Vector3.new(0, 28.5, -65), C(112, 92, 161), MAT.Metal)
	block(portal, "MonumentGuard", Vector3.new(14, 1.1, 1.8), Vector3.new(0, 31, -65), GOLD, MAT.Metal)
	for j = 1, 4 do
		block(portal, "FloatingMonumentBlade", Vector3.new(7 - j * 0.9, 5.4, 1.1), Vector3.new(0, 32 + j * 5.8, -65), C(220, 223, 255), MAT.Metal, CFrame.Angles(0, 0, math.rad(j % 2 == 0 and 4 or -4)))
		block(portal, "MonumentCore", Vector3.new(0.3, 4.8, 1), Vector3.new(0, 32 + j * 5.8, -65), C(153, 216, 255), MAT.Neon)
	end
	sign(portal, "SPIRIT TRIALS\n15 REALMS • ENTER TO BEGIN", Vector3.new(0, 19, -60), 41, 5.3, GOLD)
	garland(portal, Vector3.new(-23, 23, -59), Vector3.new(23, 23, -59), C(255, 162, 189))
end

local function sanctuaryCliffs(parent)
	local cliffs = model(parent, "PetalstoneCanyon")
	local rose, plum = C(201, 141, 163), C(146, 113, 168)
	for _, side in { -1, 1 } do
		for j = 1, 5 do
			local z = -60 + (j - 1) * 32
			for tier = 1, 3 do
				local top = ({ 18, 30, 43 })[tier] + (j % 3 - 1) * 3
				local x = side * (164 + (tier - 1) * 20)
				local yaw = CFrame.Angles(0, math.rad((j % 2 == 0 and 1 or -1) * 4), 0)
				block(cliffs, "PetalstoneTerrace", Vector3.new(29, top + 10, 35), Vector3.new(x, (top - 10) / 2, z), tier == 2 and plum or rose, MAT.Slate, yaw)
				block(cliffs, "BrightCliffGrass", Vector3.new(29.4, 0.85, 35.4), Vector3.new(x, top + 0.4, z), C(100, 197, 103), MAT.Grass, yaw)
				block(cliffs, "CliffSediment", Vector3.new(29.5, 0.65, 34), Vector3.new(x, top - 5.5, z), C(229, 178, 179), MAT.Slate, yaw)
				if tier == 1 and j % 2 == 1 then
					rock(cliffs, Vector3.new(x - side * 10, top + 0.8, z + 7), Vector3.new(5, 4, 6), C(173, 134, 168))
				end
			end
		end
		for _, z in { -52, 53 } do tree(cliffs, Vector3.new(side * 184, 30.8, z), C(255, 168, 203), 1.15, true) end
		local p = Vector3.new(side * 205, 44, -3)
		for _, edge in { -1, 1 } do block(cliffs, "RuinedPerchPillar", Vector3.new(1.6, 10, 2.2), p + Vector3.new(edge * 5.5, 5, 0), C(238, 218, 224), MAT.Marble) end
		block(cliffs, "RuinedPerchArch", Vector3.new(14, 2, 3), p + Vector3.new(0, 10.5, 0), C(239, 216, 223), MAT.Marble, CFrame.Angles(0, 0, math.rad(side * 4)))
		local waterfall = block(cliffs, "SilkWaterfall", Vector3.new(0.3, 23, 6), Vector3.new(side * 149.2, 7, -27), C(126, 219, 240), MAT.Glass)
		waterfall.Transparency = 0.35
		for _, offset in { -1.7, 1.7 } do block(cliffs, "WaterfallRibbon", Vector3.new(0.32, 21, 0.3), waterfall.Position + Vector3.new(0, 0, offset), C(209, 243, 255), MAT.SmoothPlastic) end
		for j = 1, 3 do
			local x = side * (45 + (j - 1) * 47)
			local top = 24 + (j % 2) * 8
			block(cliffs, "NorthernCanyon", Vector3.new(43, top + 10, 22), Vector3.new(x, (top - 10) / 2, -91), rose, MAT.Slate)
			block(cliffs, "NorthernGrass", Vector3.new(43.5, 0.8, 22.5), Vector3.new(x, top + 0.4, -91), C(109, 204, 111), MAT.Grass)
		end
	end
end

-- Small linked courtyards replace the open lawns. All props are authored before
-- the final scale so the entire hub, prompts and saved coordinates stay aligned.
local function courtyardDetails(hub)
	local m = model(hub, "LinkedCourtyards")
	local cedar, plaster, leaf = C(111, 77, 119), C(251, 222, 215), C(77, 159, 113)
	-- Three overhead thresholds break the long sightline into readable districts.
	for i, z in { 122, 72, -8 } do
		for _, side in { -1, 1 } do
			block(m, "DistrictPost", Vector3.new(1.1, 14, 1.1), Vector3.new(side * 13, 7, z), cedar, MAT.Wood)
			block(m, "DistrictCollar", Vector3.new(1.5, 0.8, 1.5), Vector3.new(side * 13, 11.5, z), GOLD, MAT.Metal)
			block(m, "GatewayPlanter", Vector3.new(7, 1.1, 10), Vector3.new(side * 22, 0.55, z), plaster, MAT.Marble)
			ball(m, "GatewayBonsai", Vector3.new(5.8, 4.8, 8), Vector3.new(side * 22, 3.2, z), leaf, MAT.Grass, false)
		end
		block(m, "DistrictLintel", Vector3.new(29, 1.1, 3.2), Vector3.new(0, 14.5, z), cedar, MAT.Wood)
		block(m, "DistrictRoof", Vector3.new(32, 0.6, 5), Vector3.new(0, 15.3, z), C(120, 103, 170), MAT.Slate)
		sign(m, ({ "TRAINING COURT", "SPIRIT WALK", "TRIAL APPROACH" })[i], Vector3.new(0, 12.4, z), 19, 2.1, GOLD)
	end
	-- Slatted garden walls frame the side courts, leaving each crosswalk open.
	for _, side in { -1, 1 } do
		for _, z in { 17, 76, 123 } do
			local x = side * 67
			block(m, "CourtyardWall", Vector3.new(2, 3.5, 17), Vector3.new(x, 1.75, z), plaster, MAT.SmoothPlastic)
			block(m, "WallCoping", Vector3.new(2.6, 0.4, 18), Vector3.new(x, 3.7, z), cedar, MAT.Wood)
			for j = 1, 5 do
				block(m, "PrivacySlat", Vector3.new(0.5, 4.5, 0.5), Vector3.new(x, 6, z - 9 + j * 3), cedar, MAT.Wood)
			end
			block(m, "ScreenLintel", Vector3.new(0.8, 0.5, 18), Vector3.new(x, 8.5, z), cedar, MAT.Wood)
		end
		-- Pocket orchards occupy former grass strips beside the arrival plaza.
		for _, z in { 157, 22, -25 } do
			local p = Vector3.new(side * 43, 0, z)
			cylinder(m, "OrchardPlanter", 9, 0.8, p + Vector3.new(0, 0.4, 0), plaster, MAT.Marble)
			tree(m, p + Vector3.new(0, 0.8, 0), C(255, 170, 201), 0.8, true)
			block(m, "RestBench", Vector3.new(10, 0.7, 2.7), p + Vector3.new(0, 1.7, -10), cedar, MAT.Wood)
			for _, dx in { -3.5, 3.5 } do
				block(m, "BenchLeg", Vector3.new(0.7, 1.4, 2), p + Vector3.new(dx, 0.7, -10), cedar, MAT.Wood)
			end
		end
	end
	-- A walled tea garden fills the empty rear-left corner with a destination.
	local garden = model(m, "MoonTeaGarden")
	local p = Vector3.new(-100, 0, -40)
	block(garden, "GardenPaving", Vector3.new(62, 0.14, 45), p + Vector3.new(0, 0.08, 0), C(235, 209, 221), MAT.Cobblestone)
	for _, side in { -1, 1 } do
		block(garden, "GardenEnclosure", Vector3.new(2, 5, 44), p + Vector3.new(side * 30, 2.5, 0), plaster, MAT.SmoothPlastic)
		block(garden, "GardenCap", Vector3.new(3, 0.6, 45), p + Vector3.new(side * 30, 5.2, 0), cedar, MAT.Wood)
		block(garden, "EntranceHedge", Vector3.new(20, 3.2, 3), p + Vector3.new(side * 20, 1.6, 21), leaf, MAT.Grass)
	end
	shrine(garden, p + Vector3.new(-12, 0, -8), C(188, 119, 164), 1.25)
	cylinder(garden, "KoiBasinRim", 8.5, 0.7, p + Vector3.new(14, 0.35, -2), plaster, MAT.Marble)
	local water = cylinder(garden, "KoiWater", 7.8, 0.12, p + Vector3.new(14, 0.74, -2), C(105, 216, 225), MAT.Glass, false)
	water.Transparency = 0.18
	for i = 1, 5 do
		block(garden, "SteppingStone", Vector3.new(5, 0.16, 3), p + Vector3.new(0, 0.18, 18 - i * 4), C(255, 236, 217), MAT.Slate)
	end
	tree(garden, p + Vector3.new(23, 0, -16), C(242, 163, 205), 1.1, true)
	lantern(garden, p + Vector3.new(-24, 0, 15), GOLD, false)
	lantern(garden, p + Vector3.new(24, 0, 15), GOLD, false)
	sign(garden, "MOON TEA GARDEN", p + Vector3.new(0, 8, 21), 22, 2, C(244, 191, 220))
end

local function compactHub(hub, result)
	local scale, anchor = W.HUB_SCALE, Vector3.new(0, 0, -80)
	local function position(p) return anchor + (p - anchor) * scale end
	local function transform(cf)
		return CFrame.new(position(cf.Position)) * cf.Rotation
	end
	for _, obj in hub:GetDescendants() do
		if obj:IsA("BasePart") then
			obj.Size *= scale
			obj.CFrame = transform(obj.CFrame)
		elseif obj:IsA("Attachment") then obj.Position *= scale
		elseif obj:IsA("PointLight") then obj.Range *= scale end
	end
	for _, station in result.training do
		station.center = position(station.center)
		station.radius *= scale
		local m = hub:FindFirstChild("Training_" .. station.id, true)
		m:SetAttribute("TrainingCenter", station.center)
		m:SetAttribute("TrainingRadius", station.radius)
	end
	result.spawn = transform(result.spawn)
	result.folder:SetAttribute("Spawn", result.spawn)
	result.folder:SetAttribute("HubScale", scale)
end

local function buildHub(SD, folder, result)
	local hub = model(folder, "SpiritbladeSanctuary")
	local island = block(hub, "SanctuaryIsland", Vector3.new(300, 8, 260), Vector3.new(0, -4, 50), C(93, 193, 110), MAT.Grass, nil, true)
	island.TopSurface = Enum.SurfaceType.Studs
	block(hub, "SanctuaryCliff", Vector3.new(286, 11, 248), Vector3.new(0, -13.5, 50), C(177, 142, 155), MAT.Slate)
	block(hub, "LowerCliffTerrace", Vector3.new(265, 9, 226), Vector3.new(0, -23, 50), C(137, 116, 156), MAT.Slate)
	block(hub, "Promenade", Vector3.new(22, 0.18, 260), Vector3.new(0, 0.1, 50), C(207, 184, 247), MAT.SmoothPlastic)
	for _, side in { -1, 1 } do
		block(hub, "PromenadeIvoryEdge", Vector3.new(1.3, 0.22, 260), Vector3.new(side * 11.4, 0.12, 50), C(255, 240, 204), MAT.SmoothPlastic)
	end
	for _, z in { 45, 100, 145 } do
		block(hub, "Crosswalk", Vector3.new(284, 0.17, 9), Vector3.new(0, 0.11, z), C(220, 206, 255), MAT.SmoothPlastic)
	end
	for j = 1, 19 do
		block(hub, "PromenadeChevron", Vector3.new(4, 0.04, 0.4), Vector3.new(-1.5, 0.22, 158 - j * 10), C(255, 241, 213), MAT.SmoothPlastic, CFrame.Angles(0, math.rad(-27), 0))
		block(hub, "PromenadeChevron", Vector3.new(4, 0.04, 0.4), Vector3.new(1.5, 0.22, 158 - j * 10), C(255, 241, 213), MAT.SmoothPlastic, CFrame.Angles(0, math.rad(27), 0))
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.CFrame = "SanctuarySpawn", Vector3.new(9, 0.25, 9), CFrame.new(0, 0.28, 145)
	spawn.Transparency, spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.CanCollide = 1, true, true, 0, false
	spawn.Parent = hub
	local spawnSeal = model(hub, "ArrivalSeal")
	polygonRing(spawnSeal, "ArrivalGlyph", Vector3.new(0, 0.25, 145), 9, 0.15, GOLD, 12, false)
	sign(hub, "BLADEBOUND", Vector3.new(0, 20, 172), 54, 6.8, C(255, 222, 160))
	sign(hub, "TRAIN • COLLECT • CONQUER", Vector3.new(0, 14, 172), 43, 2.4, C(239, 226, 255))
	for _, side in { -1, 1 } do
		block(hub, "ArrivalBannerPole", Vector3.new(1, 21, 1), Vector3.new(side * 29, 10.5, 172), C(119, 91, 153), MAT.Wood)
		block(hub, "ArrivalBanner", Vector3.new(7, 12, 0.2), Vector3.new(side * 29, 14, 172), side == -1 and C(174, 133, 224) or C(239, 148, 183), MAT.Fabric)
	end
	local positions = { Vector3.new(-44, 0, 100), Vector3.new(44, 0, 100), Vector3.new(-44, 0, 45), Vector3.new(44, 0, 45) }
	for i, def in SD.TRAINING do result.training[i] = trainingStation(hub, def, i, positions[i]) end
	buildShowroom(SD, hub, result)
	buildEggPromenade(SD, hub, result)
	buildGrandPortal(hub)
	sanctuaryCliffs(hub)
	local aura = model(hub, "AuraAwakeningShrine")
	local origin = Vector3.new(103, 0, -23)
	cylinder(aura, "AuraCourt", 20, 0.3, origin + Vector3.new(0, 0.15, 0), C(196, 171, 237), MAT.Marble, true)
	for _, side in { -1, 1 } do
		block(aura, "AuraPillar", Vector3.new(1.6, 14, 1.6), origin + Vector3.new(side * 12, 7, -7), C(160, 126, 202), MAT.Marble)
	end
	polygonRing(aura, "AwakeningRing", origin + Vector3.new(0, 8, -7), 8, 0.25, C(178, 221, 255), 16, true)
	local awakeningCore = ball(aura, "AwakeningCore", Vector3.new(4, 4, 4), origin + Vector3.new(0, 8, -7), C(225, 192, 255), MAT.Neon, false)
	awakeningCore:SetAttribute("AmbientFloat", true)
	sign(aura, "AURA AWAKENING\nYOUR SPIRIT, MADE VISIBLE", origin + Vector3.new(0, 17, -9), 39, 4.2, C(219, 190, 255))
	local p = prompt(interactionMarker(aura, "AuraMenu", origin + Vector3.new(0, 3, 8)), "Open auras", "Awakening Shrine", 14)
	p:SetAttribute("HubTab", "Auras")
	result.hubPrompts.Auras = p
	for _, side in { -1, 1 } do
		for _, z in { -42, 5, 72, 154 } do
			tree(hub, Vector3.new(side * 145, 0, z), C(255, 163, 197), 1.4, true)
		end
		for _, z in { 18, 72, 127 } do
			lantern(hub, Vector3.new(side * 23, 0, z), C(255, 218, 166), true)
		end
		for _, z in { 18, 72, 127 } do
			garland(hub, Vector3.new(side * 23, 12, z), Vector3.new(side * 65, 12, z), C(255, 166, 204))
		end
		for _, z in { -69, 163 } do flowerBed(hub, Vector3.new(side * 76, 0, z), 36, side == -1 and C(255, 171, 201) or C(196, 165, 255)) end
		-- Edge hedges define a safe, readable island silhouette without enclosing the hub.
		for j = 1, 8 do
			local hedge = block(hub, "GardenBoundary", Vector3.new(4, 2.3, 27), Vector3.new(side * 148, 1.15, -80 + j * 30), C(59, 151, 97), MAT.Grass, nil, true)
			hedge.TopSurface = Enum.SurfaceType.Studs
		end
		for j = 1, 7 do
			rock(hub, Vector3.new(side * 146, -7, -94 + j * 37), Vector3.new(14, 12 + j % 3 * 2, 17), C(189, 153, 171))
		end
	end
	for _, x in { -108, -36, 36, 108 } do
		block(hub, "SouthernGardenBoundary", Vector3.new(64, 2.3, 3), Vector3.new(x, 1.15, 177), C(66, 160, 100), MAT.Grass, nil, true)
	end
	courtyardDetails(hub)
	compactHub(hub, result)
end

-- Original anime realm silhouettes. Decorative only; encounter coordinates stay fixed.
-- Uses WorldBuilder's existing model/block/cylinder/ball/C/MAT helpers.
local function polishRealm(parent, center, theme, accent, index)
	local m = model(parent, "RealmDetail_" .. tostring(index))
	local function p(x, y, z) return center + Vector3.new(x, y, z) end
	local function b(name, size, pos, color, material, rotation)
		return block(m, name, size, pos, color, material or MAT.SmoothPlastic, rotation, false)
	end
	local function orb(name, size, pos, color, material)
		return ball(m, name, size, pos, color, material or MAT.SmoothPlastic, false)
	end
	local function disc(name, radius, height, pos, color, material)
		return cylinder(m, name, radius, height, pos, color, material or MAT.SmoothPlastic, false)
	end
	local function beam(name, a, z, width, color, material)
		return b(name, Vector3.new(width, width, (z - a).Magnitude), (a + z) * 0.5,
			color, material, CFrame.lookAt(a, z).Rotation)
	end
	local function arch(name, at, radius, startAngle, endAngle, count, color, width, depth)
		for i = 1, count do
			local a0 = math.rad(startAngle + (endAngle - startAngle) * (i - 1) / count)
			local a1 = math.rad(startAngle + (endAngle - startAngle) * i / count)
			local v0 = at + Vector3.new(math.cos(a0) * radius, math.sin(a0) * radius, 0)
			local v1 = at + Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius, 0)
			local segment = beam(name, v0, v1, width, color, MAT.SmoothPlastic)
			segment.Size = Vector3.new(width, depth or width, (v1 - v0).Magnitude + 0.25)
		end
	end
	local function crystal(at, size, color, lean)
		b("FacetedCrystal", size, at, color, MAT.Glass, CFrame.Angles(0, math.rad(25), math.rad(lean or 0)))
		b("CrystalEdge", size * Vector3.new(0.16, 1.08, 0.18), at + Vector3.new(0, 0.4, -size.Z * 0.36), color, MAT.Neon,
			CFrame.Angles(0, math.rad(25), math.rad(lean or 0)))
	end
	local function pennant(at, color, length)
		b("SilkPennant", Vector3.new(2.6, length, 0.12), at, color, MAT.Fabric)
		b("PennantCrest", Vector3.new(0.9, 0.9, 0.16), at + Vector3.new(0, 0.3, -0.09), C(255, 236, 155), MAT.SmoothPlastic,
			CFrame.Angles(0, 0, math.rad(45)))
	end
	local function roof(at, width, depth, color)
		for _, side in { -1, 1 } do
			b("SweptEave", Vector3.new(width * 0.56, 1.1, depth), at + Vector3.new(side * width * 0.23, 0, 0), color,
				MAT.SmoothPlastic, CFrame.Angles(0, 0, math.rad(side * -15)))
			b("UpturnedTip", Vector3.new(4.5, 0.8, depth + 0.8), at + Vector3.new(side * width * 0.48, -0.7, 0), color,
				MAT.SmoothPlastic, CFrame.Angles(0, 0, math.rad(side * 16)))
		end
		b("GildedRoofRidge", Vector3.new(0.7, 0.8, depth + 1.2), at + Vector3.new(0, 1.5, 0), C(255, 218, 115), MAT.Metal)
	end
	local function cloud(at, size)
		orb("CloudHeart", size, at, C(247, 251, 255))
		orb("CloudLobe", size * Vector3.new(0.65, 1, 0.9), at + Vector3.new(size.X * 0.3, size.Y * 0.15, 0), C(238, 247, 255))
		orb("CloudLobe", size * Vector3.new(0.6, 0.85, 0.95), at - Vector3.new(size.X * 0.3, 0, 0), C(225, 240, 255))
	end

	-- Chunky, layered side terrain gives each realm a landscape silhouette instead
	-- of a bare rectangular platform. No added solid scenery occupies the route.
	local lush, earth, cap = C(113, 207, 99), C(184, 139, 105), C(163, 231, 126)
	if theme == "ice" then lush, earth, cap = C(172, 225, 251), C(112, 177, 221), C(238, 253, 255)
	elseif theme == "sky" or theme == "celestial" then lush, earth, cap = C(170, 221, 237), C(140, 180, 213), C(237, 253, 249)
	elseif theme == "lava" then lush, earth, cap = C(143, 99, 126), C(106, 76, 114), C(255, 158, 77)
	elseif theme == "void" then lush, earth, cap = C(159, 115, 220), C(98, 72, 152), C(212, 165, 255)
	elseif theme == "shadow" or theme == "spirit" then lush, earth, cap = C(145, 173, 219), C(110, 115, 173), C(178, 227, 217)
	elseif theme == "thunder" then lush, earth, cap = C(216, 215, 109), C(166, 129, 150), C(255, 237, 140)
	elseif theme == "water" then lush, earth, cap = C(109, 213, 182), C(100, 166, 175), C(170, 241, 218)
	elseif theme == "throne" then lush, earth, cap = C(191, 187, 239), C(153, 144, 193), C(255, 234, 170) end
	for _, side in { -1, 1 } do
		for j = 1, 3 do
			local x, z = side * (64 + (j % 2) * 7), -55 + j * 28
			local h = 7 + ((j + index) % 3) * 4
			local rot = CFrame.Angles(0, math.rad(side * (10 + j * 7)), 0)
			b("LayeredCliff", Vector3.new(25, h, 29), p(x, h * 0.5 - 3, z), earth, MAT.SmoothPlastic, rot)
			b("TerraceTop", Vector3.new(26, 1.5, 30), p(x, h - 2.1, z), lush, MAT.SmoothPlastic, rot)
			b("UpperTerrace", Vector3.new(17, 4, 20), p(x + side * 3, h - 0.6, z - 1), cap, MAT.SmoothPlastic, rot)
		end
	end

	if theme == "dojo" then
		-- A raised vermilion open-air school faces the practice sword monument.
		local at = p(-38, 0, -5)
		b("DojoVeranda", Vector3.new(28, 1.8, 27), at + Vector3.new(0, 0.9, 0), C(227, 174, 126), MAT.WoodPlanks)
		for _, x in { -10, 10 } do
			for _, z in { -10, 10 } do
				b("DojoPillar", Vector3.new(1.7, 13, 1.7), at + Vector3.new(x, 8.2, z), C(219, 93, 88), MAT.SmoothPlastic)
			end
		end
		roof(at + Vector3.new(0, 15, 0), 32, 30, C(69, 167, 158))
		roof(at + Vector3.new(0, 18, 0), 22, 20, C(82, 188, 170))
		for i = 1, 4 do pennant(at + Vector3.new(-10 + i * 4, 11, 10.8), C(255, 234, 171), 5) end
		disc("SwordMonumentFoot", 7, 2, p(37, 1, -2), C(222, 180, 116))
		b("PracticeBlade", Vector3.new(2.8, 22, 0.9), p(37, 13, -2), C(196, 245, 244), MAT.Metal, CFrame.Angles(0, 0, math.rad(-12)))
		b("PracticeBladeEdge", Vector3.new(0.3, 22, 1), p(35.5, 13.2, -2), C(255, 244, 190), MAT.Neon, CFrame.Angles(0, 0, math.rad(-12)))
		b("PracticeTsuba", Vector3.new(11, 1.1, 2.4), p(34.5, 24, -2), C(255, 204, 92), MAT.Metal)
		b("PracticeGrip", Vector3.new(1.5, 7, 1.5), p(34.3, 27.8, -2), C(90, 126, 175), MAT.Fabric)
	elseif theme == "bamboo" then
		-- The Jade Ribbon: a bright waterfall feeding a carved koi pool.
		b("WaterfallCliff", Vector3.new(20, 29, 31), p(-65, 11, -6), C(109, 159, 133))
		b("CascadeCrown", Vector3.new(24, 2, 35), p(-65, 26, -6), C(116, 221, 123), MAT.Grass)
		for j = 1, 4 do
			local fall = b("JadeRibbon", Vector3.new(0.28, 26 - j, 3.4), p(-54.4 + j * 0.12, 13, -15 + j * 5), C(122, 240, 243), MAT.Glass)
			fall.Transparency = 0.18
		end
		b("KoiPoolBorder", Vector3.new(26, 0.7, 35), p(-39, 0.35, -6), C(243, 211, 163))
		local pool = b("JadePool", Vector3.new(23, 0.28, 32), p(-39, 0.77, -6), C(71, 203, 198), MAT.Glass)
		pool.Transparency = 0.15
		for j = 1, 3 do
			local at = p(-44 + j * 3, 1.05, -19 + j * 7)
			orb("Koi", Vector3.new(1.5, 0.4, 3.8), at, j % 2 == 0 and C(255, 229, 158) or C(255, 137, 104))
			b("KoiTail", Vector3.new(2.2, 0.16, 1.2), at + Vector3.new(0, 0, 2), C(255, 239, 191), nil, CFrame.Angles(0, math.rad(45), 0))
		end
		for j = 1, 5 do
			beam("WishRope", p(23, 12, -36 + j * 13), p(47, 12, -36 + j * 13), 0.13, C(230, 198, 135), MAT.Fabric)
			for k = 1, 2 do pennant(p(26 + k * 7, 10, -36 + j * 13), k == 1 and C(247, 219, 143) or C(179, 240, 184), 3) end
		end
	elseif theme == "village" then
		-- A teal-roof bell tower with bright festival bunting between the houses.
		local at = p(-66, 0, -3)
		b("BellTowerFoundation", Vector3.new(23, 3, 25), at + Vector3.new(0, 1.5, 0), C(231, 200, 164))
		for _, x in { -8, 8 } do
			for _, z in { -8, 8 } do b("BellTowerUpright", Vector3.new(1.8, 28, 1.8), at + Vector3.new(x, 16, z), C(210, 126, 114), MAT.Wood) end
		end
		b("BellTowerFloor", Vector3.new(21, 1.5, 21), at + Vector3.new(0, 19, 0), C(235, 182, 132), MAT.WoodPlanks)
		roof(at + Vector3.new(0, 32, 0), 29, 27, C(64, 163, 190))
		disc("FestivalBell", 3.8, 6, at + Vector3.new(0, 25, 0), C(253, 206, 108), MAT.Metal)
		disc("BellLip", 4.5, 0.8, at + Vector3.new(0, 22, 0), C(255, 230, 152), MAT.Metal)
		for _, z in { -12, 13 } do
			beam("FestivalCable", p(-29, 15, z), p(29, 15, z), 0.15, C(197, 152, 128))
			for j = 1, 7 do pennant(p(-28 + j * 7, 13.5, z), ({ C(251, 151, 174), C(255, 218, 119), C(119, 222, 211) })[j % 3 + 1], 2.3) end
		end
	elseif theme == "ice" then
		-- Giant frost-lotus shrine, made of angular ice petals rather than a generic rock.
		local at = p(38, 0, -4)
		disc("FrostLotusBase", 13, 1.8, at + Vector3.new(0, 0.9, 0), C(204, 242, 255), MAT.Ice)
		for j = 1, 8 do
			local a = j * math.pi / 4
			local atPetal = at + Vector3.new(math.cos(a) * 6, 9, math.sin(a) * 6)
			b("LotusPetal", Vector3.new(3.8, 20, 2.6), atPetal, j % 2 == 0 and C(160, 224, 255) or C(215, 245, 255), MAT.Ice,
				CFrame.Angles(math.sin(a) * 0.37, a, math.cos(a) * 0.37))
		end
		crystal(at + Vector3.new(0, 17, 0), Vector3.new(5, 25, 5), C(121, 231, 255), 0)
		for j = 1, 3 do
			crystal(p(-37 + j * 2, 5 + j * 4, -26 + j * 14), Vector3.new(4.5, 12 + j * 3, 4.5), C(192, 237, 255), -22 + j * 8)
		end
		for j = 1, 5 do
			local atFlake = p(-34, 16 + j, -46 + j * 17)
			beam("FloatingSnowGlyph", atFlake - Vector3.new(2, 0, 0), atFlake + Vector3.new(2, 0, 0), 0.25, C(241, 255, 255), MAT.Neon)
			beam("FloatingSnowGlyph", atFlake - Vector3.new(0, 2, 0), atFlake + Vector3.new(0, 2, 0), 0.25, C(241, 255, 255), MAT.Neon)
		end
	elseif theme == "thunder" then
		-- A suspended storm wheel and lightning suspended between golden pylons.
		local at = p(-37, 22, 0)
		arch("StormWheel", at, 13, 0, 360, 12, C(149, 115, 222), 2, 2)
		arch("StormWheelTrim", at + Vector3.new(0, 0, -1.2), 14.5, 0, 360, 12, C(255, 226, 118), 0.45, 0.45)
		orb("StormHeart", Vector3.new(7, 7, 7), at, C(255, 230, 110), MAT.Neon)
		for j = 1, 6 do
			local a = j * math.pi / 3
			beam("StormSpoke", at + Vector3.new(math.cos(a) * 4, math.sin(a) * 4, 0), at + Vector3.new(math.cos(a) * 12, math.sin(a) * 12, 0), 0.7, C(237, 217, 159), MAT.Metal)
		end
		for j = 1, 5 do
			local x = 34 + (j % 2) * 4
			beam("ForkedLightning", p(x, 8 + j * 4, -3), p(x + (j % 2 == 0 and -5 or 5), 12 + j * 4, -3), 0.8, C(255, 231, 122), MAT.Neon)
		end
		for j = 1, 3 do crystal(p(36, 7 + j, -46 + j * 22), Vector3.new(4, 13 + j * 2, 4), C(195, 150, 245), j * 7 - 13) end
	elseif theme == "temple" then
		-- The three-tier Scarlet Lantern pagoda dominates a lush side terrace.
		local at = p(-68, 0, -6)
		b("PagodaBase", Vector3.new(31, 2.2, 31), at + Vector3.new(0, 1.1, 0), C(243, 204, 153))
		for level = 1, 3 do
			local width, h = 28 - level * 4, 4 + (level - 1) * 10
			b("PagodaChamber", Vector3.new(width - 3, 8, width - 3), at + Vector3.new(0, h + 4, 0), C(230, 96, 103), MAT.SmoothPlastic)
			roof(at + Vector3.new(0, h + 9, 0), width + 6, width + 4, C(87, 113, 159))
			for _, side in { -1, 1 } do
				b("PagodaWindow", Vector3.new(2.5, 4.8, 0.16), at + Vector3.new(side * width * 0.22, h + 4, -(width - 3) * 0.5 - 0.1), C(255, 219, 144), MAT.Neon)
			end
		end
		b("PagodaSpire", Vector3.new(0.9, 10, 0.9), at + Vector3.new(0, 38, 0), C(255, 218, 129), MAT.Metal)
		for j = 1, 4 do disc("SpireRing", 2.8 - j * 0.4, 0.4, at + Vector3.new(0, 34 + j * 2, 0), C(255, 218, 129), MAT.Metal) end
		local bowl = p(37, 2, -2)
		disc("SunBrazier", 8, 3, bowl, C(253, 183, 92), MAT.Metal)
		for j = 1, 7 do
			local a = j * math.pi * 2 / 7
			b("BrazierFlame", Vector3.new(1.7, 7 + j % 3 * 2, 1.7), bowl + Vector3.new(math.cos(a) * 3.7, 5, math.sin(a) * 3.7), C(255, 170 + j * 7, 95), MAT.Neon,
				CFrame.Angles(0, a, math.rad(j % 2 * 18 - 9)))
		end
	elseif theme == "shadow" then
		-- Mint-lit crescent monument: shadow remains readable in the shared daylight.
		local at = p(35, 27, -5)
		arch("MoonCrescentOuter", at, 16, 62, 302, 13, C(201, 214, 255), 3.8, 3.8)
		arch("MoonCrescentCore", at + Vector3.new(0, 0, -2), 14.5, 67, 297, 12, C(162, 255, 230), 0.8, 0.8)
		for j = 1, 3 do
			local atRoot = p(-34, 0, -41 + j * 23)
			beam("MoonTreeTrunk", atRoot, atRoot + Vector3.new(0, 16 + j * 2, 0), 2, C(114, 104, 169))
			for _, side in { -1, 1 } do
				beam("MoonTreeBranch", atRoot + Vector3.new(0, 10, 0), atRoot + Vector3.new(side * 8, 16 + j, 1), 1.1, C(139, 124, 189))
				orb("MoonTreeCanopy", Vector3.new(9, 5, 8), atRoot + Vector3.new(side * 7, 18 + j, 1), C(166, 172, 239))
				orb("MoonlightFruit", Vector3.new(1.1, 1.5, 1.1), atRoot + Vector3.new(side * 7, 13 + j, 1), C(164, 255, 226), MAT.Neon)
			end
		end
	elseif theme == "water" then
		-- Waterfall terraces and an oversized ceremonial koi carved in living gold.
		for level = 1, 3 do
			local at = p(-66, level * 8 - 3, -25 + level * 12)
			b("TideTerrace", Vector3.new(22, 9, 25), at, C(113, 188, 187))
			b("TideTerraceWater", Vector3.new(23, 0.3, 23), at + Vector3.new(0, 4.7, 0), C(122, 243, 237), MAT.Glass).Transparency = 0.1
			b("TerraceCascade", Vector3.new(0.3, 10, 14), at + Vector3.new(11.2, 0, 0), C(172, 249, 244), MAT.Glass).Transparency = 0.2
		end
		local at = p(37, 10, -4)
		orb("GoldenKoiBody", Vector3.new(8, 9, 22), at, C(255, 218, 123), MAT.SmoothPlastic)
		orb("KoiWhitePattern", Vector3.new(8.2, 5, 7), at + Vector3.new(0, 1.5, 3), C(255, 246, 208))
		orb("KoiCoralPattern", Vector3.new(8.2, 5, 5), at + Vector3.new(0, 2, -5), C(255, 149, 132))
		for _, side in { -1, 1 } do
			b("KoiSideFin", Vector3.new(7, 0.8, 7), at + Vector3.new(side * 5.5, -1.5, 0), C(253, 237, 175), nil, CFrame.Angles(0, math.rad(side * 25), math.rad(side * -12)))
			orb("KoiEye", Vector3.new(1, 1.5, 1), at + Vector3.new(side * 3.3, 1.5, -8), C(89, 134, 151))
			b("KoiTailFin", Vector3.new(7, 1, 7), at + Vector3.new(side * 2.2, 0, 12), C(255, 187, 125), nil, CFrame.Angles(0, math.rad(side * 32), 0))
		end
		disc("KoiSculptureFoot", 11, 1.5, p(37, 0.75, -4), C(233, 231, 198))
	elseif theme == "sky" then
		-- A floating sky garden. Stair fragments are scenic, not false walkable routes.
		local at = p(-66, 18, -3)
		b("CloudGardenRock", Vector3.new(26, 12, 28), at, C(149, 184, 220), nil, CFrame.Angles(0, math.rad(25), math.rad(-6)))
		disc("CloudGardenGrass", 15, 1.6, at + Vector3.new(0, 7, 0), C(156, 232, 186))
		for _, x in { -8, 8 } do
			for _, z in { -7, 7 } do b("CloudPavilionPillar", Vector3.new(1.2, 11, 1.2), at + Vector3.new(x, 13, z), C(254, 239, 203), MAT.Marble) end
		end
		roof(at + Vector3.new(0, 19, 0), 25, 23, C(102, 205, 226))
		cloud(at + Vector3.new(0, -7, 0), Vector3.new(39, 9, 31))
		for j = 1, 4 do
			b("FloatingStair", Vector3.new(8, 1.3, 5), p(-31 - j * 5, 4 + j * 3.5, 20), C(228, 246, 255), MAT.Marble)
		end
		for j = 1, 3 do
			local atIsland = p(58 + j * 4, 8 + j * 5, -43 + j * 24)
			b("SatelliteGardenRock", Vector3.new(13, 8, 12), atIsland, C(151, 181, 225), nil, CFrame.Angles(0, j, 0))
			disc("SatelliteGrass", 7, 1.2, atIsland + Vector3.new(0, 4, 0), C(173, 238, 180))
			cloud(atIsland - Vector3.new(0, 4, 0), Vector3.new(23, 6, 17))
		end
	elseif theme == "lava" then
		-- A monumental sun-forge, with magma ribbons and a broad anime anvil.
		local at = p(-37, 0, -2)
		disc("SunforgePlinth", 13, 3, at + Vector3.new(0, 1.5, 0), C(161, 110, 138))
		disc("MoltenForgeBowl", 10, 1.4, at + Vector3.new(0, 3.4, 0), C(255, 170, 81), MAT.Neon)
		arch("SunforgeArch", at + Vector3.new(0, 9, 0), 11.5, 0, 180, 9, C(108, 91, 137), 4, 4)
		for j = 1, 6 do
			local a = j * math.pi * 2 / 6
			b("ForgeFin", Vector3.new(2, 10, 2), at + Vector3.new(math.cos(a) * 8, 7, math.sin(a) * 8), C(255, 194, 108), MAT.Metal,
				CFrame.Angles(0, a, math.rad(15)))
		end
		b("AnvilFoot", Vector3.new(15, 3, 13), p(36, 1.5, -3), C(163, 116, 142))
		b("AnvilWaist", Vector3.new(7, 5, 7), p(36, 5, -3), C(113, 103, 140), MAT.Metal)
		b("AnvilFace", Vector3.new(19, 2.4, 11), p(36, 8.5, -3), C(178, 157, 193), MAT.Metal)
		b("AnvilHorn", Vector3.new(9, 2.3, 6), p(47, 8.3, -3), C(211, 171, 197), MAT.Metal, CFrame.Angles(0, 0, math.rad(-9)))
		crystal(p(34, 16, -3), Vector3.new(2.2, 17, 1.5), C(255, 203, 113), -12)
		for j = 1, 4 do
			beam("RisingMagmaRibbon", p(-48, 3 + j * 5, -13), p(-45 + j % 2 * 3, 7 + j * 5, -13), 0.5, C(255, 191, 104), MAT.Neon)
		end
	elseif theme == "spirit" then
		-- A pale spirit tree bearing suspended paper lanterns and floating gates.
		local at = p(-36, 0, -3)
		beam("SpiritTreeTrunk", at, at + Vector3.new(-3, 26, 0), 4, C(225, 229, 222))
		for j = 1, 5 do
			local side = j % 2 == 0 and -1 or 1
			local endPos = at + Vector3.new(side * (7 + j * 1.4), 16 + j * 3, (j - 3) * 3)
			beam("SpiritTreeBough", at + Vector3.new(-1, 10 + j * 2, 0), endPos, 1.7, C(233, 235, 229))
			orb("SpiritTreeFoliage", Vector3.new(11, 7, 11), endPos + Vector3.new(0, 2, 0), j % 2 == 0 and C(185, 239, 232) or C(215, 208, 251))
			beam("LanternThread", endPos, endPos - Vector3.new(0, 6, 0), 0.09, C(188, 163, 220))
			b("SpiritPaperLantern", Vector3.new(2, 3, 2), endPos - Vector3.new(0, 7, 0), C(255, 225, 179), MAT.Neon)
			b("LanternTop", Vector3.new(2.2, 0.25, 2.2), endPos - Vector3.new(0, 5.4, 0), C(174, 150, 198))
		end
		for j = 1, 3 do
			local atGate = p(36, 8 + j * 5, -27 + j * 13)
			for _, side in { -1, 1 } do b("FloatingGatePost", Vector3.new(0.7, 6, 0.7), atGate + Vector3.new(side * 3, 0, 0), C(189, 242, 223)) end
			b("FloatingGateLintel", Vector3.new(9, 0.8, 1.3), atGate + Vector3.new(0, 3, 0), C(245, 224, 159))
		end
	elseif theme == "dragon" then
		-- The Jade Leviathan: a side-lane skeleton with six sweeping gold-white ribs.
		local at = p(-36, 0, -3)
		beam("LeviathanSpine", at + Vector3.new(0, 23, -28), at + Vector3.new(0, 23, 27), 2, C(248, 231, 185))
		for j = 1, 6 do
			local ribAt = at + Vector3.new(0, 11, -34 + j * 10)
			arch("LeviathanRib", ribAt, 11 + math.sin(j / 6 * math.pi) * 2, 6, 174, 5, C(240, 220, 172), 1.4, 1.4)
		end
		orb("LeviathanSkull", Vector3.new(10, 8, 13), at + Vector3.new(0, 22, -36), C(244, 226, 183))
		b("LeviathanMuzzle", Vector3.new(7, 3, 9), at + Vector3.new(0, 20, -43), C(228, 203, 159))
		for _, side in { -1, 1 } do
			beam("LeviathanHorn", at + Vector3.new(side * 3, 25, -35), at + Vector3.new(side * 7, 33, -29), 1.2, C(255, 215, 121), MAT.Metal)
			orb("LeviathanEye", Vector3.new(1.2, 1.2, 0.7), at + Vector3.new(side * 3.9, 22.8, -41.7), C(122, 247, 197), MAT.Neon)
		end
		for j = 1, 4 do
			crystal(p(36, 4 + j % 2, -43 + j * 19), Vector3.new(3.6, 8 + j, 3.6), C(151, 230, 171), j * 5 - 12)
		end
	elseif theme == "void" then
		-- A bright magenta rift held between sheared monoliths and orbiting fragments.
		local at = p(36, 17, -3)
		for _, side in { -1, 1 } do
			b("ShearedMonolith", Vector3.new(5, 31, 7), at + Vector3.new(side * 7, 0, 0), C(140, 112, 198), nil, CFrame.Angles(0, 0, math.rad(side * -16)))
			b("RiftEdge", Vector3.new(0.5, 27, 0.5), at + Vector3.new(side * 3, 0, -4), C(255, 148, 230), MAT.Neon,
				CFrame.Angles(0, 0, math.rad(side * -10)))
		end
		local veil = b("RiftMembrane", Vector3.new(7, 26, 0.2), at, C(195, 145, 246), MAT.Glass)
		veil.Transparency = 0.25
		for j = 1, 8 do
			local a = j * math.pi / 4
			b("OrbitingRiftShard", Vector3.new(2.6, 4.5, 2.2), at + Vector3.new(math.cos(a) * 15, math.sin(a) * 14, 1), C(225, 189, 255), MAT.Glass,
				CFrame.Angles(0, a, a * 0.6))
		end
		for j = 1, 4 do
			local atScar = p(-37, 0.3, -43 + j * 19)
			b("VoidGroundShard", Vector3.new(14, 0.12, 2.6), atScar, C(219, 142, 255), MAT.Neon, CFrame.Angles(0, math.rad(-20 + j * 8), 0))
			b("UpliftedScarFragment", Vector3.new(6, 3, 6), atScar + Vector3.new(0, 3 + j, 0), C(166, 131, 210), nil, CFrame.Angles(j * 0.1, j * 0.5, 0.3))
		end
	elseif theme == "celestial" then
		-- A golden astrolabe with two perpendicular rings above a radiant garden.
		local at = p(-36, 23, -3)
		arch("SolarAstrolabe", at, 14, 0, 360, 12, C(255, 216, 117), 1.3, 1.3)
		for j = 1, 12 do
			local a0, a1 = (j - 1) * math.pi / 6, j * math.pi / 6
			beam("AstralMeridian", at + Vector3.new(0, math.cos(a0) * 11, math.sin(a0) * 11), at + Vector3.new(0, math.cos(a1) * 11, math.sin(a1) * 11), 0.8, C(239, 246, 255), MAT.Metal)
		end
		orb("SolarPearl", Vector3.new(8, 8, 8), at, C(255, 237, 178), MAT.Neon)
		b("AstrolabeStem", Vector3.new(2.4, 10, 2.4), p(-36, 5, -3), C(255, 225, 147), MAT.Metal)
		disc("AstrolabeFoot", 11, 2, p(-36, 1, -3), C(237, 242, 245), MAT.Marble)
		for j = 1, 4 do
			local atArch = p(36, 0, -47 + j * 21)
			for _, side in { -1, 1 } do b("CelestialGardenPost", Vector3.new(1.3, 12, 1.3), atArch + Vector3.new(side * 5, 6, 0), C(243, 242, 228), MAT.Marble) end
			arch("CelestialGardenArch", atArch + Vector3.new(0, 12, 0), 5, 0, 180, 5, C(255, 219, 131), 1, 1)
		end
	elseif theme == "throne" then
		-- An asymmetrical imperial fan of giant ceremonial swords crowns the finale.
		local at = p(36, 0, -4)
		disc("ImperialDais", 13, 2.8, at + Vector3.new(0, 1.4, 0), C(255, 218, 136), MAT.Marble)
		for j = 1, 5 do
			local x, angle = (j - 3) * 4, math.rad((j - 3) * -11)
			local h = 26 - math.abs(j - 3) * 3
			b("CrownBlade", Vector3.new(2.1, h, 1), at + Vector3.new(x, 4 + h / 2, 0), C(217, 237, 255), MAT.Metal, CFrame.Angles(0, 0, angle))
			b("CrownBladeInlay", Vector3.new(0.3, h - 1, 1.1), at + Vector3.new(x, 4 + h / 2, 0), C(255, 230, 155), MAT.Neon, CFrame.Angles(0, 0, angle))
			b("CrownBladeGuard", Vector3.new(7, 1, 2.5), at + Vector3.new(x, 4, 0), C(255, 206, 108), MAT.Metal)
		end
		for j = 1, 3 do
			local atSeat = p(-37, 0, -41 + j * 23)
			b("ImperialGalleryBase", Vector3.new(18, 1, 14), atSeat + Vector3.new(0, 0.5, 0), C(236, 216, 185), MAT.Marble)
			for _, side in { -1, 1 } do b("GalleryPillar", Vector3.new(1.5, 15, 1.5), atSeat + Vector3.new(side * 7, 8, 0), C(223, 214, 247), MAT.Marble) end
			b("ImperialGalleryLintel", Vector3.new(19, 1.5, 3), atSeat + Vector3.new(0, 15.5, 0), C(255, 218, 139), MAT.Metal)
			pennant(atSeat + Vector3.new(0, 11, 0), C(175, 126, 216), 8)
		end
	end
end


function W.build(SD)
	local previous = workspace:FindFirstChild("AnimeSwordWorld")
	if previous then previous:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "AnimeSwordWorld"
	folder.Parent = workspace
	local result = {
		folder = folder,
		spawn = CFrame.new(0, 4, 145),
		rooms = {}, training = {}, roomPrompts = {}, returnPrompts = {}, hubPrompts = {}, swordPrompts = {}, eggPrompts = {},
	}

	folder:SetAttribute("WorldVersion", W.BAKED_VERSION)
	folder:SetAttribute("Spawn", result.spawn)
	applyLighting()
	buildHub(SD, folder, result)

	bridge(folder, -80, -136, C(181, 75, 85))
	for i, def in SD.STAGES do
		local center = Vector3.new(0, 0, -(i * 160 + 40))
		local room = model(folder, ("Room_%02d_%s"):format(i, def.name))
		room:SetAttribute("RoomIndex", i)
		local theme = THEMES[i] -- Stable biome identity even when stage display names are customized.
		local accent = def.color
		decorateRoom(room, center, theme, accent, i)
		polishRealm(room, center, theme, accent, i)
		-- A sequence of small battle courts frames the encounter road; side gaps
		-- remain wide enough to dodge, explore landmarks and reach recall sigils.
		local courts = model(room, "EncounterCourtyards")
		for _, side in { -1, 1 } do
			for _, dz in { 28, -4, -35 } do
				local p = center + Vector3.new(side * 19, 0, dz)
				block(courts, "CourtPlanter", Vector3.new(3, 0.8, 15), p + Vector3.new(0, 0.4, 0), C(222, 202, 213), MAT.Slate)
				block(courts, "CourtFoliage", Vector3.new(2.6, 2.4, 14), p + Vector3.new(0, 1.9, 0), accent:Lerp(C(92, 164, 119), 0.55), MAT.Grass, nil, false)
				block(courts, "CourtEndPost", Vector3.new(1, 4, 1), p + Vector3.new(0, 2, 8), accent, MAT.Wood)
			end
		end
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
		local recallPrompt = prompt(returnStone, "Return to sanctuary", "Recall sigil", 10)
		recallPrompt:SetAttribute("RoomIndex", i)
		recallPrompt:SetAttribute("ReturnHub", true)
		result.returnPrompts[i] = recallPrompt
		local enemySpawns = {}
		for step, offset in { Vector3.new(-6, 3.2, 28), Vector3.new(6, 3.2, 12), Vector3.new(-6, 3.2, -4), Vector3.new(6, 3.2, -20), Vector3.new(-5, 3.2, -35), Vector3.new(0, 3.2, -49) } do
			enemySpawns[step] = CFrame.new(center + offset) * CFrame.Angles(0, math.pi, 0)
			local spawnMarker = interactionMarker(room, "EncounterSpawn_" .. step, center + offset)
			spawnMarker.CFrame = enemySpawns[step]
			spawnMarker:SetAttribute("RoomIndex", i)
			spawnMarker:SetAttribute("EncounterStep", step)
			if step < 6 then
				cylinder(room, "EnemySeal_" .. step, 3.2, 0.06, center + Vector3.new(offset.X, 0.12, offset.Z), accent, MAT.Neon, false)
			end
		end
		room:SetAttribute("RoomCenter", center)
		room:SetAttribute("RoomSpawn", CFrame.new(center + Vector3.new(0, 4, 50)))
		room:SetAttribute("RoomEntry", entry)
		result.rooms[i] = {
			center = center, spawn = CFrame.new(center + Vector3.new(0, 4, 50)),
			enemySpawns = enemySpawns, entry = entry,
		}
		if i < #SD.STAGES then bridge(folder, center.Z - 64, center.Z - 96, accent) end
	end
	return result
end

-- Reuse the edit-time baked map so Studio edits survive Play. Runtime-only builds
-- remain available through W.build for the scripts-only installation.
function W.load(SD)
	local folder = workspace:FindFirstChild("AnimeSwordWorld")
	if not folder or folder:GetAttribute("BakedWorldVersion") ~= W.BAKED_VERSION then
		if folder and folder:GetAttribute("BakedWorldVersion") ~= nil then
			-- Keep incompatible baked maps recoverable instead of deleting user edits.
			local storage = game:GetService("ServerStorage")
			local backups = storage:FindFirstChild("BladeboundWorldBackups")
			if not backups then backups = Instance.new("Folder"); backups.Name = "BladeboundWorldBackups"; backups.Parent = storage end
			folder.Name = "PreservedWorld_" .. tostring(os.time())
			folder.Parent = backups
			warn("Bladebound: preserved an older baked map in ServerStorage.BladeboundWorldBackups before building the current world.")
		end
		return W.build(SD)
	end
	local result = { folder = folder, spawn = folder:GetAttribute("Spawn"), rooms = {}, training = {},
		roomPrompts = {}, returnPrompts = {}, hubPrompts = {}, swordPrompts = {}, eggPrompts = {} }
	local encounterMarkers = {}
	local valid = typeof(result.spawn) == "CFrame"
	local function index(n, count)
		return type(n) == "number" and n % 1 == 0 and n >= 1 and n <= count
	end
	for _, obj in folder:GetDescendants() do
		local roomIndex, trainingId = obj:GetAttribute("RoomIndex"), obj:GetAttribute("TrainingId")
		if obj:IsA("Model") and index(roomIndex, #SD.STAGES) then
			if result.rooms[roomIndex] then valid = false end
			local center, spawn, entry = obj:GetAttribute("RoomCenter"), obj:GetAttribute("RoomSpawn"), obj:GetAttribute("RoomEntry")
			if typeof(center) ~= "Vector3" or typeof(spawn) ~= "CFrame" or typeof(entry) ~= "CFrame" then valid = false end
			result.rooms[roomIndex] = { center = center, spawn = spawn, entry = entry, enemySpawns = {} }
		elseif obj:IsA("Model") and index(trainingId, #SD.TRAINING) then
			if result.training[trainingId] then valid = false end
			local center, radius = obj:GetAttribute("TrainingCenter"), obj:GetAttribute("TrainingRadius")
			if typeof(center) ~= "Vector3" or type(radius) ~= "number" or radius <= 0 then valid = false end
			result.training[trainingId] = { id = trainingId, center = center, radius = radius }
		elseif obj:IsA("BasePart") and index(roomIndex, #SD.STAGES) and index(obj:GetAttribute("EncounterStep"), SD.STAGE_MINIONS + 1) then
			table.insert(encounterMarkers, obj)
		end
	end
	for _, obj in folder:GetDescendants() do
		if obj:IsA("ProximityPrompt") then
			local roomIndex, trainingId = obj:GetAttribute("RoomIndex"), obj:GetAttribute("TrainingId")
			local swordIndex, eggIndex, tab = obj:GetAttribute("SwordIndex"), obj:GetAttribute("EggIndex"), obj:GetAttribute("HubTab")
			if index(trainingId, #SD.TRAINING) and result.training[trainingId] then
				result.training[trainingId].prompt = obj
			elseif index(swordIndex, #SD.SWORDS) then result.swordPrompts[swordIndex] = obj
			elseif index(eggIndex, #SD.EGGS) then result.eggPrompts[eggIndex] = obj
			elseif tab == "Swords" or tab == "Pets" or tab == "Auras" then result.hubPrompts[tab] = obj
			elseif index(roomIndex, #SD.STAGES) then
				if obj:GetAttribute("ReturnHub") == true then result.returnPrompts[roomIndex] = obj
				else result.roomPrompts[roomIndex] = obj end
			end
		end
	end
	for _, marker in encounterMarkers do
		local room = result.rooms[marker:GetAttribute("RoomIndex")]
		if room then
			local step = marker:GetAttribute("EncounterStep")
			if room.enemySpawns[step] then valid = false end
			room.enemySpawns[step] = marker.CFrame
		end
	end
	for i = 1, #SD.STAGES do
		local room = result.rooms[i]
		if not room or not result.roomPrompts[i] or not result.returnPrompts[i] then valid = false
		else
			for step = 1, SD.STAGE_MINIONS + 1 do if typeof(room.enemySpawns[step]) ~= "CFrame" then valid = false end end
		end
	end
	for i = 1, #SD.TRAINING do if not result.training[i] or not result.training[i].prompt then valid = false end end
	for i = 1, #SD.SWORDS do if not result.swordPrompts[i] then valid = false end end
	for i = 1, #SD.EGGS do if not result.eggPrompts[i] then valid = false end end
	for _, tab in { "Swords", "Pets", "Auras" } do if not result.hubPrompts[tab] then valid = false end end
	if valid then applyLighting(); return result end
	-- Missing metadata is recoverable; the original remains available for inspection.
	local storage = game:GetService("ServerStorage")
	local backups = storage:FindFirstChild("BladeboundWorldBackups")
	if not backups then backups = Instance.new("Folder"); backups.Name = "BladeboundWorldBackups"; backups.Parent = storage end
	folder.Name = "PreservedWorld_" .. tostring(os.time())
	folder.Parent = backups
	warn("Bladebound: baked world metadata was incomplete. The original is preserved in ServerStorage.BladeboundWorldBackups; generating a working fallback.")
	return W.build(SD)
end

return W
