--[[
	EncounterView — the on-foot fight, for the local player (and how everyone else looks doing it).

	  camera     over-the-shoulder: on keyboard + mouse the cursor locks and you aim with the mouse (hold ALT for
	             a free cursor); on gamepad the right stick aims; on touch you drag to look and FIRE auto-aims
	  launcher   tap to fire a dart, HOLD to charge a heavy dart; real darts fly, stick in the dino and pop
	             calm numbers. Darts into a staggered dino hit its glowing WEAK SPOT for double
	  dodge      Q / B / DODGE rolls (invulnerable mid-roll). Roll THROUGH an attack for a PERFECT DODGE:
	             the roll recharges and your next dart is a guaranteed weak-spot hit
	  lock-on    the dino you're aiming at gets a reticle with its calm bar; red when it's winding up
	  gadgets    1 / 2 (or the buttons): you throw them
	  telegraphs every attack is drawn on the ground and fills up before it lands: get out of the red
	  rodeo      when a big dino is exhausted, E jumps on: you ride it, keep the balance needle in the green
	  scramble   eggs burst out of the nest: run over them to scoop them up
	  downed     you crawl; a friend holds E on you to revive (they kneel and pump your chest)
	Player bodies are animated by PlayerAnim (procedural Motor6D, R6 + R15).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local Gear = require(DinoShared:WaitForChild("Game"):WaitForChild("Gear"))
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local DinosaurAnimations = require(DinoShared:WaitForChild("DinosaurAnimations"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)
local Panels = require(script.Parent.UI.Panels)
local RarityFx = require(script.Parent.RarityFx)
local PlayerAnim = require(script.Parent.PlayerAnim)
local C = Theme.C

local player = Players.LocalPlayer
local Runtime = DinoShared:WaitForChild("Runtime")
local Chasers = Runtime:WaitForChild("Chasers")
local SiteEggs = Runtime:WaitForChild("SiteEggs")
local Sites = Runtime:WaitForChild("Sites")
local EggT = DinoShared:WaitForChild("Eggs")

local View = {}
local Exp -- ExpeditionView (creature models)
local ui: any = {}
local active = false
local siteKey: string? = nil
local sprinting = false
local nextFire, nextDodge = 0, 0
local combo, comboT = 0, 0
local target: Configuration? = nil
local lastShot = 0
local charging: number? = nil -- os.clock() when the trigger went down
local charged = false -- a perfect dodge banked a weak-spot shot
local dodgingUntil = 0
local rodeo = nil :: any -- the ride in progress (startRodeo)
local freeCursor = false
local camOffset = Vector3.zero
local BASE_FOV = 70
local stepAwareness: (Configuration?) -> () -- defined with the sneak HUD

local function hrp(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function hum(): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function siteFolder(): Configuration?
	if not siteKey then return nil end
	for _, f in ipairs(Sites:GetChildren()) do if f:GetAttribute("Key") == siteKey then return f :: Configuration end end
	return nil
end
local function profileGear()
	return Net.Profile and Net.Profile.Gear or { Launcher = "Rookie", LauncherLvl = 1, Gadgets = { "", "" } }
end
local function launcherInfo()
	return Config.Launchers[profileGear().Launcher] or Config.Launchers.Rookie
end

--------------------------------------------------------------------------------
-- sound: every combat moment is an Audio slot (AUDIO.md); an empty slot is silent
--------------------------------------------------------------------------------
local SFX_SLOT = { Fire = "DartFire", Dry = "DryFire", Click = "Reload", Impact = "DartHit", Weak = "Glance", Dodge = "Dodge", Hurt = "PlayerHurt", Perfect = "Perfect", Charge = "ChargeReady", Heavy = "StompBig" }
local function sfx(name: string, at: Vector3?, pitch: number?)
	local slot = SFX_SLOT[name]
	if not slot then return end
	-- a heavy (charged) dart is a deeper shot
	local k = (name == "Fire" and pitch and pitch < 1.4) and 0.82 or 1
	require(script.Parent.Audio).Play(slot, { At = at, Pitch = k })
end

--------------------------------------------------------------------------------
-- the launcher in a hand (everyone at the site carries one; built locally on each client)
--------------------------------------------------------------------------------
local launchers = {} :: { [Model]: Model }
local function buildLauncher(char: Model, gearName: string?)
	local old = launchers[char]
	if old then old:Destroy() launchers[char] = nil end
	-- the tier's real model (tools/gen/gear.js), welded into the right hand
	local m = Gear.Hold(char, gearName or "Rookie")
	if not m then return nil end
	m.Name = "DinoLauncher"
	launchers[char] = m
	return m
end

local function muzzleOf(char: Model?): Vector3
	local m = char and launchers[char]
	local mz = Gear.Muzzle(m)
	if mz then return mz end
	local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return r and (r.Position + Vector3.new(0, 1.5, 0)) or Vector3.zero
end

--------------------------------------------------------------------------------
-- targets
--------------------------------------------------------------------------------
local FIGHTABLE = { Unaware = true, Idle = true, Chase = true, Telegraph = true, Attack = true, Recover = true, Stunned = true, Distracted = true, Exhausted = true, Perch = true, Leap = true }
-- the sea ruler: dart it while it swims, slams, drags someone or spins (not while it's deep under)
for _, st in ipairs({ "Swim", "TailSlam", "Grab", "Drag", "Whirl", "Breach" }) do FIGHTABLE[st] = true end
-- the land bosses' signature moves (not while it's under the sand or lost in the whiteout)
for _, st in ipairs({ "Roaring", "Guard", "Harvest", "Dazed", "Erupt" }) do FIGHTABLE[st] = true end

local function actorsHere(): { { Cfg: Configuration, Model: Model?, Root: BasePart? } }
	local list = {}
	local creatures = Exp and Exp.Creatures() or {}
	for _, cfg in ipairs(Chasers:GetChildren()) do
		if cfg:IsA("Configuration") and cfg:GetAttribute("Site") == siteKey and not cfg:GetAttribute("Buddy") and FIGHTABLE[cfg:GetAttribute("State") or ""] then
			local c = creatures[cfg]
			table.insert(list, { Cfg = cfg, Model = c and c.Model, Root = c and c.Root })
		end
	end
	return list
end

-- where a dart should land on a dino: its chest (or root, lifted)
local function aimPoint(cfg: Configuration): Vector3?
	local c = Exp and Exp.Creatures()[cfg]
	if c and c.Model then
		local chest = DinosaurVFX.findAttachment(c.Model, "VFX_Chest")
		if chest then return chest.WorldPosition end
		return c.Root.Position + Vector3.new(0, 1.5, 0)
	end
	local p = cfg:GetAttribute("P")
	return typeof(p) == "Vector3" and p or nil
end

-- the crosshair picks: whatever is closest to the screen centre inside a forgiving cone, else the nearest in front
local btCache = { At = -1, R = nil :: Configuration? }
local function bestTarget(screenPos: Vector2?): Configuration?
	-- (asked several times a frame for the crosshair: one real pick per frame)
	if not screenPos and os.clock() - btCache.At < 0.012 then return btCache.R end
	local r = hrp()
	if not r then return nil end
	local cam = Workspace.CurrentCamera
	local range = launcherInfo().Range
	local center = screenPos or (cam.ViewportSize / 2)
	local best, bestS = nil, -math.huge
	for _, a in ipairs(actorsHere()) do
		local p = aimPoint(a.Cfg)
		if not p then continue end
		local d = (p - r.Position).Magnitude
		if d > range then continue end
		local s = 600 - d * 2
		if a.Cfg:GetAttribute("Weak") then s += 250 end
		local sp, on = cam:WorldToViewportPoint(p)
		if on then
			local off = (Vector2.new(sp.X, sp.Y) - center).Magnitude / math.max(1, cam.ViewportSize.Y)
			s += 3000 - off * 9000 -- a dino under the crosshair wins
		else
			s -= 2500
		end
		if s > bestS then best, bestS = a.Cfg, s end
	end
	if not screenPos then btCache.At, btCache.R = os.clock(), best end
	return best
end

--------------------------------------------------------------------------------
-- feedback: floaters, hit flashes, darts
--------------------------------------------------------------------------------
local function floater(pos: Vector3, text: string, color: Color3, size: number?, rise: number?)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.Transparency = true, false, false, 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(pos)
	part.Parent = Workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 64)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = part
	local t = Kit.Text(bb, text, { Size = UDim2.fromScale(1, size or 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = color, Stroke = 4, Shadow = 3, MaxSize = 48 })
	Kit.Pop(t, 2)
	local side = (math.random() - 0.5) * 3
	TweenService:Create(part, TweenInfo.new(0.85, Enum.EasingStyle.Quad), { CFrame = CFrame.new(pos + Vector3.new(side, rise or 4, 0)) }):Play()
	task.delay(0.55, function()
		for _, l in ipairs(bb:GetDescendants()) do
			if l:IsA("TextLabel") then TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1 }):Play() end
			if l:IsA("UIStroke") then TweenService:Create(l, TweenInfo.new(0.3), { Transparency = 1 }):Play() end
		end
	end)
	task.delay(0.9, function() part:Destroy() end)
end

local function flashModel(model: Model?, color: Color3)
	if not model then return end
	local h = model:FindFirstChild("HitFlash") :: Highlight?
	if not h then
		h = Instance.new("Highlight")
		h.Name = "HitFlash"
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.OutlineTransparency = 1
		h.Parent = model
	end
	local hl = h :: Highlight
	hl.FillColor = color
	hl.FillTransparency = 0.25
	hl.Enabled = true
	-- (switched off once faded: an enabled Highlight costs a render pass even when invisible, and every dino
	-- or rover ever hit kept one - Roblox only draws 31 at all)
	local tw = TweenService:Create(hl, TweenInfo.new(0.18), { FillTransparency = 1 })
	tw.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and hl.FillTransparency >= 0.99 then hl.Enabled = false end
	end)
	tw:Play()
end

local function dartModel(color: Color3, heavy: boolean): Model
	local m = Instance.new("Model")
	m.Name = "Dart"
	local function p(size: Vector3, cf: CFrame, col: Color3, mat: Enum.Material?)
		local q = Instance.new("Part")
		q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch, q.CastShadow = true, false, false, false, false
		q.Size = size
		q.Color = col
		q.Material = mat or Enum.Material.SmoothPlastic
		q.CFrame = cf
		q.Parent = m
		return q
	end
	local k = heavy and 1.6 or 1
	local body = p(Vector3.new(0.22, 0.22, 1.3) * k, CFrame.new(), Color3.fromRGB(230, 236, 242), Enum.Material.Metal)
	p(Vector3.new(0.16, 0.16, 0.5) * k, CFrame.new(0, 0, -0.85 * k), Color3.fromRGB(120, 255, 140), Enum.Material.Neon)
	for i = 0, 2 do p(Vector3.new(0.05, 0.42, 0.42) * k, CFrame.new(0, 0, 0.6 * k) * CFrame.Angles(0, 0, i * math.pi / 3), color) end
	m.PrimaryPart = body
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.08, 0.5)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.08, 0.5)
	a1.Parent = body
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.12
	tr.LightEmission = 1
	tr.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.WidthScale = NumberSequence.new(heavy and 3 or 1.6, 0)
	tr.Parent = body
	m.Parent = Workspace
	return m
end

-- a dart flies from a muzzle to a point on a dino, sticks in and fades; onLand fires at impact
local function flyDart(from: Vector3, cfg: Configuration?, to: Vector3, color: Color3, heavy: boolean, onLand: ((Vector3) -> ())?)
	local m = dartModel(color, heavy)
	local creature = cfg and Exp and Exp.Creatures()[cfg]
	local rel = creature and creature.Root and creature.Root.CFrame:PointToObjectSpace(to) or nil
	local dist = (to - from).Magnitude
	local dur = math.clamp(dist / 230, 0.05, 0.42)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		-- the target keeps moving: home in on where it is now
		local goal = (rel and creature and creature.Root and creature.Root.Parent) and creature.Root.CFrame:PointToWorldSpace(rel) or to
		local u = math.clamp((os.clock() - t0) / dur, 0, 1)
		local arc = math.sin(u * math.pi) * math.min(2.4, dist * 0.03)
		local p = from:Lerp(goal, u) + Vector3.new(0, arc, 0)
		local ahead = from:Lerp(goal, math.min(1, u + 0.05)) + Vector3.new(0, math.sin(math.min(1, u + 0.05) * math.pi) * math.min(2.4, dist * 0.03), 0)
		if (ahead - p).Magnitude > 0.01 then m:PivotTo(CFrame.lookAt(p, ahead)) end
		if u >= 1 then
			conn:Disconnect()
			if onLand then onLand(goal) end
			-- stick in for a moment, riding the dino
			local stuckT = os.clock()
			local dir = (goal - from).Unit
			local stickRel = (creature and creature.Root and creature.Root.Parent) and creature.Root.CFrame:ToObjectSpace(CFrame.lookAt(goal - dir * 0.4, goal + dir)) or nil
			local c2
			c2 = RunService.RenderStepped:Connect(function()
				if os.clock() - stuckT > 1.1 or not m.Parent then c2:Disconnect() m:Destroy() return end
				if stickRel and creature and creature.Root and creature.Root.Parent then m:PivotTo(creature.Root.CFrame * stickRel) end
			end)
		end
	end)
	return m
end

local function impactFx(at: Vector3, color: Color3, big: boolean)
	require(script.Parent.Audio).Play("DartHit", { At = at, Pitch = big and 0.85 or 1, Volume = big and 1.3 or 1 })
	DinosaurVFX.Burst(CFrame.new(at), big and 22 or 10, { Lifetime = NumberRange.new(0.15, 0.4), Speed = NumberRange.new(big and 10 or 5, big and 22 or 12), Color = color, LightEmission = 1, Size = NumberSequence.new(big and 0.8 or 0.5, 0) })
	if big then DinosaurVFX.BlockRing(CFrame.new(at) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 12, R0 = 0.5, R1 = 6, Color = color, Duration = 0.35 }) end
end

--------------------------------------------------------------------------------
-- firing: tap = quick dart, hold = charged heavy dart
--------------------------------------------------------------------------------
local fovKick = 0
-- the magazine (server-authoritative; mirrored here so the HUD reacts instantly)
local mag, reloadUntil = nil :: number?, 0
local function magSize(): number return (launcherInfo() :: any).Mag or 6 end
local function shoot(charge: number)
	if not active or player:GetAttribute("Downed") or Cinema.Playing() then return end
	local now = os.clock()
	local info = launcherInfo()
	if now < nextFire then return end
	if now < reloadUntil then
		Kit.Shake(ui.Crosshair)
		nextFire = now + 0.2
		return
	end
	local cam = Workspace.CurrentCamera
	local t = bestTarget(nil)
	if not t then
		-- nothing to lock on to: it still fires - at whatever you're aiming at, a puff of grit where it lands (2026-10-13,
		-- user: "more immersion"). Costs no dart and tells the server nothing: it can't hit anything
		nextFire = now + info.Rate
		local char = player.Character
		local vp = cam.ViewportSize
		local sp = Vector2.new(vp.X / 2, vp.Y / 2)
		if UserInputService.MouseEnabled and not UserInputService.TouchEnabled and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			sp = UserInputService:GetMouseLocation()
		end
		local ray = cam:ViewportPointToRay(sp.X, sp.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = {} :: { Instance }
		if char then table.insert(skip, char) end
		local lf = Workspace:FindFirstChild("DinoExpeditionLocal")
		if lf then table.insert(skip, lf) end
		params.FilterDescendantsInstances = skip
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 160, params)
		local to = hit and hit.Position or (ray.Origin + ray.Direction * 160)
		local r = hrp()
		if r then
			local flat = Vector3.new(to.X, r.Position.Y, to.Z)
			if (flat - r.Position).Magnitude > 0.5 then r.CFrame = CFrame.lookAt(r.Position, flat) end
		end
		PlayerAnim.Act(char, "Fire")
		sfx("Fire", nil, 1.7)
		fovKick = -2
		DinosaurVFX.Burst(CFrame.new(muzzleOf(char)), 6, { Lifetime = NumberRange.new(0.08, 0.2), Speed = NumberRange.new(2, 8), Color = Color3.fromRGB(255, 230, 160), LightEmission = 1, Size = NumberSequence.new(0.5, 0) })
		Kit.Punch(ui.Crosshair, 0.25)
		local m = flyDart(muzzleOf(char), nil, to, info.Color, false, function(p)
			if hit then
				DinosaurVFX.Cubes(p, 4, { Color3.fromRGB(150, 140, 125), Color3.fromRGB(110, 104, 96) }, 0.16, 5, 0.35)
				require(script.Parent.Audio).Play("Glance", { At = p, Pitch = 0.9, Volume = 0.5 })
			end
		end)
		if not hit then task.delay(0.5, function() if m.Parent then m:Destroy() end end) end
		return
	end
	nextFire = now + info.Rate
	lastShot = now
	target = t
	mag = (mag or magSize()) - 1
	local startedReload = false
	if (mag :: number) <= 0 then
		startedReload = true
		mag = magSize()
		reloadUntil = now + Config.Encounter.Reload
		sfx("Click", nil, 0.8)
		local flags = Net.Profile and Net.Profile.Flags
		local tips = flags and flags.Tips
		if not (tips and tips.Reload) then
			Kit.Toast("OUT OF DARTS - RELOADING. A PERFECT DODGE RELOADS INSTANTLY!", "Orange", "Launcher")
			if tips then tips.Reload = true end
			task.spawn(function() Net.Ask("Tip", { Key = "Reload" }) end)
		end
	end
	local to = aimPoint(t) or Vector3.zero
	local char = player.Character
	-- face the shot (touch, or a free cursor); the shoulder camera already faces it
	local r = hrp()
	if r then
		local flat = Vector3.new(to.X, r.Position.Y, to.Z)
		if (flat - r.Position).Magnitude > 0.5 then r.CFrame = CFrame.lookAt(r.Position, flat) end
	end
	local heavy = charge >= 0.98
	local wasCharged = charged
	charged = false
	PlayerAnim.Act(char, "Fire")
	if heavy then PlayerAnim.Act(char, "Fire") end
	sfx("Fire", nil, heavy and 1.1 or 1.7)
	fovKick = heavy and -6 or -2
	DinosaurVFX.Burst(CFrame.new(muzzleOf(char)), heavy and 14 or 6, { Lifetime = NumberRange.new(0.08, 0.2), Speed = NumberRange.new(2, 8), Color = Color3.fromRGB(255, 230, 160), LightEmission = 1, Size = NumberSequence.new(heavy and 0.9 or 0.5, 0) })
	Kit.Punch(ui.Crosshair, heavy and 0.5 or 0.25)
	local color = (wasCharged and C.YellowHi) or info.Color
	local result = nil
	local landed: Vector3? = nil
	local dartM: Model? = nil
	local function resolve()
		if not (result and landed) then return end
		local p = landed :: Vector3
		local creature = Exp and Exp.Creatures()[t]
		if result.Ok and (result.Result == "Wall" or result.Result == "Dodge") and dartM and dartM.Parent then
			dartM:Destroy() -- (it hit the rock / the dino wasn't there: nothing sticks in it)
		end
		if result.Ok and result.Result == "Wall" then
			-- it hit the rock in the way: a puff of grit where it struck, no number, no message
			local at = typeof(result.HitPos) == "Vector3" and result.HitPos or p
			DinosaurVFX.Cubes(at, 5, { Color3.fromRGB(150, 140, 125), Color3.fromRGB(110, 104, 96) }, 0.18, 6, 0.4)
			require(script.Parent.Audio).Play("Glance", { At = at, Pitch = 0.8, Volume = 0.6 })
		elseif result.Ok and result.Result == "Dodge" then
			-- it saw that one coming: a whiff of dust where it was, and the combo's gone
			DinosaurVFX.FootstepDust(p, 0.8)
			require(script.Parent.Audio).Play("Dodge", { At = p, Pitch = 1.2 })
			local creature2 = Exp and Exp.Creatures()[t]
			if creature2 and creature2.Anim and creature2.Anim:HasAction("Hop") and not creature2.Anim:IsPlaying() then creature2.Anim:Play("Hop") end
		elseif result.Ok and result.Result == "Guard" then
			-- off the crossed claws: a spark, a clang, and it answers
			impactFx(p, Color3.fromRGB(200, 210, 220), false)
			DinosaurVFX.Cubes(p, 8, { Color3.new(1, 1, 1), Color3.fromRGB(255, 220, 140) }, 0.2, 18, 0.4)
			floater(p + Vector3.new(0, 2, 0), "BLOCKED!", Color3.fromRGB(210, 216, 226), 0.6, 3)
			require(script.Parent.Audio).Play("Glance", { At = p, Pitch = 1.3 })
		elseif result.Ok then
			local weak = result.Weak
			flashModel(creature and creature.Model, weak and C.YellowHi or Color3.new(1, 1, 1))
			impactFx(p, weak and C.YellowHi or color, weak or result.Heavy)
			sfx(weak and "Weak" or (result.Heavy and "Heavy" or "Impact"), nil)
			ui.HitMark(weak and C.YellowHi or Color3.new(1, 1, 1))
			floater(p + Vector3.new(0, 1, 0), "+" .. tostring(result.Amount or 0), weak and C.YellowHi or C.Cream, weak and 0.6 or 0.45, 3)
			if weak then floater(p + Vector3.new(0, 3, 0), "WEAK SPOT!", C.YellowHi, 0.85, 5) DinosaurVFX.Shake(0.35, 0.15) end
			if result.Heavy then floater(p + Vector3.new(0, 4.5, 0), "HEAVY!", C.OrangeHi, 0.7, 5) DinosaurVFX.Shake(0.5, 0.2) end
			if result.Ambush then floater(p + Vector3.new(0, 6, 0), "AMBUSH x3!", C.LimeHi, 0.9, 5) DinosaurVFX.Shake(0.6, 0.25) end
			if (result.Combo or 0) >= 2 then Kit.Punch(ui.Combo, 0.35) end
			-- big hits make it flinch, and the world catches for a beat (hit-stop): you FEEL it land
			if (weak or result.Heavy) and creature and creature.Anim and creature.Anim:HasAction("Stumble") then creature.Anim:Play("Stumble") end
			if weak or result.Heavy then
				require(script.Parent.UI.CineKit).HitStop(result.Heavy and 0.07 or 0.05, 0.05, 0.12)
				fovKick = math.min(fovKick, result.Heavy and -7 or -4)
			end
		end
	end
	dartM = flyDart(muzzleOf(char), t, to, color, heavy or wasCharged, function(p)
		landed = p
		resolve()
	end)
	task.spawn(function()
		local res = Net.Ask("FireAt", { Id = t:GetAttribute("Id"), Charge = charge })
		result = res
		if res.Ok then
			combo, comboT = res.Combo or 0, os.clock()
			if res.Mag then mag = res.Mag end
			if res.Reload and res.Reload > 0 then reloadUntil = os.clock() + res.Reload end
			resolve()
		elseif res.Reloading then
			return
		else
			-- the server didn't take that shot (out of range, too soon): give the dart back - and don't sit through a
			-- reload the server never started
			if startedReload then
				reloadUntil = 0
				mag = 1
			else
				mag = math.min(magSize(), (mag or 0) + 1)
			end
			if res.Err then Kit.Toast(res.Err, "Red", "Dart") end
		end
	end)
end

local CHARGE_TIME = 0.9
function View.TriggerDown()
	if not active or player:GetAttribute("Downed") or Cinema.Playing() then return end
	if player:GetAttribute("HoldingBall") then return end -- a toy ball in your hand: the click throws that instead
	charging = os.clock()
end
function View.TriggerUp()
	if not charging then return end
	if Cinema.Playing() then charging = nil return end
	local held = os.clock() - charging
	charging = nil
	local charge = held < 0.22 and 0 or math.clamp(held / CHARGE_TIME, 0, 1)
	shoot(charge)
end
-- tap from the HUD button / F
function View.Fire(_screenPos: Vector2?)
	shoot(0)
end

--------------------------------------------------------------------------------
-- dodge roll
--------------------------------------------------------------------------------
local function afterimages(char: Model, n: number)
	for i = 1, n do
		task.delay(i * 0.06, function()
			if not char.Parent then return end
			local ghost = Instance.new("Model")
			for _, d in ipairs(char:GetChildren()) do
				if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
					local g = Instance.new("Part")
					g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
					g.Size = d.Size
					g.CFrame = d.CFrame
					g.Material = Enum.Material.Neon
					g.Color = charged and C.YellowHi or C.TealHi
					g.Transparency = 0.55
					g.Parent = ghost
					TweenService:Create(g, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				end
			end
			ghost.Parent = Workspace
			task.delay(0.32, function() ghost:Destroy() end)
		end)
	end
end

-- the roll's cooldown for you (a Raptor Hide armour rolls 20% sooner, same as the server)
local function dodgeCooldown(): number
	return Config.Player.DodgeCooldown * ((profileGear().Armor == "RaptorHide") and 0.8 or 1)
end
local dodgeStarted = 0

-- THE ROLL: a real tumble along the ground, ~22 studs in half a second, fast off the mark and easing out. It's
-- pushed by a velocity constraint (the character's own walk controller used to cancel a plain velocity kick, so
-- the old dodge barely moved you). Sideways it's a cartwheel, backwards a back-roll.
function View.Dodge()
	if not active or player:GetAttribute("Downed") then return end
	if rodeo or Cinema.Playing() then return end -- (no rolling off a dino you're riding, or in a cutscene)
	local now = os.clock()
	if now < nextDodge then
		-- still recovering: the button shakes so you know why nothing happened
		Kit.Shake(ui.DodgeBtn)
		return
	end
	local r, h = hrp(), hum()
	if not r or not h then return end
	nextDodge = now + dodgeCooldown()
	dodgeStarted = now
	local T = Config.Player.DodgeTime
	dodgingUntil = now + T
	local dir = h.MoveDirection
	if dir.Magnitude < 0.1 then
		local cam = Workspace.CurrentCamera
		dir = -Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	task.spawn(function() Net.Ask("Dodge") end)
	PlayerAnim.Act(player.Character, "Dodge", { Dir = r.CFrame:VectorToObjectSpace(dir), Duration = T })
	afterimages(player.Character :: Model, 4)
	sfx("Dodge")
	DinosaurVFX.FootstepDust(r.Position - Vector3.new(0, 2.6, 0), 1.0)
	-- speed eases out: v(u) = v0 * (1 - 0.6u), so the distance covered is v0 * T * 0.7
	local v0 = Config.Player.DodgeDistance / (T * 0.7)
	-- a Microraptor companion's GLIDE: in the air, the roll is an air dash - farther, with a little lift
	if h.FloorMaterial == Enum.Material.Air and require(script.Parent.Glide).Has() then
		v0 *= 1.4
		local v = r.AssemblyLinearVelocity
		r.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 12), v.Z)
		DinosaurVFX.Cubes(r.Position, 8, { Color3.fromRGB(46, 197, 214), Color3.fromRGB(20, 30, 40) }, 0.2, 10, 0.5)
	end
	local att = r:FindFirstChild("DinoRollAtt") :: Attachment?
	if not att then
		local a = Instance.new("Attachment")
		a.Name = "DinoRollAtt"
		a.Parent = r
		att = a
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "DinoRoll"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane -- (up and down stay free: you roll down slopes, gravity works)
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = 1e6
	lv.PlaneVelocity = Vector2.new(dir.X * v0, dir.Z * v0)
	lv.Parent = r
	local t0 = os.clock()
	local puffed = false
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local u = (os.clock() - t0) / T
		if u >= 1 or not r.Parent or player:GetAttribute("Downed") then
			conn:Disconnect()
			lv:Destroy()
			if r.Parent then DinosaurVFX.FootstepDust(r.Position - Vector3.new(0, 2.6, 0), 0.7) end
			return
		end
		local v = v0 * (1 - 0.6 * u)
		lv.PlaneVelocity = Vector2.new(dir.X * v, dir.Z * v)
		if not puffed and u > 0.45 then
			puffed = true
			DinosaurVFX.FootstepDust(r.Position - Vector3.new(0, 2.6, 0), 0.6)
		end
	end)
	Kit.Punch(ui.DodgeBtn, 0.2)
end

--------------------------------------------------------------------------------
-- telegraphs
--------------------------------------------------------------------------------
local teles = {} :: { [number]: any }
local function flatPart(color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Parent = Workspace
	return p
end
local function wedge(color: Color3, tr: number): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = true, false, false, false, false
	w.Material = Enum.Material.Neon
	w.Color = color
	w.Transparency = tr
	w.Parent = Workspace
	return w
end
local function drawTri(a: WedgePart, b: WedgePart, p1: Vector3, p2: Vector3, p3: Vector3)
	local ab, ac, bc = p2 - p1, p3 - p1, p3 - p2
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then p3, p1 = p1, p3 elseif acd > bcd and acd > abd then p1, p2 = p2, p1 end
	ab, ac, bc = p2 - p1, p3 - p1, p3 - p2
	local cr = ac:Cross(ab)
	if cr.Magnitude < 1e-4 then return end
	local right = cr.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	a.Size = Vector3.new(0.1, height, math.abs(ab:Dot(back)))
	a.CFrame = CFrame.fromMatrix((p1 + p2) / 2, right, up, back)
	b.Size = Vector3.new(0.1, height, math.abs(ac:Dot(back)))
	b.CFrame = CFrame.fromMatrix((p1 + p3) / 2, -right, up, -back)
end

local RED = Color3.fromRGB(255, 70, 50)
local HOT = Color3.fromRGB(255, 236, 120)
local layoutButtons: (boolean) -> () -- (defined with the step loop)
local Floor = require(script.Parent.Floor)

-- is p inside a telegraph? (the same test the server makes)
local function inTele(info, p: Vector3): boolean
	local o = info.O
	if not info.Reach and math.abs(p.Y - o.Y) > 10 then return false end
	local d = Vector3.new(p.X - o.X, 0, p.Z - o.Z)
	if info.Shape == "Circle" then return d.Magnitude <= info.R end
	if info.Shape == "Ring" then return d.Magnitude <= info.R and d.Magnitude >= (info.Inner or 0) end
	local dir = info.Dir or Vector3.new(0, 0, -1)
	if info.Shape == "Line" then
		local along = d:Dot(dir)
		return along >= -2 and along <= info.Len and (d - dir * along).Magnitude <= info.Width / 2
	end
	if info.Shape == "Cone" then
		if d.Magnitude > info.Len then return false end
		if d.Magnitude < 2 then return true end
		return math.deg(math.acos(math.clamp(d.Unit:Dot(dir), -1, 1))) <= info.Angle / 2
	end
	return false
end

-- the ground a telegraph is drawn on. Over the sea the floor ray goes through the water to the seabed, so the sea
-- boss's shapes carry Surface (2026-10-14): never drawn lower than the water, where everyone can see them
local teleSurface: number? = nil
local function teleFloor(p: Vector3, up: number): Vector3
	local g = Floor.At(p, up)
	if teleSurface and g.Y < teleSurface then return Vector3.new(g.X, teleSurface, g.Z) end
	return g
end

-- an edge of a telegraph: a bright bar laid along the real ground between a and b (it bends over bumps)
local function edge(parts, a: Vector3, b: Vector3, width: number)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	-- (a segment per 8 studs: per 4 it was hundreds of parts and ground rays for one boss move)
	local n = math.max(1, math.ceil(d.Magnitude / 8))
	local prev = teleFloor(a + Vector3.new(0, 6, 0), 8)
	for i = 1, n do
		local q = a:Lerp(b, i / n)
		local g = teleFloor(q + Vector3.new(0, 6, 0), 8)
		local seg = flatPart(RED, 0.05)
		local p0, p1 = prev + Vector3.new(0, 0.28, 0), g + Vector3.new(0, 0.28, 0)
		local len = (p1 - p0).Magnitude
		if len > 0.05 then
			seg.Size = Vector3.new(width, 0.12, len + width * 0.6)
			seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
			table.insert(parts, seg)
		else
			seg:Destroy()
		end
		prev = g
	end
end

local function onTele(info)
	-- lined up on me? flash the dodge button for the wind-up
	do
		local r = hrp()
		if r and ui.DodgeCue and info.O then
			local d = Vector3.new(r.Position.X - info.O.X, 0, r.Position.Z - info.O.Z).Magnitude
			local reach = (info.R or info.Len or 10) + 2
			if d <= reach and math.abs(r.Position.Y - info.O.Y) < 12 then ui.CueUntil = os.clock() + (info.Time or 1) end
		end
	end
	-- the fill sits on the ground at the attack's origin; the outline follows every bump of the real ground
	teleSurface = typeof(info.Surface) == "number" and info.Surface or nil
	local base = teleFloor(info.O + Vector3.new(0, 6, 0), 10)
	local o = Vector3.new(info.O.X, base.Y + 0.22, info.O.Z)
	local parts, outline = {}, {}
	local fill: any = {}
	local function add(p) table.insert(parts, p) return p end
	local dir = info.Dir or Vector3.new(0, 0, -1)
	local function ring(r: number, w: number)
		local n = math.clamp(math.floor(r * 0.9), 12, 28)
		for i = 0, n - 1 do
			local a0, a1 = i / n * math.pi * 2, (i + 1) / n * math.pi * 2
			edge(outline, o + Vector3.new(math.cos(a0) * r, 0, math.sin(a0) * r), o + Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r), w)
		end
	end
	if info.Shape == "Circle" or info.Shape == "Ring" then
		local disc = add(flatPart(RED, 0.8))
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.1, info.R * 2, info.R * 2)
		disc.CFrame = CFrame.new(o) * CFrame.Angles(0, 0, math.pi / 2)
		local inner = add(flatPart(RED, 0.4))
		inner.Shape = Enum.PartType.Cylinder
		inner.Size = Vector3.new(0.12, 0.2, 0.2)
		inner.CFrame = disc.CFrame
		fill = { Kind = "Disc", Part = inner, R = info.R }
		ring(info.R, 0.55)
		if info.Shape == "Ring" and info.Inner then
			local hole = add(flatPart(Color3.fromRGB(40, 255, 120), 0.6))
			hole.Shape = Enum.PartType.Cylinder
			hole.Size = Vector3.new(0.14, info.Inner * 2, info.Inner * 2)
			hole.CFrame = disc.CFrame
			ring(info.Inner, 0.35)
		end
	elseif info.Shape == "Line" then
		local len, w = info.Len, info.Width
		local cf = CFrame.lookAt(o, o + dir) * CFrame.new(0, 0, -len / 2)
		local bar = add(flatPart(RED, 0.8))
		bar.Size = Vector3.new(w, 0.1, len)
		bar.CFrame = cf
		local inner = add(flatPart(RED, 0.4))
		fill = { Kind = "Line", Part = inner, Len = len, W = w, O = o, Dir = dir }
		local side = dir:Cross(Vector3.yAxis) * (w / 2)
		local tip = o + dir * len
		edge(outline, o - side, tip - side, 0.5)
		edge(outline, o + side, tip + side, 0.5)
		edge(outline, tip - side, tip + side, 0.5)
		-- chevrons down the lane: it's coming THIS way
		for k = 1, math.max(1, math.floor(len / 9)) do
			local c = o + dir * (k * len / (math.floor(len / 9) + 1))
			local g = teleFloor(c + Vector3.new(0, 6, 0), 8) + Vector3.new(0, 0.3, 0)
			for sgn = -1, 1, 2 do
				local ch = flatPart(RED, 0.25)
				ch.Size = Vector3.new(0.45, 0.1, w * 0.42)
				ch.CFrame = CFrame.lookAt(g, g + dir) * CFrame.Angles(0, sgn * math.rad(50), 0) * CFrame.new(0, 0, w * 0.12)
				table.insert(outline, ch)
			end
		end
	elseif info.Shape == "Cone" then
		local half = math.rad(info.Angle / 2)
		local yaw = math.atan2(-dir.X, -dir.Z)
		local function d(a: number) return Vector3.new(-math.sin(a), 0, -math.cos(a)) end
		local n = 4
		for i = 0, n - 1 do
			local a0 = yaw - half + (2 * half) * i / n
			local a1 = yaw - half + (2 * half) * (i + 1) / n
			local w1, w2 = add(wedge(RED, 0.8)), add(wedge(RED, 0.8))
			drawTri(w1, w2, o, o + d(a0) * info.Len, o + d(a1) * info.Len)
		end
		fill = { Kind = "Cone", O = o, Yaw = yaw, Half = half, Len = info.Len, Parts = {} }
		for _ = 1, n do table.insert(fill.Parts, { add(wedge(RED, 0.4)), add(wedge(RED, 0.4)) }) end
		edge(outline, o, o + d(yaw - half) * info.Len, 0.5)
		edge(outline, o, o + d(yaw + half) * info.Len, 0.5)
		local m = math.max(6, math.floor(info.Angle / 12))
		for i = 0, m - 1 do
			edge(outline, o + d(yaw - half + 2 * half * i / m) * info.Len, o + d(yaw - half + 2 * half * (i + 1) / m) * info.Len, 0.5)
		end
	end
	teleSurface = nil
	local t0 = os.clock()
	local rec = { Parts = parts, Done = false, Info = info, PaintAt = 0 }
	local key = info.Key or info.Actor or 0 -- (a scripted boss move can draw several at once: each has its own key)
	teles[key] = rec
	task.spawn(function()
		while not rec.Done and os.clock() - t0 < info.Time + 0.2 do
			local u = math.clamp((os.clock() - t0) / info.Time, 0.02, 1)
			if fill.Kind == "Disc" then
				fill.Part.Size = Vector3.new(0.12, fill.R * 2 * u, fill.R * 2 * u)
			elseif fill.Kind == "Line" then
				fill.Part.Size = Vector3.new(fill.W, 0.12, fill.Len * u)
				fill.Part.CFrame = CFrame.lookAt(fill.O, fill.O + fill.Dir) * CFrame.new(0, 0.01, -fill.Len * u / 2)
			elseif fill.Kind == "Cone" then
				local function d(a: number) return Vector3.new(-math.sin(a), 0, -math.cos(a)) end
				for i, pair in ipairs(fill.Parts) do
					local a0 = fill.Yaw - fill.Half + (2 * fill.Half) * (i - 1) / #fill.Parts
					local a1 = fill.Yaw - fill.Half + (2 * fill.Half) * i / #fill.Parts
					drawTri(pair[1], pair[2], fill.O, fill.O + d(a0) * fill.Len * u, fill.O + d(a1) * fill.Len * u)
				end
			end
			for _, p in ipairs(parts) do if p.Transparency < 0.6 then p.Transparency = 0.45 - u * 0.15 end end
			-- the outline: steady red, hotter and faster as the hit comes - and blazing when YOU are standing in it
			-- (recoloured ~20 times a second, not every frame: a big move has a couple of hundred outline parts)
			if os.clock() >= (rec.PaintAt or 0) then
				rec.PaintAt = os.clock() + 0.05
				local r = hrp()
				local mine = r ~= nil and inTele(info, r.Position)
				local beat = math.abs(math.sin((os.clock() - t0) * (mine and 16 or 7) * (0.6 + u)))
				local col = mine and RED:Lerp(HOT, 0.35 + beat * 0.5) or RED:Lerp(HOT, u * 0.4)
				for _, e in ipairs(outline) do
					e.Color = col
					e.Transparency = mine and 0 or (0.15 + (1 - beat) * 0.2)
				end
			end
			task.wait()
		end
		-- the strike frame: the whole shape blinks white, then it's gone
		for _, p in ipairs(parts) do p.Color = Color3.new(1, 1, 1) p.Transparency = 0.25 end
		for _, e in ipairs(outline) do e.Color = Color3.new(1, 1, 1) e.Transparency = 0 end
		task.wait(0.07)
		for _, p in ipairs(parts) do p:Destroy() end
		for _, e in ipairs(outline) do TweenService:Create(e, TweenInfo.new(0.18), { Transparency = 1 }):Play() end
		task.delay(0.2, function() for _, e in ipairs(outline) do e:Destroy() end end)
		if teles[key] == rec then teles[key] = nil end
	end)
end

--------------------------------------------------------------------------------
-- rodeo: you ride the exhausted dino; keep the balance needle in the green until it drops
--------------------------------------------------------------------------------
-- (rodeo is declared up top: the roll reads it)
local function startRodeo(actorId: number, time: number)
	local cine = Cinema.Begin("DinoRodeo")
	local gui, canvas = Kit.Screen("DinoRodeo", 56, false, 0.8)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -90)
	box.Size = UDim2.fromOffset(560, 120)
	box.Parent = canvas
	Kit.Text(box, "RODEO! HOLD ON!", { Size = UDim2.new(1, 0, 0, 40), Stroke = 5, Shadow = 4, Color = C.YellowHi, MaxSize = 44 })
	local track = Instance.new("Frame")
	track.BackgroundColor3 = C.InkSoft
	track.Size = UDim2.new(1, 0, 0, 34)
	track.Position = UDim2.fromOffset(0, 54)
	track.Parent = box
	Kit.Corner(track, 12)
	Kit.Stroke(track, C.Ink, 4)
	local zone = Instance.new("Frame")
	zone.BackgroundColor3 = C.Lime
	zone.AnchorPoint = Vector2.new(0.5, 0)
	zone.Position = UDim2.fromScale(0.5, 0)
	zone.Size = UDim2.fromScale(0.34, 1)
	zone.Parent = track
	Kit.Corner(zone, 10)
	local needle = Instance.new("Frame")
	needle.BackgroundColor3 = Color3.new(1, 1, 1)
	needle.AnchorPoint = Vector2.new(0.5, 0.5)
	needle.Size = UDim2.new(0, 10, 1, 16)
	needle.Position = UDim2.fromScale(0.5, 0.5)
	needle.Parent = track
	Kit.Stroke(needle, C.Ink, 3)
	local timer = Kit.Segments(box, 12, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 100) })
	Kit.Text(box, Kit.Platform() == "Touch" and "HOLD LEFT / RIGHT" or (Kit.Gamepad() and "LEFT STICK" or "A / D"), { Pixel = true, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, -20), Stroke = 2.5 })
	rodeo = { Actor = actorId, X = 0, V = 0, Out = 0, T0 = os.clock(), Time = time, Push = 0 }
	local creature = nil
	for cfg, c in pairs(Exp and Exp.Creatures() or {}) do if cfg:GetAttribute("Id") == actorId then creature = c end end
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local char = player.Character
	local root = hrp()
	local h = hum()
	if root then root.Anchored = true end
	if h then h.PlatformStand = true end
	PlayerAnim.SetLoop(char, "Rodeo")
	-- where the rider sits: just behind the head on the back
	local seatY = 0
	if creature and creature.Model then
		local _, size = creature.Model:GetBoundingBox()
		seatY = size.Y * 0.62
	end
	-- touch: HOLD the left or right half of the screen (a tap used to give only a 0.18 s nudge)
	local touches = {} :: { [InputObject]: number }
	local function touchPush()
		local p = 0
		for _, side in pairs(touches) do p += side end
		if rodeo then rodeo.Push = math.clamp(p, -1, 1) end
	end
	local touchConn = UserInputService.TouchStarted:Connect(function(t)
		touches[t] = (t.Position.X < cam.ViewportSize.X / 2) and -1 or 1
		touchPush()
	end)
	local touchEnd = UserInputService.TouchEnded:Connect(function(t)
		touches[t] = nil
		touchPush()
	end)
	local fail = false
	DinosaurVFX.Shake(0.8, 0.4)
	-- the server watches the ride as it happens (where the needle is, four times a second) - it can end it early
	local lastPulse = 0
	while rodeo and os.clock() - rodeo.T0 < time do
		if rodeo.ServerFail then fail = true break end
		if os.clock() - lastPulse >= 0.25 then
			lastPulse = os.clock()
			local x = rodeo.X
			task.spawn(function() Net.Ask("RodeoPulse", { Id = actorId, X = x }) end)
		end
		local dt = RunService.RenderStepped:Wait()
		local k = UserInputService
		local push = rodeo.Push
		if k:IsKeyDown(Enum.KeyCode.A) or k:IsKeyDown(Enum.KeyCode.Left) then push = -1 end
		if k:IsKeyDown(Enum.KeyCode.D) or k:IsKeyDown(Enum.KeyCode.Right) then push = 1 end
		for _, st in ipairs(k:GetGamepadState(Enum.UserInputType.Gamepad1)) do
			if st.KeyCode == Enum.KeyCode.Thumbstick1 and math.abs(st.Position.X) > 0.2 then push = st.Position.X end
		end
		local u = (os.clock() - rodeo.T0) / time
		-- the dino bucks hard one way, then switches without warning (harder as it tires): you must fight it
		if os.clock() >= (rodeo.NextFlip or 0) then
			rodeo.Buck = (rodeo.Buck or (math.random() < 0.5 and -1 or 1)) * -1
			if math.random() < 0.25 then rodeo.Buck *= -1 end -- sometimes a fake-out: same way again
			rodeo.NextFlip = os.clock() + 0.75 + math.random() * (0.95 - u * 0.3)
			DinosaurVFX.Shake(0.35, 0.15)
		end
		-- tuned so hands-off always loses but steady steering always wins: your push is clearly stronger
		-- than its buck, the first half second is a free settle-in, and the zone stays generous
		-- (2026-10-12: softer bucks and much more damping - the needle used to fly past centre every time you
		-- pushed back, so holding it steady felt impossible)
		local force = (rodeo.Buck or 1) * (1.8 + u * 1.0) + math.noise(os.clock() * 2.3, actorId) * 0.6
		if os.clock() - rodeo.T0 < 0.6 then force *= 0.3 end
		rodeo.V += (force + push * 6.4) * dt
		rodeo.V *= math.exp(-dt * 2.6)
		rodeo.X = math.clamp(rodeo.X + rodeo.V * dt, -1, 1)
		if math.abs(rodeo.X) >= 1 then rodeo.V *= -0.3 end
		needle.Position = UDim2.fromScale(0.5 + rodeo.X * 0.48, 0.5)
		local half = 0.36 - u * 0.04 -- the green zone narrows a little as it tires
		zone.Size = UDim2.fromScale(half * 2 * 0.96, 1)
		local inZone = math.abs(rodeo.X) < half
		zone.BackgroundColor3 = inZone and C.Lime or C.Orange
		if not inZone then rodeo.Out += dt else rodeo.Out = math.max(0, rodeo.Out - dt * 0.9) end
		if rodeo.Out > 2.0 then fail = true break end
		timer(1 - u, inZone and C.Lime or C.Orange)
		PlayerAnim.SetRodeoTilt(char, rodeo.X)
		if creature and creature.Root and root then
			local rcf = creature.Root.CFrame
			local buck = math.sin(os.clock() * 9) * 0.5
			root.CFrame = rcf * CFrame.new(0, seatY + buck * 0.4, 0) * CFrame.Angles(buck * 0.08, 0, rodeo.X * 0.35)
			local shake = math.noise(os.clock() * 6) * 0.6
			cam.CFrame = CFrame.lookAt((rcf * CFrame.new(4 + rodeo.X * 3, seatY + 5 + shake, 11)).Position, rcf.Position + Vector3.new(0, seatY * 0.7, 0) + rcf.LookVector * -6) * CFrame.Angles(0, 0, rodeo.X * 0.12)
		end
	end
	touchConn:Disconnect()
	touchEnd:Disconnect()
	rodeo = nil
	gui:Destroy()
	PlayerAnim.SetLoop(char, nil)
	if root then
		root.Anchored = false
		-- hop off to the side - the side with something under it (2026-10-14: off a Tidebreaker lying along the Maw's
		-- rock, one side is the open sea)
		local side = 1
		if creature and creature.Model then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { char :: Instance, creature.Model }
			params.IgnoreWater = true
			local depth = (creature.Lift or 3) + seatY + 10
			local function solid(s: number): boolean
				local p = (root.CFrame * CFrame.new(s * (fail and 7 or 5), 1, 2)).Position
				return Workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -depth, 0), params) ~= nil
			end
			if not solid(1) and solid(-1) then side = -1 end
		end
		root.CFrame = root.CFrame * CFrame.new(side * (fail and 7 or 5), 1, 2)
		root.AssemblyLinearVelocity = root.CFrame.RightVector * side * (fail and 30 or 12) + Vector3.new(0, 20, 0)
	end
	if h then h.PlatformStand = false end
	cam.CameraType = Enum.CameraType.Custom
	if h then cam.CameraSubject = h end
	Cinema.End(cine)
	task.spawn(function() Net.Ask("RodeoResult", { Id = actorId, Success = not fail }) end)
	if fail then
		Kit.Toast("THROWN OFF!", "Red", "Alert")
		PlayerAnim.Act(char, "BigHit", { Side = 1 })
	end
end

--------------------------------------------------------------------------------
-- eggs in the scramble
--------------------------------------------------------------------------------
local eggs = {} :: { [Configuration]: any }
local rodeoPrompt: ProximityPrompt? = nil -- (the RODEO! prompt while a dino is open to ride: egg prompts hide meanwhile)
local function ownRover(): BasePart?
	local vf = Workspace:FindFirstChild("ActiveVehicles")
	if not vf then return nil end
	for _, v in ipairs(vf:GetChildren()) do
		if v:GetAttribute("Owner") == player.UserId and v:IsA("Model") then return v.PrimaryPart end
	end
	return nil
end

-- THE RARITY CARD: the moment an egg is yours, a card in its colour - the egg, the rarity big, the species and
-- weight, what to do next. Rare and up get a shine sweeping across it; Epic+ lands with a punch; Secret's outline
-- cycles the rainbow. (It replaces the old tilted stamp, which testers said looked cheap.)
local rarityGui = nil :: ScreenGui?
local function rarityCard(rarity: string?, species: string?, kg: number?, sub: string)
	local r = Config.Rarity[rarity or ""] :: any
	local col = r and r.Color or C.YellowHi
	local order = r and r.Order or 1
	if rarityGui then rarityGui:Destroy() rarityGui = nil end
	local gui, canvas = Kit.Screen("DinoRarityCard", 30, false, 0.9)
	rarityGui = gui
	local outer, content = Kit.Card(canvas, { Size = UDim2.fromOffset(440, 128), Position = UDim2.new(0.5, 0, 0, 132), AnchorPoint = Vector2.new(0.5, 0), Border = col, ZIndex = 10, Radius = 16 })
	-- a soft disc of the rarity's colour behind the egg
	local halo = Instance.new("Frame")
	halo.BackgroundColor3 = col
	halo.BackgroundTransparency = 0.55
	halo.Size = UDim2.fromOffset(104, 104)
	halo.Position = UDim2.new(0, 10, 0.5, 0)
	halo.AnchorPoint = Vector2.new(0, 0.5)
	halo.ZIndex = 13
	halo.Parent = content
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(1, 0)
	hc.Parent = halo
	Kit.Icon(content, "Egg", { Species = species, Size = UDim2.fromOffset(96, 96), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 15, Rotation = -8 })
	local sp = species and Config.Species[species] :: any
	Kit.Text(content, "NEW EGG", { Pixel = true, Size = UDim2.new(1, -140, 0, 11), Position = UDim2.fromOffset(128, 12), Align = Enum.TextXAlignment.Left, Color = C.Cream, Stroke = 2, Shadow = 1, ZIndex = 16, MaxSize = 11 })
	local name = Kit.Text(content, r and r.Name or "MYSTERY", { Size = UDim2.new(1, -140, 0, 40), Position = UDim2.fromOffset(126, 26), Align = Enum.TextXAlignment.Left, Color = col, Stroke = 4, Shadow = 3, ZIndex = 16, MaxSize = 40 })
	Kit.Text(content, ((sp and sp.Name) or "") .. ((kg and kg > 0) and ("  -  " .. Config.FormatKG(kg)) or ""), { Pixel = true, Size = UDim2.new(1, -140, 0, 13), Position = UDim2.fromOffset(128, 70), Align = Enum.TextXAlignment.Left, Color = C.Cream, Stroke = 2, Shadow = 1, ZIndex = 16, MaxSize = 13 })
	Kit.Text(content, sub, { Pixel = true, Size = UDim2.new(1, -140, 0, 10), Position = UDim2.fromOffset(128, 92), Align = Enum.TextXAlignment.Left, Color = C.YellowHi, Stroke = 2, Shadow = 1, ZIndex = 16, MaxSize = 10 })
	local body = outer:FindFirstChild("Body") :: GuiObject?
	if order >= 3 and body then Kit.Shine(body, 1.4) end
	if order >= 6 then
		for _, d in ipairs(outer:GetDescendants()) do if d:IsA("UIStroke") and d.Parent and d.Parent.Name == "InnerBorder" then RarityFx.Rainbow(d) end end
		for _, d in ipairs(name:GetDescendants()) do if d:IsA("TextLabel") then RarityFx.Rainbow(d) end end
	end
	Kit.Pop(outer, order >= 4 and 1.35 or 0.5)
	if order >= 4 then
		task.delay(0.12, function() if outer.Parent then Kit.Punch(outer, 0.25) end end)
		DinosaurVFX.Shake(0.35 + (order - 4) * 0.15, 0.2)
	end
	task.delay(1.9 + order * 0.25, function()
		if rarityGui ~= gui then return end
		Kit.PopOut(outer, false)
		task.delay(0.25, function() gui:Destroy() if rarityGui == gui then rarityGui = nil end end)
	end)
end
View.RarityCard = rarityCard

-- only eggs YOU can take are shown (2026-10-13, user: "don't show extra eggs that you can't pick up"): never someone
-- else's prize, the boss nest only to its winners, and a rider's nest once they've had their one
local function eggVisible(cfg: Configuration): boolean
	local owner = cfg:GetAttribute("Owner")
	if owner and owner ~= player.UserId then return false end
	local site = cfg:GetAttribute("Site")
	if cfg:GetAttribute("BossEgg") then
		return owner ~= nil or player:GetAttribute("BossWinner") == site
	end
	return player:GetAttribute("RiderTook") ~= site
end

local function spawnEgg(cfg: Configuration)
	if cfg:GetAttribute("Site") ~= siteKey or eggs[cfg] then return end
	if not eggVisible(cfg) then return end
	local owner = cfg:GetAttribute("Owner")
	local t = EggT:FindFirstChild(tostring(cfg:GetAttribute("Species") or "Velociraptor") .. "Egg")
	if not t then return end
	local m = t:Clone() :: Model
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery = true, false, false end
	end
	local kg = cfg:GetAttribute("KG") or 0
	m:ScaleTo(0.75 * Config.EggScale(tostring(cfg:GetAttribute("Species") or "Velociraptor"), kg))
	local p = cfg:GetAttribute("P") :: Vector3
	local _, size = m:GetBoundingBox()
	m:PivotTo(CFrame.new(p + Vector3.new(0, size.Y / 2, 0)))
	m.Parent = Workspace
	local rarity = cfg:GetAttribute("Rarity")
	if rarity and rarity ~= "" then RarityFx.Apply(m, rarity, 2) end
	require(script.Parent.EggTip).Tag(m, cfg:GetAttribute("Species") :: any, rarity :: any, kg)
	local light = Instance.new("PointLight")
	light.Range = 7
	light.Brightness = 0.9
	light.Color = Color3.fromRGB(255, 236, 190)
	light.Parent = m.PrimaryPart
	-- the pick-up prompt (yours only for a ruler's prize)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt:SetAttribute("Outline", true)
	local spName = ((Config.Species[cfg:GetAttribute("Species")] or {}).Name or "Egg") :: string
	prompt.ObjectText = (cfg:GetAttribute("BossEgg") and ("Boss egg - " .. spName)) or (owner and "Your prize egg") or spName
	prompt.HoldDuration = 0.45
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Enabled = owner == nil or owner == player.UserId
	prompt.Parent = m.PrimaryPart
	prompt.Triggered:Connect(function()
		task.spawn(function()
			local res = Net.Ask("PickEgg", { Id = cfg:GetAttribute("Id") })
			if res and res.Ok and res.Companion then
				-- you SEE it go: the egg hops from the nest onto your companion's back (it rides there until you load
				-- up at the rover - LOAD takes both)
				local from = m.PrimaryPart and m.PrimaryPart.Position or nil
				local to = nil
				for _, c in ipairs(Chasers:GetChildren()) do
					if c:GetAttribute("Buddy") and c:GetAttribute("Owner") == player.UserId and c:GetAttribute("CarryEgg") then
						local p = c:GetAttribute("P")
						if typeof(p) == "Vector3" then to = p end
					end
				end
				if from and to then
					local r = Config.Rarity[tostring(res.Egg and res.Egg.Rarity or "")]
					local ball = Instance.new("Part")
					ball.Shape = Enum.PartType.Ball
					ball.Size = Vector3.new(1.4, 1.4, 1.4)
					ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
					ball.Material = Enum.Material.SmoothPlastic
					ball.Color = r and r.Color or Color3.fromRGB(245, 235, 210)
					ball.Parent = Workspace
					local dest = to + Vector3.new(0, 4, 0)
					local t0 = os.clock()
					require(script.Parent.Audio).Play("EggPickup", { Volume = 0.6 })
					task.spawn(function()
						while os.clock() - t0 < 0.45 do
							local u = (os.clock() - t0) / 0.45
							ball.Position = from:Lerp(dest, u) + Vector3.new(0, math.sin(u * math.pi) * 6, 0)
							RunService.RenderStepped:Wait()
						end
						ball:Destroy()
						DinosaurVFX.BlockRing(CFrame.new(dest) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 10, R0 = 0.4, R1 = 3, Color = ball.Color, Duration = 0.3 })
						require(script.Parent.Audio).Play("EggPlace", { Volume = 0.6 })
					end)
				end
				Kit.Toast(res.Companion .. " HAS IT!", "Teal", "Buddy")
			elseif res and res.Ok then
				-- (the lift itself plays from PlayerAnim when the Holding attribute arrives)
				-- the rarity, big and in its colour, the moment it's in your arms
				local r = Config.Rarity[res.Egg.Rarity]
				local rn = r and r.Name or "MYSTERY"
				local putKey = Kit.Platform() == "Pad" and "D-PAD DOWN" or (Kit.Platform() == "Touch" and "PUT DOWN" or "G")
				-- (riding along in someone's rover: no rack of your own, it went straight to your bag)
				-- (a boss egg: straight to your bag too, whoever's rover is parked where)
				local sub = res.Boss and "BOSS EGG - SAFE IN YOUR BAG!" or (res.Bagged and "SENT STRAIGHT TO YOUR BAG" or ("LOAD IT ON YOUR ROVER  -  [" .. putKey .. "] TO PUT IT DOWN"))
				local _ = rn
				rarityCard(res.Egg.Rarity, res.Egg.Species, res.Egg.KG, sub)
				local Audio = require(script.Parent.Audio)
				if (r and r.Order or 1) >= 5 then Audio.Sting("HatchRare", 0.45) elseif (r and r.Order or 1) >= 3 then Audio.Play("Perfect", { Pitch = 1.1 }) end
			elseif res and res.Err then
				Kit.Toast(res.Err, "Orange", "Egg")
			end
		end)
	end)
	local rec = { Model = m, Pos = p, Lift = size.Y / 2, Prompt = prompt, Conns = {} }
	eggs[cfg] = rec
	-- a takedown or a companion's sniff lifted it: it flashes and comes back brighter
	table.insert(rec.Conns, cfg:GetAttributeChangedSignal("Rarity"):Connect(function()
		if eggs[cfg] ~= rec or not cfg.Parent then return end
		local r = Config.Rarity[cfg:GetAttribute("Rarity") or ""]
		for _, c in ipairs(rec.Conns) do c:Disconnect() end
		m:Destroy()
		eggs[cfg] = nil
		if r then
			DinosaurVFX.BlockRing(CFrame.new(p + Vector3.new(0, 1, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 14, R0 = 0.4, R1 = 4, Color = r.Color, Duration = 0.45 })
			DinosaurVFX.Cubes(p + Vector3.new(0, 1.2, 0), 10, { r.Color, Color3.new(1, 1, 1) }, 0.25, 8, 0.7)
		end
		spawnEgg(cfg)
	end))
	-- your companion sniffed this one out: it glows gold and sparkles
	local function sniffed()
		if not cfg:GetAttribute("Sniffed") or m:FindFirstChild("SniffGlow") then return end
		local h = Instance.new("Highlight")
		h.Name = "SniffGlow"
		h.FillColor = Color3.fromRGB(255, 214, 80)
		h.FillTransparency = 0.6
		h.OutlineColor = Color3.fromRGB(255, 240, 160)
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = m
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Rate = 10
		pe.Lifetime = NumberRange.new(0.6, 1.1)
		pe.Speed = NumberRange.new(1, 2.5)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new(0.4, 0)
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 220, 110))
		pe.LightEmission = 1
		pe.Parent = m.PrimaryPart
	end
	table.insert(rec.Conns, cfg:GetAttributeChangedSignal("Sniffed"):Connect(sniffed))
	sniffed()
end

local function stepEggs()
	local holding = player:GetAttribute("Holding") ~= nil
	-- your companion with a free back, when your hands are full and it's learned to carry
	local carrier, carrierName = nil, "companion"
	if holding and player:GetAttribute("CompanionCarry") == true then
		for _, c in ipairs(Chasers:GetChildren()) do
			if c:GetAttribute("Buddy") and c:GetAttribute("Owner") == player.UserId and not c:GetAttribute("CarryEgg") and c:GetAttribute("State") ~= "Downed" then
				carrier, carrierName = c, string.upper(tostring(c:GetAttribute("Name") or "companion"))
				break
			end
		end
	end
	for cfg, e in pairs(eggs) do
		if cfg.Parent and not eggVisible(cfg) then
			-- (just became one you can't take: gone quietly)
			for _, c in ipairs(e.Conns or {}) do c:Disconnect() end
			e.Model:Destroy()
			eggs[cfg] = nil
			continue
		end
		if not cfg.Parent then
			DinosaurVFX.BlockRing(CFrame.new(e.Pos + Vector3.new(0, 1, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 10, R0 = 0.4, R1 = 3, Color = Color3.fromRGB(255, 240, 180), Duration = 0.3 })
			for _, c in ipairs(e.Conns or {}) do c:Disconnect() end
			e.Model:Destroy()
			eggs[cfg] = nil
			continue
		end
		-- a gentle wobble in the nest
		e.Model:PivotTo(CFrame.new(e.Pos + Vector3.new(0, e.Lift, 0)) * CFrame.Angles(math.sin(os.clock() * 2 + e.Pos.X) * 0.06, 0, math.cos(os.clock() * 1.7 + e.Pos.Z) * 0.06))
		-- hands full: a companion that's learned to carry takes the next one for you - the prompt says who (it read
		-- "Companion carry", and kids didn't know what it did or where the egg went - 2026-10-14)
		-- (a boss egg goes straight to your bag: hands full or not, you take it yourself)
		local boss = cfg:GetAttribute("BossEgg") == true
		local carry = carrier ~= nil and not boss
		e.Prompt.ActionText = carry and ("Give to " .. carrierName) or "Pick up"
		-- (no egg pop-ups while RODEO! is up: they shared E with it)
		e.Prompt.Enabled = rodeoPrompt == nil and (not holding or carry or boss) and not player:GetAttribute("Downed") and (cfg:GetAttribute("Owner") == nil or cfg:GetAttribute("Owner") == player.UserId)
	end
end

-- prompts on your own rover: LOAD the egg you're carrying, DRIVE OFF once something's on the rack
local roverPrompts = { Load = nil :: ProximityPrompt?, Go = nil :: ProximityPrompt?, Root = nil :: BasePart?, Raw = nil :: string?, Loaded = 0 }
local function stepRover()
	local root = active and ownRover() or nil
	if root ~= roverPrompts.Root then
		if roverPrompts.Load then roverPrompts.Load:Destroy() end
		if roverPrompts.Go then roverPrompts.Go:Destroy() end
		roverPrompts.Load, roverPrompts.Go, roverPrompts.Root = nil, nil, root
		if root then
			local a = Instance.new("Attachment")
			a.Name = "DinoRoverPrompts"
			a.Position = Vector3.new(0, 3, 0)
			a.Parent = root
			local load = Instance.new("ProximityPrompt")
			load.ActionText = "Load egg"
			load:SetAttribute("Outline", true)
			load.ObjectText = "Roof rack"
			load.HoldDuration = 0.5
			load.MaxActivationDistance = 14
			load.RequiresLineOfSight = false
			load.KeyboardKeyCode = Enum.KeyCode.E
			load.GamepadKeyCode = Enum.KeyCode.ButtonX
			load.Parent = a
			load.Triggered:Connect(function()
				task.spawn(function()
					local res = Net.Ask("LoadEgg")
					if res and res.Ok then
						Kit.Toast(string.format("EGG LOADED! %d/%d ON THE RACK", res.Loaded, res.Capacity), "Green", "Rack")
						DinosaurVFX.BlockRing(CFrame.new(root.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 12, R0 = 0.5, R1 = 5, Color = C.YellowHi, Duration = 0.35 })
					elseif res and res.Err then Kit.Toast(res.Err, "Orange", "Rack") end
				end)
			end)
			local go = Instance.new("ProximityPrompt")
			go.ActionText = "DRIVE OFF!"
			go.ObjectText = "Escape with the eggs"
			go.HoldDuration = 0.6
			go.MaxActivationDistance = 14
			go.RequiresLineOfSight = false
			-- (R, not F: F fires your launcher at a site and would never reach the prompt)
			go.KeyboardKeyCode = Enum.KeyCode.R
			go.GamepadKeyCode = Enum.KeyCode.ButtonY
			go.UIOffset = Vector2.new(0, 70)
			go.Parent = a
			go.Triggered:Connect(function()
				task.spawn(function()
					local res = Net.Ask("DriveOff")
					if res and not res.Ok and res.Err then Kit.Toast(res.Err, "Orange", "Jeep") end
				end)
			end)
			roverPrompts.Load, roverPrompts.Go = load, go
		end
	end
	if roverPrompts.Load and roverPrompts.Go then
		local run = Runtime.Runs:FindFirstChild(tostring(player.UserId))
		-- (decoded only when the rack changes: this runs every frame)
		local raw = run and run:GetAttribute("Eggs") or "[]"
		if raw ~= roverPrompts.Raw then
			local ok, list = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
			roverPrompts.Raw, roverPrompts.Loaded = raw, ok and #list or 0
		end
		local loaded = roverPrompts.Loaded or 0
		local holding = player:GetAttribute("Holding") ~= nil
		-- your companion carrying an egg for you: that loads (and rides off) too
		local compEgg = false
		for _, cfg in ipairs(Chasers:GetChildren()) do
			if cfg:GetAttribute("Buddy") and cfg:GetAttribute("Owner") == player.UserId and cfg:GetAttribute("CarryEgg") then compEgg = true end
		end
		roverPrompts.Load.Enabled = (holding or compEgg) and rodeoPrompt == nil -- (it shares E with RODEO!: loading can wait ~7 s)
		if ui.PutDown then ui.PutDown.Visible = active and holding and not player:GetAttribute("Downed") end
		-- (a won boss fight: the boss egg went straight to your bag and a boss den has no MAP - you can always go)
		local sf = siteKey and Sites:FindFirstChild(((siteKey :: string):gsub("/", "_")))
		local won = sf ~= nil and sf:GetAttribute("Boss") == true and (sf:GetAttribute("Phase") or 0) >= 4
		roverPrompts.Go.Enabled = (loaded > 0 or compEgg or won) and not holding
		roverPrompts.Go.ObjectText = (won and loaded == 0) and "Drive off" or string.format("Escape with %d egg%s", loaded, loaded == 1 and "" or "s")
	end
end

--------------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------------
local function build()
	local gui, canvas = Kit.Screen("DinoFight", 13, false, 0.6)
	ui.Gui, ui.Canvas = gui, canvas
	gui.Enabled = false
	-- health (bottom left)
	local hp = Instance.new("Frame")
	hp.BackgroundTransparency = 1
	hp.AnchorPoint = Vector2.new(0, 1)
	hp.Position = UDim2.new(0, 24, 1, -24)
	hp.Size = UDim2.fromOffset(340, 70)
	hp.Parent = canvas
	Kit.Icon(hp, "Armor", { Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Rotation = -8, ZIndex = 8 })
	ui.HPText = Kit.Text(hp, "100", { Size = UDim2.new(1, -80, 0, 30), Position = UDim2.fromOffset(74, 0), Align = Enum.TextXAlignment.Left, Stroke = 4, Shadow = 3, Color = C.Lime, MaxSize = 34 })
	ui.SetHP = Kit.Segments(hp, 10, { Size = UDim2.new(1, -80, 0, 22), Position = UDim2.fromOffset(74, 38) })
	ui.HP = hp
	-- target calm (top centre)
	local tg = Instance.new("Frame")
	tg.BackgroundTransparency = 1
	tg.AnchorPoint = Vector2.new(0.5, 0)
	tg.Position = UDim2.new(0.5, 0, 0, 14)
	tg.Size = UDim2.fromOffset(520, 80)
	tg.Parent = canvas
	ui.TargetName = Kit.Text(tg, "", { Size = UDim2.new(1, 0, 0, 30), Stroke = 4, Shadow = 3, MaxSize = 34 })
	ui.SetCalm = Kit.Segments(tg, 20, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 38) })
	ui.CalmHint = Kit.Text(tg, "", { Pixel = true, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 66), Stroke = 2.5, Color = C.Cream })
	ui.Target = tg
	-- crosshair: four ticks that spread on fire, a hit marker, a charge ring and the combo counter
	local ch = Instance.new("Frame")
	ch.Name = "Crosshair"
	ch.BackgroundTransparency = 1
	ch.AnchorPoint = Vector2.new(0.5, 0.5)
	ch.Position = UDim2.fromScale(0.5, 0.5)
	ch.Size = UDim2.fromOffset(60, 60)
	ch.Parent = canvas
	ui.Crosshair = ch
	ui.Ticks = {}
	for i, d in ipairs({ Vector2.new(0, -1), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(-1, 0) }) do
		local t = Instance.new("Frame")
		t.BackgroundColor3 = Color3.new(1, 1, 1)
		t.BorderSizePixel = 0
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Size = d.X ~= 0 and UDim2.fromOffset(10, 4) or UDim2.fromOffset(4, 10)
		t.Parent = ch
		Kit.Stroke(t, C.Ink, 1.5)
		ui.Ticks[i] = { Frame = t, Dir = d }
	end
	local dot = Instance.new("Frame")
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.Parent = ch
	Kit.Stroke(dot, C.Ink, 1.5)
	ui.Dot = dot
	local hm = Kit.Glyph(ch, "X", { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.new(1, 1, 1) })
	hm.Visible = false
	ui.HitMarkGlyph = hm
	function ui.HitMark(color: Color3)
		for _, b in ipairs(hm:GetChildren()) do if b:IsA("Frame") and b.Name == "Fill" then b.BackgroundColor3 = color end end
		hm.Visible = true
		Kit.Pop(hm, 1.6)
		local my = {}
		ui.HitToken = my
		task.delay(0.16, function() if ui.HitToken == my then hm.Visible = false end end)
	end
	ui.SetCharge, ui.ChargeBar = Kit.Segments(canvas, 8, { Size = UDim2.fromOffset(90, 8), Position = UDim2.new(0.5, 0, 0.5, 40), AnchorPoint = Vector2.new(0.5, 0) })
	ui.ChargeBar.Visible = false
	ui.ChargedTag = Kit.Text(canvas, "CHARGED", { Pixel = true, Size = UDim2.fromOffset(120, 11), Position = UDim2.new(0.5, 0, 0.5, -46), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 2, Shadow = 1, Color = C.YellowHi, MaxSize = 11 })
	ui.ChargedTag.Visible = false
	-- ammo: one pip per dart in the magazine, RELOADING with a filling bar when it's empty
	ui.Ammo = Instance.new("Frame")
	ui.Ammo.BackgroundTransparency = 1
	ui.Ammo.AnchorPoint = Vector2.new(0.5, 0)
	ui.Ammo.Position = UDim2.new(0.5, 0, 0.5, 34)
	ui.Ammo.Size = UDim2.fromOffset(120, 12)
	ui.Ammo.Parent = canvas
	local pl = Instance.new("UIListLayout")
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pl.Padding = UDim.new(0, 4)
	pl.Parent = ui.Ammo
	ui.Pips = {}
	for i = 1, 10 do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(8, 12)
		pip.BackgroundColor3 = C.YellowHi
		pip.BorderSizePixel = 0
		pip.LayoutOrder = i
		pip.Parent = ui.Ammo
		local ps = Instance.new("UIStroke")
		ps.Thickness = 1.5
		ps.Color = C.Ink
		ps.Parent = pip
		ui.Pips[i] = pip
	end
	ui.Reload = Kit.Text(canvas, "RELOADING", { Pixel = true, Size = UDim2.fromOffset(160, 11), Position = UDim2.new(0.5, 0, 0.5, 52), AnchorPoint = Vector2.new(0.5, 0), Stroke = 2, Shadow = 1, Color = C.OrangeHi, MaxSize = 11 })
	ui.Reload.Visible = false
	ui.Combo = Kit.Text(canvas, "", { Size = UDim2.fromOffset(120, 40), Position = UDim2.new(0.5, 46, 0.5, -10), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, Stroke = 4, Shadow = 3, Color = C.OrangeHi, MaxSize = 40 })
	ui.SetComboTime, ui.ComboBar = Kit.Segments(canvas, 6, { Size = UDim2.fromOffset(60, 6), Position = UDim2.new(0.5, 48, 0.5, 14) })
	ui.CursorHint = Kit.Text(canvas, "HOLD ALT FOR CURSOR", { Pixel = true, Size = UDim2.fromOffset(260, 10), Position = UDim2.new(0.5, 0, 1, -14), AnchorPoint = Vector2.new(0.5, 1), Stroke = 2, Shadow = 1, Color = C.Cream, MaxSize = 10 })
	-- action buttons (bottom right; on keyboard they show their keys)
	ui.FireBtn = Kit.Tile(canvas, { Name = "Fire", Icon = "Launcher", Label = "DART", Color = "Orange", Size = UDim2.fromOffset(118, 118), Position = UDim2.new(1, -22, 1, -24), AnchorPoint = Vector2.new(1, 1) })
	local fireHit = ui.FireBtn:FindFirstChild("Hit") :: TextButton
	fireHit.MouseButton1Down:Connect(function() View.TriggerDown() end)
	fireHit.MouseButton1Up:Connect(function() View.TriggerUp() end)
	ui.DodgeBtn = Kit.Tile(canvas, { Name = "Dodge", Icon = "Footprints", Label = "DODGE", Color = "Blue", Size = UDim2.fromOffset(96, 96), Position = UDim2.new(1, -152, 1, -24), AnchorPoint = Vector2.new(1, 1), OnClick = function() View.Dodge() end })
	ui.Gadget = {}
	for i = 1, Config.GadgetSlots do
		ui.Gadget[i] = Kit.Tile(canvas, { Name = "Gadget" .. i, Icon = "Star", Label = tostring(i), Color = "Purple", Size = UDim2.fromOffset(76, 76), Position = UDim2.new(1, -22 - (i - 1) * 88, 1, -158), AnchorPoint = Vector2.new(1, 1), OnClick = function() View.Gadget(i) end })
	end
	-- keycaps: what to press on keyboard / gamepad (hidden on touch); swapped live when the input changes
	local function cap(tile: Frame, w: number): Frame
		return Kit.Text(tile, "", { Pixel = true, Size = UDim2.fromOffset(w, 12), Position = UDim2.new(0, 8, 0, 6), Stroke = 2, Shadow = 1, Color = C.YellowHi, MaxSize = 12, ZIndex = 30 })
	end
	ui.Keys = { cap(ui.FireBtn, 46), cap(ui.DodgeBtn, 30) }
	ui.KeyText = { { "LMB", "RT" }, { "Q", "B" } }
	for i, g in ipairs(ui.Gadget) do
		table.insert(ui.Keys, cap(g, 28))
		table.insert(ui.KeyText, { tostring(i), i == 1 and "LB" or "RB" })
	end
	-- the dodge button flashes red while an attack is lined up on you (dodge right as it lands = PERFECT)
	local cue = Instance.new("Frame")
	cue.Name = "DodgeCue"
	cue.BackgroundColor3 = Color3.fromRGB(255, 60, 40)
	cue.BackgroundTransparency = 1
	cue.Size = UDim2.new(1, 10, 1, 10)
	cue.Position = UDim2.fromScale(0.5, 0.5)
	cue.AnchorPoint = Vector2.new(0.5, 0.5)
	cue.ZIndex = 1
	cue.Parent = ui.DodgeBtn
	Instance.new("UICorner", cue).CornerRadius = UDim.new(0, 20)
	ui.DodgeCue = cue
	-- the roll recharging: a dark shade over the button that drains away (gone = you can roll)
	local shade = Instance.new("Frame")
	shade.Name = "DodgeCooldown"
	shade.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	shade.BackgroundTransparency = 0.35
	shade.BorderSizePixel = 0
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.fromScale(0, 1)
	shade.Size = UDim2.fromScale(1, 0)
	shade.ZIndex = 40
	shade.Parent = ui.DodgeBtn
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0.22, 0)
	sc.Parent = shade
	ui.DodgeShade = shade
	ui.CueUntil = 0
	-- put down the egg in your arms (G / d-pad down / this button)
	do
		local plat = Kit.Platform()
		local label = plat == "Pad" and "PUT DOWN  (D-PAD DOWN)" or (plat == "Touch" and "PUT DOWN" or "PUT DOWN  [G]")
		local b = Kit.Button(canvas, { Name = "PutDown", Text = label, Icon = "Egg", Color = "Slate", Size = UDim2.fromOffset(plat == "Touch" and 170 or 230, 52), Position = UDim2.new(0, 24, 1, -142), AnchorPoint = Vector2.new(0, 1), ZIndex = 30, OnClick = function() View.PutDown() end })
		b.Visible = false
		ui.PutDown = b
	end
	-- down: GIVE UP instead of waiting out the timer (tap twice - one stray tap mustn't end your run)
	do
		local plat = Kit.Platform()
		local function label(confirm: boolean): string
			if confirm then return "TAP AGAIN TO GIVE UP" end
			return plat == "Pad" and "GIVE UP  (Y)" or (plat == "Touch" and "GIVE UP" or "GIVE UP  [G]")
		end
		local armed = 0
		local function press()
			if not player:GetAttribute("Downed") then return end
			if os.clock() > armed then
				armed = os.clock() + 3
				local lbl = ui.GiveUp and ui.GiveUp:FindFirstChild("Text", true)
				if lbl then Kit.SetText(lbl :: any, label(true)) end
				task.delay(3, function()
					if os.clock() >= armed and ui.GiveUp then
						local l2 = ui.GiveUp:FindFirstChild("Text", true)
						if l2 then Kit.SetText(l2 :: any, label(false)) end
					end
				end)
				return
			end
			armed = 0
			task.spawn(function() Net.Ask("GiveUp") end)
		end
		local b = Kit.Button(canvas, { Name = "GiveUp", Text = label(false), Icon = "Alert", Color = "Red", Size = UDim2.fromOffset(plat == "Touch" and 200 or 260, 52), Position = UDim2.new(0.5, 0, 0.3, 46), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 30, OnClick = press })
		b.Visible = false
		ui.GiveUp = b
		UserInputService.InputBegan:Connect(function(input, gp)
			if gp or not b.Visible then return end
			if input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.ButtonY then press() end
		end)
	end
	-- eggs carried
	ui.Eggs = Kit.Text(canvas, "", { Size = UDim2.fromOffset(260, 30), Position = UDim2.new(0, 24, 1, -104), AnchorPoint = Vector2.new(0, 1), Align = Enum.TextXAlignment.Left, Stroke = 4, Shadow = 3, Color = C.YellowHi, MaxSize = 32 })
	-- hurt + downed overlays
	local root = gui:FindFirstChild("Root") :: Frame
	local vig = Instance.new("ImageLabel")
	vig.BackgroundTransparency = 1
	vig.Image = "rbxasset://textures/ui/TopBar/WhiteOverlayAsset.png"
	vig.ImageTransparency = 1
	vig.Size = UDim2.fromScale(1, 1)
	vig.Parent = root
	local hurt = Instance.new("Frame")
	hurt.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
	hurt.BackgroundTransparency = 1
	hurt.Size = UDim2.fromScale(1, 1)
	hurt.Parent = root
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(0.65, 1), NumberSequenceKeypoint.new(1, 0) })
	g.Parent = hurt
	ui.Hurt = hurt
	local dn = Instance.new("Frame")
	dn.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
	dn.BackgroundTransparency = 1
	dn.Size = UDim2.fromScale(1, 1)
	dn.Parent = root
	ui.DownTint = dn
	ui.DownText = Kit.Text(canvas, "", { Size = UDim2.fromOffset(700, 44), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 5, Shadow = 4, Color = C.RedHi, MaxSize = 48 })
	ui.Banner = Kit.Banner(canvas, { Position = UDim2.new(0.5, 0, 0, 120), ZIndex = 30 })
	-- the sneak bar (eye + one line), under the target panel
	local sn = Instance.new("Frame")
	sn.BackgroundTransparency = 1
	sn.AnchorPoint = Vector2.new(0.5, 0)
	sn.Position = UDim2.new(0.5, 0, 0, 100)
	sn.Size = UDim2.fromOffset(560, 40)
	sn.Visible = false
	sn.Parent = canvas
	Kit.Icon(sn, "Eye", { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 8 })
	ui.SneakText = Kit.Text(sn, "", { Pixel = true, Size = UDim2.new(1, -50, 0, 13), Position = UDim2.new(0, 48, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, Stroke = 2.5, Shadow = 2, MaxSize = 13, ZIndex = 8 })
	ui.Sneak = sn
end

function View.Gadget(slot: number)
	if not active or Cinema.Playing() then return end
	task.spawn(function()
		local res = Net.Ask("Gadget", { Slot = slot })
		if res.Ok then
			Kit.Punch(ui.Gadget[slot], 0.3)
			ui.GadgetReady = ui.GadgetReady or {}
			ui.GadgetReady[slot] = os.clock() + (res.Cooldown or 15)
		elseif res.Err then
			Kit.Toast(res.Err, "Grey", "Clock")
		end
	end)
end

local function refreshGadgets()
	local g = profileGear()
	for i, tile in ipairs(ui.Gadget) do
		local id = g.Gadgets and g.Gadgets[i] or ""
		tile.Visible = active and id ~= ""
		local label = tile:FindFirstChild("Label", true)
		if label and id ~= "" then Kit.SetText(label, (Config.Gadgets[id] and Config.Gadgets[id].Name or id):sub(1, 9)) end
		local holder = tile:FindFirstChild("Content", true)
		local icon = holder and holder:FindFirstChildWhichIsA("GuiObject")
		if icon and id ~= "" and icon.Name ~= "Icon_Gadget_" .. id then
			icon:Destroy()
			Kit.Icon(holder :: Instance, "Gadget_" .. id, { Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = tile.ZIndex + 4 })
		end
	end
end

local downedPrompts = {} :: { [Player]: ProximityPrompt }
local buddyPrompts = {} :: { [Instance]: ProximityPrompt }
-- holding a revive prompt: you kneel and pump their chest
local function reviveHold(p: ProximityPrompt, target: () -> Vector3?)
	p.PromptButtonHoldBegan:Connect(function()
		PlayerAnim.SetLoop(player.Character, "Revive")
		PlayerAnim.Look(player.Character, target)
	end)
	p.PromptButtonHoldEnded:Connect(function()
		PlayerAnim.SetLoop(player.Character, nil)
		PlayerAnim.Look(player.Character, nil)
	end)
end
local function stepRevivePrompts()
	-- (nothing to do away from a site with no prompts up: this used to scan every actor every frame anywhere)
	-- (a friend's revive prompt is still up after you left the site: keep going until it's taken down)
	if not active and next(buddyPrompts) == nil and next(downedPrompts) == nil then return end
	-- downed buddies (yours or a friend's): hold E to get them back up
	for _, cfg in ipairs(Chasers:GetChildren()) do
		local down = active and cfg:GetAttribute("Buddy") and cfg:GetAttribute("State") == "Downed" and cfg:GetAttribute("Site") == siteKey
		local pr = buddyPrompts[cfg]
		local creature = down and Exp and Exp.Creatures()[cfg]
		if creature and creature.Root and not pr then
			local p = Instance.new("ProximityPrompt")
			p.ActionText = "Revive"
			p.ObjectText = cfg:GetAttribute("Name") or "Buddy"
			p.HoldDuration = Config.Buddy.ReviveTime
			p.MaxActivationDistance = 10
			p.RequiresLineOfSight = false
			p.KeyboardKeyCode = Enum.KeyCode.E
			p:SetAttribute("Revive", true)
			p.Parent = creature.Root
			local root = creature.Root
			reviveHold(p, function() return root.Parent and root.Position or nil end)
			p.Triggered:Connect(function()
				task.spawn(function()
					local res = Net.Ask("ReviveBuddy", { Id = cfg:GetAttribute("Id") })
					if res and not res.Ok and res.Err then Kit.Toast(res.Err, "Red", "Shield") end
				end)
			end)
			buddyPrompts[cfg] = p
		elseif not creature and pr then
			pr:Destroy()
			buddyPrompts[cfg] = nil
		end
	end
	for cfg, pr in pairs(buddyPrompts) do
		if not cfg.Parent then pr:Destroy() buddyPrompts[cfg] = nil end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		local isDown = plr ~= player and plr:GetAttribute("Downed") == true and plr:GetAttribute("Site") == siteKey and active
		local pr = downedPrompts[plr]
		-- (their character respawned: the old prompt went with it - make a new one if they're down again)
		if pr and not pr.Parent then
			downedPrompts[plr] = nil
			pr = nil
		end
		if isDown and not pr then
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local p = Instance.new("ProximityPrompt")
				p.ActionText = "Revive"
				p.ObjectText = plr.DisplayName
				p.HoldDuration = Config.Player.ReviveTime
				p.MaxActivationDistance = 9
				p.RequiresLineOfSight = false
				p.KeyboardKeyCode = Enum.KeyCode.E
				p:SetAttribute("Revive", true)
				p.Parent = root
				reviveHold(p, function() return root.Parent and root.Position or nil end)
				p.Triggered:Connect(function()
					task.spawn(function()
						local res = Net.Ask("Revive", { UserId = plr.UserId })
						if not res.Ok and res.Err then Kit.Toast(res.Err, "Red", "Shield") end
					end)
				end)
				downedPrompts[plr] = p
			end
		elseif not isDown and pr then
			pr:Destroy()
			downedPrompts[plr] = nil
		end
	end
	for plr, pr in pairs(downedPrompts) do
		if not plr.Parent then pr:Destroy() downedPrompts[plr] = nil end
	end
end

-- where the RODEO! prompt hangs: on the body's surface right beside you, at your height (2026-10-14, user: "it says
-- get closer" - it hung on the root in the middle of the 32-stud Tidebreaker and opened 14 from THAT, while the
-- server measured the same 14 flat: standing at its head you got the prompt's button and then GET CLOSER). Both now
-- measure from the body: a capsule along its length from the species' template x its Scale - the same numbers as
-- Encounter.luau's bodyGap, which allows RODEO_REACH plus a little lag. Every species and size, land bosses too
local RODEO_REACH = 9
local bodyExtents = {} :: { [string]: Vector3 }
local function rodeoSpot(cfg: Configuration, creature: any, me: Vector3): Vector3
	local species = tostring(cfg:GetAttribute("Species") or "")
	local base = bodyExtents[species]
	if not base then
		local folder = DinoShared:FindFirstChild("Dinosaurs")
		local t = folder and folder:FindFirstChild(species)
		local ok, ext = pcall(function() return (t :: Model):GetExtentsSize() end)
		base = (ok and typeof(ext) == "Vector3") and ext or Vector3.new(4, 4, 8)
		bodyExtents[species] = base
	end
	local b = base :: Vector3
	local scale = tonumber(cfg:GetAttribute("Scale")) or 1
	local len, wide = math.max(b.X, b.Z) * scale, math.min(b.X, b.Z) * scale
	local r = wide * 0.35
	local half = math.max(0, len / 2 - r)
	local pos = cfg:GetAttribute("P")
	if typeof(pos) ~= "Vector3" then pos = creature.Root.Position end
	local yaw = tonumber(cfg:GetAttribute("Yaw")) or 0
	local fwd = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local along = math.clamp(Vector3.new(me.X - pos.X, 0, me.Z - pos.Z):Dot(fwd), -half, half)
	local axis = pos + fwd * along
	local out = Vector3.new(me.X - axis.X, 0, me.Z - axis.Z)
	local surf = axis + (out.Magnitude > 0.05 and out.Unit * math.min(r, out.Magnitude) or Vector3.zero)
	local bottom = creature.Root.Position.Y - (creature.Lift or 0)
	return Vector3.new(surf.X, math.clamp(me.Y, bottom, bottom + b.Y * scale), surf.Z)
end

local rodeoFor: Configuration? = nil
local function stepRodeoPrompt()
	if not active and not rodeoPrompt then return end
	local open = nil
	for _, cfg in ipairs(Chasers:GetChildren()) do
		if cfg:GetAttribute("Site") == siteKey and cfg:GetAttribute("RodeoOpen") then open = cfg end
	end
	local creature = open and Exp and Exp.Creatures()[open]
	local me = hrp()
	if open and creature and creature.Root and active and me then
		if not rodeoPrompt or rodeoFor ~= open or not (rodeoPrompt.Parent and rodeoPrompt.Parent.Parent == creature.Root) then
			if rodeoPrompt then
				local old = rodeoPrompt.Parent
				rodeoPrompt:Destroy()
				if old and old:IsA("Attachment") then old:Destroy() end
			end
			-- (an attachment on the body, moved every frame to the spot on its surface nearest you)
			local anchor = Instance.new("Attachment")
			anchor.Name = "RodeoAnchor"
			anchor.Parent = creature.Root
			local p = Instance.new("ProximityPrompt")
			p.ActionText = "RODEO!"
			p.ObjectText = "Jump on"
			p.HoldDuration = 0
			p.MaxActivationDistance = RODEO_REACH
			p.RequiresLineOfSight = false
			-- E again (user, 2026-10-13: the SPACE key cap read "SPA"); the egg prompts it shared E with hide while
			-- this is up (stepEggs), so E always means RODEO! here
			p.KeyboardKeyCode = Enum.KeyCode.E
			p.GamepadKeyCode = Enum.KeyCode.ButtonX
			p.Parent = anchor
			local id = open:GetAttribute("Id")
			p.Triggered:Connect(function()
				task.spawn(function()
					local res = Net.Ask("RodeoStart", { Id = id })
					if res.Ok then startRodeo(id, res.Time or Config.Encounter.RodeoTime)
					elseif res.Err then Kit.Toast(res.Err, "Orange", "Hand") end
				end)
			end)
			rodeoPrompt = p
			rodeoFor = open
		end
		local anchor = (rodeoPrompt :: ProximityPrompt).Parent
		if anchor and anchor:IsA("Attachment") then anchor.WorldPosition = rodeoSpot(open, creature, me.Position) end
	elseif rodeoPrompt then
		local old = rodeoPrompt.Parent
		rodeoPrompt:Destroy()
		if old and old:IsA("Attachment") then old:Destroy() end
		rodeoPrompt = nil
		rodeoFor = nil
	end
end

--------------------------------------------------------------------------------
-- the sneak: a "?" meter over every unaware dino (fills as it notices you), "!" when it's suspicious
--------------------------------------------------------------------------------
local aware = {} :: { [Configuration]: any }
stepAwareness = function(sf: Configuration?)
	local creatures = Exp and Exp.Creatures() or {}
	local seen = {}
	local anySus = false
	for cfg, c in pairs(creatures) do
		if cfg:GetAttribute("Site") ~= siteKey or cfg:GetAttribute("State") ~= "Unaware" or not c.Root then continue end
		seen[cfg] = true
		local rec = aware[cfg]
		if not rec then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(70, 80)
			bb.AlwaysOnTop = true
			bb.LightInfluence = 0
			bb.MaxDistance = 140
			local _, size = c.Model:GetBoundingBox()
			bb.StudsOffset = Vector3.new(0, size.Y * 0.6 + 2, 0)
			bb.Adornee = c.Root
			local mark = Kit.Text(bb, "?", { Size = UDim2.new(1, 0, 0, 50), Color = C.Cream, Stroke = 4, Shadow = 3, MaxSize = 50 })
			local track = Instance.new("Frame")
			track.BackgroundColor3 = C.Ink
			track.Size = UDim2.new(0.8, 0, 0, 10)
			track.Position = UDim2.new(0.1, 0, 0, 58)
			track.Parent = bb
			Kit.Corner(track, 5)
			local fill = Instance.new("Frame")
			fill.BackgroundColor3 = C.Yellow
			fill.Size = UDim2.fromScale(0, 1)
			fill.Parent = track
			Kit.Corner(fill, 5)
			bb.Parent = player:WaitForChild("PlayerGui")
			rec = { Bill = bb, Mark = mark, Fill = fill, Track = track }
			aware[cfg] = rec
		end
		local a = cfg:GetAttribute("Aware") or 0
		local sus = cfg:GetAttribute("Sus") == true
		anySus = anySus or sus
		rec.Fill.Size = UDim2.fromScale(a, 1)
		rec.Fill.BackgroundColor3 = a > 0.7 and C.Red or (a > 0.35 and C.Orange or C.Yellow)
		Kit.SetText(rec.Mark, sus and "!?" or "?")
		Kit.SetTextColor(rec.Mark, sus and C.OrangeHi or C.Cream)
		rec.Bill.Enabled = (a > 0.02 or sus) and not Cinema.Playing()
		if sus and not rec.WasSus then Kit.Pop(rec.Mark, 1.8) end
		rec.WasSus = sus
	end
	for cfg, rec in pairs(aware) do
		if not seen[cfg] then rec.Bill:Destroy() aware[cfg] = nil end
	end
	-- the sneak hint up top
	local sneaking = sf ~= nil and not sf:GetAttribute("Alarm") and not sf:GetAttribute("Boss") and not sf:GetAttribute("Takedown")
	ui.Sneak.Visible = sneaking
	if sneaking then
		Kit.SetText(ui.SneakText, anySus and "SOMETHING HEARD YOU..." or (sprinting and "TOO LOUD!" or "SNEAKING"))
		Kit.SetTextColor(ui.SneakText, anySus and C.OrangeHi or (sprinting and C.RedHi or C.Cream))
	end
end

--------------------------------------------------------------------------------
-- the lock-on reticle (over whatever the crosshair would hit)
--------------------------------------------------------------------------------
local reticle: BillboardGui? = nil
local reticleBits = {} :: any
local function ensureReticle(): BillboardGui
	if reticle and reticle.Parent then return reticle end
	local bb = Instance.new("BillboardGui")
	bb.Name = "DinoReticle"
	bb.Size = UDim2.fromOffset(150, 170)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(110, 110)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0, 72)
	frame.Parent = bb
	reticleBits.Frame = frame
	reticleBits.Corners = {}
	for i, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local h = Instance.new("Frame")
		h.BackgroundColor3 = Color3.new(1, 1, 1)
		h.BorderSizePixel = 0
		h.AnchorPoint = Vector2.new(c[1], c[2])
		h.Position = UDim2.fromScale(c[1], c[2])
		h.Size = UDim2.fromOffset(18, 5)
		h.Parent = frame
		Kit.Stroke(h, C.Ink, 1.5)
		local v = Instance.new("Frame")
		v.BackgroundColor3 = Color3.new(1, 1, 1)
		v.BorderSizePixel = 0
		v.AnchorPoint = Vector2.new(c[1], c[2])
		v.Position = UDim2.fromScale(c[1], c[2])
		v.Size = UDim2.fromOffset(5, 18)
		v.Parent = frame
		Kit.Stroke(v, C.Ink, 1.5)
		reticleBits.Corners[i] = { h, v }
	end
	reticleBits.SetCalm, reticleBits.Bar = Kit.Segments(bb, 10, { Size = UDim2.fromOffset(110, 10), Position = UDim2.new(0.5, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 0) })
	reticleBits.Tag = Kit.Text(bb, "", { Pixel = true, Size = UDim2.fromOffset(150, 11), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 0), Stroke = 2, Shadow = 1, MaxSize = 11 })
	bb.Parent = player:WaitForChild("PlayerGui")
	reticle = bb
	return bb
end

local function stepReticle(t: Configuration?)
	local creature = t and Exp and Exp.Creatures()[t]
	if not (active and t and creature and creature.Root) or Cinema.Playing() then
		if reticle then reticle.Enabled = false end
		return
	end
	local bb = ensureReticle()
	bb.Enabled = true
	if bb.Adornee ~= creature.Root then
		bb.Adornee = creature.Root
		Kit.Pop(reticleBits.Frame, 1.6)
	end
	local _, size = creature.Model:GetBoundingBox()
	bb.StudsOffset = Vector3.new(0, size.Y * 0.35, 0)
	local st = t:GetAttribute("State")
	local weak = t:GetAttribute("Weak") == true
	local col = weak and C.YellowHi or ((st == "Telegraph" or st == "Attack") and C.RedHi or Color3.new(1, 1, 1))
	local spin = os.clock() * (weak and 3 or 1.2)
	reticleBits.Frame.Rotation = math.deg(spin) % 90 * (weak and 1 or 0)
	local pulse = 1 + math.sin(os.clock() * 8) * (weak and 0.08 or 0.03)
	reticleBits.Frame.Size = UDim2.fromOffset(110 * pulse, 110 * pulse)
	for _, pair in ipairs(reticleBits.Corners) do pair[1].BackgroundColor3 = col pair[2].BackgroundColor3 = col end
	local calm, cmax = t:GetAttribute("Calm") or 0, math.max(1, t:GetAttribute("CalmMax") or 1)
	reticleBits.SetCalm(calm / cmax, weak and C.YellowHi or C.TealHi)
	Kit.SetText(reticleBits.Tag, weak and "WEAK SPOT!" or (t:GetAttribute("Shield") and "SHIELDED" or (t:GetAttribute("Enraged") and "ENRAGED" or "")))
	Kit.SetTextColor(reticleBits.Tag, weak and C.YellowHi or C.Cream)
end

--------------------------------------------------------------------------------
-- the frame
--------------------------------------------------------------------------------
local function combatCamOn(): boolean
	if not active or Cinema.Playing() or rodeo or Panels.IsOpen() then return false end
	if player:GetAttribute("Downed") then return false end
	if Kit.Platform() == "Touch" then return false end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then return false end
	return not freeCursor
end

local wasCam = false
-- leaves and bushes the camera passes through (they don't collide, so Roblox's camera ignores them):
-- anything between the lens and you, or wrapped round the lens, goes see-through until it's clear again
local faded = {} :: { [BasePart]: boolean }
local fadeParams = RaycastParams.new()
fadeParams.FilterType = Enum.RaycastFilterType.Exclude
fadeParams.RespectCanCollide = false
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
local function stepFoliageFade(cam: Camera, r: BasePart?)
	local want = {} :: { [BasePart]: boolean }
	if active and r and cam.CameraType == Enum.CameraType.Custom and not Cinema.Playing() then
		local skip = { player.Character :: Instance }
		local lf = Workspace:FindFirstChild("DinoExpeditionLocal")
		if lf then table.insert(skip, lf) end
		fadeParams.FilterDescendantsInstances = skip
		overlap.FilterDescendantsInstances = skip
		local from = cam.CFrame.Position
		local to = r.Position + Vector3.new(0, 1.5, 0)
		local function consider(part: Instance)
			if part:IsA("BasePart") and not part.CanCollide and part.Transparency < 0.9 and part.Size.Magnitude < 60 then want[part] = true end
		end
		for _ = 1, 4 do
			local hit = Workspace:Raycast(from, to - from, fadeParams)
			if not hit then break end
			consider(hit.Instance)
			table.insert(skip, hit.Instance)
			fadeParams.FilterDescendantsInstances = skip
			from = hit.Position
		end
		for _, part in ipairs(Workspace:GetPartBoundsInRadius(cam.CFrame.Position, 2.2, overlap)) do consider(part) end
	end
	for part in pairs(want) do
		if not faded[part] then faded[part] = true end
		part.LocalTransparencyModifier = math.min(0.75, part.LocalTransparencyModifier + 0.12)
	end
	for part in pairs(faded) do
		if not want[part] then
			part.LocalTransparencyModifier = math.max(0, part.LocalTransparencyModifier - 0.08)
			if part.LocalTransparencyModifier <= 0 or not part.Parent then faded[part] = nil end
		end
	end
end

local function stepCamera(dt: number)
	local h, r = hum(), hrp()
	local cam = Workspace.CurrentCamera
	stepFoliageFade(cam, r)
	local on = combatCamOn()
	local gamepad = Kit.Gamepad()
	-- shoulder offset eases in and out
	local want = (active and not rodeo) and Vector3.new(1.9, 0.45, 0) or Vector3.zero
	camOffset = camOffset:Lerp(want, math.min(1, dt * 8))
	if h then h.CameraOffset = camOffset end
	if on and not gamepad then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	elseif wasCam then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
	wasCam = on and not gamepad
	-- face where the camera looks (keyboard + gamepad); touch faces movement and turns to shoot
	local faceAim = active and not rodeo and (on or gamepad) and os.clock() > dodgingUntil and not player:GetAttribute("Downed")
	if h then h.AutoRotate = not faceAim end
	if faceAim and r then
		local lv = cam.CFrame.LookVector
		local flat = Vector3.new(lv.X, 0, lv.Z)
		if flat.Magnitude > 0.1 then
			local want2 = CFrame.lookAt(r.Position, r.Position + flat)
			local cur = r.CFrame
			r.CFrame = CFrame.new(cur.Position) * cur.Rotation:Lerp(want2.Rotation, math.min(1, dt * 18))
		end
	end
	-- FOV: sprint widens, a charge zooms, shots kick
	fovKick *= math.exp(-dt * 10)
	local fov = BASE_FOV
	if active and sprinting then fov += 7 end
	if charging then fov -= math.clamp((os.clock() - charging) / CHARGE_TIME, 0, 1) * 9 end
	if active and not Cinema.Playing() and cam.CameraType == Enum.CameraType.Custom then
		cam.FieldOfView += (fov + fovKick - cam.FieldOfView) * math.min(1, dt * 10)
	end
end

-- where the action buttons go. Keyboard / gamepad: the bottom-right cluster (they show their keys). Touch: built
-- around Roblox's own JUMP button so nothing covers it - FIRE big to its left, DODGE right above it, the gadgets
-- in a row above FIRE (thumb reach, no overlaps with RUN / DIVE further up the right edge)
layoutButtons = function(touch: boolean)
	if not ui.FireBtn then return end
	local canvas = ui.FireBtn.Parent :: Frame
	local sc = canvas:FindFirstChildOfClass("UIScale")
	local k = sc and sc.Scale or 1
	if not touch then
		ui.FireBtn.Size = UDim2.fromOffset(118, 118)
		ui.FireBtn.AnchorPoint = Vector2.new(1, 1)
		ui.FireBtn.Position = UDim2.new(1, -22, 1, -24)
		ui.DodgeBtn.Size = UDim2.fromOffset(96, 96)
		ui.DodgeBtn.AnchorPoint = Vector2.new(1, 1)
		ui.DodgeBtn.Position = UDim2.new(1, -152, 1, -24)
		for i, g in ipairs(ui.Gadget) do
			g.AnchorPoint = Vector2.new(1, 1)
			g.Position = UDim2.new(1, -22 - (i - 1) * 88, 1, -158)
		end
		if ui.PutDown then
			ui.PutDown.AnchorPoint = Vector2.new(0, 1)
			ui.PutDown.Position = UDim2.new(0, 24, 1, -142)
		end
		return
	end
	-- the jump button's rectangle, in canvas units (or Roblox's default spot if the touch gui isn't up yet)
	local cam = Workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local jl, jt, jr, jb
	local tg = player:FindFirstChild("PlayerGui") and (player.PlayerGui :: any):FindFirstChild("TouchGui")
	local jump = tg and tg:FindFirstChild("JumpButton", true) :: GuiObject?
	if jump and jump.AbsoluteSize.X > 4 then
		local p0, s0 = jump.AbsolutePosition - canvas.AbsolutePosition, jump.AbsoluteSize
		jl, jt, jr, jb = p0.X / k, p0.Y / k, (p0.X + s0.X) / k, (p0.Y + s0.Y) / k
	else
		local small = math.min(vs.X, vs.Y) <= 500
		local js = small and 70 or 120
		local ax, ay = vs.X - (js * 1.5 - 10), vs.Y - (small and (js + 20) or js * 1.75)
		local o = canvas.AbsolutePosition
		jl, jt, jr, jb = (ax - o.X) / k, (ay - o.Y) / k, (ax + js - o.X) / k, (ay + js - o.Y) / k
	end
	local fire = 112
	ui.FireBtn.Size = UDim2.fromOffset(fire, fire)
	ui.FireBtn.AnchorPoint = Vector2.new(1, 1)
	ui.FireBtn.Position = UDim2.fromOffset(jl - 12, jb)
	ui.DodgeBtn.Size = UDim2.fromOffset(86, 86)
	ui.DodgeBtn.AnchorPoint = Vector2.new(0.5, 1)
	ui.DodgeBtn.Position = UDim2.fromOffset((jl + jr) / 2, jt - 12)
	for i, g in ipairs(ui.Gadget) do
		g.AnchorPoint = Vector2.new(1, 1)
		g.Position = UDim2.fromOffset(jl - 12 - (i - 1) * 84, jb - fire - 12)
	end
	-- PUT DOWN over the gadgets on the right: bottom-left is the thumbstick's (a thumb there moved you instead)
	if ui.PutDown then
		ui.PutDown.AnchorPoint = Vector2.new(1, 1)
		ui.PutDown.Position = UDim2.fromOffset(jl - 12, jb - fire - 100)
	end
end

local function step(dt: number)
	local key = player:GetAttribute("Site")
	local now = typeof(key) == "string" and key or nil
	if now ~= siteKey then
		siteKey = now
		active = siteKey ~= nil
		if active then
			if player.Character then buildLauncher(player.Character, profileGear().Launcher) end
			for _, cfg in ipairs(SiteEggs:GetChildren()) do spawnEgg(cfg :: Configuration) end
		else
			if player.Character and launchers[player.Character] then launchers[player.Character]:Destroy() launchers[player.Character] = nil end
			charged = false -- (a banked perfect-dodge shot doesn't carry over to the next site)
			for _, e in pairs(eggs) do
				for _, c in ipairs(e.Conns or {}) do c:Disconnect() end
				e.Model:Destroy()
			end
			table.clear(eggs)
			charging = nil
			mag, reloadUntil = nil, 0
			local h = hum()
			if h then h.AutoRotate = true end
			Workspace.CurrentCamera.FieldOfView = BASE_FOV
		end
		refreshGadgets()
	end
	-- other players at the site carry launchers too
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr == player then continue end
		local c = plr.Character
		if not c then continue end
		local there = plr:GetAttribute("Site") ~= nil
		if there and not launchers[c] then buildLauncher(c, plr:GetAttribute("Launcher") or "Rookie")
		elseif not there and launchers[c] then launchers[c]:Destroy() launchers[c] = nil end
	end
	stepCamera(dt)
	ui.Gui.Enabled = active and not Cinema.Playing()
	stepRevivePrompts()
	stepRodeoPrompt()
	stepRover()
	if not active then stepReticle(nil) return end
	local sf = siteFolder()
	stepEggs()
	stepAwareness(sf)
	-- movement: sprint (not while charging), the body's stance follows
	local h = hum()
	local down = player:GetAttribute("Downed") == true
	local moving = h and h.MoveDirection.Magnitude > 0.1
	local sneaking = sf ~= nil and not sf:GetAttribute("Alarm") and not sf:GetAttribute("Boss") and not sf:GetAttribute("Takedown")
	local holding = player:GetAttribute("Holding") ~= nil
	local runFast = sprinting and moving and not charging and os.clock() - lastShot > 0.5
	if Kit.Platform() == "Touch" then runFast = (sprinting or not sneaking) and moving and os.clock() - lastShot > 1.6 and not charging end
	if h and Cinema.Playing() then
		h.WalkSpeed = 0 -- nobody walks off mid-cutscene (the camera is elsewhere)
	elseif h and not down then
		local walk = sneaking and Config.Encounter.Sneak.SneakSpeed or Config.Player.WalkSpeed
		if holding then walk = 9 end -- an egg is heavy and you can't see your feet
		h.WalkSpeed = runFast and (holding and 15 or Config.Player.SprintSpeed) or (charging and walk * 0.7 or walk)
		-- a SPRINT buddy (Gallimimus) in the hunt: everyone here is quicker (not while sneaking - that stays a creep)
		local buff = player:GetAttribute("SpeedBuff")
		if typeof(buff) == "number" and not sneaking then h.WalkSpeed *= math.clamp(buff, 1, 1.5) end
		-- caught in a terror roar: your legs won't go for a moment
		local fear = player:GetAttribute("FearUntil")
		if typeof(fear) == "number" and Workspace:GetServerTimeNow() < fear then h.WalkSpeed *= 0.45 end
	end
	local rig = PlayerAnim.Rig(player.Character)
	if rig then
		rig.Sprint = runFast == true
		rig.Stance = holding and "Carry" or (sneaking and "Sneak" or nil)
		local aimT = bestTarget(nil)
		local pitch = 0
		local r = hrp()
		local cam = Workspace.CurrentCamera
		if combatCamOn() or Kit.Gamepad() then
			pitch = math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1)) + 0.08
		elseif aimT and r then
			local p = aimPoint(aimT)
			if p then pitch = math.atan2(p.Y - (r.Position.Y + 1.5), Vector3.new(p.X - r.Position.X, 0, p.Z - r.Position.Z).Magnitude) end
		end
		PlayerAnim.SetAim(player.Character, pitch, not runFast)
	end
	ui.DownTint.BackgroundTransparency = down and (0.65 + math.sin(os.clock() * 3) * 0.08) or 1
	if down and not ui.DownAt then ui.DownAt = os.clock() elseif not down then ui.DownAt = nil end
	local left = ui.DownAt and math.max(0, Config.Player.DownedTime - (os.clock() - ui.DownAt)) or 0
	Kit.SetText(ui.DownText, down and string.format("DOWNED! A FRIEND CAN REVIVE YOU (%ds)", math.ceil(left)) or "")
	if ui.GiveUp then ui.GiveUp.Visible = active and down and not Cinema.Playing() end
	local hpv, max = player:GetAttribute("HP") or 100, player:GetAttribute("MaxHP") or 100
	Kit.SetText(ui.HPText, tostring(math.floor(hpv)))
	-- the health bar only shows when it matters: a fight is on, you're hurt, or it just changed
	if hpv ~= ui.LastHP then ui.LastHP = hpv ui.HPChangedAt = os.clock() end
	local fighting = sf ~= nil and (sf:GetAttribute("Alarm") or sf:GetAttribute("Boss") or sf:GetAttribute("Takedown")) and true or false
	ui.HP.Visible = fighting or down or hpv < max or os.clock() - (ui.HPChangedAt or 0) < 3
	ui.SetHP(hpv / math.max(1, max), hpv / max <= 0.3 and C.Red or (hpv / max <= 0.6 and C.Orange or C.Lime))
	-- target panel + reticle
	local t = bestTarget(nil)
	stepReticle(t)
	if not (t and t.Parent and t:GetAttribute("State") ~= "KO") then t = target end
	if t and t.Parent and t:GetAttribute("State") ~= "KO" then
		local calm, cmax = t:GetAttribute("Calm") or 0, t:GetAttribute("CalmMax") or 1
		local name = t:GetAttribute("DisplayName") or (Config.Species[t:GetAttribute("Species")] and Config.Species[t:GetAttribute("Species")].Name or "")
		Kit.SetText(ui.TargetName, name)
		ui.SetCalm(calm / math.max(1, cmax), t:GetAttribute("Weak") and C.YellowHi or C.TealHi)
		local hint = t:GetAttribute("Weak") and "WEAK SPOT!" or (t:GetAttribute("Shield") and "SHIELDED BY ITS PACK" or "")
		if t:GetAttribute("State") == "Unaware" then hint = "UNAWARE - AMBUSH x3" end
		if t:GetAttribute("RodeoOpen") then hint = "EXHAUSTED!" end
		Kit.SetText(ui.CalmHint, hint)
		ui.Target.Visible = true
	else
		ui.Target.Visible = sf ~= nil and (sf:GetAttribute("State") == "Scramble")
		Kit.SetText(ui.TargetName, sf and sf:GetAttribute("State") == "Scramble" and "GRAB THE EGGS!" or "")
		Kit.SetText(ui.CalmHint, "")
	end
	-- crosshair: spread from recent shots and movement, charge bar, combo timer
	local since = os.clock() - lastShot
	local spread = 9 + math.max(0, 0.25 - since) * 40 + (moving and 4 or 0)
	local onTarget = t ~= nil and bestTarget(nil) ~= nil
	for _, tk in ipairs(ui.Ticks) do
		tk.Frame.Position = UDim2.new(0.5, tk.Dir.X * spread, 0.5, tk.Dir.Y * spread)
		tk.Frame.BackgroundColor3 = charged and C.YellowHi or (onTarget and C.RedHi or Color3.new(1, 1, 1))
	end
	local touch = Kit.Platform() == "Touch"
	ui.Crosshair.Visible = not touch or charging ~= nil
	ui.ChargedTag.Visible = charged
	local size = magSize()
	local now2 = os.clock()
	local reloading = now2 < reloadUntil
	for i, pip in ipairs(ui.Pips) do
		pip.Visible = i <= size
		pip.BackgroundTransparency = (reloading or i > (mag or size)) and 0.75 or 0
	end
	ui.Reload.Visible = reloading
	if reloading then Kit.SetText(ui.Reload, string.format("RELOADING %.1f", reloadUntil - now2)) end
	if charging then
		local c = math.clamp((os.clock() - charging) / CHARGE_TIME, 0, 1)
		ui.ChargeBar.Visible = os.clock() - charging > 0.2
		ui.SetCharge(c, c >= 0.98 and C.YellowHi or C.OrangeHi)
		if c >= 0.98 and not ui.ChargeDing then ui.ChargeDing = true sfx("Charge") Kit.Punch(ui.Crosshair, 0.3) end
	else
		ui.ChargeBar.Visible = false
		ui.ChargeDing = false
	end
	local ct = os.clock() - comboT
	if ct > Config.Encounter.ComboWindow then combo = 0 end
	Kit.SetText(ui.Combo, combo >= 2 and ("x" .. combo) or "")
	ui.ComboBar.Visible = combo >= 2
	if combo >= 2 then ui.SetComboTime(1 - ct / Config.Encounter.ComboWindow, C.OrangeHi) end
	ui.FireBtn.Visible = true
	ui.DodgeBtn.Visible = true
	local pad = Kit.Gamepad()
	for i, k in ipairs(ui.Keys) do
		k.Visible = not touch
		Kit.SetText(k, ui.KeyText[i][pad and 2 or 1])
	end
	-- (the PUT DOWN button names the key for whatever you're holding right now, not what you joined with)
	local plat = touch and "Touch" or (pad and "Pad" or "Keys")
	if ui.PutDown and ui.PutDownPlat ~= plat then
		ui.PutDownPlat = plat
		Kit.SetText(ui.PutDown, plat == "Pad" and "PUT DOWN  (D-PAD DOWN)" or (plat == "Touch" and "PUT DOWN" or "PUT DOWN  [G]"))
	end
	-- the roll recharging
	do
		local left = nextDodge - os.clock()
		local total = math.max(0.05, nextDodge - dodgeStarted)
		ui.DodgeShade.Size = UDim2.fromScale(1, left > 0 and math.clamp(left / total, 0, 1) or 0)
		if left <= 0 and ui.DodgeWasCooling then Kit.Pop(ui.DodgeBtn, 1.15) end -- ready again
		ui.DodgeWasCooling = left > 0
	end
	-- the dodge cue: pulses while something's about to hit you
	local cueLeft = ui.CueUntil - os.clock()
	ui.DodgeCue.BackgroundTransparency = cueLeft > 0 and (0.25 + math.abs(math.sin(os.clock() * 14)) * 0.45) or 1
	if os.clock() >= (ui.NextLayout or 0) then ui.NextLayout = os.clock() + 0.5 layoutButtons(touch) end
	ui.CursorHint.Visible = not touch and not Kit.Gamepad()
	local run = Runtime.Runs:FindFirstChild(tostring(player.UserId))
	local rawEggs = run and run:GetAttribute("Eggs") or "[]"
	if rawEggs ~= ui.EggsRaw then
		local ok, list = pcall(function() return game:GetService("HttpService"):JSONDecode(rawEggs) end)
		ui.EggsRaw, ui.EggsN = rawEggs, ok and #list or 0
	end
	local carried = ui.EggsN or 0
	local slots = run and run:GetAttribute("Slots") or 2
	Kit.SetText(ui.Eggs, (carried > 0 or player:GetAttribute("Holding")) and ("ON THE RACK " .. carried .. "/" .. slots) or "")
	for i, tile in ipairs(ui.Gadget) do
		local ready = (ui.GadgetReady and ui.GadgetReady[i] or 0) <= os.clock()
		local body = tile:FindFirstChild("Body") :: Frame?
		if body then body.BackgroundTransparency = ready and 0 or 0.5 end
	end
end

local function charOf(userId: number): Model?
	local plr = Players:GetPlayerByUserId(userId)
	return plr and plr.Character
end

--------------------------------------------------------------------------------
function View.Start(exp)
	Exp = exp
	build()
	PlayerAnim.Start()
	SiteEggs.ChildAdded:Connect(function(cfg) if active then task.defer(spawnEgg, cfg :: Configuration) end end)
	Net.On("Tele", onTele)
	-- your parked rover got hit: it flashes red and shows the dent
	Net.On("RoverHit", function(info)
		local v = nil :: Model?
		do
			for _, m in ipairs((Workspace:FindFirstChild("ActiveVehicles") or Workspace):GetChildren()) do
				if m:IsA("Model") and m:GetAttribute("Owner") == player.UserId then v = m end
			end
		end
		if v and v.PrimaryPart then
			flashModel(v, Color3.fromRGB(255, 60, 40))
			floater(v.PrimaryPart.Position + Vector3.new(0, 4, 0), "-" .. tostring(info.Damage or 0), C.RedHi, 0.6, 5)
			DinosaurVFX.Shake(0.2, 0.15)
		end
		Kit.Toast("YOUR ROVER GOT HIT! " .. math.floor(info.HP or 0) .. " / " .. math.floor(info.MaxHP or 0), "Red", "Jeep")
	end)
	Net.On("Strike", function(info)
		local rec = teles[info.Key or info.Actor or 0]
		if rec then rec.Done = true end
		-- the attack lands with weight, shaped like what it was: a slam cracks the ground and throws a ring of
		-- blocks, a charge ploughs a furrow of dust, a sweep throws an arc of dirt and leaves
		local t = rec and rec.Info
		local r = hrp()
		local near = 1
		-- (the sea boss's blows land in water: SeaFight / BossFx throw the spray, not dirt and leaves)
		if t and typeof(t.O) == "Vector3" and t.Surface then
			if r then near = math.clamp(1 - ((r.Position - (t.O :: Vector3)).Magnitude - 10) / 40, 0.25, 1) end
		elseif t and typeof(t.O) == "Vector3" then
			local o = t.O :: Vector3
			local dir = (typeof(t.Dir) == "Vector3" and (t.Dir :: Vector3).Magnitude > 0.01) and (t.Dir :: Vector3).Unit or Vector3.new(0, 0, -1)
			if r then near = math.clamp(1 - ((r.Position - o).Magnitude - 10) / 40, 0.25, 1) end
			if t.Shape == "Circle" or t.Shape == "Ring" then
				local rad = t.R or 8
				DinosaurVFX.GroundImpact(o, rad / 8)
				DinosaurVFX.GroundCracks(o, rad / 8)
				DinosaurVFX.BlockRing(CFrame.new(o + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 22, R0 = 1, R1 = rad * 1.1, Color = Color3.fromRGB(150, 120, 90), Duration = 0.55, Block = 0.9 })
				DinosaurVFX.Cubes(o + Vector3.new(0, 1, 0), 18, { Color3.fromRGB(130, 100, 70), Color3.fromRGB(100, 170, 70), Color3.fromRGB(255, 160, 50) }, 0.45, 22, 1)
			elseif t.Shape == "Line" then
				local len = t.Len or 20
				DinosaurVFX.DustWave(o, dir, len / 20)
				for k = 1, 3 do
					DinosaurVFX.Cubes(o + dir * (len * k / 3) + Vector3.new(0, 1, 0), 8, { Color3.fromRGB(140, 110, 80), Color3.fromRGB(100, 170, 70) }, 0.4, 14, 0.8)
				end
			elseif t.Shape == "Cone" then
				local len = t.Len or 12
				DinosaurVFX.Cubes(o + dir * (len * 0.6) + Vector3.new(0, 1.5, 0), 22, { Color3.fromRGB(140, 110, 80), Color3.fromRGB(100, 170, 70), Color3.fromRGB(230, 70, 40) }, 0.4, 20, 0.9)
				DinosaurVFX.FoliageBurst(o + dir * (len * 0.5), len / 10)
			end
		end
		DinosaurVFX.Shake(0.75 * near, 0.25)
	end)
	Net.On("PlayerHit", function(info)
		local maxHp = math.max(1, player:GetAttribute("MaxHP") or 100)
		-- "big" is relative to YOUR health: a quarter of it in one go is a big hit in any era
		local big = (info.Damage or 0) >= maxHp * 0.22
		DinosaurVFX.Shake(big and 1.2 or 0.7, big and 0.45 or 0.28)
		if big then
			require(script.Parent.UI.CineKit).HitStop(0.06, 0.1, 0.15)
			fovKick = 9
		end
		ui.Hurt.BackgroundTransparency = big and 0.35 or 0.55
		TweenService:Create(ui.Hurt, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		Kit.Shake(ui.HP)
		sfx("Hurt")
		charging = nil
		-- knocked back away from whatever hit you
		local r = hrp()
		local side = 0
		if r then
			local nearest, nd = nil, math.huge
			for _, a in ipairs(actorsHere()) do
				if a.Root then
					local d = (a.Root.Position - r.Position).Magnitude
					if d < nd then nearest, nd = a.Root, d end
				end
			end
			if nearest then
				local away = Vector3.new(r.Position.X - nearest.Position.X, 0, r.Position.Z - nearest.Position.Z)
				if away.Magnitude > 0.1 then
					away = away.Unit
					side = r.CFrame.RightVector:Dot(away) > 0 and 1 or -1
					r.AssemblyLinearVelocity = away * (big and 46 or 26) + Vector3.new(0, big and 22 or 10, 0)
				end
			end
		end
		PlayerAnim.Act(player.Character, big and "BigHit" or "Hit", { Side = side })
		floater((r and r.Position or Vector3.zero) + Vector3.new(0, 3, 0), "-" .. math.floor(info.Damage or 0), C.RedHi, 0.6, 3)
	end)
	-- KNOCKBACK: a dino's hit that throws you (off the rock you camped on; the charge that caught you in a cutscene).
	-- A short, real shove (a LinearVelocity like the roll - the walk controller would cancel a plain velocity kick)
	Net.On("Knockback", function(info)
		local r = hrp()
		if not r or rodeo then return end
		local from = typeof(info.From) == "Vector3" and info.From or (r.Position - r.CFrame.LookVector)
		local d = Vector3.new(r.Position.X - from.X, 0, r.Position.Z - from.Z)
		d = d.Magnitude > 0.1 and d.Unit or -Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z).Unit
		local force = math.clamp(tonumber(info.Force) or 40, 10, 70)
		local att = r:FindFirstChild("DinoRollAtt") :: Attachment?
		if not att then
			local a = Instance.new("Attachment")
			a.Name = "DinoRollAtt"
			a.Parent = r
			att = a
		end
		local old = r:FindFirstChild("DinoKnock")
		if old then old:Destroy() end
		local lv = Instance.new("LinearVelocity")
		lv.Name = "DinoKnock"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.xAxis
		lv.SecondaryTangentAxis = Vector3.zAxis
		lv.MaxForce = 1e6
		lv.PlaneVelocity = Vector2.new(d.X * force, d.Z * force)
		lv.Parent = r
		r.AssemblyLinearVelocity = Vector3.new(d.X * force, math.clamp(tonumber(info.Up) or 28, 0, 50), d.Z * force)
		task.delay(0.28, function() if lv.Parent then lv:Destroy() end end)
		PlayerAnim.Act(player.Character, "BigHit", { Side = r.CFrame.RightVector:Dot(d) > 0 and 1 or -1 })
		DinosaurVFX.Shake(1.1, 0.45)
		DinosaurVFX.FootstepDust(r.Position - Vector3.new(0, 2.6, 0), 1.2)
		require(script.Parent.UI.CineKit).HitStop(0.08, 0.05, 0.15)
		-- (caught in a cutscene: a red flash on the screen edge says it, no words)
		if info.Caught then require(script.Parent.UI.CineKit).ImpactFrame(0.6) end
	end)
	-- the new buddy jobs (2026-10-12): a forager heals you, a scavenger runs your darts back, a spitter blinds
	Net.On("BuddyHelp", function(info)
		local r = hrp()
		local at = (r and r.Position or Vector3.zero) + Vector3.new(0, 5, 0)
		if info.Kind == "Heal" then
			floater(at, "+" .. math.floor(info.Amount or 0), C.TealHi, 0.6, 3)
		elseif info.Kind == "Reload" then
			mag, reloadUntil = magSize(), 0
			floater(at, "DARTS DELIVERED!", C.TealHi, 0.7, 4)
		elseif info.Kind == "Miss" then
			floater(at, "MISSED YOU!", C.YellowHi, 0.6, 3)
		elseif info.Kind == "Steal" then
			-- (a dino, not a buddy: a Compy snatched a dart)
			mag = math.min(mag, info.Mag or mag)
			floater(at, "DART STOLEN!", C.RedHi, 0.6, 3)
		end
	end)
	Net.On("PerfectDodge", function()
		charged = true
		mag, reloadUntil = magSize(), 0
		local rr = hrp()
		if rr then floater(rr.Position + Vector3.new(0, 6, 0), "INSTANT RELOAD!", C.TealHi, 0.7, 4) end
		nextDodge = math.min(nextDodge, os.clock() + (Config.Player.PerfectRefund or 0.5))
		sfx("Perfect")
		DinosaurVFX.Shake(0.4, 0.2)
		fovKick = 8
		local r = hrp()
		if r then floater(r.Position + Vector3.new(0, 4, 0), "PERFECT DODGE!", C.YellowHi, 0.8, 4) end
		Kit.Pop(ui.ChargedTag, 2)
		afterimages(player.Character :: Model, 4)
	end)
	-- a buddy's move: what it did, where, and how much it helped
	-- your buddies' fortunes
	Net.On("BuddyDown", function(info)
		if info.Owner == player.UserId then
			Kit.Toast((info.Name or "YOUR BUDDY") .. " IS DOWN! HOLD E ON IT TO HELP IT UP", "Red", "Buddy")
		end
	end)
	Net.On("BuddyFallen", function(info)
		-- two events share this name: the site's (everyone there: info.Buddy = actor id) and yours (info.Name)
		if info.Name then
			Kit.Toast(info.Name .. " IS HURT - IT RIDES HOME TO REST (HEAL IT IN YOUR BAG)", "Orange", "Buddy")
			return
		end
		-- (the site's copy: nobody's pet dies any more (2026-10-12) - it lies down where it fell and is carried
		-- back to the rover, which the buddy's own state already shows)
	end)
	Net.On("BuddyLost", function(info)
		local names = info.Names or {}
		if #names > 0 then
			task.delay(4, function() Kit.Toast("YOU FAINTED - " .. table.concat(names, ", ") .. " DIDN'T MAKE IT", "Red", "Buddy") end)
		end
	end)
	Net.On("BuddySaved", function(info)
		local names = info.Names or {}
		if #names > 0 then
			task.delay(2.5, function() Kit.Toast(table.concat(names, ", ") .. " MADE IT HOME - RESTING UP. IT'LL BE OK!", "Green", "Buddy") end)
		end
	end)
	Net.On("BuddyAct", function(info)
		local mine = info.Owner == player.UserId
		local at = typeof(info.T) == "Vector3" and info.T or nil
		local from = typeof(info.P) == "Vector3" and info.P or at
		if not (at and from) then return end
		local col = mine and C.OrangeHi or C.Cream
		floater(at + Vector3.new(0, 5, 0), "+" .. tostring(info.Amount or 0) .. (mine and ("  " .. tostring(info.Role or "")) or ""), col, mine and 0.6 or 0.4, mine and 4 or 3)
		if info.Area then
			DinosaurVFX.BlockRing(CFrame.new(from) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 22, R0 = 1, R1 = info.Area, Color = C.OrangeHi, Duration = 0.5, Block = 0.7 })
			DinosaurVFX.Shake(mine and 0.4 or 0.2, 0.2)
		end
		if info.Stun then DinosaurVFX.Cubes(at + Vector3.new(0, 4, 0), 8, { C.YellowHi, Color3.new(1, 1, 1) }, 0.3, 10, 0.6) end
		if info.Role == "HONK" then
			for cfg, c in pairs(Exp.Creatures()) do
				if cfg:GetAttribute("Id") == info.Buddy and c.Model then DinosaurVFX.SoundRings(c.Model, "VFX_Head", 1) end
			end
		end
	end)
	Net.On("SiteDart", function(info)
		if info.UserId == player.UserId then return end
		-- teammates' darts: their arm kicks, a dart flies from their launcher
		local c = charOf(info.UserId)
		if not c then return end
		PlayerAnim.Act(c, "Fire")
		for cfg, cr in pairs(Exp.Creatures()) do
			if cfg:GetAttribute("Id") == info.Actor and cr.Root then
				local dm
				dm = flyDart(muzzleOf(c), cfg, aimPoint(cfg) or cr.Root.Position, info.Weak and C.YellowHi or C.OrangeHi, info.Heavy == true, function(p)
					-- (a teammate's dart it sidestepped: a puff of dust where it was, no hit)
					if info.Result == "Dodge" then
						if dm and dm.Parent then dm:Destroy() end
						DinosaurVFX.FootstepDust(p, 0.6)
						return
					end
					impactFx(p, info.Weak and C.YellowHi or C.OrangeHi, info.Weak == true)
					flashModel(cr.Model, Color3.new(1, 1, 1))
				end)
			end
		end
	end)
	Net.On("PlayerAct", function(info)
		if info.UserId == player.UserId then
			if info.Act == "Throw" then PlayerAnim.Act(player.Character, "Throw") end
			return
		end
		local c = charOf(info.UserId)
		if not c then return end
		local r = c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if info.Act == "Dodge" and r then
			local v = r.AssemblyLinearVelocity
			local flat = Vector3.new(v.X, 0, v.Z)
			PlayerAnim.Act(c, "Dodge", { Dir = flat.Magnitude > 1 and r.CFrame:VectorToObjectSpace(flat.Unit) or Vector3.new(0, 0, 1), Duration = Config.Player.DodgeTime })
		else
			PlayerAnim.Act(c, info.Act)
		end
	end)
	Net.On("Spotted", function(info)
		local you = info.UserId == player.UserId
		-- the spotted cutscene tells the story; this line only lands once it's over (who got seen, what now)
		task.spawn(function()
			local t0 = os.clock()
			task.wait(0.5)
			while Cinema.Playing() and os.clock() - t0 < 30 do task.wait(0.1) end
			if player:GetAttribute("Site") then
				ui.Banner.Show("FIGHT!", you and "IT SAW YOU - CALM IT WITH DARTS, OR GRAB AN EGG AND RUN" or (string.upper(info.Name or "SOMEONE") .. " WAS SPOTTED - HELP OUT!"), "Alert", C.RedHi, 2.4)
			end
		end)
	end)
	-- a boss's signature move: its name big for a moment, and how to beat it
	Net.On("BossMove", function(info)
		if not info.Name then return end
		ui.Banner.Show(info.Name, info.Hint or "", "Alert", C.OrangeHi, 1.8)
	end)
	Net.On("Enrage", function(info)
		local name = Config.Species[info.Species] and Config.Species[info.Species].Name or "IT"
		ui.Banner.Show("ENRAGED!", name, "Alert", C.RedHi, 2.2)
		for cfg, c in pairs(Exp.Creatures()) do
			if cfg:GetAttribute("Id") == info.Actor and c.Model then
				if c.Anim and c.Anim:HasAction("Roar") then c.Anim:Play("Roar") end
				DinosaurVFX.EyeGlow(c.Model, 30)
				flashModel(c.Model, C.RedHi)
				DinosaurVFX.Shake(0.7, 0.35)
			end
		end
	end)
	-- a hurt dino roars for help: everyone else comes running
	Net.On("CallHelp", function(info)
		for cfg, c in pairs(Exp.Creatures()) do
			if cfg:GetAttribute("Id") == info.Actor and c.Model and c.Root then
				-- it throws its head back and bellows; the others come running (you see them turn and charge)
				if c.Anim and c.Anim:HasAction("Roar") then c.Anim:Play("Roar") end
				DinosaurVFX.BlockRing(CFrame.new(c.Root.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 18, R0 = 2, R1 = 22, Color = Color3.fromRGB(255, 170, 90), Duration = 0.6 })
				DinosaurVFX.Shake(0.5, 0.3)
				require(script.Parent.Audio).Play("Growl", { At = c.Root.Position, Pitch = 0.9 })
			end
		end
	end)
	-- your first fight: the first wind-up aimed at you - the DODGE button pulses hard (no words; the red ground
	-- outline already shows where it'll land)
	Net.On("DodgeHint", function()
		if ui.DodgeBtn then
			Kit.Punch(ui.DodgeBtn, 0.6)
			task.delay(0.35, function() if ui.DodgeBtn then Kit.Punch(ui.DodgeBtn, 0.5) end end)
			task.delay(0.7, function() if ui.DodgeBtn then Kit.Punch(ui.DodgeBtn, 0.4) end end)
		end
	end)
	Net.On("EggDropped", function() Kit.Toast("YOU DROPPED THE EGG!", "Red", "Egg") end)
	Net.On("Alarm", function(info)
		ui.Banner.Show("THE NEST IS OPEN!", string.upper(info.Name or "") .. " GRABBED AN EGG - THEY'RE ANGRY!", "Alert", C.RedHi, 2.6)
		DinosaurVFX.Shake(0.9, 0.4)
	end)
	Net.On("Scramble", function(info)
		if info.Takedown == false then
			-- grabbed from the nest, nobody knocked out: they're coming - get the eggs to the rover
			ui.Banner.Show("GRAB THE EGGS!", "CARRY THEM TO YOUR ROVER AND DRIVE OFF - FAST!", "Egg", C.YellowHi, 3)
		else
			ui.Banner.Show("KNOCKED OUT!", "THE NEST IS YOURS - CARRY THE EGGS TO YOUR ROVER (BETTER ODDS!)", "Egg", C.LimeHi, 3)
		end
		if info.Takedown then PlayerAnim.Act(player.Character, "Victory") end
	end)
	Net.On("KnockedOut", function(info)
		for cfg, c in pairs(Exp.Creatures()) do
			if cfg:GetAttribute("Id") == info.Actor and c.Root then
				DinosaurVFX.Stunned(c.Model, 6)
				-- the knockout lands like a cutscene beat: a storm of blocks and leaves, a big ring, a kick of the camera
				local _, e = c.Model:GetBoundingBox()
				local k = math.clamp(math.max(e.X, e.Y, e.Z) / 10, 0.8, 2.5)
				local sp = Config.Species[c.Species or ""] :: any
				local col = sp and sp.Color or C.LimeHi
				DinosaurVFX.Cubes(c.Root.Position + Vector3.new(0, e.Y * 0.3, 0), math.floor(30 * k), { col, Color3.fromRGB(230, 70, 40), Color3.fromRGB(255, 150, 40), Color3.fromRGB(120, 200, 70) }, 0.5 * k, 26 * k, 1.1)
				DinosaurVFX.Cubes(c.Root.Position + Vector3.new(0, e.Y * 0.5, 0), 14, { Color3.new(1, 1, 1), C.YellowHi }, 0.3, 30, 0.6)
				DinosaurVFX.BlockRing(CFrame.new(c.Root.Position) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 26, R0 = 1, R1 = 16 * k, Color = C.LimeHi, Duration = 0.7, Block = 0.9 })
				DinosaurVFX.Shake(1.0, 0.45)
				fovKick = 12
				local CK = require(script.Parent.UI.CineKit)
				CK.ImpactFrame(0.7)
				CK.HitStop(0.12)
				require(script.Parent.Audio).Sting("KnockedOut")
				floater(c.Root.Position + Vector3.new(0, 6, 0), "KNOCKED OUT!", C.LimeHi, 0.9, 5)
				sfx("Heavy", c.Root.Position, 0.6)
				flashModel(c.Model, C.LimeHi)
			end
		end
	end)
	Net.On("RodeoOpen", function()
		ui.Banner.Show("IT'S EXHAUSTED!", "", "Hand", C.YellowHi, 2.2)
	end)
	Net.On("RodeoEnd", function(info)
		-- (the server ended my ride - I lost the green for too long: off I go, right now)
		if not info.Success and info.UserId == player.UserId and rodeo and rodeo.Actor == info.Actor then rodeo.ServerFail = true end
		if info.Success then
			-- the finisher lands like a cutscene beat
			local CineKit = require(script.Parent.UI.CineKit)
			CineKit.Slam(ui.Gui, "KNOCKOUT!", info.UserId == player.UserId and "RODEO FINISH!" or "THE NEST IS OPEN!", C.LimeHi, 2.2, 0.28)
			for cfg, c in pairs(Exp.Creatures()) do
				if cfg:GetAttribute("Id") == info.Actor and c.Root then CineKit.Burst(c.Root.Position + Vector3.new(0, 3, 0), 1.4) end
			end
			if info.UserId == player.UserId then PlayerAnim.Act(player.Character, "Victory") end
		end
	end)
	Net.On("Downed", function(info)
		if info.UserId ~= player.UserId then Kit.Toast(string.upper(info.Name) .. " IS DOWN! HOLD E TO REVIVE", "Red", "Shield") end
	end)
	Net.On("Revived", function(info) if info.UserId == player.UserId then Kit.Toast("BACK ON YOUR FEET!", "Green", "Shield") end end)
	Net.On("GadgetFx", function(info)
		local p = info.P
		if info.Id == "Flare" then
			DinosaurVFX.Burst(CFrame.new(p + Vector3.new(0, 2, 0)), 30, { Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(10, 20), Color = Color3.new(1, 1, 1), LightEmission = 1, Size = NumberSequence.new(1, 0) })
		elseif info.Id == "Earthshaker" then
			DinosaurVFX.BlockRing(CFrame.new(p) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 26, R0 = 1, R1 = 20, Color = Color3.fromRGB(150, 230, 200), Duration = 0.7, Block = 1 })
			DinosaurVFX.Shake(1.2, 0.5)
		else
			DinosaurVFX.Cubes(p + Vector3.new(0, 1, 0), 8, { Color3.fromRGB(200, 70, 50), Color3.fromRGB(240, 220, 200) }, 0.3, 6, 1)
		end
	end)
	Net.On("Profile", function()
		if active and player.Character then buildLauncher(player.Character, profileGear().Launcher) end
		refreshGadgets()
	end)
	player.CharacterAdded:Connect(function(c) task.wait(1) if active then buildLauncher(c, profileGear().Launcher) end end)
	-- reviving someone: kneel and pump while you hold the prompt
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(pr) if pr:GetAttribute("Revive") then PlayerAnim.SetLoop(player.Character, "Revive") end end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(pr) if pr:GetAttribute("Revive") then PlayerAnim.SetLoop(player.Character, nil) end end)
	-- input
	ContextActionService:BindActionAtPriority("DinoFightKeys", function(_, state, input)
		if not active then return Enum.ContextActionResult.Pass end
		local kc = input.KeyCode
		if kc == Enum.KeyCode.F or kc == Enum.KeyCode.ButtonR2 then
			if state == Enum.UserInputState.Begin then View.TriggerDown() elseif state == Enum.UserInputState.End then View.TriggerUp() end
			return Enum.ContextActionResult.Sink
		end
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if kc == Enum.KeyCode.Q or kc == Enum.KeyCode.ButtonB then View.Dodge() return Enum.ContextActionResult.Sink end
		if kc == Enum.KeyCode.One or kc == Enum.KeyCode.ButtonL1 then View.Gadget(1) return Enum.ContextActionResult.Sink end
		if kc == Enum.KeyCode.Two or kc == Enum.KeyCode.ButtonR1 then View.Gadget(2) return Enum.ContextActionResult.Sink end
		if (kc == Enum.KeyCode.G or kc == Enum.KeyCode.DPadDown) and player:GetAttribute("Holding") then View.PutDown() return Enum.ContextActionResult.Sink end
		return Enum.ContextActionResult.Pass
	end, false, 2300, Enum.KeyCode.F, Enum.KeyCode.ButtonR2, Enum.KeyCode.Q, Enum.KeyCode.ButtonB, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.G, Enum.KeyCode.DPadDown)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then sprinting = true end
		if not active then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and (not processed or combatCamOn()) then View.TriggerDown() end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then sprinting = false end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and charging then View.TriggerUp() end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok then warn("[EncounterView]", err) end
	end)
end

function View.Active(): boolean
	return active
end

-- set the egg in your arms down in front of you (it keeps its rarity and stays yours)
local putting = false
function View.PutDown()
	if putting or not player:GetAttribute("Holding") or Cinema.Playing() then return end
	putting = true
	task.spawn(function()
		local res = Net.Ask("PutDownEgg")
		if res and res.Ok then require(script.Parent.Audio).Play("EggPlace") end
		putting = false
	end)
end

-- an egg in anyone's arms wears its rarity (glow, sparkle, colour) with a small name tag over it
local function dressHeld(m: Instance)
	if m.Name ~= "HeldEggModel" or not m:IsA("Model") or m:GetAttribute("HeldDino") then return end
	task.defer(function()
		local rarity = m:GetAttribute("Rarity")
		local r = rarity and Config.Rarity[rarity]
		if not (r and m.Parent and m.PrimaryPart) then return end
		RarityFx.Apply(m, rarity, 1.5)
		local bb = Instance.new("BillboardGui")
		bb.Name = "HeldRarity"
		bb.Size = UDim2.fromOffset(160, 26)
		bb.StudsOffset = Vector3.new(0, 1.6, 0)
		bb.MaxDistance = 70
		bb.LightInfluence = 0
		bb.Parent = m.PrimaryPart
		Kit.Text(bb, r.Name, { Pixel = true, Size = UDim2.fromScale(1, 1), Color = r.Color, Stroke = 2, Shadow = 1, MaxSize = 14 })
	end)
end
local function watchChar(c: Model)
	c.ChildAdded:Connect(dressHeld)
	for _, ch in ipairs(c:GetChildren()) do dressHeld(ch) end
end
local function watchPlayer(p: Player)
	if p.Character then watchChar(p.Character) end
	p.CharacterAdded:Connect(watchChar)
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)

return View
