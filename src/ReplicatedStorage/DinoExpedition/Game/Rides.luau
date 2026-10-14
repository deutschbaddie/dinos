--[[
	Rides — build-your-own rover. A rover is a BODY (Rookie Ranger, Raptor Runner, Titan Transport) that you build
	out: paint and two-tone, finish, rims and tyres, ride height, front / rear / roof kits, wraps, underglow,
	boost trail and horn. Shared by the server (it styles the real rover everyone sees) and the garage studio
	(it styles the preview on the turntable), so what you see in the garage is exactly what rolls out.

	Simple on the surface: every option is one big tile; tap it and the car changes. Deep underneath: parts
	carry SPEED / BOOST / ARMOR / GRIP trade-offs, rarer parts sit behind era and boss progress.

	Rides.Fill(style)                 a complete style (defaults filled in)
	Rides.StyleFor(profile, body)     the saved style for that body
	Rides.Stats(body, style)          { HP, Cruise, Boost, Darts, Grip, Add = { Speed, Boost, Armor, Grip } }
	Rides.Apply(model, body, style)   restyle a freshly cloned body template (call before moving it)
	Rides.Owns / Rides.LockReason / Rides.Price / Rides.Valid   shop rules (server enforces them)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local Rides = {}

local rgb = Color3.fromRGB

--------------------------------------------------------------------------------
-- catalog
--------------------------------------------------------------------------------
-- one shared colour rack: buy a colour once and it's yours for paint, trim, rims, wraps and glow
-- PRICES follow the income curve (GDD "Balance and pacing": ~7 coins/s at the start, ~25/s mid Fern Valley,
-- 50 -> 650/s in Giant Plains). Only FACTORY parts are free. Cheap paint is a few minutes of early income;
-- every tier after that has something worth saving for, and the era / ruler parts sit with that stage's money.
Rides.Colors = {
	{ Id = "Sunburst", Name = "SUNBURST", Color = rgb(242, 182, 50), Price = 400 },
	{ Id = "Lava", Name = "LAVA RED", Color = rgb(222, 58, 40), Price = 400 },
	{ Id = "Jungle", Name = "JUNGLE", Color = rgb(52, 128, 64), Price = 400 },
	{ Id = "Ocean", Name = "OCEAN", Color = rgb(36, 112, 226), Price = 400 },
	{ Id = "Tangerine", Name = "TANGERINE", Color = rgb(255, 122, 26), Price = 400 },
	{ Id = "Snow", Name = "SNOW", Color = rgb(238, 240, 236), Price = 400 },
	{ Id = "Coal", Name = "COAL", Color = rgb(34, 35, 40), Price = 400 },
	{ Id = "Grape", Name = "GRAPE", Color = rgb(128, 66, 204), Price = 400 },
	{ Id = "Bubblegum", Name = "BUBBLEGUM", Color = rgb(255, 128, 196), Price = 900 },
	{ Id = "Sky", Name = "SKY", Color = rgb(112, 202, 255), Price = 900 },
	{ Id = "Mint", Name = "MINT", Color = rgb(122, 232, 180), Price = 900 },
	{ Id = "Sand", Name = "DESERT SAND", Color = rgb(226, 198, 138), Price = 900 },
	{ Id = "Olive", Name = "ARMY OLIVE", Color = rgb(108, 118, 58), Price = 1200 },
	{ Id = "Chocolate", Name = "CHOCOLATE", Color = rgb(112, 70, 42), Price = 1200 },
	{ Id = "Lime", Name = "LIME", Color = rgb(150, 232, 48), Price = 2000 },
	{ Id = "Teal", Name = "LAGOON", Color = rgb(22, 176, 170), Price = 2000 },
	{ Id = "Cherry", Name = "CHERRY", Color = rgb(186, 18, 52), Price = 3000 },
	{ Id = "Midnight", Name = "MIDNIGHT", Color = rgb(26, 32, 78), Price = 4000 },
	{ Id = "HotPink", Name = "HOT PINK", Color = rgb(255, 40, 146), Price = 6000 },
	{ Id = "Ice", Name = "GLACIER", Color = rgb(186, 238, 255), Price = 6000 },
	{ Id = "Rust", Name = "RAPTOR RUST", Color = rgb(168, 80, 38), Price = 8000 },
	{ Id = "Silver", Name = "SILVER", Color = rgb(190, 196, 206), Price = 15000 },
	{ Id = "Gold", Name = "SOLID GOLD", Color = rgb(255, 196, 36), Price = 90000, Req = { Boss = "TyrantKing" } },
	{ Id = "Toxic", Name = "TOXIC", Color = rgb(176, 255, 0), Price = 120000, Req = { Era = "GiantPlains" } },
	{ Id = "Royal", Name = "ROYAL", Color = rgb(84, 46, 182), Price = 180000, Req = { Era = "GiantPlains" } },
	{ Id = "Obsidian", Name = "OBSIDIAN", Color = rgb(14, 12, 20), Price = 1500000, Req = { Boss = "Titan" } },
	-- Spine River: the Tidebreaker's rewards (sea-themed, for whoever beat the river's ruler)
	{ Id = "Abyss", Name = "DEEP TIDE", Color = rgb(18, 70, 150), Price = 1800000, Req = { Boss = "Tidebreaker" } },
	-- SECRET paints (2026-10-14, the Index's discovery tracker): never sold - finding every secret of that era gives
	-- it (Discover.luau puts it in RideOwned). The price only picks the tile's band colour.
	{ Id = "SecretFern", Name = "FERN EMERALD", Color = rgb(20, 214, 118), Price = 250000, Req = { Secrets = "FernValley" } },
	{ Id = "SecretPlains", Name = "PRAIRIE SUNSET", Color = rgb(255, 112, 70), Price = 250000, Req = { Secrets = "GiantPlains" } },
	{ Id = "SecretRiver", Name = "KINGFISHER", Color = rgb(0, 152, 255), Price = 250000, Req = { Secrets = "SpineRiver" } },
	{ Id = "SecretCliffs", Name = "HOODOO CORAL", Color = rgb(255, 92, 84), Price = 250000, Req = { Secrets = "RedCliffs" } },
	{ Id = "SecretFrost", Name = "AURORA", Color = rgb(100, 255, 212), Price = 250000, Req = { Secrets = "FrostForest" } },
	{ Id = "SecretDawn", Name = "DAWN ROSE", Color = rgb(255, 156, 176), Price = 250000, Req = { Secrets = "DawnDesert" } },
}

-- Stats: Speed / Boost are added to the body's cruise / boost speed; Armor and Grip are percentages
Rides.Options = {
	Finish = {
		{ Id = "Gloss", Name = "FACTORY GLOSS", Price = 0, Desc = "SHINY FACTORY PAINT" },
		{ Id = "Matte", Name = "MATTE", Price = 2500, Desc = "FLAT AND MEAN" },
		{ Id = "Metallic", Name = "METALLIC", Price = 8000, Desc = "SPARKLES IN THE SUN" },
		{ Id = "Chrome", Name = "CHROME", Price = 250000, Desc = "A MIRROR ON WHEELS", Req = { Era = "GiantPlains" } },
		{ Id = "Neon", Name = "NEON", Price = 400000, Desc = "THE WHOLE BODY GLOWS", Req = { Era = "GiantPlains" } },
		{ Id = "Ghost", Name = "GHOST", Price = 2000000, Desc = "SHIMMERING SEE-THROUGH SHELL", Req = { Boss = "Titan" } },
	},
	Rims = {
		{ Id = "Stock", Name = "FACTORY", Price = 0, Desc = "WHAT IT CAME WITH" },
		{ Id = "Steelie", Name = "STEELIE", Price = 1500, Desc = "TOUGH PLAIN STEEL", Stats = { Armor = 2 } },
		{ Id = "Spoke", Name = "SPORT 5", Price = 3000, Desc = "FIVE FAT SPOKES" },
		{ Id = "Dish", Name = "RACE DISH", Price = 6000, Desc = "SMOOTH AND FAST", Stats = { Speed = 1 } },
		{ Id = "Mesh", Name = "MESH 10", Price = 10000, Desc = "TEN THIN SPOKES" },
		{ Id = "Star", Name = "STAR", Price = 18000, Desc = "POINTY STAR RIMS" },
		{ Id = "Turbine", Name = "TURBINE", Price = 35000, Desc = "JET ENGINE FANS", Stats = { Boost = 1 } },
		{ Id = "Claw", Name = "RAPTOR CLAW", Price = 120000, Desc = "THREE CURVED CLAWS", Req = { Boss = "TyrantKing" } },
	},
	Tires = {
		{ Id = "Stock", Name = "FACTORY", Price = 0, Desc = "ALL-ROUNDERS" },
		{ Id = "Whitewall", Name = "WHITEWALL", Price = 2000, Desc = "CLASSIC WHITE RING" },
		{ Id = "Redline", Name = "RED LINE", Price = 2500, Desc = "SPORTY RED STRIPE" },
		{ Id = "Slick", Name = "SLICKS", Price = 9000, Desc = "FAST ON THE ROAD, SLIPPY IN TURNS", Stats = { Speed = 3, Grip = -10 } },
		{ Id = "Knobby", Name = "KNOBBY", Price = 12000, Desc = "BIG BLOCKS, GRIP AND GUTS", Stats = { Grip = 8, Armor = 3, Speed = -1 } },
		{ Id = "Mud", Name = "MUD MONSTERS", Price = 25000, Desc = "DEEP CHEVRONS, GRIP EVERYTHING", Stats = { Grip = 15, Speed = -2 } },
	},
	Lift = {
		{ Id = "Stock", Name = "FACTORY", Price = 0, Desc = "NORMAL RIDE HEIGHT", Lift = 0 },
		{ Id = "Lifted", Name = "LIFTED", Price = 7500, Desc = "UP ON TALL SPRINGS", Lift = 0.9, Stats = { Armor = 4, Speed = -1 } },
		{ Id = "Monster", Name = "MONSTER", Price = 300000, Desc = "WAY UP HIGH", Lift = 1.8, Stats = { Armor = 8, Grip = 5, Speed = -2 }, Req = { Era = "GiantPlains" } },
	},
	Front = {
		{ Id = "Stock", Name = "FACTORY", Price = 0, Desc = "WHAT IT CAME WITH" },
		{ Id = "RacerLip", Name = "RACER LIP", Price = 4000, Desc = "LOW SPLITTER, CUTS THE AIR", Stats = { Speed = 2, Armor = -3 } },
		{ Id = "BullBar", Name = "RHINO BAR", Price = 7000, Desc = "BIG TUBE BAR AND LIGHTS", Stats = { Armor = 6, Speed = -1 } },
		{ Id = "Plow", Name = "DINO PLOW", Price = 20000, Desc = "PUSHES ANYTHING OUT THE WAY", Stats = { Armor = 12, Speed = -2 } },
		{ Id = "CrocJaw", Name = "CROC JAW", Price = 35000, Desc = "A BUMPER FULL OF TEETH", Stats = { Armor = 8, Grip = 4 } },
		{ Id = "TrikeRam", Name = "TRIKE RAM", Price = 450000, Desc = "THREE HORNS, ALL BUSINESS", Stats = { Armor = 14 }, Req = { Era = "GiantPlains" } },
	},
	Rear = {
		{ Id = "Stock", Name = "FACTORY", Price = 0, Desc = "WHAT IT CAME WITH" },
		{ Id = "Ducktail", Name = "DUCKTAIL", Price = 3500, Desc = "LITTLE LIP SPOILER", Stats = { Grip = 4 } },
		{ Id = "TwinPipes", Name = "TWIN PIPES", Price = 9000, Desc = "LOUD CHROME EXHAUSTS", Stats = { Boost = 3 } },
		{ Id = "GTWing", Name = "GT WING", Price = 18000, Desc = "HUGE RACING WING", Stats = { Grip = 10, Boost = 1, Speed = -1 } },
		{ Id = "DinoTail", Name = "DINO TAIL", Price = 30000, Desc = "A SPIKY STEGO TAIL", Stats = { Armor = 6, Grip = 4 } },
		{ Id = "Rocket", Name = "ROCKET PACK", Price = 150000, Desc = "TWIN ROCKET BOOSTERS", Stats = { Boost = 7, Grip = -4 }, Req = { Boss = "TyrantKing" } },
		{ Id = "Outboard", Name = "OUTBOARD MOTOR", Price = 3500000, Desc = "A BOAT ENGINE ON THE BACK, PROPELLER AND ALL", Stats = { Boost = 5, Grip = 6 }, Req = { Boss = "Tidebreaker" } },
	},
	Roof = {
		{ Id = "Stock", Name = "FACTORY", Price = 0, Desc = "WHAT IT CAME WITH" },
		{ Id = "LightBar", Name = "LIGHT BAR", Price = 2500, Desc = "A ROW OF BRIGHT LIGHTS" },
		{ Id = "Dish", Name = "RADAR DISH", Price = 5000, Desc = "SPINS AND SCANS" },
		{ Id = "Sirens", Name = "RESCUE SIRENS", Price = 12000, Desc = "FLASHING RED AND BLUE" },
		{ Id = "DinoHead", Name = "REX HEAD", Price = 40000, Desc = "A BIG BLOCKY T. REX MASCOT" },
		{ Id = "Crown", Name = "TYRANT CROWN", Price = 200000, Desc = "FOR WHOEVER BEAT THE KING", Req = { Boss = "TyrantKing" } },
	},
	Wrap = {
		{ Id = "None", Name = "CLEAN", Price = 0, Desc = "JUST YOUR PAINT" },
		{ Id = "Stripe", Name = "SIDE STRIPE", Price = 2000, Desc = "ONE BOLD LINE" },
		{ Id = "Racing", Name = "RACING STRIPES", Price = 4000, Desc = "TWIN STRIPES NOSE TO TAIL" },
		{ Id = "Checker", Name = "CHECKERED", Price = 6500, Desc = "FINISH-LINE FLAG" },
		{ Id = "Spots", Name = "DINO SPOTS", Price = 6500, Desc = "LIKE A DINO EGG" },
		{ Id = "Tiger", Name = "TIGER", Price = 10000, Desc = "WILD STRIPES" },
		{ Id = "Camo", Name = "CAMO", Price = 10000, Desc = "HIDE IN THE FERNS" },
		{ Id = "Lightning", Name = "LIGHTNING", Price = 20000, Desc = "A BOLT DOWN EACH SIDE" },
		{ Id = "Flames", Name = "FLAMES", Price = 30000, Desc = "HOT ROD FLAMES" },
		{ Id = "Claws", Name = "CLAW SLASH", Price = 100000, Desc = "SOMETHING BIG SCRATCHED IT", Req = { Boss = "TyrantKing" } },
		{ Id = "Tide", Name = "TIDE", Price = 2500000, Desc = "ROLLING WAVES AND SEA FOAM", Req = { Boss = "Tidebreaker" } },
	},
	Glow = {
		{ Id = "None", Name = "OFF", Price = 0, Desc = "NO UNDERGLOW" },
		{ Id = "Steady", Name = "STEADY", Price = 8000, Desc = "A SOLID GLOW UNDERNEATH" },
		{ Id = "Pulse", Name = "PULSE", Price = 15000, Desc = "BREATHES IN AND OUT" },
		{ Id = "Chase", Name = "RUNNING", Price = 25000, Desc = "LIGHTS RACE AROUND THE CAR" },
		{ Id = "Police", Name = "RESCUE", Price = 30000, Desc = "RED AND BLUE FLASHES" },
		{ Id = "Rainbow", Name = "RAINBOW", Price = 350000, Desc = "EVERY COLOUR, ALL THE TIME", Req = { Era = "GiantPlains" } },
	},
	Trail = {
		{ Id = "Flame", Name = "FACTORY FLAME", Price = 0, Desc = "THE BLUE FACTORY BOOST" },
		{ Id = "Fire", Name = "HOT FIRE", Price = 4000, Desc = "ORANGE AND ANGRY" },
		{ Id = "Toxic", Name = "TOXIC", Price = 8000, Desc = "BUBBLING GREEN" },
		{ Id = "Leaves", Name = "LEAF STORM", Price = 10000, Desc = "A WHIRL OF JUNGLE LEAVES" },
		{ Id = "Sparkle", Name = "SPARKLE", Price = 15000, Desc = "GLITTER EVERYWHERE" },
		{ Id = "Ghost", Name = "GHOST SMOKE", Price = 20000, Desc = "SPOOKY PURPLE SMOKE" },
		{ Id = "Comet", Name = "COMET", Price = 160000, Desc = "A TAIL OF STARS", Req = { Boss = "TyrantKing" } },
		{ Id = "Rainbow", Name = "RAINBOW", Price = 300000, Desc = "LEAVE A RAINBOW BEHIND", Req = { Era = "GiantPlains" } },
		{ Id = "Lightning", Name = "LIGHTNING", Price = 500000, Desc = "CRACKLING BOLTS", Req = { Era = "GiantPlains" } },
		{ Id = "Spray", Name = "SEA SPRAY", Price = 2200000, Desc = "A ROOSTER TAIL OF RIVER WATER", Req = { Boss = "Tidebreaker" } },
	},
	Horn = {
		{ Id = "Beep", Name = "FACTORY BEEP", Price = 0, Desc = "THE FACTORY HORN", Say = "BEEP BEEP!" },
		{ Id = "Truck", Name = "BIG RIG", Price = 2500, Desc = "A HUGE TRUCK HORN", Say = "HOOOONK!" },
		{ Id = "Duck", Name = "RUBBER DUCK", Price = 3000, Desc = "QUACK QUACK", Say = "QUACK!" },
		{ Id = "Clown", Name = "CLOWN", Price = 5000, Desc = "HONK HONK", Say = "HONK HONK!" },
		{ Id = "Train", Name = "TRAIN", Price = 12000, Desc = "ALL ABOARD", Say = "CHOO CHOO!" },
		{ Id = "Raptor", Name = "RAPTOR", Price = 20000, Desc = "A RAPTOR SCREECH", Say = "SKREEEE!" },
		{ Id = "Fanfare", Name = "FANFARE", Price = 30000, Desc = "TA-DA-DAAA!", Say = "TA-DA-DAAA!" },
		{ Id = "Rex", Name = "REX ROAR", Price = 100000, Desc = "THE KING'S ROAR", Say = "RAAAWR!", Req = { Boss = "TyrantKing" } },
	},
}

-- colour slots (Stock = the body's own factory colour)
Rides.ColorSlots = { Paint = true, Paint2 = true, RimColor = true, WrapColor = true, GlowColor = true }
local STOCK_OK = { Paint = true, Paint2 = true, RimColor = true, WrapColor = true, GlowColor = true }

-- the garage studio's tabs, kid-sized: each tab is one or more rows of big tiles
Rides.Tabs = {
	{ Id = "Paint", Name = "PAINT", Icon = "Star", Rows = { { "Paint", "MAIN COLOUR" }, { "Paint2", "TRIM COLOUR" }, { "Finish", "FINISH" } } },
	{ Id = "Wheels", Name = "WHEELS", Icon = "Gear", Rows = { { "Rims", "RIMS" }, { "RimColor", "RIM COLOUR" }, { "Tires", "TYRES" }, { "Lift", "RIDE HEIGHT" } } },
	{ Id = "Kit", Name = "BODY KIT", Icon = "Wrench", Rows = { { "Front", "FRONT" }, { "Rear", "REAR" }, { "Roof", "ROOF" } } },
	{ Id = "Wrap", Name = "WRAPS", Icon = "Shield", Rows = { { "Wrap", "WRAP" }, { "WrapColor", "WRAP COLOUR" } } },
	{ Id = "Glow", Name = "GLOW", Icon = "Bolt", Rows = { { "Glow", "UNDERGLOW" }, { "GlowColor", "GLOW COLOUR" } } },
	{ Id = "Boost", Name = "BOOST", Icon = "Dart", Rows = { { "Trail", "BOOST TRAIL" } } },
	{ Id = "Horn", Name = "HORN", Icon = "Alert", Rows = { { "Horn", "HORN" } } },
}

Rides.Default = {
	Paint = "Stock", Paint2 = "Stock", Finish = "Gloss",
	Rims = "Stock", RimColor = "Stock", Tires = "Stock", Lift = "Stock",
	Front = "Stock", Rear = "Stock", Roof = "Stock",
	Wrap = "None", WrapColor = "Stock",
	Glow = "None", GlowColor = "Stock",
	Trail = "Flame", Horn = "Beep",
}
Rides.Slots = {}
for k in pairs(Rides.Default) do table.insert(Rides.Slots, k) end
table.sort(Rides.Slots)

local index = {} -- slot -> id -> item
for slot, list in pairs(Rides.Options) do
	index[slot] = {}
	for i, it in ipairs(list) do it.Order = i index[slot][it.Id] = it end
end
local colorIndex = {}
for i, c in ipairs(Rides.Colors) do c.Order = i colorIndex[c.Id] = c end
local STOCK_COLOR = { Id = "Stock", Name = "FACTORY", Price = 0, Order = 0 }
-- what "factory" means for the colour slots that have no body colour behind them
Rides.StockWrap = Color3.fromRGB(245, 245, 240)
Rides.StockGlow = Color3.fromRGB(112, 202, 255)

function Rides.List(slot: string): { any }
	if Rides.ColorSlots[slot] then
		if STOCK_OK[slot] then
			local l = { STOCK_COLOR }
			for _, c in ipairs(Rides.Colors) do table.insert(l, c) end
			return l
		end
		return Rides.Colors
	end
	return Rides.Options[slot] or {}
end

function Rides.Item(slot: string, id: string?): any
	if not id then return nil end
	if Rides.ColorSlots[slot] then
		if id == "Stock" then return STOCK_OK[slot] and STOCK_COLOR or nil end
		return colorIndex[id]
	end
	return index[slot] and index[slot][id]
end

function Rides.Fill(style: any?)
	local s = table.clone(Rides.Default)
	if typeof(style) == "table" then
		for k, v in pairs(style) do
			if Rides.Default[k] ~= nil and typeof(v) == "string" and Rides.Item(k, v) then s[k] = v end
		end
	end
	return s
end

function Rides.StyleFor(profile: any, body: string)
	return Rides.Fill(profile and profile.Rides and profile.Rides[body])
end

--------------------------------------------------------------------------------
-- shop rules
--------------------------------------------------------------------------------
function Rides.Key(slot: string, id: string): string
	return Rides.ColorSlots[slot] and ("Color:" .. id) or (slot .. ":" .. id)
end

function Rides.Owns(profile: any, slot: string, id: string): boolean
	local it = Rides.Item(slot, id)
	if not it then return false end
	if (it.Price or 0) <= 0 then return true end
	return profile ~= nil and profile.RideOwned ~= nil and profile.RideOwned[Rides.Key(slot, id)] == true
end

-- nil when you can buy it; otherwise what you still have to do
function Rides.LockReason(profile: any, item: any): string?
	local req = item and item.Req
	if not req then return nil end
	if req.Era and not (profile and profile.Unlocked and profile.Unlocked[req.Era]) then
		local name = req.Era
		for _, e in ipairs(Config.Eras or {}) do if e.Id == req.Era then name = e.Name end end
		return "OPEN " .. string.upper(name)
	end
	if req.Boss then
		local rec = profile and profile.Bosses and profile.Bosses[req.Boss]
		if not (rec and (rec.Clears or 0) > 0) then
			local b = Config.Bosses and Config.Bosses[req.Boss]
			return "BEAT THE " .. string.upper((b and b.Name) or req.Boss)
		end
	end
	if req.Runs and not (profile and profile.Stats and (profile.Stats.Runs or 0) >= req.Runs) then
		return "DO " .. req.Runs .. " EXPEDITIONS"
	end
	-- a secret paint is never bought: until it's yours (Owns), this is how you get it
	if req.Secrets then
		local name = req.Secrets
		for _, e in ipairs(Config.Eras or {}) do if e.Id == req.Secrets then name = e.Name end end
		return "FIND ALL " .. string.upper(name) .. " SECRETS"
	end
	return nil
end

function Rides.Price(slot: string, id: string): number
	local it = Rides.Item(slot, id)
	return it and (it.Price or 0) or 0
end

-- every slot of a style is something this profile owns
function Rides.Valid(profile: any, style: any): (boolean, string?)
	for _, slot in ipairs(Rides.Slots) do
		local id = style[slot]
		if typeof(id) ~= "string" or not Rides.Item(slot, id) then return false, "UNKNOWN PART" end
		if not Rides.Owns(profile, slot, id) then return false, "YOU DON'T OWN " .. Rides.Item(slot, id).Name end
	end
	return true, nil
end

--------------------------------------------------------------------------------
-- stats
--------------------------------------------------------------------------------
local STAT_SLOTS = { "Rims", "Tires", "Lift", "Front", "Rear", "Roof" }
function Rides.Stats(body: string, style: any?)
	local base = Config.Vehicles[body] or Config.Vehicles.RookieRanger
	local s = Rides.Fill(style)
	local add = { Speed = 0, Boost = 0, Armor = 0, Grip = 0 }
	for _, slot in ipairs(STAT_SLOTS) do
		local it = Rides.Item(slot, s[slot])
		if it and it.Stats then
			for k, v in pairs(it.Stats) do add[k] = (add[k] or 0) + v end
		end
	end
	return {
		Name = base.Name, Order = base.Order,
		HP = math.floor(base.HP * (1 + add.Armor / 100) + 0.5),
		Cruise = base.Cruise + add.Speed,
		Boost = base.Boost + add.Speed + add.Boost,
		Darts = base.Darts,
		Grip = math.max(0.6, 1 + add.Grip / 100),
		Add = add,
	}
end

--------------------------------------------------------------------------------
-- styling a model
--------------------------------------------------------------------------------
-- looked up when used: on clients the kit folder can replicate after this module first loads
local function kitsFolder(): Instance?
	local d = ReplicatedStorage:FindFirstChild("DinoExpedition")
	return d and d:FindFirstChild("RoverKits")
end

function Rides.Color(id: string?): Color3?
	local c = id and colorIndex[id]
	return c and c.Color or nil
end

local function shade(c: Color3, f: number): Color3
	if f >= 1 then return c:Lerp(Color3.new(1, 1, 1), math.min(1, f - 1)) end
	return Color3.new(c.R * f, c.G * f, c.B * f)
end
Rides.Shade = shade

local function weldTo(p: BasePart, to: BasePart)
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	local w = Instance.new("Weld")
	w.Name = "Weld"
	w.Part0 = to
	w.Part1 = p
	w.C0 = to.CFrame:Inverse() * p.CFrame
	w.Parent = p
end

-- clone a kit model into the rover, every part welded to `to` (the root, or a wheel hub)
local function graft(kit: Instance, into: Instance, to: BasePart): Instance
	local c = kit:Clone()
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then weldTo(p, to) end
	end
	if c:IsA("BasePart") then weldTo(c, to) end
	c.Parent = into
	return c
end

local function partsIn(m: Instance, fn: (BasePart) -> ())
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then fn(p) end
	end
end

local RIM_PARTS = { Rim = true, RimLip = true, RimAccent = true, Spoke = true, LugNut = true }
local TIRE_PARTS = { Tire = true, Sidewall = true, Tread = true }
local LOWER_PARTS = { Axle = true, Differential = true, LeafSpring = true, TrailingArm = true, AArm = true, DiffCover = true }

local function wheels(v: Model): { Model }
	local list = {}
	for _, m in ipairs(v:GetDescendants()) do
		if m:IsA("Model") and m.Name:match("^Wheel%u") then table.insert(list, m) end
	end
	return list
end

local function underglow(v: Model, root: BasePart, ground: number, color: Color3)
	local L = v:GetAttribute("Length") or 14
	local W = v:GetAttribute("Width") or 7
	local f = Instance.new("Model")
	f.Name = "Underglow"
	local y = ground + 0.75
	local function strip(size: Vector3, pos: Vector3, i: number)
		local p = Instance.new("Part")
		p.Name = "GlowStrip"
		p.Size = size
		p.CFrame = root.CFrame * CFrame.new(pos)
		p.Material = Enum.Material.Neon
		p.Color = shade(color, 0.7) -- neon under bloom: a glow, not a floodlight
		p.CastShadow = false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p:SetAttribute("GlowIndex", i)
		p.Parent = f
		weldTo(p, root)
		return p
	end
	local hx, hz = W / 2 - 1.5, L / 2 - 2.2
	strip(Vector3.new(0.3, 0.22, hz * 2), Vector3.new(hx, y, 0), 0)
	strip(Vector3.new(hx * 2, 0.22, 0.3), Vector3.new(0, y, hz), 1)
	strip(Vector3.new(0.3, 0.22, hz * 2), Vector3.new(-hx, y, 0), 2)
	strip(Vector3.new(hx * 2, 0.22, 0.3), Vector3.new(0, y, -hz), 3)
	-- the light that paints the ground
	local plate = Instance.new("Part")
	plate.Name = "GlowPlate"
	plate.Size = Vector3.new(hx * 2, 0.1, hz * 2)
	plate.CFrame = root.CFrame * CFrame.new(0, y + 0.05, 0)
	plate.Transparency = 1
	plate.CastShadow = false
	plate.Parent = f
	weldTo(plate, root)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 120
	light.Range = 10
	light.Brightness = 2
	light.Color = color
	light.Parent = plate
	f.Parent = v
end

-- restyle a body: call on a fresh clone of its template, BEFORE it is moved (kits are authored in template space)
function Rides.Apply(v: Model, body: string, style: any?)
	local s = Rides.Fill(style)
	local root = v.PrimaryPart
	if not root then return end
	local folder = kitsFolder()
	local kits = folder and folder:FindFirstChild(body)
	local function kit(group: string, id: string): Instance?
		local g = kits and kits:FindFirstChild(group)
		return g and g:FindFirstChild(id)
	end
	-- 1. kits that replace stock bits (front / rear / roof)
	for _, slot in ipairs({ "Front", "Rear", "Roof" }) do
		local k = s[slot] ~= "Stock" and kit(slot, s[slot])
		if k then
			for _, p in ipairs(v:GetDescendants()) do
				if p:IsA("BasePart") and p:GetAttribute("KitSlot") == slot then p:Destroy() end
			end
			graft(k, v, root)
		end
	end
	local wrap = s.Wrap ~= "None" and kit("Wrap", s.Wrap)
	if wrap then graft(wrap, v, root) end
	-- 2. wheels: new rims and / or tyres on every road wheel (the hub stays: it carries the wheel's joint)
	local rims = s.Rims ~= "Stock" and kit("Wheels", "Rim_" .. s.Rims)
	local tires = s.Tires ~= "Stock" and kit("Wheels", "Tire_" .. s.Tires)
	for _, w in ipairs(wheels(v)) do
		local hub = w:FindFirstChild("Hub", true) :: BasePart?
		if not hub then continue end
		if rims and rims:FindFirstChild(w.Name) then
			for _, p in ipairs(w:GetDescendants()) do if p:IsA("BasePart") and RIM_PARTS[p.Name] then p:Destroy() end end
			graft((rims :: Instance):FindFirstChild(w.Name) :: Instance, w, hub)
		end
		if tires and tires:FindFirstChild(w.Name) then
			for _, p in ipairs(w:GetDescendants()) do if p:IsA("BasePart") and TIRE_PARTS[p.Name] then p:Destroy() end end
			graft((tires :: Instance):FindFirstChild(w.Name) :: Instance, w, hub)
		end
	end
	-- 3. paint: every part tagged with a paint role
	Rides.Paint(v, s, v:GetAttribute("StockP"), v:GetAttribute("StockS"))
	-- 4. ride height: the body rises, the wheels (and axles) stay on the ground
	Rides.Lift(v, s)
	-- 5. underglow (clients animate the modes) + what the effects layer needs to know
	local liftItem = Rides.Item("Lift", s.Lift)
	local lift = liftItem and liftItem.Lift or 0
	if s.Glow ~= "None" then
		underglow(v, root, -(v:GetAttribute("RootHeight") or 2.6), Rides.Color(s.GlowColor) or Rides.StockGlow)
	end
	v:SetAttribute("Glow", s.Glow)
	v:SetAttribute("GlowColor", s.GlowColor)
	v:SetAttribute("Trail", s.Trail)
	v:SetAttribute("Horn", s.Horn)
	v:SetAttribute("Roof", s.Roof)
	v:SetAttribute("Lift", lift)
end

-- colour every paint-role part under `container` (also used on the garage studio's thumbnails)
function Rides.Paint(container: Instance, style: any, stockP: string?, stockS: string?)
	local s = Rides.Fill(style)
	local P = Rides.Color(s.Paint) or (stockP and Color3.fromHex(stockP)) or nil
	local S = Rides.Color(s.Paint2) or (stockS and Color3.fromHex(stockS)) or nil
	local R = Rides.Color(s.RimColor)
	local Wc = Rides.Color(s.WrapColor) or Rides.StockWrap
	local finish = s.Finish
	partsIn(container, function(p)
		local role = p:GetAttribute("Paint")
		if not role then return end
		local f = p:GetAttribute("Shade") or 1
		if role == "P" and P then
			p.Color = shade(P, f)
			if finish == "Matte" then
				p.Reflectance = 0
				p.Color = shade(p.Color, 0.86)
			elseif finish == "Metallic" then
				p.Material = Enum.Material.SmoothPlastic
				p.Reflectance = 0.22
			elseif finish == "Chrome" then
				p.Material = Enum.Material.SmoothPlastic
				p.Reflectance = 0.5
				p.Color = shade(p.Color, 1.12)
			elseif finish == "Neon" then
				-- glowing, but dimmed hard so it reads as a glow and not a white blob under bloom
				p.Material = Enum.Material.Neon
				p.Color = shade(p.Color, 0.42)
			elseif finish == "Ghost" then
				p.Material = Enum.Material.ForceField
			else
				p.Reflectance = math.max(p.Reflectance, 0.05)
			end
		elseif role == "S" and S then
			p.Color = shade(S, f)
		elseif role == "R" and R then
			p.Color = shade(R, f)
		elseif role == "W" then
			p.Color = shade(Wc, f)
		end
	end)
end

-- ride height: the body rises, the wheels (and axles) stay on the ground
function Rides.Lift(v: Model, s: any)
	local root = v.PrimaryPart :: BasePart
	local liftItem = Rides.Item("Lift", s.Lift)
	local lift = liftItem and liftItem.Lift or 0
	local rh = v:GetAttribute("RootHeight") or 2.6
	if lift > 0 then
		local down = CFrame.new(0, -lift, 0)
		for _, m in ipairs(root:GetChildren()) do
			if m:IsA("Motor6D") and m.Name:match("^Wheel") then m.C0 = down * m.C0 end
		end
		for _, w in ipairs(v:GetDescendants()) do
			if w:IsA("Weld") and w.Part0 == root and w.Part1 then
				local p1 = w.Part1 :: BasePart
				local inWheel = p1:FindFirstAncestorWhichIsA("Model")
				if (inWheel and inWheel ~= v and inWheel.Name:match("^Wheel%u")) or LOWER_PARTS[p1.Name] then w.C0 = down * w.C0 end
			end
		end
		-- chunky lift struts so the gap reads as suspension, not a floating body
		local seen = {}
		for _, w in ipairs(wheels(v)) do
			local hub = w:FindFirstChild("Hub", true) :: BasePart?
			if not hub or seen[w] then continue end
			seen[w] = true
			local lp = root.CFrame:PointToObjectSpace(hub.Position)
			local inward = lp.X > 0 and -1 or 1
			local strut = Instance.new("Part")
			strut.Name = "LiftStrut"
			strut.Shape = Enum.PartType.Cylinder
			strut.Size = Vector3.new(lift + 1.4, 0.42, 0.42)
			strut.Color = Color3.fromRGB(200, 205, 212)
			strut.Material = Enum.Material.Metal
			strut.CFrame = root.CFrame * CFrame.new(lp.X + inward * 1.1, lp.Y + 0.5 - lift / 2 + 0.2, lp.Z) * CFrame.Angles(0, 0, math.pi / 2)
			strut.Parent = w
			weldTo(strut, root)
			local spring = Instance.new("Part")
			spring.Name = "LiftSpring"
			spring.Shape = Enum.PartType.Cylinder
			spring.Size = Vector3.new(lift + 0.6, 0.7, 0.7)
			spring.Color = Rides.Color(s.RimColor) or Color3.fromRGB(230, 60, 40)
			spring.Material = Enum.Material.SmoothPlastic
			spring.CFrame = strut.CFrame
			spring.Parent = w
			weldTo(spring, root)
		end
		v:SetAttribute("RootHeight", rh + lift)
		v:SetAttribute("Height", (v:GetAttribute("Height") or 8) + lift)
	end
end

return Rides
