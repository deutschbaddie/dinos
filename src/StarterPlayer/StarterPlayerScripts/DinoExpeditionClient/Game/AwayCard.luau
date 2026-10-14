--[[
	AwayCard — the WHILE YOU WERE AWAY card (2026-10-14). The server already paid the offline money as the profile
	loaded (Data.payAway: Config.Offline.Share of the yard's rate, at most MaxHours) and put it in the snapshot as
	Away = { Seconds, Coins, Capped, Id }. This is the celebration: the time away, a big coin count-up with ticking
	coins, and COLLECT, which flies the coins into the HUD's coin counter.

	It waits for a quiet moment: after the menu (it starts after MainMenu.Run), never during the cold open, the
	camp intro, a warp or any cutscene, and only at camp. Nothing earned = no card.
	Input: tap / click COLLECT, ENTER, or A / B on a gamepad (the button is also the gamepad's selection).
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)
local Audio = require(script.Parent.Audio)
local Drive = require(script.Parent.Drive)
local Warp = require(script.Parent.Warp)
local Config = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Game"):WaitForChild("Config"))
local DinosaurCinematics = require(ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("DinosaurCinematics"))

local C = Theme.C

local AwayCard = {}
local HUD = nil :: any
local shownId = nil :: any
local open = false

local function awayText(sec: number, capped: boolean): string
	if capped then return `{Config.Offline.MaxHours}H+` end
	local h, m = sec // 3600, (sec % 3600) // 60
	if h > 0 then return `{h}H {m}M` end
	return `{math.max(1, m)}M`
end

-- a calm moment at camp: no cutscene (cold open, intro, warp, hatch, talk...), no expedition, no open panel
local function quiet(): boolean
	if Cinema.Playing() or Warp.Playing then return false end
	local okCine, cine = pcall(DinosaurCinematics.IsPlaying)
	if okCine and cine then return false end
	local p = Net.Profile
	local f = p and p.Flags
	if not f or f.ColdOpenSeen ~= true or (tonumber(f.Tutorial) or 0) < 1 then return false end
	local mode = Drive.State.Mode
	if mode == "Route" or mode == "Roam" or mode == "Frozen" then return false end
	if HUD and HUD.PanelOpen and HUD.PanelOpen() then return false end
	return true
end

-- blocky gold confetti popping off the coin when the count lands
local function confetti(host: GuiObject, at: UDim2)
	local cols = { C.YellowHi, C.Yellow, C.Orange, C.LimeHi, C.Cream }
	for i = 1, 16 do
		local sz = math.random(9, 15)
		local f = Kit.New("Frame", { BackgroundColor3 = cols[(i % #cols) + 1], Size = UDim2.fromOffset(sz, sz), AnchorPoint = Vector2.new(0.5, 0.5), Position = at, ZIndex = 30, Rotation = math.random(0, 90) }, host)
		Kit.Corner(f, 3)
		local st = Kit.Stroke(f, C.Ink, 2)
		local ang = (i / 16) * math.pi * 2 + math.random() * 0.4
		local dist = 70 + math.random() * 70
		local to = at + UDim2.fromOffset(math.cos(ang) * dist, math.sin(ang) * dist * 0.75 - 20)
		Kit.Tween(f, 0.55, { Position = to, Rotation = f.Rotation + math.random(-200, 200) }, Enum.EasingStyle.Quad)
		local fade = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3)
		TweenService:Create(f, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(st, fade, { Transparency = 1 }):Play()
		task.delay(0.65, function() f:Destroy() end)
	end
end

local function show(info)
	open = true
	local coins = math.max(0, math.floor(tonumber(info.Coins) or 0))
	local secs = tonumber(info.Seconds) or 0
	local capped = info.Capped == true

	-- the room dims behind it (its own full-bleed screen, under the card)
	local dimGui = Kit.Screen("DinoAwayDim", 35, true)
	local dim = Kit.New("Frame", { Name = "Dim", BackgroundColor3 = C.Night, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, dimGui:FindFirstChild("Root"))
	Kit.Tween(dim, 0.35, { BackgroundTransparency = 0.45 })

	local gui, canvas = Kit.Screen("DinoAwayCard", 36, false)
	local root = gui:FindFirstChild("Root") :: Frame
	local win, inner = Kit.Window(canvas, { Name = "AwayCard", Title = "WHILE YOU WERE AWAY", Color = "Yellow", Icon = "Clock", Size = UDim2.fromOffset(600, 410), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Fit = true, ZIndex = 20 })

	-- how long you were gone
	Kit.TierBar(inner, "AWAY FOR " .. awayText(secs, capped), { Size = UDim2.fromOffset(340, 36), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), Color = C.Blue, Color2 = C.BlueLo, ZIndex = 24, TextPx = 14 })

	-- the haul: a coin over spinning sun rays, and the number rolling up
	local _, cc = Kit.Card(inner, { Size = UDim2.new(1, -20, 0, 150), Position = UDim2.new(0.5, 0, 0, 52), AnchorPoint = Vector2.new(0.5, 0), Color = "Forest", Border = C.Yellow, ZIndex = 23 })
	local clip = Kit.New("CanvasGroup", { Name = "Rays", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), ZIndex = 25 }, cc)
	Kit.Corner(clip, 9)
	local rays = Kit.New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.2, 0.5), Size = UDim2.fromOffset(0, 0), ZIndex = 25 }, clip)
	for i = 1, 12 do
		local ray = Kit.New("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.09, 0.5), Rotation = i * 30, BackgroundColor3 = (i % 2 == 0) and C.YellowHi or C.Orange, BackgroundTransparency = 0.45, ZIndex = 25 }, rays)
		Kit.New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, ray)
	end
	Kit.Tween(rays, 0.5, { Size = UDim2.fromOffset(360, 360) }, Enum.EasingStyle.Back)
	local spin = RunService.RenderStepped:Connect(function(dt) rays.Rotation += dt * 24 end)
	gui.Destroying:Connect(function() spin:Disconnect() end)
	local coinIcon = Kit.Icon(cc, "Coin", { Size = UDim2.fromOffset(124, 124), Position = UDim2.fromScale(0.2, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 28, Rotation = -10 })
	Kit.Bob(coinIcon, 4, 2.4)
	local amount = Kit.Text(cc, "+0", { Name = "Amount", Size = UDim2.new(0.6, 0, 0, 72), Position = UDim2.new(0.38, 0, 0.42, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, Color = C.YellowHi, Color2 = C.Orange, Stroke = 5, Shadow = 5, MaxSize = 76, ZIndex = 28 })
	Kit.Text(cc, "COINS", { Pixel = true, Size = UDim2.new(0.6, 0, 0, 16), Position = UDim2.new(0.38, 4, 0.8, 0), AnchorPoint = Vector2.new(0, 0.5), Align = Enum.TextXAlignment.Left, Color = C.Cream, Stroke = 3, Shadow = 2, MaxSize = 16, ZIndex = 28 })

	Kit.Text(inner, `YOUR DINOS EARN WHILE YOU'RE AWAY - UP TO {Config.Offline.MaxHours}H`, { Pixel = true, Size = UDim2.new(1, -30, 0, 11), Position = UDim2.new(0.5, 0, 0, 222), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.Muted, Stroke = 2.5, Shadow = 2, MaxSize = 11, ZIndex = 24 })

	local shownAt = os.clock()
	local done, skip = false, false
	local collect: () -> ()
	local btn, hit = Kit.Button(inner, { Name = "Collect", Text = "COLLECT", Icon = "Coin", IconOut = true, IconSize = 1.05, TextLeft = 0.3, Color = "Lime", Size = UDim2.fromOffset(300, 62), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 26, Shine = true, Studs = 3, MaxText = 36, OnClick = function() collect() end })
	-- the key that collects (none on touch: the button is the key)
	local platform = Kit.Platform()
	if platform ~= "Touch" then
		local key = (Kit.Gamepad() or platform == "Console") and "A" or "ENTER"
		Kit.Text(btn, key, { Name = "Key", Size = UDim2.fromOffset(key == "A" and 22 or 60, 20), Position = UDim2.new(1, -4, 0, -8), AnchorPoint = Vector2.new(1, 0), ZIndex = 40, Stroke = 3, Shadow = 2, MaxSize = 20, Color = C.Cream })
	end
	if Kit.Gamepad() then GuiService.SelectedObject = hit end

	-- the count-up: coins tick faster and higher as the number climbs, then it lands with a pop
	local counted = false
	task.spawn(function()
		task.wait(0.45)
		local dur = math.clamp(1.0 + math.log10(math.max(coins, 1)) * 0.14, 1.2, 2.2)
		local t0 = os.clock()
		local nextTick = 0
		while gui.Parent do
			local a = skip and 1 or math.clamp((os.clock() - t0) / dur, 0, 1)
			local e = 1 - (1 - a) ^ 3
			Kit.SetText(amount, "+" .. Config.FormatNumber(coins * e))
			if os.clock() >= nextTick and a < 1 then
				nextTick = os.clock() + 0.085
				Audio.Play("Coins", { Pitch = 0.9 + 0.55 * e, Exact = true, Volume = 0.5, Gap = 0.05 })
			end
			if a >= 1 then break end
			RunService.RenderStepped:Wait()
		end
		counted = true
		if not gui.Parent or done then return end
		Kit.Punch(amount, 0.22)
		Kit.Punch(coinIcon, 0.18)
		Audio.Play("ItemGet", { Pitch = 1.1 })
		confetti(cc, UDim2.fromScale(0.2, 0.5))
	end)

	local function unbind()
		ContextActionService:UnbindAction("DinoAwayCollect")
		local sel = GuiService.SelectedObject
		if sel and sel:IsDescendantOf(gui) then GuiService.SelectedObject = nil end
	end

	-- coins arc from the button into the HUD's coin counter (positions in the card screen's own unscaled root, so
	-- the top-bar inset can't shift them)
	local function onScreen(g: GuiObject): boolean
		local a: Instance? = g
		while a do
			if a:IsA("GuiObject") and not a.Visible then return false end
			if a:IsA("ScreenGui") then return a.Enabled end
			a = a.Parent
		end
		return false
	end
	local function flyHome()
		local target = HUD and HUD.CoinTarget and HUD.CoinTarget()
		if not (target and target.AbsoluteSize.X > 0 and onScreen(target)) then return end
		local origin = root.AbsolutePosition
		local from = btn.AbsolutePosition + btn.AbsoluteSize / 2 - origin
		local to = target.AbsolutePosition + Vector2.new(40, target.AbsoluteSize.Y / 2) - origin
		for i = 1, 14 do
			task.delay(i * 0.045, function()
				if not root.Parent then return end
				local c = Kit.Icon(root, "Coin", { Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(from.X, from.Y), ZIndex = 60 })
				local mid = from + Vector2.new((math.random() - 0.5) * 260, -90 - math.random() * 110)
				local dur = 0.55 + math.random() * 0.2
				local t0 = os.clock()
				while c.Parent do
					local u = math.clamp((os.clock() - t0) / dur, 0, 1)
					local p = from:Lerp(mid, u):Lerp(mid:Lerp(to, u * u), u)
					c.Position = UDim2.fromOffset(p.X, p.Y)
					c.Size = UDim2.fromOffset(40 - u * 14, 40 - u * 14)
					if u >= 1 then break end
					RunService.RenderStepped:Wait()
				end
				c:Destroy()
				Kit.Punch(target, 0.08)
				if i % 3 == 0 then Audio.Play("Coins", { Pitch = 1.1 + i * 0.02, Exact = true, Volume = 0.45, Gap = 0.03 }) end
			end)
		end
	end

	collect = function()
		if done or os.clock() - shownAt < 0.5 then return end
		if not counted then skip = true end
		done = true
		unbind()
		Audio.Sting("Payout", 0.6)
		flyHome()
		Kit.Exit(win, true)
		TweenService:Create(dim, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		task.delay(1.6, function()
			gui:Destroy()
			dimGui:Destroy()
			open = false
		end)
	end

	ContextActionService:BindActionAtPriority("DinoAwayCollect", function(_, state)
		-- (a cutscene that starts over the card hides it: the keys go back to the game until it's back)
		if not gui.Enabled then return Enum.ContextActionResult.Pass end
		if state == Enum.UserInputState.Begin then collect() end
		return Enum.ContextActionResult.Sink
	end, false, 2300, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB)

	Kit.Enter(win)
end

function AwayCard.Start(hud)
	HUD = hud
	task.spawn(function()
		task.wait(1.5) -- (the onboarding decides on a cold open / intro first)
		local calm = 0
		while true do
			local p = Net.Profile
			if p then
				local info = p.Away
				-- nothing earned this session (or it's been shown): done for good
				if typeof(info) ~= "table" or info.Id == shownId or not ((tonumber(info.Coins) or 0) > 0) then return end
				calm = (not open and quiet()) and calm + 0.25 or 0
				if calm >= 1.5 then
					shownId = info.Id
					local ok, err = pcall(show, info)
					if not ok then
						-- (never leave a half-built card or the dim over the game: the coins are already theirs)
						warn("[AwayCard] couldn't show the card:", err)
						ContextActionService:UnbindAction("DinoAwayCollect")
						local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
						for _, n in ipairs({ "DinoAwayCard", "DinoAwayDim" }) do
							local g = pg and pg:FindFirstChild(n)
							if g then g:Destroy() end
						end
						open = false
					end
					return
				end
			end
			task.wait(0.25)
		end
	end)
end

return AwayCard
