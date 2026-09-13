local PartAccess = require("./PartAccess")
local QueryFilter = require("./QueryFilter")
local ShapeIntersect = require("./ShapeIntersect")
local Vector3 = require("./Vector3")

local RayQuery = {}

local EPSILON = 1e-8

local isVector3Like = PartAccess.isVector3Like
local getPartSize = PartAccess.getPartSize
local getPartPosition = PartAccess.getPartPosition
local getPartCFrame = PartAccess.getPartCFrame
local getPartShape = PartAccess.getPartShape

function RayQuery.assertRay(origin, direction)
	assert(isVector3Like(origin), "Workspace:Raycast origin must be a Vector3")
	assert(isVector3Like(direction), "Workspace:Raycast direction must be a Vector3")
end

function RayQuery.rayIntersectOBB(origin, direction, partCFrame, boxSize)
	if partCFrame == nil then
		return nil
	end

	local localOrigin = partCFrame:PointToObjectSpace(origin)
	local localDirection = partCFrame:VectorToObjectSpace(direction)
	local intersection = RayQuery.rayIntersectAABB(localOrigin, localDirection, Vector3.new(0, 0, 0), boxSize)

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

function RayQuery.rayIntersectPart(origin, direction, part, size, partCFrame)
	local shape = getPartShape(part)
	local maxDistance = math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

	if maxDistance <= EPSILON then
		return nil
	end

	if shape == "Ball" then
		local center = if partCFrame ~= nil then partCFrame.Position else getPartPosition(part)
		local radius = math.min(size.X, size.Y, size.Z) / 2

		if radius <= 0 then
			return nil
		end

		local relative = origin - center
		local hit = ShapeIntersect.raySphere(relative, direction, radius)

		if hit == nil then
			return nil
		end

		return {
			t = hit.t,
			distance = hit.t * maxDistance,
			position = center + hit.position,
			normal = hit.normal,
		}
	end

	if shape == "Cylinder" or shape == "Wedge" or shape == "CornerWedge" then
		local center = if partCFrame ~= nil then partCFrame.Position else getPartPosition(part)
		local localOrigin = origin - center
		local localDirection = direction
		local toWorldPosition = nil
		local toWorldNormal = nil

		if partCFrame ~= nil then
			localOrigin = partCFrame:PointToObjectSpace(origin)
			localDirection = partCFrame:VectorToObjectSpace(direction)
			toWorldPosition = function(localPos)
				return partCFrame:PointToWorldSpace(localPos)
			end
			toWorldNormal = function(localNormal)
				return partCFrame:VectorToWorldSpace(localNormal)
			end
		else
			toWorldPosition = function(localPos)
				return center + localPos
			end
			toWorldNormal = function(localNormal)
				return localNormal
			end
		end

		local hit = nil

		if shape == "Cylinder" then
			local radius = math.min(size.Y, size.Z) / 2
			local halfLength = size.X / 2

			if radius <= 0 or halfLength <= 0 then
				return nil
			end

			hit = ShapeIntersect.rayCylinderX(localOrigin, localDirection, radius, halfLength)
		elseif shape == "Wedge" then
			hit = ShapeIntersect.rayWedge(localOrigin, localDirection, size.X / 2, size.Y / 2, size.Z / 2)
		else
			hit = ShapeIntersect.rayCornerWedge(localOrigin, localDirection, size.X / 2, size.Y / 2, size.Z / 2)
		end

		if hit == nil then
			return nil
		end

		return {
			t = hit.t,
			distance = hit.t * maxDistance,
			position = toWorldPosition(hit.position),
			normal = toWorldNormal(hit.normal),
		}
	end

	if partCFrame ~= nil then
		return RayQuery.rayIntersectOBB(origin, direction, partCFrame, size)
	end

	return RayQuery.rayIntersectAABB(origin, direction, getPartPosition(part), size)
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

	-- Engine (verified against Studio): a ray ending exactly on a face
	-- (t=1) misses, and a ray starting strictly inside the box passes
	-- through it. Only rays entering from outside with t < 1 hit.
	if tNear >= 1 or tFar < 0 then
		return nil
	end

	if origin.X > minBound.X and origin.X < maxBound.X
		and origin.Y > minBound.Y and origin.Y < maxBound.Y
		and origin.Z > minBound.Z and origin.Z < maxBound.Z
	then
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

function RayQuery.rayIntersectAABB(origin, direction, boxCenter, boxSize)
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

function RayQuery.raycast(workspace, origin, direction, params)
	RayQuery.assertRay(origin, direction)

	local maxDistance = math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

	if maxDistance <= EPSILON then
		return nil
	end

	local closestHit = nil
	local closestPart = nil

	for _, part in ipairs(QueryFilter.collectCandidateParts(workspace, params, nil)) do
		local size = getPartSize(part)
		local partCFrame = getPartCFrame(part)
		local intersection = RayQuery.rayIntersectPart(origin, direction, part, size, partCFrame)

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

	return QueryFilter.buildResult(closestPart, closestHit.position, closestHit.distance, closestHit.normal)
end

return RayQuery
