-- upvalues, for great justice
local oUF = oUF
local UnitReaction, UnitIsConnected, UnitIsFriend, UnitIsTapped, UnitIsTappedByPlayer, UnitClass,
      UnitPlayerControlled, UnitCanAttack, UnitLevel, UnitHasVehicleUI, UnitClassification, UnitName, UnitIsPlayer,
      UnitCreatureFamily, UnitCreatureType, UnitIsDead, UnitIsGhost, UnitRace =
      UnitReaction, UnitIsConnected, UnitIsFriend, UnitIsTapped, UnitIsTappedByPlayer, UnitClass,
      UnitPlayerControlled, UnitCanAttack, UnitLevel, UnitHasVehicleUI, UnitClassification, UnitName, UnitIsPlayer,
      UnitCreatureFamily, UnitCreatureType, UnitIsDead, UnitIsGhost, UnitRace
local GetQuestGreenRange, GetDifficultyColor = GetQuestGreenRange, GetDifficultyColor
local RAID_CLASS_COLORS, MAX_COMBO_POINTS = RAID_CLASS_COLORS, MAX_COMBO_POINTS

local format, floor, unpack, type, select, tinsert = string.format, math.floor, unpack, type, select, tinsert

local backdrop = {
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16,
		edgeFile = "Interface\\AddOns\\oUF_Nev\\media\\border", edgeSize = 8, 
		insets = {left = 4, right = 4, top = 4, bottom = 4},
	}
local statusbartexture = "Interface\\AddOns\\oUF_Nev\\media\\bantobar"
-- local bordertexture = "Interface\\AddOns\\oUF_Ammo\\media\\border"
local font = "Interface\\AddOns\\oUF_Nev\\media\\myriad.ttf"

local red = {0.9, 0.2, 0.3}
local yellow = {1, 0.85, 0.1}
local green = {0.4, 0.95, 0.3}
local white = { r = 1, g = 1, b = 1}
local smoothGradient = {0.9,  0.2, 0.3, 
                          1, 0.85, 0.1, 
                        0.4, 0.95, 0.3}

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
	worldboss = "?? Boss",
	rareelite = "%d+ Rare",
	elite = "%d+",
	rare = "%d Rare",
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
		if key:find("raidpet%d") then self[key] = self.raidpet
		elseif key:find("raidtarget%d") then self[key] = self.raidtarget
		elseif key:find("raid%d") then self[key] = self.raid
		elseif key:find("partypet%d") then self[key] = self.partypet
		elseif key:find("party%dtarget") then self[key] = self.partytarget
		elseif key:find("party%d") then self[key] = self.party
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

local function OnEnter(self)
	UnitFrame_OnEnter(self)
end

local function OnLeave(self)
	UnitFrame_OnLeave()
end

local updateHealthBarWithReaction
do
	function updateHealthBarWithReaction(self, event, unit, bar, min, max)
		local r, g, b, t
		if(bar.colorTapping and UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit)) then
			t = self.colors.tapped
		elseif(bar.colorDisconnected and not UnitIsConnected(unit)) then
			t = self.colors.disconnected
		elseif(bar.colorReaction and not UnitIsFriend(unit, "player")) then
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
		elseif(bar.colorSmooth and max ~= 0) then
			r, g, b = self.ColorGradient(min / max, unpack(bar.smoothGradient or self.colors.smooth))
		elseif(bar.colorHealth) then
			t = self.colors.health
		end

		if(t) then
			r, g, b = t[1], t[2], t[3]
		end

		if(b) then
			bar:SetStatusBarColor(r, g, b)

			local bg = bar.bg
			if(bg) then
				bg:SetVertexColor(r, g, b)
			end
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

local function style(settings, self, unit)
	self:RegisterForClicks("anyup")
	self:SetAttribute("*type2", "menu")

	local micro = settings["nev-micro"]
	local tiny = settings["nev-tiny"]

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
	hp.colorTapping = true
	hp.colorDisconnected = true
	hp.colorSmooth = true
	hp.smoothGradient = smoothGradient

	if unit == "player" then
		hp.frequentUpdates = true
	end

	if unit:find("target") then
		hp.colorReaction = true
		self.OverrideUpdateHealth = updateHealthBarWithReaction
	end
	
	-- Healthbar text
	hp.value = getFontString(hp)
	hp.value:SetPoint("RIGHT", -2, 0)

	self.Health = hp
	self.PostUpdateHealth = updateHealth

	local icon = hp:CreateTexture(nil, "OVERLAY")
	icon:SetHeight(16)
	icon:SetWidth(16)
	icon:SetPoint("TOP", self, 0, 5)
	icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	self.RaidIcon = icon

	self.Name = getFontString(hp)
	self.Name:SetPoint("LEFT", 2, 0)
	self:RegisterEvent("UNIT_NAME_UPDATE", updateName)
	self:RegisterEvent("UNIT_LEVEL", updateName)

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

		pp.value = getFontString(pp)
		pp.value:SetPoint("RIGHT", -2, 0)

		self.Lvl = getFontString(pp)
		self.Lvl:SetPoint("LEFT", pp, "LEFT", 2, 0)

		self.Class = getFontString(pp)
		self.Class:SetPoint("LEFT", self.Lvl, "RIGHT",  1, 0)

		self.Race = getFontString(pp)
		self.Race:SetPoint("LEFT", self.Class, "RIGHT",  1, 0)
	end

	if not unit or unit == "player" then --raid, party or player gets a leader icon
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
		castbar.Spark:SetWidth( 4 )
		castbar.Spark:SetBlendMode("ADD")
		self.Castbar = castbar

		self.CPoints = {}
		for i=1,MAX_COMBO_POINTS do
			local c = castbar:CreateTexture(nil, "OVERLAY")
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


oUF:SetActiveStyle("Nev")
local player = oUF:Spawn("player", "oUF_Player")
player:SetPoint("RIGHT", UIParent, "CENTER", -20, -250)

oUF:SetActiveStyle("NevCastBar")
local target = oUF:Spawn("target", "oUF_Target")
target:SetPoint("LEFT", UIParent, "CENTER", 20, -250)

oUF:SetActiveStyle("Nev_Micro")
local targettarget = oUF:Spawn("targettarget", "oUF_TargetTarget")
targettarget:SetPoint("LEFT", UIParent, "CENTER", 20, -200)
