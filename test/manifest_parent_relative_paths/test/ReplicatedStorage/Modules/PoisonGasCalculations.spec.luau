local ReplicatedStorage = game:GetService("ReplicatedStorage")
local calc = require(ReplicatedStorage.Modules.PoisonGasCalculations)

local t = {}

function t.isOk()
	assert(calc.compute() == 42, "sanity")
end

return t
