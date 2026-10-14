--[[
	FakeWarp — the plain time travel, for showing the contrast with the real Warp.
	Gallery only (Settings > CUTSCENES > BAD TIME WARP). Your rover drives through the Time Gate on a chase
	cam (riding the floor, wheels turning), then a flat full-screen warp: streaks of light, a TIME TRAVELING...
	bar filling up, and a 65 MILLION YEARS AGO card. Game-styled, but a loading screen instead of a ride.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Cinema = require(script.Parent.UI.Cinema)
local Kit = require(script.Parent.UI.Kit)
local Net = require(script.Parent.Net)

local player = Players.LocalPlayer
local FakeWarp = {}

-- the player's own rover, cloned from the template and anchored (a prop, not the real driven vehicle)
local function realCar(parent: Instance): (Model?, BasePart?)
	local gear = (Net.Profile and Net.Profile.Gear) or {}
	local templates = ReplicatedStorage:WaitForChild("DinoExpedition"):FindFirstChild("Vehicles")
	local t = templates and (templates:FindFirstChild(gear.Vehicle or "RookieRanger") or templates:FindFirstChild("RookieRanger"))
	if not t then return nil, nil end
	local m = t:Clone() :: Model
	m.Name = "FakeWarpCar"
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Constraint") then
			d:Destroy()
		end
	end
	m.Parent = parent
	return m, m.PrimaryPart
end

local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
ray.RespectCanCollide = true -- (solid floors only: inside the gate frame the ray landed on the membrane and the car hopped 15 studs)
-- top of whatever is under a point (the gate deck, the plaza, terrain)
local function floorAt(p: Vector3, fallback: number): number
	local hit = Workspace:Raycast(p + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), ray)
	return hit and hit.Position.Y or fallback
end

local function gateCFrames(): (Vector3, Vector3)
	local camp = Workspace:FindFirstChild("BaseCamp")
	local trig = camp and camp:FindFirstChild("GateTrigger", true)
	local arr = camp and camp:FindFirstChild("GateArrival", true)
	if trig and arr and trig:IsA("BasePart") and arr:IsA("BasePart") then
		local at = Vector3.new(trig.Position.X, arr.Position.Y, trig.Position.Z)
		local d = at - arr.Position
		d = Vector3.new(d.X, 0, d.Z)
		return at, (d.Magnitude > 0.1 and d.Unit or Vector3.new(0, 0, -1))
	end
	-- no camp loaded: drive at an imaginary gate in front of you
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local p = root and root.Position or Vector3.new(0, 5, 0)
	return p + Vector3.new(0, -3, -40), Vector3.new(0, 0, -1)
end

function FakeWarp.Play()
	local cine = Cinema.Begin("DinoFakeWarpUI")
	local cam = Workspace.CurrentCamera
	-- (the rover's camera stands down: played from the gallery while seated, its chase cam fought every frame)
	local Drive = require(script.Parent.Drive)
	Drive.HoldCamera(true)
	Drive.SetCameraOverride(true)
	cam.CameraType = Enum.CameraType.Scriptable
	local folder = Instance.new("Folder")
	folder.Name = "DinoFakeWarp"
	folder.Parent = Workspace
	local gui = Instance.new("ScreenGui")
	gui.Name = "DinoFakeWarpUI"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local blur = Instance.new("BlurEffect")
	blur.Name = "DinoFakeWarpBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local skipped = false
	local t0 = os.clock()
	local conn = UserInputService.InputBegan:Connect(function(input)
		if os.clock() - t0 > 1 and (input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA) then skipped = true end
	end)
	local function wait(s: number)
		local e = os.clock() + s
		while os.clock() < e and not skipped do RunService.RenderStepped:Wait() end
	end

	local ok, err = pcall(function()
		-- 1. drive in: your rover rolls up to the gate and through it, camera chasing behind
		local gate, dir = gateCFrames()
		local car, root = realCar(folder)
		ray.FilterDescendantsInstances = { folder, player.Character :: Instance }
		local rh = car and car:GetAttribute("RootHeight") or 2.6
		local from, to = gate - dir * 80, gate + dir * 8
		local wheels = {}
		if car and root then
			for _, w in ipairs(car:GetDescendants()) do
				if w:IsA("Model") and w.Name:match("^Wheel[FR][LR]$") then
					table.insert(wheels, { M = w, Off = root.CFrame:ToObjectSpace(w:GetPivot()), R = w:GetAttribute("Radius") or 1.4 })
				end
			end
		end
		cam.FieldOfView = 65
		local dur = 4
		local start = os.clock()
		local floorY = floorAt(from, gate.Y)
		local camPos: Vector3? = nil
		while not skipped do
			local u = math.min((os.clock() - start) / dur, 1)
			-- eases up to speed, no stopping at the end (it goes through)
			local e = u * u * (1.6 - 0.6 * u)
			local p = from:Lerp(to, e)
			floorY += (floorAt(p, floorY) - floorY) * 0.35
			local t = os.clock() - start
			local bob = math.sin(t * 9) * 0.06
			local rootCF = CFrame.lookAt(Vector3.new(p.X, floorY + rh + bob, p.Z), Vector3.new(p.X, floorY + rh + bob, p.Z) + dir) * CFrame.Angles(math.sin(t * 5) * 0.012, 0, math.sin(t * 7) * 0.01)
			if car and root then
				local dist = (to - from).Magnitude * e
				local spun = {}
				for _, w in ipairs(wheels) do spun[w] = rootCF * w.Off * CFrame.Angles(-dist / w.R, 0, 0) end
				car:PivotTo(rootCF * root.CFrame:ToObjectSpace(car:GetPivot()))
				for w, cf in pairs(spun) do w.M:PivotTo(cf) end
			end
			local want = rootCF.Position - dir * 24 + Vector3.new(0, 8, 0)
			camPos = camPos and camPos:Lerp(want, 0.12) or want
			cam.CFrame = CFrame.lookAt(camPos :: Vector3, rootCF.Position + dir * 10 + Vector3.new(0, 2, 0))
			if u >= 1 then break end
			RunService.RenderStepped:Wait()
		end
		if car then car:Destroy() end

		-- 2. the warp: no tunnel, no ride - the screen fills with streaking time light and a bar fills up
		local base = Instance.new("Frame")
		base.Size = UDim2.fromScale(1, 1)
		base.BackgroundColor3 = Color3.fromRGB(20, 60, 70)
		base.BorderSizePixel = 0
		base.Parent = gui
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 220, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 90, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 80)),
		})
		grad.Parent = base
		-- light streaks racing across (fixed layout so every play looks the same)
		local streaks = {}
		for i = 1, 26 do
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = (i % 3 == 0) and Color3.fromRGB(255, 220, 120) or Color3.fromRGB(190, 255, 245)
			f.BackgroundTransparency = 0.25 + (i % 4) * 0.15
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Size = UDim2.new(0.12 + (i % 5) * 0.06, 0, 0, 3 + (i % 3) * 3)
			f.ZIndex = 2
			f.Parent = gui
			streaks[i] = { F = f, Y = ((i * 37) % 100) / 100, Speed = 1.4 + (i % 6) * 0.45, X0 = ((i * 53) % 100) / 100 }
		end
		local label = Kit.Text(gui, "TIME TRAVELING...", { Size = UDim2.fromScale(0.6, 0.08), Position = UDim2.fromScale(0.5, 0.44), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.fromRGB(255, 244, 214), Stroke = 4, Shadow = 5, ZIndex = 10, MaxSize = 56 })
		local track = Instance.new("Frame")
		track.AnchorPoint = Vector2.new(0.5, 0.5)
		track.Position = UDim2.fromScale(0.5, 0.54)
		track.Size = UDim2.fromScale(0.5, 0.035)
		track.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
		track.ZIndex = 10
		track.Parent = gui
		Kit.Corner(track, 10)
		Kit.Stroke(track, Color3.new(0, 0, 0), 3)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
		fill.ZIndex = 11
		fill.Parent = track
		Kit.Corner(fill, 10)
		local s0 = os.clock()
		local WARP = 2.6
		while not skipped do
			local t = os.clock() - s0
			local u = math.min(t / WARP, 1)
			for _, st in ipairs(streaks) do
				local x = (st.X0 + t * st.Speed) % 1.4 - 0.2
				st.F.Position = UDim2.fromScale(x, st.Y)
			end
			grad.Rotation = t * 40
			fill.Size = UDim2.fromScale(u, 1)
			if u >= 1 then break end
			RunService.RenderStepped:Wait()
		end
		for _, st in ipairs(streaks) do st.F:Destroy() end
		label:Destroy()
		track:Destroy()

		-- 3. the arrival card
		base.BackgroundColor3 = Color3.new(0, 0, 0)
		grad:Destroy()
		Kit.Text(gui, "65 MILLION YEARS AGO", { Size = UDim2.fromScale(0.8, 0.1), Position = UDim2.fromScale(0.5, 0.48), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.fromRGB(255, 244, 214), Stroke = 4, Shadow = 5, ZIndex = 10, MaxSize = 64 })
		wait(2)
	end)
	if not ok then warn("[FakeWarp]", err) end

	conn:Disconnect()
	gui:Destroy()
	blur:Destroy()
	folder:Destroy()
	cam.FieldOfView = 70
	Drive.HoldCamera(false)
	Drive.SetCameraOverride(false)
	cam.CameraType = Enum.CameraType.Custom
	Cinema.End(cine)
end

return FakeWarp
