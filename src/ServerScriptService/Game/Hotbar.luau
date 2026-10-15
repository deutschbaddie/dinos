--[[
	Hotbar — which dinos you've pinned to your hotbar (drag one from the Bag onto a slot). Eggs fill the slots
	that aren't pinned. profile.HotbarPins is a list of 6 dino ids ("" = free slot).
]]

local Hotbar = {}
Hotbar.SLOTS = 6
local Data, Net

local function pins(profile): { string }
	local p = profile.HotbarPins
	if typeof(p) ~= "table" then p = {} end
	for i = 1, Hotbar.SLOTS do if typeof(p[i]) ~= "string" then p[i] = "" end end
	for i = #p, Hotbar.SLOTS + 1, -1 do p[i] = nil end
	profile.HotbarPins = p
	return p
end
Hotbar.Pins = pins

local function hasDino(profile, id: string): boolean
	for _, d in ipairs(profile.Dinos or {}) do if d.Id == id then return true end end
	return false
end

-- pin a dino to a slot (nil slot = unpin it everywhere). A dino can only be in one slot.
function Hotbar.Pin(player: Player, id: string, slot: number?)
	local profile = Data.Peek(player)
	if not profile then return { Ok = false } end
	if not hasDino(profile, id) then return { Ok = false, Err = "THAT DINO IS GONE" } end
	local p = pins(profile)
	for i = 1, Hotbar.SLOTS do if p[i] == id then p[i] = "" end end
	if slot then
		slot = math.clamp(math.floor(slot), 1, Hotbar.SLOTS)
		p[slot] = id
	end
	Data.Changed(player)
	return { Ok = true, Slot = slot }
end

-- a new dino with nowhere else to go: the first free slot (nil when all six hold dinos: it waits in the bag)
function Hotbar.AutoPin(profile, id: string): number?
	local p = pins(profile)
	for i = 1, Hotbar.SLOTS do
		if p[i] == "" or not hasDino(profile, p[i]) then p[i] = id return i end
	end
	return nil
end

function Hotbar.Start(deps)
	Data, Net = deps.Data, deps.Net
	Net.On("PinHotbar", function(player, args)
		if typeof(args.Id) ~= "string" then return { Ok = false } end
		return Hotbar.Pin(player, args.Id, tonumber(args.Slot))
	end)
end

return Hotbar
