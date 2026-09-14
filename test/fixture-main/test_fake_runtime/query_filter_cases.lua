local TestHelpers = require("@test/test_helpers")

local assertClose = TestHelpers.assertClose
local assertEqual = TestHelpers.assertEqual

local m = {}

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

return m
