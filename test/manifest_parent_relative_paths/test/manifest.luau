return {
	testLocations = { "./**/*" },
	mounts = {
		ReplicatedStorage = { _root = "../src/shared", Packages = "../Packages" },
		ServerScriptService = "../src/server",
		PlayerScripts = "../src/client",
	},
}
