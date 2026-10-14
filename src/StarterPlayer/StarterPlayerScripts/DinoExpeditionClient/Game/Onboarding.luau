--[[
	Onboarding — show, don't tell. No dialogue boxes.

	  first join   a short flyover of camp under the logo, landing on you
	  guide        a glowing chevron trail on the ground leads to the next thing to do, and that thing
	               glows (garage → Time Gate → incubators → cash pad → ...). Shown while you're new.
	  on the road  animated key glyphs appear exactly when you need them: steer + boost at the start,
	               brake when a nest is near, DART when a lunge is coming; holo-arrows mark each fork.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.UI.Kit)
local Cinema = require(script.Parent.UI.Cinema)
local Theme = require(script.Parent.UI.Theme)
local Net = require(script.Parent.Net)
local Drive = require(script.Parent.Drive)
local EraView = require(script.Parent.EraView)
local Prologue = require(script.Parent.Prologue)

local player = Players.LocalPlayer
local C = Theme.C
local Onboarding = {}
local HUD
local canvas
local playing = false
local CAMP = Vector3.new(600, 0, 0)

local function hintsOn(): boolean
	local p = Net.Profile
	return not (p and p.Settings and p.Settings.Hints == false)
end

-- new players get the full guide; veterans just the HUD waypoint
local function isNew(): boolean
	local p = Net.Profile
	if not p then return true end
	return (p.Stats and p.Stats.Runs or 0) < 2 or #(p.Dinos or {}) == 0
end

--------------------------------------------------------------------------------
-- world guide: chevron trail + target glow
--------------------------------------------------------------------------------
local trailFolder: Folder? = nil
local trail = {} :: { BasePart }
local chevrons = {} :: { { M: Model, P: Vector3, Parts: { BasePart } } } -- front (nearest you) first
local trailKey = nil
local glow: Highlight? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function groundY(p: Vector3): number
	local hit = Workspace:Raycast(Vector3.new(p.X, 60, p.Z), Vector3.new(0, -120, 0), rayParams)
	return hit and hit.Position.Y or p.Y
end

local function ringPoint(angle: number, r: number): Vector3
	return CAMP + Vector3.new(math.sin(angle) * r, 0, -math.cos(angle) * r)
end
local function angleOf(p: Vector3): number
	local d = p - CAMP
	return math.atan2(d.X, -d.Z)
end

-- (2026-10-12, Base Camp Islands) where a point is in camp: on the hub, on a bridge, or out on an island. A bridge
-- point leads to that bridge's hub end; an island point to its island end, then its hub end.
local ISLAND_FRONT = 268 -- hub centre -> the islands' front shore (tools/gen/islandLayout.js RF 280, a bit inside)
local function flatOf(p: Vector3): Vector3 return Vector3.new(p.X - CAMP.X, 0, p.Z - CAMP.Z) end
local function placeOf(p: Vector3): (string, Vector3?, Vector3?)
	local d = flatOf(p)
	if d.Magnitude < 1 then return "Hub", nil, nil end
	local camp = Workspace:FindFirstChild("BaseCamp")
	local folder = camp and camp:FindFirstChild("Bridges")
	if not folder then return "Hub", nil, nil end
	-- the bridge that lines up best with the point
	local bestDot, ie, he = -2, nil, nil
	for _, b in ipairs(folder:GetChildren()) do
		local i = b:FindFirstChild("BridgeIslandEnd", true) :: BasePart?
		local h = b:FindFirstChild("BridgeHubEnd", true) :: BasePart?
		if i and h then
			local dot = d.Unit:Dot(flatOf(i.Position).Unit)
			if dot > bestDot then bestDot, ie, he = dot, i, h end
		end
	end
	if not (ie and he) then return "Hub", nil, nil end
	local axis = flatOf(ie.Position)
	local u = axis.Unit
	local along = d:Dot(u)
	local lateral = (d - u * along).Magnitude
	if lateral < 14 and along > 100 and along < axis.Magnitude - 2 then return "Bridge", nil, he.Position end
	if d.Magnitude > ISLAND_FRONT then return "Island", ie.Position, he.Position end
	return "Hub", nil, nil
end

-- the ring road from angle a0 to a1
local function ringArc(pts: { Vector3 }, a0: number, a1: number)
	local R = 94
	table.insert(pts, ringPoint(a0, R))
	local da = math.atan2(math.sin(a1 - a0), math.cos(a1 - a0))
	local n = math.max(1, math.floor(math.abs(da) * R / 18))
	for i = 1, n do table.insert(pts, ringPoint(a0 + da * i / n, R)) end
end

-- a path between two points in camp: over your bridge when an end is out there, straight down the walkway that
-- lines up with a bridge for the plaza, round the ring road otherwise, up the gate approach for the Time Gate
local function campPath(from: Vector3, to: Vector3, toGate: boolean): { Vector3 }
	local pts = { from }
	local fk, fi, fh = placeOf(from)
	local tk, ti, th = "Hub", nil, nil
	if not toGate then tk, ti, th = placeOf(to) end
	-- both ends on the same bridge / island: straight there (by the island end when one is still on the bridge)
	if fh and th and (fh - th).Magnitude < 1 then
		if fk ~= tk and (fi or ti) then table.insert(pts, (fi or ti) :: Vector3) end
		table.insert(pts, to)
		return pts
	end
	local a = from
	if fh then
		if fi then table.insert(pts, fi) end
		table.insert(pts, fh)
		a = fh
	end
	local b = th or to
	local da, db = flatOf(a), flatOf(b)
	if toGate then
		-- already on the gate road / ramp: straight up it
		local onApproach = da.Z < -80 and math.abs(da.X) < 40
		if not onApproach then ringArc(pts, angleOf(a), 0) end
		if da.Z > -120 then table.insert(pts, CAMP + Vector3.new(0, 0, -120)) end
	elseif db.Magnitude < 60 and da.Magnitude >= 60 then
		-- into the plaza: down the walkway that lines up with where you came from
		local ang = angleOf(a)
		table.insert(pts, ringPoint(ang, 90))
		table.insert(pts, ringPoint(ang, 52))
	elseif da.Magnitude < 60 and db.Magnitude >= 60 then
		-- out of the plaza toward a bridge: its walkway
		local ang = angleOf(b)
		table.insert(pts, ringPoint(ang, 52))
		table.insert(pts, ringPoint(ang, 90))
	elseif (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude > 70 then
		ringArc(pts, angleOf(a), angleOf(b))
	end
	if th then
		table.insert(pts, th)
		if ti then table.insert(pts, ti) end
	end
	table.insert(pts, to)
	return pts
end

local function clearTrail()
	if trailFolder then trailFolder:Destroy() end
	trailFolder = nil
	table.clear(trail)
	table.clear(chevrons)
	trailKey = nil
end

local function chevron(cf: CFrame, parent: Instance)
	local m = Instance.new("Model")
	local parts = {}
	for _, side in ipairs({ -1, 1 }) do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = C.YellowHi
		p.Size = Vector3.new(0.6, 0.12, 2.4)
		p.CFrame = cf * CFrame.new(side * 0.75, 0, 0) * CFrame.Angles(0, side * math.rad(40), 0) -- tips meet in front (-Z): points along the path
		p.Parent = m
		table.insert(trail, p)
		table.insert(parts, p)
	end
	m.Parent = parent
	table.insert(chevrons, { M = m, P = cf.Position, Parts = parts })
end

local function buildTrail(pts: { Vector3 })
	clearTrail()
	local folder = Instance.new("Folder")
	folder.Name = "DinoGuideTrail"
	folder.Parent = Workspace
	trailFolder = folder
	-- (one filter for the whole build: it used to allocate a new table per chevron)
	rayParams.FilterDescendantsInstances = { player.Character, Workspace:FindFirstChild("ActiveVehicles"), folder }
	local acc = 3
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local L = d.Magnitude
		if L < 0.1 then continue end
		local dir = d.Unit
		while acc < L do
			local p = a + dir * acc
			local y = groundY(p) + 0.18
			chevron(CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) + dir), folder)
			acc += 6
		end
		acc -= L
	end
end

local function setGlow(model: Instance?)
	if glow and glow.Adornee == model then return end
	if glow then glow:Destroy() glow = nil end
	if not model then return end
	local h = Instance.new("Highlight")
	h.Name = "DinoGuideGlow"
	h.Adornee = model
	h.FillColor = C.YellowHi
	h.OutlineColor = C.Yellow
	h.FillTransparency = 0.85
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = player:WaitForChild("PlayerGui")
	glow = h
end

-- the model a target part belongs to (glow the whole building, not one block)
local GLOW_GROUPS = { Garage = true, Paddock = true, MotorPool = true, Frame = true, HologramEgg = true, DailyChest = true, CashPadGroup = true }
local function glowModel(part: BasePart): Instance
	-- an NPC spot glows the character standing on it; a nest glows the whole nest
	local npc = part:FindFirstChild("Npc")
	if npc then return npc end
	local nest = part:FindFirstAncestorWhichIsA("Model")
	if nest and nest.Name:match("^Nest%d+$") then return nest end
	-- your power trainer's pad / board (TrainerView, 2026-10-14): glow the whole machine ("Trainer1".."TrainerN")
	if part.Name == "TrainerPad" or part.Name == "TrainerBoard" or part:FindFirstAncestor("TrainerBoard") then
		local node: Instance? = part
		while node and node.Parent do
			if node:IsA("Model") and node.Name:match("^Trainer%d+$") then return node end
			node = node.Parent
		end
		return part
	end
	local node: Instance? = part
	while node and node.Parent do
		if GLOW_GROUPS[node.Name] then return node end
		node = node.Parent
	end
	return part
end

-- the guide runs until onboarding is over: your first arrival in Giant Plains (after the first boss)
local function guiding(): boolean
	if isNew() then return true end
	local p = Net.Profile
	local tips = p and p.Flags and p.Flags.Tips
	return not (tips and tips.Est_GiantPlains)
end

local function stepGuide()
	local target = HUD and HUD.CurrentTarget
	-- (not during cutscenes: the garage roll-out used to get a trail through its wall)
	local show = target and hintsOn() and guiding() and Drive.State.Mode ~= "Route" and Drive.State.Mode ~= "Roam" and not HUD.Hidden and not Cinema.Playing()
		and not player:GetAttribute("Site") and not player:GetAttribute("RidingWith") -- (never in a fight or out on a ride)
	if not show then clearTrail() setGlow(nil) return end
	local char = player.Character
	local from = (Drive.State.Root and Drive.State.Root.Position) or (char and char:FindFirstChild("HumanoidRootPart") and (char.HumanoidRootPart :: BasePart).Position)
	if not from then return end
	local toGate = target.Name == "GateTrigger"
	local key = target:GetFullName()
	-- build once per target, then eat the chevrons you've passed; rebuild only if you wander off the trail. (It used to
	-- tear down and rebuild the whole 70-100 chevron trail every ~13 studs: 3x a second while driving)
	local stray = false
	if key == trailKey and trailFolder and #chevrons > 0 then
		local f = Vector3.new(from.X, 0, from.Z)
		local best, bestD = 1, math.huge
		for i = 1, math.min(#chevrons, 40) do
			local c = chevrons[i].P
			local dd = (Vector3.new(c.X, 0, c.Z) - f).Magnitude
			if dd < bestD then best, bestD = i, dd end
		end
		stray = bestD > 22
		if not stray and best > 2 then
			for _ = 1, best - 2 do
				local c = table.remove(chevrons, 1)
				if c then c.M:Destroy() end
			end
			table.clear(trail)
			for _, c in ipairs(chevrons) do for _, p in ipairs(c.Parts) do table.insert(trail, p) end end
		end
	end
	if key ~= trailKey or not trailFolder or stray then
		buildTrail(campPath(from, target.Position, toGate))
		trailKey = key
	end
	setGlow(glowModel(target))
	-- a pulse that runs along the trail toward the goal
	local t = os.clock()
	for i, p in ipairs(trail) do
		local wave = (math.sin(t * 6 - i * 0.35) + 1) / 2
		p.Transparency = 0.15 + (1 - wave) * 0.6
	end
	if glow then glow.FillTransparency = 0.7 + math.sin(t * 4) * 0.15 end
end

--------------------------------------------------------------------------------
-- input glyphs (key caps that pulse on screen when you need them)
--------------------------------------------------------------------------------
local glyphs = {} -- name -> frame

local function keyCap(parent: Instance, label: string, w: number, color: string)
	local outer, content = Kit.Brick(parent, { Size = UDim2.fromOffset(w, 56), Color = color, ZIndex = 60, Lip = 6, Radius = 10 })
	Kit.Text(content, label, { Pixel = true, Size = UDim2.new(1, -12, 0, #label > 2 and 12 or 20), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 64, Stroke = 3, Shadow = 0 })
	return outer
end

-- a row of key caps (keyboard), stick/trigger caps (gamepad) or an arrow at the HUD button (touch)
local function showGlyph(name: string, keys: { { any } }, duration: number, anchor: UDim2?, parent: Instance?)
	if glyphs[name] or not hintsOn() then return end
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = anchor or UDim2.new(0.5, 0, 1, -160)
	row.Size = UDim2.fromOffset(600, 70)
	row.Parent = parent or canvas
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.VerticalAlignment = Enum.VerticalAlignment.Center
	lay.Padding = UDim.new(0, 10)
	lay.Parent = row
	local caps = {}
	for i, k in ipairs(keys) do
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = i
		holder.Size = UDim2.fromOffset(tonumber(k[2]) or 64, 64)
		holder.Parent = row
		if k[1] == "+" or k[1] == "/" then
			Kit.Glyph(holder, k[1] == "+" and "Plus" or "Minus", { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.Cream })
		elseif k[1] == "<" or k[1] == ">" then
			local g = Kit.Glyph(holder, "Chevron", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.YellowHi })
			if k[1] == "<" then g.Rotation = 180 end
		else
			local cap = keyCap(holder, k[1], tonumber(k[2]) or 64, k[3] or "Panel")
			table.insert(caps, cap)
		end
	end
	glyphs[name] = row
	Kit.Stagger(caps, 0.06, 0.3)
	task.spawn(function()
		local t0 = os.clock()
		while row.Parent and os.clock() - t0 < duration do
			for i, cap in ipairs(caps) do
				local body = cap:FindFirstChild("Body") :: Frame?
				if body then
					-- press animation: each key taps in turn, like a demo
					local pressed = math.floor((os.clock() - t0) * 2.5) % #caps == i - 1
					body.Position = pressed and UDim2.fromOffset(0, 5) or UDim2.fromOffset(0, 0)
				end
			end
			task.wait(0.05)
		end
		if row.Parent then Kit.Exit(row, true) end
		task.delay(0.3, function() glyphs[name] = nil end)
	end)
end

local function platform(): string
	if Kit.Gamepad() then return "Pad" end
	if Kit.Platform() == "Touch" then return "Touch" end
	return "Keys"
end

-- a controls card: labelled groups of key caps (keyboard), stick / trigger caps (gamepad) or a ghost
-- thumbstick (touch). It stays until done() says the player has got it (or maxTime passes).
local controls = nil :: any
local function hideControls()
	if controls then
		local c = controls
		controls = nil
		Kit.Exit(c.Root, true)
	end
end

local function capRow(parent: Instance, keys: { { any } }, y: number, z: number): number
	local x = 0
	for _, k in ipairs(keys) do
		local w = tonumber(k[2]) or 58
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(w, 56)
		holder.Position = UDim2.fromOffset(x, y)
		holder.ZIndex = z
		holder.Parent = parent
		keyCap(holder, k[1], w, k[3] or "Panel")
		x += w + 8
	end
	return x - 8
end

-- groups: { { Keys = { {label, width?, color?}, ... }, Top = { ... }?, Label = "DRIVE" }, ... }
local function showControls(groups, done: () -> boolean, maxTime: number, touchStick: string?)
	hideControls()
	if not hintsOn() then return end
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -150)
	root.Size = UDim2.fromOffset(700, 170)
	root.Parent = canvas
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.VerticalAlignment = Enum.VerticalAlignment.Bottom
	lay.Padding = UDim.new(0, 34)
	lay.Parent = root
	local caps = {}
	for i, g in ipairs(groups) do
		local col = Instance.new("Frame")
		col.BackgroundTransparency = 1
		col.LayoutOrder = i
		col.Parent = root
		local h = 0
		local w = 0
		if g.Top then
			-- a key above the row (the W of WASD)
			local rowW = 0
			for _, k in ipairs(g.Keys) do rowW += (tonumber(k[2]) or 58) + 8 end
			rowW -= 8
			local tw = tonumber(g.Top[2]) or 58
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromOffset(tw, 56)
			holder.Position = UDim2.fromOffset((rowW - tw) / 2, 0)
			holder.Parent = col
			table.insert(caps, keyCap(holder, g.Top[1], tw, g.Top[3] or "Panel"))
			h = 64
		end
		local rowW = capRow(col, g.Keys, h, 60)
		for _, c in ipairs(col:GetDescendants()) do if c.Name == "Brick" and not table.find(caps, c) then table.insert(caps, c) end end
		w = math.max(rowW, 120)
		h += 64
		Kit.Text(col, g.Label, { Pixel = true, Size = UDim2.new(1, 20, 0, 14), Position = UDim2.new(0.5, 0, 0, h + 4), AnchorPoint = Vector2.new(0.5, 0), Color = C.YellowHi, Stroke = 2.5, Shadow = 2, MaxSize = 14, ZIndex = 64 })
		col.Size = UDim2.fromOffset(w, h + 22)
	end
	-- touch: a ghost thumbstick on the left with the knob pushing forward
	local stick = nil
	if touchStick then
		stick = Instance.new("Frame")
		stick.BackgroundColor3 = Color3.new(1, 1, 1)
		stick.BackgroundTransparency = 0.75
		stick.Size = UDim2.fromOffset(150, 150)
		stick.AnchorPoint = Vector2.new(0.5, 0.5)
		stick.Position = UDim2.new(0, 170, 1, -170)
		stick.Parent = canvas
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.5, 0)
		cr.Parent = stick
		local st = Instance.new("UIStroke")
		st.Color = C.YellowHi
		st.Thickness = 4
		st.Parent = stick
		local knob = Instance.new("Frame")
		knob.BackgroundColor3 = C.YellowHi
		knob.Size = UDim2.fromOffset(60, 60)
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.Position = UDim2.fromScale(0.5, 0.5)
		knob.Parent = stick
		local kc = Instance.new("UICorner")
		kc.CornerRadius = UDim.new(0.5, 0)
		kc.Parent = knob
		Kit.Stroke(knob, C.Ink, 3)
		Kit.Text(stick, touchStick, { Pixel = true, Size = UDim2.new(1.6, 0, 0, 14), Position = UDim2.new(0.5, 0, 0, -26), AnchorPoint = Vector2.new(0.5, 0), Color = C.YellowHi, Stroke = 2.5, Shadow = 2, MaxSize = 14 })
		task.spawn(function()
			while stick.Parent do
				local t = os.clock() * 1.6
				local up = (math.sin(t) + 1) / 2
				knob.Position = UDim2.new(0.5, math.sin(t * 0.5) * 18, 0.5, -up * 40)
				task.wait()
			end
		end)
	end
	controls = { Root = root, Stick = stick }
	local me = controls
	Kit.Stagger(caps, 0.05, 0.3)
	task.spawn(function()
		local t0 = os.clock()
		while controls == me and os.clock() - t0 < maxTime and not done() do
			-- the caps tap in turn, like a demo
			for i, cap in ipairs(caps) do
				local body = cap:FindFirstChild("Body") :: Frame?
				if body then
					local pressed = math.floor((os.clock() - t0) * 2.5) % #caps == i - 1
					body.Position = pressed and UDim2.fromOffset(0, 5) or UDim2.fromOffset(0, 0)
				end
			end
			task.wait(0.05)
		end
		if controls == me then hideControls() end
		if stick and stick.Parent then stick:Destroy() end
	end)
end

-- behind the wheel at camp: you drive yourself (W / stick / drag), Shift / RT / the button boosts
local function campDriveControls()
	local p = platform()
	local driven = 0
	local last = os.clock()
	local function done(): boolean
		local now = os.clock()
		local dt = now - last
		last = now
		if Drive.State.Mode ~= "Camp" then return true end
		if Drive.State.Speed > 8 then driven += dt end
		return driven > 3
	end
	if p == "Keys" then
		showControls({
			{ Top = { "W" }, Keys = { { "A" }, { "S" }, { "D" } }, Label = "DRIVE + STEER" },
			{ Keys = { { "SHIFT", 130, "Blue" } }, Label = "BOOST" },
		}, done, 25)
	elseif p == "Pad" then
		showControls({
			{ Keys = { { "LEFT STICK", 190 } }, Label = "DRIVE + STEER" },
			{ Keys = { { "RB", 80, "Blue" } }, Label = "BOOST" },
		}, done, 25)
	else
		showControls({}, done, 25, "DRAG HERE TO DRIVE")
	end
end

-- the escape chase: the autopilot drives; you can steer, boost and dart
local function chaseControls()
	local p = platform()
	local t0 = os.clock()
	local function done(): boolean return Drive.State.Mode ~= "Route" or os.clock() - t0 > 8 end
	if p == "Keys" then
		showControls({
			{ Keys = { { "A" }, { "D" } }, Label = "STEER" },
			{ Keys = { { "SHIFT", 130, "Blue" } }, Label = "BOOST" },
			{ Keys = { { "CLICK", 120, "Orange" } }, Label = "DART A DINO" },
		}, done, 9)
	elseif p == "Pad" then
		showControls({
			{ Keys = { { "LEFT STICK", 190 } }, Label = "STEER" },
			{ Keys = { { "RT", 80, "Blue" } }, Label = "BOOST" },
			{ Keys = { { "Y", 64, "Orange" } }, Label = "DART" },
		}, done, 9)
	end
end
local steerGlyph = chaseControls

-- on foot at a site: fire, dodge, sprint (shown the first few times you fight)
local function fightGlyph()
	local p = platform()
	if p == "Keys" then
		showGlyph("Fight", { { "CLICK", 110, "Orange" }, { "/", 30 }, { "F", 64, "Orange" }, { "+", 30 }, { "Q", 64, "Teal" }, { "+", 30 }, { "SHIFT", 120, "Blue" } }, 7, UDim2.new(0.5, 0, 1, -170))
	elseif p == "Pad" then
		showGlyph("Fight", { { "RT", 80, "Orange" }, { "+", 30 }, { "B", 64, "Teal" }, { "+", 30 }, { "L3", 80, "Blue" } }, 7, UDim2.new(0.5, 0, 1, -170))
	end
end

local function dartGlyph()
	local p = platform()
	showGlyph("Dart", p == "Keys" and { { "F", 64, "Orange" } } or (p == "Pad" and { { "Y", 64, "Orange" } } or { { "DART", 120, "Orange" } }), 1.6, UDim2.new(0.5, 0, 0.62, 0))
end

--------------------------------------------------------------------------------
-- holo arrows at a fork (world space, appear as you approach)
--------------------------------------------------------------------------------
local forkArrows: Folder? = nil
local forkShownFor = nil
local function showForkArrows()
	local st = Drive.State
	local fi = Drive.ForkInfo()
	if not (fi and fi.S and st.Route) then
		if forkArrows then forkArrows:Destroy() forkArrows = nil end
		return
	end
	local ahead = fi.S - st.S
	if ahead > 130 or ahead < -4 then
		if forkArrows then forkArrows:Destroy() forkArrows = nil end
		return
	end
	if forkArrows and forkShownFor == fi.Index then
		local t = os.clock()
		for _, p in ipairs(forkArrows:GetChildren()) do
			if p:IsA("BasePart") then p.Transparency = 0.25 + math.sin(t * 8) * 0.15 end
		end
		return
	end
	if forkArrows then forkArrows:Destroy() end
	forkShownFor = fi.Index
	local folder = Instance.new("Folder")
	folder.Name = "DinoForkArrows"
	folder.Parent = Workspace
	forkArrows = folder
	local r = st.Route
	for side = -1, 1, 2 do
		local base = r:Position(st.Variant, fi.S - 14, side * 6.5)
		local _, f = r:Sample(st.Variant, fi.S - 14)
		local dir = (f + Vector3.new(f.Z, 0, -f.X) * -side * 0.7).Unit -- forward and out toward this branch
		for k = 0, 2 do
			local p = base + dir * (k * 3.2) + Vector3.new(0, 0.3, 0)
			for _, s2 in ipairs({ -1, 1 }) do
				local part = Instance.new("Part")
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CastShadow = false
				part.Material = Enum.Material.Neon
				part.Color = side < 0 and C.TealHi or C.YellowHi
				part.Size = Vector3.new(0.8, 0.15, 3)
				part.CFrame = CFrame.lookAt(p, p + dir) * CFrame.new(s2 * 1.0, 0, 0) * CFrame.Angles(0, s2 * math.rad(40), 0)
				part.Parent = folder
			end
		end
	end
end

--------------------------------------------------------------------------------
-- the intro flyover (logo only)
--------------------------------------------------------------------------------
local function find(name: string): BasePart?
	local camp = Workspace:FindFirstChild("BaseCamp")
	local p = camp and camp:FindFirstChild(name, true)
	return p and p:IsA("BasePart") and p or nil
end

function Onboarding.Intro()
	if playing then return end
	playing = true
	local cam = Workspace.CurrentCamera
	local gate, holo = find("GateTrigger"), find("HologramAnchor")
	local idx = player:GetAttribute("Plot")
	local camp = Workspace:FindFirstChild("BaseCamp")
	local plot = camp and idx and camp:FindFirstChild("Plot" .. idx, true)
	local spawnP = plot and plot:FindFirstChild("PlayerSpawn", true) :: BasePart?
	if not (gate and holo and spawnP) then playing = false return end
	local cine = Cinema.Begin("DinoIntro")
	cam.CameraType = Enum.CameraType.Scriptable
	local g2, c2 = Kit.Screen("DinoIntro", 55, true)
	local root = g2:FindFirstChild("Root") :: Frame
	local bars = {}
	for i, anchor in ipairs({ 0, 1 }) do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, anchor)
		f.Position = UDim2.fromScale(0, anchor)
		f.Size = UDim2.fromScale(1, 0.12)
		f.Parent = root
		bars[i] = f
	end
	local fade = Instance.new("Frame")
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.Size = UDim2.fromScale(1, 1)
	fade.ZIndex = 30
	fade.Parent = root
	TweenService:Create(fade, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
	local logo = Kit.Text(c2, "DINO EXPEDITION", { Pixel = true, Size = UDim2.fromOffset(820, 66), Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.YellowHi, Color2 = C.Orange, Shadow = 6, Stroke = 5, ZIndex = 20 })
	logo.Visible = false
	local skipped = false
	local tap = Instance.new("TextButton")
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 40
	tap.Parent = root
	local cutStart = os.clock()
	tap.Activated:Connect(function() if os.clock() - cutStart > 1 then skipped = true end end)
	local center, gp, sp = holo.Position, gate.Position, spawnP.Position
	local back = (sp - center).Unit
	local shots = {
		{ 3.4, gp + Vector3.new(-90, 70, 160), gp + Vector3.new(40, 46, 120), gp + Vector3.new(0, 10, 0), gp + Vector3.new(0, 16, 0), 55 },
		{ 2.8, center + Vector3.new(60, 22, -40), center + Vector3.new(-40, 18, -60), center + Vector3.new(0, 6, 0), center + Vector3.new(0, 8, 0), 60 },
		-- (ends inside your island's name gate, off to one side: 14 studs straight back was inside its sign)
		{ 3.0, sp - back * 40 + Vector3.new(0, 50, 0), sp - back * 8 + back:Cross(Vector3.yAxis) * 9 + Vector3.new(0, 10, 0), sp + Vector3.new(0, 6, 0), sp + Vector3.new(0, 3, 0), 62 },
	}
	for i, s in ipairs(shots) do
		if skipped then break end
		if i == 1 then task.delay(0.9, function() Kit.Pop(logo, 0.4) end) end
		if i == 2 then Kit.PopOut(logo) end
		local t0 = os.clock()
		while os.clock() - t0 < s[1] and not skipped do
			local u = (os.clock() - t0) / s[1]
			local e = u * u * (3 - 2 * u)
			cam.CFrame = CFrame.lookAt(s[2]:Lerp(s[3], e), s[4]:Lerp(s[5], e))
			cam.FieldOfView = s[6]
			RunService.RenderStepped:Wait()
		end
	end
	if logo.Visible then Kit.PopOut(logo) end
	for _, f in ipairs(bars) do TweenService:Create(f, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0) }):Play() end
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	task.delay(0.45, function() g2:Destroy() end)
	Cinema.End(cine)
	Net.Ask("Tutorial", { Step = 1 })
	if Net.Profile and Net.Profile.Flags then Net.Profile.Flags.Tutorial = 1 end
	playing = false
end

-- the cold open (Prologue.luau): a ~37 s cinematic (baked, not playable) that ends with the Tyrant King flipping you
function Onboarding.ColdOpen()
	if playing then return end
	playing = true
	Prologue.Play({ Glyph = showGlyph, Platform = platform })
	-- watched: it won't play again (until a reset wipes the save)
	Net.Ask("Tutorial", { Step = 1, ColdOpen = true })
	if Net.Profile and Net.Profile.Flags then
		Net.Profile.Flags.Tutorial = math.max(Net.Profile.Flags.Tutorial or 0, 1)
		Net.Profile.Flags.ColdOpenSeen = true
	end
	playing = false
end

--------------------------------------------------------------------------------
-- the coach: a big bouncing arrow + a short instruction pointing at exactly what to press
--------------------------------------------------------------------------------
local coach = {} :: any
local function buildCoach()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DinoCoach"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	coach.Gui = gui
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.ZIndex = 5
	ring.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = ring
	local st = Instance.new("UIStroke")
	st.Color = C.YellowHi
	st.Thickness = 5
	st.Parent = ring
	coach.Ring, coach.Stroke = ring, st
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Size = UDim2.fromOffset(300, 110)
	holder.ZIndex = 6
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	coach.Scale = scale
	coach.Arrow = Kit.Glyph(holder, "Chevron", { Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0.5, 0, 1, -28), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.YellowHi, ZIndex = 8 })
	coach.Label = Kit.Text(holder, "", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 0), Color = Color3.new(1, 1, 1), Stroke = 4, Shadow = 3, MaxSize = 34, ZIndex = 9 })
	coach.Holder = holder
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
end

local coachKey = nil
local function stepCoach()
	local p = Net.Profile
	local runs = p and p.Stats and p.Stats.Runs or 0
	local hatched = p and p.Stats and p.Stats.Hatched or 0
	local target: GuiObject? = nil
	local text = ""
	-- never over a cutscene, the cutscene gallery or any open window (the map is the one exception)
	local camType = Workspace.CurrentCamera and Workspace.CurrentCamera.CameraType
	local busy = Cinema.Playing() or (HUD and HUD.PanelOpen and HUD.PanelOpen()) or camType == Enum.CameraType.Scriptable
		or player:GetAttribute("Site") ~= nil or player:GetAttribute("RidingWith") ~= nil
	if hintsOn() and (not busy or EraView.MapOpen()) then
		local mapGo = runs == 0 and EraView.CoachTarget() or nil
		local mapPin = runs == 0 and EraView.CoachPoint() or nil
		local obj = HUD and HUD.ObjectiveText and HUD.ObjectiveText() or ""
		if mapPin then
			-- a world waypoint: point at its spot on screen (viewport -> this gui's space)
			local inset = game:GetService("GuiService"):GetGuiInset()
			coach.Point = mapPin - Vector2.new(0, inset.Y) + Vector2.new(0, 60)
			text = Kit.Platform() == "Touch" and "TAP A SITE!" or "CLICK A SITE!"
		elseif mapGo then
			target, text = mapGo, "PRESS GO!"
		elseif HUD and (obj:sub(1, 11) == "PRESS DRIVE" or obj:sub(1, 5) == "GO ON") and runs < 3 then
			target, text = HUD.CoachTarget("Drive"), Kit.Platform() == "Touch" and "TAP DRIVE!" or (Kit.Gamepad() and "PRESS D-PAD RIGHT!" or "CLICK DRIVE (OR PRESS V)")
		elseif HUD and Kit.Platform() == "Touch" and Drive.State.Mode == "Camp" and runs == 0 and controls ~= nil then
			target, text = HUD.CoachTarget("Boost"), "HOLD TO BOOST"
		elseif HUD and obj:sub(1, 6) == "TAP AN" and hatched < 2 then
			target, text = HUD.CoachTarget("Slot1"), Kit.Platform() == "Touch" and "TAP YOUR EGG!" or "CLICK YOUR EGG (OR PRESS 1)"
		end
	end
	local pos, size
	if coach.Point and text ~= "" and not target then
		size = Vector2.new(96, 96)
		pos = coach.Point - size / 2
	elseif target and target.Visible and target.AbsoluteSize.X > 0 then
		pos, size = target.AbsolutePosition, target.AbsoluteSize
	end
	coach.Point = nil
	if not pos then
		coach.Gui.Enabled = false
		coachKey = nil
		return
	end
	coach.Gui.Enabled = true
	if coachKey ~= text then
		coachKey = text
		Kit.SetText(coach.Label, text)
		Kit.Pop(coach.Holder, 0.6)
	end
	local t = os.clock()
	local pad = 8 + math.sin(t * 6) * 3
	coach.Ring.Position = UDim2.fromOffset(pos.X - pad, pos.Y - pad)
	coach.Ring.Size = UDim2.fromOffset(size.X + pad * 2, size.Y + pad * 2)
	coach.Stroke.Transparency = 0.15 + math.sin(t * 6) * 0.15
	local k = Kit.ScaleFactor(coach.Gui.AbsoluteSize) * 0.85
	coach.Scale.Scale = k
	local bounce = math.abs(math.sin(t * 4)) * 14
	local cam = Workspace.CurrentCamera
	local above = pos.Y > 160
	if above then
		-- arrow above the target pointing down
		coach.Holder.AnchorPoint = Vector2.new(0.5, 1)
		coach.Holder.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y - 10 - bounce)
		coach.Arrow.Rotation = 90
		coach.Arrow.Position = UDim2.new(0.5, 0, 1, -28)
		coach.Label.Position = UDim2.fromOffset(0, 0)
	else
		coach.Holder.AnchorPoint = Vector2.new(0.5, 0)
		coach.Holder.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y + size.Y + 10 + bounce)
		coach.Arrow.Rotation = -90
		coach.Arrow.Position = UDim2.new(0.5, 0, 0, 28)
		coach.Label.Position = UDim2.new(0, 0, 1, -34)
	end
	-- keep the label on screen near the edges
	local vp = cam and cam.ViewportSize or Vector2.new(1000, 600)
	local half = 150 * k
	local cx = pos.X + size.X / 2
	local x = math.clamp(cx, half, vp.X - half)
	coach.Holder.Position = UDim2.fromOffset(x, coach.Holder.Position.Y.Offset)
	-- the label is kept on screen, but the arrow always sits right over the thing it points at
	local ap = coach.Arrow.Position
	coach.Arrow.Position = UDim2.new(0.5, (cx - x) / math.max(k, 0.01), ap.Y.Scale, ap.Y.Offset)
end

--------------------------------------------------------------------------------
function Onboarding.Start(hud)
	HUD = hud
	local _
	_, canvas = Kit.Screen("DinoGlyphs", 40, false, 0.7)
	buildCoach()
	-- first time behind the wheel at camp: show the driving keys
	local campSteerShown = false
	Drive.OnChanged(function(what)
		if what == "Seated" and Drive.State.Mode == "Camp" and not campSteerShown and isNew() then
			campSteerShown = true
			task.delay(1.2, campDriveControls)
		end
	end)
	local started = false
	local function check()
		local p = Net.Profile
		if started or not p or not p.Flags then return end
		started = true
		if Drive.State.Mode == "Route" or Drive.State.Mode == "Roam" then return end
		if p.Flags.ColdOpenSeen ~= true then
			-- a brand-new (or freshly reset) save: the cold open (chased and flipped by the Tyrant King), then camp
			task.wait(1.2)
			Onboarding.ColdOpen()
		elseif (p.Flags.Tutorial or 0) == 0 then
			task.wait(1.2)
			Onboarding.Intro()
		end
	end
	Net.On("Profile", function() task.spawn(check) end)
	if Net.Profile then task.spawn(check) end
	Net.On("ReplayTutorial", function() task.spawn(Onboarding.ColdOpen) end)
	-- cues: the chase (steer / boost), the first lunge (dart), the first fights on foot (fire / dodge / sprint)
	local dartCues, fightCues = 0, 0
	Net.On("ChaseStart", function()
		if isNew() then task.delay(1.5, steerGlyph) end
	end)
	Net.On("Warning", function(info)
		if info.Kind == "Lunge" and dartCues < 3 then
			dartCues += 1
			dartGlyph()
		end
	end)
	-- (2026-10-13: no key glyphs over a fight - the first fight teaches by doing; fightGlyph stays for a calmer moment)
	local _ = fightCues
	local _f = fightGlyph
	RunService.RenderStepped:Connect(function()
		stepGuide()
		stepCoach()
		local st = Drive.State
		if st.Mode == "Route" and not st.OnFoot and not st.Frozen then
			showForkArrows()
		elseif forkArrows then
			forkArrows:Destroy()
			forkArrows = nil
		end
	end)
end

return Onboarding
