--[[
	Npcs — real R6 characters at every NpcSpot_<Kind> in the world, each with a role:
	  Professor   the story; introduces every ruler; boss tiers + mastery
	  Mechanic    (shown as THE ARMORER) armor and gadgets, crafted from boss parts (launcher power is the trainer's now)
	  EggKeeper   hatching help, selling dinos, the Dino Index
	  Ranger      era jobs (side quests) at each era's arrival camp
	They idle with the classic R6 animations; clients add looks, waves and conversation gestures.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Npcs = {}

local IDLE = "rbxassetid://180435571"

local SKIN = {
	Professor = Color3.fromRGB(242, 200, 160),
	Mechanic = Color3.fromRGB(201, 140, 94),
	EggKeeper = Color3.fromRGB(246, 215, 184),
	Ranger = Color3.fromRGB(141, 90, 59),
	Sightseer = Color3.fromRGB(234, 192, 150),
}
local OUTFIT = {
	Professor = { Torso = Color3.fromRGB(245, 245, 240), Legs = Color3.fromRGB(138, 122, 90) },
	Mechanic = { Torso = Color3.fromRGB(255, 138, 36), Legs = Color3.fromRGB(240, 120, 28) },
	EggKeeper = { Torso = Color3.fromRGB(242, 230, 200), Legs = Color3.fromRGB(90, 122, 58) },
	Ranger = { Torso = Color3.fromRGB(201, 179, 122), Legs = Color3.fromRGB(110, 90, 54) },
	Sightseer = { Torso = Color3.fromRGB(46, 196, 182), Legs = Color3.fromRGB(214, 190, 140) }, -- a loud tourist shirt, khaki shorts
}

-- weld a little block to a body part (offset in that part's space)
local function piece(char: Model, partName: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local body = char:FindFirstChild(partName) :: BasePart?
	if not body then return nil end
	local p = Instance.new("Part")
	p.Name = "Outfit"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CFrame = body.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = body, p
	w.Parent = p
	p.Parent = char
	return p
end

local function dress(char: Model, kind: string)
	local dark = Color3.fromRGB(43, 45, 49)
	if kind == "Professor" then
		piece(char, "Head", Vector3.new(1.25, 0.35, 1.1), CFrame.new(0, 0.62, 0.05), Color3.fromRGB(205, 208, 214))
		piece(char, "Head", Vector3.new(0.7, 0.3, 0.4), CFrame.new(0.3, 0.55, -0.45) * CFrame.Angles(0, 0, -0.2), Color3.fromRGB(205, 208, 214))
		for _, s in ipairs({ -1, 1 }) do
			local rim = piece(char, "Head", Vector3.new(0.34, 0.3, 0.05), CFrame.new(s * 0.22, 0.12, -0.58), dark)
			local lens = piece(char, "Head", Vector3.new(0.26, 0.22, 0.04), CFrame.new(s * 0.22, 0.12, -0.6), Color3.fromRGB(190, 232, 255), Enum.Material.Glass)
			if lens then lens.Transparency = 0.35 end
			local _ = rim
		end
		piece(char, "Torso", Vector3.new(2.06, 1.3, 1.08), CFrame.new(0, -1.55, 0), Color3.fromRGB(250, 250, 248)) -- coat tails
		for _, s in ipairs({ -1, 1 }) do piece(char, "Torso", Vector3.new(0.4, 1.5, 0.08), CFrame.new(s * 0.45, 0.2, -0.53) * CFrame.Angles(0, 0, s * 0.2), Color3.fromRGB(228, 228, 222)) end
		piece(char, "Torso", Vector3.new(0.3, 1.2, 0.06), CFrame.new(0, 0.15, -0.54), Color3.fromRGB(210, 58, 58)) -- tie
		piece(char, "Left Arm", Vector3.new(1.3, 1.7, 0.12), CFrame.new(-0.2, -1.1, -0.65) * CFrame.Angles(-0.3, 0, 0), Color3.fromRGB(138, 90, 51)) -- clipboard
		piece(char, "Left Arm", Vector3.new(1.1, 1.4, 0.04), CFrame.new(-0.2, -1.08, -0.73) * CFrame.Angles(-0.3, 0, 0), Color3.new(1, 1, 1))
	elseif kind == "Mechanic" then
		piece(char, "Head", Vector3.new(1.3, 0.45, 1.15), CFrame.new(0, 0.65, 0), Color3.fromRGB(47, 107, 58))
		piece(char, "Head", Vector3.new(1.05, 0.12, 0.7), CFrame.new(0, 0.48, 0.85), Color3.fromRGB(47, 107, 58))
		piece(char, "Head", Vector3.new(1.25, 0.28, 0.12), CFrame.new(0, 0.42, -0.6), dark)
		for _, s in ipairs({ -1, 1 }) do piece(char, "Head", Vector3.new(0.36, 0.22, 0.06), CFrame.new(s * 0.28, 0.42, -0.66), Color3.fromRGB(127, 227, 255), Enum.Material.Neon) end
		piece(char, "Torso", Vector3.new(1.3, 1.1, 0.08), CFrame.new(0, -0.35, -0.53), Color3.fromRGB(224, 115, 26)) -- bib
		for _, s in ipairs({ -1, 1 }) do piece(char, "Torso", Vector3.new(0.28, 1.2, 0.08), CFrame.new(s * 0.55, 0.35, -0.53), Color3.fromRGB(224, 115, 26)) end
		piece(char, "Torso", Vector3.new(0.4, 0.7, 0.06), CFrame.new(-0.72, -0.7, -0.54) * CFrame.Angles(0, 0, 0.15), Color3.fromRGB(210, 58, 58)) -- rag
		piece(char, "Right Arm", Vector3.new(0.3, 2.2, 0.3), CFrame.new(0, -1.6, -0.45), Color3.fromRGB(184, 190, 196), Enum.Material.Metal) -- wrench
		piece(char, "Right Arm", Vector3.new(0.9, 0.5, 0.3), CFrame.new(0, -2.7, -0.45), Color3.fromRGB(184, 190, 196), Enum.Material.Metal)
	elseif kind == "EggKeeper" then
		piece(char, "Head", Vector3.new(0.15, 2.6, 2.6), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(227, 197, 106), nil, Enum.PartType.Cylinder)
		piece(char, "Head", Vector3.new(1.25, 0.6, 1.25), CFrame.new(0, 0.95, 0), Color3.fromRGB(227, 197, 106))
		piece(char, "Head", Vector3.new(1.28, 0.18, 1.28), CFrame.new(0, 0.72, 0), Color3.fromRGB(95, 211, 90))
		piece(char, "Torso", Vector3.new(1.6, 2.4, 0.08), CFrame.new(0, -0.55, -0.53), Color3.fromRGB(79, 176, 67)) -- apron
		piece(char, "Torso", Vector3.new(0.9, 0.5, 0.08), CFrame.new(0, -0.9, -0.58), Color3.fromRGB(63, 154, 58))
		piece(char, "Left Arm", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0.5, -1.3, -0.7), Color3.fromRGB(255, 244, 214), nil, Enum.PartType.Ball) -- the egg
	elseif kind == "Ranger" then
		piece(char, "Head", Vector3.new(0.15, 2.3, 2.3), CFrame.new(0, 0.66, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(168, 146, 90), nil, Enum.PartType.Cylinder)
		piece(char, "Head", Vector3.new(1.2, 0.55, 1.2), CFrame.new(0, 0.96, 0), Color3.fromRGB(191, 166, 106))
		piece(char, "Head", Vector3.new(1.24, 0.16, 1.24), CFrame.new(0, 0.76, 0), Color3.fromRGB(94, 63, 34))
		piece(char, "Torso", Vector3.new(2.08, 1.6, 1.08), CFrame.new(0, 0.1, 0), Color3.fromRGB(94, 122, 58)) -- vest
		piece(char, "Torso", Vector3.new(0.9, 0.5, 0.4), CFrame.new(0.15, -0.35, -0.78), dark) -- binoculars
		piece(char, "Torso", Vector3.new(1.6, 1.8, 0.8), CFrame.new(0, -0.1, 0.92), Color3.fromRGB(138, 90, 51)) -- backpack
		piece(char, "Torso", Vector3.new(1.8, 0.5, 0.5), CFrame.new(0, 0.9, 0.95), Color3.fromRGB(63, 122, 46)) -- bedroll
	elseif kind == "Sightseer" then
		-- a tourist out sightseeing in the age of the dinosaurs: sun hat, sunglasses, a camera round the neck, a map
		piece(char, "Head", Vector3.new(0.15, 2.4, 2.4), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(246, 226, 160), nil, Enum.PartType.Cylinder)
		piece(char, "Head", Vector3.new(1.2, 0.5, 1.2), CFrame.new(0, 0.9, 0), Color3.fromRGB(246, 226, 160))
		piece(char, "Head", Vector3.new(1.23, 0.14, 1.23), CFrame.new(0, 0.7, 0), Color3.fromRGB(232, 84, 120)) -- hat band
		for _, s in ipairs({ -1, 1 }) do
			piece(char, "Head", Vector3.new(0.34, 0.22, 0.05), CFrame.new(s * 0.22, 0.12, -0.6), Color3.fromRGB(30, 30, 36), Enum.Material.Glass)
		end
		piece(char, "Head", Vector3.new(0.14, 0.06, 0.05), CFrame.new(0, 0.15, -0.6), Color3.fromRGB(30, 30, 36))
		-- the shirt's flowers
		for i, o in ipairs({ Vector3.new(-0.5, 0.45, -0.52), Vector3.new(0.45, -0.2, -0.52), Vector3.new(-0.3, -0.6, -0.52), Vector3.new(0.55, 0.6, -0.52) }) do
			piece(char, "Torso", Vector3.new(0.32, 0.32, 0.06), CFrame.new(o) * CFrame.Angles(0, 0, i), i % 2 == 0 and Color3.fromRGB(255, 214, 72) or Color3.fromRGB(255, 120, 160))
		end
		piece(char, "Torso", Vector3.new(0.08, 1.1, 0.08), CFrame.new(-0.35, 0.45, -0.55) * CFrame.Angles(0, 0, 0.55), dark) -- camera strap
		piece(char, "Torso", Vector3.new(0.08, 1.1, 0.08), CFrame.new(0.35, 0.45, -0.55) * CFrame.Angles(0, 0, -0.55), dark)
		piece(char, "Torso", Vector3.new(0.75, 0.5, 0.35), CFrame.new(0, -0.05, -0.72), dark) -- the camera
		piece(char, "Torso", Vector3.new(0.3, 0.3, 0.2), CFrame.new(0, -0.05, -0.95), Color3.fromRGB(120, 200, 255), Enum.Material.Glass)
		piece(char, "Left Arm", Vector3.new(1.4, 1.1, 0.06), CFrame.new(0.1, -1.2, -0.68) * CFrame.Angles(-0.4, 0.2, 0), Color3.fromRGB(240, 228, 196)) -- the map
		piece(char, "Left Arm", Vector3.new(0.5, 0.35, 0.07), CFrame.new(0.2, -1.1, -0.7) * CFrame.Angles(-0.4, 0.2, 0), Color3.fromRGB(110, 190, 90))
		piece(char, "Torso", Vector3.new(1.4, 1.4, 0.6), CFrame.new(0, -0.05, 0.82), Color3.fromRGB(232, 84, 120)) -- a little backpack
	end
end

local function spawnAt(spot: BasePart)
	local kind = spot:GetAttribute("Npc")
	if not kind or spot:FindFirstChild("Npc") then return end
	local desc = Instance.new("HumanoidDescription")
	local skin, fit = SKIN[kind] or SKIN.Professor, OUTFIT[kind] or OUTFIT.Professor
	desc.HeadColor = skin
	desc.LeftArmColor = fit.Torso
	desc.RightArmColor = fit.Torso
	desc.TorsoColor = fit.Torso
	desc.LeftLegColor = fit.Legs
	desc.RightLegColor = fit.Legs
	local ok, char = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6) end)
	if not ok or not char then warn("[Npcs] couldn't build", kind, char) return end
	char.Name = "Npc"
	char:SetAttribute("Npc", kind)
	-- hands use skin colour (the arms are sleeves)
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.MaxHealth, hum.Health = math.huge, math.huge
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
	-- stand on whatever is really under the spot (steps, decks, stages): R6 root sits 3 studs above the feet
	local cf = spot.CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { spot, char }
	-- the floor under the spot: the highest SOLID surface across the footprint (a step or porch under one foot
	-- counts; see-through decor plates don't), from above so a raised deck isn't missed
	params.RespectCanCollide = true
	local floorY = cf.Position.Y - 3
	for _, o in ipairs({ Vector3.zero, Vector3.new(0.8, 0, 0), Vector3.new(-0.8, 0, 0), Vector3.new(0, 0, 0.6), Vector3.new(0, 0, -0.6) }) do
		local from = (cf * CFrame.new(o)).Position + Vector3.new(0, 4, 0)
		local hit = Workspace:Raycast(from, Vector3.new(0, -16, 0), params)
		if hit and hit.Position.Y <= cf.Position.Y + 1.5 and hit.Position.Y > floorY then floorY = hit.Position.Y end
	end
	char:PivotTo(cf)
	-- then stand the rig on it by its real feet (measured, not assumed): no NPC knee-deep in the floor
	local feet = math.huge
	for _, n in ipairs({ "Left Leg", "Right Leg", "LeftFoot", "RightFoot" }) do
		local leg = char:FindFirstChild(n) :: BasePart?
		if leg then feet = math.min(feet, leg.Position.Y - leg.Size.Y / 2) end
	end
	if feet < math.huge then char:PivotTo(char:GetPivot() + Vector3.new(0, floorY - feet + 0.02, 0)) end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then d.CanCollide = d == root d.CanQuery = false d.CanTouch = false end
	end
	root.Anchored = true
	dress(char, kind)
	local animate = char:FindFirstChild("Animate")
	if animate then animate:Destroy() end
	char.Parent = spot
	CollectionService:AddTag(char, "DinoNpc")
	-- the classic R6 idle on loop (clients add waves and talk gestures on top)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local a = Instance.new("Animation")
	a.AnimationId = IDLE
	local okT, track = pcall(function() return (animator :: Animator):LoadAnimation(a) end)
	if okT and track then track.Looped = true track:Play(0.3) end
end

-- the Mechanic is THE ARMORER now (id unchanged so saves / quests keep working; 2026-10-14, user: "quartermaster is
-- just for armor so call him the armorer"): fix any baked-in name in the world until the map is regenerated with
-- the new npcs.js / hub.js (name tag, Talk prompt, the outfitters' sign and its prompt)
local RENAME_TEXT = { ["THE MECHANIC"] = "THE ARMORER", ["THE QUARTERMASTER"] = "THE ARMORER", ["QUARTERMASTER"] = "THE ARMORER" }
local RENAME_OBJECT = { Mechanic = "Armorer", Quartermaster = "Armorer" }
local function renameMechanic(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextLabel") and RENAME_TEXT[d.Text] then d.Text = RENAME_TEXT[d.Text]
		elseif d:IsA("ProximityPrompt") then
			if RENAME_OBJECT[d.ObjectText] then d.ObjectText = RENAME_OBJECT[d.ObjectText] end
			-- (his outfitters' counter: he doesn't run a workshop of everything any more)
			if d:GetAttribute("CampAction") == "Shop" and d.ActionText == "Workshop" then d.ActionText = "Gear up" end
		end
	end
end

-- an NPC at a spot made at runtime (the Sightseer: Sightseer.luau places one per era)
Npcs.SpawnAt = spawnAt

function Npcs.Start()
	task.spawn(function() renameMechanic(Workspace:WaitForChild("BaseCamp")) end)
	for _, zone in ipairs({ Workspace:WaitForChild("BaseCamp"), Workspace:FindFirstChild("FernValley"), Workspace:FindFirstChild("GiantPlains"), Workspace:FindFirstChild("SpineRiver"), Workspace:FindFirstChild("RedCliffs"), Workspace:FindFirstChild("FrostForest"), Workspace:FindFirstChild("DawnDesert") }) do
		if not zone then continue end
		for _, spot in ipairs(zone:GetDescendants()) do
			if spot:IsA("BasePart") and spot.Name:match("^NpcSpot_") then task.spawn(spawnAt, spot) end
		end
	end
end

return Npcs
