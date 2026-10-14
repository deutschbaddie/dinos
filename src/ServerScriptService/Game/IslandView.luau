--[[
	IslandView — dresses every island to match its owner's buildings (Config.Island), on the server so everyone
	who walks over the bridge sees it.

	Plots.Sync writes the plot attribute "Island" (JSON { Hatchery = tier, Garage = tier, Pens = { lot -> {
	Species, Dino } } }). This clones the kit models (ReplicatedStorage.DinoExpedition.IslandKit, built by
	tools/gen/islandKit.js) onto the building anchors in the map (HatcheryAnchor, GarageAnchor, each lot's
	LotAnchor), and hides a star lot's survey stakes once its pen stands there. A freed island goes back to tier 1.
	Kit model names: HatcheryT2, HatcheryT3, GarageT2, GarageT3, Pen_<Species>_<Lot>.
	The SHOWCASE pedestal (2026-10-14): Showcase at ShowcaseAnchor, always (the client draws the dino on it).
	The POWER TRAINER (2026-10-14): Trainer1..Trainer7 at TrainerAnchor - always one (a free island shows the first),
	the tier from the plot attribute "TrainerLevel" (Trainer.luau), its four LevelPip lights showing the level in it.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local IslandView = {}

local kit: Instance? = nil
local STAKES = { SurveyStake = true, StakeFlag = true, SurveyString = true, LotDirt = true, Buoy = true, BuoyTop = true }

local function decode(plot: Model)
	local raw = plot:GetAttribute("Island")
	if typeof(raw) ~= "string" or raw == "" then return nil end
	local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and t or nil
end

local function anchorFor(plot: Model, name: string): BasePart?
	if name:match("^Trainer") then return plot:FindFirstChild("TrainerAnchor", true) :: BasePart? end
	if name == "Showcase" then return plot:FindFirstChild("ShowcaseAnchor", true) :: BasePart? end
	if name:match("^Hatchery") then return plot:FindFirstChild("HatcheryAnchor", true) :: BasePart? end
	if name:match("^Garage") then return plot:FindFirstChild("GarageAnchor", true) :: BasePart? end
	local lot = name:match("^Pen_[%w]+_(Star%w)$")
	local group = lot and plot:FindFirstChild(lot, true)
	return group and group:FindFirstChild("LotAnchor", true) :: BasePart? or nil
end

local function trainerLevel(plot: Model): number
	return math.clamp(math.floor(tonumber(plot:GetAttribute("TrainerLevel")) or 1), 1, #Config.Trainer.Levels)
end

local function wanted(state, plot: Model): { [string]: boolean }
	local want = {}
	want["Trainer" .. Config.TrainerTier(trainerLevel(plot))] = true
	want.Showcase = true -- (the SHOWCASE pedestal stands on every island; ShowcaseView puts the owner's star on it)
	if not state then return want end
	local h, g = tonumber(state.Hatchery) or 1, tonumber(state.Garage) or 1
	for t = 2, h do want["HatcheryT" .. t] = true end
	for t = 2, g do want["GarageT" .. t] = true end
	for lot, pen in pairs(state.Pens or {}) do
		if typeof(pen) == "table" and typeof(pen.Species) == "string" then want["Pen_" .. pen.Species .. "_" .. lot] = true end
	end
	return want
end

local function setStakes(lotGroup: Instance, built: boolean)
	for _, p in ipairs(lotGroup:GetDescendants()) do
		if p:IsA("BasePart") and STAKES[p.Name] then
			if p:GetAttribute("T0") == nil then p:SetAttribute("T0", p.Transparency) end
			p.Transparency = built and 1 or (p:GetAttribute("T0") :: number)
		end
	end
end

local function apply(plot: Model)
	if not kit then return end
	local state = decode(plot)
	local want = wanted(state, plot)
	local folder = plot:FindFirstChild("IslandKit")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "IslandKit"
		folder.Parent = plot
	end
	for _, m in ipairs((folder :: Instance):GetChildren()) do
		if not want[m.Name] then m:Destroy() end
	end
	for name in pairs(want) do
		if not (folder :: Instance):FindFirstChild(name) then
			local src = (kit :: Instance):FindFirstChild(name)
			local at = anchorFor(plot, name)
			if src and src:IsA("Model") and at then
				local m = src:Clone()
				m:PivotTo(at.CFrame)
				m.Parent = folder
			elseif not src then
				warn("[IslandView] no kit model", name)
			end
		end
	end
	-- the trainer's level lights: one per level reached in this tier (they glow in the tier's accent colour)
	local lvl = trainerLevel(plot)
	local inTier = (lvl - 1) % Config.Trainer.PerTier + 1
	for _, m in ipairs((folder :: Instance):GetChildren()) do
		if m:IsA("Model") and m.Name:match("^Trainer%d+$") then
			for _, pip in ipairs(m:GetDescendants()) do
				local k = pip:IsA("BasePart") and tonumber(pip.Name:match("^LevelPip(%d)$"))
				if k and pip:IsA("BasePart") then
					if pip:GetAttribute("OnColor") == nil then pip:SetAttribute("OnColor", pip.Color) end
					local on = k <= inTier
					pip.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
					pip.Color = on and (pip:GetAttribute("OnColor") :: Color3) or Color3.fromRGB(58, 62, 70)
				end
			end
		end
	end
	-- star lots: the stakes go once a pen stands there
	local pens = state and state.Pens or {}
	for _, lotGroup in ipairs(plot:GetDescendants()) do
		if lotGroup:IsA("Model") and lotGroup:GetAttribute("StarPen") then
			setStakes(lotGroup, pens[lotGroup.Name] ~= nil)
		end
	end
end

function IslandView.Start()
	kit = ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("IslandKit", 30)
	if not kit then warn("[IslandView] IslandKit is missing (run node tools/gen/build.js)") end
	local camp = Workspace:WaitForChild("BaseCamp", 30)
	local plots = camp and camp:WaitForChild("Plots", 30)
	if not plots then return end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:IsA("Model") and plot:GetAttribute("PlotIndex") then
			plot:GetAttributeChangedSignal("Island"):Connect(function() apply(plot) end)
			plot:GetAttributeChangedSignal("TrainerLevel"):Connect(function() apply(plot) end)
			apply(plot)
		end
	end
	print("[IslandView] dressing", #plots:GetChildren(), "islands")
end

return IslandView
