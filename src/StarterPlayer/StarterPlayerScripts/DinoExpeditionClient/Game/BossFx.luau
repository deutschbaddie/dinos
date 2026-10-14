--[[
	BossFx — what the bosses' signature moves look like for the hunters in the fight (LandKings.luau / SeaKing.luau
	on the server; the move names are EncounterView's banner). The red shapes are EncounterView's telegraphs; this
	is the spectacle on top of them: props, particles, sound, camera.

	  WHITEOUT    the den's Whiteout attribute: the air fills with driving snow, the world drains to white, and the
	              boss (State "Stalk") is only a pale shape with burning eyes until it pounces
	  CRASH       a charge into the rocks: a burst of stone, cracks and a heavy shake
	  GUARD BREAK the crossed claws knocked open: a ring of sparks and a flash on the boss
	(2026-10-14, the "more epic" pass)
	  ENRAGED     an angry boss smoulders: embers and heat haze pour off it (frost mist / sea spray for the
	              cold and wet ones) and its eyes keep burning
	  ARENA SHIFT the set piece (LandKings): a roar that shakes the screen, and the arena's hazard arrives - trees
	              crash down, fissures split the plain, boulders and icicles fall, sand geysers burst. Each prop is
	              timed to land exactly when its red shape does
	  CHOMP / SHOCKWAVE / RAZOR / SPIKES / SAND TRAP / KNOCKDOWN   the land bosses' new moves (crests, blades and
	              spikes travel at the same speed the server times their hits to)
	  SEA BOSS    the fin's wake (Submerge + Fin), the cannonball's shadow growing on the planks, the ripple out of
	              the belly flop, the crash of it beaching itself, stars while it wallows (Recover), and the storm
	              that rolls over the Maw once it's angry (the den's Storm attribute: rain, dark sky, lightning)
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local DinosaurVFX = require(Shared:WaitForChild("DinosaurVFX"))
local Config = require(Shared:WaitForChild("Game"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Audio = require(script.Parent.Audio)
local CineKit = require(script.Parent.UI.CineKit)
local Zone = require(script.Parent.Zone)
local Floor = require(script.Parent.Floor)

local player = Players.LocalPlayer
local Sites = Shared:WaitForChild("Runtime"):WaitForChild("Sites")
local Chasers = Shared.Runtime:WaitForChild("Chasers")

local BossFx = {}
local Exp -- ExpeditionView (creature models)

local WATER = { Color3.fromRGB(110, 190, 255), Color3.fromRGB(170, 220, 255), Color3.fromRGB(235, 250, 255) }
local DIRT = { Color3.fromRGB(122, 92, 60), Color3.fromRGB(150, 116, 76), Color3.fromRGB(98, 76, 52) }
local WOOD = { Color3.fromRGB(150, 104, 62), Color3.fromRGB(122, 84, 50), Color3.fromRGB(176, 128, 80) }

local function fxPart(props): BasePart
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do (p :: any)[k] = v end
	p.Parent = DinosaurVFX.Folder()
	return p
end

local function creatureById(id: any)
	if not Exp then return nil end
	for cfg, c in pairs(Exp.Creatures()) do
		if cfg:GetAttribute("Id") == id then return c end
	end
	return nil
end

-- the ground under p (the floor, never the seabed under water when a surface height is given)
local function ground(p: Vector3, surface: number?): Vector3
	local g = Floor.At(p + Vector3.new(0, 6, 0), 12)
	if surface and g.Y < surface then g = Vector3.new(g.X, surface, g.Z) end
	return g
end

-- how close the camera is (0 far .. 1 on top of it): scales the shakes of things happening around the arena
local function nearness(at: Vector3, range: number): number
	local cam = Workspace.CurrentCamera
	if not cam then return 1 end
	return math.clamp(1 - (cam.CFrame.Position - at).Magnitude / range, 0, 1)
end

--------------------------------------------------------------------------------
-- whiteout
--------------------------------------------------------------------------------
local white = nil :: any
local function whiteOn()
	if white then return end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DinoWhiteout"
	grade.Parent = Lighting
	TweenService:Create(grade, TweenInfo.new(0.8), { Saturation = -0.45, Brightness = 0.06, TintColor = Color3.fromRGB(226, 238, 255) }):Play()
	local was = atm and { atm.Density, atm.Haze, atm.Color, atm.Glare, atm.Decay }
	if atm then
		TweenService:Create(atm, TweenInfo.new(0.8), { Density = 0.62, Haze = 3, Color = Color3.fromRGB(232, 240, 250), Glare = 0, Decay = Color3.fromRGB(220, 230, 245) }):Play()
	end
	-- the snow, driven sideways past the lens
	local host = Instance.new("Part")
	host.Name = "DinoWhiteoutSnow"
	host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch, host.Transparency = true, false, false, false, 1
	host.Size = Vector3.new(60, 1, 60)
	host.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Rate = 160
	pe.Lifetime = NumberRange.new(1.2, 2)
	pe.Speed = NumberRange.new(14, 26)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Acceleration = Vector3.new(18, -4, 6)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(Color3.fromRGB(245, 250, 255))
	pe.LightEmission = 0.2
	pe.Parent = host
	local conn = RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if cam then host.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 18, 0)) end
	end)
	white = { Grade = grade, Atm = atm, Was = was, Host = host, Conn = conn, Zone = Zone.Current }
end
local function whiteOff()
	if not white then return end
	local w = white
	white = nil
	w.Conn:Disconnect()
	local pe = w.Host:FindFirstChildOfClass("ParticleEmitter")
	if pe then pe.Enabled = false end
	task.delay(2, function() w.Host:Destroy() end)
	TweenService:Create(w.Grade, TweenInfo.new(0.7), { Saturation = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	task.delay(0.75, function() w.Grade:Destroy() end)
	-- (only put the air back if we're still in the same era: a warp home has already set camp's own)
	if w.Atm and w.Was and Zone.Current == w.Zone then
		-- (the zone's air as it is now - the weather may have changed under the whiteout)
		local look = Zone.Look()
		local a = look and look.Atmosphere or { Density = w.Was[1], Haze = w.Was[2], Color = w.Was[3], Glare = w.Was[4], Decay = w.Was[5] }
		TweenService:Create(w.Atm, TweenInfo.new(0.9), { Density = a.Density, Haze = a.Haze, Color = a.Color, Glare = a.Glare, Decay = a.Decay }):Play()
	end
end

--------------------------------------------------------------------------------
-- the storm over the Maw (the sea boss, angry, at its last stand)
--------------------------------------------------------------------------------
local storm = nil :: any
local function bolt(at: Vector3)
	-- a jagged white bolt from the clouds into the sea, a flash, and the thunder a beat later
	local top = at + Vector3.new(0, 140, 0)
	local prev = top
	local parts = {}
	for k = 1, 7 do
		local u = k / 7
		local p = top:Lerp(at, u) + (k < 7 and Vector3.new(math.random(-9, 9), 0, math.random(-9, 9)) or Vector3.zero)
		local len = (p - prev).Magnitude
		table.insert(parts, fxPart({ Material = Enum.Material.Neon, Color = Color3.fromRGB(235, 245, 255), Size = Vector3.new(0.9, 0.9, len), CFrame = CFrame.lookAt((p + prev) / 2, p) }))
		prev = p
	end
	task.delay(0.12, function() for _, p in ipairs(parts) do p:Destroy() end end)
	if storm then
		local g = storm.Grade :: ColorCorrectionEffect
		g.Brightness = 0.45
		TweenService:Create(g, TweenInfo.new(0.35), { Brightness = -0.08 }):Play()
	end
	DinosaurVFX.WaterSplash(at, 1.4)
	task.delay(0.35 + math.random() * 0.4, function()
		Audio.Play("StompBig", { Volume = 0.9, Pitch = 0.32, Exact = true })
		DinosaurVFX.Shake(0.35, 0.6)
	end)
end
local function stormOn(center: Vector3?)
	if storm then return end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DinoStorm"
	grade.Parent = Lighting
	TweenService:Create(grade, TweenInfo.new(2), { Saturation = -0.25, Brightness = -0.08, Contrast = 0.18, TintColor = Color3.fromRGB(196, 214, 240) }):Play()
	local was = atm and { atm.Density, atm.Haze, atm.Color, atm.Glare, atm.Decay }
	if atm then
		TweenService:Create(atm, TweenInfo.new(2), { Density = 0.45, Haze = 2.4, Color = Color3.fromRGB(150, 165, 185), Glare = 0, Decay = Color3.fromRGB(90, 105, 125) }):Play()
	end
	-- rain, falling hard round the camera
	local host = Instance.new("Part")
	host.Name = "DinoStormRain"
	host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch, host.Transparency = true, false, false, false, 1
	host.Size = Vector3.new(80, 1, 80)
	host.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 260
	pe.Lifetime = NumberRange.new(0.5, 0.7)
	pe.Speed = NumberRange.new(70, 90)
	pe.SpreadAngle = Vector2.new(4, 4)
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Orientation = Enum.ParticleOrientation.VelocityParallel
	pe.Acceleration = Vector3.new(6, 0, 3)
	pe.Size = NumberSequence.new(0.18)
	pe.Squash = NumberSequence.new(2.5) -- (stretched along their fall: streaks)
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.6) })
	pe.Color = ColorSequence.new(Color3.fromRGB(200, 220, 240))
	pe.LightEmission = 0.3
	pe.Parent = host
	local nextBolt = os.clock() + 2.5
	local conn = RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if cam then host.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 30, 0)) end
		if os.clock() >= nextBolt then
			nextBolt = os.clock() + 4 + math.random() * 5
			local c = center or (cam and cam.CFrame.Position) or Vector3.zero
			local a = math.random() * math.pi * 2
			local r = 70 + math.random() * 80
			bolt(Vector3.new(c.X + math.cos(a) * r, c.Y, c.Z + math.sin(a) * r))
		end
	end)
	storm = { Grade = grade, Atm = atm, Was = was, Host = host, Conn = conn, Zone = Zone.Current }
end
local function stormOff()
	if not storm then return end
	local s = storm
	storm = nil
	s.Conn:Disconnect()
	local pe = s.Host:FindFirstChildOfClass("ParticleEmitter")
	if pe then pe.Enabled = false end
	task.delay(1.5, function() s.Host:Destroy() end)
	TweenService:Create(s.Grade, TweenInfo.new(1.5), { Saturation = 0, Brightness = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	task.delay(1.6, function() s.Grade:Destroy() end)
	if s.Atm and s.Was and Zone.Current == s.Zone then
		local look = Zone.Look()
		local a = look and look.Atmosphere or { Density = s.Was[1], Haze = s.Was[2], Color = s.Was[3], Glare = s.Was[4], Decay = s.Was[5] }
		TweenService:Create(s.Atm, TweenInfo.new(1.6), { Density = a.Density, Haze = a.Haze, Color = a.Color, Glare = a.Glare, Decay = a.Decay }):Play()
	end
end

-- the boss in the whiteout: a ghost of itself, eyes burning
local function stepStalkers()
	if not Exp then return end
	for cfg, c in pairs(Exp.Creatures()) do
		if cfg:GetAttribute("Boss") and c.Model then
			local stalking = cfg:GetAttribute("State") == "Stalk" and white ~= nil
			local want = stalking and 0.82 or 0
			local now = c.StalkFade or 0
			if math.abs(now - want) > 0.01 then
				now += (want - now) * 0.15
				if math.abs(now - want) < 0.02 then now = want end
				c.StalkFade = now
				c.StalkParts = c.StalkParts or c.Model:GetDescendants()
				for _, d in ipairs(c.StalkParts) do
					if d:IsA("BasePart") and not CollectionService:HasTag(d, "DinoEye") then
						d.LocalTransparencyModifier = math.max(d.LocalTransparencyModifier, now)
						if now == 0 then d.LocalTransparencyModifier = 0 end
					end
				end
			end
			if stalking and os.clock() >= (c.EyesAt or 0) then
				c.EyesAt = os.clock() + 1.5
				DinosaurVFX.EyeGlow(c.Model, 1.6)
			end
		end
	end
end

local function watchSite()
	local key = player:GetAttribute("Site")
	local on, wet = false, false
	local f = nil
	if typeof(key) == "string" then
		f = Sites:FindFirstChild(((key :: string):gsub("/", "_")))
		on = f ~= nil and f:GetAttribute("Whiteout") == true
		local ph = f and f:GetAttribute("Phase") or 0
		wet = f ~= nil and f:GetAttribute("Storm") == true and ph >= 1 and ph <= 3
	end
	if on then whiteOn() else whiteOff() end
	if wet then
		-- (the storm centres on the boss: the lightning strikes round the arena, not round you)
		local centre, ko = nil, false
		if Exp then
			for cfg, c in pairs(Exp.Creatures()) do
				if cfg:GetAttribute("Boss") and cfg:GetAttribute("Site") == key then
					if c.Root then centre = c.Root.Position end
					-- (2026-10-14: knocked out = the storm breaks. It used to rage on over the egg nest until the den reset)
					if cfg:GetAttribute("State") == "KO" then ko = true end
				end
			end
		end
		if ko then stormOff() else stormOn(centre) end
	else
		stormOff()
	end
end

--------------------------------------------------------------------------------
-- the boss itself: enraged aura, the sea boss's fin wake and its dazed wallow
--------------------------------------------------------------------------------
local auras = {} :: { [Configuration]: any }
local wakes = {} :: { [Configuration]: any } -- (the fin wakes alive right now: swept when their creature goes)
local function endWake(c)
	local h = c.WakeHost :: BasePart?
	c.WakeHost = nil
	if c.WakeSound then c.WakeSound:Destroy() c.WakeSound = nil end
	if not h then return end
	local pe = h:FindFirstChildOfClass("ParticleEmitter")
	if pe then pe.Enabled = false end
	task.delay(1, function() h:Destroy() end)
end
local AURA = {
	Frostfang = { Color3.fromRGB(200, 236, 255), Color3.fromRGB(150, 210, 255) },
	Tidebreaker = { Color3.fromRGB(220, 245, 255), Color3.fromRGB(120, 200, 240) },
}
local function bossIdOf(cfg: Configuration): string?
	local key = cfg:GetAttribute("Site")
	local era = typeof(key) == "string" and (key :: string):match("^(.-)/") or nil
	for id, b in pairs(Config.Bosses) do if b.Era == era then return id end end
	return nil
end
local function makeAura(cfg: Configuration, c)
	local id = bossIdOf(cfg)
	local boss = id and Config.Bosses[id]
	local pal = (id and AURA[id]) or { (boss and boss.Color) or Color3.fromRGB(255, 120, 60), Color3.fromRGB(255, 70, 30) }
	local bb, size = c.Model:GetBoundingBox()
	-- (a box the size of the body, following its root: the embers pour off all of it, not one point)
	local att = fxPart({ Name = "DinoRageAura", Transparency = 1, Size = size * Vector3.new(0.6, 0.5, 0.6) })
	local offset = c.Root.CFrame:ToObjectSpace(bb)
	local hot = not (id and AURA[id])
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Rate = 22
	embers.Lifetime = NumberRange.new(0.8, 1.4)
	embers.Speed = NumberRange.new(4, 9)
	embers.SpreadAngle = Vector2.new(60, 60)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Acceleration = Vector3.new(0, hot and 6 or 2, 0)
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	embers.Color = ColorSequence.new(pal[1], pal[2])
	embers.LightEmission = 0.8
	embers.Shape = Enum.ParticleEmitterShape.Box
	embers.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	embers.Parent = att
	local haze = Instance.new("ParticleEmitter")
	haze.Texture = "rbxasset://textures/particles/smoke_main.dds"
	haze.Rate = 8
	haze.Lifetime = NumberRange.new(1, 1.6)
	haze.Speed = NumberRange.new(2, 4)
	haze.SpreadAngle = Vector2.new(40, 40)
	haze.EmissionDirection = Enum.NormalId.Top
	haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size.Y * 0.25), NumberSequenceKeypoint.new(1, size.Y * 0.6) })
	haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
	haze.Color = ColorSequence.new(hot and Color3.fromRGB(120, 40, 30) or pal[1])
	haze.Parent = att
	local light = Instance.new("PointLight")
	light.Color = pal[1]
	light.Range = math.clamp(size.Magnitude * 0.5, 8, 24)
	light.Brightness = 1.2
	light.Parent = att
	return { Att = att, Offset = offset, EyesAt = 0 }
end

local function stepBosses(dt: number)
	if not Exp then return end
	local here = player:GetAttribute("Site")
	for cfg, c in pairs(Exp.Creatures()) do
		if not (cfg:GetAttribute("Boss") and c.Model and c.Root) then continue end
		local state = cfg:GetAttribute("State")
		-- enraged: smouldering, eyes burning
		local angry = cfg:GetAttribute("Enraged") == true and cfg:GetAttribute("Site") == here and state ~= "KO" and state ~= "Hidden"
		local a = auras[cfg]
		if angry and not a then
			local ok, made = pcall(makeAura, cfg, c)
			if ok then auras[cfg] = made a = made end
		elseif not angry and a then
			-- (knocked out: the fire goes out - the embers stop, one last breath of smoke, the glow fades. 2026-10-14)
			local att = a.Att
			auras[cfg] = nil
			a = nil
			if state == "KO" and att.Parent then
				for _, d in ipairs(att:GetChildren()) do
					if d:IsA("ParticleEmitter") then
						d.Enabled = false
						if d.Texture:find("smoke") then d:Emit(6) end
					elseif d:IsA("PointLight") then
						TweenService:Create(d, TweenInfo.new(0.8), { Brightness = 0 }):Play()
					end
				end
				task.delay(1.8, function() att:Destroy() end)
			else
				att:Destroy()
			end
		end
		if a then a.Att.CFrame = c.Root.CFrame * a.Offset end
		if a and os.clock() >= a.EyesAt then
			a.EyesAt = os.clock() + 1.4
			DinosaurVFX.EyeGlow(c.Model, 1.5)
		end
		-- the sea boss
		if c.Swim then
			-- the fin cutting toward you: spray off it, and the rush of water
			local fin = state == "Submerge" and cfg:GetAttribute("Fin") == true
			if fin then
				local at = Vector3.new(c.Root.Position.X, c.WaterY or 0, c.Root.Position.Z)
				if os.clock() >= (c.WakeAt or 0) then
					c.WakeAt = os.clock() + 0.08
					DinosaurVFX.Cubes(at + Vector3.new(0, 0.4, 0), 3, WATER, 0.35, 11, 0.5)
				end
				if not c.WakeHost then
					local h = fxPart({ Transparency = 1, Size = Vector3.one })
					c.WakeHost = h
					wakes[cfg] = c
					c.WakeSound = Audio.Loop("SwimLoop", h)
					local pe = Instance.new("ParticleEmitter")
					pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
					pe.Rate = 40
					pe.Lifetime = NumberRange.new(0.5, 0.9)
					pe.Speed = NumberRange.new(3, 7)
					pe.SpreadAngle = Vector2.new(50, 50)
					pe.EmissionDirection = Enum.NormalId.Top
					pe.Acceleration = Vector3.new(0, -12, 0)
					pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 2.6) })
					pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
					pe.Color = ColorSequence.new(WATER[3])
					pe.Parent = h
				end
				(c.WakeHost :: BasePart).Position = at
			elseif c.WakeHost then
				endWake(c)
				wakes[cfg] = nil
			end
			-- knocked silly in the water (after a breach, shaken loose, the whirlpool spun out): stars
			if state ~= c.FxState and state == "Recover" then DinosaurVFX.Stunned(c.Model, 2.6) end
			-- up on a deck, wallowing for breath: puffs of spray out of it
			if state == "Exhausted" and os.clock() >= (c.PuffAt or 0) then
				c.PuffAt = os.clock() + 1.3
				DinosaurVFX.Burst(CFrame.new(c.Root.Position + Vector3.new(0, 2, 0)), 10, { Color = WATER[3], Speed = NumberRange.new(8, 14), Spread = Vector2.new(20, 20), Acceleration = Vector3.new(0, -20, 0) })
			end
		end
		c.FxState = state
	end
	-- (a creature that's gone - destroyed, or dropped when you left the site - takes its aura and its fin wake's
	-- looping rush of water with it: before, they could be left behind with the loop playing on)
	local live = Exp.Creatures()
	for cfg, a in pairs(auras) do
		if not cfg.Parent or not live[cfg] then a.Att:Destroy() auras[cfg] = nil end
	end
	for cfg, c in pairs(wakes) do
		if not cfg.Parent or live[cfg] ~= c then endWake(c) wakes[cfg] = nil end
	end
	local _ = dt
end

--------------------------------------------------------------------------------
-- rolling crests (a shockwave over the ground, a ripple over water): rings of blocks that roll out at the same
-- speed the server times the hits to. curve(u) -> 0..1 how far across the band the crest is
--------------------------------------------------------------------------------
local function crestRing(o: Vector3, from: number, to: number, t: number, colors: { Color3 }, height: number, curve: (number) -> number)
	local n = 44
	local blocks = {}
	for k = 1, n do
		local a = (k / n) * math.pi * 2
		local b = fxPart({ Material = Enum.Material.SmoothPlastic, Color = colors[(k % #colors) + 1], Transparency = 0.15, Size = Vector3.new(1, 0.2, 2) })
		blocks[k] = { Part = b, A = a }
	end
	task.spawn(function()
		local t0 = os.clock()
		while true do
			local u = (os.clock() - t0) / t
			if u >= 1.15 then break end
			local r = from + (to - from) * curve(math.clamp(u, 0, 1))
			local h = (u <= 1 and math.sin(math.clamp(u * 1.2, 0, 1) * math.pi * 0.5) or (1 - (u - 1) / 0.15)) * height + 0.3
			local w = (2 * math.pi * r) / n + 0.6
			for _, bk in ipairs(blocks) do
				bk.Part.Size = Vector3.new(w, h, 2)
				bk.Part.CFrame = CFrame.new(o + Vector3.new(math.cos(bk.A) * r, h / 2, math.sin(bk.A) * r)) * CFrame.Angles(0, -bk.A - math.pi / 2, 0) -- (long side along the ring)
				bk.Part.Transparency = u > 1 and math.clamp(0.15 + (u - 1) * 6, 0, 1) or 0.15
			end
			RunService.Heartbeat:Wait()
		end
		for _, bk in ipairs(blocks) do bk.Part:Destroy() end
	end)
end

-- a dark shadow on the ground, growing and darkening until whatever's falling lands
local function shadow(at: Vector3, r: number, t: number)
	local s = fxPart({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = Color3.new(0, 0, 0), Transparency = 0.85,
		Size = Vector3.new(0.12, r * 0.4, r * 0.4), CFrame = CFrame.new(at + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	TweenService:Create(s, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0.12, r * 2, r * 2), Transparency = 0.35 }):Play()
	task.delay(t + 0.05, function() s:Destroy() end)
end

--------------------------------------------------------------------------------
-- the arena's hazards: each prop lands exactly when its red shape does
--------------------------------------------------------------------------------
local function fallingTree(o: Vector3, dir: Vector3, len: number, t: number)
	local g = ground(o)
	local H = len * 0.9
	local hinge = CFrame.lookAt(g, g + Vector3.new(dir.X, 0, dir.Z))
	local trunk = fxPart({ Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 76, 46), Size = Vector3.new(1.8, H, 1.8) })
	local leaves = {}
	for k = 1, 3 do
		local s = 6.5 - k * 1.2
		table.insert(leaves, { Part = fxPart({ Material = Enum.Material.Grass, Color = Color3.fromRGB(63 + k * 10, 154 + k * 8, 58), Size = Vector3.new(s, s * 0.8, s) }), Y = H - 1 + (k - 1) * 2.2, X = (k - 2) * 0.8 })
	end
	local function place(theta: number, shake: number)
		local cf = hinge * CFrame.Angles(-theta, 0, shake)
		trunk.CFrame = cf * CFrame.new(0, H / 2, 0)
		for _, l in ipairs(leaves) do l.Part.CFrame = cf * CFrame.new(l.X, l.Y, 0) end
	end
	place(0, 0)
	DinosaurVFX.FoliageBurst(g + Vector3.new(0, H, 0), 1.2) -- (shaken loose at the edge of the clearing)
	-- it shudders, creaks, then goes over
	task.spawn(function()
		local t0 = os.clock()
		local creak = false
		while true do
			local el = os.clock() - t0
			if el >= t then break end
			local u = el / t
			if u < 0.55 then
				place(0, math.sin(el * 30) * 0.03 * u)
			else
				if not creak then
					creak = true
					Audio.Play("Clunk", { At = g, Volume = 1.1, Pitch = 0.5 })
					DinosaurVFX.FallingLeaves(g + dir * len * 0.5, 4, 10, H)
				end
				local f = (u - 0.55) / 0.45
				place((f * f) * math.pi / 2, 0) -- (gravity: slow to start, slamming at the end)
			end
			RunService.Heartbeat:Wait()
		end
		place(math.pi / 2, 0)
		-- TIMBER
		local mid = g + Vector3.new(dir.X, 0, dir.Z).Unit * len * 0.6
		DinosaurVFX.FoliageBurst(g + Vector3.new(dir.X, 0, dir.Z).Unit * (H - 1), 1.6)
		DinosaurVFX.DustWave(g, Vector3.new(dir.X, 0, dir.Z).Unit, len / 20)
		DinosaurVFX.Shake(1.1 * nearness(mid, 90), 0.4)
		Audio.Play("StompBig", { At = mid, Volume = 1.2, Pitch = 0.75 })
		task.delay(1.4, function()
			for _, p in ipairs({ trunk, leaves[1].Part, leaves[2].Part, leaves[3].Part }) do
				TweenService:Create(p, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
			task.delay(0.55, function()
				trunk:Destroy()
				for _, l in ipairs(leaves) do l.Part:Destroy() end
			end)
		end)
	end)
end

local function fissure(o: Vector3, dir: Vector3, len: number, t: number)
	local a, b = ground(o), ground(o + dir * len)
	local crack = fxPart({ Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 40), Transparency = 0.6, Size = Vector3.new(0.2, 0.15, len),
		CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.2, 0), b + Vector3.new(0, 0.2, 0)) })
	TweenService:Create(crack, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(2.2, 0.15, len), Transparency = 0 }):Play()
	-- the ground grumbles under it
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < t do
			DinosaurVFX.Cubes(a:Lerp(b, math.random()) + Vector3.new(0, 0.3, 0), 2, DIRT, 0.3, 6, 0.5)
			task.wait(0.12)
		end
		-- it bursts open along its whole length
		for k = 0, 4 do
			local p = a:Lerp(b, k / 4)
			DinosaurVFX.Cubes(p + Vector3.new(0, 0.5, 0), 8, { DIRT[1], DIRT[2], Color3.fromRGB(255, 150, 50) }, 0.55, 24, 1)
			DinosaurVFX.GroundImpact(p, 0.9)
		end
		DinosaurVFX.Shake(0.9 * nearness((a + b) / 2, 90), 0.4)
		Audio.Play("StompBig", { At = (a + b) / 2, Volume = 1.1, Pitch = 0.55 })
		TweenService:Create(crack, TweenInfo.new(1.2), { Transparency = 1, Color = Color3.fromRGB(60, 40, 30) }):Play()
		task.delay(1.3, function() crack:Destroy() end)
	end)
end

local function dropFromSky(at: Vector3, r: number, t: number, kind: string)
	local g = ground(at)
	shadow(g, r, t)
	local fall = math.min(0.7, t * 0.8)
	task.delay(t - fall, function()
		local obj: BasePart
		local height = 60
		if kind == "Icicle" then
			obj = fxPart({ Material = Enum.Material.Ice, Color = Color3.fromRGB(190, 230, 255), Transparency = 0.15, Size = Vector3.new(1.6, 7, 1.6) })
		else
			obj = fxPart({ Material = Enum.Material.Slate, Color = Color3.fromRGB(150, 82, 60), Size = Vector3.new(r * 0.9, r * 0.8, r * 0.9) })
		end
		local spin = math.random() * 6
		local t0 = os.clock()
		while true do
			local u = math.clamp((os.clock() - t0) / fall, 0, 1)
			local y = g.Y + height * (1 - u * u) + obj.Size.Y / 2
			obj.CFrame = CFrame.new(g.X, y, g.Z) * (kind == "Icicle" and CFrame.identity or CFrame.Angles(u * spin, u * spin * 0.7, 0))
			if u >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		if kind == "Icicle" then
			DinosaurVFX.Cubes(g + Vector3.new(0, 1, 0), 12, { Color3.fromRGB(190, 230, 255), Color3.fromRGB(240, 250, 255) }, 0.4, 18, 0.8)
			Audio.Play("Glance", { At = g, Volume = 1.2, Pitch = 1.5 })
			obj:Destroy()
		else
			DinosaurVFX.Debris(g + Vector3.new(0, 1, 0), r / 4, Color3.fromRGB(150, 82, 60))
			Audio.Play("StompBig", { At = g, Volume = 1.1, Pitch = 0.9 })
			TweenService:Create(obj, TweenInfo.new(0.8), { Transparency = 1, Size = obj.Size * 0.6 }):Play()
			task.delay(0.85, function() obj:Destroy() end)
		end
		DinosaurVFX.GroundCracks(g, r / 5)
		DinosaurVFX.Shake(0.8 * nearness(g, 70), 0.3)
	end)
end

local function geyser(at: Vector3, r: number, t: number)
	local g = ground(at)
	local SAND = { Color3.fromRGB(214, 170, 112), Color3.fromRGB(176, 130, 84), Color3.fromRGB(235, 200, 140) }
	task.spawn(function()
		local t0 = os.clock()
		-- the sand bubbles and sinks, faster as it builds
		while os.clock() - t0 < t do
			local u = (os.clock() - t0) / t
			local a = math.random() * math.pi * 2
			DinosaurVFX.Cubes(g + Vector3.new(math.cos(a), 0, math.sin(a)) * r * math.random() * 0.8 + Vector3.new(0, 0.2, 0), 2, SAND, 0.3, 5 + u * 8, 0.4)
			task.wait(0.1 - u * 0.06)
		end
		-- WHOOSH: a column of sand
		local col = fxPart({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Sand, Color = SAND[1], Size = Vector3.new(1, r * 1.4, r * 1.4), CFrame = CFrame.new(g) * CFrame.Angles(0, 0, math.pi / 2) })
		TweenService:Create(col, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(16, r * 1.1, r * 1.1), CFrame = CFrame.new(g + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.pi / 2) }):Play()
		task.delay(0.3, function()
			TweenService:Create(col, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.new(20, r * 0.6, r * 0.6) }):Play()
			task.delay(0.65, function() col:Destroy() end)
		end)
		DinosaurVFX.Cubes(g + Vector3.new(0, 1, 0), 18, SAND, 0.5, 30, 1.2)
		DinosaurVFX.Burst(CFrame.new(g), 16, { Color = SAND[3], Speed = NumberRange.new(12, 24), Spread = Vector2.new(20, 20), Acceleration = Vector3.new(0, -20, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) }) })
		DinosaurVFX.Shake(0.7 * nearness(g, 70), 0.3)
		Audio.Play("Splash", { At = g, Volume = 1.0, Pitch = 0.55 })
	end)
end

local function hazard(info)
	local at = typeof(info.At) == "Vector3" and info.At or nil
	if not at then return end
	local t = tonumber(info.Time) or 1.3
	local dir = typeof(info.Dir) == "Vector3" and (info.Dir :: Vector3) or Vector3.new(0, 0, -1)
	if info.Kind == "Tree" then fallingTree(at, dir, tonumber(info.Len) or 26, t)
	elseif info.Kind == "Fissure" then fissure(at, dir, tonumber(info.Len) or 28, t)
	elseif info.Kind == "Boulder" or info.Kind == "Icicle" then dropFromSky(at, tonumber(info.R) or 5, t, info.Kind)
	elseif info.Kind == "Geyser" then geyser(at, tonumber(info.R) or 5, t) end
end

-- the set piece: the roar that turns the arena
local function arenaShift(info)
	local c = creatureById(info.Actor)
	local at = (c and c.Root and c.Root.Position) or (typeof(info.At) == "Vector3" and info.At) or nil
	if not at then return end
	local centre = typeof(info.Center) == "Vector3" and info.Center or at
	local R = tonumber(info.Radius) or 40
	Audio.Play("RoarBoss", { At = at, Volume = 1.4, Range = 400 })
	if c and c.Model then
		DinosaurVFX.EyeGlow(c.Model, 3)
		local head = DinosaurVFX.findAttachment(c.Model, "VFX_Head")
		if head then DinosaurVFX.RoarShockwave(head.WorldCFrame, DinosaurVFX.ModelScale(c.Model) * 1.4) end
	end
	CineKit.ImpactFrame(0.45)
	DinosaurVFX.Shake(1.6, 1.4)
	DinosaurVFX.BlockRing(CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 32, R0 = 2, R1 = R, Color = Color3.fromRGB(255, 226, 150), Duration = 0.9, Block = 1 })
	-- what the arena turns into, all at once: the first taste of its hazard (just for show)
	if info.Kind == "Tree" then
		DinosaurVFX.FallingLeaves(centre, R * 0.7, 70, 26)
	elseif info.Kind == "Fissure" then
		for k = 1, 6 do
			local a = k / 6 * math.pi * 2
			local p = ground(centre + Vector3.new(math.cos(a), 0, math.sin(a)) * R * 0.6)
			task.delay(k * 0.08, function() DinosaurVFX.GroundCracks(p, 2.5) DinosaurVFX.GroundImpact(p, 1.2) end)
		end
	elseif info.Kind == "Boulder" or info.Kind == "Icicle" then
		for _ = 1, 26 do
			local p = centre + Vector3.new((math.random() * 2 - 1) * R * 0.8, 22 + math.random() * 10, (math.random() * 2 - 1) * R * 0.8)
			DinosaurVFX.Cubes(p, 1, info.Kind == "Icicle" and { Color3.fromRGB(220, 240, 255) } or { Color3.fromRGB(150, 82, 60), Color3.fromRGB(120, 70, 50) }, info.Kind == "Icicle" and 0.4 or 0.7, 4, 2.2)
		end
	elseif info.Kind == "Geyser" then
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2 + 0.4
			local p = centre + Vector3.new(math.cos(a), 0, math.sin(a)) * R * 0.55
			task.delay(k * 0.12, function()
				DinosaurVFX.Burst(CFrame.new(ground(p)), 12, { Color = Color3.fromRGB(235, 200, 140), Speed = NumberRange.new(14, 26), Spread = Vector2.new(15, 15), Acceleration = Vector3.new(0, -20, 0),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) }) })
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- the land bosses' new moves
--------------------------------------------------------------------------------
local function razorBlade(o: Vector3, dir: Vector3, len: number, speed: number)
	local d = Vector3.new(dir.X, 0, dir.Z).Unit
	local side = d:Cross(Vector3.yAxis)
	local blocks = {}
	for k = -4, 4 do
		local a = k / 4 * 1.1
		local off = side * math.sin(a) * 3.4 - d * (1 - math.cos(a)) * 2.2
		table.insert(blocks, { Part = fxPart({ Material = Enum.Material.Neon, Color = k == 0 and Color3.new(1, 1, 1) or Color3.fromRGB(255, 236, 170), Transparency = 0.1, Size = Vector3.new(0.9, 0.5, 0.9) }), Off = off })
	end
	Audio.Play("Snap", { At = o, Volume = 1.2, Pitch = 1.5 })
	task.spawn(function()
		local t0 = os.clock()
		local dur = len / speed
		local lastPuff = 0
		while true do
			local u = math.clamp((os.clock() - t0) / dur, 0, 1)
			local p = ground(o + d * len * u) + Vector3.new(0, 2.4, 0)
			for _, b in ipairs(blocks) do b.Part.CFrame = CFrame.lookAt(p + b.Off, p + b.Off + d) end
			if os.clock() - lastPuff > 0.06 then
				lastPuff = os.clock()
				DinosaurVFX.Cubes(p - Vector3.new(0, 2, 0), 2, { Color3.fromRGB(196, 120, 80), Color3.fromRGB(150, 100, 70) }, 0.3, 8, 0.4)
			end
			if u >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		for _, b in ipairs(blocks) do
			TweenService:Create(b.Part, TweenInfo.new(0.2), { Transparency = 1 }):Play()
			task.delay(0.22, function() b.Part:Destroy() end)
		end
	end)
end

local function iceSpikes(o: Vector3, dir: Vector3, len: number, gap: number, speed: number)
	local d = Vector3.new(dir.X, 0, dir.Z).Unit
	local n = math.floor(len / gap)
	for k = 1, n do
		task.delay(k * gap / speed, function()
			local g = ground(o + d * k * gap)
			local h = 5 + math.random() * 2.5
			local tilt = CFrame.Angles((math.random() - 0.5) * 0.4, math.random() * 6, (math.random() - 0.5) * 0.4)
			local s = fxPart({ Material = Enum.Material.Ice, Color = Color3.fromRGB(180, 225, 255), Transparency = 0.1, Size = Vector3.new(2, 0.3, 2), CFrame = CFrame.new(g) * tilt })
			TweenService:Create(s, TweenInfo.new(0.09, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(1.8, h, 1.8), CFrame = CFrame.new(g + Vector3.new(0, h / 2 - 0.4, 0)) * tilt }):Play()
			DinosaurVFX.Cubes(g + Vector3.new(0, 0.5, 0), 4, { Color3.fromRGB(220, 240, 255), Color3.new(1, 1, 1) }, 0.35, 12, 0.6)
			if k % 2 == 1 then Audio.Play("Glance", { At = g, Volume = 0.9, Pitch = 1.3 + math.random() * 0.4, Gap = 0.05 }) end
			if k % 3 == 0 then DinosaurVFX.Shake(0.35 * nearness(g, 50), 0.15) end
			task.delay(1.1, function()
				DinosaurVFX.Cubes(g + Vector3.new(0, h * 0.5, 0), 5, { Color3.fromRGB(190, 230, 255) }, 0.4, 10, 0.6)
				TweenService:Create(s, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(1.2, h * 0.5, 1.2) }):Play()
				task.delay(0.3, function() s:Destroy() end)
			end)
		end)
	end
end

-- the sand trap: a sinkhole spinning round its jaws, dragging you in (run against it)
local trap = nil :: any
local function sandTrap(info)
	if trap then
		trap.Fx:Destroy()
		if trap.Sound then trap.Sound:Destroy() end
		trap = nil
	end
	local t = tonumber(info.Time) or 0
	if t <= 0 or typeof(info.At) ~= "Vector3" then return end
	local o = ground(info.At)
	local R = tonumber(info.R) or 32
	local fx = Instance.new("Model")
	fx.Name = "DinoSandTrap"
	local rings = {}
	for k = 1, 3 do
		local rr = R * (0.35 + k * 0.2)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Sand
		p.Color = k == 1 and Color3.fromRGB(150, 108, 66) or Color3.fromRGB(214, 170, 112)
		p.Transparency = 0.25 + k * 0.15
		p.Size = Vector3.new(0.2, rr * 2, rr * 2)
		p.Parent = fx
		rings[k] = p
	end
	fx.Parent = Workspace
	local host = rings[1]
	local sound = Audio.Loop("Whirlpool", host)
	if sound then sound.PlaybackSpeed = 0.6 end
	trap = { O = o, R = R, Inner = tonumber(info.Inner) or 9, Pull = tonumber(info.Pull) or 8, Until = os.clock() + t, Fx = fx, Rings = rings, Sound = sound, T0 = os.clock(), Time = t }
	DinosaurVFX.Shake(0.8, 0.5)
end
local function stepTrap(dt: number)
	if not trap then return end
	local now = os.clock()
	if now > trap.Until then
		trap.Fx:Destroy()
		if trap.Sound then trap.Sound:Destroy() end
		trap = nil
		return
	end
	local u = (now - trap.T0) / trap.Time
	for k, r in ipairs(trap.Rings) do
		-- the pit sinks as it spins up
		r.CFrame = CFrame.new(trap.O + Vector3.new(0, 0.15 - u * 0.5 * (4 - k) * 0.3, 0)) * CFrame.Angles(0, now * (1.2 + k * 0.7), 0) * CFrame.Angles(0, 0, math.pi / 2)
	end
	if math.random() < 0.6 then
		local a = math.random() * math.pi * 2
		local rr = trap.R * (0.4 + math.random() * 0.6)
		DinosaurVFX.Cubes(trap.O + Vector3.new(math.cos(a) * rr, 0.4, math.sin(a) * rr), 1, { Color3.fromRGB(214, 170, 112), Color3.fromRGB(176, 130, 84) }, 0.35, 4, 0.5)
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- (only a hunter on foot in the fight is dragged: out of the site, or sat in a rover, sliding the root would drag
	-- the whole vehicle - 2026-10-14)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local inFight = player:GetAttribute("Site") ~= nil and not (hum and hum.SeatPart)
	if hrp and not hrp.Anchored and inFight then
		local d = Vector3.new(trap.O.X - hrp.Position.X, 0, trap.O.Z - hrp.Position.Z)
		if d.Magnitude < trap.R and d.Magnitude > 1.5 and math.abs(hrp.Position.Y - trap.O.Y) < 10 then
			-- (slides the body - the walk controller would undo a velocity nudge - so running out against it works)
			local pull = d.Unit * trap.Pull * (1 - d.Magnitude / trap.R * 0.5) * math.clamp(u * 3, 0, 1)
			local swirl = Vector3.new(-d.Unit.Z, 0, d.Unit.X) * trap.Pull * 0.3
			hrp.CFrame += (pull + swirl) * dt
		end
	end
end

--------------------------------------------------------------------------------
function BossFx.Start(expView)
	Exp = expView
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(function()
			watchSite()
			stepStalkers()
			stepBosses(dt)
		end)
		if not ok then warn("[BossFx]", err) end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(stepTrap, dt)
		if not ok then warn("[BossFx] trap:", err) trap = nil end
	end)
	Net.On("BossMove", function(info)
		local at = typeof(info.At) == "Vector3" and info.At or nil
		local move = info.Move
		if move == "Crash" and at then
			DinosaurVFX.Debris(at + Vector3.new(0, 2, 0), 3, Color3.fromRGB(150, 138, 120))
			DinosaurVFX.GroundCracks(at, 3)
			CineKit.Burst(at + Vector3.new(0, 4, 0), 1.4, { Color3.fromRGB(150, 138, 120), Color3.fromRGB(110, 100, 90), Color3.fromRGB(200, 180, 150) })
			DinosaurVFX.Shake(1.4, 0.6, at, 140)
			Audio.Play("StompBig", { At = at, Volume = 1.4, Pitch = 0.6 })
			Audio.Play("Clunk", { At = at, Volume = 1.2, Pitch = 0.6 })
		elseif move == "GuardBreak" and at then
			DinosaurVFX.BlockRing(CFrame.new(at + Vector3.new(0, 6, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 24, R0 = 2, R1 = 16, Color = Color3.fromRGB(255, 226, 120), Duration = 0.5, Block = 0.8 })
			DinosaurVFX.Cubes(at + Vector3.new(0, 6, 0), 20, { Color3.new(1, 1, 1), Color3.fromRGB(255, 220, 140) }, 0.3, 26, 0.6)
			CineKit.HitStop(0.12, 0, 0.2)
			Audio.Play("Perfect", { Pitch = 0.8 })
		-- the arena turns + its hazards
		elseif move == "ArenaShift" then
			arenaShift(info)
		elseif move == "Hazard" then
			hazard(info)
		-- the new moves
		elseif move == "Chomp" and at then
			DinosaurVFX.BiteImpact(at + Vector3.new(0, 3, 0), info.Big and 2.2 or 1.4)
			Audio.Play("Snap", { At = at, Volume = info.Big and 1.5 or 1.1, Pitch = info.Big and 0.7 or 0.9 })
			DinosaurVFX.Shake((info.Big and 0.9 or 0.45) * nearness(at, 60), 0.25)
			if info.Big then CineKit.HitStop(0.06, 0.1, 0.12) end
		elseif move == "Shockwave" and at then
			local from, to, t = tonumber(info.From) or 5, tonumber(info.To) or 30, tonumber(info.Time) or 1.1
			crestRing(ground(at), from, to, t, DIRT, 2.6, function(u) return u end)
			DinosaurVFX.GroundCracks(at, 3)
			DinosaurVFX.GroundImpact(at, 2.4)
			DinosaurVFX.Shake(1.3 * math.max(0.35, nearness(at, 80)), 0.5)
			CineKit.ImpactFrame(0.3)
			Audio.Play("StompBig", { At = at, Volume = 1.5, Pitch = 0.5, Gap = 0.1 })
		elseif move == "Razor" and at and typeof(info.Dir) == "Vector3" then
			razorBlade(at, info.Dir, tonumber(info.Len) or 44, tonumber(info.Speed) or 50)
		elseif move == "Spikes" and at and typeof(info.Dir) == "Vector3" then
			iceSpikes(at, info.Dir, tonumber(info.Len) or 42, tonumber(info.Gap) or 4.5, tonumber(info.Speed) or 60)
		elseif move == "SandTrap" then
			sandTrap(info)
		elseif move == "Knockdown" and at then
			local g = ground(at)
			DinosaurVFX.GroundImpact(g, 2.6)
			DinosaurVFX.Debris(g + Vector3.new(0, 1, 0), 2, Color3.fromRGB(150, 120, 90))
			DinosaurVFX.Cubes(g + Vector3.new(0, 4, 0), 18, { Color3.new(1, 1, 1), Color3.fromRGB(255, 220, 120) }, 0.35, 24, 0.7)
			DinosaurVFX.Shake(1.5 * math.max(0.4, nearness(g, 90)), 0.6)
			CineKit.ImpactFrame(0.5)
			CineKit.HitStop(0.1, 0, 0.2)
			Audio.Play("StompBig", { At = g, Volume = 1.6, Pitch = 0.55 })
			Audio.Play("DinoHurt", { At = g, Volume = 1.3, Pitch = 0.7 })
		-- the sea boss
		elseif move == "Cannonball" then
			local c = creatureById(info.Actor)
			Audio.Play("SeaRoar", { At = (c and c.Root) or nil, Volume = 1.3, Range = 400 })
			if c and c.Model then DinosaurVFX.EyeGlow(c.Model, 2.5) end
		elseif move == "SeaShadow" and at then
			shadow(at, tonumber(info.R) or 11, tonumber(info.Time) or 1.5)
		elseif move == "Ripple" and at then
			local from, to, t = tonumber(info.From) or 11, tonumber(info.To) or 23, tonumber(info.Time) or 0.85
			-- (the same curve SeaKing times the hits to: the crest gathers, then rolls across the band)
			crestRing(at, from, to, t, WATER, 2.4, function(u) return math.clamp((u - 0.3) / 0.75, 0, 1) end)
		elseif move == "Flop" and at then
			DinosaurVFX.Cubes(at + Vector3.new(0, 1.5, 0), 22, WOOD, 0.5, 26, 1.2)
			DinosaurVFX.Cubes(at + Vector3.new(0, 1, 0), 26, WATER, 0.45, 30, 1)
			DinosaurVFX.BlockRing(CFrame.new(at + Vector3.new(0, 0.6, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 28, R0 = 3, R1 = 16, Color = WATER[2], Duration = 0.6, Block = 1 })
			DinosaurVFX.Shake(1.8 * math.max(0.35, nearness(at, 90)), 0.7)
			CineKit.ImpactFrame(0.5)
			CineKit.HitStop(0.08, 0.05, 0.15)
			Audio.Play("StompBig", { At = at, Volume = 1.6, Pitch = 0.6 })
			Audio.Play("Clunk", { At = at, Volume = 1.2, Pitch = 0.5 })
		elseif move == "Beach" and at then
			DinosaurVFX.Cubes(at + Vector3.new(0, 1, 0), 14, WOOD, 0.4, 18, 1)
			DinosaurVFX.Shake(1.1 * math.max(0.3, nearness(at, 80)), 0.5)
			Audio.Play("Clunk", { At = at, Volume = 1.3, Pitch = 0.45 })
			Audio.Play("StompBig", { At = at, Volume = 1.2, Pitch = 0.7 })
		end
	end)
	local _ = Chasers
end

return BossFx
