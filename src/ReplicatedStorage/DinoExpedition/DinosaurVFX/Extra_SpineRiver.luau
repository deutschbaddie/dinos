--[[
	Spine River species effects (Croc Creek / Sarcosuchus), registered as DinosaurVFX.Extra events.

	LidsShut { Dur }     eyes shut (lids drawn) for Dur seconds, then they snap open
	LogDrift { Dur }     the stage's "DriftLogs" prop drifts along the water (or, with no prop around, a few
	                     temporary logs float by the croc) for the length of the signature, then everything goes home
	EyeRipple { Scale }  little rings spreading from the eyes at the waterline
	Bubbles { Dur }      bubbles boiling up around the snout (the bank-lunge telegraph)
	LensSpray { Scale }  a sheet of water flung straight at the camera + drops running down the "lens"
	RollSpray { Dur }    the death roll: spray thrown off the spinning body, rings around its axis
	Hiss { Scale }       a wet hiss: mist and spittle from the gaping jaws
	WaterDance { Dur }   the bellow: water drops dancing up off its back scutes
	TailWave { Scale }   the tail sweep throws a wall of water (dust on dry land)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local WATER = { Color3.fromRGB(110, 190, 255), Color3.fromRGB(170, 220, 255), Color3.fromRGB(80, 160, 230) }
local FOAM = Color3.fromRGB(230, 244, 255)
local BARK = { Color3.fromRGB(94, 65, 40), Color3.fromRGB(107, 74, 43), Color3.fromRGB(125, 87, 51) }

return function(VFX)
	local function att(model: Model, name: string): Attachment?
		return VFX.findAttachment(model, name)
	end
	-- the water surface under the model (falls back to the given height on dry land)
	local function surfaceY(model: Model, fallback: number): number
		local y = VFX.waterSurface(model)
		return y or fallback
	end
	local function anchored(props): Part
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		for k, v in pairs(props) do (p :: any)[k] = v end
		p.Parent = VFX.Folder()
		return p
	end
	-- a flat ring of blocks lying on the water
	local function waterRing(pos: Vector3, r0: number, r1: number, block: number, dur: number?, count: number?)
		VFX.BlockRing(CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0), {
			Count = count or 14, R0 = r0, R1 = r1, Block = block, Color = FOAM, Transparency = 0.35, Duration = dur or 0.9,
		})
	end

	-- eyes shut, then open: drives the animator's own lid state so its blinking doesn't fight us
	VFX.Extra.LidsShut = function(model: Model, arg, _s)
		local Animations = require(script.Parent.Parent:WaitForChild("DinosaurAnimations")) :: any
		local anim = Animations.find(model)
		local dur = (arg and arg.Dur) or 1.5
		if anim then anim.EyesClosed = true end
		task.delay(dur, function()
			if anim then anim.EyesClosed = false end
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "Eyelid" then d.Transparency = 1 end
			end
		end)
	end

	-- logs drifting with the croc: the stage's own DriftLogs prop, or temporary logs when there isn't one
	VFX.Extra.LogDrift = function(model: Model, arg, s)
		local dur = (arg and arg.Dur) or 7
		local pivot = model:GetPivot()
		local along = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
		along = along.Magnitude > 0.01 and along.Unit or Vector3.new(0, 0, -1)
		local prop = VFX.findProp(model, "DriftLogs")
		local logs = {}
		if prop then
			for _, m in ipairs(prop:GetChildren()) do
				if m:IsA("Model") then table.insert(logs, { Model = m, Home = m:GetPivot(), Temp = false }) end
			end
		else
			-- no stage: three logs float by on the water around it, then sink away
			local y = surfaceY(model, pivot.Position.Y)
			local side = pivot.RightVector
			for i, spot in ipairs({ { -1.0, -0.55 }, { 1.0, -0.35 }, { -0.9, 0.35 } }) do
				local m = Instance.new("Model")
				m.Name = "DriftLogTemp"
				local len = (7 + i) * math.max(1, s * 0.6)
				local d = 1.8 * math.max(1, s * 0.6)
				local c = pivot.Position + side * spot[1] * 9 * math.max(1, s * 0.5) + along * spot[2] * 30 * math.max(1, s * 0.4)
				local cf = CFrame.new(c.X, y, c.Z) * CFrame.Angles(0, math.rad(60 + i * 37), 0)
				local body = anchored({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, d, d), Color = BARK[i], Material = Enum.Material.Wood, CFrame = cf, CastShadow = true })
				body.Parent = m
				local cap = anchored({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, d * 0.86, d * 0.86), Color = Color3.fromRGB(201, 154, 98), CFrame = cf * CFrame.new(-len / 2 - 0.02, 0, 0) })
				cap.Parent = m
				local moss = anchored({ Size = Vector3.new(len * 0.35, 0.2, d * 0.5), Color = Color3.fromRGB(95, 143, 62), Material = Enum.Material.Grass, CFrame = cf * CFrame.new(-len * 0.15, d / 2, 0) })
				moss.Parent = m
				m.PrimaryPart = body
				m.Parent = VFX.Folder()
				table.insert(logs, { Model = m, Home = m:GetPivot(), Temp = true })
			end
		end
		if #logs == 0 then return end
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			for i, l in ipairs(logs) do
				if l.Model.Parent then
					-- slow drift with the current, a lazy turn, a bob on the swell
					local u = math.min(t, dur)
					local drift = along * u * (0.35 + i * 0.08) * math.max(1, s * 0.5)
					local bob = math.sin(t * 1.3 + i * 2.1) * 0.08
					local turn = CFrame.Angles(0, math.sin(t * 0.25 + i) * 0.06, math.sin(t * 0.9 + i) * 0.04)
					l.Model:PivotTo(CFrame.new(drift + Vector3.new(0, bob, 0)) * l.Home * turn)
				end
			end
			if t > dur then
				conn:Disconnect()
				for _, l in ipairs(logs) do
					if l.Temp then
						for _, p in ipairs(l.Model:GetChildren()) do
							if p:IsA("BasePart") then TweenService:Create(p, TweenInfo.new(1.2), { Transparency = 1 }):Play() end
						end
						Debris:AddItem(l.Model, 1.4)
					else
						-- home again, out of shot (the hero hold is on the croc)
						task.delay(1.5, function() if l.Model.Parent then l.Model:PivotTo(l.Home) end end)
					end
				end
			end
		end)
	end

	-- rings spreading from the eyes at the waterline as they open
	VFX.Extra.EyeRipple = function(model: Model, arg, s)
		local k = ((arg and arg.Scale) or 1) * math.max(0.6, s * 0.5)
		for _, n in ipairs({ "VFX_RightEye", "VFX_LeftEye" }) do
			local a = att(model, n)
			if a then
				local y = surfaceY(model, a.WorldPosition.Y - 0.3)
				local p = Vector3.new(a.WorldPosition.X, y + 0.05, a.WorldPosition.Z)
				for j = 0, 2 do
					task.delay(j * 0.22, function() waterRing(p, 0.3 * k, (2.2 + j) * k, 0.18 * k, 1.1, 12) end)
				end
			end
		end
	end

	-- bubbles boiling up in front of the snout
	VFX.Extra.Bubbles = function(model: Model, arg, s)
		local dur = (arg and arg.Dur) or 0.8
		local head = att(model, "VFX_Head")
		local mouth = att(model, "VFX_Mouth")
		if not head then return end
		local t0 = os.clock()
		task.spawn(function()
			while os.clock() - t0 < dur and model.Parent do
				local a = head.WorldPosition
				local b = mouth and mouth.WorldPosition or a
				local at = a:Lerp(b, math.random()) + Vector3.new((math.random() - 0.5) * 1.6 * s, 0, (math.random() - 0.5) * 1.6 * s)
				local y = surfaceY(model, a.Y)
				local d = (0.25 + math.random() * 0.35) * math.max(0.7, s * 0.6)
				local bub = anchored({ Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), Color = FOAM, Material = Enum.Material.Glass, Transparency = 0.25, CFrame = CFrame.new(at.X, y - 0.1, at.Z) })
				TweenService:Create(bub, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = bub.Size * 1.6, Transparency = 1, CFrame = bub.CFrame + Vector3.new(0, 0.3, 0) }):Play()
				Debris:AddItem(bub, 0.4)
				if math.random() < 0.3 then waterRing(Vector3.new(at.X, y + 0.04, at.Z), 0.2, 1.2 * s * 0.6, 0.12, 0.6, 8) end
				task.wait(0.05)
			end
		end)
	end

	-- a sheet of water flung at the lens, and drops that run down the glass
	VFX.Extra.LensSpray = function(model: Model, arg, s)
		local k = (arg and arg.Scale) or 1
		local cam = Workspace.CurrentCamera
		local mouth = att(model, "VFX_Mouth") or att(model, "VFX_Head")
		if not (cam and mouth) then return end
		local from = mouth.WorldPosition
		local to = cam.CFrame.Position
		local dir = (to - from)
		if dir.Magnitude < 0.1 then return end
		for _ = 1, math.floor(18 * k) do
			local p = Instance.new("Part")
			local sz = (0.18 + math.random() * 0.3) * math.max(0.7, s * 0.5)
			p.Size = Vector3.new(sz, sz, sz)
			p.Color = WATER[math.random(1, #WATER)]
			p.Material = Enum.Material.Glass
			p.Transparency = 0.2
			p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
			p.CFrame = CFrame.new(from + Vector3.new((math.random() - 0.5) * 2, math.random(), (math.random() - 0.5) * 2) * s * 0.5)
			p.Parent = VFX.Folder()
			local aim = (to + Vector3.new((math.random() - 0.5) * 6, (math.random() - 0.3) * 4, (math.random() - 0.5) * 6)) - p.Position
			local t = 0.45 + math.random() * 0.25
			-- ballistic: reach the lens area in ~t seconds against gravity
			local g = Workspace.Gravity
			p.AssemblyLinearVelocity = aim / t + Vector3.new(0, 0.5 * g * t, 0)
			Debris:AddItem(p, 1.2)
		end
		-- drops on the glass
		local plr = Players.LocalPlayer
		local pg = plr and plr:FindFirstChildOfClass("PlayerGui")
		if not pg then return end
		local gui = Instance.new("ScreenGui")
		gui.Name = "SarcoLensDrops"
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 50
		gui.ResetOnSpawn = false
		gui.Parent = pg
		task.delay(0.42, function()
			for _ = 1, math.floor(14 * k) do
				local f = Instance.new("Frame")
				local w = 0.02 + math.random() * 0.05
				f.Size = UDim2.fromScale(w, w * 1.7)
				f.Position = UDim2.fromScale(math.random(), math.random() * 0.8)
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.BackgroundColor3 = Color3.fromRGB(200, 232, 255)
				f.BackgroundTransparency = 0.55 + math.random() * 0.2
				f.BorderSizePixel = 0
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0.5, 0)
				c.Parent = f
				local st = Instance.new("UIStroke")
				st.Color = Color3.new(1, 1, 1)
				st.Transparency = 0.6
				st.Thickness = 1.5
				st.Parent = f
				f.Parent = gui
				local life = 1.0 + math.random() * 0.8
				TweenService:Create(f, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = f.Position + UDim2.fromScale((math.random() - 0.5) * 0.02, 0.15 + math.random() * 0.2), BackgroundTransparency = 1,
				}):Play()
				TweenService:Create(st, TweenInfo.new(life), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(gui, 2.6)
	end

	-- the death roll: spray off the spinning body and rings around its long axis
	VFX.Extra.RollSpray = function(model: Model, arg, s)
		local dur = (arg and arg.Dur) or 1.5
		local chest = att(model, "VFX_Chest")
		local tail = att(model, "VFX_TailTip")
		local head = att(model, "VFX_Head")
		if not chest then return end
		local t0 = os.clock()
		local lastRing = 0
		task.spawn(function()
			while os.clock() - t0 < dur and model.Parent do
				local c = chest.WorldPosition
				local a = head and head.WorldPosition or c
				local b = tail and tail.WorldPosition or c
				local y = surfaceY(model, c.Y)
				local along = (a - b)
				local axis = along.Magnitude > 0.1 and along.Unit or model:GetPivot().LookVector
				local p = b:Lerp(a, math.random())
				VFX.Cubes(Vector3.new(p.X, y + 0.2, p.Z), 4, WATER, 0.28 * s * 0.6, 14 + s * 3, 0.7)
				if os.clock() - lastRing > 0.32 then
					lastRing = os.clock()
					VFX.BlockRing(CFrame.lookAt(c, c + axis), { Count = 16, R0 = 1.2 * s * 0.6, R1 = 4.5 * s * 0.6, Block = 0.4 * s * 0.5, Color = FOAM, Transparency = 0.3, Duration = 0.5 })
					VFX.WaterSplash(Vector3.new(c.X, y, c.Z), 0.9 * math.max(0.8, s * 0.6))
				end
				task.wait(0.07)
			end
		end)
	end

	-- a wet hiss: mist + spittle from the open jaws
	VFX.Extra.Hiss = function(model: Model, arg, s)
		local k = ((arg and arg.Scale) or 1) * math.max(0.7, s * 0.6)
		local mouth = att(model, "VFX_Mouth")
		local head = att(model, "VFX_Head")
		if not mouth then return end
		local dir = head and (mouth.WorldPosition - head.WorldPosition) or mouth.WorldCFrame.LookVector
		if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, -1) end
		local cf = CFrame.lookAt(head and head.WorldPosition:Lerp(mouth.WorldPosition, 0.4) or mouth.WorldPosition, mouth.WorldPosition + dir)
		VFX.Burst(cf, math.floor(16 * k), {
			Speed = NumberRange.new(5 * k, 11 * k), Spread = Vector2.new(28, 28), Direction = Enum.NormalId.Front,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * k), NumberSequenceKeypoint.new(1, 2.4 * k) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
			Color = Color3.fromRGB(235, 242, 245), Lifetime = NumberRange.new(0.5, 0.9), Acceleration = Vector3.new(0, 1.5, 0), Drag = 4,
		})
		VFX.Spittle(cf, k)
		VFX.Shake(0.25 * k, 0.7, mouth.WorldPosition, 50 * k)
	end

	-- the bellow: water drops jump off its back like a drumskin
	VFX.Extra.WaterDance = function(model: Model, arg, s)
		local dur = (arg and arg.Dur) or 1.2
		local spots = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name == "Osteoderm" or d.Name == "NuchalPlate") then table.insert(spots, d) end
		end
		if #spots == 0 then return end
		local t0 = os.clock()
		task.spawn(function()
			while os.clock() - t0 < dur and model.Parent do
				for _ = 1, 3 do
					local p = spots[math.random(1, #spots)]
					local top = p.Position + p.CFrame.UpVector * (p.Size.Y / 2 + 0.1)
					local drop = Instance.new("Part")
					local sz = (0.14 + math.random() * 0.12) * math.max(0.7, s * 0.5)
					drop.Size = Vector3.new(sz, sz * 1.4, sz)
					drop.Color = WATER[math.random(1, #WATER)]
					drop.Material = Enum.Material.Glass
					drop.Transparency = 0.15
					drop.CanCollide, drop.CanQuery, drop.CanTouch, drop.CastShadow = false, false, false, false
					drop.CFrame = CFrame.new(top)
					drop.Parent = VFX.Folder()
					drop.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 2, 10 + math.random() * 8, (math.random() - 0.5) * 2) * math.sqrt(math.max(0.6, s * 0.5))
					Debris:AddItem(drop, 0.8)
				end
				task.wait(0.04)
			end
		end)
	end

	-- the tail sweep throws a wall of water (a wave of dust on dry land)
	VFX.Extra.TailWave = function(model: Model, arg, s)
		local k = ((arg and arg.Scale) or 1) * math.max(0.7, s * 0.6)
		local tip = att(model, "VFX_TailTip")
		if not tip then return end
		local pivot = model:GetPivot()
		local water = VFX.waterSurface(model)
		local foot = att(model, "VFX_RightFoot")
		local gy = water or (foot and foot.WorldPosition.Y) or pivot.Position.Y
		local p = Vector3.new(tip.WorldPosition.X, gy, tip.WorldPosition.Z)
		local out = p - Vector3.new(pivot.Position.X, gy, pivot.Position.Z)
		out = out.Magnitude > 0.1 and out.Unit or pivot.RightVector
		if water then
			for j = 0, 3 do
				task.delay(j * 0.06, function()
					VFX.WaterSplash(p + out * j * 2.2 * k + pivot.LookVector * (j - 1.5) * 1.6 * k, 1.1 * k)
				end)
			end
			waterRing(p, 1 * k, 9 * k, 0.5 * k, 0.8, 18)
		else
			VFX.DustWave(p, out, k)
			VFX.FootstepDust(p, 1.4 * k)
		end
	end
end
