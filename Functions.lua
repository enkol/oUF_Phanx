--[[--------------------------------------------------------------------
	oUF_Phanx
	Fully-featured PVE-oriented layout for oUF.
	Copyright 2008-2018 Phanx <addons@phanx.net>. All rights reserved.
	https://www.wowinterface.com/downloads/info13993-oUF_Phanx.html
	https://www.curseforge.com/wow/addons/ouf-phanx
	https://github.com/Phanx/oUF_Phanx
----------------------------------------------------------------------]]

local _, ns = ...
local _, playerClass = UnitClass("player")
local colors = oUF.colors
local noop = function() return end
local playerUnits = { player = true, pet = true, vehicle = true }
local si = ns.si
ns.noop = noop

------------------------------------------------------------------------

ns.framePrototype = {
	RegisterForMouseover = function(self, element)
		if not self.mouseovers then
			self.mouseovers = {}
		else
			for i = 1, #self.mouseovers do
				if self.mouseovers[i] == element then
					return
				end
			end
		end
		tinsert(self.mouseovers, element)
	end,
	RegisterForRoleChange = function(self, func)
		if not self.updateOnRoleChange then
			self.updateOnRoleChange = {}
		else
			for i = 1, #self.updateOnRoleChange do
				if self.updateOnRoleChange[i] == func then
					return
				end
			end
		end
		tinsert(self.updateOnRoleChange, func)
	end,
}

------------------------------------------------------------------------
--	General utility
------------------------------------------------------------------------

if playerClass == "HUNTER" or playerClass == "MAGE" or playerClass == "ROGUE" or playerClass == "WARLOCK" then
	function ns.GetPlayerRole()
		return "DAMAGER"
	end
else
	function ns.GetPlayerRole()
		local spec = GetSpecialization() or 0
		local _, _, _, _, _, role = GetSpecializationInfo(spec)
		return role or "DAMAGER"
	end
end

------------------------------------------------------------------------
--	Border
------------------------------------------------------------------------

function ns.ExtraBar_OnShow(self) --if self.__name then print("Show", self.__name) end
	local frame = self.__owner
	frame:SetBorderSize(nil, 0, 0, self:GetHeight() - 1 + (self.borderOffset or 0), 0)
	if self.value then
		return self.value:SetParent(frame.overlay)
	end
	for i = 1, #self do
		local v = self[i]
		if type(v) == "table" and v.value then
			v.value:SetParent(frame.overlay)
		end
	end
end

function ns.ExtraBar_OnHide(self) --if self.__name then print("Hide", self.__name) end
	local frame = self.__owner
	frame:SetBorderSize(nil, 0, 0, 0, 0)
	if self.value then
		return self.value:SetParent(self)
	end
	for i = 1, #self do
		local v = self[i]
		if type(v) == "table" and v.value then
			v.value:SetParent(self)
		end
	end
end

function ns.UpdateBorder(self)
	local threat, debuff, dispellable = self.threatLevel, self.debuffType, self.debuffDispellable
	-- print("UpdateBorder", self.unit, "threatLevel", threat, "debuffType", debuff, "debuffDispellable", dispellable)

	local color, glow
	if debuff and dispellable then
		-- print(self.unit, "has dispellable debuff:", debuff)
		color = colors.debuff[debuff]
		glow = true
	elseif threat and threat > 1 then
		-- print(self.unit, "has aggro:", threat)
		color = colors.threat[threat]
		glow = true
	elseif debuff and not ns.config.dispelFilter then
		-- print(self.unit, "has debuff:", debuff)
		color = colors.debuff[debuff]
	elseif threat and threat > 0 then
		-- print(self.unit, "has high threat")
		color = colors.threat[threat]
	end

	if color then
		self:SetBackdropBorderColor(color[1], color[2], color[3], 1, glow and ns.config.borderGlow)
	else
		self:SetBackdropBorderColor(0, 0, 0, 0)
	end
end

------------------------------------------------------------------------
--	Health
------------------------------------------------------------------------

do
	local GHOST = GetSpellInfo(8326)
	if GetLocale() == "deDE" then
		GHOST = "Geist" -- TOO LONG OMG
	end

	local UnitIsConnected, UnitIsGhost, UnitIsDead, UnitIsPlayer, UnitClass, UnitIsTapDenied, UnitIsEnemy, UnitReaction, UnitCanAssist
	    = UnitIsConnected, UnitIsGhost, UnitIsDead, UnitIsPlayer, UnitClass, UnitIsTapDenied, UnitIsEnemy, UnitReaction, UnitCanAssist

	function ns.Health_PostUpdate(bar, unit, cur, max)
		if not unit then return end -- Blizz bug in 7.1
		local frame = bar.__owner

		ns.HealthPrediction_Override(frame, "Health_PostUpdate", unit)

		local absent = not UnitIsConnected(unit) and PLAYER_OFFLINE or UnitIsGhost(unit) and GHOST or UnitIsDead(unit) and DEAD
		if absent then
			bar:SetValue(0) -- 5.2: UnitHealth is sometimes > 0 for dead units
			local power = frame.Power
			if power then
				power:SetValue(0)
				if power.value then
					power.value:SetText(nil)
				end
			end
			local color = colors.disconnected
			if frame.isMouseOver and max > 0 then -- max is 0 for offline units
				return bar.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, si(max))
			else
				return bar.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, absent)
			end
		end

		local color = ns.GetUnitColor(unit)

		-- HEALER: deficit, percent on mouseover
		-- OTHER:  percent, current on mouseover

		if cur < max then
			if ns.GetPlayerRole() == "HEALER" and UnitCanAssist("player", unit) then
				if frame.isMouseOver and not frame.isGroupFrame then
					-- don't change text on party frames, it's annoying for click-cast or mouseover healing
					bar.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, si(cur))
				else
					bar.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, si(cur - max))
				end
			elseif frame.isMouseOver then
				bar.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, si(cur))
			else
				bar.value:SetFormattedText("|cff%02x%02x%02x%d%%|r", color[1] * 255, color[2] * 255, color[3] * 255, floor(cur / max * 100 + 0.5))
			end
		elseif frame.isMouseOver then
			bar.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, si(max))
		else
			bar.value:SetText(nil)
		end
	end
end

------------------------------------------------------------------------
--	HealthPrediction
------------------------------------------------------------------------

do
	local UnitHealth, UnitHealthMax, UnitGetTotalAbsorbs, UnitGetIncomingHeals
	    = UnitHealth, UnitHealthMax, UnitGetTotalAbsorbs, UnitGetIncomingHeals

	function ns.HealthPrediction_Override(self, event, unit)
		--print("HealthPrediction Override", event, unit)
		local element = self.HealthPrediction
		local parent = self.Health

		local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
		if maxHealth == 0 or UnitIsDeadOrGhost(unit) then
			element.healingBar:Hide()
			element.healingBar.cap:Hide()
			element.absorbsBar:Hide()
			element.absorbsBar.cap:Hide()
			return
		end

		local missing = maxHealth - health

		local healing = UnitGetIncomingHeals(unit) or 0
		if healing > 0 and ns.config.ignoreOwnHeals then
			healing = healing - (UnitGetIncomingHeals(unit, "player") or 0)
		end

		if (healing / maxHealth) >= 0.1 and missing > 0 then
			local bar = element.healingBar
			bar:Show()
			bar:SetMinMaxValues(0, maxHealth)
			if healing > missing then
				bar:SetValue(missing)
				bar.cap:SetShown((healing - missing) / maxHealth > element.maxOverflow)
				missing = 0
			else
				bar:SetValue(healing)
				bar.cap:Hide()
				missing = missing - healing
			end
			parent = bar
		else
			element.healingBar:Hide()
			element.healingBar.cap:SetShown(healing / maxHealth > element.maxOverflow)
		end

		local absorbs = UnitGetTotalAbsorbs(unit) or 0
		if (absorbs / maxHealth) >= 0.1 and missing > 0 then
			local bar = element.absorbsBar
			bar:Show()
			bar:SetPoint("TOPLEFT", parent.fg, "TOPRIGHT")
			bar:SetPoint("BOTTOMLEFT", parent.fg, "BOTTOMRIGHT")
			bar:SetMinMaxValues(0, maxHealth)
			if absorbs > missing then
				bar:SetValue(missing)
				bar.cap:SetShown((absorbs - missing) / maxHealth > element.maxOverflow)
			else
				bar:SetValue(absorbs)
				bar.cap:Hide()
			end
		else
			element.absorbsBar:Hide()
			element.absorbsBar.cap:SetShown(absorbs / maxHealth > element.maxOverflow)
		end
	end
end

------------------------------------------------------------------------
--	Power
------------------------------------------------------------------------

do
	local UnitIsDeadOrGhost, UnitPowerType, UnitPower, UnitPowerMax
	    = UnitIsDeadOrGhost, UnitPowerType, UnitPower, UnitPowerMax

	function ns.Power_PostUpdate(self, unit, cur, min, max)
		if max == 0 then
			self.__owner.Health:SetPoint("BOTTOM", self.__owner, "BOTTOM", 0, 1)
			return self:Hide()
		else
			self.__owner.Health:SetPoint("BOTTOM", self, "TOP", 0, 1)
			self:Show()
		end

		if UnitIsDeadOrGhost(unit) then
			self:SetValue(0)
			if self.value then
				self.value:SetText(nil)
			end
			return
		end

		if not self.value then return end

		local _, powerType = UnitPowerType(unit)
		local color = colors.power[powerType] or colors.power.FUEL
		if cur < max then
			if self.__owner.isMouseOver then
				self.value:SetFormattedText("%s.|cff%02x%02x%02x%s|r", si(cur), color[1] * 255, color[2] * 255, color[3] * 255, si(max))
			elseif powerType == "MANA" then
				self.value:SetFormattedText("%d|cff%02x%02x%02x%%|r", floor(cur / max * 100 + 0.5), color[1] * 255, color[2] * 255, color[3] * 255)
			elseif cur > 0 then
				self.value:SetText(cur)
			else
				self.value:SetText(nil)
			end
		elseif powerType == "MANA" and self.__owner.isMouseOver then
			self.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, si(max))
		else
			self.value:SetText(nil)
		end
	end
end

------------------------------------------------------------------------
--	ClassPower
------------------------------------------------------------------------

function ns.ClassPower_PostUpdate(element, cur, max, hasMaxChanged, event)
	--print("ClassPower PostUpdate", cur, max, hasMaxChanged)
	ns.Orbs.Update(element, cur, max)
	--[[
	for i = 1, max do
		local icon = element[i]
		if i > cur then
			icon.bg:SetVertexColor(0.4, 0.4, 0.4)
			icon.bg:SetAlpha(0.5)
			icon.fg:Hide()
			icon:Show()
		else
			icon.bg:SetVertexColor(0.25, 0.25, 0.25)
			icon.bg:SetAlpha(1)
			icon.fg:Show()
		end
	end
	]]
end

------------------------------------------------------------------------
--	Druid mana
------------------------------------------------------------------------

function ns.AdditionalPower_PostUpdate(bar, unit, mana, maxMana)
	bar.value:SetFormattedText(si(mana, true))
end

------------------------------------------------------------------------
--	Stagger
--	TODO reimplement or remove
------------------------------------------------------------------------

function ns.Stagger_PostUpdate(bar, cur, max)
	local perc = cur / max * 100
	if perc < 5 then
		return bar:Hide()
	end
	--print("Stagger PostUpdate", stagger, perc)
	bar.value:SetFormattedText("%.0f%%", perc)
	bar:Show()
end

------------------------------------------------------------------------
--	Dungeon role icon
------------------------------------------------------------------------

local roleTexCoords = {
	DAMAGER = { 0.25, 0.5, 0, 1 },
	TANK    = { 0.5, 0.75, 0, 1 },
	HEALER  = { 0.75, 1, 0, 1 },
}

function ns.GroupRoleIndicator_Override(self, event)
	local lfdrole = self.GroupRoleIndicator
	if(lfdrole.PreUpdate) then
		lfdrole:PreUpdate()
	end

	local role = UnitGroupRolesAssigned(self.unit)
	local coords = roleTexCoords[role or ""]
	if coords then
		lfdrole:SetTexCoord(unpack(coords))
		lfdrole:Show()
	else
		lfdrole:Hide()
	end

	if(lfdrole.PostUpdate) then
		return lfdrole:PostUpdate(role)
	end
end

------------------------------------------------------------------------
--	Phase icon
------------------------------------------------------------------------

function ns.PhaseIndicator_PostUpdate(icon, inPhase)
	if not inPhase and not UnitIsPlayer(icon.__owner.unit) then
		return icon:Hide()
	end
end

------------------------------------------------------------------------
--	PvP icon
------------------------------------------------------------------------

local PLAYER_FACTION = UnitFactionGroup("player")

local pvpTextures = {
	Alliance = "Interface\\AddOns\\oUF_Phanx\\Media\\DotDiamond",
	Horde = "Interface\\AddOns\\oUF_Phanx\\Media\\DotCircle",
	FFA = "Interface\\AddOns\\oUF_Phanx\\Media\\DotSquare",
}

function ns.PvPIndicator_PostUpdate(element, unit, status)
	--print("PvP PostUpdate", element.__owner.unit, status)
	if not status or status == PLAYER_FACTION then
		return element:Hide()
	end

	local tex = pvpTextures[status] or pvpTextures[PLAYER_FACTION]
	element:SetTexture(tex)

	if status == "FFA" then
		element:SetVertexColor(0.8, 0.4, 0)
	elseif status == "Alliance" then
		element:SetVertexColor(0.2, 0.4, 1)
	elseif status == "Horde" then
		element:SetVertexColor(0.6, 0, 0)
	end

	element:Show()
end

------------------------------------------------------------------------
--	Buffs & debuffs
------------------------------------------------------------------------

local function AuraIconCD_OnShow(cd)
	local button = cd:GetParent()
	button:SetBorderParent(cd)
	button.Count:SetParent(cd)
end

local function AuraIconCD_OnHide(cd)
	local button = cd:GetParent()
	button:SetBorderParent(button)
	button.Count:SetParent(button)
end

local function AuraIconOverlay_SetBorderColor(overlay, r, g, b)
	if not r or not g or not b then
		local color = ns.config.borderColor
		r, g, b = color[1], color[2], color[3]
	end
	overlay:GetParent():SetBorderColor(r, g, b)
end

function ns.Auras_PostCreateButton(element, button)
	ns.CreateBorder(button, 12)

	button.Cooldown:SetReverse(true)
	button.Cooldown:SetScript("OnHide", AuraIconCD_OnHide)
	button.Cooldown:SetScript("OnShow", AuraIconCD_OnShow)
	if button.Cooldown:IsShown() then AuraIconCD_OnShow(button.Cooldown) end

	button.Icon:SetTexCoord(0.03, 0.97, 0.03, 0.97)

	button.Overlay:Hide()
	button.Overlay.Hide = AuraIconOverlay_SetBorderColor
	button.Overlay.SetVertexColor = AuraIconOverlay_SetBorderColor
	button.Overlay.Show = noop
end

local function FindAuraTimer(button, unit)
	local timer
	if OmniCC then
		for i = 1, button:GetNumChildren() do
			local child = select(i, button:GetChildren())
			if child.text and (child.Icon == button.Icon or child.Cooldown == button.Cooldown) then
				child.ClearAllPoints = noop
				child.SetAlpha = noop
				child.SetPoint = noop
				child.SetScale = noop
				timer = child.text
				break
			end
		end
	else
		local region = button.Cooldown:GetRegions()
		timer = region.SetText and region
	end
	if timer then
		timer:ClearAllPoints()
		timer.ClearAllPoints = noop

		timer:SetPoint("CENTER", button, "TOP", 0, 2)
		timer.SetPoint = noop

		timer:SetFont(ns.GetFontFile(), unit:match("^party") and 12 or 16, ns.config.fontOutline)
		timer.SetFont = noop

		timer:SetTextColor(1, 0.8, 0)
		timer.SetTextColor = noop
		timer.SetVertexColor = noop

		tinsert(ns.fontstrings, timer)

		return timer
	end
	return not OmniCC
end

function ns.Auras_PostUpdateButton(element, button, unit, data, position) --element, unit, button, index, offset)
	button.Icon:SetDesaturated(not playerUnits[button.caster or ""])

	if not button.timer then
		button.timer = FindAuraTimer(button, unit)
	end
end

function ns.Auras_PostUpdate(self, unit)
	-- self.__owner.Health:ForceUpdate() -- required to detect Dead => Ghost
	-- TODO: check if PLAYER_FLAGS_CHANGED or UNIT_FLAGS can work for this
end

------------------------------------------------------------------------
--	Threat
------------------------------------------------------------------------

function ns.Threat_Override(frame, event, unit)
	if unit ~= frame.unit then return end

	local status = UnitThreatSituation(unit or frame.unit) or 0
	if not ns.config.threatLevels then
		status = status > 1 and 3 or 0
	end

	if frame.threatLevel == status then return end
	--print("ThreatHighlightOverride", frame.unit, status)

	frame.threatLevel = status
	frame:UpdateBorder()
end

------------------------------------------------------------------------
--	Dispel highlight
------------------------------------------------------------------------

function ns.DispelHighlight_Override(element, debuffType, canDispel)
	local frame = element.__owner

	if frame.debuffType == debuffType then return end
	-- print("DispelHighlightOverride", unit, debuffType, canDispel)

	frame.debuffType = debuffType
	frame.debuffDispellable = canDispel
	frame:UpdateBorder()
end

------------------------------------------------------------------------
--	Frames
------------------------------------------------------------------------

function ns.UnitFrame_OnEnter(self)
	if self.__owner then
		self = self.__owner
	end

	if IsShiftKeyDown() or not UnitAffectingCombat("player") then
		local noobTips = SHOW_NEWBIE_TIPS == "1"
		if noobTips and self.unit == "player" then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			GameTooltip_AddNewbieTip(self, PARTY_OPTIONS_LABEL, 1, 1, 1, NEWBIE_TOOLTIP_PARTYOPTIONS)
		elseif noobTips and self.unit == "target" and UnitPlayerControlled("target") and not UnitIsUnit("target", "player") and not UnitIsUnit("target", "pet") then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			GameTooltip_AddNewbieTip(self, PLAYER_OPTIONS_LABEL, 1, 1, 1, NEWBIE_TOOLTIP_PLAYEROPTIONS)
		else
			UnitFrame_OnEnter(self)
		end
	end

	self.isMouseOver = true
	if self.mouseovers then
		for _, element in pairs(self.mouseovers) do
			if type(element) == "function" then
				element(self, true)
			elseif element.ForceUpdate then
				element:ForceUpdate()
			else
				element:Show()
			end
		end
	end
end

function ns.UnitFrame_OnLeave(self)
	if self.__owner then
		self = self.__owner
	end

	UnitFrame_OnLeave(self)

	self.isMouseOver = nil
	if self.mouseovers then
		for _, element in pairs(self.mouseovers) do
			if type(element) == "function" then
				element(self)
			elseif element.ForceUpdate then
				element:ForceUpdate()
			else
				element:Hide()
			end
		end
	end
end

function ns.UnitFrame_DropdownMenu(self)
	local unit = self.unit:sub(1, -2)
	if unit == "party" or unit == "partypet" then
		ToggleDropDownMenu(1, nil, _G["PartyMemberFrame" .. self.id .. "DropDown"], "cursor", 0, 0)
	else
		local cunit = gsub(self.unit, "^%l", strupper)
		if cunit == "Vehicle" then
			cunit = "Pet"
		end
		if _G[cunit .. "FrameDropDown"] then
			ToggleDropDownMenu(1, nil, _G[cunit .. "FrameDropDown"], "cursor", 0, 0)
		end
	end
end
