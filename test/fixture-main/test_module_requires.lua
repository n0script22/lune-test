local TestHelpers = require("@test/test_helpers")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assertEqual = TestHelpers.assertEqual
local assertRequireError = TestHelpers.assertRequireError

local m = {}

function m.replicatedStorageAndRelativeRequires()
	local SomeModule = require("./src/server/SomeModule")
	local add = SomeModule.add

	_G.SomeGlobal = "Hello World"
	SomeModule.AValue = "Test"
	assert(add(1, 1) == 2, "1+1 is not 2")
	assert(add(2, 2) == 4, "2+2 is not 4")
end

function m.playerScriptsClientRequires()
	local ClientModule1 = require("./src/client/ClientModule1")
	local multiply = ClientModule1.multiply

	assert(multiply(2, 2) == 4, "2*2 is not 4")
	assert(multiply(4, 4) == 16, "4*4 is not 16")
end

function m.starterPlayerScriptsClientRequires()
	local StarterPlayer = game:GetService("StarterPlayer")
	local ClientModule1 = require(StarterPlayer.StarterPlayerScripts.ClientModule1)
	local multiply = ClientModule1.multiply

	assert(multiply(3, 2) == 6, "3*2 is not 6")
	assert(multiply(5, 4) == 20, "5*4 is not 20")
end

function m.aliasRequires()
	local SomeModule = require("@test/fixture-main/src/server/SomeModule")
	local NestedModule = require("@test/game/unit/module")
	assert(SomeModule.add(1, 1) == 2, "1+1 is not 2")
	assert(NestedModule.add(2, 3) == 5, "@test alias did not resolve test/game/unit/module")
end

function m.luaurcAliasCanDifferFromDirectoryName()
	local SpecNestedModule = require("@spec/game/unit/module")

	assert(SpecNestedModule.add(3, 4) == 7, "@spec alias did not resolve despite differing from directory name")
end

function m.initLuaDirectoryRequires()
	local mountedUtilModule = require(ReplicatedStorage.UtilModule)
	local fileUtilModule = require("./src/shared/UtilModule")
	local outsideModule = require("./src/shared/OutsideModule")
	local gameUtilModule = require("@game/ReplicatedStorage/UtilModule")
	local gameSomeModule = require("@game/ServerScriptService/SomeModule")

	assert(mountedUtilModule.add(2, 3) == 5, "mounted init.lua module did not load")
	assert(fileUtilModule.add(4, 5) == 9, "filesystem init.lua module did not load")
	assert(outsideModule.add(6, 7) == 13, "relative require into init.lua directory did not load")
	assert(ReplicatedStorage.UtilModule.ChildModule ~= nil)
	assert(gameUtilModule.add(2, 3) == 5)
	assert(gameSomeModule.add(2, 3) == 5)
end

function m.requireStylesResolveToSameModuleAndShareState()
	local requireStyles = require("./src/server/RequireStylesModule")
	local byRelativeString = requireStyles.byRelativeString
	local byAbsoluteString = requireStyles.byAbsoluteString
	local byAbsoluteInstance = requireStyles.byAbsoluteInstance
	local byRelativeInstance = requireStyles.byRelativeInstance
	local byGameString = requireStyles.byGameString

	assert(byRelativeString == byAbsoluteString)
	assert(byRelativeString == byAbsoluteInstance)
	assert(byRelativeString == byRelativeInstance)
	assert(byRelativeString == byGameString)
	assertEqual(byRelativeString.getCount(), 0)

	assertEqual(byAbsoluteString.increment(), 1)
	assertEqual(byRelativeString.getCount(), 1)
	assertEqual(byAbsoluteInstance.getCount(), 1)
	assertEqual(byRelativeInstance.getCount(), 1)
	assertEqual(byGameString.getCount(), 1)
end

function m.invalidRequiresProduceErrors()
	assertRequireError(function()
		require(ReplicatedStorage.InvalidPath)
	end, "Cannot require value of type nil")

	assertRequireError(function()
		require(123)
	end, "Cannot require value of type number")

	assertRequireError(function()
		require("/invalidPath")
	end, 'Unable to resolve module path "invalidPath"')

	assertRequireError(function()
		require("12345")
	end, 'Unable to resolve module path "12345"')

	assertRequireError(function()
		require("./invalidPath")
	end, "missing module source for")

	assertRequireError(function()
		require("./")
	end, "missing module source for")

	assertRequireError(function()
		require("/")
	end, 'Unable to resolve module path ""')

	assertRequireError(function()
		require("../")
	end, "missing module source for")

	assertRequireError(function()
		require("./src")
	end, "missing module source for")

	assertRequireError(function()
		require("@invalidAlias")
	end, 'Unable to resolve module path "@invalidAlias"')

	assertRequireError(function()
		require("@alias")
	end, 'Unable to resolve module path "@alias"')

	assertRequireError(function()
		require("@alias/invalidPath")
	end, 'Unable to resolve module path "@alias/invalidPath"')

	assertRequireError(function()
		require("@test/test_helperss")
	end, 'Unable to resolve module path "@test/test_helperss"')
end

function m.rojoModelLoading()
	local remotes = getEnvironment():loadRojoModel("./src/shared/Remotes.model.json")
	assert(remotes == ReplicatedStorage.Remotes)

	assert(remotes.ClassName == "Folder")
	assert(remotes.ServiceA.ClassName == "Folder")
	assert(remotes.ServiceA.pingRemote.ClassName == "RemoteFunction")
end

function m.rojoModelLoadingMergesExistingInstances()
	local remotes = Instance.new("Folder", ReplicatedStorage)
	remotes.Name = "Remotes"

	local SomeFolder = Instance.new("Folder", remotes)
	SomeFolder.Name = "SomeFolder"

	getEnvironment():loadRojoModel("./src/shared/Remotes.model.json")

	assert(SomeFolder ~= nil)
	assert(SomeFolder.Parent == remotes)

	assert(remotes.ClassName == "Folder")
	assert(remotes.ServiceA.ClassName == "Folder")
	assert(remotes.ServiceA.pingRemote.ClassName == "RemoteFunction")
end

function m.rojoModelLoadingErrorsIfOtherInstanceExists()
	local remotes = Instance.new("Model", ReplicatedStorage)
	remotes.Name = "Remotes"

	TestHelpers.assertError(function()
		getEnvironment():loadRojoModel("./src/shared/Remotes.model.json")
	end, "exists")
end

function m.rojoModelLoadingisIsolated()
	local env = getEnvironment()
	local env2 = createEnvironment()

	env2:loadRojoModel("./src/shared/Remotes.model.json")

	assert(env.game:GetService("ReplicatedStorage").Remotes == nil)
	assert(env2.game:GetService("ReplicatedStorage").Remotes.ClassName == "Folder")
end

return m
