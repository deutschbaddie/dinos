--[[
	Sightseer — a tourist out seeing the sights in every era (2026-10-14, user: "make like a sightseer npc in the eras
	... don't make it mandatory or part of the onboarding, just something you stumble on").

	Where: one per era, standing a few steps off one of its landmarks (a DiscoverSpots marker that isn't up on top of
	something), on open ground, well away from every nest, facing away from the view. Npcs.SpawnAt dresses them.
	What: an optional hunt for that era's landmarks you haven't found yet - up to Pick of them, each with a hint
	(IndexDefs.KindWord: "A WATERFALL") and which way and how far it is from the Sightseer. Found ones tick off as you
	find them (Discover.OnMark; a toast says so); come back when they're all ticked for the reward: Coins minutes of
	your yard's income (never below MinPerTier x the era's tier) and PowerSecs of training. Then another hunt, until
	there's nothing left to see.
	  SightseerTalk   { Era } -> { Ok, Type = "Offer" | "Hunt" | "TurnIn" | "AllSeen", Leads = { Hint, Dir, Dist, Found },
	                              Reward = { Coins, Power }, Sets }
	  SightseerAccept { Era } -> the same, with the hunt started
	  SightseerClaim  { Era } -> { Ok, Coins, Power } then the next talk
	profile.Sightseer[era] = { Leads = { secret ids } | nil, Sets = hunts finished }
	You have to be standing by them (Reach). Nothing here touches quests, the goal line or the onboarding.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local Defs = require(ReplicatedStorage.DinoExpedition.Game.IndexDefs)

local Sightseer = {}
local Data, Net, Dinos, Encounter

local PICK = 3 -- leads per hunt
local REACH = 18 -- studs from the Sightseer to talk
local COIN_MINUTES = 6 -- the reward: this many minutes of your yard's income
local MIN_PER_TIER = 1500 -- never less than this x the era's tier
local POWER_SECS = 90 -- and this many seconds of trainer POWER

local spotsByEra = {} :: { [string]: BasePart }
local rng = Random.new()

--------------------------------------------------------------------------------
-- where they stand
--------------------------------------------------------------------------------
local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function landmarkMarkers(eraId: string): { BasePart }
	local zm = Workspace:FindFirstChild(eraId)
	local folder = zm and zm:FindFirstChild("DiscoverSpots", true)
	local out = {}
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		local id = m:GetAttribute("Id")
		if m:IsA("BasePart") and typeof(id) == "string" and m:GetAttribute("Up") ~= true then
			local s = Defs.SecretOf(eraId, id)
			if s and s.Landmark then table.insert(out, m) end
		end
	end
	table.sort(out, function(a, b) return tostring(a:GetAttribute("Id")) < tostring(b:GetAttribute("Id")) end)
	return out
end

-- open, dry, level ground at (x, z) near height y, with room to stand and nothing solid crowding it
local function groundNear(x: number, z: number, y: number, skip: { Instance }): Vector3?
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = skip
	rp.IgnoreWater = false
	local hit = Workspace:Raycast(Vector3.new(x, y + 40, z), Vector3.new(0, -100, 0), rp)
	if not hit or hit.Material == Enum.Material.Water or hit.Normal.Y < 0.85 then return nil end
	if math.abs(hit.Position.Y - y) > 8 then return nil end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = skip
	for _, part in ipairs(Workspace:GetPartBoundsInRadius(hit.Position + Vector3.new(0, 3, 0), 2.6, op)) do
		if part.CanCollide then
			local cf, s = part.CFrame, part.Size
			local half = (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
			if part.Position.Y + half > hit.Position.Y + 1.2 and part.Position.Y - half < hit.Position.Y + 5.5 then return nil end
		end
	end
	return hit.Position
end

local function place(era): BasePart?
	local markers = landmarkMarkers(era.Id)
	if #markers == 0 then return nil end
	local nests = {}
	for _, site in ipairs(Encounter.Sites(era.Id)) do
		if site.Center then table.insert(nests, site.Center) end
	end
	local skip = {} :: { Instance }
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(skip, p.Character) end end
	-- start from the middle of the list: not the first sight down the road, not the last
	local n = #markers
	for k = 0, n - 1 do
		local m = markers[((n // 2) + k) % n + 1]
		local base = m.Position - Vector3.new(0, m.Size.Y / 2, 0)
		for _, r in ipairs({ 10, 13, 16, 20 }) do
			for i = 0, 11 do
				local a = i / 12 * math.pi * 2
				local p = groundNear(base.X + math.cos(a) * r, base.Z + math.sin(a) * r, base.Y, skip)
				if p then
					local clear = true
					for _, c in ipairs(nests) do
						if flat(p, c) < Defs.NestRadius + 25 then clear = false break end
					end
					if clear then
						-- (facing away from the sight: when you talk, it's behind them in the shot)
						local away = Vector3.new(p.X - base.X, 0, p.Z - base.Z)
						local spot = Instance.new("Part")
						spot.Name = "NpcSpot_Sightseer"
						spot.Anchored, spot.CanCollide, spot.CanQuery, spot.CanTouch = true, false, false, false
						spot.Transparency = 1
						spot.Size = Vector3.new(2, 1, 1)
						spot.CFrame = CFrame.lookAt(p + Vector3.new(0, 3, 0), p + Vector3.new(0, 3, 0) + away)
						spot:SetAttribute("Npc", "Sightseer")
						spot:SetAttribute("Era", era.Id)
						local tag = Instance.new("BillboardGui")
						tag.Name = "NameTag"
						tag.Size = UDim2.fromOffset(220, 50)
						tag.StudsOffset = Vector3.new(0, 4.4, 0)
						tag.MaxDistance = 70
						tag.LightInfluence = 0
						local label = Instance.new("TextLabel")
						label.Name = "Name"
						label.BackgroundTransparency = 1
						label.Size = UDim2.fromScale(1, 1)
						label.Font = Enum.Font.FredokaOne
						label.TextScaled = true
						label.TextColor3 = Color3.new(1, 1, 1)
						label.Text = "THE SIGHTSEER"
						local stroke = Instance.new("UIStroke")
						stroke.Thickness = 3
						stroke.Color = Color3.fromRGB(20, 24, 30)
						stroke.Parent = label
						label.Parent = tag
						tag.Parent = spot
						local att = Instance.new("Attachment")
						att.Name = "TalkAttachment"
						att.CFrame = CFrame.new(0, 0.5, -1.4)
						att.Parent = spot
						local pr = Instance.new("ProximityPrompt")
						pr.Name = "TalkPrompt"
						pr.ActionText = "Talk"
						pr.ObjectText = "Sightseer"
						pr.KeyboardKeyCode = Enum.KeyCode.E
						pr.MaxActivationDistance = 11
						pr.HoldDuration = 0
						pr.RequiresLineOfSight = false
						pr:SetAttribute("Npc", "Sightseer")
						pr:SetAttribute("PromptColor", "Teal")
						pr.Parent = att
						spot.Parent = Workspace:FindFirstChild(era.Id)
						return spot
					end
				end
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- the hunts
--------------------------------------------------------------------------------
local function rec(profile, eraId: string)
	if typeof(profile.Sightseer) ~= "table" then profile.Sightseer = {} end
	local r = profile.Sightseer[eraId]
	if typeof(r) ~= "table" then
		r = { Sets = 0 }
		profile.Sightseer[eraId] = r
	end
	r.Sets = tonumber(r.Sets) or 0
	if typeof(r.Leads) ~= "table" then r.Leads = nil end
	return r
end

local COMPASS = { "EAST", "SOUTH-EAST", "SOUTH", "SOUTH-WEST", "WEST", "NORTH-WEST", "NORTH", "NORTH-EAST" }
-- which way from here (north is -Z, like the maps) and how far, in steps
local function bearing(from: Vector3, to: Vector3): (string, number)
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local ang = math.deg(math.atan2(d.Z, d.X)) -- 0 = east, 90 = south (+Z)
	local i = math.floor(((ang % 360) + 22.5) / 45) % 8 + 1
	return COMPASS[i], math.floor(d.Magnitude / 10 + 0.5) * 10
end

local function markerPos(eraId: string, id: string): Vector3?
	local zm = Workspace:FindFirstChild(eraId)
	local folder = zm and zm:FindFirstChild("DiscoverSpots", true)
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		if m:IsA("BasePart") and m:GetAttribute("Id") == id then return m.Position end
	end
	return nil
end

local function unfound(profile, eraId: string): { string }
	local out = {}
	for _, s in ipairs(Defs.Secrets(eraId)) do
		if s.Landmark and not Defs.SecretFound(profile, eraId, s.Id) and markerPos(eraId, s.Id) then table.insert(out, s.Id) end
	end
	return out
end

local function yardRate(player: Player, profile): number
	local ok, r = pcall(Dinos.Rate, profile, player, false, true)
	r = ok and tonumber(r) or 0
	return (r and r > 0 and r < math.huge) and r or 0
end

local function reward(player: Player, profile, eraId: string): (number, number)
	local coins = math.max(MIN_PER_TIER * Config.EraTier(eraId), math.floor(yardRate(player, profile) * 60 * COIN_MINUTES))
	local power = 0
	pcall(function()
		local T = require(script.Parent.Trainer) :: any
		power = math.floor(T.PerSec(player) * POWER_SECS)
	end)
	return coins, power
end

local function view(player: Player, profile, eraId: string)
	local spot = spotsByEra[eraId]
	local r = rec(profile, eraId)
	local coins, power = reward(player, profile, eraId)
	local out = { Ok = true, Era = eraId, Sets = r.Sets, Reward = { Coins = coins, Power = power } }
	if r.Leads then
		local leads, done = {}, 0
		for _, id in ipairs(r.Leads) do
			local s = Defs.SecretOf(eraId, id)
			local found = Defs.SecretFound(profile, eraId, id)
			if found then done += 1 end
			local pos = markerPos(eraId, id)
			local dir, dist = "", 0
			if pos and spot then dir, dist = bearing(spot.Position, pos) end
			table.insert(leads, {
				Hint = s and (Defs.KindWord[s.Kind] or "SOMETHING") or "SOMETHING", Name = (found and s) and s.Name or nil,
				Dir = dir, Dist = dist, Found = found,
			})
		end
		out.Leads = leads
		out.Type = (done >= #r.Leads) and "TurnIn" or "Hunt"
		return out
	end
	out.Type = #unfound(profile, eraId) > 0 and "Offer" or "AllSeen"
	return out
end

-- the player is standing by this era's Sightseer
local function near(player: Player, eraId: string): boolean
	local spot = spotsByEra[eraId]
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return spot ~= nil and hrp ~= nil and (hrp.Position - spot.Position).Magnitude <= REACH
end

local function guard(player: Player, args): (any, string?)
	local profile = Data.Peek(player)
	local eraId = typeof(args) == "table" and args.Era
	if not profile or typeof(eraId) ~= "string" or not spotsByEra[eraId] then return nil, nil end
	if not near(player, eraId) then return nil, nil end
	return profile, eraId
end

function Sightseer.Start(deps)
	Data, Net, Dinos, Encounter = deps.Data, deps.Net, deps.Dinos, deps.Encounter
	task.spawn(function()
		local Npcs = require(script.Parent.Npcs) :: any
		for _, era in ipairs(Config.Eras) do
			if not (era.Built and Workspace:FindFirstChild(era.Id)) then continue end
			-- (the landmark list comes from the era's route module: give it a moment to be there)
			local spot = nil
			for _ = 1, 10 do
				local ok, s = pcall(place, era)
				if ok and s then spot = s break end
				if not ok then warn("[Sightseer] " .. era.Id .. ": " .. tostring(s)) break end
				task.wait(1)
			end
			if spot then
				spotsByEra[era.Id] = spot
				task.spawn(Npcs.SpawnAt, spot)
			else
				warn("[Sightseer] found nowhere to stand in " .. era.Id)
			end
		end
	end)
	Net.On("SightseerTalk", function(player, args)
		local profile, eraId = guard(player, args)
		if not profile then return { Ok = false } end
		return view(player, profile, eraId :: string)
	end)
	Net.On("SightseerAccept", function(player, args)
		local profile, eraId = guard(player, args)
		if not profile then return { Ok = false } end
		local r = rec(profile, eraId :: string)
		if not r.Leads then
			local list = unfound(profile, eraId :: string)
			if #list == 0 then return view(player, profile, eraId :: string) end
			for i = #list, 2, -1 do
				local j = rng:NextInteger(1, i)
				list[i], list[j] = list[j], list[i]
			end
			r.Leads = { table.unpack(list, 1, math.min(PICK, #list)) }
			Data.Changed(player)
		end
		return view(player, profile, eraId :: string)
	end)
	Net.On("SightseerClaim", function(player, args)
		local profile, eraId = guard(player, args)
		if not profile then return { Ok = false } end
		local r = rec(profile, eraId :: string)
		if not r.Leads then return { Ok = false } end
		for _, id in ipairs(r.Leads) do
			if not Defs.SecretFound(profile, eraId :: string, id) then return { Ok = false, Err = "NOT ALL FOUND YET" } end
		end
		local coins, power = reward(player, profile, eraId :: string)
		r.Leads = nil
		r.Sets += 1
		profile.Coins += coins
		profile.Earned += coins
		local gained = 0
		pcall(function()
			local T = require(script.Parent.Trainer) :: any
			gained = T.AddPower(player, power, "Sightseer") or 0
		end)
		Data.Changed(player)
		return { Ok = true, Coins = coins, Power = gained }
	end)
	-- a lead found out in the era: a word about it (the hunt's own count; the SECRET FOUND! pop says the rest)
	local okD, Discover = pcall(function() return require(script.Parent.Discover) :: any end)
	if okD and Discover then
		Discover.OnMark = function(player: Player, eraId: string, id: string)
			local profile = Data.Peek(player)
			local r = profile and typeof(profile.Sightseer) == "table" and profile.Sightseer[eraId]
			if typeof(r) ~= "table" or typeof(r.Leads) ~= "table" or not table.find(r.Leads, id) then return end
			local done = 0
			for _, l in ipairs(r.Leads) do if Defs.SecretFound(profile, eraId, l) then done += 1 end end
			local all = done >= #r.Leads
			Net.Fire(player, "Toast", {
				Text = all and "SIGHTSEER: ALL SPOTTED! GO TELL THEM" or string.format("SIGHTSEER: %d / %d SPOTTED", done, #r.Leads),
				Color = all and "Lime" or "Teal",
			})
		end
	end
end

return Sightseer
