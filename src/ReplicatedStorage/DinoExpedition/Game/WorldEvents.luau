--[[
	WorldEvents — the server's WEATHER and its METEOR SHOWERS (2026-10-14; testers asked for both). Shared numbers:
	the server (ServerScriptService Game/Weather.luau, Game/Meteors.luau) runs them, the client draws them
	(WeatherView.luau, MeteorView.luau).

	WEATHER: one sky for the whole server, wherever you are (camp and every era). A new one rolls in every
	Switch seconds (10-15 min), never the same twice in a row, fading over Fade seconds. The look of each one is the
	client's (WeatherView LOOK); in the snowy Frost Forest rain falls as snow. Only a THUNDERSTORM does anything:
	STORM LUCK (x Luck) while it lasts.
	The DinoExpedition folder carries it: Weather (id), WeatherPrev (id), WeatherAt (os.time() it changed),
	WeatherNext (os.time() of the next change).

	METEOR SHOWERS: every Every minutes (the first FirstAfter minutes into a server) for Duration seconds, meteors
	streak over BASE CAMP and land around the hub and on the islands. Each leaves a glowing METEORITE: anyone can
	collect each one once (it pays coins: minutes of your yard's income). One per shower is a STAR METEORITE: an
	egg from your eras. They glow on for Linger seconds after the last one lands.
]]

local WorldEvents = {}

WorldEvents.Switch = { 600, 900 } -- seconds between weathers
WorldEvents.Fade = 25 -- seconds a new weather takes to roll in
WorldEvents.Order = { "Clear", "Rain", "Storm", "Fog", "Wind", "Hail" }
WorldEvents.Weathers = {
	Clear = { Name = "CLEAR SKIES", Weight = 38, Icon = "Star", Color = "Yellow", Line = "THE SKY CLEARS UP" },
	Rain = { Name = "RAIN", Weight = 17, Icon = "Alert", Color = "Blue", Line = "IT'S STARTING TO RAIN" },
	Storm = { Name = "THUNDERSTORM", Weight = 14, Icon = "Bolt", Color = "Purple", Line = "A THUNDERSTORM ROLLS IN", Luck = 1.2 },
	Fog = { Name = "FOG", Weight = 12, Icon = "Eye", Color = "Grey", Line = "A THICK FOG ROLLS IN" },
	Wind = { Name = "STRONG WINDS", Weight = 11, Icon = "Alert", Color = "Teal", Line = "THE WIND PICKS UP" },
	Hail = { Name = "HAILSTORM", Weight = 8, Icon = "Alert", Color = "Blue", Line = "HAIL! FIND SOME COVER" },
}
-- a lightning strike every Bolt seconds in a thunderstorm (once it has rolled in)
WorldEvents.Bolt = { 5, 13 }

-- the next weather from a 0..1 roll: weighted, never `current` again
function WorldEvents.PickWeather(u: number, current: string?): string
	local total = 0
	for _, id in ipairs(WorldEvents.Order) do
		if id ~= current then total += WorldEvents.Weathers[id].Weight end
	end
	local x = u * total
	for _, id in ipairs(WorldEvents.Order) do
		if id ~= current then
			x -= WorldEvents.Weathers[id].Weight
			if x < 0 then return id end
		end
	end
	return current == "Clear" and "Rain" or "Clear"
end

WorldEvents.Meteor = {
	FirstAfter = { 12, 25 }, -- minutes into a server before the first shower
	Every = { 40, 65 }, -- minutes from one shower's end to the next one's start
	Warn = 20, -- seconds of "a meteor shower is coming!" before the first one lands
	Duration = 90, -- seconds meteors keep falling
	Hub = 14, -- meteorites around the hub per shower
	PerIsland = 3, -- and on every island someone's on
	Linger = 75, -- seconds they glow on after the last one lands (then fade away)
	CoinMinutes = 2, CoinMin = 300, -- each meteorite: this many minutes of your yard's income (never below CoinMin)
	StarMinutes = 6, StarMin = 1500, -- the STAR METEORITE: an egg, or this much if your egg bag is full
	Reach = 14, -- studs: how close you must be to collect one
}

return WorldEvents
