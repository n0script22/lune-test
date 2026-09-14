local SimBindings = {}
SimBindings.__index = SimBindings

local FREQUENCIES = {
	Hz60 = { interval = 1, dt = 1 / 60 },
	Hz30 = { interval = 2, dt = 1 / 30 },
	Hz15 = { interval = 4, dt = 1 / 15 },
	Hz10 = { interval = 6, dt = 1 / 10 },
	Hz5 = { interval = 12, dt = 1 / 5 },
	Hz1 = { interval = 60, dt = 1 },
}

function SimBindings.new()
	return setmetatable({
		_bindings = {},
		_order = 0,
	}, SimBindings)
end

function SimBindings.normalizeFrequency(freq): string
	if freq == nil then
		return "Hz30"
	end
	assert(FREQUENCIES[freq] ~= nil, `invalid StepFrequency: {tostring(freq)}`)
	return freq
end

function SimBindings.normalizePriority(prio): number
	if prio == nil then
		return 2000
	end
	assert(type(prio) == "number", "priority must be a number")
	return prio
end

function SimBindings:bind(fn, freq, prio, kind: string?)
	assert(type(fn) == "function", "BindToSimulation expects a function")
	local frequency = SimBindings.normalizeFrequency(freq)
	local priority = SimBindings.normalizePriority(prio)
	self._order += 1
	local binding = {
		fn = fn,
		freq = frequency,
		prio = priority,
		order = self._order,
		kind = kind or "sim",
		connected = true,
	}
	table.insert(self._bindings, binding)
	local bindings = self._bindings
	local connection = {
		Connected = true,
		Disconnect = function(conn)
			if not conn.Connected then
				return
			end
			conn.Connected = false
			binding.connected = false
			for index, candidate in ipairs(bindings) do
				if candidate == binding then
					table.remove(bindings, index)
					break
				end
			end
		end,
	}
	return connection
end

local function sortedSnapshot(bindings, kindFilter: string?)
	local snapshot = {}
	for _, binding in ipairs(bindings) do
		if binding.connected and (kindFilter == nil or binding.kind == kindFilter) then
			table.insert(snapshot, binding)
		end
	end
	table.sort(snapshot, function(a, b)
		if a.prio == b.prio then
			return a.order < b.order
		end
		return a.prio < b.prio
	end)
	return snapshot
end

function SimBindings:runTick(tickIndex: number, invoke)
	local snapshot = sortedSnapshot(self._bindings, nil)
	for _, binding in ipairs(snapshot) do
		if not binding.connected then
			continue
		end
		local spec = FREQUENCIES[binding.freq]
		if tickIndex % spec.interval == 0 then
			invoke(binding.fn, spec.dt, binding)
		end
	end
end

function SimBindings:count()
	local n = 0
	for _, binding in ipairs(self._bindings) do
		if binding.connected then
			n += 1
		end
	end
	return n
end

return SimBindings
