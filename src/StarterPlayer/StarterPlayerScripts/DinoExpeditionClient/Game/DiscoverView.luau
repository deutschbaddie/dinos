--[[
	DiscoverView — the moment you find one of an era's SECRETS (server: Discover.luau; the list: IndexDefs.Secrets;
	the page: the Index's SECRETS tab).

	  "SecretFound"      a SECRET FOUND! banner at the top: what it was and how many of the era's you have (3 / 14),
	                     a chime, and a sparkle where it was. Several at once queue up, never pile on top.
	  "SecretsComplete"  every secret of an era: a big ALL SECRETS! title, the rover paint it unlocked and the coins.
	Both wait out cutscenes (a find during a boss reveal shows once it's over).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)
local CineKit = require(script.Parent.UI.CineKit)
local Audio = require(script.Parent.Audio)

local C = Theme.C
local DiscoverView = {}

local ICON = { Nest = "Egg", Boss = "Dino", Stash = "Gift", Wild = "Dino", Shiny = "Star" }

local gui: ScreenGui? = nil
local banner: any = nil
local function ensure()
	if gui then return end
	local g, canvas = Kit.Screen("DinoSecrets", 28, false, 0.85)
	gui = g
	banner = Kit.Banner(canvas, { Position = UDim2.new(0.5, 0, 0, 96), ZIndex = 30 })
end

local queue = {} :: { any }
local running = false

local function showFound(info)
	ensure()
	local found, total = tonumber(info.Found) or 0, tonumber(info.Total) or 0
	local sub = string.upper(tostring(info.Name or "SECRET"))
	if total > 0 then sub ..= string.format("   %d / %d", found, total) end
	Audio.Sting("Discover", 0.55)
	banner.Show("SECRET FOUND!", sub, ICON[info.Kind] or "Map", C.TealHi, 2.6)
	if typeof(info.At) == "Vector3" then pcall(CineKit.Sparkle, info.At + Vector3.new(0, 3, 0), C.TealHi, 1.4) end
	task.wait(2.9)
end

local function showComplete(info)
	ensure()
	local era = Config.Era(tostring(info.Era))
	local parts = {}
	if typeof(info.PaintName) == "string" then table.insert(parts, string.upper(info.PaintName) .. " PAINT") end
	if (tonumber(info.Coins) or 0) > 0 then table.insert(parts, "+$" .. Config.FormatNumber(info.Coins)) end
	Audio.Sting("QuestDone", 0.8)
	pcall(CineKit.RayTitle, gui :: ScreenGui, "ALL SECRETS!", (era and era.Name or "") .. "  -  " .. table.concat(parts, "  "), C.TealHi, 3.2, 0.3)
	task.wait(3.6)
	if typeof(info.PaintName) == "string" then Kit.Toast("NEW ROVER PAINT AT YOUR RIDE SHOP!", "Teal", "Jeep") end
end

local function pump()
	if running then return end
	running = true
	task.spawn(function()
		while #queue > 0 do
			-- (never over a cutscene: wait it out)
			while Cinema.Playing() do task.wait(0.25) end
			local item = table.remove(queue, 1)
			local ok, err = pcall(item.Fn, item.Info)
			if not ok then warn("[DiscoverView]", err) end
		end
		running = false
	end)
end

function DiscoverView.Start()
	Net.On("SecretFound", function(info)
		if typeof(info) ~= "table" then return end
		if #queue < 8 then table.insert(queue, { Fn = showFound, Info = info }) end
		pump()
	end)
	Net.On("SecretsComplete", function(info)
		if typeof(info) ~= "table" then return end
		table.insert(queue, { Fn = showComplete, Info = info })
		pump()
	end)
end

return DiscoverView
