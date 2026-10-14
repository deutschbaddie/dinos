--[[
	NpcView — the camp crew feel alive and useful:
	  - their heads follow you when you're near, and they wave when you walk up
	  - Talk opens a conversation: the camera frames them over your shoulder, a dialogue box types their line,
	    and big option buttons sit beside it (quest offers, hand-ins, and each NPC's job:
	    Mechanic (THE ARMORER: armor + gadgets) -> his drawer, Egg Keeper -> SELL / INDEX, Professor -> rulers & the Time Gate, Ranger -> fight tips)
	Quests are optional: every conversation can just be a chat.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local Kit = require(script.Parent.UI.Kit)
local PlayerAnim = require(script.Parent.PlayerAnim)
local Cinema = require(script.Parent.UI.Cinema)
local Net = require(script.Parent.Net)
local Drive = require(script.Parent.Drive)
local Scenes = require(script.Parent.Scenes)

local player = Players.LocalPlayer
local C = Kit.Colors
local View = {}
local Panels

local TITLE = { Professor = "THE PROFESSOR", Mechanic = "THE ARMORER", EggKeeper = "EGG KEEPER", Ranger = "RANGER", Sightseer = "THE SIGHTSEER" }
local COLOR = { Professor = "Blue", Mechanic = "Orange", EggKeeper = "Lime", Ranger = "Teal", Sightseer = "Purple" }
local ROLE = {
	Professor = "I study the Time Gate. Every era has a boss - beat one and the next dial opens.",
	Mechanic = "Armor and gadgets. Bring me boss parts and I'll make you tough enough to bite back. Power? That's your trainer.",
	EggKeeper = "Bigger eggs hatch bigger dinos. Bigger dinos make more money. I'll also buy any you don't need.",
	Ranger = "Out here, red on the ground means MOVE. Roll through it, then dart the weak spot while it's dazed.",
	Sightseer = "I came to see the sights! Waterfalls, old ruins, giant trees... everyone says they're out here somewhere.",
}
local TIPS = {
	Professor = { "Bosses wake up for everyone every ten minutes. Knockouts can drop a Boss Key to wake one yourself.", "Beat a boss on a harder tier for a mastery star - every star makes you stronger for good." },
	Ranger = { "Q (or B) dodge-rolls. You can't be hit mid-roll.", "Big ones get exhausted near the end - jump on for a rodeo to finish them!", "Your buddy dinos fight with you. Pick strong ones in your bag." },
}

--------------------------------------------------------------------------------
-- life: look at you, wave hello
--------------------------------------------------------------------------------
local npcs = {} :: { [Model]: any }

local function track(m: Model)
	if npcs[m] then return end
	local torso = m:FindFirstChild("Torso")
	local neck = torso and torso:FindFirstChild("Neck") :: Motor6D?
	npcs[m] = { Neck = neck, C0 = neck and neck.C0, Yaw = 0, Pitch = 0, Waved = false, Kind = m:GetAttribute("Npc") }
	-- THE ARMORER's outline: only while the goal line sends you to him (stepLife), where he's in view
	if m:GetAttribute("Npc") == "Mechanic" and not m:FindFirstChild("DinoNpcOutline") then
		local h = Instance.new("Highlight")
		h.Name = "DinoNpcOutline"
		h.FillTransparency = 1
		h.OutlineColor = Color3.fromRGB(255, 150, 46)
		h.OutlineTransparency = 0.15
		h.DepthMode = Enum.HighlightDepthMode.Occluded -- (only round him where you can see him: through walls it read as a ghost)
		h.Parent = m
		npcs[m].Outline = h
	end
end

local talking = nil :: any -- (the conversation in progress; set by startTalk below)
local function stepLife(dt: number)
	-- (only while your goal line sends you to him - the HUD's ARMORER lines; user 2026-10-13)
	local okH, HUD = pcall(require, script.Parent.UI.HUD)
	local goal = okH and HUD and HUD.ObjectiveText and HUD.ObjectiveText() or ""
	local want = string.find(goal, "ARMORER", 1, true) ~= nil and not Cinema.Playing() and talking == nil
	for _, n in pairs(npcs) do if n.Outline and n.Outline.Enabled ~= want then n.Outline.Enabled = want end end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	for m, st in pairs(npcs) do
		if not m.Parent then npcs[m] = nil continue end
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (root and st.Neck and st.C0) then continue end
		local yaw, pitch = 0, 0
		local near = false
		if hrp then
			local off = root.CFrame:PointToObjectSpace(hrp.Position + Vector3.new(0, 1.5, 0))
			local d = off.Magnitude
			if d < 28 then
				near = d < 13
				yaw = math.clamp(math.atan2(-off.X, -off.Z), -1.1, 1.1)
				pitch = math.clamp(math.atan2(off.Y - 1.5, math.sqrt(off.X * off.X + off.Z * off.Z)), -0.4, 0.4)
			end
		end
		local k = 1 - math.exp(-dt * 6)
		st.Yaw += (yaw - st.Yaw) * k
		st.Pitch += (pitch - st.Pitch) * k
		-- R6 neck: C0 is rotated so its Z axis is up and X is the pitch axis
		st.Neck.C0 = st.C0 * CFrame.Angles(-st.Pitch, 0, -st.Yaw)
		if near and not st.Waved then
			st.Waved = true
			Scenes.Gesture(m, "Wave")
			-- wave back (and look at them while you do)
			if char then
				local me = char
				local head = m:FindFirstChild("Head") :: BasePart?
				task.delay(0.35, function()
					PlayerAnim.Act(me, "Wave")
					if head then PlayerAnim.Look(me, head) end
					task.delay(1.6, function() PlayerAnim.Look(me, nil) end)
				end)
			end
		elseif not near and hrp and (root.Position - hrp.Position).Magnitude > 22 then
			st.Waved = false
		end
	end
end

--------------------------------------------------------------------------------
-- the conversation
--------------------------------------------------------------------------------
local ui = {} :: any
talking = nil

local function buildUI()
	local gui, canvas = Kit.Screen("DinoTalkUI", 40, false, 0.9)
	gui.Enabled = false
	ui.Gui = gui
	-- the speech box ends just left of the answer buttons (it used to run 100px underneath them and hide words)
	local box, content = Kit.Card(canvas, { Size = UDim2.fromOffset(640, 150), Position = UDim2.new(0.5, -180, 1, -24), AnchorPoint = Vector2.new(0.5, 1), Color = "Forest", Border = C.YellowHi, ZIndex = 10, Radius = 18 })
	ui.Box = box
	ui.Plate = Kit.Ribbon(box, "", { Position = UDim2.fromOffset(10, -36), Width = 280, Color = "Yellow", ZIndex = 16, Tilt = -3 })
	ui.Text = Kit.Text(content, "", { Size = UDim2.new(1, -40, 0, 92), Position = UDim2.fromOffset(20, 30), Align = Enum.TextXAlignment.Left, ZIndex = 16, Color = C.Cream, Stroke = 2.5, Shadow = 2, MaxSize = 26 })
	local label = ui.Text:FindFirstChild("Main") :: TextLabel
	for _, l in ipairs(ui.Text:GetChildren()) do
		if l:IsA("TextLabel") then
			l.TextWrapped = true
			l.TextYAlignment = Enum.TextYAlignment.Top
			l.TextScaled = false
			l.TextSize = 24
		end
	end
	ui.Label = label
	ui.Goal = Kit.Text(content, "", { Pixel = true, Size = UDim2.new(1, -40, 0, 14), Position = UDim2.new(0, 20, 1, -22), Align = Enum.TextXAlignment.Left, ZIndex = 16, Color = C.YellowHi, Stroke = 2, Shadow = 1, MaxSize = 14 })
	ui.Options = Instance.new("Frame")
	ui.Options.BackgroundTransparency = 1
	ui.Options.Size = UDim2.fromOffset(250, 300)
	ui.Options.Position = UDim2.new(0.5, 400, 1, -24)
	ui.Options.AnchorPoint = Vector2.new(1, 1)
	ui.Options.ZIndex = 12
	ui.Options.Parent = canvas
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.VerticalAlignment = Enum.VerticalAlignment.Bottom
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = ui.Options
end

local function setLine(text: string, goal: string?)
	ui.Full = text
	Kit.SetText(ui.Goal, goal or "")
	-- typewriter
	local my = {}
	ui.TypeToken = my
	for _, l in ipairs(ui.Text:GetChildren()) do if l:IsA("TextLabel") then l.Text = text l.MaxVisibleGraphemes = 0 l.TextSize = 24 end end
	-- a long line steps its size down until the whole thing fits the box (nothing cut off)
	local main = ui.Label :: TextLabel?
	if main then
		local size = 24
		task.defer(function()
			while size > 14 and main.AbsoluteSize.Y > 0 and not main.TextFits do
				size -= 2
				for _, l in ipairs(ui.Text:GetChildren()) do if l:IsA("TextLabel") then l.TextSize = size end end
				task.wait()
			end
		end)
	end
	task.spawn(function()
		local n = utf8.len(text) or #text
		for i = 1, n do
			if ui.TypeToken ~= my then return end
			for _, l in ipairs(ui.Text:GetChildren()) do if l:IsA("TextLabel") then l.MaxVisibleGraphemes = i end end
			if i % 3 == 0 then Kit.Sound("Click", 0.12, 1.5 + math.random() * 0.2) end
			task.wait(0.018)
		end
		for _, l in ipairs(ui.Text:GetChildren()) do if l:IsA("TextLabel") then l.MaxVisibleGraphemes = -1 end end
	end)
end

local function setOptions(list: { { any } })
	for _, c in ipairs(ui.Options:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local first = nil
	for i, o in ipairs(list) do
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(250, 52)
		holder.LayoutOrder = i
		holder.Parent = ui.Options
		local b, hit = Kit.Button(holder, { Text = o[1], Icon = o[3], IconSize = 0.9, TextLeft = o[3] and 0.28 or 0.06, Color = o[2], Size = UDim2.fromScale(1, 1), ZIndex = 14, Radius = 14, MaxText = 22, OnClick = o[4] })
		Kit.Pop(b, 0.5, 0.05 * i)
		first = first or hit
	end
	if Kit.Gamepad() and first then GuiService.SelectedObject = first end
end

local endTalk

local function goalText(q): string
	local g = q.Goal
	local what = ({ Expedition = "FINISH AN EXPEDITION", Hatch = "HATCH EGGS", Takedown = "KNOCK OUT DINOS", Escape = "ESCAPE WITH EGGS", Eggs = "BRING HOME EGGS", Craft = "CRAFT NEW GEAR", Boss = "BEAT THE BOSS", Rarity = "HATCH A " .. string.upper(g.Rarity or "") .. " OR BETTER" })[g.Kind] or g.Kind
	return string.format("GOAL: %s x%d   -   REWARD: %s COINS", what, g.Count or 1, Config.FormatNumber(q.Reward and q.Reward.Coins or 0))
end

-- the free first upgrade (Shop.levelUp) is his to give only until the trainer takes it over (Config.Trainer.FirstFree,
-- 2026-10-14: "the first free upgrade is now at the TRAINER") - then the onboarding sends you there instead
local function freeHere(): boolean
	local p = Net.Profile
	local tr = (Config :: any).Trainer
	if not p or (tr and tr.FirstFree) then return false end
	return not (p.Flags and p.Flags.FreeUpgradeUsed) and ((p.Stats and p.Stats.Runs) or 0) >= 1
end

local function roleOptions(kind: string): { { any } }
	local list = {}
	if kind == "Mechanic" then
		local free = freeHere()
		table.insert(list, { free and "FREE UPGRADE!" or "ARMOR + GADGETS", free and "Lime" or "Orange", "Armor", function() endTalk() Panels.Open("Workshop") end })
	elseif kind == "EggKeeper" then
		table.insert(list, { "SELL DINOS", "Red", "Coin", function() endTalk() Panels.Open("Bag") end })
		table.insert(list, { "DINO INDEX", "Blue", "Index", function() endTalk() Panels.Open("Index") end })
	elseif kind == "Professor" then
		table.insert(list, { "THE TIME GATE", "Teal", "Gate", function() endTalk() Panels.Open("Eras") end })
	end
	if TIPS[kind] then
		table.insert(list, { "ANY TIPS?", "Slate", "Star", function()
			local tips = TIPS[kind]
			setLine(tips[math.random(1, #tips)])
			Scenes.Gesture(talking and talking.Model, "Point")
		end })
	end
	table.insert(list, { "WHAT DO YOU DO?", "Slate", nil, function() setLine(ROLE[kind] or "") end })
	return list
end

--------------------------------------------------------------------------------
-- the Sightseer (Sightseer.luau): an optional hunt for an era's sights you haven't found
--------------------------------------------------------------------------------
local function leadsText(leads): string
	local parts, done = {}, 0
	for _, l in ipairs(leads or {}) do
		if l.Found then
			done += 1
		else
			table.insert(parts, string.format("%s (%s, about %d steps)", string.lower(tostring(l.Hint)), string.lower(tostring(l.Dir)), tonumber(l.Dist) or 0))
		end
	end
	return table.concat(parts, ", "), done
end

local function sightseer()
	local era = talking and talking.Era
	local eraCfg = era and Config.Era(era)
	local eraName = eraCfg and eraCfg.Name or "here"
	local res = Net.Ask("SightseerTalk", { Era = era })
	local bye = { "BYE!", "Red", nil, function() endTalk() end }
	if not (res and res.Ok) then
		setLine("Oh! Sorry, I was miles away.")
		setOptions({ bye })
		return
	end
	local rw = res.Reward or {}
	local prize = string.format("REWARD: %s COINS + %s POWER", Config.FormatNumber(rw.Coins or 0), Config.FormatNumber(rw.Power or 0))
	if res.Type == "Offer" then
		local first = (res.Sets or 0) == 0
		setLine(first and string.format("Oh, a traveller! I came all the way to %s to see the sights, and I can't find a single one. Will you help me spot a few?", eraName)
			or "You've got a good eye! There's more out there, I'm sure of it. Spot a few more for me?", prize)
		Scenes.Gesture(talking and talking.Model, "Point")
		setOptions({
			{ "SURE!", "Lime", "Map", function()
				local r = Net.Ask("SightseerAccept", { Era = era })
				if r and r.Ok and r.Leads then
					local list = leadsText(r.Leads)
					setLine("Wonderful! I heard about " .. list .. ". Get close and I'll know - then come back and tell me!", prize)
					Scenes.Gesture(talking and talking.Model, "Cheer")
					setOptions({ { "ON IT!", "Lime", nil, function() endTalk() end } })
				else
					sightseer()
				end
			end },
			{ "NOT NOW", "Grey", nil, function()
				setLine("No rush! I'll be right here, enjoying the view.")
				setOptions({ bye })
			end },
			bye,
		})
	elseif res.Type == "Hunt" then
		local list, done = leadsText(res.Leads)
		setLine(string.format("%d of %d spotted! Still looking for %s.", done, #(res.Leads or {}), list), prize)
		Scenes.Gesture(talking and talking.Model, "Point")
		setOptions({ { "WHAT DO YOU DO?", "Slate", nil, function() setLine(ROLE.Sightseer) end }, bye })
	elseif res.Type == "TurnIn" then
		setLine("You found them all! I'd never have seen them without you. Here - for your trouble.", prize)
		Scenes.Gesture(talking and talking.Model, "Cheer")
		setOptions({
			{ "CLAIM REWARD", "Lime", "Gift", function()
				local r = Net.Ask("SightseerClaim", { Era = era })
				if r and r.Ok then
					Kit.Toast(string.format("+%s COINS  +%s POWER - SIGHTSEER", Config.FormatNumber(r.Coins or 0), Config.FormatNumber(r.Power or 0)), "Gold", "Coin")
					PlayerAnim.Act(player.Character, "Victory")
					Scenes.Gesture(talking and talking.Model, "Laugh")
					task.delay(1.2, function() if talking and talking.Kind == "Sightseer" then sightseer() end end)
				else
					Kit.Toast((r and r.Err) or "NOT YET", "Red", "Map")
				end
			end },
			bye,
		})
	else
		setLine(string.format("You've shown me every sight in %s. What a trip! Best holiday ever.", eraName))
		Scenes.Gesture(talking and talking.Model, "Laugh")
		setOptions({ bye })
	end
end

local function converse(kind: string)
	if kind == "Sightseer" then return sightseer() end
	local res = Net.Ask("Talk", { Npc = kind })
	if not (res and res.Ok) then setLine("...") return end
	local opts = {}
	if res.Type == "TurnIn" then
		setLine(res.Text, res.Quest and ("DONE: " .. res.Quest.Title) or nil)
		Scenes.Gesture(talking and talking.Model, "Cheer")
		table.insert(opts, { "CLAIM REWARD", "Lime", "Gift", function()
			local r = Net.Ask("TurnIn", { Npc = kind })
			if r and r.Ok then
				Kit.Toast("+" .. Config.FormatNumber(r.Coins or 0) .. " COINS - " .. (r.Quest and r.Quest.Title or ""), "Gold", "Coin")
				PlayerAnim.Act(player.Character, "Victory")
				Scenes.Gesture(talking and talking.Model, "Laugh")
				converse(kind)
			end
		end })
	elseif res.Type == "Offer" then
		setLine(res.Text, goalText(res.Quest))
		Scenes.Gesture(talking and talking.Model, "Point")
		table.insert(opts, { "ACCEPT", "Lime", "Star", function()
			local r = Net.Ask("AcceptQuest", { Npc = kind })
			if r and r.Ok then
				setLine("Great! It's on your quest list, on the right of your screen. Come back to me when it's done and I'll pay up.", goalText(res.Quest))
				Scenes.Gesture(talking and talking.Model, "Cheer")
				setOptions({ { "OK!", "Lime", nil, function() endTalk() end } })
			else
				Kit.Toast((r and r.Err) or "CAN'T", "Red", "Star")
			end
		end })
		table.insert(opts, { "NOT NOW", "Grey", nil, function()
			setLine("No rush. I'll be right here.")
			local rest = roleOptions(kind)
			table.insert(rest, { "BYE!", "Red", nil, function() endTalk() end })
			setOptions(rest)
		end })
	else
		local free = kind == "Mechanic" and freeHere()
		setLine(free and "First upgrade's on me, rookie." or res.Text, (res.Type == "Progress" and res.Quest) and goalText(res.Quest) or nil)
		if free then Scenes.Gesture(talking and talking.Model, "Point") end
	end
	for _, o in ipairs(roleOptions(kind)) do table.insert(opts, o) end
	table.insert(opts, { "BYE!", "Red", nil, function() endTalk() end })
	setOptions(opts)
end

local function startTalk(spot: BasePart, kind: string)
	-- (at camp, or out exploring an era on foot: the Ranger and the Sightseer stand out there)
	local St = Drive.State
	local roaming = St.Mode == "Roam" and St.OnFoot and not player:GetAttribute("Site")
	if talking or Cinema.Playing() or (St.Mode ~= "None" and not roaming) then return end
	local m = spot:FindFirstChild("Npc") :: Model?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (m and hrp) then return end
	local head = m:FindFirstChild("Head") :: BasePart?
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (head and root) then return end
	local token = Cinema.Begin("DinoTalkUI")
	-- (a chat lasts as long as you read: Cinema's 40 s safety handed the HUD back over long ones. Our own, longer
	-- safety still ends a chat that something broke)
	token.Long = true
	talking = { Model = m, Kind = kind, Token = token, Era = spot:GetAttribute("Era") }
	task.delay(300, function() if talking and talking.Token == token and endTalk then endTalk() end end)
	-- stand in front of them, facing them
	local front = root.CFrame.LookVector
	local stand = root.Position + front * 5.5
	hrp.CFrame = CFrame.lookAt(Vector3.new(stand.X, hrp.Position.Y, stand.Z), Vector3.new(root.Position.X, hrp.Position.Y, root.Position.Z))
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then talking.Walk = hum.WalkSpeed hum.WalkSpeed = 0 end
	-- camera: over your shoulder onto their face
	local cam = Workspace.CurrentCamera
	talking.Fov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	local right = hrp.CFrame.RightVector
	local eye = head.Position
	local from = hrp.Position + right * 2.4 + Vector3.new(0, 2.2, 0) - hrp.CFrame.LookVector * 3.4
	local goal = CFrame.lookAt(from, eye + Vector3.new(0, -0.3, 0) - right * 0.6)
	TweenService:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { CFrame = goal, FieldOfView = 42 }):Play()
	ui.Gui.Enabled = true
	ui.Plate:Destroy()
	ui.Plate = Kit.Ribbon(ui.Box, TITLE[kind] or kind, { Position = UDim2.fromOffset(10, -36), Width = 300, Color = COLOR[kind] or "Yellow", ZIndex = 16, Tilt = -3 })
	Kit.Pop(ui.Box, 0.6)
	Scenes.Gesture(m, "Wave")
	converse(kind)
end

endTalk = function()
	if not talking then return end
	local t = talking
	talking = nil
	ui.TypeToken = nil
	ui.Gui.Enabled = false
	GuiService.SelectedObject = nil
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = t.Fov or 70
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and t.Walk then hum.WalkSpeed = t.Walk end
	Cinema.End(t.Token)
end
View.EndTalk = endTalk

function View.Start(panels)
	Panels = panels
	buildUI()
	for _, m in ipairs(CollectionService:GetTagged("DinoNpc")) do if m:IsA("Model") then track(m) end end
	CollectionService:GetInstanceAddedSignal("DinoNpc"):Connect(function(m) if m:IsA("Model") then task.defer(track, m) end end)
	RunService.RenderStepped:Connect(stepLife)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local kind = prompt:GetAttribute("Npc")
		if not kind then return end
		local spot = prompt:FindFirstAncestorWhichIsA("BasePart")
		if spot then startTalk(spot, kind) end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if talking and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then endTalk() end
	end)
end

return View
