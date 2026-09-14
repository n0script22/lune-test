local Vector3 = require("./Vector3")

local ConvexClip = {}

local CLIP_EPS = 1e-9

local function quantKey(x: number): string
	return tostring(math.floor(x * 1e6 + 0.5))
end

local function vertKey(v): string
	return quantKey(v.X) .. "," .. quantKey(v.Y) .. "," .. quantKey(v.Z)
end

-- Clip a closed { verts, faces } polyhedron against the half-space n.dot(p)
-- <= d (n must be unit). The removed side is capped so output stays closed.
-- Fully-kept input shares its tables read-only; fully-removed input yields an
-- empty face list.
function ConvexClip.clipAgainstPlane(convex, n, d)
	local verts = convex.verts
	local dists = {}
	local anyIn = false
	local anyOut = false

	for i, v in ipairs(verts) do
		local dist = n:Dot(v) - d
		dists[i] = dist

		if dist > CLIP_EPS then
			anyOut = true
		else
			anyIn = true
		end
	end

	if not anyOut then
		return { verts = verts, faces = convex.faces }
	end

	if not anyIn then
		return { verts = {}, faces = {} }
	end

	local newVerts = {}
	local remap = {}
	local cutKeys = {}
	local cutPoints = {}

	local function getIndex(oldIdx: number): number
		local mapped = remap[oldIdx]

		if mapped == nil then
			table.insert(newVerts, verts[oldIdx])
			mapped = #newVerts
			remap[oldIdx] = mapped
		end

		return mapped
	end

	local function addCut(p): number
		local key = vertKey(p)

		for i, q in ipairs(newVerts) do
			if vertKey(q) == key then
				if not cutKeys[key] then
					cutKeys[key] = true
					table.insert(cutPoints, i)
				end

				return i
			end
		end

		table.insert(newVerts, p)
		local idx = #newVerts
		cutKeys[key] = true
		table.insert(cutPoints, idx)

		return idx
	end

	local function crossing(aIdx: number, da: number, bIdx: number, db: number): number
		local t = da / (da - db)
		return addCut(verts[aIdx] + (verts[bIdx] - verts[aIdx]) * t)
	end

	local newFaces = {}

	for _, f in ipairs(convex.faces) do
		local kept = {}

		for k = 1, 3 do
			local cur = f[k]
			local nxt = f[k % 3 + 1]
			local curIn = dists[cur] <= CLIP_EPS
			local nxtIn = dists[nxt] <= CLIP_EPS

			if curIn then
				table.insert(kept, getIndex(cur))
			end

			if curIn ~= nxtIn then
				table.insert(kept, crossing(cur, dists[cur], nxt, dists[nxt]))
			end
		end

		for i = 2, #kept - 1 do
			table.insert(newFaces, { kept[1], kept[i], kept[i + 1] })
		end
	end

	-- Cap the cut with a fan over the cut polygon (crossings plus kept
	-- on-plane verts, so grazing faces cannot leave an open edge). The fan
	-- faces the removed side (+n).
	for i, v in ipairs(newVerts) do
		if math.abs(n:Dot(v) - d) <= CLIP_EPS then
			local key = vertKey(v)

			if not cutKeys[key] then
				cutKeys[key] = true
				table.insert(cutPoints, i)
			end
		end
	end

	if #cutPoints >= 3 then
		local centroid = Vector3.zero

		for _, idx in ipairs(cutPoints) do
			centroid = centroid + newVerts[idx]
		end
		centroid = centroid / #cutPoints

		local axis = math.abs(n.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
		local u = n:Cross(axis)
		u = u / u.Magnitude
		local v = n:Cross(u)

		local ordered = {}

		for _, idx in ipairs(cutPoints) do
			local rel = newVerts[idx] - centroid
			table.insert(ordered, { idx = idx, angle = math.atan2(rel:Dot(v), rel:Dot(u)) })
		end

		table.sort(ordered, function(a, b)
			return a.angle < b.angle
		end)

		for i = 2, #ordered - 1 do
			local a = newVerts[ordered[1].idx]
			local b = newVerts[ordered[i].idx]
			local c = newVerts[ordered[i + 1].idx]
			local faceNormal = (b - a):Cross(c - a)

			if faceNormal:Dot(n) >= 0 then
				table.insert(newFaces, { ordered[1].idx, ordered[i].idx, ordered[i + 1].idx })
			else
				table.insert(newFaces, { ordered[1].idx, ordered[i + 1].idx, ordered[i].idx })
			end
		end
	end

	return { verts = newVerts, faces = newFaces }
end

-- Outward unit plane of a face, verified against the convex interior point.
-- Returns nil for degenerate faces.
local function outwardPlane(convex, face, interior)
	local a = convex.verts[face[1]]
	local n = (convex.verts[face[2]] - a):Cross(convex.verts[face[3]] - a)
	local len = n.Magnitude

	if len <= 1e-12 then
		return nil
	end

	n = n / len

	if n:Dot(interior - a) > 0 then
		n = -n
	end

	return n, n:Dot(a)
end

local function convexInterior(convex)
	local center = Vector3.zero

	for _, v in ipairs(convex.verts) do
		center = center + v
	end

	return center / #convex.verts
end

function ConvexClip.isSolid(convex): boolean
	if #convex.faces < 4 or #convex.verts < 4 then
		return false
	end

	local minX, maxX, minY, maxY, minZ, maxZ = nil, nil, nil, nil, nil, nil

	for _, v in ipairs(convex.verts) do
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
		if minZ == nil or v.Z < minZ then
			minZ = v.Z
		end
		if maxZ == nil or v.Z > maxZ then
			maxZ = v.Z
		end
	end

	return (maxX - minX) > 1e-6 and (maxY - minY) > 1e-6 and (maxZ - minZ) > 1e-6
end

-- Intersection of two closed convexes, or nil when disjoint.
function ConvexClip.intersectConvex(a, b)
	local interiorB = convexInterior(b)
	local result = { verts = a.verts, faces = a.faces }

	for _, f in ipairs(b.faces) do
		local n, d = outwardPlane(b, f, interiorB)

		if n ~= nil then
			result = ConvexClip.clipAgainstPlane(result, n, d)

			if #result.faces == 0 then
				return nil
			end
		end
	end

	if not ConvexClip.isSolid(result) then
		return nil
	end

	return result
end

-- Fragments of `a` with `b` removed (possibly empty).
function ConvexClip.subtractConvex(a, b)
	local interiorB = convexInterior(b)
	local remaining = { verts = a.verts, faces = a.faces }
	local fragments = {}

	for _, f in ipairs(b.faces) do
		local n, d = outwardPlane(b, f, interiorB)

		if n ~= nil then
			local outside = ConvexClip.clipAgainstPlane(remaining, -n, -d)

			if #outside.faces > 0 and ConvexClip.isSolid(outside) then
				table.insert(fragments, outside)
			end

			remaining = ConvexClip.clipAgainstPlane(remaining, n, d)

			if #remaining.faces == 0 then
				break
			end
		end
	end

	return fragments
end

return ConvexClip
