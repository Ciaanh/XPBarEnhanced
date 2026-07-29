-- XP Bar Enhanced - Stats Module
-- Consolidated from: StatsController.lua + StatsView.lua
-- Manages the stats window displaying level and session statistics

local Addon = XPBarEnhanced
local L = Addon.L or {}

local Stats = {}

--------------------------------------------------------------------------------
-- Dependencies
--------------------------------------------------------------------------------

local SessionService = Addon and Addon.Session
local TimeCalc = Addon and Addon.TimeCalculations
local XPCalc = Addon and Addon.XPCalculations

--------------------------------------------------------------------------------
-- Local caches & helpers
--------------------------------------------------------------------------------

local _G = _G
local UIParent = _G.UIParent
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local GetXPExhaustion = GetXPExhaustion
local time = time
local date = date
local tostring = tostring
local type = type
local math_max = math.max
local math_floor = math.floor
local string_format = string.format

local Utils = Addon and Addon.Utils or {}
Utils.ShortNumber = Utils.ShortNumber or function(v) return tostring(v) end
Utils.FormatDuration = Utils.FormatDuration or function(v) return tostring(v) end

-- Upvalue for the stats window frame (must not leak into _G)
local frame

---Format a number honoring the abbreviateNumbers option
local function FormatNumber(value)
    local abbreviate = true
    if Addon.Config and Addon.Config.GetOptionValue then
        abbreviate = Addon.Config:GetOptionValue("abbreviateNumbers") ~= false
    end
    local formatter = Addon.TextFormatter
    if formatter and formatter.FormatNumber then
        return formatter:FormatNumber(value, abbreviate)
    end
    return Utils.ShortNumber(value)
end

local function SetTextSafe(el, value)
    if el and el.SetText then
        el:SetText(value)
    end
end

--------------------------------------------------------------------------------
-- Frame Mixin (for XML-defined frame)
--------------------------------------------------------------------------------

local StatsFrameMixin = {}
-- Register the mixin under a namespaced table and expose the global
-- alias only for XML mixin resolution.
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}
Addon.UI.Mixins.StatsFrameMixin = StatsFrameMixin
_G.XPBarEnhancedStatsMixin = StatsFrameMixin

local modifierChecks = {
    SHIFT = function() return IsShiftKeyDown and IsShiftKeyDown() end,
    CTRL  = function() return IsControlKeyDown and IsControlKeyDown() end,
    ALT   = function() return IsAltKeyDown and IsAltKeyDown() end
}

local function isModifierRequirementMet(requirement)
    if not requirement then return true end

    if type(requirement) == "table" then
        for _, modifier in ipairs(requirement) do
            local check = modifierChecks[string.upper(modifier)]
            if not (check and check()) then
                return false
            end
        end
        return true
    end

    local check = modifierChecks[string.upper(requirement)]
    return check and check()
end

-- Begin: position storage + drag functions embedded into StatsFrameMixin
function StatsFrameMixin:InitPositionStorage(getter, setter, defaultsProvider)
    self._positionStoreGetter = getter
    self._positionStoreSetter = setter
    self._positionStoreDefaultsProvider = defaultsProvider
end

function StatsFrameMixin:GetOrCreatePositionStore()
    if not self.__posStore then
        local getter = self._positionStoreGetter
        if getter then
            self.__posStore = getter() or {}
        else
            self.__posStore = {}
        end
    end
    return self.__posStore
end

function StatsFrameMixin:GetPositionDefaults()
    if self._positionStoreDefaultsProvider then
        return self._positionStoreDefaultsProvider(self)
    end
    -- canonical default
    return {point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0, left = 0, top = 0}
end

function StatsFrameMixin:ApplyStoredPosition()
    local stored = self:GetOrCreatePositionStore() or {}
    local defaults = self:GetPositionDefaults() or {}

    -- Backwards compatibility: raw left/top pixels, only when no anchor data
    -- was saved (anchor data survives UI-scale/resolution changes, raw pixels
    -- do not).
    if stored.point == nil and stored.left ~= nil and stored.top ~= nil then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", stored.left, stored.top)
        return
    end

    local point = stored.point or defaults.point or "CENTER"
    local relativeName = stored.relativeTo or defaults.relativeTo or "UIParent"
    local relativePoint = stored.relativePoint or defaults.relativePoint or point
    local x = stored.x or defaults.x or 0
    local y = stored.y or defaults.y or 0

    local relative = _G[relativeName]
    if not relative or type(relative) ~= "table" then
        relative = UIParent
    end

    self:ClearAllPoints()
    self:SetPoint(point, relative, relativePoint, x, y)
end

function StatsFrameMixin:SaveStoredPosition()
    local store = self:GetOrCreatePositionStore()
    if not store then return end

    local point, relativeTo, relativePoint, x, y = self:GetPoint()
    local left = self.GetLeft and self:GetLeft() or nil
    local top  = self.GetTop and self:GetTop() or nil

    if not point then
        if left == nil or top == nil then return end
    end

    local defaults = self:GetPositionDefaults() or {}
    local toSave = {}

    if point then
        toSave.point = point
        toSave.relativeTo = relativeTo and relativeTo:GetName() or "UIParent"
        toSave.relativePoint = relativePoint
        toSave.x = x
        toSave.y = y
    else
        -- No anchor available; fall back to raw pixels
        toSave.left = left
        toSave.top = top
    end

    -- Clear storage when matching defaults
    if toSave.point and defaults.point and toSave.point == defaults.point and toSave.x == defaults.x and toSave.y == defaults.y then
        if self._positionStoreSetter then self._positionStoreSetter(nil) end
        self.__posStore = nil
        return
    end

    if self._positionStoreSetter then
        self._positionStoreSetter(toSave)
    end
    self.__posStore = toSave
end

function StatsFrameMixin:EnableDrag(options)
    options = options or {}
    local originalStart = options.onDragStart
    local originalStop = options.onDragStop

    options.onDragStart = function(frame, ...)
        if frame.SaveStoredPosition then
            frame._xpcWasDragging = true
        end
        if originalStart then
            originalStart(frame, ...)
        end
    end

    options.onDragStop = function(frame, ...)
        if originalStop then
            originalStop(frame, ...)
        end
        if frame._xpcWasDragging then
            frame._xpcWasDragging = nil
            frame:SaveStoredPosition()
        end
    end

    local button = options and options.button or "LeftButton"

    self:SetMovable(true)
    self:EnableMouse(true)

    if type(button) == "table" then
        self:RegisterForDrag(unpack(button))
    else
        self:RegisterForDrag(button)
    end

    self:SetScript("OnDragStart", function(self)
        if options.requireModifier and not isModifierRequirementMet(options.requireModifier) then
            self:StopMovingOrSizing()
            if options.onModifierFail then options.onModifierFail(self) end
            return
        end

        self.isDragging = true
        if options.onDragStart then options.onDragStart(self) end
        self:StartMoving()
    end)

    self:SetScript("OnDragStop", function(self)
        if not self.isDragging then return end

        self:StopMovingOrSizing()
        self.isDragging = nil
        if options.onDragStop then options.onDragStop(self) end
    end)

    -- Mark frame as draggable and store options for hints/tooltip usage
    self.isDraggable = true
    if options and options.requireModifier then
        self._xpbeDragModifier = options.requireModifier
    end
    self._xpbeDragButton = (options and options.button) or "LeftButton"
end
-- End: embedded position + drag behavior

---Apply localized text to the XML-defined FontStrings (page titles, row
---labels, window title). XML carries no hardcoded text= attributes.
function StatsFrameMixin:ApplyLocalizedLabels()
    SetTextSafe(self.TitleText, L["ADDON_NAME"])

    local leftPage = self.LeftPage
    if leftPage then
        SetTextSafe(leftPage.PageTitle, L["STATS_PAGE_CURRENT_LEVEL"])
        local content = leftPage.Content
        if content then
            SetTextSafe(content.CurrentLevelLabel, L["STATS_LABEL_LEVEL"])
            SetTextSafe(content.CurrentXPLabel, L["STATS_LABEL_CURRENT_XP"])
            SetTextSafe(content.MaxXPLabel, L["STATS_LABEL_MAX_XP"])
            SetTextSafe(content.ProgressLabel, L["STATS_LABEL_PROGRESS"])
            SetTextSafe(content.RemainingXPLabel, L["STATS_LABEL_XP_TO_LEVEL"])
            SetTextSafe(content.RestedXPLabel, L["STATS_LABEL_RESTED_XP"])
            SetTextSafe(content.QuestXPLabel, L["STATS_LABEL_QUEST_XP"])
            SetTextSafe(content.LevelTimeLabel, L["STATS_LABEL_TIME_ON_LEVEL"])
            SetTextSafe(content.TimeToLevelLabel, L["STATS_LABEL_EST_TIME_TO_LEVEL"])
        end
    end

    local rightPage = self.RightPage
    if rightPage then
        SetTextSafe(rightPage.PageTitle, L["STATS_PAGE_CURRENT_SESSION"])
        local content = rightPage.Content
        if content then
            SetTextSafe(content.SessionDurationLabel, L["STATS_LABEL_DURATION"])
            SetTextSafe(content.SessionStartLabel, L["STATS_LABEL_STARTED"])
            SetTextSafe(content.SessionXPLabel, L["STATS_LABEL_XP_GAINED"])
            SetTextSafe(content.LevelsGainedLabel, L["STATS_LABEL_LEVELS_GAINED"])
            SetTextSafe(content.XPPerHourLabel, L["STATS_LABEL_XP_PER_HOUR"])
        end
    end
end

function StatsFrameMixin:OnLoad()
    if self._xpbeInitialized then
        return
    end
    self._xpbeInitialized = true

    local statsFrame = self
    Stats:SetFrame(statsFrame)

    statsFrame:ApplyLocalizedLabels()

    statsFrame:SetClampedToScreen(true)

    -- Initialize local position storage + drag behavior
    statsFrame:InitPositionStorage(
        function()
            return Addon.db and Addon.db.statsPosition
        end,
        function(pos)
            if Addon.db then Addon.db.statsPosition = pos end
        end,
        function()
            return {
                point = "CENTER",
                relativeTo = "UIParent",
                relativePoint = "CENTER",
                x = 0,
                y = 0
            }
        end
    )

    -- Apply stored position and enable dragging
    statsFrame:ApplyStoredPosition()
    statsFrame:EnableDrag({button = "LeftButton"})

    -- Setup close button
    if statsFrame.CloseButton then
        statsFrame.CloseButton:SetScript("OnClick", function(btn)
            btn:GetParent():Hide()
        end)
    end

    -- Initial update
    Stats:Update()
end

function StatsFrameMixin:OnShow()
    Stats:Update()
end

function StatsFrameMixin:OnHide()
    -- Could add event unsubscribing here if needed
end

--------------------------------------------------------------------------------
-- Core Stats Module
--------------------------------------------------------------------------------

---Set the Stats frame instance used by the module
function Stats:SetFrame(newFrame)
    frame = newFrame
    self.frame = newFrame
end

---Return the currently registered Stats frame (or nil)
function Stats:GetFrame()
    if frame then
        return frame
    end

    local existing = _G["XPBarEnhancedStatsFrame"]
    if existing then
        self:SetFrame(existing)
        return existing
    end
end

function Stats:Initialize()
    local existing = _G["XPBarEnhancedStatsFrame"]
    if existing and existing.OnLoad and not existing._xpbeInitialized then
        existing:OnLoad()
    end
    if existing then
        self:SetFrame(existing)
        self:Update()
    end
    -- Subscribe to EventBus broadcasts, keeping in sync with game
    self:RegisterEventHandlers()
end

---True when the stats window exists and is visible; hidden windows skip
---refreshes entirely (OnShow runs a full update when it reopens).
local function isStatsWindowVisible()
    local statsFrame = Stats.frame
    return statsFrame and statsFrame.IsShown and statsFrame:IsShown() or false
end

function Stats:RegisterEventHandlers()
    if self._eventHandles then return end

    local bus = Addon.EventBus
    local names = Addon.EventNames
    if not (bus and bus.RegisterWithHandle and names) then return end

    local function onBroadcast()
        if isStatsWindowVisible() then
            Stats:Update()
        end
    end

    -- XPBAR_BROADCAST_UPDATE fires on XP updates, level ups and TIME_PLAYED_MSG
    -- (routed through core/EventRouter → Session); the quest cache events fire
    -- on quest log changes. No direct WoW event registration here.
    self._eventHandles = {
        bus:RegisterWithHandle(names.XPBAR_BROADCAST_UPDATE, "stats-window", onBroadcast),
        bus:RegisterWithHandle(names.QUESTS_CACHE_INVALIDATED, "stats-window", onBroadcast),
        bus:RegisterWithHandle(names.QUESTS_CACHE_REBUILT, "stats-window", onBroadcast),
    }
end

function Stats:ShutdownEventHandlers()
    if not self._eventHandles then return end
    for _, handle in ipairs(self._eventHandles) do
        if handle and handle.Unregister then
            handle.Unregister()
        end
    end
    self._eventHandles = nil
end

function Stats:Toggle()
    local statsFrame = self:GetFrame()
    if not statsFrame then return end

    if statsFrame:IsShown() then
        statsFrame:Hide()
    else
        self:Update()
        statsFrame:Show()
    end
end

function Stats:Update()
    local statsFrame = self:GetFrame()
    if not statsFrame then return end

    -- Update Left Page (Current Level Stats)
    self:UpdateLevelStats(statsFrame)

    -- Update Right Page (Session Stats)
    self:UpdateSessionStats(statsFrame)
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

-- Event handlers gate on visibility: hidden windows skip the recompute
-- (OnShow runs a full Update), and this avoids double work when a direct
-- caller and the EventBus broadcast both fire.
function Stats:OnXPUpdate() if isStatsWindowVisible() then self:Update() end end
function Stats:OnLevelUp() if isStatsWindowVisible() then self:Update() end end
function Stats:OnXPChanged() if isStatsWindowVisible() then self:UpdateLevelStats(self.frame) end end
function Stats:OnSessionUpdated() if isStatsWindowVisible() then self:UpdateSessionStats(self.frame) end end
function Stats:OnQuestXPUpdated() if isStatsWindowVisible() then self:UpdateLevelStats(self.frame) end end
function Stats:OnTimePlayed(totalTime, levelTime) if isStatsWindowVisible() then self:Update() end end

--------------------------------------------------------------------------------
-- Update Methods
--------------------------------------------------------------------------------

-- Update left page with current level statistics
function Stats:UpdateLevelStats(statsFrame)
    if not (statsFrame and statsFrame.LeftPage) then return end

    local leftPage = statsFrame.LeftPage
    local content = leftPage.Content
    if not content then return end

    -- Get current player stats
    local level = UnitLevel("player")
    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0
    local remainingXP = math_max(0, (maxXP - currentXP))
    local restedXP = GetXPExhaustion() or 0

    -- Calculate progress percentage
    local percent = (currentXP / math_max(maxXP, 1)) * 100

    -- Get session data for level time tracking
    local session = SessionService and SessionService.GetCurrent and SessionService:GetCurrent()

    local levelTime = session and session.realLevelTime or 0

    -- Calculate XP rate for THIS LEVEL (not just current session)
    local levelXPRate = 0 -- XP per second for this level
    if levelTime > 0 and currentXP > 0 then
        levelXPRate = (currentXP / levelTime)
    end

    -- Calculate time to next level based on current level's XP rate
    local timeToLevel = nil
    if levelXPRate > 0 and remainingXP > 0 then
        timeToLevel = remainingXP / levelXPRate -- in seconds
    end

    -- Update current level and XP values using safe setters
    SetTextSafe(content.CurrentLevelValue, tostring(level))
    SetTextSafe(content.CurrentXPValue, FormatNumber(currentXP))
    SetTextSafe(content.MaxXPValue, FormatNumber(maxXP))
    SetTextSafe(content.ProgressValue, string_format("%.1f%%", percent))
    SetTextSafe(content.RemainingXPValue, FormatNumber(remainingXP))

    if content.RestedXPValue then
        if restedXP > 0 then
            SetTextSafe(content.RestedXPValue, FormatNumber(restedXP))
        else
            SetTextSafe(content.RestedXPValue, L["TT_NONE"])
        end
    end

    -- Update quest XP
    if content.QuestXPValue then
        local totalQuestXP, completeQuestXP, incompleteQuestXP = self:GetQuestXP()

        if totalQuestXP and totalQuestXP > 0 then
            local questPercent = (totalQuestXP / math_max(maxXP, 1)) * 100
            SetTextSafe(content.QuestXPValue, string_format("%s (%.1f%%)", FormatNumber(totalQuestXP), questPercent))
        else
            SetTextSafe(content.QuestXPValue, L["TT_NONE"])
        end
    end

    -- Update time on this level
    if content.LevelTimeValue then
        if levelTime > 0 then
            SetTextSafe(content.LevelTimeValue, Utils.FormatDuration(levelTime))
        else
            SetTextSafe(content.LevelTimeValue, L["TT_NA"])
        end
    end

    -- Update time to next level
    if content.TimeToLevelValue then
        if timeToLevel and timeToLevel > 0 then
            SetTextSafe(content.TimeToLevelValue, Utils.FormatDuration(timeToLevel))
        else
            SetTextSafe(content.TimeToLevelValue, L["TT_NA"])
        end
    end
end

-- Update right page with session statistics
function Stats:UpdateSessionStats(statsFrame)
    if not (statsFrame and statsFrame.RightPage) then return end

    local rightPage = statsFrame.RightPage
    local content = rightPage.Content
    if not content then return end

    -- Get session data
    local session = SessionService and SessionService.GetCurrent and SessionService:GetCurrent()
    if not session then
        session = { sessionStart = time(), gainedXP = 0, realLevelTime = 0 }
    end

    -- Calculate session duration using TimeCalculations
    local sessionElapsed = TimeCalc and TimeCalc.SessionDuration(session.sessionStart) or (time() - (session.sessionStart or time()))
    local sessionXP = session.gainedXP or 0

    -- Calculate XP per hour using TimeCalculations
    local xpPerHour = TimeCalc and TimeCalc.CalculateXPPerHour(session.sessionStart, sessionXP) or 0

    -- Levels gained this session (tracked via PLAYER_LEVEL_UP)
    local levelsGained = session.levelsGained or 0

    -- Update session duration & start
    SetTextSafe(content.SessionDurationValue, Utils.FormatDuration(sessionElapsed))
    SetTextSafe(content.SessionStartValue, date("%H:%M", session.sessionStart or time()))
    SetTextSafe(content.SessionXPValue, FormatNumber(sessionXP))
    SetTextSafe(content.LevelsGainedValue, tostring(levelsGained))

    if content.XPPerHourValue then
        if xpPerHour > 0 then
            SetTextSafe(content.XPPerHourValue, FormatNumber(xpPerHour))
        else
            SetTextSafe(content.XPPerHourValue, L["TT_CALCULATING"])
        end
    end

    -- Session XP-rate chart + quest/other split
    self:RenderSessionChart(statsFrame, session)
end

--------------------------------------------------------------------------------
-- Session Chart
--------------------------------------------------------------------------------

local HISTOGRAM_BUCKETS = 12

---Acquire pooled texture #index from a frame's pool (creates on demand)
local function acquireBar(frame, index, layer, subLevel)
    frame._pool = frame._pool or {}
    local tex = frame._pool[index]
    if not tex then
        tex = frame:CreateTexture(nil, layer or "ARTWORK", nil, subLevel or 1)
        frame._pool[index] = tex
    end
    tex:Show()
    return tex
end

---Hide pooled textures from `fromIndex` onward
local function hidePoolFrom(frame, fromIndex)
    if not frame._pool then return end
    for i = fromIndex, #frame._pool do
        frame._pool[i]:Hide()
    end
end

local function colorOrDefault(key, dr, dg, db)
    if Addon.Colors and Addon.Colors.Get then
        local c = Addon.Colors:Get(key)
        if c then
            return c.r or dr, c.g or dg, c.b or db
        end
    end
    return dr, dg, db
end

-- Render the session XP-rate histogram and the quest-vs-other split bar.
-- Pure texture drawing (no OnUpdate); data are plain numbers from gainsHistory.
function Stats:RenderSessionChart(statsFrame, session)
    local panel = statsFrame and statsFrame.ChartPanel
    if not panel then return end

    -- All user-facing text goes through the locale table
    if panel.Title then panel.Title:SetText(L["STATS_CHART_TITLE"]) end
    if panel.EmptyLabel then panel.EmptyLabel:SetText(L["STATS_CHART_EMPTY"]) end

    local plot = panel.Plot
    local split = panel.Split
    local gains = session and session.gainsHistory or {}
    local sessionStart = session and session.sessionStart
    local now = time()

    -- Bucket gains into time slices and find the peak XP/hour
    local span = sessionStart and (now - sessionStart) or 0
    local buckets = {}
    for i = 1, HISTOGRAM_BUCKETS do buckets[i] = 0 end

    if span > 0 then
        local bucketDur = span / HISTOGRAM_BUCKETS
        for _, gain in ipairs(gains) do
            local ts = gain.timestamp
            local amount = gain.amount
            if ts and amount and ts >= sessionStart then
                local idx = math.floor((ts - sessionStart) / bucketDur) + 1
                if idx < 1 then idx = 1 elseif idx > HISTOGRAM_BUCKETS then idx = HISTOGRAM_BUCKETS end
                buckets[idx] = buckets[idx] + amount
            end
        end
    end

    local questXP = session and session.questXP or 0
    local otherXP = session and session.otherXP or 0
    local splitTotal = questXP + otherXP

    -- Peak bucket rate (XP/hour) for scaling the bars
    local bucketDur = (span > 0) and (span / HISTOGRAM_BUCKETS) or 1
    local maxRate = 0
    local rates = {}
    for i = 1, HISTOGRAM_BUCKETS do
        local rate = buckets[i] / bucketDur * 3600
        rates[i] = rate
        if rate > maxRate then maxRate = rate end
    end

    -- Empty state: nothing gained yet
    if maxRate <= 0 and splitTotal <= 0 then
        if panel.EmptyLabel then panel.EmptyLabel:Show() end
        if panel.PlotMaxLabel then panel.PlotMaxLabel:SetText("") end
        if panel.SplitLegend then panel.SplitLegend:SetText("") end
        if plot then hidePoolFrom(plot, 1) end
        if split then hidePoolFrom(split, 1) end
        return
    end
    if panel.EmptyLabel then panel.EmptyLabel:Hide() end

    -- Histogram bars
    if plot then
        local plotW = plot:GetWidth() or 0
        local plotH = plot:GetHeight() or 0
        if plotW > 0 and plotH > 0 and maxRate > 0 then
            local slot = plotW / HISTOGRAM_BUCKETS
            local barW = math.max(1, slot * 0.7)
            local r, g, b = colorOrDefault("xpBar", 0.58, 0.0, 0.55)
            for i = 1, HISTOGRAM_BUCKETS do
                local h = math.max(0, (rates[i] / maxRate) * plotH)
                local tex = acquireBar(plot, i)
                tex:SetColorTexture(r, g, b, 0.9)
                tex:ClearAllPoints()
                if h > 0 then
                    tex:SetSize(barW, h)
                    tex:SetPoint("BOTTOMLEFT", plot, "BOTTOMLEFT", (i - 1) * slot + (slot - barW) / 2, 0)
                    tex:Show()
                else
                    tex:Hide()
                end
            end
            hidePoolFrom(plot, HISTOGRAM_BUCKETS + 1)
        else
            hidePoolFrom(plot, 1)
        end
        if panel.PlotMaxLabel then
            panel.PlotMaxLabel:SetText(maxRate > 0 and string.format(L["STATS_CHART_RATE_FORMAT"], FormatNumber(maxRate)) or "")
        end
    end

    -- Quest-vs-other split bar
    if split then
        local splitW = split:GetWidth() or 0
        local splitH = split:GetHeight() or 0
        if splitW > 0 and splitTotal > 0 then
            local questFrac = questXP / splitTotal
            local questW = math.max(0, splitW * questFrac)
            local otherW = math.max(0, splitW - questW)

            local qr, qg, qb = colorOrDefault("questComplete", 1.0, 0.65, 0.0)
            local seg1 = acquireBar(split, 1)
            seg1:SetColorTexture(qr, qg, qb, 0.9)
            seg1:ClearAllPoints()
            seg1:SetPoint("LEFT", split, "LEFT", 0, 0)
            seg1:SetSize(math.max(1, questW), splitH)
            if questW <= 0 then seg1:Hide() end

            local orr, org, orb = colorOrDefault("xpBar", 0.58, 0.0, 0.55)
            local seg2 = acquireBar(split, 2)
            seg2:SetColorTexture(orr, org, orb, 0.9)
            seg2:ClearAllPoints()
            seg2:SetPoint("LEFT", split, "LEFT", questW, 0)
            seg2:SetSize(math.max(1, otherW), splitH)
            if otherW <= 0 then seg2:Hide() end

            hidePoolFrom(split, 3)

            if panel.SplitLegend then
                local qpct = math.floor(questFrac * 100 + 0.5)
                panel.SplitLegend:SetText(string.format(L["STATS_CHART_SPLIT_LEGEND"], qpct, 100 - qpct))
            end
        else
            hidePoolFrom(split, 1)
            if panel.SplitLegend then panel.SplitLegend:SetText("") end
        end
    end
end

--------------------------------------------------------------------------------
-- Quest XP Integration
--------------------------------------------------------------------------------

---Return quest XP totals (total, complete, incomplete)
function Stats:GetQuestXP(forceRefresh)
    if Addon and Addon.QuestXP and Addon.QuestXP.GetQuestXP then
        return Addon.QuestXP:GetQuestXP(forceRefresh)
    end
    return 0, 0, 0
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

XPBarEnhanced.Stats = Stats
