--[[
	DinoExpeditionServer — relays showcase pedestal ProximityPrompts to every client.
	Animations are procedural and client-side (Motor6D.Transform does not replicate), so the server
	only broadcasts "play action X on dinosaur Y"; the player who triggered it also gets the cinematic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local remote = ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Remotes"):WaitForChild("ShowcaseEvent")
local VALID = { Roar = true, Signature = true, CycleAnimation = true, Reset = true }
local lastUse: { [Player]: number } = {}

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
	local action = prompt:GetAttribute("DinoAction")
	if not VALID[action] then return end
	local now = os.clock()
	if lastUse[player] and now - lastUse[player] < 0.5 then return end
	lastUse[player] = now
	local pedestal = prompt:FindFirstAncestorWhichIsA("Model")
	local target = pedestal and pedestal:FindFirstChild("Target")
	local model = target and target:IsA("ObjectValue") and target.Value
	if model and model:IsA("Model") then
		remote:FireAllClients(model, action, player)
	end
end)

game:GetService("Players").PlayerRemoving:Connect(function(p) lastUse[p] = nil end)
