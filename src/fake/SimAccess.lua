local SimAccess = {}

local SIM_WRITE_ALLOW = {
	Anchored = true,
	CanCollide = true,
	Position = true,
	CFrame = true,
	Velocity = true,
	AssemblyLinearVelocity = true,
	AssemblyAngularVelocity = true,
	RotVelocity = true,
}

function SimAccess.isWriteAllowed(propertyName: string): boolean
	return SIM_WRITE_ALLOW[propertyName] == true
end

function SimAccess.assertWrite(runtime, instance, propertyName: string)
	if runtime == nil or not runtime._inSimCallback then
		return
	end
	local isInDataModel = false
	if runtime._isInDataModel ~= nil then
		isInDataModel = runtime:_isInDataModel(instance)
	end
	if not isInDataModel then
		return
	end
	if SimAccess.isWriteAllowed(propertyName) then
		return
	end
	local className = rawget(instance, "ClassName") or "Instance"
	error(
		`Writing to {className}.{propertyName} is not allowed for simulation callbacks on Instances in the DataModel`,
		2
	)
end

function SimAccess.assertParentWrite(runtime, instance, newParent)
	if runtime == nil or not runtime._inSimCallback then
		return
	end
	local isInDataModel = false
	if runtime._isInDataModel ~= nil then
		isInDataModel = runtime:_isInDataModel(instance)
	end
	if not isInDataModel then
		return
	end
	local className = rawget(instance, "ClassName") or "Instance"
	error(`Writing to {className}.Parent is not allowed for simulation callbacks on Instances in the DataModel`, 2)
end

function SimAccess.assertMethod(runtime, methodName: string)
	if runtime == nil or not runtime._inSimCallback then
		return
	end
	error(`Function Instance.{methodName} is not allowed for simulation callbacks`, 2)
end

return SimAccess
