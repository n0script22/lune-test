local Vector3 = require("./Vector3")

local ShapeIntersect = {}

local EPSILON = 1e-8

local function dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end

local function sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

local function cross(a, b)
	return Vector3.new(
		a.Y * b.Z - a.Z * b.Y,
		a.Z * b.X - a.X * b.Z,
		a.X * b.Y - a.Y * b.X
	)
end

function ShapeIntersect.raySphere(origin, direction, radius)
	local a = dot(direction, direction)

	if a <= EPSILON * EPSILON then
		return nil
	end

	local ox, oy, oz = origin.X, origin.Y, origin.Z
	local b = 2 * (ox * direction.X + oy * direction.Y + oz * direction.Z)
	local c = ox * ox + oy * oy + oz * oz - radius * radius

	-- Origin strictly inside the sphere: engine passes through (miss),
	-- matching the box inside-origin rule. On-surface origins still hit.
	if c < 0 then
		return nil
	end

	local discriminant = b * b - 4 * a * c

	if discriminant < 0 then
		return nil
	end

	local root = math.sqrt(discriminant)
	local t0 = (-b - root) / (2 * a)
	local t1 = (-b + root) / (2 * a)

	local t = nil

	if t0 >= 0 and t0 <= 1 then
		t = t0
	elseif t1 >= 0 and t1 <= 1 and t0 < 0 then
		t = 0
		return {
			t = 0,
			position = origin,
			normal = Vector3.new(
				-direction.X / math.sqrt(a),
				-direction.Y / math.sqrt(a),
				-direction.Z / math.sqrt(a)
			),
		}
	end

	if t == nil then
		return nil
	end

	local position = origin + direction * t
	local nLength = math.sqrt(position.X * position.X + position.Y * position.Y + position.Z * position.Z)

	if nLength < 1e-9 then
		return nil
	end

	return {
		t = t,
		position = position,
		normal = position / nLength,
	}
end

-- Engine cylinder (verified against Studio): axis is local X with length
-- Size.X; circular cross-section in YZ with radius min(Size.Y, Size.Z)/2.
function ShapeIntersect.rayCylinderX(origin, direction, radius, halfLength)
	local bestT = nil
	local bestNormal = nil

	-- Origin strictly inside the cylinder: engine passes through (miss).
	local radialSq = origin.Y * origin.Y + origin.Z * origin.Z

	if math.abs(origin.X) < halfLength and radialSq < radius * radius then
		return nil
	end

	-- Side surface: y^2 + z^2 = r^2.
	local a = direction.Y * direction.Y + direction.Z * direction.Z

	if a > EPSILON * EPSILON then
		local b = 2 * (origin.Y * direction.Y + origin.Z * direction.Z)
		local c = radialSq - radius * radius
		local discriminant = b * b - 4 * a * c

		if discriminant >= 0 then
			local root = math.sqrt(discriminant)

			for _, t in ipairs({ (-b - root) / (2 * a), (-b + root) / (2 * a) }) do
				if t >= 0 and t <= 1 and (bestT == nil or t < bestT) then
					local x = origin.X + direction.X * t

					if math.abs(x) <= halfLength + 1e-9 then
						local ny = origin.Y + direction.Y * t
						local nz = origin.Z + direction.Z * t
						local nLen = math.sqrt(ny * ny + nz * nz)

						if nLen > 1e-9 then
							bestT = t
							bestNormal = Vector3.new(0, ny / nLen, nz / nLen)
						end
					end
				end
			end
		end
	end

	-- Caps: x = +/- halfLength.
	if math.abs(direction.X) > EPSILON then
		for _, side in ipairs({ 1, -1 }) do
			local planeX = side * halfLength
			local t = (planeX - origin.X) / direction.X

			if t >= 0 and t <= 1 and (bestT == nil or t < bestT) then
				local y = origin.Y + direction.Y * t
				local z = origin.Z + direction.Z * t

				if y * y + z * z <= radius * radius + 1e-9 then
					bestT = t
					bestNormal = Vector3.new(side, 0, 0)
				end
			end
		end
	end

	if bestT == nil or bestNormal == nil then
		return nil
	end

	return {
		t = bestT,
		position = origin + direction * bestT,
		normal = bestNormal,
	}
end

local function rayTriangle(origin, direction, a, b, c)
	local edge1 = sub(b, a)
	local edge2 = sub(c, a)
	local h = cross(direction, edge2)
	local det = dot(edge1, h)

	if math.abs(det) < 1e-12 then
		return nil
	end

	local invDet = 1 / det
	local s = sub(origin, a)
	local u = dot(s, h) * invDet

	if u < -1e-9 or u > 1 + 1e-9 then
		return nil
	end

	local q = cross(s, edge1)
	local v = dot(direction, q) * invDet

	if v < -1e-9 or u + v > 1 + 1e-9 then
		return nil
	end

	local t = dot(edge2, q) * invDet

	if t < 0 or t > 1 then
		return nil
	end

	local n = cross(edge1, edge2)
	local nLen = math.sqrt(dot(n, n))

	if nLen < 1e-12 then
		return nil
	end

	n = n / nLen

	-- Orient normal against the ray (entering face).
	if dot(n, direction) > 0 then
		n = Vector3.new(-n.X, -n.Y, -n.Z)
	end

	return t, n
end

-- Engine wedge (verified against Studio): tall face at +Z spanning full
-- height, tapering to the -Z bottom edge. Solid is y <= z in local units.
local function wedgeTriangles(hx, hy, hz)
	-- Corners
	local b0 = Vector3.new(-hx, -hy, -hz)
	local b1 = Vector3.new(hx, -hy, -hz)
	local b2 = Vector3.new(hx, -hy, hz)
	local b3 = Vector3.new(-hx, -hy, hz)
	local t2 = Vector3.new(-hx, hy, hz)
	local t3 = Vector3.new(hx, hy, hz)

	return {
		-- Bottom (y=-hy)
		{ b0, b1, b2 },
		{ b0, b2, b3 },
		-- Tall face (z=+hz)
		{ b3, b2, t3 },
		{ b3, t3, t2 },
		-- Slope (top-front edge to bottom-back edge)
		{ t2, t3, b1 },
		{ t2, b1, b0 },
		-- Left (x=-hx)
		{ b0, t2, b3 },
		-- Right (x=hx)
		{ b1, b2, t3 },
	}
end

-- Engine corner wedge (verified against Studio): bottom is a full quad,
-- top surface is y <= min(x, -z) in local units — high at the (+X, -Z) top
-- corner, sloping down toward -X and toward +Z.
local function cornerTriangles(hx, hy, hz)
	local b0 = Vector3.new(-hx, -hy, -hz)
	local b1 = Vector3.new(hx, -hy, -hz)
	local b2 = Vector3.new(hx, -hy, hz)
	local b3 = Vector3.new(-hx, -hy, hz)
	local apex = Vector3.new(hx, hy, -hz)

	return {
		-- Bottom (y=-hy)
		{ b0, b1, b2 },
		{ b0, b2, b3 },
		-- Back (z=-hz)
		{ b0, b1, apex },
		-- Right (x=hx)
		{ b1, b2, apex },
		-- Slope y=x
		{ b0, apex, b3 },
		-- Slope y=-z
		{ apex, b2, b3 },
	}
end

function ShapeIntersect.rayWedge(origin, direction, hx, hy, hz)
	-- Origin strictly inside the solid: engine passes through (miss).
	if math.abs(origin.X) < hx and math.abs(origin.Y) < hy and math.abs(origin.Z) < hz
		and origin.Y * hz < origin.Z * hy
	then
		return nil
	end

	local bestT = nil
	local bestNormal = nil

	for _, tri in ipairs(wedgeTriangles(hx, hy, hz)) do
		local t, n = rayTriangle(origin, direction, tri[1], tri[2], tri[3])

		if t ~= nil and (bestT == nil or t < bestT) then
			bestT = t
			bestNormal = n
		end
	end

	if bestT == nil or bestNormal == nil then
		return nil
	end

	return {
		t = bestT,
		position = origin + direction * bestT,
		normal = bestNormal,
	}
end

function ShapeIntersect.rayCornerWedge(origin, direction, hx, hy, hz)
	-- Origin strictly inside the solid: engine passes through (miss).
	if math.abs(origin.X) < hx and math.abs(origin.Y) < hy and math.abs(origin.Z) < hz
		and origin.Y < origin.X * hy / hx and origin.Y < -origin.Z * hy / hz
	then
		return nil
	end

	local bestT = nil
	local bestNormal = nil

	for _, tri in ipairs(cornerTriangles(hx, hy, hz)) do
		local t, n = rayTriangle(origin, direction, tri[1], tri[2], tri[3])

		if t ~= nil and (bestT == nil or t < bestT) then
			bestT = t
			bestNormal = n
		end
	end

	if bestT == nil or bestNormal == nil then
		return nil
	end

	return {
		t = bestT,
		position = origin + direction * bestT,
		normal = bestNormal,
	}
end

function ShapeIntersect.sweepSphereVsSphere(originRelative, direction, targetRadius, movingRadius)
	local combined = targetRadius + movingRadius
	local distSq = dot(originRelative, originRelative)

	-- Center starts inside target: ignored like box initial overlap.
	if distSq < targetRadius * targetRadius then
		return nil
	end

	local dist = math.sqrt(distSq)

	if dist <= combined then
		-- Already overlapping at t=0 but center outside target: contact now.
		if dist < 1e-9 then
			return nil
		end

		local normal = originRelative / dist
		return {
			t = 0,
			normal = normal,
			contact = normal * targetRadius,
		}
	end

	local hit = ShapeIntersect.raySphere(originRelative, direction, combined)

	if hit == nil then
		return nil
	end

	local movingCenter = originRelative + direction * hit.t
	local nLen = math.sqrt(dot(movingCenter, movingCenter))

	if nLen < 1e-9 then
		return nil
	end

	local normal = movingCenter / nLen

	return {
		t = hit.t,
		normal = normal,
		contact = normal * targetRadius,
	}
end

return ShapeIntersect
