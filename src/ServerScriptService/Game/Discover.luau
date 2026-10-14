--[[
	Discover — every era's SECRETS (2026-10-14, round 2 #6; the list is IndexDefs.Secrets, the page is in the Index).
	The server spots them, never the client:
	  LANDMARKS   reach a DiscoverSpot marker (Workspace/<era>/DiscoverSpots, placed by the era generator: attributes
	              Id, Name, Era, Kind, Radius, Up) on foot or in the rover, during a run in that era. Up = it's on
	              top of something (a lookout, a deck): you have to be up there, not underneath.
	  NESTS       get to a nest (within IndexDefs.NestRadius of its centre, or into its fight)
	  BOSS        the era's boss beaten (profile.Bosses) - counted quietly, it has its own big moment
	  STASH       take one of the era's hidden egg stashes (WildLife.OnStash)
	  WILD/SHINY  calm a wild dino / a SHINY one (WildLife.OnWildCalm)
	profile.Discover[era][id] = true. "SecretFound" tells the finder (DiscoverView pops SECRET FOUND!); the last
	one of an era pays its rover paint + coins once (IndexRewards.Claimed["Secrets/<era>"]) and fires
	"SecretsComplete".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local Defs = require(ReplicatedStorage.DinoExpedition.Game.IndexDefs)
local Rides = require(ReplicatedStorage.DinoExpedition.Game.Rides)

local Discover = {}
local Net, Data, Encounter, Expedition

local TICK = 0.4

-- the markers of one era: { Id, Name, Kind, Pos (the ground under the marker), R, Up }
local spotCache = {} :: { [string]: { any } }
local function spots(eraId: string): { any }
	local cached = spotCache[eraId]
	if cached then return cached end
	local zm = Workspace:FindFirstChild(eraId)
	local folder = zm and zm:FindFirstChild("DiscoverSpots", true)
	if not folder then return {} end
	local out = {}
	for _, m in ipairs(folder:GetChildren()) do
		local id = m:GetAttribute("Id")
		if m:IsA("BasePart") and typeof(id) == "string" and Defs.SecretOf(eraId, id) then
			table.insert(out, {
				Id = id, Name = m:GetAttribute("Name") or id, Kind = m:GetAttribute("Kind"),
				Pos = m.Position - Vector3.new(0, m.Size.Y / 2, 0),
				R = tonumber(m:GetAttribute("Radius")) or Defs.SpotRadius, Up = m:GetAttribute("Up") == true,
			})
		end
	end
	spotCache[eraId] = out
	return out
end

local function bag(profile, eraId: string)
	if typeof(profile.Discover) ~= "table" then profile.Discover = {} end
	local d = profile.Discover[eraId]
	if typeof(d) ~= "table" then
		d = {}
		profile.Discover[eraId] = d
	end
	return d
end

-- all of an era found: its paint + coins, once
local function complete(player: Player, profile, eraId: string)
	local n, total = Defs.SecretProgress(profile, eraId)
	if total == 0 or n < total then return end
	if typeof(profile.IndexRewards) ~= "table" then profile.IndexRewards = { Claimed = {}, Title = "" } end
	local ir = profile.IndexRewards
	if typeof(ir.Claimed) ~= "table" then ir.Claimed = {} end
	local key = "Secrets/" .. eraId
	if ir.Claimed[key] then return end
	ir.Claimed[key] = true
	local coins = Defs.SecretCoinsPerTier * Config.EraTier(eraId)
	profile.Coins += coins
	profile.Earned += coins
	local paint = Defs.SecretPaint[eraId]
	local item = paint and Rides.Item("Paint", paint)
	if item then
		profile.RideOwned = profile.RideOwned or {}
		profile.RideOwned[Rides.Key("Paint", paint)] = true
	end
	local era = Config.Era(eraId)
	Net.Fire(player, "SecretsComplete", { Era = eraId, Coins = coins, Paint = item and paint or nil, PaintName = item and item.Name or nil, Total = total })
	Net.FireOthers(player, "Announce", { Text = string.format("%s FOUND EVERY SECRET IN %s!", string.upper(player.DisplayName), era and era.Name or eraId), Color = "Teal" })
end

-- mark one secret found. quiet: no SECRET FOUND! pop (the boss: it already had its moment)
local function mark(player: Player, eraId: string, id: string, at: Vector3?, quiet: boolean?)
	local profile = Data.Peek(player)
	if not profile then return end
	local s = Defs.SecretOf(eraId, id)
	if not s then return end
	local d = bag(profile, eraId)
	if d[id] then return end
	d[id] = true
	local n, total = Defs.SecretProgress(profile, eraId)
	if not quiet then
		Net.Fire(player, "SecretFound", { Era = eraId, Id = id, Name = s.Name, Kind = s.Kind, Species = s.Species, Found = n, Total = total, At = at })
	end
	complete(player, profile, eraId)
	Data.Changed(player)
end
Discover.Mark = mark

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- one look round for one player on a run
local function scan(player: Player, profile, run)
	local eraId = run.Zone
	if typeof(eraId) ~= "string" or run.Phase == "Warping" then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or (hum and hum.Health <= 0) then return end
	local p = hrp.Position
	local d = typeof(profile.Discover) == "table" and profile.Discover[eraId] or nil
	for _, s in ipairs(spots(eraId)) do
		if not (d and d[s.Id]) and flat(p, s.Pos) <= s.R then
			local dy = p.Y - s.Pos.Y
			-- (Up: you're up there, not driving past underneath; otherwise roughly level with it)
			local ok = if s.Up then dy > -4 and dy < 24 else math.abs(dy) < math.max(30, s.R)
			if ok then mark(player, eraId, s.Id, s.Pos) end
		end
	end
	local siteKey = player:GetAttribute("Site")
	for _, site in ipairs(Encounter.Sites(eraId)) do
		local def = site.Def
		if def and not site.Boss and not def.Wild and site.Center then
			local id = "Nest_" .. tostring(def.Id)
			if not (d and d[id]) and (siteKey == site.Key or flat(p, site.Center) <= Defs.NestRadius) then
				mark(player, eraId, id, site.Center)
			end
		end
	end
end

-- bosses beaten before (or while) this was here: counted quietly
local function bosses(player: Player, profile)
	for _, e in ipairs(Defs.PageEras()) do
		local rec = typeof(profile.Bosses) == "table" and profile.Bosses[e.Boss]
		if typeof(rec) == "table" and (tonumber(rec.Best) or 0) >= 1 and not Defs.SecretFound(profile, e.Id, "Boss") then
			mark(player, e.Id, "Boss", nil, true)
		end
	end
end

-- the era a player is in right now (their own run, or riding along in someone else's)
local function runOf(player: Player)
	return Expedition.Get(player) or (Expedition.RiderRun and Expedition.RiderRun(player)) or nil
end

function Discover.Start(deps)
	Net, Data, Encounter, Expedition = deps.Net, deps.Data, deps.Encounter, deps.Expedition
	-- free roam's finds tell us who found them (WildLife.luau hooks)
	local okW, WildLife = pcall(function() return require(script.Parent.WildLife) :: any end)
	if okW and WildLife then
		WildLife.OnStash = function(player: Player, eraId: string, at: Vector3?)
			mark(player, eraId, "Stash", at)
		end
		WildLife.OnWildCalm = function(site)
			local eraId = site and site.Era
			if typeof(eraId) ~= "string" then return end
			local shiny = site.Def and site.Def.WildFloor == "Epic" -- (the SHINY glow: WildLife's top roll)
			for plr in pairs(site.Players or {}) do
				if typeof(plr) == "Instance" and plr:IsA("Player") then
					mark(plr, eraId, "Wild", site.Center)
					if shiny then mark(plr, eraId, "Shiny", site.Center) end
				end
			end
		end
	end
	task.spawn(function()
		local beat = 0
		while true do
			task.wait(TICK)
			beat += 1
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = Data.Peek(player)
				if profile then
					local run = runOf(player)
					if run then
						local ok, err = pcall(scan, player, profile, run)
						if not ok then warn("[Discover] scan:", err) end
					end
					-- (every ~2 s is plenty for the boss check)
					if beat % 5 == 0 then pcall(bosses, player, profile) end
				end
			end
		end
	end)
end

return Discover
