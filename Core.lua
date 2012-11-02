--[[--------------------------------------------------------------------
	oUF_Phanx
	Fully-featured PVE-oriented layout for oUF.
	Copyright (c) 2008-2012 Phanx <addons@phanx.net>. All rights reserved.
	See the accompanying README and LICENSE files for more information.
	http://www.wowinterface.com/downloads/info13993-oUF_Phanx.html
	http://www.curse.com/addons/wow/ouf-phanx
----------------------------------------------------------------------]]

local _, ns = ...
local config
local colors = oUF.colors
local playerClass = select(2, UnitClass("player"))
local playerUnits = { player = true, pet = true, vehicle = true }
local function noop() return end

ns.frames, ns.headers, ns.objects, ns.fontstrings, ns.statusbars = {}, {}, {}, {}, {}

------------------------------------------------------------------------

function ns.si(value)
	local absvalue = abs(value)

	if absvalue >= 10000000 then
		return format("%.1fm", value / 1000000)
	elseif absvalue >= 1000000 then
		return format("%.2fm", value / 1000000)
	elseif absvalue >= 100000 then
		return format("%.0fk", value / 1000)
	elseif absvalue >= 1000 then
		return format("%.1fk", value / 1000)
	end

	return value
end

local si = ns.si

function ns.si_raw(value)
	local absvalue = abs(value)

	if absvalue >= 10000000 then
		return "%.1fm", value / 1000000
	elseif absvalue >= 1000000 then
		return "%.2fm", value / 1000000
	elseif absvalue >= 100000 then
		return "%.0fk", value / 1000
	elseif absvalue >= 1000 then
		return "%.1fk", value / 1000
	end

	return "%d", value
end

local si_raw = ns.si_raw

------------------------------------------------------------------------

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
	elseif debuff and not config.dispelFilter then
		-- print(self.unit, "has debuff:", debuff)
		color = colors.debuff[debuff]
	elseif threat and threat > 0 then
		-- print(self.unit, "has high threat")
		color = colors.threat[threat]
	else
		-- print(self.unit, "is normal")
	end

	if color then
		self:SetBackdropBorderColor(color[1], color[2], color[3], 1, glow and config.borderGlow)
	else
		self:SetBackdropBorderColor(0, 0, 0, 0)
	end
end

------------------------------------------------------------------------

function ns.PostUpdateHealth(self, unit, cur, max)
	if not UnitIsConnected(unit) then
		local color = colors.disconnected
		local power = self.__owner.Power
		if power then
			power:SetValue(0)
			if power.value then
				power.value:SetText(nil)
			end
		end
		return self.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, PLAYER_OFFLINE)
	elseif UnitIsDeadOrGhost(unit) then
		local color = colors.disconnected
		local power = self.__owner.Power
		if power then
			power:SetValue(0)
			if power.value then
				power.value:SetText(nil)
			end
		end
		return self.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, UnitIsGhost(unit) and GHOST or DEAD)
	end

	if cur > 0 then
		self:GetStatusBarTexture():SetTexCoord(0, cur / max, 0, 1)
	end

	local color
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		color = colors.class[class]
	elseif UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
		color = colors.tapped
	elseif UnitIsEnemy(unit, "player") then
		color = colors.reaction[1]
	else
		color = colors.reaction[UnitReaction(unit, "player") or 5]
	end

	-- HEALER: deficit, percent on mouseover
	-- OTHER:  percent, current on mouseover

	if cur < max then
		if ns.isHealing and UnitCanAssist("player", unit) then
			if self.__owner.isMouseOver and not unit:match("^party") then
				self.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, si(UnitHealth(unit)))
			else
				self.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, si(UnitHealth(unit) - UnitHealthMax(unit)))
			end
		elseif self.__owner.isMouseOver then
			self.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, si(UnitHealth(unit)))
		else
			self.value:SetFormattedText("|cff%02x%02x%02x%d%%|r", color[1] * 255, color[2] * 255, color[3] * 255, floor(UnitHealth(unit) / UnitHealthMax(unit) * 100 + 0.5))
		end
	elseif self.__owner.isMouseOver then
		self.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, si(UnitHealthMax(unit)))
	else
		self.value:SetText(nil)
	end
end

------------------------------------------------------------------------

function ns.UpdateIncomingHeals(self, event, unit)
	if self.unit ~= unit then return end

	local bar = self.HealPrediction

	local incoming = UnitGetIncomingHeals(unit) or 0

	if incoming == 0 then
		return bar:Hide()
	end

	local health = self.Health:GetValue()
	local _, maxHealth = self.Health:GetMinMaxValues()

	if health == maxHealth then
		return bar:Hide()
	end

	if self.ignoreSelf then
		incoming = incoming - (UnitGetIncomingHeals(unit, "player") or 0)
	end

	if incoming == 0 then
		return bar:Hide()
	end

	bar:SetMinMaxValues(0, maxHealth)
	bar:SetValue(health + incoming)
	bar:Show()
end

------------------------------------------------------------------------

function ns.PostUpdatePower(self, unit, cur, max)
	local shown = self:IsShown()
	if max == 0 then
		if shown then
			self:Hide()
		end
		return
	elseif not shown then
		self:Show()
	end

	if UnitIsDeadOrGhost(unit) then
		self:SetValue(0)
		if self.value then
			self.value:SetText(nil)
		end
		return
	end

	if cur > 0 then
		self:GetStatusBarTexture():SetTexCoord(0, cur / max, 0, 1)
	end

	if not self.value then return end

	local _, type = UnitPowerType(unit)
	local color = colors.power[type] or colors.power.FUEL
	if cur < max then
		if self.__owner.isMouseOver then
			self.value:SetFormattedText("%s.|cff%02x%02x%02x%s|r", si(UnitPower(unit)), color[1] * 255, color[2] * 255, color[3] * 255, si(UnitPowerMax(unit)))
		elseif type == "MANA" then
			self.value:SetFormattedText("%d|cff%02x%02x%02x%%|r", floor(UnitPower(unit) / UnitPowerMax(unit) * 100 + 0.5), color[1] * 255, color[2] * 255, color[3] * 255)
		elseif cur > 0 then
			self.value:SetFormattedText("%d|cff%02x%02x%02x|r", floor(UnitPower(unit) / UnitPowerMax(unit) * 100 + 0.5), color[1] * 255, color[2] * 255, color[3] * 255)
		else
			self.value:SetText(nil)
		end
	elseif type == "MANA" and self.__owner.isMouseOver then
		self.value:SetFormattedText("|cff%02x%02x%02x%s|r", color[1] * 255, color[2] * 255, color[3] * 255, si(UnitPowerMax(unit)))
	else
		self.value:SetText(nil)
	end
end

------------------------------------------------------------------------

local SPELL_POWER_LIGHT_FORCE = SPELL_POWER_LIGHT_FORCE

function ns.UpdateChi(self, event, unit, powerType)
	if unit ~= self.unit or (powerType and powerType ~= "LIGHT_FORCE") then return end

	local num = UnitPower("player", SPELL_POWER_LIGHT_FORCE)
	local max = UnitPowerMax("player", SPELL_POWER_LIGHT_FORCE)

	--print("UpdateChi", num, max)
	ns.Orbs.Update(self.Harmony, num, max)
end

------------------------------------------------------------------------

local SPELL_POWER_HOLY_POWER = SPELL_POWER_HOLY_POWER

function ns.UpdateHolyPower(self, event, unit, powerType)
	if unit ~= self.unit or (powerType and powerType ~= "HOLY_POWER") then return end

	local num = UnitPower("player", SPELL_POWER_HOLY_POWER)
	local max = UnitPowerMax("player", SPELL_POWER_HOLY_POWER)

	--print("UpdateHolyPower", num, max)
	ns.Orbs.Update(self.HolyPower, num, max)
end

------------------------------------------------------------------------

local SPELL_POWER_SHADOW_ORBS = SPELL_POWER_SHADOW_ORBS
local PRIEST_BAR_NUM_ORBS = PRIEST_BAR_NUM_ORBS

function ns.UpdateShadowOrbs(self, event, unit, powerType)
	if unit ~= self.unit or (powerType and powerType ~= "SHADOW_ORBS") then return end

	local num = UnitPower("player", SPELL_POWER_SHADOW_ORBS)
	local max = UnitPowerMax("player", SPELL_POWER_SHADOW_ORBS)

	--print("UpdateShadowOrbs", num, max)
	ns.Orbs.Update(self.ShadowOrbs, num, max)
end

------------------------------------------------------------------------

function ns.UpdateComboPoints(self, event, unit)
	if unit == "pet" then return end

	local cp
	if UnitHasVehicleUI("player") then
		cp = GetComboPoints("vehicle", "target")
	else
		cp = GetComboPoints("player", "target")
	end

	ns.Orbs.Update(self.CPoints, cp)
end

------------------------------------------------------------------------

local function AuraIconCD_OnShow(cd)
	local button = cd:GetParent()
	button:SetBorderParent(cd)
	button.count:SetParent(cd)
end

local function AuraIconCD_OnHide(cd)
	local button = cd:GetParent()
	button:SetBorderParent(button)
	button.count:SetParent(button)
end

local function AuraIconOverlay_SetBorderColor(overlay, r, g, b)
	if not r or not g or not b then
		local color = config.borderColor
		r, g, b = color[1], color[2], color[3]
	end
	overlay:GetParent():SetBorderColor(r, g, b)
end

function ns.PostCreateAuraIcon(element, button)
	ns.CreateBorder(button, 12)

	button.cd:SetReverse(true)
	button.cd:SetScript("OnHide", AuraIconCD_OnHide)
	button.cd:SetScript("OnShow", AuraIconCD_OnShow)
	if button.cd:IsShown() then AuraIconCD_OnShow(button.cd) end

	button.icon:SetTexCoord(0.03, 0.97, 0.03, 0.97)

	button.overlay:Hide()
	button.overlay.Hide = AuraIconOverlay_SetBorderColor
	button.overlay.SetVertexColor = AuraIconOverlay_SetBorderColor
	button.overlay.Show = noop

	button:SetScript("OnClick", nil) -- because oUF still tries to cancel buffs on right-click, and Blizzard thinks preventing this will stop botting?

	element.anchoredIcons = 0 -- work around bizarre 1.#IND bug
	element:ForceUpdate()
end

function ns.PostUpdateAuraIcon(element, unit, button, index, offset)
	local name, _, texture, count, type, duration, timeLeft, caster, isStealable, shouldConsolidate, spellID = UnitAura(unit, index, button.filter)

	if playerUnits[caster] then
		button.icon:SetDesaturated(false)
	else
		button.icon:SetDesaturated(true)
	end

	if button.timer then return end

	if OmniCC then
		for i = 1, button:GetNumChildren() do
			local child = select(i, button:GetChildren())
			if child.text and (child.icon == button.icon or child.cooldown == button.cd) then
				-- found it!
				child.ClearAllPoints = noop
				child.SetAlpha = noop
				child.SetPoint = noop
				child.SetScale = noop

				child.text:ClearAllPoints()
				child.text.ClearAllPoints = noop

				child.text:SetPoint("CENTER", button, "TOP", 0, 2)
				child.text.SetPoint = noop

				child.text:SetFont(config.font, unit:match("^party") and 14 or 18, config.fontOutline)
				child.text.SetFont = noop

				child.text:SetTextColor(1, 0.8, 0)
				child.text.SetTextColor = noop
				child.text.SetVertexColor = noop

				tinsert(ns.fontstrings, child.text)

				button.timer = child.text

				return
			end
		end
	else
		button.timer = true
	end
end

function ns.PostUpdateAuras(self, unit)
	self.__owner.Health:ForceUpdate() -- required to detect Dead => Ghost
end

------------------------------------------------------------------------

function ns.PostCastStart(self, unit, name, rank, castid)
	local color
	if UnitIsUnit(unit, "player") then
		color = colors.class[playerClass]
	elseif self.interrupt then
		color = colors.uninterruptible
	elseif UnitIsFriend(unit, "player") then
		color = colors.reaction[5]
	else
		color = colors.reaction[1]
	end
	local r, g, b = color[1], color[2], color[3]
	self:SetStatusBarColor(r * 0.8, g * 0.8, b * 0.8)
	self.bg:SetVertexColor(r * 0.2, g * 0.2, b * 0.2)

	local safezone = self.SafeZone
	if safezone then
		self:GetStatusBarTexture():SetDrawLayer("ARTWORK")
		safezone:SetDrawLayer("BORDER")
		if safezone:GetWidth() == 0 then -- fix for bug on first cast
			safezone:Hide()
		end
	end
end

function ns.PostChannelStart(self, unit, name, rank, text)
	local color
	if UnitIsUnit(unit, "player") then
		color = colors.class[playerClass]
	elseif self.interrupt then
		color = colors.reaction[4]
	elseif UnitIsFriend(unit, "player") then
		color = colors.reaction[5]
	else
		color = colors.reaction[1]
	end
	local r, g, b = color[1], color[2], color[3]
	self:SetStatusBarColor(r * 0.6, g * 0.6, b * 0.6)
	self.bg:SetVertexColor(r * 0.2, g * 0.2, b * 0.2)

	local safezone = self.SafeZone
	if safezone then
		self:GetStatusBarTexture():SetDrawLayer("BORDER")
		safezone:SetDrawLayer("ARTWORK")
		if safezone:GetWidth() == 0 then -- fix for bug on first cast
			safezone:Hide()
		end
	end
end

function ns.CustomDelayText(self, duration)
	self.Time:SetFormattedText("%.1f|cffff0000-%.1f|r", self.max - duration, self.delay)
end

function ns.CustomTimeText(self, duration)
	self.Time:SetFormattedText("%.1f", self.max - duration)
end

------------------------------------------------------------------------

function ns.UpdateDispelHighlight(self, unit, debuffType, canDispel)
	-- print("UpdateDispelHighlight", unit, debuffType, canDispel)

	local frame = self.__owner
	frame.debuffType = debuffType
	frame.debuffDispellable = canDispel
	frame:UpdateBorder()
end

------------------------------------------------------------------------

function ns.UpdateThreatHighlight(self, unit, status)
	if not status then status = 0 end
	-- print("UpdateThreatHighlight", unit, status)

	if not config.threatLevels then
		status = status > 1 and 3 or 0
	end

	if self.threatLevel == status then return end
	-- print("New threat status:", status)

	self.threatLevel = status
	self:UpdateBorder()
end

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
	for _, element in pairs(self.mouseovers) do
		if element.ForceUpdate then
			element:ForceUpdate()
		else
			element:Show()
		end
	end

	if IsShiftKeyDown() and not UnitAffectingCombat("player") then
		local buffs = self.Buffs or self.Auras
		if buffs and buffs.CustomFilter then
			buffs.__CustomFilter = buffs.CustomFilter
			buffs.CustomFilter = nil
			buffs:ForceUpdate()
		end
	end
end

function ns.UnitFrame_OnLeave(self)
	if self.__owner then
		self = self.__owner
	end

	UnitFrame_OnLeave(self)

	self.isMouseOver = nil
	for _, element in pairs(self.mouseovers) do
		if element.ForceUpdate then
			element:ForceUpdate()
		else
			element:Hide()
		end
	end

	local buffs = self.Buffs or self.Auras
	if buffs and buffs.__CustomFilter then
		buffs.CustomFilter = buffs.__CustomFilter
		buffs.__CustomFilter = nil
		buffs:ForceUpdate()
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

------------------------------------------------------------------------

function ns.CreateFontString(parent, size, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(config.font, size or 16, config.fontOutline)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetShadowOffset(1, -1)

	tinsert(ns.fontstrings, fs)
	return fs
end

------------------------------------------------------------------------

function ns.SetStatusBarValue(self, cur)
	local min, max = self:GetMinMaxValues()
	self:GetStatusBarTexture():SetTexCoord(0, (cur - min) / (max - min), 0, 1)
	self.orig_SetValue(self, cur)
end

function ns.CreateStatusBar(parent, size, justify, nohook)
	local sb = CreateFrame("StatusBar", nil, parent)
	sb:SetStatusBarTexture(config.statusbar)
	sb:GetStatusBarTexture():SetDrawLayer("BORDER")
	sb:GetStatusBarTexture():SetHorizTile(false)
	sb:GetStatusBarTexture():SetVertTile(false)

	sb.bg = sb:CreateTexture(nil, "BACKGROUND")
	sb.bg:SetTexture(config.statusbar)
	sb.bg:SetAllPoints(true)

	if size then
		sb.value = ns.CreateFontString(sb, size, justify)
	end

	if not nohook then
		sb.orig_SetValue = sb.SetValue
		sb.SetValue = ns.SetStatusBarValue
	end

	tinsert(ns.statusbars, sb)
	return sb
end

------------------------------------------------------------------------

function ns.Spawn(self, unit, isSingle)
	if self:GetParent():GetAttribute("useOwnerUnit") then
		local suffix = self:GetParent():GetAttribute("unitsuffix")
		self:SetAttribute("useOwnerUnit", true)
		self:SetAttribute("unitsuffix", suffix)
		unit = unit .. suffix
	end

	local uconfig = ns.uconfig[unit]
	self.spawnunit = unit

	unit = gsub(unit, "%d", "") -- turn "boss2" into "boss" for example

	-- print("Spawn", self:GetName(), unit)
	tinsert(ns.objects, self)

	self.mouseovers = {}

	self.menu = ns.UnitFrame_DropdownMenu

	self:HookScript("OnEnter", ns.UnitFrame_OnEnter)
	self:HookScript("OnLeave", ns.UnitFrame_OnLeave)

	self:RegisterForClicks("anyup")

	local FRAME_WIDTH  = config.width  * (uconfig.width  or 1)
	local FRAME_HEIGHT = config.height * (uconfig.height or 1)

	if isSingle then
		self:SetAttribute("*type2", "menu")

		self:SetAttribute("initial-width", FRAME_WIDTH)
		self:SetAttribute("initial-height", FRAME_HEIGHT)

		self:SetWidth(FRAME_WIDTH)
		self:SetHeight(FRAME_HEIGHT)
	else
		-- used for aura filtering
		self.isGroupFrame = true
	end

	-------------------------
	-- Health bar and text --
	-------------------------

	local health = ns.CreateStatusBar(self, 24, "RIGHT", true)
	health:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -2)
	health:SetPoint("TOPRIGHT", self, "TOPRIGHT", -1, -2)
	health:SetPoint("BOTTOM", self, "BOTTOM", 0, 0)
	self.Health = health

	health:GetStatusBarTexture():SetDrawLayer("ARTWORK")
	health.value:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, config.height * config.powerHeight - 2)

	local healthColorMode = config.healthColorMode
	health.colorClass = healthColorMode == "CLASS"
	health.colorReaction = healthColorMode == "CLASS"
	health.colorSmooth = healthColorMode == "HEALTH"

	local healthBG = config.healthBG
	health.bg.multiplier = healthBG

	if healthColorMode == "CUSTOM" then
		local r, g, b = unpack(config.healthColor)
		health:SetStatusBarColor(r, g, b)
		health.bg:SetVertexColor(r * healthBG, g * healthBG, b * healthBG)
	end

	health.PostUpdate = ns.PostUpdateHealth
	tinsert(self.mouseovers, health)

	---------------------------
	-- Predicted healing bar --
	---------------------------

	local heals = ns.CreateStatusBar(self)
	heals:SetAllPoints(self.Health)
	heals:SetAlpha(0.25)
	heals:SetStatusBarColor(0, 1, 0)
	heals:Hide()
	self.HealPrediction = heals

	heals:SetFrameLevel(self.Health:GetFrameLevel())

	heals.bg:ClearAllPoints()
	heals.bg:SetTexture("")
	heals.bg:Hide()
	heals.bg = nil

	heals.ignoreSelf = config.ignoreOwnHeals
	heals.maxOverflow = 1

	heals.Override = ns.UpdateIncomingHeals

	------------------------
	-- Power bar and text --
	------------------------

	if uconfig.power then
		local power = ns.CreateStatusBar(self, (uconfig.width or 1) > 0.75 and 16, "LEFT", true)
		power:SetFrameLevel(self.Health:GetFrameLevel() + 2)
		power:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 1, 1)
		power:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -1, 1)
		power:SetHeight(config.height * config.powerHeight)
		self.Power = power

		if power.value then
			power.value:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 4, config.height * config.powerHeight - 2)
			power.value:SetPoint("BOTTOMRIGHT", self.Health.value, "BOTTOMLEFT", -8, 0)

			tinsert(self.mouseovers, power)
		end

		local powerColorMode = config.powerColorMode
		power.colorClass = powerColorMode == "CLASS"
		power.colorReaction = powerColorMode == "CLASS"
		power.colorPower = powerColorMode == "POWER"

		local powerBG = config.powerBG
		power.bg.multiplier = powerBG

		if powerColorMode == "CUSTOM" then
			local r, g, b = unpack(config.powerColor)
			power:SetStatusBarColor(r, g, b)
			power.bg:SetVertexColor(r / powerBG, g / powerBG, b / powerBG)
		end

		power.frequentUpdates = unit == "player"
		power.PostUpdate = ns.PostUpdatePower
	end

	-----------------------------------------------------------
	-- Overlay to avoid reparenting stuff on powerless units --
	-----------------------------------------------------------

	self.overlay = CreateFrame("Frame", nil, self)
	self.overlay:SetAllPoints(self)
	self.overlay:SetFrameLevel(self.Health:GetFrameLevel() + (self.Power and 3 or 2))

	health.value:SetParent(self.overlay)

	--------------------------
	-- Element: Threat text -- NOT YET IMPLEMENTED
	--------------------------
--[[
	if unit == "target" then
		self.ThreatText = ns.CreateFontString(self.overlay, 20, "RIGHT")
		self.ThreatText:SetPoint("BOTTOMRIGHT", self.Health, "TOPRIGHT", -2, -4)
	end
]]
	---------------------------
	-- Name text, Level text --
	---------------------------

	if unit == "target" or unit == "focus" then
		self.Level = ns.CreateFontString(self.overlay, 16, "LEFT")
		self.Level:SetPoint("BOTTOMLEFT", self.Health, "TOPLEFT", 2, -3)

		self:Tag(self.Level, "[difficulty][level][shortclassification]")
--[[
		if unit == "target" then
			self.RareElite = self.overlay:CreateTexture(nil, "ARTWORK")
			self.RareElite:SetPoint("TOPRIGHT", self, "TOPRIGHT", 10, 10)
			self.RareElite:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 10, -10)
			self.RareElite:SetTexture("Interface\\AddOns\\oUF_Phanx\\media\\Elite")
		end
]]
		self.Name = ns.CreateFontString(self.overlay, 20, "LEFT")
		self.Name:SetPoint("BOTTOMLEFT", self.Level, "BOTTOMRIGHT", 0, -1)
		self.Name:SetPoint("BOTTOMRIGHT", self.Threat or self.Health, self.Threat and "BOTTOMLEFT" or "TOPRIGHT", self.Threat and -8 or -2, self.Threat and 0 or -4)

		self:Tag(self.Name, "[unitcolor][name]")
	elseif unit ~= "player" and not unit:match("pet") then
		self.Name = ns.CreateFontString(self.overlay, 20, "LEFT")
		self.Name:SetPoint("BOTTOMLEFT", self.Health, "TOPLEFT", 2, -4)
		self.Name:SetPoint("BOTTOMRIGHT", self.Health, "TOPRIGHT", -2, -4)

		self:Tag(self.Name, "[unitcolor][name]")
	end

	------------------
	-- Combo points --
	------------------

	if unit == "target" then
		local t = ns.Orbs.Create(self.overlay, MAX_COMBO_POINTS, 20)
		for i = MAX_COMBO_POINTS, 1, -1 do
			local orb = t[i]
			if i == 1 then
				orb:SetPoint("TOPLEFT", self, "BOTTOMLEFT", -2, 5)
			else
				orb:SetPoint("BOTTOMLEFT", t[i - 1], "BOTTOMRIGHT", -2, 0)
			end
			orb.bg:SetVertexColor(0.25, 0.25, 0.25)
			orb.fg:SetVertexColor(1, 0.8, 0)
		end
		self.CPoints = t
		self.CPoints.Override = ns.UpdateComboPoints
	end

	------------------------------
	-- Class-specific resources --
	------------------------------

	if unit == "player" and (playerClass == "MONK" or playerClass == "PALADIN" or playerClass == "PRIEST" or playerClass == "WARLOCK") then
		local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass]

		local element, max, power, update, statusbar = "ClassIcons", 5

		---------
		-- Chi --
		---------
		if playerClass == "MONK" then
			power = SPELL_POWER_LIGHT_FORCE
			update = ns.UpdateChi
		----------------
		-- Holy power --
		----------------
		elseif playerClass == "PALADIN" then
			power = SPELL_POWER_HOLY_POWER
			update = ns.UpdateHolyPower
		-----------------
		-- Shadow orbs --
		-----------------
		elseif playerClass == "PRIEST" then
			power = SPELL_POWER_SHADOW_ORBS
			update = ns.UpdateShadowOrbs
		-----------------------------------------------
		-- Soul shards, demonic fury, burning embers --
		-----------------------------------------------
		elseif playerClass == "WARLOCK" then
			element = "WarlockPower" -- "SoulShards"
			max = 4
			power = SPELL_POWER_SOUL_SHARDS
			statusbar = true
		end

		local function SetAlpha(self, alpha)
			--print("SetAlpha", self.id, alpha)
			if alpha == 1 then
				self.bg:SetVertexColor(0.25, 0.25, 0.25)
				self.bg:SetAlpha(1)
				self.fg:Show()
			else
				self.bg:SetVertexColor(0.4, 0.4, 0.4)
				self.bg:SetAlpha(0.5)
				self.fg:Hide()
			end
		end

		local t = ns.Orbs.Create(self.overlay, max, 20, statusbar)
		for i = 1, max do
			local orb = t[i]
			if i == 1 then
				orb:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 2, -5)
			else
				orb:SetPoint("BOTTOMRIGHT", t[i - 1], "BOTTOMLEFT", 2, 0)
			end
			orb.bg:SetVertexColor(0.25, 0.25, 0.25)
			orb.fg:SetVertexColor(color.r, color.g, color.b)
			if not statusbar then
				orb.SetAlpha = SetAlpha
			end
		end
		t.powerType = power
		t.Override = update
		t.UpdateTexture = function() return end -- fuck off oUF >:(
		self[element] = t

		if CUSTOM_CLASS_COLORS then
			CUSTOM_CLASS_COLORS:RegisterCallback(function()
				local color = CUSTOM_CLASS_COLORS[playerClass]
				for i = 1, #t do
					t.fg:SetVertexColor(color.r, color.g, color.b)
				end
			end)
		end
	end

	--------------------
	-- Stacking buffs --
	--------------------

	if unit == "player" and playerClass == "SHAMAN" then
		local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass]

		local function SetAlpha(orb, alpha)
			if alpha == 1 then
				orb.bg:SetVertexColor(0.25, 0.25, 0.25)
				orb.bg:SetAlpha(1)
				orb.fg:Show()
			else
				orb.bg:SetVertexColor(0.4, 0.4, 0.4)
				orb.bg:SetAlpha(0.5)
				orb.fg:Hide()
			end
		end

		local t = ns.Orbs.Create(self.overlay, 5, 20)
		for i = 1, 5 do
			local orb = t[i]
			if i == 1 then
				orb:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 2, -5)
			else
				orb:SetPoint("BOTTOMRIGHT", t[i - 1], "BOTTOMLEFT", 2, 0)
			end
			orb.bg:SetVertexColor(0.25, 0.25, 0.25)
			orb.fg:SetVertexColor(color.r, color.g, color.b)
			orb.SetAlpha = SetAlpha
		end

		t.buff = GetSpellInfo(53817)
		self.PowerStack = t

		if CUSTOM_CLASS_COLORS then
			CUSTOM_CLASS_COLORS:RegisterCallback(function()
				local color = CUSTOM_CLASS_COLORS[playerClass]
				for i = 1, #t do
					t.fg:SetVertexColor(color.r, color.g, color.b)
				end
			end)
		end
	end

	-----------------------
	-- Status icons --
	-----------------------

	if unit == "player" then
		self.Status = ns.CreateFontString(self.overlay, 16, "LEFT")
		self.Status:SetPoint("LEFT", self.Health, "TOPLEFT", 2, 2)

		self:Tag(self.Status, "[leadericon][mastericon]")

		self.Resting = self.overlay:CreateTexture(nil, "OVERLAY")
		self.Resting:SetPoint("LEFT", self.Health, "BOTTOMLEFT", 0, -2)
		self.Resting:SetSize(20, 20)

		self.Combat = self.overlay:CreateTexture(nil, "OVERLAY")
		self.Combat:SetPoint("RIGHT", self.Health, "BOTTOMRIGHT", 0, -2)
		self.Combat:SetSize(24, 24)
	elseif unit == "party" or unit == "target" then
		self.Status = ns.CreateFontString(self.overlay, 16, "RIGHT")
		self.Status:SetPoint("RIGHT", self.Health, "BOTTOMRIGHT", -2, 0)

		self:Tag(self.Status, "[mastericon][leadericon]")
	end

	----------------
	-- Phase icon --
	----------------

	if unit == "party" or unit == "target" or unit == "focus" then
		self.PhaseIcon = self.overlay:CreateTexture(nil, "OVERLAY")
		self.PhaseIcon:SetPoint("TOP", self, "TOP", 0, -4)
		self.PhaseIcon:SetPoint("BOTTOM", self, "BOTTOM", 0, 4)
		self.PhaseIcon:SetWidth(self.PhaseIcon:GetHeight())
		self.PhaseIcon:SetTexture([[Interface\Icons\Spell_Frost_Stun]])
		self.PhaseIcon:SetTexCoord(0.05, 0.95, 0.5 - 0.25 * 0.9, 0.5 + 0.25 * 0.9)
		self.PhaseIcon:SetDesaturated(true)
		self.PhaseIcon:SetBlendMode("ADD")
		self.PhaseIcon:SetAlpha(0.5)
	end

	---------------------
	-- Quest boss icon --
	---------------------

	if unit == "target" then
		self.QuestIcon = self.overlay:CreateTexture(nil, "OVERLAY")
		self.QuestIcon:SetPoint("CENTER", self, "LEFT", 0, 0)
		self.QuestIcon:SetSize(32, 32)
	end

	-----------------------
	-- Raid target icons --
	-----------------------

	self.RaidIcon = self.overlay:CreateTexture(nil, "OVERLAY")
	self.RaidIcon:SetPoint("CENTER", self, 0, 0)
	self.RaidIcon:SetSize(32, 32)

	----------------------
	-- Ready check icon --
	----------------------

	if unit == "player" or unit == "party" then
		self.ReadyCheck = self.overlay:CreateTexture(nil, "OVERLAY")
		self.ReadyCheck:SetPoint("CENTER", self)
		self.ReadyCheck:SetSize(config.height, config.height)
	end

	----------------
	-- Role icons --
	----------------

	if unit == "player" or unit == "party" then
		self.LFDRole = self.overlay:CreateTexture(nil, "OVERLAY")
		self.LFDRole:SetPoint("CENTER", self, unit == "player" and "LEFT" or "RIGHT", unit == "player" and -2 or 2, 0)
		self.LFDRole:SetSize(16, 16)
	end

	----------------
	-- Aura icons --
	----------------

	if unit == "player" then
		local GAP = 6

		self.Buffs = CreateFrame("Frame", nil, self)
		self.Buffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 24)
		self.Buffs:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 24)
		self.Buffs:SetHeight(config.height)

		self.Buffs["growth-x"] = "LEFT"
		self.Buffs["growth-y"] = "UP"
		self.Buffs["initialAnchor"] = "BOTTOMRIGHT"
		self.Buffs["num"] = floor((config.width + GAP) / (config.height + GAP))
		self.Buffs["size"] = config.height
		self.Buffs["spacing-x"] = GAP
		self.Buffs["spacing-y"] = GAP

		self.Buffs.CustomFilter   = ns.CustomAuraFilters.player
		self.Buffs.PostCreateIcon = ns.PostCreateAuraIcon
		self.Buffs.PostUpdateIcon = ns.PostUpdateAuraIcon
		self.Buffs.PostUpdate = ns.PostUpdateAuras -- required to detect Dead => Ghost

		self.Buffs.parent = self
	elseif unit == "pet" then
		local GAP = 6

		self.Buffs = CreateFrame("Frame", nil, self)
		self.Buffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 24)
		self.Buffs:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 24)
		self.Buffs:SetHeight(config.height)

		self.Buffs["growth-x"] = "LEFT"
		self.Buffs["growth-y"] = "UP"
		self.Buffs["initialAnchor"] = "BOTTOMRIGHT"
		self.Buffs["num"] = floor((config.width * uconfig.width + GAP) / (config.height + GAP))
		self.Buffs["size"] = config.height
		self.Buffs["spacing-x"] = GAP
		self.Buffs["spacing-y"] = GAP

		self.Buffs.CustomFilter   = ns.CustomAuraFilters.pet
		self.Buffs.PostCreateIcon = ns.PostCreateAuraIcon
		self.Buffs.PostUpdateIcon = ns.PostUpdateAuraIcon

		self.Buffs.parent = self
	elseif unit == "party" then
		local GAP = 6

		self.Buffs = CreateFrame("Frame", nil, self)
		self.Buffs:SetPoint("RIGHT", self, "LEFT", -10, 0)
		self.Buffs:SetHeight(config.height)
		self.Buffs:SetWidth((config.height * 4) + (GAP * 3))

		self.Buffs["growth-x"] = "LEFT"
		self.Buffs["growth-y"] = "DOWN"
		self.Buffs["initialAnchor"] = "RIGHT"
		self.Buffs["num"] = 4
		self.Buffs["size"] = config.height
		self.Buffs["spacing-x"] = GAP
		self.Buffs["spacing-y"] = GAP

		self.Buffs.CustomFilter   = ns.CustomAuraFilters.party
		self.Buffs.PostCreateIcon = ns.PostCreateAuraIcon
		self.Buffs.PostUpdateIcon = ns.PostUpdateAuraIcon
		self.Buffs.PostUpdate = ns.PostUpdateAuras -- required to detect Dead => Ghost

		self.Buffs.parent = self
	elseif unit == "target" then
		local GAP = 6

		local MAX_ICONS = floor((config.width + GAP) / (config.height + GAP)) - 1
		local NUM_BUFFS = math.max(1, floor(MAX_ICONS * 0.2))
		local NUM_DEBUFFS = math.min(MAX_ICONS - 1, floor(MAX_ICONS * 0.8))

		self.Debuffs = CreateFrame("Frame", nil, self)
		self.Debuffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 24)
		self.Debuffs:SetWidth((config.height * NUM_DEBUFFS) + (GAP * (NUM_DEBUFFS - 1)))
		self.Debuffs:SetHeight((config.height * 2) + (GAP * 2))

		self.Debuffs["growth-x"] = "RIGHT"
		self.Debuffs["growth-y"] = "UP"
		self.Debuffs["initialAnchor"] = "BOTTOMLEFT"
		self.Debuffs["num"] = NUM_DEBUFFS
		self.Debuffs["showType"] = true
		self.Debuffs["size"] = config.height
		self.Debuffs["spacing-x"] = GAP
		self.Debuffs["spacing-y"] = GAP * 2

		self.Debuffs.CustomFilter   = ns.CustomAuraFilters.target
		self.Debuffs.PostCreateIcon = ns.PostCreateAuraIcon
		self.Debuffs.PostUpdateIcon = ns.PostUpdateAuraIcon
		self.Debuffs.PostUpdate = ns.PostUpdateAuras -- required to detect Dead => Ghost

		self.Debuffs.parent = self

		self.Buffs = CreateFrame("Frame", nil, self)
		self.Buffs:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 2, 24)
		self.Buffs:SetWidth((config.height * NUM_BUFFS) + (GAP * (NUM_BUFFS - 1)))
		self.Buffs:SetHeight((config.height * 2) + (GAP * 2))

		self.Buffs["growth-x"] = "LEFT"
		self.Buffs["growth-y"] = "UP"
		self.Buffs["initialAnchor"] = "BOTTOMRIGHT"
		self.Buffs["num"] = NUM_BUFFS
		self.Buffs["showType"] = false
		self.Buffs["size"] = config.height
		self.Buffs["spacing-x"] = GAP
		self.Buffs["spacing-y"] = GAP * 2

		self.Buffs.CustomFilter   = ns.CustomAuraFilters.target
		self.Buffs.PostCreateIcon = ns.PostCreateAuraIcon
		self.Buffs.PostUpdateIcon = ns.PostUpdateAuraIcon

		self.Buffs.parent = self
	end

	--------------------
	-- Druid mana bar --
	--------------------

	if unit == "player" and playerClass == "DRUID" and config.druidMana then
		local druidMana = ns.CreateStatusBar(self, 16, "CENTER")
		druidMana:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 6)
		druidMana:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 6)
		druidMana:SetHeight(config.height * (1 - config.powerHeight) * 0.5)
		self.DruidMana = druidMana

		local druidManaText = druidMana.value
		druidManaText:SetPoint("CENTER", 0, 1)
		druidManaText:Hide()
		table.insert(self.mouseovers, druidManaText)

		druidMana.colorPower = true
		druidMana.bg.multiplier = config.powerBG

		function druidMana:PostUpdate(unit, cur, max)
			self.value:SetFormattedText(si_raw(cur))
		end

		ns.CreateBorder(druidMana)
	end

	-----------------------
	-- Druid eclipse bar --
	-----------------------

	if unit == "player" and playerClass == "DRUID" and config.eclipseBar then
		local eclipseBar = ns.CreateEclipseBar(self, config.statusbar, config.eclipseBarIcons)
		eclipseBar:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 6)
		eclipseBar:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 6)
		eclipseBar:SetHeight(config.height * (1 - config.powerHeight) * 0.5)

		table.insert(ns.statusbars, eclipseBar.bg)
		table.insert(ns.statusbars, eclipseBar.lunarBG)
		table.insert(ns.statusbars, eclipseBar.solarBG)

		local eclipseText = ns.CreateFontString(eclipseBar, 16, "CENTER")
		eclipseText:SetPoint("CENTER", eclipseBar, "CENTER", 0, 1)
		eclipseText:Hide()
		self:Tag(eclipseText, "[pereclipse]%")
		table.insert(self.mouseovers, eclipseText)
		eclipseBar.value = eclipseText

		ns.CreateBorder(eclipseBar)
		eclipseBar.BorderTextures.LEFT:Hide()
		eclipseBar.BorderTextures.RIGHT:Hide()

		eclipseBar:SetScript("OnEnter", ns.UnitFrame_OnEnter)
		eclipseBar:SetScript("OnLeave", ns.UnitFrame_OnLeave)

		self.EclipseBar = eclipseBar
	end

	-----------------------
	-- Shaman totem bars --
	-----------------------

	if unit == "player" and playerClass == "SHAMAN" and config.totemBars then
		local Totems = ns.CreateTotems(self)

		local N = #Totems
		local TOTEM_WIDTH = (config.width - (6 * (N - 1))) / N
		local TOTEM_HEIGHT = config.height * (1 - config.powerHeight) * 0.5

		for i = 1, N do
			local bar = Totems[i]
			bar:SetFrameLevel(self.overlay:GetFrameLevel() + 1)
			bar:SetSize(TOTEM_WIDTH, TOTEM_HEIGHT)
			bar.Icon:SetHeight(TOTEM_WIDTH)
			bar.bg.multiplier = config.powerBG
			if i > 1 then
				bar:SetPoint("LEFT", Totems[i-1], "RIGHT", 6, 0)
			else
				bar:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 6)
			end
		end

		self.Totems = Totems
	end

	----------------------------
	-- Death knight rune bars --
	----------------------------

	if unit == "player" and playerClass == "DEATHKNIGHT" and config.runeBars then
		local Runes = ns.CreateRunes(self)
		Runes:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 6)
		Runes:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 6)
		Runes:SetHeight(config.height * (1 - config.powerHeight) * 0.5)

		Runes:SetBackdrop(config.backdrop)
		Runes:SetBackdropColor(0, 0, 0, 1)
		Runes:SetBackdropBorderColor(unpack(config.borderColor))

		local N = #Runes
		local RUNE_WIDTH = (config.width - (1 * (N + 1))) / N

		for i = 1, N do
			local bar = Runes[i]
			bar:SetWidth(RUNE_WIDTH)
			bar.bg.multiplier = config.powerBG

			if i > 1 then
				bar:SetPoint("TOPLEFT", Runes[i-1], "TOPRIGHT", 1, 0)
				bar:SetPoint("BOTTOMLEFT", Runes[i-1], "BOTTOMRIGHT", 1, 0)
			else
				bar:SetPoint("TOPLEFT", Runes, 1, 0)
				bar:SetPoint("BOTTOMLEFT", Runes, 1, 0)
			end
		end

		self.Runes = Runes
	end

	------------------------------
	-- Cast bar, icon, and text --
	------------------------------

	if uconfig.castbar then
		local height = config.height * (1 - config.powerHeight)

		local Castbar = ns.CreateStatusBar(self)
		Castbar:SetPoint("TOPLEFT", self, "BOTTOMLEFT", height, -10)
		Castbar:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -10)
		Castbar:SetHeight(height)

		local Icon = Castbar:CreateTexture(nil, "BACKDROP")
		Icon:SetPoint("TOPRIGHT", Castbar, "TOPLEFT", 0, 0)
		Icon:SetPoint("BOTTOMRIGHT", Castbar, "BOTTOMLEFT", 0, 0)
		Icon:SetWidth(height)
		Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		Castbar.Icon = Icon

		if unit == "player" then
			local SafeZone = Castbar:CreateTexture(nil, "BORDER")
			SafeZone:SetTexture(config.statusbar)
			SafeZone:SetVertexColor(1, 0.5, 0, 0.75)
			Castbar.SafeZone = SafeZone

			Castbar.Time = ns.CreateFontString(Castbar, 20, "RIGHT")
			Castbar.Time:SetPoint("RIGHT", Castbar, "RIGHT", -4, 0)

		elseif (uconfig.width or 1) > 0.75 then
			Castbar.Text = ns.CreateFontString(Castbar, 16, "LEFT")
			Castbar.Text:SetPoint("LEFT", Castbar, "LEFT", 4, 0)
		end

		ns.CreateBorder(Castbar, nil, nil, nil, "OVERLAY")

		local d = floor(config.borderSize / 2 + 0.5) - 2
		Castbar.BorderTextures.TOPLEFT:SetPoint("TOPLEFT", Castbar.Icon, "TOPLEFT", -d, d)
		Castbar.BorderTextures.BOTTOMLEFT:SetPoint("BOTTOMLEFT", Castbar.Icon, "BOTTOMLEFT", -d, -d)

		local o = Castbar.SetBorderSize
		function Castbar:SetBorderSize(size, offset)
			o(self, size, offset)
			local d = floor(size / 2 + 0.5) - 2
			self.BorderTextures.TOPLEFT:SetPoint("TOPLEFT", self.Icon, "TOPLEFT", -d, d)
			self.BorderTextures.BOTTOMLEFT:SetPoint("BOTTOMLEFT", self.Icon, "BOTTOMLEFT", -d, -d)
		end

		Castbar.PostCastStart = ns.PostCastStart
		Castbar.PostChannelStart = ns.PostChannelStart
		Castbar.CustomDelayText = ns.CustomDelayText
		Castbar.CustomTimeText = ns.CustomTimeText

		self.Castbar = Castbar
	end

	-----------
	-- Range --
	-----------

	if unit == "pet" or unit == "party" or unit == "partypet" then
		self.Range = {
			insideAlpha = 1,
			outsideAlpha = 0.5,
		}
	end

	-------------------------
	-- Border and backdrop --
	-------------------------

	ns.CreateBorder(self, config.borderSize)
	self:SetBorderParent(self.overlay)
	self.UpdateBorder = ns.UpdateBorder

	self:SetBackdrop(config.backdrop)
	self:SetBackdropColor(0, 0, 0, 1)
	self:SetBackdropBorderColor(unpack(config.borderColor))

	----------------------
	-- Element: AFK text --
	----------------------

	if unit == "player" or unit == "party" then
		self.AFK = ns.CreateFontString(self.overlay, 12, "CENTER")
		self.AFK:SetPoint("CENTER", self.Health, "BOTTOM", 0, -2)
		self.AFK.fontFormat = "AFK %s:%s"
	end

	-------------------------------
	-- Element: Dispel highlight --
	-------------------------------

	self.DispelHighlight = ns.UpdateDispelHighlight
	self.DispelHighlightFilter = true

	-------------------------------
	-- Element: Threat highlight --
	-------------------------------

	self.threatLevel = 0
	self.ThreatHighlight = ns.UpdateThreatHighlight

	--------------------------------
	-- Element: Resurrection text --
	--------------------------------

	if not strmatch(unit, ".+target$") and not strmatch(unit, "^arena") and not strmatch(unit, "^boss") then
		self.Resurrection = ns.CreateFontString(self.overlay, 16, "CENTER")
		self.Resurrection:SetPoint("CENTER", self.Health)
	end

	--------------------------------
	-- Plugin: oUF_CombatFeedback --
	--------------------------------

	if IsAddOnLoaded("oUF_CombatFeedback") and not unit:match("^(.+)target$") then
		local cft = ns.CreateFontString(self.overlay, 24, "CENTER")
		cft:SetPoint("CENTER", 0, 1)
		self.CombatFeedbackText = cft
	end

	------------------------
	-- Plugin: oUF_Smooth --
	------------------------

	if IsAddOnLoaded("oUF_Smooth") and not unit:match(".+target$") then
		self.Health.Smooth = true
		if self.Power then
			self.Power.Smooth = true
		end
		if self.DruidMana then
			self.DruidMana.Smooth = true
		end
	end

	----------------------------
	-- Plugin: oUF_SpellRange --
	----------------------------

	if IsAddOnLoaded("oUF_SpellRange") and not self.Range then
		self.SpellRange = {
			insideAlpha = 1,
			outsideAlpha = 0.5,
		}
	end
end

------------------------------------------------------------------------

oUF:Factory(function(oUF)
	config = ns.config

	for _, menu in pairs(UnitPopupMenus) do
		for i = #menu, 1, -1 do
			local name = menu[i]
			if name == "SET_FOCUS" or name == "CLEAR_FOCUS" or name:match("^LOCK_%u+_FRAME$") or name:match("^UNLOCK_%u+_FRAME$") or name:match("^MOVE_%u+_FRAME$") or name:match("^RESET_%u+_FRAME_POSITION") then
				table.remove(menu, i)
			end
		end
	end

	oUF:RegisterStyle("Phanx", ns.Spawn)
	oUF:SetActiveStyle("Phanx")

	local initialConfigFunction = [[
		self:SetAttribute("*type2", "menu")
		self:SetAttribute("initial-width", %d)
		self:SetWidth(%d)
		self:SetAttribute("initial-height", %d)
		self:SetHeight(%d)
	]]

	for u, udata in pairs(ns.uconfig) do
		local name = "oUFPhanx" .. u:gsub("%a", strupper, 1):gsub("target", "Target"):gsub("pet", "Pet")
		if udata.point then
			if udata.attributes then
				-- print("generating header for", u)
				local w = config.width  * (udata.width  or 1)
				local h = config.height * (udata.height or 1)

				ns.headers[u] = oUF:SpawnHeader(name, nil, udata.visible,
					"oUF-initialConfigFunction", initialConfigFunction:format(w, w, h, h),
					unpack(udata.attributes))
			else
				-- print("generating frame for", u)
				ns.frames[u] = oUF:Spawn(u, name)
			end
		end
	end

	for u, f in pairs(ns.frames) do
		local udata = ns.uconfig[u]
		local p1, parent, p2, x, y = string.split(" ", udata.point)
		f:ClearAllPoints()
		f:SetPoint(p1, ns.headers[parent] or ns.frames[parent] or _G[parent] or UIParent, p2, tonumber(x) or 0, tonumber(y) or 0)
	end
	for u, f in pairs(ns.headers) do
		local udata = ns.uconfig[u]
		local p1, parent, p2, x, y = string.split(" ", udata.point)
		f:ClearAllPoints()
		f:SetPoint(p1, ns.headers[parent] or ns.frames[parent] or _G[parent] or UIParent, p2, tonumber(x) or 0, tonumber(y) or 0)
	end

	for i = 1, 3 do
		local barname = "MirrorTimer" .. i
		local bar = _G[barname]

		for i, region in pairs({ bar:GetRegions() }) do
			if region.GetTexture and region:GetTexture() == "SolidTexture" then
				region:Hide()
			end
		end

		bar:SetParent(UIParent)
		bar:SetWidth(225)
		bar:SetHeight(config.height * (1 - config.powerHeight))

		bar.bg = bar:GetRegions()
		bar.bg:ClearAllPoints()
		bar.bg:SetAllPoints(bar)
		bar.bg:SetTexture(config.statusbar)
		bar.bg:SetVertexColor(0.2, 0.2, 0.2, 1)

		bar.text = _G[barname .. "Text"]
		bar.text:ClearAllPoints()
		bar.text:SetPoint("LEFT", bar, 4, 0)
		bar.text:SetFont(config.font, 16, config.fontOutline)

		bar.border = _G[barname .. "Border"]
		bar.border:Hide()

		bar.bar = _G[barname .. "StatusBar"]
		bar.bar:SetAllPoints(bar)
		bar.bar:SetStatusBarTexture(config.statusbar)
		bar.bar:SetAlpha(0.8)

		ns.CreateBorder(bar, config.borderSize, nil, bar.bar, "OVERLAY")
	end
end)