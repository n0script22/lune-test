local TestHelpers = require("@test/test_helpers")

local assertEqual = TestHelpers.assertEqual
local assertClose = TestHelpers.assertClose

local m = {}

function m.workspaceAuthorityPropertiesHaveEngineDefaults()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.game:GetService("Workspace")

	assertEqual(workspace.AuthorityMode, "Automatic")
	assertEqual(workspace.UseFixedSimulation, "Disabled")
	assertEqual(workspace.SignalBehavior, "Default")
	assertEqual(workspace.NextGenerationReplication, "Disabled")
	assertEqual(workspace.StreamingEnabled, true)
end

function m.settingAuthorityModeServerAutoEnablesRequiredStack()
	local env = createEnvironment({
		activePlayers = {},
		datamodel = {
			AuthorityMode = "Server",
		},
	})
	local workspace = env.game:GetService("Workspace")

	assertEqual(workspace.AuthorityMode, "Server")
	assertEqual(workspace.NextGenerationReplication, "Enabled")
	assertEqual(workspace.SignalBehavior, "Deferred")
	assertEqual(workspace.UseFixedSimulation, "Enabled")
	assertEqual(workspace.StreamingEnabled, true)
end

function m.authorityEnumsAreExposed()
	local env = createEnvironment({
		activePlayers = {},
	})
	env:install()

	assertEqual(Enum.AuthorityMode.Server, "Server")
	assertEqual(Enum.AuthorityMode.Automatic, "Automatic")
	assertEqual(Enum.SignalBehavior.Deferred, "Deferred")
	assertEqual(Enum.SignalBehavior.Immediate, "Immediate")
	assertEqual(Enum.StepFrequency.Hz60, "Hz60")
	assertEqual(Enum.StepFrequency.Hz30, "Hz30")

	env:uninstall()
end

function m.bindToSimulationRequiresFixedSimulation()
	local env = createEnvironment({
		activePlayers = {},
	})
	local runService = env.game:GetService("RunService")

	local ok = pcall(function()
		runService:BindToSimulation(function() end)
	end)
	assertEqual(ok, false)
end

function m.bindToSimulationRunsAtFixedFrequencyIndependentOfFramerate()
	local env = createEnvironment({
		activePlayers = {},
		workspace = {
			UseFixedSimulation = "Enabled",
		},
	})
	local runService = env.game:GetService("RunService")

	local count60 = 0
	local dt60
	runService:BindToSimulation(function(dt)
		count60 += 1
		dt60 = dt
	end, "Hz60")

	local count30 = 0
	local dt30
	runService:BindToSimulation(function(dt)
		count30 += 1
		dt30 = dt
	end, "Hz30")

	env.scheduler:advance(1)

	assertEqual(count60, 60)
	assertEqual(count30, 30)
	assertClose(dt60, 1 / 60, 1e-6, "Hz60 dt")
	assertClose(dt30, 1 / 30, 1e-6, "Hz30 dt")
end

function m.bindToSimulationRespectsPriorityOrder()
	local env = createEnvironment({
		activePlayers = {},
		workspace = {
			UseFixedSimulation = "Enabled",
		},
	})
	local runService = env.game:GetService("RunService")

	local order = {}
	runService:BindToSimulation(function()
		table.insert(order, "low-prio")
	end, "Hz60", 200)
	runService:BindToSimulation(function()
		table.insert(order, "high-prio")
	end, "Hz60", 50)

	env.scheduler:advance(1 / 60)

	assertEqual(order[1], "high-prio")
	assertEqual(order[2], "low-prio")
end

function m.isResimulatingAndPredictionEventsExist()
	local env = createEnvironment({
		activePlayers = {},
		workspace = {
			UseFixedSimulation = "Enabled",
		},
	})
	local runService = env.game:GetService("RunService")

	assertEqual(runService:IsResimulating(), false)
	assertEqual(type(runService.Misprediction.Connect), "function")
	assertEqual(type(runService.Rollback.Connect), "function")
end

function m.simBoundFunctionsRejectUnsynchronizedWrites()
	local env = createEnvironment({
		activePlayers = {},
		workspace = {
			UseFixedSimulation = "Enabled",
		},
	})
	local runService = env.game:GetService("RunService")
	local part = env.Instance.new("Part", env.game:GetService("Workspace"))

	local writeErr
	local attrOk
	runService:BindToSimulation(function()
		local ok, err = pcall(function()
			part.Transparency = 0.5
		end)
		if writeErr == nil then
			writeErr = ok
		end
		local okAttr = pcall(function()
			part:SetAttribute("Sync", 1)
		end)
		if attrOk == nil then
			attrOk = okAttr
		end
	end, "Hz60")

	env.scheduler:advance(1 / 60)

	assertEqual(writeErr, false)
	assertEqual(attrOk, true)
end

function m.simBoundFunctionsAllowPreParentWritesForStitching()
	local env = createEnvironment({
		activePlayers = {},
		workspace = {
			UseFixedSimulation = "Enabled",
		},
	})
	local runService = env.game:GetService("RunService")
	local workspace = env.game:GetService("Workspace")

	local beforeOk
	runService:BindToSimulation(function()
		local p = env.Instance.new("Part")
		local ok = pcall(function()
			p.Name = "PredictedPart"
			p.Transparency = 0.5
		end)
		if beforeOk == nil then
			beforeOk = ok
		end
		p.Parent = workspace
	end, "Hz60")

	env.scheduler:advance(1 / 60)

	assertEqual(beforeOk, true)
	assertEqual(workspace:FindFirstChild("PredictedPart") ~= nil, true)
end

function m.attributeReplicationFilterDropsNonReplicable()
	local env = createEnvironment({
		activePlayers = {},
		workspace = {
			UseFixedSimulation = "Enabled",
		},
	})
	local runService = env.game:GetService("RunService")
	local part = env.Instance.new("Part", env.game:GetService("Workspace"))

	runService:BindToSimulation(function()
		part:SetAttribute("SyncOk", 1)
		part:SetAttribute(string.rep("n", 51), 2)
		part:SetAttribute("LongString", string.rep("x", 51))
	end, "Hz60")

	env.scheduler:advance(1 / 60)

	local replicated = env:getReplicatedAttributes(part)
	assertEqual(replicated.SyncOk, 1)
	assertEqual(replicated[string.rep("n", 51)], nil)
	assertEqual(replicated.LongString, nil)
	-- Local values still set; replication drops them
	assertEqual(part:GetAttribute(string.rep("n", 51)), 2)
end

function m.stitchedInstancesRequireParentingSameFrame()
	local env = createEnvironment({
		activePlayers = {},
		workspace = {
			UseFixedSimulation = "Enabled",
		},
	})
	local runService = env.game:GetService("RunService")

	runService:BindToSimulation(function()
		local p = env.Instance.new("Part")
		p.Name = "Orphan"
		-- Intentionally not parenting: must error at end of tick
	end, "Hz60")

	local ok = pcall(function()
		env.scheduler:advance(1 / 60)
	end)
	assertEqual(ok, false)
end

function m.rollbackResimulatesBoundFunctionsWithFlagAndEvents()
	local env = createEnvironment({
		activePlayers = {},
		workspace = {
			AuthorityMode = "Server",
		},
	})
	local runService = env.game:GetService("RunService")
	local part = env.Instance.new("Part", env.game:GetService("Workspace"))
	part:SetAttribute("Health", 100)

	local simRuns = 0
	local sawResimulating = nil
	runService:BindToSimulation(function()
		simRuns += 1
		if simRuns > 1 then
			sawResimulating = runService:IsResimulating()
		end
		local h = part:GetAttribute("Health")
		part:SetAttribute("Health", h - 10)
	end, "Hz60")

	env.scheduler:advance(2 / 60)

	local rollbackTime
	local mispredicted
	runService.Rollback:Connect(function(t)
		rollbackTime = t
	end)
	runService.Misprediction:Connect(function(t, instances, stats)
		mispredicted = { t = t, instances = instances, stats = stats }
	end)

	local runsBefore = simRuns
	env:forceMispredict({
		time = env:getGameTime() - 1 / 60,
		authoritative = {
			{ instance = part, attributes = { Health = 100 } },
		},
	})

	assertEqual(runService:IsResimulating(), false)
	assertEqual(sawResimulating, true)
	assertEqual(simRuns > runsBefore, true)
	assertEqual(rollbackTime ~= nil, true)
	assertEqual(mispredicted ~= nil, true)
end

return m
