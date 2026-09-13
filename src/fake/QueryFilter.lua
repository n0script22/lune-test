local CollisionGroups = require("./CollisionGroups")
local PartAccess = require("./PartAccess")

local QueryFilter = {}

function QueryFilter.collisionGroupsAreCollidable(workspace, groupA: string, groupB: string): boolean
	if type(workspace) ~= "table" then
		return true
	end

	return CollisionGroups.areCollidable(workspace._collisionGroupData, groupA, groupB)
end

function QueryFilter.isDescendantOrSelf(part, ancestor): boolean
	local cursor = part

	while cursor ~= nil do
		if cursor == ancestor then
			return true
		end

		cursor = cursor.Parent
	end

	return false
end

function QueryFilter.matchesFilterList(part, filterList): boolean
	if type(filterList) ~= "table" then
		return false
	end

	for _, entry in ipairs(filterList) do
		if type(entry) == "table" and entry._isFakeRobloxInstance then
			if QueryFilter.isDescendantOrSelf(part, entry) then
				return true
			end
		end
	end

	return false
end

function QueryFilter.isPartPassingFilters(part, params): boolean
	if params == nil then
		return true
	end

	local excludeList = params.ExcludeInstances
	local includeList = params.IncludeInstances

	if type(excludeList) == "table" and QueryFilter.matchesFilterList(part, excludeList) then
		return false
	end

	if includeList ~= nil then
		if type(includeList) ~= "table" then
			return true
		end

		if #includeList == 0 then
			return false
		end

		if not QueryFilter.matchesFilterList(part, includeList) then
			return false
		end
	end

	local legacyList = params.FilterDescendantsInstances
	local filterType = params.FilterType

	if type(legacyList) == "table" and #legacyList > 0 then
		local matchesLegacy = QueryFilter.matchesFilterList(part, legacyList)

		if filterType == "Include" then
			if not matchesLegacy then
				return false
			end
		elseif matchesLegacy then
			return false
		end
	end

	return true
end

function QueryFilter.isPartQueryEligible(part, params, workspace)
	if params ~= nil and params.IgnoreWater == true and part.ClassName == "Terrain" and part.Material == "Water" then
		return false
	end

	if not QueryFilter.isPartPassingFilters(part, params) then
		return false
	end

	-- Engine (verified against Studio): BruteForceAllSlow bypasses only the
	-- CanQuery/CanCollide flag check. Collision groups, filters and
	-- IgnoreWater still apply.
	if params == nil or params.BruteForceAllSlow ~= true then
		local respectCanCollide = params ~= nil and params.RespectCanCollide == true
		local flag = if respectCanCollide then part.CanCollide else part.CanQuery

		if flag == nil then
			flag = true
		end

		if flag == false then
			return false
		end
	end

	local partGroup = part.CollisionGroup

	if partGroup == nil then
		partGroup = "Default"
	end

	local queryGroup = "Default"

	if params ~= nil and params.CollisionGroup ~= nil then
		queryGroup = params.CollisionGroup
	end

	if workspace ~= nil and not QueryFilter.collisionGroupsAreCollidable(workspace, partGroup, queryGroup) then
		return false
	end

	return true
end

function QueryFilter.collectCandidateParts(workspace, params, excludePart)
	local parts = {}

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= excludePart then
			if QueryFilter.isPartQueryEligible(descendant, params, workspace) then
				local size = PartAccess.getPartSize(descendant)

				if size.X > 0 and size.Y > 0 and size.Z > 0 then
					table.insert(parts, descendant)
				end
			end
		end
	end

	return parts
end

function QueryFilter.buildResult(part, position, distance, normal)
	local material = part.Material

	if material == nil then
		material = "Plastic"
	end

	return {
		Instance = part,
		Position = position,
		Distance = distance,
		Normal = normal,
		Material = material,
	}
end

return QueryFilter
