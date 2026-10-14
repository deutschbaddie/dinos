--[[
	BillboardCalm — every floating label in the world (name tags, rarity tags, pins, prompts, egg tips...) keeps its
	text small. (2026-10-13, user: "minimize the max size the billboardguis textlabels can be, they can be
	overstimmy.") Any text inside a BillboardGui gets a text-size cap (a smaller one it already has is kept), now and
	for anything made later.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BillboardCalm = {}
BillboardCalm.MaxText = 18

local function cap(t: Instance)
	if not (t:IsA("TextLabel") or t:IsA("TextButton") or t:IsA("TextBox")) then return end
	if not t:FindFirstAncestorWhichIsA("BillboardGui") then return end
	local c = t:FindFirstChildOfClass("UITextSizeConstraint")
	if not c then
		c = Instance.new("UITextSizeConstraint")
		c.Parent = t
	end
	if c.MaxTextSize > BillboardCalm.MaxText then c.MaxTextSize = BillboardCalm.MaxText end
	if not (t :: any).TextScaled and (t :: any).TextSize > BillboardCalm.MaxText then (t :: any).TextSize = BillboardCalm.MaxText end
end

local function watch(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do cap(d) end
	root.DescendantAdded:Connect(function(d)
		-- (a label is often parented first and given its text a moment later)
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then task.defer(cap, d) end
	end)
end

function BillboardCalm.Start()
	watch(Workspace)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	watch(pg)
end

return BillboardCalm
