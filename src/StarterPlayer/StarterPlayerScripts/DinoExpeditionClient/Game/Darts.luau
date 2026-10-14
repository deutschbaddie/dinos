--[[
	Darts — the tranq launcher on every vehicle.
	Auto-targets the most urgent threat (a raptor mid-telegraph or a charger first, then the alpha,
	then the closest), shows a reticle on it, swings the roof turret to track it, and fires on
	F / gamepad Y / the DART button. The dart flies (client prediction), the server decides the hit.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Net = require(script.Parent.Net)
local Drive = require(script.Parent.Drive)

local player = Players.LocalPlayer
local C = Theme.C
local Darts = {}
local View -- ExpeditionView (creatures)
local HUD
local target = nil -- { Cfg, Model, Root }
local reticle: BillboardGui? = nil
local turretYaw = 0
local recoil = 0
local nextFire = 0
local lastFireTarget = nil

local BAD = { Sleep = true, Gone = true, Sedated = true, Retreat = true, Tired = true, Stunned = true, Wake = true, Doze = true, Stir = true, Watch = true, Hunt = true }

local function myCreatures()
	local list = {}
	for cfg, c in pairs(View.Creatures()) do
		-- (only the run's chasers: never your own companion, a site's residents or a ball you threw)
		if cfg.Parent and cfg:GetAttribute("Owner") == player.UserId and not cfg:GetAttribute("Buddy") and cfg:GetAttribute("Site") == nil
			and not BAD[cfg:GetAttribute("State") or ""] and c.Root and c.Root.Parent then
			table.insert(list, { Cfg = cfg, Model = c.Model, Root = c.Root })
		end
	end
	return list
end

local function score(t, from: Vector3, fwd: Vector3): number?
	local d = (t.Root.Position - from)
	local dist = d.Magnitude
	if dist > Config.Expedition.DartRange then return nil end
	local st = t.Cfg:GetAttribute("State")
	local s = 1000 - dist
	if st == "Telegraph" or st == "Lunge" or st == "Latch" then s += 2000 end
	if st == "Charge" then s += 1800 end
	if t.Cfg:GetAttribute("Boss") then s += 600 end
	if fwd:Dot(d.Unit) < -0.6 then s -= 400 end -- far behind: lower priority
	-- gunner aim: the creature nearest the mouse wins (mouse players point and click; touch / pad keep auto-aim)
	local cam = workspace.CurrentCamera
	if cam and UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local sp, onScreen = cam:WorldToViewportPoint(t.Root.Position)
		if onScreen then
			local m = UserInputService:GetMouseLocation()
			local dm = (Vector2.new(sp.X, sp.Y) - m).Magnitude
			if dm < 260 then s += 3500 - dm * 6 end
		end
	end
	return s
end

local function buildReticle()
	local bb = Instance.new("BillboardGui")
	bb.Name = "DinoReticle"
	bb.Size = UDim2.fromOffset(110, 110)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	local spin = Instance.new("Frame")
	spin.Name = "Spin"
	spin.BackgroundTransparency = 1
	spin.Size = UDim2.fromScale(1, 1)
	spin.AnchorPoint = Vector2.new(0.5, 0.5)
	spin.Position = UDim2.fromScale(0.5, 0.5)
	spin.Parent = bb
	for k = 0, 3 do
		local corner = Instance.new("Frame")
		corner.BackgroundTransparency = 1
		corner.Size = UDim2.fromScale(0.3, 0.3)
		corner.AnchorPoint = Vector2.new(0.5, 0.5)
		local x, y = (k % 2 == 0) and 0.18 or 0.82, (k < 2) and 0.18 or 0.82
		corner.Position = UDim2.fromScale(x, y)
		corner.Parent = spin
		for _, horiz in ipairs({ true, false }) do
			local b = Instance.new("Frame")
			b.Name = "Bar"
			b.BackgroundColor3 = C.OrangeHi
			b.BorderSizePixel = 0
			b.Size = horiz and UDim2.new(1, 0, 0, 6) or UDim2.new(0, 6, 1, 0)
			b.Position = UDim2.fromScale(horiz and 0 or (x < 0.5 and 0 or 1), horiz and (y < 0.5 and 0 or 1) or 0)
			b.AnchorPoint = Vector2.new(horiz and 0 or (x < 0.5 and 0 or 1), horiz and (y < 0.5 and 0 or 1) or 0)
			b.Parent = corner
			Kit.Corner(b, 3)
			Kit.Stroke(b, C.Ink, 2)
		end
	end
	local dot = Instance.new("Frame")
	dot.BackgroundColor3 = C.Red
	dot.Size = UDim2.fromOffset(12, 12)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Parent = bb
	Kit.Corner(dot, 6)
	Kit.Stroke(dot, C.Ink, 2)
	local key = Kit.Text(bb, "F", { Name = "Key", Size = UDim2.fromOffset(40, 16), Position = UDim2.new(0.5, 0, 1, 2), AnchorPoint = Vector2.new(0.5, 0), Color = C.YellowHi, Shadow = 2, Stroke = 2 })
	local _ = key
	bb.Parent = player:WaitForChild("PlayerGui")
	return bb
end

local function launcherMotor(v: Model?): Motor6D?
	local root = v and v.PrimaryPart
	return root and root:FindFirstChild("LauncherYaw") :: Motor6D?
end

local function muzzle(v: Model?): Attachment?
	local base = v and v:FindFirstChild("LauncherBase", true)
	return base and base:FindFirstChild("Muzzle") :: Attachment?
end

-- the dart: a tiny cylinder + neon tip with a trail, flying on a slight arc
local function flyDart(from: Vector3, to: () -> Vector3, duration: number)
	local folder = DinosaurVFX.Folder()
	local dart = Instance.new("Part")
	dart.Anchored = true
	dart.CanCollide = false
	dart.CanQuery = false
	dart.CanTouch = false
	dart.Size = Vector3.new(0.3, 0.3, 1.4)
	dart.Color = Color3.fromRGB(200, 205, 210)
	dart.Material = Enum.Material.Metal
	dart.Parent = folder
	local tip = Instance.new("Part")
	tip.Anchored = true
	tip.CanCollide = false
	tip.CanQuery = false
	tip.Size = Vector3.new(0.34, 0.34, 0.45)
	tip.Color = Color3.fromRGB(63, 224, 200)
	tip.Material = Enum.Material.Neon
	tip.Parent = folder
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.12, 0.6)
	a0.Parent = dart
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.12, 0.6)
	a1.Parent = dart
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.25
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(63, 224, 200))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 1
	trail.Parent = dart
	local t0 = os.clock()
	local last = from
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / duration, 0, 1)
		local dest = to()
		local p = from:Lerp(dest, u) + Vector3.new(0, math.sin(u * math.pi) * 2.2, 0)
		local dir = (p - last)
		if dir.Magnitude > 1e-3 then
			dart.CFrame = CFrame.lookAt(p, p + dir)
			tip.CFrame = dart.CFrame * CFrame.new(0, 0, -0.9)
		end
		last = p
		if u >= 1 then
			conn:Disconnect()
			task.delay(0.3, function() dart:Destroy() tip:Destroy() end)
		end
	end)
end

function Darts.Fire()
	if Drive.State.Mode ~= "Route" or Drive.State.OnFoot then return end
	local now = os.clock()
	if now < nextFire then return end
	if not target then
		nextFire = now + 0.4 -- nothing to hit: a dry click, no toast spam
		return
	end
	nextFire = now + Config.Expedition.DartCooldown
	local t = target
	local id = t.Cfg:GetAttribute("Id") or tonumber(t.Cfg.Name:match("%d+$"))
	local v = Drive.State.Vehicle
	local m = muzzle(v)
	local from = m and m.WorldPosition or (Drive.State.Root and Drive.State.Root.Position + Vector3.new(0, 6, 0)) or t.Root.Position
	local dist = (t.Root.Position - from).Magnitude
	local travel = math.clamp(dist / Config.Expedition.DartSpeed, 0.08, 0.7)
	-- predicted shot (instant feel); the server confirms the hit
	recoil = 1
	DinosaurVFX.Burst(CFrame.new(from), 6, { Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(2, 6), Color = Color3.fromRGB(255, 230, 160), Size = NumberSequence.new(0.6, 0), LightEmission = 1 })
	local root = t.Root
	flyDart(from, function() return root.Parent and (root.Position + Vector3.new(0, 1.5, 0)) or from end, travel)
	lastFireTarget = t
	task.spawn(function()
		local res = Net.Ask("FireDart", { Id = id })
		if not res.Ok and res.Err then Kit.Toast(res.Err, "Red", "Dart") end
	end)
end

local function floater(pos: Vector3, text: string, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(pos)
	p.Parent = DinosaurVFX.Folder()
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 46)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = p
	bb.Parent = p
	local t = Kit.Text(bb, text, { Size = UDim2.fromScale(1, 1), Color = color, Shadow = 3, Stroke = 3 })
	Kit.Pop(t, 2)
	TweenService:Create(p, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) }):Play()
	task.delay(1.1, function() p:Destroy() end)
end

-- the hit callouts (PERFECT!, DODGED!...) floating over a chaser; TikTok recordings reuse them
Darts.Floater = floater

function Darts.Start(view, hud)
	View, HUD = view, hud
	HUD.OnFire = Darts.Fire
	ContextActionService:BindActionAtPriority("DinoDart", function(_, state)
		-- (only in the rover: on foot at a site, F and Y belong to the fight and the rover's DRIVE OFF prompt)
		if state == Enum.UserInputState.Begin and Drive.State.Mode == "Route" and not Drive.State.OnFoot then
			Darts.Fire()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 2100, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	-- click / tap anywhere in the world to fire at the creature under (or nearest) the cursor
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if Drive.State.Mode == "Route" and not Drive.State.OnFoot and target then Darts.Fire() end
	end)
	Net.On("DartHit", function(info)
		local hitC = nil
		for cfg, c in pairs(View.Creatures()) do
			if (cfg:GetAttribute("Id") or tonumber(cfg.Name:match("%d+$"))) == info.Id then hitC = c end
		end
		local pos = hitC and hitC.Root and hitC.Root.Position + Vector3.new(0, 3, 0)
		if not pos then return end
		if info.Result == "None" then
			floater(pos, "NO EFFECT", C.Muted)
			return
		end
		DinosaurVFX.Cubes(pos, 10, { Color3.fromRGB(63, 224, 200), Color3.fromRGB(255, 255, 255) }, 0.3, 14, 0.6)
		DinosaurVFX.BlockRing(CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 12, R0 = 0.5, R1 = 5, Color = Color3.fromRGB(120, 255, 230), Duration = 0.4 })
		if info.Result == "Perfect" then
			-- the timed shot: a big hit, it tumbles back
			floater(pos, "PERFECT!", C.YellowHi)
			require(script.Parent.Audio).Sting("Perfect", 0.5)
			DinosaurVFX.Shake(0.7, 0.25)
			DinosaurVFX.Cubes(pos, 22, { Color3.fromRGB(255, 226, 120), Color3.fromRGB(255, 255, 255), Color3.fromRGB(63, 224, 200) }, 0.45, 22, 0.8)
			DinosaurVFX.BlockRing(CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 18, R0 = 1, R1 = 10, Color = Color3.fromRGB(255, 226, 120), Duration = 0.5, Block = 0.8 })
		elseif info.Result == "Glance" then floater(pos, "IT SHRUGS IT OFF - WAIT FOR THE LUNGE", C.Cream)
		elseif info.Result == "Dodge" then floater(pos, "DODGED!", C.OrangeHi)
		elseif info.Result == "Stun" then floater(pos, "STUNNED!", C.TealHi)
		elseif info.Result == "Calm" then
			-- (a boss on the run: its calm meter as a percent; a normal chaser: hits left of its handful)
			floater(pos, info.Pct and ("CALM " .. info.Pct .. "%") or (info.Calm and ("CALM " .. info.Calm .. "/" .. (info.CalmMax or 5))) or "HIT!", C.YellowHi)
			DinosaurVFX.Shake(0.4, 0.2)
		elseif info.Result == "Sedated" then
			floater(pos, "SEDATED!", C.LimeHi)
			DinosaurVFX.Shake(1.2, 0.5)
			DinosaurVFX.BlockRing(CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 22, R0 = 1, R1 = 14, Color = Color3.fromRGB(150, 255, 120), Duration = 0.7, Block = 1 })
		end
	end)
	-- threat portraits: chasers you can't see (behind you, off the edge) show at the bottom edge of the screen on
	-- the side they're coming from; red and NOW! when they're lining up a lunge or hanging off the rover
	local tgui = Instance.new("ScreenGui")
	tgui.Name = "DinoThreats"
	tgui.ResetOnSpawn = false
	tgui.IgnoreGuiInset = true
	tgui.DisplayOrder = 8
	tgui.Parent = player:WaitForChild("PlayerGui")
	local slots = {}
	for i = 1, 4 do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 1)
		f.Size = UDim2.fromOffset(74, 74)
		f.BackgroundColor3 = C.Forest
		f.BackgroundTransparency = 0.15
		f.Visible = false
		f.Parent = tgui
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.5, 0)
		cr.Parent = f
		local ring = Instance.new("UIStroke")
		ring.Thickness = 4
		ring.Parent = f
		local label = Kit.Text(f, "", { Pixel = true, Size = UDim2.new(1.6, 0, 0, 12), Position = UDim2.new(0.5, 0, 0, -8), AnchorPoint = Vector2.new(0.5, 1), Stroke = 2, Shadow = 1, MaxSize = 12, ZIndex = 4 })
		slots[i] = { Frame = f, Ring = ring, Label = label, Species = nil }
	end
	RunService.RenderStepped:Connect(function()
		local st = Drive.State
		local cam = Workspace.CurrentCamera
		local used = 0
		if st.Mode == "Route" and st.Root and not st.OnFoot and cam then
			local rc = st.Root.CFrame
			local vp = cam.ViewportSize
			for _, t in ipairs(myCreatures()) do
				if used >= #slots then break end
				local p = t.Root.Position
				local sp, onScreen = cam:WorldToViewportPoint(p)
				local visible = onScreen and sp.Z > 0 and sp.X > 40 and sp.X < vp.X - 40 and sp.Y < vp.Y - 60
				if visible then continue end
				used += 1
				local slot = slots[used]
				local species = t.Cfg:GetAttribute("Species")
				if slot.Species ~= species then
					for _, ch in ipairs(slot.Frame:GetChildren()) do if ch:IsA("ImageLabel") or ch.Name == "Icon" then ch:Destroy() end end
					local ic = Kit.Icon(slot.Frame, "Dino", { Species = species, Size = UDim2.fromScale(1.05, 1.05), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
					ic.Name = "Icon"
					slot.Species = species
				end
				local lat = rc.RightVector:Dot(p - rc.Position)
				local x = vp.X * (0.5 + math.clamp(lat / 26, -0.42, 0.42))
				local danger = t.Cfg:GetAttribute("State") == "Telegraph" or t.Cfg:GetAttribute("State") == "Latch"
				local dist = (p - rc.Position).Magnitude
				local pulse = danger and (1 + math.abs(math.sin(os.clock() * 14)) * 0.18) or 1
				local size = math.clamp(96 - dist * 1.2, 54, 92) * pulse
				slot.Frame.Size = UDim2.fromOffset(size, size)
				slot.Frame.Position = UDim2.fromOffset(x, vp.Y - 96)
				slot.Ring.Color = danger and C.RedHi or C.OrangeHi
				Kit.SetText(slot.Label, danger and ("NOW! " .. (Kit.Gamepad() and "Y" or (Kit.Platform() == "Touch" and "DART" or "F"))) or (math.floor(dist) .. "M"))
				Kit.SetTextColor(slot.Label, danger and C.RedHi or C.Cream)
				slot.Frame.Visible = true
			end
		end
		for i = used + 1, #slots do slots[i].Frame.Visible = false end
	end)

	RunService.RenderStepped:Connect(function(dt)
		-- pick the target
		local st = Drive.State
		if st.Mode ~= "Route" or not st.Root or st.OnFoot then
			target = nil
		else
			local from = st.Root.Position
			local fwd = st.Root.CFrame.LookVector
			local best, bestS = nil, -math.huge
			for _, t in ipairs(myCreatures()) do
				local s = score(t, from, fwd)
				if s and s > bestS then best, bestS = t, s end
			end
			target = best
		end
		-- reticle
		if target then
			reticle = reticle or buildReticle()
			reticle.Enabled = true
			reticle.Adornee = target.Root
			local _, size = target.Model:GetBoundingBox()
			reticle.StudsOffset = Vector3.new(0, size.Y * 0.35, 0)
			local spin = reticle:FindFirstChild("Spin") :: Frame
			spin.Rotation = (os.clock() * 90) % 360
			local tst = target.Cfg:GetAttribute("State")
			local urgent = tst == "Telegraph" or tst == "Charge" or tst == "Latch"
			local pulse = 1 + math.sin(os.clock() * (urgent and 18 or 6)) * 0.08
			reticle.Size = UDim2.fromOffset(110 * pulse, 110 * pulse)
			for _, b in ipairs(spin:GetDescendants()) do
				if b:IsA("Frame") and b.Name == "Bar" then b.BackgroundColor3 = urgent and C.RedHi or C.OrangeHi end
			end
			local key = reticle:FindFirstChild("Key")
			-- the reticle teaches the timing: it flashes red and says NOW while the dino lines up its lunge
			local keyName = Kit.Gamepad() and "Y" or (Kit.Platform() == "Touch" and "DART" or "F")
			if key then Kit.SetText(key, urgent and ("NOW! " .. keyName) or keyName) end
		elseif reticle then
			reticle.Enabled = false
		end
		-- turret: track the target (or sweep), recoil kick
		recoil = math.max(0, recoil - dt * 6)
		local v = st.Vehicle
		local motor = launcherMotor(v)
		if motor and v and v.PrimaryPart then
			local want
			if target then
				local lp = v.PrimaryPart.CFrame:PointToObjectSpace(target.Root.Position)
				want = math.atan2(-lp.X, -lp.Z)
			else
				want = math.sin(os.clock() * 0.6) * 0.5
			end
			turretYaw += math.atan2(math.sin(want - turretYaw), math.cos(want - turretYaw)) * math.min(1, dt * 8)
			motor.Transform = CFrame.Angles(0, turretYaw, 0) * CFrame.new(0, 0, recoil * 0.35) * CFrame.Angles(recoil * 0.12, 0, 0)
		end
	end)
end

return Darts
