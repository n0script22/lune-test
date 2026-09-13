# Datatypes and Instances

The fake environment provides several Roblox datatypes and objects.

## Globals

The sandbox exposes:

- `BrickColor`
- `CFrame`
- `Color3`
- `Enum`
- `Instance`
- `Random`
- `RaycastParams`
- `UDim`
- `UDim2`
- `Vector2`
- `Vector3`

`Enum.SortDirection.Ascending` and `Enum.SortDirection.Descending` are available for fake MemoryStore sorted maps. `Enum.RaycastFilterType.Exclude` and `Enum.RaycastFilterType.Include` are available for fake raycasts. `Enum.Material` (including `Plastic`, `SmoothPlastic`, `Wood`, `Metal`, `Glass`, `DiamondPlate`, `Neon`, `Grass`, and `Water`) and `Enum.PartType` (`Block`, `Ball`, `Cylinder`, `Wedge`, `CornerWedge`) are available for parts and shape queries.

## Supported Instance Classes

The fake class table supports:

- `Instance`
- `DataModel`
- `Folder`
- `Model`
- `Tool`
- `Backpack`
- `Workspace`
- `BasePart`
- `Part`
- `SpawnLocation`
- `Terrain`
- `NumberValue`
- `RemoteEvent`
- `RemoteFunction`
- `Player`
- `Players`
- `RunService`
- `CollectionService`
- `MemoryStoreService`
- `ReplicatedStorage`
- `ServerScriptService`
- `StarterPlayer`
- `StarterPlayerScripts`
- `PlayerScripts`
- `ModuleScript`
- `LocalScript`

Service classes and other non-creatable classes are created by the environment, not through `Instance.new`.

```lua
local folder = Instance.new("Folder", workspace)
folder.Name = "Things"

local part = Instance.new("Part", folder)
part.Name = "Block"

assert(workspace.Things.Block == part)
assert(part:GetFullName() == "game.Workspace.Things.Block")
```

## Instance API

Fake instances support:

- `GetFullName()`
- `FindFirstChild(name)`
- `FindFirstChildOfClass(className)`
- `FindFirstChildWhichIsA(className, recursive)`
- `WaitForChild(name, timeout)`
- `GetChildren()`
- `GetDescendants()`
- `IsA(className)`
- `IsDescendantOf(ancestor)`
- `IsAncestorOf(descendant)`
- `GetPropertyChangedSignal(propertyName)`
- `SetAttribute(attributeName, value)`
- `GetAttribute(attributeName)`
- `GetAttributeChangedSignal(attributeName)`
- `AddTag(tag)`
- `RemoveTag(tag)`
- `HasTag(tag)`
- `GetTags()`
- `Destroy()`
- `ClearAllChildren()`
- `Clone()`

Common signals include `Changed`, `ChildAdded`, `ChildRemoved`, `Destroying`, `AncestryChanged`, and `AttributeChanged`.

`BasePart` keeps `Position` and `CFrame` in sync, and setting `Position` preserves the current orientation. New parts default to `Size` of `(4, 1, 2)`, `CanQuery`/`CanCollide`/`CanTouch` on, `Material` of `Plastic`, and the `"Default"` collision group. `Part` adds `Shape` (default `Block`); `Workspace.Terrain` is a `BasePart` with an empty volume until a test sizes it. `NumberValue.Changed` fires with the new value when `Value` changes; other instances use the changed property name.

```lua
local value = Instance.new("NumberValue")
local changed

value.Changed:Connect(function(newValue)
	changed = newValue
end)

value.Value = 10
assert(changed == 10)
```

## RBXScriptSignal

Signals support:

- `Connect(listener)`
- `ConnectPlayer(player, listener)`
- `Fire(...)`
- `FireForPlayer(player, ...)`
- `DisconnectAll()`
- `GetConnectionCount()`
- `GetDebugName()`

`:Connect` returns a `RBXScriptConnection` object.
Connections support `Disconnect()` and expose a `Connected` field.

```lua
local signal = RBXScriptSignal.new("Example")
local count = 0

local connection = signal:Connect(function()
	count += 1
end)

signal:Fire()
connection:Disconnect()
signal:Fire()

assert(count == 1)
```

`ConnectPlayer` and `FireForPlayer` let a signal deliver callbacks to one specific fake player. This is a fake-runtime testing helper used by client-targeted remote events.

## Vector2 and Vector3

`Vector2` supports `new`, `zero`, `one`, `xAxis`, `yAxis`, `Dot`, `Lerp`, arithmetic operators, equality, unary minus, and string conversion.

`Vector3` supports `new`, `zero`, `one`, `xAxis`, `yAxis`, `zAxis`, `Magnitude`, `Unit`, `Dot`, `Cross`, `Lerp`, arithmetic operators, equality, unary minus, and string conversion.

`Magnitude` is the vector length (`math.sqrt(X^2 + Y^2 + Z^2)`) and `Unit` is the normalized direction. `Unit` of a zero vector has `NaN` components, matching the engine.

```lua
local a = Vector3.new(1, 2, 3)
local b = Vector3.new(4, 5, 6)

assert(a + b == Vector3.new(5, 7, 9))
assert(a:Dot(b) == 32)
assert(Vector3.new(3, 4, 0).Magnitude == 5)
assert(Vector3.new(0, 5, 0).Unit == Vector3.new(0, 1, 0))
```

## CFrame

`CFrame` tracks a position plus a 3x3 rotation matrix:

- `CFrame.new(x, y, z)`
- `CFrame.new(vector3)`
- `CFrame.new(vector3, lookAt)`
- `CFrame.new(x, y, z, qX, qY, qZ, qW)` (quaternion)
- `CFrame.new(x, y, z, R00, ...)` (12-number rotation matrix)
- `CFrame.identity`
- `CFrame.lookAt(position, target, up?)`
- `CFrame.lookAlong(position, direction, up?)`
- `CFrame.fromMatrix(position, xVector, yVector, zVector?)`
- `CFrame.Angles(x, y, z)` (= `fromEulerAnglesXYZ`)
- `CFrame.fromEulerAnglesXYZ(x, y, z)`
- `CFrame.fromEulerAnglesYXZ(x, y, z)`
- `CFrame.fromOrientation(x, y, z)` (= `fromEulerAnglesYXZ`)
- `CFrame.fromAxisAngle(axis, angle)`
- `ToOrientation()` (= `ToEulerAnglesYXZ`)
- `ToEulerAnglesXYZ()` / `ToEulerAnglesYXZ()` / `ToEulerAngles(order?)`
- `GetComponents()` / `components`
- `ToAxisAngle()` / `AngleBetween(other)` / `FuzzyEq(other, epsilon?)`
- `Orthonormalize()`
- `ToWorldSpace(cf)` / `ToObjectSpace(cf)`
- `PointToWorldSpace(v)` / `PointToObjectSpace(v)`
- `VectorToWorldSpace(v)` / `VectorToObjectSpace(v)`
- `Lerp(other, alpha)`
- `Inverse()`
- `Position`, `Rotation`, `X/Y/Z`, `LookVector`, `RightVector`/`XVector`, `UpVector`/`YVector`, `ZVector`
- multiplication (compose / transform points), addition, subtraction, equality, and string conversion

```lua
local tilted = CFrame.new(5, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
local point = tilted:PointToWorldSpace(Vector3.new(0, 0, -1))

assert((tilted.LookVector - Vector3.new(-1, 0, 0)).Magnitude < 1e-6)
assert((point - Vector3.new(4, 0, 0)).Magnitude < 1e-6)
```

## RaycastParams

`RaycastParams.new()` returns a blank mutable params object with engine defaults (`FilterType` of `"Exclude"`, empty `FilterDescendantsInstances`, `IgnoreWater` off, `BruteForceAllSlow` off, `RespectCanCollide` off, `CollisionGroup` of `"Default"`). Each call returns an independent object. Prefer the modern filter lists; the legacy `FilterType`/`FilterDescendantsInstances` pair still works and exclusions always win over inclusions. Like the engine, assigning anything other than `Enum.RaycastFilterType.Exclude`/`Include` to `FilterType` errors.

`AddToFilter` accepts a single instance or an array of instances:

```lua
local params = RaycastParams.new()
params.IgnoreWater = true

params:AddToFilter(workspace.Enemies)

assert(params.FilterType == "Exclude")
assert(#params.FilterDescendantsInstances == 1)
```

Modern filtering checks self-or-descendant membership:

```lua
local params = RaycastParams.new()
params.ExcludeInstances = { character }
params.IncludeInstances = { workspace.Arena }

local hit = workspace:Raycast(origin, direction, params)
```

## RaycastResult

Hits return a table with the intersection details:

- `Instance`: the `BasePart` that was hit
- `Position`: world-space intersection point
- `Distance`: distance from the ray origin (travel distance for shape casts)
- `Normal`: face normal at the intersection
- `Material`: the part material at the intersection

```lua
local hit = workspace:Raycast(origin, direction)

if hit ~= nil then
	assert(hit.Instance:IsA("BasePart"))
	assert(hit.Distance >= 0)
end
```

## Color3

`Color3` supports:

- `Color3.new(r, g, b)`
- `Color3.fromRGB(r, g, b)`
- `Color3.fromHSV(h, s, v)`
- `ToHSV()`
- `Lerp(other, alpha)`
- `ToHex()`
- equality and string conversion

RGB components are clamped to `0..1`.

```lua
local color = Color3.fromRGB(255, 0, 128)
assert(color:ToHex() == "FF0080")
```

## UDim and UDim2

`UDim` supports `new`, addition, subtraction, equality, and string conversion.

`UDim2` supports:

- `UDim2.new(xScale, xOffset, yScale, yOffset)`
- `UDim2.fromScale(xScale, yScale)`
- `UDim2.fromOffset(xOffset, yOffset)`
- `Lerp(other, alpha)`
- addition, subtraction, equality, and string conversion

## BrickColor

`BrickColor` supports:

- `BrickColor.new(value)`
- `BrickColor.White()`
- `BrickColor.Gray()` / `BrickColor.Grey()`
- `BrickColor.Black()`
- `BrickColor.Red()`
- `BrickColor.Blue()`
- `BrickColor.Yellow()`
- `BrickColor.Green()`
- `BrickColor.random()`
- `BrickColor.palette(index)`
- `BrickColor.closest(color3)`
- equality and string conversion

Unknown names and numbers fall back to `Medium stone grey`.

## Random

`Random.new(seed)` returns a deterministic random object when a seed is provided.

Random objects support:

- `Clone()`
- `NextNumber(min, max)`
- `NextInteger(min, max)`
- `NextUnitVector()`
- `Shuffle(table)`

```lua
local random = Random.new(123)
local clone = random:Clone()

assert(random:NextInteger(1, 10) == clone:NextInteger(1, 10))
```
