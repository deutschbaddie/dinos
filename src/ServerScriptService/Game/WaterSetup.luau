--[[
	WaterSetup — real water for the eras that have it (Spine River's river, bay and sea).
	Generators can't save Terrain into a model file, so they leave invisible WaterVolume boxes tagged
	"TerrainWater"; at startup the server fills each with Terrain water (it replicates to everyone) and
	removes the box. Terrain water gives native swimming, waves and reflections for free.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local WaterSetup = {}

function WaterSetup.Start()
	local T = Workspace.Terrain
	-- one look for every era's water: clear tropical green-blue, gentle waves
	T.WaterColor = Color3.fromRGB(38, 128, 142)
	T.WaterTransparency = 0.62
	T.WaterReflectance = 0.38
	T.WaterWaveSize = 0.18
	T.WaterWaveSpeed = 10
	-- (2026-10-13) the world is islands in the sea now (Base Camp's lagoon, and open ocean outside the crater rim):
	-- a template Baseplate left in the place (top at y 0) would lie over the water like a grey floor. In a running game
	-- it goes; the anim showcase stands on its own pad (build.js). Studio edit mode is untouched - delete it there too.
	local bp = Workspace:FindFirstChild("Baseplate")
	if bp and bp:IsA("BasePart") then
		bp:Destroy()
		print("[WaterSetup] removed the template Baseplate (the sea is the floor now)")
	end
	-- the sea floor first (TerrainSand: the ocean's sandy bottom), then the water above it
	local n = 0
	for _, kind in ipairs({ { "TerrainSand", Enum.Material.Sand }, { "TerrainWater", Enum.Material.Water } }) do
		for _, m in ipairs(CollectionService:GetTagged(kind[1])) do
			if m:IsA("BasePart") then
				local ok, err = pcall(function() T:FillBlock(m.CFrame, m.Size, kind[2]) end)
				if ok then n += 1 else warn("[WaterSetup]", err) end
				m:Destroy()
			end
		end
	end
	print("[WaterSetup] filled", n, "water / sea floor volumes")
end

return WaterSetup
