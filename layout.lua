-- upvalues, for great justice
local oUF = oUF
local UnitReaction, UnitIsConnected, UnitIsFriend, UnitIsTapped, UnitIsTappedByPlayer, UnitClass,
      UnitPlayerControlled, UnitCanAttack, UnitLevel, UnitHasVehicleUI, UnitClassification, UnitName, UnitIsPlayer,
      UnitCreatureFamily, UnitCreatureType, UnitIsDead, UnitIsGhost, UnitRace =
      UnitReaction, UnitIsConnected, UnitIsFriend, UnitIsTapped, UnitIsTappedByPlayer, UnitClass,
      UnitPlayerControlled, UnitCanAttack, UnitLevel, UnitHasVehicleUI, UnitClassification, UnitName, UnitIsPlayer,
      UnitCreatureFamily, UnitCreatureType, UnitIsDead, UnitIsGhost, UnitRace
local GetDifficultyColor = GetDifficultyColor
local RAID_CLASS_COLORS, MAX_COMBO_POINTS = RAID_CLASS_COLORS, MAX_COMBO_POINTS

local format, strfind, gsub, strsub, strupper = string.format, string.find, string.gsub, string.sub, string.upper
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local unpack, type, select, tinsert =  unpack, type, select, table.insert

local backdrop = {
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16,
		edgeFile = "Interface\\AddOns\\oUF_Nev\\media\\border", edgeSize = 8, 
		insets = {left = 4, right = 4, top = 4, bottom = 4},
	}
local statusbartexture = "Interface\\AddOns\\oUF_Nev\\media\\bantobar"
local font = "Interface\\AddOns\\oUF_Nev\\media\\myriad.ttf"

local red = {0.9, 0.2, 0.3}
local yellow = {1, 0.85, 0.1}
local green = {0.4, 0.95, 0.3}
local white = { r = 1, g = 1, b = 1}
local smoothGradient = {0.9,  0.2, 0.3, 
                          1, 0.85, 0.1, 
                        0.4, 0.95, 0.3}

-- This is the core of RightClick menus on diffrent frames
local function menu(self)
	local unit = strsub(self.unit, 1, -2)
	local cunit = gsub(self.unit, "(.)", strupper, 1)

	if(unit == "party" or unit == "partypet") then
		ToggleDropDownMenu(1, nil, _G["PartyMemberFrame"..self.id.."DropDown"], "cursor", 0, 0)
	elseif(_G[cunit.."FrameDropDown"]) then
		ToggleDropDownMenu(1, nil, _G[cunit.."FrameDropDown"], "cursor", 0, 0)
	end
end

local function formatLargeValue(value)
	if value < 9999 then
		return value
	elseif value < 999999 then
		return format("%.1fk", value / 1000)
	else
		return format("%.2fm", value / 1000000)
	end
end

local classificationFormats = {
	worldboss = "?? |cffff0000Boss|r",
	rareelite = "%d|cffffcc00+|r |cffffaaffRare|r",
	elite = "%d|cffffcc00+|r",
	rare = "%d |cffff66ffRare|r",
	normal = "%d",
	trivial = "%d",
}

local function getDifficultyColor(level)
	local c = GetDifficultyColor((level > 0) and level or 99)
	return c.r, c.g, c.b
end

local barFormatMinMax = "%s/%s"
local barFormatPercMinMax = "%d%% %s/%s"
local barFormatPerc = "%d%%"

local function fmt_standard(txt, min, max)
	min, max = formatLargeValue(min), formatLargeValue(max)
	txt:SetFormattedText(barFormatMinMax, min, max)
end

local function fmt_percminmax(txt, min, max)
	local perc = floor(min/max*100)
	min, max = formatLargeValue(min), formatLargeValue(max)
	txt:SetFormattedText(barFormatPercMinMax, perc, min, max)
end

local function fmt_perc(txt, min, max)
	local perc = floor(min/max*100)
	txt:SetFormattedText(barFormatPerc, perc)
end

local fmtmeta = { __index = function(self, key)
	if type(key) == "nil" then return nil end
	rawset(self, key, fmt_standard)
	return self[key]
end}

local formats = setmetatable({}, { 
	__index = function(self, key)
		if type(key) == "nil" then return nil end
		if strfind(key, "raidpet%d") then self[key] = self.raidpet
		elseif strfind(key, "raidtarget%d") then self[key] = self.raidtarget
		elseif strfind(key, "raid%d") then self[key] = self.raid
		elseif strfind(key, "partypet%d") then self[key] = self.partypet
		elseif strfind(key, "party%dtarget") then self[key] = self.partytarget
		elseif strfind(key, "party%d") then self[key] = self.party
		else
			self[key] = {}
		end
		return self[key]
	end,
	__newindex = function(self, key, value)
		rawset(self, key, setmetatable(value, fmtmeta))
	end,
})

formats.target.health = fmt_percminmax
formats.targettarget.health = fmt_perc
formats.targettargettarget.health = fmt_perc
formats.raid.health = fmt_perc
formats.raidtarget.health = fmt_perc

local function updateHealthBarWithReaction(self, event, unit, bar, min, max)
	local r, g, b, t
	if bar.colorTapping and UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
		t = self.colors.tapped
	elseif bar.colorDisconnected and not UnitIsConnected(unit) then
		t = self.colors.disconnected
	elseif bar.colorReaction and not UnitIsFriend(unit, "player") then
		if UnitPlayerControlled(unit) then
			if UnitCanAttack("player", unit) then
				r, g, b = red
			else
				r, g, b = 0.68, 0.33, 0.38
			end
		else
			local reaction = UnitReaction(unit, "player")
			if reaction then
				if reaction > 4 then
					t = green
				elseif reaction == 4 then
					t = yellow
				elseif reaction < 4 then
					t = red
				end
			end
		end
	elseif bar.colorSmooth and max ~= 0 then
		r, g, b = self.ColorGradient(min / max, unpack(bar.smoothGradient or self.colors.smooth))
	elseif bar.colorHealth then
		t = self.colors.health
	end

	if t then
		r, g, b = t[1], t[2], t[3]
	end

	if b then
		bar:SetStatusBarColor(r, g, b)
		local bg = bar.bg
		if bg then
			bg:SetVertexColor(r, g, b)
		end
	end
end

-- Change oUF Colors for the PowerBar
oUF.colors.power.MANA = {0.3, 0.5, 0.85}
oUF.colors.power.RAGE = {0.9, 0.2, 0.3}
oUF.colors.power.FOCUS = {1, 0.85, 0}
oUF.colors.power.ENERGY = {1, 0.85, 0.1}
oUF.colors.power.HAPPINESS = { 0, 1, 1}
oUF.colors.power.RUNES = {0.5, 0.5, 0.5 }
oUF.colors.power.RUNIC_POWER = {0.6, 0.45, 0.35}

local function updateLevel(self, event, unit)
	if self.unit ~= unit then return end
	
	local lvl = self.Lvl
	local level = UnitLevel(unit)

	lvl:SetFormattedText(classificationFormats[UnitClassification(unit)] or classificationFormats["normal"], level)

	if UnitCanAttack("player", unit) then
		lvl:SetTextColor(getDifficultyColor(level))
	else
		lvl:SetTextColor(1, 1, 1)
	end
end

local function updateName(self, event, unit)
	if self.unit ~= unit then return end

	self.Name:SetText(UnitName(unit))

	if self.Lvl then
		updateLevel(self, event, unit)
	end

	if self.Class then
		local color = white
		if UnitIsPlayer(unit) then
			self.Class:SetText(UnitClass(unit))
			color = RAID_CLASS_COLORS[select(2, UnitClass(unit))] or white
		else
			self.Class:SetText(UnitCreatureFamily(unit) or UnitCreatureType(unit))
		end
		self.Class:SetVertexColor(color.r, color.g, color.b)
	end

	if self.Race then
		self.Race:SetText(UnitRace(unit))
	end
end

local function updateHighlight(self, entered)
	if (UnitExists("target") and UnitIsUnit("target", self.unit) and (not strfind(self.unit, "target", 1, true))) or entered then
		self.MouseOverHighlight:Show()
	else
		self.MouseOverHighlight:Hide()
	end
end

local function updateMouseOverHighlight(self, event, unit)
	updateHighlight(self)
end

local function OnEnter(self)
	updateHighlight(self, true)
	UnitFrame_OnEnter(self)
end

local function OnLeave(self)
	updateHighlight(self)
	UnitFrame_OnLeave()
end

local function updateHealth(self, event, unit, bar, min, max)
	if UnitIsDead(unit) then
		bar:SetValue(0)
		bar.value:SetText("Dead")
	elseif UnitIsGhost(unit) then
		bar:SetValue(0)
		bar.value:SetText("Ghost")
	elseif not UnitIsConnected(unit) then
		bar:SetValue(0)
		bar.value:SetText("Offline")
	else
		formats[unit].health(bar.value, min, max)
	end
	self:UNIT_NAME_UPDATE(event, unit)
end

local function updatePower(self, event, unit, bar, min, max)
	if max == 0 or UnitIsDead(unit) or UnitIsGhost(unit) or not UnitIsConnected(unit) then
		bar:SetValue(0)
		if bar.value then
			bar.value:SetText()
		end
	elseif bar.value then
		formats[unit].power(bar.value, min, max)
	end
end

local function getFontString(parent, justify, size)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(font, size or 11)
	fs:SetShadowColor(0,0,0)
	fs:SetShadowOffset(0.8, -0.8)
	fs:SetTextColor(1,1,1)
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

local function SetAuraPosition(self, icons, x)
	if icons and x > 0 then
		local col = 0
		local row = 0
		local spacing = 2
		local size = 16 + spacing
		local anchor = icons.initialAnchor or "BOTTOMLEFT"
		local growthx = (icons["growth-x"] == "LEFT" and -1) or 1
		local growthy = (icons["growth-y"] == "DOWN" and -1) or 1
		local cols = icons.cols or 10
		local rows = icons.rows or 2
		local maxicons = cols*rows
		local isFriend = true
		if self.unit == "target" or self.unit == "focus" then
			isFriend = UnitIsFriend(self.unit, "player")
		end

		local showBuffs, showDebuffs = 0, 0
		if isFriend then
			showDebuffs = min(icons.visibleDebuffs, maxicons)
			showBuffs = min(icons.visibleBuffs, maxicons - (showDebuffs > 0 and showDebuffs + 1 or 0))
		else
			showBuffs = min(icons.visibleBuffs, maxicons)
			showDebuffs = min(icons.visibleDebuffs, maxicons - (showBuffs > 0 and showBuffs + 1 or 0))
		end
		local requiredIcons = showBuffs + showDebuffs + ((showBuffs > 0 and showDebuffs > 0) and 1 or 0)
		assert(requiredIcons <= maxicons)

		rows = ceil(requiredIcons / cols)

		-- show buffs
		col, row = 0, 0
		for i = 1, showBuffs do
			local button = icons[i]
			if(button and button:IsShown()) then
				if(col >= cols) then
					col = 0
					row = row + 1
				end
				button:ClearAllPoints()
				button:SetPoint(anchor, icons, anchor, col * size * growthx, row * size * growthy)
				col = col + 1
			end
		end

		local offset = icons.visibleBuffs
		row, col = rows - 1, cols - 1
		for i = offset + 1, (offset + showDebuffs) do
			local button = icons[i]
			if button and button:IsShown() then
				if col < 0 then
					col = cols - 1
					row = row - 1
				end
				button:ClearAllPoints()
				button:SetPoint(anchor, icons, anchor, col * size * growthx, row * size * growthy)
				col = col - 1
			end
		end
	end
end

local function postCreateAuraIcon(self, button, icons, index, debuff)
	local cols = icons.cols or 10
	local rows = icons.rows or 2
	local width = icons.width or icons:GetWidth() or self:GetWidth()
	local scale = width / (16 * cols + (cols - 1) * 2)
	button:SetScale(scale)

	-- change default font, its teh big
	local Count = button.count
	Count:SetFont(font, 11, "OUTLINE")
	Count:SetShadowColor(0, 0, 0, 1)
	Count:SetShadowOffset(0.8, -0.8)
	Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
	Count:SetWidth(18)
	Count:SetHeight(10)
	Count:SetJustifyH("RIGHT")
end

local function fixNamePos(self, state)
	local name = self.Name
	if state then
		name:SetPoint("LEFT", 16, 0)
	else
		name:SetPoint("LEFT", 2, 0)
	end
end

local function style(settings, self, unit)
	self.menu = menu
	self.unit = unit
	self:RegisterForClicks("anyup")
	self:SetAttribute("*type2", "menu")
	self:SetScript("OnEnter", OnEnter)
	self:SetScript("OnLeave", OnLeave)

	local micro = settings["nev-micro"]
	local tiny = settings["nev-tiny"]
	local mt = settings["nev-mt"]

	-- Background
	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0,0,0,0.5)
	self:SetBackdropBorderColor(0.31, 0.28, 0.47, 1)

	local hpheight = micro and 18 or (tiny and 13 or 19)
	local ppheight = tiny and 10 or 16

	-- Healthbar
	local hp = CreateFrame("StatusBar", nil, self)
	hp:SetHeight(hpheight)
	hp:SetStatusBarTexture(statusbartexture)
	hp:SetAlpha(0.8)

	hp:SetPoint("TOPLEFT", 5, -5)
	hp:SetPoint("TOPRIGHT", -5, -5)

	-- Healthbar background
	hp.bg = hp:CreateTexture(nil, "BORDER")
	hp.bg:SetAllPoints(hp)
	hp.bg:SetTexture(statusbartexture)
	hp.bg:SetAlpha(0.25)

	-- healthbar coloring
	if mt then
		hp.colorClass = true
	end
	hp.colorTapping = true
	hp.colorDisconnected = true
	hp.colorSmooth = true
	hp.smoothGradient = smoothGradient

	if unit == "player" then
		hp.frequentUpdates = true
	end

	if unit and strfind(unit, "target", 1, true) then
		hp.colorReaction = true
		self.OverrideUpdateHealth = updateHealthBarWithReaction
	end

	-- Healthbar text
	hp.value = getFontString(hp, "RIGHT")
	hp.value:SetPoint("RIGHT", -2, 0)

	self.Health = hp
	self.PostUpdateHealth = updateHealth

	local icon = hp:CreateTexture(nil, "OVERLAY")
	if micro then
		icon:SetHeight(14)
		icon:SetWidth(14)
		icon:SetPoint("LEFT", 1, 0)
		icon.oShow = icon.Show
		icon.Show = function(this) this:oShow() fixNamePos(self, true) end
		icon.oHide = icon.Hide
		icon.Hide = function(this) this:oHide() fixNamePos(self, false) end
	else
		icon:SetHeight(16)
		icon:SetWidth(16)
		icon:SetPoint("TOP", self, 0, 5)
	end
	self.RaidIcon = icon

	self.Name = getFontString(hp, "LEFT")
	self.Name:SetPoint("LEFT", 2, 0)
	self.Name:SetPoint("RIGHT", hp.value, "LEFT", 2, 0)
	self:RegisterEvent("UNIT_NAME_UPDATE", updateName)
	self:RegisterEvent("UNIT_LEVEL", updateName)

	local dbh = hp:CreateTexture(nil, "OVERLAY")
	dbh:SetTexture("Interface\\AddOns\\oUF_Nev\\media\\debuffHighlight")
	dbh:SetBlendMode("ADD")
	dbh:SetVertexColor(0,0,0,0) -- set alpha to 0 to hide the texture
	dbh:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -5)
	dbh:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 5)
	self.DebuffHighlight = dbh
	self.DebuffHighlightFilter = true
	self.DebuffHighlightAlpha = 0.5

	local moh = hp:CreateTexture(nil, "OVERLAY")
	moh:SetTexture("Interface\\AddOns\\oUF_Nev\\media\\mouseoverHighlight")
	moh:SetAlpha(0.5)
	moh:SetBlendMode("ADD")
	moh:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -5)
	moh:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 5)
	moh:Hide()
	self.MouseOverHighlight = moh
	self:RegisterEvent("PLAYER_TARGET_CHANGED", updateMouseOverHighlight)

	-- micro is only the health bar and associated strings, anything that follows is not micro anymore
	-- Only ToT/ToToT frames
	local pp
	if not micro then
		-- Power Bar
		pp = CreateFrame("StatusBar", nil, self)
		pp:SetHeight(ppheight)
		pp:SetStatusBarTexture(statusbartexture)
		pp:SetAlpha(0.8)

		pp:SetPoint("LEFT", 5, 0)
		pp:SetPoint("RIGHT", -5, 0)
		pp:SetPoint("TOP", hp, "BOTTOM", 0, -1)

		pp.colorPower = true
		pp.colorDisconnected = true
		pp.colorTapping = true

		pp.bg = pp:CreateTexture(nil, "BORDER")
		pp.bg:SetAllPoints(pp)
		pp.bg:SetTexture(statusbartexture)
		pp.bg:SetAlpha(0.25)

		if unit == "player" then
			pp.frequentUpdates = true
		end

		self.Power = pp
		self.PostUpdatePower = updatePower

		pp.value = getFontString(pp, "RIGHT")
		pp.value:SetPoint("RIGHT", -2, 0)

		self.Lvl = getFontString(pp)
		self.Lvl:SetPoint("LEFT", pp, "LEFT", 2, 0)

		self.Class = getFontString(pp)
		self.Class:SetPoint("LEFT", self.Lvl, "RIGHT",  1, 0)

		self.Race = getFontString(pp, "LEFT")
		self.Race:SetPoint("LEFT", self.Class, "RIGHT",  1, 0)
		self.Race:SetPoint("RIGHT", pp.value, "LEFT",  1, 0)
	end

	if (not mt and not unit) or unit == "player" then --raid, party or player gets a leader icon
		local leader = hp:CreateTexture(nil, "OVERLAY")
		leader:SetHeight(12)
		leader:SetWidth(12)
		leader:SetPoint("TOPLEFT", self, -1, 3)
		leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
		self.Leader = leader
	end

	if unit == "player" then -- player gets resting and combat
		local resting = pp:CreateTexture(nil, "OVERLAY")
		resting:SetHeight(14)
		resting:SetWidth(14)
		resting:SetPoint("BOTTOMLEFT", -8, -8)
		resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
		resting:SetTexCoord(0.09, 0.43, 0.08, 0.42)
		self.Resting = resting

		local combat = pp:CreateTexture(nil, "OVERLAY")
		combat:SetHeight(12)
		combat:SetWidth(12)
		combat:SetPoint("BOTTOMLEFT", -6, -6)
		combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
		combat:SetTexCoord(0.57, 0.90, 0.08, 0.41)
		self.Combat = combat
	end

	-- Target has CPoints and a castbar
	if unit == "target" then
		local castbar = CreateFrame("StatusBar", nil, self)
		castbar:SetPoint("LEFT", 5, 0)
		castbar:SetPoint("RIGHT", -5, 0)
		castbar:SetPoint("TOP", pp, "BOTTOM", 0, -1)
		castbar:SetStatusBarTexture(statusbartexture)
		castbar:SetStatusBarColor(1, 0.7, 0)
		--castbar:SetBackdrop(backdrop)
		--castbar:SetBackdropColor(0, 0, 0)
		castbar:SetHeight(12)
		castbar:SetAlpha(0.8)

		castbar.Text = getFontString(castbar, nil, 10)
		castbar.Text:SetPoint("LEFT", castbar, 2, 0)

		castbar.Time = getFontString(castbar, nil, 10)
		castbar.Time:SetJustifyH("RIGHT")
		castbar.Time:SetPoint("RIGHT", castbar, -2, 0)

		castbar.bg = castbar:CreateTexture(nil, 'BORDER')
		castbar.bg:SetAllPoints(castbar)
		castbar.bg:SetTexture(statusbartexture)
		castbar.bg:SetVertexColor(0.25, 0.25, 0.25, 0.35)
		castbar.bg:SetAlpha(.2)

		castbar.Spark = castbar:CreateTexture(nil, "OVERLAY")
		castbar.Spark:SetWidth(4)
		castbar.Spark:SetBlendMode("ADD")
		self.Castbar = castbar

		self.CPoints = {}
		for i=1,MAX_COMBO_POINTS do
			local c = hp:CreateTexture(nil, "OVERLAY")
			c:SetTexture("Interface\\AddOns\\oUF_Nev\\media\\combo")
			c:SetHeight(10)
			c:SetWidth(10)
			if i > 1 then
				c:SetPoint("BOTTOMRIGHT",self.CPoints[i-1],"BOTTOMLEFT")
			else
				c:SetPoint("BOTTOMRIGHT",self,"BOTTOMRIGHT",-4,1)
			end
			tinsert(self.CPoints, c)
		end
		-- a metatable hack to always query UnitHasVehicleUI on CP updates
		setmetatable(self.CPoints, {__index = function(t, k)
			if k == "unit" then
				return UnitHasVehicleUI("player") and "vehicle" or "player"
			end
			return nil
		end})
	end

	if not micro and (unit == "target" or unit == "pet" or not unit) then
		local auras = CreateFrame("Frame", nil, self)
		auras:SetHeight(16)
		auras:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", -4, 2)
		auras:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 4, 2)
		auras.width = settings["initial-width"] - 8
		auras.initialAnchor = "TOPLEFT"
		auras["growth-x"] = "RIGHT"
		auras["growth-y"] = "DOWN"
		auras.spacing = 2
		auras.disableCooldown = true
		auras.showDebuffType = true

		if unit == "target" then
			auras.rows = 4
			auras.cols = 11
		elseif unit == "pet" then
			auras.rows = 1
			auras.cols = 11
			auras.buffFilter = "RAID|HELPFUL"
			auras.debuffFilter = "RAID|HARMFUL"
		elseif not unit then -- party frames
			auras.rows = 1
			auras.cols = 11
			auras.buffFilter = "RAID|HELPFUL"
			auras.debuffFilter = "RAID|HARMFUL"
		end

		self.Auras = auras
		self.PostCreateAuraIcon = postCreateAuraIcon
		self.SetAuraPosition = SetAuraPosition
	end

	self.disallowVehicleSwap = true

	return self
end

oUF:RegisterStyle("Nev", setmetatable({
	["initial-width"] = 170,
	["initial-height"] = 46,
	["initial-scale"] = 1.3,
}, {__call = style}))

oUF:RegisterStyle("NevCastBar", setmetatable({
	["initial-width"] = 170,
	["initial-height"] = 59,
	["initial-scale"] = 1.3,
	["castbar"] = true,
}, {__call = style}))

oUF:RegisterStyle("Nev_Tiny", setmetatable({
	["initial-width"] = 190,
	["initial-height"] = 34,
	["initial-scale"] = 1.0,
	["nev-tiny"] = true,
}, {__call = style}))

oUF:RegisterStyle("Nev_Micro", setmetatable({
	["initial-width"] = 135,
	["initial-height"] = 28,
	["initial-scale"] = 1.0,
	["nev-micro"] = true,
}, {__call = style}))

oUF:RegisterStyle("Nev_MicroMT", setmetatable({
	["initial-width"] = 135,
	["initial-height"] = 28,
	["initial-scale"] = 1.0,
	["nev-micro"] = true,
	["nev-mt"] = true,
}, {__call = style}))


oUF:SetActiveStyle("Nev")
local player = oUF:Spawn("player", "oUF_Player")
player:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -26)

oUF:SetActiveStyle("NevCastBar")
local target = oUF:Spawn("target", "oUF_Target")
target:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 185, -26)

oUF:SetActiveStyle("Nev_Micro")
local targettarget = oUF:Spawn("targettarget", "oUF_TargetTarget")
targettarget:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 460, -35)

local targettargettarget = oUF:Spawn("targettargettarget", "oUF_TargetTargetTarget")
targettargettarget:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 460, -63)

oUF:SetActiveStyle("Nev_Tiny")
local pet = oUF:Spawn("pet", "oUF_Pet")
pet:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 25, -90)

local focus = oUF:Spawn("focus", "oUF_Focus")
focus:SetScale(1.2)
focus:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 25, -390)

oUF:SetActiveStyle("Nev")
local party = oUF:Spawn("header", "oUF_Party")
party:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -120)
party:SetManyAttributes("showParty", true, "yOffset", -10)
party:Show()

oUF:SetActiveStyle("Nev_MicroMT")
local MTs = oUF:Spawn("header", "oUF_MTs")
MTs:SetPoint("CENTER", 0, -200)
MTs:SetManyAttributes(
	"template", "oUF_Nev_MTTemplate",
	"showRaid", true,
	"groupFilter", "MAINTANK",
	"groupBy", "ROLE",
	"groupingOrder", "1,2,3,4,5,6,7,8"
)
MTs:Show()

RegisterStateDriver(party, "visibility", "[group:raid]hide;show")
