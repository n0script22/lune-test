local paths = require("@src/runner/paths")

local m = {}

function m.normalizeModuleLookupPathPreservesUnixAbsolutePaths()
	assert(paths.normalizeModuleLookupPath("/home/user/project/module.lua") == "/home/user/project/module")
	assert(paths.normalizeModuleLookupPath("/home/user/project/module/") == "/home/user/project/module")
end

function m.normalizeModuleLookupPathPreservesDriveQualifiedPaths()
	assert(paths.normalizeModuleLookupPath("C:\\Users\\user\\project\\module.luau") == "C:/Users/user/project/module")
	assert(paths.normalizeModuleLookupPath("D:/project/module/") == "D:/project/module")
end

function m.normalizeRequirePathTreatsLeadingSlashAsVirtualRoot()
	assert(paths.normalizeRequirePath("/ReplicatedStorage/UtilModule") == "ReplicatedStorage/UtilModule")
	assert(paths.normalizeRequirePath("/invalidPath") == "invalidPath")
end

function m.normalizeModuleLookupPathPreservesUnixAbsoluteStringRequires()
	assert(paths.normalizeModuleLookupPath("/some/path") == "/some/path")
	assert(paths.normalizeModuleLookupPath("/some/path/") == "/some/path")
end

return m
