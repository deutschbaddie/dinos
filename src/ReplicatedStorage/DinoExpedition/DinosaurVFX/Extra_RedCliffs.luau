--[[
	Red Cliffs species effects (Oviraptor, Protoceratops, Gallimimus, Therizinosaurus), registered as DinosaurVFX.Extra
	events. Every effect also works out in the era (no stage props): a missing prop gets a temporary stand-in.

	EggSnatch { Prop, Hand, Hold }   an egg (the stage nest's, or a fresh one) is welded into the hand bone for Hold s
	CasqueFlash (dur)                the Oviraptor's casque blazes neon orange-red
	FrillFlash (dur)                 the Protoceratops' frill rim and eye-spots flush hot pink
	SandBreath { Scale }             the dune it hides under breathes: a sigh of sand off the top
	SandBurst { Scale }              it erupts out of the sand: a sand-block explosion (a mound appears and blows apart
	                                 when the stage has no Dune prop)
	SandShake { Scale }              a wet-dog shake: sand sprays off its body in pulses
	FlockRush { Count, From, To, Time }  a flock of client-side runners streaks across the creature's local X lane
	ClawRake { Scale, Arm, Hook }    claws rake through branches (leaves + twigs fall), or into rock (Hook)
	ScytheSlash { Arm, Scale, Wide, Cross, AtCamera }  three glowing cream slash streaks along the claw's swing
	                                 (AtCamera: the streaks cut across the lens)
	ClawRattle { Scale }             the scythe claws clack together: sparks at both claw tips
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local SAND = { Color3.fromRGB(217, 173, 114), Color3.fromRGB(232, 194, 138), Color3.fromRGB(196, 150, 96) }
local SAND_DUST = Color3.fromRGB(226, 190, 140)
local LEAVES = { Color3.fromRGB(79, 122, 46), Color3.fromRGB(95, 143, 54), Color3.fromRGB(63, 106, 40), Color3.fromRGB(106, 154, 58) }
local TWIG = { Color3.fromRGB(94, 63, 34), Color3.fromRGB(122, 86, 51) }
local ROCK = { Color3.fromRGB(180, 80, 46), Color3.fromRGB(198, 95, 54), Color3.fromRGB(156, 65, 38) }
local CLAW = Color3.fromRGB(255, 240, 205)
local EGG = Color3.fromRGB(47, 111, 138)
local EGG_STRIPE = Color3.fromRGB(255, 106, 42)

return function(VFX)
	local function att(model: Model, name: string): Attachment?
		return VFX.findAttachment(model, name)
	end
	local function rootCF(model: Model): CFrame
		local r = model.PrimaryPart
		return r and r.CFrame or model:GetPivot()
	end
	local function groundY(model: Model): number
		local foot = att(model, "VFX_RightFoot")
		if foot then return foot.WorldPosition.Y end
		local cf, size = model:GetBoundingBox()
		return cf.Position.Y - size.Y / 2
	end
	local function part(props): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in pairs(props) do (p :: any)[k] = v end
		p.Parent = VFX.Folder()
		return p
	end
	local function fadeOut(p: BasePart, after: number, dur: number)
		task.delay(after, function()
			if p.Parent then TweenService:Create(p, TweenInfo.new(dur), { Transparency = 1 }):Play() end
		end)
		Debris:AddItem(p, after + dur + 0.1)
	end
	-- temporarily recolour (and light up) the named parts of a creature, then put them back
	local function flush(model: Model, names: { [string]: Color3 }, dur: number)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and names[d.Name] then
				local orig, mat = d.Color, d.Material
				d.Material = Enum.Material.Neon
				TweenService:Create(d, TweenInfo.new(0.25), { Color = names[d.Name] }):Play()
				task.delay(dur, function()
					if d.Parent then
						d.Material = mat
						TweenService:Create(d, TweenInfo.new(0.6), { Color = orig }):Play()
					end
				end)
			end
		end
	end

	----------------------------------------------------------------------------------------------- Oviraptor
	VFX.Extra.EggSnatch = function(model: Model, arg, s: number)
		arg = arg or {}
		local handName = arg.Hand or "LeftForearm"
		local bone = model:FindFirstChild(handName)
		if not (bone and bone:IsA("BasePart")) then return end
		local side = string.sub(handName, 1, 4) == "Left" and "Left" or "Right"
		local claw = att(model, `VFX_{side}Claw`)
		local at = claw and claw.WorldCFrame or bone.CFrame
		local hold = arg.Hold or 4
		-- the stage nest's egg (hidden while it's held) or a fresh one
		local hidden: { BasePart } = {}
		local prop = arg.Prop and VFX.findProp(model, arg.Prop)
		local source: BasePart? = nil
		if prop then
			for _, d in ipairs(prop:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "NestEgg" and d.Transparency < 1 then
					source = d
					break
				end
			end
		end
		local egg: BasePart
		if source then
			egg = source:Clone()
			for _, c in ipairs(egg:GetChildren()) do if not c:IsA("SpecialMesh") then c:Destroy() end end
			for _, d in ipairs((prop :: Model):GetDescendants()) do
				if d:IsA("BasePart") and (d == source or (d.Name == "EggStripe" and (d.Position - source.Position).Magnitude < 0.4)) then
					d.Transparency = 1
					table.insert(hidden, d)
				end
			end
		else
			egg = Instance.new("Part")
			egg.Size = Vector3.new(0.36, 0.5, 0.36) * s
			egg.Color = EGG
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = egg
		end
		egg.Name = "StolenEgg"
		egg.Anchored = false
		egg.CanCollide = false
		egg.CanQuery = false
		egg.CanTouch = false
		egg.Massless = true
		egg.CFrame = at * CFrame.new(0, 0.12 * s, -0.05 * s) * CFrame.Angles(0, 0, math.rad(25))
		egg.Parent = VFX.Folder()
		local stripe = part({ Name = "StolenEggStripe", Size = Vector3.new(egg.Size.X * 0.86, 0.06 * s, egg.Size.Z * 1.04), Color = EGG_STRIPE, CFrame = egg.CFrame })
		stripe.Anchored = false
		stripe.Massless = true
		for _, p in ipairs({ egg, stripe }) do
			local w = Instance.new("WeldConstraint")
			w.Part0 = bone
			w.Part1 = p
			w.Parent = p
		end
		VFX.Cubes(at.Position, 4, { EGG, EGG_STRIPE, Color3.new(1, 1, 1) }, 0.12 * s, 5, 0.5)
		task.delay(hold, function()
			for _, p in ipairs({ egg, stripe }) do
				if p.Parent then
					TweenService:Create(p, TweenInfo.new(0.35), { Transparency = 1 }):Play()
					Debris:AddItem(p, 0.4)
				end
			end
			for _, d in ipairs(hidden) do
				if d.Parent then TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 0 }):Play() end
			end
		end)
	end

	VFX.Extra.CasqueFlash = function(model: Model, arg, s: number)
		local dur = type(arg) == "number" and arg or 1.5
		flush(model, { Casque = Color3.fromRGB(255, 110, 40), CasqueBlaze = Color3.fromRGB(255, 220, 120) }, dur)
		local crest = att(model, "VFX_Crest")
		if crest then
			VFX.BlockRing(crest.WorldCFrame * CFrame.Angles(0, math.pi / 2, 0), { Count = 12, R0 = 0.3 * s, R1 = 2.2 * s, Block = 0.18 * s, Color = Color3.fromRGB(255, 150, 60), Duration = 0.45 })
		end
	end

	----------------------------------------------------------------------------------------------- Protoceratops
	VFX.Extra.FrillFlash = function(model: Model, arg, s: number)
		local dur = type(arg) == "number" and arg or 1.5
		flush(model, {
			FrillRim = Color3.fromRGB(255, 90, 140), FrillScallop = Color3.fromRGB(255, 120, 170),
			FrillSpotRing = Color3.fromRGB(255, 240, 200), FrillSpot = Color3.fromRGB(120, 30, 60),
		}, dur)
		local crest = att(model, "VFX_Crest")
		if crest then
			local head = att(model, "VFX_Head")
			local dir = head and (head.WorldPosition - crest.WorldPosition) or crest.WorldCFrame.LookVector
			VFX.BlockRing(CFrame.lookAt(crest.WorldPosition, crest.WorldPosition + dir), { Count = 16, R0 = 0.5 * s, R1 = 3.2 * s, Travel = 2 * s, Block = 0.22 * s, Color = Color3.fromRGB(255, 120, 170), Duration = 0.55 })
		end
	end

	VFX.Extra.SandBreath = function(model: Model, arg, s: number)
		local k = ((arg and arg.Scale) or 0.7) * s
		local head = att(model, "VFX_Crest") or att(model, "VFX_Head")
		local gy = groundY(model)
		local base = rootCF(model).Position
		local at = head and Vector3.new(head.WorldPosition.X, math.max(head.WorldPosition.Y, gy) + 0.3, head.WorldPosition.Z) or base
		VFX.Burst(CFrame.new(at), math.floor(5 + k * 4), {
			Speed = NumberRange.new(1.5 * k, 3.5 * k), Spread = Vector2.new(60, 60), Color = SAND_DUST,
			Size = NumberSequence.new(0.5 * k, 1.6 * k), Transparency = NumberSequence.new(0.45, 1), Acceleration = Vector3.new(0, -1, 0),
		})
		VFX.Cubes(at, 4, SAND, 0.14 * k, 4, 0.6)
		-- the stage dune heaves once
		local dune = VFX.findProp(model, "Dune")
		if dune then
			local home = dune:GetPivot()
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < 0.7 and dune.Parent do
					local u = (os.clock() - t0) / 0.7
					dune:PivotTo(home * CFrame.new(0, math.sin(u * math.pi) * 0.18 * k, 0))
					RunService.Heartbeat:Wait()
				end
				if dune.Parent then dune:PivotTo(home) end
			end)
		end
	end

	VFX.Extra.SandBurst = function(model: Model, arg, s: number)
		local k = ((arg and arg.Scale) or 1) * s
		local gy = groundY(model)
		local c = rootCF(model).Position
		local at = Vector3.new(c.X, gy + 0.3, c.Z)
		-- no stage dune: a stand-in mound appears for a frame and blows apart
		if not VFX.findProp(model, "Dune") then
			local _, size = model:GetBoundingBox()
			for i = 1, 9 do
				local a = (i / 9) * math.pi * 2
				local r = math.max(size.X, size.Z) * 0.3
				local p = part({
					Name = "SandClod", Size = Vector3.new(1.2, 0.7, 1.2) * k * (0.7 + math.random() * 0.6), Color = SAND[(i % 3) + 1],
					Material = Enum.Material.Sand, CFrame = CFrame.new(at + Vector3.new(math.cos(a) * r, 0.1, math.sin(a) * r)) * CFrame.Angles(0, a, 0),
				})
				p.Anchored = false
				p.CanCollide = true
				p.AssemblyLinearVelocity = Vector3.new(math.cos(a) * 14, 18 + math.random() * 10, math.sin(a) * 14) * math.sqrt(k)
				p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 10
				fadeOut(p, 1.6, 0.6)
			end
		end
		VFX.Cubes(at, math.floor(22 * k), SAND, 0.4 * k, 22 * k, 1.4)
		VFX.BlockRing(CFrame.new(at) * CFrame.Angles(math.pi / 2, 0, 0), { Count = 20, R0 = 1 * k, R1 = 9 * k, Block = 0.55 * k, Color = SAND_DUST, Transparency = 0.25, Duration = 0.7 })
		VFX.Burst(CFrame.new(at), math.floor(18 + 8 * k), {
			Speed = NumberRange.new(6 * k, 14 * k), Spread = Vector2.new(70, 70), Color = SAND_DUST,
			Size = NumberSequence.new(1.2 * k, 4.5 * k), Lifetime = NumberRange.new(0.8, 1.6), Acceleration = Vector3.new(0, -3, 0),
		})
		VFX.Shake(0.5 * k, 0.4, at, 50)
	end

	VFX.Extra.SandShake = function(model: Model, arg, s: number)
		local k = ((arg and arg.Scale) or 0.8) * s
		local cf = rootCF(model)
		for pulse = 0, 3 do
			task.delay(pulse * 0.24, function()
				if not model.Parent then return end
				local side = (pulse % 2 == 0) and 1 or -1
				for _, name in ipairs({ "VFX_Chest", "VFX_Head", "VFX_TailTip" }) do
					local a = att(model, name)
					if a then
						VFX.Burst(CFrame.lookAt(a.WorldPosition, a.WorldPosition + cf.RightVector * side + Vector3.new(0, 0.4, 0)), math.floor(5 + 3 * k), {
							Direction = Enum.NormalId.Front, Spread = Vector2.new(35, 35), Speed = NumberRange.new(5 * k, 10 * k), Color = SAND_DUST,
							Size = NumberSequence.new(0.4 * k, 1.6 * k), Lifetime = NumberRange.new(0.5, 0.9), Acceleration = Vector3.new(0, -8, 0),
						})
						VFX.Cubes(a.WorldPosition, 3, SAND, 0.12 * k, 9 * k, 0.6)
					end
				end
			end)
		end
	end

	----------------------------------------------------------------------------------------------- Gallimimus
	VFX.Extra.FlockRush = function(model: Model, arg, s: number)
		arg = arg or {}
		local root = model.PrimaryPart
		if not root then return end
		local ok, Animations = pcall(require, script.Parent.Parent:WaitForChild("DinosaurAnimations"))
		if not ok then return end
		local base = root.CFrame
		local lift = root.Position.Y - groundY(model)
		local gy = groundY(model)
		local count = arg.Count or 5
		local from, to, dur = (arg.From or -28) * s, (arg.To or 30) * s, arg.Time or 2.2
		-- lanes (studs along the creature's Z): one right past the lens, the rest behind the leader
		local lanes = { -3.2, 3.5, 7.5, -1.4, 11, 5.5, 14, 1.8 }
		for i = 1, count do
			task.delay((i - 1) * 0.11 + (i == 1 and 0 or 0.05), function()
				if not model.Parent then return end
				local runner = model:Clone()
				runner.Name = "FlockRunner"
				CollectionService:RemoveTag(runner, "DinoExpeditionDinosaur")
				for _, tag in ipairs(CollectionService:GetTags(runner)) do CollectionService:RemoveTag(runner, tag) end
				runner:SetAttribute("FlockRunner", true)
				for _, d in ipairs(runner:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CanCollide = false
						d.CanQuery = false
						d.CanTouch = false
					elseif d:IsA("Script") or d:IsA("LocalScript") then
						d:Destroy()
					end
				end
				local rr = runner.PrimaryPart :: BasePart
				rr.Anchored = true
				runner.Parent = VFX.Folder()
				local anim = Animations.get(runner)
				if anim then
					anim.GaitPhase = math.random()
					anim:SetLocomotion("Run", 0.05)
				end
				local lane = (lanes[((i - 1) % #lanes) + 1]) * s
				local startX = from - (i - 1) * 2.5 * s
				local t0 = os.clock()
				local lastDust = 0
				local conn
				conn = RunService.Heartbeat:Connect(function()
					local u = (os.clock() - t0) / dur
					if u >= 1 or not runner.Parent then
						conn:Disconnect()
						runner:Destroy()
						return
					end
					local x = startX + (to - startX) * u
					local p = base:PointToWorldSpace(Vector3.new(x, 0, lane))
					p = Vector3.new(p.X, gy + lift, p.Z)
					rr.CFrame = CFrame.lookAt(p, p + base.RightVector)
					if os.clock() - lastDust > 0.18 then
						lastDust = os.clock()
						VFX.Burst(CFrame.new(p.X, gy + 0.2, p.Z), 3, { Speed = NumberRange.new(2, 5), Color = SAND_DUST, Size = NumberSequence.new(1 * s, 3 * s), Transparency = NumberSequence.new(0.5, 1) })
					end
				end)
			end)
		end
	end

	----------------------------------------------------------------------------------------------- Therizinosaurus
	local function clawTips(model: Model, which: string?): { Attachment }
		local out = {}
		for _, side in ipairs({ "Right", "Left" }) do
			if which == nil or which == "Both" or which == side then
				local a = att(model, `VFX_{side}Claw`)
				if a then table.insert(out, a) end
			end
		end
		return out
	end

	VFX.Extra.ClawRake = function(model: Model, arg, s: number)
		arg = arg or {}
		local k = (arg.Scale or 1) * s
		for _, a in ipairs(clawTips(model, arg.Arm or "Right")) do
			local p = a.WorldPosition
			if arg.Hook then
				VFX.Cubes(p, math.floor(10 * k), ROCK, 0.3 * k, 12, 1.2)
				VFX.Debris(p, 1.2 * k, ROCK[1])
			else
				VFX.FallingLeaves(p - Vector3.new(0, 6 * k, 0), 4 * k, math.floor(14 * k), 4 * k)
				VFX.Cubes(p, math.floor(8 * k), LEAVES, 0.35 * k, 10, 1.4)
				VFX.Cubes(p, math.floor(4 * k), TWIG, 0.3 * k, 8, 1.4)
				VFX.FoliageBurst(p, 0.9 * k)
			end
		end
	end

	VFX.Extra.ClawRattle = function(model: Model, arg, s: number)
		local k = ((arg and arg.Scale) or 1) * s
		for _, a in ipairs(clawTips(model, "Both")) do
			VFX.Cubes(a.WorldPosition, 5, { CLAW, Color3.new(1, 1, 1) }, 0.12 * k, 8, 0.5)
			VFX.BlockRing(a.WorldCFrame, { Count = 8, R0 = 0.2 * k, R1 = 1.4 * k, Block = 0.14 * k, Color = CLAW, Duration = 0.3 })
		end
		VFX.Shake(0.12 * k, 0.25, rootCF(model).Position, 40 * k)
	end

	-- three glowing streaks: thin neon bars laid along the claw's sweep, flaring and fading
	local function streaks(cf: CFrame, len: number, k: number, spread: number)
		for i = -1, 1 do
			local bar = part({
				Name = "ScytheStreak", Material = Enum.Material.Neon, Color = CLAW, Transparency = 0.1,
				Size = Vector3.new(0.18 * k, 0.18 * k, len * 0.3), CFrame = cf * CFrame.new(i * spread, 0, 0),
			})
			TweenService:Create(bar, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3 * k, 0.12 * k, len) }):Play()
			TweenService:Create(bar, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.12), { Transparency = 1, Size = Vector3.new(0.05, 0.05, len * 1.1) }):Play()
			Debris:AddItem(bar, 0.6)
		end
	end

	VFX.Extra.ScytheSlash = function(model: Model, arg, s: number)
		arg = arg or {}
		local k = (arg.Scale or 1) * s
		local root = rootCF(model)
		local tips = clawTips(model, arg.Arm or "Right")
		for n, a in ipairs(tips) do
			local p = a.WorldPosition
			local side = a.Name == "VFX_LeftClaw" and -1 or 1
			-- the swing runs high-outside to low-across
			local dir = (root.RightVector * -side * 0.8 + Vector3.new(0, -1, 0) + root.LookVector * 0.5).Unit
			if arg.Wide then dir = (root.RightVector * -side + root.LookVector * 0.3).Unit end
			local center = p - dir * 2 * k
			local cf = CFrame.lookAt(center, center + dir)
			if arg.AtCamera and n == 1 then
				local cam = Workspace.CurrentCamera
				if cam then
					-- cut right across the lens: the streaks hang between the claw and the camera, diagonal in view
					local toCam = cam.CFrame.Position - p
					local mid = p + toCam * 0.55
					local diag = (cam.CFrame.RightVector - cam.CFrame.UpVector).Unit
					streaks(CFrame.lookAt(mid, mid + diag) * CFrame.Angles(0, 0, math.pi / 2), 9 * k, k * 0.7, 0.5 * k)
				end
			end
			streaks(cf, 7 * k, k, 0.45 * k)
			if arg.Cross then
				local d2 = (root.RightVector * side * 0.8 + Vector3.new(0, -1, 0) + root.LookVector * 0.5).Unit
				streaks(CFrame.lookAt(center, center + d2), 7 * k, k, 0.45 * k)
			end
			VFX.Cubes(p, 6, { CLAW, Color3.fromRGB(255, 220, 150) }, 0.15 * k, 12, 0.5)
		end
		VFX.Shake(0.4 * k, 0.35, root.Position, 60 * k)
	end
end
