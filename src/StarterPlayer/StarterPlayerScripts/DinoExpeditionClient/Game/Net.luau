--[[
	Net (client) + State — server messages fan out to listeners; the latest profile snapshot is cached
	so every screen reads the same numbers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Remotes")
local Event = Remotes:WaitForChild("GameEvent") :: RemoteEvent
local Request = Remotes:WaitForChild("GameRequest") :: RemoteFunction
local Drive = Remotes:WaitForChild("DriveState") :: UnreliableRemoteEvent

local Net = {}
local listeners = {} :: { [string]: { (any) -> () } }

Net.Profile = nil :: any
Net.ProfileAt = 0 -- os.clock() when the snapshot arrived
Net.ServerOffset = 0 -- server os.time() - local os.time()

function Net.On(kind: string, fn: (any) -> ())
	listeners[kind] = listeners[kind] or {}
	table.insert(listeners[kind], fn)
end

local function emit(kind: string, payload: any)
	for _, fn in ipairs(listeners[kind] or {}) do
		task.spawn(fn, payload)
	end
end
Net.Emit = emit

-- held: while the tester main menu is up most of the game hasn't started listening yet, so messages nobody is
-- listening for (welcome back toasts, onboarding, ...) wait here and are delivered once the game boots. Kinds
-- that already have listeners (Base Camp's world) still arrive live. Release re-sends the latest Profile so
-- the screens that started late see it too.
local held: { { any } }? = nil
function Net.Hold()
	held = held or {}
end
function Net.Release()
	local list = held
	if not list then return end
	held = nil
	for _, m in ipairs(list) do emit(m[1], m[2]) end
	if Net.Profile then emit("Profile", Net.Profile) end
end

Event.OnClientEvent:Connect(function(kind: string, payload: any)
	if kind == "Profile" then
		Net.Profile = payload
		Net.ProfileAt = os.clock()
		if payload and payload.ServerTime then Net.ServerOffset = payload.ServerTime - os.time() end
	end
	if held and #(listeners[kind] or {}) == 0 then
		if #held < 200 then table.insert(held, { kind, payload }) end
		return
	end
	emit(kind, payload)
end)

Net.AskHook = nil :: ((string, any, any) -> ())? -- SoundFx: a sound for what a request did (sold, bought, crafted...)
function Net.Ask(name: string, args: any?): any
	local ok, res = pcall(function() return Request:InvokeServer(name, args or {}) end)
	if not ok then return { Ok = false, Err = "CONNECTION ERROR" } end
	res = res or { Ok = false }
	if Net.AskHook then task.spawn(Net.AskHook, name, args, res) end
	return res
end

function Net.SendDrive(s: number, x: number, v: number, boosting: boolean, c1: number?, c2: number?)
	Drive:FireServer(s, x, v, boosting, c1, c2)
end

function Net.ServerTime(): number
	return os.time() + Net.ServerOffset
end

-- first snapshot (in case the push arrived before we were listening)
task.spawn(function()
	if not Net.Profile then
		local res = Net.Ask("Profile")
		if res and res.Ok and not Net.Profile then
			Net.Profile = res.Profile
			Net.ProfileAt = os.clock()
			if res.Profile.ServerTime then Net.ServerOffset = res.Profile.ServerTime - os.time() end
			emit("Profile", res.Profile)
		end
	end
end)

return Net
