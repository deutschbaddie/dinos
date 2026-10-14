--[[
	Spin — the DAILY SPIN (2026-10-14; prizes: ReplicatedStorage Game/SpinWheel.luau, client: SpinView.luau, the wheel
	at camp: tools/gen/spinWheel.js).

	  "Spin" {}   uses your free spin if it's ready, else one bought spin. The server rolls the slice and pays it
	              before answering: { Ok, Index, Prize = { Text, Icon, Color }, Spins, NextFree }. The client turns the
	              wheel onto that slice and shows the prize when it stops (the reward is already yours).
	  profile.Spin = { NextFree = os.time() the next free spin is ready, Extra = bought spins }
	  Bought spins: Config.Products Spin1 / Spin3 / Spin10 (Monetization calls Spin.Give).
	  The big wheel at camp turns for everyone when someone spins near it ("WheelSpin" to all).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)
local SpinWheel = require(ReplicatedStorage.DinoExpedition.Game.SpinWheel)

local Spin = {}
local Data, Net, Dinos
local rng = Random.new()
local busyUntil = {} :: { [Player]: number }

local function state(profile)
	if typeof(profile.Spin) ~= "table" then profile.Spin = { NextFree = 0, Extra = 0 } end
	local sp = profile.Spin
	sp.NextFree = tonumber(sp.NextFree) or 0
	sp.Extra = math.max(0, math.floor(tonumber(sp.Extra) or 0))
	return sp
end

-- bought spins (the products)
function Spin.Give(player: Player, n: number): boolean
	local profile = Data.Peek(player)
	if not profile then return false end
	local sp = state(profile)
	sp.Extra += math.max(0, math.floor(n))
	Data.Changed(player)
	return true
end

-- the yard's coins per second, for the coin prizes (raw: no timed boosts, like offline money)
local function yardRate(player: Player, profile): number
	local ok, r = pcall(Dinos.Rate, profile, player, false, true)
	r = ok and tonumber(r) or 0
	return (r and r > 0 and r < math.huge) and r or 0
end

local function coinsFor(player: Player, profile, seg): number
	return math.max(seg.Min or 0, math.floor(yardRate(player, profile) * 60 * (seg.Minutes or 0)))
end

-- an egg from the shop's odds (Config.ShopEggRoll) of a species from your unlocked eras; it always fits
local function shopEgg(player: Player, profile, kind: string)
	local pool = Config.ShopEggSpecies(profile.Unlocked)
	if #pool == 0 then return nil end
	local species = pool[rng:NextInteger(1, #pool)]
	return Dinos.AddEgg(player, species, Config.ShopEggRoll(kind, rng:NextNumber()), nil, nil, true)
end

local function pay(player: Player, profile, seg): { Text: string, Icon: string, Color: Color3 }
	local text = seg.Name
	if seg.Kind == "Coins" then
		local c = coinsFor(player, profile, seg)
		profile.Coins += c
		profile.Earned += c
		text = "+" .. Config.FormatNumber(c) .. " COINS"
	elseif seg.Kind == "Power" then
		local got = 0
		pcall(function()
			local T = require(script.Parent.Trainer) :: any
			got = T.AddPower(player, T.PerSec(player) * (seg.Seconds or 300), "Spin") or 0
		end)
		text = "+" .. Config.FormatNumber(got) .. " POWER"
	elseif seg.Kind == "Egg" then
		local e = shopEgg(player, profile, seg.Shop or "Premium")
		local r = e and Config.Rarity[e.Rarity]
		local sp = e and Config.Species[e.Species]
		text = e and string.format("%s %s EGG!", r and r.Name or "", sp and sp.Name or "") or "AN EGG!"
	elseif seg.Kind == "Luck" then
		profile.LuckUntil = math.max(os.time(), tonumber(profile.LuckUntil) or 0) + (seg.LuckMinutes or 15) * 60
		text = "LUCK BOOST - " .. (seg.LuckMinutes or 15) .. " MIN!"
	elseif seg.Kind == "Jackpot" then
		local c = coinsFor(player, profile, seg)
		profile.Coins += c
		profile.Earned += c
		local e = shopEgg(player, profile, seg.Shop or "Epic")
		local r = e and Config.Rarity[e.Rarity]
		text = "JACKPOT!  +" .. Config.FormatNumber(c) .. " COINS + " .. (r and r.Name or "EPIC") .. " EGG"
		Net.FireOthers(player, "Announce", { Text = string.upper(player.DisplayName) .. " HIT THE JACKPOT ON THE DAILY SPIN!", Color = "Gold" })
	end
	return { Text = text, Icon = seg.Icon, Color = seg.Color }
end

-- the big wheel at camp: is this player near it?
local wheelBase: BasePart? = nil
local function nearWheel(player: Player): boolean
	if not (wheelBase and wheelBase.Parent) then
		wheelBase = nil
		local camp = Workspace:FindFirstChild("BaseCamp")
		local w = camp and camp:FindFirstChild("SpinWheel", true)
		local b = w and w:FindFirstChild("SpinBase", true)
		if b and b:IsA("BasePart") then wheelBase = b end
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return wheelBase ~= nil and hrp ~= nil and (hrp.Position - (wheelBase :: BasePart).Position).Magnitude < 60
end

local function onSpin(player: Player)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	local now = os.time()
	if (busyUntil[player] or 0) > os.clock() then return { Ok = false, Err = "THE WHEEL IS STILL SPINNING" } end
	local sp = state(profile)
	local total, free = SpinWheel.State(profile, now)
	if total <= 0 then
		local left = math.max(0, sp.NextFree - now)
		return { Ok = false, Err = string.format("NEXT FREE SPIN IN %d:%02d", left // 3600, (left % 3600) // 60), NoSpins = true }
	end
	if free then sp.NextFree = now + SpinWheel.FreeEvery else sp.Extra -= 1 end
	local index = SpinWheel.Pick(rng:NextNumber())
	local prize = pay(player, profile, SpinWheel.Segments[index])
	profile.Stats.Spins = (tonumber(profile.Stats.Spins) or 0) + 1
	busyUntil[player] = os.clock() + SpinWheel.SpinTime - 0.4
	Data.Changed(player)
	if nearWheel(player) then Net.FireAll("WheelSpin", { UserId = player.UserId, Index = index, T = now }) end
	local left = SpinWheel.State(profile, now)
	return { Ok = true, Index = index, Prize = prize, Spins = left, NextFree = sp.NextFree, UsedFree = free }
end

function Spin.Start(deps)
	Data, Net, Dinos = deps.Data, deps.Net, deps.Dinos
	Net.On("Spin", onSpin)
	Players.PlayerRemoving:Connect(function(p) busyUntil[p] = nil end)
end

return Spin
