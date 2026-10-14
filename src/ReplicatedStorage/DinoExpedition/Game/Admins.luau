--[[
	Admins — who gets the ADMIN tab in Settings. Matched by UserId, so name changes don't lock anyone out.
	  Owner  everything: making / removing admins, bans + unbans, giving coins / eggs, announcing to every server,
	         shutting a server down
	  Admin  moderation: go to / bring / send home / freeze / respawn / spectate, kick, server announcements, waking
	         the boss. Banning only for admins marked CanBan. Admins can't act on the owner or on each other.
	The server (Admin.luau) checks every request against this list; the client only uses it to show the tab.
	In Studio everyone is Owner so the panel can be tested.
]]

local RunService = game:GetService("RunService")

local Admins = {}

-- (2026-10-14, the user: only SickleEdge makes admins; only SickleEdge and NotTufferson ban - every other admin can
-- kick but never ban. CanBan marks the one admin who may)
Admins.List = {
	{ Name = "SickleEdge", UserId = 2036303552, Role = "Owner" },
	{ Name = "NotTufferson", UserId = 11747542860, Role = "Admin", CanBan = true },
	{ Name = "Get_clap2unitz", UserId = 9063807477, Role = "Admin" },
	{ Name = "RyanMitar100", UserId = 572317491, Role = "Admin" },
	{ Name = "DracoOfGaia", UserId = 1055598263, Role = "Admin" },
}

local RANK = { Owner = 2, Admin = 1 }
local byId = {} :: { [number]: string }
local banners = {} :: { [number]: boolean }
for _, a in ipairs(Admins.List) do
	byId[a.UserId] = a.Role
	if a.CanBan then banners[a.UserId] = true end
end
-- admins SickleEdge made in game (the server loads and keeps these: Admin.luau). Always plain admins: kick, no ban
Admins.Granted = {} :: { [number]: boolean }

-- "Owner", "Admin" or nil
function Admins.Role(userId: number): string?
	if RunService:IsStudio() then return "Owner" end
	return byId[userId] or (Admins.Granted[userId] and "Admin" or nil)
end

-- may ban (and unban): the owner, and the admins marked CanBan
function Admins.CanBan(userId: number): boolean
	local role = Admins.Role(userId)
	return role == "Owner" or (role ~= nil and banners[userId] == true)
end

-- made an admin in game (not on the list above): the owner can take it away again
function Admins.IsGranted(userId: number): boolean
	return byId[userId] == nil and Admins.Granted[userId] == true
end

function Admins.Rank(userId: number): number
	return RANK[Admins.Role(userId) or ""] or 0
end

-- may this staff member moderate that player? (the owner can act on anyone; admins only on non-staff)
function Admins.CanTarget(actorId: number, targetId: number): boolean
	if actorId == targetId then return false end
	local a = Admins.Rank(actorId)
	if a >= RANK.Owner then return true end
	return a > 0 and Admins.Rank(targetId) == 0
end

return Admins
