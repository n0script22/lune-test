local RaycastParams = {}
RaycastParams.__index = RaycastParams

function RaycastParams.new()
	return setmetatable({
		FilterType = "Exclude",
		FilterDescendantsInstances = {},
		IgnoreWater = false,
		BruteForceAllSlow = false,
		RespectCanCollide = false,
		CollisionGroup = "Default",
	}, RaycastParams)
end

function RaycastParams:AddToFilter(instances)
	if type(instances) == "table" and instances._isFakeRobloxInstance then
		table.insert(self.FilterDescendantsInstances, instances)
		return
	end

	assert(type(instances) == "table", "AddToFilter expects an Instance or an array of Instances")

	for _, instance in ipairs(instances) do
		table.insert(self.FilterDescendantsInstances, instance)
	end
end

return RaycastParams
