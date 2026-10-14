--[[
	Showcase — DINO NAMES and the SHOWCASE PEDESTAL (2026-10-14).

	  names      any dino you own can be named (its card in the DINOS / COMPANIONS windows, or NAME IT right after it
	             hatches). Roblox rules: the server filters every name (TextService:FilterStringAsync, then
	             GetNonChatStringForBroadcastAsync - everyone can see it), stores the FILTERED text on the record as
	             d.Name (so it travels with the dino through trades), Config.Names.Max characters at most, rate
	             limited, every call pcall'd. If the filter can't be reached nothing changes: the dino keeps the name
	             it had, or its species name (Config.DinoName) if it never had one. A blank name clears it.
	  showcase   every island has a pedestal by its bridge landing (islandKit.js Showcase, placed by IslandView). Its
	             owner picks one dino for it (profile.Showcase = dino id); Publish puts the dino's record on the plot
	             attribute "Showcase" (JSON, "" = empty) and every client draws it there (ShowcaseView.luau). The record
	             goes whole, so fields added later (Mutation, Hybrid) reach the clients untouched.
	             A dino that leaves (sold, traded, lost) or moves into a land star pen clears the pedestal on the next
	             Plots.Sync, with a toast for the owner. Sea species stand in a tank on it (Config.ShowcaseTank).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.DinoExpedition.Game.Config)

local Showcase = {}
local Data, Net, Plots

local function find(list, id: string)
	for _, v in ipairs(list or {}) do if v.Id == id then return v end end
	return nil
end

-- a land star pen (the sea pen is a sea star's only home: it can still be shown, in its tank)
local function inLandPen(profile, id: string): boolean
	for lot, pen in pairs(profile.Island and profile.Island.Pens or {}) do
		if typeof(pen) == "table" and pen.Dino == id and Config.Island.Lots[lot] ~= "Sea" then return true end
	end
	return false
end

--------------------------------------------------------------------------------
-- names
--------------------------------------------------------------------------------
-- what the player typed, tidied: valid UTF-8, no control characters, spaces collapsed, at most Max characters
local function tidy(raw: any): string?
	if typeof(raw) ~= "string" or #raw > 200 or not utf8.len(raw) then return nil end
	local s = raw:gsub("%c", " "):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
	if (utf8.len(s) or 0) > Config.Names.Max then
		local cut = utf8.offset(s, Config.Names.Max + 1)
		s = cut and s:sub(1, cut - 1) or s
		s = s:match("^(.-)%s*$") or s
	end
	return s
end

-- the filter, for everyone to read (nil = the filter couldn't be reached)
local function filter(player: Player, text: string): string?
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
	end)
	if not ok or not result then
		warn("[Showcase] name filter failed:", result)
		return nil
	end
	local ok2, out = pcall(function() return (result :: TextFilterResult):GetNonChatStringForBroadcastAsync() end)
	if not ok2 or typeof(out) ~= "string" then
		warn("[Showcase] name filter failed:", out)
		return nil
	end
	return out
end

local renames = {} :: { [Player]: { number } }
Players.PlayerRemoving:Connect(function(p) renames[p] = nil end)
local function rateOk(player: Player): (boolean, string?)
	local cfg = Config.Names
	local now = os.clock()
	local log = renames[player] or {}
	renames[player] = log
	while log[1] and now - log[1] > cfg.Window do table.remove(log, 1) end
	if log[#log] and now - log[#log] < cfg.Every then return false, "ONE NAME AT A TIME - TRY AGAIN IN A MOMENT" end
	if #log >= cfg.PerWindow then return false, "THAT'S A LOT OF NAMES! TRY AGAIN IN A FEW MINUTES" end
	table.insert(log, now)
	return true, nil
end

function Showcase.Name(player: Player, id: any, raw: any)
	local profile = Data.Peek(player)
	if not profile or typeof(id) ~= "string" then return { Ok = false } end
	if player:GetAttribute("Trading") then return { Ok = false, Err = "FINISH YOUR TRADE FIRST" } end
	local d = find(profile.Dinos, id)
	if not d then return { Ok = false, Err = "THAT DINO IS GONE" } end
	local text = tidy(raw)
	if not text then return { Ok = false, Err = "THAT NAME WON'T WORK - TRY ANOTHER" } end
	if text == "" then
		-- back to its species name (no filter needed)
		d.Name = nil
		Plots.Sync(player)
		Data.Changed(player)
		return { Ok = true, Name = Config.DinoName(d), Cleared = true }
	end
	local ok, why = rateOk(player)
	if not ok then return { Ok = false, Err = why } end
	local clean = filter(player, text)
	-- (the filter yields: the dino may have left meanwhile - a trade can't start mid-call, but a sale could)
	d = find(profile.Dinos, id)
	if not d then return { Ok = false, Err = "THAT DINO IS GONE" } end
	if not clean then
		-- couldn't check it: nothing changes (it keeps its old name, or its species name)
		return { Ok = false, Err = "COULDN'T CHECK THAT NAME RIGHT NOW - TRY AGAIN SOON" }
	end
	clean = tidy(clean) or ""
	-- the filter hid part of it: don't keep a name of hashes, ask for another one
	if clean == "" or (clean:find("#", 1, true) and not text:find("#", 1, true)) then
		return { Ok = false, Err = "THAT NAME ISN'T ALLOWED - TRY ANOTHER" }
	end
	d.Name = clean
	Plots.Sync(player)
	Data.Changed(player)
	return { Ok = true, Name = Config.DinoName(d) }
end

--------------------------------------------------------------------------------
-- the pedestal
--------------------------------------------------------------------------------
-- why a dino can't go on your pedestal (nil = it can)
function Showcase.Block(profile, id: string): string?
	local d = find(profile.Dinos, id)
	if not d then return "THAT DINO IS GONE" end
	if inLandPen(profile, id) then return "IT LIVES IN ITS STAR PEN" end
	if not Config.Species[d.Species] then return "THAT ONE CAN'T BE SHOWN" end
	return nil
end

function Showcase.Set(player: Player, id: any)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	if id == nil or id == "" then
		profile.Showcase = ""
		Plots.Sync(player)
		Data.Changed(player)
		return { Ok = true, Cleared = true }
	end
	if typeof(id) ~= "string" then return { Ok = false } end
	local why = Showcase.Block(profile, id)
	if why then return { Ok = false, Err = why } end
	profile.Showcase = id
	Plots.Sync(player)
	Data.Changed(player)
	local d = find(profile.Dinos, id)
	return { Ok = true, Name = d and Config.DinoName(d) or nil, Tank = d and Config.ShowcaseTank(d.Species) or nil }
end

-- Plots.Sync calls this: checks the showcased dino is still yours and showable, and puts it on the plot for every
-- client. A dino that went (sold, traded, lost on a run, moved into a star pen) clears the pedestal with a toast.
function Showcase.Publish(player: Player, profile, plot: Model)
	local id = profile.Showcase
	local d = nil
	if typeof(id) == "string" and id ~= "" then
		if Showcase.Block(profile, id) then
			profile.Showcase = ""
			if Net then Net.Fire(player, "Toast", { Text = "YOUR SHOWCASE IS EMPTY NOW - PICK A NEW STAR FOR IT!", Color = "Orange" }) end
		else
			d = find(profile.Dinos, id)
		end
	elseif typeof(id) ~= "string" then
		profile.Showcase = ""
	end
	local raw = ""
	if d then
		local ok, s = pcall(function() return HttpService:JSONEncode(table.clone(d)) end)
		raw = ok and s or ""
	end
	if plot:GetAttribute("Showcase") ~= raw then plot:SetAttribute("Showcase", raw) end
end

function Showcase.Start(deps)
	Data, Net, Plots = deps.Data, deps.Net, deps.Plots
	Net.On("NameDino", function(player, args) return Showcase.Name(player, args.Id, args.Name) end)
	Net.On("SetShowcase", function(player, args) return Showcase.Set(player, args.Id) end)
end

return Showcase
