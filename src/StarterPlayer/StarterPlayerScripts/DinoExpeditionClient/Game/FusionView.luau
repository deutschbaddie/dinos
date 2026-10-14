--[[
	FusionView — EGG FUSION at the Egg Keeper's Fusion Nest (server: Fusion.luau, model: tools/gen/fusionNest.js).

	  the nest      its amber glow breathes slowly; when your bag holds a trio (3 eggs, same dino, same rarity) it
	                pulses bright and a "N READY" tag floats over the pod - you can see there's something to do
	  the window    EGG FUSION (from the nest's prompt, CampAction "Fusion"): every dino + rarity you hold, how many
	                of 3 you have, what it becomes. FUSE on one row, or FUSE ALL (the server picks the same trios this
	                window shows: heaviest eggs first)
	  the cutscene  the three eggs sit in the cradles, glow, fly into the pod, it flares - and the new egg drops into
	                the middle cradle with its rarity's glow. Skippable after the first second (tap / Space / A).
	                FUSE ALL plays it once, for the rarest egg it made, and counts the rest.

	Nothing here is trusted by the server: it only sends egg ids; Fusion.luau checks everything again.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(Shared:WaitForChild("Game"):WaitForChild("Config"))
local Net = require(script.Parent.Net)
local Kit = require(script.Parent.UI.Kit)
local Theme = require(script.Parent.UI.Theme)
local Cinema = require(script.Parent.UI.Cinema)
local CineKit = require(script.Parent.UI.CineKit)
local Audio = require(script.Parent.Audio)
local RarityFx = require(script.Parent.RarityFx)

local player = Players.LocalPlayer
local C = Theme.C
local COUNT = Config.Fusion.Count

local FusionView = {}
local Panels: any = nil

--------------------------------------------------------------------------------
-- the trios in your bag (the same grouping Fusion.FuseAll uses)
--------------------------------------------------------------------------------
type Group = { Key: string, Species: string, Rarity: string, To: string, Eggs: { any } }

local function groupsOf(profile): { Group }
	local byKey, list = {}, {}
	for _, e in ipairs((profile and profile.Eggs) or {}) do
		if Config.CanFuse(e) then
			local key = e.Species .. "|" .. e.Rarity
			local g = byKey[key]
			if not g then
				g = { Key = key, Species = e.Species, Rarity = e.Rarity, To = Config.FuseTo(e.Rarity) :: string, Eggs = {} }
				byKey[key] = g
				table.insert(list, g)
			end
			table.insert(g.Eggs, e)
		end
	end
	for _, g in ipairs(list) do
		table.sort(g.Eggs, function(a, b) return (a.KG or 0) > (b.KG or 0) end)
	end
	-- ready ones first (rarest first), then the closest to ready, then by the index's order
	table.sort(list, function(a, b)
		local ra, rb = #a.Eggs >= COUNT, #b.Eggs >= COUNT
		if ra ~= rb then return ra end
		local oa, ob = Config.Rarity[a.Rarity].Order, Config.Rarity[b.Rarity].Order
		if not ra then
			local na, nb = math.min(#a.Eggs, COUNT), math.min(#b.Eggs, COUNT)
			if na ~= nb then return na > nb end
		end
		if oa ~= ob then return oa > ob end
		return (table.find(Config.SpeciesOrder, a.Species) or 99) < (table.find(Config.SpeciesOrder, b.Species) or 99)
	end)
	return list
end

local function triosOf(profile): number
	local n = 0
	for _, g in ipairs(groupsOf(profile)) do n += math.floor(#g.Eggs / COUNT) end
	return n
end

--------------------------------------------------------------------------------
-- the nest in the world
--------------------------------------------------------------------------------
local nestModel: Model? = nil
local function nest(): Model?
	if nestModel and nestModel.Parent then return nestModel end
	nestModel = nil
	local camp = Workspace:FindFirstChild("BaseCamp")
	local m = camp and camp:FindFirstChild("FusionNest", true)
	if m and m:IsA("Model") then nestModel = m end
	return nestModel
end
local function part(name: string): BasePart?
	local m = nest()
	local p = m and m:FindFirstChild(name, true)
	return (p and p:IsA("BasePart")) and p or nil
end

-- the glow: every FusionGlow* part breathes; brighter and faster when you have a trio waiting
local glowParts: { { Part: BasePart, Base: number } }? = nil
local function glows()
	if glowParts then return glowParts end
	local m = nest()
	if not m then return nil end
	local list = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:sub(1, 10) == "FusionGlow" then table.insert(list, { Part = d, Base = d.Transparency }) end
	end
	glowParts = list
	return list
end
local flare = 0 -- 0..1: the cutscene drives the nest to full brightness through this
local ready = 0 -- trios in your bag right now
local readyTag: BillboardGui? = nil
local function setReadyTag(n: number)
	local pod = part("FusionPod")
	if n <= 0 or not pod then
		if readyTag then readyTag.Enabled = false end
		return
	end
	if not readyTag or not readyTag.Parent then
		local bb = Instance.new("BillboardGui")
		bb.Name = "FusionReadyTag"
		bb.AlwaysOnTop = false
		bb.LightInfluence = 0
		bb.Size = UDim2.fromOffset(220, 56)
		bb.StudsOffset = Vector3.new(0, 4.4, 0)
		bb.MaxDistance = 70
		bb.Adornee = pod
		bb.Parent = player:WaitForChild("PlayerGui")
		Kit.Text(bb, "", { Name = "Label", Size = UDim2.fromScale(1, 1), Color = C.YellowHi, Color2 = C.Orange, Stroke = 4, Shadow = 3, MaxSize = 34 })
		readyTag = bb
	end
	local bb = readyTag :: BillboardGui
	bb.Enabled = not Cinema.Playing()
	local label = bb:FindFirstChild("Label")
	if label then Kit.SetText(label, n == 1 and "1 READY!" or (n .. " READY!")) end
end

local function stepGlow(now: number)
	local list = glows()
	if not list then return end
	local hot = ready > 0
	local speed = hot and 3.2 or 0.9
	local wave = 0.5 + 0.5 * math.sin(now * speed)
	for _, g in ipairs(list) do
		local idle = hot and (g.Base * 0.3 + 0.25 * wave) or (g.Base + (1 - g.Base) * 0.35 * wave)
		g.Part.Transparency = idle + (0 - idle) * flare
	end
	local core = part("FusionCore")
	if core then
		local light = core:FindFirstChildOfClass("PointLight")
		if light then light.Brightness = (hot and 1.2 or 0.7) + 5 * flare end
	end
end

--------------------------------------------------------------------------------
-- the cutscene
--------------------------------------------------------------------------------
local EggT = Shared:WaitForChild("Eggs")
local playing = false

local function prep(m: Model)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
end

-- an egg model this tall (studs), its pivot at its centre; nil if the species has no egg model
local function eggOf(species: string, height: number): Model?
	local t = EggT:FindFirstChild(species .. "Egg")
	if not (t and t:IsA("Model")) then return nil end
	local e = t:Clone() :: Model
	prep(e)
	local _, size = e:GetBoundingBox()
	local tall = math.max(size.X, size.Y, size.Z)
	if tall > 0.01 then e:ScaleTo(e:GetScale() * height / tall) end
	return e
end
-- where an egg's pivot goes so its bottom sits on `spot`
local function seat(e: Model, spot: Vector3, yaw: number): CFrame
	local box, size = e:GetBoundingBox()
	local lift = e:GetPivot().Position.Y - box.Position.Y + size.Y / 2
	return CFrame.new(spot + Vector3.new(0, lift, 0)) * CFrame.Angles(0, yaw, 0)
end

local function heightFor(species: string, kg: number?): number
	-- 1.2 .. 1.75 studs by its real size, so a heavy egg looks heavy in the cradle
	return 1.2 + 0.55 * math.clamp((Config.EggScale(species, kg) - 0.95) / 2.0, 0, 1)
end

local function hrpOf(): BasePart?
	local ch = player.Character
	local h = ch and ch:FindFirstChild("HumanoidRootPart")
	return (h and h:IsA("BasePart")) and h or nil
end

-- result: { Egg, From, Used }; extra: how many more eggs FUSE ALL made besides this one
local function playScene(result, extra: number)
	local egg = result and result.Egg
	if typeof(egg) ~= "table" or not Config.Species[egg.Species] or not Config.Rarity[egg.Rarity] then return end
	local origin, pod = part("FusionOrigin"), part("FusionPod")
	local cradles = { part("FusionCradle1"), part("FusionCradle2"), part("FusionCradle3") }
	local hrp = hrpOf()
	-- (no nest, or you're not at it: the toast alone tells you)
	if playing or Cinema.Playing() or not (origin and pod and cradles[1] and cradles[2] and cradles[3] and hrp) then return end
	if (hrp.Position - pod.Position).Magnitude > 60 then return end
	playing = true
	local fromR, toR = Config.Rarity[result.From] or Config.Rarity.Common, Config.Rarity[egg.Rarity]
	local sp = Config.Species[egg.Species]
	local cine = Cinema.Begin("DinoFusionFx")
	local gui = Kit.Screen("DinoFusionFx", 40, true)
	local root = gui:FindFirstChild("Root") :: Frame
	local folder = Instance.new("Folder")
	folder.Name = "DinoFusionScene"
	folder.Parent = Workspace
	local cam = Workspace.CurrentCamera
	local oldType, oldFov = cam.CameraType, cam.FieldOfView
	local drive = require(script.Parent.Drive)
	drive.HoldCamera(true)
	cam.CameraType = Enum.CameraType.Scriptable
	-- you watch from the step, facing the pod
	local stand = part("FusionStand")
	local wasAnchored = hrp.Anchored
	hrp.Anchored = true
	if stand then
		local at = Vector3.new(stand.Position.X, hrp.Position.Y, stand.Position.Z)
		hrp.CFrame = CFrame.lookAt(at, Vector3.new(pod.Position.X, at.Y, pod.Position.Z))
	end
	-- the three eggs in the cradles
	local kgs = typeof(result.Used) == "table" and result.Used or {}
	local ins: { Model } = {}
	for i = 1, 3 do
		local c = cradles[i] :: BasePart
		local e = eggOf(egg.Species, heightFor(egg.Species, tonumber(kgs[i])))
		if e then
			e:PivotTo(seat(e, c.Position, math.rad(math.random(0, 359))))
			e.Parent = folder
			pcall(RarityFx.Apply, e, result.From, 1.2)
			ins[i] = e
		end
	end
	local outEgg = eggOf(egg.Species, heightFor(egg.Species, egg.KG) * 1.12)
	local outHome = outEgg and seat(outEgg, (cradles[2] :: BasePart).Position, 0) or nil
	-- the shot: a little above the step, the pod and all three cradles in frame
	local o = origin.CFrame
	local look = pod.Position + Vector3.new(0, -0.6, 0)
	-- (off to one side: you stand on the step right in front, and a straight-on shot filmed through your head)
	local camFrom = (o * CFrame.new(-4.4, 4.6, -9.6)).Position
	local camTo = (o * CFrame.new(-3.2, 3.6, -7.2)).Position
	cam.FieldOfView = 55
	cam.CFrame = CFrame.lookAt(camFrom, look)
	-- skip: after the first second, jump to the reveal; once the new egg is out, a press ends it
	local REVEAL, DONE = 2.9, 6.2
	local t0 = os.clock()
	local revealed = false
	local finished = false
	local function press()
		local t = os.clock() - t0
		if t > 1 and t < REVEAL then
			t0 = os.clock() - REVEAL
		elseif revealed and t > REVEAL + 0.7 then
			finished = true
		end
	end
	local tap = Instance.new("TextButton")
	tap.Name = "Tap"
	tap.Text = ""
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 1
	tap.Parent = root
	local conns = {}
	table.insert(conns, tap.Activated:Connect(press))
	table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then press() end
	end))
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = Color3.fromRGB(255, 236, 190)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 30
	flash.Parent = root
	local hint = Kit.Text(root, "TAP TO SKIP", { Pixel = true, Size = UDim2.new(0.4, 0, 0, 12), Position = UDim2.new(0.5, 0, 1, -28), AnchorPoint = Vector2.new(0.5, 1), Color = C.Cream, Stroke = 2, Shadow = 1, MaxSize = 12, ZIndex = 35 })
	hint.Visible = false
	local homes: { CFrame }, scale0: { number } = {}, {}
	for i, e in pairs(ins) do
		homes[i] = e:GetPivot()
		scale0[i] = e:GetScale()
	end
	local lit = { false, false, false }
	local function step()
		local t = os.clock() - t0
		hint.Visible = t > 1 and t < REVEAL
		-- 0 .. 0.9: each cradle lights in turn under its egg
		for i = 1, 3 do
			if not lit[i] and t >= 0.15 + (i - 1) * 0.28 then
				lit[i] = true
				Audio.Play("EggPlace", { Volume = 0.6, Pitch = 1 + i * 0.08 })
				local c = cradles[i] :: BasePart
				CineKit.Sparkle(c.Position + Vector3.new(0, 0.8, 0), fromR.Color, 0.5)
			end
		end
		-- 0.9 .. 2.4: they lift, spiral in and shrink into the pod; the nest builds to a flare
		local u = math.clamp((t - 0.9) / 1.5, 0, 1)
		flare = math.clamp((t - 0.6) / 1.9, 0, 1) ^ 2
		for i, e in pairs(ins) do
			if e.Parent then
				local home = homes[i]
				local k = u * u * (3 - 2 * u)
				local spin = (i - 2) * 1.6 + k * 7
				local r = (1 - k) * (home.Position - pod.Position) * Vector3.new(1, 0, 1)
				local around = CFrame.Angles(0, k * 2.4, 0) * r
				local lift = math.sin(k * math.pi) * 2.2
				local p = pod.Position + around + Vector3.new(0, (home.Position.Y - pod.Position.Y) * (1 - k) + lift, 0)
				e:PivotTo(CFrame.new(p) * CFrame.Angles(k * 3, spin, 0))
				if k > 0.02 and k < 0.98 then e:ScaleTo(math.max(0.05, scale0[i] * (1 - 0.85 * k))) end
				if k >= 0.98 then e:Destroy() end
			end
		end
		-- the camera creeps in the whole time
		local cu = math.clamp(t / DONE, 0, 1)
		local ce = 1 - (1 - cu) ^ 2
		cam.CFrame = CFrame.lookAt(camFrom:Lerp(camTo, ce), look + Vector3.new(0, ce * 0.4, 0))
		-- 2.9: the flare, and the new egg
		if t >= REVEAL and not revealed then
			revealed = true
			for _, e in pairs(ins) do if e.Parent then e:Destroy() end end
			flash.BackgroundTransparency = 0.05
			TweenService:Create(flash, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
			pcall(CineKit.Punch, 0.6)
			Audio.Sting(toR.Order >= 4 and "HatchLegendary" or (toR.Order >= 3 and "HatchRare" or "Hatch"), 0.8)
			CineKit.Burst(pod.Position, 0.7, { toR.Color, Color3.fromRGB(255, 200, 90), Color3.new(1, 1, 1) })
			if outEgg then
				outEgg:PivotTo(CFrame.new(pod.Position))
				outEgg.Parent = folder
				pcall(RarityFx.Apply, outEgg, egg.Rarity, 1.6)
			end
			local sub = string.format("%s EGG  -  %s", sp.Name, Config.FormatKG(egg.KG or 0))
			if extra > 0 then sub ..= string.format("   (+%d MORE)", extra) end
			pcall(CineKit.RayTitle, root, toR.Name .. "!", sub, toR.Color, DONE - REVEAL, 0.24)
		end
		-- 2.9 .. 3.6: the new egg arcs out of the pod and drops into the middle cradle
		if revealed and outEgg and outHome and outEgg.Parent then
			local a = math.clamp((t - REVEAL) / 0.7, 0, 1)
			local e = 1 - (1 - a) ^ 3
			local p = pod.Position:Lerp(outHome.Position, e) + Vector3.new(0, math.sin(a * math.pi) * 1.6, 0)
			outEgg:PivotTo(CFrame.new(p) * CFrame.Angles(0, (1 - e) * 6 + t * 0.6, 0))
			if a >= 1 and not outEgg:GetAttribute("Landed") then
				outEgg:SetAttribute("Landed", true)
				Audio.Play("EggPlace", { Volume = 0.9 })
				CineKit.Sparkle(outHome.Position, toR.Color, 1)
			end
		end
		if revealed then flare = math.max(0, 1 - (t - REVEAL) / 1.2) end
		if t >= DONE then finished = true end
	end
	local ok, err = pcall(function()
		while not finished do
			step()
			RunService.RenderStepped:Wait()
			-- (a respawn or leaving mid-scene ends it cleanly)
			if not hrp.Parent then break end
		end
	end)
	if not ok then warn("[FusionView] cutscene:", err) end
	for _, c in ipairs(conns) do c:Disconnect() end
	folder:Destroy()
	gui:Destroy()
	flare = 0
	cam.FieldOfView = oldFov
	cam.CameraType = oldType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or oldType
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
	if hrp.Parent then hrp.Anchored = wasAnchored end
	drive.HoldCamera(false)
	Cinema.End(cine)
	playing = false
end

--------------------------------------------------------------------------------
-- the EGG FUSION window
--------------------------------------------------------------------------------
local canvas: Frame? = nil
local dim: TextButton? = nil
local win: Frame? = nil
local busy = false
local lastSig = ""

local function closeWindow()
	local w = win
	win = nil
	if w then Kit.Exit(w, true) end
	if dim then TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play() end
	task.delay(0.22, function() if not win and dim then dim.Visible = false end end)
end
FusionView.Close = closeWindow
function FusionView.IsOpen(): boolean
	return win ~= nil
end

local function ensureScreen()
	if canvas then return end
	local _, cv = Kit.Screen("DinoFusion", 21)
	canvas = cv
	local d = Instance.new("TextButton")
	d.Name = "Dim"
	d.Text = ""
	d.AutoButtonColor = false
	d.BackgroundColor3 = Color3.fromRGB(8, 16, 10)
	d.BackgroundTransparency = 1
	d.Size = UDim2.fromScale(4, 4)
	d.Position = UDim2.fromScale(-1.5, -1.5)
	d.Visible = false
	d.ZIndex = 1
	d.Parent = cv
	d.Activated:Connect(closeWindow)
	dim = d
end

local function pixel(parent: Instance, s: string, props)
	props.Pixel = true
	props.Color = props.Color or C.Cream
	props.Stroke = props.Stroke or 2
	props.Shadow = props.Shadow or 1
	props.MaxSize = props.MaxSize or 12
	return Kit.Text(parent, s, props)
end

local function sigOf(profile): string
	local parts = {}
	for _, g in ipairs(groupsOf(profile)) do
		local ids = {}
		for k = 1, math.min(#g.Eggs, COUNT) do table.insert(ids, g.Eggs[k].Id) end
		table.insert(parts, g.Key .. "=" .. #g.Eggs .. ":" .. table.concat(ids, ","))
	end
	return table.concat(parts, "|")
end

local buildWindow: () -> ()

-- one request; on success the window closes and the scene plays
local function fuse(ids: { string }?)
	if busy or playing then return end
	busy = true
	local res = ids and Net.Ask("Fuse", { Ids = ids }) or Net.Ask("FuseAll")
	busy = false
	if not (res and res.Ok) then
		Kit.Toast(string.upper(tostring(res and res.Err or "COULDN'T FUSE THOSE")), "Red", "Egg")
		if win then Kit.Shake(win) end
		return
	end
	local results = ids and { res.Result } or (typeof(res.Results) == "table" and res.Results or {})
	local best = results[#results] -- (FUSE ALL comes back lowest first: the last one is the rarest)
	closeWindow()
	if best and best.Egg then
		local r = Config.Rarity[best.Egg.Rarity]
		task.spawn(playScene, best, #results - 1)
		-- (the toast lands once the scene is over, or right away if there was no scene)
		task.spawn(function()
			task.wait(0.2)
			while playing do task.wait(0.1) end
			if #results > 1 then
				Kit.Toast(string.format("FUSED %d EGGS!  BEST: %s", #results, r and r.Name or ""), "Orange", "Egg")
			else
				local sp = Config.Species[best.Egg.Species]
				Kit.Toast(string.format("%s %s EGG!", r and r.Name or "", sp and sp.Name or ""), "Orange", "Egg")
			end
			if res.More then Kit.Toast("MORE TRIOS LEFT - FUSE AGAIN!", "Yellow", "Egg") end
		end)
	end
end

local function row(list: ScrollingFrame, g: Group, order: number)
	local fromR, toR = Config.Rarity[g.Rarity], Config.Rarity[g.To]
	local sp = Config.Species[g.Species]
	local have = #g.Eggs
	local can = have >= COUNT
	local card, cc = Kit.Card(list, { Size = UDim2.new(1, -12, 0, 92), ZIndex = 24, Border = can and toR.Color or nil })
	card.LayoutOrder = order
	-- the three it takes: filled ones in the rarity colour, empty ones as dark slots
	for k = 1, COUNT do
		local slot = Instance.new("Frame")
		slot.Name = "Slot" .. k
		slot.Size = UDim2.fromOffset(62, 62)
		slot.Position = UDim2.new(0, 10 + (k - 1) * 58, 0.5, 0)
		slot.AnchorPoint = Vector2.new(0, 0.5)
		slot.BackgroundColor3 = k <= have and fromR.Color:Lerp(C.Forest, 0.55) or C.InkSoft
		slot.BackgroundTransparency = k <= have and 0.1 or 0.3
		slot.ZIndex = 26
		slot.Parent = cc
		Kit.Corner(slot, 14)
		Kit.Stroke(slot, k <= have and fromR.Color or C.Ink, 2.5)
		if k <= have then
			Kit.Icon(slot, "Egg", { Species = g.Species, Size = UDim2.fromScale(0.82, 0.82), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27 })
		else
			Kit.Glyph(slot, "Plus", { Size = UDim2.fromScale(0.4, 0.4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 27, Color = C.JungleHi })
		end
	end
	-- the name, what you have, what it makes
	local x = 10 + COUNT * 58 + 12
	Kit.Text(cc, sp.Name, { Size = UDim2.new(1, -x - 170, 0, 22), Position = UDim2.fromOffset(x, 12), Align = Enum.TextXAlignment.Left, ZIndex = 27, Stroke = 3, Shadow = 2, MaxSize = 22 })
	local count = have > COUNT and string.format("%s  x%d", fromR.Name, have) or fromR.Name
	pixel(cc, count, { Size = UDim2.new(1, -x - 170, 0, 10), Position = UDim2.fromOffset(x, 42), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 10, Color = fromR.Color:Lerp(Color3.new(1, 1, 1), 0.3) })
	local kgs = {}
	for k = 1, math.min(have, COUNT) do table.insert(kgs, g.Eggs[k].KG or 0) end
	local into = can and string.format("MAKES  %s  %s", toR.Name, Config.FormatKG(Config.FuseKG(g.Species, kgs))) or ("MAKES  " .. toR.Name)
	pixel(cc, into, { Size = UDim2.new(1, -x - 170, 0, 10), Position = UDim2.fromOffset(x, 62), Align = Enum.TextXAlignment.Left, ZIndex = 27, MaxSize = 10, Color = toR.Color:Lerp(Color3.new(1, 1, 1), 0.25) })
	if can then
		local ids = { g.Eggs[1].Id, g.Eggs[2].Id, g.Eggs[3].Id }
		local _, hit = Kit.Button(cc, { Text = "FUSE", Icon = "Egg", IconSize = 0.85, TextLeft = 0.36, Color = "Orange", Size = UDim2.fromOffset(150, 56), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 28, MaxText = 22, Shine = true, OnClick = function() fuse(ids) end })
		return hit
	end
	local need = COUNT - have
	pixel(cc, string.format("NEED %d MORE", need), { Size = UDim2.fromOffset(150, 12), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Align = Enum.TextXAlignment.Center, ZIndex = 27, MaxSize = 12, Color = C.Muted })
	return nil
end

buildWindow = function()
	if not canvas then return end
	local profile = Net.Profile or {}
	local groups = groupsOf(profile)
	local trios = 0
	for _, g in ipairs(groups) do trios += math.floor(#g.Eggs / COUNT) end
	local root, content = Kit.Window(canvas, { Fit = true, Title = "EGG FUSION", Color = "Orange", Icon = "Egg", Size = UDim2.fromOffset(760, 470), Position = UDim2.fromScale(0.5, 0.53), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20, OnClose = closeWindow })
	win = root
	-- the rule, once, in one line; FUSE ALL on the right
	pixel(content, string.format("%d MATCHING EGGS  =  1 EGG ONE RARITY UP", COUNT), { Size = UDim2.new(1, -250, 0, 12), Position = UDim2.fromOffset(4, 16), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 12, Color = C.YellowHi })
	pixel(content, "SAME DINO + SAME RARITY.  UP TO " .. Config.Rarity[Config.Fusion.MaxResult].Name .. ".", { Size = UDim2.new(1, -250, 0, 9), Position = UDim2.fromOffset(4, 36), Align = Enum.TextXAlignment.Left, ZIndex = 26, MaxSize = 9, Color = C.Muted })
	local first = nil
	if trios > 0 then
		local _, hit = Kit.Button(content, { Text = trios > 1 and ("FUSE ALL  x" .. trios) or "FUSE ALL", Icon = "Egg", IconSize = 0.9, TextLeft = 0.28, Color = "Yellow", Size = UDim2.fromOffset(230, 50), Position = UDim2.new(1, 0, 0, 2), AnchorPoint = Vector2.new(1, 0), ZIndex = 26, MaxText = 22, Shine = true, OnClick = function() fuse(nil) end })
		first = hit
	end
	local list = Instance.new("ScrollingFrame")
	list.Name = "Groups"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, 0, 1, -66)
	list.Position = UDim2.fromOffset(0, 62)
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = C.LimeHi
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 23
	list.Parent = content
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 10)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = list
	local cards = {}
	for i, g in ipairs(groups) do
		local hit = row(list, g, i)
		first = first or hit
	end
	for _, c in ipairs(list:GetChildren()) do if c:IsA("Frame") then table.insert(cards, c) end end
	if #groups == 0 then
		local msg = Instance.new("Frame")
		msg.BackgroundTransparency = 1
		msg.Size = UDim2.new(1, 0, 0, 120)
		msg.ZIndex = 24
		msg.Parent = list
		Kit.Icon(msg, "Egg", { Size = UDim2.fromOffset(72, 72), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 26 })
		pixel(msg, "NO EGGS THAT CAN FUSE YET", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0.5, 0, 0, 84), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 26, MaxSize = 14 })
		pixel(msg, "BRING BACK 3 OF THE SAME DINO AND RARITY", { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0.5, 0, 0, 106), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 26, MaxSize = 10, Color = C.Muted })
	end
	Kit.Stagger(cards, 0.02, 0.3)
	if first and Kit.Gamepad() then game:GetService("GuiService").SelectedObject = first end
end

local function openWindow()
	if Cinema.Playing() or playing then return end
	ensureScreen()
	if Panels and Panels.IsOpen and Panels.IsOpen() then Panels.Close() end
	if win then win:Destroy() win = nil end
	if dim then
		dim.Visible = true
		TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.4 }):Play()
	end
	buildWindow()
	lastSig = sigOf(Net.Profile)
	if win then Kit.Enter(win) end
end
FusionView.Open = openWindow

local function refreshWindow()
	if not win or busy then return end
	local sig = sigOf(Net.Profile)
	if sig == lastSig then return end
	lastSig = sig
	win:Destroy()
	win = nil
	buildWindow()
end

--------------------------------------------------------------------------------
function FusionView.Start(panels: any?)
	Panels = panels
	ProximityPromptService.PromptTriggered:Connect(function(pr)
		if pr:GetAttribute("CampAction") == "Fusion" then openWindow() end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if win and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then closeWindow() end
	end)
	local function onProfile()
		ready = triosOf(Net.Profile)
		pcall(setReadyTag, ready)
		refreshWindow()
	end
	Net.On("Profile", onProfile)
	if Net.Profile then onProfile() end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 20 then return end
		acc = 0
		pcall(stepGlow, os.clock())
		-- (another screen's cutscene hides the tag; it comes back after)
		if readyTag then readyTag.Enabled = ready > 0 and not Cinema.Playing() end
		-- a cutscene starting elsewhere closes the window
		if win and Cinema.Playing() and not playing then closeWindow() end
	end)
end

return FusionView
