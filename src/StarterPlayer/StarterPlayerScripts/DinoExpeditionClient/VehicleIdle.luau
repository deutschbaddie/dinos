-- VehicleIdle — small client-side idle life for the showcase vehicles:
-- amber beacons blink (tag "BlinkLight") and the Titan's radar dish turns (tag "SpinRadar").

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VehicleIdle = {}

function VehicleIdle.start()
	local lights = {}
	local radars = {}
	local function track(tag, store, fn)
		for _, i in ipairs(CollectionService:GetTagged(tag)) do fn(i, store) end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(i) task.defer(fn, i, store) end)
	end
	track("BlinkLight", lights, function(p, store)
		if p:IsA("BasePart") and p:IsDescendantOf(Workspace) then
			store[p] = { Color = p.Color, Phase = math.random() * 0.5 }
		end
	end)
	track("SpinRadar", radars, function(m, store)
		-- only the anchored showcase dish: the drivable Titan's template carries the same tag, and its dish is welded
		-- into the rover, so PivotTo-ing it every frame dragged the whole truck round in circles (tester, 2026-10-13)
		if m:IsA("Model") and m:IsDescendantOf(Workspace) and m.PrimaryPart and m.PrimaryPart.Anchored then
			store[m] = { Base = m:GetPivot(), Angle = 0 }
		end
	end)
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		for p, st in pairs(lights) do
			if not p.Parent then lights[p] = nil continue end
			local on = ((clock + st.Phase) % 0.9) < 0.45
			p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			p.Color = on and st.Color or st.Color:Lerp(Color3.new(0, 0, 0), 0.55)
		end
		for m, st in pairs(radars) do
			if not m.Parent or not (m.PrimaryPart and m.PrimaryPart.Anchored) then radars[m] = nil continue end
			st.Angle += dt * 1.2
			m:PivotTo(st.Base * CFrame.Angles(0, st.Angle, 0))
		end
	end)
end

return VehicleIdle
