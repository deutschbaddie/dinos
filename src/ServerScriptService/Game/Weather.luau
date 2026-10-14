--[[
	Weather — the server's sky (2026-10-14; numbers: ReplicatedStorage Game/WorldEvents.luau, drawn by WeatherView).

	  A new weather every WorldEvents.Switch seconds, never the same twice running. The DinoExpedition folder
	  carries Weather / WeatherPrev / WeatherAt / WeatherNext, so every client (late joiners too) draws the same
	  sky and fades it in from the same moment.
	  "Weather" { Id, Prev, At, Next, T } to everyone when it changes (the toast); "Lightning" { Seed, T } to
	  everyone on each strike in a thunderstorm (each client puts the bolt somewhere in its own sky).
	  A THUNDERSTORM is STORM LUCK (Boosts source "Storm").
	  Weather.Set(id, by?) - Settings > ADMIN (the WEATHER button steps through them).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldEvents = require(ReplicatedStorage.DinoExpedition.Game.WorldEvents)

local Weather = {}
local Net
local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local rng = Random.new()

local state = { Id = "Clear", Prev = "Clear", At = 0, Next = 0 }

function Weather.Current(): string
	return state.Id
end

-- has the current weather finished rolling in
local function settled(): boolean
	return os.time() - state.At >= WorldEvents.Fade
end

local function publish(announce: boolean)
	Shared:SetAttribute("WeatherPrev", state.Prev)
	Shared:SetAttribute("WeatherAt", state.At)
	Shared:SetAttribute("WeatherNext", state.Next)
	Shared:SetAttribute("Weather", state.Id) -- (last: a client watching this one reads the rest already set)
	if announce then
		Net.FireAll("Weather", { Id = state.Id, Prev = state.Prev, At = state.At, Next = state.Next, T = os.time() })
	end
end

local function pushBoosts()
	pcall(function()
		local Boosts = require(script.Parent.Boosts) :: any
		for _, p in ipairs(Players:GetPlayers()) do Boosts.Push(p) end
	end)
end

-- id: a WorldEvents.Weathers key. fresh: start the clock now (fades in); otherwise it's already here
local function set(id: string, fresh: boolean)
	local now = os.time()
	state.Prev = fresh and state.Id or id
	state.Id = id
	state.At = fresh and now or (now - WorldEvents.Fade)
	state.Next = now + rng:NextInteger(WorldEvents.Switch[1], WorldEvents.Switch[2])
	publish(fresh)
	pushBoosts()
end

-- Settings > ADMIN: a named weather, or nil = the next one in WorldEvents.Order
function Weather.Set(id: string?): (boolean, string)
	if id == nil then
		local i = table.find(WorldEvents.Order, state.Id) or 0
		id = WorldEvents.Order[i % #WorldEvents.Order + 1]
	end
	local w = WorldEvents.Weathers[id :: string]
	if not w then return false, "NO SUCH WEATHER" end
	set(id :: string, true)
	return true, "WEATHER: " .. w.Name
end

function Weather.Start(deps)
	Net = deps.Net
	-- a server opens on any weather, already in place
	set(WorldEvents.PickWeather(rng:NextNumber(), nil), false)
	pcall(function()
		local Boosts = require(script.Parent.Boosts) :: any
		Boosts.AddSource("Storm", function()
			local w = WorldEvents.Weathers[state.Id]
			if not (w and w.Luck and settled()) then return nil end
			return { Luck = w.Luck, Name = "STORM LUCK", Icon = "Bolt", Color = "Purple", Ends = state.Next }
		end)
	end)
	task.spawn(function()
		local nextBolt = 0
		local wasSettled = true
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				local now = os.time()
				if now >= state.Next then
					set(WorldEvents.PickWeather(rng:NextNumber(), state.Id), true)
					wasSettled = false
					return
				end
				-- (STORM LUCK starts once the storm is really here)
				local s = settled()
				if s and not wasSettled then pushBoosts() end
				wasSettled = s
				if state.Id == "Storm" and os.clock() >= nextBolt and now - state.At >= WorldEvents.Fade * 0.6 then
					nextBolt = os.clock() + rng:NextNumber(WorldEvents.Bolt[1], WorldEvents.Bolt[2])
					Net.FireAll("Lightning", { Seed = rng:NextInteger(1, 2 ^ 30), T = now })
				end
			end)
			if not ok then warn("[Weather] tick failed: " .. tostring(err)) end
		end
	end)
end

return Weather
