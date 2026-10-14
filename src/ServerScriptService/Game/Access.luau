--[[
	Access — the PRE-BETA gate (live servers only; Studio walks straight in, see Testing.luau).
	Sets player attribute Access, which the client's main menu animates:
	  "Checking"  -> deciding
	  "Granted"   -> on the tester list (or the owner / a group admin; or anyone at all while Testing.Open) and in
	                 the group: the game loads
	  "NeedGroup" -> on the list but not in the group yet: the menu offers JOIN, then asks AccessRecheck
	  "Denied"    -> not on the list: the menu shows ACCESS DENIED, the server kicks after DENY_GRACE
	  "Open"      -> no test phase on this server (Studio, or after launch)
	Also sets attribute Tester on every approved tester (their PRE-BETA TESTER tag, kept after launch),
	and answers PlayerCard: everything about a player in this game for the profile card.
]]

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local Testing = require(ReplicatedStorage.DinoExpedition.Game.Testing)
local Admins = require(ReplicatedStorage.DinoExpedition.Game.Admins)
local DevTools = require(script.Parent.DevTools)

local Access = {}
local Net, Data, Dinos

local DENY_GRACE = 11 -- seconds the ACCESS DENIED screen shows before the kick
local GROUP_WAIT = 600 -- a tester who never joins the group is let go after this
local KICK_DENIED = `Dino Expedition is in {Testing.Phase} testing - approved testers only. Apply in our Discord: {Testing.Discord}`
local KICK_GROUP = "Join the group to play the PRE-BETA, then rejoin!"
-- Studio preview only (Testing.PreviewInStudio): "Denied" / "NeedGroup" shows that screen instead of granting
local PREVIEW_RESULT: string? = Testing.PreviewResult

local function staff(player: Player): boolean
	if RunService:IsStudio() then return PREVIEW_RESULT == nil end
	return DevTools.Allowed(player) or Admins.Role(player.UserId) ~= nil
end

-- GetRankInGroup is cached for the whole session, so after a join ask GroupService for the live list
local function inGroup(player: Player, fresh: boolean?): boolean
	if RunService:IsStudio() then return fresh == true end
	if fresh then
		local ok, groups = pcall(function() return GroupService:GetGroupsAsync(player.UserId) end)
		if ok and typeof(groups) == "table" then
			for _, g in ipairs(groups) do
				if g.Id == Testing.GroupId then return true end
			end
			return false
		end
	end
	local ok, rank = pcall(function() return player:GetRankInGroup(Testing.GroupId) end)
	return ok and rank > 0
end

-- yields until this player may play (true), or they're on their way out (false). Call before loading the profile.
function Access.Gate(player: Player): boolean
	if Testing.IsTester(player.UserId) then player:SetAttribute("Tester", true) end
	if not Testing.Active() then
		print(`[Access] no {Testing.Phase} gate on this server (Studio, or Testing.Enabled is off): {player.Name} walks in`)
		player:SetAttribute("Access", "Open")
		return true
	end
	player:SetAttribute("Access", "Checking")
	local isStaff = staff(player)
	-- (the Studio NeedGroup preview plays a tester who isn't in the group yet)
	-- (an open test lets anyone in - they just need the group)
	local listed = Testing.IsTester(player.UserId) or Testing.Open or (RunService:IsStudio() and PREVIEW_RESULT == "NeedGroup")
	print(`[Access] {player.Name} ({player.UserId}): tester={listed} staff={isStaff}`)
	if not isStaff and (not listed or PREVIEW_RESULT == "Denied") then
		player:SetAttribute("Access", "Denied")
		warn(`[Access] {player.Name} ({player.UserId}) is not a {Testing.Phase} tester - kicking`)
		if not RunService:IsStudio() then
			task.delay(DENY_GRACE, function() if player.Parent then player:Kick(KICK_DENIED) end end)
		end
		return false
	end
	if isStaff or inGroup(player) then
		player:SetAttribute("Access", "Granted")
		return true
	end
	player:SetAttribute("Access", "NeedGroup")
	local t0 = os.clock()
	while player.Parent and player:GetAttribute("Access") == "NeedGroup" do
		if os.clock() - t0 > GROUP_WAIT then
			if not RunService:IsStudio() then player:Kick(KICK_GROUP) end
			return false
		end
		task.wait(0.5)
	end
	return player.Parent ~= nil and player:GetAttribute("Access") == "Granted"
end

--------------------------------------------------------------------------------
-- the profile card: everything about a player in this game (the headline is the best boss they've knocked out)
--------------------------------------------------------------------------------
local function eraName(id: string?): string
	local e = id and Config.Era(id)
	return e and e.Name or ""
end

local function card(target: Player)
	local profile = Data.Peek(target)
	if not profile then return nil end
	-- every boss beaten, hardest first (boss power x the best tier cleared)
	local bosses = {}
	for id, rec in pairs(profile.Bosses or {}) do
		local b = Config.Bosses[id]
		if b and (rec.Best or 0) >= 1 then
			local tier = Config.BossTier(rec.Best)
			table.insert(bosses, {
				Id = id, Name = b.Name, Species = b.Species, Era = eraName(b.Era), Color = b.Color,
				Tier = tier.Name, TierIndex = rec.Best, Clears = rec.Clears or 0, BestTime = rec.BestTime,
				Score = b.Power * tier.Power,
			})
		end
	end
	table.sort(bosses, function(a, b) return a.Score > b.Score end)
	local bossTotal = 0
	for _ in pairs(Config.Bosses) do bossTotal += 1 end
	-- the dinos: rarest (rarity, then weight) and heaviest
	local rarest, heaviest
	for _, d in ipairs(profile.Dinos or {}) do
		local r = Config.Rarity[d.Rarity]
		local order = r and r.Order or 0
		if not rarest or order > rarest.Order or (order == rarest.Order and (d.KG or 0) > (rarest.KG or 0)) then
			rarest = { Species = d.Species, Rarity = d.Rarity, KG = d.KG, Order = order }
		end
		if not heaviest or (d.KG or 0) > (heaviest.KG or 0) then heaviest = { Species = d.Species, Rarity = d.Rarity, KG = d.KG } end
	end
	local index = 0
	for _ in pairs(profile.Index or {}) do index += 1 end
	local eras, erasBuilt = 0, 0
	for _, e in ipairs(Config.Eras) do
		if e.Built then
			erasBuilt += 1
			if profile.Unlocked and profile.Unlocked[e.Id] then eras += 1 end
		end
	end
	local buddies = {}
	for _, d in ipairs(Dinos.BuddyList(profile)) do table.insert(buddies, { Species = d.Species, Rarity = d.Rarity }) end
	local gear = profile.Gear or {}
	local launcher = Config.Launchers[gear.Launcher or ""]
	local armor = Config.Armors[gear.Armor or ""]
	local rover = Config.Vehicles[gear.Vehicle or ""]
	return {
		UserId = target.UserId, Name = target.Name, DisplayName = target.DisplayName,
		Tester = target:GetAttribute("Tester") == true, Dev = target:GetAttribute("Dev") == true,
		BestBoss = bosses[1], Bosses = bosses, BossTotal = bossTotal,
		Power = Config.PowerOf(profile, Dinos.BuddyList(profile)),
		Earned = profile.Earned or 0, Rate = Dinos.Rate(profile, target), Stars = profile.Stars or 0,
		DinoCount = #(profile.Dinos or {}), EggCount = #(profile.Eggs or {}), Index = index,
		Rarest = rarest, Heaviest = heaviest, Buddies = buddies,
		Eras = eras, ErasBuilt = erasBuilt, Era = eraName(profile.Era),
		Launcher = launcher and launcher.Name or "", LauncherLvl = gear.LauncherLvl or 1,
		TrainerLvl = Config.TrainerLevel(profile), TrainPower = profile.TrainPower or 0, -- (the power trainer, 2026-10-14)
		Armor = armor and armor.Name or "", ArmorLvl = gear.ArmorLvl or 1,
		Rover = rover and rover.Name or "", RoverLvl = gear.RoverLvl or 1,
		Stats = profile.Stats or {},
	}
end

function Access.Start(deps)
	Net, Data, Dinos = deps.Net, deps.Data, deps.Dinos
	-- the JOIN button was pressed: look the membership up live and let them in
	local lastCheck = {} :: { [Player]: number }
	Net.On("AccessRecheck", function(player)
		if player:GetAttribute("Access") ~= "NeedGroup" then return { Ok = true, Access = player:GetAttribute("Access") } end
		if lastCheck[player] and os.clock() - lastCheck[player] < 1.5 then return { Ok = false, Access = "NeedGroup" } end
		lastCheck[player] = os.clock()
		if inGroup(player, true) then player:SetAttribute("Access", "Granted") end
		return { Ok = true, Access = player:GetAttribute("Access") }
	end)
	Net.On("PlayerCard", function(player, args)
		local target = typeof(args.UserId) == "number" and Players:GetPlayerByUserId(args.UserId) or nil
		if not target then return { Ok = false, Err = "THEY LEFT" } end
		local c = card(target)
		if not c then return { Ok = false, Err = "STILL LOADING" } end
		return { Ok = true, Card = c }
	end)
	Players.PlayerRemoving:Connect(function(p) lastCheck[p] = nil end)
end

return Access
