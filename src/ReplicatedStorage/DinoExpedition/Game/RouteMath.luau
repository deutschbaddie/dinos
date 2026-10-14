--[[
	RouteMath — guided-road geometry shared by server (validation, chase AI) and client (driving, rendering).

	A route has several variants (one per combination of fork choices). Each variant is a polyline
	sampled every `Step` studs with cumulative distance. Positions are addressed as (variant, s, x):
	s = distance along the road, x = lateral offset (+ = right of travel).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RouteMath = {}
RouteMath.__index = RouteMath

local cache = {}

function RouteMath.get(zone: string)
	if cache[zone] then return cache[zone] end
	local mod = ReplicatedStorage:WaitForChild("DinoExpedition"):WaitForChild("Routes"):FindFirstChild(zone)
	if not mod then return nil end
	local data = require(mod)
	local self = setmetatable({ Data = data, Zone = zone, Variants = {} }, RouteMath)
	for vi, v in ipairs(data.Variants) do
		local pts, cum = {}, {}
		local flat = v.Points
		for i = 1, #flat, 3 do
			table.insert(pts, Vector3.new(flat[i], flat[i + 1], flat[i + 2]))
		end
		cum[1] = 0
		for i = 2, #pts do
			local d = pts[i] - pts[i - 1]
			cum[i] = cum[i - 1] + Vector3.new(d.X, 0, d.Z).Magnitude
		end
		self.Variants[vi] = { Points = pts, Cum = cum, Length = cum[#cum], Choices = v.Choices, HalfWidths = v.HalfWidths }
	end
	cache[zone] = self
	return self
end

function RouteMath:Variant(vi: number)
	return self.Variants[vi] or self.Variants[1]
end

-- index i such that Cum[i] <= s < Cum[i+1]
local function locate(v, s: number): (number, number)
	local cum = v.Cum
	local n = #cum
	if s <= 0 then return 1, 0 end
	if s >= cum[n] then return n - 1, 1 end
	-- uniform-ish spacing: start from a guess then walk
	local i = math.clamp(math.floor(s / (cum[n] / (n - 1))) + 1, 1, n - 1)
	while i > 1 and cum[i] > s do i -= 1 end
	while i < n - 1 and cum[i + 1] <= s do i += 1 end
	local t = (s - cum[i]) / math.max(1e-6, cum[i + 1] - cum[i])
	return i, t
end

-- centre position, forward (flat, unit), right (flat, unit), slope (dy/ds)
function RouteMath:Sample(vi: number, s: number): (Vector3, Vector3, Vector3, number)
	local v = self:Variant(vi)
	local i, t = locate(v, s)
	local a, b = v.Points[i], v.Points[i + 1]
	local p = a:Lerp(b, t)
	-- smooth the heading by looking a little ahead and behind
	local ia, _ = locate(v, s - 3)
	local ib, _ = locate(v, s + 3)
	local fa, fb = v.Points[ia], v.Points[math.min(#v.Points, ib + 1)]
	local d = fb - fa
	local flat = Vector3.new(d.X, 0, d.Z)
	local f = flat.Magnitude > 1e-4 and flat.Unit or Vector3.new(0, 0, -1)
	local r = Vector3.new(-f.Z, 0, f.X)
	local run = flat.Magnitude
	local slope = run > 1e-4 and d.Y / run or 0
	return p, f, r, slope
end

function RouteMath:Position(vi: number, s: number, x: number): Vector3
	local p, _, r = self:Sample(vi, s)
	return p + r * x
end

-- vehicle CFrame on the road: positioned at (s, x), facing along the road, pitched with the slope
function RouteMath:Frame(vi: number, s: number, x: number, yawOffset: number?): CFrame
	local p, f, r, slope = self:Sample(vi, s)
	local pos = p + r * x
	local look = (f + Vector3.new(0, slope, 0)).Unit
	local cf = CFrame.lookAt(pos, pos + look)
	if yawOffset and yawOffset ~= 0 then cf = cf * CFrame.Angles(0, yawOffset, 0) end
	return cf
end

function RouteMath:HalfWidth(vi: number, s: number): number
	local v = self:Variant(vi)
	local hw = 12
	for _, e in ipairs(v.HalfWidths) do
		if s >= e[1] then hw = e[2] else break end
	end
	return hw
end

function RouteMath:Length(vi: number): number
	return self:Variant(vi).Length
end

-- nearest (s, x) to a world position; `hint` (an s) keeps the search local and cheap
function RouteMath:Project(vi: number, pos: Vector3, hint: number?): (number, number, number)
	local v = self:Variant(vi)
	local pts, cum = v.Points, v.Cum
	local n = #pts
	local i0, i1 = 1, n - 1
	if hint then
		local hi = locate(v, hint)
		i0, i1 = math.max(1, hi - 40), math.min(n - 1, hi + 40)
	end
	local best, bs, bx = math.huge, 0, 0
	for i = i0, i1 do
		local a, b = pts[i], pts[i + 1]
		local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local L2 = d:Dot(d)
		if L2 < 1e-8 then continue end
		local q = Vector3.new(pos.X - a.X, 0, pos.Z - a.Z)
		local t = math.clamp(q:Dot(d) / L2, 0, 1)
		local c = Vector3.new(a.X, 0, a.Z) + d * t
		local dist = (Vector3.new(pos.X, 0, pos.Z) - c).Magnitude
		if dist < best then
			best = dist
			local L = math.sqrt(L2)
			bs = cum[i] + L * t
			local r = Vector3.new(-d.Z / L, 0, d.X / L)
			bx = (Vector3.new(pos.X, 0, pos.Z) - c):Dot(r)
		end
	end
	return bs, bx, best
end

-- variant index for a set of fork choices (1 = left branch, 2 = right). Unchosen forks default to 1.
function RouteMath:VariantFor(c1: number?, c2: number?): number
	for vi, v in ipairs(self.Variants) do
		if v.Choices[1] == (c1 or 1) and v.Choices[2] == (c2 or 1) then return vi end
	end
	return 1
end

-- S of an indexed table that stores one value per variant (-1 = not on that variant)
function RouteMath.SOn(perVariant, vi: number): number?
	local s = perVariant[vi]
	if s == nil or s < 0 then return nil end
	return s
end

return RouteMath
