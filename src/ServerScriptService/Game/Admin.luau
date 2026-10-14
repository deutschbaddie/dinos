--[[
	Admin — the Settings > ADMIN panel's server side. Every request is checked here against Admins.luau
	(the client only decides whether to show the tab). Roles:
	  Admin  GoTo / Bring / SendHome / Freeze / Unfreeze / Respawn, Kick, Announce (this server), WakeBoss, LuckEvent
	         + Ban (any length) / Ban by username / Unban - only the admins marked CanBan in Admins.luau (NotTufferson)
	  Owner  all of that, plus MakeAdmin / RemoveAdmin (saved, every server), GiveCoins / GiveEgg, Announce to every
	         server, Shutdown
	Admins can't act on the owner or other admins (Admins.CanTarget). Typed text (reasons, announcements) goes
	through TextService before anyone else sees it. Every action is printed as "[Admin] ..." and kept in a short
	per-server log the panel shows.
	Sets player attribute AdminRole ("Owner" / "Admin") so the client knows to show the tab.
]]

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local Admins = require(ReplicatedStorage.DinoExpedition.Game.Admins)
local DevTools = require(script.Parent.DevTools)

local Admin = {}
local Net, Data, Vehicles, Dinos, Expedition

local TOPIC = "DinoAdminAnnounce"
-- admins SickleEdge makes in game: saved (every server, every session) and pushed live to the other servers
local ROLES_TOPIC = "DinoAdminRoles"
local ROLES_KEY = "Granted"
local rolesStore = nil :: any
pcall(function() rolesStore = DataStoreService:GetDataStore("DinoAdmins_v1") end)
local BAN_SECONDS = { ["1h"] = 3600, ["1d"] = 86400, ["7d"] = 7 * 86400, ["Forever"] = -1 }
local LOG_MAX = 40
local log = {} :: { { T: number, Text: string } }
local startedAt = os.time()
local shuttingDown = false

local function record(text: string)
	print("[Admin] " .. text)
	table.insert(log, 1, { T = os.time(), Text = text })
	if #log > LOG_MAX then table.remove(log) end
end

-- filtered for everyone in the game; nil when the filter refuses or fails
local function filter(text: any, fromId: number): string?
	if typeof(text) ~= "string" then return nil end
	text = text:sub(1, 160):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return nil end
	local ok, res = pcall(function()
		return TextService:FilterStringAsync(text, fromId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)
	return ok and res or nil
end

local function root(p: Player): BasePart?
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- out of any run and rover before being moved (otherwise they'd stay "at a site" back at camp)
local function leaveRun(p: Player)
	if Expedition.Get(p) then
		Expedition.Abort(p)
		Net.Fire(p, "WokeUp", {})
	end
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart then hum.Sit = false task.wait(0.15) end
	Vehicles.Despawn(p)
end

-- which world (era lighting / zone) a player is standing in: their run's era, or camp
local function zoneOf(p: Player): string
	local run = Expedition.Get(p) or (Expedition.RiderRun and Expedition.RiderRun(p))
	return run and run.Zone or "BaseCamp"
end
-- a teleport that sticks: the server moves the body, AND tells that player's own game to (it owns its character's
-- physics, and a run ending under it - the wake-up at camp - used to pull it straight back), in the right world
local function moveTo(p: Player, cf: CFrame, zone: string?)
	local c = p.Character
	local to = cf + Vector3.new(0, 3, 0)
	if c then c:PivotTo(to) end
	Net.Fire(p, "AdminTP", { At = to, Zone = zone or "BaseCamp" })
end

local function setFrozen(p: Player, on: boolean)
	p:SetAttribute("AdminFrozen", on or nil)
	local c = p.Character
	local r = root(p)
	if r then r.Anchored = on end
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum then hum:SetAttribute("Frozen", on or nil) end
end

local function ban(actor: Player, userId: number, name: string, length: string, reason: string?)
	local secs = BAN_SECONDS[length]
	if not secs then return false, "PICK A BAN LENGTH" end
	local shown = reason or "Banned by a Dino Expedition admin."
	local ok, err = pcall(function()
		Players:BanAsync({
			UserIds = { userId }, ApplyToUniverse = true, Duration = secs,
			DisplayReason = shown, PrivateReason = `by {actor.Name} ({actor.UserId})`, ExcludeAltAccounts = false,
		})
	end)
	if not ok then
		warn("[Admin] BanAsync failed: " .. tostring(err))
		return false, "BAN FAILED (BANS ONLY WORK IN THE LIVE GAME)"
	end
	local target = Players:GetPlayerByUserId(userId)
	if target then target:Kick(shown) end
	record(`{actor.Name} banned {name} ({length}){reason and (": " .. reason) or ""}`)
	return true, (length == "Forever" and "BANNED FOREVER: " or `BANNED {string.upper(length)}: `) .. name
end

local function userIdFromName(name: any): (number?, string?)
	if typeof(name) ~= "string" or name == "" then return nil end
	local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
	if not ok or not id then return nil end
	local ok2, real = pcall(function() return Players:GetNameFromUserIdAsync(id) end)
	return id, ok2 and real or name
end

-- the saved list -> Admins.Granted, and every player here gets (or loses) the ADMIN tab to match
local function applyGranted(map: any)
	table.clear(Admins.Granted)
	for k in pairs(typeof(map) == "table" and map or {}) do
		local id = tonumber(k)
		if id then Admins.Granted[id] = true end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local role = Admins.Role(p.UserId)
		if p:GetAttribute("AdminRole") ~= role then p:SetAttribute("AdminRole", role) end
	end
end
local function loadGranted()
	if not rolesStore then return end
	local ok, map = pcall(function() return rolesStore:GetAsync(ROLES_KEY) end)
	if ok then applyGranted(map) else warn("[Admin] couldn't load the admin list: " .. tostring(map)) end
end
-- add (grant = true) or remove a granted admin, saved first; then this server and every other one updates
local function setGranted(actor: Player, userId: number, name: string, grant: boolean): (boolean, string)
	if not rolesStore then return false, "SAVING ISN'T AVAILABLE HERE" end
	local ok, err = pcall(function()
		rolesStore:UpdateAsync(ROLES_KEY, function(old)
			local map = typeof(old) == "table" and old or {}
			if grant then map[tostring(userId)] = { Name = name, By = actor.UserId, At = os.time() } else map[tostring(userId)] = nil end
			return map
		end)
	end)
	if not ok then return false, "COULDN'T SAVE - TRY AGAIN (" .. tostring(err) .. ")" end
	loadGranted()
	pcall(function() MessagingService:PublishAsync(ROLES_TOPIC, { At = os.time() }) end)
	record(`{actor.Name} {grant and "made" or "removed"} {name} {grant and "an admin" or "as admin"}`)
	return true, grant and ("MADE " .. name .. " AN ADMIN") or ("REMOVED " .. name .. " AS ADMIN")
end

local function playerRow(actor: Player, p: Player)
	local profile = Data.Peek(p)
	local run = Expedition.Get(p)
	local era = run and Config.Era(run.Era or "")
	return {
		UserId = p.UserId, Name = p.Name, DisplayName = p.DisplayName,
		Role = Admins.Role(p.UserId), Granted = Admins.IsGranted(p.UserId), Tester = p:GetAttribute("Tester") == true,
		Frozen = p:GetAttribute("AdminFrozen") == true, CanTarget = Admins.CanTarget(actor.UserId, p.UserId),
		Run = era and era.Name or nil, Coins = profile and profile.Coins or 0,
		Power = profile and Config.PowerOf(profile, Dinos.BuddyList(profile)) or 0,
	}
end

local function announce(text: string, from: string, everywhere: boolean)
	local payload = { Text = text, From = from }
	if everywhere then
		local ok = pcall(function() MessagingService:PublishAsync(TOPIC, payload) end)
		if ok then return end -- this server hears its own publish through the subscription
	end
	Net.FireAll("AdminAnnounce", payload)
end

local function shutdown(actor: Player)
	shuttingDown = true
	record(actor.Name .. " shut the server down")
	announce("THIS SERVER IS RESTARTING", actor.Name, false)
	task.delay(6, function()
		for _, p in ipairs(Players:GetPlayers()) do p:Kick("This server was restarted by an admin. Rejoin to keep playing!") end
	end)
end

-- player actions: fn(actor, target, args) -> message
local ON_PLAYER = {} :: { [string]: { Role: string, Fn: (Player, Player, any) -> (boolean, string) } }
ON_PLAYER.GoTo = { Role = "Admin", Fn = function(actor, target)
	local r = root(target)
	if not r then return false, "THEY HAVE NO CHARACTER" end
	local zone = zoneOf(target)
	leaveRun(actor)
	moveTo(actor, r.CFrame * CFrame.new(0, 0, 5), zone)
	record(`{actor.Name} went to {target.Name}`)
	return true, "TELEPORTED TO " .. target.Name
end }
ON_PLAYER.Bring = { Role = "Admin", Fn = function(actor, target)
	local r = root(actor)
	if not r then return false, "YOU HAVE NO CHARACTER" end
	local zone = zoneOf(actor)
	leaveRun(target)
	moveTo(target, r.CFrame * CFrame.new(0, 0, -5), zone)
	record(`{actor.Name} brought {target.Name}`)
	return true, "BROUGHT " .. target.Name
end }
ON_PLAYER.SendHome = { Role = "Admin", Fn = function(actor, target)
	if not Data.Peek(target) then return false, "STILL LOADING" end
	DevTools.Run(target, "Teleport", { Where = "Plot" })
	record(`{actor.Name} sent {target.Name} home`)
	return true, "SENT " .. target.Name .. " HOME"
end }
ON_PLAYER.Freeze = { Role = "Admin", Fn = function(actor, target)
	setFrozen(target, true)
	record(`{actor.Name} froze {target.Name}`)
	return true, "FROZE " .. target.Name
end }
ON_PLAYER.Unfreeze = { Role = "Admin", Fn = function(actor, target)
	setFrozen(target, false)
	record(`{actor.Name} unfroze {target.Name}`)
	return true, "UNFROZE " .. target.Name
end }
ON_PLAYER.Respawn = { Role = "Admin", Fn = function(actor, target)
	leaveRun(target)
	target:LoadCharacter()
	record(`{actor.Name} respawned {target.Name}`)
	return true, "RESPAWNED " .. target.Name
end }
ON_PLAYER.Kick = { Role = "Admin", Fn = function(actor, target, args)
	local reason = filter(args.Reason, actor.UserId)
	record(`{actor.Name} kicked {target.Name}{reason and (": " .. reason) or ""}`)
	target:Kick(reason and ("Kicked by an admin: " .. reason) or "Kicked by a Dino Expedition admin.")
	return true, "KICKED " .. target.Name
end }
ON_PLAYER.Ban = { Role = "Admin", Fn = function(actor, target, args)
	if not Admins.CanBan(actor.UserId) then return false, "ONLY SICKLEEDGE AND NOTTUFFERSON CAN BAN - YOU CAN KICK" end
	local length = tostring(args.Length)
	return ban(actor, target.UserId, target.Name, length, filter(args.Reason, actor.UserId))
end }
-- WATCH (the owner only): see exactly what another player sees - their camera, in their world - without them
-- knowing. Their game quietly reports its camera; the server passes it to the watcher and nobody else
local watching = {} :: { [Player]: Player } -- target -> watcher
local function stopWatch(target: Player)
	local w = watching[target]
	if not w then return end
	watching[target] = nil
	if target.Parent then Net.Fire(target, "CamStream", { On = false }) end
	if w.Parent then Net.Fire(w, "WatchFrame", { Stop = true }) end
end
ON_PLAYER.Watch = { Role = "Owner", Fn = function(actor, target)
	if target == actor then return false, "PICK SOMEONE ELSE" end
	for t, w in pairs(watching) do if w == actor then stopWatch(t) end end
	watching[target] = actor
	Net.Fire(target, "CamStream", { On = true })
	Net.Fire(actor, "WatchFrame", { Start = true, UserId = target.UserId, Name = target.Name, Zone = zoneOf(target) })
	return true, "WATCHING " .. target.Name
end }
ON_PLAYER.Unwatch = { Role = "Owner", Fn = function(actor, target)
	if watching[target] == actor then stopWatch(target) end
	return true, "STOPPED"
end }
Admin.StopWatch = stopWatch
Admin.Watching = watching

-- making admins: SickleEdge (the owner) only. Made admins can kick but not ban
ON_PLAYER.MakeAdmin = { Role = "Owner", Fn = function(actor, target)
	if Admins.Role(target.UserId) then return false, target.Name .. " IS ALREADY STAFF" end
	return setGranted(actor, target.UserId, target.Name, true)
end }
ON_PLAYER.RemoveAdmin = { Role = "Owner", Fn = function(actor, target)
	if not Admins.IsGranted(target.UserId) then return false, target.Name .. " ISN'T AN ADMIN YOU MADE" end
	return setGranted(actor, target.UserId, target.Name, false)
end }
ON_PLAYER.GiveCoins = { Role = "Owner", Fn = function(actor, target, args)
	if not Data.Peek(target) then return false, "STILL LOADING" end
	local n = math.clamp(math.floor(tonumber(args.Amount) or 0), 1, 1e9)
	DevTools.Run(target, "AddCoins", { Amount = n })
	record(`{actor.Name} gave {target.Name} {Config.FormatNumber(n)} coins`)
	return true, `+{Config.FormatNumber(n)} COINS TO {target.Name}`
end }
ON_PLAYER.GiveEgg = { Role = "Owner", Fn = function(actor, target, args)
	if not Data.Peek(target) then return false, "STILL LOADING" end
	local rarity = Config.Rarity[args.Rarity] and args.Rarity or "Legendary"
	local msg = DevTools.Run(target, "GiveEgg", { Rarity = rarity, Species = args.Species })
	record(`{actor.Name} gave {target.Name} an egg: {msg}`)
	return true, `{msg} TO {target.Name}`
end }

-- server actions: fn(actor, args) -> message
local ON_SERVER = {} :: { [string]: { Role: string, Fn: (Player, any) -> (boolean, string) } }
ON_SERVER.Announce = { Role = "Admin", Fn = function(actor, args)
	local everywhere = args.Everywhere == true
	if everywhere and Admins.Role(actor.UserId) ~= "Owner" then return false, "ONLY THE OWNER CAN ANNOUNCE TO EVERY SERVER" end
	local text = filter(args.Text, actor.UserId)
	if not text then return false, "TYPE A MESSAGE FIRST" end
	announce(text, actor.Name, everywhere)
	record(`{actor.Name} announced{everywhere and " (all servers)" or ""}: {text}`)
	return true, everywhere and "SENT TO EVERY SERVER" or "SENT TO THIS SERVER"
end }
ON_SERVER.WakeBoss = { Role = "Admin", Fn = function(actor)
	if not Data.Peek(actor) then return false, "STILL LOADING" end
	local msg = DevTools.Run(actor, "OpenBoss", {})
	record(`{actor.Name} woke the boss: {msg}`)
	return true, msg
end }
-- a server-wide 2x LUCK for everyone here (Boosts.luau; another press while one runs adds 15 minutes, up to an hour)
ON_SERVER.LuckEvent = { Role = "Admin", Fn = function(actor)
	local ok, res, msg = pcall(function() return (require(script.Parent.Boosts) :: any).StartLuckEvent({ By = actor.DisplayName, Source = "Admin" }) end)
	if not ok then return false, "LUCK EVENTS AREN'T READY" end
	if res then record(`{actor.Name} started 2x LUCK: {msg}`) end
	return res == true, tostring(msg)
end }
ON_SERVER.BanName = { Role = "Admin", Fn = function(actor, args)
	if not Admins.CanBan(actor.UserId) then return false, "ONLY SICKLEEDGE AND NOTTUFFERSON CAN BAN" end
	local id, name = userIdFromName(args.Name)
	if not id then return false, "NO PLAYER WITH THAT NAME" end
	if Admins.Rank(id) > 0 then return false, "THAT'S AN ADMIN" end
	return ban(actor, id, name :: string, "Forever", filter(args.Reason, actor.UserId))
end }
ON_SERVER.Unban = { Role = "Admin", Fn = function(actor, args)
	if not Admins.CanBan(actor.UserId) then return false, "ONLY SICKLEEDGE AND NOTTUFFERSON CAN UNBAN" end
	local id, name = userIdFromName(args.Name)
	if not id then return false, "NO PLAYER WITH THAT NAME" end
	local ok, err = pcall(function() Players:UnbanAsync({ UserIds = { id }, ApplyToUniverse = true }) end)
	if not ok then
		warn("[Admin] UnbanAsync failed: " .. tostring(err))
		return false, "UNBAN FAILED (BANS ONLY WORK IN THE LIVE GAME)"
	end
	record(`{actor.Name} unbanned {name}`)
	return true, "UNBANNED " .. tostring(name)
end }
ON_SERVER.Shutdown = { Role = "Owner", Fn = function(actor)
	shutdown(actor)
	return true, "SHUTTING DOWN IN 6 SECONDS"
end }

local function allowed(actor: Player, need: string): boolean
	local role = Admins.Role(actor.UserId)
	return role == "Owner" or (need == "Admin" and role == "Admin")
end

function Admin.Start(deps)
	Net, Data, Vehicles, Dinos, Expedition = deps.Net, deps.Data, deps.Vehicles, deps.Dinos, deps.Expedition

	local function onJoin(p: Player)
		if shuttingDown then p:Kick("This server is restarting. Rejoin to keep playing!") return end
		local role = Admins.Role(p.UserId)
		if role then p:SetAttribute("AdminRole", role) end
		p.CharacterAdded:Connect(function()
			if p:GetAttribute("AdminFrozen") then
				task.defer(function()
					local c = p.Character
					if c then c:WaitForChild("HumanoidRootPart", 5) end
					setFrozen(p, true)
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end
	task.spawn(loadGranted)
	pcall(function()
		MessagingService:SubscribeAsync(ROLES_TOPIC, function() task.spawn(loadGranted) end)
	end)

	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(msg)
			local d = msg.Data
			if typeof(d) == "table" and typeof(d.Text) == "string" then
				Net.FireAll("AdminAnnounce", { Text = d.Text, From = tostring(d.From or "") })
			end
		end)
	end)

	-- the watched player's camera, passed straight to the one watcher (only while they're being watched)
	Net.On("CamFrame", function(p, args)
		local w = watching[p]
		if not (w and w.Parent) then return { Ok = false, Stop = true } end
		if typeof(args.P) ~= "Vector3" or typeof(args.L) ~= "Vector3" then return { Ok = false } end
		Net.Fire(w, "WatchFrame", { P = args.P, L = args.L, F = tonumber(args.F) or 70, Zone = zoneOf(p) })
		return { Ok = true }
	end)
	Players.PlayerRemoving:Connect(function(p)
		if watching[p] then stopWatch(p) end
		for t, w in pairs(watching) do if w == p then stopWatch(t) end end
	end)

	Net.On("Admin", function(actor, args)
		local role = Admins.Role(actor.UserId)
		if not role then return { Ok = false, Err = "ADMINS ONLY" } end
		local action = args.Action
		if action == "List" then
			local rows = {}
			for _, p in ipairs(Players:GetPlayers()) do table.insert(rows, playerRow(actor, p)) end
			table.sort(rows, function(a, b) return a.Name:lower() < b.Name:lower() end)
			local recent = {}
			for i = 1, math.min(12, #log) do recent[i] = log[i] end
			return {
				Ok = true, Role = role, CanBan = Admins.CanBan(actor.UserId), Players = rows, Log = recent, ServerTime = os.time(),
				Server = { Players = #Players:GetPlayers(), Max = Players.MaxPlayers, Uptime = os.time() - startedAt, Job = game.JobId:sub(1, 8) },
			}
		end
		local pa = ON_PLAYER[action]
		if pa then
			if not allowed(actor, pa.Role) then return { Ok = false, Err = "ONLY THE OWNER CAN DO THAT" } end
			local target = typeof(args.UserId) == "number" and Players:GetPlayerByUserId(args.UserId) or nil
			if not target then return { Ok = false, Err = "THEY LEFT" } end
			-- going to someone is harmless (even another admin); the owner may gift anyone, themselves included;
			-- everything else respects rank
			local harmless = action == "GoTo" and target ~= actor
			local gift = action == "GiveCoins" or action == "GiveEgg"
			if not (harmless or gift or Admins.CanTarget(actor.UserId, target.UserId)) then
				return { Ok = false, Err = "YOU CAN'T DO THAT TO " .. target.Name }
			end
			local ok, msg = pa.Fn(actor, target, args)
			return { Ok = ok, Message = ok and msg or nil, Err = (not ok) and msg or nil }
		end
		local sa = ON_SERVER[action]
		if sa then
			if not allowed(actor, sa.Role) then return { Ok = false, Err = "ONLY THE OWNER CAN DO THAT" } end
			local ok, msg = sa.Fn(actor, args)
			return { Ok = ok, Message = ok and msg or nil, Err = (not ok) and msg or nil }
		end
		return { Ok = false, Err = "UNKNOWN ACTION" }
	end)
end

return Admin
