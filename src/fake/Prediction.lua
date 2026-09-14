local Prediction = {}

function Prediction.isReplicableName(name: string): boolean
	return type(name) == "string" and #name > 0 and #name <= 50
end

function Prediction.isReplicableValue(value): boolean
	if type(value) == "string" then
		return #value <= 50
	end
	return true
end

function Prediction.filterReplicated(attributes): { [string]: any }
	local names = {}
	for name, value in pairs(attributes or {}) do
		if Prediction.isReplicableName(name) and Prediction.isReplicableValue(value) then
			table.insert(names, name)
		end
	end
	table.sort(names)
	local filtered = {}
	for index, name in ipairs(names) do
		if index > 64 then
			break
		end
		filtered[name] = attributes[name]
	end
	return filtered
end

return Prediction
