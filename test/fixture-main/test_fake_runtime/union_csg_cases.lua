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

function m.unionAsyncRotatedBaseKeepsFrame()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 3600, 0) * CFrame.Angles(0, math.rad(45), 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 3602, 0)

	local u = a:UnionAsync({ b })
	assert(u ~= nil, "expected union result")
	u.Parent = workspace

	assertEqual(u.CFrame.RightVector, a.CFrame.RightVector)
	assertEqual(u.CFrame.UpVector, a.CFrame.UpVector)

	local hit =
		workspace:Raycast(Vector3.new(0, 3600, -10), Vector3.new(0, 0, 20), RaycastParams.new())
	assert(hit ~= nil, "solid ray through the rotated base must hit")
	assertEqual(hit.Instance, u)
end

function m.unionAsyncWedgeSource()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local wedge = env.Instance.new("Part", workspace)
	wedge.Shape = Enum.PartType.Wedge
	wedge.Size = Vector3.new(4, 4, 4)
	wedge.CFrame = CFrame.new(0, 2600, 0)

	local box = env.Instance.new("Part", workspace)
	box.Size = Vector3.new(4, 4, 4)
	box.CFrame = CFrame.new(5, 2595, 0)

	local u = wedge:UnionAsync({ box }, Enum.CollisionFidelity.PreciseConvexDecomposition)
	assert(u ~= nil, "expected union result")
	u.Parent = workspace
	assertEqual(u.Size, Vector3.new(9, 9, 4))

	-- X-ray at (y 2601.5, z 0): the wedge is void there (y > z at every
	-- x) and the box sits below the channel.
	u.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	assertEqual(
		workspace:Raycast(Vector3.new(-10, 2601.5, 0), Vector3.new(20, 0, 0)),
		nil
	)

	u.CollisionFidelity = Enum.CollisionFidelity.Box
	assert(
		workspace:Raycast(Vector3.new(-10, 2601.5, 0), Vector3.new(20, 0, 0)) ~= nil,
		"Box must hit the wedge notch volume"
	)
end

function m.unionAsyncBallSource()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local ball = env.Instance.new("Part", workspace)
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(4, 4, 4)
	ball.CFrame = CFrame.new(0, 2700, 0)

	local box = env.Instance.new("Part", workspace)
	box.Size = Vector3.new(4, 4, 4)
	box.CFrame = CFrame.new(3, 2700, 0)

	local u = ball:UnionAsync({ box }, Enum.CollisionFidelity.PreciseConvexDecomposition)
	assert(u ~= nil, "expected union result")
	u.Parent = workspace
	assertEqual(u.Size, Vector3.new(7, 4, 4))

	-- (-1.5, 2701.5) is outside the r=2 sphere and left of the box.
	u.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	assertEqual(
		workspace:Raycast(Vector3.new(-1.5, 2701.5, -10), Vector3.new(0, 0, 20)),
		nil
	)

	u.CollisionFidelity = Enum.CollisionFidelity.Box
	assert(
		workspace:Raycast(Vector3.new(-1.5, 2701.5, -10), Vector3.new(0, 0, 20)) ~= nil,
		"Box must hit the ball corner volume"
	)
end

function m.unionAsyncNestedSource()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 2800, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 2802, 0)

	local inner = a:UnionAsync({ b }, Enum.CollisionFidelity.PreciseConvexDecomposition)
	assert(inner ~= nil, "expected inner union")

	local c = env.Instance.new("Part", workspace)
	c.Size = Vector3.new(1, 1, 1)
	c.CFrame = CFrame.new(-1.5, 2803, 0)

	-- The block fills the inner union's notch.
	local u = inner:UnionAsync({ c }, Enum.CollisionFidelity.PreciseConvexDecomposition)
	assert(u ~= nil, "expected nested union")
	u.Parent = workspace
	inner:Destroy()
	a:Destroy()
	b:Destroy()
	c:Destroy()
	assertEqual(u.Size, Vector3.new(5, 6, 4))

	u.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
	local hit =
		workspace:Raycast(Vector3.new(-1.5, 2803, -10), Vector3.new(0, 0, 20))
	assert(hit ~= nil, "filled notch must hit")
	assertEqual(hit.Instance, u)
end

function m.subtractAsyncChain()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(6, 6, 6)
	a.CFrame = CFrame.new(0, 2900, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(2, 6, 6)
	b.CFrame = CFrame.new(-2, 2900, 0)

	local c = env.Instance.new("Part", workspace)
	c.Size = Vector3.new(2, 6, 6)
	c.CFrame = CFrame.new(2, 2900, 0)

	local u = a:SubtractAsync({ b, c })
	assert(u ~= nil, "expected middle slab")
	u.Parent = workspace
	assertEqual(u.Size, Vector3.new(2, 6, 6))
	assertEqual(u.CFrame.Position, Vector3.new(0, 2900, 0))
end

function m.unionAsyncThreeParts()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 3000, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 3002, 0)

	local c = env.Instance.new("Part", workspace)
	c.Size = Vector3.new(4, 4, 4)
	c.CFrame = CFrame.new(2, 3004, 0)

	local u = a:UnionAsync({ b, c })
	assert(u ~= nil, "expected triple union")
	u.Parent = workspace
	assertEqual(u.Size, Vector3.new(6, 8, 4))
	assertEqual(u.CFrame.Position, Vector3.new(1, 3002, 0))
end

function m.intersectAsyncDisjointReturnsNil()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 3100, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(50, 3100, 0)

	assertEqual(a:IntersectAsync({ b }), nil)
end

function m.unionAsyncDisjointSingle()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local c = env.Instance.new("Part", workspace)
	c.Size = Vector3.new(2, 2, 2)
	c.CFrame = CFrame.new(0, 3200, 0)

	local d = env.Instance.new("Part", workspace)
	d.Size = Vector3.new(2, 2, 2)
	d.CFrame = CFrame.new(50, 3200, 0)

	local u = c:UnionAsync({ d })
	assert(u ~= nil, "disjoint union must still produce one part")
	assertEqual(u.Size, Vector3.new(52, 2, 2))
	assertEqual(u.CFrame.Position, Vector3.new(25, 3200, 0))
end

function m.geometryServiceSplitThreeAndTouchingMerge()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local gs = env.game:GetService("GeometryService")
	assert(gs ~= nil, "expected GeometryService")

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(2, 2, 2)
	a.CFrame = CFrame.new(0, 3300, 0)

	local c = env.Instance.new("Part", workspace)
	c.Size = Vector3.new(2, 2, 2)
	c.CFrame = CFrame.new(50, 3300, 0)

	local e = env.Instance.new("Part", workspace)
	e.Size = Vector3.new(2, 2, 2)
	e.CFrame = CFrame.new(-50, 3300, 0)

	-- Nil options: SplitApart defaults to true, fidelity to Default.
	local split = gs:UnionAsync(a, { c, e })
	assertEqual(#split, 3)
	assertEqual(split[1].CollisionFidelity, Enum.CollisionFidelity.Default)

	-- Face-touching bodies stay one component.
	local left = env.Instance.new("Part", workspace)
	left.Size = Vector3.new(2, 2, 2)
	left.CFrame = CFrame.new(0, 3400, 0)

	local right = env.Instance.new("Part", workspace)
	right.Size = Vector3.new(2, 2, 2)
	right.CFrame = CFrame.new(2, 3400, 0)

	local merged = gs:UnionAsync(left, { right })
	assertEqual(#merged, 1)
	assertEqual(merged[1].Size, Vector3.new(4, 2, 2))
end

function m.unionAsyncRejectsBadOptions()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local a = env.Instance.new("Part", workspace)
	a.Size = Vector3.new(4, 4, 4)
	a.CFrame = CFrame.new(0, 3700, 0)

	local b = env.Instance.new("Part", workspace)
	b.Size = Vector3.new(4, 4, 4)
	b.CFrame = CFrame.new(1, 3702, 0)

	assert(not pcall(function()
		a:UnionAsync({ b }, "High")
	end), "bad fidelity must error")
	assert(not pcall(function()
		a:UnionAsync({ b }, Enum.CollisionFidelity.Box, "Fast")
	end), "bad render fidelity must error")

	local gs = env.game:GetService("GeometryService")
	assert(not pcall(function()
		gs:UnionAsync(a, { b }, { SplitApart = 1 })
	end), "non-boolean SplitApart must error")
	assert(not pcall(function()
		gs:UnionAsync(a, { b }, "nope")
	end), "non-table options must error")

	local flat = env.Instance.new("Part", workspace)
	flat.Size = Vector3.new(0, 2, 2)
	flat.CFrame = CFrame.new(0, 3710, 0)
	assert(not pcall(function()
		a:UnionAsync({ flat })
	end), "zero-size sources must error")
end

function m.geometryServiceSubtractAndIntersect()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local gs = env.game:GetService("GeometryService")
	assert(gs ~= nil, "expected GeometryService")

	local c = env.Instance.new("Part", workspace)
	c.Size = Vector3.new(4, 4, 4)
	c.CFrame = CFrame.new(0, 3500, 0)

	local d = env.Instance.new("Part", workspace)
	d.Size = Vector3.new(2, 4, 4)
	d.CFrame = CFrame.new(0, 3500, 0)

	local carved = gs:SubtractAsync(c, { d }, { SplitApart = false })
	assertEqual(#carved, 1)
	assertEqual(carved[1].Size, Vector3.new(4, 4, 4))

	local e = env.Instance.new("Part", workspace)
	e.Size = Vector3.new(4, 4, 4)
	e.CFrame = CFrame.new(0, 3510, 0)

	local f = env.Instance.new("Part", workspace)
	f.Size = Vector3.new(4, 4, 4)
	f.CFrame = CFrame.new(2, 3510, 0)

	local overlap = gs:IntersectAsync(e, { f })
	assertEqual(#overlap, 1)
	assertEqual(overlap[1].Size, Vector3.new(2, 4, 4))
end


function m.unionAndMeshAreCreatableBaseParts()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local u = env.Instance.new("UnionOperation", workspace)
	local mp = env.Instance.new("MeshPart", workspace)
	assert(u:IsA("BasePart"), "UnionOperation must be a BasePart")
	assert(mp:IsA("BasePart"), "MeshPart must be a BasePart")
	assertEqual(u.CollisionFidelity, Enum.CollisionFidelity.Box)
	assertEqual(mp.CollisionFidelity, Enum.CollisionFidelity.Box)
	assertEqual(mp.MeshId, "")
end

return m
