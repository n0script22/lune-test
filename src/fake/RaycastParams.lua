local RaycastParams = {}

local function getValues(self)
	return rawget(self, "_values")
end

function RaycastParams.__index(self, key)
	local values = getValues(self)

	if values ~= nil and values[key] ~= nil then
		return values[key]
	end

	return RaycastParams[key]
end

-- Engine (verified against Studio): FilterType only accepts the
-- RaycastFilterType enum values; anything else errors on assignment.
-- Values live in a backing store so __newindex sees every write.
function RaycastParams.__newindex(self, key, value)
	if key == "FilterType" and value ~= "Exclude" and value ~= "Include" then
		error(`Invalid FilterType {tostring(value)}. Must be Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Include`)
	end

	getValues(self)[key] = value
end

function RaycastParams.new()
	local self = setmetatable({ _values = {} }, RaycastParams)

	self.FilterType = "Exclude"
	self.FilterDescendantsInstances = {}
	self.IgnoreWater = false
	self.BruteForceAllSlow = false
	self.RespectCanCollide = false
	self.CollisionGroup = "Default"

	return self
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
