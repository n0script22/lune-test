local ShapeIntersect = require("./ShapeIntersect")
local SweepFrame = require("./SweepFrame")
local Vector3 = require("./Vector3")

local ConvexDecomp = {}

local HULL_EPS = 1e-9
local INSIDE_EPS = 1e-7

local BALL_SIDES = 10
local BALL_BANDS = 5
local CYLINDER_SIDES = 12

local rotationApply = SweepFrame.rotationApply

-- A local convex is { verts: {Vector3}, faces: {{i, j, k}} } centered on the
-- part origin (1-indexed, counter-clockwise when viewed from outside).
-- withPlanes adds { normals, edges }; toWorld adds { center } and converts to
-- the SweepConvex-compatible world format (extra `faces` field is ignored by
-- the existing sweepers).

local function quantKey(x: number): string
	return tostring(math.floor(x * 1e6 + 0.5))
end

local function vertKey(v): string
	return quantKey(v.X) .. "," .. quantKey(v.Y) .. "," .. quantKey(v.Z)
end

local function dirKey(v): string
	local x, y, z = v.X, v.Y, v.Z

	if x < -1e-12
		or (math.abs(x) <= 1e-12 and y < -1e-12)
		or (math.abs(x) <= 1e-12 and math.abs(y) <= 1e-12 and z < 0)
	then
		x, y, z = -x, -y, -z
	end

	return quantKey(x) .. "," .. quantKey(y) .. "," .. quantKey(z)
end

local function faceUnit(verts, face)
	local n = (verts[face[2]] - verts[face[1]]):Cross(verts[face[3]] - verts[face[1]])
	local len = n.Magnitude

	if len <= 1e-12 then
		return nil
	end

	return n / len
end

local function orientOutward(verts, face, interior)
	local n = (verts[face[2]] - verts[face[1]]):Cross(verts[face[3]] - verts[face[1]])

	if n:Dot(interior - verts[face[1]]) > 0 then
		face[2], face[3] = face[3], face[2]
	end
end

-- Triangular QuickHull over an already-deduplicated volumetric point cloud.
function ConvexDecomp.convexHull(points)
	local verts = {}
	local seen = {}

	for _, p in ipairs(points) do
		local key = vertKey(p)

		if not seen[key] then
			seen[key] = true
			table.insert(verts, p)
		end
	end

	assert(#verts >= 4, "ConvexDecomp.convexHull requires at least 4 points")

	local minX, maxX, minY, maxY, minZ, maxZ = 1, 1, 1, 1, 1, 1

	for i, p in ipairs(verts) do
		if p.X < verts[minX].X then
			minX = i
		end
		if p.X > verts[maxX].X then
			maxX = i
		end
		if p.Y < verts[minY].Y then
			minY = i
		end
		if p.Y > verts[maxY].Y then
			maxY = i
		end
		if p.Z < verts[minZ].Z then
			minZ = i
		end
		if p.Z > verts[maxZ].Z then
			maxZ = i
		end
	end

	local extremes = { minX, maxX, minY, maxY, minZ, maxZ }
	local i0, i1 = extremes[1], extremes[2]
	local bestPair = -1

	for a = 1, #extremes do
		for b = a + 1, #extremes do
			local d = (verts[extremes[a]] - verts[extremes[b]]).Magnitude

			if d > bestPair then
				bestPair = d
				i0, i1 = extremes[a], extremes[b]
			end
		end
	end

	assert(bestPair > HULL_EPS, "ConvexDecomp.convexHull requires volumetric input")

	local lineUnit = (verts[i1] - verts[i0]) / bestPair
	local i2 = nil
	local bestLine = HULL_EPS

	for i, p in ipairs(verts) do
		if i ~= i0 and i ~= i1 then
			local d = (p - verts[i0]):Cross(lineUnit).Magnitude

			if d > bestLine then
				bestLine = d
				i2 = i
			end
		end
	end

	assert(i2 ~= nil, "ConvexDecomp.convexHull requires volumetric input")

	local planeNormal = (verts[i1] - verts[i0]):Cross(verts[i2] - verts[i0])
	local planeLen = planeNormal.Magnitude
	assert(planeLen > 1e-12, "ConvexDecomp.convexHull requires volumetric input")
	local planeUnit = planeNormal / planeLen
	local i3 = nil
	local bestPlane = HULL_EPS

	for i, p in ipairs(verts) do
		if i ~= i0 and i ~= i1 and i ~= i2 then
			local d = math.abs(planeUnit:Dot(p - verts[i0]))

			if d > bestPlane then
				bestPlane = d
				i3 = i
			end
		end
	end

	assert(i3 ~= nil, "ConvexDecomp.convexHull requires volumetric input")

	local interior = (verts[i0] + verts[i1] + verts[i2] + verts[i3]) / 4
	local faces = { { i0, i1, i2 }, { i0, i3, i1 }, { i0, i2, i3 }, { i1, i3, i2 } }
	local faceCount = 4

	for _, f in ipairs(faces) do
		orientOutward(verts, f, interior)
	end

	local function distToFace(face, p): number
		local unit = faceUnit(verts, face)

		if unit == nil then
			return -1
		end

		return unit:Dot(p - verts[face[1]])
	end

	local outside = {}

	local function assignPoint(pi)
		local p = verts[pi]

		for idx = 1, faceCount do
			local f = faces[idx]

			if f ~= false and distToFace(f, p) > HULL_EPS then
				outside[idx] = outside[idx] or {}
				table.insert(outside[idx], pi)
				return
			end
		end
	end

	for pi, _ in ipairs(verts) do
		if pi ~= i0 and pi ~= i1 and pi ~= i2 and pi ~= i3 then
			assignPoint(pi)
		end
	end

	local guard = #verts * #verts + 100

	while guard > 0 do
		local workFace = nil

		for idx, set in pairs(outside) do
			if #set > 0 then
				workFace = idx
				break
			end
		end

		if workFace == nil then
			break
		end

		guard -= 1
		-- NOTE: do not clear outside[workFace] here. The apex search below
		-- only consumes the furthest point; the remaining members must be
		-- re-homed as orphans. Since the apex is strictly outside workFace,
		-- workFace is always in the visible set, whose loop clears it.
		local set = outside[workFace]

		local apex = nil
		local bestApex = HULL_EPS

		for _, pi in ipairs(set) do
			local d = distToFace(faces[workFace], verts[pi])

			if d > bestApex then
				bestApex = d
				apex = pi
			end
		end

		-- No strict outsider: the set held only boundary points, so the face
		-- is final and its riders are inside the hull. Drop them.
		if apex == nil then
			outside[workFace] = nil
		else
			local apexPoint = verts[apex]
			local visible = {}

			for idx = 1, faceCount do
				local f = faces[idx]

				if f ~= false and distToFace(f, apexPoint) > HULL_EPS then
					visible[idx] = true
				end
			end

			local directed = {}

			for idx in pairs(visible) do
				local f = faces[idx]

				for k = 1, 3 do
					directed[f[k] .. ">" .. f[k % 3 + 1]] = true
				end
			end

			local horizon = {}

			for key in pairs(directed) do
				local u, v = key:match("^(%d+)>(%d+)$")
				u, v = tonumber(u), tonumber(v)

				if not directed[v .. ">" .. u] then
					table.insert(horizon, { u, v })
				end
			end

			local orphans = {}

			for idx in pairs(visible) do
				local subset = outside[idx]

				if subset ~= nil then
					for _, pi in ipairs(subset) do
						if pi ~= apex then
							table.insert(orphans, pi)
						end
					end

					outside[idx] = nil
				end

				faces[idx] = false
			end

			for _, h in ipairs(horizon) do
				-- (u, v) is directed as wound in the removed visible face,
				-- whose invisible neighbor winds it (v, u). Winding the new
				-- triangle (u, v, apex) therefore stitches outward by
				-- induction, with no reference point needed.
				local nf = { h[1], h[2], apex }
				faceCount += 1
				faces[faceCount] = nf
			end

			-- Orphans may be outside surviving invisible faces too, not just
			-- the new cones, so scan every live face.
			for _, pi in ipairs(orphans) do
				assignPoint(pi)
			end
		end
	end

	assert(guard > 0, "ConvexDecomp.convexHull failed to converge")

	local compact = {}

	for idx = 1, faceCount do
		if faces[idx] ~= false then
			table.insert(compact, faces[idx])
		end
	end

	return { verts = verts, faces = compact }
end

-- Exact local triangulation of a Part shape at the given full size, centered
-- on the origin. Ball/Cylinder use the same conventions as the query modules
-- (Ball radius min(Size)/2, Cylinder X-axis length Size.X); tessellation is an
-- approximation like the engine's own convex decomposition.
function ConvexDecomp.primitiveLocal(shape: string, size)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2

	if shape == "Ball" then
		local r = math.min(size.X, size.Y, size.Z) / 2
		local points = {
			Vector3.new(r, 0, 0),
			Vector3.new(-r, 0, 0),
			Vector3.new(0, r, 0),
			Vector3.new(0, -r, 0),
			Vector3.new(0, 0, r),
			Vector3.new(0, 0, -r),
		}

		for i = 1, BALL_BANDS - 1 do
			local theta = math.pi * i / BALL_BANDS
			local y = r * math.cos(theta)
			local ring = r * math.sin(theta)

			for j = 0, BALL_SIDES - 1 do
				local phi = 2 * math.pi * j / BALL_SIDES
				table.insert(points, Vector3.new(ring * math.cos(phi), y, ring * math.sin(phi)))
			end
		end

		return ConvexDecomp.convexHull(points)
	elseif shape == "Cylinder" then
		local r = math.min(size.Y, size.Z) / 2
		local h = size.X / 2
		local points = {}

		for _, sx in ipairs({ h, -h }) do
			for j = 0, CYLINDER_SIDES - 1 do
				local angle = 2 * math.pi * j / CYLINDER_SIDES
				table.insert(points, Vector3.new(sx, r * math.cos(angle), r * math.sin(angle)))
			end
		end

		return ConvexDecomp.convexHull(points)
	elseif shape == "Wedge" then
		return ConvexDecomp.convexHull({
			Vector3.new(-hx, -hy, -hz),
			Vector3.new(hx, -hy, -hz),
			Vector3.new(hx, -hy, hz),
			Vector3.new(-hx, -hy, hz),
			Vector3.new(-hx, hy, hz),
			Vector3.new(hx, hy, hz),
		})
	elseif shape == "CornerWedge" then
		return ConvexDecomp.convexHull({
			Vector3.new(-hx, -hy, -hz),
			Vector3.new(hx, -hy, -hz),
			Vector3.new(hx, -hy, hz),
			Vector3.new(-hx, -hy, hz),
			Vector3.new(hx, hy, -hz),
		})
	else
		return ConvexDecomp.convexHull({
			Vector3.new(-hx, -hy, -hz),
			Vector3.new(hx, -hy, -hz),
			Vector3.new(hx, -hy, hz),
			Vector3.new(-hx, -hy, hz),
			Vector3.new(-hx, hy, -hz),
			Vector3.new(hx, hy, -hz),
			Vector3.new(hx, hy, hz),
			Vector3.new(-hx, hy, hz),
		})
	end
end

-- Adds per-face unit normals and deduplicated edge directions (same frame).
function ConvexDecomp.withPlanes(convex)
	local normals = {}

	for _, f in ipairs(convex.faces) do
		local unit = faceUnit(convex.verts, f)

		if unit ~= nil then
			table.insert(normals, unit)
		end
	end

	local edges = {}
	local seen = {}

	for _, f in ipairs(convex.faces) do
		for k = 1, 3 do
			local e = convex.verts[f[k % 3 + 1]] - convex.verts[f[k]]
			local len = e.Magnitude

			if len > 1e-9 then
				local d = e / len
				local key = dirKey(d)

				if not seen[key] then
					seen[key] = true
					table.insert(edges, d)
				end
			end
		end
	end

	return { verts = convex.verts, faces = convex.faces, normals = normals, edges = edges }
end

function ConvexDecomp.convexHullOfVerts(points)
	return ConvexDecomp.withPlanes(ConvexDecomp.convexHull(points))
end

-- Converts a finished local convex to world space. scaleVec is the
-- component-wise local scale (for post-creation Size edits); normals use the
-- inverse-transpose so non-uniform scales stay correct.
function ConvexDecomp.toWorld(convex, center, cols, scaleVec)
	local sx, sy, sz = scaleVec.X, scaleVec.Y, scaleVec.Z
	local worldVerts = {}

	for i, v in ipairs(convex.verts) do
		worldVerts[i] = center + rotationApply(cols, Vector3.new(v.X * sx, v.Y * sy, v.Z * sz))
	end

	local worldNormals = {}

	for _, n in ipairs(convex.normals) do
		local t = rotationApply(cols, Vector3.new(n.X / sx, n.Y / sy, n.Z / sz))
		local len = t.Magnitude

		if len > 1e-12 then
			table.insert(worldNormals, t / len)
		end
	end

	local worldEdges = {}

	for _, e in ipairs(convex.edges) do
		local t = rotationApply(cols, Vector3.new(e.X * sx, e.Y * sy, e.Z * sz))
		local len = t.Magnitude

		if len > 1e-12 then
			table.insert(worldEdges, t / len)
		end
	end

	return {
		center = center,
		verts = worldVerts,
		faces = convex.faces,
		normals = worldNormals,
		edges = worldEdges,
	}
end

function ConvexDecomp.allVerts(list)
	local flat = {}

	for _, convex in ipairs(list) do
		for _, v in ipairs(convex.verts) do
			table.insert(flat, v)
		end
	end

	return flat
end

function ConvexDecomp.boundingHalfExtents(verts)
	local minX, maxX, minY, maxY, minZ, maxZ = nil, nil, nil, nil, nil, nil

	for _, v in ipairs(verts) do
		if minX == nil or v.X < minX then
			minX = v.X
		end
		if maxX == nil or v.X > maxX then
			maxX = v.X
		end
		if minY == nil or v.Y < minY then
			minY = v.Y
		end
		if maxY == nil or v.Y > maxY then
			maxY = v.Y
		end
		if maxZ == nil or v.Z > maxZ then
			maxZ = v.Z
		end
		if minZ == nil or v.Z < minZ then
			minZ = v.Z
		end
	end

	return Vector3.new((maxX - minX) / 2, (maxY - minY) / 2, (maxZ - minZ) / 2)
end

-- True when the point is inside ANY of the world convexes.
function ConvexDecomp.pointInConvexes(point, worldConvexes): boolean
	for _, c in ipairs(worldConvexes) do
		local inside = true

		for _, f in ipairs(c.faces) do
			local a = c.verts[f[1]]
			local n = (c.verts[f[2]] - a):Cross(c.verts[f[3]] - a)
			local len = n.Magnitude

			if len > 1e-12 and n:Dot(point - a) > INSIDE_EPS * len then
				inside = false
				break
			end
		end

		if inside then
			return true
		end
	end

	return false
end

-- Closest exterior hit across world convexes. The origin must be outside all
-- of them (callers enforce the union-level inside rule first).
function ConvexDecomp.rayConvexes(origin, direction, worldConvexes)
	local bestT = nil
	local bestNormal = nil

	for _, c in ipairs(worldConvexes) do
		for _, f in ipairs(c.faces) do
			local t, n =
				ShapeIntersect.rayTriangle(origin, direction, c.verts[f[1]], c.verts[f[2]], c.verts[f[3]])

			if t ~= nil and (bestT == nil or t < bestT) then
				bestT = t
				bestNormal = n
			end
		end
	end

	if bestT == nil then
		return nil
	end

	return {
		t = bestT,
		position = origin + direction * bestT,
		normal = bestNormal,
	}
end

function ConvexDecomp.supportPoint(worldConvex, direction)
	local best = nil
	local bestDist = nil

	for _, v in ipairs(worldConvex.verts) do
		local d = v:Dot(direction)

		if bestDist == nil or d > bestDist then
			best = v
			bestDist = d
		end
	end

	return best
end

return ConvexDecomp
