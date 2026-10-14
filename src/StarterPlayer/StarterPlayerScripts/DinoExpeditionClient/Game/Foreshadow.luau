--[[
	Foreshadow — the Tyrant King is out there (user pick 2026-10-12: foreshadow, then summon). Until you've beaten it:

	  run 1  giant three-toed footprints cross the Fern Valley road near the arrival portal (you drive over them)
	  run 2  on arrival, before the map: the ground shudders, the camera whips to the throne - it's awake, it ROARS
	         at you across the valley, birds and leaves burst out of the canopy, then it settles back down
	  run 3  mid-escape, it crosses the road AHEAD of you, huge, not stopping - and that run's takedown drops a key
	         (server: Encounter.DropKeys) -> the SUMMON prompt at the Time Gate (BossHype)

	No words. Each beat plays once (Flags.Tips "Fore_*").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local RouteMath = require(Shared:WaitForChild("Game"):WaitForChild("RouteMath"))
local DinosaurVFX = require(Shared:WaitForChild("DinosaurVFX"))
local Net = require(script.Parent.Net)
local Drive = require(script.Parent.Drive)
local Audio = require(script.Parent.Audio)
local Cinema = require(script.Parent.UI.Cinema)
local CineKit = require(script.Parent.UI.CineKit)
local Stage = require(script.Parent.TikTok.Stage)
local Floor = require(script.Parent.Floor)
local UserInputService = game:GetService("UserInputService")

-- a fresh press after the first second skips (a button already held when the beat began doesn't count)
local function skipper(): (() -> boolean, () -> ())
	local skipped = false
	local armAt = os.clock() + 1
	local conn = UserInputService.InputBegan:Connect(function(input)
		if os.clock() < armAt then return end
		local k, t = input.KeyCode, input.UserInputType
		if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA or k == Enum.KeyCode.E
			or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			skipped = true
		end
	end)
	return function() return skipped end, function() conn:Disconnect() end
end

local player = Players.LocalPlayer
local Foreshadow = {}
local ZONE, BOSS = "FernValley", "TyrantKing"

local function profile() return Net.Profile end
local function beaten(): boolean
	local p = profile()
	return p ~= nil and p.Bosses ~= nil and p.Bosses[BOSS] ~= nil and (p.Bosses[BOSS].Best or 0) >= 1
end
local function runs(): number
	local p = profile()
	return p and p.Stats and p.Stats.Runs or 0
end
local function seen(key: string): boolean
	local p = profile()
	return p ~= nil and p.Flags ~= nil and p.Flags.Tips ~= nil and p.Flags.Tips[key] == true
end
local function markSeen(key: string)
	local p = profile()
	if p and p.Flags then
		p.Flags.Tips = p.Flags.Tips or {}
		p.Flags.Tips[key] = true
	end
	task.spawn(function()
		for _ = 1, 4 do
			local res = Net.Ask("Tip", { Key = key })
			if not (res and res.Err == "slow down") then return end
			task.wait(0.3)
		end
	end)
end
-- a roar still ringing when the set is cleared plays out instead of being cut dead (2026-10-14: "the T. rex roar
-- gets cut off"). flat: as a plain 2D sound, for a cut where the camera jumps away from it
local function keepSounds(root: Instance?, flat: boolean?)
	if not root then return end
	for _, s in ipairs(root:GetDescendants()) do
		if s:IsA("Sound") and s.IsPlaying and s.TimeLength > 0 then
			local left = (s.TimeLength - s.TimePosition) / math.max(s.PlaybackSpeed, 0.05)
			if left > 0.15 then
				local c = s:Clone()
				if flat then
					c.Parent = game:GetService("SoundService")
				else
					local host = Instance.new("Part")
					host.Name = "DinoSfxKeep"
					host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch, host.Transparency = true, false, false, false, 1
					host.Size = Vector3.new(0.2, 0.2, 0.2)
					host.Position = s.Parent and s.Parent:IsA("BasePart") and (s.Parent :: BasePart).Position or Vector3.zero
					host.Parent = Workspace
					c.Parent = host
					task.delay(left + 0.3, function() host:Destroy() end)
				end
				c.TimePosition = s.TimePosition
				c:Play()
				c.Ended:Connect(function() c:Destroy() end)
				task.delay(left + 0.3, function() if c.Parent then c:Destroy() end end)
				s:Stop()
			end
		end
	end
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

--------------------------------------------------------------------------------
-- run 1: footprints across the road
--------------------------------------------------------------------------------
local prints: Folder? = nil
local function footprint(parent: Instance, at: Vector3, dir: Vector3, left: boolean)
	local side = dir:Cross(Vector3.yAxis) * (left and -1 or 1)
	local base = at + side * 2.2
	local g = Stage.Ground(base, 20)
	local cf = CFrame.lookAt(g, g + dir)
	local col = Color3.fromRGB(62, 52, 40)
	local function pad(off: Vector3, size: Vector3, yaw: number)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Ground
		p.Color = col
		p.Size = size
		local wp = (cf * CFrame.new(off)).Position
		local gy = Stage.Ground(wp, 6).Y
		p.CFrame = CFrame.new(wp.X, gy + 0.06, wp.Z) * (cf - cf.Position) * CFrame.Angles(0, yaw, 0)
		p.Parent = parent
	end
	-- a heel pad and three long toes (a T. rex foot is about the size of the rover's bonnet)
	pad(Vector3.new(0, 0, 0.6), Vector3.new(3.4, 0.12, 3.0), 0)
	pad(Vector3.new(0, 0, -2.6), Vector3.new(1.3, 0.12, 4.2), 0)
	pad(Vector3.new(-1.7, 0, -1.9), Vector3.new(1.2, 0.12, 3.6), math.rad(28))
	pad(Vector3.new(1.7, 0, -1.9), Vector3.new(1.2, 0.12, 3.6), math.rad(-28))
end
local function buildPrints()
	if prints or beaten() then return end
	local route = RouteMath.get(ZONE)
	if not route then return end
	local f = Instance.new("Folder")
	f.Name = "DinoForeshadowPrints"
	-- a stride that crosses the road at a slant just past the arrival portal, from one tree line to the other
	local s0 = 120
	local p0, fwd, right = route:Sample(1, s0)
	local hw = route:HalfWidth(1, s0)
	local from = p0 - right * (hw + 26) + fwd * 10
	local to = p0 + right * (hw + 26) - fwd * 10
	local dir = (to - from)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local n = 9
	for i = 0, n - 1 do
		footprint(f, from:Lerp(to, i / (n - 1)), dir, i % 2 == 0)
	end
	f.Parent = Workspace
	prints = f
end
local function clearPrints()
	if prints then prints:Destroy() prints = nil end
end

--------------------------------------------------------------------------------
-- run 2: it wakes on the throne and roars at you across the valley
--------------------------------------------------------------------------------
local function zoneMarker(name: string): BasePart?
	local zm = Workspace:FindFirstChild(ZONE)
	local m = zm and zm:FindFirstChild(name, true)
	return (m and m:IsA("BasePart")) and m or nil
end
local function roarBeat()
	local throne, center = zoneMarker("Throne"), zoneMarker("DenCenter")
	local root = Drive.State.Root or (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not (throne and center and root) then return end
	local cam = Workspace.CurrentCamera
	local cine = Cinema.Begin("DinoForeshadow")
	Drive.HoldCamera(true) -- the rover's chase cam must not fight the roar shot
	local skipped, stopSkip = skipper()
	-- swap the sleeping boss for an awake double for a few seconds
	local sleeper = Workspace:FindFirstChild("SleepingRuler", true)
	local sleeperParent = sleeper and sleeper.Parent
	local set = nil
	-- (everything after Begin is protected: a failure here used to leave the HUD hidden and the rover's camera held)
	local ok, err = pcall(function()
		if sleeper then sleeper.Parent = nil end
		set = Stage.new("Foreshadow")
		set:Show()
		local rex = set:Dino("TyrannosaurusRex", { Scale = 1.15 })
		if not rex then return end
		local top = throne.Position + Vector3.new(0, throne.Size.Y / 2, 0)
		local me = root.Position
		local look = Vector3.new(me.X - top.X, 0, me.Z - top.Z)
		rex:Place(top, look.Magnitude > 1 and look.Unit or Vector3.new(0, 0, 1))
		cam.CameraType = Enum.CameraType.Scriptable
		local eye = me + Vector3.new(0, 7, 0)
		if not Stage.Clear(eye, rex:Head()) then eye = me + Vector3.new(0, 34, 0) end
		local startLook = eye + (Drive.State.Root and Drive.State.Root.CFrame.LookVector or Vector3.new(0, 0, -1)) * 40
		-- 1. a shudder under you (the camera sits on the rover, looking down the road)
		DinosaurVFX.Shake(0.5, 1.0)
		local t0 = os.clock()
		while os.clock() - t0 < 0.9 and not skipped() do
			RunService.RenderStepped:Wait()
			cam.CFrame = CFrame.lookAt(eye, startLook)
			cam.FieldOfView = 70
		end
		if skipped() then return end
		-- 2. whip pan + long lens onto the throne: it's awake, it roars
		CineKit.Punch(8)
		Audio.Sting("Spotted", 0.7)
		local head = rex:Head()
		local dist = (head - eye).Magnitude
		local fov = math.clamp(math.deg(2 * math.atan((rex.Size.Y * 1.6) / dist)), 9, 45)
		rex:Act("Roar")
		task.delay(0.6, function()
			DinosaurVFX.FallingLeaves(top + Vector3.new(0, 18, 0), 30, 50, 24)
			DinosaurVFX.Cubes(top + Vector3.new(0, 22, 0), 22, { Color3.fromRGB(240, 240, 235), Color3.fromRGB(120, 95, 70) }, 0.4, 30, 1.6) -- birds bursting out
			DinosaurVFX.Shake(0.9, 1.2)
		end)
		local t1 = os.clock()
		while os.clock() - t1 < 3.2 and not skipped() do
			RunService.RenderStepped:Wait()
			local u = smooth((os.clock() - t1) / 0.35)
			local target = startLook:Lerp(rex:Head(), u)
			cam.CFrame = CFrame.lookAt(eye, target)
			cam.FieldOfView = 70 + (fov - 70) * u
		end
	end)
	if not ok then warn("[Foreshadow] roar:", err) end
	stopSkip()
	if set then pcall(keepSounds, set.Folder, true) end
	if set then pcall(function() set:Destroy() end) end
	if sleeper and sleeperParent and sleeperParent.Parent then sleeper.Parent = sleeperParent end
	cam.FieldOfView = 70
	cam.CameraType = Enum.CameraType.Custom
	Drive.HoldCamera(false)
	Cinema.End(cine)
end

--------------------------------------------------------------------------------
-- run 3: mid-escape, it crosses the road ahead of you (no fight, no stop - just a promise)
--------------------------------------------------------------------------------
local function crossBeat()
	local route = RouteMath.get(ZONE)
	local st = Drive.State
	if not route or st.Mode ~= "Route" then return end
	local vi = st.Variant or 1
	local set = Stage.new("ForeshadowCross")
	set:Show()
	local rex = set:Dino("TyrannosaurusRex", { Scale = 1.3 })
	if not rex then set:Destroy() return end
	-- a line across the road it can REALLY run (2026-10-13, user: "the t rex goes through the walls... it just looks
	-- dumb"): a few distances ahead, either way across, shorter runs if need be - level ground, nothing solid in the
	-- way of a body its size. No clear line anywhere: no beat this time (it waits for a later escape)
	local sz = rex.Size or Vector3.new(8, 12, 20)
	local from, to = nil, nil
	for _, ds in ipairs({ 140, 160, 120, 185, 210, 105 }) do
		local s = (st.S or 0) + ds
		if s > route:Length(vi) - 60 then continue end
		local hw = route:HalfWidth(vi, s)
		local p, fwd, right = route:Sample(vi, s)
		for _, side in ipairs({ 1, -1 }) do
			for _, len in ipairs({ 34, 26, 18 }) do
				local a = Floor.At(p - right * side * (hw + len) + fwd * 6, 20)
				local b = Floor.At(p + right * side * (hw + len + 6) - fwd * 6, 20)
				if math.abs(a.Y - b.Y) < 6 and math.abs(a.Y - p.Y) < 8 and Floor.PathClear(a, b, sz.Y, math.max(sz.X, 4)) then
					from, to = a, b
					break
				end
			end
			if from then break end
		end
		if from then break end
	end
	if not (from and to) then set:Destroy() return end
	markSeen("Fore_Cross") -- (only now: a beat that couldn't play stays unseen for the next escape)
	-- (protected: a throw mid-run used to leave a frozen T. rex standing on the road for the rest of the escape)
	local ok, err = pcall(function()
		rex:Loco("Run", 0.05)
		local dir = (to - from)
		dir = Vector3.new(dir.X, 0, dir.Z).Unit
		local t0 = os.clock()
		local roared = false
		-- (on the era's real floor, never on rocks or logs; the ferns and saplings it runs through step aside)
		CineKit.Burst(from + Vector3.new(0, 4, 0), 1.1)
		while os.clock() - t0 < 3.4 and Drive.State.Mode == "Route" do
			RunService.RenderStepped:Wait()
			local u = (os.clock() - t0) / 3.4
			local at = Floor.At(from:Lerp(to, u), 20)
			rex:Place(at, dir)
			Floor.Trample(CFrame.lookAt(at, at + dir) + Vector3.new(0, sz.Y / 2, 0), sz)
			if math.random() < 0.2 then DinosaurVFX.FootstepDust(at, 1.6) end
			if not roared and u > 0.45 then
				roared = true
				rex:Act("Roar")
				DinosaurVFX.Shake(0.8, 1.0)
			end
		end
		CineKit.Burst(to + Vector3.new(0, 4, 0), 1.0)
	end)
	if not ok then warn("[Foreshadow] cross:", err) end
	pcall(keepSounds, set.Folder, false)
	set:Destroy()
end

local crossPending = false
function Foreshadow.Start(EraView)
	local function refresh()
		if beaten() then clearPrints() else buildPrints() end
	end
	Net.On("Profile", refresh)
	task.defer(refresh)
	EraView.BeforeMap = function(zone: string)
		if zone ~= ZONE or beaten() or runs() ~= 1 or seen("Fore_Roar") then return end
		markSeen("Fore_Roar")
		task.wait(0.4)
		roarBeat()
	end
	Net.On("ChaseStart", function(info)
		if info and info.Boss then return end
		if beaten() or runs() ~= 2 or seen("Fore_Cross") then return end
		if Drive.State.Mode ~= "Route" then return end
		local route = RouteMath.get(ZONE)
		if not (route and Drive.State.Route == route) then return end
		if crossPending then return end
		crossPending = true
		task.delay(4.5, function()
			crossPending = false
			if not seen("Fore_Cross") then crossBeat() end
		end)
	end)
end

return Foreshadow
