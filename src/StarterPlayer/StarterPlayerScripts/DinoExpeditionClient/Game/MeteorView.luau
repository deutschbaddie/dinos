--[[
	MeteorView — METEOR SHOWERS over Base Camp, on your screen (2026-10-14; server: Meteors.luau).

	  "MeteorShower" Warn  a banner (or a toast if you're out on an expedition / in a cutscene); Over: a toast
	  "Meteor"             a fireball streaks in from high in the sky and slams down: a flash, dirt flying, cracks,
	                       a rumble if you're close. The server drops the METEORITE there as it lands.
	  the meteorites       a glowing star marker over each one you haven't collected (seen from across camp)
	  "MeteorGot"          what you got; that rock goes cold for you (its prompt off, its glow out)
]]

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
local Zone = require(script.Parent.Zone)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)

local player = Players.LocalPlayer
local C = Theme.C
local MeteorView = {}
MeteorView.Ready = false -- (init.client: the main menu is done - no banners or fireballs over it)

local ORANGE = Color3.fromRGB(255, 132, 40)
local CYAN = Color3.fromRGB(110, 232, 255)
local fxFolder: Folder
local banner: any = nil
local got = {} :: { [string]: boolean } -- meteorites you've collected this shower
local markers = {} :: { [Model]: BillboardGui }

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do (p :: any)[k] = v end
	p.Parent = fxFolder
	return p
end

-- out on an expedition (or anywhere that isn't camp)
local function away(): boolean
	return Zone.Current ~= "BaseCamp"
end

--------------------------------------------------------------------------------
-- a meteor coming in
--------------------------------------------------------------------------------
local function impact(at: Vector3, star: boolean)
	local col = star and CYAN or ORANGE
	-- the flash: a ball of light that blows out and fades
	local ball = part({ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = col, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(at + Vector3.new(0, 1, 0)), Transparency = 0.05 })
	TweenService:Create(ball, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(16, 16, 16) * (star and 1.4 or 1), Transparency = 1 }):Play()
	local light = Instance.new("PointLight")
	light.Color = col
	light.Range = 50
	light.Brightness = 6
	light.Parent = ball
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	task.delay(0.7, function() ball:Destroy() end)
	-- a shockwave ring along the ground
	local ring = part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = col, Size = Vector3.new(0.2, 4, 4), CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 0.3 })
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, 30, 30), Transparency = 1 }):Play()
	task.delay(0.7, function() ring:Destroy() end)
	pcall(DinosaurVFX.Debris, at, star and 2.2 or 1.6, Color3.fromRGB(70, 58, 50))
	pcall(DinosaurVFX.GroundCracks, at, star and 3 or 2.2)
	if not Cinema.Playing() then DinosaurVFX.Shake(star and 0.55 or 0.4, 0.5, at, 110) end
	if Audio.Has("MeteorHit") then
		Audio.Play("MeteorHit", { At = at })
	else
		Audio.Play("Earthshaker", { At = at, Range = 600, Volume = star and 1 or 0.8 })
	end
end

local function fly(info)
	local from, to = info.From, info.To
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then return end
	local cam = Workspace.CurrentCamera
	-- (only people at camp see them come down; an expedition is a long way off)
	if away() or not cam or (cam.CFrame.Position - to).Magnitude > 1600 then return end
	-- (not over the menu or a cutscene, and never late: one held back would land long after its rock)
	if not MeteorView.Ready or Cinema.Playing() then return end
	if typeof(info.T) == "number" and Net.ServerTime() - info.T > (tonumber(info.Fall) or 2.6) + 1 then return end
	local star = info.Star == true
	local col = star and CYAN or ORANGE
	local fall = math.clamp(tonumber(info.Fall) or 2.6, 0.5, 6)
	local size = star and 4.2 or 3
	local head = part({ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.new(1, 0.95, 0.85):Lerp(col, 0.35), Size = Vector3.new(size, size, size), CFrame = CFrame.new(from) })
	local shell = part({ Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = col, Size = Vector3.new(size, size, size) * 1.7, CFrame = CFrame.new(from), Transparency = 0.55 })
	-- the tail: a long fading trail plus fire shedding off it (its two edges either side of the head, across the
	-- way it's flying - the head's Y lies along its path)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(size * 0.45, 0, 0)
	a0.Parent = head
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-size * 0.45, 0, 0)
	a1.Parent = head
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.55
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.new(1, 0.97, 0.9), col)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
	trail.Parent = head
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Rate = 70
	fire.Lifetime = NumberRange.new(0.4, 0.7)
	fire.Speed = NumberRange.new(1, 3)
	fire.SpreadAngle = Vector2.new(180, 180)
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.9), NumberSequenceKeypoint.new(1, 0) })
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 230, 160), col)
	fire.Parent = head
	local glow = Instance.new("PointLight")
	glow.Color = col
	glow.Range = 40
	glow.Brightness = 3
	glow.Parent = head
	if Audio.Has("MeteorFall") then
		Audio.Play("MeteorFall", { At = to + Vector3.new(0, 40, 0), Volume = 0.8 })
	else
		task.delay(math.max(0, fall - 1), function() Audio.Play("Dodge", { At = to + Vector3.new(0, 20, 0), Range = 260, Pitch = 0.55, Exact = true }) end)
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / fall, 0, 1)
		-- (speeding up all the way down)
		local e = u ^ 1.35
		local p = from:Lerp(to, e)
		local cf = CFrame.lookAt(p, p + (to - from)) * CFrame.Angles(math.pi / 2, 0, 0)
		head.CFrame = cf
		shell.CFrame = cf
		if u >= 1 then
			(conn :: RBXScriptConnection):Disconnect()
			fire.Enabled = false
			head.Transparency, shell.Transparency = 1, 1
			glow.Enabled = false
			task.delay(0.7, function() head:Destroy() shell:Destroy() end)
			impact(to, star)
		end
	end)
end

--------------------------------------------------------------------------------
-- the meteorites lying around: markers, and the ones you've had
--------------------------------------------------------------------------------
local function goCold(m: Model)
	local pr = m:FindFirstChild("Collect", true)
	if pr and pr:IsA("ProximityPrompt") then pr.Enabled = false end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Color = Color3.fromRGB(70, 62, 58)
			d.Material = Enum.Material.Basalt
		elseif d:IsA("PointLight") or d:IsA("ParticleEmitter") then
			(d :: any).Enabled = false
		end
	end
	local mk = markers[m]
	if mk then mk:Destroy() markers[m] = nil end
end

local function marker(m: Model)
	if markers[m] then return end
	local core = m:FindFirstChild("Core")
	if not (core and core:IsA("BasePart")) then return end
	local star = m:GetAttribute("Star") == true
	local bb = Instance.new("BillboardGui")
	bb.Name = "DinoMeteorMark"
	bb.Adornee = core
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(star and 46 or 34, star and 46 or 34)
	bb.StudsOffset = Vector3.new(0, star and 9 or 7, 0)
	bb.MaxDistance = 600
	bb.ResetOnSpawn = false
	Kit.Icon(bb, "Star", { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	bb.Parent = player:WaitForChild("PlayerGui")
	markers[m] = bb
	-- (a soft bob, so it reads as "come here", not as part of the HUD)
	task.spawn(function()
		local t = math.random() * 3
		while bb.Parent do
			t += 0.05
			bb.Enabled = not Cinema.Playing() -- (never over a cutscene)
			bb.StudsOffset = Vector3.new(0, (star and 9 or 7) + math.sin(t * 2.4) * 0.6, 0)
			task.wait(0.05)
		end
	end)
end

local function watchRock(m: Instance)
	if not m:IsA("Model") then return end
	local id = m:GetAttribute("MeteorId")
	if typeof(id) ~= "string" then return end
	local owner = m:GetAttribute("Owner")
	local mine = owner == nil or owner == player.UserId
	if string.find(tostring(m:GetAttribute("Got") or ""), "," .. player.UserId .. ",", 1, true) then got[id] = true end
	-- (the whole rock arrives together, but give its core a moment in case it's still coming in)
	if not m:FindFirstChild("Core") and not m:WaitForChild("Core", 5) then return end
	if not m.Parent then return end
	if not mine then
		-- (someone else's island: theirs to collect - no prompt, no marker for you)
		local pr = m:FindFirstChild("Collect", true)
		if pr and pr:IsA("ProximityPrompt") then pr.Enabled = false end
	elseif got[id] then
		goCold(m)
	else
		marker(m)
	end
	m.AncestryChanged:Connect(function(_, parent)
		if parent == nil and markers[m] then
			markers[m]:Destroy()
			markers[m] = nil
		end
	end)
end

local function findRock(id: string): Model?
	local f = Workspace:FindFirstChild("DinoMeteorites")
	local m = f and f:FindFirstChild("Meteorite_" .. id)
	return (m and m:IsA("Model")) and m or nil
end

local function onGot(info)
	if typeof(info) ~= "table" or typeof(info.Id) ~= "string" then return end
	got[info.Id] = true
	local m = findRock(info.Id)
	if m then goCold(m) end
	if info.Already then return end
	local coins = tonumber(info.Coins) or 0
	if info.Star and typeof(info.Egg) == "table" then
		local r = Config.Rarity[info.Egg.Rarity]
		local sp = Config.Species[info.Egg.Species]
		Audio.Sting("Discover", 0.6)
		Kit.Toast(string.format("STAR METEORITE: %s %s EGG!", r and r.Name or "", sp and sp.Name or ""), "Teal", "Egg")
	elseif coins > 0 then
		Audio.Play("Coins")
		Kit.Toast("+" .. Config.FormatNumber(coins) .. " COINS" .. (info.Star and " - STAR METEORITE!" or " - METEORITE"), info.Star and "Teal" or "Gold", "Coin")
	end
end

--------------------------------------------------------------------------------
function MeteorView.Start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "DinoMeteorFx"
	fxFolder.Parent = Workspace
	local _, canvas = Kit.Screen("DinoMeteors", 12, false, 0.6)
	banner = Kit.Banner(canvas, { Position = UDim2.new(0.5, 0, 0, 170), ZIndex = 30 })
	Net.On("MeteorShower", function(info)
		if typeof(info) ~= "table" then return end
		if info.Phase == "Warn" then
			table.clear(got)
			if not MeteorView.Ready then return end
			if away() or Cinema.Playing() then
				Kit.Toast("A METEOR SHOWER IS HITTING BASE CAMP!", "Orange", "Star")
				return
			end
			Audio.Sting("Spotted", 0.6)
			banner.Show("METEOR SHOWER!", "METEORS ARE ABOUT TO HIT CAMP - GRAB THE GLOWING ROCKS", "Star", C.OrangeHi, 3.6)
		elseif info.Phase == "Over" then
			table.clear(got)
			if MeteorView.Ready and not away() then Kit.Toast("THE METEOR SHOWER IS OVER", "Grey", "Star") end
		end
	end)
	Net.On("Meteor", fly)
	Net.On("MeteorGot", onGot)
	-- the rocks the server drops (and any already there when you join)
	local function hook(f: Instance)
		for _, m in ipairs(f:GetChildren()) do task.spawn(watchRock, m) end
		f.ChildAdded:Connect(function(m) task.spawn(watchRock, m) end)
	end
	local f = Workspace:FindFirstChild("DinoMeteorites")
	if f then hook(f) end
	Workspace.ChildAdded:Connect(function(c)
		if c.Name == "DinoMeteorites" then hook(c) end
	end)
end

return MeteorView
