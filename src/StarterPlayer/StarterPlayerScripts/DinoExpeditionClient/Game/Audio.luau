--[[
	Audio — every sound in the game: music that follows where you are, stingers on the big moments, sound effects
	(one-shots, in 3D when they happen somewhere) and an ambience bed per place. Every slot is an asset id in IDS
	below (AUDIO.md lists the file for each); an empty slot is simply silent.

	Audio.SetMusic(slot)       crossfade to a looping track ("Camp", "FernValley", ..., "Map", "Chase", "Boss")
	Audio.Push(slot) / Pop()   a temporary track over the zone music (chase, boss)
	Audio.Sting(slot, vol?)    a one-shot stinger; the music ducks under it
	Audio.Play(slot, opts?)    a sound effect. opts: At (Vector3 | BasePart: 3D, fades with distance), Volume (x),
	                           Pitch (x), Exact (no random pitch), Range (studs). Some slots have variations
	                           (RoarBig / RoarBig2) and pick one at random, and every play varies its pitch a little
	                           so repeats never sound copy-pasted.
	Audio.Loop(slot, parent?)  a looping Sound you own (engine, swimming, the whirlpool); nil if the slot is empty
	Audio.Has(slot)            is there an id in it
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Zone = require(script.Parent.Zone)

local Audio = {}

-- paste rbxassetid://<id> strings here --------------------------------------------------------------------------
local IDS = {
	-- music (loops; Roblox Creator Store music from APM, licensed for Roblox games. Alternatives are listed in AUDIO.md)
	Camp = "rbxassetid://1838609493", FernValley = "rbxassetid://1837299746", GiantPlains = "rbxassetid://1839924446", SpineRiver = "rbxassetid://1846751102", RedCliffs = "rbxassetid://9042768313", FrostForest = "rbxassetid://1841460294", DawnDesert = "rbxassetid://1847792600", Map = "rbxassetid://1841928563", Chase = "rbxassetid://1837322700", Boss = "rbxassetid://9045953477",
	-- stingers (one-shots). Sound effects are from mixkit.co (AUDIO.md lists the file for every slot)
	Reveal = "rbxassetid://133102378087009", Discover = "rbxassetid://102083733837786", Spotted = "rbxassetid://116271575873974", Fight = "rbxassetid://101366901832272", Escape = "rbxassetid://125276638226699", Escaped = "rbxassetid://87120581917069", Defeated = "rbxassetid://85349664685946", KnockedOut = "rbxassetid://130597192717300",
	Hatch = "rbxassetid://78349555920691", HatchRare = "rbxassetid://124055750390432", HatchLegendary = "rbxassetid://115013670294100", EggCrack = "rbxassetid://94586812782729", Warp = "rbxassetid://139691314773253", Perfect = "rbxassetid://105707986269135", LevelUp = "rbxassetid://116334422859689", QuestDone = "rbxassetid://137584049715702", BossRising = "rbxassetid://121130959820813",
	-- dino voices + steps
	RoarBig = "rbxassetid://125515657311579", RoarBig2 = "rbxassetid://135832918761653", RoarBoss = "rbxassetid://125961266352447", Screech = "rbxassetid://140127912769348", Screech2 = "rbxassetid://71021431551579", Bellow = "rbxassetid://131891493546265", SeaRoar = "rbxassetid://127466954591627",
	Growl = "rbxassetid://106532144139508", Snap = "rbxassetid://129137498902830", DinoHurt = "rbxassetid://71370103723132", BabyChirp = "rbxassetid://130585825236541", StompBig = "rbxassetid://123176808686351", Stomp = "rbxassetid://111835870146599",
	-- the boss reveals (TikTok/Fx cues)
	TreeCrack = "rbxassetid://93297706899932", Slash = "rbxassetid://82541699490915", IceCrack = "rbxassetid://94586812782729", -- (stand-ins from existing sounds: rover crunch, dodge whoosh, egg crack - 2026-10-14)
	-- combat
	DryFire = "rbxassetid://73594411517812", Glance = "rbxassetid://102960159543903", DartFire = "rbxassetid://99876659468234", DartHit = "rbxassetid://92501079911185", PlayerHurt = "rbxassetid://86270817581826", Dodge = "rbxassetid://82541699490915", Reload = "rbxassetid://139786514205545", ChargeReady = "rbxassetid://131845044220611", Calmed = "rbxassetid://111284256599799",
	-- rover
	EngineLoop = "rbxassetid://73755677935809", Boost = "rbxassetid://71136655871014", RoverHit = "rbxassetid://93297706899932", CarDoor = "rbxassetid://109664901932081", Splash = "rbxassetid://77332465545090",
	-- ui + rewards
	Talk = "rbxassetid://81020645782949", Confirm = "", Click = "rbxassetid://84936066404166", Open = "rbxassetid://127763826191288", Close = "rbxassetid://103119951323035", Error = "rbxassetid://107899093683820", Toast = "rbxassetid://99968973668186", Coins = "rbxassetid://72940755536798", Payout = "rbxassetid://125666977943874",
	-- eggs + pets
	EggPickup = "rbxassetid://70824052710673", EggPlace = "rbxassetid://73661071300622", Pet = "rbxassetid://105257192158974",
	-- ambience loops + water + gadgets
	AmbCamp = "rbxassetid://110921704203108", AmbFernValley = "rbxassetid://128372450334117", AmbGiantPlains = "rbxassetid://111022630434131", AmbSpineRiver = "rbxassetid://117082428177458", AmbRedCliffs = "rbxassetid://116672201806270", AmbFrostForest = "rbxassetid://132342618575634", AmbDawnDesert = "rbxassetid://123606575449494",
	SwimLoop = "rbxassetid://130404763172698", Underwater = "rbxassetid://71652739380772", Whirlpool = "rbxassetid://114301806860120", Breach = "rbxassetid://84587022119799", Flare = "rbxassetid://140425785126495", Earthshaker = "rbxassetid://140464392838849", Bait = "rbxassetid://95191309285558",
	-- rover horns (played at the rover, heard by everyone nearby). Raptor / Rex reuse Screech / RoarBig
	HornBeep = "rbxassetid://120756408449725", HornTruck = "rbxassetid://127302783184661", HornDuck = "rbxassetid://100736621450629", HornClown = "rbxassetid://119957687898063", HornTrain = "rbxassetid://72027311033020", HornRaptor = "rbxassetid://140127912769348", HornFanfare = "rbxassetid://111251775328302", HornRex = "rbxassetid://125515657311579",
	-- garage studio
	Spray = "rbxassetid://107158966284157", Clunk = "rbxassetid://118942286185428", Purchase = "rbxassetid://120261282337874",
	-- pickups
	ItemDrop = "rbxassetid://124994810895688", ItemGet = "rbxassetid://92608346024892",
	-- weather + meteor showers (2026-10-14: AUDIO.md "Weather + meteors" lists the files; empty = silent, and the
	-- thunder / meteors fall back on StompBig / Earthshaker until they're in)
	RainLoop = "", StormLoop = "", WindLoop = "", HailLoop = "", ThunderNear = "", ThunderFar = "", MeteorFall = "", MeteorHit = "",
}
Audio.IDS = IDS
-------------------------------------------------------------------------------------------------------------------

local VOLUME = { Music = 0.35, Sting = 0.7, Amb = 0.5 }
local ZONE_MUSIC = { BaseCamp = "Camp", FernValley = "FernValley", GiantPlains = "GiantPlains", SpineRiver = "SpineRiver", RedCliffs = "RedCliffs", FrostForest = "FrostForest", DawnDesert = "DawnDesert" }
local ZONE_AMB = { BaseCamp = "AmbCamp", FernValley = "AmbFernValley", GiantPlains = "AmbGiantPlains", SpineRiver = "AmbSpineRiver", RedCliffs = "AmbRedCliffs", FrostForest = "AmbFrostForest", DawnDesert = "AmbDawnDesert" }

-- the mix: each slot's level (the files were picked by their waveforms; quiet beds are lifted, hot hits trimmed)
local LEVEL = {
	RoarBig = 0.9, RoarBig2 = 0.75, RoarBoss = 1, Screech = 0.7, Screech2 = 0.75, Bellow = 0.75, SeaRoar = 1.6,
	Growl = 0.55, Snap = 0.6, DinoHurt = 0.55, BabyChirp = 0.45, StompBig = 0.7, Stomp = 0.35,
	DartFire = 0.35, DartHit = 0.45, PlayerHurt = 0.6, Dodge = 0.4, Reload = 0.4, ChargeReady = 0.35, Perfect = 0.55, Calmed = 0.6,
	Boost = 0.5, RoverHit = 0.7, CarDoor = 0.5, Splash = 0.6, Breach = 0.9, Flare = 0.6, Earthshaker = 0.8, Bait = 0.6,
	Click = 0.3, Talk = 0.18, Confirm = 0.4, DryFire = 0.45, Glance = 0.5, Open = 0.3, Close = 0.3, Error = 0.4, Toast = 0.3, Coins = 0.45, Payout = 0.55, Purchase = 0.5,
	EggPickup = 0.45, EggPlace = 0.4, Pet = 0.45, EggCrack = 0.6, ItemDrop = 0.5, ItemGet = 0.6, LevelUp = 0.6, QuestDone = 0.55,
	Spray = 0.5, Clunk = 0.5, BossRising = 0.8, TreeCrack = 0.9, Slash = 0.8, IceCrack = 0.7,
	-- ambience beds (some files are recorded very quietly)
	AmbCamp = 1.4, AmbFernValley = 3, AmbGiantPlains = 0.8, AmbSpineRiver = 4, AmbRedCliffs = 1.2, AmbFrostForest = 0.7, AmbDawnDesert = 0.8,
	SwimLoop = 0.5, Underwater = 0.6, Whirlpool = 0.9, EngineLoop = 0.35,
	RainLoop = 0.6, StormLoop = 0.7, WindLoop = 0.5, HailLoop = 0.55, ThunderNear = 1, ThunderFar = 0.8, MeteorFall = 0.6, MeteorHit = 0.9,
}
-- variations: a slot plays one of these at random
local VARIANTS = { RoarBig = { "RoarBig", "RoarBig2" }, Screech = { "Screech", "Screech2" } }
-- how far a 3D sound carries
local RANGE = { RoarBig = 320, RoarBig2 = 320, RoarBoss = 500, SeaRoar = 400, Bellow = 260, Screech = 220, Screech2 = 220, StompBig = 200, BossRising = 1000, Breach = 400, ThunderNear = 1400, ThunderFar = 2000, MeteorFall = 500, MeteorHit = 600 }

local tracks = {} :: { [string]: Sound }
local playing: Sound? = nil
local playingSlot: string? = nil
local stack = {} :: { string }
local enabled = true
local lastPlay = {} :: { [string]: number }
local sfxFolder: Folder? = nil

function Audio.Has(slot: string): boolean
	local id = IDS[slot]
	return id ~= nil and id ~= ""
end

local function trackFor(slot: string): Sound?
	local id = IDS[slot]
	if not id or id == "" then return nil end
	local s = tracks[slot]
	if not s then
		s = Instance.new("Sound")
		s.Name = "DinoMusic_" .. slot
		s.SoundId = id
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		tracks[slot] = s
	end
	return s
end

function Audio.SetMusic(slot: string?)
	if slot == playingSlot then return end
	local old = playing
	if old then
		TweenService:Create(old, TweenInfo.new(1.2), { Volume = 0 }):Play()
		task.delay(1.25, function() if playing ~= old then old:Stop() end end)
	end
	playingSlot = slot
	playing = slot and trackFor(slot) or nil
	if playing and enabled then
		playing.Volume = 0
		if not playing.IsPlaying then playing:Play() end
		TweenService:Create(playing, TweenInfo.new(1.5), { Volume = VOLUME.Music }):Play()
	end
end

-- a track over the zone's own (chase, boss); Pop returns to whatever was under it
function Audio.Push(slot: string)
	table.insert(stack, slot)
	Audio.SetMusic(slot)
end
function Audio.Pop()
	table.remove(stack)
	Audio.SetMusic(stack[#stack] or ZONE_MUSIC[Zone.Current])
end
-- take one named track out of the stack wherever it sits (a boss theme ends when the fight does, even with a chase
-- track pushed over it)
function Audio.Remove(slot: string)
	for i = #stack, 1, -1 do
		if stack[i] == slot then
			table.remove(stack, i)
			Audio.SetMusic(stack[#stack] or ZONE_MUSIC[Zone.Current])
			return
		end
	end
end

local function duck()
	if playing then
		playing.Volume = VOLUME.Music * 0.35
		TweenService:Create(playing, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 1.2), { Volume = VOLUME.Music }):Play()
	end
end

function Audio.Sting(slot: string, volume: number?)
	local id = IDS[slot]
	if not id or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = (volume or VOLUME.Sting) * (LEVEL[slot] and LEVEL[slot] / 0.6 or 1)
	s.Parent = SoundService
	s.Ended:Connect(function() s:Destroy() end)
	s:Play()
	duck()
	task.delay(14, function() if s.Parent then s:Destroy() end end)
end

local function folder(): Folder
	if sfxFolder and sfxFolder.Parent then return sfxFolder end
	local f = Instance.new("Folder")
	f.Name = "DinoSfx"
	f.Parent = Workspace
	sfxFolder = f
	return f
end

-- a sound effect; in 3D when it has a place (opts.At)
function Audio.Play(slot: string, opts: any?): Sound?
	opts = opts or {}
	local pick = slot
	local vars = VARIANTS[slot]
	if vars then
		local have = {}
		for _, v in ipairs(vars) do if Audio.Has(v) then table.insert(have, v) end end
		if #have > 0 then pick = have[math.random(1, #have)] end
	end
	local id = IDS[pick]
	if not id or id == "" then return nil end
	-- the same sound stacking up in one frame just gets louder and phasey: let it through once
	local now = os.clock()
	if (lastPlay[pick] or 0) > now - (opts.Gap or 0.04) then return nil end
	lastPlay[pick] = now
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = (LEVEL[pick] or 0.6) * (opts.Volume or 1)
	s.PlaybackSpeed = (opts.Pitch or 1) * (opts.Exact and 1 or (0.93 + math.random() * 0.14))
	local at = opts.At
	if at then
		local host: Instance
		if typeof(at) == "Instance" and at:IsA("BasePart") then
			host = at
		else
			local p = Instance.new("Part")
			p.Name = "Sfx_" .. pick
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
			p.Size = Vector3.new(0.2, 0.2, 0.2)
			p.Position = at :: Vector3
			p.Parent = folder()
			host = p
			task.delay(12, function() p:Destroy() end)
		end
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = opts.Near or 14
		s.RollOffMaxDistance = opts.Range or RANGE[pick] or 160
		s.Parent = host
	else
		s.Parent = SoundService
	end
	s.Ended:Connect(function() s:Destroy() end)
	s:Play()
	task.delay(12, function() if s.Parent then s:Destroy() end end)
	return s
end

-- a looping sound for the caller to drive (Volume / PlaybackSpeed) and Destroy
function Audio.Loop(slot: string, parent: Instance?): Sound?
	local id = IDS[slot]
	if not id or id == "" then return nil end
	local s = Instance.new("Sound")
	s.Name = "Loop_" .. slot
	s.SoundId = id
	s.Looped = true
	s.Volume = LEVEL[slot] or 0.5
	if parent and parent:IsA("BasePart") then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 160
	end
	s.Parent = parent or SoundService
	s:Play()
	return s
end
Audio.Level = LEVEL

function Audio.Enabled(): boolean
	return enabled
end

function Audio.SetEnabled(on: boolean)
	enabled = on
	if playing then playing.Volume = on and VOLUME.Music or 0 end
end

-- the ambience bed: each place has its own sound under the music (birds, river, wind), crossfaded
local amb: Sound? = nil
local ambSlot: string? = nil
local ambDuck = 1
local function setAmb(slot: string?)
	if slot == ambSlot then return end
	ambSlot = slot
	local old = amb
	if old then
		TweenService:Create(old, TweenInfo.new(2), { Volume = 0 }):Play()
		task.delay(2.1, function() old:Destroy() end)
	end
	amb = slot and Audio.Loop(slot) or nil
	if amb then
		local target = (LEVEL[slot :: string] or 1) * VOLUME.Amb * ambDuck
		amb.Volume = 0
		TweenService:Create(amb, TweenInfo.new(2.5), { Volume = target }):Play()
	end
end
-- cutscenes and swimming can pull the bed down (0..1)
function Audio.AmbienceLevel(k: number)
	ambDuck = k
	if amb and ambSlot then
		TweenService:Create(amb, TweenInfo.new(0.6), { Volume = (LEVEL[ambSlot] or 1) * VOLUME.Amb * k }):Play()
	end
end

function Audio.Start()
	-- the zone's music and ambience follow the zone (unless a chase / boss track is on top)
	local last = nil
	task.spawn(function()
		while true do
			task.wait(0.5)
			if Zone.Current ~= last then
				last = Zone.Current
				table.clear(stack)
				Audio.SetMusic(ZONE_MUSIC[Zone.Current])
				setAmb(ZONE_AMB[Zone.Current])
			end
		end
	end)
end

return Audio
