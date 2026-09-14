local TestHelpers = require("@test/test_helpers")

local assertClose = TestHelpers.assertClose
local assertEqual = TestHelpers.assertEqual

local m = {}

function m.raycastUnionHullCoversNotchWhileDefaultMisses()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 100, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 102, 0)

	local u = a:UnionAsync({ b })
	assert(u ~= nil, "expected union result")
	u.Parent = workspace
	a:Destroy()
	b:Destroy()

	-- (-1.5, 102.5) is outside both boxes but inside the convex hull rind.
	local notchOrigin = Vector3.new(-1.5, 102.5, -10)
	local notchDirection = Vector3.new(0, 0, 20)

	u.CollisionFidelity = Enum.CollisionFidelity.Box
	assert(
		workspace:Raycast(notchOrigin, notchDirection, RaycastParams.new()) ~= nil,
		"Box must hit the notch volume"
	)

	u.CollisionFidelity = Enum.CollisionFidelity.Hull
	assert(
		workspace:Raycast(notchOrigin, notchDirection, RaycastParams.new()) ~= nil,
		"Hull must cover the notch rind"
	)

	u.CollisionFidelity = Enum.CollisionFidelity.Default
	assertEqual(workspace:Raycast(notchOrigin, notchDirection, RaycastParams.new()), nil)

	u.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	assertEqual(workspace:Raycast(notchOrigin, notchDirection, RaycastParams.new()), nil)

	-- Solid rays hit at every fidelity with face normal and position.
	for _, fidelity in ipairs({ "Box", "Hull", "Default", "PreciseConvexDecomposition" }) do
		u.CollisionFidelity = fidelity
		local hit =
			workspace:Raycast(Vector3.new(1, 100, -10), Vector3.new(0, 0, 20), RaycastParams.new())
		assert(hit ~= nil, `solid ray must hit at {fidelity}`)
		assertEqual(hit.Instance, u)
		assertClose(hit.Position.X, 1, 1e-6, "solid hit x")
		assertClose(hit.Position.Y, 100, 1e-6, "solid hit y")
		assertClose(hit.Position.Z, -2, 1e-6, "solid hit z")
		assertEqual(hit.Normal, Vector3.new(0, 0, -1))
	end
end

function m.spherecastVsUnionNotchMatchesRay()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 600, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 602, 0)

	local u = a:UnionAsync({ b }, Enum.CollisionFidelity.PreciseConvexDecomposition)
	assert(u ~= nil, "expected union result")
	u.Parent = workspace
	a:Destroy()
	b:Destroy()

	u.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	assertEqual(
		workspace:Spherecast(Vector3.new(-1.5, 603, -10), 0.25, Vector3.new(0, 0, 20)),
		nil
	)

	u.CollisionFidelity = Enum.CollisionFidelity.Box
	local boxHit =
		workspace:Spherecast(Vector3.new(-1.5, 603, -10), 0.25, Vector3.new(0, 0, 20))
	assert(boxHit ~= nil, "Box fidelity must hit the notch volume")
	assertEqual(boxHit.Instance, u)
	assertEqual(boxHit.Normal, Vector3.new(0, 0, -1))
	assertClose(boxHit.Distance, 7.75, 1e-6, "notch distance")

	u.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	local hit = workspace:Spherecast(Vector3.new(1, 600, -10), 0.5, Vector3.new(0, 0, 20))
	assert(hit ~= nil, "solid spherecast must hit")
	assertEqual(hit.Instance, u)
	assertClose(hit.Distance, 7.5, 1e-6, "solid distance")
	assertClose(hit.Position.Z, -2, 1e-6, "solid hit z")
	assertEqual(hit.Normal, Vector3.new(0, 0, -1))
end

function m.blockcastVsUnionHullHitsNotch()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 600, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 602, 0)

	local u = a:UnionAsync({ b })
	assert(u ~= nil, "expected union result")
	u.Parent = workspace
	a:Destroy()
	b:Destroy()

	u.CollisionFidelity = Enum.CollisionFidelity.Hull
	local hullHit = workspace:Blockcast(
		CFrame.new(-1.5, 602.75, -10),
		Vector3.new(0.5, 0.5, 0.5),
		Vector3.new(0, 0, 20),
		RaycastParams.new()
	)
	assert(hullHit ~= nil, "Hull must cover the notch rind")
	assertEqual(hullHit.Instance, u)

	u.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	assertEqual(
		workspace:Blockcast(
			CFrame.new(-1.5, 602.75, -10),
			Vector3.new(0.5, 0.5, 0.5),
			Vector3.new(0, 0, 20),
			RaycastParams.new()
		),
		nil
	)

	local solidHit = workspace:Blockcast(
		CFrame.new(1, 600, -10),
		Vector3.new(1, 1, 1),
		Vector3.new(0, 0, 20),
		RaycastParams.new()
	)
	assert(solidHit ~= nil, "solid blockcast must hit")
	assertEqual(solidHit.Instance, u)
	assertClose(solidHit.Distance, 7.5, 1e-6, "solid distance")
	assertClose(solidHit.Position.Z, -2, 1e-6, "solid hit z")
	assertEqual(solidHit.Normal, Vector3.new(0, 0, -1))
end

function m.shapecastWedgeCasterVsUnionTarget()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 700, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 702, 0)

	local u = a:UnionAsync({ b })
	assert(u ~= nil, "expected union result")
	u.Parent = workspace
	a:Destroy()
	b:Destroy()

	local cast = env.Instance.new("Part", workspace)
	cast.Shape = Enum.PartType.Wedge
	cast.Size = Vector3.new(0.5, 0.5, 0.5)
	cast.CFrame = CFrame.new(-1.5, 703, -10)

	u.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	assertEqual(workspace:Shapecast(cast, Vector3.new(0, 0, 20), RaycastParams.new()), nil)

	u.CollisionFidelity = Enum.CollisionFidelity.Box
	local hit = workspace:Shapecast(cast, Vector3.new(0, 0, 20), RaycastParams.new())
	assert(hit ~= nil, "Box fidelity must hit the notch volume")
	assertEqual(hit.Instance, u)
end

function m.shapecastUnionCasterNotchPassesThrough()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 800, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 802, 0)

	local cast = a:UnionAsync({ b }, Enum.CollisionFidelity.PreciseConvexDecomposition)
	assert(cast ~= nil, "expected union caster")
	cast.Parent = workspace
	a:Destroy()
	b:Destroy()

	-- Post threading the caster notch: the exact caster passes, the box
	-- caster hits early.
	local post = env.Instance.new("Part", workspace)
	post.Size = Vector3.new(0.5, 0.5, 4)
	post.CFrame = CFrame.new(-1.5, 803, 5)

	cast.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	assertEqual(workspace:Shapecast(cast, Vector3.new(0, 0, 20), RaycastParams.new()), nil)

	cast.CollisionFidelity = Enum.CollisionFidelity.Box
	local boxHit = workspace:Shapecast(cast, Vector3.new(0, 0, 20), RaycastParams.new())
	assert(boxHit ~= nil, "box caster must hit the post")
	assertEqual(boxHit.Instance, post)

	-- A solid wall still stops the exact caster.
	local wall = env.Instance.new("Part", workspace)
	wall.Size = Vector3.new(4, 4, 4)
	wall.CFrame = CFrame.new(1, 800, 15)
	post:Destroy()

	cast.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	local wallHit = workspace:Shapecast(cast, Vector3.new(0, 0, 20), RaycastParams.new())
	assert(wallHit ~= nil, "exact caster must hit a solid wall")
	assertEqual(wallHit.Instance, wall)
	assertClose(wallHit.Distance, 11, 1e-6, "wall distance")
	assertEqual(wallHit.Normal, Vector3.new(0, 0, -1))
end

function m.sweepExactTouchUnionCountsAsHit()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 900, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 902, 0)

	local u = a:UnionAsync({ b }, Enum.CollisionFidelity.PreciseConvexDecomposition)
	assert(u ~= nil, "expected union result")
	u.Parent = workspace
	a:Destroy()
	b:Destroy()

	-- Engine (verified against Studio): sweeps count exact-touch (t = 1) as
	-- hits against unions, while rays exclude it.
	u.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	local blockHit = workspace:Blockcast(
		CFrame.new(1, 900, 6.5),
		Vector3.new(1, 1, 1),
		Vector3.new(0, 0, -4),
		RaycastParams.new()
	)
	assert(blockHit ~= nil, "exact-touch blockcast must hit the union")
	assertEqual(blockHit.Instance, u)

	local sphereHit =
		workspace:Spherecast(Vector3.new(1, 900, 6), 1, Vector3.new(0, 0, -3))
	assert(sphereHit ~= nil, "exact-touch spherecast must hit the union")
	assertEqual(sphereHit.Instance, u)

	assertEqual(
		workspace:Raycast(Vector3.new(1, 900, 10), Vector3.new(0, 0, -8), RaycastParams.new()),
		nil
	)

	-- Plain-part twins pin the shared sweep cores (unchanged behavior).
	local wall = env.Instance.new("Part", workspace)
	wall.Size = Vector3.new(4, 4, 4)
	wall.CFrame = CFrame.new(30, 900, 0)

	assert(
		workspace:Blockcast(
			CFrame.new(30, 900, 6.5),
			Vector3.new(1, 1, 1),
			Vector3.new(0, 0, -4),
			RaycastParams.new()
		) ~= nil,
		"exact-touch blockcast must hit a part"
	)
	assert(
		workspace:Spherecast(Vector3.new(30, 900, 6), 1, Vector3.new(0, 0, -3)) ~= nil,
		"exact-touch spherecast must hit a part"
	)
end

function m.shapecastUnionCasterVsBallTarget()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 1800, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 1802, 0)

	local cast = a:UnionAsync({ b }, Enum.CollisionFidelity.PreciseConvexDecomposition)
	assert(cast ~= nil, "expected union caster")
	cast.Parent = workspace
	a:Destroy()
	b:Destroy()

	local ball = env.Instance.new("Part", workspace)
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2, 2, 2)
	ball.CFrame = CFrame.new(1, 1800, 10)

	cast.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	local hit = workspace:Shapecast(cast, Vector3.new(0, 0, 30), RaycastParams.new())
	assert(hit ~= nil, "union caster must hit the ball")
	assertEqual(hit.Instance, ball)
	assertClose(hit.Distance, 7, 1e-6, "ball distance")
	assertEqual(hit.Normal, Vector3.new(0, 0, -1))
end

return m
