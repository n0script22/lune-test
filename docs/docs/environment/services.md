# Services

Fake services are created through `game:GetService("...")`. The same service object is returned each time within a given environment.

```lua
local replicatedStorage = game:GetService("ReplicatedStorage")
assert(replicatedStorage == game:GetService("ReplicatedStorage"))
```

By default, these services are available:

- `CollectionService`
- `MemoryStoreService`
- `Players`
- `ReplicatedStorage`
- `RunService`
- `ServerScriptService`
- `StarterPlayer`
- `Workspace`

Use `availableServices` when creating an environment to limit or extend the service list. It must be a map of `serviceName = true/false` entries.

```lua
local env = createEnvironment({
	availableServices = {
		ReplicatedStorage = true,
		MyCustomService = true,
	},
	serviceOverrides = {
		MyCustomService = {
			Ping = function()
				return "pong"
			end,
		},
	},
})

env:install()
assert(game:GetService("MyCustomService"):Ping() == "pong")
env:uninstall()
```

## Instance Services

Generic services such as `ReplicatedStorage`, `ServerScriptService`, and `StarterPlayer` are fake instances. Mounted modules are parented under these services and can be resolved lazily when a test accesses them.

```lua
local shared = game:GetService("ReplicatedStorage")
local module = require(shared.SomeModule)
```

## Workspace

`Workspace` holds live 3D objects and supports geometric queries against `BasePart` descendants (including `Workspace.Terrain`). Shapes are respected (all verified against Studio): `Block` casts as an oriented box, `Ball` as a sphere (radius `min(Size)/2`), `Cylinder` as an X-axis cylinder (length `Size.X`, radius `min(Size.Y, Size.Z)/2`), `Wedge` as a ramp with its tall face at `+Z` tapering to the `-Z` bottom edge (solid `y <= z`), and `CornerWedge` as a double ramp peaking at the (`+X`, `-Z`) top corner (solid `y <= min(x, -z)`):

```lua
local wall = Instance.new("Part", workspace)
wall.Name = "Wall"
wall.Position = Vector3.new(5, 0, 0)
wall.Size = Vector3.new(2, 2, 2)

local hit = workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0))

assert(hit.Instance == wall)
assert(hit.Position == Vector3.new(4, 0, 0))
assert(hit.Distance == 4)
assert(hit.Normal == Vector3.new(-1, 0, 0))
assert(hit.Material == Enum.Material.Plastic)
```

The direction vector encodes the max distance, so rays shorter than the gap miss — and a ray ending exactly on a face misses too (hits need `t < 1`). A `nil` result means no eligible part was hit. A ray starting inside a part passes through it (but can still hit parts beyond).

Use `ExcludeInstances`/`IncludeInstances` to filter candidates (exclusions win; an empty include list hits nothing):

```lua
local params = RaycastParams.new()
params.ExcludeInstances = { character }

local hit = workspace:Raycast(origin, direction, params)
```

Parts with `CanQuery` off are skipped (`RespectCanCollide` swaps the check to `CanCollide`; `BruteForceAllSlow` skips only `CanQuery`/`CanCollide` — collision groups, `Exclude`/`Include` filters and `IgnoreWater` still apply). Collision groups registered with `RegisterCollisionGroup` participate too: parts whose group is non-collidable with the query `CollisionGroup` are ignored. Renaming a group onto an existing name is a silent no-op.

```lua
workspace:RegisterCollisionGroup("Ghosts")
workspace:RegisterCollisionGroup("Walls")
workspace:CollisionGroupSetCollidable("Ghosts", "Walls", false)

local params = RaycastParams.new()
params.CollisionGroup = "Ghosts"

assert(workspace:Raycast(origin, direction, params) == nil)
```

`Workspace.Terrain` exists by default with an empty volume, so it never hits until a test gives it `Position` and `Size`. Water terrain is skipped when `IgnoreWater` is set:

```lua
workspace.Terrain.Position = Vector3.new(0, -6, 0)
workspace.Terrain.Size = Vector3.new(100, 2, 100)

local hit = workspace:Raycast(Vector3.new(0, 10, 0), Vector3.new(0, -30, 0))
assert(hit.Instance == workspace.Terrain)
```

Shape queries sweep a volume along a direction and skip parts the shape starts inside; unlike rays, sweeps count exact-touch (`t = 1`) as hits. `Ball` targets sweep as spheres (radius `min(Size)/2`) and `Cylinder` targets sweep as X-axis cylinders; `Wedge`/`CornerWedge` targets sweep as boxes. Casters follow the same rule: `Ball` parts cast as spheres, `Block`/`Cylinder` parts cast as boxes, and `Wedge`/`CornerWedge` parts cast with their exact shape (all matching the engine):

```lua
local hit = workspace:Spherecast(Vector3.new(0, 0, 0), 1, Vector3.new(10, 0, 0))
local blockHit = workspace:Blockcast(CFrame.new(0, 0, 0), Vector3.new(2, 2, 2), Vector3.new(10, 0, 0))
local shapeHit = workspace:Shapecast(handle, Vector3.new(10, 0, 0))
```

Part shape affects raycasts (a ray through a box corner outside the inscribed sphere/cylinder/wedge misses):

```lua
local ball = Instance.new("Part", workspace)
ball.Position = Vector3.new(5, 0, 0)
ball.Size = Vector3.new(2, 2, 2)
ball.Shape = Enum.PartType.Ball

assert(workspace:Raycast(Vector3.new(0, 0.9, 0.9), Vector3.new(10, 0, 0)) == nil)
assert(workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0)).Instance == ball)
```

`UnionOperation` and `MeshPart` are `BasePart`s whose queries follow `CollisionFidelity` (verified against Studio): `Box` casts the bounding box, `Hull` a single convex hull, and `Default`/`PreciseConvexDecomposition` the exact convex decomposition. The same rule applies when a union or mesh is the shapecast caster. Concave unions come from the real CSG APIs — `Part:UnionAsync`/`SubtractAsync`/`IntersectAsync` (single result) or `GeometryService` (array result, `SplitApart` defaulting to `true`; mesh input yields mesh output). Results are bbox-centered with their decomposition stored, so later `Size` edits scale the geometry and `Clone()` carries the decomposition over:

```lua
local slab = Instance.new("Part", workspace)
slab.Size = Vector3.new(4, 4, 4)
slab.CFrame = CFrame.new(0, 2, 0)

local cap = Instance.new("Part", workspace)
cap.Size = Vector3.new(4, 4, 4)
cap.CFrame = CFrame.new(2, 6, 0)

local union = slab:UnionAsync({ cap }, Enum.CollisionFidelity.PreciseConvexDecomposition)
union.Parent = workspace
slab:Destroy()
cap:Destroy()

-- Bounding fidelity hits the empty corner; exact fidelity misses it.
union.CollisionFidelity = Enum.CollisionFidelity.Box
assert(workspace:Raycast(Vector3.new(-1, 6, -10), Vector3.new(0, 0, 20)) ~= nil)

union.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
assert(workspace:Raycast(Vector3.new(-1, 6, -10), Vector3.new(0, 0, 20)) == nil)
```

```lua
local geometry = game:GetService("GeometryService")

local first = Instance.new("Part", workspace)
first.Size = Vector3.new(2, 2, 2)
first.CFrame = CFrame.new(0, 20, 0)

local second = Instance.new("Part", workspace)
second.Size = Vector3.new(2, 2, 2)
second.CFrame = CFrame.new(50, 20, 0)

-- SplitApart defaults to true, so disjoint bodies come back separately.
local results = geometry:UnionAsync(first, { second })
assert(#results == 2)
assert(results[1].ClassName == "UnionOperation")
```

## RunService

`RunService` exposes:

- `Heartbeat`
- `Stepped`
- `RenderStepped`
- `IsStudio()`
- `IsServer()`
- `IsClient()`

The three signals fire when the scheduler advances by a positive amount.

```lua
local env = getEnvironment()
local runService = game:GetService("RunService")

local dt
runService.Heartbeat:Connect(function(deltaTime)
	dt = deltaTime
end)

env.scheduler:advance(0.25)
assert(dt == 0.25)
```

`IsStudio`, `IsServer`, and `IsClient` read from environment config flags.

`RunService` also exposes `PreSimulation` and `PostSimulation` (physics-step time, which may deviate from wall `dt`).

## Workspace authority

`Workspace` exposes the server-authority stack:

- `AuthorityMode` (`Automatic` default, `Server` for server authority)
- `UseFixedSimulation` (`Disabled` default, `Enabled` for fixed-step sim)
- `SignalBehavior` (`Default`, `Immediate`, `Deferred`, `AncestryDeferred`)
- `NextGenerationReplication` (`Disabled`/`Enabled`)
- `StreamingEnabled` (default `true`)
- `DistributedGameTime` (elapsed game time) and `GetServerTimeNow()` (monotonic server approx)

```lua
local env = createEnvironment({
	workspace = {
		AuthorityMode = "Server",
	},
})

local workspace = env.game:GetService("Workspace")
assert(workspace.SignalBehavior == "Deferred")
assert(workspace.UseFixedSimulation == "Enabled")
```

Setting `AuthorityMode` to `Server` auto-enables `NextGenerationReplication`, `Deferred` signals, fixed simulation, and streaming, like the engine.

## Server simulation

`RunService:BindToSimulation(fn, freq, prio)` and `BindToAnimation` run at a fixed frequency independent of framerate when `UseFixedSimulation` is enabled (`Hz60`/`Hz30`/`Hz15`/`Hz10`/`Hz5`/`Hz1`, lower `prio` first). `IsResimulating()`, `Misprediction`, and `Rollback` cover resimulation; `env:forceMispredict` drives a deterministic rollback in tests.

```lua
local env = createEnvironment({
	workspace = {
		UseFixedSimulation = "Enabled",
	},
})
local runService = env.game:GetService("RunService")

local count = 0
runService:BindToSimulation(function(dt)
	count += 1
end, "Hz60")

env.scheduler:advance(1)
assert(count == 60)
```

Inside sim-bound functions, writes to unsynchronized properties on in-DataModel instances error (store custom state in attributes and apply it in `PostSimulation`/`RenderStepped`); only replicated attributes (first 64, name ≤50, string value ≤50) are tracked for rollback. Instances created inside sim must be parented into the DataModel the same frame (instance stitching).

## Players

`Players` exposes:

- `LocalPlayer`
- `PlayerAdded`
- `PlayerRemoving`
- `GetPlayers()`
- `GetPlayerByUserId(userId)`

In a client-capable environment, a default `LocalPlayer` is created unless `activePlayers` is provided.

```lua
local env = getEnvironment()
local players = game:GetService("Players")

local player = env:addPlayer({
	name = "TestPlayer",
	userId = 42,
	createCharacter = true,
})

assert(players:GetPlayerByUserId(42) == player)
assert(player.Character ~= nil)
```

Player helpers on the environment include `addPlayer`, `assignLocalPlayer`, `getPlayers`, `removePlayer`, and `replaceCharacter`.

## CollectionService

`CollectionService` supports:

- `AddTag(instance, tag)`
- `RemoveTag(instance, tag)`
- `HasTag(instance, tag)`
- `GetTagged(tag)`
- `GetInstanceAddedSignal(tag)`
- `GetInstanceRemovedSignal(tag)`

Instances also expose matching tag helpers:

- `instance:AddTag(tag)`
- `instance:RemoveTag(tag)`
- `instance:HasTag(tag)`
- `instance:GetTags()`

`GetTagged` only returns tagged instances that are currently in the fake data model.

```lua
local collectionService = game:GetService("CollectionService")
local part = Instance.new("Part", workspace)

collectionService:AddTag(part, "Interactable")
assert(part:HasTag("Interactable"))
assert(collectionService:GetTagged("Interactable")[1] == part)
```

## MemoryStoreService

`MemoryStoreService` provides in-memory sorted maps and queues.

Sorted maps support:

- `GetAsync(key)`
- `SetAsync(key, value, expirationSeconds, sortKey)`
- `UpdateAsync(key, transform, expirationSeconds)`
- `RemoveAsync(key)`
- `GetRangeAsync(sortDirection, count)`
- `ListItemsAsync()`

```lua
local map = game:GetService("MemoryStoreService"):GetSortedMap("scores")

map:SetAsync("player-a", 10, nil, 10)
map:SetAsync("player-b", 25, nil, 25)

local top = map:GetRangeAsync(Enum.SortDirection.Descending, 1)
assert(top[1].key == "player-b")
```

Queues support:

- `AddAsync(value, expirationSeconds, priority)`
- `ReadAsync(count, allOrNothing, waitTimeout)`
- `RemoveAsync(reservationId)`
- `GetSizeAsync(excludeInvisible)`

```lua
local queue = game:GetService("MemoryStoreService"):GetQueue("jobs")

queue:AddAsync("first")

local values, reservationId = queue:ReadAsync(1)
assert(values[1] == "first")

queue:RemoveAsync(reservationId)
assert(queue:GetSizeAsync() == 0)
```

The fake service also has `SetAdapter(name, adapter)` and `GetAdapter(name)` for test-owned persistence adapters.
