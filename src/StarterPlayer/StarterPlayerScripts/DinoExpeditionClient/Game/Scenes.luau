--[[
	Scenes — in-person moments around Base Camp, each a short skippable cutscene with the HUD hidden:
	  Craft      you stand at the Mechanic's bench: he lays out the boss parts, hammers, sparks fly,
	             the new gear rises off the anvil with its name and perk (Press Start 2P)
	  LevelUp    a quick tune-up at the bench (+1 LEVEL)
	  Chest      the daily chest: the lid swings, coins burst, the streak stamps in
	  NewNest    a new incubator powers up at your plot
	The R6 NPCs gesture with the classic animations; hammering is done by swinging the arm joint locally.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local DinoShared = ReplicatedStorage:WaitForChild("DinoExpedition")
local Config = require(DinoShared:WaitForChild("Game"):WaitForChild("Config"))
local Gear = require(DinoShared:WaitForChild("Game"):WaitForChild("Gear"))
local DinosaurVFX = require(DinoShared:WaitForChild("DinosaurVFX"))
local Kit = require(script.Parent.UI.Kit)
local CineKit = require(script.Parent.UI.CineKit)
local PlayerAnim = require(script.Parent.PlayerAnim)
local Cinema = require(script.Parent.UI.Cinema)
local Icons = require(script.Parent.UI.Icons)
local Drive = require(script.Parent.Drive)
local CampView = require(script.Parent.CampView)
local Audio = require(script.Parent.Audio)

local player = Players.LocalPlayer
local C = Kit.Colors
local Scenes = {}
Scenes.Playing = false

local ANIM = { Wave = "rbxassetid://128777973", Point = "rbxassetid://128853357", Cheer = "rbxassetid://129423030", Laugh = "rbxassetid://129423131" }

local function find(name: string, root: Instance?): BasePart?
	local r = root or Workspace:FindFirstChild("BaseCamp")
	local p = r and r:FindFirstChild(name, true)
	return (p and p:IsA("BasePart")) and p or nil
end

local function npcModel(kind: string): Model?
	local spot = find("NpcSpot_" .. kind)
	local m = spot and spot:FindFirstChild("Npc")
	return (m and m:IsA("Model")) and m or nil
end
Scenes.NpcModel = npcModel

local tracks = {}
local function gesture(char: Model?, name: string, speed: number?): AnimationTrack?
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	tracks[animator] = tracks[animator] or {}
	local tr = tracks[animator][name]
	if not tr then
		local a = Instance.new("Animation")
		a.AnimationId = ANIM[name]
		local ok, t = pcall(function() return (animator :: Animator):LoadAnimation(a) end)
		if not ok then return nil end
		tr = t
		tracks[animator][name] = tr
	end
	(tr :: AnimationTrack):Play(0.15, 1, speed or 1)
	return tr
end
Scenes.Gesture = gesture

-- face a character toward a point (locally; NPC roots are anchored)
local function face(char: Model?, at: Vector3)
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local p = root.Position
	local look = Vector3.new(at.X, p.Y, at.Z)
	if (look - p).Magnitude < 0.1 then return end
	root.CFrame = CFrame.lookAt(p, look)
end
Scenes.Face = face

--------------------------------------------------------------------------------
-- shared cutscene layer
--------------------------------------------------------------------------------
local ui = {} :: any
local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DinoSceneUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 58
	gui.Enabled = false
	ui.Gui = gui
	ui.Bars = {}
	for i, a in ipairs({ 0, 1 }) do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, a)
		f.Position = UDim2.fromScale(0, a)
		f.Size = UDim2.fromScale(1, 0)
		f.ZIndex = 5
		f.Parent = gui
		ui.Bars[i] = f
	end
	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 3
	flash.Parent = gui
	ui.Flash = flash
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.fromScale(0.5, 0.86)
	holder.Size = UDim2.fromScale(0.8, 0.2)
	holder.ZIndex = 8
	holder.Parent = gui
	ui.Holder = holder
	ui.Kicker = Kit.Text(holder, "", { Pixel = true, Size = UDim2.fromScale(1, 0.16), Position = UDim2.fromScale(0, 0), Color = C.YellowHi, Stroke = 2.5, Shadow = 3, ZIndex = 9, MaxSize = 20 })
	ui.Title = Kit.Text(holder, "", { Pixel = true, Size = UDim2.fromScale(1, 0.42), Position = UDim2.fromScale(0, 0.2), Color = Color3.fromRGB(255, 244, 214), Color2 = Color3.fromRGB(255, 176, 46), Stroke = 4, Shadow = 6, ZIndex = 9, MaxSize = 56 })
	ui.Sub = Kit.Text(holder, "", { Pixel = true, Size = UDim2.fromScale(1, 0.13), Position = UDim2.fromScale(0, 0.74), Color = Color3.fromRGB(230, 236, 245), Stroke = 2, Shadow = 3, ZIndex = 9, MaxSize = 16 })
	ui.Skip = Kit.Text(gui, "TAP TO SKIP", { Pixel = true, Size = UDim2.new(0.3, 0, 0.026, 0), Position = UDim2.new(0.5, 0, 0.97, 0), AnchorPoint = Vector2.new(0.5, 1), Color = Color3.fromRGB(255, 226, 120), Stroke = 2, Shadow = 2, ZIndex = 14, MaxSize = 16 })
	local tap = Instance.new("TextButton")
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 15
	tap.Parent = gui
	tap.Activated:Connect(function() if ui.OnSkip then ui.OnSkip() end end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function textAlpha(a: number, t: number)
	for _, l in ipairs(ui.Holder:GetDescendants()) do
		if l:IsA("TextLabel") then TweenService:Create(l, TweenInfo.new(t), { TextTransparency = 1 - a }):Play()
		elseif l:IsA("UIStroke") then TweenService:Create(l, TweenInfo.new(t), { Transparency = 1 - a }):Play() end
	end
end

local function caption(kicker: string, title: string, sub: string?, color: Color3?)
	Kit.SetText(ui.Kicker, kicker)
	Kit.SetText(ui.Title, title)
	Kit.SetText(ui.Sub, sub or "")
	Kit.SetTextColor(ui.Kicker, color or C.YellowHi)
	textAlpha(0, 0)
	textAlpha(1, 0.3)
	Kit.Pop(ui.Holder, 1.3)
end

local function flash(a: number?, color: Color3?)
	ui.Flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	ui.Flash.BackgroundTransparency = 1 - (a or 0.6)
	TweenService:Create(ui.Flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
end

-- run body(skipped, later) with the camera, HUD hidden and a skip; restores everything after. later(fn) queues a
-- clean-up that runs however the body ends - finished, skipped or thrown (2026-10-14: a throw mid-scene left the
-- chest lid hanging open and the floating gear in the air). Returns false if it couldn't play.
local function scene(body: (() -> boolean, (() -> ()) -> ()) -> ()): boolean
	-- (another camp scene still finishing: this one waits its turn instead of being dropped)
	local t0 = os.clock()
	while Scenes.Playing and os.clock() - t0 < 6 do task.wait(0.1) end
	if Scenes.Playing then return false end
	Scenes.Playing = true
	local token = Cinema.Begin("DinoSceneUI")
	local cam = Workspace.CurrentCamera
	local savedFov = cam.FieldOfView
	Drive.HoldCamera(true)
	cam.CameraType = Enum.CameraType.Scriptable
	ui.Gui.Enabled = true
	textAlpha(0, 0)
	for _, b in ipairs(ui.Bars) do TweenService:Create(b, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0.1) }):Play() end
	local skipped = false
	local cutStart = os.clock()
	ui.OnSkip = function() if os.clock() - cutStart > 1 then skipped = true end end
	ContextActionService:BindAction("DinoSceneSkip", function(_, st)
		if st == Enum.UserInputState.Begin and os.clock() - cutStart > 1 then skipped = true end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local ws = hum and hum.WalkSpeed
	if hum then hum.WalkSpeed = 0 end
	local cleanups = {}
	local ok, err = pcall(body, function() return skipped end, function(fn) table.insert(cleanups, fn) end)
	if not ok then warn("[Scenes]", err) end
	for i = #cleanups, 1, -1 do
		local okC, errC = pcall(cleanups[i])
		if not okC then warn("[Scenes] clean-up:", errC) end
	end
	if hum and ws then hum.WalkSpeed = ws end
	ContextActionService:UnbindAction("DinoSceneSkip")
	ui.OnSkip = nil
	textAlpha(0, 0.25)
	for _, b in ipairs(ui.Bars) do TweenService:Create(b, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, 0) }):Play() end
	task.wait(0.3)
	ui.Gui.Enabled = false
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = savedFov
	Drive.HoldCamera(false)
	Cinema.End(token)
	Scenes.Playing = false
	return true
end

local function glide(from: CFrame, to: CFrame, dur: number, skipped: () -> boolean, fovA: number?, fovB: number?)
	local cam = Workspace.CurrentCamera
	local t0 = os.clock()
	while true do
		local u = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = u < 0.5 and 2 * u * u or 1 - (-2 * u + 2) ^ 2 / 2
		cam.CFrame = from:Lerp(to, e)
		cam.FieldOfView = (fovA or 50) + ((fovB or fovA or 50) - (fovA or 50)) * e
		if u >= 1 or skipped() then return end
		RunService.RenderStepped:Wait()
	end
end

local function waitFor(t: number, skipped: () -> boolean)
	local t0 = os.clock()
	while os.clock() - t0 < t and not skipped() do RunService.RenderStepped:Wait() end
end

-- a floating picture of an item (icon billboard) used as the "thing" in scenes
-- the real thing for the crafting reveal: a launcher lying level, or a full armor set on an invisible bust
local function gearProp(result, at: Vector3): Model?
	if result.What == "Launcher" then
		local m = Gear.Launcher(result.Id)
		if not m then return nil end
		for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false p.CanQuery = false end end
		pcall(function() m:ScaleTo(1.3) end)
		m:PivotTo(CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(0, 1.6, 0))
		m.Parent = Workspace
		return m
	elseif result.What == "Armor" then
		local bust = Instance.new("Model")
		bust.Name = "ArmorBust"
		local function bone(name: string, size: Vector3, off: Vector3): Part
			local b = Instance.new("Part")
			b.Name = name
			b.Size = size
			b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
			b.Transparency = 1
			b.CFrame = CFrame.new(at + off)
			b.Parent = bust
			return b
		end
		local torso = bone("Torso", Vector3.new(2, 2, 1), Vector3.zero)
		bone("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0))
		bone("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0))
		bone("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0))
		bust.PrimaryPart = torso
		bust.Parent = Workspace
		Gear.DressArmor(bust, result.Id, 10)
		return bust
	end
	return nil
end

local function iconProp(at: Vector3, icon: string, size: number, opts): BillboardGui
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = at
	part.Name = "DinoSceneProp"
	part.Parent = Workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size, size)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Adornee = part
	bb.Parent = part
	Icons.Make(icon, { Size = UDim2.fromScale(1, 1), Parent = bb, Species = opts and opts.Species, Vehicle = opts and opts.Vehicle })
	return bb
end

--------------------------------------------------------------------------------
-- the crafting bench
--------------------------------------------------------------------------------
local ICON = { Launcher = "Launcher", Armor = "Armor", Gadget = "Gadget_Flare", Rover = "Jeep", Plating = "Armor", Level = "Hammer" }

local function swingArm(char: Model?, dur: number, hits: number, onHit: (number) -> ())
	local torso = char and char:FindFirstChild("Torso")
	local shoulder = torso and torso:FindFirstChild("Right Shoulder") :: Motor6D?
	if not shoulder then
		for i = 1, hits do task.wait(dur / hits) onHit(i) end
		return
	end
	local c0 = shoulder.C0
	local t0 = os.clock()
	local lastHit = 0
	while os.clock() - t0 < dur do
		local t = (os.clock() - t0) / dur * hits
		local k = t % 1
		-- wind up slowly, slam down fast
		local a = k < 0.7 and (k / 0.7) * 2.1 or (1 - (k - 0.7) / 0.3) * 2.1
		shoulder.C0 = c0 * CFrame.Angles(0, 0, a)
		local i = math.floor(t) + (k >= 0.97 and 1 or 0)
		if k > 0.95 and math.floor(t) + 1 > lastHit then
			lastHit = math.floor(t) + 1
			onHit(lastHit)
		end
		RunService.RenderStepped:Wait()
		local _ = i
	end
	shoulder.C0 = c0
end

function Scenes.Craft(result)
	local bench = find("CraftBench")
	local stand = find("CraftStand")
	local mech = npcModel("Mechanic")
	if not (bench and stand) then
		Kit.Toast("BUILT: " .. (result.Name or ""), "Orange", ICON[result.What] or "Wrench")
		return
	end
	local played = scene(function(skipped, later)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local top = bench.Position
		local standPos = stand.Position + Vector3.new(0, 3, 0)
		if root then root.CFrame = CFrame.lookAt(standPos, Vector3.new(top.X, standPos.Y, top.Z)) end
		face(mech, standPos)
		local toPlayer = (Vector3.new(standPos.X, top.Y, standPos.Z) - top)
		toPlayer = toPlayer.Magnitude > 0.1 and toPlayer.Unit or Vector3.new(0, 0, -1)
		local side = toPlayer:Cross(Vector3.yAxis)
		-- 1. the parts on the bench (boss materials as glowing chips)
		local props = {}
		local info = result.What == "Launcher" and Config.Launchers[result.Id] or (result.What == "Armor" and Config.Armors[result.Id]) or (result.What == "Gadget" and Config.Gadgets[result.Id]) or (result.What == "Rover" and Config.Vehicles[result.Id]) or (result.What == "Plating" and Config.Plating) or nil
		local mats = info and ((info.Craft and info.Craft.Mats) or info.Mats) or {}
		later(function() for _, p in ipairs(props) do if p.Parent then p:Destroy() end end end)
		later(function() PlayerAnim.SetLoop(char, nil) PlayerAnim.Look(char, nil) end)
		local n = 0
		for mat in pairs(mats) do
			n += 1
			local bb = iconProp(top + side * (n - 1.5) * 1.6 + Vector3.new(0, 0.9, 0), "Mat_" .. mat, 1.6)
			table.insert(props, bb.Parent)
			DinosaurVFX.Cubes(top + Vector3.new(0, 0.6, 0), 6, { (Config.Materials[mat] or {}).Color or C.OrangeHi }, 0.25, 6, 0.6)
		end
		caption("THE ARMORER GETS TO WORK", result.Name or "", nil, C.OrangeHi)
		gesture(mech, "Point")
		glide(CFrame.lookAt(top + toPlayer * 9 + side * 5 + Vector3.new(0, 4, 0), top), CFrame.lookAt(top + toPlayer * 6 + side * 2.5 + Vector3.new(0, 2.6, 0), top + Vector3.new(0, 0.5, 0)), 1.6, skipped, 50, 44)
		-- 2. hammering: sparks on every hit
		if not skipped() then
			local cam = Workspace.CurrentCamera
			cam.CFrame = CFrame.lookAt(top - side * 6 + Vector3.new(0, 2.2, 0) + toPlayer * 1.5, top + Vector3.new(0, 0.8, 0))
			cam.FieldOfView = 40
			PlayerAnim.SetLoop(char, "Work")
			PlayerAnim.Look(char, top + Vector3.new(0, 0.5, 0))
			swingArm(mech, 1.8, 3, function(i)
				Audio.Play("Clunk", { Pitch = 1.25 + i * 0.08, Volume = 0.9 })
				DinosaurVFX.Cubes(top + Vector3.new(0, 0.8, 0), 12, { C.YellowHi, C.OrangeHi, Color3.new(1, 1, 1) }, 0.22, 18, 0.5)
				DinosaurVFX.Shake(0.25 + i * 0.1, 0.15)
				flash(0.15, C.YellowHi)
			end)
		end
		PlayerAnim.SetLoop(char, nil)
		for _, p in ipairs(props) do p:Destroy() end
		-- 3. the reveal: the new gear rises off the anvil
		-- launchers and armor rise as the real 3D gear; everything else as its icon
		local gearModel = gearProp(result, top + Vector3.new(0, 1.2, 0))
		if gearModel then later(function() gearModel:Destroy() end) end
		local part
		if gearModel then
			part = gearModel.PrimaryPart :: BasePart
		else
			local bb = iconProp(top + Vector3.new(0, 1, 0), result.What == "Gadget" and ("Gadget_" .. tostring(result.Id)) or ICON[result.What] or "Hammer", 3.2, { Vehicle = result.What == "Rover" and result.Id or nil })
			part = bb.Parent :: BasePart
			later(function() part:Destroy() end)
		end
		flash(0.8, C.YellowHi)
		Audio.Play("ItemGet")
		DinosaurVFX.BlockRing(CFrame.new(top + Vector3.new(0, 0.6, 0)), { Count = 18, R0 = 0.5, R1 = 7, Color = C.YellowHi, Duration = 0.6 })
		DinosaurVFX.Shake(0.6, 0.3)
		CineKit.ImpactFrame(0.5)
		CineKit.SunBurst(0.7)
		local light = Instance.new("PointLight")
		light.Color = C.YellowHi
		light.Range = 14
		light.Brightness = 3
		light.Parent = part
		if gearModel then
			-- up off the anvil, turning slowly so you see all of it
			local from = gearModel:GetPivot()
			task.spawn(function()
				local t0 = os.clock()
				while gearModel.Parent do
					local u = math.clamp((os.clock() - t0) / 1.4, 0, 1)
					local e = 1 - (1 - u) ^ 3
					gearModel:PivotTo(CFrame.new(from.Position + Vector3.new(0, 2.2 * e, 0)) * CFrame.Angles(0, (os.clock() - t0) * 0.9, 0) * from.Rotation)
					RunService.RenderStepped:Wait()
				end
			end)
		else
			TweenService:Create(part, TweenInfo.new(1.4, Enum.EasingStyle.Back), { Position = top + Vector3.new(0, 3.2, 0) }):Play()
		end
		caption(result.Kind == "Craft" and "NEW GEAR CRAFTED!" or "BUILT!", result.Name or "", result.Perk, C.LimeHi)
		PlayerAnim.Act(char, "Victory")
		gesture(mech, "Laugh")
		glide(CFrame.lookAt(top + toPlayer * 10 + Vector3.new(0, 3, 0), top + Vector3.new(0, 2.5, 0)), CFrame.lookAt(top + toPlayer * 6.5 + side * 1.5 + Vector3.new(0, 3.4, 0), top + Vector3.new(0, 3, 0)), 2.4, skipped, 48, 40)
		waitFor(1.2, skipped)
	end)
	if not played then Kit.Toast("BUILT: " .. (result.Name or ""), "Orange", ICON[result.What] or "Wrench") end
end

function Scenes.LevelUp(what: string, level: number)
	local bench = find("CraftBench")
	local mech = npcModel("Mechanic")
	if not bench then return end
	-- no full cutscene: the Mechanic gives it a whack and the bench sparks (you see it behind the panel)
	task.spawn(function()
		gesture(mech, "Point", 1.4)
		swingArm(mech, 0.6, 1, function()
			DinosaurVFX.Cubes(bench.Position + Vector3.new(0, 0.8, 0), 10, { C.YellowHi, C.OrangeHi }, 0.22, 14, 0.5)
		end)
	end)
	Kit.Toast(string.upper(what) .. " LEVEL " .. level .. "!", "Gold", ICON[what] or "Wrench")
end

--------------------------------------------------------------------------------
-- the daily chest
--------------------------------------------------------------------------------
function Scenes.Chest(res)
	local chest = Workspace:FindFirstChild("BaseCamp") and (Workspace.BaseCamp :: Instance):FindFirstChild("DailyChest", true)
	local lid = chest and chest:FindFirstChild("ChestLid", true) :: Model?
	local host = find("ChestPromptHost")
	if not (lid and host) then
		Kit.Toast("+" .. Config.FormatNumber(res.Coins or 0) .. " COINS", "Gold", "Gift")
		return
	end
	local played = scene(function(skipped, later)
		local hinge = lid:FindFirstChild("LidHinge", true) :: BasePart?
		local pivot0 = lid:GetPivot()
		-- (it shuts again however the scene ends - it's everyone's chest)
		later(function() if lid.Parent then lid:PivotTo(pivot0) end end)
		-- the chest's own middle and the side its lock faces (the prompt sits out front): never a fixed world
		-- direction, so a turned camp still films it from the front
		local base = chest and chest:FindFirstChild("ChestBase", true)
		local center = (base and base:IsA("BasePart")) and (base.Position + Vector3.new(0, 1, 0)) or (host.Position + Vector3.new(0, 0.6, 2))
		local front = Vector3.new(host.Position.X - center.X, 0, host.Position.Z - center.Z)
		front = front.Magnitude > 0.1 and front.Unit or Vector3.new(0, 0, -1)
		local char = player.Character
		face(char, center)
		-- approach: low, slow push toward the lock
		caption("DAY " .. (res.Streak or 1) .. " STREAK", "DAILY CHEST", nil, C.YellowHi)
		glide(CFrame.lookAt(center + front * 11 + Vector3.new(0, 2.5, 0), center), CFrame.lookAt(center + front * 7 + Vector3.new(0, 3.5, 0), center + Vector3.new(0, 0.5, 0)), 1.2, skipped, 50, 44)
		-- the lid swings open on its hinge
		local hp = hinge and hinge.Position or (pivot0.Position)
		local axis = (hinge and hinge.CFrame.RightVector) or pivot0.RightVector
		local t0 = os.clock()
		while os.clock() - t0 < 0.55 do
			local u = (os.clock() - t0) / 0.55
			local e = 1 - (1 - u) ^ 3
			local rot = CFrame.fromAxisAngle(axis, e * math.rad(105))
			lid:PivotTo(CFrame.new(hp) * rot * CFrame.new(-hp) * pivot0)
			RunService.RenderStepped:Wait()
		end
		flash(0.8, C.YellowHi)
		Audio.Play("Clunk", { Pitch = 0.9 })
		Audio.Play("Payout")
		DinosaurVFX.Shake(0.5, 0.3)
		CineKit.ImpactFrame(0.6)
		CineKit.SunBurst(0.8)
		DinosaurVFX.Cubes(center + Vector3.new(0, 1, 0), 30, { C.YellowHi, C.Yellow, Color3.new(1, 1, 1) }, 0.35, 26, 1.2)
		DinosaurVFX.BlockRing(CFrame.new(center), { Count = 20, R0 = 0.5, R1 = 9, Color = C.YellowHi, Duration = 0.6 })
		DinosaurVFX.Shake(0.2, 0.2)
		local coin = iconProp(center + Vector3.new(0, 1, 0), "Coin", 3)
		local cpart = coin.Parent :: BasePart
		later(function() cpart:Destroy() end)
		TweenService:Create(cpart, TweenInfo.new(1, Enum.EasingStyle.Back), { Position = center + Vector3.new(-1.4, 4.2, 0) }):Play()
		local egg = nil
		if res.Egg then
			egg = iconProp(center + Vector3.new(0, 1, 0), "Egg", 3, { Species = res.Egg.Species })
			local eggPart = egg.Parent :: Instance
			later(function() eggPart:Destroy() end)
			TweenService:Create(egg.Parent :: BasePart, TweenInfo.new(1.1, Enum.EasingStyle.Back), { Position = center + Vector3.new(1.6, 4.4, 0) }):Play()
		end
		caption("DAY " .. (res.Streak or 1), "+" .. Config.FormatNumber(res.Coins or 0) .. " COINS", res.Egg and ("+ A " .. (Config.Rarity[res.Egg.Rarity] and Config.Rarity[res.Egg.Rarity].Name or "") .. " " .. (Config.Species[res.Egg.Species] and Config.Species[res.Egg.Species].Name or "") .. " EGG!") or nil, C.YellowHi)
		PlayerAnim.Act(char, "Victory")
		glide(CFrame.lookAt(center + front * 9 + Vector3.new(0, 5, 0), center + Vector3.new(0, 3, 0)), CFrame.lookAt(center + front * 7.5 + Vector3.new(0, 4.4, 0), center + Vector3.new(0, 3.5, 0)), 2, skipped, 46, 40)
		waitFor(0.8, skipped)
	end)
	if not played then Kit.Toast("+" .. Config.FormatNumber(res.Coins or 0) .. " COINS", "Gold", "Gift") end
end

--------------------------------------------------------------------------------
-- a new incubator at your plot
--------------------------------------------------------------------------------
function Scenes.NewNest(slot: number)
	local nest = CampView.NestPoint(slot)
	if not nest then return end
	scene(function(skipped)
		local p = nest.Position
		local cam = Workspace.CurrentCamera
		local back = cam.CFrame.LookVector
		back = Vector3.new(back.X, 0, back.Z)
		back = back.Magnitude > 0.1 and back.Unit or Vector3.new(0, 0, 1)
		glide(CFrame.lookAt(p - back * 16 + Vector3.new(0, 9, 0), p), CFrame.lookAt(p - back * 10 + Vector3.new(0, 5, 0), p + Vector3.new(0, 1, 0)), 1, skipped, 50, 46)
		flash(0.5, C.TealHi)
		Audio.Play("ItemGet")
		CineKit.SunBurst(0.6)
		DinosaurVFX.BlockRing(CFrame.new(p), { Count = 18, R0 = 1, R1 = 8, Color = C.TealHi, Duration = 0.6 })
		DinosaurVFX.FootstepDust(p, 2)
		caption("BASE UPGRADE", "NEW INCUBATOR!", "BIG EGGS NEED BIG NESTS", C.TealHi)
		waitFor(1.6, skipped)
	end)
end

-- an island upgrade (the answer to Shop's IslandBuild): the camera finds the building, a cloud of dust, and the
-- new part of it is standing there. The server's IslandView clones the model; we hide it until the dust settles.
function Scenes.IslandBuild(res)
	local idx = player:GetAttribute("Plot")
	local camp = Workspace:FindFirstChild("BaseCamp")
	local plots = camp and camp:FindFirstChild("Plots")
	local plot = plots and idx and plots:FindFirstChild("Plot" .. idx)
	if not plot then return end
	local anchor: BasePart? = nil
	if res.What == "Hatchery" then
		anchor = plot:FindFirstChild("HatcheryAnchor", true) :: BasePart?
	elseif res.What == "Garage" then
		anchor = plot:FindFirstChild("GarageAnchor", true) :: BasePart?
	else
		local lot = res.Lot and plot:FindFirstChild(res.Lot, true)
		anchor = lot and lot:FindFirstChild("LotAnchor", true) :: BasePart? or nil
	end
	if not anchor then return end
	local kitName = res.What == "Pen" and ("Pen_" .. tostring(res.Species) .. "_" .. tostring(res.Lot)) or (res.What .. "T" .. tostring(res.Tier))
	local isNew = res.What ~= "Pen" or res.Built
	local parts = {}
	local switched = {} -- signs, lights and sparks that were on, off until the reveal
	local function showAll()
		for _, part in ipairs(parts) do part.LocalTransparencyModifier = 0 end
		for inst in pairs(switched) do if inst.Parent then (inst :: any).Enabled = true end end
		table.clear(switched)
	end
	CampView.HoldPenStars = res.What == "Pen"
	scene(function(skipped)
		local a = anchor :: BasePart
		local p = a.Position + Vector3.new(0, 4, 0)
		local front = Vector3.new(a.CFrame.LookVector.X, 0, a.CFrame.LookVector.Z).Unit
		local dist = res.What == "Pen" and (res.Lot == "StarA" and 46 or 64) or (res.What == "Garage" and 52 or 62)
		-- the server's model: hide it for the reveal (it's usually here already)
		local t0 = os.clock()
		local model = nil
		while os.clock() - t0 < 2.5 do
			local kit = plot:FindFirstChild("IslandKit")
			model = kit and kit:FindFirstChild(kitName)
			if model then break end
			task.wait(0.05)
		end
		if model and isNew then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then table.insert(parts, d) d.LocalTransparencyModifier = 1
				elseif (d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("Light") or d:IsA("ParticleEmitter")) and (d :: any).Enabled then
					(d :: any).Enabled = false
					switched[d] = true
				end
			end
		end
		glide(CFrame.lookAt(p + front * (dist + 14) + Vector3.new(0, dist * 0.6, 0), p), CFrame.lookAt(p + front * dist + Vector3.new(0, dist * 0.42, 0), p), 1.1, skipped, 52, 48)
		if isNew then
			for k = 0, 5 do
				local ang = k / 6 * math.pi * 2
				DinosaurVFX.FootstepDust(a.Position + Vector3.new(math.cos(ang) * 10, 0.5, math.sin(ang) * 10), 3)
			end
			DinosaurVFX.Shake(0.25, 0.4)
			waitFor(0.35, skipped)
			local s0 = os.clock()
			while os.clock() - s0 < 0.5 do
				local u = 1 - (os.clock() - s0) / 0.5
				for _, part in ipairs(parts) do part.LocalTransparencyModifier = u end
				RunService.RenderStepped:Wait()
			end
		end
		showAll()
		-- the star moves in now
		CampView.HoldPenStars = false
		CampView.RefreshOwn()
		flash(0.45, C.YellowHi)
		Audio.Play("ItemGet")
		CineKit.SunBurst(0.6)
		DinosaurVFX.BlockRing(CFrame.new(a.Position), { Count = 22, R0 = 2, R1 = 14, Color = C.YellowHi, Duration = 0.7 })
		if res.What == "Pen" then
			caption("STAR PEN", tostring(res.Name or "STAR PEN") .. "!", "+" .. math.floor(Config.Island.PenIncome * 100) .. "% ISLAND INCOME", C.YellowHi)
		else
			local tier = Config.Island[res.What] and Config.Island[res.What][res.Tier]
			caption("ISLAND UPGRADE", tostring(res.Name or "UPGRADED") .. "!", tier and tier.Perk and string.match(tier.Perk, "^[^+]+") or nil, C.YellowHi)
		end
		waitFor(1.8, skipped)
	end)
	showAll()
	if CampView.HoldPenStars then
		CampView.HoldPenStars = false
		CampView.RefreshOwn()
	end
end

function Scenes.Start()
	build()
	-- the chest prompt (in the hub): open it in person
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("CampAction") == "Chest" then
			local Net = require(script.Parent.Net)
			local res = Net.Ask("OpenChest")
			if res and res.Ok then Scenes.Chest(res) else Kit.Toast(res and res.Err or "NOT YET", "Orange", "Clock") end
		end
	end)
	-- the timer over the chest
	task.spawn(function()
		local Net = require(script.Parent.Net)
		while true do
			task.wait(1)
			local host = find("ChestPromptHost")
			local tag = host and host:FindFirstChild("ChestTag")
			local timer = tag and tag:FindFirstChild("Timer")
			local p = Net.Profile
			if timer and p and p.Daily then
				local left = Config.Daily.Every - (Net.ServerTime() - (p.Daily.Last or 0))
				local text = left <= 0 and "READY!" or Config.FormatTime(left)
				for _, l in ipairs(timer:GetDescendants()) do if l:IsA("TextLabel") then l.Text = text end end
				if timer:IsA("TextLabel") then timer.Text = text end
			end
		end
	end)
end

return Scenes
