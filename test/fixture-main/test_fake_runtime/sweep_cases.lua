local TestHelpers = require("@test/test_helpers")

local assertClose = TestHelpers.assertClose
local assertEqual = TestHelpers.assertEqual

local m = {}

function m.blockcastHitsRotatedPart()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Size = Vector3.new(2, 2, 4)
	part.CFrame = CFrame.new(5, 0, 0) * CFrame.Angles(0, math.rad(90), 0)

	local hit =
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected block to hit rotated part")
	assertEqual(hit.Instance, part)
	assertClose(hit.Distance, 2, 1e-3, "distance")
	assertClose(hit.Position.X, 3, 1e-3, "hit x")
end

function m.blockcastTangentialOffsetPositionLiesOnPart()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(1.5, -1, 0)
	part.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Blockcast(
		CFrame.new(0, 2, 0),
		Vector3.new(2, 2, 2),
		Vector3.new(0, -10, 0),
		RaycastParams.new()
	)
	assert(hit ~= nil, "expected block to land on part")
	assertEqual(hit.Instance, part)
	assertClose(hit.Distance, 1, 1e-3, "distance")
	assertEqual(hit.Normal, Vector3.new(0, 1, 0))
	assertClose(hit.Position.Y, 0, 1e-3, "hit y")
	assert(hit.Position.X >= 0.5 - 1e-3 and hit.Position.X <= 1 + 1e-3, "contact must lie on the part top face")
end

function m.blockcastRotatedOffsetPositionLiesOnPart()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Size = Vector3.new(2, 2, 4)
	part.CFrame = CFrame.new(5, 0, 0) * CFrame.Angles(0, math.rad(90), 0)

	local hit = workspace:Blockcast(
		CFrame.new(0, 1.5, 0),
		Vector3.new(2, 2, 2),
		Vector3.new(10, 0, 0),
		RaycastParams.new()
	)
	assert(hit ~= nil, "expected block to hit rotated part")
	assertEqual(hit.Instance, part)

	local localPoint = part.CFrame:PointToObjectSpace(hit.Position)
	assertClose(localPoint.Z, -2, 1e-3, "contact on part face")
	assert(math.abs(localPoint.X) <= 1 + 1e-3, "contact within part bounds")
	assert(math.abs(localPoint.Y) <= 1 + 1e-3, "contact within part bounds")
end

function m.spherecastEdgeHitHasRadialNormal()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Spherecast(Vector3.new(0, 2, 0), 1, Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected sphere to graze part edge")
	assertEqual(hit.Instance, part)
	assertClose(hit.Distance, 4, 1e-3, "distance")
	assertEqual(hit.Normal, Vector3.new(0, 1, 0))
	assertEqual(hit.Position, Vector3.new(4, 1, 0))
end

function m.spherecastHitsRotatedPart()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Size = Vector3.new(2, 2, 4)
	part.CFrame = CFrame.new(5, 0, 0) * CFrame.Angles(0, math.rad(90), 0)

	local hit = workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected sphere to hit rotated part")
	assertEqual(hit.Instance, part)
	assertClose(hit.Distance, 2, 1e-3, "distance")
	assertClose(hit.Position.X, 3, 1e-3, "hit x")
	assert((hit.Normal - Vector3.new(-1, 0, 0)).Magnitude < 1e-6, "normal")
end

function m.blockcastDiagonalContactIsOnPartSurface()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Size = Vector3.new(2, 2, 2)
	part.CFrame = CFrame.new(6, 0, 0) * CFrame.Angles(0, math.rad(45), 0)

	local hit =
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected block to hit diagonal part")
	assertEqual(hit.Instance, part)
	assertClose(hit.Distance, 3.5858, 1e-3, "distance")
	assertEqual(hit.Normal, Vector3.new(-1, 0, 0))

	local localPoint = part.CFrame:PointToObjectSpace(hit.Position)
	assertClose(math.abs(localPoint.X), 1, 1e-3, "contact on part face")
	assert(math.abs(localPoint.Y) <= 1 + 1e-3, "contact within part bounds")
	assert(math.abs(localPoint.Z) <= 1 + 1e-3, "contact within part bounds")
end

function m.spherecastHitsPart()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected sphere to hit part")
	assertEqual(hit.Instance, part)
	assertClose(hit.Distance, 3, 1e-3, "distance")
	assertClose(hit.Position.X, 4, 1e-3, "hit x")
	assertEqual(hit.Normal, Vector3.new(-1, 0, 0))
end

function m.spherecastIgnoresInitiallyOverlappingParts()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(0, 0, 0)
	part.Size = Vector3.new(4, 4, 4)

	assertEqual(workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0), RaycastParams.new()), nil)
end

function m.blockcastHitsPart()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local hit =
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected block to hit part")
	assertEqual(hit.Instance, part)
	assertClose(hit.Distance, 3, 1e-3, "distance")
	assertClose(hit.Position.X, 4, 1e-3, "hit x")
	assertEqual(hit.Normal, Vector3.new(-1, 0, 0))
end

function m.blockcastIgnoresInitiallyOverlappingParts()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(0, 0, 0)
	part.Size = Vector3.new(4, 4, 4)

	assertEqual(
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0), RaycastParams.new()),
		nil
	)
end

function m.shapecastHitsTargetAndExcludesCastPart()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local castPart = env.Instance.new("Part", workspace)
	castPart.Position = Vector3.new(0, 0, 0)
	castPart.Size = Vector3.new(2, 2, 2)

	local target = env.Instance.new("Part", workspace)
	target.Position = Vector3.new(5, 0, 0)
	target.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Shapecast(castPart, Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected shape to hit target")
	assertEqual(hit.Instance, target)
	assertClose(hit.Distance, 3, 1e-3, "distance")
end

function m.shapecastWithOnlyCastPartMisses()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local castPart = env.Instance.new("Part", workspace)
	castPart.Position = Vector3.new(0, 0, 0)
	castPart.Size = Vector3.new(2, 2, 2)

	assertEqual(workspace:Shapecast(castPart, Vector3.new(10, 0, 0), RaycastParams.new()), nil)
end

function m.shapecastBallUsesSphereApproximation()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local castPart = env.Instance.new("Part", workspace)
	castPart.Position = Vector3.new(0, 0, 0)
	castPart.Size = Vector3.new(2, 2, 2)
	castPart.Shape = Enum.PartType.Ball

	local target = env.Instance.new("Part", workspace)
	target.Position = Vector3.new(5, 0, 0)
	target.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Shapecast(castPart, Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected ball shape to hit target")
	assertEqual(hit.Instance, target)
	assertClose(hit.Distance, 3, 1e-3, "distance")
end

function m.shapecastRejectsNonParts()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	assert(not pcall(function()
		workspace:Shapecast(workspace, Vector3.new(10, 0, 0))
	end))
end

-- Sweep validation and geometry: direction/radius/size boundaries, invalid
-- types, tangential misses, initial overlap, corner normals, self-exclusion.

function m.sweepZeroDirectionErrors()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	assert(not pcall(function()
		workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(0, 0, 0))
	end))
	assert(not pcall(function()
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(0, 0, 0))
	end))

	local castPart = env.Instance.new("Part", workspace)
	castPart.Position = Vector3.new(0, 0, 0)
	castPart.Size = Vector3.new(2, 2, 2)
	assert(not pcall(function()
		workspace:Shapecast(castPart, Vector3.new(0, 0, 0))
	end))
end

function m.sweepDirectionLengthBoundary()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(500, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	-- Exactly 1024 must not error.
	local okMax = pcall(function()
		workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(1024, 0, 0))
	end)
	assert(okMax, "direction length 1024 must pass")

	assert(not pcall(function()
		workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(1025, 0, 0))
	end))
	assert(not pcall(function()
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(0, 2000, 0))
	end))
end

function m.spherecastRadiusBoundaries()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	assert(not pcall(function()
		workspace:Spherecast(Vector3.new(0, 0, 0), 0, Vector3.new(10, 0, 0))
	end))

	-- 256 is the documented max and must pass validation.
	local okMax = pcall(function()
		workspace:Spherecast(Vector3.new(0, 0, 0), 256, Vector3.new(10, 0, 0))
	end)
	assert(okMax, "radius 256 must pass")

	assert(not pcall(function()
		workspace:Spherecast(Vector3.new(0, 0, 0), 256.1, Vector3.new(10, 0, 0))
	end))
end

function m.blockcastSizeBoundaries()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- 512 per-axis is the documented max and must pass.
	local okMax = pcall(function()
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(512, 2, 2), Vector3.new(10, 0, 0))
	end)
	assert(okMax, "size 512 must pass")

	assert(not pcall(function()
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(512.1, 2, 2), Vector3.new(10, 0, 0))
	end))
	assert(not pcall(function()
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(-1, 2, 2), Vector3.new(10, 0, 0))
	end))
end

function m.sweepInvalidTypesError()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	assert(not pcall(function()
		workspace:Blockcast(Vector3.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0))
	end))
	assert(not pcall(function()
		workspace:Spherecast("not-a-vector", 1, Vector3.new(10, 0, 0))
	end))
	assert(not pcall(function()
		workspace:Spherecast(Vector3.new(0, 0, 0), "1", Vector3.new(10, 0, 0))
	end))

	local model = env.Instance.new("Model", workspace)
	assert(not pcall(function()
		workspace:Shapecast(model, Vector3.new(10, 0, 0))
	end))
end

function m.sweepTangentialNearMissReturnsNil()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	-- Sphere path at Y=2.5 with radius 1 grazes above the part top (y=1). Gap 0.5 > 0.
	assertEqual(workspace:Spherecast(Vector3.new(0, 2.5, 0), 1, Vector3.new(10, 0, 0)), nil)

	-- Block path offset in Y by 3 with half-height 1 each side: gap 1 > 0.
	assertEqual(
		workspace:Blockcast(CFrame.new(0, 3, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0)),
		nil
	)
end

function m.spherecastInsideCoreIsIgnored()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(0, 0, 0)
	part.Size = Vector3.new(4, 4, 4)

	-- Origin strictly inside the box core must be ignored (existing behavior).
	assertEqual(workspace:Spherecast(Vector3.new(0, 0.5, 0), 1, Vector3.new(10, 0, 0)), nil)
end

function m.spherecastCornerHitHasDiagonalNormal()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	-- Aim at the top-front edge: origin offset so sphere clips the corner.
	local hit = workspace:Spherecast(Vector3.new(0, 1.5, 1.5), 1, Vector3.new(10, 0, 0))
	assert(hit ~= nil, "expected corner hit")
	assertEqual(hit.Instance, part)
	-- Corner normal must have both Y and Z components (not axis-aligned).
	assert(math.abs(hit.Normal.Y) > 0.1 and math.abs(hit.Normal.Z) > 0.1, "corner normal must be diagonal")
	assertClose(
		math.sqrt(hit.Normal.X * hit.Normal.X + hit.Normal.Y * hit.Normal.Y + hit.Normal.Z * hit.Normal.Z),
		1,
		1e-3,
		"normal unit"
	)
end

function m.shapecastExcludesOnlySelf()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local castPart = env.Instance.new("Part", workspace)
	castPart.Position = Vector3.new(0, 0, 0)
	castPart.Size = Vector3.new(2, 2, 2)

	local child = env.Instance.new("Part", castPart)
	child.Position = Vector3.new(5, 0, 0)
	child.Size = Vector3.new(2, 2, 2)

	-- Child of the cast part is a separate candidate and must be hittable.
	local hit = workspace:Shapecast(castPart, Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "child of cast part must remain hittable")
	assertEqual(hit.Instance, child)
end

function m.blockcastRotatedInitialOverlapIsIgnored()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Size = Vector3.new(4, 4, 4)
	part.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(45), 0)

	assertEqual(
		workspace:Blockcast(
			CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(45), 0),
			Vector3.new(2, 2, 2),
			Vector3.new(10, 0, 0)
		),
		nil
	)
end

function m.sweepResultCarriesMaterial()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.Material = Enum.Material.Metal

	local sphereHit = workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0))
	assert(sphereHit ~= nil, "expected sphere hit")
	assertEqual(sphereHit.Material, Enum.Material.Metal)

	local blockHit =
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0))
	assert(blockHit ~= nil, "expected block hit")
	assertEqual(blockHit.Material, Enum.Material.Metal)
end

function m.shapecastBallNonUniformUsesMinRadius()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local castPart = env.Instance.new("Part", workspace)
	castPart.Position = Vector3.new(0, 0, 0)
	castPart.Size = Vector3.new(2, 4, 6)
	castPart.Shape = Enum.PartType.Ball

	local target = env.Instance.new("Part", workspace)
	target.Position = Vector3.new(5, 0, 0)
	target.Size = Vector3.new(2, 2, 2)

	-- Ball radius = min(2,4,6)/2 = 1, so travel distance to target face (x=4) is 3.
	local hit = workspace:Shapecast(castPart, Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected ball shapecast hit")
	assertEqual(hit.Instance, target)
	assertClose(hit.Distance, 3, 1e-3, "distance")
end

function m.spherecastBallTargetMissesBoxCorner()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local ball = env.Instance.new("Part", workspace)
	ball.Position = Vector3.new(5, 0, 0)
	ball.Size = Vector3.new(2, 2, 2)
	ball.Shape = Enum.PartType.Ball

	-- Sphere path through box corner outside ball must miss.
	-- Offset (1.2,1.2) is inside expanded box (1.5) but outside combined radius (1.5 vs 1.697).
	assertEqual(workspace:Spherecast(Vector3.new(0, 1.2, 1.2), 0.5, Vector3.new(10, 0, 0)), nil)

	-- Center path hits.
	local hit = workspace:Spherecast(Vector3.new(0, 0, 0), 0.5, Vector3.new(10, 0, 0))
	assert(hit ~= nil, "center sphere path must hit ball")
	assertEqual(hit.Instance, ball)
	assertClose(hit.Distance, 3.5, 1e-3, "distance")
end

function m.spherecastVsWedgeUsesBoxApproximation()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine (verified against Studio): sweeps test shaped targets as
	-- boxes, so a sphere grazing the wedge's empty half still hits.
	local wedge = env.Instance.new("Part", workspace)
	wedge.Position = Vector3.new(5, 0, 0)
	wedge.Size = Vector3.new(2, 2, 2)
	wedge.Shape = Enum.PartType.Wedge

	-- Engine (verified against Studio): sweeps test shaped targets as
	-- boxes. Sphere bottom (0.6) stays above the slope (0.5) yet still hits.
	local hit = workspace:Spherecast(Vector3.new(0, 1.1, 0.5), 0.5, Vector3.new(10, 0, 0))
	assert(hit ~= nil, "sweep vs wedge must use box approximation")
	assertEqual(hit.Instance, wedge)

	-- Control: far above the expanded box still misses.
	assertEqual(workspace:Spherecast(Vector3.new(0, 1.6, 0.5), 0.5, Vector3.new(10, 0, 0)), nil)
end

function m.blockVsBallCornerMiss()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine (verified against Studio): Blockcast vs Ball is exact
	-- box-vs-sphere, not box-vs-box.
	local ball = env.Instance.new("Part", workspace)
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2, 2, 2)
	ball.Position = Vector3.new(5, 0, 0)

	-- Corner path: box-vs-box would HIT, exact box-vs-sphere must MISS.
	assertEqual(
		workspace:Blockcast(CFrame.new(0, 1.8, 1.8), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0)),
		nil
	)

	-- Center control HITs at distance 3.
	local hit = workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0))
	assert(hit ~= nil, "center block path must hit ball")
	assertEqual(hit.Instance, ball)
	assertClose(hit.Distance, 3, 1e-3, "distance")

	-- Same corner miss via block-caster Shapecast.
	local caster = env.Instance.new("Part", workspace)
	caster.Size = Vector3.new(2, 2, 2)
	caster.CFrame = CFrame.new(0, 1.8, 1.8)
	assertEqual(workspace:Shapecast(caster, Vector3.new(10, 0, 0)), nil)
end

function m.spherecastVsCylinderIsExact()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine (verified against Studio): Spherecast vs Cylinder target is
	-- exact, not box approximation.
	local cyl = env.Instance.new("Part", workspace)
	cyl.Shape = Enum.PartType.Cylinder
	cyl.Size = Vector3.new(4, 2, 2)
	cyl.Position = Vector3.new(5, 1400, 0)

	-- Radial 1.697 > 1 + 0.5: exact MISS, box approx would HIT.
	assertEqual(workspace:Spherecast(Vector3.new(0, 1401.2, 1.2), 0.5, Vector3.new(10, 0, 0)), nil)

	-- Center control HITs at distance 2.5.
	local hit = workspace:Spherecast(Vector3.new(0, 1400, 0), 0.5, Vector3.new(10, 0, 0))
	assert(hit ~= nil, "center sphere path must hit cylinder")
	assertEqual(hit.Instance, cyl)
	assertClose(hit.Distance, 2.5, 1e-3, "distance")
end

function m.blockcastVsCylinderIsExact()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine (verified against Studio): Blockcast vs Cylinder is exact
	-- box-vs-cylinder, not box-vs-box.
	local cyl = env.Instance.new("Part", workspace)
	cyl.Shape = Enum.PartType.Cylinder
	cyl.Size = Vector3.new(4, 2, 2)
	cyl.Position = Vector3.new(5, 0, 0)

	-- Corner path: box-vs-box would HIT, exact must MISS.
	assertEqual(
		workspace:Blockcast(CFrame.new(0, 1.8, 1.8), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0)),
		nil
	)

	-- Center control HITs at distance 2.
	local hit =
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0))
	assert(hit ~= nil, "center block path must hit cylinder")
	assertEqual(hit.Instance, cyl)
	assertClose(hit.Distance, 2, 1e-3, "distance")
end

function m.shapecastCylinderUsesBoxApproximation()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine (verified against Studio): Cylinder casters sweep as boxes.
	local wall = env.Instance.new("Part", workspace)
	wall.Size = Vector3.new(2, 2, 2)
	wall.Position = Vector3.new(5, 1500, 0)

	local cast = env.Instance.new("Part", workspace)
	cast.Shape = Enum.PartType.Cylinder
	cast.Size = Vector3.new(4, 2, 2)
	cast.CFrame = CFrame.new(0, 1500.9, 0.9)

	-- Box fallback HITs (exact cylinder would MISS: radial 1.27 > 1).
	local hit = workspace:Shapecast(cast, Vector3.new(10, 0, 0))
	assert(hit ~= nil, "cylinder caster must use box fallback")
	assertEqual(hit.Instance, wall)
end

function m.blockcastVsWedgeUsesBoxApproximation()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine (verified against Studio): Blockcast vs Wedge is box approx.
	local wedge = env.Instance.new("Part", workspace)
	wedge.Shape = Enum.PartType.Wedge
	wedge.Size = Vector3.new(2, 2, 2)
	wedge.Position = Vector3.new(5, 0, 0)

	-- Box HITs even though exact wedge would MISS (bottom 0.6 above slope 0.5).
	local hit =
		workspace:Blockcast(CFrame.new(0, 1.1, 0.5), Vector3.new(1, 1, 1), Vector3.new(10, 0, 0))
	assert(hit ~= nil, "block vs wedge must use box approximation")
	assertEqual(hit.Instance, wedge)
end

function m.shapecastWedgeIsExact()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine (verified against Studio): Wedge casters are exact, not boxes.
	local wall = env.Instance.new("Part", workspace)
	wall.Size = Vector3.new(2, 2, 2)
	wall.Position = Vector3.new(5, 1501.5, -1.5)

	local cast = env.Instance.new("Part", workspace)
	cast.Shape = Enum.PartType.Wedge
	cast.Size = Vector3.new(2, 2, 2)
	cast.CFrame = CFrame.new(0, 1500, 0)

	-- Box fallback would HIT; exact wedge must MISS.
	assertEqual(workspace:Shapecast(cast, Vector3.new(10, 0, 0)), nil)

	-- Aligned control HITs at distance 3.
	cast.CFrame = CFrame.new(0, 1501.5, -1.5)
	local hit = workspace:Shapecast(cast, Vector3.new(10, 0, 0))
	assert(hit ~= nil, "aligned wedge path must hit")
	assertEqual(hit.Instance, wall)
	assertClose(hit.Distance, 3, 1e-3, "distance")
end

function m.shapecastCornerWedgeIsExact()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine (verified against Studio): CornerWedge casters are exact.
	local wall = env.Instance.new("Part", workspace)
	wall.Size = Vector3.new(2, 2, 2)
	wall.Position = Vector3.new(5, 1501.5, 1.5)

	local cast = env.Instance.new("Part", workspace)
	cast.Shape = Enum.PartType.CornerWedge
	cast.Size = Vector3.new(2, 2, 2)
	cast.CFrame = CFrame.new(0, 1500, 0)

	-- Box fallback would HIT; exact corner must MISS.
	assertEqual(workspace:Shapecast(cast, Vector3.new(10, 0, 0)), nil)

	-- Aligned control HITs.
	cast.CFrame = CFrame.new(0, 1501.5, 1.5)
	local hit = workspace:Shapecast(cast, Vector3.new(10, 0, 0))
	assert(hit ~= nil, "aligned corner path must hit")
	assertEqual(hit.Instance, wall)
end

function m.shapecastWedgeVsBallIsExact()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine (verified against Studio): Wedge caster vs Ball is exact.
	local ball = env.Instance.new("Part", workspace)
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2, 2, 2)
	ball.Position = Vector3.new(5, 1501.5, -1.5)

	local cast = env.Instance.new("Part", workspace)
	cast.Shape = Enum.PartType.Wedge
	cast.Size = Vector3.new(2, 2, 2)
	cast.CFrame = CFrame.new(0, 1500, 0)

	-- Box caster would HIT; exact wedge must MISS.
	assertEqual(workspace:Shapecast(cast, Vector3.new(10, 0, 0)), nil)
end

return m
