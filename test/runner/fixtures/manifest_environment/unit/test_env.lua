local m = {}

function m.virtualClockUsesManifestUnixBase()
	assert(os.time() == 1700000000)
end

return m
