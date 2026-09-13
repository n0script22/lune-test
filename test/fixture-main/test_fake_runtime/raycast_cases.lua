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

function m.raycastMissesWhenDirectionTooShort()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Position = Vector3.new(5, 0, 0)
	part.Size = Vector3.new(2, 2, 2)

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(2, 0, 0), RaycastParams.new())
	assertEqual(hit, nil)
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

function m.raycastSettingPositionPreservesRotation()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	local part = env.Instance.new("Part", workspace)
	part.Size = Vector3.new(2, 2, 4)
	part.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	part.Position = Vector3.new(5, 0, 0)

	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), RaycastParams.new())
	assert(hit ~= nil, "expected ray to hit rotated part after Position set")
	assertClose(hit.Distance, 3, 1e-3, "distance")
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

function m.collisionGroupsNonCollidablePartsAreSkippedByRaycast()
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

	params.CollisionGroup = "Walls"
	local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), params)
	assert(hit ~= nil, "same-group ray should hit")
	assertEqual(hit.Instance, wall)
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

function m.spherecastRejectsInvalidRadius()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	assert(not pcall(function()
		workspace:Spherecast(Vector3.new(0, 0, 0), -1, Vector3.new(10, 0, 0))
	end))
	assert(not pcall(function()
		workspace:Spherecast(Vector3.new(0, 0, 0), 512, Vector3.new(10, 0, 0))
	end))
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

function m.blockcastRejectsInvalidSize()
	local env = createEnvironment({
		activePlayers = {},
	})
	local workspace = env.globals.Workspace

	assert(not pcall(function()
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(0, 2, 2), Vector3.new(10, 0, 0))
	end))
	assert(not pcall(function()
		workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(1024, 2, 2), Vector3.new(10, 0, 0))
	end))
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

return m
