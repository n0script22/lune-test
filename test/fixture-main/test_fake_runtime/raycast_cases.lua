local TestHelpers = require("@test/test_helpers")

local assertClose = TestHelpers.assertClose
local assertEqual = TestHelpers.assertEqual

local m = {}

function m.raycastHitsAxisAlignedPart()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Name = "Wall"
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new())

	assert(hit ~= nil, "expected ray to hit wall part")
	assertEqual(hit.Instance, part)
	assertEqual(hit.Position, Vector3.new(4, 0, 0))
	assertClose(hit.Distance, 4, 1e-4, "distance")
	assertEqual(hit.Normal, Vector3.new(-1, 0, 0))
end

function m.raycastReturnsClosestPart()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local nearPart = env.Instance.new("Part", workspace)
	nearPart.Name = "Near"
	nearPart.Position = Vector3.new(5, 0, 0)
	nearPart.Size = Vector3.new(2, 2, 2)

	local farPart = env.Instance.new("Part", workspace)
	farPart.Name = "Far"
	farPart.Position = Vector3.new(9, 0, 0)
	farPart.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected a hit")
	assertEqual(hit.Instance, nearPart)
	assertClose(hit.Distance, 4, 1e-4, "distance")
end

function m.raycastHitsRotatedPart()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Size = Vector3.new(2, 2, 4)
	part.CFrame = CFrame.new(5, 0, 0) * CFrame.Angles(0, math.rad(90), 0)

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected ray to hit rotated part")
	assertEqual(hit.Instance, part)
	assertClose(hit.Distance, 3, 1e-3, "distance")
	assertClose(hit.Position.X, 3, 1e-3, "hit x")
end

function m.workspaceHasTerrainSingleton()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	assert(workspace.Terrain ~= nil, "expected Workspace.Terrain")
	assert(workspace.Terrain:IsA("BasePart"))
	assertEqual(workspace.Terrain.ClassName, "Terrain")
end

function m.raycastHitsTerrainGround()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace.Terrain.Position = Vector3.new(0, -6, 0)
	workspace.Terrain.Size = Vector3.new(100, 2, 100)

	local hit = workspace:Raycast(Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), RaycastParams.new())
	assert(hit ~= nil, "expected ray to hit terrain ground")
	assertEqual(hit.Instance, workspace.Terrain)
	assertClose(hit.Position.Y, -5, 1e-3, "hit y")
end

function m.raycastIgnoreWaterSkipsWaterTerrain()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace.Terrain.Position = Vector3.new(0, -6, 0)
	workspace.Terrain.Size = Vector3.new(100, 2, 100)
	workspace.Terrain.Material = Enum.Material.Water

	local waterParams = RaycastParams.new()
	waterParams.IgnoreWater = true
	assertEqual(workspace:Raycast(Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), waterParams), nil)

	local hit = workspace:Raycast(Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), RaycastParams.new())
	assert(hit ~= nil, "expected to hit water terrain when not ignoring water")
	assertEqual(hit.Instance, workspace.Terrain)
end

function m.raycastRejectsInvalidArguments()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local okOrigin = pcall(function()
		workspace:Raycast("not-a-vector", Vector3.new(1, 0, 0))
	end)
	assert(not okOrigin, "expected error for non-Vector3 origin")

	local okDirection = pcall(function()
		workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(0, 0, 0))
	end)
	assert(okDirection, "zero direction should miss, not error")
	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)), nil)
end

function m.raycastWorksWithoutParams()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0))
	assert(hit ~= nil, "expected ray without params to hit part")
	assertEqual(hit.Instance, part)

	local sphereHit = workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0))
	assert(sphereHit ~= nil, "expected sphere without params to hit part")
	assertEqual(sphereHit.Instance, part)
end

-- Core geometry hardening: inside-origin, parallel-slab, back/top faces,
-- t=1 boundary, zero-size skip, material propagation, decorative props,
-- workspace isolation, nested hierarchy, terrain volume.

function m.raycastOriginInsidePartPassesThrough()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine (verified against Studio): a ray starting inside a part
	-- ignores that part instead of reporting a zero-distance hit.
	local inner = env.Instance.new("Part", workspace)
	inner.Position = Vector3.new(0, 0, 0)
	inner.Size = Vector3.new(4, 4, 4)

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new()), nil)

	-- ...but still hits parts beyond the containing one.
	local beyond = env.Instance.new("Part", workspace)
	beyond.Position = Vector3.new(9, 0, 0)
	beyond.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected to see past the containing part")
	assertEqual(hit.Instance, beyond)
	assertClose(hit.Distance, 8, 1e-4, "distance")
end

function m.raycastOriginInsideBallPassesThrough()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local ball = env.Instance.new("Part", workspace)
	ball.Position = Vector3.new(0, 0, 0)
	ball.Size = Vector3.new(4, 4, 4)
	ball.Shape = Enum.PartType.Ball

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new()), nil)
end

function m.raycastParallelOutsideSlabMisses()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	-- Ray travels along X at Y=5, parallel to X faces but outside Y slab.
	assertEqual(workspace:Raycast(Vector3.new(0, 5, 0), Vector3.new(10, 0, 0), RaycastParams.new()), nil)
end

function m.raycastParallelInsideSlabHits()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 10, 2)

	-- Ray travels along Y inside the X/Z slabs; must hit top/bottom via slab logic.
	local hit = workspace:Raycast(Vector3.new(5, -10, 0), Vector3.new(0, 30, 0), RaycastParams.new())
	assert(hit ~= nil, "expected parallel-inside hit")
	assertEqual(hit.Instance, part)
	assertEqual(hit.Normal, Vector3.new(0, -1, 0))
end

function m.raycastBackSideNormalIsPositiveX()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Raycast(Vector3.new(10, 0, 0), Vector3.new(-10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected back-side hit")
	assertEqual(hit.Instance, part)
	assertEqual(hit.Position, Vector3.new(6, 0, 0))
	assertEqual(hit.Normal, Vector3.new(1, 0, 0))
	assertClose(hit.Distance, 4, 1e-4, "distance")
end

function m.raycastTopFaceNormal()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(0, 5, 0)
	part.Size = Vector3.new(4, 2, 4)

	local hit = workspace:Raycast(Vector3.new(0, 10, 0), Vector3.new(0, -10, 0), RaycastParams.new())
	assert(hit ~= nil, "expected top-face hit")
	assertEqual(hit.Instance, part)
	assertEqual(hit.Normal, Vector3.new(0, 1, 0))
	assertClose(hit.Position.Y, 6, 1e-4, "hit y")
end

function m.raycastDistanceBoundaryHitsAtOneMissesBeyond()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	-- Entry face at x=4. Engine (verified against Studio) excludes hits
	-- at exactly t=1: a direction of exactly 4 misses, 4.1 hits.
	local touching = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(4, 0, 0), RaycastParams.new())
	assertEqual(touching, nil)

	local reaching = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(4.1, 0, 0), RaycastParams.new())
	assert(reaching ~= nil, "expected just-past-boundary to hit")

	local short = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(3.9, 0, 0), RaycastParams.new())
	assertEqual(short, nil)
end

function m.raycastSkipsZeroSizeParts()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local flat = env.Instance.new("Part", workspace)
	flat.Position = Vector3.new(5, 0, 0)
	flat.Size = Vector3.new(0, 2, 2)

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new())
	assertEqual(hit, nil)
end

function m.raycastPropagatesNonDefaultMaterial()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.Material = Enum.Material.Wood

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected hit")
	assertEqual(hit.Material, Enum.Material.Wood)
end

function m.raycastIgnoresDecorativeProperties()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.Transparency = 1
	part.Anchored = false
	part.CanTouch = false

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "transparency/anchored/CanTouch must not affect raycast")
	assertEqual(hit.Instance, part)
	assertClose(hit.Distance, 4, 1e-4, "distance")
	assertEqual(hit.Normal, Vector3.new(-1, 0, 0))
end

function m.raycastIgnoresPartsOutsideWorkspace()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local storage = env.game:GetService("ReplicatedStorage")
	local outsider = env.Instance.new("Part", storage)
	outsider.Position = Vector3.new(5, 0, 0)
	outsider.Size = Vector3.new(2, 2, 2)

	local detached = env.Instance.new("Part")
	detached.Position = Vector3.new(5, 0, 0)
	detached.Size = Vector3.new(2, 2, 2)

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new()), nil)
end

function m.raycastIgnoresDestroyedParts()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part:Destroy()

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new()), nil)
end

function m.raycastHitsDeeplyNestedPart()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local outer = env.Instance.new("Model", workspace)
	outer.Name = "Outer"
	local inner = env.Instance.new("Model", outer)
	inner.Name = "Inner"
	local part = env.Instance.new("Part", inner)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected nested hit")
	assertEqual(hit.Instance, part)
	assertClose(hit.Distance, 4, 1e-4, "distance")
end

function m.terrainEmptyVolumeNeverHits()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Default terrain has empty volume; vertical ray must miss everything.
	assertEqual(workspace.Terrain.Size, Vector3.new(0, 0, 0))
	assertEqual(workspace:Raycast(Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), RaycastParams.new()), nil)
end

function m.terrainNonWaterHitsWithIgnoreWater()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace.Terrain.Position = Vector3.new(0, -6, 0)
	workspace.Terrain.Size = Vector3.new(100, 2, 100)
	workspace.Terrain.Material = Enum.Material.Grass

	local params = RaycastParams.new()
	params.IgnoreWater = true

	local hit = workspace:Raycast(Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), params)
	assert(hit ~= nil, "non-water terrain must hit even with IgnoreWater")
	assertEqual(hit.Instance, workspace.Terrain)
end

-- Part shapes: Ball/Cylinder/Wedge/CornerWedge ray targets use exact shape
-- geometry (not box approximation).

function m.raycastBallTargetMissesBoxCorner()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local ball = env.Instance.new("Part", workspace)
	ball.Position = Vector3.new(5, 0, 0)
	ball.Size = Vector3.new(2, 2, 2)
	ball.Shape = Enum.PartType.Ball

	-- Path through box corner (0.9, 0.9 offset) is outside sphere radius 1.
	assertEqual(workspace:Raycast(Vector3.new(0, 0.9, 0.9), Vector3.new(10, 0, 0)), nil)

	-- Center path still hits with face normal.
	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0))
	assert(hit ~= nil, "center ray must hit ball")
	assertEqual(hit.Instance, ball)
	assertClose(hit.Distance, 4, 1e-3, "distance")
	assertEqual(hit.Normal, Vector3.new(-1, 0, 0))
end

function m.raycastCylinderTargetMissesBoxCorner()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine cylinder: axis is local X, length Size.X, circular cross-section
	-- radius min(Size.Y, Size.Z)/2 (verified against Studio).
	local cyl = env.Instance.new("Part", workspace)
	cyl.Position = Vector3.new(5, 0, 0)
	cyl.Size = Vector3.new(4, 2, 2)
	cyl.Shape = Enum.PartType.Cylinder

	-- Path through box corner (radial 1.27 > radius 1) misses the cylinder.
	assertEqual(workspace:Raycast(Vector3.new(0, 0.9, 0.9), Vector3.new(10, 0, 0)), nil)

	-- Center axial ray hits the -X end cap.
	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0))
	assert(hit ~= nil, "center ray must hit cylinder cap")
	assertEqual(hit.Instance, cyl)
	assertEqual(hit.Normal, Vector3.new(-1, 0, 0))
	assertClose(hit.Position.X, 3, 1e-3, "hit x")
end

function m.raycastWedgeTargetMissesEmptyHalf()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine wedge: tall face at +Z, tapering to the -Z bottom edge
	-- (solid y <= z in local units; verified against Studio).
	local wedge = env.Instance.new("Part", workspace)
	wedge.Position = Vector3.new(5, 0, 0)
	wedge.Size = Vector3.new(2, 2, 2)
	wedge.Shape = Enum.PartType.Wedge

	-- High ray past the slope (slope 0.5 < 0.9) misses.
	assertEqual(workspace:Raycast(Vector3.new(0, 0.9, 0.5), Vector3.new(10, 0, 0)), nil)

	-- Low ray under the slope hits (mirrored geometry would miss this).
	local hit = workspace:Raycast(Vector3.new(0, 0, 0.5), Vector3.new(10, 0, 0))
	assert(hit ~= nil, "low ray must hit wedge")
	assertEqual(hit.Instance, wedge)
	assertClose(hit.Distance, 4, 1e-4, "distance")
	assertEqual(hit.Position, Vector3.new(4, 0, 0.5))
	assertEqual(hit.Normal, Vector3.new(-1, 0, 0))
end

function m.raycastCornerWedgeDiffersFromBox()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine corner wedge: high at the (+X, -Z) top corner, sloping down
	-- toward -X and +Z (solid y <= min(x, -z); verified against Studio).
	local corner = env.Instance.new("Part", workspace)
	corner.Position = Vector3.new(5, 0, 0)
	corner.Size = Vector3.new(2, 2, 2)
	corner.Shape = Enum.PartType.CornerWedge

	-- Above both slopes: box would hit, corner misses.
	assertEqual(workspace:Raycast(Vector3.new(0, 0.9, 0), Vector3.new(10, 0, 0)), nil)

	-- Ray enters through the slope itself, mid-box.
	local hit = workspace:Raycast(Vector3.new(0, -0.5, -0.5), Vector3.new(10, 0, 0))
	assert(hit ~= nil, "slope entry must hit")
	assertEqual(hit.Instance, corner)
	assertClose(hit.Position.X, 4.5, 1e-3, "slope entry x")
end

return m
