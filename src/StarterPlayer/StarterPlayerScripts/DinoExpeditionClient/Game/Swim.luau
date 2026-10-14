--[[
	Swim — being in the water (Spine River's rivers and lagoon are real Terrain water).
	Roblox's own Humanoid swimming does the physics + the swim stroke animation; this module adds:
	  * the "Swimming" attribute on every Player this client can see (PlayerAnim stands down while it's set,
	    so the stroke isn't fought by our procedural poses). Evaluated locally for every character nearby.
	  * DIVE: hold C / Left Ctrl / L1 / the DIVE tile to swim down (Space / jump swims up, as usual)
	  * a breath meter that only shows while your head is under water; when it runs out you're pushed
	    back up to the surface (no damage - it's a kids' game), with a gasp of bubbles
	  * splashes going in, a little wake ring at the surface, bubbles under water
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.UI.Kit)
local Cinema = require(script.Parent.UI.Cinema)

local player = Players.LocalPlayer
local Swim = {}

local BREATH = 14 -- seconds under water
local DIVE_SPEED = 16
local waterRay = RaycastParams.new()
waterRay.FilterType = Enum.RaycastFilterType.Include
waterRay.IgnoreWater = false

-- the water surface above/below a point (nil = no water here). Terrain only: the cast hits the water's surface
local function surfaceAt(p: Vector3): number?
	waterRay.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(p + Vector3.new(0, 12, 0), Vector3.new(0, -24, 0), waterRay)
	if hit and hit.Material == Enum.Material.Water then return hit.Position.Y end
	return nil
end

local function fx(at: Vector3, kind: string)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = at
	p.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.LightEmission = 0.2
	if kind == "Splash" then
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Lifetime = NumberRange.new(0.45, 0.8)
		e.Speed = NumberRange.new(10, 18)
		e.SpreadAngle = Vector2.new(35, 35)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -40, 0)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 2.6) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255))
		e.Parent = p
		e:Emit(26)
	elseif kind == "Ring" then
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Lifetime = NumberRange.new(0.8, 1.1)
		e.Speed = NumberRange.new(0, 0)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.fromRGB(225, 245, 255))
		e.Parent = p
		e:Emit(1)
	else -- Bubbles
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(3, 6)
		e.SpreadAngle = Vector2.new(25, 25)
		e.EmissionDirection = Enum.NormalId.Top
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
		e.Color = ColorSequence.new(Color3.fromRGB(210, 240, 255))
		e.Parent = p
		e:Emit(kind == "Gasp" and 24 or 4)
	end
	task.delay(2, function() p:Destroy() end)
end

function Swim.Start()
	-- UI: a DIVE tile (touch) and the breath meter (only while under)
	local _, canvas = Kit.Screen("DinoSwimUI", 9, false, 0.75)
	local diving = false
	local diveTile = Kit.Tile(canvas, { Name = "Dive", Icon = "Bolt", Label = "DIVE", Color = "Blue", Size = UDim2.fromOffset(84, 84), Position = UDim2.new(1, -24, 1, -330), AnchorPoint = Vector2.new(1, 1), OnClick = function() end })
	diveTile.Visible = false
	-- the tile is a hold: press to dive, release to stop
	for _, d in ipairs(diveTile:GetDescendants()) do
		if d:IsA("GuiButton") then
			d.MouseButton1Down:Connect(function() diving = true end)
			d.MouseButton1Up:Connect(function() diving = false end)
			d.MouseLeave:Connect(function() diving = false end)
		end
	end
	local meter = Instance.new("Frame")
	meter.Name = "Breath"
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.new(0.5, 0, 1, -150)
	meter.Size = UDim2.fromOffset(240, 22)
	meter.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	meter.Visible = false
	meter.Parent = canvas
	Instance.new("UICorner", meter).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(16, 20, 28)
	stroke.Parent = meter
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 200, 255)
	fill.Parent = meter
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = "AIR"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = 3
	label.Parent = meter
	local ls = Instance.new("UIStroke")
	ls.Thickness = 2
	ls.Parent = label

	local DIVE_KEYS = { [Enum.KeyCode.C] = true, [Enum.KeyCode.LeftControl] = true, [Enum.KeyCode.ButtonL1] = true }
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if DIVE_KEYS[input.KeyCode] then diving = true end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if DIVE_KEYS[input.KeyCode] then diving = false end
	end)

	local breath = BREATH
	local wasIn = {} :: { [Player]: boolean }
	-- (2026-10-13) swimming in Base Camp's lagoon is allowed (island to island: the shore walls are only on the bridges
	-- now), but anyone who gets out past the crater rim into the open sea is put back on the last dry ground they stood on
	local Zone = require(script.Parent.Zone)
	local lastDry: CFrame? = nil
	local dryAt, wetSince = 0, nil :: number?
	local function campRescue(now: number, hum: Humanoid?, hrp: BasePart?, swimming: boolean)
		if Zone.Current ~= "BaseCamp" or not (hum and hrp) or hum.SeatPart or Cinema.Playing() then wetSince = nil return end
		if not swimming then
			wetSince = nil
			local floor = hum.FloorMaterial
			if now >= dryAt and floor ~= Enum.Material.Air and floor ~= Enum.Material.Water then
				dryAt = now + 0.4
				lastDry = hrp.CFrame
			end
			return
		end
		-- (inside the rim = the lagoon: swim away. The rim runs ~710-730 studs out from the hub, world (600, 0, 0))
		local off = hrp.Position - Vector3.new(600, 0, 150)
		local outside = math.abs(off.X) > 735 or off.Z > 600 or off.Z < -640
		if not outside then wetSince = nil return end
		wetSince = wetSince or now
		if now - wetSince < 1.2 then return end
		wetSince = nil
		local to = lastDry
		if not to then
			local camp = Workspace:FindFirstChild("BaseCamp")
			local spawn = camp and camp:FindFirstChild("CampSpawn", true) :: BasePart?
			to = spawn and spawn.CFrame or nil
		end
		if not to then return end
		local body = hrp.Parent :: Model
		hrp.AssemblyLinearVelocity = Vector3.zero
		body:PivotTo(to + Vector3.new(0, 3, 0))
		Kit.Toast("BACK ON DRY LAND!", "Blue")
	end
	-- my swimming sounds: strokes at the surface, a muffled hush under it (the place's ambience sinks away)
	local Audio = require(script.Parent.Audio)
	local strokeSnd, underSnd = nil :: Sound?, nil :: Sound?
	local wasUnder = false
	local function swimSounds(on: boolean, under: boolean, moving: boolean)
		if on and not strokeSnd then strokeSnd = Audio.Loop("SwimLoop") end
		if on and not underSnd then underSnd = Audio.Loop("Underwater") end
		if strokeSnd then strokeSnd.Volume = (on and not under and moving) and (Audio.Level.SwimLoop or 0.5) or 0 end
		if underSnd then underSnd.Volume = (on and under) and (Audio.Level.Underwater or 0.6) or 0 end
		if under ~= wasUnder then
			wasUnder = under
			Audio.AmbienceLevel(under and 0.25 or 1)
		end
		if not on then
			if strokeSnd then strokeSnd:Destroy() strokeSnd = nil end
			if underSnd then underSnd:Destroy() underSnd = nil end
		end
	end
	local nextRing, nextBubble, scanAt = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		-- who's swimming: every character near this client (4x a second is plenty)
		if now >= scanAt then
			scanAt = now + 0.25
			local cam = Workspace.CurrentCamera
			local eye = cam and cam.CFrame.Position or Vector3.zero
			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local swimming = false
				if hrp and hum and hum.SeatPart == nil and (hrp.Position - eye).Magnitude < 400 then
					if plr == player then
						swimming = hum:GetState() == Enum.HumanoidStateType.Swimming
					else
						local s = surfaceAt(hrp.Position)
						swimming = s ~= nil and hrp.Position.Y < s + 0.6
					end
				end
				if swimming ~= (plr:GetAttribute("Swimming") == true) then
					plr:SetAttribute("Swimming", swimming or nil)
					if swimming and hrp then
						local s = surfaceAt(hrp.Position)
						fx(Vector3.new(hrp.Position.X, (s or hrp.Position.Y), hrp.Position.Z), "Splash")
						Audio.Play("Splash", { At = Vector3.new(hrp.Position.X, (s or hrp.Position.Y), hrp.Position.Z), Gap = 0.2 })
					end
				end
				wasIn[plr] = swimming
			end
		end
		-- my own swimming: dive, breath, ripples
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local head = char and char:FindFirstChild("Head") :: BasePart?
		local mine = player:GetAttribute("Swimming") == true and hrp ~= nil and not Cinema.Playing()
		campRescue(now, char and char:FindFirstChildOfClass("Humanoid"), hrp, player:GetAttribute("Swimming") == true)
		diveTile.Visible = mine and UserInputService.TouchEnabled
		if not (mine and hrp) then
			if strokeSnd or underSnd or wasUnder then swimSounds(false, false, false) end
			breath = math.min(BREATH, breath + dt * 4)
			meter.Visible = false
			return
		end
		if diving then
			local v = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(v.X, -DIVE_SPEED, v.Z)
		end
		local under = false
		if head then
			-- under = the top of the head is below the surface (a voxel read alone counts surface swimming)
			local s = surfaceAt(head.Position)
			under = s ~= nil and head.Position.Y + 0.4 < s
		end
		do
			local v = hrp.AssemblyLinearVelocity
			swimSounds(true, under, Vector3.new(v.X, 0, v.Z).Magnitude > 3)
		end
		if under then
			breath = math.max(0, breath - dt)
			if now >= nextBubble then nextBubble = now + 0.5 fx(head.Position, "Bubbles") end
			if breath <= 0 then
				-- out of air: up you go, with a big gasp of bubbles
				fx(head.Position, "Gasp")
				diving = false
				hrp.AssemblyLinearVelocity = Vector3.new(0, 34, 0)
				breath = BREATH * 0.35
				Kit.Toast("OUT OF AIR!", "Blue", "Alert")
			end
		else
			breath = math.min(BREATH, breath + dt * 5)
			local s = surfaceAt(hrp.Position)
			if s and now >= nextRing and hrp.AssemblyLinearVelocity.Magnitude > 4 then
				nextRing = now + 0.35
				fx(Vector3.new(hrp.Position.X, s + 0.05, hrp.Position.Z), "Ring")
			end
		end
		meter.Visible = under or breath < BREATH - 0.05
		local k = breath / BREATH
		fill.Size = UDim2.fromScale(math.max(0.04, k), 1)
		fill.BackgroundColor3 = k > 0.35 and Color3.fromRGB(90, 200, 255) or Color3.fromRGB(255, 90, 70)
	end)
	Players.PlayerRemoving:Connect(function(plr) wasIn[plr] = nil end)
	local _ = TweenService
end

return Swim
