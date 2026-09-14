local TestHelpers = require("@test/test_helpers")

local assertClose = TestHelpers.assertClose
local assertEqual = TestHelpers.assertEqual

local m = {}

function m.unionAsyncBuildsConcaveUnion()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 100, 0)
	a.Material = Enum.Material.Wood

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 102, 0)

	local u = a:UnionAsync({ b }, Enum.CollisionFidelity.PreciseConvexDecomposition, Enum.RenderFidelity.Precise)
	assert(u ~= nil, "expected union result")
	u.Parent = workspace

	assertEqual(u.ClassName, "UnionOperation")
	assert(u:IsA("BasePart"), "union must be a BasePart")
	assert(u:IsA("PartOperation"), "union must be a PartOperation")
	assertEqual(u.Size, Vector3.new(5, 6, 4))
	assertEqual(u.CFrame.Position, Vector3.new(0.5, 101, 0))
	assertEqual(u.CollisionFidelity, Enum.CollisionFidelity.PreciseConvexDecomposition)
	assertEqual(u.RenderFidelity, Enum.RenderFidelity.Precise)
	assertEqual(u.Material, Enum.Material.Wood)

	-- Exact notch (outside both boxes, inside the bounding box): Precise
	-- misses, Box hits.
	assertEqual(
		workspace:Raycast(Vector3.new(-1.5, 103, -10), Vector3.new(0, 0, 20), RaycastParams.new()),
		nil
	)

	u.CollisionFidelity = Enum.CollisionFidelity.Box
	local notchHit =
		workspace:Raycast(Vector3.new(-1.5, 103, -10), Vector3.new(0, 0, 20), RaycastParams.new())
	assert(notchHit ~= nil, "Box fidelity must hit the notch bounding volume")
	assertEqual(notchHit.Instance, u)
end

function m.geometryServiceUnionReturnsArray()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 200, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 202, 0)

	local gs = env.game:GetService("GeometryService")
	assert(gs ~= nil, "expected GeometryService")

	local res = gs:UnionAsync(a, { b }, {
		CollisionFidelity = Enum.CollisionFidelity.Default,
		RenderFidelity = Enum.RenderFidelity.Automatic,
		SplitApart = false,
	})
	assertEqual(#res, 1)
	res[1].Parent = workspace
	assertEqual(res[1].ClassName, "UnionOperation")
	assertEqual(res[1].Size, Vector3.new(5, 6, 4))

	-- SplitApart defaults to true: disjoint bodies split.
	local c = env.Instance.new("Part", workspace)
	c.Size = Vector3.new(2, 2, 2)
	c.CFrame = CFrame.new(50, 200, 0)
	assertEqual(#gs:UnionAsync(a, { c }), 2)

	-- Mesh input yields mesh output.
	local mp = env.Instance.new("MeshPart", workspace)
	mp.Size = Vector3.new(2, 2, 2)
	mp.CFrame = CFrame.new(0, 210, 0)
	local mushed = gs:UnionAsync(mp, { a })
	assertEqual(#mushed, 2)
	assertEqual(mushed[1].ClassName, "MeshPart")
	assertEqual(mushed[2].ClassName, "MeshPart")
end

function m.subtractAsyncFullyConsumedReturnsNil()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 300, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(8, 8, 8)
	b.CFrame = CFrame.new(0, 300, 0)

	assertEqual(a:SubtractAsync({ b }), nil)

	local c = env.Instance.new("Part", workspace)
	c.Size = Vector3.new(4, 4, 4)
	c.CFrame = CFrame.new(0, 310, 0)

	local d = env.Instance.new("Part", workspace)
	d.Size = Vector3.new(2, 4, 4)
	d.CFrame = CFrame.new(0, 310, 0)

	local u = c:SubtractAsync({ d })
	assert(u ~= nil, "partial subtract must keep the walls")
	u.Parent = workspace
	assertEqual(u.Size, Vector3.new(4, 4, 4))
end

function m.intersectAsyncOverlapSize()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 400, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(2, 400, 0)

	local u = a:IntersectAsync({ b })
	assert(u ~= nil, "expected intersection result")
	u.Parent = workspace
	assertEqual(u.Size, Vector3.new(2, 4, 4))
	assertEqual(u.CFrame.Position, Vector3.new(1, 400, 0))
end

function m.unionAsyncRejectsInvalidSources()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 500, 0)

	assert(not pcall(function()
		a:UnionAsync({})
	end), "empty parts must error")

	local folder = env.Instance.new("Folder", workspace)
	assert(not pcall(function()
		a:UnionAsync({ folder })
	end), "non-part sources must error")
	assert(not pcall(function()
		folder:UnionAsync({ a })
	end), "UnionAsync on non-BasePart must error")
	assert(not pcall(function()
		a:UnionAsync({ workspace.Terrain })
	end), "terrain sources must error")

	local spawn = env.Instance.new("SpawnLocation", workspace)
	assert(not pcall(function()
		a:UnionAsync({ spawn })
	end), "spawn sources must error")
end

function m.clonePreservesUnionDecomposition()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 1000, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 1002, 0)

	local u = a:UnionAsync({ b }, Enum.CollisionFidelity.PreciseConvexDecomposition)
	assert(u ~= nil, "expected union result")
	u.Parent = workspace
	a:Destroy()
	b:Destroy()

	local copy = u:Clone()
	copy.Parent = workspace
	assertEqual(copy.ClassName, "UnionOperation")
	assertEqual(copy.Size, u.Size)
	assertEqual(copy.CollisionFidelity, Enum.CollisionFidelity.PreciseConvexDecomposition)
	u:Destroy()

	assertEqual(
		workspace:Raycast(Vector3.new(-1.5, 1003, -10), Vector3.new(0, 0, 20), RaycastParams.new()),
		nil
	)

	local hit =
		workspace:Raycast(Vector3.new(1, 1000, -10), Vector3.new(0, 0, 20), RaycastParams.new())
	assert(hit ~= nil, "clone must answer queries from its own decomposition")
	assertEqual(hit.Instance, copy)
end

return m
