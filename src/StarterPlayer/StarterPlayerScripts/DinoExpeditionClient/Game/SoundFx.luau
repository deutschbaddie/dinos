--[[
	SoundFx — where the game's sound effects come from (the slots themselves live in Audio).

	  * dinos: every creature's animation already fires timed events (Roar, Bite, Footstep, Land, Splash...). The
	    voice and the thud ride those, so they land exactly on the frame, in cutscenes and gameplay alike, in 3D
	    from the dino. The voice follows the species (big carnivores roar, small hunters screech, herbivores
	    bellow, the Mosasaurus screams), the pitch follows its size (babies chirp), giant ones roar like bosses.
	  * rovers: an engine on every occupied rover in view, pitched by its speed; a whoosh when you boost; the door
	    when you get in or out.
	  * server moments: rover hits, latches, road pickups, cash pad, quests, boss loot, gadgets, the rodeo.
	  * requests: what a button actually did (sold, bought, crafted, picked up an egg...) gets its own sound.
	  * UI: Kit's clicks / windows / toasts go through Kit.SoundHook, and any other button clicks too.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DinosaurAnimations = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("DinosaurAnimations"))
local Audio = require(script.Parent.Audio)
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)

local player = Players.LocalPlayer
local SoundFx = {}

--------------------------------------------------------------------------------
-- dinos
--------------------------------------------------------------------------------
local BIG = { TyrannosaurusRex = true, Giganotosaurus = true, Carnotaurus = true, Spinosaurus = true, Yutyrannus = true, Postosuchus = true, PrimalRex = true, Sarcosuchus = true }
local HUNTER = { Velociraptor = true, Dilophosaurus = true, Coelophysis = true, Microraptor = true, Compy = true, Oviraptor = true, Gallimimus = true }

local sizes: { [Model]: { H: number, Species: string } } = setmetatable({}, { __mode = "k" }) :: any
local lastStep: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local settled: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function sizeOf(model: Model)
	local s = sizes[model]
	if s then return s end
	local ok, ext = pcall(function() return model:GetExtentsSize() end)
	local a = DinosaurAnimations.find(model)
	local sp = (a and a.Species) or model:GetAttribute("Species") or model.Name
	s = { H = ok and ext.Y or 4, Species = tostring(sp) }
	sizes[model] = s
	-- re-measure ONCE when it has settled (scaled after spawning, grown up...) - it used to be thrown away every
	-- 2 s, so every stepping dino re-measured its whole rig over and over
	if not settled[model] then
		settled[model] = true
		task.delay(2, function() sizes[model] = nil end)
	end
	return s
end

-- bigger animals sound lower; babies higher
local function pitchFor(h: number): number
	return math.clamp(1.3 - h / 30, 0.72, 1.35)
end

local function voice(model: Model, root: BasePart, name: string, arg)
	local s = sizeOf(model)
	local h, sp = s.H, s.Species
	local loud = math.clamp((arg and typeof(arg) == "table" and arg.Scale or 1) * 0.85, 0.6, 1.4)
	if h < 2.4 then
		Audio.Play("BabyChirp", { At = root, Pitch = pitchFor(h) + 0.2, Volume = 0.8 })
		return
	end
	if sp == "Mosasaurus" then
		Audio.Play("SeaRoar", { At = root, Volume = loud, Pitch = 0.9 })
	elseif BIG[sp] then
		if h > 16 and name == "Roar" then
			Audio.Play("RoarBoss", { At = root, Volume = loud })
		else
			Audio.Play("RoarBig", { At = root, Volume = name == "Roar" and loud or 0.7, Pitch = math.clamp(1.15 - h / 40, 0.75, 1.1) })
		end
	elseif HUNTER[sp] or (arg and typeof(arg) == "table" and arg.Screech) then
		Audio.Play("Screech", { At = root, Volume = name == "Roar" and loud or 0.75, Pitch = pitchFor(h) })
	else
		Audio.Play("Bellow", { At = root, Volume = name == "Roar" and loud or 0.8, Pitch = pitchFor(h) * 0.95 })
	end
end

local function onAnimEvent(model: Model, name: string, arg, _track)
	local root = model.PrimaryPart
	if not root or not model:IsDescendantOf(Workspace) then return end
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local dist = (root.Position - cam.CFrame.Position).Magnitude
	if dist > 450 then return end
	if name == "Roar" or name == "Call" or name == "HerdCall" or name == "PackCue" or name == "Alarm" then
		voice(model, root, name, arg)
	elseif name == "Growl" or name == "Hiss" then
		local s = sizeOf(model)
		Audio.Play("Growl", { At = root, Pitch = pitchFor(s.H) * (name == "Hiss" and 1.35 or 1) })
	elseif name == "Bite" or name == "Snatch" or name == "EggSnatch" or name == "ClawRake" or name == "ScytheSlash" then
		local s = sizeOf(model)
		if BIG[s.Species] or HUNTER[s.Species] or name ~= "Bite" then
			Audio.Play("Snap", { At = root, Pitch = pitchFor(s.H) })
		else
			-- a herbivore's "bite" is a horn / tail / club hit
			Audio.Play("StompBig", { At = root, Pitch = 1.15, Volume = 0.8 })
		end
	elseif name == "Footstep" then
		if dist > 160 then return end
		-- a dino riding along (in the rover's seats, floating through the time warp) has nothing to step on: silent
		local crew = Workspace:FindFirstChild("DinoCrewRiders")
		local warp = Workspace:FindFirstChild("DinoWarpTunnel")
		local vehicles = Workspace:FindFirstChild("ActiveVehicles")
		if (crew and model:IsDescendantOf(crew)) or (warp and model:IsDescendantOf(warp)) or (vehicles and model:IsDescendantOf(vehicles)) then return end
		local s = sizeOf(model)
		if s.H < 2.5 then return end
		local now = os.clock()
		if (lastStep[model] or 0) > now - 0.12 then return end
		lastStep[model] = now
		-- a dino trotting right beside you (your companion, nearly always) steps softly: you hear it all the time
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local beside = hrp ~= nil and s.H < 12 and (root.Position - hrp.Position).Magnitude < 24
		local soft = beside and 0.3 or 1
		if s.H >= 7 then
			Audio.Play("StompBig", { At = root, Volume = math.clamp(s.H / 18, 0.35, 1.1) * soft, Pitch = pitchFor(s.H), Gap = 0 })
		else
			Audio.Play("Stomp", { At = root, Volume = math.clamp(s.H / 7, 0.3, 0.8) * soft, Pitch = pitchFor(s.H) + 0.1, Gap = 0 })
		end
	elseif name == "Land" or name == "Impact" or name == "JumpDust" or name == "GateHit" or name == "BreakProp" then
		local s = sizeOf(model)
		Audio.Play(s.H >= 5 and "StompBig" or "Stomp", { At = root, Volume = math.clamp(s.H / 12, 0.5, 1.2), Pitch = pitchFor(s.H) })
	elseif name == "Splash" or name == "RollSpray" or name == "MudBurst" then
		local s = sizeOf(model)
		Audio.Play(s.H > 14 and "Breach" or "Splash", { At = root, Volume = math.clamp(s.H / 10, 0.5, 1.2), Gap = 0.15 })
	elseif name == "Stunned" then
		local s = sizeOf(model)
		Audio.Play("DinoHurt", { At = root, Pitch = pitchFor(s.H) })
	end
end

--------------------------------------------------------------------------------
-- rovers: engines, boost, doors
--------------------------------------------------------------------------------
local engines = {} :: { [Model]: { Snd: Sound, Root: BasePart } }

local function occupied(v: Model): boolean
	for _, d in ipairs(v:GetDescendants()) do
		if (d:IsA("VehicleSeat") or d:IsA("Seat")) and d.Occupant then return true end
	end
	return false
end

local function myRover(): Model?
	local av = Workspace:FindFirstChild("ActiveVehicles")
	if not av then return nil end
	for _, m in ipairs(av:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("Owner") == player.UserId then return m end
	end
	return nil
end

local function startRovers()
	local scanAt = 0
	local wasBoost = false
	local lastBoost, boostTired = -100, 0
	local Drive = nil
	pcall(function() Drive = require(script.Parent.Drive) end)
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local av = Workspace:FindFirstChild("ActiveVehicles")
		if av and now >= scanAt then
			scanAt = now + 0.5
			for _, v in ipairs(av:GetChildren()) do
				if v:IsA("Model") and v.PrimaryPart then
					local on = occupied(v) or (v:GetAttribute("Owner") == player.UserId and player:GetAttribute("Driving") == true)
					local e = engines[v]
					if on and not e then
						local snd = Audio.Loop("EngineLoop", v.PrimaryPart)
						if snd then
							snd.Volume = 0
							snd.RollOffMaxDistance = 180
							engines[v] = { Snd = snd, Root = v.PrimaryPart }
						end
					elseif e and not on then
						e.Snd:Destroy()
						engines[v] = nil
					end
				end
			end
		end
		for v, e in pairs(engines) do
			if not v.Parent or not e.Root.Parent then
				e.Snd:Destroy()
				engines[v] = nil
				continue
			end
			local vel = e.Root.AssemblyLinearVelocity
			local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
			local k = math.clamp(speed / 60, 0, 1.3)
			-- idle burble to a high rev; volume swells with speed
			local pitch = 0.7 + k * 0.55
			local vol = (Audio.Level.EngineLoop or 0.35) * (0.45 + k * 0.6)
			e.Snd.PlaybackSpeed += (pitch - e.Snd.PlaybackSpeed) * math.min(1, dt * 4)
			e.Snd.Volume += (vol - e.Snd.Volume) * math.min(1, dt * 3)
		end
		-- the boost whoosh, on the press
		local st = Drive and (Drive :: any).State
		local boosting = st and st.Boosting == true or false
		-- (nearly empty, holding boost just flickers it on and off as the meter refills: those trickles are silent.
		-- A whoosh needs a real tank behind it and a moment since the last one)
		local tank = st and tonumber(st.Boost) or 1
		if boosting and not wasBoost and tank >= 0.3 and now - lastBoost > 0.8 then
			-- the whoosh fades as it plays, and boosting again and again wears it down (it recovers after a rest)
			local since = now - lastBoost
			boostTired = since > 6 and 0 or math.min(boostTired + 1, 4)
			lastBoost = now
			local r = myRover()
			local snd = Audio.Play("Boost", { At = r and r.PrimaryPart or nil, Volume = 1 - boostTired * 0.15 })
			if snd then
				TweenService:Create(snd, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = snd.Volume * 0.2 }):Play()
			end
		end
		wasBoost = boosting
	end)
	-- the door: getting in and out
	local function bindHum(char: Model)
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hum then return end
		hum.Seated:Connect(function(_active, seat)
			local s = seat or hum.SeatPart
			local v = s and s:FindFirstAncestorOfClass("Model")
			local inRover = v and v:IsDescendantOf(Workspace:FindFirstChild("ActiveVehicles") or Workspace)
			if inRover or (not s) then
				local r = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				Audio.Play("CarDoor", { At = r, Gap = 0.4 })
			end
		end)
	end
	if player.Character then task.spawn(bindHum, player.Character) end
	player.CharacterAdded:Connect(bindHum)
end

--------------------------------------------------------------------------------
-- server moments
--------------------------------------------------------------------------------
local function at(): BasePart?
	local r = myRover()
	if r and r.PrimaryPart then return r.PrimaryPart end
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function startEvents()
	Net.On("RoverHit", function() Audio.Play("RoverHit", { At = at() }) end)
	Net.On("Hit", function(info) Audio.Play("RoverHit", { At = at(), Volume = (info.Damage or 0) >= 20 and 1.3 or 1 }) end)
	Net.On("Bump", function() Audio.Play("RoverHit", { At = at(), Volume = 0.5, Pitch = 1.2 }) end)
	Net.On("Wrecked", function() Audio.Play("RoverHit", { Volume = 1.5, Pitch = 0.8 }) Audio.Play("StompBig", { Volume = 1.2, Pitch = 0.8 }) end)
	Net.On("FootHit", function() Audio.Play("PlayerHurt") end)
	Net.On("Latched", function() Audio.Play("Snap", { At = at() }) end)
	Net.On("ShakenOff", function() Audio.Play("Dodge", { Pitch = 0.9 }) end)
	Net.On("Pickup", function(info)
		if info.Kind == "Coin" or info.Kind == "Coins" then Audio.Play("Coins") else Audio.Play("Perfect", { Pitch = 1.15, Volume = 0.8 }) end
	end)
	Net.On("Collected", function(info) Audio.Play((info.Amount or 0) >= 1e5 and "Payout" or "Coins") end)
	Net.On("QuestDone", function() Audio.Sting("QuestDone", 0.6) end)
	Net.On("BondUp", function() Audio.Sting("LevelUp", 0.55) end)
	Net.On("BossLoot", function() task.delay(1.6, function() Audio.Play("Payout") end) end)
	Net.On("EggReady", function() Audio.Play("Perfect", { Pitch = 0.85, Volume = 0.7 }) end)
	Net.On("RodeoEnd", function(info) if info.Success then Audio.Play("Calmed") end end)
	Net.On("Revived", function(info) if info.UserId == player.UserId then Audio.Play("Calmed", { Pitch = 1.1 }) end end)
	Net.On("GadgetFx", function(info)
		local p = info.P
		local slot = info.Id == "Flare" and "Flare" or (info.Id == "Earthshaker" and "Earthshaker" or "Bait")
		Audio.Play(slot, { At = typeof(p) == "Vector3" and p or nil })
	end)
end

--------------------------------------------------------------------------------
-- what a request did
--------------------------------------------------------------------------------
local ASK = {
	SellDinos = "Coins", BuyBase = "Purchase", RideBuy = "Purchase", UnlockEra = "Purchase",
	LevelUp = "LevelUp", Craft = "LevelUp", OpenChest = "Payout",
	Incubate = "EggPlace", AutoIncubate = "EggPlace", LoadEgg = "EggPlace", DropEgg = "EggPlace", PinHotbar = "EggPlace",
	PickEgg = "EggPickup", PickBall = "EggPickup", TakeBall = "EggPickup", PickSiteBall = "EggPickup",
	EquipGear = "Clunk", EquipBest = "Clunk", EquipCompanion = "Pet", ReviveBuddy = "Calmed",
	ThrowBall = "Dodge",
}
local function onAsk(name: string, args, res)
	if not (res and res.Ok) then return end
	if name == "HoldEgg" or name == "HoldDino" then
		Audio.Play(args and args.Id and "EggPickup" or "EggPlace")
		return
	end
	local slot = ASK[name]
	if slot == "LevelUp" or slot == "Payout" then
		Audio.Sting(slot, 0.6)
	elseif slot then
		Audio.Play(slot, { Pitch = name == "ThrowBall" and 1.3 or nil })
	end
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------
local UI_SLOT = { Click = "Click", Pop = "Toast", Open = "Open", Close = "Close", Toast = "Toast", Error = "Error", Talk = "Talk", Confirm = "Confirm" }
local function uiSound(name: string, volume: number?, pitch: number?): boolean
	-- the dialogue typewriter calls a very quiet click on every few letters: that's the talk blip
	if name == "Click" and volume and volume <= 0.15 then name = "Talk" end
	-- the old pitched clicks meant yes / no (the main menu's checks): give them the real sounds
	if name == "Click" and volume and volume >= 0.5 and pitch then
		if pitch >= 1.2 then name, pitch = "Confirm", nil elseif pitch <= 0.65 then name, pitch = "Error", nil end
	end
	local slot = UI_SLOT[name]
	if not slot or not Audio.Has(slot) then return false end
	Audio.Play(slot, { Volume = volume and math.clamp(volume / 0.45, 0.3, 1.5) or 1, Pitch = pitch, Exact = pitch ~= nil, Gap = 0.06 })
	return true
end

local function startUi()
	Kit.SoundHook = uiSound
	-- buttons that aren't Kit buttons (cards, tiles, hit areas) click too; a Kit button's own click and this one
	-- land in the same frame and play once
	local pg = player:WaitForChild("PlayerGui")
	local function bind(d: Instance)
		if d:IsA("GuiButton") and not d:GetAttribute("Silent") then
			d.Activated:Connect(function() uiSound("Click", 0.4) end)
		end
	end
	for _, d in ipairs(pg:GetDescendants()) do bind(d) end
	pg.DescendantAdded:Connect(bind)
end

function SoundFx.Start()
	DinosaurAnimations.onEvent(onAnimEvent)
	startRovers()
	startEvents()
	Net.AskHook = onAsk
	task.spawn(startUi)
end

return SoundFx
