--[[
	CampMoves — your character's moves around camp that need a little staging on the client.

	  setting an egg in a nest   the nest prompt is the server's (it takes the egg out of your arms at once); here
	                             a local stand-in of that egg rides your hands down into the bowl (PlayerAnim
	                             "Place": you crouch, set it in, let go and stand), the real nest egg stays hidden
	                             until it lands, and the egg in your arms is hidden meanwhile so there's never two.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local CampView = require(script.Parent.CampView)
local PlayerAnim = require(script.Parent.PlayerAnim)

local player = Players.LocalPlayer
local CampMoves = {}

local function incubatorIn(plot: Instance, slot: number): boolean
	local ok, list = pcall(HttpService.JSONDecode, HttpService, plot:GetAttribute("Incubators") or "[]")
	if not ok then return false end
	for _, inc in ipairs(list) do if inc.Slot == slot then return true end end
	return false
end

local placing = false
local function placeEgg(prompt: ProximityPrompt)
	if placing then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local held = char and char:FindFirstChild("HeldEggModel") :: Model?
	local slot = prompt:GetAttribute("Slot")
	local plot = CampView.OwnPlot()
	if not (hrp and hum and held and typeof(slot) == "number" and plot and prompt:IsDescendantOf(plot)) then return end
	if incubatorIn(plot, slot) then return end -- that's a hatch, not a placing
	local point = CampView.NestPoint(slot)
	if not point then return end
	placing = true
	-- the stand-in: a copy of the egg in your arms, then hide the real one (the server removes it in a moment)
	local proxy = held:Clone()
	for _, d in ipairs(proxy:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true d.CanCollide = false d.CanQuery = false end
	end
	proxy.Name = "PlacingEgg"
	proxy.Parent = Workspace
	for _, d in ipairs(held:GetDescendants()) do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 end
	end
	CampView.HideEgg(slot, true)
	-- face the nest and hold still for the moment it takes
	local look = Vector3.new(point.Position.X, hrp.Position.Y, point.Position.Z)
	if (look - hrp.Position).Magnitude > 0.2 then hrp.CFrame = CFrame.lookAt(hrp.Position, look) end
	hum:SetAttribute("Frozen", true)
	local seat = CampView.SeatOn(proxy, point.CFrame)
	local done = false
	PlayerAnim.Act(char, "Place", {
		Target = seat, Model = proxy, Size = proxy:GetExtentsSize(),
		Done = function()
			if done then return end
			done = true
			-- the real egg takes its place once the server has it in the nest (or the egg comes back if it didn't)
			local t0 = os.clock()
			while os.clock() - t0 < 2 and not incubatorIn(plot, slot) do task.wait() end
			CampView.HideEgg(slot, false)
			proxy:Destroy()
			if held.Parent then
				for _, d in ipairs(held:GetDescendants()) do
					if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
				end
			end
		end,
	})
	task.delay(0.85, function()
		hum:SetAttribute("Frozen", nil)
		placing = false
	end)
end

function CampMoves.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("CampAction") == "Hatch" and player:GetAttribute("HeldEgg") then placeEgg(prompt) end
	end)
end

return CampMoves
