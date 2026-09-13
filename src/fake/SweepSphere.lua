local Vector3 = require("./Vector3")
local SweepFrame = require("./SweepFrame")

local EPSILON = SweepFrame.EPSILON
local transposeApply = SweepFrame.transposeApply
local rotationApply = SweepFrame.rotationApply

local SweepSphere = {}

function SweepSphere.sweepSphereVsAABB(origin, direction, half, radius)
	if
		math.abs(origin.X) < half.X
		and math.abs(origin.Y) < half.Y
		and math.abs(origin.Z) < half.Z
	then
		return nil
	end

	local o = { origin.X, origin.Y, origin.Z }
	local d = { direction.X, direction.Y, direction.Z }
	local h = { half.X, half.Y, half.Z }

	local bestT = nil
	local bestNormal = nil
	local bestContact = nil

	local function consider(t, normal, contact)
		if t >= 0 and t <= 1 and (bestT == nil or t < bestT) then
			bestT = t
			bestNormal = normal
			bestContact = contact
		end
	end

	for j = 1, 3 do
		if math.abs(d[j]) > EPSILON then
			local k1 = (j % 3) + 1
			local k2 = ((j + 1) % 3) + 1

			for _, side in ipairs({ 1, -1 }) do
				local plane = side * (h[j] + radius)
				local t = (plane - o[j]) / d[j]

				if t >= 0 and t <= 1 then
					local p1 = o[k1] + d[k1] * t
					local p2 = o[k2] + d[k2] * t

					if math.abs(p1) <= h[k1] + 1e-9 and math.abs(p2) <= h[k2] + 1e-9 then
						local normalParts = { 0, 0, 0 }
						normalParts[j] = side
						local contactParts = { 0, 0, 0 }
						contactParts[j] = side * h[j]
						contactParts[k1] = p1
						contactParts[k2] = p2
						consider(
							t,
							Vector3.new(normalParts[1], normalParts[2], normalParts[3]),
							Vector3.new(contactParts[1], contactParts[2], contactParts[3])
						)
					end
				end
			end
		end
	end

	for j = 1, 3 do
		local k1 = (j % 3) + 1
		local k2 = ((j + 1) % 3) + 1

		for _, s1 in ipairs({ 1, -1 }) do
			for _, s2 in ipairs({ 1, -1 }) do
				local ux = o[k1] - s1 * h[k1]
				local uy = o[k2] - s2 * h[k2]
				local vx = d[k1]
				local vy = d[k2]
				local a = vx * vx + vy * vy

				if a > EPSILON * EPSILON then
					local b = 2 * (ux * vx + uy * vy)
					local c = ux * ux + uy * uy - radius * radius
					local discriminant = b * b - 4 * a * c

					if discriminant >= 0 then
						local root = math.sqrt(discriminant)

						for _, t in ipairs({ (-b - root) / (2 * a), (-b + root) / (2 * a) }) do
							if t >= 0 and t <= 1 then
								local along = o[j] + d[j] * t

								if math.abs(along) <= h[j] + 1e-9 then
									local px = o[k1] + d[k1] * t
									local py = o[k2] + d[k2] * t
									local nx = px - s1 * h[k1]
									local ny = py - s2 * h[k2]
									local length = math.sqrt(nx * nx + ny * ny)

									if length > 1e-9 then
										local normalParts = { 0, 0, 0 }
										normalParts[k1] = nx / length
										normalParts[k2] = ny / length
										local contactParts = { 0, 0, 0 }
										contactParts[j] = along
										contactParts[k1] = s1 * h[k1]
										contactParts[k2] = s2 * h[k2]
										consider(
											t,
											Vector3.new(normalParts[1], normalParts[2], normalParts[3]),
											Vector3.new(contactParts[1], contactParts[2], contactParts[3])
										)
									end
								end
							end
						end
					end
				end
			end
		end
	end

	for _, s1 in ipairs({ 1, -1 }) do
		for _, s2 in ipairs({ 1, -1 }) do
			for _, s3 in ipairs({ 1, -1 }) do
				local corner = { s1 * h[1], s2 * h[2], s3 * h[3] }
				local wx = o[1] - corner[1]
				local wy = o[2] - corner[2]
				local wz = o[3] - corner[3]
				local a = d[1] * d[1] + d[2] * d[2] + d[3] * d[3]

				if a > EPSILON * EPSILON then
					local b = 2 * (wx * d[1] + wy * d[2] + wz * d[3])
					local c = wx * wx + wy * wy + wz * wz - radius * radius
					local discriminant = b * b - 4 * a * c

					if discriminant >= 0 then
						local root = math.sqrt(discriminant)

						for _, t in ipairs({ (-b - root) / (2 * a), (-b + root) / (2 * a) }) do
							if t >= 0 and t <= 1 then
								local px = o[1] + d[1] * t - corner[1]
								local py = o[2] + d[2] * t - corner[2]
								local pz = o[3] + d[3] * t - corner[3]
								local length = math.sqrt(px * px + py * py + pz * pz)

								if length > 1e-9 then
									consider(
										t,
										Vector3.new(px / length, py / length, pz / length),
										Vector3.new(corner[1], corner[2], corner[3])
									)
								end
							end
						end
					end
				end
			end
		end
	end

	if bestT == nil then
		return nil
	end

	return {
		t = bestT,
		normal = bestNormal,
		contact = bestContact,
	}
end

-- Exact box-vs-sphere sweep (engine: Blockcast vs Ball is NOT box-vs-box).
-- Role-swap into the caster's box frame: the box becomes a static AABB at
-- the origin and the sphere moves along -Rᵀ·d, reusing sweepSphereVsAABB.
function SweepSphere.sweepBoxVsSphere(castCenter0, castCols, castHalf, direction, sphereCenter, sphereRadius)
	local rel = transposeApply(castCols, sphereCenter - castCenter0)
	local revDir = transposeApply(castCols, direction) * -1
	local sweep = SweepSphere.sweepSphereVsAABB(rel, revDir, castHalf, sphereRadius)

	if sweep == nil then
		return nil
	end

	local boxContactWorld = castCenter0 + direction * sweep.t + rotationApply(castCols, sweep.contact)
	local offset = boxContactWorld - sphereCenter
	local length = math.sqrt(offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z)

	if length < 1e-9 then
		return nil
	end

	return {
		t = sweep.t,
		normal = offset / length,
		contact = boxContactWorld,
	}
end

local function distPointCylinderX(p, radius, halfLength)
	local ax = math.abs(p.X)
	local radial = math.sqrt(p.Y * p.Y + p.Z * p.Z)

	if ax <= halfLength and radial <= radius then
		return 0, p
	end

	if ax <= halfLength then
		local inv = radius / radial
		return radial - radius, Vector3.new(p.X, p.Y * inv, p.Z * inv)
	end

	local sign = if p.X >= 0 then 1 else -1

	if radial <= radius then
		return ax - halfLength, Vector3.new(sign * halfLength, p.Y, p.Z)
	end

	local dx = ax - halfLength
	local dr = radial - radius
	local inv = radius / radial
	return math.sqrt(dx * dx + dr * dr), Vector3.new(sign * halfLength, p.Y * inv, p.Z * inv)
end

-- Exact sphere-vs-cylinder sweep, cylinder axis X centered at origin.
-- Uses convex distance (ternary + bisection); sweeps include t=1, and a
-- center starting inside the cylinder misses like box initial overlap.
function SweepSphere.sweepSphereVsCylinderX(origin, direction, radius, halfLength, movingRadius)
	local radialSq = origin.Y * origin.Y + origin.Z * origin.Z

	if math.abs(origin.X) < halfLength and radialSq < radius * radius then
		return nil
	end

	local function distAt(t)
		local p = origin + direction * t
		local dist, _ = distPointCylinderX(p, radius, halfLength)
		return dist
	end

	local d0 = distAt(0)

	if d0 <= movingRadius then
		local p0 = origin
		local _, closest = distPointCylinderX(p0, radius, halfLength)
		local offset = p0 - closest
		local length = math.sqrt(offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z)

		if length < 1e-9 then
			return nil
		end

		return {
			t = 0,
			normal = offset / length,
			contact = closest,
		}
	end

	local lo, hi = 0, 1

	for _ = 1, 60 do
		local m1 = lo + (hi - lo) / 3
		local m2 = hi - (hi - lo) / 3

		if distAt(m1) > distAt(m2) then
			lo = m1
		else
			hi = m2
		end
	end

	local tMin = (lo + hi) / 2

	if distAt(tMin) > movingRadius then
		return nil
	end

	local entryLo, entryHi = 0, tMin

	for _ = 1, 60 do
		local mid = (entryLo + entryHi) / 2

		if distAt(mid) <= movingRadius then
			entryHi = mid
		else
			entryLo = mid
		end
	end

	local pHit = origin + direction * entryHi
	local _, closest = distPointCylinderX(pHit, radius, halfLength)
	local offset = pHit - closest
	local length = math.sqrt(offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z)

	if length < 1e-9 then
		return nil
	end

	return {
		t = entryHi,
		normal = offset / length,
		contact = closest,
	}
end

local function clampNum(v, lo, hi)
	if v < lo then
		return lo
	end
	if v > hi then
		return hi
	end
	return v
end

local function distPointWedge(p, hx, hy, hz)
	local qx = clampNum(p.X, -hx, hx)
	local qy = clampNum(p.Y, -hy, hy)
	local qz = clampNum(p.Z, -hz, hz)
	local inHalf = p.Y * hz - p.Z * hy <= 0

	if inHalf then
		local q = Vector3.new(qx, qy, qz)
		local off = p - q
		return math.sqrt(off.X * off.X + off.Y * off.Y + off.Z * off.Z), q
	end

	local cx = clampNum(p.X, -hx, hx)
	local denom = hy * hy + hz * hz
	local t = 0
	if denom > 1e-12 then
		t = clampNum((p.Y * hy + p.Z * hz) / denom, -1, 1)
	end
	local q = Vector3.new(cx, t * hy, t * hz)
	local off = p - q
	return math.sqrt(off.X * off.X + off.Y * off.Y + off.Z * off.Z), q
end

local function distPointCorner(p, hx, hy, hz)
	local q = Vector3.new(clampNum(p.X, -hx, hx), clampNum(p.Y, -hy, hy), clampNum(p.Z, -hz, hz))
	local c1 = p.Y * hx - p.X * hy <= 0
	local c2 = p.Y * hz + p.Z * hy <= 0

	if c1 and c2 then
		local off = p - q
		return math.sqrt(off.X * off.X + off.Y * off.Y + off.Z * off.Z), q
	end

	local bestDist, bestQ = nil, nil
	local function consider(qc)
		local off = p - qc
		local d = math.sqrt(off.X * off.X + off.Y * off.Y + off.Z * off.Z)
		if bestDist == nil or d < bestDist then
			bestDist = qc and d or d
			bestQ = qc
		end
	end

	if not c1 and c2 then
		local a = hy / hx
		local x = (p.X + a * p.Y) / (1 + a * a)
		x = clampNum(x, -hx, hx)
		consider(Vector3.new(x, x * a, clampNum(p.Z, -hz, hz)))
	elseif c1 and not c2 then
		local b = hy / hz
		local z = (p.Z - b * p.Y) / (1 + b * b)
		z = clampNum(z, -hz, hz)
		consider(Vector3.new(clampNum(p.X, -hx, hx), -b * z, z))
	else
		local dir = Vector3.new(hx, hy, -hz)
		local lenSq = dir.X * dir.X + dir.Y * dir.Y + dir.Z * dir.Z
		local t = 0
		if lenSq > 1e-12 then
			t = clampNum((p.X * dir.X + p.Y * dir.Y + p.Z * dir.Z) / lenSq, -1, 1)
		end
		consider(dir * t)
		local a = hy / hx
		local x = clampNum((p.X + a * p.Y) / (1 + a * a), -hx, hx)
		local q1 = Vector3.new(x, x * a, clampNum(p.Z, -hz, hz))
		if q1.Y * hz + q1.Z * hy <= 1e-9 then
			consider(q1)
		end
		local b = hy / hz
		local z2 = clampNum((p.Z - b * p.Y) / (1 + b * b), -hz, hz)
		local q2 = Vector3.new(clampNum(p.X, -hx, hx), -b * z2, z2)
		if q2.Y * hx - q2.X * hy <= 1e-9 then
			consider(q2)
		end
	end

	return bestDist, bestQ
end

local function sweepSphereVsConvex(origin, direction, movingRadius, insideFn, distFn)
	if insideFn(origin) then
		return nil
	end

	local function distAt(t)
		local d, _ = distFn(origin + direction * t)
		return d
	end

	local d0 = distAt(0)
	if d0 <= movingRadius then
		local _, closest = distFn(origin)
		local off = origin - closest
		local len = math.sqrt(off.X * off.X + off.Y * off.Y + off.Z * off.Z)
		if len < 1e-9 then
			return nil
		end
		return { t = 0, normal = off / len, contact = closest }
	end

	local lo, hi = 0, 1
	for _ = 1, 60 do
		local m1 = lo + (hi - lo) / 3
		local m2 = hi - (hi - lo) / 3
		if distAt(m1) > distAt(m2) then
			lo = m1
		else
			hi = m2
		end
	end
	local tMin = (lo + hi) / 2
	if distAt(tMin) > movingRadius then
		return nil
	end

	local eLo, eHi = 0, tMin
	for _ = 1, 60 do
		local mid = (eLo + eHi) / 2
		if distAt(mid) <= movingRadius then
			eHi = mid
		else
			eLo = mid
		end
	end

	local _, closest = distFn(origin + direction * eHi)
	local off = (origin + direction * eHi) - closest
	local len = math.sqrt(off.X * off.X + off.Y * off.Y + off.Z * off.Z)
	if len < 1e-9 then
		return nil
	end
	return { t = eHi, normal = off / len, contact = closest }
end

function SweepSphere.sweepSphereVsWedge(origin, direction, hx, hy, hz, movingRadius)
	return sweepSphereVsConvex(origin, direction, movingRadius, function(p)
		return math.abs(p.X) < hx and math.abs(p.Y) < hy and math.abs(p.Z) < hz
			and p.Y * hz - p.Z * hy < 0
	end, function(p)
		return distPointWedge(p, hx, hy, hz)
	end)
end

function SweepSphere.sweepSphereVsCorner(origin, direction, hx, hy, hz, movingRadius)
	return sweepSphereVsConvex(origin, direction, movingRadius, function(p)
		return math.abs(p.X) < hx and math.abs(p.Y) < hy and math.abs(p.Z) < hz
			and p.Y * hx - p.X * hy < 0 and p.Y * hz + p.Z * hy < 0
	end, function(p)
		return distPointCorner(p, hx, hy, hz)
	end)
end

-- Wedge/corner caster vs sphere target via role-swap (static wedge, moving
-- sphere). Returns t, target (sphere) normal, world contact like box-vs-sphere.
function SweepSphere.sweepWedgeVsSphere(
	castCenter0,
	castCols,
	hx,
	hy,
	hz,
	isCorner,
	direction,
	sphereCenter,
	sphereRadius
)
	local rel = transposeApply(castCols, sphereCenter - castCenter0)
	local revDir = transposeApply(castCols, direction) * -1
	local sweep
	if isCorner then
		sweep = SweepSphere.sweepSphereVsCorner(rel, revDir, hx, hy, hz, sphereRadius)
	else
		sweep = SweepSphere.sweepSphereVsWedge(rel, revDir, hx, hy, hz, sphereRadius)
	end
	if sweep == nil then
		return nil
	end
	local contactWorld = castCenter0 + direction * sweep.t + rotationApply(castCols, sweep.contact)
	local off = contactWorld - sphereCenter
	local len = math.sqrt(off.X * off.X + off.Y * off.Y + off.Z * off.Z)
	if len < 1e-9 then
		return nil
	end
	return { t = sweep.t, normal = off / len, contact = contactWorld }
end

return SweepSphere
