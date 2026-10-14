--[[
	Plots — one camp plot per player at Base Camp. Assignment, the owner sign, spawning at home,
	the cash pad (income accrues every second, step on the pad to collect) and the replicated
	plot state that every client renders (incubators, babies, pending cash).
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Plots = {}
local Data, Net, Dinos
local plotOf = {} :: { [Player]: Model }
local owners = {} :: { [Model]: Player }

local function camp(): Model
	return Workspace:WaitForChild("BaseCamp") :: Model
end

local function allPlots(): { Model }
	local list = {}
	for _, p in ipairs(camp():WaitForChild("Plots"):GetChildren()) do
		if p:IsA("Model") and p:GetAttribute("PlotIndex") then table.insert(list, p) end
	end
	table.sort(list, function(a, b) return a:GetAttribute("PlotIndex") < b:GetAttribute("PlotIndex") end)
	return list
end

local function setSign(plot: Model, text: string)
	local sign = plot:FindFirstChild("OwnerSign", true)
	if not sign then return end
	for _, gui in ipairs(sign:GetChildren()) do
		if gui:IsA("SurfaceGui") then
			for _, l in ipairs(gui:GetDescendants()) do
				if l:IsA("TextLabel") then l.Text = text end
			end
		end
	end
end

function Plots.Get(player: Player): Model?
	return plotOf[player]
end

function Plots.OwnerOf(plot: Model): Player?
	return owners[plot]
end

function Plots.Find(plot: Model, name: string): Instance?
	return plot:FindFirstChild(name, true)
end

function Plots.SpawnCFrame(player: Player): CFrame?
	local plot = plotOf[player]
	local m = plot and plot:FindFirstChild("PlayerSpawn", true)
	if m and m:IsA("BasePart") then
		-- face into the plot: shed, pen and garage in view
		return m.CFrame * CFrame.Angles(0, math.pi, 0)
	end
	return nil
end

-- the plot state every client renders: incubators, the dinos roaming your yard, cash, trophies
function Plots.Sync(player: Player)
	local plot, profile = plotOf[player], Data.Peek(player)
	if not plot or not profile then return end
	local incs = {}
	for _, inc in ipairs(profile.Incubators) do
		table.insert(incs, { Slot = inc.Slot, Species = inc.Species, Rarity = inc.Rarity, KG = inc.KG, Start = inc.Start, Duration = inc.Duration })
	end
	plot:SetAttribute("Incubators", HttpService:JSONEncode(incs))
	plot:SetAttribute("IncubatorCount", profile.IncubatorCount)
	local yard = {}
	for _, d in ipairs(Dinos.PlacedList(profile)) do
		table.insert(yard, { d.Id, d.Species, d.Rarity, d.KG })
	end
	plot:SetAttribute("Yard", HttpService:JSONEncode(yard))
	-- your companions follow you round camp (only yard dinos; the lead one first)
	local comps = {}
	for _, id in ipairs(profile.Buddies) do
		if table.find(profile.Placed, id) then table.insert(comps, id) end
	end
	plot:SetAttribute("Companions", HttpService:JSONEncode(comps))
	plot:SetAttribute("CompanionSlots", profile.Gear.BuddySlots or 1)
	plot:SetAttribute("PenSlots", profile.PenSlots)
	plot:SetAttribute("Pending", math.floor(profile.Pending))
	plot:SetAttribute("Rate", Dinos.Rate(profile, player))
	local trophies = {}
	for id, b in pairs(profile.Bosses) do trophies[id] = b.Best or 0 end
	plot:SetAttribute("Trophies", HttpService:JSONEncode(trophies))
	plot:SetAttribute("Launcher", profile.Gear.Launcher)
	plot:SetAttribute("Armor", profile.Gear.Armor)
	-- your island's buildings (IslandView dresses them on the server, CampView puts each star in its pen)
	local pens = {}
	for lot, pen in pairs(Dinos.PenList(profile)) do
		local d = pen.Dino
		pens[lot] = { Species = pen.Species, Dino = d and { d.Id, d.Species, d.Rarity, d.KG } or nil }
	end
	plot:SetAttribute("Island", HttpService:JSONEncode({ Hatchery = Config.IslandTier(profile, "Hatchery"), Garage = Config.IslandTier(profile, "Garage"), Pens = pens }))
end

function Plots.Assign(player: Player): Model?
	for _, plot in ipairs(allPlots()) do
		if not owners[plot] then
			owners[plot] = player
			plotOf[player] = plot
			plot:SetAttribute("Owner", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName)
			local name = string.upper(player.DisplayName)
			if #name > 12 then name = name:sub(1, 11) .. "." end
			setSign(plot, name .. "'S ISLAND")
			player:SetAttribute("Plot", plot:GetAttribute("PlotIndex"))
			return plot
		end
	end
	warn("[Plots] no free plot for", player.Name)
	return nil
end

function Plots.Release(player: Player)
	local plot = plotOf[player]
	if not plot then return end
	owners[plot] = nil
	plotOf[player] = nil
	plot:SetAttribute("Owner", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("Incubators", "[]")
	plot:SetAttribute("Yard", "[]")
	plot:SetAttribute("Trophies", "{}")
	plot:SetAttribute("Pending", 0)
	plot:SetAttribute("Rate", 0)
	plot:SetAttribute("Island", "")
	setSign(plot, "FREE ISLAND")
end

function Plots.Collect(player: Player)
	local profile = Data.Peek(player)
	if not profile then return end
	local amount = math.floor(profile.Pending)
	if amount <= 0 then return end
	profile.Pending -= amount
	profile.Coins += amount
	profile.Earned += amount
	Net.Fire(player, "Collected", { Amount = amount })
	Plots.Sync(player)
	Data.Changed(player)
end

local function characterOf(hit: BasePart): Player?
	local node: Instance? = hit.Parent
	while node and node ~= Workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then return Players:GetPlayerFromCharacter(node) end
		node = node.Parent
	end
	return nil
end

function Plots.Start(deps)
	Data, Net, Dinos = deps.Data, deps.Net, deps.Dinos
	for _, plot in ipairs(allPlots()) do
		plot:SetAttribute("Owner", 0)
		local pad = plot:FindFirstChild("CashPad", true)
		if pad and pad:IsA("BasePart") then
			local last = {}
			pad.Touched:Connect(function(hit)
				local plr = characterOf(hit)
				if not plr or owners[plot] ~= plr then return end
				if last[plr] and os.clock() - last[plr] < 0.6 then return end
				last[plr] = os.clock()
				Plots.Collect(plr)
			end)
		end
	end
	-- income: every second, the dinos in your yard earn into your cash pad (auto-collect pass skips the pad)
	task.spawn(function()
		while true do
			task.wait(1)
			for plr, plot in pairs(plotOf) do
				local profile = Data.Peek(plr)
				if profile and plot.Parent then
					local rate = Dinos.Rate(profile, plr)
					if rate > 0 then
						if plr:GetAttribute("Pass_AutoCollect") then
							profile.Coins += rate
							profile.Earned += rate
							if math.floor(os.clock()) % 5 == 0 then Data.Changed(plr) end
						else
							profile.Pending += rate
							plot:SetAttribute("Pending", math.floor(profile.Pending))
						end
					end
				end
			end
		end
	end)
end

-- (offline earnings moved to Data.luau's payAway on 2026-10-14: 25% of the yard's rate, paid straight to coins)

return Plots
