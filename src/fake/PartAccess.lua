local Vector3 = require("./Vector3")

local PartAccess = {}

function PartAccess.isVector3Like(value): boolean
	return type(value) == "table" and type(value.X) == "number" and type(value.Y) == "number" and type(value.Z) == "number"
end

function PartAccess.getPartSize(part)
	local size = part.Size

	if PartAccess.isVector3Like(size) then
		return size
	end

	return Vector3.new(4, 1, 2)
end

function PartAccess.getPartPosition(part)
	local position = part.Position

	if PartAccess.isVector3Like(position) then
		return position
	end

	local cframe = part.CFrame

	if type(cframe) == "table" and PartAccess.isVector3Like(cframe.Position) then
		return cframe.Position
	end

	return Vector3.new(0, 0, 0)
end

function PartAccess.getPartCFrame(part)
	local cframe = part.CFrame

	if type(cframe) == "table" and PartAccess.isVector3Like(cframe.Position) and cframe._Rotation ~= nil then
		return cframe
	end

	return nil
end

function PartAccess.getPartShape(part): string
	local shape = part.Shape

	if type(shape) == "string" then
		return shape
	end

	return "Block"
end

return PartAccess
