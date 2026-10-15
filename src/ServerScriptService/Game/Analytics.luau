--[[
	Analytics — what the Creator Dashboard (Analytics > Funnels / Economy / Progression) shows (2026-10-15).
	Everything goes through AnalyticsService, server side, wrapped so a failed call never breaks the game.

	ONBOARDING FUNNEL (each new player once, in order - where do new players drop off?):
	  1 Joined  2 FirstDrive  3 FirstTrip (through the Time Gate)  4 ArrivedInEra  5 FirstFight  6 FirstEgg
	  7 FirstTripHome  8 FirstHatch  9 FirstTraining  10 FirstBoss  11 SecondEra
	  Logged steps are remembered in profile.Flags.Funnel, so a returning player never logs one twice.
	EXPEDITION FUNNEL (every run, one funnel session each - how far does a typical run get?):
	  1 Start  2 Arrived  3 Fight  4 Egg  5 Home
	PURCHASE FUNNEL (every Robux prompt): 1 Prompted  2 Bought  (product / pass id in the step's fields)
	PROGRESSION "Eras": Start when an era opens, Complete when its boss first falls (level = the era's number)
	ECONOMY "Coins": the big sources (yard cash, expedition pay, quests, the spin, meteors, the Sightseer) and sinks
	  (gear, island, trainer levels, the Time Gate dials).
	Hooks: Quests.Progress feeds OnProgress (hatch / eggs / takedown / boss...); the rest call in directly.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Analytics = {}
local Data = nil :: any

local ONBOARDING = { "Joined", "FirstDrive", "FirstTrip", "ArrivedInEra", "FirstFight", "FirstEgg", "FirstTripHome", "FirstHatch", "FirstTraining", "FirstBoss", "SecondEra" }
local STEP = {} :: { [string]: number }
for i, n in ipairs(ONBOARDING) do STEP[n] = i end
local RUN_STEPS = { Start = 1, Arrived = 2, Fight = 3, Egg = 4, Home = 5 }

local lastWarn = -math.huge
local function safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		-- (quiet: analytics is never worth an error in the Output more than once a minute)
		local now = os.clock()
		if now - lastWarn > 60 then
			lastWarn = now
			warn("[Analytics] " .. tostring(err))
		end
	end
end

local function flags(profile)
	profile.Flags = typeof(profile.Flags) == "table" and profile.Flags or {}
	local f = profile.Flags.Funnel
	if typeof(f) ~= "table" then
		f = {}
		profile.Flags.Funnel = f
	end
	return f
end

-- an onboarding step, once per player ever
function Analytics.Onboard(player: Player, name: string)
	local step = STEP[name]
	local profile = Data and Data.Peek(player)
	if not (step and profile) then return end
	local f = flags(profile)
	if f[name] then return end
	f[name] = true
	safe(function() AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name) end)
end

-- a step of this run's funnel (once per run)
function Analytics.RunStep(player: Player, run: any, name: string)
	local step = RUN_STEPS[name]
	if not (step and typeof(run) == "table") then return end
	run.Funnel = typeof(run.Funnel) == "table" and run.Funnel or {}
	if run.Funnel[name] then return end
	run.Funnel[name] = true
	run.FunnelId = run.FunnelId or HttpService:GenerateGUID(false)
	local era = tostring(run.Zone or "?")
	safe(function() AnalyticsService:LogFunnelStepEvent(player, "Expedition", run.FunnelId, step, name, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = era }) end)
end

-- coins in or out. who: a Player, or a profile (the player is found from it). flow: "Source" | "Sink"
-- tx: one of Enum.AnalyticsEconomyTransactionType's names (Gameplay, Shop, TimedReward, Onboarding, IAP...)
function Analytics.Coins(who: any, flow: string, amount: number, tx: string, sku: string?)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 or amount ~= amount or amount == math.huge then return end
	local player: Player? = nil
	local profile = nil
	if typeof(who) == "Instance" and who:IsA("Player") then
		player = who
		profile = Data and Data.Peek(who)
	elseif typeof(who) == "table" and Data then
		profile = who
		for plr, p in pairs(Data.Profiles) do
			if p == who then player = plr break end
		end
	end
	if not (player and profile) then return end
	local balance = math.max(0, math.floor(tonumber(profile.Coins) or 0))
	safe(function()
		AnalyticsService:LogEconomyEvent(player, flow == "Sink" and Enum.AnalyticsEconomyFlowType.Sink or Enum.AnalyticsEconomyFlowType.Source,
			"Coins", amount, balance, tx, sku)
	end)
end

local function eraIndex(eraId: string): number
	for i, e in ipairs(Config.Eras) do if e.Id == eraId then return i end end
	return 0
end

-- an era opened (the Time Gate dial bought)
function Analytics.EraOpened(player: Player, eraId: string)
	local i = eraIndex(eraId)
	if i <= 0 then return end
	safe(function() AnalyticsService:LogProgressionStartEvent(player, "Eras", i, eraId) end)
	if i == 2 then Analytics.Onboard(player, "SecondEra") end
end

-- Quests.Progress sees every hatch, egg, takedown, escape, trip home and boss: the funnels read it from there
function Analytics.OnProgress(player: Player, kind: string, data: any)
	if kind == "Hatch" then
		Analytics.Onboard(player, "FirstHatch")
	elseif kind == "Eggs" then
		Analytics.Onboard(player, "FirstEgg")
		local okE, Expedition = pcall(function() return require(script.Parent.Expedition) :: any end)
		local run = okE and Expedition and Expedition.Get(player)
		if run then Analytics.RunStep(player, run, "Egg") end
	elseif kind == "Expedition" then
		Analytics.Onboard(player, "FirstTripHome")
	elseif kind == "Boss" and typeof(data) == "table" and typeof(data.Boss) == "string" then
		local boss = Config.Bosses[data.Boss]
		local profile = Data and Data.Peek(player)
		if not (boss and profile) then return end
		Analytics.Onboard(player, "FirstBoss")
		local f = flags(profile)
		local key = "Era_" .. boss.Era
		if not f[key] then
			f[key] = true
			local i = eraIndex(boss.Era)
			safe(function() AnalyticsService:LogProgressionCompleteEvent(player, "Eras", i, boss.Era) end)
		end
	end
end

function Analytics.Start(deps)
	Data = deps.Data
	-- the first ever session (a fresh save: no Funnel record yet) is step 1
	local function joined(player: Player)
		task.spawn(function()
			local profile = Data.Get(player)
			if profile and player.Parent then Analytics.Onboard(player, "Joined") end
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, p in ipairs(Players:GetPlayers()) do joined(p) end
	-- every Robux prompt: shown, and bought or not
	local function purchase(player: Player?, kind: string, id: number, bought: boolean)
		if not (player and player.Parent) then return end
		local session = HttpService:GenerateGUID(false)
		local fields = { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = kind .. ":" .. tostring(id) }
		safe(function() AnalyticsService:LogFunnelStepEvent(player, "Purchase", session, 1, "Prompted", fields) end)
		if bought then
			safe(function() AnalyticsService:LogFunnelStepEvent(player, "Purchase", session, 2, "Bought", fields) end)
		end
	end
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, bought: boolean)
		purchase(Players:GetPlayerByUserId(userId), "Product", productId, bought)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, bought: boolean)
		purchase(player, "Pass", passId, bought)
	end)
end

return Analytics
