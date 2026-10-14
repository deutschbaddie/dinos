--[[
	Net (server) — one RemoteEvent for server→client messages, one RemoteFunction for client requests,
	one UnreliableRemoteEvent for the 15 Hz driving state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage.DinoExpedition.Remotes
local Event = Remotes:WaitForChild("GameEvent") :: RemoteEvent
local Request = Remotes:WaitForChild("GameRequest") :: RemoteFunction
local Drive = Remotes:WaitForChild("DriveState") :: UnreliableRemoteEvent

local Net = {}
local handlers = {}
local driveHandler = nil
local lastRequest = {} :: { [Player]: { [string]: number } }

function Net.Fire(player: Player, kind: string, payload: any?)
	if player.Parent then Event:FireClient(player, kind, payload) end
end

function Net.FireAll(kind: string, payload: any?)
	Event:FireAllClients(kind, payload)
end

function Net.FireOthers(except: Player, kind: string, payload: any?)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= except then Event:FireClient(p, kind, payload) end
	end
end

-- fn(player, args) -> result table
function Net.On(name: string, fn)
	handlers[name] = fn
end

function Net.OnDrive(fn)
	driveHandler = fn
end

-- (2026-10-12, security review) every number a client sends must be a real, finite number: NaN slips through
-- math.clamp / math.min / range checks (one NaN dart charge knocked out any dino, a NaN tier broke a boss for the
-- whole server). Walks the args (nested tables, Vector3 / Vector2 / CFrame parts), shallow depth.
local function finite(n: number): boolean return n == n and n ~= math.huge and n ~= -math.huge end
local function clean(v: any, depth: number): boolean
	local t = typeof(v)
	if t == "number" then return finite(v) end
	if t == "Vector3" then return finite(v.X) and finite(v.Y) and finite(v.Z) end
	if t == "Vector2" then return finite(v.X) and finite(v.Y) end
	if t == "CFrame" then return finite(v.X) and finite(v.Y) and finite(v.Z) end
	if t == "table" then
		if depth > 4 then return false end
		local n = 0
		for k, x in pairs(v) do
			n += 1
			if n > 200 or not clean(k, depth + 1) or not clean(x, depth + 1) then return false end
		end
	end
	return true
end
Net.Clean = clean

Request.OnServerInvoke = function(player: Player, name: any, args: any)
	if typeof(name) ~= "string" then return { Ok = false, Err = "bad request" } end
	if not clean(args, 0) then return { Ok = false, Err = "bad request" } end
	local fn = handlers[name]
	if not fn then return { Ok = false, Err = "unknown request" } end
	-- light rate limit per request type
	lastRequest[player] = lastRequest[player] or {}
	local now = os.clock()
	if lastRequest[player][name] and now - lastRequest[player][name] < 0.15 then return { Ok = false, Err = "slow down" } end
	lastRequest[player][name] = now
	local ok, res = pcall(fn, player, typeof(args) == "table" and args or {})
	if not ok then
		warn(`[Net] {name} failed for {player.Name}: {res}`)
		return { Ok = false, Err = "server error" }
	end
	return res or { Ok = true }
end

local lastDrive = {} :: { [Player]: number }
Drive.OnServerEvent:Connect(function(player, s, x, v, boosting, c1, c2)
	-- (at most ~40 reports a second: a flood of reports each got its own movement allowance in the chase check)
	local now = os.clock()
	if now - (lastDrive[player] or 0) < 0.025 then return end
	lastDrive[player] = now
	if driveHandler and typeof(s) == "number" and typeof(x) == "number" and typeof(v) == "number" and finite(s) and finite(x) and finite(v)
		and (c1 == nil or (typeof(c1) == "number" and finite(c1))) and (c2 == nil or (typeof(c2) == "number" and finite(c2))) then
		driveHandler(player, s, x, v, boosting == true, typeof(c1) == "number" and c1 or nil, typeof(c2) == "number" and c2 or nil)
	end
end)

Players.PlayerRemoving:Connect(function(p) lastRequest[p] = nil lastDrive[p] = nil end)

return Net
