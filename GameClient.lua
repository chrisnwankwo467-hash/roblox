--[[
    BLADEBOUND / SPIRIT TRIALS — LocalScript in StarterPlayer > StarterPlayerScripts.
    Owns presentation and input only. The server owns damage, rewards and progression.
    All art is made from Roblox primitives; no private animation or image assets required.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local SD = require(ReplicatedStorage:WaitForChild("SwordData"))
local action = ReplicatedStorage:WaitForChild("GameAction")
local sync = ReplicatedStorage:WaitForChild("GameSync")
local fmt = SD.fmt
local state, currentTab, lastVer = nil, nil, nil
local autoSwing, lastSwing, combo = false, 0, 0
local afford, navButtons = {}, {}
local openTab, render, requestSwing
local c = Color3.fromRGB
local C = {
    ink = c(16, 22, 43), panel = c(24, 31, 56), card = c(34, 44, 73),
    line = c(76, 100, 144), white = c(245, 250, 255), muted = c(176, 196, 222),
    gold = c(255, 220, 57), orange = c(255, 151, 36), blue = c(46, 179, 255),
    cyan = c(75, 235, 229), green = c(113, 235, 75), pink = c(255, 89, 188),
    purple = c(175, 83, 255), red = c(240, 91, 109), grey = c(84, 99, 123),
}
local RARITY = {
    Common = C.muted, Uncommon = C.green, Rare = C.blue, Epic = C.purple,
    Legendary = C.gold, Mythic = C.pink,
}

local function new(class, props, parent)
    local object = Instance.new(class)
    for key, value in props do object[key] = value end
    object.Parent = parent
    return object
end
local function corner(object, radius)
    new("UICorner", { CornerRadius = UDim.new(0, radius or 14) }, object)
end
local function stroke(object, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or C.ink, Thickness = thickness or 2,
        Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, object)
end
local function gradient(object, top, bottom, rotation)
    return new("UIGradient", {
        Color = ColorSequence.new(top, bottom), Rotation = rotation or 90,
    }, object)
end
local function text(parent, value, size, position, fontSize, color, font, align)
    return new("TextLabel", {
        Size = size, Position = position or UDim2.new(), BackgroundTransparency = 1,
        Text = value, TextSize = fontSize or 20, TextColor3 = color or C.white,
        Font = font or Enum.Font.GothamBold, TextXAlignment = align or Enum.TextXAlignment.Left,
        TextWrapped = true, TextStrokeTransparency = 0.35, TextStrokeColor3 = C.ink,
    }, parent)
end
local function button(parent, caption, color, size, position, callback)
    local b = new("TextButton", {
        Size = size, Position = position or UDim2.new(), BackgroundColor3 = color,
        Text = caption, Font = Enum.Font.FredokaOne, TextSize = 20,
        TextColor3 = C.white, TextStrokeColor3 = C.ink, TextStrokeTransparency = 0.35,
        AutoButtonColor = true, BorderSizePixel = 0, Selectable = true,
    }, parent)
    corner(b, 8)
    stroke(b, C.ink, 4)
    gradient(b, c(255, 255, 255), c(182, 195, 220))
    if callback then b.Activated:Connect(callback) end
    return b
end
local function frame(parent, size, position, color)
    local f = new("Frame", {
        Size = size, Position = position or UDim2.new(), BackgroundColor3 = color or C.panel,
        BorderSizePixel = 0,
    }, parent)
    corner(f)
    stroke(f, C.line, 2)
    return f
end
-- Vector icons remain crisp without relying on external image assets.
local function icon(parent, kind, color)
    local box = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(40, 40) }, parent)
    local function block(w, h, x, y, rot, round)
        local p = new("Frame", { Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x, y),
            BackgroundColor3 = color, BorderSizePixel = 0, Rotation = rot or 0 }, box)
        if round then corner(p, round) end
        return p
    end
    if kind == "sword" then
        block(7, 27, 18, 0, 35, 2); block(23, 5, 5, 25, 35, 2); block(6, 13, 7, 27, 35, 2)
    elseif kind == "trophy" then
        block(22, 19, 9, 3, 0, 6); block(7, 13, 16, 19, 0, 2); block(25, 6, 7, 31, 0, 3)
        local cup = block(36, 16, 2, 5, 0, 8); cup.BackgroundTransparency = 1; stroke(cup, color, 3)
    elseif kind == "gem" then
        block(23, 23, 8, 8, 45, 3); block(4, 14, 17, 12, 0, 2).BackgroundColor3 = C.white
    elseif kind == "room" then
        block(28, 34, 6, 3, 0, 3); block(17, 25, 11, 11, 0, 1).BackgroundColor3 = C.ink
    elseif kind == "training" then
        block(28, 6, 6, 17, 0, 2); block(8, 25, 2, 7, 0, 3); block(8, 25, 30, 7, 0, 3)
    elseif kind == "pet" then
        block(26, 24, 7, 12, 0, 8); block(10, 14, 7, 4, -20, 3); block(10, 14, 23, 4, 20, 3)
        block(4, 5, 13, 21, 0, 2).BackgroundColor3 = C.ink
        block(4, 5, 24, 21, 0, 2).BackgroundColor3 = C.ink
    elseif kind == "aura" then
        local ring = block(31, 31, 4, 4, 0, 20); ring.BackgroundTransparency = 1; stroke(ring, color, 4)
        block(10, 10, 15, 15, 45, 2)
    elseif kind == "rebirth" then
        local ring = block(28, 28, 6, 6, 0, 20); ring.BackgroundTransparency = 1; stroke(ring, color, 4)
        block(10, 10, 26, 5, 45, 1)
    else
        block(31, 24, 5, 8, -12, 5); block(18, 3, 11, 18, -12, 1).BackgroundColor3 = C.ink
    end
    return box
end

local gui = new("ScreenGui", {
    Name = "BladeboundHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = false, DisplayOrder = 10,
}, player:WaitForChild("PlayerGui"))
local root = new("Frame", {
    Name = "ResponsiveCanvas", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(1280, 720), BackgroundTransparency = 1,
}, gui)
local uiScale = new("UIScale", { Scale = 1 }, root)
local brand = text(root, "BLADEBOUND", UDim2.fromOffset(390, 38), UDim2.fromOffset(20, 2), 28, C.white, Enum.Font.GothamBlack)
local subtitle = text(root, "S P I R I T   T R I A L S", UDim2.fromOffset(390, 20), UDim2.fromOffset(22, 36), 12, C.cyan)
local function currency(kind, title, color)
    local box = frame(root, UDim2.fromOffset(235, 72), nil, color:Lerp(C.ink, 0.45))
    gradient(box, c(255,255,255), c(145,155,200))
    stroke(box, color, 2)
    local symbol = icon(box, kind, color); symbol.Position = UDim2.fromOffset(12, 16)
    local value = text(box, "0", UDim2.new(1, -68, 0, 33), UDim2.fromOffset(62, 5), 27, C.white, Enum.Font.GothamBlack)
    text(box, title, UDim2.new(1, -68, 0, 22), UDim2.fromOffset(62, 40), 13, color)
    return box, value
end
local spiritCard, spiritLabel = currency("gem", "SPIRIT", C.cyan)
local trophyCard, trophyLabel = currency("trophy", "TROPHIES", C.gold)
local powerCard, powerLabel = currency("sword", "DAMAGE / HIT", C.pink)
local rebirthTag = text(root, "REBIRTH 0", UDim2.fromOffset(200, 25), UDim2.new(), 16, C.purple, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)

local route = frame(root, UDim2.fromOffset(440, 66), nil, c(255,255,255))
gradient(route,C.purple,C.blue,0)
local routeTitle = text(route, "ROOM 01 / 15", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 6), 16, C.gold)
local routeText = text(route, "TRAIN. FIGHT. ASCEND.", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 29), 14, C.white)
local nav = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 490) }, root)
local tabs = {
    { "Swords", "sword", C.orange }, { "Rooms", "room", C.green },
    { "Training", "training", C.cyan }, { "Pets", "pet", C.pink },
    { "Auras", "aura", C.purple }, { "Rebirth", "rebirth", C.gold },
    { "Codes", "code", C.blue },
}
local navTitles, navIcons = {}, {}
local upgradeBadge
for i, tab in tabs do
    local b = button(nav, "", tab[3], UDim2.fromOffset(110, 88), UDim2.new(), function()
        openTab(tab[1])
    end)
    local symbol = icon(b, tab[2], C.white)
    local title = text(b, tab[1]:upper(), UDim2.new(1, -8, 0, 24), UDim2.fromOffset(4, 58), 17, C.white, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
    title.TextStrokeTransparency = 0
    navButtons[i], navTitles[i], navIcons[i] = b, title, symbol
    if i == 1 then
        upgradeBadge = text(b, "!", UDim2.fromOffset(26, 26), UDim2.new(1, -25, 0, -8), 21, C.white, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
        upgradeBadge.BackgroundColor3 = C.red; upgradeBadge.BackgroundTransparency = 0
        corner(upgradeBadge, 20); stroke(upgradeBadge, C.ink, 3)
        upgradeBadge.Visible = false
    end
end

local quest = frame(root, UDim2.fromOffset(252, 180), nil, C.ink)
text(quest, "YOUR QUEST TRAIL", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 12), 14, C.gold)
local questTitle = text(quest, "Train your first blade", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 40), 21, C.white, Enum.Font.GothamBlack)
local questDetail = text(quest, "Earn Spirit with every swing. Walk through the gate to Room 1.", UDim2.new(1, -24, 0, 52), UDim2.fromOffset(12, 82), 13, C.white)
local questReward = text(quest, "+5 TROPHIES", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 136), 15, C.green)

local questButton = button(quest,"START TRAINING",C.green,UDim2.new(1,-24,0,34),UDim2.new(0,12,1,-44),function()
    if not state then return end
    if state.fight then openTab("Rooms",true)
    elseif state.mastery==0 then openTab("Training",true)
    else action:FireServer("Fight",state.stage) end
end)
questButton.TextSize=16
local comboFlash = text(root,"",UDim2.fromOffset(480,30),nil,23,C.gold,Enum.Font.FredokaOne,Enum.TextXAlignment.Center)
comboFlash.TextStrokeTransparency=0
local comboToken=0

local fightBar = frame(root, UDim2.fromOffset(520, 96), nil, C.ink)
fightBar.Visible = false
local fightName = text(fightBar, "ENEMY", UDim2.new(1, -90, 0, 26), UDim2.fromOffset(14, 8), 19, C.white, Enum.Font.GothamBlack)
local fightCount = text(fightBar, "1 / 6", UDim2.fromOffset(70, 26), UDim2.new(1, -82, 0, 8), 17, C.gold, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)
local hpBack = frame(fightBar, UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 40), C.panel)
local hpFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.red, BorderSizePixel = 0 }, hpBack)
corner(hpFill, 8); gradient(hpFill, C.orange, C.red, 0)
local hpText = text(fightBar, "Approach and swing to attack", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 65), 14, C.muted, nil, Enum.TextXAlignment.Center)

local mastery = frame(root, UDim2.fromOffset(480, 72), nil, c(255,255,255))
gradient(mastery,c(255,232,95),c(158,112,255),0)
local masteryTitle = text(mastery, "SWORD MASTERY 0", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 7), 16, C.cyan, Enum.Font.GothamBlack)
local masteryBonus = text(mastery, "Train at a station to permanently increase gains", UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 30), 12, C.muted)
local xpBack = frame(mastery, UDim2.new(1, -24, 0, 8), UDim2.fromOffset(12, 55), C.panel)
local xpFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.gold, BorderSizePixel = 0 }, xpBack)
corner(xpFill, 5)
local trainingTag = text(root, "", UDim2.fromOffset(490, 28), nil, 16, C.cyan, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
local swingButton = button(root, "SWING", C.blue, UDim2.fromOffset(258, 65), nil, function() requestSwing() end)
local swingCaption = text(swingButton, "+1 SPIRIT", UDim2.new(1, -14, 0, 18), UDim2.fromOffset(7, 42), 13, C.white, nil, Enum.TextXAlignment.Center)
swingButton.TextYAlignment = Enum.TextYAlignment.Top
new("UIPadding", { PaddingTop = UDim.new(0, 8) }, swingButton)
local autoButton = button(root, "AUTO: OFF", C.grey, UDim2.fromOffset(155, 50), nil, function()
    autoSwing = not autoSwing
end)
autoButton.TextSize = 16
local hubButton = button(root, "RETURN TO HUB", C.purple, UDim2.fromOffset(192, 44), nil, function()
    autoSwing = false
    action:FireServer("ReturnHub")
end)
hubButton.TextSize = 15
local stopButton = button(root, "END TRAINING", C.grey, UDim2.fromOffset(192, 38), nil, function()
    action:FireServer("StopTraining")
end)
stopButton.Visible = false; stopButton.TextSize = 14
local controls = text(root, "CLICK / TAP / R2 TO SWING  •  WALK TO YOUR ENEMY", UDim2.fromOffset(650, 22), nil, 12, C.white, nil, Enum.TextXAlignment.Center)
local savingLabel = text(root, "CONNECTING TO YOUR SAVE…", UDim2.fromOffset(900, 28), nil, 16, C.gold, Enum.Font.GothamBold, Enum.TextXAlignment.Center)

-- Modal shield prevents weapon clicks passing through menus.
local shade = new("TextButton", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.25,
    Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20,
}, root)
local panel = frame(shade, UDim2.fromOffset(840, 540), UDim2.fromScale(0.5, 0.5), C.panel)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Active = true
stroke(panel, C.cyan, 3)
local panelTitle = text(panel, "ARMORY", UDim2.new(1, -100, 0, 42), UDim2.fromOffset(22, 10), 27, C.white, Enum.Font.GothamBlack)
local panelHint = text(panel, "", UDim2.new(1, -44, 0, 30), UDim2.fromOffset(22, 54), 14, C.muted)
local closeButton = button(panel, "X", C.red, UDim2.fromOffset(44, 42), UDim2.new(1, -58, 0, 12), function()
    shade.Visible = false; currentTab = nil
end)
local content = new("ScrollingFrame", {
    Position = UDim2.fromOffset(16, 92), Size = UDim2.new(1, -32, 1, -108),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
    ScrollBarImageColor3 = C.cyan, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, panel)
local toastLabel = text(root, "", UDim2.fromOffset(780, 60), nil, 25, C.gold, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
toastLabel.ZIndex = 40; toastLabel.TextStrokeTransparency = 0.2; toastLabel.Visible = false
local toastToken = 0
local function toast(message, color)
    toastToken += 1
    local token = toastToken
    toastLabel.Text = tostring(message)
    toastLabel.TextColor3 = color or C.gold
    toastLabel.TextTransparency = 0; toastLabel.Visible = true
    task.delay(3.8, function()
        if token == toastToken then
            TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        end
    end)
end
local function gainPopup(amount)
    local popup = text(root, "+" .. fmt(amount) .. " SPIRIT", UDim2.fromOffset(280, 38),
        UDim2.new(0.5, math.random(-90, 70) - 140, 0.61, 0), 25, C.cyan, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
    popup.ZIndex = 15
    TweenService:Create(popup, TweenInfo.new(0.75), {
        Position = popup.Position - UDim2.fromOffset(0, 75), TextTransparency = 1, TextStrokeTransparency = 1,
    }):Play()
    Debris:AddItem(popup, 0.8)
end

local portrait = false
local function layout()
    local available = gui.AbsoluteSize
    if available.X <= 0 or available.Y <= 0 then return end
    portrait = available.X / available.Y < 0.95
    local w, h = portrait and 720 or 1280, portrait and 1120 or 720
    root.Size = UDim2.fromOffset(w, h)
    uiScale.Scale = math.min(available.X / w, available.Y / h)
    if portrait then
        spiritCard.Position=UDim2.fromOffset(16,64); spiritCard.Size=UDim2.fromOffset(336,64)
        trophyCard.Position=UDim2.fromOffset(368,64); trophyCard.Size=UDim2.fromOffset(336,64)
        powerCard.Position=UDim2.fromOffset(16,138); powerCard.Size=UDim2.fromOffset(336,64)
        route.Position=UDim2.fromOffset(368,138); route.Size=UDim2.fromOffset(336,64)
        rebirthTag.Position=UDim2.fromOffset(486,24)
        nav.Position=UDim2.fromOffset(16,220);nav.Size=UDim2.fromOffset(688,164)
        for i,b in navButtons do
            b.Size=UDim2.fromOffset(162,74)
            b.Position=UDim2.fromOffset(((i-1)%4)*174,math.floor((i-1)/4)*84)
            navIcons[i].Position=UDim2.fromOffset(61,2)
            navTitles[i].Position=UDim2.fromOffset(4,47);navTitles[i].Size=UDim2.new(1,-8,0,23)
        end
        quest.Position=UDim2.fromOffset(35,400);quest.Size=UDim2.fromOffset(650,208)
        fightBar.Position=UDim2.fromOffset(60,624);fightBar.Size=UDim2.fromOffset(600,96)
        savingLabel.Position=UDim2.fromOffset(20,749);savingLabel.Size=UDim2.fromOffset(680,28)
        hubButton.Position=UDim2.fromOffset(40,782);hubButton.Size=UDim2.fromOffset(300,42)
        stopButton.Position=UDim2.fromOffset(366,782);stopButton.Size=UDim2.fromOffset(300,42)
        mastery.Position=UDim2.fromOffset(40,842);mastery.Size=UDim2.fromOffset(640,76)
        trainingTag.Position=UDim2.fromOffset(112,925)
        comboFlash.Position=UDim2.fromOffset(110,722);comboFlash.Size=UDim2.fromOffset(500,24)
        swingButton.Position=UDim2.fromOffset(70,970);swingButton.Size=UDim2.fromOffset(355,76)
        autoButton.Position=UDim2.fromOffset(455,979);autoButton.Size=UDim2.fromOffset(188,58)
        controls.Position=UDim2.fromOffset(35,1060)
        panel.Size=UDim2.fromOffset(680,850)
        toastLabel.Position=UDim2.fromOffset(20,620);toastLabel.Size=UDim2.fromOffset(680,70)
    else
        route.Position=UDim2.fromOffset(420,4);route.Size=UDim2.fromOffset(440,56)
        spiritCard.Position=UDim2.fromOffset(16,74);spiritCard.Size=UDim2.fromOffset(228,66)
        trophyCard.Position=UDim2.fromOffset(16,148);trophyCard.Size=UDim2.fromOffset(228,66)
        powerCard.Position=UDim2.fromOffset(16,552);powerCard.Size=UDim2.fromOffset(228,66)
        rebirthTag.Position=UDim2.fromOffset(1050,18)
        nav.Position=UDim2.fromOffset(16,230);nav.Size=UDim2.fromOffset(228,310)
        for i,b in navButtons do
            if i==1 then
                b.Size=UDim2.fromOffset(228,48);b.Position=UDim2.fromOffset(0,0)
                navIcons[i].Position=UDim2.fromOffset(10,3)
                navTitles[i].Position=UDim2.fromOffset(50,8);navTitles[i].Size=UDim2.new(1,-60,0,30)
            else
                b.Size=UDim2.fromOffset(110,78)
                b.Position=UDim2.fromOffset(((i-2)%2)*118,58+math.floor((i-2)/2)*86)
                navIcons[i].Position=UDim2.fromOffset(35,2)
                navTitles[i].Position=UDim2.fromOffset(4,49);navTitles[i].Size=UDim2.new(1,-8,0,24)
            end
        end
        quest.Position=UDim2.fromOffset(998,84);quest.Size=UDim2.fromOffset(266,208)
        fightBar.Position=UDim2.fromOffset(380,76);fightBar.Size=UDim2.fromOffset(520,96)
        mastery.Position=UDim2.fromOffset(330,535);mastery.Size=UDim2.fromOffset(600,76)
        trainingTag.Position=UDim2.fromOffset(382,504)
        comboFlash.Position=UDim2.fromOffset(390,467);comboFlash.Size=UDim2.fromOffset(480,30)
        swingButton.Position=UDim2.fromOffset(382,626);swingButton.Size=UDim2.fromOffset(320,64)
        autoButton.Position=UDim2.fromOffset(726,633);autoButton.Size=UDim2.fromOffset(174,50)
        hubButton.Position=UDim2.fromOffset(1054,644);hubButton.Size=UDim2.fromOffset(198,42)
        stopButton.Position=UDim2.fromOffset(1054,592);stopButton.Size=UDim2.fromOffset(198,38)
        controls.Position=UDim2.fromOffset(320,694)
        savingLabel.Position=UDim2.fromOffset(300,185);savingLabel.Size=UDim2.fromOffset(680,40)
        panel.Size=UDim2.fromOffset(840,540)
        toastLabel.Position=UDim2.fromOffset(270,360);toastLabel.Size=UDim2.fromOffset(740,70)
    end
    if shade.Visible and render then render(true) end
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

local function clear()
    for _, child in content:GetChildren() do child:Destroy() end
    afford = {}
end
local function listLayout()
    new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, content)
    new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, content)
end
local function trackAfford(b, cost)
    afford[#afford + 1] = { button = b, cost = cost }
end
local function updateAfford()
    if not state then return end
    for _, entry in afford do
        if entry.button.Parent then
            entry.button.BackgroundColor3 = state.spirit >= entry.cost and C.orange or C.grey
        end
    end
end
local function previewSword(viewport, definition)
    local world = new("WorldModel", {}, viewport)
    local model = new("Model", {}, world)
    SD.buildSword(definition, model)
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") then part.Anchored = true end
    end
    model:PivotTo(CFrame.Angles(0, math.rad(-20), math.rad(-35)) * CFrame.Angles(math.rad(70), 0, 0))
    local cf, size = model:GetBoundingBox()
    local camera = new("Camera", { FieldOfView = 35 }, viewport)
    camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(1, 0, math.max(size.X, size.Y, size.Z) * 1.7), cf.Position)
    viewport.CurrentCamera = camera
end
local function renderSwords()
    local width = portrait and 302 or 252
    new("UIGridLayout", { CellSize = UDim2.fromOffset(width, 298), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, content)
    new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12) }, content)
    for i, def in SD.SWORDS do
        local card = frame(content, UDim2.new(), nil, C.card); card.LayoutOrder = i
        local rarity = def.rarity or (i >= 11 and "Mythic" or i >= 7 and "Legendary" or i >= 4 and "Rare" or "Common")
        local tint = RARITY[rarity] or C.cyan
        stroke(card, tint, state and state.equipped == i and 3 or 1)
        local viewport = new("ViewportFrame", {
            Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 154),
            BackgroundColor3 = C.ink, BorderSizePixel = 0, Ambient = c(205, 215, 240),
            LightColor = C.white, LightDirection = Vector3.new(-1, -1, -1),
        }, card)
        corner(viewport, 10)
        previewSword(viewport, def)
        text(card, rarity:upper(), UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 163), 12, tint)
        text(card, def.name, UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 183), 19, C.white, Enum.Font.GothamBlack)
        text(card, "x" .. fmt(def.mult) .. " blade multiplier", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 224), 13, C.cyan)
        local size, pos = UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 1, -46)
        if state and state.equipped == i then
            button(card, "EQUIPPED", C.green, size, pos).AutoButtonColor = false
        elseif state and state.owned[tostring(i)] then
            button(card, "EQUIP", C.blue, size, pos, function() action:FireServer("EquipSword", i) end)
        else
            trackAfford(button(card, fmt(def.cost) .. " SPIRIT", C.orange, size, pos, function() action:FireServer("BuySword", i) end), def.cost)
        end
    end
end
local function renderRooms()
    listLayout()
    for i, def in SD.STAGES do
        local row = frame(content, UDim2.new(1, 0, 0, 126), nil, C.card); row.LayoutOrder = i
        local unlocked = state and i <= state.stage
        text(row, string.format("%02d", i), UDim2.fromOffset(50, 46), UDim2.fromOffset(12, 12), 28, def.color, Enum.Font.GothamBlack)
        text(row, def.name, UDim2.new(1, -220, 0, 30), UDim2.fromOffset(70, 10), 20, unlocked and C.white or C.muted, Enum.Font.GothamBlack)
        text(row, fmt(SD.enemyHp(i, false)) .. " HP minions  /  " .. fmt(SD.enemyHp(i, true)) .. " HP boss", UDim2.new(1, -225, 0, 32), UDim2.fromOffset(70, 42), 14, C.muted)
        text(row, "+" .. fmt(SD.roomTrophies(i)) .. " trophies  +" .. fmt(SD.roomReward(i)) .. " Spirit / clear", UDim2.new(1, -35, 0, 28), UDim2.fromOffset(16, 87), 16, C.gold)
        local b = button(row, unlocked and "ENTER" or "LOCKED", unlocked and C.green or C.grey,
            UDim2.fromOffset(132, 45), UDim2.new(1, -146, 0, 22), function()
                if unlocked then
                    action:FireServer("Fight", i); shade.Visible = false; currentTab = nil
                else toast("Clear the previous room to open this gate.", C.gold) end
            end)
        b.TextSize = 17
    end
end
local function renderTraining()
    listLayout()
    local info = frame(content, UDim2.new(1, 0, 0, 112), nil, C.ink); info.LayoutOrder = 0
    local level = state and state.mastery or 0
    text(info, "MASTERY " .. level .. "  /  x" .. string.format("%.2f", SD.masteryMultiplier(level)), UDim2.new(1, -28, 0, 34), UDim2.fromOffset(14, 10), 24, C.cyan, Enum.Font.GothamBlack)
    text(info, "Walk to a training model in the hub and activate its prompt. Swing while inside the ring to earn XP and boosted Spirit. Each mastery level permanently adds +8% to your blade multiplier.", UDim2.new(1, -28, 0, 61), UDim2.fromOffset(14, 45), 15, C.muted)
    for i, def in SD.TRAINING do
        local row = frame(content, UDim2.new(1, 0, 0, 140), nil, C.card); row.LayoutOrder = i
        stroke(row, def.color, 2)
        text(row, def.name, UDim2.new(1, -190, 0, 32), UDim2.fromOffset(16, 12), 23, def.color, Enum.Font.GothamBlack)
        text(row, def.description, UDim2.new(1, -190, 0, 38), UDim2.fromOffset(16, 45), 14, C.muted)
        text(row, "x" .. def.mult .. " Spirit  •  +" .. def.xp .. " XP / swing", UDim2.new(1, -30, 0, 24), UDim2.fromOffset(16, 86), 16, C.cyan)
        text(row, fmt(def.requiredTrophies) .. " trophies required", UDim2.new(1, -30, 0, 20), UDim2.fromOffset(16, 111), 13, C.gold)
        local unlocked = state and state.trophies >= def.requiredTrophies
        local active = state and state.training == i
        local b = button(row, active and "STOP" or unlocked and "TRAIN" or "LOCKED", active and C.orange or unlocked and C.green or C.grey,
            UDim2.fromOffset(138, 46), UDim2.new(1, -154, 0, 26), function()
                if active then action:FireServer("StopTraining")
                elseif unlocked then action:FireServer("Train", i)
                else toast("Earn " .. fmt(def.requiredTrophies) .. " trophies to train here.", C.gold) end
            end)
        b.TextSize = 17
    end
end
local function renderPets()
    listLayout()
    for eggIndex, egg in SD.EGGS do
        local row = frame(content, UDim2.new(1, 0, 0, 202), nil, C.card); row.LayoutOrder = eggIndex
        text(row, egg.name, UDim2.new(1, -190, 0, 30), UDim2.fromOffset(16, 10), 23, C.pink, Enum.Font.GothamBlack)
        local total = 0
        for _, pet in SD.PETS do if pet.egg == eggIndex then total += pet.weight end end
        local lines = {}
        for _, pet in SD.PETS do
            if pet.egg == eggIndex then
                lines[#lines + 1] = string.format("%s  +%s%%  /  %.1f%%", pet.name, fmt(pet.bonus * 100), pet.weight / total * 100)
            end
        end
        text(row, table.concat(lines, "\n"), UDim2.new(1, -190, 0, 146), UDim2.fromOffset(16, 45), 15, C.muted)
        local b = button(row, "HATCH\n" .. fmt(egg.cost), C.orange, UDim2.fromOffset(145, 66), UDim2.new(1, -162, 0.5, -33), function()
            action:FireServer("Hatch", eggIndex)
        end)
        trackAfford(b, egg.cost)
    end
    local header = text(content, "YOUR COMPANIONS — BEST THREE ACTIVE", UDim2.new(1, 0, 0, 36), nil, 17, C.white, Enum.Font.GothamBlack)
    header.LayoutOrder = 20
    local any = false
    for i, pet in SD.PETS do
        local count = state and state.pets[pet.name] or 0
        if count > 0 then
            any = true
            local row = frame(content, UDim2.new(1, 0, 0, 68), nil, C.card); row.LayoutOrder = 20 + i
            text(row, pet.name .. "  x" .. count, UDim2.new(0.66, -14, 0, 32), UDim2.fromOffset(14, 5), 20, RARITY[pet.rarity])
            text(row, pet.rarity .. "  /  +" .. fmt(pet.bonus * 100) .. "% each", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 39), 14, C.muted)
        end
    end
    if not any then
        local l = text(content, "No companions yet. Hatch your first spirit egg!", UDim2.new(1, 0, 0, 38), nil, 18, C.muted)
        l.LayoutOrder = 21
    end
end
local function renderAuras()
    listLayout()
    for i, def in SD.AURAS do
        local row = frame(content, UDim2.new(1, 0, 0, 100), nil, C.card); row.LayoutOrder = i
        text(row, def.name, UDim2.new(1, -200, 0, 34), UDim2.fromOffset(16, 10), 24, def.color, Enum.Font.GothamBlack)
        text(row, "+" .. fmt(def.bonus * 100) .. "% Spirit and damage", UDim2.new(1, -200, 0, 30), UDim2.fromOffset(16, 51), 16, C.muted)
        local owned = state and state.auras[tostring(i)]
        local active = state and state.aura == i
        local b = button(row, active and "REMOVE" or owned and "EQUIP" or fmt(def.cost), active and C.green or owned and C.blue or C.orange,
            UDim2.fromOffset(156, 46), UDim2.new(1, -174, 0.5, -23), function() action:FireServer("Aura", i) end)
        b.TextSize = 17
        if not owned then trackAfford(b, def.cost) end
    end
end
local function renderRebirth()
    listLayout()
    local rebirths = state and state.rebirths or 0
    local cost = state and state.rebirthCost or SD.rebirthCost(0)
    local box = frame(content, UDim2.new(1, 0, 0, 340), nil, C.card)
    text(box, "ASCEND BEYOND YOUR LIMITS", UDim2.new(1, -40, 0, 42), UDim2.fromOffset(20, 18), 25, C.gold, Enum.Font.GothamBlack)
    text(box, "REBIRTH " .. rebirths .. "  /  +" .. rebirths * 50 .. "% permanent bonus", UDim2.new(1, -40, 0, 30), UDim2.fromOffset(20, 65), 20, C.purple)
    text(box, "Your Spirit balance and owned swords reset.\n\nKeep trophies, unlocked rooms, mastery, pets and auras. Every rebirth adds +50% to your rebirth multiplier.\n\nCost: " .. fmt(cost) .. " Spirit", UDim2.new(1, -40, 0, 160), UDim2.fromOffset(20, 110), 19, C.muted)
    local confirm = false
    local b
    b = button(box, "REBIRTH", C.orange, UDim2.new(1, -40, 0, 48), UDim2.new(0, 20, 1, -64), function()
        if not confirm then
            confirm = true; b.Text = "CONFIRM RESET SPIRIT + SWORDS"
        else
            confirm = false; b.Text = "REBIRTH"; action:FireServer("Rebirth")
        end
    end)
    b.TextSize = 18
    trackAfford(b, cost)
end
local function renderCodes()
    listLayout()
    local box = frame(content, UDim2.new(1, 0, 0, 220), nil, C.card)
    text(box, "A GIFT FOR YOUR JOURNEY", UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 14), 24, C.blue, Enum.Font.GothamBlack)
    text(box, "Redeem a code once per account for bonus Spirit.", UDim2.new(1, -32, 0, 26), UDim2.fromOffset(16, 55), 16, C.muted)
    local input = new("TextBox", {
        Size = UDim2.new(1, -32, 0, 48), Position = UDim2.fromOffset(16, 94),
        BackgroundColor3 = C.ink, TextColor3 = C.white, TextSize = 23, Font = Enum.Font.GothamBlack,
        PlaceholderText = "ENTER CODE", PlaceholderColor3 = C.muted, Text = "", ClearTextOnFocus = false,
    }, box)
    corner(input, 10); stroke(input, C.line, 2)
    button(box, "REDEEM", C.green, UDim2.new(1, -32, 0, 44), UDim2.fromOffset(16, 158), function()
        action:FireServer("Redeem", input.Text); input.Text = ""
    end)
end
local renderers = {
    Swords = renderSwords, Rooms = renderRooms, Stages = renderRooms, Training = renderTraining,
    Pets = renderPets, Auras = renderAuras, Rebirth = renderRebirth, Codes = renderCodes,
}
local hints = {
    Swords = "Original forged blades. Equip one and feel every swing.",
    Rooms = "Five guardians. One boss. Greater rewards beyond every gate.",
    Training = "Physical training stations turn practice into lasting power.",
    Pets = "Hatch companions. The best three bonuses equip automatically.",
    Auras = "Channel an elemental aura to increase Spirit and damage.",
    Rebirth = "Trade your current loadout for a permanent multiplier.",
    Codes = "Claim rewards from your journey's code collection.",
}
render = function(preserveScroll)
    if not currentTab then return end
    local scroll = content.CanvasPosition
    clear()
    panelTitle.Text = currentTab:upper()
    panelHint.Text = hints[currentTab] or ""
    local renderer = renderers[currentTab]
    if renderer then renderer() end
    if preserveScroll then content.CanvasPosition = scroll else content.CanvasPosition = Vector2.zero end
    updateAfford()
end
openTab = function(tab, force)
    if tab == "Stages" then tab = "Rooms" end
    if not renderers[tab] then return end
    if not force and currentTab == tab and shade.Visible then
        shade.Visible = false; currentTab = nil; return
    end
    currentTab = tab; shade.Visible = true
    render()
end
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
        shade.Visible = false; currentTab = nil
    end
end)

-- Asset-free, three-hit sword choreography. Each client animates the local
-- prediction and server-confirmed swings of nearby observers independently.
local swingTracks = {}
local animationConnection
local IDENTITY = CFrame.identity

local function stopSwing(character)
	local track = swingTracks[character]
	if not track then return end
	for _, joint in track.joints do
		if joint.motor.Parent then joint.motor.C0 = joint.base end
	end
	if track.tool.Parent then track.tool.Grip = track.grip end
	for _, trail in track.trails do
		if trail.Parent then trail.Enabled = false end
	end
	swingTracks[character] = nil
end

local function rotation(x, y, z)
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- Delta rotations are expressed in the parent limb's axes, before the joint's
-- original orientation. This keeps the same choreography usable on R6 and R15.
local COMBO_POSES = {
	{
		wind = { right = rotation(120, 35, 65), left = rotation(32, 0, -20), body = rotation(0, -22, -5), elbow = rotation(25, 0, 0), wrist = rotation(0, 0, 18) },
		strike = { right = rotation(65, -30, -74), left = rotation(50, 0, -24), body = rotation(0, 27, 7), elbow = rotation(8, 0, 0), wrist = rotation(0, 0, -24) },
	},
	{
		wind = { right = rotation(90, -30, -75), left = rotation(40, 0, -15), body = rotation(0, 24, 6), elbow = rotation(32, 0, 0), wrist = rotation(0, 0, -18) },
		strike = { right = rotation(70, 40, 73), left = rotation(28, 0, -30), body = rotation(0, -28, -7), elbow = rotation(10, 0, 0), wrist = rotation(0, 0, 20) },
	},
	{
		wind = { right = rotation(166, 6, 10), left = rotation(120, -10, -28), body = rotation(-8, -8, 0), elbow = rotation(30, 0, 0), wrist = rotation(-12, 0, 0) },
		strike = { right = rotation(38, -5, -12), left = rotation(52, 0, -30), body = rotation(14, 8, 0), elbow = rotation(2, 0, 0), wrist = rotation(12, 0, 0) },
	},
}

local function animateSwing(character, combo)
	if not character or not character.Parent then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local tool
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("IsSword") then tool = child; break end
	end
	if not humanoid or humanoid.Health <= 0 or not tool then return end
	stopSwing(character)

	local names = humanoid.RigType == Enum.HumanoidRigType.R15
		and { RightShoulder = "right", LeftShoulder = "left", Waist = "body", RightElbow = "elbow", RightWrist = "wrist" }
		or { ["Right Shoulder"] = "right", ["Left Shoulder"] = "left", RootJoint = "body" }
	local joints, trails = {}, {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and names[descendant.Name] then
			table.insert(joints, { motor = descendant, base = descendant.C0, role = names[descendant.Name] })
		end
	end
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("Trail") then
			descendant.Enabled = false
			table.insert(trails, descendant)
		end
	end
	swingTracks[character] = {
		started = os.clock(), humanoid = humanoid, tool = tool, grip = tool.Grip,
		joints = joints, trails = trails, poses = COMBO_POSES[math.clamp(math.floor(tonumber(combo) or 1), 1, 3)],
	}

	if animationConnection then return end
	animationConnection = RunService.PreSimulation:Connect(function()
		local now = os.clock()
		for activeCharacter, track in swingTracks do
			local elapsed = now - track.started
			if elapsed >= 0.40 or not activeCharacter.Parent or track.humanoid.Health <= 0 or track.tool.Parent ~= activeCharacter then
				stopSwing(activeCharacter)
			else
				local from, to, alpha
				if elapsed < 0.08 then
					from, to = nil, track.poses.wind
					alpha = math.sin(math.clamp(elapsed / 0.08, 0, 1) * math.pi / 2)
				elseif elapsed < 0.20 then
					from, to = track.poses.wind, track.poses.strike
					local t = math.clamp((elapsed - 0.08) / 0.12, 0, 1)
					alpha = 1 - (1 - t) ^ 3
				else
					from, to = track.poses.strike, nil
					local t = math.clamp((elapsed - 0.20) / 0.20, 0, 1)
					alpha = t * t * (3 - 2 * t)
				end
				for _, joint in track.joints do
					if joint.motor.Parent then
						local offset = (from and from[joint.role] or IDENTITY):Lerp(to and to[joint.role] or IDENTITY, alpha)
						joint.motor.C0 = CFrame.new(joint.base.Position) * offset * joint.base.Rotation
					end
				end
				for _, trail in track.trails do
					if trail.Parent then trail.Enabled = elapsed >= 0.07 and elapsed < 0.24 end
				end
			end
		end
		if next(swingTracks) == nil then
			animationConnection:Disconnect()
			animationConnection = nil
		end
	end)
end


local function equippedSword(character)
    if not character then return nil end
    for _, child in character:GetChildren() do
        if child:IsA("Tool") and child:GetAttribute("IsSword") then return child end
    end
    return nil
end
requestSwing = function()
    if not state or shade.Visible or UserInputService:GetFocusedTextBox() then return end
    local now = os.clock()
    if now - lastSwing < (SD.SWING_COOLDOWN or 0.42) + 0.025 then return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 or not equippedSword(character) then return end
    combo = now - lastSwing >= 1.15 and 1 or combo % 3 + 1
    lastSwing = now
    animateSwing(character, combo)
    comboToken+=1
    local token=comboToken
    comboFlash.Text=({"I  •  MOON CUT","II  •  BLOSSOM CROSS","III  •  SPIRIT BREAK"})[combo]
    comboFlash.TextColor3=combo==3 and C.pink or C.gold
    task.delay(0.65,function() if comboToken==token then comboFlash.Text="" end end)
    action:FireServer("Swing")
end
local toolConnections, characterConnection = {}, nil
local function bindTool(tool)
    if not tool:IsA("Tool") or not tool:GetAttribute("IsSword") or toolConnections[tool] then return end
    toolConnections[tool] = tool.Activated:Connect(function() requestSwing() end)
    tool.Destroying:Once(function()
        if toolConnections[tool] then toolConnections[tool]:Disconnect(); toolConnections[tool] = nil end
    end)
end
local function bindCharacter(character)
    if characterConnection then characterConnection:Disconnect() end
    for tool, connection in toolConnections do connection:Disconnect(); toolConnections[tool] = nil end
    lastSwing, combo = 0, 0
    for _, child in character:GetChildren() do bindTool(child) end
    characterConnection = character.ChildAdded:Connect(bindTool)
    local humanoid = character:WaitForChild("Humanoid")
    humanoid.Died:Once(function() autoSwing = false end)
end
player.CharacterAdded:Connect(bindCharacter)
if player.Character then task.spawn(bindCharacter, player.Character) end
ContextActionService:BindAction("BladeboundSwing", function(_, inputState)
    if inputState == Enum.UserInputState.Begin then requestSwing() end
    return shade.Visible and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonR2)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

-- Local ambient polish caches only opt-in decorative parts, never collision or
-- prompt anchors. The map is inspected once, then maintained by hierarchy events.
local ambientFolder
local ambientProps, displayPrompts, mapConnections = {}, {}, {}
local function restoreAmbient(part, entry)
    if entry.active and part.Parent then part.CFrame = entry.base end
    entry.active = false
end
local function personalizePrompt(prompt, entry)
    if not prompt.Parent then return end
    if entry.sword then
        local definition = SD.SWORDS[entry.sword]
        if not definition then return end
        prompt.ObjectText = definition.name
        if state and state.equipped == entry.sword then
            prompt.ActionText = "Equipped"
        elseif state and state.owned and state.owned[tostring(entry.sword)] then
            prompt.ActionText = "Equip"
        else
            prompt.ActionText = "Buy " .. fmt(definition.cost) .. " Spirit"
        end
    elseif entry.egg then
        local definition = SD.EGGS[entry.egg]
        if definition then
            prompt.ObjectText = definition.name
            prompt.ActionText = "Hatch • " .. fmt(definition.cost) .. " Spirit"
        end
    end
end
local function refreshDisplayPrompts()
    for prompt, entry in displayPrompts do personalizePrompt(prompt, entry) end
end
local function clearAmbientMap()
    for _, connection in mapConnections do connection:Disconnect() end
    table.clear(mapConnections)
    for part, entry in ambientProps do restoreAmbient(part, entry) end
    for prompt, entry in displayPrompts do
        if prompt.Parent then
            prompt.ActionText = entry.action
            prompt.ObjectText = entry.object
        end
    end
    table.clear(ambientProps)
    table.clear(displayPrompts)
    ambientFolder = nil
end
local function trackWorldObject(object)
    if object:IsA("BasePart") and object:GetAttribute("AmbientFloat") == true then
        -- The builder opts in only isolated anchored art. Skip any accidental
        -- colliding part or prompt carrier so interaction positions stay fixed.
        if not object.Anchored or object.CanCollide or object:FindFirstChildWhichIsA("ProximityPrompt", true) then return end
        if not ambientProps[object] then
            local position = object.Position
            ambientProps[object] = {
                base = object.CFrame, rotate = object:GetAttribute("AmbientRotate") == true,
                phase = (position.X * 0.37 + position.Y * 0.19 + position.Z * 0.11) % (2 * math.pi),
                active = false,
            }
        end
    elseif object:IsA("ProximityPrompt") then
        local sword, egg = object:GetAttribute("SwordIndex"), object:GetAttribute("EggIndex")
        if (sword and SD.SWORDS[sword]) or (egg and SD.EGGS[egg]) then
            if not displayPrompts[object] then
                displayPrompts[object] = {
                    sword = sword, egg = egg, action = object.ActionText, object = object.ObjectText,
                }
            end
            personalizePrompt(object, displayPrompts[object])
        end
    end
end
local function attachAmbientMap(folder)
    if folder == ambientFolder or folder.Name ~= "AnimeSwordWorld" or not folder:IsA("Folder") then return end
    clearAmbientMap()
    ambientFolder = folder
    mapConnections[#mapConnections + 1] = folder.DescendantAdded:Connect(function(object)
        -- Attributes are assigned by the builder during the same construction
        -- step; deferring also accommodates replicated descendant arrival.
        task.defer(function()
            if ambientFolder == folder and object:IsDescendantOf(folder) then trackWorldObject(object) end
        end)
    end)
    mapConnections[#mapConnections + 1] = folder.DescendantRemoving:Connect(function(object)
        local entry = ambientProps[object]
        if entry then restoreAmbient(object, entry); ambientProps[object] = nil end
        displayPrompts[object] = nil
    end)
    mapConnections[#mapConnections + 1] = folder.AncestryChanged:Connect(function()
        if ambientFolder == folder and folder.Parent ~= workspace then clearAmbientMap() end
    end)
    for _, object in folder:GetDescendants() do trackWorldObject(object) end
end
local worldAddedConnection = workspace.ChildAdded:Connect(function(object)
    if object.Name == "AnimeSwordWorld" then attachAmbientMap(object) end
end)
local existingWorld = workspace:FindFirstChild("AnimeSwordWorld")
if existingWorld then attachAmbientMap(existingWorld) end
local ambientElapsed = 0
local ambientConnection = RunService.Heartbeat:Connect(function(dt)
    ambientElapsed += dt
    if ambientElapsed < 1 / 30 then return end
    ambientElapsed = 0
    local camera = workspace.CurrentCamera
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local viewer = camera and camera.CFrame.Position or (rootPart and rootPart.Position)
    local now = os.clock()
    for part, entry in ambientProps do
        if not part.Parent then
            ambientProps[part] = nil
        else
            local offset = viewer and (entry.base.Position - viewer)
            if offset and offset:Dot(offset) <= 180 * 180 then
                local bob = math.sin(now * 1.2 + entry.phase) * 0.3
                local spin = entry.rotate and CFrame.Angles(0, now * 0.18 + entry.phase, 0) or CFrame.identity
                part.CFrame = CFrame.new(0, bob, 0) * entry.base * spin
                entry.active = true
            else
                restoreAmbient(part, entry)
            end
        end
    end
end)
gui.Destroying:Once(function()
    worldAddedConnection:Disconnect()
    ambientConnection:Disconnect()
    clearAmbientMap()
end)

local function onState(s)
    local previous=state
    state = s
    if previous and (s.mastery or 0)>(previous.mastery or 0) then
        toast("MASTERY UP!  LEVEL "..s.mastery,C.gold)
    end
    refreshDisplayPrompts()
    spiritLabel.Text = fmt(s.spirit)
    trophyLabel.Text = fmt(s.trophies)
    powerLabel.Text = fmt(s.damage or s.mult * 4)
    rebirthTag.Text = "REBIRTH " .. s.rebirths
    swingCaption.Text = "+" .. fmt(s.swingGain or s.mult) .. " SPIRIT"
    local stageIndex = math.clamp(s.fight and s.fight.stage or s.stage, 1, #SD.STAGES)
    local stageDef = SD.STAGES[stageIndex]
    routeTitle.Text = string.format("ROOM %02d / %02d", stageIndex, #SD.STAGES)
    routeText.Text = stageDef.name:upper()
    questTitle.Text = stageDef.name
    questReward.Text = "+" .. fmt(SD.roomTrophies(stageIndex)) .. " TROPHIES  /  +" .. fmt(SD.roomReward(stageIndex)) .. " SPIRIT"
    questDetail.Text = s.fight and "Approach your guardian and face it. Swing to deal damage. Clear all six enemies to open the next gate." or "Enter the next room, defeat its guardians, and claim a boss trophy chest. Train in the hub when enemies get tougher."
    if s.fight then
        questTitle.Text=s.fight.boss and "DEFEAT THE BOSS" or "CLEAR THE GUARDIANS"
        questDetail.Text=string.format("%d / %d cleared. Face your target to hit. Dodge when the enemy flashes red.",s.fight.step-1,s.fight.total)
        questButton.Text="VIEW ROOM TRACK"
    elseif (s.mastery or 0)==0 then
        questTitle.Text="AWAKEN YOUR BLADE"
        questDetail.Text="Stand on Bamboo Fundamentals, start training, and swing until mastery reaches level 1."
        questButton.Text="SHOW TRAINING"
    else
        questTitle.Text="CONQUER ROOM "..s.stage
        questDetail.Text="Beat the next boss for better trophies and Spirit. Train or forge a new sword if you need more power."
        questButton.Text="ENTER ROOM "..s.stage
    end
    local upgrade=false
    for i,def in SD.SWORDS do
        if not s.owned[tostring(i)] and def.cost<=s.spirit then upgrade=true;break end
    end
    upgradeBadge.Visible=upgrade
    local level, xp, needed = s.mastery or 0, s.masteryXP or 0, s.masteryNeed or SD.masteryNeed(s.mastery or 0)
    masteryTitle.Text = "SWORD MASTERY " .. level .. "    " .. fmt(xp) .. " / " .. fmt(needed) .. " XP"
    masteryBonus.Text = string.format("x%.2f permanent blade bonus  /  train at a station to level up", s.masteryMult or SD.masteryMultiplier(level))
    TweenService:Create(xpFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(math.clamp(xp / math.max(needed, 1), 0, 1), 1) }):Play()
    local training = s.training and SD.TRAINING[s.training]
    trainingTag.Text = training and (training.name:upper() .. "  /  x" .. (s.trainingMult or training.mult) .. " SPIRIT") or "SWING TO GAIN SPIRIT  /  TRAIN TO GAIN MASTERY"
    stopButton.Visible = training ~= nil
    if s.fight then
        fightBar.Visible = true
        fightName.Text = (s.fight.boss and "BOSS  /  " or "GUARDIAN  /  ") .. (s.fight.boss and stageDef.boss or stageDef.minion)
        fightName.TextColor3 = s.fight.boss and C.gold or C.white
        fightCount.Text = s.fight.step .. " / " .. s.fight.total
        local hp, maxHp = s.fight.hp or 0, s.fight.maxHp or 1
        TweenService:Create(hpFill, TweenInfo.new(0.12), { Size = UDim2.fromScale(math.clamp(hp / math.max(maxHp, 1), 0, 1), 1) }):Play()
        hpText.Text = fmt(hp) .. " / " .. fmt(maxHp) .. " HP  •  FACE YOUR ENEMY TO HIT"
    else fightBar.Visible = false end
    savingLabel.Visible = s.saving == false
    savingLabel.Text = "SAVING UNAVAILABLE — This session's progress cannot be saved."
    if s.ver ~= lastVer then
        lastVer = s.ver
        if shade.Visible then render(true) end
    end
    updateAfford()
end
sync.OnClientEvent:Connect(function(kind, a, b)
    if kind == "State" then onState(a)
    elseif kind == "Gain" then gainPopup(a)
    elseif kind == "Toast" then toast(a, b)
    elseif kind == "RoomClear" then
        toast("ROOM "..a.stage.." CLEAR!  +"..fmt(a.trophies).." TROPHIES",C.gold)
        for i=1,18 do
            local bit=new("Frame",{Size=UDim2.fromOffset(8,14),Position=UDim2.new(0.5,0,0.35,0),Rotation=i*23,
                BorderSizePixel=0,BackgroundColor3=({C.gold,C.pink,C.cyan,C.green})[i%4+1],ZIndex=45},root)
            TweenService:Create(bit,TweenInfo.new(1.1),{Position=UDim2.new(0.5,math.random(-300,300),0.8,math.random(-120,40)),
                Rotation=i*97,BackgroundTransparency=1}):Play()
            Debris:AddItem(bit,1.2)
        end
    elseif kind == "Hatch" then toast("HATCHED " .. tostring(a) .. "  /  " .. tostring(b), RARITY[b] or C.gold)
    elseif kind == "Open" then openTab(a, true)
    elseif kind == "Swing" then
        if a == player.UserId then
            -- Reconcile the sequence after a throttled packet without replaying prediction.
            combo = b
        else
            local other = Players:GetPlayerByUserId(a)
            if other and other.Character then animateSwing(other.Character, b) end
        end
    end
end)
local autoElapsed = 0
RunService.Heartbeat:Connect(function(dt)
    autoElapsed += dt
    if autoElapsed >= 0.1 then
        autoElapsed = 0
        autoButton.Text = autoSwing and "AUTO: ON" or "AUTO: OFF"
        autoButton.BackgroundColor3 = autoSwing and C.green or C.grey
        if autoSwing then requestSwing() end
    end
end)
task.spawn(function()
    while not state do
        action:FireServer("RequestState")
        task.wait(2)
        if not state then
            savingLabel.Text = "LOADING YOUR JOURNEY… If this continues, check GameServer in Output."
            savingLabel.Visible = true
        end
    end
end)
