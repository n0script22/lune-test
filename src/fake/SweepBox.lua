local Vector3 = require("./Vector3")
local SweepFrame = require("./SweepFrame")

local dot3 = SweepFrame.dot3
local SAT_OVERLAP_EPS = SweepFrame.SAT_OVERLAP_EPS

local SweepBox = {}

local function projectedHalfExtent(halves, cols, axis)
	return halves[1] * math.abs(dot3(cols[1], axis))
		+ halves[2] * math.abs(dot3(cols[2], axis))
		+ halves[3] * math.abs(dot3(cols[3], axis))
end

function SweepBox.sweepBoxVsBox(
	castCenter0,
	castCols,
	castHalf,
	direction,
	partCenter,
	partCols,
	partHalf
)
	local rel = partCenter - castCenter0
	local castHalves = { castHalf.X, castHalf.Y, castHalf.Z }
	local partHalves = { partHalf.X, partHalf.Y, partHalf.Z }

	local axes = {}

	for j = 1, 3 do
		table.insert(axes, partCols[j])
	end

	for i = 1, 3 do
		table.insert(axes, castCols[i])
	end

	for j = 1, 3 do
		for i = 1, 3 do
			local cross = partCols[j]:Cross(castCols[i])

			if cross.Magnitude > 1e-8 then
				table.insert(axes, cross / cross.Magnitude)
			end
		end
	end

	local bestT = 0
	local bestAxis = nil
	local bestS = 0
	local allOverlapping = true

	for _, axis in ipairs(axes) do
		local s = dot3(rel, axis)
		local extent = projectedHalfExtent(partHalves, partCols, axis)
			+ projectedHalfExtent(castHalves, castCols, axis)
		local dist = math.abs(s) - extent

		if dist >= -SAT_OVERLAP_EPS then
			allOverlapping = false
		end

		if dist > 0 then
			local closing = (if s > 0 then 1 else -1) * dot3(direction, axis)

			if closing <= 0 then
				return nil
			end

			local enterT = dist / closing

			if enterT > bestT then
				bestT = enterT
				bestAxis = axis
				bestS = s
			end
		end
	end

	if allOverlapping then
		return nil
	end

	if bestT > 1 then
		return nil
	end

	if bestAxis == nil then
		local fallbackAxis = partCols[1]
		local fallbackDist = nil

		for _, axis in ipairs(axes) do
			local s = dot3(rel, axis)
			local extent = projectedHalfExtent(partHalves, partCols, axis)
				+ projectedHalfExtent(castHalves, castCols, axis)
			local dist = math.abs(s) - extent

			if fallbackDist == nil or dist > fallbackDist then
				fallbackDist = dist
				fallbackAxis = axis
				bestS = s
			end
		end

		bestAxis = fallbackAxis
	end

	local sign = if bestS >= 0 then 1 else -1

	return bestT, bestAxis * -sign
end

local function collectBoxFaces(center, cols, half, tag, out)
	local halves = { half.X, half.Y, half.Z }

	for j = 1, 3 do
		local normal = cols[j]
		local u = cols[(j % 3) + 1]
		local v = cols[((j + 1) % 3) + 1]
		local hu = halves[(j % 3) + 1]
		local hv = halves[((j + 1) % 3) + 1]

		table.insert(out, {
			tag = tag,
			center = center + normal * halves[j],
			normal = normal,
			u = u,
			v = v,
			hu = hu,
			hv = hv,
		})
		table.insert(out, {
			tag = tag,
			center = center - normal * halves[j],
			normal = -normal,
			u = u,
			v = v,
			hu = hu,
			hv = hv,
		})
	end
end

local function clipPolygonAgainstPlane(points, planePoint, keepDirection)
	local result = {}

	if #points == 0 then
		return result
	end

	local function signedDistance(point)
		local offset = point - planePoint
		return dot3(offset, keepDirection)
	end

	for index = 1, #points do
		local current = points[index]
		local prev = points[if index == 1 then #points else index - 1]
		local distCurrent = signedDistance(current)
		local distPrev = signedDistance(prev)

		if distCurrent >= -SAT_OVERLAP_EPS then
			if distPrev < -SAT_OVERLAP_EPS then
				local t = distPrev / (distPrev - distCurrent)
				table.insert(result, prev + (current - prev) * t)
			end

			table.insert(result, current)
		elseif distPrev >= -SAT_OVERLAP_EPS then
			local t = distPrev / (distPrev - distCurrent)
			table.insert(result, prev + (current - prev) * t)
		end
	end

	return result
end

local function incidentFaceCorners(face)
	return {
		face.center + face.u * face.hu + face.v * face.hv,
		face.center + face.u * face.hu - face.v * face.hv,
		face.center - face.u * face.hu - face.v * face.hv,
		face.center - face.u * face.hu + face.v * face.hv,
	}
end

local function clampPointToPartBox(worldPoint, partCenter, partCols, partHalf)
	local offset = worldPoint - partCenter
	local localCoords = {
		dot3(offset, partCols[1]),
		dot3(offset, partCols[2]),
		dot3(offset, partCols[3]),
	}
	local halves = { partHalf.X, partHalf.Y, partHalf.Z }
	local clamped = {}

	for j = 1, 3 do
		clamped[j] = math.clamp(localCoords[j], -halves[j], halves[j])
	end

	return partCenter + partCols[1] * clamped[1] + partCols[2] * clamped[2] + partCols[3] * clamped[3]
end

function SweepBox.boxContactPoint(
	castCenterStar,
	castCols,
	castHalf,
	partCenter,
	partCols,
	partHalf,
	normal
)
	local partFaces = {}
	local castFaces = {}
	collectBoxFaces(partCenter, partCols, partHalf, "part", partFaces)
	collectBoxFaces(castCenterStar, castCols, castHalf, "cast", castFaces)

	local bestPartFace = partFaces[1]
	local bestPartDot = dot3(bestPartFace.normal, normal)

	for _, face in ipairs(partFaces) do
		local alignment = dot3(face.normal, normal)

		if alignment > bestPartDot then
			bestPartDot = alignment
			bestPartFace = face
		end
	end

	local negated = Vector3.new(-normal.X, -normal.Y, -normal.Z)
	local bestCastFace = castFaces[1]
	local bestCastDot = dot3(bestCastFace.normal, negated)

	for _, face in ipairs(castFaces) do
		local alignment = dot3(face.normal, negated)

		if alignment > bestCastDot then
			bestCastDot = alignment
			bestCastFace = face
		end
	end

	local refFace
	local incidentFace
	local partPlanePoint
	local partPlaneNormal

	if bestPartDot >= bestCastDot then
		refFace = bestPartFace
		incidentFace = castFaces[1]

		local worst = dot3(incidentFace.normal, refFace.normal)

		for _, face in ipairs(castFaces) do
			local alignment = dot3(face.normal, refFace.normal)

			if alignment < worst then
				worst = alignment
				incidentFace = face
			end
		end

		partPlanePoint = refFace.center
		partPlaneNormal = refFace.normal
	else
		refFace = bestCastFace
		incidentFace = partFaces[1]

		local worst = dot3(incidentFace.normal, refFace.normal)

		for _, face in ipairs(partFaces) do
			local alignment = dot3(face.normal, refFace.normal)

			if alignment < worst then
				worst = alignment
				incidentFace = face
			end
		end

		partPlanePoint = incidentFace.center
		partPlaneNormal = incidentFace.normal
	end

	local polygon = incidentFaceCorners(incidentFace)
	polygon = clipPolygonAgainstPlane(polygon, refFace.center + refFace.u * refFace.hu, -refFace.u)
	polygon = clipPolygonAgainstPlane(polygon, refFace.center - refFace.u * refFace.hu, refFace.u)
	polygon = clipPolygonAgainstPlane(polygon, refFace.center + refFace.v * refFace.hv, -refFace.v)
	polygon = clipPolygonAgainstPlane(polygon, refFace.center - refFace.v * refFace.hv, refFace.v)

	if #polygon == 0 then
		return clampPointToPartBox(castCenterStar, partCenter, partCols, partHalf)
	end

	local contact = polygon[1]
	local separation = dot3(contact - partPlanePoint, partPlaneNormal)

	return contact - partPlaneNormal * separation
end

return SweepBox
