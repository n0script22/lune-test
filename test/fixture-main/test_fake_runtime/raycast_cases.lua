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

function m.raycastSkipsCanQueryFalseParts()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.CanQuery = false

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new()), nil)
end

function m.raycastRespectCanCollideUsesCanCollide()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.CanQuery = false
	part.CanCollide = true

	local params = RaycastParams.new()
	params.RespectCanCollide = true

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params)
	assert(hit ~= nil, "RespectCanCollide should use CanCollide instead of CanQuery")
	assertEqual(hit.Instance, part)
end

function m.raycastBruteForceHitsRegardlessOfFlags()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.CanQuery = false
	part.CanCollide = false

	local params = RaycastParams.new()
	params.BruteForceAllSlow = true

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params)
	assert(hit ~= nil, "BruteForceAllSlow should ignore CanQuery/CanCollide")
	assertEqual(hit.Instance, part)
end

function m.raycastExcludeInstancesSkipsListedParts()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local excluded = env.Instance.new("Part", workspace)
	excluded.Name = "Excluded"
	excluded.Position = Vector3.new(5, 0, 0)
	excluded.Size = Vector3.new(2, 2, 2)

	local kept = env.Instance.new("Part", workspace)
	kept.Name = "Kept"
	kept.Position = Vector3.new(9, 0, 0)
	kept.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.ExcludeInstances = { excluded }

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), params)
	assert(hit ~= nil, "expected to hit kept part")
	assertEqual(hit.Instance, kept)
end

function m.raycastExcludeInstancesSkipsDescendants()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local folder = env.Instance.new("Folder", workspace)
	folder.Name = "Enemies"

	local part = env.Instance.new("Part", folder)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.ExcludeInstances = { folder }

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params), nil)
end

function m.raycastIncludeInstancesOnlyHitsListed()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local ignored = env.Instance.new("Part", workspace)
	ignored.Name = "Ignored"
	ignored.Position = Vector3.new(5, 0, 0)
	ignored.Size = Vector3.new(2, 2, 2)

	local wanted = env.Instance.new("Part", workspace)
	wanted.Name = "Wanted"
	wanted.Position = Vector3.new(9, 0, 0)
	wanted.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.IncludeInstances = { wanted }

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), params)
	assert(hit ~= nil, "expected to hit wanted part")
	assertEqual(hit.Instance, wanted)
end

function m.raycastEmptyIncludeListHitsNothing()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.IncludeInstances = {}

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params), nil)
end

function m.raycastExclusionWinsOverInclusion()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.ExcludeInstances = { part }
	params.IncludeInstances = { part }

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params), nil)
end

function m.raycastLegacyExcludeFilterType()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local excluded = env.Instance.new("Part", workspace)
	excluded.Position = Vector3.new(5, 0, 0)
	excluded.Size = Vector3.new(2, 2, 2)

	local kept = env.Instance.new("Part", workspace)
	kept.Position = Vector3.new(9, 0, 0)
	kept.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.FilterType = "Exclude"
	params.FilterDescendantsInstances = { excluded }

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), params)
	assert(hit ~= nil, "expected to hit kept part")
	assertEqual(hit.Instance, kept)
end

function m.raycastLegacyIncludeFilterType()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local ignored = env.Instance.new("Part", workspace)
	ignored.Position = Vector3.new(5, 0, 0)
	ignored.Size = Vector3.new(2, 2, 2)

	local wanted = env.Instance.new("Part", workspace)
	wanted.Position = Vector3.new(9, 0, 0)
	wanted.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.FilterType = "Include"
	params.FilterDescendantsInstances = { wanted }

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), params)
	assert(hit ~= nil, "expected to hit wanted part")
	assertEqual(hit.Instance, wanted)
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

function m.collisionGroupsDefaultToCollidable()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	assert(workspace:CollisionGroupsAreCollidable("Default", "Default"))
	assert(workspace:CollisionGroupsAreCollidable("UnregisteredA", "UnregisteredB"))
	assert(workspace:IsCollisionGroupRegistered("Default"))
	assert(not workspace:IsCollisionGroupRegistered("Ghosts"))
end

function m.collisionGroupSetCollidableErrorsForUnregisteredGroups()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local ok = pcall(function()
		workspace:CollisionGroupSetCollidable("MissingA", "MissingB", false)
	end)
	assert(not ok, "expected error for unregistered groups")
end

function m.collisionGroupsCanBeRenamedUnregisteredAndListed()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace:RegisterCollisionGroup("Walls")
	workspace:RegisterCollisionGroup("Ghosts")
	workspace:CollisionGroupSetCollidable("Walls", "Ghosts", false)
	assert(not workspace:CollisionGroupsAreCollidable("Walls", "Ghosts"))

	workspace:RenameCollisionGroup("Ghosts", "Spectres")
	assert(workspace:IsCollisionGroupRegistered("Spectres"))
	assert(not workspace:IsCollisionGroupRegistered("Ghosts"))
	assert(not workspace:CollisionGroupsAreCollidable("Walls", "Spectres"))

	workspace:CollisionGroupSetCollidable("Walls", "Spectres", true)
	assert(workspace:CollisionGroupsAreCollidable("Walls", "Spectres"))

	workspace:UnregisterCollisionGroup("Spectres")
	assert(not workspace:IsCollisionGroupRegistered("Spectres"))
	assert(workspace:CollisionGroupsAreCollidable("Walls", "Spectres"))

	local groups = workspace:GetRegisteredCollisionGroups()
	local names = {}

	for _, entry in ipairs(groups) do
		names[entry.name] = true
	end

	assert(names.Default and names.Walls)
	assert(names.Spectres == nil)
end

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

function m.terrainCanQueryFalseIsSkipped()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace.Terrain.Position = Vector3.new(0, -6, 0)
	workspace.Terrain.Size = Vector3.new(100, 2, 100)
	workspace.Terrain.CanQuery = false

	assertEqual(workspace:Raycast(Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), RaycastParams.new()), nil)
end

-- Filter interactions: disjoint modern Exclude/Include, modern+legacy
-- combinations, legacy empty/invalid types, junk entries, Model exclusion.

function m.raycastDisjointExcludeIncludeHitsArena()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local character = env.Instance.new("Model", workspace)
	character.Name = "Character"
	local head = env.Instance.new("Part", character)
	head.Position = Vector3.new(5, 0, 0)
	head.Size = Vector3.new(2, 2, 2)

	local arena = env.Instance.new("Folder", workspace)
	arena.Name = "Arena"
	local wall = env.Instance.new("Part", arena)
	wall.Position = Vector3.new(9, 0, 0)
	wall.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.ExcludeInstances = { character }
	params.IncludeInstances = { arena }

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), params)
	assert(hit ~= nil, "expected arena wall")
	assertEqual(hit.Instance, wall)
end

function m.raycastModernAndLegacyExcludeBothEnforced()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local modernExcluded = env.Instance.new("Part", workspace)
	modernExcluded.Position = Vector3.new(5, 0, 0)
	modernExcluded.Size = Vector3.new(2, 2, 2)

	local legacyExcluded = env.Instance.new("Part", workspace)
	legacyExcluded.Position = Vector3.new(9, 0, 0)
	legacyExcluded.Size = Vector3.new(2, 2, 2)

	local kept = env.Instance.new("Part", workspace)
	kept.Position = Vector3.new(13, 0, 0)
	kept.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.ExcludeInstances = { modernExcluded }
	params.FilterType = "Exclude"
	params.FilterDescendantsInstances = { legacyExcluded }

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), params)
	assert(hit ~= nil, "expected kept part")
	assertEqual(hit.Instance, kept)
end

function m.raycastModernAndLegacyIncludeMustBothPass()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local arena = env.Instance.new("Folder", workspace)
	arena.Name = "Arena"
	local wanted = env.Instance.new("Part", arena)
	wanted.Position = Vector3.new(5, 0, 0)
	wanted.Size = Vector3.new(2, 2, 2)

	local outsider = env.Instance.new("Part", workspace)
	outsider.Position = Vector3.new(3, 0, 0)
	outsider.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.IncludeInstances = { arena }
	params.FilterType = "Include"
	params.FilterDescendantsInstances = { wanted }

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), params)
	assert(hit ~= nil, "expected wanted part satisfying both includes")
	assertEqual(hit.Instance, wanted)

	-- Same modern include but legacy wanting a different part must miss the outsider.
	local params2 = RaycastParams.new()
	params2.IncludeInstances = { arena }
	params2.FilterType = "Include"
	params2.FilterDescendantsInstances = { outsider }
	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), params2), nil)
end

function m.raycastLegacyEmptyIncludeHitsEverything()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.FilterType = "Include"
	params.FilterDescendantsInstances = {}

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params)
	assert(hit ~= nil, "empty legacy include must not filter")
	assertEqual(hit.Instance, part)
end

function m.raycastLegacyInvalidFilterTypeErrorsOnAssign()
	local params = RaycastParams.new()

	-- Engine (verified against Studio): only the RaycastFilterType enum
	-- values are accepted; anything else errors on assignment.
	local ok = pcall(function()
		params.FilterType = "Foo"
	end)
	assert(not ok, "invalid FilterType must error")

	params.FilterType = "Include"
	assertEqual(params.FilterType, "Include")
	params.FilterType = Enum.RaycastFilterType.Exclude
	assertEqual(params.FilterType, "Exclude")
end

function m.raycastFilterListWithJunkEntriesDoesNotCrash()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local excluded = env.Instance.new("Part", workspace)
	excluded.Position = Vector3.new(5, 0, 0)
	excluded.Size = Vector3.new(2, 2, 2)

	local kept = env.Instance.new("Part", workspace)
	kept.Position = Vector3.new(9, 0, 0)
	kept.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.ExcludeInstances = { 123, "string", excluded }

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), params)
	assert(hit ~= nil, "expected kept part despite junk entries")
	assertEqual(hit.Instance, kept)
end

function m.raycastModelExclusionSkipsCharacterParts()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local character = env.Instance.new("Model", workspace)
	character.Name = "Character"
	local head = env.Instance.new("Part", character)
	head.Position = Vector3.new(5, 0, 0)
	head.Size = Vector3.new(2, 2, 2)

	local wall = env.Instance.new("Part", workspace)
	wall.Position = Vector3.new(9, 0, 0)
	wall.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.ExcludeInstances = { character }

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), params)
	assert(hit ~= nil, "expected wall after character exclusion")
	assertEqual(hit.Instance, wall)
end

function m.raycastParamsAddToFilterRejectsInvalid()
	local params = RaycastParams.new()

	local ok = pcall(function()
		params:AddToFilter(123)
	end)
	assert(not ok, "AddToFilter must error on non-instance")

	local before = #params.FilterDescendantsInstances
	params:AddToFilter({})
	assertEqual(#params.FilterDescendantsInstances, before)
end

-- CanQuery/CanCollide matrix and BruteForceAllSlow: filters and IgnoreWater
-- still apply, only CanQuery/CanCollide/collision groups are bypassed.

function m.canQueryMatrixRespectFalseUsesCanQuery()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.CanQuery = true
	part.CanCollide = false

	local params = RaycastParams.new()
	params.RespectCanCollide = false

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params)
	assert(hit ~= nil, "CanQuery=true must hit when RespectCanCollide=false")
	assertEqual(hit.Instance, part)
end

function m.canQueryMatrixRespectTrueUsesCanCollide()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.CanQuery = true
	part.CanCollide = false

	local params = RaycastParams.new()
	params.RespectCanCollide = true

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params), nil)
end

function m.canQueryMatrixBothFalseRespectTrueMisses()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.CanQuery = false
	part.CanCollide = false

	local params = RaycastParams.new()
	params.RespectCanCollide = true

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params), nil)
end

function m.bruteForceRespectsExcludeInstances()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.CanQuery = false
	part.CanCollide = false

	local params = RaycastParams.new()
	params.BruteForceAllSlow = true
	params.ExcludeInstances = { part }

	assertEqual(
		workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params),
		nil,
		"BruteForce must still respect ExcludeInstances"
	)
end

function m.bruteForceRespectsEmptyInclude()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.CanQuery = false

	local params = RaycastParams.new()
	params.BruteForceAllSlow = true
	params.IncludeInstances = {}

	assertEqual(
		workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params),
		nil,
		"BruteForce must still respect empty IncludeInstances"
	)
end

function m.bruteForceRespectsCollisionGroup()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace:RegisterCollisionGroup("Ghosts")
	workspace:RegisterCollisionGroup("Walls")
	workspace:CollisionGroupSetCollidable("Ghosts", "Walls", false)

	local wall = env.Instance.new("Part", workspace)
	wall.Position = Vector3.new(5, 0, 0)
	wall.Size = Vector3.new(2, 2, 2)
	wall.CollisionGroup = "Walls"

	-- Engine (verified against Studio): BruteForceAllSlow bypasses only
	-- CanQuery/CanCollide; collision groups still apply.
	local params = RaycastParams.new()
	params.BruteForceAllSlow = true
	params.CollisionGroup = "Ghosts"

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params), nil)
end

function m.bruteForceRespectsIgnoreWater()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace.Terrain.Position = Vector3.new(0, -6, 0)
	workspace.Terrain.Size = Vector3.new(100, 2, 100)
	workspace.Terrain.Material = Enum.Material.Water

	local params = RaycastParams.new()
	params.BruteForceAllSlow = true
	params.IgnoreWater = true

	assertEqual(workspace:Raycast(Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), params), nil)
end

function m.bruteForceAppliesToSweeps()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.CanQuery = false
	part.CanCollide = false

	local params = RaycastParams.new()
	params.BruteForceAllSlow = true

	local sphereHit = workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0), params)
	assert(sphereHit ~= nil, "BruteForce must apply to Spherecast")
	assertEqual(sphereHit.Instance, part)
	assertClose(sphereHit.Distance, 3, 1e-3, "sphere distance")

	local blockHit =
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0), params)
	assert(blockHit ~= nil, "BruteForce must apply to Blockcast")
	assertEqual(blockHit.Instance, part)
	assertClose(blockHit.Distance, 3, 1e-3, "block distance")

	-- But filtered sweeps still miss.
	local filtered = RaycastParams.new()
	filtered.BruteForceAllSlow = true
	filtered.ExcludeInstances = { part }
	assertEqual(workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0), filtered), nil)
	assertEqual(
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0), filtered),
		nil
	)
end

-- Collision groups: registration contracts, symmetry, self-pairs,
-- unregistered defaults, sorted listing, and filtering on all query types.

function m.collisionGroupRegisterDuplicateIsIdempotent()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace:RegisterCollisionGroup("Walls")
	workspace:RegisterCollisionGroup("Walls")

	assert(workspace:IsCollisionGroupRegistered("Walls"))
end

function m.collisionGroupRegisterRejectsDefaultAndEmpty()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	assert(not pcall(function()
		workspace:RegisterCollisionGroup("Default")
	end))
	assert(not pcall(function()
		workspace:RegisterCollisionGroup("")
	end))
end

function m.collisionGroupUnregisterDefaultErrorsMissingNoOp()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	assert(not pcall(function()
		workspace:UnregisterCollisionGroup("Default")
	end))

	-- Missing group is a no-op, must not error.
	workspace:UnregisterCollisionGroup("NeverRegistered")
	assert(not workspace:IsCollisionGroupRegistered("NeverRegistered"))
end

function m.collisionGroupRenameMissingAndSameAreNoOps()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace:RenameCollisionGroup("Missing", "Other")
	assert(not workspace:IsCollisionGroupRegistered("Other"))

	workspace:RegisterCollisionGroup("Walls")
	workspace:RenameCollisionGroup("Walls", "Walls")
	assert(workspace:IsCollisionGroupRegistered("Walls"))
end

function m.collisionGroupRenameToDefaultErrors()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace:RegisterCollisionGroup("Walls")
	assert(not pcall(function()
		workspace:RenameCollisionGroup("Walls", "Default")
	end))
end

function m.collisionGroupRenameOntoExistingIsNoOp()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	-- Engine (verified against Studio): renaming onto a registered name is
	-- a silent no-op; both groups and all relations are preserved.
	workspace:RegisterCollisionGroup("A")
	workspace:RegisterCollisionGroup("B")
	workspace:RegisterCollisionGroup("C")
	workspace:CollisionGroupSetCollidable("A", "C", false)

	workspace:RenameCollisionGroup("A", "B")

	assert(workspace:IsCollisionGroupRegistered("A"))
	assert(workspace:IsCollisionGroupRegistered("B"))
	assert(not workspace:CollisionGroupsAreCollidable("A", "C"))
	assert(workspace:CollisionGroupsAreCollidable("B", "C"))
end

function m.collisionGroupsAreCollidableIsSymmetric()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace:RegisterCollisionGroup("A")
	workspace:RegisterCollisionGroup("B")
	workspace:CollisionGroupSetCollidable("A", "B", false)

	assert(not workspace:CollisionGroupsAreCollidable("A", "B"))
	assert(not workspace:CollisionGroupsAreCollidable("B", "A"))

	workspace:CollisionGroupSetCollidable("B", "A", true)
	assert(workspace:CollisionGroupsAreCollidable("A", "B"))
	assert(workspace:CollisionGroupsAreCollidable("B", "A"))
end

function m.collisionGroupSelfNonCollidableSkipsQuery()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace:RegisterCollisionGroup("Walls")
	workspace:CollisionGroupSetCollidable("Walls", "Walls", false)

	local wall = env.Instance.new("Part", workspace)
	wall.Position = Vector3.new(5, 0, 0)
	wall.Size = Vector3.new(2, 2, 2)
	wall.CollisionGroup = "Walls"

	local params = RaycastParams.new()
	params.CollisionGroup = "Walls"

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params), nil)
end

function m.collisionGroupUnregisteredDefaultsToCollidable()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.CollisionGroup = "CustomUnregistered"

	-- Unregistered part group vs Default query must hit.
	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "unregistered part group must default collidable")
	assertEqual(hit.Instance, part)

	-- Registered part vs unregistered query group must hit.
	workspace:RegisterCollisionGroup("Walls")
	local wall = env.Instance.new("Part", workspace)
	wall.Position = Vector3.new(9, 0, 0)
	wall.Size = Vector3.new(2, 2, 2)
	wall.CollisionGroup = "Walls"

	local params = RaycastParams.new()
	params.CollisionGroup = "QueryUnregistered"
	local hit2 = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), params)
	assert(hit2 ~= nil, "unregistered query group must default collidable")
end

function m.collisionGroupListIsSortedWithMasks()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace:RegisterCollisionGroup("Zebras")
	workspace:RegisterCollisionGroup("Apples")

	local groups = workspace:GetRegisteredCollisionGroups()
	assert(groups[1].name == "Apples", "list must be sorted")
	assert(groups[2].name == "Default" or groups[2].name == "Zebras", "sorted order")

	local byName = {}
	for _, entry in ipairs(groups) do
		byName[entry.name] = entry
		assert(type(entry.mask) == "number", "entry must have numeric mask")
	end

	assert(byName.Default ~= nil and byName.Apples ~= nil and byName.Zebras ~= nil)

	local maskBefore = byName.Apples.mask
	workspace:RenameCollisionGroup("Apples", "Apricots")
	local renamed = workspace:GetRegisteredCollisionGroups()
	local renamedByName = {}
	for _, entry in ipairs(renamed) do
		renamedByName[entry.name] = entry
	end
	assertEqual(renamedByName.Apricots.mask, maskBefore)
end

function m.collisionGroupFilteringAppliesToAllQueryTypes()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	workspace:RegisterCollisionGroup("Ghosts")
	workspace:RegisterCollisionGroup("Walls")
	workspace:CollisionGroupSetCollidable("Ghosts", "Walls", false)

	local wall = env.Instance.new("Part", workspace)
	wall.Position = Vector3.new(5, 0, 0)
	wall.Size = Vector3.new(2, 2, 2)
	wall.CollisionGroup = "Walls"

	local params = RaycastParams.new()
	params.CollisionGroup = "Ghosts"

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params), nil)
	assertEqual(workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0), params), nil)
	assertEqual(
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0), params),
		nil
	)

	local castPart = env.Instance.new("Part", workspace)
	castPart.Position = Vector3.new(0, 5, 0)
	castPart.Size = Vector3.new(2, 2, 2)
	assertEqual(workspace:Shapecast(castPart, Vector3.new(0, -10, 0), params), nil)

	-- Same-group queries must hit for every query type.
	local sameParams = RaycastParams.new()
	sameParams.CollisionGroup = "Walls"
	local sameRay = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), sameParams)
	assert(sameRay ~= nil, "same-group ray should hit")
	assertEqual(sameRay.Instance, wall)
	local sameSphere =
		workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0), sameParams)
	assert(sameSphere ~= nil, "same-group sphere should hit")
	assertEqual(sameSphere.Instance, wall)
	local sameBlock = workspace:Blockcast(
		CFrame.new(0, 0, 0),
		Vector3.new(2, 2, 2),
		Vector3.new(10, 0, 0),
		sameParams
	)
	assert(sameBlock ~= nil, "same-group block should hit")
	assertEqual(sameBlock.Instance, wall)
end

function m.canQueryFilteringAppliesToAllQueryTypes()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)
	part.CanQuery = false

	local params = RaycastParams.new()
	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params), nil)
	assertEqual(workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0), params), nil)
	assertEqual(
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0), params),
		nil
	)
end

function m.excludeFilteringAppliesToAllQueryTypes()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local params = RaycastParams.new()
	params.ExcludeInstances = { part }

	assertEqual(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params), nil)
	assertEqual(workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0), params), nil)
	assertEqual(
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0), params),
		nil
	)
	assertClose(
		workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new()).Distance,
		4,
		1e-4,
		"unfiltered baseline"
	)
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

-- Part shapes: Ball/Cylinder/Wedge/CornerWedge ray targets use exact shape
-- geometry (not box approximation); Ball sweeps use sphere-vs-sphere.

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

function m.emptyUnionCastsAsBox()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local u = env.Instance.new("UnionOperation", workspace)
	u.Size = Vector3.new(4, 4, 4)
	u.Position = Vector3.new(0, 100, 0)

	local hit = workspace:Raycast(Vector3.new(0, 100, -10), Vector3.new(0, 0, 20), RaycastParams.new())
	assert(hit ~= nil, "empty union must cast as its bounding box")
	assertEqual(hit.Instance, u)
	assertEqual(hit.Position, Vector3.new(0, 100, -2))
	assertEqual(hit.Normal, Vector3.new(0, 0, -1))

	local mp = env.Instance.new("MeshPart", workspace)
	mp.Size = Vector3.new(4, 4, 4)
	mp.Position = Vector3.new(20, 100, 0)

	local meshHit =
		workspace:Raycast(Vector3.new(20, 100, -10), Vector3.new(0, 0, 20), RaycastParams.new())
	assert(meshHit ~= nil, "empty mesh must cast as its bounding box")
	assertEqual(meshHit.Instance, mp)
end

return m
