--[[
	HUD — the always-on screens, in the reference style (floating outlined counters, chunky tiles, tilted tabs).

	Camp:   SHOP / HOME / ERAS tabs, SETTINGS + INDEX tiles, a quest tracker (collapses to a pill on phones),
	        HUNTER POWER, DRIVE + MY ROVERS, money with $/s, one objective with a waypoint, and the hotbar:
	        your best eggs (tap / 1-6 to carry one to a nest) with the BAG as the rightmost tile
	        (tap it on mobile, B on keyboard, Y on a gamepad).
	Chase:  armour, roof-rack eggs (rarity + KG), darts, coins, route progress, the ruler's calm bar,
	        forks, side warnings, boost / dart / brake buttons on touch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local RouteMath = require(DinoShared.Game:WaitForChild("RouteMath"))
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local Cinema = require(script.Parent.Cinema)
local Net = require(script.Parent.Parent.Net)
local Drive = require(script.Parent.Parent.Drive)
local CampView = require(script.Parent.Parent.CampView)

local player = Players.LocalPlayer
local C = Theme.C
local Runtime = DinoShared:WaitForChild("Runtime")
local HUD = {}
local Panels -- set in Start
local dripFeed: (seated: boolean) -> ()
local BossHype = require(script.Parent.Parent.BossHype)
HUD.OnFire = nil :: (() -> ())? -- set by Darts
HUD.OnDrive = nil :: (() -> ())? -- set by Garage
HUD.OnSpin = nil :: (() -> ())? -- set by init (SpinView.Open)
HUD.FlushSummary = nil :: (() -> ())? -- shows a waiting run summary (after the warp home lands)
HUD.CurrentTarget = nil :: BasePart?
HUD.Hidden = false

local canvas
local camp = {} :: any
local run = {} :: any
local mode = "Camp"
local banner

local function frame(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	for k, v in pairs(props or {}) do (f :: any)[k] = v end
	f.Parent = parent
	return f
end

-- a hold button that always lets go: a thumb sliding off before it lifts never fired MouseButton1Up / MouseLeave
-- on touch, which left BOOST (or BRAKE) stuck on and the rover driving itself
local function holdButton(hit: GuiButton, set: (boolean) -> ())
	local holding: InputObject? = nil
	hit.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then holding = input set(true) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if holding and (input == holding or (input.UserInputType == Enum.UserInputType.MouseButton1
			and holding.UserInputType == Enum.UserInputType.MouseButton1)) then
			holding = nil
			set(false)
		end
	end)
end

local function isTouch(): boolean
	return Kit.Platform() == "Touch"
end

--------------------------------------------------------------------------------
-- waypoint: a bouncing chevron + label + distance over the objective
--------------------------------------------------------------------------------
local waypoint = nil
local function setWaypoint(target: BasePart?, label: string?)
	if waypoint and waypoint.Adornee == target then return end
	if waypoint then waypoint:Destroy() waypoint = nil end
	if not target then return end
	local bb = Instance.new("BillboardGui")
	bb.Name = "DinoWaypoint"
	bb.Size = UDim2.fromOffset(150, 120)
	bb.StudsOffset = Vector3.new(0, 8, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 3000
	bb.Adornee = target
	local arrow = Kit.Glyph(bb, "Chevron", { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), Color = C.YellowHi })
	arrow.Rotation = 90
	Kit.Text(bb, label or "", { Name = "Label", Pixel = true, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 60), Color = C.YellowHi, Shadow = 2, Stroke = 2.5, MaxSize = 14 })
	local dist = Kit.Text(bb, "", { Name = "Dist", Pixel = true, Size = UDim2.new(1, 0, 0, 11), Position = UDim2.new(0, 0, 0, 82), Color = C.Cream, Shadow = 2, Stroke = 2, MaxSize = 11 })
	bb.Parent = player:WaitForChild("PlayerGui")
	waypoint = bb
	task.spawn(function()
		while bb.Parent do
			arrow.Position = UDim2.new(0.5, 0, 0, 6 + math.abs(math.sin(os.clock() * 3.2)) * 10)
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and target.Parent then
				local d = (hrp.Position - target.Position).Magnitude
				Kit.SetText(dist, string.format("%dm", d))
				bb.Enabled = d > 14 and not HUD.Hidden and not Cinema.Playing()
			end
			task.wait()
		end
	end)
end
HUD.SetWaypoint = setWaypoint

-- (cached: the objective asks for these every frame, and a recursive search of Base Camp walks ~30k parts; a name
-- that isn't there is looked for again only every few seconds)
local findCache = setmetatable({}, { __mode = "k" }) :: { [Instance]: { [string]: any } }
local function find(root: Instance?, name: string): BasePart?
	if not root then return nil end
	local per = findCache[root]
	if not per then per = {} findCache[root] = per end
	local e = per[name]
	if e then
		if e.Part and e.Part.Parent then return e.Part end
		if not e.Part and os.clock() < e.Retry then return nil end
	end
	local p = root:FindFirstChild(name, true)
	local part = p and p:IsA("BasePart") and p or nil
	per[name] = { Part = part, Retry = os.clock() + 30 } -- (missing names: a ~30k-part search every 4 s was a hitch)
	return part
end
local function baseCamp(): Instance? return Workspace:FindFirstChild("BaseCamp") end

local NPC_NAME = { Professor = "THE PROFESSOR", Mechanic = "THE ARMORER", EggKeeper = "THE EGG KEEPER", Ranger = "THE RANGER" }
local function npcSpot(npc: string): BasePart?
	-- (only camp NPCs get a waypoint: one who lives in an era - the Ranger - used to pull the trail straight across
	-- the lagoon toward Fern Valley; the line still says who to talk to)
	return find(baseCamp(), "NpcSpot_" .. npc)
end

local function freeNest(p): number?
	local used = {}
	for _, inc in ipairs(p.Incubators or {}) do used[inc.Slot] = true end
	for s = 1, p.IncubatorCount or 0 do if not used[s] then return s end end
	return nil
end


local function ownRoverRoot(): BasePart?
	local vf = Workspace:FindFirstChild("ActiveVehicles")
	for _, v in ipairs(vf and vf:GetChildren() or {}) do
		if v:GetAttribute("Owner") == player.UserId and v:IsA("Model") then return v.PrimaryPart end
	end
	return nil
end

-- THE POWER TRAINER on your island (TrainerView, 2026-10-14): power is earned only while you stand on its pad.
-- Required lazily and pcall'd: without TrainerView (or if it throws) the goal chain just skips its trainer steps.
local trainer = { View = nil :: any, Tried = -math.huge, PadTime = 0, LastT = 0, Told = false }
local function trainerPad(): BasePart?
	if trainer.View == nil and os.clock() - trainer.Tried > 5 then
		trainer.Tried = os.clock()
		local mod = script.Parent.Parent:FindFirstChild("TrainerView")
		if mod and mod:IsA("ModuleScript") then
			local ok, tv = pcall(require, mod)
			if ok and type(tv) == "table" then trainer.View = tv end
		end
	end
	local tv = trainer.View
	if not (tv and type(tv.Pad) == "function") then return nil end
	local ok, pad = pcall(tv.Pad)
	if ok and typeof(pad) == "Instance" and pad:IsA("BasePart") and pad:IsDescendantOf(Workspace) then return pad end
	return nil
end
-- where its upgrade is bought: the machine's board if it has one, else the pad itself
local function trainerBoard(pad: BasePart): BasePart
	local tv = trainer.View
	if tv and type(tv.Board) == "function" then
		local ok, b = pcall(tv.Board)
		if ok and typeof(b) == "Instance" and b:IsA("BasePart") then return b end
	end
	local m = pad:FindFirstAncestorWhichIsA("Model")
	local b = m and m:FindFirstChild("TrainerBoard", true)
	if b and b:IsA("BasePart") then return b end
	if b and b:IsA("Model") and b.PrimaryPart then return b.PrimaryPart end
	return pad
end
-- standing on it (TrainerView's own answer if it has one; else over the pad's footprint, box or round)
local function onPad(pad: BasePart): boolean
	local tv = trainer.View
	if tv and type(tv.OnPad) == "function" then
		local ok, on = pcall(tv.OnPad)
		if ok and type(on) == "boolean" then return on end
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false end
	local d = hrp.Position - pad.Position
	local r = math.max(pad.Size.X, pad.Size.Y, pad.Size.Z) / 2 + 0.5
	return Vector3.new(d.X, 0, d.Z).Magnitude <= r and math.abs(d.Y) < 8
end
-- Config.Trainer.Levels = { { Cost =, PerSec = }, ... } (the trainer's numbers), read defensively
local function trainerLevels(): { any }?
	local t = (Config :: any).Trainer
	return (t and type(t.Levels) == "table") and t.Levels or nil
end
-- your first training session: ~10 s on the pad (or the power that earns), remembered on the server (Tips.Trained)
local function trainedOnce(p): boolean
	local tips = p.Flags and p.Flags.Tips
	if tips and tips.Trained then return true end
	local levels = trainerLevels()
	local per = levels and levels[1] and tonumber(levels[1].PerSec) or nil
	local done = trainer.PadTime >= 10 or (per ~= nil and per > 0 and (tonumber(p.TrainPower) or 0) >= per * 10)
	if done and not trainer.Told then
		trainer.Told = true
		task.spawn(function() Net.Ask("Tip", { Key = "Trained" }) end)
	end
	return done
end

-- a guide someone asked for ("show me the way"): it wins until you get there (or two minutes pass)
local guide = nil :: any
function HUD.Guide(target: BasePart?, label: string, text: string, icon: string?)
	guide = target and { Target = target, Label = label, Text = text, Icon = icon or "Map", Until = os.clock() + 120 } or nil
end

-- the single next thing to do: text, world target, waypoint tag, icon
local function objective()
	local p = Net.Profile
	if not p then return "BASE CAMP", nil, nil, "Home" end
	if guide then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not guide.Target.Parent or os.clock() > guide.Until or (hrp and (hrp.Position - guide.Target.Position).Magnitude < 12) then
			guide = nil
		else
			return guide.Text, guide.Target, guide.Label, guide.Icon
		end
	end
	local plot = CampView.OwnPlot()
	local now = Net.ServerTime()
	local seated = Drive.State.Mode == "Camp"
	local runs = p.Stats and p.Stats.Runs or 0
	local readySlot, soonest, soonSlot = nil, math.huge, nil
	for _, inc in ipairs(p.Incubators or {}) do
		local remain = inc.Start + inc.Duration - now
		if remain <= 0 then readySlot = readySlot or inc.Slot elseif remain < soonest then soonest, soonSlot = remain, inc.Slot end
	end
	local free = freeNest(p)
	if not seated then
		if player:GetAttribute("HeldEgg") and free then return "WALK TO A NEST AND PRESS E", CampView.NestPoint(free), "NEST", "Incubator" end
		if readySlot then return "HATCH YOUR EGG!", CampView.NestPoint(readySlot), "HATCH", "Egg" end
		-- the yard's full and a dino's waiting in your bag: show where to make room (the yard bench by your Companion
		-- pad), once you can afford the next space (2026-10-14, user: "explain that ... right now it just says it goes
		-- in your hotbar")
		local slots = p.PenSlots or Config.Pen.Base
		if slots < Config.Pen.Max and #(p.Placed or {}) >= slots and (p.Coins or 0) >= Config.PenPrice(slots) then
			local busy = {}
			for _, id in ipairs(p.Placed or {}) do busy[id] = true end
			for _, id in ipairs(p.Buddies or {}) do busy[id] = true end
			for _, pen in pairs((p.Island and p.Island.Pens) or {}) do if type(pen) == "table" and pen.Dino then busy[pen.Dino] = true end end
			local waiting = false
			for _, d in ipairs(p.Dinos or {}) do if not busy[d.Id] then waiting = true break end end
			local kit = require(script.Parent.Parent.PaddockLife).YardKit
			local host = kit and kit.Parent and kit:FindFirstChild("YardPromptHost", true) :: BasePart?
			if waiting and host then return "YARD FULL - BUILD MORE ROOM AT YOUR PEN", host, "BIGGER YARD", "Paddock" end
		end
	end
	-- home with eggs on the rack: drive to your plot, then unload each one
	local onRack = #(p.RoverEggs or {})
	if onRack > 0 then
		local rover = ownRoverRoot()
		local home = plot and (find(plot, "RollOutPoint") or find(plot, "GarageSign"))
		local farFromHome = rover and home and (rover.Position - home.Position).Magnitude > 60
		-- (islands: you come back out of the Time Gate, 400-570 studs from your nests - drive home first, then grab
		-- them; hopping out by the gate meant carrying every egg on foot across your bridge)
		if seated and farFromHome then return "DRIVE HOME TO YOUR ISLAND", home, "HOME", "Home" end
		-- (hopping out parks the rover with the eggs still strapped on: you take each one off its rack. The old "PRESS V
		-- TO GRAB YOUR EGGS" promised they'd land in your bag - testers thought a boss egg was lost)
		if seated then return (Kit.Gamepad() and "PRESS D-PAD RIGHT" or (Kit.Platform() == "Touch" and "PRESS EXIT" or "PRESS V")) .. " TO HOP OUT", nil, nil, "Rack" end
		if rover and not player:GetAttribute("HeldEgg") then return "TAKE YOUR EGGS OFF THE RACK", rover, "EGGS", "Rack" end
	end
	if not seated then
		if #(p.Eggs or {}) > 0 and free then return "TAP AN EGG IN YOUR HOTBAR TO PICK IT UP", nil, nil, "Egg" end
		-- eggs waiting, every nest busy: build another one if you can afford it
		if #(p.Eggs or {}) > 0 and not free then
			local spot, price = CampView.BuyNestPoint()
			if spot and price and (p.Coins or 0) >= price then return "BUILD A NEW INCUBATOR (" .. Config.FormatNumber(price) .. " COINS)", spot, "BUILD", "Incubator" end
		end
		for _, q in ipairs((p.Quests and p.Quests.Active) or {}) do
			if (q.Progress or 0) >= q.Goal.Count then return "TALK TO " .. (NPC_NAME[q.Npc] or q.Npc), npcSpot(q.Npc), "QUEST", "Quest" end
		end
		-- (the daily chest is NOT an objective - user 2026-10-13: it's there to find, not a chore on the list)
	end
	-- (from here on, a 5th value true = a SOFT goal: the line says what to do, but the waypoint and the ground
	-- trail only appear if you wander off or stall - some players don't want to be walked everywhere)
	local beatKing = p.Bosses and p.Bosses.TyrantKing and (p.Bosses.TyrantKing.Best or 0) >= 1
	-- (a boss that's awake is BossHype's card - JOIN on it - not an objective line saying the same thing twice)
	-- a boss key in your pocket: summon it at the Time Gate console
	local summon = BossHype and BossHype.Summonable()
	-- (only once you're nearly strong enough: at 278 power it used to send you into the 400-power Titan, and the
	-- lost fights cost minutes; below 85% the line below suggests the upgrade that gets you there instead)
	local summonBoss = summon and Config.Bosses[summon] :: any
	if summon and not seated and (p.Power or 0) >= (summonBoss.Power or 0) * 0.85 then
		return "SUMMON THE " .. summonBoss.Name, BossHype.SummonPoint(), "SUMMON", "Crown", true
	end
	-- (2026-10-13: "the onboarding said go to the quartermaster, I got in my car and it said drive into the time gate"
	-- - the camp steps below now hold while you drive there; the Time Gate only when there's nothing at camp to do)
	-- (only a SHORT wait is worth standing around for: an Epic's 6 minutes put the whole tutorial on hold -
	-- 2026-10-13. A long one hatches while you do the next thing; the nest's own timer shows it)
	if runs == 1 and soonSlot and soonest <= 40 and not seated then return "YOUR EGG HATCHES IN " .. Config.FormatTime(soonest), CampView.NestPoint(soonSlot), "NEST", "Clock" end
	if runs >= 1 then
		-- the next real step, not just "go again": craft what you've earned, get strong enough, open the next era
		-- (at the wheel only the ones you drive TO count: a "save up" line falls through to the Time Gate)
		local gear = p.Gear or {}
		local mats = p.Materials or {}
		local coins = p.Coins or 0
		local power = p.Power or 0
		local tips = (p.Flags and p.Flags.Tips) or {}
		local fang = Config.Launchers.QueensFang :: any
		local console = find(baseCamp(), "EraPromptHost")
		-- THE POWER TRAINER (2026-10-14): power comes from standing on your trainer's pad, so it's the first stop after
		-- your first run - show, don't tell: stand there, the +POWER numbers pop and the HUNTER POWER counter appears
		local pad = trainerPad()
		local levels = trainerLevels()
		local tlvl = tonumber(p.Trainer and p.Trainer.Level) or 1
		local tnext = levels and levels[tlvl + 1]
		local tcost = tnext and tonumber(tnext.Cost) or nil
		local standing = pad ~= nil and not seated and onPad(pad)
		local tnow = os.clock()
		if standing then trainer.PadTime += math.min(0.5, tnow - trainer.LastT) end
		trainer.LastT = tnow
		if pad and not trainedOnce(p) then
			-- (not soft: nobody knows where it is yet, so the waypoint shows at once; on the pad the line just says stay)
			if standing then return "TRAINING! STAY ON THE PAD", nil, nil, "Power" end
			return (seated and "DRIVE HOME TO YOUR POWER TRAINER" or "STAND ON YOUR POWER TRAINER"), pad, "TRAINER", "Power"
		end
		-- the free first upgrade: the trainer's when it gives it (Config.Trainer.FirstFree), else still the Armorer's
		-- first armor level (Shop.levelUp) - the only thing he does now is armor and gadgets
		if not (p.Flags and p.Flags.FreeUpgradeUsed) then
			local tr = (Config :: any).Trainer
			if pad and tcost and tr and tr.FirstFree then
				return (seated and "DRIVE TO YOUR TRAINER - ITS FIRST UPGRADE IS FREE" or "UPGRADE YOUR TRAINER - IT'S FREE!"), trainerBoard(pad), "FREE UPGRADE", "Power"
			elseif not (tr and tr.FirstFree) and (gear.ArmorLvl or 1) < Config.MaxLevel then
				return (seated and "DRIVE TO THE ARMORER - FREE ARMOR UPGRADE" or "VISIT THE ARMORER - YOUR FIRST ARMOR UPGRADE IS FREE"), npcSpot("Mechanic"), "ARMORER", "Armor"
			end
		end
		-- (the first paid trainer level, once you can afford it: the upgrade loop, shown once)
		if pad and tcost and tlvl <= 1 and coins >= tcost and not seated then
			return "UPGRADE YOUR TRAINER - MORE POWER EVERY SECOND", trainerBoard(pad), "UPGRADE", "Power", true
		end
		-- boss launchers are crafted at the trainer now (its own window)
		if fang and fang.Craft and gear.Launcher == "Rookie" and (mats.QueenClaw or 0) >= 3 then
			if coins >= fang.Craft.Coins then return "CRAFT THE " .. (fang.Name or "TYRANT FANG") .. " AT YOUR TRAINER", pad and trainerBoard(pad) or nil, "CRAFT", "Hammer", true end
			if not seated then return "SAVE UP FOR THE " .. (fang.Name or "TYRANT FANG") .. "  " .. Config.FormatNumber(coins) .. " / " .. Config.FormatNumber(fang.Craft.Coins), nil, nil, "Coin" end
		end
		-- opening the next era happens at the Time Gate CONSOLE (the era picker), then you drive through the gate
		for _, era in ipairs(Config.Eras) do
			local e = era :: any
			if not e.Built or not e.Unlock or not e.Unlock.Boss then continue end
			local rec = p.Bosses and p.Bosses[e.Unlock.Boss]
			if rec and (rec.Best or 0) >= 1 and not (p.Unlocked and p.Unlocked[e.Id]) then
				if coins >= e.Unlock.Coins then return "OPEN " .. e.Name .. " AT THE TIME GATE", console, "OPEN ERA", "Gate" end
				if not seated then return "SAVE UP TO OPEN " .. e.Name .. "  " .. Config.FormatNumber(coins) .. " / " .. Config.FormatNumber(e.Unlock.Coins), nil, nil, "Coin" end
			end
			-- opened but never been: go there (set the gate if it points somewhere else)
			if p.Unlocked and p.Unlocked[e.Id] and not tips["Est_" .. e.Id] then
				if p.Era ~= e.Id then return "SET THE TIME GATE TO " .. e.Name, console, "TIME GATE", "Gate" end
				if not seated then return "DRIVE TO " .. e.Name .. "!", nil, nil, "Gate" end
			end
		end
		-- not strong enough for the next boss yet (the one you hold a key for, else the Tyrant King until beaten): the
		-- cheaper of the next trainer level / armor level if you can afford one, else a short stand on the trainer
		local target = summonBoss or ((not beatKing) and Config.Bosses.TyrantKing) or nil :: any
		if target and power < target.Power then
			local gap = "  (POWER " .. power .. " / " .. target.Power .. ")"
			local alvl = gear.ArmorLvl or 1
			local a = Config.Armors[gear.Armor or "None"] :: any
			local ap = alvl < Config.MaxLevel and Config.LevelPrice(a and a.Order or 1, alvl) or math.huge
			local tp = (pad and tcost) or math.huge
			if coins >= math.min(tp, ap) then
				if pad and tp <= ap then return "UPGRADE YOUR TRAINER" .. gap, trainerBoard(pad), "UPGRADE", "Power", true end
				return "UPGRADE YOUR ARMOR AT THE ARMORER" .. gap, npcSpot("Mechanic"), "UPGRADE", "Armor", true
			end
			-- (only when it's a short stand: a long one is an expedition's coins and a trainer upgrade away - nobody
			-- should be told to stand still for ten minutes; user 2026-10-13 on waiting)
			local per = levels and levels[tlvl] and tonumber(levels[tlvl].PerSec) or 0
			if pad and not seated and per > 0 and (target.Power - power) / per <= 150 then
				if standing then return "TRAINING FOR THE " .. target.Name .. " - STAY ON THE PAD", nil, nil, "Power" end
				return "TRAIN ON YOUR POWER TRAINER" .. gap, pad, "TRAIN", "Power", true
			end
		end
	end
	if seated then return "DRIVE INTO THE TIME GATE", find(baseCamp(), "GateTrigger"), "TIME GATE", "Gate" end
	if runs >= 1 then
		-- you're on your own now: hunt, hatch, and take on the bosses
		local beaten = p.Bosses and next(p.Bosses) ~= nil
		return beaten and "GO ON AN EXPEDITION - HUNT BIGGER DINOS" or "GO ON ANOTHER EXPEDITION - FIND THE BOSS", nil, nil, "Map"
	end
	return "PRESS DRIVE TO GET YOUR ROVER", nil, nil, "Jeep"
end

--------------------------------------------------------------------------------
-- camp: hotbar
--------------------------------------------------------------------------------
local HOTBAR = 6
local function sortedEggs(p): { any }
	local list = table.clone(p.Eggs or {})
	table.sort(list, function(a, b)
		local ra, rb = Config.Rarity[a.Rarity].Order, Config.Rarity[b.Rarity].Order
		if ra ~= rb then return ra > rb end
		return (a.KG or 0) > (b.KG or 0)
	end)
	return list
end

local function holdEgg(id: string?)
	if Drive.State.Mode ~= "None" then Kit.Toast("GET OUT OF THE ROVER FIRST", "Red", "Jeep") return end
	if player:GetAttribute("Site") then return end
	local res = Net.Ask("HoldEgg", { Id = id })
	if res and not res.Ok then Kit.Toast(res.Err or "CAN'T", "Red", "Egg") end
end
-- hold one of your dinos in your arms, like an egg
local function holdDino(id: string?)
	if Drive.State.Mode ~= "None" then Kit.Toast("GET OUT OF THE ROVER FIRST", "Red", "Jeep") return end
	if player:GetAttribute("Site") then return end
	local res = Net.Ask("HoldDino", { Id = id })
	if res and not res.Ok then Kit.Toast(res.Err or "CAN'T", "Red", "Dino") end
end
-- the hotbar holds eggs and dinos: dinos you've dragged onto a slot stay pinned there (profile.HotbarPins);
-- your eggs fill every other slot, best first
local function hotbarItems(p): { any }
	local eggs = sortedEggs(p)
	local byId = {}
	for _, d in ipairs(p.Dinos or {}) do byId[d.Id] = d end
	local list = {}
	local pins = p.HotbarPins or {}
	for i = 1, HOTBAR do
		local d = byId[pins[i] or ""]
		if d then list[i] = { Kind = "Dino", Id = d.Id, Species = d.Species, Rarity = d.Rarity, KG = d.KG } end
	end
	local ei = 1
	for i = 1, HOTBAR do
		if not list[i] and eggs[ei] then
			local e = eggs[ei]
			list[i] = { Kind = "Egg", Id = e.Id, Species = e.Species, Rarity = e.Rarity, KG = e.KG }
			ei += 1
		end
	end
	return list
end
HUD.HotbarItems = hotbarItems
local function isHeld(id: string?): boolean
	return id ~= nil and (player:GetAttribute("HeldEgg") == id or player:GetAttribute("HeldDino") == id)
end
local function useSlot(rec)
	if not rec.Id then return end
	-- tap the one in your arms again to put it away
	local id = if isHeld(rec.Id) then nil else rec.Id
	if rec.Kind == "Dino" then holdDino(id) else holdEgg(id) end
end

local function buildHotbar(root: Frame)
	local bar = frame(root, { Name = "Hotbar", Size = UDim2.fromOffset((HOTBAR + 1) * 82 + 16, 92), Position = UDim2.new(0.5, 0, 1, -14), AnchorPoint = Vector2.new(0.5, 1) })
	camp.Hotbar = bar
	camp.Slots = {}
	for i = 1, HOTBAR do
		local slot = frame(bar, { Name = "Slot" .. i, Size = UDim2.fromOffset(74, 74), Position = UDim2.fromOffset((i - 1) * 82, 12), BackgroundTransparency = 0.25, BackgroundColor3 = C.Forest })
		Kit.Corner(slot, 14)
		local st = Kit.Stroke(slot, C.Ink, 3.5)
		local inner = frame(slot, { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4) })
		Kit.Corner(inner, 10)
		local ist = Kit.Stroke(inner, Color3.new(1, 1, 1), 2)
		ist.Transparency = 0.6
		local iconHolder = frame(slot, { Size = UDim2.fromScale(1, 1), ZIndex = 6 })
		local kg = Kit.Text(slot, "", { Name = "KG", Pixel = true, Size = UDim2.new(1, -6, 0, 9), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9, Stroke = 2, Shadow = 1, MaxSize = 9 })
		local key = Kit.Text(slot, tostring(i), { Name = "Key", Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(4, 2), ZIndex = 9, Stroke = 2.5, Shadow = 2, MaxSize = 18, Color = C.Cream })
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 12
		hit.Parent = slot
		local rec = { Frame = slot, Stroke = st, Icon = iconHolder, KG = kg, Key = key, Id = nil :: string?, Sig = "", Info = nil :: any }
		-- hover (or tap on touch): what it is, its weight and rarity
		require(script.Parent.Parent.EggTip).Bind(hit, function() return rec.Info end)
		hit.Activated:Connect(function()
			Kit.Punch(slot, 0.12)
			Kit.Sound("Click", 0.4)
			if not rec.Id then Panels.Open("Bag") return end
			useSlot(rec)
		end)
		camp.Slots[i] = rec
	end
	-- the bag: always the rightmost tile
	local bagTile = Kit.Tile(bar, { Name = "Bag", Icon = "Bag", Label = "BAG", Color = "Yellow", Size = UDim2.fromOffset(86, 86), Position = UDim2.fromOffset(HOTBAR * 82 + 2, 2), OnClick = function() Panels.Open("Bag") end })
	camp.Bag = bagTile
	camp.BagKey = Kit.Text(bagTile, "B", { Name = "Key", Size = UDim2.fromOffset(22, 20), Position = UDim2.new(1, -4, 0, -6), AnchorPoint = Vector2.new(1, 0), ZIndex = 20, Stroke = 3, Shadow = 2, MaxSize = 20, Color = C.Cream })
end

local function refreshHotbar()
	local p = Net.Profile
	if not p or not camp.Slots then return end
	local list = hotbarItems(p)
	for i, rec in ipairs(camp.Slots) do
		local e = list[i]
		local sig = e and (e.Kind .. e.Id .. tostring(isHeld(e.Id))) or ""
		if sig == rec.Sig then continue end
		rec.Sig = sig
		rec.Id = e and e.Id or nil
		rec.Kind = e and e.Kind or nil
		rec.Info = e and { Species = e.Species, Rarity = e.Rarity, KG = e.KG, Dino = e.Kind == "Dino" } or nil
		local held = e and isHeld(e.Id) and e.Id or nil
		for _, c in ipairs(rec.Icon:GetChildren()) do c:Destroy() end
		if e then
			local r = Config.Rarity[e.Rarity]
			rec.Frame.BackgroundColor3 = r.Color:Lerp(C.Forest, 0.45)
			rec.Frame.BackgroundTransparency = 0.05
			rec.Stroke.Color = held == e.Id and C.YellowHi or C.Ink
			rec.Stroke.Thickness = held == e.Id and 5 or 3.5
			Kit.Icon(rec.Icon, e.Kind == "Dino" and "Dino" or "Egg", { Species = e.Species, Size = UDim2.fromScale(e.Kind == "Dino" and 0.95 or 0.8, e.Kind == "Dino" and 0.95 or 0.8), Position = UDim2.fromScale(0.5, 0.44), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 7 })
			Kit.SetText(rec.KG, Config.FormatKG(e.KG or 0))
			Kit.SetTextColor(rec.KG, r.Color:Lerp(Color3.new(1, 1, 1), 0.35))
			rec.Frame.Position = UDim2.fromOffset(rec.Frame.Position.X.Offset, held == e.Id and 2 or 12)
		else
			rec.Frame.BackgroundColor3 = C.Forest
			rec.Frame.BackgroundTransparency = 0.45
			rec.Stroke.Color = C.Ink
			rec.Stroke.Thickness = 3.5
			Kit.SetText(rec.KG, "")
			rec.Frame.Position = UDim2.fromOffset(rec.Frame.Position.X.Offset, 12)
		end
	end
	local n = #(p.Eggs or {})
	Kit.Badge(camp.Bag, n > HOTBAR and n or nil)
end

--------------------------------------------------------------------------------
-- camp: quest tracker
--------------------------------------------------------------------------------
local trackerOpen = true
local function goalText(q): string
	local g = q.Goal
	local n = g.Count or 1
	local what = ({ Expedition = "FINISH EXPEDITIONS", Hatch = "HATCH EGGS", Takedown = "KNOCKOUTS", Escape = "ESCAPES", Eggs = "BRING HOME EGGS", Craft = "CRAFT GEAR", Boss = "BEAT THE BOSS", Rarity = "HATCH A " .. string.upper(g.Rarity or "") .. "+" })[g.Kind] or g.Kind
	return string.format("%s %d/%d", what, math.min(q.Progress or 0, n), n)
end

local function refreshTracker()
	local p = Net.Profile
	local holder = camp.Tracker
	if not p or not holder then return end
	for _, c in ipairs(holder:GetChildren()) do if c:IsA("GuiObject") and c.Name ~= "Toggle" then c:Destroy() end end
	local active = (p.Quests and p.Quests.Active) or {}
	holder.Visible = #active > 0
	camp.TrackerToggle.Visible = #active > 0
	Kit.SetText(camp.TrackerToggleText, (trackerOpen and "QUESTS  -" or "QUESTS  +") .. "  " .. #active)
	if not trackerOpen then return end
	for i, q in ipairs(active) do
		local done = (q.Progress or 0) >= q.Goal.Count
		local row, rc = Kit.Card(holder, { Size = UDim2.fromOffset(250, 58), Position = UDim2.fromOffset(0, 34 + (i - 1) * 64), Color = done and "Lime" or "Card", ZIndex = 4, Lip = 4 })
		row.Name = "Q" .. i
		Kit.Text(rc, q.Title, { Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(10, 6), Align = Enum.TextXAlignment.Left, ZIndex = 8, Stroke = 3, Shadow = 2, MaxSize = 18 })
		Kit.Text(rc, done and ("TALK TO " .. (NPC_NAME[q.Npc] or "")) or goalText(q), { Pixel = true, Size = UDim2.new(1, -16, 0, 9), Position = UDim2.fromOffset(10, 28), Align = Enum.TextXAlignment.Left, ZIndex = 8, Stroke = 1.5, Shadow = 1, MaxSize = 9, Color = done and C.YellowHi or C.Cream })
		if not done then
			local set = Kit.Segments(rc, math.min(q.Goal.Count, 8), { Size = UDim2.new(1, -20, 0, 8), Position = UDim2.fromOffset(10, 42), ZIndex = 8 })
			set((q.Progress or 0) / q.Goal.Count, C.Lime)
		end
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 12
		hit.Parent = row
		hit.Activated:Connect(function() Panels.Open("Quests") end)
	end
end

--------------------------------------------------------------------------------
-- camp HUD
--------------------------------------------------------------------------------
local function buildCamp()
	local root = frame(canvas, { Name = "Camp", Size = UDim2.fromScale(1, 1) })
	camp.Root = root
	local tabs = {
		{ "SHOP", "Blue", function() Panels.Open("Shop") end },
		{ "HOME", "Red", function()
			local res = Net.Ask("Home")
			if not (res and res.Ok) then Kit.Toast("CAN'T GO HOME RIGHT NOW", "Red", "Home") end
		end },
		{ "ERAS", "Yellow", function() Panels.Open("Eras") end },
	}
	camp.Tabs = {}
	for i, t in ipairs(tabs) do
		camp.Tabs[t[1]] = Kit.NavTab(root, { Name = t[1], Text = t[1], Color = t[2], Size = UDim2.fromOffset(150, 50), Position = UDim2.new(0.5, (i - 2) * 168, 0, 18), AnchorPoint = Vector2.new(0.5, 0), Tilt = -3, OnClick = t[3] })
	end
	-- right column: settings, index, quest tracker
	camp.Settings = Kit.Tile(root, { Name = "Settings", Icon = "Gear", Color = "Purple", Size = UDim2.fromOffset(62, 62), Position = UDim2.new(1, -16, 0, 16), AnchorPoint = Vector2.new(1, 0), IconSize = 0.8, OnClick = function() Panels.Open("Settings") end })
	camp.Index = Kit.Tile(root, { Name = "Index", Icon = "Index", Color = "Blue", Size = UDim2.fromOffset(62, 62), Position = UDim2.new(1, -88, 0, 16), AnchorPoint = Vector2.new(1, 0), IconSize = 0.8, OnClick = function() Panels.Open("Index") end })
	-- the DAILY SPIN (SpinView), with a "!" when the free spin is ready
	camp.Spin = Kit.Tile(root, { Name = "Spin", Icon = "Star", Color = "Orange", Size = UDim2.fromOffset(62, 62), Position = UDim2.new(1, -160, 0, 16), AnchorPoint = Vector2.new(1, 0), IconSize = 0.8, OnClick = function()
		if HUD.OnSpin then HUD.OnSpin() end
	end })
	local tracker = frame(root, { Name = "Tracker", Size = UDim2.fromOffset(250, 230), Position = UDim2.new(1, -16, 0, 96), AnchorPoint = Vector2.new(1, 0), Visible = false })
	camp.Tracker = tracker
	local toggle = Kit.Brick(tracker, { Name = "Toggle", Size = UDim2.fromOffset(150, 28), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Color = "Forest", Lip = 3, Radius = 10, ZIndex = 4 })
	camp.TrackerToggle = toggle
	toggle.Visible = false
	camp.TrackerToggleText = Kit.Text(toggle:FindFirstChild("Body"):FindFirstChild("Content") :: Instance, "QUESTS", { Pixel = true, Size = UDim2.new(1, -14, 0, 11), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8, Stroke = 2, Shadow = 1, MaxSize = 11, Color = C.YellowHi })
	local th = Instance.new("TextButton")
	th.BackgroundTransparency = 1
	th.Text = ""
	th.Size = UDim2.fromScale(1, 1)
	th.ZIndex = 12
	th.Parent = toggle
	th.Activated:Connect(function() trackerOpen = not trackerOpen refreshTracker() end)
	-- left: hunter power, DRIVE, MY ROVERS
	local pw = frame(root, { Name = "Power", Size = UDim2.fromOffset(240, 50), Position = UDim2.new(0, 22, 0.5, -122), AnchorPoint = Vector2.new(0, 0.5) })
	Kit.Icon(pw, "Power", { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 6, Rotation = -8 })
	Kit.Text(pw, "HUNTER POWER", { Pixel = true, Size = UDim2.new(1, -60, 0, 10), Position = UDim2.fromOffset(58, 4), Align = Enum.TextXAlignment.Left, ZIndex = 6, Stroke = 2, Shadow = 1, MaxSize = 10, Color = C.Cream })
	camp.Power = Kit.Text(pw, "0", { Size = UDim2.new(1, -60, 0, 30), Position = UDim2.fromOffset(58, 16), Align = Enum.TextXAlignment.Left, ZIndex = 6, Stroke = 4, Shadow = 3, MaxSize = 32, Color = C.TealHi })
	camp.PowerPanel = pw
	camp.Drive = Kit.Tile(root, { Name = "Drive", Icon = "Jeep", Label = "DRIVE", Color = "Orange", Size = UDim2.fromOffset(112, 112), Position = UDim2.new(0, 22, 0.5, -30), AnchorPoint = Vector2.new(0, 0.5), OnClick = function()
		if HUD.OnDrive then HUD.OnDrive() end
	end })
	camp.DriveKey = Kit.Text(camp.Drive, "V", { Name = "Key", Size = UDim2.fromOffset(22, 20), Position = UDim2.new(1, -4, 0, -6), AnchorPoint = Vector2.new(1, 0), ZIndex = 20, Stroke = 3, Shadow = 2, MaxSize = 20, Color = C.Cream })
	camp.MyRovers = Kit.Button(root, { Name = "MyRovers", Text = "MY ROVERS", Color = "Purple", Size = UDim2.fromOffset(132, 38), Position = UDim2.new(0, 22, 0.5, 36), Radius = 10, Lip = 4, MaxText = 24, TextSize = 0.62, OnClick = function() Panels.Open("Picker") end })
	-- bottom left: money
	local money, amount, sub = Kit.Money(root, { Name = "Coins", Icon = "Coin", Text = "0", Sub = "+0/s from your dinos", Color = C.Lime, Size = UDim2.fromOffset(380, 80), Position = UDim2.new(0, 24, 1, -24), AnchorPoint = Vector2.new(0, 1), OnPlus = function() Panels.Open("Shop") end })
	camp.Coins, camp.Rate, camp.CoinPill = amount, sub, money
	-- objective callout under the tabs
	local obj = frame(root, { Name = "Objective", Size = UDim2.fromOffset(560, 64), Position = UDim2.new(0.5, 0, 0, 88), AnchorPoint = Vector2.new(0.5, 0) })
	camp.ObjIconHolder = frame(obj, { Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 8 })
	camp.ObjText = Kit.Text(obj, "", { Size = UDim2.new(1, -70, 0, 40), Position = UDim2.new(0, 66, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 6, Stroke = 4, Shadow = 4, Color = Color3.new(1, 1, 1), MaxSize = 42 })
	camp.Obj = obj
	-- driving
	camp.Exit = Kit.Button(root, { Name = "Exit", Text = "EXIT", Icon = "Door", IconOut = true, IconSize = 1.1, TextLeft = 0.42, Color = "Red", Size = UDim2.fromOffset(170, 60), Position = UDim2.new(1, -22, 1, -24), AnchorPoint = Vector2.new(1, 1), Radius = 16, OnClick = function() Net.Ask("ExitVehicle") end })
	camp.ExitKey = Kit.Text(camp.Exit, "V", { Name = "Key", Size = UDim2.fromOffset(22, 20), Position = UDim2.new(1, -4, 0, -6), AnchorPoint = Vector2.new(1, 0), ZIndex = 20, Stroke = 3, Shadow = 2, MaxSize = 20, Color = C.Cream })
	camp.Boost = Kit.Tile(root, { Name = "Boost", Icon = "Bolt", Label = "BOOST", Color = "Blue", Size = UDim2.fromOffset(104, 104), Position = UDim2.new(1, -22, 1, -100), AnchorPoint = Vector2.new(1, 1) })
	holdButton(camp.Boost:FindFirstChild("Hit") :: TextButton, Drive.SetBoostHeld)
	-- holding an egg: a little "PUT AWAY" chip above the hotbar
	camp.PutAway = Kit.Button(root, { Name = "PutAway", Text = "PUT AWAY", Color = "Grey", Size = UDim2.fromOffset(150, 40), Position = UDim2.new(0.5, 0, 1, -116), AnchorPoint = Vector2.new(0.5, 1), Radius = 10, Lip = 4, MaxText = 22, OnClick = function() holdEgg(nil) end })
	buildHotbar(root)
end

local lastCoins = nil
local function refreshCamp()
	local p = Net.Profile
	if not p then return end
	if lastCoins ~= p.Coins then
		local from = lastCoins or p.Coins
		Kit.Count(camp.Coins, from, p.Coins, function(n) return Config.FormatNumber(n) end, 0.7)
		if lastCoins and p.Coins > lastCoins then Kit.Punch(camp.CoinPill, 0.12) end
		lastCoins = p.Coins
	end
	Kit.SetText(camp.Rate, "+" .. Config.FormatNumber(p.Rate or 0) .. "/s from your dinos")
	Kit.SetText(camp.Power, Config.FormatNumber(p.Power or 0))
	-- badges: eggs ready on the bag, an affordable upgrade on SHOP is the Mechanic's job now (no badge spam)
	local now = Net.ServerTime()
	local ready = 0
	for _, inc in ipairs(p.Incubators or {}) do if inc.Start + inc.Duration <= now then ready += 1 end end
	-- the Index has a reward ready to claim (IndexDefs: species track, era pages)
	local okR, claimable = pcall(require(DinoShared.Game:WaitForChild("IndexDefs")).ClaimableCount, p)
	Kit.Badge(camp.Index, (okR and (claimable :: number) > 0) and claimable or nil)
	local okS, spins, freeNow = pcall(require(DinoShared.Game:WaitForChild("SpinWheel")).State, p, Net.ServerTime())
	Kit.Badge(camp.Spin, (okS and freeNow) and "!" or ((okS and (spins :: number) > 0) and spins or nil))
	refreshHotbar()
	refreshTracker()
	local _ = ready
end
HUD.RefreshCamp = refreshCamp

-- drifting from a soft goal: no closer for 14 s, or 40 studs further than your closest
local drift = { Key = nil :: string?, Best = math.huge, At = 0, On = false }
local function drifting(target: BasePart): boolean
	local key = target:GetFullName()
	local root = Drive.State.Root or (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not root then return false end
	local now = os.clock()
	local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(target.Position.X, 0, target.Position.Z)).Magnitude
	if drift.Key ~= key then
		drift.Key, drift.Best, drift.At, drift.On = key, dist, now, false
	end
	if dist < drift.Best - 6 then drift.Best, drift.At = dist, now end
	if dist > drift.Best + 40 or now - drift.At > 14 then drift.On = true end
	return drift.On
end

-- DRIP-FEED (user pick 2026-10-12): a new player starts with DRIVE (and settings). Every other piece of the camp HUD
-- pops in, with a sparkle, the first time it matters - the screen teaches you without words.
local HUD_UNLOCK = {
	Coins = function(p, runs) return runs >= 1 or (p.Coins or 0) > 0 end,
	Hotbar = function(p) return #(p.Eggs or {}) > 0 or (p.Stats and (p.Stats.Hatched or 0) >= 1) or player:GetAttribute("HeldEgg") ~= nil end,
	Home = function(_, runs) return runs >= 1 end,
	Index = function(p) return p.Stats and (p.Stats.Hatched or 0) >= 1 end,
	Spin = function(_, runs) return runs >= 1 end, -- (the DAILY SPIN: once you've been out once)
	-- (the HUNTER POWER counter: your first upgrade, or the first second on your power trainer's pad)
	Power = function(p) return (p.Flags and p.Flags.FreeUpgradeUsed) or (tonumber(p.TrainPower) or 0) > 0 or (p.Flags and p.Flags.Tips and p.Flags.Tips.Trained) end,
	Eras = function(p) return p.Bosses and p.Bosses.TyrantKing and (p.Bosses.TyrantKing.Best or 0) >= 1 end,
	Shop = function(p, runs) return runs >= 3 or (p.Bosses and next(p.Bosses) ~= nil) end,
	Rovers = function(p) return p.Unlocked and p.Unlocked.GiantPlains end,
}
local revealed = {} :: { [string]: boolean }
local function unlockedHud(key: string): boolean
	local p = Net.Profile
	if not p then return true end
	local runs = p.Stats and p.Stats.Runs or 0
	if runs >= 8 then return true end -- veterans: everything, always
	return HUD_UNLOCK[key](p, runs) and true or false
end
local function gate(key: string, inst: GuiObject?, want: boolean)
	if not inst then return end
	local open = unlockedHud(key)
	local show = want and open
	if open and not revealed[key] then
		revealed[key] = true
		local p = Net.Profile
		local tips = p and p.Flags and p.Flags.Tips
		-- the first time ever (not every session): pop it in with a sparkle so the eye goes there
		if show and not (tips and tips["Hud_" .. key]) then
			task.defer(function()
				Kit.Pop(inst, 0.2)
				local ab = inst.AbsolutePosition + inst.AbsoluteSize / 2
				local ray = Workspace.CurrentCamera:ViewportPointToRay(ab.X, ab.Y)
				local CineKit = require(script.Parent.CineKit)
				CineKit.Sparkle(ray.Origin + ray.Direction * 12, C.YellowHi, 0.5)
			end)
			if tips then tips["Hud_" .. key] = true end
			task.spawn(function() Net.Ask("Tip", { Key = "Hud_" .. key }) end)
		end
	end
	inst.Visible = show
end
dripFeed = function(seated: boolean)
	gate("Coins", camp.CoinPill, true)
	gate("Hotbar", camp.Hotbar, not seated)
	gate("Index", camp.Index, true)
	gate("Spin", camp.Spin, true)
	gate("Power", camp.PowerPanel, not seated)
	gate("Rovers", camp.MyRovers, not seated)
	gate("Home", camp.Tabs.HOME, true)
	gate("Eras", camp.Tabs.ERAS, true)
	gate("Shop", camp.Tabs.SHOP, true)
	-- the ERAS tab shouts when the next era can be opened (and quietly counts up while you save)
	local p = Net.Profile
	if p and camp.Tabs.ERAS then
		local ready = false
		for _, e in ipairs(Config.Eras) do
			local era = e :: any
			local rec = era.Unlock and era.Built and p.Bosses and p.Bosses[era.Unlock.Boss]
			if rec and (rec.Best or 0) >= 1 and not (p.Unlocked and p.Unlocked[era.Id]) and (p.Coins or 0) >= era.Unlock.Coins then ready = true end
		end
		if ready ~= camp.ErasReady then
			camp.ErasReady = ready
			Kit.Badge(camp.Tabs.ERAS, ready and "!" or nil)
		end
		-- ready: the tab wiggles (a different rhythm from everything else on screen)
		camp.Tabs.ERAS.Rotation = ready and (-3 + math.sin(os.clock() * 9) * 4 * (math.sin(os.clock() * 1.3) > 0 and 1 or 0)) or -3
	end
end

local objIcon = nil
local function stepCamp()
	if mode ~= "Camp" then return end
	camp.Root.Visible = not HUD.Hidden
	local seated = Drive.State.Mode == "Camp"
	local touch = isTouch()
	camp.Drive.Visible = not seated
	camp.MyRovers.Visible = not seated
	camp.Exit.Visible = seated
	camp.Boost.Visible = seated and touch
	camp.Hotbar.Visible = not seated
	camp.PutAway.Visible = not seated and (player:GetAttribute("HeldEgg") ~= nil or player:GetAttribute("HeldDino") ~= nil)
	camp.PowerPanel.Visible = not seated
	dripFeed(seated)
	-- hotbar slot keys only make sense with a keyboard; fewer slots on small phones
	local small = touch and Workspace.CurrentCamera.ViewportSize.X < 900
	for i, rec in ipairs(camp.Slots) do
		rec.Key.Visible = not touch and not Kit.Gamepad()
		rec.Frame.Visible = not (small and i > 4)
	end
	camp.Bag.Position = UDim2.fromOffset((small and 4 or HOTBAR) * 82 + 2, 2)
	camp.Hotbar.Size = UDim2.fromOffset(((small and 4 or HOTBAR) + 1) * 82 + 16, 92)
	Kit.SetText(camp.BagKey, Kit.Gamepad() and "Y" or (touch and "" or "B"))
	Kit.SetText(camp.DriveKey, (touch or Kit.Gamepad()) and "" or "V")
	Kit.SetText(camp.ExitKey, (touch or Kit.Gamepad()) and "" or "V")
	local text, target, label, icon, soft = objective()
	-- a soft goal shows its line only; the waypoint (and Onboarding's trail) join in once you drift or stall
	if soft and target and not drifting(target) then target = nil end
	HUD.CurrentTarget = target
	if camp.LastObj ~= text then
		camp.Obj.Size = UDim2.fromOffset(math.clamp(#text * 26 + 80, 260, 760), 64)
		local first = camp.LastObj == nil
		camp.LastObj = text
		Kit.SetText(camp.ObjText, text)
		if icon ~= objIcon then
			objIcon = icon
			for _, c in ipairs(camp.ObjIconHolder:GetChildren()) do c:Destroy() end
			Kit.Icon(camp.ObjIconHolder, icon or "Star", { Size = UDim2.fromScale(1, 1), ZIndex = 9, Rotation = -8 })
		end
		if not first then Kit.Pop(camp.Obj, 1.6) end
	end
	local hints = not (Net.Profile and Net.Profile.Settings and Net.Profile.Settings.Hints == false)
	setWaypoint((not HUD.Hidden and hints) and target or nil, label)
end

--------------------------------------------------------------------------------
-- chase HUD
--------------------------------------------------------------------------------
local function buildRun()
	local root = frame(canvas, { Name = "Run", Size = UDim2.fromScale(1, 1), Visible = false })
	run.Root = root
	local function counter(name: string, icon: string, text: string, color: Color3, pos: UDim2, anchor: Vector2)
		local h = frame(root, { Name = name, Size = UDim2.fromOffset(190, 56), Position = pos, AnchorPoint = anchor })
		Kit.Icon(h, icon, { Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 6, Rotation = -8 })
		Kit.Text(h, text, { Name = "Amount", Size = UDim2.new(1, -62, 0, 38), Position = UDim2.new(0, 62, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, Color = color, Stroke = 4, Shadow = 3, MaxSize = 40, ZIndex = 6 })
		return h
	end
	-- armour (bottom-left)
	local hp = frame(root, { Name = "Armor", Size = UDim2.fromOffset(300, 64), Position = UDim2.new(0, 24, 1, -24), AnchorPoint = Vector2.new(0, 1) })
	Kit.Icon(hp, "Shield", { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 8, Rotation = -8 })
	run.VName = Kit.Text(hp, "ROOKIE RANGER", { Size = UDim2.new(1, -74, 0, 22), Position = UDim2.fromOffset(70, 2), Align = Enum.TextXAlignment.Left, ZIndex = 6, Stroke = 3.5, Shadow = 3, MaxSize = 24 })
	run.SetHP = Kit.Segments(hp, 10, { Size = UDim2.new(1, -74, 0, 22), Position = UDim2.fromOffset(70, 32), ZIndex = 6 })
	run.HPPanel = hp
	-- roof rack (top-right): one tile per slot, rarity colour + KG
	local eg = frame(root, { Name = "Eggs", Size = UDim2.fromOffset(250, 78), Position = UDim2.new(1, -16, 0, 14), AnchorPoint = Vector2.new(1, 0) })
	run.EggPanel = eg
	run.EggHolder = frame(eg, { Size = UDim2.fromScale(1, 1) })
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Right
	lay.VerticalAlignment = Enum.VerticalAlignment.Top
	lay.Padding = UDim.new(0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = run.EggHolder
	run.DartPill = counter("Darts", "Dart", "8/8", C.OrangeHi, UDim2.new(1, -16, 0, 98), Vector2.new(1, 0))
	run.CoinPill = counter("Coins", "Coin", "0", C.Lime, UDim2.new(1, -16, 0, 156), Vector2.new(1, 0))
	-- route progress (top-centre)
	local pr = frame(root, { Name = "Progress", Size = UDim2.fromOffset(440, 46), Position = UDim2.new(0.5, 0, 0, 16), AnchorPoint = Vector2.new(0.5, 0) })
	local track = frame(pr, { Name = "Track", Size = UDim2.new(1, -56, 0, 18), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 0, BackgroundColor3 = C.InkSoft })
	Kit.Corner(track, 9)
	Kit.Stroke(track, C.Ink, 3.5)
	local fill = frame(track, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = C.Yellow, ZIndex = 4 })
	Kit.Corner(fill, 9)
	Kit.Gradient(fill, C.YellowHi, C.Orange, 0)
	run.Track, run.Fill = track, fill
	run.CarIcon = Kit.Icon(track, "Jeep", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9 })
	Kit.Icon(pr, "Gate", { Size = UDim2.fromOffset(50, 50), Position = UDim2.new(1, 4, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 8 })
	run.ProgressPanel = pr
	-- the goal, always on screen during the chase
	run.Goal = Kit.Text(root, "", { Size = UDim2.fromOffset(520, 26), Position = UDim2.new(0.5, 0, 0, 62), AnchorPoint = Vector2.new(0.5, 0), Color = C.YellowHi, Stroke = 4, Shadow = 3, MaxSize = 28, ZIndex = 6 })
	-- the ruler's calm bar (the phase-2 chase)
	local boss, bc = Kit.Brick(root, { Name = "Boss", Size = UDim2.fromOffset(440, 58), Position = UDim2.new(0.5, 0, 0, 76), AnchorPoint = Vector2.new(0.5, 0), Color = "Red", ZIndex = 3, Round = true })
	boss.Visible = false
	Kit.Icon(bc, "Trophy", { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0, -14, 0.5, -4), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 9 })
	run.BossName = Kit.Text(bc, "", { Size = UDim2.new(1, -150, 0, 16), Position = UDim2.fromOffset(62, 7), Align = Enum.TextXAlignment.Left, ZIndex = 7, Shadow = 2, Stroke = 2.5, MaxSize = 18 })
	run.SetCalm = Kit.Segments(bc, 10, { Size = UDim2.new(1, -150, 0, 16), Position = UDim2.fromOffset(62, 29), ZIndex = 7 })
	Kit.Text(bc, "DART IT!", { Pixel = true, Size = UDim2.fromOffset(80, 10), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 7, Shadow = 1, Stroke = 2, Color = C.YellowHi, MaxSize = 10 })
	run.Boss = boss
	-- fork chooser
	local fk, fc = Kit.Brick(root, { Name = "Fork", Size = UDim2.fromOffset(560, 62), Position = UDim2.new(0.5, 0, 0, 262), AnchorPoint = Vector2.new(0.5, 0), Color = "Purple", ZIndex = 9, Radius = 14 })
	fk.Visible = false
	run.Fork = fk
	local la = Kit.Glyph(fc, "Chevron", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 12, Color = C.YellowHi })
	la.Rotation = 180
	Kit.Glyph(fc, "Chevron", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 12, Color = C.YellowHi })
	run.ForkL = Kit.Text(fc, "", { Size = UDim2.new(0.42, -30, 0, 18), Position = UDim2.new(0, 46, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 12, Shadow = 2, Stroke = 2.5, MaxSize = 20 })
	run.ForkR = Kit.Text(fc, "", { Size = UDim2.new(0.42, -30, 0, 18), Position = UDim2.new(1, -46, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 12, Shadow = 2, Stroke = 2.5, MaxSize = 20 })
	-- side warnings
	run.Warn = {}
	for _, side in ipairs({ -1, 1 }) do
		local w = frame(root, { Name = side < 0 and "WarnL" or "WarnR", Size = UDim2.new(0, 190, 1, 0), Position = UDim2.new(side < 0 and 0 or 1, 0, 0.5, 0), AnchorPoint = Vector2.new(side < 0 and 0 or 1, 0.5), Visible = false, BackgroundTransparency = 0, BackgroundColor3 = C.Red })
		local grad = Instance.new("UIGradient")
		grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, side < 0 and 0.25 or 1), NumberSequenceKeypoint.new(1, side < 0 and 1 or 0.25) })
		grad.Parent = w
		Kit.Icon(w, "Alert", { Size = UDim2.fromOffset(90, 90), Position = UDim2.fromScale(side < 0 and 0.32 or 0.68, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 })
		local chev = Kit.Glyph(w, "Chevron", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromScale(side < 0 and 0.32 or 0.68, 0.58), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8, Color = C.YellowHi })
		chev.Rotation = side < 0 and 180 or 0
		run.Warn[side] = w
	end
	-- boost meter + touch buttons
	local bm = frame(root, { Name = "BoostMeter", Size = UDim2.fromOffset(260, 50), Position = UDim2.new(1, -16, 1, -18), AnchorPoint = Vector2.new(1, 1) })
	Kit.Icon(bm, "Bolt", { Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 8, Rotation = -8 })
	local bbar = frame(bm, { Size = UDim2.new(1, -60, 0, 18), Position = UDim2.new(0, 56, 0.5, -6), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 0, BackgroundColor3 = C.InkSoft, ZIndex = 5 })
	Kit.Corner(bbar, 9)
	Kit.Stroke(bbar, C.Ink, 3.5)
	run.BoostFill = frame(bbar, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = C.BlueHi, ZIndex = 6 })
	Kit.Corner(run.BoostFill, 9)
	run.BoostHint = Kit.Text(bm, "", { Size = UDim2.new(1, -60, 0, 12), Position = UDim2.new(0, 56, 1, -8), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, Color = C.BlueHi, ZIndex = 6, Shadow = 2, Stroke = 2, Pixel = true, MaxSize = 11 })
	run.BoostMeter = bm
	run.DartBtn = Kit.Button(root, { Name = "DartBtn", Text = "DART", Icon = "Dart", Color = "Orange", Stack = true, IconSize = 0.7, Round = true, Size = UDim2.fromOffset(112, 112), Position = UDim2.new(1, -16, 1, -80), AnchorPoint = Vector2.new(1, 1), OnClick = function() if HUD.OnFire then HUD.OnFire() end end })
	run.BoostBtn = Kit.Button(root, { Name = "BoostBtn", Text = "BOOST", Icon = "Bolt", Color = "Blue", Stack = true, IconSize = 0.7, Round = true, Size = UDim2.fromOffset(112, 112), Position = UDim2.new(1, -138, 1, -80), AnchorPoint = Vector2.new(1, 1) })
	run.BrakeBtn = Kit.Button(root, { Name = "BrakeBtn", Text = "BRAKE", Color = "Red", Round = true, Size = UDim2.fromOffset(110, 62), Position = UDim2.new(1, -260, 1, -86), AnchorPoint = Vector2.new(1, 1) })
	-- touch: hold LOOK to see what's behind you
	run.LookBtn = Kit.Button(root, { Name = "LookBtn", Text = "LOOK", Icon = "Eye", Color = "Slate", Stack = true, IconSize = 0.6, Round = true, Size = UDim2.fromOffset(84, 84), Position = UDim2.new(1, -260, 1, -160), AnchorPoint = Vector2.new(1, 1) })
	for _, pair in ipairs({ { run.BoostBtn, Drive.SetBoostHeld }, { run.BrakeBtn, Drive.SetBrakeHeld }, { run.LookBtn, Drive.SetLookBack } }) do
		holdButton(pair[1]:FindFirstChild("Hit") :: TextButton, pair[2])
	end
	run.DartKey = Kit.Text(run.DartBtn, "F", { Size = UDim2.fromOffset(22, 16), Position = UDim2.new(0, 6, 0, 4), ZIndex = 20, Shadow = 1, Stroke = 2, Color = C.YellowHi })
	run.Vignette = frame(root, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BackgroundColor3 = Color3.fromRGB(200, 20, 20), ZIndex = 1 })
end

local function eggTile(parent: Instance, egg, order: number)
	local r = egg and Config.Rarity[egg.Rarity or "Common"]
	local holder = frame(parent, { Size = UDim2.fromOffset(62, 62), LayoutOrder = order, BackgroundTransparency = egg and 0 or 0.35, BackgroundColor3 = r and r.Color or C.Forest })
	Kit.Corner(holder, 12)
	Kit.Stroke(holder, C.Ink, 3.5)
	if r then Kit.Gradient(holder, Kit.Shade(r.Color, 1.25), Kit.Shade(r.Color, 0.8)) end
	local inner = frame(holder, { Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3) })
	Kit.Corner(inner, 9)
	Kit.Stroke(inner, Color3.new(1, 1, 1), 2).Transparency = 0.4
	if egg then
		Kit.Icon(holder, "Egg", { Species = egg.Species, Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 7 })
		Kit.Text(holder, Config.FormatKG(egg.KG or 0), { Pixel = true, Size = UDim2.new(1, 4, 0, 9), Position = UDim2.new(0.5, 0, 1, 6), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9, Stroke = 2, Shadow = 1, MaxSize = 9 })
	else
		Kit.Glyph(holder, "Plus", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.Muted })
	end
	return holder
end

local runCfg: Configuration? = nil
local lastHP, lastEggsKey = nil, nil
-- TikTok recordings stage the run HUD with chosen numbers: HUD.Puppet = { HP, MaxHP, Eggs (json), Slots, Coins,
-- Darts, MaxDarts, State = { Route, Variant, S, Length, Zone, Boost } }. nil = the real run (the normal case)
HUD.Puppet = nil :: any
local function runAttr(key: string, default: any): any
	local P = HUD.Puppet
	if P then
		local v = P[key]
		if v == nil then return default end
		return v
	end
	local v = runCfg and runCfg:GetAttribute(key)
	if v == nil then return default end
	return v
end
local function readRun()
	runCfg = Runtime.Runs:FindFirstChild(tostring(player.UserId)) :: Configuration?
	if not runCfg and not HUD.Puppet then return end
	local hp, max = runAttr("HP", 0), runAttr("MaxHP", 1)
	if hp ~= lastHP then
		local f = hp / max
		run.SetHP(f, f <= 0.3 and C.Red or (f <= 0.6 and C.Orange or C.Lime))
		if lastHP and hp < lastHP then Kit.Shake(run.HPPanel) end
		lastHP = hp
	end
	local eggsJson = runAttr("Eggs", "[]")
	local slots = runAttr("Slots", 2)
	local key = eggsJson .. slots
	if key ~= lastEggsKey then
		local grew = lastEggsKey ~= nil
		lastEggsKey = key
		local ok, eggs = pcall(HttpService.JSONDecode, HttpService, eggsJson)
		eggs = ok and eggs or {}
		run.EggN = #eggs
		for _, c in ipairs(run.EggHolder:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		for i = 1, math.max(slots, #eggs) do
			local t = eggTile(run.EggHolder, eggs[i], i)
			if eggs[i] and grew then Kit.Pop(t, 1.4) end
		end
		run.EggPanel.Size = UDim2.fromOffset(math.max(120, slots * 70), 78)
	end
	Kit.SetText(run.CoinPill:FindFirstChild("Amount") :: Instance, Config.FormatNumber(runAttr("Coins", 0)))
	Kit.SetText(run.DartPill:FindFirstChild("Amount") :: Instance, string.format("%d/%d", runAttr("Darts", 0), runAttr("MaxDarts", 0)))
end

local warnUntil = { [-1] = 0, [1] = 0 }
local lastSection = nil

local function stepRun()
	if mode ~= "Run" then return end
	readRun()
	local P = HUD.Puppet
	local phase = P and "Driving" or (runCfg and runCfg:GetAttribute("Phase"))
	local driving = phase == "Driving" or phase == "Extracting" or phase == "Wrecked"
	-- out roaming with eggs aboard (a chase you shook off, 2026-10-14): the rack and the armour stay up - what the next
	-- chase puts at risk, and a full rack shows itself (every slot filled, no empty one left). Nothing else of the chase
	local roaming = not P and not driving and phase == "Map" and (run.EggN or 0) > 0 and not Cinema.Playing()
	run.Root.Visible = not HUD.Hidden and ((driving and (P ~= nil or not Drive.State.OnFoot)) or roaming)
	if not run.Root.Visible then return end
	local chaseOnly = { run.ProgressPanel, run.DartPill, run.CoinPill, run.BoostMeter, run.DartBtn }
	if roaming then
		for _, g in ipairs(chaseOnly) do g.Visible = false end
		for _, g in ipairs({ run.Goal, run.Fork, run.Boss, run.BoostBtn, run.BrakeBtn, run.LookBtn, run.Warn[-1], run.Warn[1] }) do g.Visible = false end
		return
	end
	for _, g in ipairs(chaseOnly) do g.Visible = true end
	local st = P and P.State or Drive.State
	local r = st.Route
	if not r then return end
	local u = math.clamp(st.S / math.max(1, st.Length), 0, 1)
	local left = math.max(0, st.Length - st.S)
	Kit.SetText(run.Goal, string.format("ESCAPE TO THE TIME PORTAL  -  %dm", math.floor(left)))
	run.Goal.Visible = not st.StopAt
	run.Fill.Size = UDim2.fromScale(u, 1)
	run.CarIcon.Position = UDim2.fromScale(u, 0.5)
	local current = nil
	for _, sec in ipairs(r.Data.Sections or {}) do
		local s = sec.S[st.Variant]
		if s and s >= 0 and st.S >= s and (not current or s >= current.S) then current = { Name = sec.Name, S = s } end
	end
	-- area names stay off the middle of the screen on the run: the goal bar is the one thing to read
	if current and current.Name ~= lastSection then lastSection = current.Name end
	local fi = (not P) and Drive.ForkInfo() or nil
	if fi and fi.S and fi.S - st.S < 110 and fi.S - st.S > -2 and not st.StopAt then
		if not run.Fork.Visible then Kit.Pop(run.Fork, 0.5) end
		run.Fork.Visible = true
		Kit.SetText(run.ForkL, fi.Labels[1])
		Kit.SetText(run.ForkR, fi.Labels[2])
		Kit.SetTextColor(run.ForkL, fi.Choice == 1 and C.YellowHi or C.Muted)
		Kit.SetTextColor(run.ForkR, fi.Choice == 2 and C.YellowHi or C.Muted)
	else
		run.Fork.Visible = false
	end
	local now = os.clock()
	for side, w in pairs(run.Warn) do
		local on = now < warnUntil[side]
		w.Visible = on and (math.floor(now * 10) % 2 == 0 or warnUntil[side] - now > 0.35)
	end
	run.BoostFill.Size = UDim2.fromScale(math.clamp(st.Boost, 0, 1), 1)
	run.BoostFill.BackgroundColor3 = st.Boosting and C.White or C.BlueHi
	local touch = isTouch()
	run.BoostBtn.Visible = touch
	run.BrakeBtn.Visible = touch
	run.LookBtn.Visible = touch
	run.DartKey.Visible = not touch
	Kit.SetText(run.DartKey, Kit.Gamepad() and "Y" or "F")
	Kit.SetText(run.BoostHint, Kit.Gamepad() and "HOLD RT" or (touch and "" or "HOLD SHIFT / W"))
	-- the ruler's calm, shared by every rover chasing her
	local boss = nil
	for _, f in ipairs(P and {} or Runtime.Sites:GetChildren()) do
		if f:GetAttribute("Boss") and f:GetAttribute("Phase") == 2 and f:GetAttribute("Era") == (st.Zone or "") then boss = f end
	end
	if boss then
		if not run.Boss.Visible then Kit.Enter(run.Boss) end
		run.Boss.Visible = true
		Kit.SetText(run.BossName, boss:GetAttribute("Name") or "THE BOSS")
		local calm, max = boss:GetAttribute("Calm") or 0, math.max(1, boss:GetAttribute("CalmMax") or 1)
		run.SetCalm(calm / max, C.RedHi)
	else
		run.Boss.Visible = false
	end
end

--------------------------------------------------------------------------------
-- run summary card
--------------------------------------------------------------------------------
local function summary(title: string, color: string, lines, eggs: { any }?)
	local card = Kit.Window(canvas, { Fit = true, Name = "Summary", Title = title, Color = color, Icon = color == "Red" and "Alert" or "Trophy", Size = UDim2.fromOffset(540, 380), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 40 })
	local cc = card:FindFirstChild("Inner", true) :: Frame
	local rows = {}
	for i, l in ipairs(lines) do
		local row, rc = Kit.Card(cc, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, (i - 1) * 46), ZIndex = 44 })
		Kit.Text(rc, l[1], { Pixel = true, Size = UDim2.new(0.55, 0, 0, 11), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, ZIndex = 47, Stroke = 2, Shadow = 1, Color = C.Muted, MaxSize = 11 })
		Kit.Text(rc, l[2], { Size = UDim2.new(0.4, 0, 0, 22), Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Right, ZIndex = 47, Stroke = 3, Shadow = 2, Color = C.Cream, MaxSize = 24 })
		table.insert(rows, row)
	end
	if eggs and #eggs > 0 then
		local row = frame(cc, { Size = UDim2.new(1, 0, 0, 74), Position = UDim2.new(0, 0, 0, #lines * 46 + 4), ZIndex = 44 })
		local lay = Instance.new("UIListLayout")
		lay.FillDirection = Enum.FillDirection.Horizontal
		lay.Padding = UDim.new(0, 8)
		lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
		lay.Parent = row
		for i, e in ipairs(eggs) do
			if typeof(e) == "table" then table.insert(rows, eggTile(row, e, i)) end
		end
	end
	local ok, okHit = Kit.Button(cc, { Text = "AWESOME!", Color = "Lime", Size = UDim2.fromOffset(220, 56), Position = UDim2.new(0.5, 0, 1, 4), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 46, Shine = true, Radius = 18, OnClick = function() Kit.Exit(card, true) end })
	Kit.Enter(card)
	Kit.Stagger(rows, 0.08, 0.2)
	Kit.Pop(ok, 0.3, 0.5)
	if Kit.Gamepad() then game:GetService("GuiService").SelectedObject = okHit end
	task.delay(10, function() if card.Parent then Kit.Exit(card, true) end end)
end

--------------------------------------------------------------------------------
-- public
--------------------------------------------------------------------------------
-- a big centre callout (icon + outlined title + subtitle)
function HUD.Banner(title: string, sub: string?, icon: string?, color: Color3?)
	if banner then banner.Show(title, sub, icon, color, 2.6) end
end

-- flash the side warning (a chaser lining up a lunge on that side: -1 left, 1 right)
function HUD.Warn(side: number, seconds: number?)
	warnUntil[side] = os.clock() + (seconds or 0.9)
end

function HUD.PrepareRun()
	lastHP, lastEggsKey, lastSection = nil, nil, nil
end

function HUD.ShowRun(info)
	mode = "Run"
	HUD.CurrentTarget = nil -- (camp's last objective: Onboarding's trail must not chase it round the era)
	camp.Root.Visible = false
	setWaypoint(nil)
	local vname = Drive.State.Vehicle and Config.Vehicles[Drive.State.Vehicle:GetAttribute("VehicleName")]
	Kit.SetText(run.VName, (info and info.VehicleName) or (vname and vname.Name) or "ROVER")
	for _, c in ipairs(run.Track:GetChildren()) do if c.Name == "Pip" then c:Destroy() end end
	local r = info and info.Zone and RouteMath.get(info.Zone)
	if r then
		local L = r:Length(1)
		for _, n in ipairs(r.Data.Nests or {}) do
			local s = n.S[1] >= 0 and n.S[1] or (n.S[4] or 0)
			local pip = Kit.Icon(run.Track, "Egg", { Species = n.Species, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(s / L, 0, 0, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 8 })
			pip.Name = "Pip"
		end
	end
end

-- riding along in someone else's rover: neither camp's screen (your coins and power showed through a boss fight,
-- 2026-10-13) nor a driver's (it's not your armour or rack). The fight's own HUD still comes and goes on its own
function HUD.ShowRide()
	mode = "Ride"
	HUD.CurrentTarget = nil
	camp.Root.Visible = false
	run.Root.Visible = false
	setWaypoint(nil)
end

function HUD.ShowCamp()
	mode = "Camp"
	run.Root.Visible = false
	camp.Root.Visible = true
	camp.LastObj = nil
	Kit.Stagger({ camp.Tabs.SHOP, camp.Tabs.HOME, camp.Tabs.ERAS, camp.Drive, camp.MyRovers, camp.CoinPill, camp.Settings, camp.Index, camp.Hotbar }, 0.05, 0.4)
end

function HUD.OnHit(info)
	run.Vignette.BackgroundTransparency = 0.6
	TweenService:Create(run.Vignette, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	if info.Lost then
		local r = Config.Rarity[info.LostRarity or "Common"]
		Kit.Toast("A " .. (r and r.Name or "") .. " EGG FELL OFF THE RACK!", "Red", "Egg")
	elseif info.Kind == "Lunge" or info.Kind == "Charge" or info.Kind == "Stampede" then
		Kit.Toast("OUCH! -" .. info.Damage .. " ARMOR", "Red", "Shield")
	end
end

function HUD.OnPickup(info)
	if info.Kind == "Coin" then Kit.Punch(run.CoinPill, 0.18)
	elseif info.Kind == "Boost" then Kit.Punch(run.BoostMeter, 0.2) Kit.Toast("BOOST +", "Blue", "Bolt")
	elseif info.Kind == "Repair" then Kit.Punch(run.HPPanel, 0.15) Kit.Toast("REPAIRED +" .. Config.Expedition.RepairPickup, "Green", "Wrench")
	elseif info.Kind == "Darts" then Kit.Punch(run.DartPill, 0.2) Kit.Toast("TRANQ DARTS +" .. Config.Expedition.DartPickup, "Orange", "Dart") end
end

function HUD.OnEgg(_info) end

function HUD.OnWrecked(info)
	HUD.Banner("WRECKED!", "THE EGGS ARE GONE - YOU KEEP YOUR COINS", "Alert", C.Red)
	task.delay(0.8, function()
		summary("WRECKED!", "Red", { { "EGGS LOST", tostring(#(info.Lost or {})) }, { "COINS KEPT", Config.FormatNumber(info.Coins or 0) } }, info.Lost)
	end)
end

function HUD.OnFainted(info)
	task.delay(0.3, function()
		summary("KNOCKED OUT", "Red", { { "EGGS LOST", tostring(#(info.Lost or {})) }, { "COINS KEPT", Config.FormatNumber(info.Coins or 0) } }, info.Lost)
	end)
end

function HUD.OnExtracted(info)
	-- the ESCAPED! beat (EraView) carries the moment; the summary waits until you've landed at camp
	local shown = false
	local function show()
		if shown then return end
		shown = true
		HUD.FlushSummary = nil
		summary("EXPEDITION COMPLETE!", "Yellow", {
			{ "EGGS BANKED", tostring(#info.Eggs) },
			{ "COINS", "+" .. Config.FormatNumber(info.Coins) },
			{ "TIME", Config.FormatTime(info.Time) },
		}, info.Eggs)
	end
	HUD.FlushSummary = show
	task.delay(12, show) -- safety: never lose the summary if the warp is skipped oddly
end

function HUD.SetHidden(on: boolean)
	HUD.Hidden = on
	if on then setWaypoint(nil) end
end

function HUD.ObjectiveText(): string
	return mode == "Camp" and (camp.LastObj or "") or ""
end

-- the onboarding coach points at these
function HUD.PanelOpen(): boolean
	return Panels ~= nil and Panels.IsOpen()
end

function HUD.CoachTarget(name: string): GuiObject?
	if mode ~= "Camp" or not camp.Root or not camp.Root.Visible then return nil end
	if name == "Drive" then return camp.Drive.Visible and camp.Drive or nil end
	if name == "Boost" then return camp.Boost.Visible and camp.Boost or nil end
	if name == "Slot1" then return camp.Slots[1] and camp.Slots[1].Id and camp.Slots[1].Frame or nil end
	return nil
end

function HUD.CoinTarget(): GuiObject?
	return camp.CoinPill
end

--------------------------------------------------------------------------------
function HUD.Start(panels)
	Panels = panels
	local _
	_, canvas = Kit.Screen("DinoHUD", 10, false, 0.6)
	buildCamp()
	buildRun()
	banner = Kit.Banner(canvas, { Position = UDim2.new(0.5, 0, 0, 170), ZIndex = 30 })
	Net.On("Profile", refreshCamp)
	if Net.Profile then refreshCamp() end
	player:GetAttributeChangedSignal("HeldEgg"):Connect(refreshHotbar)
	player:GetAttributeChangedSignal("HeldDino"):Connect(refreshHotbar)
	Net.On("Toast", function(info) Kit.Toast(info.Text, info.Color or "Green") end)
	-- server news (hatches, bosses knocked out elsewhere, eras opened): never over a fight or a chase
	Net.On("Announce", function(info)
		if player:GetAttribute("Site") or (Drive.State.Mode == "Route" and not Drive.State.Frozen and not Drive.State.OnFoot) then return end
		Kit.Toast(info.Text, info.Color or "Orange", "Star")
	end)
	Net.On("Collected", function(info)
		Kit.Toast("+" .. Config.FormatNumber(info.Amount) .. " COINS", "Gold", "Coin")
		local cam = Workspace.CurrentCamera
		if cam then Kit.FlyCoins(cam.ViewportSize / 2 + Vector2.new(0, 60), camp.CoinPill, 10) end
	end)
	Net.On("EggReady", function(info)
		local r = Config.Rarity[info.Rarity or "Common"]
		Kit.Toast("YOUR " .. (r and r.Name or "") .. " EGG IS READY TO HATCH!", "Green", "Egg")
		refreshCamp()
	end)
	Net.On("QuestDone", function(info)
		Kit.Toast("QUEST DONE: " .. (info.Title or "") .. " - TALK TO " .. (NPC_NAME[info.Npc] or ""), "Gold", "Star")
	end)
	Net.On("Warning", function(info)
		local side = info.Side or 1
		warnUntil[side] = os.clock() + (info.Time or 0.8) + 0.3
		Drive.Kick(0.25)
	end)
	Net.On("Dodged", function() Kit.Toast("DODGED!", "Teal", "Star") end)
	Net.On("Tired", function() Kit.Toast("IT GAVE UP THE CHASE!", "Green", "Dino") end)
	-- a prompt on screen that uses gamepad Y (the Ride Shop, the boss SUMMON / JOIN): Y is its, not the Bag's
	-- prompts on screen right now (a set, not a counter: one that changed its key or was destroyed while shown
	-- used to leave the count stuck above 0, and Y stopped opening the Bag for the rest of the session)
	local shownPrompts = {} :: { [ProximityPrompt]: boolean }
	local PPS = game:GetService("ProximityPromptService")
	PPS.PromptShown:Connect(function(pr) shownPrompts[pr] = true end)
	PPS.PromptHidden:Connect(function(pr) shownPrompts[pr] = nil end)
	local function yPromptShown(): boolean
		for pr in pairs(shownPrompts) do
			if not pr.Parent or not pr.Enabled then shownPrompts[pr] = nil
			elseif pr.GamepadKeyCode == Enum.KeyCode.ButtonY then return true end
		end
		return false
	end
	-- hotbar keys (camp only): 1-6 carry an egg, B / Y opens the bag
	ContextActionService:BindActionAtPriority("DinoHotbar", function(_, st, input)
		if st ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if mode ~= "Camp" or Drive.State.Mode ~= "None" or player:GetAttribute("Site") or Cinema.Playing() then return Enum.ContextActionResult.Pass end
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		local kc = input.KeyCode
		if kc == Enum.KeyCode.ButtonY and yPromptShown() then return Enum.ContextActionResult.Pass end
		if kc == Enum.KeyCode.B or kc == Enum.KeyCode.ButtonY then Panels.Open("Bag") return Enum.ContextActionResult.Sink end
		local nums = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
		local i = table.find(nums, kc)
		if i and camp.Slots[i] and camp.Slots[i].Id then
			useSlot(camp.Slots[i])
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 2100, Enum.KeyCode.B, Enum.KeyCode.ButtonY, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six)
	-- V / gamepad D-pad right toggle the rover at camp (X stays free for prompts): get it out, or hop out
	-- (2026-10-12: gamepad had no button for it at all - exiting at camp is an onboarding step)
	ContextActionService:BindActionAtPriority("DinoDriveToggle", function(_, st)
		if st ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if mode ~= "Camp" or player:GetAttribute("Site") or Cinema.Playing() or Panels.IsOpen() then return Enum.ContextActionResult.Pass end
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if Drive.State.Mode == "Camp" then
			task.spawn(function() Net.Ask("ExitVehicle") end)
		elseif Drive.State.Mode == "None" then
			if HUD.OnDrive then HUD.OnDrive() end
		else
			return Enum.ContextActionResult.Pass
		end
		return Enum.ContextActionResult.Sink
	end, false, 2100, Enum.KeyCode.V, Enum.KeyCode.DPadRight)
	RunService.RenderStepped:Connect(function()
		stepCamp()
		stepRun()
	end)
	HUD.ShowCamp()
end

return HUD
