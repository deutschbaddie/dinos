--[[
	Floor — where a dinosaur's feet go in a cutscene. Only the eras' walkable surfaces count (the same folders the
	fight server walks its dinos on: Ground, Hills, Swells, Roads, Spine River's docks and the Maw) plus Terrain
	(water sets, the sea). Bushes, rocks, logs, nests, trees and canopies are never a floor: a dino walking past a
	boulder goes round or through it, it never climbs onto it (2026-10-12: the second dino of every era's arrival
	used to walk over the scenery).

	  Floor.At(p, up?) -> Vector3   the floor under (or just above) p; falls back to the first solid, visible thing
	                                 when there's no era floor here (Base Camp, odd spots)
	  Floor.Clear(a, b, ignore?)     is the straight line a -> b free of solid scenery a body can't pass through?
	                                 (hidden scenery - LocalTransparencyModifier 1 from a cutscene's clearPath - is
	                                 ignored, so it can be walked through)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Floor = {}
local WALK = { "Ground", "Hills", "Swells", "Roads", "SeaMouth", "TheMaw" }

local list: { Instance } = {}
local builtAt = -math.huge
local function floors(): { Instance }
	if os.clock() - builtAt < 5 and #list > 0 then return list end
	builtAt = os.clock()
	list = { Workspace.Terrain }
	for _, z in ipairs(Workspace:GetChildren()) do
		if z:IsA("Model") or z:IsA("Folder") then
			for _, n in ipairs(WALK) do
				local f = z:FindFirstChild(n)
				if f then table.insert(list, f) end
			end
		end
	end
	-- a cutscene set can add its own floor (a dock, a ramp) by tagging it
	for _, f in ipairs(CollectionService:GetTagged("DinoFloor")) do table.insert(list, f) end
	return list
end

local inc = RaycastParams.new()
inc.FilterType = Enum.RaycastFilterType.Include
inc.IgnoreWater = true
local exc = RaycastParams.new()
exc.FilterType = Enum.RaycastFilterType.Exclude

local function excludes(): { Instance }
	local l = {}
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(l, plr.Character) end end
	for _, n in ipairs({ "ActiveVehicles", "DinoExpeditionLocal", "DinoAmbience", "DinoCutsceneActors", "DinoTikTok", "DinoOmens", "DinoVFX_Client" }) do
		local f = Workspace:FindFirstChild(n)
		if f then table.insert(l, f) end
	end
	return l
end

function Floor.At(p: Vector3, up: number?): Vector3
	local h = up or 60
	inc.FilterDescendantsInstances = floors()
	local hit = Workspace:Raycast(p + Vector3.new(0, h, 0), Vector3.new(0, -(h + 300), 0), inc)
	if hit then return hit.Position end
	-- no era floor here: the first solid, visible thing (never a leaf or an invisible marker)
	local skip = excludes()
	exc.FilterDescendantsInstances = skip
	for _ = 1, 8 do
		hit = Workspace:Raycast(p + Vector3.new(0, h, 0), Vector3.new(0, -(h + 300), 0), exc)
		if not hit then break end
		local part = hit.Instance
		if part == Workspace.Terrain or (part:IsA("BasePart") and part.CanCollide and part.Transparency < 0.6) then return hit.Position end
		table.insert(skip, part)
		exc.FilterDescendantsInstances = skip
	end
	return p
end

-- the floor or the water surface, whichever is higher (a dino running through a ford splashes along the top
-- instead of running on the riverbed)
local incWater = RaycastParams.new()
incWater.FilterType = Enum.RaycastFilterType.Include
incWater.IgnoreWater = false
function Floor.AtWater(p: Vector3, up: number?): Vector3
	local h = up or 60
	incWater.FilterDescendantsInstances = floors()
	local hit = Workspace:Raycast(p + Vector3.new(0, h, 0), Vector3.new(0, -(h + 300), 0), incWater)
	if hit then return hit.Position end
	return Floor.At(p, up)
end

-- a body-height line test against solid scenery (hidden scenery and the floor itself don't block)
function Floor.Clear(a: Vector3, b: Vector3, ignore: { Instance }?): boolean
	local skip = excludes()
	for _, f in ipairs(floors()) do table.insert(skip, f) end
	if ignore then for _, i in ipairs(ignore) do table.insert(skip, i) end end
	exc.FilterDescendantsInstances = skip
	local o = a
	for _ = 1, 10 do
		local d = b - o
		if d.Magnitude < 0.05 then return true end
		local hit = Workspace:Raycast(o, d, exc)
		if not hit then return true end
		local part = hit.Instance
		local solid = part:IsA("BasePart") and part.CanCollide and part.Transparency < 0.6 and part.LocalTransparencyModifier < 0.99
		if solid then return false end
		table.insert(skip, part)
		exc.FilterDescendantsInstances = skip
		o = hit.Position + d.Unit * 0.05
	end
	return true
end

-- is a body of this size free to walk from a to b? (tested at knee and chest height, along both flanks)
function Floor.PathClear(a: Vector3, b: Vector3, height: number, width: number, ignore: { Instance }?): boolean
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	if d.Magnitude < 0.5 then return true end
	local side = d.Unit:Cross(Vector3.yAxis) * (width * 0.4)
	for _, y in ipairs({ height * 0.25, height * 0.6 }) do
		for _, s in ipairs({ -1, 0, 1 }) do
			local off = Vector3.new(0, y, 0) + side * s
			if not Floor.Clear(a + off, b + off, ignore) then return false end
		end
	end
	return true
end

-- is there room for a body here? A box (in world space) with nothing solid and visible in it - the floor, hidden
-- scenery and little foliage a cutscene can tuck away (a bush, a fern, a tuft) don't count; a rock, a trunk, a post,
-- a fence or a wall does (2026-10-14: the grazers of an era's arrival stood inside poles and boulders)
local FOLIAGE = { "Bush", "Fern", "Grass", "Flower", "Plant", "Shrub", "Reed", "Tuft", "Lily", "Mushroom", "Pebble", "Sapling", "Scrub", "Leaves" }
local freeParams = OverlapParams.new()
freeParams.FilterType = Enum.RaycastFilterType.Exclude
function Floor.Free(cf: CFrame, size: Vector3, ignore: { Instance }?): boolean
	local skip = excludes()
	for _, f in ipairs(floors()) do table.insert(skip, f) end
	if ignore then for _, i in ipairs(ignore) do table.insert(skip, i) end end
	freeParams.FilterDescendantsInstances = skip
	for _, p in ipairs(Workspace:GetPartBoundsInBox(cf, size, freeParams)) do
		if p.Transparency < 0.6 and p.LocalTransparencyModifier < 0.99 and (p.CanCollide or p.Size.Magnitude > 6) then
			local m = p:FindFirstAncestorWhichIsA("Model")
			local name = p.Name .. " " .. ((m and m ~= Workspace) and m.Name or "")
			local leafy = false
			for _, w in ipairs(FOLIAGE) do if string.find(name, w, 1, true) then leafy = true break end end
			if not leafy then return false end
		end
	end
	return true
end

-- TRAMPLE: a dinosaur running through the scenery (a chase off the road, a charge through the ferns) doesn't
-- clip through it - bushes, ferns, saplings and small rocks it runs into burst and step out of the way for a moment,
-- then come back. Whole decor models go (never half a tree); big trees, cliffs and buildings stay.
local SCENERY = { "Bush", "Fern", "Flower", "Grass", "Rock", "Tree", "Palm", "Cycad", "Plant", "Shrub", "Log", "Stump", "Reed", "Boulder",
	"Pebble", "Lily", "Mushroom", "Snag", "Conifer", "Pine", "Cactus", "Kelp", "Tuft", "Sapling", "Scrub", "Hoodoo" }
local function isScenery(name: string): boolean
	for _, w in ipairs(SCENERY) do if string.find(name, w, 1, true) then return true end end
	return false
end
local trampled = {} :: { [Instance]: { Until: number, Parts: { BasePart } } }
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
local restoring = false
local function restoreLoop()
	if restoring then return end
	restoring = true
	task.spawn(function()
		while next(trampled) do
			task.wait(0.25)
			local now = os.clock()
			for model, rec in pairs(trampled) do
				if now >= rec.Until then
					trampled[model] = nil
					for _, p in ipairs(rec.Parts) do if p.Parent then p.LocalTransparencyModifier = 0 end end
				end
			end
		end
		restoring = false
	end)
end
-- returns how many new things it knocked aside (for a burst of leaves)
function Floor.Trample(cf: CFrame, size: Vector3, hold: number?): (number, Vector3?)
	local skip = excludes()
	for _, f in ipairs(floors()) do table.insert(skip, f) end
	overlap.FilterDescendantsInstances = skip
	local n, at = 0, nil
	for _, p in ipairs(Workspace:GetPartBoundsInBox(cf, size, overlap)) do
		local model = p:FindFirstAncestorWhichIsA("Model") or p
		local rec = trampled[model]
		if rec then
			rec.Until = os.clock() + (hold or 2.5)
			continue
		end
		if not isScenery(model.Name) then continue end
		if model:IsA("Model") and model:GetExtentsSize().Magnitude > 70 then continue end
		local parts = {}
		for _, d in ipairs(model:IsA("Model") and model:GetDescendants() or { model }) do
			if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 then
				d.LocalTransparencyModifier = 1
				table.insert(parts, d)
			end
		end
		trampled[model] = { Until = os.clock() + (hold or 2.5), Parts = parts }
		n += 1
		at = p.Position
	end
	if n > 0 then restoreLoop() end
	return n, at
end

return Floor
