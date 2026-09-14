local CFrame = require("./CFrame")
local CsgOperations = require("./CsgOperations")
local PartAccess = require("./PartAccess")
local SweepFrame = require("./SweepFrame")
local Vector3 = require("./Vector3")

local CsgService = {}

local COLLISION_FIDELITIES = {
	Box = true,
	Hull = true,
	Default = true,
	PreciseConvexDecomposition = true,
}

local RENDER_FIDELITIES = {
	Automatic = true,
	Precise = true,
	Performance = true,
}

local function checkCollisionFidelity(value)
	if value == nil then
		return "Default"
	end

	local fidelity = tostring(value)

	if not COLLISION_FIDELITIES[fidelity] then
		error(`Invalid CollisionFidelity {tostring(value)}`, 3)
	end

	return fidelity
end

local function checkRenderFidelity(value)
	if value == nil then
		return "Automatic"
	end

	local fidelity = tostring(value)

	if not RENDER_FIDELITIES[fidelity] then
		error(`Invalid RenderFidelity {tostring(value)}`, 3)
	end

	return fidelity
end

local function checkSplitApart(value)
	if value == nil then
		return true
	end

	assert(type(value) == "boolean", "SplitApart must be a boolean")

	return value
end

local function isCsgSource(part): boolean
	local className = part.ClassName
	return className == "Part" or className == "UnionOperation" or className == "MeshPart"
end

local function normalizeSources(basePart, parts, methodName: string)
	assert(
		type(basePart) == "table"
			and basePart._isFakeRobloxInstance
			and basePart:IsA("BasePart")
			and isCsgSource(basePart),
		`{methodName} can only be called on a Part, UnionOperation or MeshPart`
	)
	assert(type(parts) == "table", `{methodName} parts must be an array`)
	assert(#parts > 0, `{methodName} parts array must not be empty`)

	local sources = {}

	for index, part in ipairs(parts) do
		assert(
			type(part) == "table" and part._isFakeRobloxInstance and part:IsA("BasePart") and isCsgSource(part),
			`{methodName} parts must be Parts, UnionOperations or MeshParts (bad entry at index {index})`
		)

		local size = PartAccess.getPartSize(part)
		assert(
			size.X > 0 and size.Y > 0 and size.Z > 0,
			`{methodName} parts must have a positive size (bad entry at index {index})`
		)

		table.insert(sources, part)
	end

	return sources
end

local function frameOf(part)
	local partCFrame = PartAccess.getPartCFrame(part)
	assert(partCFrame ~= nil, "CSG parts must have a valid CFrame")

	return partCFrame.Position, SweepFrame.rotationColumns(partCFrame._Rotation)
end

local function convexAABB(convex)
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

	return minX, maxX, minY, maxY, minZ, maxZ
end

-- Splits a convex list into AABB-connected components (touching counts).
local function splitComponents(list)
	local boxes = {}

	for i, convex in ipairs(list) do
		local minX, maxX, minY, maxY, minZ, maxZ = convexAABB(convex)
		boxes[i] = { minX = minX, maxX = maxX, minY = minY, maxY = maxY, minZ = minZ, maxZ = maxZ }
	end

	local componentOf = {}
	local components = {}

	for i in ipairs(list) do
		if componentOf[i] == nil then
			local componentId = #components + 1
			local queue = { i }
			componentOf[i] = componentId
			components[componentId] = {}

			while #queue > 0 do
				local current = table.remove(queue, 1)
				table.insert(components[componentId], list[current])

				for j in ipairs(list) do
					if componentOf[j] == nil then
						local a, b = boxes[current], boxes[j]

						if a.minX <= b.maxX + 1e-7
							and b.minX <= a.maxX + 1e-7
							and a.minY <= b.maxY + 1e-7
							and b.minY <= a.maxY + 1e-7
							and a.minZ <= b.maxZ + 1e-7
							and b.minZ <= a.maxZ + 1e-7
						then
							componentOf[j] = componentId
							table.insert(queue, j)
						end
					end
				end
			end
		end
	end

	return components
end

local APPEARANCE_KEYS = { "Material", "Transparency", "Anchored", "CanCollide", "CanQuery", "CollisionGroup" }

local function instantiateResult(
	runtime,
	resultClass: string,
	component,
	basePart,
	baseCenter,
	baseCols,
	collisionFidelity: string,
	renderFidelity: string
)
	local minX, maxX, minY, maxY, minZ, maxZ = nil, nil, nil, nil, nil, nil

	for _, convex in ipairs(component) do
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
	end

	local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
	assert(size.X > 0 and size.Y > 0 and size.Z > 0, "CSG result has an empty volume")

	local localCenter = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)

	for _, convex in ipairs(component) do
		for i, v in ipairs(convex.verts) do
			convex.verts[i] = v - localCenter
		end
	end

	local instance = runtime:_newInstance(resultClass, nil, true)
	instance._collisionConvexes = component
	instance._unionBaseSize = size

	for _, key in ipairs(APPEARANCE_KEYS) do
		instance[key] = basePart[key]
	end

	instance.Size = size
	instance.CFrame = CFrame.fromMatrix(
		baseCenter + SweepFrame.rotationApply(baseCols, localCenter),
		baseCols[1],
		baseCols[2]
	)
	instance.CollisionFidelity = collisionFidelity
	instance.RenderFidelity = renderFidelity

	return instance
end

-- Core boolean pipeline. Returns an array of result instances (possibly
-- empty). Result CFrames are bbox-centered in the base part's frame: this
-- keeps Size centered like every other part, which the query math requires.
-- It differs from the engine's origin-preserving convention; queries are
-- unaffected, so tests stay meaningful.
function CsgService.booleanOp(
	runtime,
	basePart,
	parts,
	kind: string,
	methodName: string,
	collisionFidelity: string,
	renderFidelity: string,
	splitApart: boolean
)
	local sources = normalizeSources(basePart, parts, methodName)
	local baseCenter, baseCols = frameOf(basePart)

	local acc = CsgOperations.sourceInUnionFrame(basePart, baseCenter, baseCols)

	for _, source in ipairs(sources) do
		local otherLocal = CsgOperations.sourceInUnionFrame(source, baseCenter, baseCols)

		if kind == "Subtract" then
			acc = CsgOperations.subtractLists(acc, otherLocal)
		elseif kind == "Intersect" then
			acc = CsgOperations.intersectLists(acc, otherLocal)
		else
			acc = CsgOperations.unionLists(acc, otherLocal)
		end

		if #acc == 0 then
			break
		end
	end

	if #acc == 0 then
		return {}
	end

	local components = if splitApart then splitComponents(acc) else { acc }
	local resultClass = if basePart.ClassName == "MeshPart" then "MeshPart" else "UnionOperation"

	for _, source in ipairs(sources) do
		if source.ClassName == "MeshPart" then
			resultClass = "MeshPart"
			break
		end
	end

	local results = {}

	for _, component in ipairs(components) do
		table.insert(
			results,
			instantiateResult(
				runtime,
				resultClass,
				component,
				basePart,
				baseCenter,
				baseCols,
				collisionFidelity,
				renderFidelity
			)
		)
	end

	return results
end

local function firstOrNil(results)
	if #results == 0 then
		return nil
	end

	return results[1]
end

-- BasePart single-result API: UnionAsync(parts, collisionFidelity?, renderFidelity?).
function CsgService.unionSingle(runtime, basePart, parts, collisionFidelity, renderFidelity)
	return firstOrNil(
		CsgService.booleanOp(
			runtime,
			basePart,
			parts,
			"Union",
			"UnionAsync",
			checkCollisionFidelity(collisionFidelity),
			checkRenderFidelity(renderFidelity),
			false
		)
	)
end

function CsgService.subtractSingle(runtime, basePart, parts, collisionFidelity, renderFidelity)
	return firstOrNil(
		CsgService.booleanOp(
			runtime,
			basePart,
			parts,
			"Subtract",
			"SubtractAsync",
			checkCollisionFidelity(collisionFidelity),
			checkRenderFidelity(renderFidelity),
			false
		)
	)
end

function CsgService.intersectSingle(runtime, basePart, parts, collisionFidelity, renderFidelity)
	return firstOrNil(
		CsgService.booleanOp(
			runtime,
			basePart,
			parts,
			"Intersect",
			"IntersectAsync",
			checkCollisionFidelity(collisionFidelity),
			checkRenderFidelity(renderFidelity),
			false
		)
	)
end

local function parseOptions(options)
	if options == nil then
		return "Default", "Automatic", true
	end

	assert(type(options) == "table", "CSG options must be a table")

	return checkCollisionFidelity(options.CollisionFidelity),
		checkRenderFidelity(options.RenderFidelity),
		checkSplitApart(options.SplitApart)
end

-- GeometryService array API: UnionAsync(part, parts, options?).
function CsgService.geometryOp(runtime, basePart, parts, kind: string, methodName: string, options)
	local collisionFidelity, renderFidelity, splitApart = parseOptions(options)

	return CsgService.booleanOp(
		runtime,
		basePart,
		parts,
		kind,
		methodName,
		collisionFidelity,
		renderFidelity,
		splitApart
	)
end

return CsgService
