--[[
	Cinema — every cutscene is clean: while one plays, all other screens (HUD, raid UI, prompts, toasts,
	Roblox's own top bar / chat / backpack) are hidden, and they come back exactly as they were after.

	local token = Cinema.Begin("DinoHatchUI")   -- name(s) of the cutscene's own ScreenGui(s) to keep
	...
	Cinema.End(token)

	Nested cutscenes are fine: the UI returns when the last one ends.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")

local Cinema = {}
Cinema.Active = 0

local keep = {} :: { [string]: number }
-- every cutscene's own screen (any name ever passed to Begin): its owner turns it on and off, Cinema never
-- brings one back (a skip layer restored after its scene ended used to leave an unclosable TAP TO SKIP)
local cutsceneGuis = {} :: { [string]: boolean }
local hidden = {} :: { ScreenGui }
local promptsWere = true
local addConn: RBXScriptConnection? = nil

-- Roblox's own touch controls (the thumbstick) are never touched: a cutscene that hid them and didn't hand them back
-- left phone players unable to steer (2026-10-12)
local NEVER = { TouchGui = true }
local function shouldHide(g: Instance): boolean
	return g:IsA("ScreenGui") and g.Enabled and not keep[g.Name] and not NEVER[g.Name]
end

function Cinema.Playing(): boolean
	return Cinema.Active > 0
end

-- the game's own screens a cutscene may ask to leave up (not cutscene screens: End restores them as usual)
local SHARED = { DinoToasts = true, DinoCoach = true, DinoBossEvent = true, DinoHUD = true }

function Cinema.Begin(...: string)
	local names = { ... }
	for _, n in ipairs(names) do
		keep[n] = (keep[n] or 0) + 1
		-- a cutscene's own screens are never restored by End; the game's shared screens it only leaves up are.
		-- (2026-10-12: those were marked too, so once a later cutscene hid the toasts they never came back - every
		-- toast in the game went silent from the 2nd era map on)
		if not SHARED[n] then cutsceneGuis[n] = true end
	end
	Cinema.Active += 1
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if Cinema.Active == 1 then
		promptsWere = ProximityPromptService.Enabled
		ProximityPromptService.Enabled = false
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
		if pg then
			addConn = pg.ChildAdded:Connect(function(g)
				task.defer(function()
					if Cinema.Active > 0 and shouldHide(g) then (g :: ScreenGui).Enabled = false table.insert(hidden, g :: ScreenGui) end
				end)
			end)
		end
	end
	if pg then
		for _, g in ipairs(pg:GetChildren()) do
			if shouldHide(g) then (g :: ScreenGui).Enabled = false table.insert(hidden, g :: ScreenGui) end
		end
	end
	local token = { Names = names, Done = false, Long = false }
	-- safety: a cutscene that errors out can never leave the UI hidden for good (a Long screen, like the garage
	-- studio, ends itself and guards its own close)
	task.delay(40, function() if not token.Done and not token.Long then Cinema.End(token) end end)
	return token
end

function Cinema.End(token)
	if Cinema.Active <= 0 or (token and token.Done) then return end
	if token then token.Done = true end
	for _, n in ipairs(token and token.Names or {}) do
		keep[n] = (keep[n] or 1) - 1
		if keep[n] <= 0 then keep[n] = nil end
	end
	Cinema.Active -= 1
	if Cinema.Active > 0 then return end
	if addConn then addConn:Disconnect() addConn = nil end
	for _, g in ipairs(hidden) do if g.Parent and not cutsceneGuis[g.Name] then g.Enabled = true end end
	table.clear(hidden)
	ProximityPromptService.Enabled = promptsWere
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
end

return Cinema
