--[[
	Shore — the invisible walls round Base Camp's shores, so nobody jumps into the lagoon (tools/gen/hub.js builds
	them along the hub + Time Gate deck, every island and both sides of every bridge, tagged "ShoreWall").
	They live in their own collision group that only player characters ("Walkers") bump into: rovers, dinos, eggs,
	the camera and every raycast in the game (which all use the Default group) go straight through them.
	Characters join Walkers when they spawn; Vehicles moves a seated driver to its own group and back to Walkers.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Shore = {}
Shore.WALL = "ShoreWall"
Shore.WALKERS = "Walkers"

-- registered at require time, so Vehicles (which requires this) can use the names straight away
pcall(function() PhysicsService:RegisterCollisionGroup(Shore.WALL) end)
pcall(function() PhysicsService:RegisterCollisionGroup(Shore.WALKERS) end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable(Shore.WALL, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(Shore.WALL, Shore.WALL, false)
	PhysicsService:CollisionGroupSetCollidable(Shore.WALL, Shore.WALKERS, true)
end)

local function setGroup(char: Instance)
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.CollisionGroup == "Default" then p.CollisionGroup = Shore.WALKERS end
	end
end

-- a seated driver is in the vehicles' group; anyone else on their feet is a walker
function Shore.Walk(char: Instance?)
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then p.CollisionGroup = Shore.WALKERS end
	end
end

-- walkers behave exactly like Default against every other group (call once the other groups exist)
function Shore.Start()
	for _, g in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
		local name = g.name
		if name ~= Shore.WALL and name ~= Shore.WALKERS then
			pcall(function()
				PhysicsService:CollisionGroupSetCollidable(Shore.WALKERS, name, PhysicsService:CollisionGroupsAreCollidable("Default", name))
				PhysicsService:CollisionGroupSetCollidable(Shore.WALL, name, false)
			end)
		end
	end
	pcall(function() PhysicsService:CollisionGroupSetCollidable(Shore.WALKERS, Shore.WALKERS, PhysicsService:CollisionGroupsAreCollidable("Default", "Default")) end)
	local n = 0
	local function wall(p: Instance)
		if p:IsA("BasePart") then
			p.CollisionGroup = Shore.WALL
			p.CanCollide = true
			p.CanTouch = false
			p.Transparency = 1
			n += 1
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("ShoreWall")) do wall(p) end
	CollectionService:GetInstanceAddedSignal("ShoreWall"):Connect(wall)
	local function onChar(char: Model)
		setGroup(char)
		-- accessories, tools and the held egg / launcher arrive after spawn (skip parts another system grouped)
		char.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and d.CollisionGroup == "Default" then d.CollisionGroup = Shore.WALKERS end
		end)
	end
	local function onPlayer(plr: Player)
		plr.CharacterAdded:Connect(onChar)
		if plr.Character then onChar(plr.Character) end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, plr in ipairs(Players:GetPlayers()) do onPlayer(plr) end
	print("[Shore]", n, "shore walls")
end

return Shore
