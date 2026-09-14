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

function m.bindToAnimationRunsAtFixedFrequency()
	local env = createEnvironment({
		activePlayers = {},
		workspace = {
			UseFixedSimulation = "Enabled",
		},
	})
	local runService = env.game:GetService("RunService")

	local count = 0
	local dt
	runService:BindToAnimation(function(step)
		count += 1
		dt = step
	end, "Hz60")

	env.scheduler:advance(1)

	assertEqual(count, 60)
	assertClose(dt, 1 / 60, 1e-6, "BindToAnimation Hz60 dt")
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
	local readOk
	local destroyErr
	local parentWriteErr
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
		local okRead = pcall(function()
			local _ = part.Transparency
			local _ = part.Name
		end)
		if readOk == nil then
			readOk = okRead
		end
		local okDestroy = pcall(function()
			part:Destroy()
		end)
		if destroyErr == nil then
			destroyErr = okDestroy
		end
		local okParent = pcall(function()
			part.Parent = nil
		end)
		if parentWriteErr == nil then
			parentWriteErr = okParent
		end
	end, "Hz60")

	env.scheduler:advance(1 / 60)

	assertEqual(writeErr, false)
	assertEqual(attrOk, true)
	assertEqual(readOk, true)
	assertEqual(destroyErr, false)
	assertEqual(parentWriteErr, false)
	assertEqual(part.Parent ~= nil, true)
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

function m.attributeReplicationFilterDropsBeyond64()
	local env = createEnvironment({
		activePlayers = {},
		workspace = {
			UseFixedSimulation = "Enabled",
		},
	})
	local part = env.Instance.new("Part", env.game:GetService("Workspace"))

	for i = 1, 65 do
		part:SetAttribute("A" .. tostring(i), i)
	end

	local replicated = env:getReplicatedAttributes(part)
	local count = 0
	for _ in pairs(replicated) do
		count += 1
	end

	assertEqual(count, 64)
	assertEqual(part:GetAttribute("A65"), 65)
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

function m.stitchedIdsMatchAcrossSidesIncludingClone()
	local function buildSide()
		local env = createEnvironment({
			activePlayers = {},
			workspace = {
				UseFixedSimulation = "Enabled",
			},
		})
		local workspace = env.game:GetService("Workspace")
		local template = env.Instance.new("Part", workspace)
		template.Name = "Template"
		local guids = {}
		env.game:GetService("RunService"):BindToSimulation(function()
			local fresh = env.Instance.new("Part")
			fresh.Name = "Fresh"
			fresh.Parent = workspace
			local cloned = template:Clone()
			cloned.Name = "Cloned"
			cloned.Parent = workspace
			local existing = env.Instance.fromExisting(template)
			existing.Name = "Existing"
			existing.Parent = workspace
			guids.fresh = fresh._predictedGuid
			guids.cloned = cloned._predictedGuid
			guids.existing = existing._predictedGuid
		end, "Hz60")
		env.scheduler:advance(1 / 60)
		return guids
	end

	local left = buildSide()
	local right = buildSide()

	assertEqual(left.fresh ~= nil, true)
	assertEqual(left.fresh, right.fresh)
	assertEqual(left.cloned, right.cloned)
	assertEqual(left.existing, right.existing)
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
	local targetTime = env:getGameTime() - 1 / 60
	env:forceMispredict({
		time = targetTime,
		authoritative = {
			{ instance = part, attributes = { Health = 100 } },
		},
	})

	assertEqual(runService:IsResimulating(), false)
	assertEqual(sawResimulating, true)
	assertEqual(simRuns > runsBefore, true)
	assertEqual(rollbackTime, targetTime)
	assertEqual(mispredicted ~= nil, true)
	assertEqual(mispredicted.t, targetTime)
	assertEqual(mispredicted.instances[1].Instance, part)
	-- Predicted Health was 80 after two ticks of -10 from 100
	assertEqual(mispredicted.instances[1].Attributes.Health.Predicted, 80)
	assertEqual(mispredicted.instances[1].Attributes.Health.Authoritative, 100)
	assertClose(mispredicted.stats.ResimulationTime, 1 / 60, 1e-9, "ResimulationTime covers replayed ticks")
	-- Resimulation re-applied the sim decrement onto authoritative state
	assertEqual(part:GetAttribute("Health"), 90)
end

function m.inspectPredictionReportsSimState()
	local env = createEnvironment({
		activePlayers = {},
		workspace = {
			UseFixedSimulation = "Enabled",
		},
	})
	local part = env.Instance.new("Part", env.game:GetService("Workspace"))
	part:SetAttribute("Health", 100)
	env.game:GetService("RunService"):BindToSimulation(function() end, "Hz60")

	env.scheduler:advance(1 / 60)

	local info = env:inspectPrediction()
	assertEqual(info.simTick, 1)
	assertClose(info.simTime, 1 / 60, 1e-9, "inspect simTime")
	assertEqual(info.isResimulating, false)
	assertEqual(info.predictedInstanceCount >= 1, true)
end

return m
