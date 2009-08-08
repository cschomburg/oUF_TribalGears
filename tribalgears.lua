--[[
	oUF_TribalGears
		with inbuild Fortitude Indicators
]]

local mainTex = [[Interface\AddOns\oUF_TribalGears\textures\TribalFalconSmooth]]
local leftTex = [[Interface\AddOns\oUF_TribalGears\textures\TribalFalconLeft]]
local rightTex = [[Interface\AddOns\oUF_TribalGears\textures\TribalFalconRight]]
local bgTex = [[Interface\AddOns\oUF_TribalGears\textures\splat]]
local highlightTex = [[Interface\AddOns\oUF_TribalGears\textures\mouseover]]

local backdrop = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = true, tileSize = 16,
	insets = {left = -2, right = -2, top = -2, bottom = -2},
}

-- 	o%	red <-- orange <-- dark gray <-- almost black	100%
local hpGradient = {1,0,0, 1,.5,0, .3,.3,.3, .15,.15,.15}

-- The unit menu
local menu = function(self)
	local unit = self.unit:sub(1, -2)
	local cunit = self.unit:gsub("(.)", string.upper, 1)

	if(unit == "party" or unit == "partypet") then
		ToggleDropDownMenu(1, nil, _G["PartyMemberFrame"..self.id.."DropDown"], "cursor", 0, 0)
	elseif(_G[cunit.."FrameDropDown"]) then
		ToggleDropDownMenu(1, nil, _G[cunit.."FrameDropDown"], "cursor", 0, 0)
	end
end

local classification = {
	worldboss = 'b',
	rareelite = 'r+',
	elite = '+',
	rare = 'r',
	normal = '',
	trivial = 't',
}

-- Updating name and level
local updateName = function(self, event, unit)
	if(self.Castbar) then
		local _, class = UnitClass(unit)
		if(class) then
			self.Castbar:SetStatusBarColor(unpack(oUF.colors.class[class]))
		else
			self.Castbar:SetStatusBarColor(1, 1, 1)
		end
	end

	if(not self.Name) then return end

	if(UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) or not UnitIsConnected(unit)) then
		self.Name:SetTextColor(.5, .5, .5)
	elseif UnitIsEnemy("player",unit) then
		self.Name:SetTextColor(1, 0, 0)
	else
		self.Name:SetTextColor(1, 1, 1)
	end
    local name = UnitName(unit)
    if(unit ~= "target") then return self.Name:SetText(name) end
	
    local lvl = UnitLevel(unit)
	self.Name:SetFormattedText(
		"%s |cffee8800%s%s|r",
		name,
		lvl,
		classification[UnitClassification(unit)]
	)
end

local siValue = function(value) 
	if(value < 1e3) then
		return value
	elseif(value < 1e6) then
		return ("%.1fk"):format(value/1e3)
	else
		return ("%.1fm"):format(value/1e6)
	end
end

-- Update health
local PostUpdateHealth = function(self, event, unit, bar, min, max)
	local c = max - min
	local p = (min/max)*100

	if(UnitIsDead(unit)) then
		bar:SetValue(0)
		bar.value:SetText"[d]"
	elseif(UnitIsGhost(unit)) then
		bar:SetValue(0)
		bar.value:SetText"[gh]"
	elseif(not UnitIsConnected(unit)) then
		bar.value:SetText"[off]"
	elseif(UnitCanAttack("player", unit)) then
		bar.value:SetText(siValue(min))
	elseif(self:GetParent():GetName():sub(1, 8) == "oUF_Raid" or unit == "targettargettarget") then
		bar.value:SetText(c > 0 and ("-"..siValue(c)) or "")
	else
		bar.value:SetText(c > 0 and ("-"..c) or siValue(max))
	end

	updateName(self, event, unit)
end

-- And update power
local PostUpdatePower = function(self, event, unit, bar, min, max)
	if((min == 0 or not UnitIsConnected(unit)) and bar.value) then
		bar.value:SetText()
	elseif(UnitIsDead(unit) or UnitIsGhost(unit)) then
		bar:SetValue(0)
	elseif(bar.value) then
		bar.value:SetText(siValue(min))
	end
end

-- Fortitude Indicator
local PostUpdateAura = function(self, event, unit)
	if(not self.Fortitude) then return nil end

	if(UnitAura(unit, "Power Word: Fortitude") or UnitAura(unit, "Prayer of Fortitude")) then
		self.Fortitude:Hide()
	else
		self.Fortitude:Show()
	end
end

local CastBarText = function(self, duration)
	self.Time:SetFormattedText("%.1f", self.channeling and duration or (self.max - duration))
end

local fish1, fish2, fish3
local PostCastStart = function(self, event, unit, name, rank, text, castid)
	if(name == "Fishing") then
		fish1:Show()
		fish2:Show()
		fish3:Show()
	else
		fish1:Hide()
		fish2:Hide()
		fish3:Hide()
	end
end

-- Main layout func
local func = function(settings, self, unit)
	self.numBuffs = 36
	self.menu = menu

	self:EnableMouse(true)

	self:SetHeight(settings['initial-height'] or 30)
	self:SetWidth(settings['initial-width'] or 230)

	if(self:GetParent():GetName():sub(1, 8) == "oUF_Raid") then
		self:SetScript("OnEnter", function() self.Name:Show() end)
		self:SetScript("OnLeave", function() self.Name:Hide() end)
	else
		self:SetScript("OnEnter", UnitFrame_OnEnter)
		self:SetScript("OnLeave", UnitFrame_OnLeave)
	end

	self:RegisterForClicks"anyup"
	self:SetAttribute("*type2", "menu")

	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0, 0, 0, 1)
	
	-- Background grunge effect
	if(unit == "player" or unit=="target") then
		self.bg = self:CreateTexture(nil, "BACKGROUND")
		self.bg:SetWidth(150)
		self.bg:SetHeight(80)
		self.bg:SetTexture(bgTex)
		if(unit == "player") then
			self.bg:SetPoint("TOPLEFT", -38, 24)
		else
			self.bg:SetPoint("TOPRIGHT", 38, 24)
			self.bg:SetTexCoord(1, 0, 0, 1)
		end
	end
	
	-- Castbars for player and target
	if(unit == "player" or unit == "target") then
		local cast = CreateFrame"StatusBar"
		cast:SetParent(UIParent)
		cast:SetStatusBarTexture(mainTex)
		cast:SetHeight(20)
		cast:SetWidth(320)

		local icon = cast:CreateTexture(nil, "OVERLAY")
		icon:SetWidth(cast:GetHeight())
		icon:SetHeight(cast:GetHeight())
		icon:SetPoint("RIGHT", cast, "LEFT", -2, 0)
		
		local time = cast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		time:SetTextColor(1,1,1)
		time:SetShadowOffset(1, -1)
		time:SetPoint("RIGHT")

		local text = cast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetTextColor(1,1,1)
		text:SetPoint("LEFT")
		text:SetPoint("RIGHT", time, "LEFT", -2)
		text:SetJustifyH("LEFT")
		text:SetShadowOffset(1, -1)
		
		local bg = cast:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture(0,0,0,.5)
		bg:SetPoint("BOTTOMRIGHT", 2, -2)
		bg:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
		
		cast:SetPoint("BOTTOM", 0, unit == "player" and 170 or 194)

		cast.Time = time
		cast.Text = text
		cast.CustomTimeText = CastBarText
		cast.Icon = icon
		self.Castbar = cast

		if(unit == "player") then
			fish1 = cast:CreateTexture(nil, "OVERLAY")
			fish1:SetWidth(3)
			fish1:SetHeight(8)
			fish1:SetTexture(0.8, 0.5, 0)
			fish1:SetPoint("BOTTOM", cast, "TOPRIGHT", -4/17*320, 0)

			fish2 = cast:CreateTexture(nil, "OVERLAY")
			fish2:SetWidth(3)
			fish2:SetHeight(8)
			fish2:SetTexture(0.8, 0.5, 0)
			fish2:SetPoint("BOTTOM", cast, "TOPRIGHT", -9/17*320, 0)

			fish3 = cast:CreateTexture(nil, "OVERLAY")
			fish3:SetWidth(3)
			fish3:SetHeight(8)
			fish3:SetTexture(0.8, 0.5, 0)
			fish3:SetPoint("BOTTOM", cast, "TOPRIGHT", -14/17*320, 0)

			self.PostCastStart = PostCastStart
			self.PostChannelStart = PostCastStart
		end
	end

	-- Health bars and text
	local hp = CreateFrame("StatusBar", nil, self)
	hp:SetHeight(settings["hp-height"] or 22)
	hp:SetStatusBarTexture(mainTex)
	hp.smoothGradient = hpGradient
	hp.colorTapping = true
	hp.colorSmooth = true

	--hp:SetFrameLevel(2)
	hp:SetPoint"TOPLEFT"
	hp:SetPoint"TOPRIGHT"

	self.Health = hp
	self.PostUpdateHealth = PostUpdateHealth

	local hpp = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hpp:SetPoint("RIGHT", -2, -1)
	hpp:SetTextColor(1, 1, 1)

	hp.value = hpp

	-- Power bars and text
	local pp = CreateFrame"StatusBar"
	pp:SetHeight(settings["pp-height"] or 7)
	pp:SetStatusBarTexture(mainTex)
	pp:SetStatusBarColor(.25, .25, .35)
	

	pp:SetParent(self)
	pp:SetFrameLevel(3)
	pp:SetPoint"BOTTOMLEFT"
	pp:SetPoint"BOTTOMRIGHT"
	pp:SetPoint("TOP", hp, "BOTTOM", 0, -1.35)

	pp.colorTapping = true
	pp.colorClass = true
	pp.colorHappiness = true
	pp.colorReaction = true
	
	self.Power = pp
	self.PostUpdatePower = PostUpdatePower

	if(unit == "player") then
		local ppp = pp:CreateFontString(nil, "OVERLAY")
		ppp:SetJustifyH"LEFT"
		ppp:SetFontObject(GameFontNormalSmall)
		ppp:SetTextColor(1, 1, 1)

		ppp:SetPoint("LEFT", hp, "LEFT", 2, -1)
		ppp:SetJustifyH"LEFT"
	
		pp.value = ppp
	end

	-- Name, Leader, Icon
	if(unit ~= "player" and unit ~= "pet") then
		local name = hp:CreateFontString(nil, "OVERLAY")
		name:SetPoint("LEFT", hp, 2, -1)
		name:SetPoint("RIGHT", hpp, "LEFT")
		name:SetJustifyH"LEFT"
		name:SetFontObject(GameFontNormalSmall)
		name:SetTextColor(1, 1, 1)
		self.Name = name
	end

	local leader = hp:CreateTexture(nil, "OVERLAY")
	leader:SetTexture"Interface\\GROUPFRAME\\UI-Group-LeaderIcon"
	leader:SetWidth(16)
	leader:SetHeight(16)
	leader:SetPoint("TOPLEFT", hp, 0, 8)
	self.Leader = leader

	local ricon = hp:CreateTexture(nil, "OVERLAY")
	ricon:SetTexture"Interface\\TargetingFrame\\UI-RaidTargetingIcons"
	ricon:SetWidth(18)
	ricon:SetHeight(18)
	ricon:SetPoint("TOP", hp, 0, 8)
	self.RaidIcon = ricon

	
	-- Buffs for party
	if(self:GetParent():GetName()=="oUF_Party") then
		local debuffs = CreateFrame("Frame", nil, self)
		debuffs.num = 6
		debuffs:SetHeight(self:GetHeight())
		debuffs:SetWidth(debuffs.num*self:GetHeight())
		debuffs:SetPoint("TOPLEFT", self, "TOPRIGHT", 4, .5)
        debuffs.size = math.floor(debuffs:GetHeight() + .5)
		self.Debuffs = debuffs
	end

	-- Tiny concept for raid
	if(self:GetParent():GetName():sub(1, 8) == "oUF_Raid") then

		self.Range = true
		self.inRangeAlpha = 1
		self.outsideRangeAlpha = .1
		self.Name:Hide()
		
		-- For the Fortitude-indicator-update
		local buffs = CreateFrame("Frame", nil, self)
		buffs.num = 0
		self.Buffs = buffs

		local fortitude = hp:CreateTexture(nil, "OVERLAY")
		fortitude:SetParent(hp)
		fortitude:SetPoint("TOPLEFT", hp, "TOPLEFT", 0 , 0)
		fortitude:SetHeight(3.25)
		fortitude:SetWidth(3.35)
		fortitude:SetTexture(155/255,146/255,246/255)
		fortitude:Hide()
		self.Fortitude = fortitude
		self.PostUpdateAura = PostUpdateAura
	end
	
	-- Pet gets debuffs
	if(unit == "pet") then
		self.numDebuffs = 6

		local debuffs = CreateFrame("Frame", nil, self)
		debuffs.num = 10
		debuffs:SetHeight(self:GetHeight())
		debuffs:SetWidth(debuffs.num*debuffs:GetHeight())
		debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
		debuffs.size = math.floor(debuffs:GetHeight() + .5) 
		self.Debuffs = debuffs
	end

	-- Custom player frame
	if(unit == "player") then
		pp:SetHeight(128)
		pp:SetStatusBarTexture(leftTex)
		pp:ClearAllPoints()
		pp:SetPoint("LEFT", self, "BOTTOMLEFT", 0, 4)
		pp:SetPoint("RIGHT", self, "BOTTOMRIGHT", 0, 4)
	end
	
	-- Custom target frame
	if(unit == "target") then
		self.numDebuffs = 20
	
		local debuffs = CreateFrame("Frame", nil, self)
		debuffs.size = 32
		debuffs:SetHeight(debuffs.size)
		debuffs:SetWidth(self:GetWidth())
		debuffs:SetPoint("TOPLEFT", self, "BOTTOMLEFT", -4.5, -4)
		debuffs.num = math.floor(self:GetWidth() / debuffs.size + .5)
		self.Debuffs = debuffs
		
		pp:SetHeight(128)
		pp:SetStatusBarTexture(rightTex)
		pp:ClearAllPoints()
		pp:SetPoint("LEFT", self, "BOTTOMLEFT", 0, 4)
		pp:SetPoint("RIGHT", self, "BOTTOMRIGHT", 0, 4)
		
		local buffs = CreateFrame("Frame", nil, self)
		buffs.num = 20
		buffs.size = self:GetHeight()/2
		buffs:SetHeight(self:GetHeight())
		buffs:SetWidth(buffs.num/2*buffs.size+.5)
		buffs:SetPoint("TOPLEFT", self, "TOPRIGHT", 1, -2)
		self.Buffs = buffs

		local cpoints = self:CreateFontString(nil, "OVERLAY")
		cpoints:SetPoint("RIGHT", self, "LEFT", -9, 1)
		cpoints:SetFont(DAMAGE_TEXT_FONT, 38)
		cpoints:SetTextColor(1, 1, 1)
		cpoints:SetJustifyH"RIGHT"
		self.CPoints = cpoints

		local name = self.Name
		name:ClearAllPoints()
		name:SetPoint("BOTTOM", self, "TOPLEFT", -5, 20)
		name:SetFont("Fonts\\FRIZQT__.TTF", 16)
		
		hpp:ClearAllPoints()
		hpp:SetPoint("LEFT", 2, -1)
	end
    
	-- Debuffs for focus
    if(unit == "focus") then
		self.numDebuffs = 1

		local debuffs = CreateFrame("Frame", nil, self)
		debuffs.num = 10
		debuffs:SetHeight(self:GetHeight())
		debuffs:SetWidth(debuffs.num*debuffs:GetHeight())
		debuffs:SetPoint("TOPLEFT", self, "TOPRIGHT", 4, .5)
		debuffs.size = math.floor(debuffs:GetHeight() + .5) 
		self.Debuffs = debuffs
    end
    
    return self
end

oUF:RegisterStyle("TribalGears", setmetatable({
	["initial-width"] = 230,
	["initial-height"] = 30,
}, {__call = func}))
oUF:RegisterStyle("TribalGears - small", setmetatable({
	["initial-width"] = 120,
	["initial-height"] = 18,
	["hp-height"] = 15,
	["pp-height"] = 1,
}, {__call = func}))
oUF:RegisterStyle("TribalGears - tiny", setmetatable({
	["initial-width"] = 60,
	["initial-height"] = 22,
	["hp-height"] = 19,
	["pp-height"] = 2,
}, {__call = func}))

oUF:SetActiveStyle"TribalGears"
	oUF:Spawn("player", "oUF_Player"):SetPoint("CENTER", -120, -440)
	oUF:Spawn("target", "oUF_Target"):SetPoint("CENTER", 120, -440)
	local party = oUF:Spawn("header", "oUF_Party")
	party:SetManyAttributes('yOffset', -5, 'showParty', true)
	party:SetPoint("TOPLEFT", 15, -150)

oUF:SetActiveStyle"TribalGears - small"
	oUF:Spawn("targettarget", "oUF_ToT"):SetPoint("BOTTOMRIGHT", oUF.units.target, "TOPRIGHT", 100, 7)
	oUF:Spawn("targettargettarget", "oUF_ToToT"):SetPoint("BOTTOMLEFT", oUF.units.targettarget, "BOTTOMRIGHT", 7, 0)
	oUF:Spawn("pet", "oUF_Pet"):SetPoint("TOPLEFT", oUF.units.player, "BOTTOMLEFT", -100, -7)
	oUF:Spawn("focus", "oUF_Focus"):SetPoint("BOTTOMLEFT", oUF.units.player, "TOPLEFT", -100, 7)

oUF:SetActiveStyle"TribalGears - tiny"
for i=1, 8 do
	local raid = oUF:Spawn("header", "oUF_Raid"..i)
	raid:SetManyAttributes("showRaid", true, "yOffset", -5, "groupFilter", i)
	raid:SetPoint("TOPLEFT", 15+65*(i-1), -15)
end

local temptoggle = CreateFrame"Frame"
temptoggle:SetScript("OnEvent", function(self)
	if(InCombatLockdown()) then
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
	else
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		if(GetNumRaidMembers() > 5) then
			party:Hide()
			for i=1, 8 do
				_G['oUF_Raid'..i]:Show()
			end
		else
			party:Show()
			for i=1, 8 do
				_G['oUF_Raid'..i]:Hide()
			end
		end
	end
end)
temptoggle:RegisterEvent"PARTY_MEMBERS_CHANGED"
temptoggle:RegisterEvent"PARTY_LEADER_CHANGED"
temptoggle:RegisterEvent"RAID_ROSTER_UPDATE"
temptoggle:RegisterEvent"PLAYER_LOGIN"