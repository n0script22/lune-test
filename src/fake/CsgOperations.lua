local ConvexClip = require("./ConvexClip")
local ConvexDecomp = require("./ConvexDecomp")
local PartAccess = require("./PartAccess")
local SweepFrame = require("./SweepFrame")
local Vector3 = require("./Vector3")

local CsgOperations = {}

local transposeApply = SweepFrame.transposeApply
local rotationApply = SweepFrame.rotationApply

-- Finished unit box shared by parts without stored decomposition data
-- (Instance.new unions/meshes): scaled to the part's Size at query time.
local UNIT_BOX = ConvexDecomp.withPlanes(ConvexDecomp.convexHull({
	Vector3.new(-1, -1, -1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
	Vector3.new(-1, 1, 1),
}))

local IDENT_COLS = { Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1) }

local function finishList(rawList)
	local finished = {}

	for _, raw in ipairs(rawList) do
		if ConvexClip.isSolid(raw) then
			table.insert(finished, ConvexDecomp.withPlanes(raw))
		end
	end

	return finished
end

-- Single finished local convex for a primitive Part shape at full size.
function CsgOperations.sourceLocalConvex(shape: string, size)
	return ConvexDecomp.withPlanes(ConvexDecomp.primitiveLocal(shape, size))
end

-- Finished world convexes for any CSG-capable part, or nil for plain Parts
-- (which keep their exact analytic query paths) and non-solids.
-- Unions/meshes without stored data fall back to their bounding box.
function CsgOperations.worldConvexesOfPart(part)
	local className = part.ClassName

	if className ~= "UnionOperation" and className ~= "MeshPart" then
		return nil
	end

	local size = PartAccess.getPartSize(part)
	local partCFrame = PartAccess.getPartCFrame(part)
	local center = if partCFrame ~= nil then partCFrame.Position else PartAccess.getPartPosition(part)
	local cols = if partCFrame ~= nil
		then SweepFrame.rotationColumns(partCFrame._Rotation)
		else IDENT_COLS

	local stored = PartAccess.getCollisionConvexes(part)

	if stored == nil then
		return {
			ConvexDecomp.toWorld(
				UNIT_BOX,
				center,
				cols,
				Vector3.new(size.X / 2, size.Y / 2, size.Z / 2)
			),
		}
	end

	local baseSize = part._unionBaseSize
	local scale = Vector3.one

	if PartAccess.isVector3Like(baseSize) and baseSize.X > 0 and baseSize.Y > 0 and baseSize.Z > 0 then
		scale = Vector3.new(size.X / baseSize.X, size.Y / baseSize.Y, size.Z / baseSize.Z)
	end

	local world = {}

	for _, localConvex in ipairs(stored) do
		table.insert(world, ConvexDecomp.toWorld(localConvex, center, cols, scale))
	end

	return world
end

-- Converts a finished world convex into union-local space (same tables for
-- faces; verts/normals/edges re-expressed).
function CsgOperations.toUnionFrame(worldConvex, center, cols)
	local verts = {}

	for i, v in ipairs(worldConvex.verts) do
		verts[i] = transposeApply(cols, v - center)
	end

	local normals = {}

	for _, n in ipairs(worldConvex.normals) do
		local t = transposeApply(cols, n)
		local len = t.Magnitude

		if len > 1e-12 then
			table.insert(normals, t / len)
		end
	end

	local edges = {}

	for _, e in ipairs(worldConvex.edges) do
		local t = transposeApply(cols, e)
		local len = t.Magnitude

		if len > 1e-12 then
			table.insert(edges, t / len)
		end
	end

	return { verts = verts, faces = worldConvex.faces, normals = normals, edges = edges }
end

-- World convexes of a CSG source part expressed in the union frame. Parts
-- contribute their primitive shape; unions/meshes contribute stored data
-- (or their box fallback), resampled through world space so mixed frames
-- and post-creation scales compose correctly.
function CsgOperations.sourceInUnionFrame(part, center, cols)
	local className = part.ClassName
	local list = {}

	if className == "UnionOperation" or className == "MeshPart" then
		local world = CsgOperations.worldConvexesOfPart(part)

		for _, w in ipairs(world) do
			table.insert(list, CsgOperations.toUnionFrame(w, center, cols))
		end

		return list
	end

	local size = PartAccess.getPartSize(part)
	local partCFrame = PartAccess.getPartCFrame(part)
	local partCenter = if partCFrame ~= nil then partCFrame.Position else PartAccess.getPartPosition(part)
	local partCols = if partCFrame ~= nil
		then SweepFrame.rotationColumns(partCFrame._Rotation)
		else IDENT_COLS
	local primitive = CsgOperations.sourceLocalConvex(PartAccess.getPartShape(part), size)
	local world = ConvexDecomp.toWorld(primitive, partCenter, partCols, Vector3.one)
	table.insert(list, CsgOperations.toUnionFrame(world, center, cols))

	return list
end

local function stripFinished(list)
	local raw = {}

	for _, c in ipairs(list) do
		table.insert(raw, { verts = c.verts, faces = c.faces })
	end

	return raw
end

local function containsAll(inner, outer): boolean
	for _, v in ipairs(inner.verts) do
		local inside = true

		for _, f in ipairs(outer.faces) do
			local a = outer.verts[f[1]]
			local n = (outer.verts[f[2]] - a):Cross(outer.verts[f[3]] - a)
			local len = n.Magnitude

			if len > 1e-12 and n:Dot(v - a) > 1e-7 * len then
				inside = false
				break
			end
		end

		if not inside then
			return false
		end
	end

	return true
end

-- Boolean OR: concatenation, dropping convexes fully contained in a strictly
-- larger sibling (duplicates are harmless for queries, which take the min).
function CsgOperations.unionLists(a, b)
	local raw = {}

	for _, c in ipairs(stripFinished(a)) do
		table.insert(raw, c)
	end
	for _, c in ipairs(stripFinished(b)) do
		table.insert(raw, c)
	end

	local kept = {}

	for i, c in ipairs(raw) do
		local contained = false

		for j, other in ipairs(raw) do
			if i ~= j and #c.verts < #other.verts and containsAll(c, other) then
				contained = true
				break
			end
		end

		if not contained then
			table.insert(kept, c)
		end
	end

	return finishList(kept)
end

-- Boolean AND over convex lists.
function CsgOperations.intersectLists(a, b)
	local out = {}

	for _, ca in ipairs(a) do
		for _, cb in ipairs(b) do
			local rawA = { verts = ca.verts, faces = ca.faces }
			local rawB = { verts = cb.verts, faces = cb.faces }
			local result = ConvexClip.intersectConvex(rawA, rawB)

			if result ~= nil then
				table.insert(out, result)
			end
		end
	end

	return finishList(out)
end

-- Boolean SUBTRACT (a minus b) over convex lists.
function CsgOperations.subtractLists(a, b)
	local rawB = {}

	for _, cb in ipairs(b) do
		table.insert(rawB, { verts = cb.verts, faces = cb.faces })
	end

	local out = {}

	for _, ca in ipairs(a) do
		local fragments = { { verts = ca.verts, faces = ca.faces } }

		for _, rb in ipairs(rawB) do
			local next = {}

			for _, f in ipairs(fragments) do
				for _, s in ipairs(ConvexClip.subtractConvex(f, rb)) do
					table.insert(next, s)
				end
			end

			fragments = next

			if #fragments == 0 then
				break
			end
		end

		for _, f in ipairs(fragments) do
			table.insert(out, f)
		end
	end

	return finishList(out)
end

return CsgOperations
