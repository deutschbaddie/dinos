--[[
	Icons — every icon in the UI is a real image. Paste each uploaded image's asset id into IDS
	("rbxassetid://123..."); until then a clean placeholder badge (color + letter) shows in its place.
	The image prompts for all of these live in ICON_PROMPTS.md at the project root.

	Icons.Make(name, opts) -> GuiObject
	  name: a key of IDS ("Coin", "Gear", ...), "Egg" + opts.Species (tinted to the species), "Dino" + opts.Species
	        (that species' portrait), "Jeep"/"Vehicle" + opts.Vehicle (that vehicle's picture)
	  opts: Size, Position, AnchorPoint, ZIndex, Parent, Silhouette (undiscovered: black shape), Rotation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))

local Icons = {}

-- paste uploaded image ids here ----------------------------------------------------------------
local IDS: { [string]: string } = {
	-- HUD + menus
	Coin = "rbxassetid://90166846371901", Gem = "rbxassetid://87663836907981", Gear = "rbxassetid://88483182942688", Shop = "rbxassetid://77074648106620", Index = "rbxassetid://97814633801298", Gate = "rbxassetid://114317058205368", Home = "rbxassetid://131096216144115", Garage = "rbxassetid://109842726932511",
	Shield = "rbxassetid://72654118132054", Bolt = "rbxassetid://76269971422076", Dart = "rbxassetid://103628377924267", Star = "rbxassetid://134015790422651", Lock = "rbxassetid://111372569291804", Eye = "rbxassetid://128095744830301", Alert = "rbxassetid://139939329473440", Trophy = "rbxassetid://129043539375034",
	Egg = "rbxassetid://79950432450814", Dino = "rbxassetid://104785299347295", Jeep = "rbxassetid://78448843176673", Hand = "rbxassetid://134838306576856", Door = "rbxassetid://125628676107763", Footprints = "rbxassetid://90514576981203", Clock = "rbxassetid://106869413136914", Map = "rbxassetid://112331194002025", Gift = "rbxassetid://103005098748432",
	Wrench = "rbxassetid://83677731758565", Paddock = "rbxassetid://125068758088161", Incubator = "rbxassetid://132226545894668",
	-- dinosaur portraits (Dino_<Species>)
	Dino_Velociraptor = "rbxassetid://78057023463383", Dino_Triceratops = "rbxassetid://80107182486696", Dino_Parasaurolophus = "rbxassetid://97900512384571", Dino_Stegosaurus = "rbxassetid://97737083682301",
	Dino_Ankylosaurus = "rbxassetid://137923187053026", Dino_Carnotaurus = "rbxassetid://91676532653581", Dino_Brachiosaurus = "rbxassetid://70994417282001", Dino_Spinosaurus = "rbxassetid://93573509533316",
	Dino_TyrannosaurusRex = "rbxassetid://101253880255231", Dino_Giganotosaurus = "rbxassetid://121779622245276", Dino_Mosasaurus = "rbxassetid://131161252547954", Dino_PrimalRex = "rbxassetid://100478668687903",
	-- round 2 (see ICON_PROMPTS.md "More icons"): ids pasted 2026-10-11 (FALLBACK still covers any blank one)
	Bag = "rbxassetid://93407548741694", Sell = "rbxassetid://137426040514125", Quest = "rbxassetid://107061009445402", Power = "rbxassetid://79405887766973", Key = "rbxassetid://114971468343053", Hammer = "rbxassetid://125800372950220", Crown = "rbxassetid://81367547252659", Film = "rbxassetid://70585695666919", Chest = "rbxassetid://87188697379535",
	Launcher = "rbxassetid://96666400944229", Armor = "rbxassetid://92863184337813", Rack = "rbxassetid://133451717237768", Buddy = "rbxassetid://84980079887344", Gadget_Bait = "rbxassetid://74613918772010", Gadget_Flare = "rbxassetid://85639659324903", Gadget_Earthshaker = "rbxassetid://109451442209739",
	Mat_QueenClaw = "rbxassetid://121428859974826", Mat_MatriarchScale = "rbxassetid://113767907114966", Era_FernValley = "rbxassetid://132532036947512", Era_GiantPlains = "rbxassetid://75182303888679",
	-- new eras (2026-10-13): their boss materials, era cards and every new species' portrait
	Mat_TideScale = "rbxassetid://90108205008094", Mat_ScytheClaw = "rbxassetid://132138498185202", Mat_FrostPlume = "rbxassetid://76197279589208", Mat_DawnScute = "rbxassetid://138669755491666",
	Era_SpineRiver = "rbxassetid://71463485162578", Era_RedCliffs = "rbxassetid://114134552740815", Era_FrostForest = "rbxassetid://99888126856278", Era_DawnDesert = "rbxassetid://100703686630057",
	Dino_Yutyrannus = "rbxassetid://128381577039306", Dino_Protoceratops = "rbxassetid://116929053129880", Dino_Therizinosaurus = "rbxassetid://79285240016047", Dino_Sarcosuchus = "rbxassetid://105212328529931",
	Dino_Psittacosaurus = "rbxassetid://119088446180772", Dino_Oviraptor = "rbxassetid://122391967512670", Dino_Postosuchus = "rbxassetid://134591147134400", Dino_Microraptor = "rbxassetid://134092705517858",
	Dino_Plateosaurus = "rbxassetid://79121706128013", Dino_Dilophosaurus = "rbxassetid://121786502501239", Dino_Compy = "rbxassetid://98129401760195", Dino_Gallimimus = "rbxassetid://108678620662530",
	Dino_Coelophysis = "rbxassetid://103589557480204",
	-- vehicles (Vehicle_<Name>)
	Vehicle_RookieRanger = "rbxassetid://102110485969223", Vehicle_RaptorRunner = "rbxassetid://94660127172326", Vehicle_TitanTransport = "rbxassetid://94513240541775",
}
Icons.IDS = IDS
-------------------------------------------------------------------------------------------------

local ALIAS = { Cart = "Shop", Heart = "Shield", Plus = "Wrench", Car = "Jeep", Vehicle = "Jeep", Book = "Index" }
local FALLBACK = {
	Bag = "Egg", Sell = "Coin", Quest = "Star", Power = "Shield", Key = "Lock", Hammer = "Wrench", Crown = "Trophy", Film = "Eye", Chest = "Gift",
	Launcher = "Dart", Armor = "Shield", Rack = "Egg", Buddy = "Dino", Gadget_Bait = "Bolt", Gadget_Flare = "Bolt", Gadget_Earthshaker = "Bolt",
	Mat_QueenClaw = "Trophy", Mat_MatriarchScale = "Trophy", Mat_TideScale = "Trophy", Mat_ScytheClaw = "Trophy", Mat_FrostPlume = "Trophy", Mat_DawnScute = "Trophy", Era_FernValley = "Gate", Era_GiantPlains = "Gate", Era_SpineRiver = "Gate", Era_RedCliffs = "Gate", Era_FrostForest = "Gate", Era_DawnDesert = "Gate",
}

-- placeholder look per icon: { color, letter }
local C = Theme.C
local PLACEHOLDER = {
	Coin = { C.Yellow, "$" }, Gem = { C.Blue, "G" }, Gear = { C.Grey, "S" }, Shop = { C.Orange, "S" }, Index = { C.Blue, "i" },
	Gate = { C.Teal, "T" }, Home = { C.Yellow, "H" }, Garage = { C.Orange, "G" }, Shield = { C.Blue, "A" }, Bolt = { C.Blue, "B" },
	Dart = { C.Orange, "D" }, Star = { C.Yellow, "*" }, Lock = { C.Grey, "L" }, Eye = { C.Purple, "o" }, Alert = { C.Red, "!" },
	Trophy = { C.Yellow, "W" }, Egg = { C.Cream, "E" }, Dino = { C.Lime, "R" }, Jeep = { C.Orange, "J" }, Hand = { C.Cream, "G" },
	Door = { C.Orange, "X" }, Footprints = { C.Lime, "F" }, Clock = { C.Cream, "T" }, Map = { C.Yellow, "M" }, Gift = { C.Red, "G" },
	Wrench = { C.Orange, "U" }, Paddock = { C.Lime, "P" }, Incubator = { C.Teal, "I" },
}

local idFor
function idFor(name: string, opts): (string, Color3?)
	if name == "Egg" then
		local sp = opts.Species and Config.Species[opts.Species]
		return IDS.Egg or "", sp and sp.Color or nil
	end
	if name == "Dino" and opts.Species then
		local id = IDS["Dino_" .. opts.Species]
		if id and id ~= "" then return id, nil end
		return IDS.Dino or "", nil
	end
	if name == "Jeep" and opts.Vehicle then
		local id = IDS["Vehicle_" .. opts.Vehicle]
		if id and id ~= "" then return id, nil end
	end
	local id = IDS[name] or ""
	if id == "" and FALLBACK[name] then return idFor(FALLBACK[name], opts) end
	return id, nil
end

function Icons.Has(name: string): boolean
	name = ALIAS[name] or name
	return (IDS[name] or "") ~= ""
end

function Icons.Make(name: string, opts)
	opts = opts or {}
	name = ALIAS[name] or name
	local id, tint = idFor(name, opts)
	local z = opts.ZIndex or 5
	local obj: GuiObject
	if id ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = id
		img.ScaleType = Enum.ScaleType.Fit
		if opts.Silhouette then
			img.ImageColor3 = Color3.fromRGB(20, 26, 22)
		elseif tint then
			img.ImageColor3 = Color3.new(1, 1, 1):Lerp(tint, 0.55)
		end
		obj = img
	else
		-- placeholder badge: a chunky circle in the icon's color with its letter, outlined like the rest of the UI
		local look = PLACEHOLDER[name] or { C.Lime, string.sub(name, 1, 1) }
		local color = opts.Silhouette and Color3.fromRGB(30, 38, 32) or (tint or look[1])
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		local disc = Instance.new("Frame")
		disc.Name = "Disc"
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5, 0.5)
		disc.Size = UDim2.fromScale(0.78, 0.78)
		disc.BackgroundColor3 = color
		disc.ZIndex = z
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(name == "Egg" and 0.45 or 0.5, 0)
		corner.Parent = disc
		local st = Instance.new("UIStroke")
		st.Color = C.Ink
		st.Thickness = 3
		st.Parent = disc
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
		g.Parent = disc
		if name == "Egg" then disc.Size = UDim2.fromScale(0.62, 0.8) end
		disc.Parent = f
		if not opts.Silhouette then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(0.62, 0.62)
			t.AnchorPoint = Vector2.new(0.5, 0.5)
			t.Position = UDim2.fromScale(0.5, 0.52)
			t.FontFace = Theme.Display
			t.TextScaled = true
			t.Text = look[2]
			t.TextColor3 = Color3.new(1, 1, 1)
			t.ZIndex = z + 1
			local ts = Instance.new("UIStroke")
			ts.Color = C.Ink
			ts.Thickness = 2
			ts.Parent = t
			t.Parent = disc
		end
		obj = f
	end
	obj.Name = "Icon_" .. name
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = obj
	obj.Size = opts.Size or UDim2.fromOffset(48, 48)
	obj.Position = opts.Position or UDim2.new()
	obj.AnchorPoint = opts.AnchorPoint or Vector2.zero
	obj.ZIndex = z
	obj.Rotation = opts.Rotation or 0
	if opts.Parent then obj.Parent = opts.Parent end
	return obj
end

return Icons
