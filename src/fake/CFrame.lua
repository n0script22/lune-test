local Vector3 = require("./Vector3")

local CFrame = {}
CFrame.__index = CFrame

local IDENTITY_ROTATION = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

local function copyRotation(rotation)
	return { rotation[1], rotation[2], rotation[3], rotation[4], rotation[5], rotation[6], rotation[7], rotation[8], rotation[9] }
end

local function multiplyRotations(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7],
		a[1] * b[2] + a[2] * b[5] + a[3] * b[8],
		a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7],
		a[4] * b[2] + a[5] * b[5] + a[6] * b[8],
		a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7],
		a[7] * b[2] + a[8] * b[5] + a[9] * b[8],
		a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end

local function rotateVector(rotation, vector)
	return Vector3.new(
		rotation[1] * vector.X + rotation[2] * vector.Y + rotation[3] * vector.Z,
		rotation[4] * vector.X + rotation[5] * vector.Y + rotation[6] * vector.Z,
		rotation[7] * vector.X + rotation[8] * vector.Y + rotation[9] * vector.Z
	)
end

local function transposeRotateVector(rotation, vector)
	return Vector3.new(
		rotation[1] * vector.X + rotation[4] * vector.Y + rotation[7] * vector.Z,
		rotation[2] * vector.X + rotation[5] * vector.Y + rotation[8] * vector.Z,
		rotation[3] * vector.X + rotation[6] * vector.Y + rotation[9] * vector.Z
	)
end

local function rotationX(angle: number)
	local c = math.cos(angle)
	local s = math.sin(angle)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end

local function rotationY(angle: number)
	local c = math.cos(angle)
	local s = math.sin(angle)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end

local function rotationZ(angle: number)
	local c = math.cos(angle)
	local s = math.sin(angle)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

local function fromEulerXYZ(rx: number, ry: number, rz: number)
	return multiplyRotations(multiplyRotations(rotationX(rx), rotationY(ry)), rotationZ(rz))
end

local function fromEulerYXZ(rx: number, ry: number, rz: number)
	return multiplyRotations(multiplyRotations(rotationY(ry), rotationX(rx)), rotationZ(rz))
end

local function clampNumber(value: number, low: number, high: number): number
	if value < low then
		return low
	end
	if value > high then
		return high
	end
	return value
end

local function toEulerXYZ(rotation)
	local r00, r01, r02 = rotation[1], rotation[2], rotation[3]
	local r10, r11, r12 = rotation[4], rotation[5], rotation[6]
	local r22 = rotation[9]

	local y = math.asin(clampNumber(r02, -1, 1))

	if math.abs(r02) < 0.99999 then
		return math.atan2(-r12, r22), y, math.atan2(-r01, r00)
	end

	if r02 > 0 then
		return math.atan2(r10, r11), y, 0
	end

	return math.atan2(-r10, r11), y, 0
end

local function toEulerYXZ(rotation)
	local r00, r01 = rotation[1], rotation[2]
	local r02, r10, r11, r12 = rotation[3], rotation[4], rotation[5], rotation[6]
	local r22 = rotation[9]

	local x = math.asin(clampNumber(-r12, -1, 1))

	if math.abs(r12) < 0.99999 then
		return x, math.atan2(r02, r22), math.atan2(r10, r11)
	end

	local sine = if x > 0 then 1 else -1
	return x, math.atan2(r01 * sine, r00), 0
end

local function orthonormalizeRotation(rotation)
	local xAxis = Vector3.new(rotation[1], rotation[4], rotation[7])
	local xUnit = xAxis.Unit
	local yAxis = Vector3.new(rotation[2], rotation[5], rotation[8])
	local yOrtho = yAxis - xUnit * xUnit:Dot(yAxis)

	if yOrtho.Magnitude < 1e-8 then
		yOrtho = if math.abs(xUnit.Y) < 0.99 then Vector3.yAxis - xUnit * xUnit.Y else Vector3.xAxis - xUnit * xUnit.X
	end

	local yUnit = yOrtho.Unit
	local zUnit = xUnit:Cross(yUnit)

	return {
		xUnit.X, yUnit.X, zUnit.X,
		xUnit.Y, yUnit.Y, zUnit.Y,
		xUnit.Z, yUnit.Z, zUnit.Z,
	}
end

local function buildCFrame(position, rotation)
	local pos = position or Vector3.new(0, 0, 0)
	local rot = if rotation == nil then copyRotation(IDENTITY_ROTATION) else copyRotation(rotation)

	return setmetatable({
		Position = Vector3.new(pos.X, pos.Y, pos.Z),
		X = pos.X,
		Y = pos.Y,
		Z = pos.Z,
		_Rotation = rot,
	}, CFrame)
end

local function quaternionToRotation(qX: number, qY: number, qZ: number, qW: number)
	local length = math.sqrt(qX * qX + qY * qY + qZ * qZ + qW * qW)

	if length < 1e-8 then
		return copyRotation(IDENTITY_ROTATION)
	end

	qX /= length
	qY /= length
	qZ /= length
	qW /= length

	return {
		1 - 2 * (qY * qY + qZ * qZ), 2 * (qX * qY - qZ * qW), 2 * (qX * qZ + qY * qW),
		2 * (qX * qY + qZ * qW), 1 - 2 * (qX * qX + qZ * qZ), 2 * (qY * qZ - qX * qW),
		2 * (qX * qZ - qY * qW), 2 * (qY * qZ + qX * qW), 1 - 2 * (qX * qX + qY * qY),
	}
end

local function lookAtRotation(at, lookAt, up)
	local forward = lookAt - at

	if forward.Magnitude < 1e-8 then
		return copyRotation(IDENTITY_ROTATION)
	end

	local zAxis = Vector3.new(-forward.X, -forward.Y, -forward.Z) / forward.Magnitude
	local upVector = up or Vector3.yAxis
	local xAxis = upVector:Cross(zAxis)

	if xAxis.Magnitude < 1e-6 then
		xAxis = Vector3.xAxis:Cross(zAxis)

		if xAxis.Magnitude < 1e-6 then
			xAxis = Vector3.zAxis:Cross(zAxis)
		end
	end

	local xUnit = xAxis.Unit
	local yUnit = zAxis:Cross(xUnit)

	return {
		xUnit.X, yUnit.X, zAxis.X,
		xUnit.Y, yUnit.Y, zAxis.Y,
		xUnit.Z, yUnit.Z, zAxis.Z,
	}
end

function CFrame.new(x: any?, y: number?, z: number?, ...: any)
	if x == nil and y == nil and z == nil and select("#", ...) == 0 then
		return buildCFrame(Vector3.new(0, 0, 0), IDENTITY_ROTATION)
	end

	if type(x) == "table" and x.X ~= nil and y ~= nil and type(y) == "table" and y.X ~= nil and select("#", ...) == 0 then
		return buildCFrame(x, lookAtRotation(x, y, nil))
	end

	if type(x) == "table" and x.X ~= nil and x.Y ~= nil and x.Z ~= nil and y == nil and z == nil and select("#", ...) == 0 then
		return buildCFrame(x, IDENTITY_ROTATION)
	end

	local rest = { ... }

	if type(x) == "number" and type(y) == "number" and type(z) == "number" then
		if #rest == 0 then
			return buildCFrame(Vector3.new(x, y, z), IDENTITY_ROTATION)
		end

		if #rest == 4 then
			return buildCFrame(Vector3.new(x, y, z), quaternionToRotation(rest[1], rest[2], rest[3], rest[4]))
		end

		if #rest == 9 then
			return buildCFrame(
				Vector3.new(x, y, z),
				{ rest[1], rest[2], rest[3], rest[4], rest[5], rest[6], rest[7], rest[8], rest[9] }
			)
		end
	end

	error("Invalid CFrame.new arguments")
end

CFrame.identity = buildCFrame(Vector3.new(0, 0, 0), IDENTITY_ROTATION)

function CFrame.lookAt(at, lookAt, up)
	return buildCFrame(at, lookAtRotation(at, lookAt, up))
end

function CFrame.lookAlong(at, direction, up)
	return buildCFrame(at, lookAtRotation(at, at + direction, up))
end

function CFrame.fromMatrix(pos, vX, vY, vZ)
	local zVector = vZ

	if zVector == nil then
		zVector = vX:Cross(vY).Unit
	end

	return buildCFrame(pos, {
		vX.X, vY.X, zVector.X,
		vX.Y, vY.Y, zVector.Y,
		vX.Z, vY.Z, zVector.Z,
	})
end

function CFrame.fromEulerAngles(rx: number, ry: number, rz: number, order)
	if order == "YXZ" then
		return buildCFrame(Vector3.new(0, 0, 0), fromEulerYXZ(rx, ry, rz))
	end

	return buildCFrame(Vector3.new(0, 0, 0), fromEulerXYZ(rx, ry, rz))
end

function CFrame.fromEulerAnglesXYZ(rx: number, ry: number, rz: number)
	return buildCFrame(Vector3.new(0, 0, 0), fromEulerXYZ(rx, ry, rz))
end

function CFrame.fromEulerAnglesYXZ(rx: number, ry: number, rz: number)
	return buildCFrame(Vector3.new(0, 0, 0), fromEulerYXZ(rx, ry, rz))
end

function CFrame.Angles(rx: number, ry: number, rz: number)
	return buildCFrame(Vector3.new(0, 0, 0), fromEulerXYZ(rx, ry, rz))
end

function CFrame.fromOrientation(rx: number, ry: number, rz: number)
	return buildCFrame(Vector3.new(0, 0, 0), fromEulerYXZ(rx, ry, rz))
end

function CFrame.fromAxisAngle(axis, angle: number)
	local unit = axis.Unit
	local c = math.cos(angle)
	local s = math.sin(angle)
	local t = 1 - c
	local x, y, z = unit.X, unit.Y, unit.Z

	return buildCFrame(Vector3.new(0, 0, 0), {
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c,
	})
end

function CFrame:ToEulerAngles(order)
	if order == "YXZ" then
		return toEulerYXZ(self._Rotation)
	end

	return toEulerXYZ(self._Rotation)
end

function CFrame:ToEulerAnglesXYZ()
	return toEulerXYZ(self._Rotation)
end

function CFrame:ToEulerAnglesYXZ()
	return toEulerYXZ(self._Rotation)
end

function CFrame:ToOrientation()
	return toEulerYXZ(self._Rotation)
end

function CFrame:GetComponents()
	local r = self._Rotation
	return self.Position.X, self.Position.Y, self.Position.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end

CFrame.components = CFrame.GetComponents

function CFrame:ToAxisAngle()
	local r = self._Rotation
	local trace = r[1] + r[5] + r[9]
	local angle = math.acos(clampNumber((trace - 1) / 2, -1, 1))

	if angle < 1e-6 then
		return Vector3.xAxis, 0
	end

	local axis = Vector3.new(r[8] - r[6], r[3] - r[7], r[4] - r[2]) / (2 * math.sin(angle))

	return axis.Unit, angle
end

function CFrame:AngleBetween(other): number
	local r = multiplyRotations(self._Rotation, {
		other._Rotation[1], other._Rotation[4], other._Rotation[7],
		other._Rotation[2], other._Rotation[5], other._Rotation[8],
		other._Rotation[3], other._Rotation[6], other._Rotation[9],
	})
	local trace = r[1] + r[5] + r[9]

	return math.acos(clampNumber((trace - 1) / 2, -1, 1))
end

function CFrame:FuzzyEq(other, epsilon: number?): boolean
	local tolerance = epsilon or 1e-5

	if (self.Position - other.Position).Magnitude > tolerance then
		return false
	end

	for index = 1, 9 do
		if math.abs(self._Rotation[index] - other._Rotation[index]) > tolerance then
			return false
		end
	end

	return true
end

function CFrame:Orthonormalize()
	return buildCFrame(self.Position, orthonormalizeRotation(self._Rotation))
end

function CFrame:Lerp(other, alpha: number)
	local position = self.Position:Lerp(other.Position, alpha)
	local rotation = {}

	for index = 1, 9 do
		rotation[index] = self._Rotation[index] + (other._Rotation[index] - self._Rotation[index]) * alpha
	end

	return buildCFrame(position, orthonormalizeRotation(rotation))
end

function CFrame:Inverse()
	local rotation = self._Rotation
	local transposed = {
		rotation[1], rotation[4], rotation[7],
		rotation[2], rotation[5], rotation[8],
		rotation[3], rotation[6], rotation[9],
	}
	local invertedPosition = rotateVector(transposed, self.Position)

	return buildCFrame(Vector3.new(-invertedPosition.X, -invertedPosition.Y, -invertedPosition.Z), transposed)
end

function CFrame:ToWorldSpace(...: any)
	local result = self

	for index = 1, select("#", ...) do
		result = result * select(index, ...)
	end

	return result
end

function CFrame:ToObjectSpace(...: any)
	local result = self:Inverse()

	for index = 1, select("#", ...) do
		result = result * select(index, ...)
	end

	return result
end

function CFrame:PointToWorldSpace(...: any)
	local results = {}

	for index = 1, select("#", ...) do
		table.insert(results, self * select(index, ...))
	end

	return unpack(results)
end

function CFrame:PointToObjectSpace(...: any)
	local inverse = self:Inverse()
	local results = {}

	for index = 1, select("#", ...) do
		table.insert(results, inverse * select(index, ...))
	end

	return unpack(results)
end

function CFrame:VectorToWorldSpace(...: any)
	local results = {}

	for index = 1, select("#", ...) do
		table.insert(results, rotateVector(self._Rotation, select(index, ...)))
	end

	return unpack(results)
end

function CFrame:VectorToObjectSpace(...: any)
	local results = {}

	for index = 1, select("#", ...) do
		table.insert(results, transposeRotateVector(self._Rotation, select(index, ...)))
	end

	return unpack(results)
end

function CFrame.__index(self, key)
	if key == "Rotation" then
		return buildCFrame(Vector3.new(0, 0, 0), self._Rotation)
	end

	if key == "RightVector" or key == "XVector" then
		local r = rawget(self, "_Rotation")
		return Vector3.new(r[1], r[4], r[7])
	end

	if key == "UpVector" or key == "YVector" then
		local r = rawget(self, "_Rotation")
		return Vector3.new(r[2], r[5], r[8])
	end

	if key == "LookVector" then
		local r = rawget(self, "_Rotation")
		return Vector3.new(-r[3], -r[6], -r[9])
	end

	if key == "ZVector" then
		local r = rawget(self, "_Rotation")
		return Vector3.new(r[3], r[6], r[9])
	end

	return CFrame[key]
end

function CFrame.__mul(a, b)
	if type(b) == "table" and b.Position ~= nil and b._Rotation ~= nil then
		local rotatedOffset = rotateVector(a._Rotation, b.Position)
		return buildCFrame(a.Position + rotatedOffset, multiplyRotations(a._Rotation, b._Rotation))
	end

	if type(b) == "table" and b.X ~= nil and b.Y ~= nil and b.Z ~= nil then
		return a.Position + rotateVector(a._Rotation, b)
	end

	error("Unsupported CFrame multiplication")
end

function CFrame.__add(a, b)
	return buildCFrame(a.Position + b, a._Rotation)
end

function CFrame.__sub(a, b)
	return buildCFrame(a.Position - b, a._Rotation)
end

function CFrame.__eq(a, b)
	if a.Position ~= b.Position then
		return false
	end

	for index = 1, 9 do
		if a._Rotation[index] ~= b._Rotation[index] then
			return false
		end
	end

	return true
end

function CFrame.__tostring(self)
	return tostring(self.Position)
end

return CFrame
