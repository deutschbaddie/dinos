--[[
	Gear — putting armor and launchers on a body (players, the Quartermaster, the outfitter's mannequin, the
	crafting bench). Models come from ReplicatedStorage.DinoExpedition.Gear (tools/gen/gear.js).

	Gear.DressArmor(char, tier, level)   armor pieces welded to the body: the tier sets the look, levels add pieces
	                                     (vest Lv1, shoulder plates Lv3, gauntlets Lv6, helmet Lv9, cape Lv10).
	                                     Works on R6 and R15 (and avatar scales): each piece hugs its bone.
	Gear.Launcher(id)                    a fresh launcher model (PrimaryPart GripRoot, barrel down -Y, Tip + Muzzle)
	Gear.Hold(char, id)                  launcher in the right hand
	Gear.Holster(char, id)               launcher slung across the back
	Gear.Clear(char, name)               remove "DinoArmor" / "DinoLauncherHand" / "DinoLauncherBack"

	Everything is welded with WeldConstraints (never Motor6Ds) so the procedural animation moves it for free.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = {}

local function lib(): Instance?
	local d = ReplicatedStorage:FindFirstChild("DinoExpedition")
	return d and d:FindFirstChild("Gear")
end

function Gear.Exists(kind: string, id: string): boolean
	local g = lib()
	local f = g and g:FindFirstChild(kind)
	return f ~= nil and f:FindFirstChild(id) ~= nil
end

local function bonePart(char: Instance, bone: string, seg: string?): BasePart?
	local function p(n: string): BasePart? return char:FindFirstChild(n) :: BasePart? end
	if bone == "Torso" then return p("UpperTorso") or p("Torso") end
	if bone == "Head" then return p("Head") end
	if bone == "RightLeg" or bone == "LeftLeg" then
		local ls = bone == "RightLeg" and "Right" or "Left"
		return p(ls .. "LowerLeg") or p(ls .. " Leg")
	end
	local side = bone == "RightArm" and "Right" or "Left"
	if p(side .. "UpperArm") then
		return seg == "LowerArm" and p(side .. "LowerArm") or p(side .. "UpperArm")
	end
	return p(side .. " Arm")
end

-- reference sizes the pieces were authored on (an R6 rig)
local REF_W = { Torso = 2, RightArm = 1, LeftArm = 1, Head = 1.2, RightLeg = 1, LeftLeg = 1 }
local REF_H = { Torso = 2, RightArm = 2, LeftArm = 2, Head = 0, RightLeg = 1, LeftLeg = 1 } -- (legs: the lower-leg guard, top at the knee)

local function weldAll(m: Instance, to: BasePart)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = to
			w.Part1 = d
			w.Parent = d
		end
	end
end

function Gear.Clear(char: Instance, name: string)
	local old = char:FindFirstChild(name)
	if old then old:Destroy() end
end

function Gear.DressArmor(char: Model, tier: string, level: number): Model?
	Gear.Clear(char, "DinoArmor")
	local g = lib()
	local tpl = g and g:FindFirstChild("Armor") and g.Armor:FindFirstChild(tier)
	if not tpl then return nil end
	local out = Instance.new("Model")
	out.Name = "DinoArmor"
	out:SetAttribute("Tier", tier)
	out:SetAttribute("Level", level)
	for _, piece in ipairs(tpl:GetChildren()) do
		if not piece:IsA("Model") then continue end
		if (piece:GetAttribute("MinLevel") or 1) > level then continue end
		local boneName = piece:GetAttribute("Bone") or "Torso"
		local bone = bonePart(char, boneName, piece:GetAttribute("Part"))
		if not bone then continue end
		local p = piece:Clone() :: Model
		-- scale to the bone's width (an R6 head part is 2 wide but looks 1.2: leave it be)
		local s = bone.Size.X / (REF_W[boneName] or 1)
		if boneName == "Head" and bone.Size.X > bone.Size.Y * 1.5 then s = 1 end
		if math.abs(s - 1) > 0.02 then pcall(function() p:ScaleTo(s) end) end
		local align = piece:GetAttribute("Align")
		local refH = REF_H[boneName] or 0
		local shift = 0
		if align == "Top" then shift = bone.Size.Y / 2 - s * refH / 2
		elseif align == "Bottom" then shift = -bone.Size.Y / 2 + s * refH / 2 end
		-- an R6 leg is one part, hip to foot: a lower-leg guard starts at its middle (the knee)
		if piece:GetAttribute("Part") == "LowerLeg" and string.find(bone.Name, " Leg", 1, true) then shift -= bone.Size.Y / 2 end
		p:PivotTo(bone.CFrame * CFrame.new(0, shift, 0))
		weldAll(p, bone)
		p.Parent = out
	end
	out.Parent = char
	return out
end

function Gear.Launcher(id: string): Model?
	local g = lib()
	local f = g and g:FindFirstChild("Launchers")
	local tpl = f and (f:FindFirstChild(id) or f:FindFirstChild("Rookie"))
	return tpl and (tpl:Clone() :: Model) or nil
end

local function hand(char: Instance): BasePart?
	return ((char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: any) :: BasePart?
end

function Gear.Hold(char: Model, id: string): Model?
	Gear.Clear(char, "DinoLauncherHand")
	local h = hand(char)
	local m = h and Gear.Launcher(id)
	if not (h and m) then return nil end
	m.Name = "DinoLauncherHand"
	-- the grip sits in the palm; the barrel runs along the arm so it points wherever the arm points
	m:PivotTo(h.CFrame * CFrame.new(0, -h.Size.Y / 2, 0))
	weldAll(m, h)
	m.Parent = char
	return m
end

function Gear.Holster(char: Model, id: string): Model?
	Gear.Clear(char, "DinoLauncherBack")
	local torso = ((char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: any) :: BasePart?
	local m = torso and Gear.Launcher(id)
	if not (torso and m) then return nil end
	m.Name = "DinoLauncherBack"
	-- slung across the back, barrel down to the left hip, sights facing out
	local armor = char:FindFirstChild("DinoArmor")
	local cape = armor and armor:FindFirstChild("Cape") and 0.12 or 0
	m:PivotTo((torso :: BasePart).CFrame * CFrame.new(0.35, 0.55, (torso :: BasePart).Size.Z / 2 + 0.42 + cape) * CFrame.Angles(0, math.pi, math.rad(-38)))
	weldAll(m, torso :: BasePart)
	m.Parent = char
	return m
end

-- the muzzle point of a held launcher
function Gear.Muzzle(m: Model?): Vector3?
	local tip = m and m:FindFirstChild("Tip", true)
	local a = tip and tip:FindFirstChild("Muzzle")
	return a and (a :: Attachment).WorldPosition or nil
end

-- what you're working toward: the first tier you don't own yet (nil when you have them all)
function Gear.NextTier(order: { string }, owned: { [string]: boolean }?): string?
	for _, id in ipairs(order) do
		if not (owned and owned[id]) then return id end
	end
	return nil
end

return Gear
