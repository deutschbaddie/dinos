--[[
	Quiz — GUESS THE DINO, the little game you play while you train on your power trainer's pad (2026-10-14).
	Client: Game/DinoQuiz.luau (opened from TrainerView's button on the pad).

	The server decides everything: it picks the dino and the four names, keeps the answer, judges the pick and pays
	the power. The client only ever learns which species to show (it has to draw it) and the names on the buttons.

	  QuizStart   { } -> { Ok, Q }                     only on your own trainer pad. An unanswered question comes back
	                                                    (closing can't skip a hard one) and the streak survives a short
	                                                    break (KEEP seconds).
	  QuizAnswer  { Id, Pick = species } -> { Ok, Correct, Answer, Gain, Capped, Streak, Best, Next = Q }
	              Errors: "TOO FAST" (the question stays open), "OFFPAD", "OLD QUESTION".

	Q = { Id, Species, Options = { species x4 }, Tier, Silhouette, Streak, Best }

	Difficulty follows the streak (TIERS): easy rounds use very different dinos as the wrong names, then lookalikes
	(GROUPS) creep in, then the dino is shown as an all-black SHADOW.

	Reward: Trainer.AddPower(player, n, "Quiz") with n = Trainer.PerSec(player) x (REWARD_BASE + REWARD_STEP per
	streak, at most REWARD_MAX) seconds of training. Both functions are the trainer's; if either is missing (or
	throws) the round still plays, it just pays nothing.

	Anti-abuse: your own pad only (Trainer.OnPad if it exists, else your island's TrainerPad); question ids are random
	GUIDs and single-use; at least MIN_ANSWER seconds per question; at most PER_MINUTE paid answers in any 60 s
	(the window survives closing and reopening). The 0.15 s per-request limit in Net stacks on top.

	Bosses stay secret: a boss species (Config.Species[x].Boss) and the Primal Rex are only ever shown once you know
	them (an Index entry or one in your yard).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Quiz = {}
local Data, Net, Plots

-- tuning ----------------------------------------------------------------------------------------------------------
local MIN_ANSWER = 1.5 -- seconds a question must be open before it can be answered
local PER_MINUTE = 12 -- paid answers in any 60 s (more still play, they just pay nothing; honest play is ~10-14 a minute)
local KEEP = 90 -- seconds a closed quiz keeps its streak and its open question
local REWARD_BASE, REWARD_STEP, REWARD_MAX = 15, 1, 30 -- seconds of training per correct answer (+1 per streak)
-- { from streak, lookalike wrong names, shadow }
local TIERS = {
	{ 0, 0, false }, -- WHO'S THAT DINO?
	{ 3, 1, false }, -- TRICKY ONES
	{ 6, 2, true }, -- SHADOW ROUND
	{ 10, 3, true }, -- SHADOW MASTER
}
-- dinos that look alike: a lookalike is a dino sharing any group
local GROUPS = {
	{ "TyrannosaurusRex", "Giganotosaurus", "Carnotaurus", "Yutyrannus", "PrimalRex", "Spinosaurus", "Dilophosaurus" }, -- big biters
	{ "Velociraptor", "Microraptor", "Compy", "Coelophysis", "Oviraptor", "Gallimimus", "Dilophosaurus" }, -- small runners
	{ "Triceratops", "Protoceratops", "Psittacosaurus", "Ankylosaurus", "Stegosaurus" }, -- frills, plates and clubs
	{ "Brachiosaurus", "Plateosaurus", "Parasaurolophus", "Therizinosaurus" }, -- long necks and grazers
	{ "Sarcosuchus", "Postosuchus", "Mosasaurus", "Spinosaurus" }, -- crocs and swimmers
	{ "Gallimimus", "Therizinosaurus", "Oviraptor" }, -- beaks and feathers
}
--------------------------------------------------------------------------------------------------------------------

local lookalike = {} :: { [string]: { [string]: boolean } }
for _, g in ipairs(GROUPS) do
	for _, a in ipairs(g) do
		lookalike[a] = lookalike[a] or {}
		for _, b in ipairs(g) do
			if a ~= b then lookalike[a][b] = true end
		end
	end
end

local rng = Random.new()
local sessions = {} :: { [Player]: any } -- { Streak, Q, Recent, Seen }
local paid = {} :: { [Player]: { number } } -- os.clock() of each paid answer (the per-minute window)

-- the trainer module (another agent's, loaded on first use: it may not exist yet on an older build)
local trainerMod: any = nil
local function trainer(): any
	if trainerMod then return trainerMod end
	local m = script.Parent:FindFirstChild("Trainer")
	if not (m and m:IsA("ModuleScript")) then return nil end
	local ok, t = pcall(require, m)
	if ok and type(t) == "table" then trainerMod = t end
	return trainerMod
end

-- YOUR trainer pad: the trainer's PadOf (the machine standing on your island), else any TrainerPad on your plot
local function padOf(player: Player): BasePart?
	local t = trainer()
	if t and type(t.PadOf) == "function" then
		local ok, pad = pcall(t.PadOf, player)
		if ok and typeof(pad) == "Instance" and pad:IsA("BasePart") then return pad end
	end
	local plot = Plots and Plots.Get(player)
	local pad = plot and plot:FindFirstChild("TrainerPad", true)
	return (pad and pad:IsA("BasePart")) and pad or nil
end

-- standing on it: the trainer's own answer if it ever has one (OnPad), else the trainer's pad rule (flat distance
-- Config.Trainer.PadRadius, PadHeight above), with a little slack so a wobble on the rim doesn't end a round
local function onPad(player: Player): boolean
	local t = trainer()
	if t and type(t.OnPad) == "function" then
		local ok, on = pcall(t.OnPad, player)
		if ok and type(on) == "boolean" then return on end
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hrp:IsA("BasePart")) or not hum or hum.Health <= 0 then return false end
	local pad = padOf(player)
	if not pad then return false end
	local cfg = (Config :: any).Trainer
	local radius = (cfg and tonumber(cfg.PadRadius)) or math.max(pad.Size.X, pad.Size.Z) / 2
	local height = (cfg and tonumber(cfg.PadHeight)) or 7
	local d = hrp.Position - pad.Position
	return Vector3.new(d.X, 0, d.Z).Magnitude <= radius + 1.5 and d.Y > -2 and d.Y < height + 1
end

-- you know this dino: it's in your Index or your yard
local function knows(profile, species: string): boolean
	local prefix = species .. ":"
	for key in pairs(typeof(profile.Index) == "table" and profile.Index or {}) do
		if type(key) == "string" and key:sub(1, #prefix) == prefix then return true end
	end
	for _, d in pairs(typeof(profile.Dinos) == "table" and profile.Dinos or {}) do
		if typeof(d) == "table" and d.Species == species then return true end
	end
	return false
end

-- every species this player may be shown: it has a model, and a boss (or the Primal Rex) only once they know it
local function pool(profile): { string }
	local folder = ReplicatedStorage.DinoExpedition:FindFirstChild("Dinosaurs")
	local list = {}
	for _, id in ipairs(Config.SpeciesOrder) do
		local sp = Config.Species[id]
		if sp and folder and folder:FindFirstChild(id) then
			local secret = sp.Boss == true or id == "PrimalRex"
			if not secret or knows(profile, id) then table.insert(list, id) end
		end
	end
	return list
end

local function shuffle<T>(list: { T }): { T }
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function tierFor(streak: number): number
	local tier = 1
	for i, t in ipairs(TIERS) do
		if streak >= t[1] then tier = i end
	end
	return tier
end

local function bestOf(profile): number
	return typeof(profile.Stats) == "table" and tonumber(profile.Stats.QuizBest) or 0
end

-- what the client sees of a question (never which name is right)
local function view(s, q, profile)
	return {
		Id = q.Id, Species = q.Species, Options = table.clone(q.Options), Tier = q.Tier, Silhouette = TIERS[q.Tier][3],
		Streak = s.Streak, Best = bestOf(profile),
	}
end

local function newQuestion(s, profile)
	local all = pool(profile)
	if #all < 4 then return nil end
	-- a dino you haven't just seen (the last few answers sit out)
	local fresh = {}
	for _, id in ipairs(all) do
		if not table.find(s.Recent, id) then table.insert(fresh, id) end
	end
	if #fresh == 0 then fresh = all end
	local answer = fresh[rng:NextInteger(1, #fresh)]
	table.insert(s.Recent, answer)
	while #s.Recent > math.min(6, #all - 1) do table.remove(s.Recent, 1) end

	local tier = tierFor(s.Streak)
	local wantAlike = TIERS[tier][2]
	local alike, other = {}, {}
	for _, id in ipairs(all) do
		if id ~= answer then
			if lookalike[answer] and lookalike[answer][id] then table.insert(alike, id) else table.insert(other, id) end
		end
	end
	shuffle(alike)
	shuffle(other)
	-- exactly the tier's number of lookalikes, then very different dinos, then (a tiny pool) any lookalike left
	local options = { answer }
	for i = 1, math.min(wantAlike, #alike) do table.insert(options, alike[i]) end
	for _, list in ipairs({ other, alike }) do
		for _, id in ipairs(list) do
			if #options >= 4 then break end
			if not table.find(options, id) then table.insert(options, id) end
		end
	end
	shuffle(options)
	s.Q = { Id = HttpService:GenerateGUID(false), Species = answer, Options = options, Tier = tier, At = os.clock() }
	return view(s, s.Q, profile)
end

-- pay a correct answer: seconds of this player's own training, growing a little with the streak
local function reward(player: Player, streak: number): number
	local t = trainer()
	if not (t and type(t.PerSec) == "function" and type(t.AddPower) == "function") then return 0 end
	local ok, per = pcall(t.PerSec, player)
	per = ok and tonumber(per) or 0
	if not (per > 0 and per < math.huge) then return 0 end
	local secs = math.min(REWARD_BASE + REWARD_STEP * math.max(0, streak - 1), REWARD_MAX)
	local amount = math.max(1, math.floor(per * secs))
	local okAdd, res = pcall(t.AddPower, player, amount, "Quiz")
	if not okAdd then
		warn(`[Quiz] Trainer.AddPower failed for {player.Name}: {res}`)
		return 0
	end
	if res == false then return 0 end
	return (type(res) == "number" and res == res and res >= 0) and math.floor(res) or amount
end

local function session(player: Player)
	local s = sessions[player]
	if not s or os.clock() - s.Seen > KEEP then
		s = { Streak = 0, Q = nil, Recent = {}, Seen = os.clock() }
		sessions[player] = s
	end
	s.Seen = os.clock()
	return s
end

local function onStart(player: Player)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false, Err = "LOADING..." } end
	if not onPad(player) then return { Ok = false, Err = "STAND ON YOUR TRAINER PAD" } end
	local s = session(player)
	if s.Q then return { Ok = true, Q = view(s, s.Q, profile) } end
	local q = newQuestion(s, profile)
	if not q then return { Ok = false, Err = "NO DINOS TO GUESS YET" } end
	return { Ok = true, Q = q }
end

local function onAnswer(player: Player, args)
	local profile = Data.Peek(player)
	local s = sessions[player]
	local q = s and s.Q
	if not (profile and q) or typeof(args.Id) ~= "string" or args.Id ~= q.Id then return { Ok = false, Err = "OLD QUESTION" } end
	if typeof(args.Pick) ~= "string" or not table.find(q.Options, args.Pick) then return { Ok = false, Err = "bad pick" } end
	if os.clock() - q.At < MIN_ANSWER then return { Ok = false, Err = "TOO FAST" } end
	if not onPad(player) then return { Ok = false, Err = "OFFPAD" } end
	s.Q = nil -- single use: this id never pays again
	s.Seen = os.clock()

	local correct = args.Pick == q.Species
	local gain, capped = 0, false
	if correct then
		s.Streak += 1
		-- the best streak ever, kept on the profile (the client shows BEST; saved with the rest of Stats)
		local newBest = typeof(profile.Stats) == "table" and s.Streak > bestOf(profile)
		if newBest then profile.Stats.QuizBest = s.Streak end
		local log = paid[player] or {}
		paid[player] = log
		local now = os.clock()
		while log[1] and now - log[1] > 60 do table.remove(log, 1) end
		if #log >= PER_MINUTE then
			capped = true
		else
			gain = reward(player, s.Streak)
			if gain > 0 then table.insert(log, now) end
		end
		-- (AddPower already pushed the profile when it paid)
		if newBest and gain <= 0 then Data.Changed(player) end
	else
		s.Streak = 0
	end
	return {
		Ok = true, Correct = correct, Answer = q.Species, Gain = gain, Capped = capped,
		Streak = s.Streak, Best = bestOf(profile), Next = newQuestion(s, profile),
	}
end

function Quiz.Start(deps)
	Data, Net, Plots = deps.Data, deps.Net, deps.Plots
	Net.On("QuizStart", onStart)
	Net.On("QuizAnswer", onAnswer)
	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
		paid[p] = nil
	end)
end

return Quiz
