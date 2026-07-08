local moduleResolution = require("@src/runner/module_resolution")
local paths = require("@src/runner/paths")

local m = {}

function m.resolvesLuaurcAliasesBeforeFallbacks()
	local resolution = moduleResolution.resolveAliasedModuleToFilePath({}, "@test/game/unit/module")

	assert(resolution ~= nil)
	assert(resolution.filePath == paths.normalizeFilesystemPath("test/game/unit/module"))
	assert(resolution.fallbackKind == nil)
end

function m.resolvesRepoRelativeFallbacksDirectly()
	local checkedPaths = {}
	local expectedPath = paths.normalizeFilesystemPath("fallback_repo/module")
	local resolution = moduleResolution.resolveAliasedModuleToFilePath({}, "@fallback_repo/module", {
		aliases = {},
		resolveExistingSourceFile = function(path: string): string?
			table.insert(checkedPaths, path)

			if path == expectedPath then
				return expectedPath .. ".lua"
			end

			return nil
		end,
	})

	assert(resolution ~= nil)
	assert(resolution.filePath == expectedPath)
	assert(resolution.fallbackKind == "repo")
	assert(#checkedPaths >= 1)
	assert(checkedPaths[1] == expectedPath)

	local warning = moduleResolution.formatFallbackWarning("@fallback_repo/module", resolution)

	assert(warning ~= nil)
	assert(warning:find("repo%-relative alias resolution", 1) ~= nil, warning)
	assert(warning:find(expectedPath, 1, true) ~= nil, warning)
end

function m.resolvesMountedRootFallbacksDirectly()
	local mountRoot = paths.normalizeFilesystemPath("test/fixture-main/src/shared")
	local expectedPath = paths.normalizeFilesystemPath("test/fixture-main/src/shared/StatefulModule")
	local resolution = moduleResolution.resolveAliasedModuleToFilePath({
		{
			mountPath = "ReplicatedStorage",
			moduleRoot = mountRoot,
		},
	}, "@legacy/shared/StatefulModule", {
		aliases = {},
		resolveExistingSourceFile = function(path: string): string?
			if path == expectedPath then
				return expectedPath .. ".lua"
			end

			return nil
		end,
	})

	assert(resolution ~= nil)
	assert(resolution.filePath == expectedPath)
	assert(resolution.fallbackKind == "mount")
end

function m.resolvesGameAliasAgainstDriveQualifiedMountRoots()
	local expectedPath = "C:/repo/src/shared/UtilModule"
	local resolution = moduleResolution.resolveAliasedModuleToFilePath({
		{
			mountPath = "ReplicatedStorage",
			moduleRoot = "C:\\repo\\src\\shared",
		},
	}, "@game/ReplicatedStorage/UtilModule", {
		resolveExistingSourceFile = function(path: string): string?
			if path == expectedPath then
				return expectedPath .. "/init.lua"
			end

			return nil
		end,
	})

	assert(resolution ~= nil)
	assert(resolution.filePath == expectedPath)
	assert(resolution.fallbackKind == nil)
end

return m
