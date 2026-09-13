local Vector3 = require("./Vector3")

local SweepFrame = {}

SweepFrame.EPSILON = 1e-8
SweepFrame.SAT_OVERLAP_EPS = 1e-9

function SweepFrame.dot3(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end

function SweepFrame.rotationColumns(rotation)
	return {
		Vector3.new(rotation[1], rotation[4], rotation[7]),
		Vector3.new(rotation[2], rotation[5], rotation[8]),
		Vector3.new(rotation[3], rotation[6], rotation[9]),
	}
end

function SweepFrame.transposeApply(cols, v)
	return Vector3.new(
		cols[1].X * v.X + cols[1].Y * v.Y + cols[1].Z * v.Z,
		cols[2].X * v.X + cols[2].Y * v.Y + cols[2].Z * v.Z,
		cols[3].X * v.X + cols[3].Y * v.Y + cols[3].Z * v.Z
	)
end

function SweepFrame.rotationApply(cols, v)
	return cols[1] * v.X + cols[2] * v.Y + cols[3] * v.Z
end

return SweepFrame
