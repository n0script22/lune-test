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

Generic services such as `ReplicatedStorage`, `ServerScriptService`, `StarterPlayer`, and `Workspace` are fake instances. Mounted modules are parented under these services and can be resolved lazily when a test accesses them.

```lua
local shared = game:GetService("ReplicatedStorage")
local module = require(shared.SomeModule)
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
