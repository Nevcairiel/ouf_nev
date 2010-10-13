-- upvalues, for great justice
local oUF = oUF
local UnitReaction, UnitIsConnected, UnitIsFriend, UnitIsTapped, UnitIsTappedByPlayer, UnitClass,
      UnitPlayerControlled, UnitCanAttack, UnitLevel, UnitHasVehicleUI, UnitClassification, UnitName, UnitIsPlayer,
      UnitCreatureFamily, UnitCreatureType, UnitIsDead, UnitIsGhost, UnitRace =
      UnitReaction, UnitIsConnected, UnitIsFriend, UnitIsTapped, UnitIsTappedByPlayer, UnitClass,
      UnitPlayerControlled, UnitCanAttack, UnitLevel, UnitHasVehicleUI, UnitClassification, UnitName, UnitIsPlayer,
      UnitCreatureFamily, UnitCreatureType, UnitIsDead, UnitIsGhost, UnitRace
local GetDifficultyColor = GetDifficultyColor or GetQuestDifficultyColor
local MAX_COMBO_POINTS = MAX_COMBO_POINTS

local format, strfind, gsub, strsub, strupper = string.format, string.find, string.gsub, string.sub, string.upper
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local unpack, type, select, tinsert, tconcat =  unpack, type, select, table.insert, table.concat

------------------------------------------------------------
--- formatting functions

-- backdrop for the frames
local backdrop = {
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16,
		edgeFile = "Interface\\AddOns\\oUF_Nev\\media\\border", edgeSize = 8, 
		insets = {left = 4, right = 4, top = 4, bottom = 4},
	}
-- texture and font
local statusbartexture = "Interface\\AddOns\\oUF_Nev\\media\\bantobar"
local font = "Interface\\AddOns\\oUF_Nev\\media\\myriad.ttf"

-- colors
local red = {0.9, 0.2, 0.3}
local yellow = {1, 0.85, 0.1}
local green = {0.4, 0.95, 0.3}
local white = {1, 1, 1}
local smoothGradient = {0.9,  0.2, 0.3, 
                          1, 0.85, 0.1, 
                        0.4, 0.95, 0.3}

-- format strings for unit classifications
local classificationFormats = {
	worldboss = "?? |cffff0000Boss|r",
	rareelite = "%d|cffffcc00+|r |cffffaaffRare|r",
	elite = "%d|cffffcc00+|r",
	rare = "%d |cffff66ffRare|r",
	normal = "%d",
	trivial = "%d",
}

-- format a large number using k and m abbreviations
local function formatLargeValue(value)
	if value < 9999 then
		return value
	elseif value < 999999 then
		return format("%.1fk", value / 1000)
	else
		return format("%.2fm", value / 1000000)
	end
end

-- wrapper for difficulty coloring
local function getDifficultyColor(level)
	local c = GetDifficultyColor((level > 0) and level or 99)
	return c.r, c.g, c.b
end

-- format strings for bar formats
local barFormatMinMax = "%s/%s"
local barFormatPercMinMax = "%d%% %s/%s"
local barFormatPerc = "%d%%"

-- default bar format - min/max value
local function fmt_standard(txt, min, max)
	min, max = formatLargeValue(min), formatLargeValue(max)
	txt:SetFormattedText(barFormatMinMax, min, max)
end

-- bar format with min/max and perc
local function fmt_percminmax(txt, min, max)
	local perc = floor(min/max*100)
	min, max = formatLargeValue(min), formatLargeValue(max)
	txt:SetFormattedText(barFormatPercMinMax, perc, min, max)
end

-- bar format with just perc
local function fmt_perc(txt, min, max)
	local perc = floor(min/max*100)
	txt:SetFormattedText(barFormatPerc, perc)
end

-- metatable for fmt functions
local fmtmeta = { __index = function(self, key)
	if type(key) == "nil" then return nil end
	rawset(self, key, fmt_standard)
	return self[key]
end}

-- format metatable to map all special units to format tags
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

-- specify formatting tags per unit
formats.target.health = fmt_percminmax
formats.targettarget.health = fmt_perc
formats.targettargettarget.health = fmt_perc
formats.raid.health = fmt_perc
formats.raidtarget.health = fmt_perc
formats.focus.health = fmt_percminmax

-- Change oUF Colors for the PowerBar
oUF.colors.power.MANA = {0.3, 0.5, 0.85}
oUF.colors.power.RAGE = {0.9, 0.2, 0.3}
oUF.colors.power.FOCUS = {1, 0.85, 0}
oUF.colors.power.ENERGY = {1, 0.85, 0.1}
oUF.colors.power.HAPPINESS = { 0, 1, 1}
oUF.colors.power.RUNES = {0.5, 0.5, 0.5 }
oUF.colors.power.RUNIC_POWER = {0.6, 0.45, 0.35}

------------------------------------------------------------
--- frame functions and element overrides

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

-- replacement for .Health.Update with better reaction coloring
local updateHealthBarReaction = function(self, event, unit)
	if(self.unit ~= unit) then return end
	local health = self.Health

	if(health.PreUpdate) then health:PreUpdate(unit) end

	local min, max = UnitHealth(unit), UnitHealthMax(unit)
	local disconnected = not UnitIsConnected(unit)
	health:SetMinMaxValues(0, max)

	if(disconnected) then
		health:SetValue(max)
	else
		health:SetValue(min)
	end

	health.disconnected = disconnected
	health.unit = unit

	local r, g, b, t
	if(health.colorTapping and UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit)) then
		t = self.colors.tapped
	elseif(health.colorDisconnected and disconnected) then
		t = self.colors.disconnected
	elseif(health.colorHappiness and unit == "pet" and GetPetHappiness()) then
		t = self.colors.happiness[GetPetHappiness()]
	elseif(health.colorClass and UnitIsPlayer(unit)) or
		(health.colorClassNPC and not UnitIsPlayer(unit)) or
		(health.colorClassPet and UnitPlayerControlled(unit) and not UnitIsPlayer(unit)) then
		local _, class = UnitClass(unit)
		t = self.colors.class[class]
	elseif(health.colorReaction and UnitReaction(unit, 'player') and not UnitIsFriend(unit, 'player')) then
		if(UnitPlayerControlled(unit)) then
			if(UnitCanAttack('player', unit)) then
				r, g, b = self.colors.reaction[1]
			else
				r, g, b = 0.68, 0.33, 0.38
			end
		else
			local reaction = UnitReaction(unit, "player")
			if reaction < 4 then
				t = red
			elseif reaction == 4 then
				t = yellow
			else
				t = green
			end
		end
	elseif(health.colorSmooth) then
		r, g, b = self.ColorGradient(min / max, unpack(health.smoothGradient or self.colors.smooth))
	elseif(health.colorHealth) then
		t = self.colors.health
	end

	if(t) then
		r, g, b = t[1], t[2], t[3]
	end

	if(b) then
		health:SetStatusBarColor(r, g, b)

		local bg = health.bg
		if(bg) then
			local mu = bg.multiplier or 1
			bg:SetVertexColor(r * mu, g * mu, b * mu)
		end
	end

	if(health.PostUpdate) then
		return health:PostUpdate(unit, min, max)
	end
end

-- Update the unit level and classificiation
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

-- update the unit name, class and race
-- also delegates calls to updateLevel
local function updateName(self, event, unit)
	if self.unit ~= unit then return end

	self.Name:SetText(UnitName(unit))

	if self.Lvl then
		updateLevel(self, event, unit)
	end

	if self.Class then
		local color = white
		if UnitIsPlayer(unit) then
			local class, eClass = UnitClass(unit)
			self.Class:SetText(class)
			color = oUF.colors.class[eClass] or white
		else
			self.Class:SetText(UnitCreatureFamily(unit) or UnitCreatureType(unit))
		end
		self.Class:SetVertexColor(unpack(color))
	end

	if self.Race then
		self.Race:SetText(UnitRace(unit))
	end
end

-- update highlight
local function updateHighlight(self, entered)
	if (UnitExists("target") and UnitIsUnit("target", self.unit) and (not strfind(self.unit, "target", 1, true))) or entered then
		self.MouseOverHighlight:Show()
	else
		self.MouseOverHighlight:Hide()
	end
end

-- update over highlight
local function updateMouseOverHighlight(self, event, unit)
	updateHighlight(self)
end

-- enterd the frame
local function OnEnter(self)
	updateHighlight(self, true)
	UnitFrame_OnEnter(self)
end

-- left the frame
local function OnLeave(self)
	updateHighlight(self)
	UnitFrame_OnLeave()
end

-- update Health - .Health.PostUpdate hook
local function updateHealth(bar, unit, min, max)
	local self = bar:GetParent()
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

	bar:GetParent():UNIT_NAME_UPDATE(nil, unit)
end

-- Update Power - .Power.PostUpdate hook
local function updatePower(bar, unit, min, max)
	if max == 0 or UnitIsDead(unit) or UnitIsGhost(unit) or not UnitIsConnected(unit) then
		bar:SetValue(0)
		if bar.value then
			bar.value:SetText()
		end
	elseif bar.value then
		formats[unit].power(bar.value, min, max)
	end
end

-- .Auras.SetPosition hook
-- custom aura positioning logic
local function SetAuraPosition(icons, x)
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
		local unit = icons:GetParent().unit
		if unit == "target" or unit == "focus" then
			isFriend = UnitIsFriend(unit, "player")
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

-- .Auras.PostCreateIcon hook
-- Adjust scale and fix count text
local function postCreateAuraIcon(icons, button)
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

-- adjust the position of the name text depending on a visible raid icon in micro layout
local function fixNamePos(self, state)
	local name = self.Name
	if state then
		name:SetPoint("LEFT", 16, 0)
	else
		name:SetPoint("LEFT", 2, 0)
	end
end

-- utility function to create a new font string
local function getFontString(parent, justify, size)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(font, size or 11)
	fs:SetShadowColor(0,0,0)
	fs:SetShadowOffset(0.8, -0.8)
	fs:SetTextColor(1,1,1)
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

-- big ass style function
local function style(settings, self, unit, noHeader)
	self.menu = menu
	self.unit = unit
	self:RegisterForClicks("anyup")
	self:SetScript("OnEnter", OnEnter)
	self:SetScript("OnLeave", OnLeave)

	local micro = settings["nev-micro"]
	local tiny = settings["nev-tiny"]
	local mt = settings["nev-mt"]

	if self:GetAttribute("oUF_NevPet") then
		micro, tiny, mt = true, nil, nil
	end

	if noHeader then
		self:SetHeight(settings["initial-height"])
		self:SetWidth(settings["initial-width"])
		self:SetScale(settings["initial-scale"])
	end

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

	hp.frequentUpdates = true

	if unit and strfind(unit, "target", 1, true) then
		hp.colorReaction = true
		hp.Update = updateHealthBarReaction
	end

	-- Healthbar text
	hp.value = getFontString(hp, "RIGHT")
	hp.value:SetPoint("RIGHT", -2, 0)

	self.Health = hp
	self.Health.PostUpdate = updateHealth

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
	if not micro then
		-- Power Bar
		local pp = CreateFrame("StatusBar", nil, self)
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
		self.Power.PostUpdate = updatePower

		pp.value = getFontString(pp, "RIGHT")
		pp.value:SetPoint("RIGHT", -2, 0)

		self.Lvl = getFontString(pp)
		self.Lvl:SetPoint("LEFT", pp, "LEFT", 2, 0)

		self.Class = getFontString(pp)
		self.Class:SetPoint("LEFT", self.Lvl, "RIGHT",  1, 0)

		self.Race = getFontString(pp, "LEFT")
		self.Race:SetPoint("LEFT", self.Class, "RIGHT",  1, 0)
		self.Race:SetPoint("RIGHT", pp.value, "LEFT",  1, 0)

		if unit == "party" or unit == "player" then --raid, party or player gets a leader and a LFD icon
			local leader = hp:CreateTexture(nil, "OVERLAY")
			leader:SetHeight(12)
			leader:SetWidth(12)
			leader:SetPoint("TOPLEFT", self, -1, 3)
			leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
			self.Leader = leader

			local lfdc = CreateFrame("Frame", nil, self)
			lfdc:SetHeight(12)
			lfdc:SetWidth(12)
			lfdc:SetPoint("BOTTOMLEFT", self, -3, -3)
			lfdc:SetFrameLevel(lfdc:GetFrameLevel() + 2)
			local lfd = lfdc:CreateTexture(nil, "OVERLAY")
			lfd:SetAllPoints(lfdc)
			self.LFDRole = lfd
		end

		if unit == "player" then -- player gets resting and combat
			local resting = pp:CreateTexture(nil, "OVERLAY")
			resting:SetHeight(14)
			resting:SetWidth(14)
			resting:SetPoint("BOTTOMRIGHT", 8, -8)
			resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
			resting:SetTexCoord(0.09, 0.43, 0.08, 0.42)
			self.Resting = resting

			local combat = pp:CreateTexture(nil, "OVERLAY")
			combat:SetHeight(12)
			combat:SetWidth(12)
			combat:SetPoint("BOTTOMRIGHT", 6, -6)
			combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
			combat:SetTexCoord(0.57, 0.90, 0.08, 0.41)
			self.Combat = combat
		end

		-- Target has CPoints and a castbar
		if settings['nev-castbar'] then
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
		end

		if unit == "target" then
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
		end

		if unit ~= "focus" then
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
			auras.rows = 1
			auras.cols = 11

			if unit == "target" then
				auras.rows = 4
			elseif unit == "pet" or unit == "party" then
				auras.buffFilter = "RAID|HELPFUL"
				auras.debuffFilter = "RAID|HARMFUL"
			elseif unit == "player" then
				auras.numBuffs = 0
				auras.debuffFilter = "RAID|HARMFUL"
			end

			self.Auras = auras
			self.Auras.PostCreateIcon = postCreateAuraIcon
			self.Auras.SetPosition = SetAuraPosition
		end
	end

	--self.disallowVehicleSwap = true

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
	["nev-castbar"] = true,
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


local configFunc = [[
	local width = self:GetAttribute("initial-width")
	if width then
		self:SetWidth(width)
	end

	local height = self:GetAttribute("initial-height")
	if height then
		self:SetHeight(height)
	end

	local scale = self:GetAttribute("initial-scale")
	if scale then
		self:SetScale(scale)
	end
]]

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
focus:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 25, -450)

oUF:SetActiveStyle("Nev")
local party = oUF:SpawnHeader("oUF_Party", nil, "party",
	"template", "oUF_Nev_PartyTemplate",
	"showParty", true,
	"yOffset", -10,
	"oUF-initialConfigFunction", configFunc
)
party:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -120)
party:Show()

oUF:SetActiveStyle("Nev_MicroMT")
local MTs = oUF:SpawnHeader("oUF_MTs", nil, "raid",
	"template", "oUF_Nev_MTTemplate",
	"showRaid", true,
	"yOffset", 1,
	"sortDir", "ASC",
	"oUF-initialConfigFunction", configFunc
)
MTs:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -140)

if oRA3 then
	local tankhandler = CreateFrame("Frame")

	tankhandler:SetScript("OnEvent", function(self, event)
		if event == "PLAYER_REGEN_ENABLED" then
			self:UpdateTanks()
			self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		end
	end)

	function tankhandler:UpdateTanks(tanks)
		if not tanks then tanks = oRA3:GetSortedTanks() end
		MTs:SetAttribute("nameList", tconcat(tanks, ","))
	end

	function tankhandler:OnTanksUpdated(event, tanks)
		if InCombatLockdown() then
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
		else
			self:UpdateTanks(tanks)
		end
	end

	tankhandler:UpdateTanks()
	oRA3.RegisterCallback(tankhandler, "OnTanksUpdated")
else
	MTs:SetAttribute("groupFilter", "MAINTANK")
	MTs:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
	MTs:SetAttribute("groupBy", "ROLE")
end
MTs:Show()
