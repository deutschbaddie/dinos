--[[
	DinosaurAnimations — procedural Motor6D animation for Dino Expedition creatures.

	These are PROCEDURAL animations (code-driven Motor6D.Transform), not published Animation assets.
	They run on the client (Transform does not replicate), so every client animates locally.
	The rigs are standard Motor6D rigs, so you can also hand-author KeyframeSequences in the
	Animation Editor later and play them through each model's AnimationController.Animator.

	Usage:
		local DinosaurAnimations = require(ReplicatedStorage.DinoExpedition.DinosaurAnimations)
		local anim = DinosaurAnimations.get(model)      -- creates (or returns) the animator
		anim:SetLocomotion("Walk")                        -- "Idle" | "Walk" | "Run"
		local track = anim:Play("Roar")                   -- one-shot action from the species profile
		track.Finished:Wait()
		anim:Reset()

	Joint convention (all bones are world-aligned at rest):
		values = { rx, ry, rz, px, py, pz }  (radians / studs, in the joint's parent frame)
		+rx raises forward-pointing segments (head, neck, jaw closes), lowers the tail, swings legs forward.
		Left-side joints mirror ry / rz (use Gaits.sym when authoring).
]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Gaits = require(script:WaitForChild("Gaits"))
local ProfilesFolder = script:WaitForChild("Profiles")

local DinosaurAnimations = {}
DinosaurAnimations.Gaits = Gaits

local Animator = {}
Animator.__index = Animator

local animators: { [Model]: any } = {}
local eventListeners: { (Model, string, any, any) -> () } = {}
local profileCache = {}
local stepConnection: RBXScriptConnection? = nil

local LOD_FULL = 260 -- studs: full-rate updates inside this camera distance
local LOD_CULL = 600 -- studs: beyond this, animation is paused

DinosaurAnimations.Ease = Gaits.Ease

-- Signal (tiny, avoids BindableEvent overhead) -----------------------------
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ _handlers = {}, _waiting = {} }, Signal) end
function Signal:Connect(fn)
	table.insert(self._handlers, fn)
	local handlers = self._handlers
	return { Disconnect = function() local i = table.find(handlers, fn) if i then table.remove(handlers, i) end end }
end
function Signal:Fire(...)
	for _, fn in ipairs(table.clone(self._handlers)) do task.spawn(fn, ...) end
	local waiting = self._waiting
	self._waiting = {}
	for _, thread in ipairs(waiting) do task.spawn(thread, ...) end
end
function Signal:Wait()
	table.insert(self._waiting, coroutine.running())
	return coroutine.yield()
end

-- Profiles -----------------------------------------------------------------
local function getProfile(species: string)
	if profileCache[species] ~= nil then return profileCache[species] end
	local mod = ProfilesFolder:FindFirstChild(species)
	local profile = mod and require(mod) or false
	if profile then
		-- compile keyframed actions into per-joint tracks once
		for name, action in pairs(profile.Actions or {}) do
			action.Name = name
			action._tracks = Gaits.compileKeys(action)
		end
	end
	profileCache[species] = profile
	return profile
end
DinosaurAnimations.getProfile = getProfile

-- Animator -----------------------------------------------------------------
function DinosaurAnimations.new(model: Model)
	if animators[model] then return animators[model] end
	local species = model:GetAttribute("Species") or model.Name
	local profile = getProfile(species)
	if not profile then
		warn(`[DinosaurAnimations] No profile for species '{species}'`)
		return nil
	end

	local self = setmetatable({}, Animator)
	self.Model = model
	self.Species = species
	self.Profile = profile
	self.Motors = {}
	self.Eyelids = {}
	self.Eyes = {}
	self.Acc = {}
	self.Time = math.random() * 50 -- desync identical species
	self.LocoWeights = { Idle = 1, Walk = 0, Run = 0 }
	self.LocoTarget = "Idle"
	self.LocoFade = 0.35
	self.GaitPhase = 0
	self.Actions = {}
	self.State = {}
	self.Paused = false
	self.Event = Signal.new()
	self._nextBlink = 1 + math.random() * 3
	self._blinkUntil = 0
	self._lastStrike = {}

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			self.Motors[d.Name] = d
			self.Acc[d.Name] = { 0, 0, 0, 0, 0, 0 }
		elseif d:IsA("BasePart") then
			if CollectionService:HasTag(d, "DinoEyelid") then table.insert(self.Eyelids, d) end
			if CollectionService:HasTag(d, "DinoEye") then table.insert(self.Eyes, d) end
		end
	end
	self.Root = model.PrimaryPart
	self.AnimScale = model:GetAttribute("AnimScale") or 1 -- juveniles share the adult profile
	self.HomeCFrame = self.Root and self.Root.CFrame

	animators[model] = self
	model.Destroying:Connect(function() self:Destroy() end)
	if not stepConnection then
		stepConnection = RunService.PreSimulation:Connect(DinosaurAnimations._stepAll)
	end
	return self
end

function DinosaurAnimations.get(model: Model)
	return animators[model] or DinosaurAnimations.new(model)
end

function DinosaurAnimations.find(model: Model)
	return animators[model]
end

-- Global event hook (VFX / camera shake). fn(model, eventName, arg, track)
function DinosaurAnimations.onEvent(fn)
	table.insert(eventListeners, fn)
end

function Animator:_fire(name, arg, track)
	self.Event:Fire(name, arg, track)
	for _, fn in ipairs(eventListeners) do task.spawn(fn, self.Model, name, arg, track) end
end

function Animator:SetLocomotion(mode: string, fade: number?)
	assert(self.LocoWeights[mode] ~= nil, `Unknown locomotion '{mode}'`)
	self.LocoTarget = mode
	self.LocoFade = fade or 0.35
end

function Animator:GetLocomotion() return self.LocoTarget end

function Animator:HasAction(name: string): boolean
	return self.Profile.Actions[name] ~= nil
end

function Animator:ListActions(): { string }
	local list = {}
	for name in pairs(self.Profile.Actions) do table.insert(list, name) end
	table.sort(list)
	return list
end

-- Play a one-shot action. opts: { Speed, Weight, Loop }
function Animator:Play(name: string, opts: any?)
	local action = self.Profile.Actions[name]
	if not action then
		warn(`[DinosaurAnimations] {self.Species} has no action '{name}'`)
		return nil
	end
	opts = opts or {}
	-- an action replaces any running action on the same layer
	for _, tr in ipairs(self.Actions) do
		if not tr.Stopping then tr:Stop(0.18) end
	end
	local track = {
		Action = action,
		Name = name,
		T = 0,
		Speed = opts.Speed or 1,
		Weight = opts.Weight or 1,
		Loop = opts.Loop or action.Loop or false,
		FadeIn = action.FadeIn or 0.18,
		FadeOut = action.FadeOut or 0.3,
		Fade = 0,
		Stopping = false,
		StopFade = 0.3,
		StopT = 0,
		EventIndex = 1,
		Finished = Signal.new(),
		Animator = self,
	}
	function track:Stop(fade: number?)
		if self.Stopping then return end
		self.Stopping = true
		self.StopFade = fade or self.FadeOut
		self.StopT = 0
	end
	table.insert(self.Actions, track)
	return track
end

function Animator:StopActions(fade: number?)
	for _, tr in ipairs(self.Actions) do tr:Stop(fade) end
end

function Animator:IsPlaying(name: string?): boolean
	for _, tr in ipairs(self.Actions) do
		if not tr.Stopping and (name == nil or tr.Name == name) then return true end
	end
	return false
end

-- Return to idle, clear actions, restore the root to where it was authored
function Animator:Reset()
	for _, tr in ipairs(self.Actions) do tr.Finished:Fire(false) end
	table.clear(self.Actions)
	self.LocoTarget = "Idle"
	self.LocoWeights = { Idle = 1, Walk = 0, Run = 0 }
	if self.Root and self.HomeCFrame then self.Root.CFrame = self.HomeCFrame end
	self.Displaced = false
	for _, m in pairs(self.Motors) do m.Transform = CFrame.identity end
	for _, lid in ipairs(self.Eyelids) do lid.Transparency = 1 end
end

-- Walk/glide back to the authored spot after root-motion actions
function Animator:ReturnHome(duration: number?)
	if not (self.Root and self.HomeCFrame) then return end
	self.Displaced = false
	local from = self.Root.CFrame
	local home = self.HomeCFrame
	local dur = duration or 1.2
	local t0 = os.clock()
	self:SetLocomotion("Walk", 0.3)
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local a = math.clamp((os.clock() - t0) / dur, 0, 1)
		if self.Root.Parent == nil then conn:Disconnect() return end
		self.Root.CFrame = from:Lerp(home, a * a * (3 - 2 * a))
		if a >= 1 then
			conn:Disconnect()
			self:SetLocomotion("Idle", 0.4)
		end
	end)
end

function Animator:Destroy()
	animators[self.Model] = nil
	for _, m in pairs(self.Motors) do
		if m.Parent then m.Transform = CFrame.identity end
	end
end

-- Core evaluation ------------------------------------------------------------
local function zeroAcc(acc)
	for _, v in pairs(acc) do
		v[1], v[2], v[3], v[4], v[5], v[6] = 0, 0, 0, 0, 0, 0
	end
end

function Animator:Add(joint: string, rx, ry, rz, px, py, pz, w)
	local v = self.Acc[joint]
	if not v then return end
	w = w or 1
	v[1] += (rx or 0) * w
	v[2] += (ry or 0) * w
	v[3] += (rz or 0) * w
	v[4] += (px or 0) * w
	v[5] += (py or 0) * w
	v[6] += (pz or 0) * w
end

function Animator:Step(dt: number)
	self.Time += dt
	local t = self.Time
	local profile = self.Profile
	zeroAcc(self.Acc)

	-- locomotion crossfade
	local fadeRate = dt / math.max(self.LocoFade, 0.01)
	for mode, w in pairs(self.LocoWeights) do
		local target = (mode == self.LocoTarget) and 1 or 0
		if w < target then w = math.min(target, w + fadeRate) elseif w > target then w = math.max(target, w - fadeRate) end
		self.LocoWeights[mode] = w
	end

	-- action weights + suppression of the base loop
	local suppress = 0
	local i = 1
	while i <= #self.Actions do
		local tr = self.Actions[i]
		local action = tr.Action
		tr.T += dt * tr.Speed
		if tr.Loop and tr.T >= action.Duration then
			tr.T -= action.Duration
			tr.EventIndex = 1
		end
		local fade = math.min(1, tr.T / math.max(tr.FadeIn, 0.001))
		if not tr.Loop then
			local remain = action.Duration - tr.T
			fade = math.min(fade, math.clamp(remain / math.max(tr.FadeOut, 0.001), 0, 1))
		end
		if tr.Stopping then
			tr.StopT += dt
			fade = math.min(fade, 1 - math.clamp(tr.StopT / math.max(tr.StopFade, 0.001), 0, 1))
		end
		tr.Fade = fade * tr.Weight
		-- events
		local events = action.Events
		if events then
			while tr.EventIndex <= #events and events[tr.EventIndex][1] <= tr.T do
				local e = events[tr.EventIndex]
				tr.EventIndex += 1
				if not tr.Stopping then self:_fire(e[2], e[3], tr) end
			end
		end
		local done = (not tr.Loop and tr.T >= action.Duration) or (tr.Stopping and tr.StopT >= tr.StopFade)
		if done then
			-- root motion: actions that end somewhere else (a charge) move the RootPart there, seamlessly
			if action.CommitRoot and not tr.Stopping and self.Root then
				local pel = action._tracks.Pelvis
				local last = pel and pel[#pel][2]
				if last then
					local k = self.AnimScale
					self.Root.CFrame = self.Root.CFrame * CFrame.new(last[4] * k, 0, last[6] * k)
					self.Displaced = true
				end
			end
			table.remove(self.Actions, i)
			tr.Finished:Fire(not tr.Stopping)
		else
			suppress = math.max(suppress, (action.Suppress or 0.85) * tr.Fade)
			i += 1
		end
	end

	-- base loop (idle / walk / run), scaled down while an action dominates
	local base = 1 - suppress
	local gait = Gaits[profile.Gait.Type]
	local wIdle, wWalk, wRun = self.LocoWeights.Idle, self.LocoWeights.Walk, self.LocoWeights.Run
	-- shared gait phase so walk <-> run blends stay in step
	local freq = profile.Gait.Walk.Freq * (wWalk + wIdle) + profile.Gait.Run.Freq * wRun
	if wWalk + wRun > 0.01 then
		self.GaitPhase += dt * freq
	end
	if wIdle > 0.001 then gait.Idle(self, t, wIdle * base, profile.Gait) end
	if wWalk > 0.001 then gait.Locomote(self, self.GaitPhase, wWalk * base, profile.Gait, profile.Gait.Walk, false) end
	if wRun > 0.001 then gait.Locomote(self, self.GaitPhase, wRun * base, profile.Gait, profile.Gait.Run, true) end
	if wWalk + wRun > 0.3 and base > 0.3 and profile.Gait.Type ~= "Swim" then Gaits.footsteps(self, self.GaitPhase, wRun > wWalk, self._lastStrike) end

	-- actions
	for _, tr in ipairs(self.Actions) do
		if tr.Fade > 0.001 then Gaits.evalAction(self, tr, tr.Fade) end
	end

	-- an extra layer from gameplay code (PaddockLife: a dino leaning into a pat, turning to look at you): it adds
	-- to the pose with self:Add(...) after everything above
	if self.Layer then self.Layer(self, dt) end

	-- blinking (or eyes shut happily while it's being petted: self.EyesClosed)
	if #self.Eyelids > 0 and self.EyesClosed then
		for _, lid in ipairs(self.Eyelids) do lid.Transparency = 0 end
		self._blinkUntil = t
	elseif #self.Eyelids > 0 then
		if t >= self._nextBlink then
			self._blinkUntil = t + 0.13
			self._nextBlink = t + 2.5 + math.random() * 4
			for _, lid in ipairs(self.Eyelids) do lid.Transparency = 0 end
		elseif self._blinkUntil > 0 and t >= self._blinkUntil then
			self._blinkUntil = 0
			for _, lid in ipairs(self.Eyelids) do lid.Transparency = 1 end
		end
	end

	-- apply
	local k = self.AnimScale
	for name, motor in pairs(self.Motors) do
		local v = self.Acc[name]
		motor.Transform = CFrame.new(v[4] * k, v[5] * k, v[6] * k) * CFrame.Angles(v[1], v[2], v[3])
	end
end

-- a global time scale for every dino's animation: cutscenes use it for hit-stop (0 for a beat) and slow motion
DinosaurAnimations.TimeScale = 1

function DinosaurAnimations._stepAll(dt: number)
	dt *= DinosaurAnimations.TimeScale
	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for model, anim in pairs(animators) do
		if anim.Paused or not model:IsDescendantOf(Workspace) then continue end
		local root = anim.Root
		local dist = root and (root.Position - camPos).Magnitude or 0
		-- (whatever it's doing: idle grazes are actions too, so the old "no actions playing" exemption kept every
		-- far dino on the map animating at full rate most of the time - the main client lag)
		if dist > LOD_CULL then continue end
		local step = dt
		if dist > LOD_FULL then
			-- far away: update at ~15 Hz (actions just advance in bigger steps)
			anim._lodAcc = (anim._lodAcc or 0) + dt
			if anim._lodAcc < 1 / 15 then continue end
			step = anim._lodAcc
			anim._lodAcc = 0
		end
		local ok, err = xpcall(anim.Step, debug.traceback, anim, step)
		if not ok then
			-- surface the full error once, then keep trying (a bad action must never freeze the creature)
			if anim.LastError ~= err then
				anim.LastError = err
				warn(`[DinosaurAnimations] {anim.Species} ({model:GetFullName()}): {err}`)
			end
			table.clear(anim.Actions)
		end
	end
end

return DinosaurAnimations
