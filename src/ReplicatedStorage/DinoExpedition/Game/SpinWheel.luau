--[[
	SpinWheel — the DAILY SPIN's prizes (2026-10-14). Shared: the server (Spin.luau) rolls and pays from these, the
	client (SpinView.luau) draws the same slices on its wheel and on the big wheel at camp (tools/gen/spinWheel.js:
	the SAME ORDER, clockwise from the top, and the same colours).

	Spins: one FREE spin every Spin.FreeEvery seconds (from your last free one), plus bought spins (profile.Spin.Extra,
	the SPIN products). Coins prizes scale with your yard (minutes of its income, never below Min), so a spin is worth
	something at every stage of the game.
]]

local SpinWheel = {}

SpinWheel.FreeEvery = 22 * 3600 -- a "daily" spin: 22 hours, so a fixed time each day never slips past you
SpinWheel.SpinTime = 5.2 -- seconds the wheel turns (the server won't take another spin from you sooner)

-- clockwise from the top. Weight = how often (out of the sum); Kind + its numbers = what it pays
SpinWheel.Segments = {
	{ Id = "CoinsS", Name = "COINS", Color = Color3.fromHex("ffd447"), Icon = "Coin", Weight = 26, Kind = "Coins", Minutes = 5, Min = 600 },
	{ Id = "Power", Name = "POWER", Color = Color3.fromHex("2fcdb4"), Icon = "Power", Weight = 18, Kind = "Power", Seconds = 300 },
	{ Id = "CoinsM", Name = "MORE COINS", Color = Color3.fromHex("ff9633"), Icon = "Coin", Weight = 18, Kind = "Coins", Minutes = 15, Min = 2000 },
	{ Id = "EraEgg", Name = "EGG", Color = Color3.fromHex("a8ed48"), Icon = "Egg", Weight = 14, Kind = "Egg", Shop = "Premium" },
	{ Id = "Jackpot", Name = "JACKPOT!", Color = Color3.fromHex("ff5252"), Icon = "Crown", Weight = 2, Kind = "Jackpot", Minutes = 60, Min = 25000, Shop = "Epic" },
	{ Id = "Luck", Name = "LUCK BOOST", Color = Color3.fromHex("ad66ff"), Icon = "Star", Weight = 10, Kind = "Luck", LuckMinutes = 15 },
	{ Id = "CoinsL", Name = "BIG COINS", Color = Color3.fromHex("ffb02e"), Icon = "Coin", Weight = 8, Kind = "Coins", Minutes = 40, Min = 6000 },
	{ Id = "RareEgg", Name = "RARE+ EGG", Color = Color3.fromHex("48a8ff"), Icon = "Egg", Weight = 4, Kind = "Egg", Shop = "Rare" },
}

-- the chance of each slice, 0..1 (the SEE ODDS line in the window)
function SpinWheel.Chance(i: number): number
	local total = 0
	for _, s in ipairs(SpinWheel.Segments) do total += s.Weight end
	local s = SpinWheel.Segments[i]
	return s and s.Weight / total or 0
end

-- a slice from a 0..1 roll
function SpinWheel.Pick(u: number): number
	local total = 0
	for _, s in ipairs(SpinWheel.Segments) do total += s.Weight end
	local x = u * total
	for i, s in ipairs(SpinWheel.Segments) do
		x -= s.Weight
		if x < 0 then return i end
	end
	return #SpinWheel.Segments
end

-- spins you can use right now (free one first), and when the next free one comes (os.time(), 0 = ready now)
function SpinWheel.State(profile, now: number): (number, boolean, number)
	local sp = profile and profile.Spin
	local nextFree = typeof(sp) == "table" and tonumber(sp.NextFree) or 0
	local extra = typeof(sp) == "table" and math.max(0, math.floor(tonumber(sp.Extra) or 0)) or 0
	local free = (nextFree or 0) <= now
	return (free and 1 or 0) + extra, free, free and 0 or (nextFree :: number)
end

return SpinWheel
