--[[
	DinoExpeditionClient — boots the showcase and the game on each client.
	- Binds a procedural animator to every dinosaur in Workspace (idle starts immediately)
	- Routes animator events (footsteps, roars, bites...) to DinosaurVFX
	- Plays showcase actions broadcast by the server (pedestal ProximityPrompts)
	- Vehicle idle life + the Studio developer panel
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local DinosaurAnimations = require(Shared:WaitForChild("DinosaurAnimations"))
local DinosaurVFX = require(Shared:WaitForChild("DinosaurVFX"))
local Showcase = require(script:WaitForChild("ShowcaseController"))
local DevPanel = require(script:WaitForChild("DevPanel"))
local VehicleIdle = require(script:WaitForChild("VehicleIdle"))

DinosaurAnimations.onEvent(DinosaurVFX.HandleEvent)

local function bind(model: Instance)
	if model:IsA("Model") and model:IsDescendantOf(Workspace) and model.PrimaryPart then
		DinosaurAnimations.get(model)
	end
end
for _, m in ipairs(CollectionService:GetTagged("DinoExpeditionDinosaur")) do bind(m) end
CollectionService:GetInstanceAddedSignal("DinoExpeditionDinosaur"):Connect(function(m) task.defer(bind, m) end)

local remote = Shared:WaitForChild("Remotes"):WaitForChild("ShowcaseEvent")
remote.OnClientEvent:Connect(function(model: Model, action: string, player: Player)
	if typeof(model) == "Instance" and model:IsA("Model") then
		Showcase.Perform(model, action, player == Players.LocalPlayer)
	end
end)

VehicleIdle.start()
-- the old showcase dev panel is no longer shown; Settings > Test Tools can still open it
local devPanel = nil
require(script:WaitForChild("Game"):WaitForChild("DevHooks")).OpenShowcasePanel = function()
	if not devPanel then
		devPanel = DevPanel.mount(Showcase)
		devPanel.Enabled = true
		return
	end
	devPanel.Enabled = not devPanel.Enabled
end

-- the game: Base Camp, expeditions, hatching, UI
local Game = script:WaitForChild("Game")
local UI = Game:WaitForChild("UI")
local Net = require(Game:WaitForChild("Net"))
local Kit = require(Game:WaitForChild("UI"):WaitForChild("Kit"))
local _Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))
local Zone = require(Game:WaitForChild("Zone"))
local Drive = require(Game:WaitForChild("Drive"))
local CampView = require(Game:WaitForChild("CampView"))
local ExpeditionView = require(Game:WaitForChild("ExpeditionView"))
local Hatch = require(Game:WaitForChild("Hatch"))
local Garage = require(Game:WaitForChild("Garage"))
local Darts = require(Game:WaitForChild("Darts"))
local EncounterView = require(Game:WaitForChild("EncounterView"))
local EraView = require(Game:WaitForChild("EraView"))
local NpcView = require(Game:WaitForChild("NpcView"))
local Scenes = require(Game:WaitForChild("Scenes"))
local Warp = require(Game:WaitForChild("Warp"))
local Movement = require(Game:WaitForChild("Movement"))
local Ambience = require(Game:WaitForChild("Ambience"))
local Audio = require(Game:WaitForChild("Audio"))
local RideFx = require(Game:WaitForChild("RideFx"))
local RideStudio = require(Game:WaitForChild("RideStudio"))
local Pickups = require(Game:WaitForChild("Pickups"))
local Wardrobe = require(Game:WaitForChild("Wardrobe"))
local Outfitter = require(Game:WaitForChild("Outfitter"))
local Onboarding = require(Game:WaitForChild("Onboarding"))
local HUD = require(UI:WaitForChild("HUD"))
local Panels = require(UI:WaitForChild("Panels"))
local Prompt = require(UI:WaitForChild("Prompt"))

Zone.Apply("BaseCamp", true)
-- Base Camp comes alive first (plots, ridge brachio, hologram, motes): the PRE-BETA tester menu films it.
-- MainMenu.Run holds the rest of the boot until PLAY on live test servers; Studio walks straight past it.
CampView.OnNestBuilt = function(slot) Scenes.NewNest(slot) end
task.spawn(CampView.Start)
Ambience.Start()
local WeatherView = require(Game:WaitForChild("WeatherView"))
WeatherView.Start() -- the server's weather: rain, storms + lightning, fog, wind, hail
-- (listening before the menu: Net holds unheard messages until it's done, and a held-back shower would land all at once)
local MeteorView = require(Game:WaitForChild("MeteorView"))
MeteorView.Start() -- METEOR SHOWERS: fireballs over camp, meteorites to collect
require(Game:WaitForChild("Freecam")).Start() -- developers: a free-flying camera (TEST TOOLS > FREECAM, or F8)
local fromMenu = require(Game:WaitForChild("MainMenu")).Run()
WeatherView.Ready, MeteorView.Ready = true, true
Drive.Start()
Prompt.Start()
Panels.Start()
HUD.Start(Panels)
Garage.Start(Panels, HUD)
require(Game:WaitForChild("PlayerAnim")).Start() -- player poses (carry, sneak, combat); also started by EncounterView
task.spawn(function() require(Game:WaitForChild("PaddockLife")).Start() end) -- petting, the companion, fetch
require(Game:WaitForChild("CampMoves")).Start() -- setting an egg into a nest
require(Game:WaitForChild("Crew")).Start() -- your buddies riding along in the rover on expeditions
require(Game:WaitForChild("Carpool")).Start() -- the driver's YES / NO card when someone asks to ride along
ExpeditionView.Start(HUD)
Darts.Start(ExpeditionView, HUD)
EncounterView.Start(ExpeditionView)
require(Game:WaitForChild("SeaFight")).Start(ExpeditionView) -- the sea ruler: bubbles, waves, grabs, the whirlpool
require(Game:WaitForChild("BossFx")).Start(ExpeditionView) -- the land rulers' signature moves: whiteout, crashes, guard breaks
require(Game:WaitForChild("BoatFx")).Start() -- the rover as a boat on Spine River's water
Scenes.Start()
Movement.Start()
require(Game:WaitForChild("EggTip")).Start() -- hover an egg: species, KG, rarity
require(Game:WaitForChild("Swim")).Start() -- water: dive, breath meter, splashes (Spine River)
require(Game:WaitForChild("Glide")).Start() -- a Microraptor companion: hold jump while falling to glide
require(Game:WaitForChild("AdminLink")).Start() -- admin teleports that stick; the owner's silent watch
require(Game:WaitForChild("BillboardCalm")).Start() -- floating labels keep their text small
Audio.Start()
require(Game:WaitForChild("SoundFx")).Start() -- dino voices + steps from their animations, engines, UI and reward sounds
RideFx.Start()
RideStudio.Start()
Pickups.Start()
Wardrobe.Start()
Outfitter.Start()
NpcView.Start(Panels)
require(Game:WaitForChild("TrainerView")).Start(Panels) -- the power trainer: boards, the TRAINER window, +N POWER pops, GUESS THE DINO
require(Game:WaitForChild("FusionView")).Start(Panels) -- EGG FUSION: the nest's glow, the window, the cutscene
require(Game:WaitForChild("ShowcaseView")).Start(Panels) -- the SHOWCASE pedestal on every island + your PICK A STAR window
require(Game:WaitForChild("DiscoverView")).Start() -- SECRET FOUND! banners + the ALL SECRETS! moment
require(Game:WaitForChild("BoostsView")).Start() -- your active boosts (top-left) + the 2x LUCK event banner
do -- the DAILY SPIN: the window, the HUD button, the wheel at camp
	local SpinView = require(Game:WaitForChild("SpinView"))
	SpinView.Start(Panels)
	HUD.OnSpin = SpinView.Open
end
Onboarding.Start(HUD)
require(Game:WaitForChild("AwayCard")).Start(HUD) -- WHILE YOU WERE AWAY: the offline coins, once the menu / cold open is done
require(Game:WaitForChild("BossHype")).Start() -- boss build-up: red Time Gate, countdown, the SUMMON prompt
require(Game:WaitForChild("Foreshadow")).Start(EraView) -- the Tyrant King teases: footprints, a roar, a crossing
local Omens = require(Game:WaitForChild("Omens")) -- every other era's boss teases you too: a sign, a glimpse, a close call
Omens.Start(EraView)
require(Game:WaitForChild("PlayerCard")).Start() -- VIEW PROFILE on other players + PRE-BETA TESTER tags
require(Game:WaitForChild("EraLife")).Start() -- free roam: herds walking the game trails, pterosaurs on the landmarks
require(Game:WaitForChild("RareHatch")).Start() -- server-wide EPIC / LEGENDARY / SECRET hatch banners (queued, never over a cutscene)
Net.On("HatchReveal", function(info) Hatch.Play(info) end)
-- the cutscene gallery (Settings > CUTSCENES) reaches every scene through these
Panels.Hooks.Scenes = Scenes
-- after the free first upgrade: show, don't tell - the HUNTER POWER counter pops in (HUD drip-feed) and one stamp
Panels.Hooks.UpgradeTour = function()
	local p = Net.Profile
	Kit.Toast("POWER UP!  " .. (p and p.Power or 0), "Lime", "Power")
end
Panels.Hooks.Hatch = Hatch
Panels.Hooks.ColdOpen = Onboarding.ColdOpen -- (Settings > CUTSCENES > COLD OPEN replays the first-minute prologue)
Panels.Hooks.RideStudio = RideStudio
-- the Quartermaster's ROVER tab: a waypoint to your garage's ride shop
Panels.Hooks.GuideToRideShop = function()
	local idx = Players.LocalPlayer:GetAttribute("Plot")
	local camp = workspace:FindFirstChild("BaseCamp")
	local plot = camp and idx and camp:FindFirstChild("Plot" .. idx, true)
	local host = plot and plot:FindFirstChild("PaintShopHost", true)
	if host and host:IsA("BasePart") then
		HUD.Guide(host, "RIDE SHOP", "GO TO THE RIDE SHOP AT YOUR GARAGE", "Jeep")
	end
end
-- the Quartermaster's ISLAND UPGRADES row: a waypoint to one of your island's blueprint boards
Panels.Hooks.GuideToBoard = function(id: string)
	local idx = Players.LocalPlayer:GetAttribute("Plot")
	local camp = workspace:FindFirstChild("BaseCamp")
	local plot = camp and idx and camp:FindFirstChild("Plot" .. idx, true)
	if not plot then return end
	for _, b in ipairs(plot:GetDescendants()) do
		if b:IsA("Model") and b.Name == "BuildBoard" and b:GetAttribute("Build") == id then
			local host = b:FindFirstChild("BuildPromptHost", true)
			if host and host:IsA("BasePart") then HUD.Guide(host, "UPGRADE", "UPGRADE YOUR ISLAND AT THE BLUEPRINT BOARD", "Hammer") end
			return
		end
	end
end
Panels.Hooks.EraView = EraView
Panels.Hooks.Omens = Omens
Panels.Hooks.FakeWarp = require(script.Game.FakeWarp)
-- TikTok recording sequences (Settings > TIKTOKS); everything they show is a local clone
Panels.Hooks.TikTok = require(script.Game.TikTok)
Panels.Hooks.Warp = function()
	local route = require(ReplicatedStorage.DinoExpedition.Game.RouteMath).get("FernValley")
	Warp.Play({ Full = true, Skippable = true, Name = "FERN VALLEY", Era = "68,000,000 BC", YearTo = route and route.Data.Year or -68000000 })
	if Drive.State.Mode == "None" then Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end
end
-- settings that live on the client
local function applySettings()
	local s = Net.Profile and Net.Profile.Settings
	if s then
		DinosaurVFX.ShakeScale = (s.Shake == false) and 0 or 1
		Audio.SetEnabled(s.Music ~= false)
	end
end
Net.On("Profile", applySettings)
applySettings()

-- spawning: once the server has moved you onto your plot, put the camera behind you looking into the plot
-- (otherwise it keeps whatever angle the default spawn left it at, often staring into a wall or sign)
local Cinema = require(UI:WaitForChild("Cinema"))
local function frameSpawn(char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hrp then return end
	local p0 = hrp.Position
	local t0 = os.clock()
	while os.clock() - t0 < 4 and (hrp.Position - p0).Magnitude < 8 do task.wait(0.05) end
	task.wait(0.1)
	if Cinema.Playing() or Drive.State.Mode ~= "None" then return end
	local cam = Workspace.CurrentCamera
	if not cam or not hrp.Parent then return end
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	cam.CameraType = Enum.CameraType.Custom
	cam.CFrame = CFrame.lookAt(hrp.Position - look * 13 + Vector3.new(0, 6, 0), hrp.Position + look * 6 + Vector3.new(0, 1.5, 0))
end
Players.LocalPlayer.CharacterAdded:Connect(function(c) task.spawn(frameSpawn, c) end)
-- camera watchdog: if a cutscene ever leaves the camera parked (Scriptable) with nobody driving it, hand it
-- back to the player instead of staring at the sky until they move
local orphanSince = nil
RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	local owned = Cinema.Playing() or Drive.State.Mode ~= "None" or Warp.Playing or EraView.MapOpen() or require(Shared:WaitForChild("DinosaurCinematics")).IsPlaying()
	if cam.CameraType == Enum.CameraType.Scriptable and not owned then
		orphanSince = orphanSince or os.clock()
		if os.clock() - orphanSince > 0.4 then
			cam.CameraType = Enum.CameraType.Custom
			local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then cam.CameraSubject = hum end
			orphanSince = nil
		end
	else
		orphanSince = nil
	end
end)
-- (after the menu, its PLAY swoop already put the camera behind you)
if Players.LocalPlayer.Character and not fromMenu then task.spawn(frameSpawn, Players.LocalPlayer.Character) end
-- everything is listening now: deliver what the server sent while the menu was up (welcome back, onboarding...)
task.delay(0.5, Net.Release)
