local Vector3 = require("./Vector3")

local ClassData = {}

local DEFAULT_PART_SIZE = Vector3.new(4, 1, 2)
local DEFAULT_UNION_MESH_SIZE = Vector3.new(4, 1.2, 2)
local EMPTY_TERRAIN_SIZE = Vector3.new(0, 0, 0)

local nonCreatableClasses = {
	CollectionService = true,
	MemoryStoreService = true,
	RunService = true,
	DataModel = true,
	ReplicatedStorage = true,
	ServerScriptService = true,
	StarterPlayer = true,
	StarterPlayerScripts = true,
	PlayerScripts = true,
	Terrain = true,
	GeometryService = true,
	PartOperation = true,
}

local parentByClass = {
	Instance = nil,
	DataModel = "Instance",
	Folder = "Instance",
	Model = "Instance",
	Tool = "Model",
	Backpack = "Folder",
	Workspace = "Model",
	BasePart = "Instance",
	Part = "BasePart",
	PartOperation = "BasePart",
	UnionOperation = "PartOperation",
	MeshPart = "BasePart",
	SpawnLocation = "BasePart",
	Terrain = "BasePart",
	NumberValue = "Instance",
	RemoteEvent = "Instance",
	RemoteFunction = "Instance",
	Player = "Instance",
	Players = "Instance",
	Humanoid = "Instance",
	ForceField = "Instance",
	RunService = "Instance",
	CollectionService = "Instance",
	GeometryService = "Instance",
	MemoryStoreService = "Instance",
	ReplicatedStorage = "Instance",
	ServerScriptService = "Instance",
	StarterPlayer = "Instance",
	StarterPlayerScripts = "Instance",
	PlayerScripts = "Instance",
	ModuleScript = "Instance",
	LocalScript = "Instance",
}

local defaultPropsByClass = {
	Instance = {},
	DataModel = {},
	Folder = {},
	Model = {},
	Tool = {
		RequiresHandle = false,
		Enabled = true,
	},
	Backpack = {},
	Workspace = {},
	BasePart = {
		Anchored = false,
		CanCollide = true,
		CanQuery = true,
		CanTouch = true,
		Transparency = 0,
		Material = "Plastic",
		CollisionGroup = "Default",
		Size = DEFAULT_PART_SIZE,
	},
	Part = {
		Shape = "Block",
	},
	UnionOperation = {
		Size = DEFAULT_UNION_MESH_SIZE,
		CollisionFidelity = "Box",
		RenderFidelity = "Automatic",
		UsePartColor = false,
	},
	MeshPart = {
		Size = DEFAULT_UNION_MESH_SIZE,
		CollisionFidelity = "Box",
		RenderFidelity = "Automatic",
		MeshId = "",
		UsePartColor = false,
	},
	Terrain = {
		Material = "Grass",
		Size = EMPTY_TERRAIN_SIZE,
	},
	SpawnLocation = {
		Neutral = true,
	},
	NumberValue = {
		Value = 0,
	},
	RemoteEvent = {},
	RemoteFunction = {},
	Player = {
		UserId = 0,
		AccountAge = 0,
		MembershipType = "None",
	},
	Humanoid = {
		Health = 100,
		MaxHealth = 100,
		WalkSpeed = 16,
		JumpPower = 50,
		JumpHeight = 7.2,
		UseJumpPower = true,
		HipHeight = 2,
		AutoRotate = true,
		BreakJointsOnDeath = true,
		RequiresNeck = true,
		EvaluateStateMachine = true,
		AutomaticScalingEnabled = true,
		AutoJumpEnabled = true,
		DisplayName = "",
		DisplayDistanceType = "Viewer",
		HealthDisplayType = "DisplayWhenDamaged",
		NameOcclusion = "OccludeAll",
		NameDisplayDistance = 100,
		HealthDisplayDistance = 100,
		MaxSlopeAngle = 89,
		RigType = "R15",
		FloorMaterial = "Air",
		CameraOffset = Vector3.new(0, 0, 0),
		WalkToPoint = Vector3.new(0, 0, 0),
		TargetPoint = Vector3.new(0, 0, 0),
		MoveDirection = Vector3.new(0, 0, 0),
		Sit = false,
		Jump = false,
		PlatformStand = false,
	},
	Players = {},
	ForceField = {},
	RunService = {},
	CollectionService = {},
	MemoryStoreService = {},
	ReplicatedStorage = {},
	ServerScriptService = {},
	StarterPlayer = {},
	StarterPlayerScripts = {},
	PlayerScripts = {},
	ModuleScript = {},
	LocalScript = {},
}

function ClassData.getParent(className: string): string?
	return parentByClass[className]
end

function ClassData.isSupported(className: string): boolean
	return parentByClass[className] ~= nil or className == "Instance"
end

function ClassData.isCreatable(className: string): boolean
	return not nonCreatableClasses[className]
end

function ClassData.isA(className: string, targetClassName: string): boolean
	local cursor = className

	while cursor ~= nil do
		if cursor == targetClassName then
			return true
		end

		cursor = parentByClass[cursor]
	end

	return false
end

function ClassData.getDefaults(className: string)
	local merged = {}
	local lineage = {}
	local cursor = className

	while cursor ~= nil do
		table.insert(lineage, 1, cursor)
		cursor = parentByClass[cursor]
	end

	for _, ancestor in ipairs(lineage) do
		for key, value in pairs(defaultPropsByClass[ancestor] or {}) do
			merged[key] = value
		end
	end

	return merged
end

function ClassData.list()
	local names = {}

	for className in pairs(parentByClass) do
		table.insert(names, className)
	end

	table.sort(names)

	return names
end

return ClassData
