--[[
	Quests — optional NPC conversations, story + side quests, and the daily chest in the hub.

	Talk(npc) answers with what that NPC has to say right now:
	  TurnIn  a quest you finished for them (claim the reward in person)
	  Offer   the next story step (Professor / Mechanic) or a side quest (Ranger / Egg Keeper)
	  Chat    a friendly line when they have nothing for you
	Progress(kind, data) is called by every system (hatching, encounters, bosses, crafting) and ticks
	matching active quests. The game is fully playable without ever accepting one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Quests = {}
local Analytics = require(script.Parent.Analytics)
local Data, Net, Dinos

local CHAT = {
	Professor = { "The Time Gate hums a little louder every day. Exciting, isn't it?", "Every egg is a little time capsule. Treat them gently!", "I once saw a SECRET hatch. I didn't sleep for a week." },
	Mechanic = { "Bring me boss parts. I'll stitch you armor that laughs at teeth.", "Every boss drops parts. Bring them here and I'll make you tougher.", "Want more power? Hit your trainer. Want to SURVIVE? That's me." },
	EggKeeper = { "Warm incubators make happy eggs.", "Heavier dinos earn more. Science!", "Rare eggs take longer. Good things wait." },
	Ranger = { "Keep your head down out there. These dinos don't like visitors.", "Knock one out and the nest is all yours.", "Dodge when you see the red on the ground!" },
}

local function goalMatches(goal, kind: string, data): boolean
	if goal.Kind ~= kind then return false end
	if goal.Site and goal.Site ~= data.Site then return false end
	if goal.Boss and goal.Boss ~= data.Boss then return false end
	-- (TITAN FORGED wants Titan scales in the craft: a flare made of Rex claws doesn't count)
	if goal.Mat and not (typeof(data.Mats) == "table" and (tonumber(data.Mats[goal.Mat]) or 0) > 0) then return false end
	if goal.Rarity then
		local need = Config.Rarity[goal.Rarity].Order
		local got = data.Rarity and Config.Rarity[data.Rarity] and Config.Rarity[data.Rarity].Order or 0
		if got < need then return false end
	end
	return true
end

local function sideList(npc: string)
	return Config.SideQuests[npc]
end

-- what a goal means, said the way the NPC would say it: what to do, and where (2026-10-13, user: "make the npcs
-- explain better - they say what the quest is and everything")
local function eraName(id: string?): string
	local e = id and Config.Era(id)
	return e and (e :: any).Name or "the eras"
end
local function howTo(g): string
	local n = g.Count or 1
	local k = g.Kind
	if k == "Expedition" then
		return "Drive your rover through the Time Gate, grab an egg from a nest and make it back out the portal."
	elseif k == "Takedown" then
		return string.format("Knock out %d dino%s - dart them until they drop. Any nest in any era counts.", n, n == 1 and "" or "s")
	elseif k == "Eggs" then
		return string.format("Bring home %d egg%s from the nests. They count once you're back through the portal.", n, n == 1 and "" or "s")
	elseif k == "Escape" then
		return string.format("Get away %d time%s - eggs on your rack, the pack on your tail, all the way to the portal.", n, n == 1 and "" or "s")
	elseif k == "Hatch" then
		return string.format("Hatch %d egg%s in the incubators on your island.", n, n == 1 and "" or "s")
	elseif k == "Rarity" then
		local r = Config.Rarity[g.Rarity or "Rare"]
		return string.format("Hatch a %s dino or better. Eggs from knocked-out dinos and bosses come out rarer.", r and string.upper(r.Name) or "RARE")
	elseif k == "Craft" then
		local m = g.Mat and Config.Materials[g.Mat]
		local b = m and Config.Bosses[m.Boss]
		if m and b then
			return string.format("Beat the %s in %s for its %s, then craft new gear with it at the Armorer.", b.Name, eraName(b.Era), m.Name)
		end
		return "Craft new gear at the Armorer."
	elseif k == "Boss" then
		local b = g.Boss and Config.Bosses[g.Boss]
		if b then
			return string.format("Knock out the %s in %s. It wakes for everyone every 10 minutes - or use a Boss Key at the Time Gate.", b.Name, eraName(b.Era))
		end
	end
	return "Do it and come back to me."
end
Quests.HowTo = howTo
local function payLine(q): string
	local c = q.Reward and q.Reward.Coins or 0
	return c > 0 and string.format("I'll pay you %s coins.", Config.FormatNumber(c)) or ""
end

local function nextOffer(profile, npc: string)
	-- story first: the current step, if this NPC gives it and it isn't already active
	local step = Config.Story[profile.Quests.Story]
	if step and step.Npc == npc then
		for _, q in ipairs(profile.Quests.Active) do if q.Id == step.Id then return nil end end
		return { Id = step.Id, Npc = npc, Title = step.Title, Goal = step.Goal, Reward = step.Reward, Story = true,
			Text = step.Text .. " " .. howTo(step.Goal) }
	end
	local list = sideList(npc)
	if not list then return nil end
	for _, q in ipairs(profile.Quests.Active) do if q.Npc == npc then return nil end end -- one side quest per NPC at a time
	local i = ((profile.Quests.Side[npc] or 0) % #list) + 1
	local q = list[i]
	return { Id = npc .. "_" .. i, Npc = npc, Title = q.Title, Goal = q.Goal, Reward = q.Reward, Index = i,
		Text = string.format("Got a job for you. %s %s Deal?", howTo(q.Goal), payLine(q)) }
end

function Quests.Talk(player: Player, npc: string)
	local profile = Data.Peek(player)
	if not profile or not CHAT[npc] then return { Ok = false } end
	for _, q in ipairs(profile.Quests.Active) do
		if q.Npc == npc and (q.Progress or 0) >= q.Goal.Count then
			return { Ok = true, Type = "TurnIn", Quest = q, Text = "You did it! Here's what I promised." }
		end
	end
	local offer = nextOffer(profile, npc)
	if offer and #profile.Quests.Active < Config.MaxQuests then
		return { Ok = true, Type = "Offer", Quest = offer, Text = offer.Text }
	end
	-- one of mine still going: where you're at, and the how-to again
	for _, q in ipairs(profile.Quests.Active) do
		if q.Npc == npc then
			local done, need = q.Progress or 0, q.Goal.Count or 1
			return { Ok = true, Type = "Progress", Quest = q,
				Text = string.format("%s - %d of %d so far. %s", q.Title, done, need, howTo(q.Goal)) }
		end
	end
	local lines = CHAT[npc]
	return { Ok = true, Type = "Chat", Text = lines[math.random(1, #lines)] }
end

-- a story step you've already done before taking it on (beat that boss, crafted with that boss's material)
-- starts complete: it used to need doing again, and a claw craft could stall the story with no claws left
local function alreadyDone(profile, q): boolean
	local g = q.Goal or {}
	if g.Kind == "Boss" and g.Boss then
		local rec = profile.Bosses and profile.Bosses[g.Boss]
		return rec ~= nil and (rec.Best or 0) >= 1
	end
	if g.Kind == "Craft" and g.Mat then
		local gear = profile.Gear or {}
		local function uses(t) return t and t.Craft and t.Craft.Mats and t.Craft.Mats[g.Mat] ~= nil end
		for id, info in pairs(Config.Launchers) do if (gear.Launchers or {})[id] and uses(info) then return true end end
		for id, info in pairs(Config.Armors) do if (gear.Armors or {})[id] and uses(info) then return true end end
		for id, info in pairs(Config.Gadgets or {}) do if (gear.GadgetsOwned or {})[id] and uses(info) then return true end end
		if gear.Plating and uses(Config.Plating) then return true end
	end
	return false
end

function Quests.Accept(player: Player, npc: string)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	if #profile.Quests.Active >= Config.MaxQuests then return { Ok = false, Err = "YOU ALREADY HAVE 3 QUESTS" } end
	local offer = nextOffer(profile, npc)
	if not offer then return { Ok = false, Err = "NOTHING TO ACCEPT" } end
	offer.Progress = alreadyDone(profile, offer) and offer.Goal.Count or 0
	offer.Text = nil
	table.insert(profile.Quests.Active, offer)
	Data.Changed(player)
	return { Ok = true, Quest = offer }
end

function Quests.Abandon(player: Player, id: string)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	for i, q in ipairs(profile.Quests.Active) do
		if q.Id == id then table.remove(profile.Quests.Active, i) Data.Changed(player) return { Ok = true } end
	end
	return { Ok = false }
end

function Quests.TurnIn(player: Player, npc: string)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	for i, q in ipairs(profile.Quests.Active) do
		if q.Npc == npc and (q.Progress or 0) >= q.Goal.Count then
			table.remove(profile.Quests.Active, i)
			local coins = q.Reward.Coins or 0
			if not q.Story then
				-- side quests pay in the money of the furthest era you've opened
				local tier = 1
				for era in pairs(profile.Unlocked or {}) do tier = math.max(tier, Config.EraTier(era)) end
				coins *= tier
			end
			profile.Coins += coins
			profile.Earned += coins
			Analytics.Coins(player, "Source", coins, q.Story and "Onboarding" or "Gameplay", q.Story and "StoryQuest" or "SideQuest")
			if q.Story then
				profile.Quests.Story += 1
			elseif q.Index then
				profile.Quests.Side[npc] = q.Index
			end
			Data.Changed(player)
			return { Ok = true, Quest = q, Coins = coins }
		end
	end
	return { Ok = false, Err = "NOTHING TO HAND IN" }
end

function Quests.Progress(player: Player, kind: string, data)
	local profile = Data.Peek(player)
	if not profile then return end
	Analytics.OnProgress(player, kind, data) -- (the funnels read hatches, eggs, trips home and bosses from here)
	local changed = false
	for _, q in ipairs(profile.Quests.Active) do
		if (q.Progress or 0) < q.Goal.Count and goalMatches(q.Goal, kind, data or {}) then
			q.Progress = math.min(q.Goal.Count, (q.Progress or 0) + ((data and data.Count) or 1))
			changed = true
			if q.Progress >= q.Goal.Count then
				Net.Fire(player, "QuestDone", { Id = q.Id, Title = q.Title, Npc = q.Npc })
			end
		end
	end
	if changed then Data.Changed(player) end
end

--------------------------------------------------------------------------------
-- daily chest: walk up and open it in the hub; a streak makes each day's chest bigger
--------------------------------------------------------------------------------
function Quests.OpenChest(player: Player)
	if Config.Daily.Enabled == false then return { Ok = false } end
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local now = os.time()
	local d = profile.Daily
	if now - (d.Last or 0) < Config.Daily.Every then
		return { Ok = false, Err = "NEXT CHEST IN " .. Config.FormatTime(Config.Daily.Every - (now - d.Last)) }
	end
	if now - (d.Last or 0) > Config.Daily.Reset then d.Streak = 0 end
	d.Streak = (d.Streak % #Config.Daily.Coins) + 1
	d.Last = now
	local coins = Config.Daily.Coins[d.Streak]
	profile.Coins += coins
	profile.Earned += coins
	local egg = nil
	if Config.Daily.EggOn[d.Streak] then
		local pool = {}
		for id in pairs(profile.Unlocked) do
			for sp, info in pairs(Config.Species) do if info.Era == id and not info.Boss then table.insert(pool, sp) end end
		end
		if #pool > 0 then egg = Dinos.AddEgg(player, pool[math.random(1, #pool)], nil, d.Streak == 7 and 2 or 1) end
	end
	Data.Changed(player)
	return { Ok = true, Coins = coins, Egg = egg, Streak = d.Streak }
end

function Quests.Start(deps)
	Data, Net, Dinos = deps.Data, deps.Net, deps.Dinos
	-- the daily chest is off for now: its prop (and its prompt) leave the plaza
	if Config.Daily.Enabled == false then
		task.spawn(function()
			local camp = workspace:WaitForChild("BaseCamp", 30)
			for _, d in ipairs(camp and camp:GetDescendants() or {}) do
				if d.Name == "DailyChest" or d.Name == "ChestPromptHost" then d:Destroy() end
			end
		end)
	end
	Net.On("Talk", function(player, args) return typeof(args.Npc) == "string" and Quests.Talk(player, args.Npc) or { Ok = false } end)
	Net.On("AcceptQuest", function(player, args) return typeof(args.Npc) == "string" and Quests.Accept(player, args.Npc) or { Ok = false } end)
	Net.On("AbandonQuest", function(player, args) return typeof(args.Id) == "string" and Quests.Abandon(player, args.Id) or { Ok = false } end)
	Net.On("TurnIn", function(player, args) return typeof(args.Npc) == "string" and Quests.TurnIn(player, args.Npc) or { Ok = false } end)
	Net.On("OpenChest", function(player) return Quests.OpenChest(player) end)
end

return Quests
