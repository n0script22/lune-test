local CollisionGroups = {}

function CollisionGroups.new()
	return {
		groups = {
			Default = true,
		},
		masks = {
			Default = 0,
		},
		nextMask = 1,
		nonCollidable = {},
	}
end

local function pairKey(groupA: string, groupB: string): string
	if groupA <= groupB then
		return groupA .. "\0" .. groupB
	end

	return groupB .. "\0" .. groupA
end

local function assertValidGroupName(name)
	assert(type(name) == "string" and name ~= "", "Invalid collision group name")
	assert(name ~= "Default", 'Collision group name cannot be "Default"')
end

function CollisionGroups.register(data, name: string)
	assertValidGroupName(name)

	if data.groups[name] then
		return
	end

	data.groups[name] = true
	data.masks[name] = data.nextMask
	data.nextMask += 1
end

function CollisionGroups.unregister(data, name: string)
	assert(type(name) == "string" and name ~= "", "Invalid collision group name")

	if name == "Default" then
		error('The "Default" collision group cannot be unregistered')
	end

	if not data.groups[name] then
		return
	end

	data.groups[name] = nil
	data.masks[name] = nil

	for key in pairs(data.nonCollidable) do
		local separator = key:find("\0", 1, true)
		local first = key:sub(1, separator - 1)
		local second = key:sub(separator + 1)

		if first == name or second == name then
			data.nonCollidable[key] = nil
		end
	end
end

function CollisionGroups.rename(data, fromName: string, toName: string)
	assert(type(fromName) == "string" and fromName ~= "", "Invalid collision group name")
	assertValidGroupName(toName)

	if not data.groups[fromName] then
		return
	end

	if fromName == toName then
		return
	end

	data.groups[fromName] = nil
	data.groups[toName] = true
	data.masks[toName] = data.masks[fromName]
	data.masks[fromName] = nil

	local movedPairs = {}

	for key in pairs(data.nonCollidable) do
		local separator = key:find("\0", 1, true)
		local first = key:sub(1, separator - 1)
		local second = key:sub(separator + 1)

		if first == fromName or second == fromName then
			local newFirst = if first == fromName then toName else first
			local newSecond = if second == fromName then toName else second
			movedPairs[pairKey(newFirst, newSecond)] = true
			data.nonCollidable[key] = nil
		end
	end

	for key in pairs(movedPairs) do
		data.nonCollidable[key] = true
	end
end

function CollisionGroups.setCollidable(data, groupA: string, groupB: string, collidable: boolean)
	assert(data.groups[groupA], `Collision group "{groupA}" is not registered`)
	assert(data.groups[groupB], `Collision group "{groupB}" is not registered`)

	local key = pairKey(groupA, groupB)

	if collidable then
		data.nonCollidable[key] = nil
	else
		data.nonCollidable[key] = true
	end
end

function CollisionGroups.areCollidable(data, groupA: string, groupB: string): boolean
	if data == nil then
		return true
	end

	if not data.groups[groupA] or not data.groups[groupB] then
		return true
	end

	return data.nonCollidable[pairKey(groupA, groupB)] ~= true
end

function CollisionGroups.isRegistered(data, name: string): boolean
	if data == nil or type(name) ~= "string" then
		return name == "Default"
	end

	return data.groups[name] == true
end

function CollisionGroups.list(data): { any }
	local names = {}

	for name in pairs(data.groups) do
		table.insert(names, name)
	end

	table.sort(names)

	local result = {}

	for _, name in ipairs(names) do
		table.insert(result, {
			name = name,
			mask = data.masks[name],
		})
	end

	return result
end

return CollisionGroups
