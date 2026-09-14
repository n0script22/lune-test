local Vector3 = require("./Vector3")
local SweepFrame = require("./SweepFrame")

local dot3 = SweepFrame.dot3
local rotationApply = SweepFrame.rotationApply
local SAT_OVERLAP_EPS = SweepFrame.SAT_OVERLAP_EPS

local SweepConvex = {}

local CYLINDER_PRISM_SIDES = 32

local function buildConvex(center, cols, localVerts, localNormals, localDirs)
	local verts = {}
	for _, v in ipairs(localVerts) do
		table.insert(verts, center + rotationApply(cols, v))
	end

	local normals = {}
	for _, n in ipairs(localNormals) do
		local wn = rotationApply(cols, n)
		local len = math.sqrt(wn.X * wn.X + wn.Y * wn.Y + wn.Z * wn.Z)
		if len > 1e-12 then
			table.insert(normals, wn / len)
		end
	end

	local edges = {}
	for _, e in ipairs(localDirs) do
		local we = rotationApply(cols, e)
		local len = math.sqrt(we.X * we.X + we.Y * we.Y + we.Z * we.Z)
		if len > 1e-12 then
			table.insert(edges, we / len)
		end
	end

	return {
		center = center,
		verts = verts,
		normals = normals,
		edges = edges,
	}
end

function SweepConvex.boxConvex(center, cols, half)
	local hx, hy, hz = half.X, half.Y, half.Z
	local verts = {}
	for _, sx in ipairs({ 1, -1 }) do
		for _, sy in ipairs({ 1, -1 }) do
			for _, sz in ipairs({ 1, -1 }) do
				table.insert(verts, Vector3.new(sx * hx, sy * hy, sz * hz))
			end
		end
	end
	return buildConvex(center, cols, verts, {
		Vector3.new(1, 0, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, 0, 1),
	}, {
		Vector3.new(1, 0, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, 0, 1),
	})
end

function SweepConvex.wedgeConvex(center, cols, hx, hy, hz)
	local slopeLen = math.sqrt(hz * hz + hy * hy)
	local diagLen = slopeLen
	if diagLen < 1e-12 then
		diagLen = 1
	end
	return buildConvex(center, cols, {
		Vector3.new(-hx, -hy, -hz),
		Vector3.new(hx, -hy, -hz),
		Vector3.new(hx, -hy, hz),
		Vector3.new(-hx, -hy, hz),
		Vector3.new(-hx, hy, hz),
		Vector3.new(hx, hy, hz),
	}, {
		Vector3.new(0, -1, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, hz / slopeLen, -hy / slopeLen),
		Vector3.new(1, 0, 0),
	}, {
		Vector3.new(1, 0, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, hy / diagLen, hz / diagLen),
	})
end

function SweepConvex.cornerConvex(center, cols, hx, hy, hz)
	local s1Len = math.sqrt(hy * hy + hx * hx)
	local s2Len = math.sqrt(hz * hz + hy * hy)
	if s1Len < 1e-12 then
		s1Len = 1
	end
	if s2Len < 1e-12 then
		s2Len = 1
	end
	local d1Len = math.sqrt(hx * hx + hy * hy)
	local d2Len = math.sqrt(hy * hy + hz * hz)
	local d3Len = math.sqrt(hx * hx + hy * hy + hz * hz)
	if d1Len < 1e-12 then
		d1Len = 1
	end
	if d2Len < 1e-12 then
		d2Len = 1
	end
	if d3Len < 1e-12 then
		d3Len = 1
	end
	return buildConvex(center, cols, {
		Vector3.new(-hx, -hy, -hz),
		Vector3.new(hx, -hy, -hz),
		Vector3.new(hx, -hy, hz),
		Vector3.new(-hx, -hy, hz),
		Vector3.new(hx, hy, -hz),
	}, {
		Vector3.new(0, -1, 0),
		Vector3.new(0, 0, -1),
		Vector3.new(1, 0, 0),
		Vector3.new(hy / s1Len, -hx / s1Len, 0),
		Vector3.new(0, hz / s2Len, hy / s2Len),
	}, {
		Vector3.new(1, 0, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(hx / d1Len, hy / d1Len, 0),
		Vector3.new(0, hy / d2Len, -hz / d2Len),
		Vector3.new(hx / d3Len, hy / d3Len, -hz / d3Len),
	})
end

function SweepConvex.prismConvex(center, cols, radius, halfLength, sides)
	local n = sides or CYLINDER_PRISM_SIDES
	local verts = {}
	for i = 0, n - 1 do
		local angle = 2 * math.pi * i / n
		local y = radius * math.cos(angle)
		local z = radius * math.sin(angle)
		table.insert(verts, Vector3.new(halfLength, y, z))
		table.insert(verts, Vector3.new(-halfLength, y, z))
	end
	local normals = { Vector3.new(1, 0, 0) }
	local edges = { Vector3.new(1, 0, 0) }
	for i = 0, n - 1 do
		local angle = 2 * math.pi * i / n
		table.insert(normals, Vector3.new(0, math.cos(angle), math.sin(angle)))
		table.insert(edges, Vector3.new(0, -math.sin(angle), math.cos(angle)))
	end
	return buildConvex(center, cols, verts, normals, edges)
end

-- Generic swept SAT for two convex polyhedra. Returns t, normal (target
-- outward) or nil. Uses true min/max intervals (not symmetric extents) so
-- asymmetric shapes like wedges separate correctly. Mirrors sweepBoxVsBox
-- semantics (initial overlap and t>1 miss, sweeps include t=1).
function SweepConvex.sweepConvexVsConvex(caster, direction, target)
	local axes = {}

	for _, n in ipairs(caster.normals) do
		table.insert(axes, n)
	end
	for _, n in ipairs(target.normals) do
		table.insert(axes, n)
	end
	for _, e1 in ipairs(caster.edges) do
		for _, e2 in ipairs(target.edges) do
			local cross = e1:Cross(e2)
			if cross.Magnitude > 1e-8 then
				table.insert(axes, cross / cross.Magnitude)
			end
		end
	end

	local function intervalOf(convex, axis)
		local lo, hi = nil, nil
		for _, v in ipairs(convex.verts) do
			local proj = dot3(v, axis)
			if lo == nil or proj < lo then
				lo = proj
			end
			if hi == nil or proj > hi then
				hi = proj
			end
		end
		return lo, hi
	end

	local bestT = 0
	local bestNormal = nil
	local allOverlapping = true

	for _, axis in ipairs(axes) do
		local cMin, cMax = intervalOf(caster, axis)
		local tMin, tMax = intervalOf(target, axis)
		local vel = dot3(direction, axis)

		if cMax < tMin - SAT_OVERLAP_EPS or tMax < cMin - SAT_OVERLAP_EPS then
			allOverlapping = false
		end

		if cMax < tMin then
			if vel <= 0 then
				return nil
			end
			local enterT = (tMin - cMax) / vel
			if enterT > bestT then
				bestT = enterT
				bestNormal = -axis
			end
		elseif tMax < cMin then
			if vel >= 0 then
				return nil
			end
			local enterT = (tMax - cMin) / vel
			if enterT > bestT then
				bestT = enterT
				bestNormal = axis
			end
		end
	end

	if allOverlapping then
		return nil
	end
	-- Engine (verified against Studio): sweeps count exact-touch (t = 1) as
	-- hits, including against union decomposition geometry, whose
	-- triangulation-diagonal edge axes can push bestT a dust above 1.
	if bestT > 1 + 1e-9 then
		return nil
	end
	if bestT > 1 then
		bestT = 1
	end
	if bestNormal == nil then
		bestNormal = target.normals[1]
		if bestNormal == nil then
			bestNormal = caster.normals[1]
		end
	end

	return bestT, bestNormal
end

-- Exact-ish box-vs-cylinder sweep (engine: Blockcast vs Cylinder is NOT
-- box-vs-box). Cylinder approximated as a 32-gon prism (apothem error
-- ~0.005 at r=1). Returns t, normal.
function SweepConvex.sweepBoxVsCylinder(
	castCenter0,
	castCols,
	castHalf,
	direction,
	cylCenter,
	cylCols,
	cylRadius,
	cylHalfLength
)
	local caster = SweepConvex.boxConvex(castCenter0, castCols, castHalf)
	local target = SweepConvex.prismConvex(cylCenter, cylCols, cylRadius, cylHalfLength)
	return SweepConvex.sweepConvexVsConvex(caster, direction, target)
end

return SweepConvex
