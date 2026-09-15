local TestHelpers = require("@test/test_helpers")

local assertEqual = TestHelpers.assertEqual
local assertSequenceEqual = TestHelpers.assertSequenceEqual

local m = {}

local function newCharacter(env, name)
	local character = env.Instance.new("Model")
	character.Name = name or "Character"

	local rootPart = env.Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Parent = character

	local head = env.Instance.new("Part")
	head.Name = "Head"
	head.Parent = character

	local humanoid = env.Instance.new("Humanoid")
	humanoid.Parent = character

	return character, humanoid, rootPart
end

function m.humanoidCreationDefaultsAndHierarchy()
	local env = createEnvironment({
		activePlayers = {},
	})
	local character, humanoid, rootPart = newCharacter(env)

	assertEqual(humanoid.ClassName, "Humanoid")
	assert(humanoid:IsA("Humanoid"))
	assert(humanoid:IsA("Instance"))
	assertEqual(character:FindFirstChildOfClass("Humanoid"), humanoid)

	assertEqual(humanoid.Health, 100)
	assertEqual(humanoid.MaxHealth, 100)
	assertEqual(humanoid.WalkSpeed, 16)
	assertEqual(humanoid.JumpPower, 50)
	assertEqual(humanoid.JumpHeight, 7.2)
	assertEqual(humanoid.UseJumpPower, true)
	assertEqual(humanoid.HipHeight, 2)
	assertEqual(humanoid.MaxSlopeAngle, 89)
	assertEqual(humanoid.AutoRotate, true)
	assertEqual(humanoid.BreakJointsOnDeath, true)
	assertEqual(humanoid.RequiresNeck, true)
	assertEqual(humanoid.EvaluateStateMachine, true)
	assertEqual(humanoid.AutomaticScalingEnabled, true)
	assertEqual(humanoid.AutoJumpEnabled, true)
	assertEqual(humanoid.DisplayName, "")
	assertEqual(humanoid.DisplayDistanceType, Enum.HumanoidDisplayDistanceType.Viewer)
	assertEqual(humanoid.HealthDisplayType, Enum.HumanoidHealthDisplayType.DisplayWhenDamaged)
	assertEqual(humanoid.NameOcclusion, Enum.NameOcclusion.OccludeAll)
	assertEqual(humanoid.NameDisplayDistance, 100)
	assertEqual(humanoid.HealthDisplayDistance, 100)
	assertEqual(humanoid.RigType, Enum.HumanoidRigType.R15)
	assertEqual(humanoid.FloorMaterial, Enum.Material.Air)
	assertEqual(humanoid.CameraOffset, Vector3.new(0, 0, 0))
	assertEqual(humanoid.WalkToPoint, Vector3.new(0, 0, 0))
	assertEqual(humanoid.TargetPoint, Vector3.new(0, 0, 0))
	assertEqual(humanoid.MoveDirection, Vector3.new(0, 0, 0))
	assertEqual(humanoid.Sit, false)
	assertEqual(humanoid.Jump, false)
	assertEqual(humanoid.PlatformStand, false)
	assertEqual(humanoid.SeatPart, nil)
	assertEqual(humanoid.WalkToPart, nil)
	assertEqual(humanoid.RootPart, rootPart)
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.Running)
end

function m.humanoidReadOnlyPropertiesError()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, humanoid = newCharacter(env)

	TestHelpers.assertError(function()
		humanoid.MoveDirection = Vector3.new(0, 0, 1)
	end, "Unable to assign property MoveDirection. Property is read only")

	TestHelpers.assertError(function()
		humanoid.FloorMaterial = Enum.Material.Grass
	end, "Unable to assign property FloorMaterial. Property is read only")

	assertEqual(humanoid.MoveDirection, Vector3.new(0, 0, 0))
end

function m.humanoidHealthClampAndChanged()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, humanoid = newCharacter(env)
	local seen = {}

	humanoid.HealthChanged:Connect(function(health)
		table.insert(seen, health)
	end)

	humanoid.Health = 999
	assertEqual(humanoid.Health, 100)

	humanoid.Health = 40
	assertEqual(humanoid.Health, 40)

	humanoid.Health = 40
	assertSequenceEqual(seen, { 40 }, "health changed")

	humanoid.Health = -10
	assertEqual(humanoid.Health, 0)
	assertSequenceEqual(seen, { 40, 0 }, "health changed after clamp")
end

function m.humanoidDeathFiresDiedAndLocksHealth()
	local env = createEnvironment({
		activePlayers = {},
	})
	local character, humanoid = newCharacter(env)
	character.Parent = env.game:GetService("Workspace")

	local diedCount = 0
	local stateChanges = {}

	humanoid.Died:Connect(function()
		diedCount += 1
	end)
	humanoid.StateChanged:Connect(function(old, new)
		table.insert(stateChanges, old .. "->" .. new)
	end)

	humanoid.Health = 0

	assertEqual(humanoid.Health, 0)
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.Dead)
	assertEqual(diedCount, 1)
	assertSequenceEqual(stateChanges, { "Running->Dead" }, "state changes")

	humanoid.Health = 50
	assertEqual(humanoid.Health, 0)
	assertEqual(diedCount, 1)

	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.Dead)
end

function m.humanoidDeathRequiresWorkspaceAndEnabledDead()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, detached = newCharacter(env)
	local detachedDied = 0

	detached.Died:Connect(function()
		detachedDied += 1
	end)
	detached.Health = 0

	assertEqual(detached.Health, 0)
	assertEqual(detachedDied, 0)
	assertEqual(detached:GetState(), Enum.HumanoidStateType.Running)

	local character, gated = newCharacter(env)
	character.Parent = env.game:GetService("Workspace")
	local gatedDied = 0

	gated.Died:Connect(function()
		gatedDied += 1
	end)
	gated:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	assertEqual(gated:GetStateEnabled(Enum.HumanoidStateType.Dead), false)

	gated.Health = 0
	assertEqual(gated.Health, 0)
	assertEqual(gatedDied, 0)
	assertEqual(gated:GetState(), Enum.HumanoidStateType.Running)
end

function m.humanoidTakeDamageAndForceField()
	local env = createEnvironment({
		activePlayers = {},
	})
	local character, humanoid = newCharacter(env)
	character.Parent = env.game:GetService("Workspace")

	humanoid:TakeDamage(30)
	assertEqual(humanoid.Health, 70)

	humanoid:TakeDamage(-10)
	assertEqual(humanoid.Health, 80)

	humanoid:takeDamage(10)
	assertEqual(humanoid.Health, 70)

	local shield = env.Instance.new("ForceField")
	shield.Name = "ForceField"
	shield.Parent = character

	humanoid:TakeDamage(50)
	assertEqual(humanoid.Health, 70)

	shield:Destroy()
	humanoid:TakeDamage(20)
	assertEqual(humanoid.Health, 50)
end

function m.humanoidMaxHealthClampsHealth()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, humanoid = newCharacter(env)
	local seen = {}

	humanoid.HealthChanged:Connect(function(health)
		table.insert(seen, health)
	end)

	humanoid.MaxHealth = 50
	assertEqual(humanoid.MaxHealth, 50)
	assertEqual(humanoid.Health, 50)
	assertSequenceEqual(seen, { 50 }, "health changed after max lower")

	humanoid.MaxHealth = 200
	assertEqual(humanoid.Health, 50)

	humanoid.Health = 200
	assertEqual(humanoid.Health, 200)
end

function m.humanoidMoveSetsDirectionAndCancelsMoveTo()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, humanoid = newCharacter(env)
	local finished = {}

	humanoid.MoveToFinished:Connect(function(reached)
		table.insert(finished, reached)
	end)

	humanoid:Move(Vector3.new(1, 0, 0))
	assertEqual(humanoid.MoveDirection, Vector3.new(1, 0, 0))

	humanoid:Move(Vector3.new(0, 0, 0))
	assertEqual(humanoid.MoveDirection, Vector3.new(0, 0, 0))

	humanoid:Move(Vector3.new(0, 3, 4))
	assertEqual(humanoid.MoveDirection, Vector3.new(0, 0.6, 0.8))

	humanoid:MoveTo(Vector3.new(10, 0, 0))
	humanoid:Move(Vector3.new(0, 0, 1))
	assertSequenceEqual(finished, { false }, "move cancels moveto")
end

function m.humanoidMoveToSetsGoalAndTimesOut()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, humanoid = newCharacter(env)
	local target = env.Instance.new("Part")
	target.Name = "Target"
	target.Parent = env.game:GetService("Workspace")

	local finished = {}

	humanoid.MoveToFinished:Connect(function(reached)
		table.insert(finished, reached)
	end)

	humanoid:MoveTo(Vector3.new(10, 5, 0), target)
	assertEqual(humanoid.WalkToPoint, Vector3.new(10, 5, 0))
	assertEqual(humanoid.WalkToPart, target)

	env.scheduler:advance(7)
	assertEqual(#finished, 0)

	humanoid:MoveTo(Vector3.new(1, 1, 1))
	assertEqual(humanoid.WalkToPart, nil)

	env.scheduler:advance(7)
	assertEqual(#finished, 0)

	env.scheduler:advance(1)
	assertSequenceEqual(finished, { false }, "moveto timeout")
end

function m.humanoidDirectWalkToSetCancelsMoveTo()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, humanoid = newCharacter(env)
	local finished = {}

	humanoid.MoveToFinished:Connect(function(reached)
		table.insert(finished, reached)
	end)

	humanoid:MoveTo(Vector3.new(10, 0, 0))
	humanoid.WalkToPoint = Vector3.new(3, 0, 0)
	assertSequenceEqual(finished, { false }, "direct set cancels moveto")

	env.scheduler:advance(8)
	assertEqual(#finished, 1)
end

function m.humanoidChangeStateTransitionsAndEvents()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, humanoid = newCharacter(env)
	local states = {}
	local jumping = {}

	humanoid.StateChanged:Connect(function(old, new)
		table.insert(states, old .. "->" .. new)
	end)
	humanoid.Jumping:Connect(function(active)
		table.insert(jumping, active)
	end)

	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.Jumping)

	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.Running)

	assertSequenceEqual(states, { "Running->Jumping", "Jumping->Running" }, "state changes")
	assertSequenceEqual(jumping, { true, false }, "jumping events")

	humanoid:ChangeState(Enum.HumanoidStateType.None)
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.Running)

	humanoid:ChangeState(Enum.HumanoidStateType.PlatformStanding)
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.Running)

	humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.GettingUp)
end

function m.humanoidSetStateEnabledGating()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, humanoid = newCharacter(env)
	local enabledChanges = {}

	humanoid.StateEnabledChanged:Connect(function(state, enabled)
		table.insert(enabledChanges, state .. "=" .. tostring(enabled))
	end)

	assertEqual(humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping), true)

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	assertEqual(humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping), false)
	assertSequenceEqual(enabledChanges, { "Jumping=false" }, "enabled changes")

	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.Running)
end

function m.humanoidSitAndSeatEvents()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, humanoid = newCharacter(env)
	local seated = {}

	humanoid.Seated:Connect(function(active, seatPart)
		table.insert(seated, { active = active, seatPart = seatPart })
	end)

	humanoid.Sit = true
	assertEqual(humanoid.Sit, true)
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.Seated)
	assertEqual(seated[1].active, true)

	humanoid.Jump = true
	assertEqual(humanoid.Sit, false)
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.Jumping)
end

function m.humanoidPlatformStandTransitions()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, humanoid = newCharacter(env)
	local standing = {}

	humanoid.PlatformStanding:Connect(function(active)
		table.insert(standing, active)
	end)

	humanoid.PlatformStand = true
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.PlatformStanding)

	humanoid.PlatformStand = false
	assertEqual(humanoid:GetState(), Enum.HumanoidStateType.Running)
	assertSequenceEqual(standing, { true, false }, "platform standing")
end

function m.humanoidRootPartAutoResolve()
	local env = createEnvironment({
		activePlayers = {},
	})
	local character = env.Instance.new("Model")
	character.Name = "Rig"

	local humanoid = env.Instance.new("Humanoid")
	humanoid.Parent = character
	assertEqual(humanoid.RootPart, nil)

	local rootPart = env.Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"

	character.Parent = env.game:GetService("Workspace")
	rootPart.Parent = character
	assertEqual(humanoid.RootPart, rootPart)

	local other = env.Instance.new("Part")
	other.Name = "Other"
	humanoid.RootPart = other
	assertEqual(humanoid.RootPart, other)

	local late = env.Instance.new("Part")
	late.Name = "HumanoidRootPart2"
	late.Parent = character
	assertEqual(humanoid.RootPart, other)
end

function m.humanoidEquipAndUnequipTools()
	local env = createEnvironment({
		activePlayers = {},
	})
	local player = env:addPlayer({
		name = "Builder",
		userId = 77,
	})
	local character, humanoid = newCharacter(env)
	character.Name = "Builder"
	character.Parent = env.game:GetService("Workspace")
	player.Character = character

	local tool = env.Instance.new("Tool")
	tool.Name = "Hammer"
	tool.Parent = player:FindFirstChild("Backpack")

	humanoid:EquipTool(tool)
	assertEqual(tool.Parent, character)

	humanoid:UnequipTools()
	assertEqual(tool.Parent, player:FindFirstChild("Backpack"))
end

function m.humanoidMoveVelocityHelpers()
	local env = createEnvironment({
		activePlayers = {},
	})
	local _, humanoid, rootPart = newCharacter(env)

	assertEqual(humanoid:GetMoveVelocity(), Vector3.new(0, 0, 0))
	assertEqual(humanoid:GetRelativeVelocityAtFloor(), Vector3.new(0, 0, 0))

	rootPart.Velocity = Vector3.new(0, 0, -16)
	assertEqual(humanoid:GetMoveVelocity(), Vector3.new(0, 0, -16))
end

return m
