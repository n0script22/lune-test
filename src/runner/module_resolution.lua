local fs = require("@lune/fs")
local serde = require("@lune/serde")

local paths = require("./paths")

local moduleResolution = {}

local cachedLuaurcAliases = nil

local function readLuaurcAliases()
	if cachedLuaurcAliases ~= nil then
		return cachedLuaurcAliases
	end

	cachedLuaurcAliases = {}

	local luaurcPath = paths.normalizeFilesystemPath(".luaurc")

	if not fs.isFile(luaurcPath) then
		return cachedLuaurcAliases
	end

	local ok, decoded = pcall(function()
		return serde.decode("json", fs.readFile(luaurcPath))
	end)

	if not ok or type(decoded) ~= "table" or type(decoded.aliases) ~= "table" then
		return cachedLuaurcAliases
	end

	for aliasName, aliasPath in pairs(decoded.aliases) do
		if type(aliasName) == "string" and type(aliasPath) == "string" then
			cachedLuaurcAliases[aliasName] = aliasPath
		end
	end

	return cachedLuaurcAliases
end

local function defaultResolveExistingSourceFile(path: string): string?
	return paths.resolveExistingSourceFile(path)
end

local function startsWithPath(path: string, prefix: string): boolean
	return path == prefix or path:sub(1, #prefix + 1) == prefix .. "/"
end

local function resolveLuaurcAlias(aliasName: string, remainder: string, options): string?
	local aliases = if options.aliases ~= nil then options.aliases else readLuaurcAliases()
	local aliasPath = aliases[aliasName]

	if aliasPath == nil or aliasPath:sub(1, 1) == "~" then
		return nil
	end

	local candidatePath = paths.normalizeFilesystemPath(paths.pathJoin(aliasPath, remainder))
	local resolveExistingSourceFile = if options.resolveExistingSourceFile ~= nil
		then options.resolveExistingSourceFile
		else defaultResolveExistingSourceFile

	if resolveExistingSourceFile(candidatePath) ~= nil then
		return candidatePath
	end

	return nil
end

function moduleResolution.resolveMountedVirtualPathToFilePath(mounts, virtualPath: string, options): string?
	options = options or {}

	local normalizedVirtualPath = paths.normalizeRequirePath(virtualPath)
	local bestCandidate = nil
	local bestMountLength = -1
	local resolveExistingSourceFile = if options.resolveExistingSourceFile ~= nil
		then options.resolveExistingSourceFile
		else defaultResolveExistingSourceFile

	for _, mount in ipairs(mounts) do
		local mountPath = paths.normalizeRequirePath(mount.mountPath)

		if startsWithPath(normalizedVirtualPath, mountPath) then
			local trailingPath = normalizedVirtualPath:sub(#mountPath + 1)

			if trailingPath:sub(1, 1) == "/" then
				trailingPath = trailingPath:sub(2)
			end

			local candidatePath = paths.normalizeFilesystemPath(paths.pathJoin(mount.moduleRoot, trailingPath))

			if resolveExistingSourceFile(candidatePath) ~= nil and #mountPath > bestMountLength then
				bestCandidate = candidatePath
				bestMountLength = #mountPath
			end
		end
	end

	return bestCandidate
end

function moduleResolution.resolveAliasedModuleToFilePath(mounts, modulePath: string, options)
	options = options or {}

	local aliasName, remainder = modulePath:match("^@([^/]+)(.*)$")

	if aliasName == nil then
		return nil
	end

	if aliasName == "game" then
		local mountedPath = moduleResolution.resolveMountedVirtualPathToFilePath(mounts, remainder, options)

		if mountedPath == nil then
			return nil
		end

		return {
			filePath = mountedPath,
		}
	end

	local aliasedPath = resolveLuaurcAlias(aliasName, remainder, options)

	if aliasedPath ~= nil then
		return {
			filePath = aliasedPath,
		}
	end

	local resolveExistingSourceFile = if options.resolveExistingSourceFile ~= nil
		then options.resolveExistingSourceFile
		else defaultResolveExistingSourceFile
	local repoRelativePath = paths.normalizeFilesystemPath(paths.pathJoin(aliasName, remainder))

	if resolveExistingSourceFile(repoRelativePath) ~= nil then
		return {
			filePath = repoRelativePath,
			fallbackKind = "repo",
		}
	end

	local firstSegment, trailingPath = remainder:match("^/([^/]+)(.*)$")

	if firstSegment ~= nil then
		for _, mount in ipairs(mounts) do
			local normalizedRoot = paths.normalizeFilesystemPath(mount.moduleRoot)
			local rootName = normalizedRoot:match("([^/]+)$")

			if rootName == firstSegment then
				local candidatePath = paths.normalizeFilesystemPath(paths.pathJoin(normalizedRoot, trailingPath))

				if resolveExistingSourceFile(candidatePath) ~= nil then
					return {
						filePath = candidatePath,
						fallbackKind = "mount",
					}
				end
			end
		end
	end

	return nil
end

function moduleResolution.formatFallbackWarning(modulePath: string, resolution): string?
	if resolution == nil or resolution.fallbackKind == nil then
		return nil
	end

	if resolution.fallbackKind == "repo" then
		return `Falling back to repo-relative alias resolution for "{modulePath}" -> "{resolution.filePath}"`
	end

	if resolution.fallbackKind == "mount" then
		return `Falling back to mounted-root alias resolution for "{modulePath}" -> "{resolution.filePath}"`
	end

	return nil
end

return moduleResolution
