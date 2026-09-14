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

function m.allTimeSourcesAdvanceTogetherOnOneVirtualClock()
	local env = createEnvironment({
		activePlayers = {},
		virtualClock = {
			unixBase = 1700000000,
		},
	})
	env:install()

	local clock0 = os.clock()
	local time0 = os.time()
	local tick0 = tick()
	local gameTime0 = time()
	local dist0 = workspace.DistributedGameTime
	local server0 = workspace:GetServerTimeNow()

	env.scheduler:advance(1.5)

	assertClose(os.clock() - clock0, 1.5, 1e-6, "os.clock advances with virtual clock")
	assertEqual(os.time() - time0, 1, "os.time advances 1s (int) after 1.5s virtual")
	assertClose(tick() - tick0, 1.5, 1e-6, "tick advances with virtual clock")
	assertClose(time() - gameTime0, 1.5, 1e-6, "time() advances with virtual clock")
	assertClose(workspace.DistributedGameTime - dist0, 1.5, 1e-6, "DistributedGameTime advances")
	assertClose(workspace:GetServerTimeNow() - server0, 1.5, 1e-6, "GetServerTimeNow advances")

	env:uninstall()
end

function m.steppedTimeArgMatchesVirtualClockAndTaskResume()
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

	local resumed
	task.spawn(function()
		resumed = task.wait(1)
	end)
	env.scheduler:flush()
	env.scheduler:advance(1)

	assertClose(steppedTime, time(), 1e-6, "Stepped time == time()")
	assertClose(steppedTime, workspace.DistributedGameTime, 1e-6, "Stepped time == DistributedGameTime")
	assertClose(steppedDt, 1, 1e-6, "Stepped dt == advance dt")
	assertClose(resumed, 1, 1e-6, "task.wait resumes with actual elapsed")

	env:uninstall()
end

function m.firingHeartbeatAdvancesSameClock()
	local env = createEnvironment({
		activePlayers = {},
	})
	env:install()

	local hbDt
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		hbDt = dt
	end)

	game:GetService("RunService").Heartbeat:Fire(0.25)

	assertClose(time(), 0.25, 1e-6, "Heartbeat:Fire advances time()")
	assertClose(workspace.DistributedGameTime, 0.25, 1e-6, "Heartbeat:Fire advances DistributedGameTime")
	assertClose(hbDt, 0.25, 1e-6, "Heartbeat listener sees fired dt")

	env:uninstall()
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
