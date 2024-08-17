--[[--------------------------------------------------------------------
	oUF_Phanx
	Fully-featured PVE-oriented layout for oUF.
	Copyright 2008-2018 Phanx <addons@phanx.net>. All rights reserved.
	https://www.wowinterface.com/downloads/info13993-oUF_Phanx.html
	https://www.curseforge.com/wow/addons/ouf-phanx
	https://github.com/Phanx/oUF_Phanx
----------------------------------------------------------------------]]

local _, ns = ...

local GetLootMethod, IsResting, UnitAffectingCombat, UnitClass, UnitInRaid, UnitIsConnected, UnitIsDeadOrGhost, UnitIsEnemy, UnitIsGroupAssistant, UnitIsGroupLeader, UnitIsPlayer, UnitIsTapped, UnitIsTappedByPlayer, UnitIsUnit, UnitPowerType, UnitReaction = GetLootMethod, IsResting, UnitAffectingCombat, UnitClass, UnitInRaid, UnitIsConnected, UnitIsDeadOrGhost, UnitIsEnemy, UnitIsGroupAssistant, UnitIsGroupLeader, UnitIsPlayer, UnitIsTapped, UnitIsTappedByPlayer, UnitIsUnit, UnitPowerType, UnitReaction

------------------------------------------------------------------------
--	Colors

oUF.Tags.Events["unitcolor"] = "UNIT_HEALTH UNIT_CONNECTION UNIT_FACTION UNIT_THREAT_SITUATION_UPDATE"
oUF.Tags.Methods["unitcolor"] = function(unit)
	local color = ns.GetUnitColor(unit)
	return format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

oUF.Tags.Events["powercolor"] = "UNIT_DISPLAYPOWER"
oUF.Tags.Methods["powercolor"] = function(unit)
	local _, type = UnitPowerType(unit)
	local color = ns.colors.power[type] or ns.colors.power.FUEL
	return format("|cff%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
end

------------------------------------------------------------------------
--	Icons

oUF.Tags.Events["combaticon"] = "PLAYER_REGEN_DISABLED PLAYER_REGEN_ENABLED"
oUF.Tags.SharedEvents["PLAYER_REGEN_DISABLED"] = true
oUF.Tags.SharedEvents["PLAYER_REGEN_ENABLED"] = true
oUF.Tags.Methods["combaticon"] = function(unit)
	if unit == "player" and UnitAffectingCombat("player") then
		return [[|TInterface\CharacterFrame\UI-StateIcon:0:0:0:0:64:64:37:58:5:26|t]]
	end
end

oUF.Tags.Events["leadericon"] = "GROUP_ROSTER_UPDATE"
oUF.Tags.SharedEvents["GROUP_ROSTER_UPDATE"] = true
oUF.Tags.Methods["leadericon"] = function(unit)
	if UnitIsGroupLeader(unit) then
		return [[|TInterface\GroupFrame\UI-Group-LeaderIcon:0|t]]
	elseif UnitInRaid(unit) and UnitIsGroupAssistant(unit) then
		return [[|TInterface\GroupFrame\UI-Group-AssistantIcon:0|t]]
	end
end

oUF.Tags.Events["restingicon"] = "PLAYER_UPDATE_RESTING"
oUF.Tags.SharedEvents["PLAYER_UPDATE_RESTING"] = true
oUF.Tags.Methods["restingicon"] = function(unit)
	if unit == "player" and IsResting() then
		return [[|TInterface\CharacterFrame\UI-StateIcon:0:0:0:-6:64:64:28:6:6:28|t]]
	end
end

oUF.Tags.Methods["battlepeticon"] = function(unit)
	if UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit) then
		local petType = UnitBattlePetType(unit)
		return [[|TInterface\TargetingFrame\PetBadge-]] .. PET_TYPE_SUFFIX[petType]
	end
end

------------------------------------------------------------------------
--	Threat

do
	local colors = {
		[0] = "|cffffffff",
		[1] = "|cffffff33",
		[2] = "|cffff9933",
		[3] = "|cffff3333",
	}
	oUF.Tags.Events["threatpct"] = "UNIT_THREAT_LIST_UPDATE"
	oUF.Tags.Methods["threatpct"] = function(unit)
		local isTanking, status, percentage, rawPercentage = UnitDetailedThreatSituation("player", unit)
		local pct = rawPercentage
		if isTanking then
			pct = UnitThreatPercentageOfLead("player", unit)
		end
		if pct and pct > 0 and pct < 300 then
			return format("%s%d%%", colors[status] or colors[0], pct + 0.5)
		end
	end
end
