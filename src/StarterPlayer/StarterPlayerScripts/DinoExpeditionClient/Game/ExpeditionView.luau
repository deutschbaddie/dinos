--[[
	ExpeditionView — everything you see on a run:
	  - creatures (server chasers) rendered smoothly with the procedural animators
	  - your pickups (boost canisters, repair kits, coins) bobbing on the road
	  - carried eggs riding in every vehicle's egg slots
	  - hit / dodge / grab / wreck effects, and the warp in and out
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Shared = DinoShared:WaitForChild("Game")
local Config = require(Shared:WaitForChild("Config"))
local RouteMath = require(Shared:WaitForChild("RouteMath"))
local DinosaurAnimations = require(DinoShared:WaitForChild("DinosaurAnimations"))
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local Net = require(script.Parent.Net)
local Drive = require(script.Parent.Drive)
local Warp = require(script.Parent.Warp)
local Zone = require(script.Parent.Zone)
local RarityFx = require(script.Parent.RarityFx)
local Kit = require(script.Parent.UI.Kit)
local C = Kit.Colors
local Cinema = require(script.Parent.UI.Cinema)
local EraView = require(script.Parent.EraView)
local Floor = require(script.Parent.Floor)

local player = Players.LocalPlayer
local View = {}
local hud -- set in Start (HUD module)

local ChaserFolder = DinoShared:WaitForChild("Runtime"):WaitForChild("Chasers")
local RunsFolder = DinoShared.Runtime:WaitForChild("Runs")
local Templates = DinoShared:WaitForChild("Dinosaurs")
local EggTemplates = DinoShared:WaitForChild("Eggs")

local localFolder: Folder
local function lf(): Folder
	if localFolder and localFolder.Parent then return localFolder end
	localFolder = Instance.new("Folder")
	localFolder.Name = "DinoExpeditionLocal"
	localFolder.Parent = Workspace
	return localFolder
end

local function prepModel(m: Model)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

--------------------------------------------------------------------------------
-- creatures
--------------------------------------------------------------------------------
local creatures = {} :: { [Configuration]: any }

-- encounter attacks -> the animation that winds it up (anything not listed falls back to Attack / Roar)
local ATTACK_ANIM = {
	Pounce = "Pounce", Bite = "Attack", Rake = "Attack", Screech = "RaptorScreech", LeapSlam = "Jump",
	Charge = "Roar", HornSweep = "Attack", Stomp = "Roar", Stampede = "Roar", Honk = "HerdResponse", TailWhip = "Attack",
	TailSwipe = "Attack", PlateRush = "Roar", StompWave = "Roar", NeckSweep = "Attack", TailQuake = "Attack",
}
local DISTRACT = { "Sniff", "Graze", "Browse", "Hunker", "LookAround" }
-- the events that are the blow itself (the frame the jaws shut / the claw connects / the foot lands)
local STRIKE_EVENTS = { Bite = true, Impact = true, TailSwing = true, ScytheSlash = true, ClawRake = true, Land = true, SpitGlob = true,
	MudBurst = true, Attack = true, Charge = true, BreathPlume = false }
local function strikeTime(anim, name: string): number?
	local a = anim and anim.Profile and anim.Profile.Actions[name]
	if not a then return nil end
	for _, e in ipairs(a.Events or {}) do
		if STRIKE_EVENTS[e[2]] then return e[1] end
	end
	return (a.Duration or 1) * 0.55
end
local KO_ANIM = { Velociraptor = "Sleep" }
-- creatures that live in the water: they ride at the surface (back + fin showing) instead of standing on P,
-- except when they breach, beach themselves or get knocked out (then P is where their belly is)
local SWIMMERS = { Mosasaurus = true }
local function waterY(): number
	for _, zn in ipairs({ "SpineRiver" }) do
		local z = Workspace:FindFirstChild(zn)
		if z and z:GetAttribute("WaterY") then return z:GetAttribute("WaterY") end
	end
	return 0
end

function View.Creatures()
	return creatures
end

-- footstep rumble only means something when it's a ruler you still have to beat, awake right now, and you're
-- either close to it or strong enough for it (cutscene footfalls keep their weight). everything else walks softly
local cfgOf = setmetatable({}, { __mode = "k" }) :: any
local function rulerRumble(model: Model): boolean
	if Cinema.Playing() then return true end
	local cfg = cfgOf[model]
	if not (cfg and cfg.Parent and cfg:GetAttribute("Boss")) then return false end
	local key = cfg:GetAttribute("Site")
	local era = typeof(key) == "string" and key:match("^(.-)/") or nil
	local bossId, boss
	for id, b in pairs(Config.Bosses) do if b.Era == era then bossId, boss = id, b end end
	if not boss then return false end
	local p = Net.Profile
	local rec = p and p.Bosses and p.Bosses[bossId]
	if rec and (rec.Clears or 0) > 0 then return false end -- already beaten
	local sites = DinoShared:FindFirstChild("Runtime") and DinoShared.Runtime:FindFirstChild("Sites")
	local folder = sites and sites:FindFirstChild((key :: string):gsub("/", "_"))
	if not (folder and (folder:GetAttribute("Phase") or 0) >= 1) then return false end -- not awake
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local close = hrp ~= nil and (hrp.Position - model:GetPivot().Position).Magnitude < 90
	return close or ((p and p.Power) or 0) >= (boss.Power or math.huge)
end
DinosaurVFX.FootstepShake = rulerRumble

-- a companion's little speech bubble: a white rounded bubble with a big glyph or icon, popping in and floating off
local BUBBLE = {
	Alert = { Text = "!", Color = Color3.fromRGB(255, 76, 60) },
	Chat = { Text = "...", Color = Color3.fromRGB(60, 64, 72) },
	Egg = { Icon = "Egg" },
	Love = { Text = "♥", Color = Color3.fromRGB(255, 92, 150) },
	Shield = { Icon = "Shield" },
	Blocked = { Icon = "Shield" },
	Sniff = { Icon = "Eye" },
	Dig = { Icon = "Egg" },
	Help = { Text = "+", Color = Color3.fromRGB(95, 211, 90) },
}
local function bubble(c, kind: string)
	local def = BUBBLE[kind]
	if not (def and c and c.Root and c.Root.Parent) then return end
	local _, size = c.Model:GetBoundingBox()
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bubble"
	bb.Size = UDim2.fromOffset(58, 58)
	bb.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.55 + 3.2, 0)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = true
	bb.MaxDistance = 140
	bb.Parent = c.Root
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = bb
	local cr = Instance.new("UICorner") cr.CornerRadius = UDim.new(0.45, 0) cr.Parent = f
	local st = Instance.new("UIStroke") st.Thickness = 3 st.Color = Color3.fromRGB(26, 28, 32) st.Parent = f
	local tail = Instance.new("Frame")
	tail.Size = UDim2.fromOffset(12, 12)
	tail.Position = UDim2.new(0.5, 0, 1, -4)
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Rotation = 45
	tail.BackgroundColor3 = Color3.new(1, 1, 1)
	tail.ZIndex = 0
	tail.Parent = f
	if def.Icon then
		Kit.Icon(f, def.Icon, { Size = UDim2.fromScale(0.82, 0.82), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
	else
		local t = Kit.Text(f, def.Text, { Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 0, MaxSize = 40, ZIndex = 3 })
		Kit.SetTextColor(t, def.Color)
	end
	local sc = Instance.new("UIScale") sc.Scale = 0.2 sc.Parent = f
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.7, function()
		TweenService:Create(sc, TweenInfo.new(0.2), { Scale = 0 }):Play()
		task.wait(0.22)
		bb:Destroy()
	end)
end

local function spawnCreature(cfg: Configuration)
	local species = cfg:GetAttribute("Species")
	local tmpl = Templates:FindFirstChild(species)
	if not tmpl then return end
	local m = tmpl:Clone() :: Model
	prepModel(m)
	local scale = cfg:GetAttribute("Scale") or 1
	if scale ~= 1 then m:ScaleTo(scale) end
	m:SetAttribute("AnimScale", scale)
	local root = m.PrimaryPart :: BasePart
	local cf0, size = m:GetBoundingBox()
	local lift = root.Position.Y - (cf0.Position.Y - size.Y / 2)
	local p = cfg:GetAttribute("P") or Vector3.zero
	local yaw = cfg:GetAttribute("Yaw") or 0
	root.CFrame = CFrame.new(p + Vector3.new(0, lift, 0)) * CFrame.Angles(0, yaw, 0)
	m.Parent = lf()
	-- a WILD one with a glow (WildLife.luau): rare = Rare's aura, shiny = Legendary's gold
	local wr = cfg:GetAttribute("WildRarity")
	if typeof(wr) == "string" then
		local ok, err = pcall(RarityFx.Apply, m, wr == "Epic" and "Legendary" or "Rare", math.max(size.X, size.Z))
		if not ok then warn("[ExpeditionView] wild glow:", err) end
	end
	local anim = DinosaurAnimations.get(m)
	local c = { Model = m, Root = root, Anim = anim, Lift = lift, Pos = p, Yaw = yaw, State = nil, Species = species, Rad = math.max(size.X, size.Z) * 0.5 } :: any
	if SWIMMERS[species] then c.Swim = true c.Height = size.Y c.WaterY = waterY() end
	-- a land boss knocked out goes over onto its side and stays down until its den rests (2026-10-14, user screenshot:
	-- the beaten Tyrant King stood there upright in a stunned loop, eyes still burning, as if it would get back up)
	c.LieKO = cfg:GetAttribute("Boss") == true and cfg:GetAttribute("Site") ~= nil and not c.Swim
	-- its eyes as they really are, so a knockout can put out a glow still burning from ENRAGED (that one lasts 30 s)
	if cfg:GetAttribute("Boss") or cfg:GetAttribute("Lead") then
		c.EyeMats = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and CollectionService:HasTag(d, "DinoEye") then c.EyeMats[d] = d.Material end
			if d:IsA("PointLight") then c.OwnLights = c.OwnLights or {} c.OwnLights[d] = true end
		end
	end
	-- motion: every position the server sends is kept with its arrival time, so the body moves at its real speed
	-- between updates (no stop-start), its legs keep pace with that speed, and it tilts with the slope it's on
	-- (a chaser can arrive before its first position does: then the buffer starts empty and the first real
	-- position snaps it into place, instead of it streaking in from the world origin)
	local hasP = typeof(cfg:GetAttribute("P")) == "Vector3"
	c.Buf = hasP and { { P = p, T = os.clock() } } or {}
	if not hasP then
		c.Unplaced = true
		root.CFrame = CFrame.new(0, -500, 0) -- (out of sight until it has somewhere to be)
	end
	c.Int = cfg:GetAttribute("Site") and 0.1 or 0.05
	c.Spd = 0
	c.Pitch = 0
	c.Mine = cfg:GetAttribute("Owner") == player.UserId and cfg:GetAttribute("Site") == nil and not cfg:GetAttribute("Buddy")
	c.HalfLen = size.Z * 0.32
	do
		local gait = anim and anim.Profile and anim.Profile.Gait
		c.WalkV = ((gait and gait.Walk and gait.Walk.Speed) or 6) * scale
		c.RunV = ((gait and gait.Run and gait.Run.Speed) or 16) * scale
	end
	cfg:GetAttributeChangedSignal("P"):Connect(function()
		local np = cfg:GetAttribute("P")
		if typeof(np) ~= "Vector3" then return end
		local now = os.clock()
		local last = c.Buf[#c.Buf]
		if c.Unplaced then
			c.Unplaced = nil
			c.Pos = np
		end
		-- it stood still for a while (no updates come while P doesn't change): pretend it was still here one update
		-- ago, so it sets off at its real speed instead of crawling across the whole idle gap
		if last and now - last.T > c.Int * 2.5 then
			table.insert(c.Buf, { P = last.P, T = now - c.Int })
			last = c.Buf[#c.Buf]
		end
		if last and now - last.T > 0.004 then c.Int += (math.clamp(now - last.T, 0.03, 0.25) - c.Int) * 0.25 end
		if last and now - last.T <= 0.004 then
			last.P = np -- (two updates in one frame: keep the newest)
		else
			table.insert(c.Buf, { P = np, T = now })
			if #c.Buf > 6 then table.remove(c.Buf, 1) end
		end
	end)
	creatures[cfg] = c
	cfgOf[m] = cfg
	-- a solid body at sites so you can't stroll through a dino (local only: your own character is the one it
	-- needs to stop). slimmer than the model so legs and tails don't snag; off while riding it or once it's out
	if cfg:GetAttribute("Site") and not cfg:GetAttribute("Buddy") then
		local box = Instance.new("Part")
		box.Name = "DinoCollider"
		box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch, box.CastShadow = true, true, false, false, false
		box.Transparency = 1
		box.Size = Vector3.new(size.X * 0.62, size.Y * 0.7, size.Z * 0.72)
		box.Parent = m
		c.Body = box
		c.BodyOffset = (cf0.Position - root.Position) * Vector3.new(0, 1, 0) + Vector3.new(0, -size.Y * 0.08, 0)
	end
	if cfg:GetAttribute("Buddy") then
		RarityFx.Apply(m, cfg:GetAttribute("Rarity") or "Common")
		-- a blue outline: it's on your side (and darts never hit it)
		local friend = Instance.new("Highlight")
		friend.Name = "FriendOutline"
		friend.FillTransparency = 1
		friend.OutlineColor = Color3.fromRGB(70, 160, 255)
		friend.OutlineTransparency = 0.05
		friend.DepthMode = Enum.HighlightDepthMode.Occluded
		friend.Parent = m
		-- its health over its head (and a HELP! countdown when it's down)
		local bb = Instance.new("BillboardGui")
		bb.Name = "BuddyBar"
		bb.Size = UDim2.fromOffset(110, 30)
		bb.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.55 + 1.6, 0)
		bb.MaxDistance = 120
		bb.LightInfluence = 0
		bb.Parent = root
		local buddyName = tostring(cfg:GetAttribute("Name") or "")
		local label = Kit.Text(bb, buddyName, { Size = UDim2.new(1, 0, 0, 13), Stroke = 2, MaxSize = 13 })
		local back = Instance.new("Frame")
		back.Size = UDim2.new(1, -16, 0, 9)
		back.Position = UDim2.new(0, 8, 0, 17)
		back.BackgroundColor3 = Color3.fromRGB(28, 30, 34)
		back.BorderSizePixel = 0
		back.Parent = bb
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = C.Lime
		fill.BorderSizePixel = 0
		fill.Parent = back
		for _, f in ipairs({ back, fill }) do local cr = Instance.new("UICorner") cr.CornerRadius = UDim.new(0, 3) cr.Parent = f end
		local st = Instance.new("UIStroke") st.Thickness = 2 st.Color = Color3.fromRGB(16, 17, 20) st.Parent = back
		c.Bar = { Gui = bb, Label = label, Fill = fill, Name = buddyName }
		local function hp()
			local k = math.clamp((tonumber(cfg:GetAttribute("HP")) or 1) / math.max(1, tonumber(cfg:GetAttribute("MaxHP")) or 1), 0, 1)
			fill.Size = UDim2.fromScale(k, 1)
			fill.BackgroundColor3 = k <= 0.3 and C.Red or (k <= 0.6 and C.Orange or C.Lime)
		end
		cfg:GetAttributeChangedSignal("HP"):Connect(hp)
		hp()
		-- an egg it's carrying for you rides on its back
		local function carry()
			if c.CarryModel then c.CarryModel:Destroy() c.CarryModel = nil end
			local sp = cfg:GetAttribute("CarryEgg")
			local t = typeof(sp) == "string" and EggTemplates:FindFirstChild(sp .. "Egg")
			if not t then return end
			local e = t:Clone() :: Model
			prepModel(e)
			e:ScaleTo(math.clamp(size.Y * 0.28, 0.6, 1.4))
			e.Parent = lf()
			c.CarryModel = e
			-- (sat ON its back, measured from the real top of the body: half its height above the root left it buried
			-- inside big ones, so you couldn't tell it had your egg - 2026-10-14)
			local top = (cf0.Position.Y + size.Y / 2) - root.Position.Y
			local _, es = e:GetBoundingBox()
			c.CarryOff = CFrame.new(0, top + es.Y * 0.35, size.Z * 0.08)
		end
		cfg:GetAttributeChangedSignal("CarryEgg"):Connect(carry)
		carry()
	end
	local function has(name: string): boolean
		return anim ~= nil and anim:HasAction(name)
	end
	local function play(name: string?, loop: boolean?)
		if not anim or not name or not has(name) then return nil end
		local tr = anim:Play(name, { Loop = loop })
		if loop and tr then tr.Loop = true end
		return tr
	end
	local function onState()
		local st = cfg:GetAttribute("State")
		if st == c.State then return end
		local prev = c.State
		c.State = st
		c.Loco = nil -- the frame loop picks walk / run / idle again from its real speed
		if st ~= "Burrow" then c.BurrowAt = nil end -- (an interrupted mud dive comes back up)
		-- a buddy knocked down lies on its side (Downed: revive it; Fainted: out for this run)
		c.Down = st == "Downed" or st == "Fainted"
		if st == "Downed" then c.DownAt = os.clock() end
		-- (out cold: eyes shut, and any glow still burning in them goes out)
		if anim then anim.EyesClosed = st == "Fainted" or st == "KO" end
		if st == "KO" then
			for e, mat in pairs(c.EyeMats or {}) do
				if e.Parent and e:GetAttribute("_glowing") then
					e.Material = mat
					for _, l in ipairs(e:GetChildren()) do if l:IsA("PointLight") and not (c.OwnLights and c.OwnLights[l]) then l:Destroy() end end
					e:SetAttribute("_glowing", nil)
				end
			end
			-- (already out cold when it streamed in: lying there, not toppling over in front of you)
			if c.LieKO and prev == nil then c.DownT = 1 end
		end
		if c.Down and anim then
			anim:StopActions(0.2)
			anim:SetLocomotion("Idle", 0.3)
			play("Stunned", true)
			DinosaurVFX.Stunned(m, st == "Fainted" and 3 or Config.Buddy.Bleed)
			return
		elseif prev == "Downed" and anim then
			anim:StopActions(0.3)
		end
		-- hidden: the ruler is off-screen (fleeing down the road)
		if st == "Hidden" then m.Parent = nil return elseif m.Parent == nil then m.Parent = lf() end
		if not anim then return end
		if st == "Idle" then
			anim:StopActions(0.3)
			anim:SetLocomotion("Idle", 0.3)
		elseif st == "Bite" then
			-- a buddy's move
			play(has("Attack") and "Attack" or "Roar")
		elseif st == "Follow" then
			anim:SetLocomotion("Walk", 0.25)
		elseif st == "Unaware" then
			anim:StopActions(0.3)
			anim:SetLocomotion("Idle", 0.3)
		elseif st == "Chase" or st == "Pursue" or st == "Flank" or st == "Hunt" then
			anim:StopActions(0.2)
			anim:SetLocomotion("Run", 0.25)
		elseif st == "Telegraph" or st == "Latch" then
			local atk = cfg:GetAttribute("Attack")
			if not cfg:GetAttribute("Site") then
				-- chase: it glows red while it lines up the lunge - that's the moment to dart it
				local h = m:FindFirstChild("DinoWarnGlow") :: Highlight?
				if not h then
					h = Instance.new("Highlight")
					h.Name = "DinoWarnGlow"
					h.FillColor = Color3.fromRGB(255, 60, 40)
					h.OutlineColor = Color3.fromRGB(255, 230, 120)
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = m
				end
				local hh = h :: Highlight
				hh.Enabled = true
				hh.FillTransparency = 0.35
				hh.OutlineTransparency = 0
				task.spawn(function()
					local t0 = os.clock()
					while hh.Parent and c.State == st and os.clock() - t0 < 4 do
						hh.FillTransparency = 0.25 + math.abs(math.sin((os.clock() - t0) * 12)) * 0.4
						task.wait()
					end
					if hh.Parent then hh.Enabled = false end
				end)
			end
			-- the wind-up is stretched to the telegraph: the jaws shut / the claws land on the very frame the hit does
			-- (wind-up, plus most of the lunge for a dash). Chasing alongside a rover its legs keep running under it
			local name = ATTACK_ANIM[atk or ""] or atk
			if not (name and has(name)) then name = has("Attack") and "Attack" or "Roar" end
			local at = (tonumber(cfg:GetAttribute("TeleTime")) or 0.8) + (tonumber(cfg:GetAttribute("TeleDash")) or 0) * 0.65
			local tr = anim:Play(name, { Weight = cfg:GetAttribute("Site") and 1 or 0.6 })
			local hitAt = strikeTime(anim, name)
			if tr and hitAt and at > 0.05 then tr.Speed = math.clamp(hitAt / at, 0.5, 2.0) end
		elseif st == "Attack" or st == "Lunge" or st == "Charge" then
			anim:SetLocomotion("Run", 0.1)
			if st == "Charge" then DinosaurVFX.ChargeDust(m, 2.5) end
		elseif st == "Recover" then
			-- the opening: it staggers and its weak spot glows
			anim:SetLocomotion("Idle", 0.2)
			play(has("Stumble") and "Stumble" or "LookAround")
		elseif st == "Stunned" or st == "Sedated" then
			anim:SetLocomotion("Idle", 0.2)
			play("Stunned")
			DinosaurVFX.Stunned(m, 2.4)
		elseif st == "Distracted" then
			anim:SetLocomotion("Walk", 0.3)
			for _, a in ipairs(DISTRACT) do if has(a) then play(a, true) break end end
		elseif st == "Exhausted" then
			anim:SetLocomotion("Idle", 0.4)
			play("Stunned", true)
			DinosaurVFX.Stunned(m, 6)
		elseif st == "Rodeo" then
			anim:SetLocomotion("Run", 0.2)
			play("Roar")
		elseif st == "KO" then
			anim:StopActions(0.2)
			anim:SetLocomotion("Idle", 0.4)
			play(KO_ANIM[species] or "Stunned", true)
			DinosaurVFX.Stunned(m, 8)
		elseif st == "Swim" or st == "Drag" or st == "Whirl" then
			anim:StopActions(0.2)
			anim:SetLocomotion("Run", 0.25)
			if st == "Drag" then play(has("Attack") and "Attack" or "Roar") end
		elseif st == "Submerge" then
			c.SubAt = os.clock()
			play(has("Dive") and "Dive" or "Attack")
			DinosaurVFX.WaterSplash(Vector3.new(c.Pos.X, c.WaterY or 0, c.Pos.Z), 1.2)
		elseif st == "Breach" then
			c.BreachAt = os.clock()
			play(has("Attack") and "Attack" or "Roar")
			DinosaurVFX.WaterSplash(Vector3.new(c.Pos.X, c.WaterY or 0, c.Pos.Z), 2.4)
		elseif st == "TailSlam" or st == "Grab" then
			anim:SetLocomotion("Idle", 0.15)
			play(has("Attack") and "Attack" or "Roar")
			if st == "TailSlam" then DinosaurVFX.WaterSplash(Vector3.new(c.Pos.X, c.WaterY or 0, c.Pos.Z), 1.8) end
		elseif st == "Perch" then
			anim:SetLocomotion("Idle", 0.2)
			play(has("RaptorScreech") and "RaptorScreech" or "Roar")
		elseif st == "Lurk" then
			-- the ford croc: eyes just above the water, dead still
			anim:SetLocomotion("Idle", 0.3)
			if has("Lurk") then play("Lurk", true) end
		elseif st == "Climb" then
			-- a Microraptor back up the trunk to its perch
			anim:SetLocomotion("Idle", 0.2)
			if has("Climb") then play("Climb", true) end
		elseif st == "Leap" then
			c.LeapAt = os.clock() -- (the sea boss's cannonball arc is timed from this)
			play(has("Jump") and "Jump" or (has("Pounce") and "Pounce" or "Attack"))
		elseif st == "Tired" or st == "Retreat" then
			anim:SetLocomotion("Walk", 0.5)
		-- the land bosses' signature moves (LandKings.luau)
		elseif st == "Roaring" then
			anim:StopActions(0.15)
			for _, n in ipairs({ "TerrorRoar", "FrostRoar", "Roar" }) do if has(n) then play(n) break end end
		elseif st == "Guard" then
			anim:StopActions(0.15)
			play("CrossGuard", true)
		elseif st == "Harvest" then
			anim:StopActions(0.1)
			local tr = play(has("ScytheSweep") and "ScytheSweep" or "Attack")
			-- the sweep lands as the ring does (1.3 s)
			local hitAt = tr and strikeTime(anim, tr.Name)
			if tr and hitAt then tr.Speed = math.clamp(hitAt / 1.3, 0.5, 2) end
		elseif st == "Dazed" then
			anim:StopActions(0.2)
			play("Stunned", true)
			DinosaurVFX.Stunned(m, 3)
		elseif st == "Burrow" then
			anim:StopActions(0.2)
			c.BurrowAt = os.clock()
			DinosaurVFX.GroundImpact(c.Pos, 1.6)
		elseif st == "Erupt" then
			c.BurrowAt = nil
			c.EruptAt = os.clock()
			local tr = play(has("MudAmbush") and "MudAmbush" or "Attack")
			if tr and tr.Name == "MudAmbush" then
				tr.T = 1.7 -- straight to the eruption (the sinking already happened, underground)
				tr.EventIndex = 3
			end
			DinosaurVFX.Debris(c.Pos + Vector3.new(0, 1, 0), 2.4, Color3.fromRGB(196, 150, 100))
			DinosaurVFX.Shake(1.0, 0.45, c.Pos, 90)
		elseif st == "Herd" then
			anim:SetLocomotion("Idle", 0.2)
			if has("Roar") then play("Roar") end
		end
		if prev == "KO" and st ~= "KO" then anim:StopActions(0.3) end
	end
	cfg:GetAttributeChangedSignal("State"):Connect(onState)
	onState()
end

local function removeCreature(cfg: Configuration)
	local c = creatures[cfg]
	creatures[cfg] = nil
	if not c then return end
	if c.CarryModel then c.CarryModel:Destroy() end
	DinosaurVFX.FootstepDust(c.Root.Position, 1.2)
	task.delay(0.25, function() c.Model:Destroy() end)
end

-- cutscenes keep their shot clear: any creature standing between the lens and the subject fades out of the shot
-- and stays out until the cutscene ends (2026-10-12: it used to slide sideways without walking - a glitchy
-- skate through the scenery right in the middle of the boss's big moment). the featured dino never changes.
local cineFocus: (() -> Vector3?)? = nil
local cineKeep: { [Model]: boolean } = {}
function View.SetCineFocus(fn: (() -> Vector3?)?, keep: { [Model]: boolean }?)
	cineFocus = fn
	cineKeep = keep or {}
end

local function cineOffset(c, cam: Camera, subject: Vector3): Vector3
	if cineKeep[c.Model] then return Vector3.zero end
	local a = cam.CFrame.Position
	local seg = subject - a
	local len = seg.Magnitude
	if len < 1 then return Vector3.zero end
	local dir = seg / len
	local centre = c.Pos + Vector3.new(0, c.Lift, 0)
	local t = math.clamp((centre - a):Dot(dir), 0, len)
	if t < 0.5 or t > len - (c.Rad + 1) then return Vector3.zero end -- behind the lens or at the subject itself
	local closest = a + dir * t
	local away = Vector3.new(centre.X - closest.X, 0, centre.Z - closest.Z)
	local d = away.Magnitude
	local clear = c.Rad + 2
	if d >= clear then return Vector3.zero end
	if d < 0.1 then away = dir:Cross(Vector3.yAxis) else away = away / d end
	return away * (clear - d + 1.5)
end

-- where the server says it was at time t: interpolated between the updates that bracket t, or carried on at its
-- last speed for a moment past the newest one
local function sampleAt(c, t: number): Vector3
	local buf = c.Buf
	local n = #buf
	if n == 0 then return c.Pos end
	if n == 1 or t <= buf[1].T then return buf[1].P end
	for i = n - 1, 1, -1 do
		local a, b = buf[i], buf[i + 1]
		if t >= a.T then
			local span = math.max(1e-3, b.T - a.T)
			if t <= b.T then return a.P:Lerp(b.P, (t - a.T) / span) end
			return b.P + (b.P - a.P) / span * math.min(t - b.T, 0.15)
		end
	end
	return buf[n].P
end

-- states where the body is posed (out cold, ridden, perched...): its legs don't run whatever the speed says
local POSED = { Exhausted = true, Rodeo = true, KO = true, Downed = true, Fainted = true, Perch = true, Hidden = true, Leap = true,
	Swim = true, Drag = true, Whirl = true, Submerge = true, Breach = true, TailSlam = true, Grab = true, Sleep = true, Stunned = true, Sedated = true,
	Roaring = true, Guard = true, Harvest = true, Dazed = true, Erupt = true }

local function stepCreatures(dt: number)
	local cam = Workspace.CurrentCamera
	local subject = cineFocus and cineFocus()
	if cineFocus and not subject and cam then subject = cam.CFrame.Position + cam.CFrame.LookVector * 30 end
	local now = os.clock()
	local rover = Drive.State.Root
	for cfg, c in pairs(creatures) do
		if not cfg.Parent then removeCreature(cfg) continue end
		local p = cfg:GetAttribute("P")
		if not p or c.Unplaced then continue end
		local yaw = cfg:GetAttribute("Yaw") or c.Yaw
		-- distance tiers (every site in every era is populated, and every client drew every dino at full rate,
		-- every frame): far ones just get placed a few times a second, mid ones skip the trample/slope work
		local camDist = cam and (c.Pos - cam.CFrame.Position).Magnitude or 0
		if not c.Mine and camDist > 500 then
			c.FarT = (c.FarT or 0) + dt
			if c.FarT < 0.3 then continue end
			c.FarT = 0
			c.Pos = sampleAt(c, now - c.Int * 1.35)
			c.Yaw = yaw
			c.Spd = 0
			c.Root.CFrame = CFrame.new(c.Pos + Vector3.new(0, c.Lift, 0)) * CFrame.Angles(0, c.Yaw, 0)
			if c.Body then c.Body.CFrame = CFrame.new(c.Root.Position + c.BodyOffset) * CFrame.Angles(0, c.Yaw, 0) end
			continue
		end
		local near = c.Mine or camDist < 140
		local before = c.Pos
		local latched = c.Mine and c.State == "Latch" and rover ~= nil and rover.Parent ~= nil
		if latched then
			-- hanging off YOUR rover: glued to the side it bit (the server's copy of you is a beat behind)
			local rcf = (rover :: BasePart).CFrame
			if not c.LatchOff then
				local o = rcf:PointToObjectSpace(sampleAt(c, now))
				local side = math.abs(o.X) > 2 and math.sign(o.X) or 0
				c.LatchSide = side
				c.LatchOff = side ~= 0 and Vector3.new(side * 4.4, 0, 0.8) or Vector3.new(0, 0, 5.6)
			end
			local wp = rcf:PointToWorldSpace(c.LatchOff :: Vector3)
			local g = Floor.At(wp, 8)
			c.Pos = c.Pos:Lerp(Vector3.new(wp.X, g.Y, wp.Z), 1 - math.exp(-dt * 26))
			local fwd = Vector3.new(rcf.LookVector.X, 0, rcf.LookVector.Z)
			local toCar = Vector3.new(rcf.Position.X - c.Pos.X, 0, rcf.Position.Z - c.Pos.Z)
			local face = (fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, -1)) + (toCar.Magnitude > 0.1 and toCar.Unit * 0.9 or Vector3.zero)
			yaw = math.atan2(-face.X, -face.Z)
		else
			c.LatchOff = nil
			-- your own chasers run on time with you; everyone else plays a beat behind so it's always between real updates
			local t = c.Mine and now or (now - c.Int * 1.35)
			local target = sampleAt(c, t)
			if (target - c.Pos).Magnitude > 40 then
				c.Pos = target -- a jump (a phase change, a warp): no sliding across the map
			else
				c.Pos = c.Pos:Lerp(target, 1 - math.exp(-dt * (c.Mine and 22 or 30)))
			end
			-- off the road (chase dinos are placed on the road's height): stand on the real ground under them
			if not cfg:GetAttribute("Site") and not c.Swim then
				local g = Floor.AtWater(c.Pos + Vector3.new(0, 6, 0), 6)
				if math.abs(g.Y - c.Pos.Y) < 25 then c.GroundY = (c.GroundY or g.Y) + (g.Y - (c.GroundY or g.Y)) * math.min(1, dt * 14) end
				if c.GroundY then c.Pos = Vector3.new(c.Pos.X, c.GroundY, c.Pos.Z) end
			end
		end
		-- running through the scenery (off the road, a charge through the ferns): what it runs into bursts and steps
		-- aside instead of the body clipping through it
		if near and not c.Swim and c.Spd > 5 and c.State ~= "Burrow" and c.State ~= "Hidden" and c.Model.Parent and now >= (c.TrampleAt or 0) then
			c.TrampleAt = now + 0.15
			local n, at = Floor.Trample(CFrame.new(c.Pos + Vector3.new(0, c.Lift, 0)) * CFrame.Angles(0, c.Yaw, 0), Vector3.new(c.Rad * 1.3, c.Lift * 2, c.Rad * 2.2))
			if n > 0 and at then DinosaurVFX.FoliageBurst(at, math.clamp(c.Rad / 4, 0.6, 1.6)) end
		end
		-- how fast it really moves (feeds the legs)
		local moved = Vector3.new(c.Pos.X - before.X, 0, c.Pos.Z - before.Z).Magnitude / math.max(dt, 1e-3)
		c.Spd += (math.min(moved, 140) - c.Spd) * math.min(1, dt * 8)
		-- turns: big bodies swing round slower than small ones
		local dy = math.atan2(math.sin(yaw - c.Yaw), math.cos(yaw - c.Yaw))
		c.Yaw += dy * math.min(1, dt * math.clamp(16 - c.Rad * 0.6, 5, 14))
		-- the slope it's standing on (sampled every few frames; smoothed)
		if not c.Swim and not c.Down then
			c.SlopeT = (c.SlopeT or 0) + dt
			if c.SlopeT > (near and 0.08 or 0.4) then
				c.SlopeT = 0
				local f = Vector3.new(-math.sin(c.Yaw), 0, -math.cos(c.Yaw)) * c.HalfLen
				local yf = Floor.At(c.Pos + f + Vector3.new(0, 4, 0), 6).Y
				local yb = Floor.At(c.Pos - f + Vector3.new(0, 4, 0), 6).Y
				c.WantPitch = math.clamp(math.atan2(yf - yb, c.HalfLen * 2), -0.3, 0.3)
			end
			c.Pitch += ((c.WantPitch or 0) - c.Pitch) * math.min(1, dt * 6)
		end
		-- in the shot's way: out for the rest of this cutscene (no sliding); back when the cutscene lets go
		if subject and cam then
			if not c.CineOut and cineOffset(c, cam, subject).Magnitude > 0 then c.CineOut = true end
		else
			c.CineOut = nil
		end
		local fadeTo = c.CineOut and 1 or 0
		local fadeNow = c.CineFade or 0
		if fadeNow ~= fadeTo then
			fadeNow = math.abs(fadeTo - fadeNow) < 0.02 and fadeTo or fadeNow + (fadeTo - fadeNow) * math.min(1, dt * 12)
			c.CineFade = fadeNow
			c.FadeParts = c.FadeParts or c.Model:GetDescendants()
			for _, d in ipairs(c.FadeParts) do
				if d:IsA("BasePart") or d:IsA("Decal") then (d :: any).LocalTransparencyModifier = fadeNow end
			end
		end
		c.CineOff = Vector3.zero
		-- (a land boss KNOCKED DOWN by a burst of hits - LandKings - goes over onto its side the same way, and so does
		-- one KNOCKED OUT: for good, a slower and heavier fall)
		local ko = c.LieKO and c.State == "KO"
		local lie = c.Down or ko or cfg:GetAttribute("Knocked") == true
		c.DownT = (c.DownT or 0) + ((lie and 1 or 0) - (c.DownT or 0)) * math.min(1, dt * (ko and 3.5 or 6))
		if c.Swim then
			-- the sea boss (2026-10-14, "no jittery movement"): its body never pops. Depth eases between the surface,
			-- fin-deep (only the fin cutting the water: SeaKing's Fin attribute) and deep; the breach and the
			-- cannonball are exact arcs that start from wherever it really was; pitch and roll ease; the whirlpool spin
			-- winds up and down instead of snapping round; and stepping between the water and a deck (beaching itself,
			-- the belly flop, sliding back in) blends across with a hop
			local landed = c.State == "Exhausted" or c.State == "Rodeo" or c.State == "KO" or c.State == "Dazed"
			local surf = (c.WaterY or 0) - c.Height * 0.66
			local want, wantPitch, wantRoll = surf, 0, 0
			if c.State == "Submerge" then
				want = surf - (cfg:GetAttribute("Fin") and c.Height * 0.3 or (c.Height + 6))
			elseif c.State == "Recover" then
				wantRoll = 0.5 -- (knocked silly, listing on its side: the weak spot's open)
			elseif c.State == "TailSlam" then
				wantPitch = 0.3 -- (reared up to slam)
			end
			c.SwimY = c.SwimY or want
			c.SwimPitch = c.SwimPitch or 0
			c.SwimRoll = (c.SwimRoll or 0) + (wantRoll - (c.SwimRoll or 0)) * math.min(1, dt * 4)
			local y = c.SwimY
			local arc = c.State == "Breach" or c.State == "Leap"
			if arc then
				local at = c.State == "Breach" and c.BreachAt or c.LeapAt
				if c.ArcKey ~= at then c.ArcKey = at c.ArcFromY = c.SwimY end
				local dur = c.State == "Breach" and 1.0 or math.max(0.3, tonumber(cfg:GetAttribute("LeapTime")) or 1.5)
				local u = math.clamp((now - (at or now)) / dur, 0, 1)
				local fromY = c.ArcFromY or surf
				-- a breach comes back down into the water; a cannonball comes down on the deck it was aimed at
				local endY = c.State == "Breach" and surf or c.Pos.Y
				local peak = c.State == "Breach" and (surf + c.Height * 0.9 + 6) or (math.max(fromY, endY) + 24)
				y = u < 0.5 and fromY + (peak - fromY) * math.sin(u * math.pi) or endY + (peak - endY) * math.sin(u * math.pi)
				c.SwimPitch = c.State == "Breach" and (0.9 - u * 1.6) or (0.75 - u * 1.5)
				c.SwimY = y
			else
				c.ArcKey = nil
				c.SwimY += (want - c.SwimY) * math.min(1, dt * 4.5)
				y = c.SwimY
				c.SwimPitch += (wantPitch - c.SwimPitch) * math.min(1, dt * 5)
			end
			-- the whirlpool spin winds up and down; when it's over the body swims gently round to its real heading.
			-- (2026-10-14: folding the spin into c.Yaw got undone by the heading's own fast catch-up to the server's
			-- yaw on the next frames - a half-turn whip right as its weak spot opened)
			c.SpinRate = (c.SpinRate or 0) + (((c.State == "Whirl") and 2.6 or 0) - (c.SpinRate or 0)) * math.min(1, dt * 1.5)
			c.Spin = ((c.Spin or 0) + c.SpinRate * dt) % (math.pi * 2)
			if c.State ~= "Whirl" and c.SpinRate < 0.05 and c.Spin ~= 0 then
				local s = c.Spin > math.pi and c.Spin - math.pi * 2 or c.Spin
				s -= s * math.min(1, dt * 1.6)
				c.Spin = math.abs(s) < 0.01 and 0 or s % (math.pi * 2)
			end
			local cf: CFrame
			if landed then
				-- up on a deck / the rock: lying on it, flanks heaving (a belly flop lies a little on its side)
				local heave = math.sin(now * 3.2) * 0.12
				cf = CFrame.new(c.Pos + c.CineOff + Vector3.new(0, c.Lift + heave, 0)) * CFrame.Angles(0, c.Yaw + c.Spin, 0) * CFrame.Angles(0, 0, c.State == "Dazed" and 0.35 or 0)
				c.SwimY = c.Pos.Y -- (so sliding back in starts from the deck, not from where it last swam)
			else
				local wob = math.sin(now * 2.2) * 0.25
				cf = CFrame.new(Vector3.new(c.Pos.X, y + c.Lift + wob, c.Pos.Z) + c.CineOff) * CFrame.Angles(0, c.Yaw + c.Spin, 0) * CFrame.Angles(c.SwimPitch, 0, c.SwimRoll)
			end
			-- between the water and a deck: a hop across instead of a snap
			if c.WasLanded ~= nil and c.WasLanded ~= landed and c.LastCF then
				c.BlendFrom, c.BlendAt = c.LastCF, now
				c.BlendHop = c.WasArc and 1.5 or (landed and 5 or 3)
			end
			c.WasLanded = landed
			c.WasArc = arc
			if c.BlendAt then
				local u = (now - c.BlendAt) / (landed and 0.5 or 0.45)
				if u >= 1 then
					c.BlendAt = nil
				else
					local e = u * u * (3 - 2 * u)
					cf = (c.BlendFrom :: CFrame):Lerp(cf, e) + Vector3.new(0, math.sin(u * math.pi) * (c.BlendHop or 3), 0)
				end
			end
			c.LastCF = cf
			c.Root.CFrame = cf
		else
			-- burrowed (the Dawn King's mud dive): the body slides down under the sand and a ridge of it hunts you
			local sink = 0
			if c.BurrowAt then
				sink = math.clamp((os.clock() - c.BurrowAt) / 0.5, 0, 1) * (c.Lift * 2.6 + 3)
				if os.clock() - (c.TrailAt or 0) > 0.09 then
					c.TrailAt = os.clock()
					local g = Floor.At(c.Pos + Vector3.new(0, 4, 0), 6)
					DinosaurVFX.Cubes(g + Vector3.new(0, 0.4, 0), 3, { Color3.fromRGB(214, 170, 112), Color3.fromRGB(176, 130, 84) }, 0.45, 9, 0.7)
					DinosaurVFX.FootstepDust(g, 1.4)
				end
			end
			c.Root.CFrame = CFrame.new(c.Pos + c.CineOff + Vector3.new(0, c.Lift * (1 - 0.45 * c.DownT) - sink, 0)) * CFrame.Angles(0, c.Yaw, 0) * CFrame.Angles(c.Pitch * (1 - c.DownT), 0, 1.35 * c.DownT)
		end
		if c.CarryModel then c.CarryModel:PivotTo(c.Root.CFrame * c.CarryOff) end
		if c.Bar then
			-- HELP! and the seconds left while it's down
			local down = c.State == "Downed"
			local left = down and math.max(0, Config.Buddy.Bleed - (os.clock() - (c.DownAt or os.clock()))) or 0
			Kit.SetText(c.Bar.Label, down and string.format("HELP! %d", math.ceil(left)) or (c.State == "Fainted" and "OUT COLD" or c.Bar.Name))
			if down then c.Bar.Fill.BackgroundTransparency = 0.3 + math.abs(math.sin(os.clock() * 6)) * 0.5 else c.Bar.Fill.BackgroundTransparency = 0 end
		end
		if c.Body then
			local solid = c.State ~= "Rodeo" and c.State ~= "KO" and c.State ~= "Hidden" and c.State ~= "Exhausted"
			-- (never for the sea boss: its box sweeping past the dock edge shoved and jittered whoever stood there)
			c.Body.CanCollide = solid and not c.Swim
			c.Body.CFrame = CFrame.new(c.Root.Position + c.BodyOffset) * CFrame.Angles(0, c.Yaw, 0)
		end
		-- legs: whatever it's doing, a body that's moving walks or runs at the pace it's really going (no skating),
		-- and one that's standing still stands
		if c.Anim and not POSED[c.State or ""] and not c.Down then
			local spd = c.Spd
			local walkTop = (c.WalkV + c.RunV) * 0.5
			local want = spd < 0.9 and "Idle" or (spd < walkTop and "Walk" or "Run")
			if c.State == "Attack" or c.State == "Lunge" or c.State == "Charge" then want = spd < 0.9 and "Idle" or "Run" end
			if want ~= c.Loco then
				c.Loco = want
				c.Anim:SetLocomotion(want, want == "Idle" and 0.35 or 0.25)
			end
			if want ~= "Idle" then
				local gait = c.Anim.Profile and c.Anim.Profile.Gait
				local g = gait and (want == "Run" and gait.Run or gait.Walk)
				local own = want == "Run" and c.RunV or c.WalkV
				if g and own > 0 then c.Anim.GaitPhase += dt * (g.Freq or 1) * (math.clamp(spd / own, 0.45, 2.8) - 1) end
			end
		end
		if c.Anim and c.State == "Unaware" then
			-- going about its day: ambles between spots, grazes and looks around when it stops; stares when uneasy
			local v = c.Spd
			local sus = cfg:GetAttribute("Sus") == true
			if sus and not c.WasSus then
				c.Anim:StopActions(0.15)
				if c.Anim:HasAction("LookAround") then c.Anim:Play("LookAround") end
			end
			c.WasSus = sus
			if not sus and v <= 0.5 and camDist < 250 and os.clock() >= (c.NextIdle or 0) then
				c.NextIdle = os.clock() + 3 + math.random() * 4
				for _, name in ipairs(math.random() < 0.6 and { "Graze", "Browse", "Sniff", "LookAround" } or { "LookAround", "Sniff", "Graze" }) do
					if c.Anim:HasAction(name) then c.Anim:Play(name) break end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- pickups (per player, rendered for your own run only)
--------------------------------------------------------------------------------
local pickups = {} :: { [number]: Model }

local function pickupModel(kind: string): Model
	local m = Instance.new("Model")
	m.Name = "Pickup_" .. kind
	local function p(size, color, mat, cf, shape)
		local q = Instance.new("Part")
		q.Anchored = true
		q.CanCollide = false
		q.CanQuery = false
		q.CanTouch = false
		q.Size = size
		q.Color = color
		q.Material = mat or Enum.Material.SmoothPlastic
		q.CFrame = cf or CFrame.new()
		q.TopSurface = Enum.SurfaceType.Smooth
		q.BottomSurface = Enum.SurfaceType.Smooth
		if shape then q.Shape = shape end
		q.Parent = m
		return q
	end
	if kind == "Darts" then
		local box = p(Vector3.new(2.6, 1.6, 1.8), Color3.fromRGB(47, 107, 58))
		box.TopSurface = Enum.SurfaceType.Studs
		box.Material = Enum.Material.Plastic
		for k = -1, 1 do
			p(Vector3.new(0.3, 0.3, 1.6), Color3.fromRGB(200, 205, 210), Enum.Material.Metal, CFrame.new(k * 0.7, 1.0, 0))
			p(Vector3.new(0.34, 0.34, 0.4), Color3.fromRGB(63, 224, 200), Enum.Material.Neon, CFrame.new(k * 0.7, 1.0, -0.9))
		end
		p(Vector3.new(2.7, 0.3, 1.9), Color3.fromRGB(255, 138, 36), nil, CFrame.new(0, -0.5, 0))
		m.PrimaryPart = box
	elseif kind == "Coin" then
		local c = p(Vector3.new(0.5, 2.6, 2.6), Color3.fromRGB(255, 196, 46), Enum.Material.Metal, nil, Enum.PartType.Cylinder)
		p(Vector3.new(0.56, 1.6, 1.6), Color3.fromRGB(255, 232, 140), Enum.Material.Neon, nil, Enum.PartType.Cylinder)
		m.PrimaryPart = c
	elseif kind == "Boost" then
		local c = p(Vector3.new(1.8, 2.8, 1.8), Color3.fromRGB(40, 120, 220), Enum.Material.Metal, nil, Enum.PartType.Cylinder)
		c.CFrame = CFrame.Angles(0, 0, math.pi / 2)
		p(Vector3.new(1.95, 0.5, 1.95), Color3.fromRGB(120, 230, 255), Enum.Material.Neon, CFrame.new(0, 0.6, 0))
		p(Vector3.new(1.95, 0.5, 1.95), Color3.fromRGB(120, 230, 255), Enum.Material.Neon, CFrame.new(0, -0.6, 0))
		p(Vector3.new(0.8, 0.5, 0.8), Color3.fromRGB(28, 30, 36), nil, CFrame.new(0, 1.6, 0))
		m.PrimaryPart = c
	else -- Repair
		local c = p(Vector3.new(2.4, 2.0, 2.4), Color3.fromRGB(95, 196, 72))
		c.TopSurface = Enum.SurfaceType.Studs
		p(Vector3.new(2.5, 0.6, 0.7), Color3.new(1, 1, 1), Enum.Material.Neon, CFrame.new(0, 0, -0.9))
		p(Vector3.new(0.7, 1.6, 0.6), Color3.new(1, 1, 1), Enum.Material.Neon, CFrame.new(0, 0, -0.95))
		m.PrimaryPart = c
	end
	local glow = Instance.new("PointLight")
	glow.Range = 10
	glow.Brightness = 1.4
	glow.Color = kind == "Coin" and Color3.fromRGB(255, 210, 100) or (kind == "Boost" and Color3.fromRGB(120, 230, 255) or (kind == "Darts" and Color3.fromRGB(255, 170, 90) or Color3.fromRGB(150, 255, 130)))
	glow.Parent = m.PrimaryPart
	prepModel(m)
	return m
end

-- road pickups (coins, boosts, repairs, darts) only exist for the escape: hidden on the drive in, on foot, and in
-- every cutscene (user, 2026-10-12)
local escaping = false
local pickupsShown = true
local function clearPickups()
	for _, m in pairs(pickups) do m:Destroy() end
	table.clear(pickups)
end

local function spawnPickups(zone: string)
	clearPickups()
	escaping = false -- a new trip: nothing on the road until the escape starts
	local route = RouteMath.get(zone)
	if not route then return end
	for _, f in ipairs(route.Data.Features) do
		if f.Type ~= "Coin" and f.Type ~= "Boost" and f.Type ~= "Repair" and f.Type ~= "Darts" then continue end
		local vi, s = nil, nil
		for i, sv in ipairs(f.S) do if sv >= 0 then vi, s = i, sv break end end
		if not vi then continue end
		local pos = route:Position(vi, s, f.X)
		local m = pickupModel(f.Type)
		m:SetAttribute("Base", pos + Vector3.new(0, 2.6, 0))
		m:PivotTo(CFrame.new(pos + Vector3.new(0, 2.6, 0)))
		m.Parent = pickupsShown and lf() or nil
		pickups[f.Id] = m
	end
end

local function stepPickups()
	local t = os.clock()
	local show = escaping and Drive.State.Mode == "Route" and not Drive.State.OnFoot and not Cinema.Playing()
	if show ~= pickupsShown then
		pickupsShown = show
		for _, m in pairs(pickups) do m.Parent = show and lf() or nil end
	end
	if not show then return end
	for id, m in pairs(pickups) do
		local base = m:GetAttribute("Base")
		if base then m:PivotTo(CFrame.new(base + Vector3.new(0, math.sin(t * 3 + id) * 0.4, 0)) * CFrame.Angles(0, t * 2.4 + id, 0)) end
	end
end

--------------------------------------------------------------------------------
-- eggs riding in vehicles (everyone's)
--------------------------------------------------------------------------------
local riding = {} :: { [number]: any } -- uid -> { [slot]: Model, Keys = { [slot]: egg key } }

local function eggModel(species: string, scale: number): Model?
	local t = EggTemplates:FindFirstChild(species .. "Egg")
	if not t then return nil end
	local e = t:Clone() :: Model
	prepModel(e)
	for _, d in ipairs(e:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
	e:ScaleTo(scale)
	return e
end

-- (egg lists decoded once per distinct string: the rack sync polls every run and rover a few times a second)
local eggJson = {} :: { [string]: { any } }
local function decodeList(raw: string): { any }
	local hit = eggJson[raw]
	if hit then return hit end
	local ok, eggs = pcall(HttpService.JSONDecode, HttpService, raw)
	hit = (ok and typeof(eggs) == "table") and eggs or {}
	if math.random() < 0.02 then table.clear(eggJson) end
	eggJson[raw] = hit
	return hit
end
local function decodeEggs(runCfg: Instance?): { any }
	if not runCfg then return {} end
	return decodeList(runCfg:GetAttribute("Eggs") or "[]")
end

-- each egg rides on the roof rack at its real size (KG) with its rarity glow
local function rackEgg(egg): Model?
	local e = eggModel(egg.Species, 0.42 * Config.EggScale(egg.Species, egg.KG))
	if e then
		RarityFx.Apply(e, egg.Rarity or "Common", 0.6)
		require(script.Parent.EggTip).Tag(e, egg.Species, egg.Rarity, egg.KG)
	end
	return e
end

local HIDDEN = CFrame.new(0, -500, 0)
local function rackSlot(uid: number, i: number): Attachment?
	local vf = Workspace:FindFirstChild("ActiveVehicles")
	for _, v in ipairs(vf and vf:GetChildren() or {}) do
		if v:GetAttribute("Owner") == uid and v:IsA("Model") and v.PrimaryPart then
			return v.PrimaryPart:FindFirstChild("EggSlot" .. i) :: Attachment?
		end
	end
	return nil
end

local function syncRidingEggs()
	local seen = {}
	-- on an expedition the run says what's on the rack; back home the rover itself does (until you unload)
	local sources = {}
	for _, runCfg in ipairs(RunsFolder:GetChildren()) do
		local uid = tonumber(runCfg.Name)
		if uid then sources[uid] = decodeEggs(runCfg) end
	end
	local vf = Workspace:FindFirstChild("ActiveVehicles")
	for _, v in ipairs(vf and vf:GetChildren() or {}) do
		local uid = v:GetAttribute("Owner")
		if uid and not sources[uid] then
			sources[uid] = decodeList(v:GetAttribute("RackEggs") or "[]")
		end
	end
	for uid, eggs in pairs(sources) do
		seen[uid] = true
		local list = riding[uid] or {}
		riding[uid] = list
		-- slot by slot: keep every egg that's still there and only build the new one (loading one egg used to
		-- destroy and rebuild the whole rack - clones, rescales, rarity lights and highlights: a lag spike per egg)
		local keys = list.Keys or {}
		list.Keys = keys
		local n = math.max(#eggs, #keys)
		for i = 1, n do
			local egg = eggs[i]
			local k = egg and (tostring(egg.Species) .. ":" .. tostring(egg.Rarity) .. ":" .. tostring(egg.KG)) or nil
			if keys[i] ~= k then
				local old = list[i]
				if old then old:Destroy() end
				list[i] = nil
				keys[i] = k
				local e = egg and rackEgg(egg)
				if e then
					e:PivotTo(HIDDEN) -- (stepRidingEggs puts it in its slot this frame)
					e.Parent = lf()
					list[i] = e
					-- your own rack at camp: tap an egg to take it off and carry it to a nest (stepRidingEggs turns the
					-- prompt on only while the rover's parked and you're on foot, off a run)
					local host = uid == player.UserId and (e.PrimaryPart or e:FindFirstChildWhichIsA("BasePart", true))
					if host then
						local r = Config.Rarity[egg.Rarity or "Common"]
						local pr = Instance.new("ProximityPrompt")
						pr.Name = "RackEggPrompt"
						pr.ActionText = "Take"
						pr.ObjectText = ((r and r.Name) or "") .. " " .. ((Config.Species[egg.Species] and Config.Species[egg.Species].Name) or "EGG")
						pr.HoldDuration = 0
						pr.MaxActivationDistance = 12
						pr.RequiresLineOfSight = false
						pr.Enabled = false
						pr:SetAttribute("PromptColor", "Lime")
						pr:SetAttribute("RackIndex", i)
						pr.Parent = host
						pr.Triggered:Connect(function()
							-- at a nest mid-run: take it off to carry (hands full: swap). At camp: unload it to your bag
							local atSite = player:GetAttribute("Site") ~= nil
							local res = Net.Ask(atSite and "TakeRackEgg" or "UnloadEgg", { Index = pr:GetAttribute("RackIndex") })
							if res and res.Ok then
								require(script.Parent.Audio).Play("Perfect", { Pitch = 1.1, Volume = 0.6 })
							elseif res and res.Err then
								Kit.Toast(res.Err, "Orange", "Egg")
							end
						end)
					end
					local slot = uid == player.UserId and rackSlot(uid, i)
					if slot then
						DinosaurVFX.BlockRing(CFrame.new(slot.WorldPosition), { Count = 10, R0 = 0.4, R1 = 3, Color = Config.Rarity[egg.Rarity or "Common"].Color, Duration = 0.35 })
					end
				end
			end
		end
	end
	for uid, list in pairs(riding) do
		if not seen[uid] then
			for i = 1, #(list.Keys or {}) do if list[i] then list[i]:Destroy() end end
			riding[uid] = nil
		end
	end
end

local function stepRidingEggs()
	-- every rack egg sits in its own slot on its owner's rover; an egg with no rover under it (the rover wrecked,
	-- an overflow egg past the last slot) is hidden instead of hanging in the air where it was built
	local roots = {}
	local vf = Workspace:FindFirstChild("ActiveVehicles")
	for _, v in ipairs(vf and vf:GetChildren() or {}) do
		local uid = v:GetAttribute("Owner")
		if uid and v:IsA("Model") and v.PrimaryPart then roots[uid] = v.PrimaryPart end
	end
	-- my rack's TAKE prompts: only with the rover parked at camp, me on foot, no run, empty hands
	local mine = roots[player.UserId]
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local canTake = mine ~= nil and mine.Parent ~= nil and (mine.Parent :: Instance):GetAttribute("Parked") == true
		and not RunsFolder:FindFirstChild(tostring(player.UserId)) and not (hum and hum.SeatPart) and not player:GetAttribute("HeldEgg")
	-- mid-run, on foot at a nest by your own rover: take one off to carry, or swap the one in your arms for it
	local atSite = mine ~= nil and player:GetAttribute("Site") ~= nil and RunsFolder:FindFirstChild(tostring(player.UserId)) ~= nil
		and not player:GetAttribute("RidingWith") and not player:GetAttribute("Downed") and not (hum and hum.SeatPart)
	local holdingEgg = player:GetAttribute("Holding") ~= nil
	-- (2026-10-13, user: at the FRONT of your parked rover you get DRIVE, round the BACK the rack's TAKE - never both)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local behind = false
	if mine and myRoot then
		local to = myRoot.Position - mine.Position
		behind = mine.CFrame.LookVector:Dot(Vector3.new(to.X, 0, to.Z)) < -1.5
		local seatPart = mine.Parent and (mine.Parent :: Instance):FindFirstChild("DriverSeat", true)
		local drive = seatPart and seatPart:FindFirstChild("ParkedDrive") :: ProximityPrompt?
		if drive and drive.Enabled == behind then drive.Enabled = not behind end
	end
	canTake = canTake and behind
	atSite = atSite and behind
	-- HOME: one TAKE ALL (2026-10-13, user: "don't make the player unload each egg one by one - one take all button,
	-- it goes to the hotbar"): every rack egg into your bag at once; the per-egg prompts are only for the nests now
	if mine then
		local all = mine:FindFirstChild("RackAllPrompt") :: ProximityPrompt?
		if not all then
			local pr = Instance.new("ProximityPrompt")
			pr.Name = "RackAllPrompt"
			pr.ActionText = "Take all eggs"
			pr.KeyboardKeyCode = Enum.KeyCode.E
			pr.GamepadKeyCode = Enum.KeyCode.ButtonX
			pr.HoldDuration = 0.25
			pr.MaxActivationDistance = 14
			pr.RequiresLineOfSight = false
			pr.Enabled = false
			pr.Parent = mine
			pr.Triggered:Connect(function()
				local n = #((Net.Profile and Net.Profile.RoverEggs) or {})
				local res = Net.Ask("UnloadAll", {})
				if res and res.Ok then
					DinosaurVFX.Cubes(mine.Position + Vector3.new(0, 3, 0), 14, { Color3.fromRGB(255, 226, 120), Color3.new(1, 1, 1) }, 0.25, 10, 0.8)
					Kit.Toast("+" .. tostring(res.Count or n) .. " EGG" .. ((res.Count or n) == 1 and "" or "S") .. " - ON YOUR HOTBAR", "Green", "Egg")
				end
			end)
			all = pr
		end
		local count = #((Net.Profile and Net.Profile.RoverEggs) or {})
		local p = all :: ProximityPrompt
		local want = canTake and count > 0
		local label = count .. " on the rack"
		if p.ObjectText ~= label then p.ObjectText = label end
		if p.Enabled ~= want then p.Enabled = want end
	end
	canTake = false -- (at camp the single TAKE ALL above replaces the per-egg prompts)
	for uid, list in pairs(riding) do
		local root = roots[uid]
		for i = 1, #(list.Keys or {}) do
			local e = list[i]
			if not e then continue end
			if uid == player.UserId then
				local pr = e:FindFirstChild("RackEggPrompt", true) :: ProximityPrompt?
				if pr then
					local want = canTake or atSite
					-- (at a nest it's T / D-pad left - E and X there are LOAD and the egg prompts, Y is DRIVE OFF; at camp
					-- it stays E / X. The keys only change while it's switched off, so nothing counting the prompts on
					-- screen ever sees one change its button)
					local key = atSite and Enum.KeyCode.T or Enum.KeyCode.E
					if pr.KeyboardKeyCode ~= key then
						if pr.Enabled then pr.Enabled = false end
						pr.KeyboardKeyCode = key
						pr.GamepadKeyCode = atSite and Enum.KeyCode.DPadLeft or Enum.KeyCode.ButtonX
					end
					if pr.Enabled ~= want then pr.Enabled = want end
					local act = atSite and (holdingEgg and "Swap" or "Take") or "Take"
					if pr.ActionText ~= act then pr.ActionText = act end
				end
			end
			local slot = root and root:FindFirstChild("EggSlot" .. i) :: Attachment?
			if slot then
				local wob = math.sin(os.clock() * 7 + i) * 0.04 * math.clamp((Drive.State.Speed or 0) / 40, 0, 1)
				e:PivotTo(slot.WorldCFrame * CFrame.new(0, -0.5, 0) * CFrame.Angles(wob, os.clock() * 0.6, wob))
			else
				e:PivotTo(HIDDEN)
			end
		end
	end
end
--------------------------------------------------------------------------------
-- effects
--------------------------------------------------------------------------------
local function vehicleRoot(): BasePart?
	return Drive.State.Root
end

local SPARK = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 255, 255) }
local DEBRIS = { Color3.fromRGB(242, 182, 50), Color3.fromRGB(60, 62, 68), Color3.fromRGB(120, 124, 130) }

local function sparksAt(side: number, n: number)
	local root = vehicleRoot()
	if not root then return end
	local pos = root.Position + root.CFrame.RightVector * side * 3.2 + Vector3.new(0, 0.5, 0)
	DinosaurVFX.Cubes(pos, n, SPARK, 0.35, 22, 0.5)
	DinosaurVFX.Cubes(pos, math.floor(n / 2), DEBRIS, 0.5, 14, 0.9)
end

-- a big hit knocks an egg off the rack: it tumbles off the side and cracks on the road
local function lostEgg(species: string, rarity: string?, side: number)
	local root = vehicleRoot()
	if not root then return end
	local e = eggModel(species, 0.6)
	if not e then return end
	if rarity then RarityFx.Apply(e, rarity, 0.6) end
	e.Parent = lf()
	local from = root.Position + Vector3.new(0, 3.5, 0)
	local vel = root.CFrame.RightVector * (side ~= 0 and -side or 1) * 22 + root.CFrame.LookVector * -18 + Vector3.new(0, 26, 0)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local p = from + vel * t + Vector3.new(0, -60, 0) * t * t * 0.5
		e:PivotTo(CFrame.new(p) * CFrame.Angles(t * 11, t * 7, t * 5))
		if t > 0.9 then
			conn:Disconnect()
			DinosaurVFX.Cubes(p, 14, { Color3.fromRGB(243, 234, 210), Config.Rarity[rarity or "Common"].Color }, 0.45, 18, 1.2)
			e:Destroy()
		end
	end)
end

local function wreckFx()
	local root = vehicleRoot()
	if not root then return end
	local pos = root.Position
	DinosaurVFX.Cubes(pos, 40, DEBRIS, 0.8, 34, 1.6)
	DinosaurVFX.Cubes(pos, 24, SPARK, 0.4, 40, 0.8)
	DinosaurVFX.BlockRing(CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 22, R0 = 1, R1 = 18, Color = Color3.fromRGB(255, 140, 60), Duration = 0.6, Block = 1.2 })
	DinosaurVFX.Burst(CFrame.new(pos), 30, { Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(10, 24), Spread = Vector2.new(180, 180), Color = Color3.fromRGB(60, 56, 54), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }) })
	DinosaurVFX.Shake(2.2, 0.9)
end

--------------------------------------------------------------------------------
-- your vehicle: boost flame + dust trail
--------------------------------------------------------------------------------
local fx = { Root = nil :: BasePart?, Flame = nil :: ParticleEmitter?, Dust = nil :: ParticleEmitter? }
local function stepVehicleFx()
	local root = Drive.State.Root
	if root ~= fx.Root then
		fx.Root = root
		fx.Flame, fx.Dust = nil, nil
		if root then
			local flameAt: Attachment? = nil -- the boost trail is your build's (RideFx)
			local exhaust = root:FindFirstChild("Exhaust") :: Attachment?
			if flameAt then
				local e = Instance.new("ParticleEmitter")
				e.Name = "DinoBoostFlame"
				e.Texture = "rbxasset://textures/particles/fire_main.dds"
				e.Rate = 60
				e.Lifetime = NumberRange.new(0.15, 0.3)
				e.Speed = NumberRange.new(10, 16)
				e.EmissionDirection = Enum.NormalId.Back
				e.SpreadAngle = Vector2.new(12, 12)
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
				e.Color = ColorSequence.new(Color3.fromRGB(150, 230, 255), Color3.fromRGB(60, 120, 255))
				e.LightEmission = 1
				e.Enabled = false
				e.Parent = flameAt
				fx.Flame = e
			end
			if exhaust then
				local d = Instance.new("ParticleEmitter")
				d.Name = "DinoDustTrail"
				d.Texture = "rbxasset://textures/particles/smoke_main.dds"
				d.Rate = 0
				d.Lifetime = NumberRange.new(0.8, 1.4)
				d.Speed = NumberRange.new(2, 5)
				d.EmissionDirection = Enum.NormalId.Back
				d.SpreadAngle = Vector2.new(35, 20)
				d.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
				d.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
				d.Color = ColorSequence.new(Color3.fromRGB(196, 170, 128))
				d.Acceleration = Vector3.new(0, 2, 0)
				d.Parent = exhaust
				fx.Dust = d
			end
		end
	end
	if fx.Flame then fx.Flame.Enabled = Drive.State.Boosting end
	if fx.Dust then fx.Dust.Rate = math.clamp(Drive.State.Speed - 8, 0, 60) * 0.5 end
end

--------------------------------------------------------------------------------
-- run flow
--------------------------------------------------------------------------------
local currentZone: string? = nil

local function onWarp(info)
	currentZone = info.Zone
	Drive.BeginRoute(info.Zone, info)
	Drive.Freeze(true)
	local route = RouteMath.get(info.Zone)
	if hud then hud.PrepareRun(info) end
	local settings = Net.Profile and Net.Profile.Settings or {}
	Warp.Play({
		Full = info.Full, Quick = (not info.Full) and settings.SkipWarp == true, Skippable = true, Name = info.Name, Era = info.Era,
		YearTo = route and route.Data.Year or -68000000, Arrival = info.Arrival,
		OnArrive = function()
			-- (instant, under the warp's flash: a 1.2 s tween here was still running when the arrival scene
			-- snapshotted the light, and that half-way look stuck)
			Zone.Apply(info.Zone, true)
			spawnPickups(info.Zone)
			task.spawn(function()
				local res = Net.Ask("Arrived")
				if hud then hud.ShowRun(info) end
				-- (a throw anywhere in the arrival used to leave the warp's last frame up with nothing driving it:
				-- the lens goes back to the rover, and EraView's roam heal picks the run up from the server's phase)
				local ok, err = pcall(EraView.Arrive, info, (res and res.Site) or info.Site)
				if not ok then
					warn("[ExpeditionView] arrival:", err)
					Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
				end
			end)
		end,
	})
end

-- a marker over the zone's return portal (visible from anywhere during the chase)
local portalMark: BillboardGui? = nil
local function markPortal(zone: string?)
	if portalMark then portalMark:Destroy() portalMark = nil end
	local zm = zone and Workspace:FindFirstChild(zone)
	local portal = zm and zm:FindFirstChild("ReturnPortal", true)
	local host = portal and portal:FindFirstChild("PortalLightHost", true) :: BasePart?
	if not host then return end
	local bb = Instance.new("BillboardGui")
	bb.Name = "DinoPortalMark"
	bb.Adornee = host
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(200, 110)
	bb.StudsOffset = Vector3.new(0, 18, 0)
	local icon = require(script.Parent.UI.Icons).Make("Gate", { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = bb })
	local _ = icon
	Kit.Text(bb, "TIME PORTAL", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 66), Color = Color3.fromRGB(255, 226, 120), Stroke = 3, Shadow = 2, MaxSize = 24 })
	bb.Parent = player:WaitForChild("PlayerGui")
	portalMark = bb
end

local function onChaseStart(info)
	-- everyone's back in their rover: the escape is on
	escaping = true
	Drive.StartChase(info)
	markPortal(currentZone)
	if hud then
		hud.ShowRun({ Zone = currentZone })
		if info.Boss then
			-- (no words: it's right there ahead of you on the road, running - you go after it)
			DinosaurVFX.Shake(0.6, 0.3)
		else
			-- (show, don't tell - 2026-10-14: the ESCAPE! slam, the portal marker and the goal bar say it; the old
			-- follow-up banner of dart / look-back instructions is gone)
			EraView.EscapeBeat(info.Eggs)
		end
	end
end

-- LOST THEM (2026-10-14): you shook the pack off - the chase is over and you're roaming again from right here, the eggs
-- still on the rack (EraView.LostBeat hands you the wheel and plays the beat). The portal marker stays up: it's still
-- the way home whenever you've had enough
function View.ChaseOver()
	escaping = false
end
local function onChaseLost(info)
	if typeof(info) ~= "table" then info = {} end
	if not info.Rider then View.ChaseOver() end
	local ok, err = pcall(EraView.LostBeat, info)
	if not ok then
		warn("[ExpeditionView] lost them:", err)
		-- (never left in the chase on screen: EraView's roam heal picks it up from the server's phase too)
		if not info.Rider then pcall(EraView.StartRoam) end
	end
end

local function onReturnHome(info)
	escaping = false
	local okR, errR = pcall(EraView.Reset) -- (a throw here used to cancel the warp home outright)
	if not okR then warn("[ExpeditionView] reset:", errR) end
	if portalMark then portalMark:Destroy() portalMark = nil end
	local from = currentZone and RouteMath.get(currentZone)
	Warp.Play({
		Reverse = true, Skippable = true, Name = "BASE CAMP", Era = "PRESENT DAY", Arrival = info.Arrival,
		YearTo = from and from.Data.Year or nil, -- (the counter runs up from the era you're leaving)
		OnArrive = function()
			-- home on foot (the rover stayed behind) vs at the wheel: only a driver gets the driving keys back
			-- (2026-10-12: SetOnFoot(false) re-bound Shift / C on foot, so sprint and dive died until your next drive)
			if info.OnFoot or not Drive.State.Vehicle or Drive.State.Toppled then
				Drive.SetToppled(false)
				Drive.ResetOnFoot()
			else
				Drive.SetOnFoot(false)
			end
			Drive.State.StopAt = nil
			Drive.EndRoute(info.Arrival)
			Zone.Apply("BaseCamp")
			clearPickups()
			currentZone = nil
			if hud then hud.ShowCamp() end
			if hud and hud.FlushSummary then task.delay(1.2, function() if hud.FlushSummary then hud.FlushSummary() end end) end
		end,
	})
end

-- carpool: riding along in someone else's rover. No run of your own (no driving keys, darts, rack or map): the warp,
-- the era and the fights at every stop; the driver's rover brings you home (or you're sent home on foot)
local function onRideWarp(info)
	currentZone = info.Zone
	if hud and hud.ShowRide then hud.ShowRide() end
	local route = RouteMath.get(info.Zone)
	local settings = Net.Profile and Net.Profile.Settings or {}
	Warp.Play({
		Full = false, Quick = settings.SkipWarp == true, Skippable = true, Name = info.Name, Era = info.Era,
		YearTo = route and route.Data.Year or -68000000, Arrival = info.Arrival,
		OnArrive = function()
			Zone.Apply(info.Zone, true)
			-- (no rover of your own for the warp to hand the camera to: back to following you in your seat)
			local cam = Workspace.CurrentCamera
			local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			cam.CameraType = Enum.CameraType.Custom
			if h then cam.CameraSubject = h end
			EraView.RideArrive(info)
		end,
	})
end
local function onRideReturn(info)
	local okR, errR = pcall(EraView.Reset)
	if not okR then warn("[ExpeditionView] reset:", errR) end
	local from = currentZone and RouteMath.get(currentZone)
	Warp.Play({
		Reverse = true, Skippable = true, Name = "BASE CAMP", Era = "PRESENT DAY", Arrival = info.Arrival,
		YearTo = from and from.Data.Year or nil,
		OnArrive = function()
			Zone.Apply("BaseCamp")
			-- (a rider's fights left the drive controller "on foot" - SetOnFoot at every site - and nothing put it back:
			-- your OWN rover then sat dead under the throttle at camp, its buttons up. Tester video 2026-10-14)
			Drive.ResetOnFoot()
			local cam = Workspace.CurrentCamera
			local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			cam.CameraType = Enum.CameraType.Custom
			if h then cam.CameraSubject = h end
			currentZone = nil
			if hud then hud.ShowCamp() end
		end,
	})
end

function View.Start(hudModule)
	hud = hudModule
	lf()
	for _, c in ipairs(ChaserFolder:GetChildren()) do task.spawn(spawnCreature, c) end
	ChaserFolder.ChildAdded:Connect(function(c) task.defer(spawnCreature, c) end)
	ChaserFolder.ChildRemoved:Connect(removeCreature)
	RunsFolder.ChildAdded:Connect(function(r)
		r:GetAttributeChangedSignal("Eggs"):Connect(syncRidingEggs)
		syncRidingEggs()
	end)
	RunsFolder.ChildRemoved:Connect(syncRidingEggs)
	for _, r in ipairs(RunsFolder:GetChildren()) do r:GetAttributeChangedSignal("Eggs"):Connect(syncRidingEggs) end
	syncRidingEggs()

	-- eggs ride on the rack until you hop out at camp; then the server drops them in your bag
	local rackTick = 0
	RunService.Heartbeat:Connect(function(dt)
		rackTick += dt
		if rackTick < 0.4 then return end
		rackTick = 0
		syncRidingEggs()
	end)
	Net.On("EggsToBag", function(info)
		local n = tonumber(info.Count) or 0
		Kit.Toast(string.format("%d EGG%s IN YOUR BAG - PUT %s IN A NEST", n, n == 1 and "" or "S", n == 1 and "IT" or "THEM"), "Green", "Bag")
	end)
	RunService.RenderStepped:Connect(function(dt)
		local St = Drive.State
		if St.Mode == "Route" and St.OnFoot and St.Route and not St.Vehicle then
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then St.S = (St.Route:Project(St.Variant, r.Position, St.S)) end
		end
		stepCreatures(dt)
		stepPickups()
		stepRidingEggs()
		stepVehicleFx()
	end)

	EraView.Start(View, hud)
	Net.On("Warp", onWarp)
	Net.On("ChaseStart", onChaseStart)
	Net.On("ChaseLost", onChaseLost)
	Net.On("ReturnHome", onReturnHome)
	Net.On("RideWarp", onRideWarp)
	-- (no words for any of these: you see it happen on the rack)
	-- your Egg Guard (Oviraptor) catches an egg that was going over the side
	Net.On("EggCaught", function(info)
		local root = vehicleRoot()
		if not root then return end
		local at = root.Position + Vector3.new(0, 4, 0) + root.CFrame.RightVector * ((info.Side or 0) ~= 0 and -(info.Side :: number) * 2 or 0)
		DinosaurVFX.BlockRing(CFrame.new(at) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 14, R0 = 0.5, R1 = 6, Color = Color3.fromRGB(42, 143, 163), Duration = 0.45 })
		DinosaurVFX.Cubes(at, 10, { Color3.fromRGB(42, 143, 163), Color3.new(1, 1, 1) }, 0.25, 10, 0.6)
		require(script.Parent.Audio).Play("Perfect", { Pitch = 1.3, Volume = 0.7 })
	end)
	-- an Oviraptor plucked one off the rack (it's in its jaws as it drops back: dart it)
	Net.On("EggPlucked", function(info)
		local root = vehicleRoot()
		if root then DinosaurVFX.Cubes(root.Position + Vector3.new(0, 4, 0), 8, { Color3.fromRGB(243, 234, 210), Color3.fromRGB(42, 143, 163) }, 0.25, 12, 0.5) end
		DinosaurVFX.Shake(0.6, 0.3)
		for cfg, c in pairs(creatures) do
			if cfg:GetAttribute("Id") == info.Id and c.Model then
				local hl = Instance.new("Highlight")
				hl.FillTransparency = 1
				hl.OutlineColor = Color3.fromRGB(255, 226, 120)
				hl.Parent = c.Model
				task.delay(6, function() hl:Destroy() end)
			end
		end
	end)
	-- darted it: the egg drops back onto the rack
	Net.On("EggBack", function()
		local root = vehicleRoot()
		if not root then return end
		DinosaurVFX.BlockRing(CFrame.new(root.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 16, R0 = 0.5, R1 = 6, Color = Color3.fromRGB(255, 226, 120), Duration = 0.45 })
		require(script.Parent.Audio).Play("Perfect", { Pitch = 1.15 })
	end)
	Net.On("RideReturn", onRideReturn)
	Net.On("Hit", function(info)
		Drive.Knock(info.Side or 0, info.Kind == "Charge" and 14 or 9)
		sparksAt(info.Side or 1, info.Kind == "Lunge" and 10 or 16)
		DinosaurVFX.Shake(info.Kind == "Charge" and 1.6 or 1.0, 0.45)
		if info.Lost then lostEgg(info.Lost, info.LostRarity, info.Side or 0) end
		if hud then hud.OnHit(info) end
	end)
	Net.On("Bump", function(info)
		Drive.Bump()
		local root = vehicleRoot()
		if root then
			local col = info.Kind == "Log" and { Color3.fromRGB(168, 116, 63), Color3.fromRGB(135, 89, 47) }
				or (info.Kind == "Branch" and { Color3.fromRGB(79, 176, 67), Color3.fromRGB(63, 154, 58) } or { Color3.fromRGB(138, 122, 104), Color3.fromRGB(120, 106, 88) })
			DinosaurVFX.Cubes(root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, 1, 0), 14, col, 0.5, 16, 1)
		end
	end)
	Net.On("Pickup", function(info)
		local m = pickups[info.Id]
		pickups[info.Id] = nil
		if m then
			local pos = m:GetPivot().Position
			local col = info.Kind == "Coin" and Color3.fromRGB(255, 210, 80) or (info.Kind == "Boost" and Color3.fromRGB(120, 230, 255) or Color3.fromRGB(140, 255, 120))
			DinosaurVFX.BlockRing(CFrame.new(pos), { Count = 10, R0 = 0.4, R1 = 4, Color = col, Duration = 0.35 })
			DinosaurVFX.Cubes(pos, 6, { col }, 0.3, 12, 0.5)
			m:Destroy()
		end
		if info.Kind == "Boost" then Drive.State.Boost = info.Boost or Drive.State.Boost end
		if hud then hud.OnPickup(info) end
	end)
	-- knocked out: the screen just goes black; you wake up on foot at your plot, then the summary
	local faint = nil :: any
	local wokeUp: () -> ()
	Net.On("Fainted", function(info)
		if faint then faint.Gui:Destroy() Cinema.End(faint.Token) end
		local gui = Instance.new("ScreenGui")
		gui.Name = "DinoFaintUI"
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
		gui.DisplayOrder = 300
		gui.ResetOnSpawn = false
		local black = Instance.new("Frame")
		black.BackgroundColor3 = Color3.new(0, 0, 0)
		black.BorderSizePixel = 0
		black.Size = UDim2.fromScale(1, 1)
		black.BackgroundTransparency = 1
		black.Parent = gui
		local label = Kit.Text(gui, "KNOCKED OUT...", { Pixel = true, Size = UDim2.fromScale(0.6, 0.05), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.fromRGB(235, 235, 235), Stroke = 0, Shadow = 0, ZIndex = 3, MaxSize = 28 })
		for _, d in ipairs(label:GetDescendants()) do if d:IsA("TextLabel") then d.TextTransparency = 1 end end
		gui.Parent = player:WaitForChild("PlayerGui")
		faint = { Gui = gui, Black = black, Label = label, Token = Cinema.Begin("DinoFaintUI") }
		-- (never black for good: if WokeUp never comes - the server lost the run part-way - wake up anyway)
		local mine = faint
		task.delay((tonumber(info.Black) or 1.1) + 10, function()
			if faint == mine and not mine.Woke then
				warn("[ExpeditionView] no WokeUp after a faint - lifting the black")
				task.spawn(wokeUp)
			end
		end)
		local t = tonumber(info.Black) or 1.1
		TweenService:Create(black, TweenInfo.new(t, Enum.EasingStyle.Sine), { BackgroundTransparency = 0 }):Play()
		task.delay(t * 0.6, function()
			for _, d in ipairs(label:GetDescendants()) do if d:IsA("TextLabel") then TweenService:Create(d, TweenInfo.new(0.5), { TextTransparency = 0 }):Play() end end
		end)
		faint.Info = info
	end)
	wokeUp = function()
		local f = faint
		if f then
			if f.Woke then return end -- (the safety and the real one: whichever comes first)
			f.Woke = true
		end
		-- back to camp state behind the black (guarded: the black lifts whatever happens here)
		local ok, err = pcall(function()
			EraView.Reset()
			if portalMark then portalMark:Destroy() portalMark = nil end
			Drive.ResetOnFoot()
			Zone.Apply("BaseCamp")
			clearPickups()
			currentZone = nil
			if hud then hud.ShowCamp() end
		end)
		if not ok then warn("[ExpeditionView] wake up:", err) end
		if not f then return end
		task.wait(1.0)
		for _, d in ipairs(f.Label:GetDescendants()) do if d:IsA("TextLabel") then TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play() end end
		local tw = TweenService:Create(f.Black, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
		tw:Play()
		tw.Completed:Wait()
		if faint == f then faint = nil end
		f.Gui:Destroy()
		Cinema.End(f.Token)
		if hud then hud.OnFainted(f.Info) end
	end
	Net.On("WokeUp", function() wokeUp() end)
	Net.On("Wrecked", function(info)
		wreckFx()
		Drive.Freeze(true)
		if hud then hud.OnWrecked(info) end
		task.delay(3.2, function() Drive.Freeze(false) end)
	end)
	Net.On("Extracted", function(info)
		local root = vehicleRoot()
		if root then
			DinosaurVFX.BlockRing(CFrame.new(root.Position), { Count = 24, R0 = 2, R1 = 22, Color = Color3.fromRGB(255, 196, 46), Duration = 0.7, Block = 1 })
		end
		EraView.ExtractBeat(#(info.Eggs or {}))
		if hud then hud.OnExtracted(info) end
	end)
	----------------------------------------------------------------------------
	-- the chase bites back: latched dinos, a flipped rover, the run on foot
	----------------------------------------------------------------------------
	local CineKit = require(script.Parent.UI.CineKit)
	Net.On("Latched", function(info)
		DinosaurVFX.Shake(1.1, 0.4)
		Drive.Kick(1)
		if hud and hud.Banner then hud.Banner("IT'S BITING YOUR ROVER!", nil, "Alert", C.RedHi) end
	end)
	Net.On("ShakenOff", function(info)
		DinosaurVFX.Shake(0.6, 0.25)
		Kit.Toast("SHAKEN OFF!", "Green", "Dino")
	end)
	local topple = nil :: any
	local function closeTopple()
		if topple then topple.Gui:Destroy() topple = nil end
	end
	-- the flip card goes when the run does: every egg cracked and no choice made (the server wrecks the run), a
	-- faint, or home (2026-10-12: it used to stay over the camp HUD with dead buttons)
	for _, kind in ipairs({ "Wrecked", "Fainted", "ReturnHome" }) do Net.On(kind, function() closeTopple() end) end
	Net.On("BuddyEmote", function(info)
		for cfg, c in pairs(creatures) do
			if cfg:GetAttribute("Buddy") and cfg:GetAttribute("Id") == info.Buddy then
				bubble(c, info.Emote)
				if c.Anim then
					local a = ({ Alert = "Roar", Chat = "LookAround", Love = "Hop", Sniff = "Sniff", Dig = "Graze", Help = "Sniff", Egg = "LookAround" })[info.Emote]
					if a and c.Anim:HasAction(a) and not c.Anim:IsPlaying() then c.Anim:Play(a) end
				end
				if info.Emote == "Dig" then DinosaurVFX.Cubes(c.Root.Position, 10, { Color3.fromRGB(120, 90, 60), Color3.fromRGB(160, 130, 90) }, 0.3, 10, 0.9) end
				if info.Emote == "Blocked" then DinosaurVFX.Cubes(c.Root.Position + Vector3.new(0, 2, 0), 8, { Color3.fromRGB(70, 160, 255), Color3.new(1, 1, 1) }, 0.25, 10, 0.6) end
			end
		end
	end)
	Net.On("BondUp", function(info)
		local perk = info.Perk and Config.PerkText[info.Perk]
		Kit.Toast(string.format("%s BOND %d!%s", info.Name or "COMPANION", info.Level or 1, perk and (" NEW: " .. perk[1]) or ""), "Teal", "Buddy")
	end)
	Net.On("MountDown", function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = 22 end
		Kit.Toast("WORN OUT - RUN THE REST!", "Orange", "Buddy")
	end)
	Net.On("Toppled", function(info)
		closeTopple()
		Drive.SetOnFoot(true)
		Drive.Freeze(true)
		task.delay(0.15, function() Drive.SetToppled(true) end)
		local root = vehicleRoot()
		if root then
			DinosaurVFX.Shake(1.4, 0.6)
			CineKit.ImpactFrame(1)
			CineKit.Burst(root.Position + Vector3.new(0, 2, 0), 1.2, { Color3.fromRGB(242, 182, 50), Color3.fromRGB(80, 80, 80), Color3.fromRGB(150, 120, 90) })
			for i, e in ipairs(info.Broken or {}) do
				-- cracked eggs: shell bits everywhere
				task.delay(0.2 * i, function()
					local sp = Config.Species[e.Species]
					DinosaurVFX.Cubes(root.Position + Vector3.new(0, 4, 0), 14, { Color3.fromRGB(243, 234, 210), sp and sp.Color or Color3.new(1, 1, 1) }, 0.3, 14, 1.2)
				end)
			end
		end
		local broken = #(info.Broken or {})
		local kept = #(info.Kept or {})
		local gui, canvas = Kit.Screen("DinoTopple", 60, false, 0.9)
		topple = { Gui = gui }
		CineKit.Slam(gui, "FLIPPED!", broken > 0 and (broken .. (broken == 1 and " EGG CRACKED" or " EGGS CRACKED")) or "THE EGGS HELD", C.RedHi, 1.6, 0.25)
		local card, content = Kit.Card(canvas, { Size = UDim2.fromOffset(560, 190), Position = UDim2.new(0.5, 0, 1, -40), AnchorPoint = Vector2.new(0.5, 1), Color = "Forest", Border = C.YellowHi, ZIndex = 10, Radius = 18 })
		Kit.Text(content, kept > 0 and ("YOUR ROVER IS ON ITS SIDE - " .. kept .. (kept == 1 and " EGG LEFT" or " EGGS LEFT")) or "YOUR ROVER IS ON ITS SIDE - NO EGGS LEFT", { Size = UDim2.new(1, -30, 0, 28), Position = UDim2.fromOffset(15, 14), ZIndex = 14, Stroke = 3, Shadow = 2, MaxSize = 28 })
		Kit.Text(content, "THEY'RE CIRCLING - DECIDE FAST", { Pixel = true, Size = UDim2.new(1, -30, 0, 12), Position = UDim2.fromOffset(15, 50), ZIndex = 14, Stroke = 2, Shadow = 1, MaxSize = 12, Color = C.OrangeHi })
		local function choose(which: string)
			task.spawn(function()
				local res = Net.Ask("ToppleChoice", { Choice = which })
				if res and res.Ok then closeTopple() elseif res and res.Err then Kit.Toast(res.Err, "Red", "Coin") end
			end)
		end
		local _, repairHit = Kit.Button(content, { Text = "REPAIR  " .. Config.FormatNumber(info.Cost or 0), Icon = "Wrench", IconSize = 0.9, TextLeft = 0.24, Color = info.CanAfford and "Lime" or "Grey", Disabled = not info.CanAfford, Size = UDim2.fromOffset(250, 64), Position = UDim2.new(0, 15, 1, -16), AnchorPoint = Vector2.new(0, 1), ZIndex = 14, MaxText = 24, OnClick = function() choose("Repair") end })
		local _, runHit = Kit.Button(content, { Text = kept > 0 and "GRAB AN EGG AND RUN!" or "HEAD HOME", Icon = kept > 0 and "Egg" or "Home", IconSize = 0.9, TextLeft = 0.22, Color = kept > 0 and "Orange" or "Red", Size = UDim2.fromOffset(260, 64), Position = UDim2.new(1, -15, 1, -16), AnchorPoint = Vector2.new(1, 1), ZIndex = 14, MaxText = 22, OnClick = function() choose("Run") end })
		if info.Ride and kept > 0 then
			-- your companion can carry you (and all the eggs) home
			Kit.Button(content, { Text = "RIDE " .. info.Ride .. " HOME!", Icon = "Buddy", IconSize = 0.9, TextLeft = 0.2, Color = "Teal", Shine = true, Size = UDim2.fromOffset(530, 58), Position = UDim2.new(0.5, 0, 0, -10), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 14, MaxText = 24, OnClick = function() choose("Ride") end })
		end
		-- gamepad: the choice is the only thing to do (you're frozen on your side), so focus it
		if Kit.Gamepad() then
			local GuiService = game:GetService("GuiService")
			GuiService.SelectedObject = (info.CanAfford and repairHit) or runHit
			gui.Destroying:Connect(function()
				local sel = GuiService.SelectedObject
				if sel and sel:IsDescendantOf(gui) then GuiService.SelectedObject = nil end
			end)
		end
		if not info.CanAfford then
			Kit.Text(content, "NOT ENOUGH COINS TO REPAIR", { Pixel = true, Size = UDim2.fromOffset(250, 10), Position = UDim2.new(0, 15, 1, -86), ZIndex = 14, Stroke = 2, Shadow = 1, MaxSize = 10, Color = C.RedHi })
		end
	end)
	Net.On("Repaired", function(info)
		closeTopple()
		Drive.SetToppled(false)
		Drive.SetOnFoot(false)
		Drive.SetRoutePos(info.S or Drive.State.S, info.X or 0, info.Variant, 12)
		Drive.Upright()
		Drive.Freeze(false)
		local root = vehicleRoot()
		if root then CineKit.Sparkle(root.Position + Vector3.new(0, 3, 0), C.LimeHi, 1.2) end
		Kit.Toast("PATCHED UP - GO GO GO!", "Green", "Wrench")
	end)
	Net.On("OnFootRun", function(info)
		closeTopple()
		Drive.State.OnFoot = true
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = info.Mount and 34 or 22 end
		if hud and hud.Banner then
			if info.Mount then hud.Banner("RIDE FOR THE TIME PORTAL!", info.Mount .. " HAS YOU!", "Gate", C.TealHi)
			else hud.Banner("RUN FOR THE TIME PORTAL!", nil, "Gate", C.YellowHi) end
		end
	end)
	Net.On("FootHit", function(info)
		DinosaurVFX.Shake(1, 0.35)
		if info.Mount then
			Kit.Toast((info.HP or 0) > 0 and "YOUR RIDE GOT BITTEN!" or "YOUR RIDE IS WORN OUT!", "Red", "Alert")
		else
			Kit.Toast((info.HP or 0) > 0 and ("BITTEN! " .. (info.Bites or math.ceil((info.HP or 0) / 34)) .. " MORE AND YOU'RE DOWN") or "DOWN!", "Red", "Alert")
		end
	end)
	Net.On("VehiclePoof", function(info)
		if info.Position then DinosaurVFX.Burst(CFrame.new(info.Position), 18, { Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(6, 12), Spread = Vector2.new(180, 180) }) end
	end)
	Net.On("Scrape", function(info) sparksAt(info.Side or 1, 3) end)
	Net.On("Warning", function(info)
		-- the autopilot sidesteps a telegraphed lunge, and eases off for a charge across the road
		if info.Kind == "Charge" then Drive.AutoBrake(1.4) else Drive.Dodge(info.Side or 1) end
	end)
	Net.On("DevJump", function(info) Drive.JumpTo(info.S) end)

	-- nest grab prompts: only at your site while the fight is on (grabbing is the escape route)
	task.spawn(function()
		local prompts = {}
		for _, era in ipairs(Config.Eras) do
			local zm = Workspace:WaitForChild(era.Id, era.Built and 30 or 0.1)
			for _, pr in ipairs(zm and zm:GetDescendants() or {}) do
				if pr:IsA("ProximityPrompt") and pr:GetAttribute("NestId") then
					pr.ActionText = "Grab an egg"
					pr.ObjectText = "Escape route"
					table.insert(prompts, { Prompt = pr, Era = era.Id })
				end
			end
		end
		local SitesFolder = DinoShared.Runtime:WaitForChild("Sites")
		while true do
			task.wait(0.25)
			local key = player:GetAttribute("Site")
			local open = {}
			if typeof(key) == "string" then
				for _, f in ipairs(SitesFolder:GetChildren()) do
					if f:GetAttribute("Key") == key and f:GetAttribute("State") == "Active" and not f:GetAttribute("Boss") then
						local def = Config.Site(f:GetAttribute("Era"), f:GetAttribute("Site"))
						if def then open[f:GetAttribute("Era") .. "#" .. def.Nest] = true end
					end
				end
			end
			for _, rec in ipairs(prompts) do
				-- eggs are real objects now (pick them up one by one); the old nest-wide grab prompt stays off
				rec.Prompt.Enabled = false
				local _ = open
			end
		end
	end)
	-- on foot whenever you're at a site; back in the rover otherwise (the server seats you)
	player:GetAttributeChangedSignal("Site"):Connect(function()
		if player:GetAttribute("Site") then Drive.SetOnFoot(true) end
		-- (the portal marker outlives a chase you shook off - it's the way home while you roam on - but not over the
		-- next fight. 2026-10-14)
		if portalMark then portalMark.Enabled = player:GetAttribute("Site") == nil end
	end)
end

return View
