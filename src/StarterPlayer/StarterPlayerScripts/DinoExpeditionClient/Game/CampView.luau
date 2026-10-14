--[[
	CampView — makes Base Camp alive on every client:
	  plots    eggs in incubators (wobbling as they get close, glowing when ready), lock covers on slots
	           you haven't bought, your timers, babies roaming their pens, the cash pad counter
	  plaza    the hologram egg (cycles the species you haven't found yet), the Hatch Stage showing the
	           server's latest baby, the Motor Pool turntable showing the next vehicle to save for
	  world    the Time Gate's rings spinning and membrane pulsing, waterfalls flowing, beacons
	           blinking, and a Brachiosaurus walking the ridge behind camp
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Shared = DinoShared:WaitForChild("Game")
local Config = require(Shared:WaitForChild("Config"))
local DinosaurAnimations = require(DinoShared:WaitForChild("DinosaurAnimations"))
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local Kit = require(script.Parent.UI.Kit)
local Net = require(script.Parent.Net)

local player = Players.LocalPlayer
local Camp = {}
Camp.HiddenSlots = {} :: { [number]: boolean } -- slots the hatch cinematic is using
Camp.HiddenBabies = {} :: { [string]: boolean } -- babies the grow cinematic is using
Camp.Openers = {} :: { BasePart } -- other things that open paddock doors as they walk up (a fresh hatchling heading to the yard)
Camp.HoldPenStars = false -- a star pen's reveal scene is on: the new star moves in once the dust settles (Scenes.IslandBuild)

local EggT = DinoShared:WaitForChild("Eggs")
local BabyT = DinoShared:WaitForChild("Babies")
local DinoT = DinoShared:WaitForChild("Dinosaurs")
local VehicleT = DinoShared:WaitForChild("Vehicles")

local folder: Folder
local function lf(): Folder
	if folder and folder.Parent then return folder end
	folder = Instance.new("Folder")
	folder.Name = "DinoCampLocal"
	folder.Parent = Workspace
	return folder
end

local function prep(m: Model, anchored: boolean?)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if anchored ~= nil then d.Anchored = anchored end
		end
	end
	return m
end

local function decode(s: string?): any
	if not s or s == "" then return {} end
	local ok, v = pcall(HttpService.JSONDecode, HttpService, s)
	return ok and v or {}
end

local function serverNow(): number
	return Net.ServerTime()
end

--------------------------------------------------------------------------------
-- plots
--------------------------------------------------------------------------------
local plots = {} -- [Model] = state
local stepBuyNest
local RarityFx = require(script.Parent.RarityFx)

-- where an egg's pivot (its middle) goes so it sits IN the nest bowl, not half under it: bottom on the point,
-- sunk a little so it nestles (eggs scale around their middle, so this has to be measured after scaling)
local function seatOn(e: Model, at: CFrame): CFrame
	local _, size = e:GetBoundingBox()
	return at * CFrame.new(0, size.Y * 0.5 - size.Y * 0.14, 0)
end
Camp.SeatOn = seatOn

local function eggClone(species: string, scale: number): Model?
	local t = EggT:FindFirstChild(species .. "Egg")
	if not t then return nil end
	local e = prep(t:Clone() :: Model, true)
	if scale ~= 1 then e:ScaleTo(scale) end
	return e
end
Camp.EggClone = eggClone

local function nestParts(plot: Model)
	local nests = {}
	for _, n in ipairs(plot:GetDescendants()) do
		if n:IsA("Model") and n:GetAttribute("Slot") and n.Name:match("^Nest%d+$") then
			local slot = n:GetAttribute("Slot")
			nests[slot] = {
				Model = n, Point = n:FindFirstChild("EggPoint", true), Status = n:FindFirstChild("StatusLight", true),
				Cover = n:FindFirstChild("LockCover", true), Prompt = n:FindFirstChild("HatchPrompt", true), Bulb = n:FindFirstChild("LampBulb", true),
			}
		end
	end
	return nests
end

local function setCover(cover: Instance?, shown: boolean)
	if not cover then return end
	for _, p in ipairs(cover:GetDescendants()) do
		if p:IsA("BasePart") then p.Transparency = shown and 0 or 1 end
	end
end

-- a hatched dino roaming your paddock: the full model scaled by its KG (most are small, heavy ones are
-- monsters), dressed in its rarity, with its tag
local function newDino(st, d, penArea: BasePart?)
	local t = DinoT:FindFirstChild(d.Species)
	if not t then return nil end
	local m = prep(t:Clone() :: Model, nil)
	local scale = Config.DinoScale(d)
	m:ScaleTo(scale)
	m:SetAttribute("AnimScale", scale)
	local swimmer = d.Species == "Mosasaurus"
	local root = m.PrimaryPart :: BasePart
	root.Anchored = true
	-- (a star in its star pen roams the pen's PenBounds instead of the paddock)
	local area = penArea or (swimmer and st.YardPond or st.Yard)
	if not area then m:Destroy() return nil end
	local cf0, size = m:GetBoundingBox()
	-- in a star pen the roam box shrinks by half the dino's length, so its nose and tail stay inside the walls
	local half = penArea and math.max(size.X, size.Z) / 2 or 0
	local function randomPoint(): Vector3
		local s = area.Size
		local hx, hz = math.max(0, s.X * 0.425 - half), math.max(0, s.Z * 0.425 - half)
		if not penArea then hx, hz = s.X * 0.425, s.Z * 0.425 end
		local lp = Vector3.new((math.random() * 2 - 1) * hx, 0, (math.random() * 2 - 1) * hz)
		return area.CFrame:PointToWorldSpace(lp)
	end
	local lift = root.Position.Y - (cf0.Position.Y - size.Y / 2)
	local floorY = area.Position.Y - area.Size.Y / 2
	local p = randomPoint()
	root.CFrame = CFrame.new(p.X, floorY + lift, p.Z) * CFrame.Angles(0, math.random() * 6.28, 0)
	m.Parent = lf()
	RarityFx.Apply(m, d.Rarity, math.max(size.X, size.Z))
	RarityFx.Tag(root, d, size.Y * 0.6 + 2.5)
	local anim = DinosaurAnimations.get(m)
	return { Model = m, Root = root, Anim = anim, Id = d.Id, Species = d.Species, KG = d.KG, Name = d.Name, TagY = size.Y * 0.6 + 2.5, Target = nil, Wait = math.random() * 3, Lift = lift, FloorY = floorY, Random = randomPoint, Speed = math.clamp(size.Z * 0.22, 2.4, 7) }
end

local function stepDino(b, dt: number)
	if not b.Root.Parent then return end
	if b.Hold then return end -- PaddockLife is driving it (being petted, following you, chasing a ball)
	if b.Wait > 0 then
		b.Wait -= dt
		if b.Wait <= 0 then
			b.Target = b.Random()
			if b.Anim then b.Anim:SetLocomotion("Walk", 0.3) end
		end
		return
	end
	if not b.Target then return end
	local pos = b.Root.Position
	local to = Vector3.new(b.Target.X, pos.Y, b.Target.Z)
	local d = to - pos
	if d.Magnitude < 0.6 then
		b.Target = nil
		b.Wait = 2 + math.random() * 5
		if b.Anim then
			b.Anim:SetLocomotion("Idle", 0.4)
			if math.random() < 0.45 then
				local picks = { "LookAround", "Roar", "Sniff", "Hop", "Graze", "Browse" }
				for _ = 1, 4 do
					local a = picks[math.random(1, #picks)]
					if b.Anim:HasAction(a) then b.Anim:Play(a) break end
				end
			end
		end
		return
	end
	local dir = d.Unit
	local step = math.min(d.Magnitude, b.Speed * dt)
	local yaw = math.atan2(-dir.X, -dir.Z)
	local _, cy = b.Root.CFrame:ToEulerAnglesYXZ()
	local ny = cy + math.atan2(math.sin(yaw - cy), math.cos(yaw - cy)) * math.min(1, dt * 5)
	b.Root.CFrame = CFrame.new(pos + dir * step) * CFrame.Angles(0, ny, 0)
end

-- trophy statues: the ruler's model in bronze / silver / gold / glowing by the best tier you've beaten
local TIER_LOOK = {
	{ Color3.fromRGB(176, 122, 58), Enum.Material.Metal }, -- Normal: bronze
	{ Color3.fromRGB(205, 210, 220), Enum.Material.Metal }, -- Hard: silver
	{ Color3.fromRGB(255, 205, 64), Enum.Material.Metal }, -- Nightmare: gold
}
local TROPHY_TURN = { TyrantKing = math.pi }
-- gold: the boss's era page is complete in the Index (IndexRewards: plot attribute IndexGold) - polished gold
-- whatever tier it was beaten on, with a sparkle and a gold outline
local function statue(spot: BasePart, bossId: string, tier: number, gold: boolean?): Model?
	local boss = Config.Bosses[bossId]
	local t = boss and DinoT:FindFirstChild(boss.Species)
	if not t then return nil end
	local m = prep(t:Clone() :: Model, true)
	local _, size = m:GetBoundingBox()
	local fit = math.min(5.2 / math.max(size.X, size.Z), 9 / size.Y)
	m:ScaleTo(fit)
	local look = gold and TIER_LOOK[3] or TIER_LOOK[math.clamp(tier, 1, 3)]
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 then
			if tier >= 4 and not gold then
				d.Color = Color3.fromRGB(120, 230, 255):Lerp(d.Color, 0.2)
				d.Material = Enum.Material.Neon
				d.Transparency = 0.15
			else
				d.Color = look[1]:Lerp(d.Color, 0.12)
				d.Material = look[2]
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") then
			d.Enabled = false
		end
	end
	local cf, sz = m:GetBoundingBox()
	local root = m.PrimaryPart :: BasePart
	local lift = root.Position.Y - (cf.Position.Y - sz.Y / 2)
	-- per-statue facing on its plinth (the Tyrant King stands turned the other way round)
	local turn = TROPHY_TURN[bossId] or 0
	m:PivotTo(CFrame.new(spot.Position.X, spot.Position.Y - spot.Size.Y / 2 + lift, spot.Position.Z) * spot.CFrame.Rotation * CFrame.Angles(0, turn, 0) * root.CFrame:ToObjectSpace(m:GetPivot()))
	if tier >= 4 and not gold then
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.Parent = m
		RarityFx.Rainbow(hl)
	end
	if gold then
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = Color3.fromRGB(255, 226, 120)
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = m
		local a = Instance.new("Attachment")
		a.Parent = root
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 236, 160))
		e.LightEmission = 0.8
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Rate = 5
		e.Parent = a
	end
	m.Parent = lf()
	return m
end

-- a dino was named (or its name cleared): swap its floating tag
local function retag(b, d)
	b.Name = d.Name
	local old = b.Root and b.Root:FindFirstChild("DinoTag")
	if old then old:Destroy() end
	if b.Root and b.Root.Parent then RarityFx.Tag(b.Root, d, b.TagY or 4) end
end

local function refreshPlot(st)
	local plot = st.Plot
	local own = plot:GetAttribute("Owner") == player.UserId
	-- the UPGRADE boards (CampAction Build) work only on your own island
	if not st.BuildPrompts then
		st.BuildPrompts = {}
		for _, d in ipairs(plot:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d:GetAttribute("CampAction") == "Build" then table.insert(st.BuildPrompts, d) end
		end
	end
	for _, pr in ipairs(st.BuildPrompts) do pr.Enabled = own end
	local count = plot:GetAttribute("IncubatorCount") or Config.Incubator.Base
	local incs = decode(plot:GetAttribute("Incubators"))
	local bySlot = {}
	for _, inc in ipairs(incs) do bySlot[inc.Slot] = inc end
	for slot, n in pairs(st.Nests) do
		setCover(n.Cover, slot > count)
		local inc = bySlot[slot]
		local cur = st.Eggs[slot]
		if inc and not Camp.HiddenSlots[slot] then
			if not cur or cur.Species ~= inc.Species or cur.Rarity ~= inc.Rarity then
				if cur then cur.Model:Destroy() end
				local e = eggClone(inc.Species, Config.EggScale(inc.Species, inc.KG))
				if e and n.Point then
					local seat = seatOn(e, n.Point.CFrame)
					e:PivotTo(seat)
					if n.Prompt then require(script.Parent.UI.Prompt).OutlineTargets[n.Prompt] = e end
					RarityFx.Apply(e, inc.Rarity, 2 * Config.EggScale(inc.Species, inc.KG))
					require(script.Parent.EggTip).Tag(e, inc.Species, inc.Rarity, inc.KG) -- hover: what's in the nest
					e.Parent = lf()
					-- the timer floats just over the top of the egg (big eggs are 6+ studs tall and used to swallow it)
					local bcf, bsize = e:GetBoundingBox()
					local top = bcf.Position.Y + bsize.Y / 2 - n.Point.Position.Y
					st.Eggs[slot] = { Model = e, Species = inc.Species, Rarity = inc.Rarity, Inc = inc, Base = seat, TimerY = math.max(3.4, top + 1.4) }
				end
			else
				cur.Inc = inc
			end
		elseif cur then
			cur.Model:Destroy()
			st.Eggs[slot] = nil
		end
	end
	-- the yard
	local yard = decode(plot:GetAttribute("Yard"))
	local want = {}
	for _, row in ipairs(yard) do want[row[1]] = { Id = row[1], Species = row[2], Rarity = row[3], KG = row[4], Name = row[5] } end
	for id, b in pairs(st.Dinos) do
		if not want[id] or Camp.HiddenBabies[id] then b.Model:Destroy() st.Dinos[id] = nil
		elseif b.Name ~= want[id].Name then retag(b, want[id]) end
	end
	for id, d in pairs(want) do
		if not st.Dinos[id] and not Camp.HiddenBabies[id] then st.Dinos[id] = newDino(st, d) end
	end
	-- star pens: each star roams its own pen (the pen model is the server's IslandView clone; until it has
	-- replicated, the star waits and the next refresh puts it in)
	local island = decode(plot:GetAttribute("Island"))
	local kit = plot:FindFirstChild("IslandKit")
	local penWant = {}
	for lot, pen in pairs(type(island) == "table" and island.Pens or {}) do
		local row = type(pen) == "table" and pen.Dino
		if type(row) == "table" and row[1] then penWant[lot] = { Id = row[1], Species = row[2], Rarity = row[3], KG = row[4], Name = row[5], Pen = pen.Species } end
	end
	st.PenStars = st.PenStars or {}
	for lot, b in pairs(st.PenStars) do
		local w = penWant[lot]
		if not w or w.Id ~= b.Id or not b.Model.Parent then b.Model:Destroy() st.PenStars[lot] = nil
		elseif b.Name ~= w.Name then retag(b, w) end
	end
	for lot, d in pairs(penWant) do
		if not st.PenStars[lot] and not (own and Camp.HoldPenStars) then
			local pen = kit and kit:FindFirstChild("Pen_" .. d.Pen .. "_" .. lot)
			local bounds = pen and pen:FindFirstChild("PenBounds", true) :: BasePart?
			if bounds then st.PenStars[lot] = newDino(st, d, bounds) end
		end
	end
	local board = plot:FindFirstChild("CapacityText", true)
	if board then
		local text = #yard .. " / " .. (plot:GetAttribute("PenSlots") or Config.Pen.Base)
		for _, l in ipairs(board:GetDescendants()) do if l:IsA("TextLabel") then l.Text = text end end
	end
	-- trophies
	local trophies = decode(plot:GetAttribute("Trophies"))
	local golds = decode(plot:GetAttribute("IndexGold"))
	for bossId in pairs(Config.Bosses) do
		local tier = trophies[bossId] or 0
		local gold = golds[bossId] == true
		local cur = st.Statues[bossId]
		if cur and (cur.Tier ~= tier or cur.Gold ~= gold) then cur.Model:Destroy() st.Statues[bossId] = nil cur = nil end
		if (tier > 0 or gold) and not cur then
			local spot = plot:FindFirstChild("TrophySpot_" .. bossId, true) :: BasePart?
			local m = spot and statue(spot, bossId, math.max(tier, 1), gold)
			if m then st.Statues[bossId] = { Model = m, Tier = tier, Gold = gold } end
		end
	end
	st.Own = own
end

-- owner badge: a small round avatar floating over each claimed base's name gate. Fixed pixel size (never balloons
-- when you walk up), fades out past ~260 studs, hidden during cutscenes (Cinema doesn't touch world billboards)
local badges = {}
local function ownerBadge(plot: Model)
	local beam = plot:FindFirstChild("NameGate", true)
	beam = beam and beam:FindFirstChild("GateBeam", true)
	if not (beam and beam:IsA("BasePart")) then return end
	local bb = Instance.new("BillboardGui")
	bb.Name = "OwnerBadge"
	bb.Adornee = beam
	bb.Size = UDim2.fromOffset(44, 44)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	bb.MaxDistance = 260
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Enabled = false
	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ring.Parent = bb
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(20, 20, 24)
	stroke.Parent = ring
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(1, -6, 1, -6)
	img.Position = UDim2.fromOffset(3, 3)
	img.Parent = ring
	Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
	bb.Parent = player:WaitForChild("PlayerGui")
	local function refresh()
		local uid = plot:GetAttribute("Owner")
		if type(uid) ~= "number" or uid <= 0 then bb.Enabled = false img.Image = "" return end
		local ok, url = pcall(function() return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
		if plot:GetAttribute("Owner") ~= uid then return end
		img.Image = ok and url or ""
		bb.Enabled = true
	end
	plot:GetAttributeChangedSignal("Owner"):Connect(function() task.spawn(refresh) end)
	task.spawn(refresh)
	badges[plot] = bb
end

local Cinema = nil
local function stepBadges()
	if not Cinema then
		local ok, m = pcall(require, script.Parent.UI.Cinema)
		Cinema = ok and m or false
	end
	local hide = Cinema and Cinema.Playing() or false
	for plot, bb in pairs(badges) do
		local owned = type(plot:GetAttribute("Owner")) == "number" and plot:GetAttribute("Owner") > 0
		bb.Enabled = owned and not hide
	end
end

local function bindPlot(plot: Model)
	if plots[plot] then return end
	local st = { Plot = plot, Nests = nestParts(plot), Eggs = {}, Dinos = {}, Statues = {}, Yard = plot:FindFirstChild("PaddockBounds", true), YardPond = plot:FindFirstChild("PaddockPondArea", true) }
	local centre = plot:FindFirstChild("PlotCenter", true) :: BasePart?
	st.Centre = centre and centre.Position or plot:GetPivot().Position -- (stepPlots skips islands far from the camera)
	st.CashAnchor = plot:FindFirstChild("CashLabelAnchor", true)
	plots[plot] = st
	ownerBadge(plot)
	-- the roll-up garage door (opens for the roll-out cutscene; everyone sees it)
	local garage = plot:FindFirstChild("Garage", true)
	local door = garage and garage:FindFirstChild("RollerDoor", true)
	if garage and door then
		local slats = {}
		for _, sl in ipairs(door:GetDescendants()) do
			if sl:IsA("BasePart") then table.insert(slats, { Part = sl, Base = sl.CFrame, Index = sl:GetAttribute("Index") or 0 }) end
		end
		local topY = 0
		for _, sl in ipairs(slats) do topY = math.max(topY, sl.Base.Position.Y) end
		local function animateDoor()
			local open = garage:GetAttribute("DoorOpen") == true
			for _, sl in ipairs(slats) do
				local goal = open and (sl.Base + Vector3.new(0, topY - sl.Base.Position.Y + 1.4 + sl.Index * 0.02, 0.6)) or sl.Base
				local delay = open and (10 - sl.Index) * 0.05 or sl.Index * 0.05
				sl.Part.CanCollide = not open
				TweenService:Create(sl.Part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, delay), { CFrame = goal, Transparency = open and 1 or 0 }):Play()
			end
		end
		garage:GetAttributeChangedSignal("DoorOpen"):Connect(animateDoor)
		if garage:GetAttribute("DoorOpen") then animateDoor() end
	end
	for _, a in ipairs({ "Incubators", "IncubatorCount", "Yard", "PenSlots", "Owner", "Trophies", "Island", "IndexGold" }) do
		plot:GetAttributeChangedSignal(a):Connect(function() refreshPlot(st) end)
	end
	-- a star pen the server just built: put its star in once the model is here
	local function watchKit(f: Instance)
		if f.Name ~= "IslandKit" then return end
		f.ChildAdded:Connect(function() task.defer(refreshPlot, st) end)
		task.defer(refreshPlot, st)
	end
	plot.ChildAdded:Connect(watchKit)
	local kitNow = plot:FindFirstChild("IslandKit")
	if kitNow then watchKit(kitNow) end
	plot:GetAttributeChangedSignal("Pending"):Connect(function()
		local gui = st.CashAnchor and st.CashAnchor:FindFirstChild("CashLabel")
		if gui then
			local text = "$" .. Config.FormatNumber(plot:GetAttribute("Pending") or 0)
			for _, l in ipairs(gui:GetDescendants()) do if l:IsA("TextLabel") then l.Text = text end end
		end
	end)
	-- per-incubator timer billboards (own plot only)
	for _, n in pairs(st.Nests) do
		if n.Point then
			local bb = Instance.new("BillboardGui")
			bb.Name = "Timer"
			bb.Size = UDim2.fromOffset(150, 40)
			bb.StudsOffset = Vector3.new(0, 3.4, 0)
			bb.MaxDistance = 60
			bb.AlwaysOnTop = true -- never hidden behind its own egg, the straw or the heat lamp
			bb.LightInfluence = 0
			bb.Enabled = false
			Kit.Text(bb, "", { Name = "Label", Size = UDim2.fromScale(1, 1), Shadow = 2, Stroke = 3 })
			bb.Parent = n.Point
			n.Timer = bb
		end
	end
	refreshPlot(st)
end

-- the next locked nest on your own plot carries a BUILD prompt and a price tag you can read from across the
-- yard (the rest stay covered); coins only, the price climbs with each one
Camp.OnNestBuilt = nil :: ((slot: number) -> ())?
local buying = false
local function buyTag(n): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "BuyTag"
	bb.Size = UDim2.fromOffset(190, 64)
	bb.StudsOffset = Vector3.new(0, 4.2, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.ResetOnSpawn = false
	Kit.Text(bb, "NEW INCUBATOR", { Name = "Head", Pixel = true, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 0), Color = Color3.fromRGB(255, 226, 120), Stroke = 2, Shadow = 2, MaxSize = 14 })
	Kit.Text(bb, "", { Name = "Price", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 20), Stroke = 4, Shadow = 3, MaxSize = 40 })
	bb.Adornee = n.Point
	bb.Parent = n.Model
	return bb
end
stepBuyNest = function(st, count: number)
	local profile = Net.Profile
	local coins = profile and profile.Coins or 0
	local nextSlot = count < Config.IncubatorMax(profile) and count + 1 or nil -- (the hatchery's tier sets the most nests)
	-- a full hatchery that can still grow: the next covered nest says so, and its prompt opens the hatchery's UPGRADE
	-- window (CampAction Build -> Panels.OpenBuild; nests left the Armorer's drawer 2026-10-14, so this is where
	-- "no room for another nest" has to be told now)
	local fullSlot = nil
	if not nextSlot and profile and st.Nests[count + 1] and Config.IslandTier(profile, "Hatchery") < #Config.Island.Hatchery then fullSlot = count + 1 end
	for slot, n in pairs(st.Nests) do
		local wantFull = slot == fullSlot and n.Point ~= nil
		if wantFull and not n.Grow then
			local pr = Instance.new("ProximityPrompt")
			pr.Name = "GrowHatcheryPrompt"
			pr.ActionText = "Bigger hatchery"
			pr.ObjectText = "Room for more nests"
			pr.HoldDuration = 0
			pr.MaxActivationDistance = 12
			pr.RequiresLineOfSight = false
			pr.KeyboardKeyCode = Enum.KeyCode.E
			pr:SetAttribute("CampAction", "Build")
			pr:SetAttribute("Build", "Hatchery")
			pr.Parent = n.Point
			n.Grow = pr
			n.GrowTag = buyTag(n)
			local head = n.GrowTag:FindFirstChild("Head")
			local label = n.GrowTag:FindFirstChild("Price")
			if head then Kit.SetText(head, "HATCHERY FULL") end
			if label then
				Kit.SetText(label, "UPGRADE IT")
				Kit.SetTextColor(label, Color3.fromRGB(255, 176, 70))
			end
		elseif not wantFull and n.Grow then
			n.Grow:Destroy()
			n.GrowTag:Destroy()
			n.Grow, n.GrowTag = nil, nil
		end
		local want = slot == nextSlot and n.Point ~= nil
		if want and not n.Buy then
			local pr = Instance.new("ProximityPrompt")
			pr.Name = "BuyNestPrompt"
			pr.ActionText = "Build incubator"
			pr.HoldDuration = 0.5
			pr.MaxActivationDistance = 12
			pr.RequiresLineOfSight = false
			pr.KeyboardKeyCode = Enum.KeyCode.E
			pr.Parent = n.Point
			pr.Triggered:Connect(function()
				if buying then return end
				buying = true
				task.spawn(function()
					local res = Net.Ask("BuyBase", { What = "Incubator" })
					buying = false
					if res and res.Ok then
						if Camp.OnNestBuilt then Camp.OnNestBuilt(slot) else Kit.Toast("NEW INCUBATOR BUILT!", "Teal", "Incubator") end
					else
						Kit.Toast((res and res.Err) or "NOT ENOUGH COINS", "Red", "Coin")
					end
				end)
			end)
			n.Buy = pr
			n.BuyTag = buyTag(n)
		elseif not want and n.Buy then
			n.Buy:Destroy()
			n.BuyTag:Destroy()
			n.Buy, n.BuyTag = nil, nil
		end
		if n.Buy then
			local price = Config.IncubatorPrice(count)
			local afford = coins >= price
			n.Buy.ObjectText = Config.FormatNumber(price) .. " coins"
			local label = n.BuyTag:FindFirstChild("Price")
			if label then
				Kit.SetText(label, Config.FormatNumber(price) .. " COINS")
				Kit.SetTextColor(label, afford and Color3.fromRGB(150, 255, 120) or Color3.fromRGB(255, 120, 110))
			end
		end
	end
end

-- a colour write only when it changes (144 nests' status lights and bulbs were rewritten every frame)
local function paint(p: BasePart?, c: Color3)
	if p and p.Color ~= c then p.Color = c end
end
-- islands far from the camera don't animate: nests/eggs past FAR, the yard dinos only past FAR_DINO (their walk cycle
-- keeps playing out to DinosaurAnimations' LOD_CULL 600, so freezing them nearer would make them walk on the spot)
local FAR, FAR_DINO = 420, 730

local function stepPlots(dt: number)
	local now = serverNow()
	local t = os.clock()
	local haveEggs = Net.Profile and Net.Profile.Eggs and #Net.Profile.Eggs > 0
	local cam = Workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or Vector3.zero
	for _, st in pairs(plots) do
		-- (your own island always runs: its prompts and timers follow your eggs even from the bridge)
		local far = not st.Own and st.Centre and (st.Centre - eye).Magnitude or 0
		if far > FAR_DINO then continue end
		if far > FAR then
			for _, b in pairs(st.Dinos) do stepDino(b, dt) end
			for _, b in pairs(st.PenStars or {}) do stepDino(b, dt) end
			continue
		end
		local count = st.Plot:GetAttribute("IncubatorCount") or Config.Incubator.Base
		for slot, egg in pairs(st.Eggs) do
			local inc = egg.Inc
			local n = st.Nests[slot]
			local remain = inc.Start + inc.Duration - now
			local ready = remain <= 0
			local progress = 1 - math.clamp(remain / math.max(1, inc.Duration), 0, 1)
			-- wobble grows as hatching nears; ready eggs hop and glow
			local amp = ready and 0.22 or (progress > 0.75 and 0.08 * (progress - 0.75) * 4 or 0)
			local wob = math.sin(t * (ready and 14 or 9) + slot) * amp
			local hop = ready and math.max(0, math.sin(t * 5 + slot)) * 0.3 or 0
			-- (an egg that isn't close to hatching sits still: one PivotTo back to rest, then none)
			if amp > 0 then
				egg.Model:PivotTo(egg.Base * CFrame.new(0, hop, 0) * CFrame.Angles(wob * 0.5, 0, wob))
				egg.Moved = true
			elseif egg.Moved ~= false then
				egg.Model:PivotTo(egg.Base)
				egg.Moved = false
			end
			local rc = Config.Rarity[egg.Rarity] and Config.Rarity[egg.Rarity].Color or Color3.fromRGB(255, 176, 46)
			if n then
				paint(n.Status, ready and Color3.fromRGB(110, 255, 100) or rc)
				paint(n.Bulb, ready and Color3.fromRGB(150, 255, 120) or rc)
			end
			if st.Own and n then
				if n.Timer then
					n.Timer.Enabled = true
					n.Timer.StudsOffset = Vector3.new(0, egg.TimerY or 3.4, 0)
					local label = n.Timer:FindFirstChild("Label")
					if label then
						Kit.SetText(label, ready and "READY!" or Config.FormatTime(remain))
						Kit.SetTextColor(label, ready and Color3.fromRGB(150, 255, 120) or rc:Lerp(Color3.new(1, 1, 1), 0.4))
					end
				end
				local pr = n.Prompt :: ProximityPrompt?
				if pr then
					pr.Enabled = ready and not Camp.HiddenSlots[slot]
					pr.ActionText = "Hatch"
				end
			end
		end
		for slot, n in pairs(st.Nests) do
			if not st.Eggs[slot] then
				if n.Timer and n.Timer.Enabled then n.Timer.Enabled = false end
				paint(n.Status, Color3.fromRGB(107, 111, 117))
				local pr = n.Prompt :: ProximityPrompt?
				if pr then
					-- an empty incubator takes an egg from your bag
					pr.Enabled = st.Own and slot <= count and haveEggs == true
					pr.ActionText = "Incubate"
				end
			end
		end
		if st.Own then stepBuyNest(st, count) end
		for _, b in pairs(st.Dinos) do stepDino(b, dt) end
		for _, b in pairs(st.PenStars or {}) do stepDino(b, dt) end
	end
end

-- the next nest you can build (own plot), and its price
function Camp.BuyNestPoint(): (BasePart?, number?)
	for _, st in pairs(plots) do
		if st.Own then
			local count = st.Plot:GetAttribute("IncubatorCount") or Config.Incubator.Base
			local n = st.Nests[count + 1]
			if n and count < Config.IncubatorMax(Net.Profile) then return n.Point, Config.IncubatorPrice(count) end
		end
	end
	return nil, nil
end

function Camp.NestPoint(slot: number): BasePart?
	for _, st in pairs(plots) do
		if st.Own and st.Nests[slot] then return st.Nests[slot].Point end
	end
	return nil
end

function Camp.HideEgg(slot: number, hidden: boolean)
	Camp.HiddenSlots[slot] = hidden or nil
	for _, st in pairs(plots) do
		if st.Own then
			local e = st.Eggs[slot]
			if e and hidden then e.Model:Destroy() st.Eggs[slot] = nil end
			refreshPlot(st)
		end
	end
end

function Camp.RefreshOwn()
	for _, st in pairs(plots) do if st.Own then refreshPlot(st) end end
end

function Camp.HideDino(id: string, hidden: boolean)
	Camp.HiddenBabies[id] = hidden or nil
	for _, st in pairs(plots) do if st.Own then refreshPlot(st) end end
end

function Camp.YardGate(): BasePart?
	for _, st in pairs(plots) do
		if st.Own then return st.Plot:FindFirstChild("PaddockGateIn", true) :: BasePart? end
	end
	return nil
end

function Camp.OwnPlot(): Model?
	for plot, st in pairs(plots) do if st.Own then return plot end end
	return nil
end

-- every plot's paddock for PaddockLife: { Plot, Own, Dinos = { [id] = dino record }, Yard (bounds marker) }.
-- A dino record: { Model, Root, Anim, Id, Species, Lift, FloorY, Speed, Random() }; set .Hold to drive it yourself.
function Camp.Paddocks()
	local out = {}
	for plot, st in pairs(plots) do table.insert(out, { Plot = plot, Own = st.Own, Dinos = st.Dinos, Yard = st.Yard }) end
	return out
end

--------------------------------------------------------------------------------
-- plaza: hologram, hatch stage, turntable
--------------------------------------------------------------------------------
local holo = { Model = nil :: Model?, Index = 0, Next = 0, Anchor = nil :: BasePart? }
local function holoCycle(anchor: BasePart)
	local profile = Net.Profile
	local disc = {}
	for key in pairs(profile and profile.Index or {}) do disc[(key:match("^(.-):") or key)] = true end
	-- undiscovered first, then everything
	local order = {}
	for _, sp in ipairs(Config.SpeciesOrder) do if not disc[sp] then table.insert(order, sp) end end
	if #order == 0 then order = table.clone(Config.SpeciesOrder) end
	holo.Index = holo.Index % #order + 1
	local sp = order[holo.Index]
	if holo.Model then holo.Model:Destroy() end
	local e = eggClone(sp, 2.4)
	if not e then return end
	local rc = Color3.fromRGB(80, 220, 255)
	for _, d in ipairs(e:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			d.Material = Enum.Material.Glass
			d.Color = Color3.fromRGB(110, 190, 220):Lerp(rc, 0.25)
			d.Transparency = 0.45
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") then
			d.Enabled = false
		end
	end
	e.Parent = lf()
	holo.Model = e
	local name = anchor:FindFirstChild("HoloName")
	if name then
		local text = disc[sp] and Config.Species[sp].Name or "???"
		for _, l in ipairs(name:GetDescendants()) do if l:IsA("TextLabel") then l.Text = text end end
	end
	local title = anchor:FindFirstChild("HoloTitle")
	if title then
		local text = disc[sp] and "DISCOVERED" or "UNDISCOVERED"
		for _, l in ipairs(title:GetDescendants()) do if l:IsA("TextLabel") then l.Text = text end end
	end
	DinosaurVFX.BlockRing(anchor.CFrame * CFrame.new(0, -7, 0) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 14, R0 = 2, R1 = 7, Color = Color3.fromRGB(80, 220, 255), Duration = 0.5 })
end

local stage = { Model = nil, Anim = nil }
local function showStage(stageModel: Instance)
	local species = stageModel:GetAttribute("Species")
	local owner = stageModel:GetAttribute("Owner")
	local anchor = stageModel:FindFirstChild("StageAnchor", true) :: BasePart?
	if not species or not anchor then return end
	if stage.Model then stage.Model:Destroy() end
	local t = BabyT:FindFirstChild(species)
	if not t then return end
	local m = prep(t:Clone() :: Model, nil)
	-- fitted to the stage's reveal pad (2026-10-13: at a flat 1.7x a T. rex swallowed the Egg Keeper, his screen and
	-- the whole stage): never longer than the pad's reach, never taller than the screen's bottom edge
	local ext0 = m:GetExtentsSize()
	local k = math.min(1.7, 9 / math.max(0.1, math.max(ext0.X, ext0.Z)), 7.5 / math.max(0.1, ext0.Y))
	m:ScaleTo(m:GetScale() * k)
	m:SetAttribute("AnimScale", 0.45 * k)
	local root = m.PrimaryPart :: BasePart
	root.Anchored = true
	local cf0, size = m:GetBoundingBox()
	local lift = root.Position.Y - (cf0.Position.Y - size.Y / 2)
	root.CFrame = CFrame.new(anchor.Position.X, anchor.Position.Y - anchor.Size.Y / 2 + lift, anchor.Position.Z) * anchor.CFrame.Rotation
	m.Parent = lf()
	stage.Model = m
	stage.Anim = DinosaurAnimations.get(m)
	if stage.Anim and stage.Anim:HasAction("Roar") then task.delay(0.4, function() if stage.Anim then stage.Anim:Play("Roar") end end) end
	local rarity = stageModel:GetAttribute("Rarity") or "Common"
	RarityFx.Apply(m, rarity, 6)
	DinosaurVFX.BlockRing(CFrame.new(anchor.Position) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 18, R0 = 1, R1 = 8, Color = Config.Rarity[rarity] and Config.Rarity[rarity].Color or Color3.new(1, 1, 1), Duration = 0.6 })
	local screen = stageModel:FindFirstChild("HatchScreen", true)
	if screen then
		local function set(name, text)
			local f = screen:FindFirstChild(name)
			if f then for _, l in ipairs(f:GetDescendants()) do if l:IsA("TextLabel") then l.Text = text end end end
		end
		set("Species", (Config.Rarity[rarity] and Config.Rarity[rarity].Name or "") .. " " .. Config.Species[species].Name)
		set("Owner", "HATCHED BY " .. string.upper(owner or "?"))
	end
end

local turn = { Model = nil :: Model?, Name = nil :: string?, Anchor = nil :: BasePart?, RH = 2.6 }
local function turntableVehicle(anchor: BasePart)
	local profile = Net.Profile
	local pick = "RaptorRunner"
	if profile then
		pick = nil
		for _, n in ipairs(Config.VehicleOrder) do if not profile.Gear.Vehicles[n] then pick = n break end end
		pick = pick or "TitanTransport"
	end
	if turn.Name == pick then return end
	if turn.Model then turn.Model:Destroy() end
	local t = VehicleT:FindFirstChild(pick)
	if not t then return end
	local m = prep(t:Clone() :: Model, true)
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("VehicleSeat") or d:IsA("Seat") then d.Disabled = true end end
	m.Parent = lf()
	turn.Model, turn.Name, turn.Anchor = m, pick, anchor
	turn.RH = m:GetAttribute("RootHeight") or 2.6
end

--------------------------------------------------------------------------------
-- world animation
--------------------------------------------------------------------------------
local spinners, streaks, blinkers, membranes, cores, guides, haloCubes = {}, {}, {}, {}, {}, {}, {}
local guideColor = Color3.fromRGB(88, 146, 214)
local function collect()
	for _, m in ipairs(CollectionService:GetTagged("GateSpin")) do
		if m:IsA("Model") and m.PrimaryPart then
			table.insert(spinners, { Model = m, Base = m:GetPivot(), Rate = m:GetAttribute("Spin") or 0.3, A = 0 })
			if m.Name == "Halo" then
				for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") and p.Name == "HaloCube" then table.insert(haloCubes, p) end end
			end
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("WaterStreak")) do
		if p:IsA("BasePart") then table.insert(streaks, { Part = p, Base = p.CFrame, H = p:GetAttribute("FallHeight") or 40, O = math.random() }) end
	end
	for _, p in ipairs(CollectionService:GetTagged("BlinkLight")) do table.insert(blinkers, p) end
	for _, p in ipairs(CollectionService:GetTagged("PortalSurface")) do table.insert(membranes, p) end
	for _, p in ipairs(CollectionService:GetTagged("PortalCore")) do table.insert(cores, p) end
	for _, p in ipairs(CollectionService:GetTagged("GuideLight")) do table.insert(guides, p) end
end

local deckY = nil
-- the Time Gate shows the era it's set to on the console + banner (and keeps its lights one steady blue)
local gateEra = nil
local function tintGate(camp: Instance)
	local p = Net.Profile
	local id = (p and p.Era) or "FernValley"
	if id == gateEra then return end
	local era = Config.Era(id)
	if not era then return end
	gateEra = id
	-- the gate stays blue for every era (user pick); only the destination text changes
	local col = Color3.fromHex("4a9bff") -- the Time Gate blue: the one thing in camp that glows (calm.js keeps its neon)
	local gate = camp:FindFirstChild("TimeGate", true)
	if not gate then return end
	for _, d in ipairs(gate:GetDescendants()) do
		if d:IsA("BasePart") then
			if CollectionService:HasTag(d, "PortalSurface") or CollectionService:HasTag(d, "GateNode") or CollectionService:HasTag(d, "GateEraTint") or d.Name == "InnerGlow" then
				d.Color = col
			end
		elseif d:IsA("SpotLight") or (d:IsA("PointLight") and d.Parent and d.Parent.Name == "PortalLightHost") then
			d.Color = col
		elseif d:IsA("TextLabel") and d.Name == "Main" and d.Parent then
			-- styled text = a Frame holding a Shadow + Main label; console frames are named Era / Year,
			-- the banner billboards are EraBanner / EraYear
			local holder = d.Parent :: Instance
			local slot = holder.Name == "Text" and holder.Parent and holder.Parent.Name or holder.Name
			local txt = (slot == "Era" or slot == "EraBanner") and era.Name or (slot == "Year" or slot == "EraYear") and era.Year or nil
			if txt then
				for _, l in ipairs(holder:GetChildren()) do if l:IsA("TextLabel") then l.Text = txt end end
			end
		end
	end
	-- the guide lights chase in the era colour
	guideColor = col
end

local function stepWorld(dt: number)
	local t = os.clock()
	for _, s in ipairs(spinners) do
		s.A += s.Rate * dt
		s.Model:PivotTo(s.Base * CFrame.Angles(0, 0, s.A))
	end
	if deckY then
		for _, c in ipairs(haloCubes) do c.Transparency = (c.Position.Y < deckY + 1.5) and 1 or 0 end
	end
	for _, w in ipairs(streaks) do
		local u = ((t * 0.55 + w.O) % 1)
		w.Part.CFrame = w.Base * CFrame.new(0, -u * math.min(w.H * 0.4, 22), 0)
		w.Part.Transparency = 0.35 + 0.5 * math.abs(u - 0.5) * 2
	end
	for i, p in ipairs(blinkers) do
		-- a slow breathe, not a strobe (tester: the camp was overstimulating)
		local bp = p :: BasePart
		bp.Transparency = 0.25 + 0.2 * math.sin(t * 0.8 + i)
	end
	for i, p in ipairs(membranes) do
		local bp = p :: BasePart
		bp.Transparency = 0.58 + math.sin(t * 2.2 + i) * 0.08
	end
	for i, p in ipairs(cores) do
		local bp = p :: BasePart
		bp.Transparency = 0.58 + math.sin(t * 3.1 + i * 1.7) * 0.1
	end
	for _, g in ipairs(guides) do
		local seq = g:GetAttribute("Seq") or 0
		-- a soft slow wave down the deck instead of a fast chase
		local w = 0.5 + 0.5 * math.sin(t * 1.2 - seq * 0.6)
		local gp = g :: BasePart
		gp.Color = guideColor:Lerp(Color3.fromRGB(235, 228, 200), w * 0.35)
	end
	if holo.Model and holo.Anchor then
		holo.Model:PivotTo(holo.Anchor.CFrame * CFrame.new(0, math.sin(t * 1.6) * 0.6 - 3, 0) * CFrame.Angles(0, t * 0.9, 0))
		if t >= holo.Next then holo.Next = t + 6 holoCycle(holo.Anchor) end
	end
	if turn.Model and turn.Anchor then
		local a = turn.Anchor
		turn.Model:PivotTo(CFrame.new(a.Position.X, a.Position.Y - a.Size.Y / 2 + turn.RH, a.Position.Z) * CFrame.Angles(0, t * 0.5, 0))
	end
end

--------------------------------------------------------------------------------
-- walkers: the ridge Brachiosaurus at camp (back and forth) and the Giant Plains herd (a loop around the Old Giant)
--------------------------------------------------------------------------------
local walkers = {}
local function addWalker(pts: { Vector3 }, scale: number, loop: boolean, start: number, speed: number)
	local t = DinoT:FindFirstChild("Brachiosaurus")
	if #pts < 2 or not t then return end
	local m = prep(t:Clone() :: Model, nil)
	m:ScaleTo(scale)
	m:SetAttribute("AnimScale", scale)
	local root = m.PrimaryPart :: BasePart
	root.Anchored = true
	local cf0, size = m:GetBoundingBox()
	m:SetAttribute("Species", "Brachiosaurus")
	CollectionService:AddTag(m, "AmbientDino") -- (cutscenes hide it while their own Brachiosaurus is on screen)
	local w = { Model = m, Root = root, Pts = pts, I = start, Dir = 1, Pos = pts[start], Loop = loop, Speed = speed, Pause = 0 }
	w.Lift = root.Position.Y - (cf0.Position.Y - size.Y / 2)
	m.Parent = lf()
	w.Anim = DinosaurAnimations.get(m)
	if w.Anim then w.Anim:SetLocomotion("Walk") end
	table.insert(walkers, w)
end

local function waypoints(zone: Instance, prefix: string): { Vector3 }
	local pts = {}
	for i = 1, 40 do
		local m = zone:FindFirstChild(prefix .. i, true) :: BasePart?
		if not m then break end
		pts[i] = m.Position - Vector3.new(0, m.Size.Y / 2, 0) -- the marker's bottom is the ground
	end
	return pts
end

local function startBrachio(camp: Instance)
	addWalker(waypoints(camp, "RidgeWaypoint"), 1.6, false, 1, 3.2)
end

-- Giant Plains: an adult and two young walk the game trail around the Old Giant, a few waypoints apart
local function startMigration()
	local gp = Workspace:FindFirstChild("GiantPlains")
	if not gp then return end
	local pts = waypoints(gp, "HerdWaypoint")
	if #pts < 3 then return end
	for k, sc in ipairs({ 1.25, 0.8, 0.62 }) do addWalker(pts, sc, true, 1 + (k - 1) * 2, 3.4) end
end

local function stepWalker(w, dt: number)
	if w.Pause > 0 then
		w.Pause -= dt
		if w.Pause <= 0 and w.Anim then w.Anim:SetLocomotion("Walk", 0.6) end
		return
	end
	local nextI = w.Loop and (w.I % #w.Pts + 1) or (w.I + w.Dir)
	local target = w.Pts[nextI]
	if not target then
		w.Dir = -w.Dir
		w.Pause = 6
		if w.Anim then
			w.Anim:SetLocomotion("Idle", 0.8)
			w.Anim:Play(math.random() < 0.5 and "Browse" or "Roar")
		end
		return
	end
	local d = target - w.Pos
	if d.Magnitude < w.Speed * dt then
		w.I = nextI
		w.Pos = target
		-- the herd stops to browse now and then
		if w.Loop and math.random() < 0.12 then
			w.Pause = 4 + math.random() * 3
			if w.Anim then w.Anim:SetLocomotion("Idle", 0.8) w.Anim:Play("Browse") end
		end
	else
		w.Pos += d.Unit * w.Speed * dt
	end
	local dir = d.Magnitude > 0.01 and d.Unit or Vector3.new(1, 0, 0)
	local yaw = math.atan2(-dir.X, -dir.Z)
	w.Yaw = w.Yaw and (w.Yaw + math.atan2(math.sin(yaw - w.Yaw), math.cos(yaw - w.Yaw)) * math.min(1, dt * 0.8)) or yaw
	w.Root.CFrame = CFrame.new(w.Pos + Vector3.new(0, w.Lift, 0)) * CFrame.Angles(0, w.Yaw, 0)
end

-- dust devils on the plains wander around where they were placed
local devils = {}
local function startDevils()
	-- every era with a Weather folder of DustDevils (Giant Plains, Dawn Desert, Red Cliffs)
	for _, zoneId in ipairs({ "GiantPlains", "DawnDesert", "RedCliffs" }) do
		local zm = Workspace:FindFirstChild(zoneId)
		local wf = zm and zm:FindFirstChild("Weather", true)
		if not wf then continue end
		for _, p in ipairs(wf:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "DustDevil" then
				table.insert(devils, { Part = p, Home = p.Position, R = p:GetAttribute("Wander") or 18, Phase = math.random() * 10 })
			end
		end
	end
end

local function stepWalkers(dt: number)
	local cam = Workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or Vector3.zero
	for _, w in ipairs(walkers) do
		-- far-away walkers freeze (nobody can see them) so they cost nothing
		if w.Model.Parent and (w.Pos - eye).Magnitude < 1100 then stepWalker(w, dt) end
	end
	local t = os.clock()
	for _, d in ipairs(devils) do
		if (d.Home - eye).Magnitude < 900 then
			local a = t * 0.11 + d.Phase
			d.Part.CFrame = CFrame.new(d.Home + Vector3.new(math.sin(a) * d.R, 0, math.sin(a * 1.7 + 1.3) * d.R * 0.7))
		end
	end
end

--------------------------------------------------------------------------------
-- Fern Valley ambient: the grazing herd in Horn Meadow
--------------------------------------------------------------------------------
local function startHerd()
	local fv = Workspace:FindFirstChild("FernValley")
	local t = DinoT:FindFirstChild("Triceratops")
	if not fv or not t then return end
	for _, spot in ipairs(CollectionService:GetTagged("MeadowHerdSpot")) do
		if spot:IsDescendantOf(fv) and spot:IsA("BasePart") then
			local m = prep(t:Clone() :: Model, nil)
			local root = m.PrimaryPart :: BasePart
			root.Anchored = true
			local cf0, size = m:GetBoundingBox()
			local lift = root.Position.Y - (cf0.Position.Y - size.Y / 2)
			root.CFrame = CFrame.new(spot.Position.X, spot.Position.Y - 0.5 + lift, spot.Position.Z) * spot.CFrame.Rotation
			m:SetAttribute("Species", "Triceratops")
			CollectionService:AddTag(m, "AmbientDino")
			m.Parent = lf()
			local anim = DinosaurAnimations.get(m)
			task.spawn(function()
				while m.Parent do
					task.wait(3 + math.random() * 5)
					if anim then anim:Play(math.random() < 0.7 and "Graze" or "LookAround") end
				end
			end)
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- paddock doors: closed, they swing open (inward) as you walk up and close behind you
--------------------------------------------------------------------------------
local doors = {} :: { any }
local function bindDoor(m: Instance)
	if not m:IsA("Model") then return end
	local hinge = m:FindFirstChild("DoorHinge", true) :: BasePart?
	if not hinge then return end
	local parts = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, { Part = d, Rel = hinge.CFrame:ToObjectSpace(d.CFrame) }) end
	end
	table.insert(doors, { Model = m, Hinge = hinge.CFrame, Parts = parts, Side = m:GetAttribute("Side") or 1, A = 0, V = 0 })
end

local function stepDoors(dt: number)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local p = hrp and hrp.Position
	for _, d in ipairs(doors) do
		local near = p ~= nil and (p - d.Hinge.Position).Magnitude < 17
		if not near then
			for _, o in ipairs(Camp.Openers) do
				if o.Parent and (o.Position - d.Hinge.Position).Magnitude < 17 then near = true break end
			end
		end
		-- a springy swing with a little overshoot
		local target = near and math.rad(96) or 0
		d.V += ((target - d.A) * 60 - d.V * 11) * dt
		d.A += d.V * dt
		if math.abs(d.A - (d.Last or -1)) > 0.0005 then
			d.Last = d.A
			local cf = d.Hinge * CFrame.Angles(0, d.Side * d.A, 0)
			for _, rec in ipairs(d.Parts) do rec.Part.CFrame = cf * rec.Rel end
		end
	end
end

function Camp.Start()
	local camp = Workspace:WaitForChild("BaseCamp")
	for _, m in ipairs(CollectionService:GetTagged("PaddockDoor")) do bindDoor(m) end
	CollectionService:GetInstanceAddedSignal("PaddockDoor"):Connect(function(m) task.defer(bindDoor, m) end)
	lf()
	for _, plot in ipairs(camp:WaitForChild("Plots"):GetChildren()) do
		if plot:IsA("Model") then task.spawn(bindPlot, plot) end
	end
	collect()
	local deck = camp:FindFirstChild("DeckTop", true) :: BasePart?
	if deck then deckY = deck.Position.Y + deck.Size.Y / 2 end
	local anchor = camp:FindFirstChild("HologramAnchor", true) :: BasePart?
	if anchor then holo.Anchor = anchor holoCycle(anchor) holo.Next = os.clock() + 6 end
	local stageModel = camp:FindFirstChild("HatchStage", true)
	if stageModel then
		stageModel:GetAttributeChangedSignal("At"):Connect(function() showStage(stageModel) end)
		if stageModel:GetAttribute("Species") then showStage(stageModel) end
	end
	local tt = camp:FindFirstChild("TurntableAnchor", true) :: BasePart?
	-- (the Quartermaster's turntable belongs to Outfitter.luau now: no vehicle on it unless a place opts back in)
	if tt and camp:GetAttribute("TurntableVehicle") == true then
		turntableVehicle(tt)
		Net.On("Profile", function() turntableVehicle(tt) end)
	end
	tintGate(camp)
	Net.On("Profile", function() tintGate(camp) end)
	startBrachio(camp)
	task.spawn(startHerd)
	task.spawn(startMigration)
	task.spawn(startDevils)
	local Zone = require(script.Parent.Zone)
	RunService.RenderStepped:Connect(function(dt)
		-- the walkers live in the eras too (the Giant Plains migration, dust devils) and freeze by distance on their
		-- own, so they step everywhere (gated on camp, the Giant Plains herd stood still while you were there)
		stepWalkers(dt)
		-- (out in an era nobody can see camp: every player's nests, paddock dinos, spinners and doors used to
		-- animate every frame wherever you were)
		if Zone.Current ~= "BaseCamp" then return end
		stepPlots(dt)
		stepWorld(dt)
		stepBadges()
		stepDoors(dt)
	end)
end

return Camp
