local PartAccess = require("./PartAccess")
local QueryFilter = require("./QueryFilter")
local ShapeIntersect = require("./ShapeIntersect")
local SweepBox = require("./SweepBox")
local SweepConvex = require("./SweepConvex")
local SweepFrame = require("./SweepFrame")
local SweepSphere = require("./SweepSphere")
local Vector3 = require("./Vector3")

local SweepQuery = {}

local EPSILON = 1e-8

local isVector3Like = PartAccess.isVector3Like
local getPartSize = PartAccess.getPartSize
local getPartPosition = PartAccess.getPartPosition
local getPartCFrame = PartAccess.getPartCFrame
local getPartShape = PartAccess.getPartShape

local function assertSweepDirection(direction, methodName: string, maxDistance: number): number
	assert(isVector3Like(direction), `{methodName} direction must be a Vector3`)

	local length = math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

	assert(length > EPSILON and length <= maxDistance, `{methodName} direction must have a length between 0 and {maxDistance} studs`)

	return length
end

local function sweepSphereVsPart(part, origin, direction, radius)
	local size = getPartSize(part)
	local partCFrame = getPartCFrame(part)

	if getPartShape(part) == "Ball" then
		local center = if partCFrame ~= nil then partCFrame.Position else getPartPosition(part)
		local targetRadius = math.min(size.X, size.Y, size.Z) / 2

		if targetRadius <= 0 then
			return nil
		end

		local relative = origin - center
		local sweep = ShapeIntersect.sweepSphereVsSphere(relative, direction, targetRadius, radius)

		if sweep == nil then
			return nil
		end

		local maxDistance =
			math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

		return {
			t = sweep.t,
			distance = sweep.t * maxDistance,
			position = center + sweep.contact,
			normal = sweep.normal,
		}
	end

	if getPartShape(part) == "Cylinder" then
		local cylRadius = math.min(size.Y, size.Z) / 2
		local cylHalf = size.X / 2

		if cylRadius <= 0 or cylHalf <= 0 then
			return nil
		end

		local localOrigin = origin
		local localDirection = direction

		if partCFrame ~= nil then
			localOrigin = partCFrame:PointToObjectSpace(origin)
			localDirection = partCFrame:VectorToObjectSpace(direction)
		end

		local sweep =
			SweepSphere.sweepSphereVsCylinderX(localOrigin, localDirection, cylRadius, cylHalf, radius)

		if sweep == nil then
			return nil
		end

		local worldNormal = sweep.normal
		local worldContact = sweep.contact

		if partCFrame ~= nil then
			worldNormal = partCFrame:VectorToWorldSpace(sweep.normal)
			worldContact = partCFrame:PointToWorldSpace(sweep.contact)
		end

		local maxDistance =
			math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

		return {
			t = sweep.t,
			distance = sweep.t * maxDistance,
			position = worldContact,
			normal = worldNormal,
		}
	end

	local half = Vector3.new(size.X / 2, size.Y / 2, size.Z / 2)

	local localOrigin = origin
	local localDirection = direction

	if partCFrame ~= nil then
		localOrigin = partCFrame:PointToObjectSpace(origin)
		localDirection = partCFrame:VectorToObjectSpace(direction)
	end

	local sweep = SweepSphere.sweepSphereVsAABB(localOrigin, localDirection, half, radius)

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

	-- Engine (verified against Studio): Blockcast vs Ball is exact
	-- box-vs-sphere, not box-vs-box.
	if getPartShape(part) == "Ball" then
		local center = if partCFrame ~= nil then partCFrame.Position else getPartPosition(part)
		local radius = math.min(size.X, size.Y, size.Z) / 2

		if radius <= 0 then
			return nil
		end

		local sweep =
			SweepSphere.sweepBoxVsSphere(castCenter0, castCols, castHalf, direction, center, radius)

		if sweep == nil then
			return nil
		end

		local maxDistance =
			math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

		return {
			t = sweep.t,
			distance = sweep.t * maxDistance,
			position = sweep.contact,
			normal = sweep.normal,
		}
	end

	local partCenter = getPartPosition(part)
	local partCols = {
		Vector3.new(1, 0, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, 0, 1),
	}

	if partCFrame ~= nil then
		partCenter = partCFrame.Position
		partCols = SweepFrame.rotationColumns(partCFrame._Rotation)
	end

	-- Engine (verified against Studio): Blockcast vs Cylinder is exact
	-- box-vs-cylinder, not box-vs-box. Contact reuses the box
	-- approximation (exact for axial hits).
	if getPartShape(part) == "Cylinder" then
		local cylRadius = math.min(size.Y, size.Z) / 2
		local cylHalf = size.X / 2

		if cylRadius <= 0 or cylHalf <= 0 then
			return nil
		end

		local cylCols = partCols
		local t, normal = SweepConvex.sweepBoxVsCylinder(
			castCenter0,
			castCols,
			castHalf,
			direction,
			partCenter,
			cylCols,
			cylRadius,
			cylHalf
		)

		if t == nil then
			return nil
		end

		local castCenterStar = castCenter0 + direction * t
		local contact = SweepBox.boxContactPoint(
			castCenterStar,
			castCols,
			castHalf,
			partCenter,
			partCols,
			partHalf,
			normal
		)
		local maxDistance =
			math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

		return {
			t = t,
			distance = t * maxDistance,
			position = contact,
			normal = normal,
		}
	end

	local t, normal =
		SweepBox.sweepBoxVsBox(castCenter0, castCols, castHalf, direction, partCenter, partCols, partHalf)

	if t == nil then
		return nil
	end

	local castCenterStar = castCenter0 + direction * t
	local contact =
		SweepBox.boxContactPoint(castCenterStar, castCols, castHalf, partCenter, partCols, partHalf, normal)
	local maxDistance = math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

	return {
		t = t,
		distance = t * maxDistance,
		position = contact,
		normal = normal,
	}
end

local function sweepWedgeVsPart(
	targetPart,
	castCenter0,
	castCols,
	castSize,
	isCorner,
	direction
)
	local hx, hy, hz = castSize.X / 2, castSize.Y / 2, castSize.Z / 2
	local castHalf = Vector3.new(hx, hy, hz)
	local targetSize = getPartSize(targetPart)
	local targetShape = getPartShape(targetPart)
	local partCFrame = getPartCFrame(targetPart)
	local partCenter = getPartPosition(targetPart)
	local partCols = {
		Vector3.new(1, 0, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, 0, 1),
	}
	if partCFrame ~= nil then
		partCenter = partCFrame.Position
		partCols = SweepFrame.rotationColumns(partCFrame._Rotation)
	end
	local partHalf =
		Vector3.new(targetSize.X / 2, targetSize.Y / 2, targetSize.Z / 2)
	local maxDistance =
		math.sqrt(direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z)

	if targetShape == "Ball" then
		local center = if partCFrame ~= nil then partCFrame.Position else getPartPosition(targetPart)
		local radius = math.min(targetSize.X, targetSize.Y, targetSize.Z) / 2
		if radius <= 0 then
			return nil
		end
		local sweep = SweepSphere.sweepWedgeVsSphere(
			castCenter0,
			castCols,
			hx,
			hy,
			hz,
			isCorner,
			direction,
			center,
			radius
		)
		if sweep == nil then
			return nil
		end
		return {
			t = sweep.t,
			distance = sweep.t * maxDistance,
			position = sweep.contact,
			normal = sweep.normal,
		}
	end

	local casterConvex = if isCorner
		then SweepConvex.cornerConvex(castCenter0, castCols, hx, hy, hz)
		else SweepConvex.wedgeConvex(castCenter0, castCols, hx, hy, hz)

	local targetConvex
	if targetShape == "Cylinder" then
		local r = math.min(targetSize.Y, targetSize.Z) / 2
		local h = targetSize.X / 2
		if r <= 0 or h <= 0 then
			return nil
		end
		targetConvex = SweepConvex.prismConvex(partCenter, partCols, r, h)
	elseif targetShape == "Wedge" then
		targetConvex = SweepConvex.wedgeConvex(
			partCenter,
			partCols,
			targetSize.X / 2,
			targetSize.Y / 2,
			targetSize.Z / 2
		)
	elseif targetShape == "CornerWedge" then
		targetConvex = SweepConvex.cornerConvex(
			partCenter,
			partCols,
			targetSize.X / 2,
			targetSize.Y / 2,
			targetSize.Z / 2
		)
	else
		targetConvex = SweepConvex.boxConvex(partCenter, partCols, partHalf)
	end

	local t, normal = SweepConvex.sweepConvexVsConvex(casterConvex, direction, targetConvex)
	if t == nil then
		return nil
	end

	local castCenterStar = castCenter0 + direction * t
	local contact = SweepBox.boxContactPoint(
		castCenterStar,
		castCols,
		castHalf,
		partCenter,
		partCols,
		partHalf,
		normal
	)

	return {
		t = t,
		distance = t * maxDistance,
		position = contact,
		normal = normal,
	}
end

local function sweepCandidates(workspace, params, excludePart, testPart)
	local closestHit = nil
	local closestPart = nil

	for _, candidate in ipairs(QueryFilter.collectCandidateParts(workspace, params, excludePart)) do
		local hit = testPart(candidate)

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

	return QueryFilter.buildResult(closestPart, closestHit.position, closestHit.distance, closestHit.normal)
end

local function sweepBoxCast(workspace, castCenter0, castCols, castHalf, direction, params, excludePart)
	return sweepCandidates(workspace, params, excludePart, function(candidate)
		return sweepBoxVsPart(candidate, castCenter0, castCols, castHalf, direction)
	end)
end

local function sweepWedgeCast(
	workspace,
	castCenter0,
	castCols,
	castSize,
	isCorner,
	direction,
	params,
	excludePart
)
	return sweepCandidates(workspace, params, excludePart, function(candidate)
		return sweepWedgeVsPart(candidate, castCenter0, castCols, castSize, isCorner, direction)
	end)
end

function SweepQuery.spherecast(workspace, position, radius: number, direction, params)
	assert(isVector3Like(position), "Workspace:Spherecast position must be a Vector3")
	assert(
		type(radius) == "number" and radius > 0 and radius <= 256,
		"Workspace:Spherecast radius must be a number between 0 and 256"
	)
	assertSweepDirection(direction, "Workspace:Spherecast", 1024)

	return sweepCandidates(workspace, params, nil, function(part)
		return sweepSphereVsPart(part, position, direction, radius)
	end)
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

function SweepQuery.blockcast(workspace, cframe, size, direction, params)
	assertCastCFrame(cframe, "Workspace:Blockcast")
	assertCastSize(size, "Workspace:Blockcast", 512)
	assertSweepDirection(direction, "Workspace:Blockcast", 1024)

	return sweepBoxCast(
		workspace,
		cframe.Position,
		SweepFrame.rotationColumns(cframe._Rotation),
		Vector3.new(size.X / 2, size.Y / 2, size.Z / 2),
		direction,
		params,
		nil
	)
end

function SweepQuery.shapecast(workspace, part, direction, params)
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

		return sweepCandidates(workspace, params, part, function(candidate)
			return sweepSphereVsPart(candidate, origin, direction, radius)
		end)
	end

	local partCFrame = getPartCFrame(part)
	assert(partCFrame ~= nil, "Workspace:Shapecast part must have a valid CFrame")

	local size = getPartSize(part)
	assertCastSize(size, "Workspace:Shapecast", 512)

	-- Engine (verified against Studio): Wedge/CornerWedge casters are exact,
	-- Cylinder casters sweep as boxes (like Block).
	if shape == "Wedge" or shape == "CornerWedge" then
		return sweepWedgeCast(
			workspace,
			partCFrame.Position,
			SweepFrame.rotationColumns(partCFrame._Rotation),
			size,
			shape == "CornerWedge",
			direction,
			params,
			part
		)
	end

	return sweepBoxCast(
		workspace,
		partCFrame.Position,
		SweepFrame.rotationColumns(partCFrame._Rotation),
		Vector3.new(size.X / 2, size.Y / 2, size.Z / 2),
		direction,
		params,
		part
	)
end

return SweepQuery
