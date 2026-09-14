return {
	environment = {
		virtualClock = {
			unixBase = 1700000000,
		},
	},
	testLocations = { "./unit/test_*" },
	mounts = {
		ReplicatedStorage = "test/fixture-main/src/shared",
	},
}
