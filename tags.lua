--[[--------------------------------------------------------------------
	oUF_Phanx
	Fully-featured PVE-oriented layout for oUF.
	Copyright (c) 2008-2012 Phanx <addons@phanx.net>. All rights reserved.
	See the accompanying README and LICENSE files for more information.
	http://www.wowinterface.com/downloads/info13993-oUF_Phanx.html
	http://www.curse.com/addons/wow/ouf-phanx
----------------------------------------------------------------------]]

local _, ns = ...

oUF.TagEvents["unitcolor"] = "UNIT_HEALTH UNIT_CLASSIFICATION UNIT_REACTION"
oUF.Tags["unitcolor"] = function(unit)
	local color
	if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
		color = oUF.colors.disconnected
	elseif UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		color = oUF.colors.class[class]
	elseif UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
		color = oUF.colors.tapped
	elseif UnitIsEnemy(unit, "player") then
		color = oUF.colors.reaction[1]
	else
		color = oUF.colors.reaction[UnitReaction(unit, "player") or 5]
	end
	return color and ("|cff%02x%02x%02x"):format(color[1] * 255, color[2] * 255, color[3] * 255) or "|cffffffff"
end

oUF.TagEvents["powercolor"] = "UNIT_DISPLAYPOWER"
oUF.Tags["powercolor"] = function(unit)
	local _, type = UnitPowerType(unit)
	local color = ns.colors.power[type] or ns.colors.power.FUEL
	return ("|cff%02x%02x%02x"):format(color[1] * 255, color[2] * 255, color[3] * 255)
end

oUF.TagEvents["combaticon"] = "PLAYER_REGEN_DISABLED PLAYER_REGEN_ENABLED"
oUF.UnitlessTagEvents["PLAYER_REGEN_DISABLED"] = true
oUF.UnitlessTagEvents["PLAYER_REGEN_ENABLED"] = true
oUF.Tags["combaticon"] = function(unit)
	if unit == "player" and UnitAffectingCombat("player") then
		return [[|TInterface\CharacterFrame\UI-StateIcon:0:0:0:0:64:64:37:58:5:26|t]]
	end
end

oUF.TagEvents["leadericon"] = "PARTY_LEADER_CHANGED PARTY_MEMBERS_CHANGED"
oUF.UnitlessTagEvents["PARTY_LEADER_CHANGED"] = true
oUF.UnitlessTagEvents["PARTY_MEMBERS_CHANGED"] = true
oUF.Tags["leadericon"] = function(unit)
	if UnitIsPartyLeader(unit) then
		return [[|TInterface\GroupFrame\UI-Group-LeaderIcon:0|t]]
	elseif UnitInRaid(unit) and UnitIsRaidOfficer(unit) then
		return [[|TInterface\GroupFrame\UI-Group-AssistantIcon:0|t]]
	end
end

oUF.TagEvents["mastericon"] = "PARTY_LOOT_METHOD_CHANGED PARTY_MEMBERS_CHANGED"
oUF.UnitlessTagEvents["PARTY_LOOT_METHOD_CHANGED"] = true
oUF.UnitlessTagEvents["PARTY_MEMBERS_CHANGED"] = true
oUF.Tags["mastericon"] = function(unit)
	local method, pid, rid = GetLootMethod()
	if method ~= "master" then return end
	local munit
	if pid then
		if pid == 0 then
			munit = "player"
		else
			munit = "party" .. pid
		end
	elseif rid then
		munit = "raid" .. rid
	end
	if munit and UnitIsUnit(munit, unit) then
		return [[|TInterface\GroupFrame\UI-Group-MasterLooter:0:0:0:2|t]]
	end
end

oUF.TagEvents["restingicon"] = "PLAYER_UPDATE_RESTING"
oUF.UnitlessTagEvents["PLAYER_UPDATE_RESTING"] = true
oUF.Tags["restingicon"] = function(unit)
	if unit == "player" and IsResting() then
		return [[|TInterface\CharacterFrame\UI-StateIcon:0:0:0:-6:64:64:28:6:6:28|t]]
	end
end

do
	local MAELSTROM_WEAPON = GetSpellInfo(53817)
	oUF.TagEvents["maelstrom"] = "UNIT_AURA"
	oUF.Tags["maelstrom"] = function(unit)
		if unit == "player" then
			local name, _, icon, count = UnitBuff("player", MAELSTROM_WEAPON)
			return name and count
		end
	end
end

do
	local EARTH_SHIELD = GetSpellInfo(974)
	local EARTH_TEXT = setmetatable({}, { __index = function(t,i) return ("|cffa7c466%d|r"):format(i) end })

	local LIGHTNING_SHIELD = GetSpellInfo(324)
	local LIGHTNING_TEXT = setmetatable({}, { __index = function(t,i) return ("|cff7f97f7%d|r"):format(i) end })

	local WATER_SHIELD = GetSpellInfo(52127)
	local WATER_TEXT = setmetatable({}, { __index = function(t,i) return ("|cff7cbdff%d|r"):format(i) end })

	oUF.TagEvents["elementalshield"] = "UNIT_AURA"
	oUF.Tags["elementalshield"] = function(unit)
		local name, _, icon, count = UnitBuff(unit, EARTH_SHIELD, nil, "PLAYER")
		if name then return EARTH_TEXT[count] end

		if unit ~= "player" then return end

		name, _, icon, count = UnitBuff(unit, LIGHTNING_SHIELD)
		if name then return LIGHTNING_TEXT[count] end

		name, _, icon, count = UnitBuff(unit, WATER_SHIELD)
		return name and WATER_TEXT[count]
	end
end

oUF.TagEvents["holypower"] = "UNIT_POWER"
oUF.Tags["holypower"] = function(unit)
	if unit == "player" then
		local holypower = UnitPower(unit, SPELL_POWER_HOLY_POWER)
		return holypower > 0 and holypower
	end
end

do
	local EVANGELISM = GetSpellInfo(81661) -- 81660 for rank 1
	local DARK_EVANGELISM = GetSpellInfo(87118) -- 87117 for rank 1
	oUF.TagEvents["evangelism"] = "UNIT_AURA"
	oUF.Tags["evangelism"] = function(unit)
		if unit == "player" then
			local name, _, icon, count = UnitBuff("player", EVANGELISM)
			if name then return count end

			name, _, icon, count = UnitBuff("player", DARK_EVANGELISM)
			return name and count
		end
	end
end

do
	local SHADOW_ORB = GetSpellInfo(77487)
	oUF.TagEvents["shadoworbs"] = "UNIT_AURA"
	oUF.Tags["shadoworbs"] = function(unit)
		if unit == "player" then
			local name, _, icon, count = UnitBuff("player", SHADOW_ORB)
			return name and count
		end
	end
end

oUF.TagEvents["soulshards"] = "UNIT_POWER"
oUF.Tags["soulshards"] = function(unit)
	if unit == "player" then
		local soulshards = UnitPower(unit, SPELL_POWER_SOUL_SHARDS)
		return soulshards > 0 and soulshards
	end
end

oUF.TagEvents["feralmana"] = "UNIT_POWER UNIT_MAXPOWER"
oUF.Tags["feralmana"]  = function(unit)
	if unit == "player" then
		return UnitPower("player", SPELL_POWER_MANA)
	end
end