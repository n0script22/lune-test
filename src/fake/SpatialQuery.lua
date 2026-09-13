local CollisionGroups = require("./CollisionGroups")
local SweepGeometry = require("./SweepGeometry")
local Vector3 = require("./Vector3")

local SpatialQuery = {}

local EPSILON = 1e-8

local function isVector3Like(value): boolean
	return type(value) == "table" and type(value.X) == "number" and type(value.Y) == "number" and type(value.Z) == "number"
end

local function getPartSize(part)
	local size = part.Size

	if isVector3Like(size) then
		return size
	end

	return Vector3.new(4, 1, 2)
end

local function getPartPosition(part)
	local position = part.Position

	if isVector3Like(position) then
		return position
	end

	local cframe = part.CFrame

	if type(cframe) == "table" and isVector3Like(cframe.Position) then
		return cframe.Position
	end

	return Vector3.new(0, 0, 0)
end

function SpatialQuery.assertRay(origin, direction)
	assert(isVector3Like(origin), "Workspace:Raycast origin must be a Vector3")
	assert(isVector3Like(direction), "Workspace:Raycast direction must be a Vector3")
end

local function getPartCFrame(part)
	local cframe = part.CFrame

	if type(cframe) == "table" and isVector3Like(cframe.Position) and cframe._Rotation ~= nil then
		return cframe
	end

	return nil
end

function SpatialQuery.rayIntersectOBB(origin, direction, partCFrame, boxSize)
	if partCFrame == nil then
		return nil
	end

	local localOrigin = partCFrame:PointToObjectSpace(origin)
	local localDirection = partCFrame:VectorToObjectSpace(direction)
	local intersection = SpatialQuery.rayIntersectAABB(localOrigin, localDirection, Vector3.new(0, 0, 0), boxSize)

	if intersection == nil then
		return nil
	end

	return {
		t = intersection.t,
		distance = intersection.distance,
		position = partCFrame:PointToWorldSpace(intersection.position),
		normal = partCFrame:VectorToWorldSpace(intersection.normal),
	}
end

local function slabTest(origin, direction, minBound, maxBound)
	local tNear = 0
	local tFar = 1
	local hitAxis = nil
	local hitSign = 0

	local origins = { origin.X, origin.Y, origin.Z }
	local directions = { direction.X, direction.Y, direction.Z }
	local mins = { minBound.X, minBound.Y, minBound.Z }
	local maxs = { maxBound.X, maxBound.Y, maxBound.Z }

	for axis = 1, 3 do
		local o = origins[axis]
		local d = directions[axis]
		local boxMin = mins[axis]
		local boxMax = maxs[axis]

		if math.abs(d) < EPSILON then
			if o < boxMin or o > boxMax then
				return nil
			end
		else
			local t1 = (boxMin - o) / d
			local t2 = (boxMax - o) / d
			local entrySign

			if t1 > t2 then
				t1, t2 = t2, t1
				entrySign = 1
			else
				entrySign = if d > 0 then -1 else 1
			end

			if t1 > tNear then
				tNear = t1
				hitAxis = axis
				hitSign = entrySign
			end

			if t2 < tFar then
				tFar = t2
			end

			if tNear > tFar then
				return nil
			end
		end
	end

	if tNear > 1 or tFar < 0 then
		return nil
	end

	return tNear, tFar, hitAxis, hitSign
end

local function axisNormal(hitAxis, hitSign)
	if hitAxis == 1 then
		return Vector3.new(hitSign, 0, 0)
	elseif hitAxis == 2 then
		return Vector3.new(0, hitSign, 0)
	end

	return Vector3.new(0, 0, hitSign)
end

function SpatialQuery.rayIntersectAABB(origin, direction, boxCenter, boxSize)
	local maxDistance = math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

	if maxDistance <= EPSILON then
		return nil
	end

	local half = Vector3.new(boxSize.X / 2, boxSize.Y / 2, boxSize.Z / 2)
	local minBound = Vector3.new(boxCenter.X - half.X, boxCenter.Y - half.Y, boxCenter.Z - half.Z)
	local maxBound = Vector3.new(boxCenter.X + half.X, boxCenter.Y + half.Y, boxCenter.Z + half.Z)

	local tNear, tFar, hitAxis, hitSign = slabTest(origin, direction, minBound, maxBound)

	if tNear == nil then
		return nil
	end

	local clampedT = if tNear < 0 then 0 else tNear
	local distance = clampedT * maxDistance
	local position = origin + direction * clampedT

	local normal
	if clampedT == 0 or hitAxis == nil then
		local unit = direction / maxDistance
		normal = Vector3.new(-unit.X, -unit.Y, -unit.Z)
	else
		normal = axisNormal(hitAxis, hitSign)
	end

	return {
		t = clampedT,
		distance = distance,
		position = position,
		normal = normal,
	}
end

function SpatialQuery.collisionGroupsAreCollidable(workspace, groupA: string, groupB: string): boolean
	if type(workspace) ~= "table" then
		return true
	end

	return CollisionGroups.areCollidable(workspace._collisionGroupData, groupA, groupB)
end

function SpatialQuery.isPartQueryEligible(part, params, workspace)
	if params ~= nil and params.IgnoreWater == true and part.ClassName == "Terrain" and part.Material == "Water" then
		return false
	end

	if params ~= nil and params.BruteForceAllSlow == true then
		return true
	end

	local respectCanCollide = params ~= nil and params.RespectCanCollide == true
	local flag = if respectCanCollide then part.CanCollide else part.CanQuery

	if flag == nil then
		flag = true
	end

	if flag == false then
		return false
	end

	local partGroup = part.CollisionGroup

	if partGroup == nil then
		partGroup = "Default"
	end

	local queryGroup = "Default"

	if params ~= nil and params.CollisionGroup ~= nil then
		queryGroup = params.CollisionGroup
	end

	if workspace ~= nil and not SpatialQuery.collisionGroupsAreCollidable(workspace, partGroup, queryGroup) then
		return false
	end

	return SpatialQuery.isPartPassingFilters(part, params)
end

function SpatialQuery.isDescendantOrSelf(part, ancestor): boolean
	local cursor = part

	while cursor ~= nil do
		if cursor == ancestor then
			return true
		end

		cursor = cursor.Parent
	end

	return false
end

function SpatialQuery.matchesFilterList(part, filterList): boolean
	if type(filterList) ~= "table" then
		return false
	end

	for _, entry in ipairs(filterList) do
		if type(entry) == "table" and entry._isFakeRobloxInstance then
			if SpatialQuery.isDescendantOrSelf(part, entry) then
				return true
			end
		end
	end

	return false
end

function SpatialQuery.isPartPassingFilters(part, params): boolean
	if params == nil then
		return true
	end

	local excludeList = params.ExcludeInstances
	local includeList = params.IncludeInstances

	if type(excludeList) == "table" and SpatialQuery.matchesFilterList(part, excludeList) then
		return false
	end

	if includeList ~= nil then
		if type(includeList) ~= "table" then
			return true
		end

		if #includeList == 0 then
			return false
		end

		if not SpatialQuery.matchesFilterList(part, includeList) then
			return false
		end
	end

	local legacyList = params.FilterDescendantsInstances
	local filterType = params.FilterType

	if type(legacyList) == "table" and #legacyList > 0 then
		local matchesLegacy = SpatialQuery.matchesFilterList(part, legacyList)

		if filterType == "Include" then
			if not matchesLegacy then
				return false
			end
		elseif matchesLegacy then
			return false
		end
	end

	return true
end

function SpatialQuery.collectCandidateParts(workspace, params, excludePart)
	local parts = {}

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= excludePart then
			if SpatialQuery.isPartQueryEligible(descendant, params, workspace) then
				local size = getPartSize(descendant)

				if size.X > 0 and size.Y > 0 and size.Z > 0 then
					table.insert(parts, descendant)
				end
			end
		end
	end

	return parts
end

local function buildResult(part, position, distance, normal)
	local material = part.Material

	if material == nil then
		material = "Plastic"
	end

	return {
		Instance = part,
		Position = position,
		Distance = distance,
		Normal = normal,
		Material = material,
	}
end

function SpatialQuery.raycast(workspace, origin, direction, params)
	SpatialQuery.assertRay(origin, direction)

	local maxDistance = math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

	if maxDistance <= EPSILON then
		return nil
	end

	local closestHit = nil
	local closestPart = nil

	for _, part in ipairs(SpatialQuery.collectCandidateParts(workspace, params, nil)) do
		local size = getPartSize(part)
		local partCFrame = getPartCFrame(part)
		local intersection

		if partCFrame ~= nil then
			intersection = SpatialQuery.rayIntersectOBB(origin, direction, partCFrame, size)
		else
			intersection = SpatialQuery.rayIntersectAABB(origin, direction, getPartPosition(part), size)
		end

		if intersection ~= nil then
			if closestHit == nil or intersection.distance < closestHit.distance then
				closestHit = intersection
				closestPart = part
			end
		end
	end

	if closestHit == nil or closestPart == nil then
		return nil
	end

	return buildResult(closestPart, closestHit.position, closestHit.distance, closestHit.normal)
end

local function assertSweepDirection(direction, methodName: string, maxDistance: number): number
	assert(isVector3Like(direction), `{methodName} direction must be a Vector3`)

	local length = math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

	assert(length > EPSILON and length <= maxDistance, `{methodName} direction must have a length between 0 and {maxDistance} studs`)

	return length
end

local function sweepSphereVsPart(part, origin, direction, radius)
	local size = getPartSize(part)
	local half = Vector3.new(size.X / 2, size.Y / 2, size.Z / 2)
	local partCFrame = getPartCFrame(part)

	local localOrigin = origin
	local localDirection = direction

	if partCFrame ~= nil then
		localOrigin = partCFrame:PointToObjectSpace(origin)
		localDirection = partCFrame:VectorToObjectSpace(direction)
	end

	local sweep = SweepGeometry.sweepSphereVsAABB(localOrigin, localDirection, half, radius)

	if sweep == nil then
		return nil
	end

	local worldNormal = sweep.normal
	local worldContact = sweep.contact

	if partCFrame ~= nil then
		worldNormal = partCFrame:VectorToWorldSpace(sweep.normal)
		worldContact = partCFrame:PointToWorldSpace(sweep.contact)
	end

	local maxDistance = math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

	return {
		t = sweep.t,
		distance = sweep.t * maxDistance,
		position = worldContact,
		normal = worldNormal,
	}
end

local function sweepBoxVsPart(part, castCenter0, castCols, castHalf, direction)
	local size = getPartSize(part)
	local partHalf = Vector3.new(size.X / 2, size.Y / 2, size.Z / 2)
	local partCFrame = getPartCFrame(part)

	local partCenter = getPartPosition(part)
	local partCols = {
		Vector3.new(1, 0, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, 0, 1),
	}

	if partCFrame ~= nil then
		partCenter = partCFrame.Position
		partCols = SweepGeometry.rotationColumns(partCFrame._Rotation)
	end

	local t, normal =
		SweepGeometry.sweepBoxVsBox(castCenter0, castCols, castHalf, direction, partCenter, partCols, partHalf)

	if t == nil then
		return nil
	end

	local castCenterStar = castCenter0 + direction * t
	local contact =
		SweepGeometry.boxContactPoint(castCenterStar, castCols, castHalf, partCenter, partCols, partHalf, normal)
	local maxDistance = math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

	return {
		t = t,
		distance = t * maxDistance,
		position = contact,
		normal = normal,
	}
end

local function sweepBoxCast(workspace, castCenter0, castCols, castHalf, direction, params, excludePart)
	local closestHit = nil
	local closestPart = nil

	for _, candidate in ipairs(SpatialQuery.collectCandidateParts(workspace, params, excludePart)) do
		local hit = sweepBoxVsPart(candidate, castCenter0, castCols, castHalf, direction)

		if hit ~= nil then
			if closestHit == nil or hit.distance < closestHit.distance then
				closestHit = hit
				closestPart = candidate
			end
		end
	end

	if closestHit == nil or closestPart == nil then
		return nil
	end

	return buildResult(closestPart, closestHit.position, closestHit.distance, closestHit.normal)
end

function SpatialQuery.spherecast(workspace, position, radius: number, direction, params)
	assert(isVector3Like(position), "Workspace:Spherecast position must be a Vector3")
	assert(
		type(radius) == "number" and radius > 0 and radius <= 256,
		"Workspace:Spherecast radius must be a number between 0 and 256"
	)
	assertSweepDirection(direction, "Workspace:Spherecast", 1024)

	local closestHit = nil
	local closestPart = nil

	for _, part in ipairs(SpatialQuery.collectCandidateParts(workspace, params, nil)) do
		local hit = sweepSphereVsPart(part, position, direction, radius)

		if hit ~= nil then
			if closestHit == nil or hit.distance < closestHit.distance then
				closestHit = hit
				closestPart = part
			end
		end
	end

	if closestHit == nil or closestPart == nil then
		return nil
	end

	return buildResult(closestPart, closestHit.position, closestHit.distance, closestHit.normal)
end

local function assertCastCFrame(cframe, methodName: string)
	assert(
		type(cframe) == "table" and isVector3Like(cframe.Position) and cframe._Rotation ~= nil,
		`{methodName} cframe must be a CFrame`
	)
end

local function assertCastSize(size, methodName: string, maxSize: number)
	assert(isVector3Like(size), `{methodName} size must be a Vector3`)
	assert(
		size.X > 0 and size.Y > 0 and size.Z > 0 and size.X <= maxSize and size.Y <= maxSize and size.Z <= maxSize,
		`{methodName} size components must be between 0 and {maxSize} studs`
	)
end

function SpatialQuery.blockcast(workspace, cframe, size, direction, params)
	assertCastCFrame(cframe, "Workspace:Blockcast")
	assertCastSize(size, "Workspace:Blockcast", 512)
	assertSweepDirection(direction, "Workspace:Blockcast", 1024)

	return sweepBoxCast(
		workspace,
		cframe.Position,
		SweepGeometry.rotationColumns(cframe._Rotation),
		Vector3.new(size.X / 2, size.Y / 2, size.Z / 2),
		direction,
		params,
		nil
	)
end

function SpatialQuery.shapecast(workspace, part, direction, params)
	assert(
		type(part) == "table" and part._isFakeRobloxInstance and part:IsA("BasePart"),
		"Workspace:Shapecast part must be a BasePart"
	)
	assertSweepDirection(direction, "Workspace:Shapecast", 1024)

	local shape = part.Shape

	if shape == nil then
		shape = "Block"
	end

	if shape == "Ball" then
		local size = getPartSize(part)
		local radius = math.min(size.X, size.Y, size.Z) / 2
		assert(radius > 0, "Workspace:Shapecast part must have a positive size")

		local partCFrame = getPartCFrame(part)
		local origin = if partCFrame ~= nil then partCFrame.Position else getPartPosition(part)
		local closestHit = nil
		local closestPart = nil

		for _, candidate in ipairs(SpatialQuery.collectCandidateParts(workspace, params, part)) do
			local hit = sweepSphereVsPart(candidate, origin, direction, radius)

			if hit ~= nil then
				if closestHit == nil or hit.distance < closestHit.distance then
					closestHit = hit
					closestPart = candidate
				end
			end
		end

		if closestHit == nil or closestPart == nil then
			return nil
		end

		return buildResult(closestPart, closestHit.position, closestHit.distance, closestHit.normal)
	end

	local partCFrame = getPartCFrame(part)
	assert(partCFrame ~= nil, "Workspace:Shapecast part must have a valid CFrame")

	local size = getPartSize(part)
	assertCastSize(size, "Workspace:Shapecast", 512)

	return sweepBoxCast(
		workspace,
		partCFrame.Position,
		SweepGeometry.rotationColumns(partCFrame._Rotation),
		Vector3.new(size.X / 2, size.Y / 2, size.Z / 2),
		direction,
		params,
		part
	)
end

return SpatialQuery
