--[[
	BossHype — one boss card, so a boss waking up always reads the same way (2026-10-12 rework: the old "BOSSES 15"
	countdown said nothing about which boss or what to do, and it stacked on top of a second pop-up).

	  THE CARD (top centre, under the objective line) only ever shows ONE boss, and only one you can fight (its era is
	  open). If several wake at once it picks the one your Time Gate is set to.
	    waking   the boss's portrait + name, "WAKES IN 12" ticking down, the ground pulsing harder (15 s before the
	             10-minute server event, or 10 s after someone summons one with a key: their name on a key tag)
	    awake    "AWAKE!" + a big JOIN button + how long it stays open; JOIN rides the Time Gate straight to its den
	  Close it with X (just for this event). New players don't get it until they've met the Tyrant King through the
	  story (beaten it, or 3+ runs), unless they summoned it themselves. Out on an expedition: no card (the era map
	  shows bosses), just one line of news. The Time Gate stays BLUE (user rule).

	  SUMMON prompt: holding a boss key for an era you've opened, the Time Gate console grows a SUMMON prompt (local;
	  the server checks everything again). While a fight is live (den, chase or final stand) the same prompt reads
	  "Join Fight" and rides you into it. The card stays up for the whole fight, not just the join window.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(Shared:WaitForChild("Game"):WaitForChild("Config"))
local DinosaurVFX = require(Shared:WaitForChild("DinosaurVFX"))
local Net = require(script.Parent.Net)
local Drive = require(script.Parent.Drive)
local Audio = require(script.Parent.Audio)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local CineKit = require(script.Parent.UI.CineKit)
local Cinema = require(script.Parent.UI.Cinema)

local player = Players.LocalPlayer
local C = Theme.C
local BossHype = {}
local Runtime = Shared:WaitForChild("Runtime")

local function inCamp(): boolean
	-- (a rider has no route of their own: riding along in an era is not camp)
	return Drive.State.Mode ~= "Route" and Drive.State.Mode ~= "Roam" and player:GetAttribute("Site") == nil and player:GetAttribute("RidingWith") == nil
end

-- the den folder of a boss (Runtime.Sites/<Era>/Den), its phase: 0 asleep, 1 den, 2 chase, 3 final stand (1-3 all
-- joinable), 4 just ended
local function denOf(id: string): Instance?
	local b = Config.Bosses[id] :: any
	local sites = Runtime:FindFirstChild("Sites")
	if not (b and sites) then return nil end
	for _, f in ipairs(sites:GetChildren()) do
		if f:GetAttribute("Boss") and f:GetAttribute("Era") == b.Era then return f end
	end
	return nil
end
local function phaseOf(id: string): number
	local f = denOf(id)
	return f and (f:GetAttribute("Phase") or 0) or 0
end

local function canFight(id: string): boolean
	local p = Net.Profile
	local b = Config.Bosses[id] :: any
	return p ~= nil and b ~= nil and p.Unlocked ~= nil and p.Unlocked[b.Era] == true
end
-- a new player meets the king through the story first (foreshadowing + their own key)
local function eligible(): boolean
	local p = Net.Profile
	if not p then return false end
	local beat = p.Bosses and next(p.Bosses) ~= nil
	return beat or (p.Stats and (p.Stats.Runs or 0) >= 3) or false
end
-- of the bosses passing `test`, the one on your Time Gate's era, else the furthest era you've opened
local function pick(test: (string) -> boolean): string?
	local p = Net.Profile
	local best, bestOrder = nil, -1
	for i, era in ipairs(Config.Eras) do
		local id = (era :: any).Boss
		if id and canFight(id) and test(id) then
			if p and p.Era == (era :: any).Id then return id end
			if i > bestOrder then best, bestOrder = id, i end
		end
	end
	return best
end

-- any boss you could join right now: a fight in progress is joinable in every phase (the den, the chase, the final
-- stand); the server lands you wherever it's got to
function BossHype.LiveBoss(): string?
	return pick(function(id)
		local ph = phaseOf(id)
		return ph >= 1 and ph <= 3
	end)
end

--------------------------------------------------------------------------------
-- the card
--------------------------------------------------------------------------------
local card = {} :: any
local rising = nil :: { Boss: string?, By: string?, Mine: boolean, Until: number, Secs: number }?
local awakeUntil = {} :: { [string]: number } -- os.clock() a boss's join window closes (from BossEvent)
local dismissed = {} :: { [string]: number } -- closed with X: hidden until this boss's next event

local function buildCard()
	local gui, canvas = Kit.Screen("DinoBossCard", 24, false, 0.85)
	gui.Enabled = false
	local outer, content = Kit.Card(canvas, { Size = UDim2.fromOffset(500, 122), Position = UDim2.new(0.5, 0, 0, 164), AnchorPoint = Vector2.new(0.5, 0), Color = "Forest", Border = C.OrangeHi, ZIndex = 10 })
	card.Gui, card.Outer, card.Content = gui, outer, content
	card.IconHolder = Instance.new("Frame")
	card.IconHolder.BackgroundTransparency = 1
	card.IconHolder.Size = UDim2.fromOffset(118, 118)
	card.IconHolder.Position = UDim2.new(0, -14, 0.5, 0)
	card.IconHolder.AnchorPoint = Vector2.new(0, 0.5)
	card.IconHolder.Parent = content
	card.Kicker = Kit.Text(content, "", { Pixel = true, Size = UDim2.new(1, -250, 0, 12), Position = UDim2.fromOffset(110, 12), Align = Enum.TextXAlignment.Left, Color = C.YellowHi, Stroke = 2, Shadow = 2, ZIndex = 16, MaxSize = 12 })
	card.Name = Kit.Text(content, "", { Size = UDim2.new(1, -250, 0, 34), Position = UDim2.fromOffset(110, 30), Align = Enum.TextXAlignment.Left, Color = C.OrangeHi, Stroke = 4, Shadow = 4, ZIndex = 16, MaxSize = 34 })
	card.Sub = Kit.Text(content, "", { Pixel = true, Size = UDim2.new(1, -250, 0, 11), Position = UDim2.fromOffset(110, 72), Align = Enum.TextXAlignment.Left, Color = C.Cream, Stroke = 2, Shadow = 2, ZIndex = 16, MaxSize = 11 })
	-- right side: the big countdown while it wakes, the JOIN button once it's up
	card.Count = Kit.Text(content, "", { Size = UDim2.fromOffset(120, 56), Position = UDim2.new(1, -70, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.YellowHi, Stroke = 4, Shadow = 4, ZIndex = 16, MaxSize = 56 })
	local joining = false
	local function joinNow()
		local id = card.Boss
		if not id or joining then return end
		joining = true
		local res = Net.Ask("JoinBoss", { Boss = id })
		joining = false
		if res and res.Ok then
			dismissed[id] = os.clock() + 300
		else
			Kit.Toast(res and res.Err or "CAN'T JOIN RIGHT NOW", "Red", "Crown")
		end
	end
	local join, joinHit = Kit.Button(content, { Text = "JOIN!", Icon = "Gate", IconSize = 0.9, TextLeft = 0.36, Color = "Orange", Size = UDim2.fromOffset(150, 52), Position = UDim2.new(1, -14, 0.5, 6), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 17, MaxText = 22, Shine = true, OnClick = function()
		joinNow()
	end })
	card.Join, card.JoinHit, card.JoinNow = join, joinHit, joinNow
	-- gamepad: D-pad left joins, B closes (the card pops up by itself - grabbing GUI focus would steal the thumbstick)
	card.PadHint = Kit.Text(content, "D-PAD LEFT", { Pixel = true, Size = UDim2.fromOffset(150, 10), Position = UDim2.new(1, -14, 1, 4), AnchorPoint = Vector2.new(1, 0), Color = C.YellowHi, Stroke = 2, Shadow = 1, ZIndex = 17, MaxSize = 10 })
	card.PadHint.Visible = false
	Kit.Button(content, { Glyph = "X", Color = "Red", Size = UDim2.fromOffset(36, 34), Position = UDim2.new(1, 6, 0, -6), AnchorPoint = Vector2.new(1, 0), ZIndex = 18, OnClick = function()
		if card.Boss then dismissed[card.Boss] = os.clock() + 300 end
		card.Gui.Enabled = false
	end })
end

local function setIcon(id: string)
	if card.IconFor == id then return end
	card.IconFor = id
	for _, c in ipairs(card.IconHolder:GetChildren()) do c:Destroy() end
	Kit.Icon(card.IconHolder, "Dino", { Species = (Config.Bosses[id] :: any).Species, Size = UDim2.fromScale(1, 1), ZIndex = 16, Rotation = -6 })
end

local function fmt(sec: number): string
	sec = math.max(0, math.ceil(sec))
	return sec >= 60 and string.format("%d:%02d", sec // 60, sec % 60) or tostring(sec)
end

-- what the card should say right now (nil = hidden)
local function cardState(): (string?, string?)
	if not eligible() and not (rising and rising.Mine) then return nil, nil end
	if not inCamp() then return nil, nil end
	if rising and os.clock() < rising.Until then
		local id = rising.Boss or pick(function(b) return phaseOf(b) == 0 end)
		if id and canFight(id) and not ((dismissed[id] or 0) > os.clock()) then return "Waking", id end
	end
	local live = BossHype.LiveBoss()
	if live and not ((dismissed[live] or 0) > os.clock()) then return "Awake", live end
	return nil, nil
end

local lastMode, lastBoss, lastCount = nil, nil, nil
local padBound = false
local function padJoin(want: boolean)
	if want == padBound then return end
	padBound = want
	local CAS = game:GetService("ContextActionService")
	if want then
		-- (D-pad LEFT: right is the HUD's get in / out of your rover. B closes the card)
		CAS:BindActionAtPriority("DinoBossCardJoin", function(_, st, input)
			if st ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
			if input.KeyCode == Enum.KeyCode.ButtonB then
				if card.Boss then dismissed[card.Boss] = os.clock() + 300 end
				card.Gui.Enabled = false
			elseif card.JoinNow then
				task.spawn(card.JoinNow)
			end
			return Enum.ContextActionResult.Sink
		end, false, 2150, Enum.KeyCode.DPadLeft, Enum.KeyCode.ButtonB)
	else
		CAS:UnbindAction("DinoBossCardJoin")
	end
end
local function stepCard()
	local mode, id = cardState()
	local show = mode ~= nil and id ~= nil and not Cinema.Playing()
	if not show then
		card.Gui.Enabled = false
		lastMode, lastBoss = nil, nil
		padJoin(false)
		return
	end
	local boss = Config.Bosses[id :: string] :: any
	local era = Config.Era(boss.Era) :: any
	if not card.Gui.Enabled or mode ~= lastMode or id ~= lastBoss then
		card.Gui.Enabled = true
		lastMode, lastBoss, lastCount = mode, id, nil
		card.Boss = id
		setIcon(id :: string)
		Kit.SetText(card.Name, boss.Name)
		Kit.Pop(card.Outer, 0.4)
		if mode == "Awake" then
			CineKit.Punch(8)
			DinosaurVFX.Shake(0.6, 0.5)
			Audio.Sting("Reveal")
		end
	end
	if mode == "Waking" then
		local r = rising :: any
		Kit.SetText(card.Kicker, r.By and ("SUMMONED BY " .. string.upper(r.By)) or "BOSS EVENT")
		Kit.SetText(card.Sub, "WAKES UP IN " .. (era and era.Name or ""))
		local left = r.Until - os.clock()
		local n = math.ceil(left)
		if n ~= lastCount then
			lastCount = n
			Kit.SetText(card.Count, tostring(math.max(0, n)))
			Kit.Punch(card.Count, n <= 3 and 0.25 or 0.1)
		end
		card.Count.Visible, card.Join.Visible = true, false
		card.PadHint.Visible = false
		padJoin(false)
	else
		local untilT = awakeUntil[id :: string]
		local den = denOf(id :: string)
		local phase = den and (den:GetAttribute("Phase") or 0) or 0
		local started = den ~= nil and den:GetAttribute("Started") == true
		local fighting = (den and (den:GetAttribute("Hunters") or den:GetAttribute("Players"))) or 0
		local hunting = fighting > 0 and (fighting .. (fighting == 1 and " HUNTER" or " HUNTERS") .. " IN") or nil
		if phase == 1 and not started then
			Kit.SetText(card.Kicker, "AWAKE NOW!")
			Kit.SetText(card.Sub, (untilT and untilT > os.clock()) and ("JOIN IN THE NEXT " .. fmt(untilT - os.clock())) or (hunting or "JOIN FROM THE TIME GATE"))
		else
			-- a fight in progress: still joinable, wherever it's got to
			Kit.SetText(card.Kicker, phase == 2 and "IT'S RUNNING - JOIN THE CHASE!" or (phase == 3 and "LAST STAND - JOIN NOW!" or "FIGHT IN PROGRESS - JOIN NOW!"))
			Kit.SetText(card.Sub, hunting and (hunting .. " - EVERY HIT COUNTS") or "EVERY HIT COUNTS")
		end
		card.Count.Visible, card.Join.Visible = false, true
		local pad = Kit.Gamepad()
		card.PadHint.Visible = pad
		padJoin(pad)
	end
end

--------------------------------------------------------------------------------
-- the build-up (ground pulses while the card counts down)
--------------------------------------------------------------------------------
local function onRising(info)
	local mine = info.ByUserId == player.UserId
	local p = Net.Profile
	if p and (p.Stats and p.Stats.Runs or 0) == 0 and not mine then return end
	local secs = info.In or 10
	rising = { Boss = info.Boss, By = info.By, Mine = mine, Until = os.clock() + secs, Secs = secs }
	local my = rising
	if info.Boss then dismissed[info.Boss] = nil else table.clear(dismissed) end
	if not inCamp() then
		-- out on an expedition: one line of news, only about a boss you could fight
		-- (not mid-fight or mid-chase: only on the map between hunts)
		if player:GetAttribute("Site") or (Drive.State.Mode == "Route" and not Drive.State.Frozen and not Drive.State.OnFoot) then return end
		local id = info.Boss or pick(function(b) return phaseOf(b) == 0 end)
		if id and canFight(id) and (eligible() or mine) then Kit.Toast((Config.Bosses[id] :: any).Name .. " IS WAKING UP", "Orange", "Crown") end
		return
	end
	local id = info.Boss or pick(function(b) return phaseOf(b) == 0 end)
	if not (id and canFight(id) and (eligible() or mine)) then return end
	if Audio.Has and Audio.Has("BossRising") then Audio.Sting("BossRising", 0.8) else Audio.Sting("Spotted", 0.6) end
	-- footsteps getting closer: slow soft pulses, then faster and harder
	task.spawn(function()
		local nextPulse = os.clock() + 0.6
		while rising == my and os.clock() < my.Until do
			RunService.RenderStepped:Wait()
			local u = 1 - (my.Until - os.clock()) / secs
			if os.clock() >= nextPulse then
				nextPulse = os.clock() + (1.5 - u * 1.0)
				if inCamp() and not Cinema.Playing() then DinosaurVFX.Shake(0.12 + u * 0.5, 0.45) end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- the SUMMON prompt on the Time Gate console (you hold a key for a boss in an era you've opened)
--------------------------------------------------------------------------------
local summonPrompt: ProximityPrompt? = nil
local function summonable(): string?
	local p = Net.Profile
	if not p or (rising and os.clock() < rising.Until) or BossHype.LiveBoss() then return nil end
	local best = nil
	for id, n in pairs(p.Keys or {}) do
		local b = Config.Bosses[id]
		if b and n > 0 and canFight(id) and phaseOf(id) == 0 then
			if b.Era == p.Era then return id end
			best = best or id
		end
	end
	return best
end
function BossHype.Summonable(): string?
	return summonable()
end
function BossHype.SummonPoint(): BasePart?
	local camp = Workspace:FindFirstChild("BaseCamp")
	local host = camp and camp:FindFirstChild("EraPromptHost", true)
	return host and host:IsA("BasePart") and host or nil
end
local function stepPrompt()
	local id = summonable()
	if not summonPrompt then
		local host = BossHype.SummonPoint()
		if not host then return end
		local at = Instance.new("Attachment")
		at.Name = "DinoSummonAt"
		at.Position = Vector3.new(0, 2.4, 0)
		at.Parent = host
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "DinoSummon"
		pr.ActionText = "Summon"
		pr.KeyboardKeyCode = Enum.KeyCode.F
		pr.GamepadKeyCode = Enum.KeyCode.ButtonY
		pr.HoldDuration = 0.8
		pr.MaxActivationDistance = 16
		pr.RequiresLineOfSight = false
		pr:SetAttribute("PromptColor", "Orange")
		pr.Enabled = false
		pr.Parent = at
		summonPrompt = pr
	end
	local pr = summonPrompt :: ProximityPrompt
	-- a fight in progress turns it into a JOIN prompt (the gate itself stays blue)
	local live = BossHype.LiveBoss()
	local target = live or id
	pr.Enabled = target ~= nil and inCamp()
	pr.ActionText = live and "Join Fight" or "Summon"
	pr:SetAttribute("Join", live ~= nil or nil)
	if target then
		pr.ObjectText = (Config.Bosses[target] :: any).Name
		pr:SetAttribute("Boss", target)
	end
end

function BossHype.Start()
	buildCard()
	Net.On("BossRising", function(info) task.spawn(onRising, info) end)
	-- a den opened: remember how long it can be joined (the card's "JOIN IN THE NEXT 1:52")
	Net.On("BossEvent", function(info)
		if typeof(info.Boss) == "string" then
			awakeUntil[info.Boss] = os.clock() + (info.Until or Config.BossEventWindow)
			if info.By then dismissed[info.Boss] = nil end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt ~= summonPrompt then return end
		local id = prompt:GetAttribute("Boss")
		if typeof(id) ~= "string" then return end
		if prompt:GetAttribute("Join") then
			-- ride the Time Gate straight into the fight in progress
			local res = Net.Ask("JoinBoss", { Boss = id })
			if res and res.Ok then dismissed[id] = os.clock() + 300
			else Kit.Toast((res and res.Err) or "CAN'T JOIN RIGHT NOW", "Red", "Crown") end
			return
		end
		local res = Net.Ask("SummonFromCamp", { Boss = id })
		if not (res and res.Ok) then Kit.Toast((res and res.Err) or "CAN'T SUMMON RIGHT NOW", "Red", "Crown") end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then return end
		acc = 0
		stepCard()
		stepPrompt()
	end)
end

return BossHype
