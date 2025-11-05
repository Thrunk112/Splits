--TODO:
--dungeons
--strat live vs dead, dire maul, etc
--font and size ui adjustment?
local RaidTimer = CreateFrame("Frame", "RaidTimerFrame", UIParent)
RaidTimer:RegisterEvent("PLAYER_REGEN_DISABLED")
RaidTimer:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
RaidTimer:RegisterEvent("CHAT_MSG_MONSTER_YELL")
RaidTimer:RegisterEvent("ZONE_CHANGED_NEW_AREA")
RaidTimer:RegisterEvent("PLAYER_ENTERING_WORLD")
RaidTimer:RegisterEvent("ADDON_LOADED")

-- Boss tables
local raidBosses = {
    ["Molten Core"] = { "Incindis", "Lucifron", "Magmadar", "Garr", "Baron Geddon", "Basalthar", "Sorcerer-Thane Thaurissan",
        "Shazzrah", "Sulfuron Harbinger", "Golemagg the Incinerator",
        "Majordomo Executus", "Ragnaros" },
    ["Blackwing Lair"] = { "Razorgore the Untamed", "Vaelastrasz the Corrupt",
        "Broodlord Lashlayer", "Firemaw", "Ebonroc", "Flamegor", "Chromaggus", "Nefarian" },
	["Zul'Gurub"] = { "High Priestess Jeklik", "High Priest Venoxis",
        "High Priestess Mar'li", "Bloodlord Mandokir",
        "Jin'do the Hexxer", "Hakkar", "High Priestess Arlokk", "High Priest Thekal" },  
    ["Tower of Karazhan"] = { "Keeper Gnarlmoon", "Ley-Watcher Incantagos",
        "Anomalus", "Echo of Medivh", "King", "Sanv Tas'dal",
        "Rupturan the Broken", "Kruul", "Mephistroth" },
    ["Ahn'Qiraj"] = {
        "The Prophet Skeram", "Bug Trio", "Battleguard Sartura", "Fankriss the Unyielding",
        "Viscidus", "Princess Huhuran", "Emperor Vek'lor", "Ouro", "C'Thun"
    },
    ["Ruins of Ahn'Qiraj"] = {
        "Kurinnaxx", "General Rajaxx", "Moam", "Buru the Gorger", "Ayamiss the Hunter", "Ossirian the Unscarred"
    },
    ["Naxxramas"] = {
        "Anub'Rekhan", "Grand Widow Faerlina", "Maexxna",  "Patchwerk", "Grobbulus", "Gluth",
        "Thaddius", "Instructor Razuvious", "Gothik the Harvester",
        "The Four Horsemen", "Noth the Plaguebringer", "Heigan the Unclean",
        "Loatheb", "Sapphiron", "Kel'Thuzad"
    },
	["Lower Karazhan"] = {
        "Moroes", "Clawlord Howlfang", "Lord Blackwald II", "Grizikil", "Brood Queen Araxxna"
    },
}

local multiBossesByRaid = {
    ["Naxxramas"] = {
        ["The Four Horsemen"] = { "Thane Korth'azz", "Lady Blaumeux", "Highlord Mograine", "Sir Zeliek" }
    },
    ["Ahn'Qiraj"] = {
        ["Bug Trio"] = { "Lord Kri", "Princess Yauj", "Vem" }
    },
}

local bossDisplayNames = { --maybe can cut this out or make it an option. 
	--AQ20
    ["Ossirian the Unscarred"]  = "Ossirian",
	--MC
	["Sulfuron Harbinger"]      = "Sulfuron",
    ["Golemagg the Incinerator"] = "Golemagg",
    ["Majordomo Executus"]      = "Majordomo",
	["Basalthar"] 				= "Twin Giants",
	["Sorcerer-Thane Thaurissan"] = "Sorcerer",
	--BWL
    ["Razorgore the Untamed"]   = "Razorgore",
    ["Vaelastrasz the Corrupt"] = "Vael",
    ["Broodlord Lashlayer"]     = "Broodlord",
	--AQ40
	["Battleguard Sartura"]     = "Sartura",
    ["Fankriss the Unyielding"] = "Fankriss",
	["Emperor Vek'lor"]			= "Twin Emps",
	--Naxx
    ["Grand Widow Faerlina"]  = "Faerlina",
	["Heigan the Unclean"]      = "Heigan",
    ["Gothik the Harvester"]    = "Gothik",
    ["Noth the Plaguebringer"]  = "Noth",
	--K40
	["King"] = "Chess",
}

local activeRaid = nil
local InRaidZone = false
local timerRunning = false
local startTime = nil
local killedBosses = {}
local splits = {}
local splitTexts = {} 
local isLocked = true
local runFinished = false

local TimerFrame = CreateFrame("Frame", "RaidTimerDisplay", UIParent)
TimerFrame:SetWidth(220)
TimerFrame:SetHeight(20)

TimerFrame.bg = TimerFrame:CreateTexture(nil, "BACKGROUND")
TimerFrame.bg:SetAllPoints(true)
TimerFrame.bg:SetTexture(0, 0, 0, 0)


local function InitOptions()
	if not SplitsOptions then
		SplitsOptions = { position = { x = -600, y = -100 }, rows = 4, compareSplits = false, showRecord = true, hide = false }
	end
	if SplitsOptions.position then
		local ux, uy = UIParent:GetCenter()
		TimerFrame:ClearAllPoints()
		TimerFrame:SetPoint("CENTER", UIParent, "CENTER",
			SplitsOptions.position.x,
			SplitsOptions.position.y
		)
	end
	if not SplitsOptions.records then
		SplitsOptions.records = {} 
	end
	if SplitsOptions.hide then
        TimerFrame:Hide()
    else
        TimerFrame:Show()
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Splits|r Active.")
    end
	if SplitsOptions.rows then
		TimerFrame:SetHeight(20 + SplitsOptions.rows *18)
	else
		TimerFrame:SetHeight(20 + 4 *18)
	end
end


local TimerText = TimerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
TimerText:SetPoint("TOP", TimerFrame, "TOP", -20, -6)
TimerText:SetWidth(100)
TimerText:SetText("")

local RecordText = TimerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
RecordText:SetPoint("BOTTOM", TimerText, "TOP", 0, 0)
RecordText:SetWidth(200)
RecordText:SetText("")

local function EnableDrag()
    TimerFrame:SetMovable(true)
    TimerFrame:EnableMouse(true)
    TimerFrame:RegisterForDrag("LeftButton")
    TimerFrame:SetScript("OnDragStart", function(self)
        this:StartMoving()
    end)
    TimerFrame:SetScript("OnDragStop", function(self)
        this:StopMovingOrSizing()
        local x, y = this:GetCenter()
        local ux, uy = UIParent:GetCenter()
        SplitsOptions.position.x = math.floor(x - ux + 0.5)
        SplitsOptions.position.y = math.floor(y - uy + 0.5)
    end)
end

local function DisableDrag()
    TimerFrame:SetMovable(false)
    TimerFrame:EnableMouse(false)
    TimerFrame:SetScript("OnDragStart", nil)
    TimerFrame:SetScript("OnDragStop", nil)
end

local function ToggleLock()
    if isLocked then
        EnableDrag()
        TimerFrame.bg:SetTexture(0,0,0,0.65)
        isLocked = false
        DEFAULT_CHAT_FRAME:AddMessage("[Splits] Unlocked. Drag to reposition.")
    else
        DisableDrag()
        TimerFrame.bg:SetTexture(0,0,0,0)
        isLocked = true
        DEFAULT_CHAT_FRAME:AddMessage("[Splits] Locked.")
    end
end

local function AddSplitLine(text)
    local fs = TimerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    fs:SetPoint("TOPLEFT", TimerText, "BOTTOMLEFT", -20, -6)

    for i = 1, table.getn(splitTexts) do
        local prev = splitTexts[i]
        local _, _, _, x, y = prev:GetPoint(1)
        prev:ClearAllPoints()
        prev:SetPoint("TOPLEFT", TimerText, "BOTTOMLEFT", x, y - 14)
    end

    table.insert(splitTexts, 1, fs)

    while table.getn(splitTexts) > SplitsOptions.rows do
        local old = table.remove(splitTexts)
        if old and old.SetText then old:SetText("") end
    end
end

local function InActiveRaidZone()
	if timerRunning or runFinished then return end
    local zone = GetRealZoneText()
	if zone == "Tower of Karazhan" then
		local raidCount = GetNumRaidMembers()
		if raidCount and raidCount < 11 then
			zone = "Lower Karazhan"
		end
    end
    if zone and raidBosses[zone] then 
		InRaidZone = true
		return zone 
	end
    return nil
end

local function IsBossInActiveRaid(name)
    if not activeRaid then return false end
    local list = raidBosses[activeRaid]
    if not list then return false end
    for i = 1, table.getn(list) do
        if list[i] == name then return true end
    end
    local raidMulti = multiBossesByRaid[activeRaid]
    if raidMulti then
        for groupName, members in pairs(raidMulti) do
            for _, m in ipairs(members) do
                if m == name then return true end
            end
        end
    end
    return false
end

local function FormatTime(secondsTotal)
    local h = math.floor(secondsTotal / 3600)
    local m = math.floor(math.mod(secondsTotal, 3600) / 60)
    local s = math.floor(math.mod(secondsTotal, 60))
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%02d:%02d", m, s)
    end
end

local function UpdateRecordDisplay()
    if SplitsOptions.showRecord and activeRaid and SplitsOptions.records[activeRaid] and SplitsOptions.records[activeRaid].bestTime then
        local bestTime = SplitsOptions.records[activeRaid].bestTime
        RecordText:SetText("Record: " .. FormatTime(bestTime))
    else
        RecordText:SetText("")
    end
end

local function StartTimerIfInRaid()
    if timerRunning or runFinished then return end
    local zone = InActiveRaidZone()
    if not zone then return end
    activeRaid = zone
    timerRunning = true
    startTime = GetTime()
    killedBosses = {}
    splits = {}
	UpdateRecordDisplay()
    TimerText:SetText("00:00")
end

local function PauseTimer()
    timerRunning = false
end

local function ResetTimer()
    timerRunning = false
    runFinished = false
    startTime = nil
    activeRaid = nil
    killedBosses = {}
    splits = {}
    for i = 1, table.getn(splitTexts) do
        if splitTexts[i] and splitTexts[i].SetText then
            splitTexts[i]:SetText("")
        end
    end
    splitTexts = {}
    TimerText:SetText("")  
	RecordText:SetText("")
    DEFAULT_CHAT_FRAME:AddMessage("[Splits] Reset.")
end

local function AddSplit(bossName)
    if not timerRunning or not activeRaid then return end
    if killedBosses[bossName] then return end
    -- Check multi-boss groups for this raid
    local raidMulti = multiBossesByRaid[activeRaid]
    if raidMulti then
        for groupName, members in pairs(raidMulti) do
            for _, m in ipairs(members) do
                if m == bossName then
                    killedBosses[bossName] = true
                    local allDead = true
                    for _, sub in ipairs(members) do
                        if not killedBosses[sub] then
                            allDead = false
                            break
                        end
                    end

                    if allDead then
                        bossName = groupName 
                    else
                        return 
                    end
                    break
                end
            end
        end
    end

    local elapsed = GetTime() - startTime
    killedBosses[bossName] = true
	local displayName = bossDisplayNames[bossName] or bossName
    --local splitText = FormatTime(elapsed) .. "  " .. displayName
	local splitText --Hacky way do do this, should split elapsed and display name frames but w/e
		if elapsed < 3600 then
			splitText = "   " .. FormatTime(elapsed) .. "  " .. displayName
		else
			splitText = FormatTime(elapsed) .. "  " .. displayName
		end

    if SplitsOptions.compareSplits then
        local recordSplits = SplitsOptions.records[activeRaid] and SplitsOptions.records[activeRaid].splits
        if recordSplits then
            for _, rec in ipairs(recordSplits) do
                if rec.boss == bossName then
                    local diff = elapsed - rec.time
                    local color = diff < 0 and "00ff00" or "ff0000"  -- green if ahead, red if behind
                    local sign = diff < 0 and "-" or "+"
                    splitText = string.format("%s (|cff%s%s%s|r)", splitText, color, sign, FormatTime(math.abs(diff)))
                    break
                end
            end
        end
    end

    splits[table.getn(splits) + 1] = { boss = bossName, time = elapsed }
    AddSplitLine(splitText)

	local allDown = true
	local list = raidBosses[activeRaid]
	local raidMulti = multiBossesByRaid[activeRaid] or {}

	for i = 1, table.getn(list) do
		local name = list[i]
		for groupName, members in pairs(raidMulti) do
			for _, m in ipairs(members) do
				if name == m then
					name = nil
					break
				end
			end
			if not name then break end
		end

		if name and not killedBosses[list[i]] then
			allDown = false
			break
		end
	end

    if allDown then
        local totalTime = GetTime() - startTime
        PauseTimer()
        runFinished = true
        SplitsOptions.records[activeRaid] = SplitsOptions.records[activeRaid] or {}
        local prevBest = SplitsOptions.records[activeRaid].bestTime
        if not prevBest or totalTime < prevBest then
            SplitsOptions.records[activeRaid].bestTime = totalTime
            SplitsOptions.records[activeRaid].splits = {}
            for i, v in ipairs(splits) do
                SplitsOptions.records[activeRaid].splits[i] = { boss = v.boss, time = v.time }
            end
            DEFAULT_CHAT_FRAME:AddMessage("[Splits] New record! Splits Updated.")
        end
    end
end

local function RefreshSplitsDisplay()
    for i, fs in ipairs(splitTexts) do
        if fs.SetText then fs:SetText("") end
    end
    splitTexts = {}

    for i, v in ipairs(splits) do
        local elapsed = v.time
        local bossName = v.boss
		local displayName = bossDisplayNames[bossName] or bossName
		--local splitText = FormatTime(elapsed) .. "  " .. displayName
		local splitText
			if elapsed < 3600 then
				splitText = "   " .. FormatTime(elapsed) .. "  " .. displayName
			else
				splitText = FormatTime(elapsed) .. "  " .. displayName
			end

        if SplitsOptions.compareSplits then
            local recordSplits = SplitsOptions.records[activeRaid] and SplitsOptions.records[activeRaid].splits
            if recordSplits then
                for _, rec in ipairs(recordSplits) do
                    if rec.boss == bossName then
                        local diff = elapsed - rec.time
                        local color = diff < 0 and "00ff00" or "ff0000"
                        local sign = diff < 0 and "-" or "+"
                        splitText = string.format("%s (|cff%s%s%s|r)", splitText, color, sign, FormatTime(math.abs(diff)))
                        break
                    end
                end
            end
        end

        AddSplitLine(splitText)
    end
end

-- Options Menu
local OptionsFrame = CreateFrame("Frame", "RaidTimerOptionsFrame", UIParent)
OptionsFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
OptionsFrame:SetBackdropColor(0, 0, 0, 1)
OptionsFrame:SetWidth(170)
OptionsFrame:SetHeight(210)
OptionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0,0)
OptionsFrame:Hide()
OptionsFrame.entries = 0


OptionsFrame.title = OptionsFrame:CreateTexture(nil, "ARTWORK")
OptionsFrame.title:SetTexture(0, 0, 0, 0.6)    
OptionsFrame.title:SetHeight(20)
OptionsFrame.title:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", 2, -2)
OptionsFrame.title:SetPoint("TOPRIGHT", OptionsFrame, "TOPRIGHT", -2, -2)

OptionsFrame.caption = OptionsFrame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
OptionsFrame.caption:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
OptionsFrame.caption:SetText("|cffffcc00Splits|r Options")
OptionsFrame.caption:SetAllPoints(OptionsFrame.title)


OptionsFrame.btnClose = CreateFrame("Button", nil, OptionsFrame)
OptionsFrame.btnClose:SetHeight(16)
OptionsFrame.btnClose:SetWidth(16)
OptionsFrame.btnClose:SetPoint("RIGHT", OptionsFrame.title, "RIGHT", -4, 0)
OptionsFrame.btnClose:SetBackdrop(backdrop)
OptionsFrame.btnClose:SetBackdropColor(.2, .2, .2, 1)
OptionsFrame.btnClose:SetBackdropBorderColor(.4, .4, .4, 1)
OptionsFrame.btnClose.caption = OptionsFrame.btnClose:CreateFontString(nil, "OVERLAY", "GameFontWhite")
OptionsFrame.btnClose.caption:SetFont(STANDARD_TEXT_FONT, 14)
OptionsFrame.btnClose.caption:SetText("x")
OptionsFrame.btnClose.caption:SetAllPoints()

OptionsFrame.btnClose:SetScript("OnClick", function()
    OptionsFrame:Hide()
end)


local function CreateConfig(parent, label, ctype, getter, setter)
    parent.entries = parent.entries + 1
    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("TOPLEFT", 10, -parent.entries * 30)
    text:SetText(label)
    if ctype == "boolean" then
        local chk = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        chk:SetPoint("LEFT", text, "RIGHT", 10, -2)
        chk:SetChecked(getter())
        chk:SetScript("OnClick", function()
            setter(chk:GetChecked())
        end)
        return chk
	elseif ctype == "number" then
		local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
		box:SetAutoFocus(false)
		box:SetWidth(30)
		box:SetHeight(20)
		box:SetPoint("LEFT", text, "RIGHT", 10, 0)
		box:SetText(getter())

		box:SetScript("OnTextChanged", function()
			local currentText = this:GetText()
			if currentText == "" then
				return
			end
			if not string.find(currentText, "^[0-9]+$") then
				this:SetText(getter())
				return
			end
			local val = tonumber(currentText)
			if val then
				val = math.max(0, math.min(20, val)) 
				if val ~= getter() then
					setter(val)
					if tostring(val) ~= currentText then
						this:SetText(val)
					end
					RefreshSplitsDisplay()
				end
			end
		end) 

		box:SetScript("OnEscapePressed", function()
			box:SetText(getter())
			box:ClearFocus()
		end)
		box:SetScript("OnEnterPressed", function() 
		box:SetText(getter()) 
		box:ClearFocus()
		end)
		box:SetScript("OnShow", function()
			box:SetText(getter())
		end)
		return box
	end
end


local function BuildOptions()
	CreateConfig(OptionsFrame, "Lock Timer               ", "boolean",
		function() return isLocked end,
		function(val)
			if val ~= isLocked then
				ToggleLock()
			end
		end
	)

	CreateConfig(OptionsFrame, "Max Prev Splits      ", "number",
		function() return SplitsOptions.rows or 4 end,
		function(val) 
			SplitsOptions.rows = val 
			TimerFrame:SetHeight(20 + val *18)
			
		end
	)

	CreateConfig(OptionsFrame, "Show Time Saved   ", "boolean",
		function() return SplitsOptions.compareSplits end,
		function(val) SplitsOptions.compareSplits = val 
		RefreshSplitsDisplay()
		end
	)
	CreateConfig(OptionsFrame, "Show Record Time ", "boolean",
		function() return SplitsOptions.showRecord end,
		function(val)
			SplitsOptions.showRecord = val
			UpdateRecordDisplay()
		end
	)
	CreateConfig(OptionsFrame, "Hide/Disable Timer", "boolean",
		function() return SplitsOptions.hide end,
		function(val)
			SplitsOptions.hide = val
			if val then
				TimerFrame:Hide()
				ResetTimer()
				DEFAULT_CHAT_FRAME:AddMessage("[Splits] Disabled.")
			else
				TimerFrame:Show()
				DEFAULT_CHAT_FRAME:AddMessage("[Splits] Enabled.")
			end
		end
	)
end

local resetBtn = CreateFrame("Button", nil, OptionsFrame, "UIPanelButtonTemplate")
resetBtn:SetWidth(100)
resetBtn:SetHeight(20)
resetBtn:SetPoint("BOTTOM", 0, 10)
resetBtn:SetText("Reset Timer")
resetBtn:SetScript("OnClick", function()
    ResetTimer()
end)

OptionsFrame:SetMovable(true)
OptionsFrame:EnableMouse(true)
OptionsFrame:RegisterForDrag("LeftButton")
OptionsFrame:SetScript("OnDragStart", function(self) this:StartMoving() end)
OptionsFrame:SetScript("OnDragStop", function(self) this:StopMovingOrSizing() end)


RaidTimer:SetScript("OnEvent", function()
	if event == "ADDON_LOADED" and arg1 == "Splits" then
		InitOptions()
		BuildOptions()
	elseif SplitsOptions.hide then 
		return
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        InActiveRaidZone()
	elseif event == "PLAYER_REGEN_DISABLED" and InRaidZone then
        StartTimerIfInRaid()
    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" and arg1 then
        local mob = string.match(arg1, "^(.-) dies")
        if mob and IsBossInActiveRaid(mob) then
            AddSplit(mob)
        end
    elseif event == "CHAT_MSG_MONSTER_YELL" and activeRaid == "Molten Core" and arg1 then
        if string.find(arg1, "Impossible! Stay your attack, mortals") then
            AddSplit("Majordomo Executus")
        end
    end
end)


local lastUpdate = 0
RaidTimer:SetScript("OnUpdate", function()
    if not timerRunning or not startTime then return end
    local now = GetTime()
    local elapsed = now - (RaidTimer._lastUpdateTime or startTime)
    RaidTimer._lastUpdateTime = now
    lastUpdate = lastUpdate + elapsed
    if lastUpdate >= .25 then --only update every 0.25s. should be ok
        TimerText:SetText(FormatTime(now - startTime))
        lastUpdate = 0
    end
end)

-- Slash command
SLASH_SPLITS1 = "/splits"
SlashCmdList["SPLITS"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "reset" then
        ResetTimer()
    elseif msg == "lock" then
        ToggleLock()
	elseif msg == "" or msg =='options' or msg=="opt" then
        if OptionsFrame:IsShown() then OptionsFrame:Hide() else OptionsFrame:Show() end
    end

end




