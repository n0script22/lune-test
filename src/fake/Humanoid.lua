local Signal = require("./Signal")
local Vector3 = require("./Vector3")

local Humanoid = {}

local MOVE_TO_TIMEOUT_SECONDS = 8

local UNSETTABLE_STATES = {
	None = true,
	StrafingNoPhysics = true,
}

local ALL_STATES = {
	"FallingDown",
	"Ragdoll",
	"GettingUp",
	"Jumping",
	"Swimming",
	"Freefall",
	"Flying",
	"Landed",
	"Running",
	"RunningNoPhysics",
	"StrafingNoPhysics",
	"Climbing",
	"Seated",
	"PlatformStanding",
	"Dead",
	"Physics",
	"None",
}

local function newStateEnabledMap()
	local enabled = {}

	for _, state in ipairs(ALL_STATES) do
		enabled[state] = true
	end

	return enabled
end

local function getNumberProperty(self, name: string, fallback: number): number
	local properties = rawget(self, "_properties")
	local value = properties[name]

	if type(value) == "number" then
		return value
	end

	return fallback
end

local function bypassSet(self, propertyName: string, value)
	rawset(self, "_humanoidBypass", true)
	self[propertyName] = value
	rawset(self, "_humanoidBypass", false)
end

local function fireEvent(self, eventName: string, ...)
	local signal = rawget(self, "_properties")[eventName]

	if signal ~= nil then
		signal:Fire(...)
	end
end

local function getRootPart(self)
	return rawget(self, "_properties").RootPart
end

local function getMoveSpeed(self): number
	local rootPart = getRootPart(self)

	if type(rootPart) == "table" then
		local velocity = rootPart.Velocity

		if type(velocity) == "table" and type(velocity.Magnitude) == "number" then
			return velocity.Magnitude
		end
	end

	return 0
end

local function applyState(self, oldState: string, newState: string)
	rawset(self, "_humanoidState", newState)
	fireEvent(self, "StateChanged", oldState, newState)

	if oldState == "Seated" then
		fireEvent(self, "Seated", false, rawget(self, "_properties").SeatPart)
	elseif oldState == "Jumping" then
		fireEvent(self, "Jumping", false)
	elseif oldState == "Freefall" then
		fireEvent(self, "FreeFalling", false)
	elseif oldState == "FallingDown" then
		fireEvent(self, "FallingDown", false)
	elseif oldState == "GettingUp" then
		fireEvent(self, "GettingUp", false)
	elseif oldState == "Ragdoll" then
		fireEvent(self, "Ragdoll", false)
	elseif oldState == "StrafingNoPhysics" then
		fireEvent(self, "Strafing", false)
	elseif oldState == "PlatformStanding" then
		fireEvent(self, "PlatformStanding", false)
	end

	if newState == "Running" or newState == "RunningNoPhysics" then
		fireEvent(self, "Running", getMoveSpeed(self))
	elseif newState == "Jumping" then
		fireEvent(self, "Jumping", true)
	elseif newState == "Seated" then
		fireEvent(self, "Seated", true, rawget(self, "_properties").SeatPart)
	elseif newState == "Climbing" then
		fireEvent(self, "Climbing", getMoveSpeed(self))
	elseif newState == "Swimming" then
		fireEvent(self, "Swimming", getMoveSpeed(self))
	elseif newState == "Freefall" then
		fireEvent(self, "FreeFalling", true)
	elseif newState == "FallingDown" then
		fireEvent(self, "FallingDown", true)
	elseif newState == "GettingUp" then
		fireEvent(self, "GettingUp", true)
	elseif newState == "Ragdoll" then
		fireEvent(self, "Ragdoll", true)
	elseif newState == "StrafingNoPhysics" then
		fireEvent(self, "Strafing", true)
	elseif newState == "PlatformStanding" then
		fireEvent(self, "PlatformStanding", true)
	end
end

local function isInWorkspace(self): boolean
	local cursor = rawget(self, "_parent")

	while cursor ~= nil do
		if rawget(cursor, "ClassName") == "Workspace" then
			return true
		end

		cursor = rawget(cursor, "_parent")
	end

	return false
end

local function kill(self)
	if rawget(self, "_humanoidDied") == true then
		return
	end

	rawset(self, "_humanoidDied", true)
	local oldState = rawget(self, "_humanoidState")
	rawset(self, "_humanoidState", "Dead")
	fireEvent(self, "StateChanged", oldState, "Dead")
	fireEvent(self, "Died")
end

local function maybeDie(self)
	local enabled = rawget(self, "_humanoidStateEnabled")

	if enabled == nil or enabled.Dead ~= true then
		return
	end

	if not isInWorkspace(self) then
		return
	end

	kill(self)
end

function Humanoid.setHealth(self, value)
	local maxHealth = getNumberProperty(self, "MaxHealth", 100)
	local clamped = math.min(math.max(value, 0), math.max(maxHealth, 0))

	if rawget(self, "_humanoidDied") == true then
		clamped = 0
	end

	local oldHealth = getNumberProperty(self, "Health", maxHealth)

	bypassSet(self, "Health", clamped)

	if clamped ~= oldHealth then
		local increasingFromFull = clamped > oldHealth and oldHealth >= maxHealth

		if not increasingFromFull then
			fireEvent(self, "HealthChanged", clamped)
		end

		if clamped <= 0 then
			maybeDie(self)
		end
	end
end

function Humanoid.cancelMoveTo(self)
	if rawget(self, "_humanoidMoveActive") ~= true then
		return
	end

	rawset(self, "_humanoidMoveActive", false)
	rawset(self, "_humanoidMoveToken", (rawget(self, "_humanoidMoveToken") or 0) + 1)
	fireEvent(self, "MoveToFinished", false)
end

function Humanoid.refreshRootPart(self)
	if rawget(self, "_humanoidRootManual") == true then
		return
	end

	local parent = rawget(self, "_parent")
	local rootPart = nil

	if type(parent) == "table" and parent._isFakeRobloxInstance then
		local candidate = parent:FindFirstChild("HumanoidRootPart")

		if type(candidate) == "table" and candidate:IsA("BasePart") then
			rootPart = candidate
		end
	end

	bypassSet(self, "RootPart", rootPart)
end

local function isForceFieldProtected(self): boolean
	local function hasForceFieldChild(instance): boolean
		for _, child in ipairs(instance:GetChildren()) do
			if rawget(child, "ClassName") == "ForceField" then
				return true
			end
		end

		return false
	end

	local rootPart = getRootPart(self)

	if type(rootPart) == "table" and hasForceFieldChild(rootPart) then
		return true
	end

	local cursor = rawget(self, "_parent")

	while cursor ~= nil do
		if rawget(cursor, "ClassName") == "Workspace" then
			break
		end

		if hasForceFieldChild(cursor) then
			return true
		end

		cursor = rawget(cursor, "_parent")
	end

	return false
end

local function toUnitOrZero(direction)
	local magnitude = direction.X * direction.X + direction.Y * direction.Y + direction.Z * direction.Z

	if magnitude <= 0 then
		return Vector3.new(0, 0, 0)
	end

	magnitude = math.sqrt(magnitude)
	return Vector3.new(direction.X / magnitude, direction.Y / magnitude, direction.Z / magnitude)
end

function Humanoid.interceptPropertySet(self, propertyName: string, value, isBypass)
	if isBypass then
		return "standard"
	end

	if propertyName == "MoveDirection" or propertyName == "FloorMaterial" then
		return "error", `Unable to assign property {propertyName}. Property is read only`
	end

	if propertyName == "Health" then
		Humanoid.setHealth(self, value)
		return "handled"
	end

	if propertyName == "MaxHealth" then
		local clampedMax = math.max(value, 0)
		bypassSet(self, "MaxHealth", clampedMax)

		if getNumberProperty(self, "Health", clampedMax) > clampedMax then
			Humanoid.setHealth(self, clampedMax)
		end

		return "handled"
	end

	if propertyName == "Sit" then
		bypassSet(self, "Sit", value)

		if value == true then
			if rawget(self, "_humanoidDied") ~= true then
				local oldState = rawget(self, "_humanoidState")

				if oldState ~= "Seated" then
					applyState(self, oldState, "Seated")
				end
			end
		elseif rawget(self, "_humanoidState") == "Seated" then
			applyState(self, "Seated", "Running")
		end

		return "handled"
	end

	if propertyName == "Jump" then
		bypassSet(self, "Jump", value)

		if value == true and rawget(self, "_humanoidDied") ~= true then
			local current = rawget(self, "_humanoidState")

			if current == "Seated" then
				bypassSet(self, "Sit", false)
				applyState(self, "Seated", "Jumping")
			elseif current ~= "Jumping" then
				local enabled = rawget(self, "_humanoidStateEnabled")

				if enabled == nil or enabled.Jumping == true then
					applyState(self, current, "Jumping")
				end
			end
		end

		return "handled"
	end

	if propertyName == "PlatformStand" then
		bypassSet(self, "PlatformStand", value)

		if value == true then
			local current = rawget(self, "_humanoidState")

			if current ~= "PlatformStanding" and rawget(self, "_humanoidDied") ~= true then
				applyState(self, current, "PlatformStanding")
			end
		elseif rawget(self, "_humanoidState") == "PlatformStanding" then
			applyState(self, "PlatformStanding", "Running")
		end

		return "handled"
	end

	if propertyName == "RootPart" then
		rawset(self, "_humanoidRootManual", true)
		return "standard"
	end

	if propertyName == "WalkToPoint" or propertyName == "WalkToPart" then
		Humanoid.cancelMoveTo(self)
		return "standard"
	end

	return "standard"
end

function Humanoid.changeState(self, state)
	if state == nil then
		return
	end

	if UNSETTABLE_STATES[state] == true then
		return
	end

	local enabled = rawget(self, "_humanoidStateEnabled")

	if enabled ~= nil and enabled[state] ~= true then
		return
	end

	if rawget(self, "_humanoidDied") == true then
		return
	end

	if state == "Dead" then
		Humanoid.setHealth(self, 0)
		return
	end

	if state == "PlatformStanding" then
		state = "Running"
	elseif state == "Swimming" then
		state = "GettingUp"
	end

	local current = rawget(self, "_humanoidState")

	if current == state then
		return
	end

	applyState(self, current, state)
end

function Humanoid.configure(runtime, humanoid)
	rawset(humanoid, "_humanoidDied", false)
	rawset(humanoid, "_humanoidState", "Running")
	rawset(humanoid, "_humanoidStateEnabled", newStateEnabledMap())
	rawset(humanoid, "_humanoidMoveToken", 0)
	rawset(humanoid, "_humanoidMoveActive", false)
	rawset(humanoid, "_humanoidRootManual", false)

	humanoid.Died = Signal.new("Humanoid.Died", rawget(humanoid, "_signalRegistry"))
	humanoid.HealthChanged = Signal.new("Humanoid.HealthChanged", rawget(humanoid, "_signalRegistry"))
	humanoid.StateChanged = Signal.new("Humanoid.StateChanged", rawget(humanoid, "_signalRegistry"))
	humanoid.StateEnabledChanged =
		Signal.new("Humanoid.StateEnabledChanged", rawget(humanoid, "_signalRegistry"))
	humanoid.MoveToFinished = Signal.new("Humanoid.MoveToFinished", rawget(humanoid, "_signalRegistry"))
	humanoid.Running = Signal.new("Humanoid.Running", rawget(humanoid, "_signalRegistry"))
	humanoid.Jumping = Signal.new("Humanoid.Jumping", rawget(humanoid, "_signalRegistry"))
	humanoid.Seated = Signal.new("Humanoid.Seated", rawget(humanoid, "_signalRegistry"))
	humanoid.Climbing = Signal.new("Humanoid.Climbing", rawget(humanoid, "_signalRegistry"))
	humanoid.Swimming = Signal.new("Humanoid.Swimming", rawget(humanoid, "_signalRegistry"))
	humanoid.FreeFalling = Signal.new("Humanoid.FreeFalling", rawget(humanoid, "_signalRegistry"))
	humanoid.FallingDown = Signal.new("Humanoid.FallingDown", rawget(humanoid, "_signalRegistry"))
	humanoid.GettingUp = Signal.new("Humanoid.GettingUp", rawget(humanoid, "_signalRegistry"))
	humanoid.Strafing = Signal.new("Humanoid.Strafing", rawget(humanoid, "_signalRegistry"))
	humanoid.PlatformStanding =
		Signal.new("Humanoid.PlatformStanding", rawget(humanoid, "_signalRegistry"))
	humanoid.Ragdoll = Signal.new("Humanoid.Ragdoll", rawget(humanoid, "_signalRegistry"))
	humanoid.Touched = Signal.new("Humanoid.Touched", rawget(humanoid, "_signalRegistry"))

	humanoid.GetState = function(self)
		return rawget(self, "_humanoidState")
	end

	humanoid.ChangeState = function(self, state)
		Humanoid.changeState(self, state)
	end

	humanoid.GetStateEnabled = function(self, state)
		local enabled = rawget(self, "_humanoidStateEnabled")

		if enabled == nil then
			return true
		end

		return enabled[state] ~= false
	end

	humanoid.SetStateEnabled = function(self, state, enabled)
		assert(type(enabled) == "boolean", "SetStateEnabled expects a boolean")
		rawget(self, "_humanoidStateEnabled")[state] = enabled
		fireEvent(self, "StateEnabledChanged", state, enabled)
	end

	local function takeDamage(self, amount)
		assert(type(amount) == "number", "TakeDamage expects a number")

		if isForceFieldProtected(self) then
			return
		end

		Humanoid.setHealth(self, getNumberProperty(self, "Health", 100) - amount)
	end

	humanoid.TakeDamage = takeDamage
	humanoid.takeDamage = takeDamage

	humanoid.Move = function(self, direction, relativeToCamera)
		assert(type(direction) == "table" and direction.X ~= nil, "Move expects a Vector3")

		local resolved = direction

		if relativeToCamera == true and runtime ~= nil then
			local workspace = runtime:getService("Workspace")
			local camera = if workspace ~= nil then workspace.CurrentCamera else nil
			local cameraCFrame = if type(camera) == "table" then camera.CFrame else nil

			if type(cameraCFrame) == "table" and cameraCFrame.VectorToWorldSpace ~= nil then
				resolved = cameraCFrame:VectorToWorldSpace(direction)
			end
		end

		bypassSet(self, "MoveDirection", toUnitOrZero(resolved))
		Humanoid.cancelMoveTo(self)
	end

	humanoid.MoveTo = function(self, location, part)
		assert(type(location) == "table" and location.X ~= nil, "MoveTo expects a Vector3")

		local token = (rawget(self, "_humanoidMoveToken") or 0) + 1
		rawset(self, "_humanoidMoveToken", token)
		rawset(self, "_humanoidMoveActive", true)

		bypassSet(self, "WalkToPoint", location)
		bypassSet(self, "WalkToPart", part)

		if runtime ~= nil and runtime.scheduler ~= nil then
			runtime.scheduler:delay(MOVE_TO_TIMEOUT_SECONDS, function()
				if
					rawget(self, "_destroyed") ~= true
					and rawget(self, "_humanoidMoveToken") == token
					and rawget(self, "_humanoidMoveActive") == true
				then
					rawset(self, "_humanoidMoveActive", false)
					fireEvent(self, "MoveToFinished", false)
				end
			end)
		end
	end

	humanoid.EquipTool = function(self, tool)
		assert(type(tool) == "table" and tool._isFakeRobloxInstance and tool:IsA("Tool"), "EquipTool expects a Tool")
		tool.Parent = rawget(self, "_parent")
	end

	humanoid.UnequipTools = function(self)
		local character = rawget(self, "_parent")

		if type(character) ~= "table" then
			return
		end

		local backpack = nil

		if runtime ~= nil then
			local playersService = runtime:getService("Players")

			if playersService ~= nil then
				for _, player in ipairs(playersService:GetPlayers()) do
					if rawget(player, "_properties").Character == character then
						backpack = player:FindFirstChild("Backpack")

						break
					end
				end
			end
		end

		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and backpack ~= nil then
				child.Parent = backpack
			end
		end
	end

	humanoid.GetMoveVelocity = function(self)
		local rootPart = getRootPart(self)

		if type(rootPart) == "table" and type(rootPart.Velocity) == "table" then
			return rootPart.Velocity
		end

		return Vector3.new(0, 0, 0)
	end

	humanoid.GetRelativeVelocityAtFloor = function(self)
		return humanoid:GetMoveVelocity()
	end

	bypassSet(humanoid, "RootPart", nil)
	bypassSet(humanoid, "SeatPart", nil)
	bypassSet(humanoid, "WalkToPart", nil)

	if getNumberProperty(humanoid, "Health", 100) <= 0 then
		Humanoid.setHealth(humanoid, 0)
	end

	Humanoid.refreshRootPart(humanoid)

	local function watchParent()
		local oldWatcher = rawget(humanoid, "_humanoidParentWatcher")

		if oldWatcher ~= nil then
			for _, connection in ipairs(oldWatcher) do
				connection:Disconnect()
			end

			rawset(humanoid, "_humanoidParentWatcher", nil)
		end

		local parent = rawget(humanoid, "_parent")

		if type(parent) ~= "table" or not parent._isFakeRobloxInstance then
			return
		end

		local function onParentChildrenChanged()
			if rawget(humanoid, "_destroyed") == true then
				return
			end

			Humanoid.refreshRootPart(humanoid)
		end

		rawset(humanoid, "_humanoidParentWatcher", {
			parent.ChildAdded:Connect(onParentChildrenChanged),
			parent.ChildRemoved:Connect(onParentChildrenChanged),
		})
	end

	watchParent()

	humanoid.AncestryChanged:Connect(function()
		if rawget(humanoid, "_destroyed") == true then
			return
		end

		Humanoid.refreshRootPart(humanoid)
		watchParent()

		if getNumberProperty(humanoid, "Health", 100) <= 0 then
			maybeDie(humanoid)
		end
	end)
end

return Humanoid
