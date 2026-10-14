--[[
	DevHooks — tiny registry so the Settings > Test Tools panel can reach client systems that live outside
	the Game folder (e.g. the legacy showcase dev panel) without a require cycle.
]]
local DevHooks = {}
DevHooks.OpenShowcasePanel = nil :: (() -> ())?
return DevHooks
