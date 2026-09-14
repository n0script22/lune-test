local TestHelpers = require("@test/test_helpers")

local assertEqual = TestHelpers.assertEqual
local assertClose = TestHelpers.assertClose

local m = {}

function m.taskWaitReturnsActualElapsedOnOvershoot()
	local env = createEnvironment({
		activePlayers = {},
	})
	local elapsed

	env.task.spawn(function()
		elapsed = env.task.wait(1)
	end)
	env.scheduler:flush()
	assertEqual(elapsed, nil)

	-- Overshoot: advance 1.5 for a 1s wait; engine returns actual elapsed
	env.scheduler:advance(1.5)
	assertClose(elapsed, 1.5, 1e-6, "task.wait actual elapsed")
end

function m.steppedTimeArgMatchesVirtualClock()
	local env = createEnvironment({
		activePlayers = {},
	})
	env:install()

	local steppedTime
	local steppedDt
	game:GetService("RunService").Stepped:Connect(function(t, dt)
		steppedTime = t
		steppedDt = dt
	end)

	env.scheduler:advance(1)

	assertClose(steppedTime, time(), 1e-6, "Stepped time == time()")
	assertClose(steppedTime, workspace.DistributedGameTime, 1e-6, "Stepped time == DistributedGameTime")
	assertClose(steppedDt, 1, 1e-6, "Stepped dt == advance dt")

	env:uninstall()
end

function m.preAndPostSimulationFireWithAdvanceDt()
	local env = createEnvironment({
		activePlayers = {},
	})
	env:install()

	local preDt
	local postDt
	local runService = game:GetService("RunService")
	runService.PreSimulation:Connect(function(dt)
		preDt = dt
	end)
	runService.PostSimulation:Connect(function(dt)
		postDt = dt
	end)

	env.scheduler:advance(0.25)

	assertClose(preDt, 0.25, 1e-6, "PreSimulation dt == advance dt")
	assertClose(postDt, 0.25, 1e-6, "PostSimulation dt == advance dt")

	env:uninstall()
end

function m.serverTimeRateAndFixedQuantization()
	local env = createEnvironment({
		activePlayers = {},
		virtualClock = {
			unixBase = 1700000000,
		},
	})
	env:install()

	local server0 = workspace:GetServerTimeNow()
	env.scheduler:advance(0.5)
	local server1 = workspace:GetServerTimeNow()
	env.scheduler:advance(0.5)
	local server2 = workspace:GetServerTimeNow()

	assertClose(server1 - server0, 0.5, 0.5 * 0.006 + 1e-6, "GetServerTimeNow tracks wall rate within 0.6%")
	assert(server2 >= server1, "GetServerTimeNow is monotonic")

	env:uninstall()

	local fixed = createEnvironment({
		activePlayers = {},
		workspace = {
			UseFixedSimulation = "Enabled",
		},
	})
	fixed:install()

	-- 0.025s holds 1 full 1/60 tick with remainder carried; time() is fixed-stepped
	fixed.scheduler:advance(0.025)
	assertClose(time(), 1 / 60, 1e-9, "time() advances in fixed steps when UseFixedSimulation is enabled")
	assertClose(workspace.DistributedGameTime, 0.025, 1e-9, "DistributedGameTime stays on wall time")

	fixed:uninstall()
end

function m.osDateAndDifftimeFollowVirtualClock()
	local env = createEnvironment({
		activePlayers = {},
		virtualClock = {
			unixBase = 1700000000,
		},
	})
	env:install()

	local t0 = os.time()
	env.scheduler:advance(2)
	local t1 = os.time()
	assertEqual(os.difftime(t1, t0), 2, "os.difftime follows virtual clock")

	local dated = os.date("!*t", t1)
	assertEqual(dated.year, 2023, "os.date formats virtual time")

	env:uninstall()
end

return m
