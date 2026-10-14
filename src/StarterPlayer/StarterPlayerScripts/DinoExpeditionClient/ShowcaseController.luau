--[[
	ShowcaseController — runs showcase actions on this client.
	Actions: Idle, Walk, Run, Roar, Attack, Chase, Signature, CycleAnimation, Reset, or any profile action name.
	`isLocal` = this player triggered it, so they also get the camera cinematic; everyone else just
	sees the creature perform.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local DinosaurAnimations = require(Shared:WaitForChild("DinosaurAnimations"))
local DinosaurCinematics = require(Shared:WaitForChild("DinosaurCinematics"))
local DinosaurVFX = require(Shared:WaitForChild("DinosaurVFX"))

local Showcase = {}
local patrols = {} -- [Model] = state
local cycleIndex = {} -- [Model] = number

local LABELS = {
	Walk = "WALK", Run = "RUN", Idle = "IDLE", Roar = "ROAR", Attack = "ATTACK", Chase = "CHASE", Stunned = "STUNNED",
	LookAround = "LOOK AROUND", Sniff = "SNIFF", Jump = "JUMP", Stumble = "STUMBLE", Signature = "SIGNATURE", Reset = "RESET",
}

local function toast(model: Model, text: string)
	local root = model.PrimaryPart
	if not root then return end
	local old = root:FindFirstChild("ShowcaseToast")
	if old then old:Destroy() end
	local _, size = model:GetBoundingBox()
	local g = Instance.new("BillboardGui")
	g.Name = "ShowcaseToast"
	g.Size = UDim2.fromOffset(240, 48)
	g.StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.55 + 1, 0)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.FontFace = Font.new("rbxasset://fonts/families/PressStart2P.json")
	l.TextColor3 = Color3.fromRGB(255, 226, 120)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170), Color3.fromRGB(255, 160, 40))
	grad.Parent = l
	local s = Instance.new("UIStroke")
	s.LineJoinMode = Enum.LineJoinMode.Miter
	s.Thickness = 3
	s.Parent = l
	l.Parent = g
	g.Parent = root
	TweenService:Create(g, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = g.StudsOffsetWorldSpace + Vector3.new(0, 2, 0) }):Play()
	task.delay(1.0, function()
		if l.Parent then
			TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			TweenService:Create(s, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
	end)
	task.delay(1.7, function() g:Destroy() end)
end

-- Locomotion demo -------------------------------------------------------------------------------
-- Walkers go out along their facing direction, turn around on the spot, come back and turn again,
-- following the ground (so they step off their platform naturally). Ground speed is derived from the
-- stride (hip height x stride angle x cadence) so the feet don't skate. Swimmers circle their pool.
local patrolConn: RBXScriptConnection? = nil
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true -- only solid ground: ignore label anchors, foliage, VFX, prompts

-- ground height under `pos`, cast down from hip height so overhead geometry is never hit
local function groundY(model: Model, pos: Vector3, fromY: number, fallback: number): number
	local fx = workspace:FindFirstChild("DinoVFX_Client")
	rayParams.FilterDescendantsInstances = fx and { model, fx } or { model }
	local hit = workspace:Raycast(Vector3.new(pos.X, fromY, pos.Z), Vector3.new(0, -60, 0), rayParams)
	return hit and hit.Position.Y or fallback
end

local function strideSpeed(anim, mode: string): number
	local G = anim.Profile.Gait
	local P = G[mode]
	if G.Type == "Swim" then return P.Speed or 8 end
	local hip = (anim.Model:GetAttribute("HipHeight") or 3) * anim.AnimScale
	local perCycle = (G.Type == "Quadruped" and 2 or 4) * hip * math.sin(P.Stride) * (G.Type == "Quadruped" and 1.6 or 1)
	return perCycle * P.Freq * 0.92
end

local function ensurePatrolLoop()
	if patrolConn then return end
	patrolConn = RunService.Heartbeat:Connect(function(dt)
		for model, st in pairs(patrols) do
			local root = model.PrimaryPart
			if not root or not model.Parent then
				patrols[model] = nil
				continue
			end
			if st.Returning then
				st.T += dt / 0.7
				local a = math.clamp(st.T, 0, 1)
				root.CFrame = st.From:Lerp(st.Home, 1 - (1 - a) ^ 3)
				if a >= 1 then patrols[model] = nil end
				continue
			end
			local home = st.Home
			if st.Swim then
				st.Theta += (st.Speed / st.Radius) * dt
				local rot = CFrame.fromAxisAngle(Vector3.yAxis, -st.Theta)
				local center = home.Position + home.RightVector * st.Radius
				root.CFrame = CFrame.new(center + rot:VectorToWorldSpace(home.Position - center)) * rot * home.Rotation
				continue
			end
			if st.Turning then
				-- turn on the spot while the legs keep stepping
				local turnRate = math.pi / st.TurnTime
				st.Yaw += turnRate * dt
				st.TurnLeft -= turnRate * dt
				if st.TurnLeft <= 0 then
					st.Yaw = st.TargetYaw
					st.Turning = false
					st.Dir = -st.Dir
				end
			else
				st.S += st.Dir * st.Speed * dt
				if (st.Dir > 0 and st.S >= st.Distance) or (st.Dir < 0 and st.S <= 0) then
					st.S = math.clamp(st.S, 0, st.Distance)
					st.Turning = true
					st.TurnLeft = math.pi
					st.TargetYaw = st.Yaw + math.pi
				end
			end
			local pos = home.Position + home.LookVector * st.S
			local target = groundY(model, pos, home.Y, st.HomeGround) + st.RootHeight
			st.Y = st.Y + (target - st.Y) * (1 - math.exp(-dt * 6))
			root.CFrame = CFrame.new(pos.X, st.Y, pos.Z) * CFrame.fromAxisAngle(Vector3.yAxis, st.Yaw) * home.Rotation
		end
	end)
end

function Showcase.StartPatrol(model: Model, mode: string)
	local anim = DinosaurAnimations.get(model)
	if not anim or not model.PrimaryPart then return end
	anim:StopActions(0.2)
	anim:SetLocomotion(mode, 0.4)
	local speed = strideSpeed(anim, mode)
	local st = patrols[model]
	if st and not st.Returning then
		st.Speed = speed
		return
	end
	local home = anim.HomeCFrame
	local _, size = model:GetBoundingBox()
	local length = math.max(size.X, size.Z)
	local profile = anim.Profile
	local hg = groundY(model, home.Position, home.Y, home.Y - size.Y / 2)
	patrols[model] = {
		Home = home, S = 0, Dir = 1, Yaw = 0, Speed = speed, Y = home.Y,
		Distance = profile.PatrolDistance and profile.PatrolDistance * anim.AnimScale or math.clamp(length * 1.1, 6, 34),
		TurnTime = math.clamp(length / 5, 1.2, 3.5),
		HomeGround = hg, RootHeight = home.Y - hg,
		Swim = profile.Gait.Type == "Swim", Theta = 0, Radius = profile.PatrolRadius or math.clamp(length * 0.35, 4, 14),
	}
	ensurePatrolLoop()
end

function Showcase.StopPatrol(model: Model, snap: boolean?)
	local st = patrols[model]
	local anim = DinosaurAnimations.find(model)
	if anim then anim:SetLocomotion("Idle", 0.5) end
	if not st or not model.PrimaryPart then return end
	if snap then
		model.PrimaryPart.CFrame = st.Home
		patrols[model] = nil
	elseif not st.Returning then
		st.Returning = true
		st.From = model.PrimaryPart.CFrame
		st.T = 0
	end
end

function Showcase.Reset(model: Model)
	if DinosaurCinematics.CurrentModel() == model then DinosaurCinematics.Stop() end
	Showcase.StopPatrol(model, true)
	local anim = DinosaurAnimations.find(model)
	if anim then anim:Reset() end
	DinosaurVFX.ResetEnvironment(model)
	cycleIndex[model] = nil
end

local function playAction(model: Model, anim, name: string, cine: ((Model) -> any)?, isLocal: boolean)
	Showcase.StopPatrol(model, true)
	-- root-motion actions (e.g. the Triceratops charge) end away from home; walk back afterwards
	local function settle()
		if anim.Displaced then task.delay(0.8, function() if anim.Displaced then anim:ReturnHome(1.6) end end) end
	end
	if isLocal and cine then
		local handle = cine(model)
		if handle then handle.Finished:Connect(settle) end
	else
		local track = anim:Play(name)
		if track then track.Finished:Connect(function() task.delay(1.5, settle) end) end
	end
end

function Showcase.Perform(model: Model, action: string, isLocal: boolean)
	local anim = DinosaurAnimations.get(model)
	if not anim then return end
	local profile = anim.Profile
	if action == "CycleAnimation" then
		local order = profile.CycleOrder or { "Walk", "Run", "Roar" }
		local i = (cycleIndex[model] or 0) % (#order + 1) + 1
		cycleIndex[model] = i
		action = order[i] or "Idle"
	end
	toast(model, LABELS[action] or string.upper(action))
	if action == "Idle" then
		Showcase.StopPatrol(model)
		anim:StopActions(0.3)
	elseif action == "Walk" or action == "Run" then
		Showcase.StartPatrol(model, action)
	elseif action == "Reset" then
		Showcase.Reset(model)
	elseif action == "Roar" then
		playAction(model, anim, "Roar", DinosaurCinematics.PlayRoar, isLocal)
	elseif action == "Attack" then
		playAction(model, anim, "Attack", DinosaurCinematics.PlayAttack, isLocal)
	elseif action == "Chase" then
		playAction(model, anim, profile.Chase or "Chase", DinosaurCinematics.PlayChase, isLocal)
	elseif action == "Signature" then
		playAction(model, anim, profile.Intro or profile.Signature, DinosaurCinematics.PlayIntro, isLocal)
	elseif action == "Special" then
		-- species-specific extra move (profile.Special), e.g. Jump, Graze, TailSwipe
		local special = profile.Special
		if special and anim:HasAction(special) then
			Showcase.StopPatrol(model)
			anim:Play(special)
		end
	elseif anim:HasAction(action) then
		Showcase.StopPatrol(model)
		anim:Play(action)
	end
end

return Showcase
