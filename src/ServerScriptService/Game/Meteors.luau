--[[
	Meteors — METEOR SHOWERS over Base Camp (2026-10-14; numbers: ReplicatedStorage Game/WorldEvents.luau Meteor,
	drawn by MeteorView).

	  A shower: a warning ("MeteorShower" { Phase = "Warn", In }), then Duration seconds of meteors - each one is
	  "Meteor" { Id, From, To, Fall, Star } to everyone Fall seconds before it lands (the client flies it in), and on
	  landing a METEORITE model here in Workspace.DinoMeteorites (a glowing rock + a COLLECT prompt).
	  Anyone may collect each meteorite once: coins (minutes of your yard's income), the STAR one an egg.
	  "MeteorGot" { Id, Coins, Egg?, Star } to the collector (their client greys that rock out for them).
	  After the last landing they glow on for Linger seconds, then "MeteorShower" { Phase = "Over" } and they go.
	  Meteors.Begin(by?) - Settings > ADMIN (METEORS button). The timer only starts one with someone at camp.
	  The DinoExpedition folder carries MeteorUntil (os.time() the rocks go), so a late joiner knows one's on.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local WorldEvents = require(ReplicatedStorage.DinoExpedition.Game.WorldEvents)

local Meteors = {}
local Analytics = require(script.Parent.Analytics)
local M = WorldEvents.Meteor
local Data, Net, Dinos, Plots, Expedition
local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local rng = Random.new()

local FALL = 2.6 -- seconds a meteor takes from the top of the sky to the ground (the client's flight)
local HUB = Vector3.new(600, 0, 0) -- the plaza's centre (hub.js HUB_ORIGIN; the HologramAnchor if it's there)

local running = false
local nextAt = 0
local folder: Folder? = nil
local rocks = {} :: { [string]: { Model: Model, Pos: Vector3, Star: boolean, Got: { [number]: boolean } } }
local seq = 0

--------------------------------------------------------------------------------
-- where they land
--------------------------------------------------------------------------------
local function hubCentre(): Vector3
	local camp = Workspace:FindFirstChild("BaseCamp")
	local a = camp and camp:FindFirstChild("HologramAnchor", true)
	if a and a:IsA("BasePart") then return Vector3.new(a.Position.X, 0, a.Position.Z) end
	return HUB
end

local function rayParams(): RaycastParams
	local skip = {} :: { Instance }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(skip, p.Character) end
	end
	if folder then table.insert(skip, folder) end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = skip
	rp.IgnoreWater = false
	return rp
end

-- open ground at (x, z): the first thing straight down is low, dry ground with nothing tall right beside it
local function groundAt(x: number, z: number, rp: RaycastParams, taken: { Vector3 }): Vector3?
	local hit = Workspace:Raycast(Vector3.new(x, 220, z), Vector3.new(0, -260, 0), rp)
	if not hit or hit.Material == Enum.Material.Water then return nil end
	local p = hit.Position
	if p.Y < -0.5 or p.Y > 4 then return nil end -- (a roof, a tree, a rock, the water)
	if hit.Normal.Y < 0.85 then return nil end -- (a slope)
	for _, q in ipairs(taken) do
		if (q - p).Magnitude < 14 then return nil end
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = rp.FilterDescendantsInstances
	for _, part in ipairs(Workspace:GetPartBoundsInRadius(p + Vector3.new(0, 3.5, 0), 4.5, op)) do
		-- (walls, posts, trunks, fences, parked rovers: anything solid standing up out of the ground. Its real height,
		-- turned and all: the lawns are cylinders lying on their side, whose Size.Y is their width)
		if part.CanCollide then
			local cf, s = part.CFrame, part.Size
			local half = (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
			if part.Position.Y + half > p.Y + 2 and part.Position.Y - half < p.Y + 5 then return nil end
		end
	end
	return p
end

local function hubSpots(n: number, taken: { Vector3 }, rp: RaycastParams): { Vector3 }
	local c = hubCentre()
	local out = {}
	for _ = 1, n * 30 do
		if #out >= n then break end
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(58, 122)
		local p = groundAt(c.X + math.cos(a) * r, c.Z + math.sin(a) * r, rp, taken)
		if p then
			table.insert(out, p)
			table.insert(taken, p)
		end
	end
	return out
end

-- a few on an island: inside its ground box, outside its paddock
local function islandSpots(plot: Model, n: number, taken: { Vector3 }, rp: RaycastParams): { Vector3 }
	local box = plot:FindFirstChild("PlotCenter", true)
	if not (box and box:IsA("BasePart")) then return {} end
	local pen = plot:FindFirstChild("PaddockBounds", true)
	local out = {}
	for _ = 1, n * 30 do
		if #out >= n then break end
		local lx = rng:NextNumber(-0.45, 0.45) * box.Size.X
		local lz = rng:NextNumber(-0.45, 0.45) * box.Size.Z
		local w = box.CFrame:PointToWorldSpace(Vector3.new(lx, 0, lz))
		local inPen = false
		if pen and pen:IsA("BasePart") then
			local l = pen.CFrame:PointToObjectSpace(w)
			inPen = math.abs(l.X) < pen.Size.X / 2 + 8 and math.abs(l.Z) < pen.Size.Z / 2 + 8
		end
		local p = not inPen and groundAt(w.X, w.Z, rp, taken) or nil
		if p then
			table.insert(out, p)
			table.insert(taken, p)
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- the meteorite (a few rough basalt chunks with glowing seams, a light, rising embers)
--------------------------------------------------------------------------------
local function chunk(parent: Instance, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CastShadow = true, false, false, true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildRock(id: string, at: Vector3, star: boolean): Model
	local m = Instance.new("Model")
	m.Name = "Meteorite_" .. id
	local k = star and 1.45 or 1
	local glow = star and Color3.fromRGB(110, 232, 255) or Color3.fromRGB(255, 132, 40)
	local rock = star and Color3.fromRGB(46, 40, 70) or Color3.fromRGB(44, 38, 36)
	local base = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	-- the scorched crater rim
	local rim = chunk(m, base * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.3, 9 * k, 9 * k), Color3.fromRGB(38, 32, 30), Enum.Material.Slate)
	rim.Shape = Enum.PartType.Cylinder
	rim.CastShadow = false
	local core = chunk(m, base * CFrame.new(0, 1.3 * k, 0) * CFrame.Angles(0.5, 0.3, 0.7), Vector3.new(2.6, 2.3, 2.5) * k, glow, Enum.Material.Neon)
	core.Name = "Core"
	-- basalt plates over the glowing core: the seams between them shine through
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local cf = base * CFrame.new(math.cos(a) * 0.8 * k, (1.1 + (i % 2) * 0.6) * k, math.sin(a) * 0.8 * k)
			* CFrame.Angles(rng:NextNumber(-0.6, 0.6), a, rng:NextNumber(-0.6, 0.6))
		chunk(m, cf, Vector3.new(rng:NextNumber(1.5, 2.1), rng:NextNumber(1.3, 1.9), rng:NextNumber(1.0, 1.4)) * k, rock, Enum.Material.Basalt)
	end
	chunk(m, base * CFrame.new(0.2, 2.25 * k, -0.1) * CFrame.Angles(0.3, 1.1, -0.4), Vector3.new(1.6, 1.0, 1.5) * k, rock, Enum.Material.Basalt)
	-- little shards thrown out round it
	for i = 1, 5 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(2.6, 4) * k
		chunk(m, base * CFrame.new(math.cos(a) * r, 0.25, math.sin(a) * r) * CFrame.Angles(rng:NextNumber(), rng:NextNumber(), rng:NextNumber()),
			Vector3.new(0.6, 0.5, 0.7) * rng:NextNumber(0.8, 1.3), i % 2 == 0 and glow or rock, i % 2 == 0 and Enum.Material.Neon or Enum.Material.Basalt)
	end
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = star and 22 or 16
	light.Brightness = star and 2.4 or 1.8
	light.Shadows = false
	light.Parent = core
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Rate = star and 14 or 8
	embers.Lifetime = NumberRange.new(1.4, 2.4)
	embers.Speed = NumberRange.new(2, 4)
	embers.SpreadAngle = Vector2.new(30, 30)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Acceleration = Vector3.new(0, 1.5, 0)
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	embers.Color = ColorSequence.new(glow)
	embers.LightEmission = 1
	embers.Parent = core
	-- (the prompt sits on an invisible host above the rock, so the card floats over it)
	local host = chunk(m, CFrame.new(at + Vector3.new(0, 3.2 * k, 0)), Vector3.new(1, 1, 1), glow, Enum.Material.SmoothPlastic)
	host.Name = "PromptHost"
	host.Transparency = 1
	host.CastShadow = false
	host.CanQuery = false
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "Collect"
	pr.ActionText = "COLLECT"
	pr.ObjectText = star and "STAR METEORITE" or "METEORITE"
	pr.HoldDuration = 0.35
	pr.MaxActivationDistance = 11
	pr.RequiresLineOfSight = false
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr:SetAttribute("CampAction", "Meteorite")
	pr:SetAttribute("MeteorId", id)
	pr:SetAttribute("PromptColor", star and "Teal" or "Orange")
	pr.Parent = host
	m:SetAttribute("MeteorId", id)
	m:SetAttribute("Star", star)
	m.PrimaryPart = core
	return m
end

--------------------------------------------------------------------------------
-- collecting
--------------------------------------------------------------------------------
local function yardRate(player: Player, profile): number
	local ok, r = pcall(Dinos.Rate, profile, player, false, true)
	r = ok and tonumber(r) or 0
	return (r and r > 0 and r < math.huge) and r or 0
end

local function collect(player: Player, id: string)
	local r = rocks[id]
	local profile = Data.Peek(player)
	if not (r and r.Model.Parent and profile) then return end
	if r.Owner and r.Owner ~= player.UserId then return end
	if r.Got[player.UserId] then
		Net.Fire(player, "MeteorGot", { Id = id, Already = true })
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or (hrp.Position - r.Pos).Magnitude > M.Reach then return end
	r.Got[player.UserId] = true
	-- (who has had it, on the rock: a client that rejoins mid-shower greys out its own ones)
	r.Model:SetAttribute("Got", (r.Model:GetAttribute("Got") or ",") .. player.UserId .. ",")
	local rate = yardRate(player, profile)
	local out = { Id = id, Star = r.Star, Coins = 0 }
	if r.Star then
		local pool = Config.ShopEggSpecies(profile.Unlocked)
		local egg = #pool > 0 and Dinos.AddEgg(player, pool[rng:NextInteger(1, #pool)]) or nil
		if egg then
			out.Egg = { Species = egg.Species, Rarity = egg.Rarity }
		else
			out.Coins = math.max(M.StarMin, math.floor(rate * 60 * M.StarMinutes))
		end
	else
		out.Coins = math.max(M.CoinMin, math.floor(rate * 60 * M.CoinMinutes))
	end
	if out.Coins > 0 then
		profile.Coins += out.Coins
		profile.Earned += out.Coins
		Analytics.Coins(player, "Source", out.Coins, "Gameplay", r.Star and "StarMeteorite" or "Meteorite")
	end
	profile.Stats.Meteors = (tonumber(profile.Stats.Meteors) or 0) + 1
	Data.Changed(player)
	Net.Fire(player, "MeteorGot", out)
end

--------------------------------------------------------------------------------
-- a shower
--------------------------------------------------------------------------------
local function atCamp(): { Player }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if Data.Peek(p) and not Expedition.InRun(p) then table.insert(out, p) end
	end
	return out
end

local function clear()
	for _, r in pairs(rocks) do r.Model:Destroy() end
	table.clear(rocks)
	Shared:SetAttribute("MeteorUntil", nil)
end

local function shower(by: string?)
	running = true
	local ok, err = pcall(function()
		folder = folder or Instance.new("Folder")
		local f = folder :: Folder
		f.Name = "DinoMeteorites"
		f.Parent = Workspace
		clear()
		local landEnd = os.time() + M.Warn + M.Duration
		Shared:SetAttribute("MeteorUntil", landEnd + M.Linger)
		Net.FireAll("MeteorShower", { Phase = "Warn", In = M.Warn, Duration = M.Duration, By = by, T = os.time() })
		task.wait(M.Warn)
		-- where they'll land: the hub, then the islands of whoever's at camp right now
		local rp = rayParams()
		local taken = {} :: { Vector3 }
		local spots = {} :: { any }
		for _, p in ipairs(hubSpots(M.Hub, taken, rp)) do table.insert(spots, { Pos = p }) end
		local hubCount = #spots
		-- (the ones on an island are its owner's: a full server doesn't pay everyone for every island)
		for _, plr in ipairs(atCamp()) do
			local plot = Plots.Get(plr)
			if plot then
				for _, p in ipairs(islandSpots(plot, M.PerIsland, taken, rp)) do table.insert(spots, { Pos = p, Owner = plr.UserId }) end
			end
		end
		if #spots == 0 then warn("[Meteors] found nowhere to land") end
		-- one STAR METEORITE, at the hub (everyone passes through it); only if the hub had no room, on an island
		if #spots > 0 then
			local s = spots[rng:NextInteger(1, hubCount > 0 and hubCount or #spots)]
			s.Star, s.Owner = true, nil
		end
		-- spread over the shower, a little bunched (showers come in bursts)
		for _, s in ipairs(spots) do s.Land = rng:NextNumber() ^ 0.85 * (M.Duration - FALL - 2) + FALL end
		table.sort(spots, function(a, b) return a.Land < b.Land end)
		-- (the star lands in the second half, so nobody who arrives late misses all of it)
		for _, s in ipairs(spots) do
			if s.Star then s.Land = math.max(s.Land, M.Duration * 0.5) end
		end
		table.sort(spots, function(a, b) return a.Land < b.Land end)
		local t0 = os.clock()
		for _, s in ipairs(spots) do
			local wait = t0 + s.Land - FALL - os.clock()
			if wait > 0 then task.wait(wait) end
			seq += 1
			local id = tostring(seq)
			-- from high in the sky, off to one side (they all come in from roughly the same direction, like a real shower)
			local a = math.rad(35) + rng:NextNumber(-0.25, 0.25)
			local from = s.Pos + Vector3.new(math.cos(a) * 340, 420 + rng:NextNumber(-40, 40), math.sin(a) * 340)
			Net.FireAll("Meteor", { Id = id, From = from, To = s.Pos, Fall = FALL, Star = s.Star == true, T = os.time() })
			task.delay(FALL, function()
				if not running then return end
				local m = buildRock(id, s.Pos, s.Star == true)
				if s.Owner then m:SetAttribute("Owner", s.Owner) end
				rocks[id] = { Model = m, Pos = s.Pos, Star = s.Star == true, Got = {}, Owner = s.Owner }
				local pr = m:FindFirstChild("Collect", true) :: ProximityPrompt?
				if pr then pr.Triggered:Connect(function(plr) collect(plr, id) end) end
				m.Parent = f
			end)
		end
		local left = t0 + M.Duration - os.clock()
		if left > 0 then task.wait(left) end
		Shared:SetAttribute("MeteorUntil", os.time() + M.Linger)
		task.wait(M.Linger)
	end)
	if not ok then warn("[Meteors] shower failed: " .. tostring(err)) end
	running = false
	clear()
	Net.FireAll("MeteorShower", { Phase = "Over", T = os.time() })
	nextAt = os.time() + rng:NextInteger(M.Every[1], M.Every[2]) * 60
end

-- Settings > ADMIN
function Meteors.Begin(by: string?): (boolean, string)
	if running then return false, "A METEOR SHOWER IS ALREADY ON" end
	task.spawn(shower, by)
	return true, "METEOR SHOWER IN " .. M.Warn .. "s"
end

function Meteors.Running(): boolean
	return running
end

function Meteors.Start(deps)
	Data, Net, Dinos, Plots, Expedition = deps.Data, deps.Net, deps.Dinos, deps.Plots, deps.Expedition
	nextAt = os.time() + rng:NextInteger(M.FirstAfter[1], M.FirstAfter[2]) * 60
	task.spawn(function()
		while true do
			task.wait(5)
			if not running and os.time() >= nextAt then
				-- (nobody at camp to see it: try again in a minute)
				if #atCamp() > 0 then Meteors.Begin(nil) else nextAt = os.time() + 60 end
			end
		end
	end)
end

return Meteors
