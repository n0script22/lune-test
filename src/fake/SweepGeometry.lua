local Vector3 = require("./Vector3")

local SweepGeometry = {}

local EPSILON = 1e-8
local SAT_OVERLAP_EPS = 1e-9

local function dot3(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end

function SweepGeometry.rotationColumns(rotation)
	return {
		Vector3.new(rotation[1], rotation[4], rotation[7]),
		Vector3.new(rotation[2], rotation[5], rotation[8]),
		Vector3.new(rotation[3], rotation[6], rotation[9]),
	}
end

local function projectedHalfExtent(halves, cols, axis)
	return halves[1] * math.abs(dot3(cols[1], axis))
		+ halves[2] * math.abs(dot3(cols[2], axis))
		+ halves[3] * math.abs(dot3(cols[3], axis))
end

function SweepGeometry.sweepBoxVsBox(
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

function SweepGeometry.boxContactPoint(
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

function SweepGeometry.sweepSphereVsAABB(origin, direction, half, radius)
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

return SweepGeometry
