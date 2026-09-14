local VirtualClock = {}
VirtualClock.__index = VirtualClock

function VirtualClock.new(config)
	config = config or {}

	local unixBase = config.unixBase
	if unixBase == nil then
		local ok, now = pcall(function()
			return os.time()
		end)
		unixBase = if ok and type(now) == "number" then now else 1700000000
	end

	local monoBase = config.monoBase
	if monoBase == nil then
		local ok, clock = pcall(function()
			return os.clock()
		end)
		monoBase = if ok and type(clock) == "number" then clock else 0
	end

	return setmetatable({
		_unixBase = unixBase,
		_monoBase = monoBase,
	}, VirtualClock)
end

function VirtualClock:unixBase()
	return self._unixBase
end

function VirtualClock:monoBase()
	return self._monoBase
end

function VirtualClock:osClock(wallTime: number): number
	return self._monoBase + wallTime
end

function VirtualClock:osTime(wallTime: number): number
	return math.floor(self._unixBase + wallTime)
end

function VirtualClock:tick(wallTime: number): number
	return self._unixBase + wallTime
end

function VirtualClock:serverTime(wallTime: number): number
	return self._unixBase + wallTime
end

return VirtualClock
