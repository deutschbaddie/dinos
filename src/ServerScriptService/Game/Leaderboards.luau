--[[
	Leaderboards — global boards on the hub plaza: boss clears, fastest ruler knock-out per boss, money earned.
	OrderedDataStores when available (falls back to this server's players in Studio without API access).
	Every board in Base Camp is a Model named "Leaderboard" with a "Stat" attribute and a BoardGui with Row1..8.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Leaderboards = {}
local Data
local stores = {}
-- PRE-BETA scores live in their own boards on live servers, so launch starts every board empty
local Testing = require(game:GetService("ReplicatedStorage").DinoExpedition.Game.Testing)
local PREFIX = (Testing.Enabled and not game:GetService("RunService"):IsStudio()) and "DinoExpedition_PreBeta_LB_" or "DinoExpedition_LB_"
local names = {} :: { [number]: string }

local function store(stat: string): OrderedDataStore?
	if stores[stat] ~= nil then return stores[stat] or nil end
	local ok, s = pcall(function() return DataStoreService:GetOrderedDataStore(PREFIX .. stat) end)
	stores[stat] = ok and s or false
	return ok and s or nil
end

local function statValue(profile, stat: string): number?
	if stat == "Coins" then return math.floor(profile.Earned) end
	if stat == "Bosses" then return profile.Stats.Bosses or 0 end
	if stat == "Stars" then return profile.Stars or 0 end
	local boss = stat:match("^Time_(.+)$")
	if boss then
		local r = profile.Bosses[boss]
		return r and r.BestTime and -r.BestTime or nil -- negative so "highest" = fastest
	end
	return nil
end

local function push(player: Player)
	local profile = Data.Peek(player)
	if not profile then return end
	-- (a temporary profile - a DataStore outage on join - isn't saved, so it mustn't post scores either: a fresh
	-- 0 would overwrite the player's real best)
	if Data.Offline[player] then return end
	names[player.UserId] = player.DisplayName
	for _, stat in ipairs(Leaderboards.Stats) do
		local v = statValue(profile, stat)
		local s = store(stat)
		if v and s and not Data.NoAccess then pcall(function() s:SetAsync(tostring(player.UserId), v) end) end
	end
end

local function rowsFor(stat: string)
	local rows = {}
	local s = (not Data.NoAccess) and store(stat) or nil
	if s then
		local ok, pages = pcall(function() return s:GetSortedAsync(false, 8) end)
		if not ok and tostring(pages):find("Studio access") then Data.NoAccess = true end
		if ok and pages then
			for _, e in ipairs(pages:GetCurrentPage()) do
				local id = tonumber(e.key) or 0
				if not names[id] then
					local okN, n = pcall(function() return Players:GetNameFromUserIdAsync(id) end)
					names[id] = okN and n or "?"
				end
				table.insert(rows, { names[id], e.value })
			end
			return rows
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		local p = Data.Peek(plr)
		local v = p and statValue(p, stat)
		if v then table.insert(rows, { plr.DisplayName, v }) end
	end
	table.sort(rows, function(a, b) return a[2] > b[2] end)
	return rows
end

local function format(stat: string, v: number): string
	if stat:match("^Time_") then return Config.FormatTime(-v) end
	if stat == "Coins" then return Config.FormatNumber(v) end
	return tostring(v)
end

-- each row is rank | name | value at one shared text size (one TextScaled line per row made long names
-- shrink to nothing and every row a different size). Built once per board from the generated Row frames.
local ROW_COLORS = { Color3.fromRGB(255, 210, 58), Color3.fromRGB(225, 230, 240), Color3.fromRGB(230, 160, 100) }
local function columns(gui: Instance, i: number)
	local row = gui:FindFirstChild("Row" .. i)
	if not row or not row:IsA("Frame") then return nil end
	local have = row:FindFirstChild("Cols")
	if have then
		return { Rank = have:FindFirstChild("Rank") :: TextLabel, Name = have:FindFirstChild("Name") :: TextLabel, Value = have:FindFirstChild("Value") :: TextLabel }
	end
	local font = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	for _, l in ipairs(row:GetDescendants()) do
		if l:IsA("TextLabel") then font = l.FontFace l.Visible = false end
	end
	local holder = Instance.new("Frame")
	holder.Name = "Cols"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = row
	local out = {}
	local function col(name: string, x: number, w: number, align: Enum.TextXAlignment)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(x, 0)
		l.Size = UDim2.fromScale(w, 1)
		l.FontFace = font
		l.TextScaled = false
		l.TextSize = 20 -- same size on every row; long names get "..." instead of shrinking
		l.TextXAlignment = align
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.TextColor3 = ROW_COLORS[i] or Color3.new(1, 1, 1)
		l.Text = ""
		local st = Instance.new("UIStroke")
		st.Thickness = 2
		st.Color = Color3.fromRGB(16, 16, 20)
		st.Parent = l
		l.Parent = holder
		out[name] = l
	end
	col("Rank", 0, 0.12, Enum.TextXAlignment.Left)
	col("Name", 0.12, 0.56, Enum.TextXAlignment.Left)
	col("Value", 0.68, 0.32, Enum.TextXAlignment.Right)
	return out
end

Leaderboards.Stats = { "Coins", "Bosses", "Stars", "Time_TyrantKing", "Time_Titan", "Time_Tidebreaker" }

function Leaderboards.Start(deps)
	Data = deps.Data
	task.spawn(function()
		while true do
			for _, p in ipairs(Players:GetPlayers()) do task.spawn(push, p) end
			task.wait(120)
		end
	end)
	task.spawn(function()
		local camp = Workspace:WaitForChild("BaseCamp")
		-- (found once: a full GetDescendants over Base Camp's ~28k instances every 30 s just to find two boards)
		local boards = {}
		for _, d in ipairs(camp:GetDescendants()) do
			if d:IsA("Model") and d.Name == "Leaderboard" then table.insert(boards, d) end
		end
		while true do
			for _, board in ipairs(boards) do
				if board.Parent then
					local stat = board:GetAttribute("Stat")
					if stat == "Dinos" then stat = "Stars" end
					local rows = rowsFor(stat)
					local gui = board:FindFirstChild("BoardGui", true)
					if gui then
						for i = 1, 8 do
							local cols = columns(gui, i)
							local r = rows[i]
							if cols then
								cols.Rank.Text = r and (i .. ".") or ""
								cols.Name.Text = r and string.upper(r[1]) or (i == 1 and "NO RUNS YET" or "")
								cols.Value.Text = r and format(stat, r[2]) or ""
							end
						end
					end
				end
			end
			task.wait(30)
		end
	end)
end

function Leaderboards.Push(player: Player)
	task.spawn(push, player)
end

return Leaderboards
