local manifestRunner = require("@src/runner/manifest")
local runner = require("@src/runner/run")
local paths = require("@src/runner/paths")
local sandbox = require("@src/runner/sandbox")

local m = {}

local fixtureMainManifest = manifestRunner.loadManifest("test/fixture-main/manifest.lua")
local fixtureMainMounts = manifestRunner.getMountsForWorkspace(fixtureMainManifest, nil)

local function countSuiteCases(manifest, suiteName)
	local suite = manifest.tests[suiteName]
	assert(suite ~= nil, `missing suite: {suiteName}`)

	local total = 0
	local caseNames = {}

	for caseName in pairs(suite.cases) do
		caseNames[caseName] = true
	end

	if suite.discoverCases then
		local discoverySandbox = sandbox.create(suite.mounts, suite.environment)
		discoverySandbox.install()
		discoverySandbox.globals.__currentFilePath = if suite.moduleIsFile then suite.module else nil

		local suiteModule = if suite.moduleIsFile
			then discoverySandbox.loadFileModule(suite.module)
			else discoverySandbox.require(suite.module)

		discoverySandbox.uninstall()

		for exportName, exportValue in pairs(suiteModule) do
			if type(exportName) == "string" and type(exportValue) == "function" then
				caseNames[exportName] = true
			end
		end
	end

	for _caseName in pairs(caseNames) do
		total += 1
	end

	return total
end

function m.runsScriptSelectionsInSeparateSandboxes()
	local results = runner.runSelections({
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/fixture-main/scripts/stateful_first.lua"),
			displayName = "stateful_first",
			mounts = fixtureMainMounts,
		},
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/fixture-main/scripts/stateful_second.lua"),
			displayName = "stateful_second",
			mounts = fixtureMainMounts,
		},
	})

	assert(results.success)
	assert(results.total == 2)
end

function m.passesSameArgsToMultipleScripts()
	local results = runner.runSelections({
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/runner/fixtures/script_args/first.lua"),
			displayName = "script_args_first",
			mounts = fixtureMainMounts,
			scriptArgs = { "1", "testString", "123" },
		},
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/runner/fixtures/script_args/second.lua"),
			displayName = "script_args_second",
			mounts = fixtureMainMounts,
			scriptArgs = { "1", "testString", "123" },
		},
	})

	assert(results.success)
	assert(results.total == 2)
end

function m.runsMixedSuiteAndScriptSelections()
	local expectedTotal = countSuiteCases(fixtureMainManifest, "test_module_requires") + 1
	local results = runner.runSelections({
		{
			kind = "suite",
			manifest = fixtureMainManifest,
			suiteName = "test_module_requires",
		},
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/fixture-main/scripts/uses_modules.lua"),
			displayName = "uses_modules",
			mounts = fixtureMainMounts,
			scriptArgs = { "1", "testString", "123" },
		},
	})

	assert(results.success)
	assert(results.total == expectedTotal)
end

function m.topLevelMissingChildReturnsNilDuringScriptLoad()
	local results = runner.runSelections({
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/runner/fixtures/top_level_yield/yielding_script.lua"),
			displayName = "yielding_script",
			mounts = fixtureMainMounts,
		},
	})

	assert(results.success)
	assert(results.total == 1)
end

function m.topLevelMissingChildReturnsNilDuringCaseExecution()
	local results = runner.runSelections({
		{
			kind = "suite",
			manifest = {
				tests = {
					yielding_case_suite = {
						module = "test/runner/fixtures/top_level_yield/yielding_case",
						cases = {
							waitsForMissingGenerated = {},
						},
						mounts = fixtureMainMounts,
					},
				},
			},
			suiteName = "yielding_case_suite",
		},
	})

	assert(results.success)
	assert(results.total == 1)
end

function m.topLevelSuiteModuleErrorsAbortImmediately()
	local ok, err = pcall(function()
		runner.runSelections({
			{
				kind = "suite",
				manifest = {
					tests = {
						invalid_suite_module = {
							module = "test/runner/fixtures/invalid_suite_module/top_level_error_suite",
							cases = {
								caseOne = {},
								caseTwo = {},
							},
							mounts = fixtureMainMounts,
							moduleIsFile = false,
							discoverCases = false,
						},
					},
				},
				suiteName = "invalid_suite_module",
			},
		})
	end)

	assert(not ok)
	assert(tostring(err):find("suite exploded at top level", 1, true) ~= nil)
end

return m
