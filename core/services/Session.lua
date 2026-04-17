-- XP Bar Enhanced - Session.lua
-- Manages player session data such as XP gained and time played

---@class SessionData
---@field sessionStart number Unix timestamp when session started
---@field sessionXP number Legacy field preserved for SavedVariables compatibility
---@field gainedXP number Total XP gained this session
---@field sessionAccumTime number Persisted elapsed session seconds used to preserve session continuity across /reload
---@field lastXP number Last recorded current XP
---@field maxXP number Last recorded max XP for level
---@field realTotalTime number Total time played on character (from TIME_PLAYED_MSG)
---@field realLevelTime number Time played at current level (from TIME_PLAYED_MSG)
---@field lastTimePlayedRequest number Timestamp of last TIME_PLAYED_MSG
---@field lastUpdate number Timestamp of last session update
---@field startLevel number Player level when session started
---@field levelsGained number Number of levels gained this session

---@class Session
---@field eventFrame? Frame Event handler frame
---@field GetCurrent fun(self: Session): SessionData|nil Get current session data
---@field Initialize fun(self: Session) Initialize session tracking
---@field Reset fun(self: Session) Reset session data
---@field RecordXPGain fun(self: Session, xpGained: number) Record an XP gain
---@field OnXPUpdate fun(self: Session) Handle PLAYER_XP_UPDATE event
---@field OnLevelUp fun(self: Session, newLevel: number) Handle PLAYER_LEVEL_UP event
---@field OnTimePlayed fun(self: Session, totalTime: number, levelTime: number) Handle TIME_PLAYED_MSG

local Addon = XPBarEnhanced
Addon.Session = Addon.Session or {}

local Session = Addon.Session
local Utils = Addon.Utils
local timePlayedTicker

-------------------------------------------------------------------
-- SESSION HELPERS
-------------------------------------------------------------------

---@param session SessionData
local function ensureSessionDefaults(session)
    session.sessionStart = session.sessionStart or time()
    session.sessionXP = session.sessionXP or 0
    session.gainedXP = session.gainedXP or 0
    session.sessionAccumTime = session.sessionAccumTime or 0
    session.lastXP = session.lastXP or UnitXP("player") or 0
    session.maxXP = session.maxXP or UnitXPMax("player") or 0
    session.realTotalTime = session.realTotalTime or 0
    session.realLevelTime = session.realLevelTime or 0
    session.lastTimePlayedRequest = session.lastTimePlayedRequest or 0
    session.lastUpdate = session.lastUpdate or time()
    session.startLevel = session.startLevel or (UnitLevel("player") or 1)
    session.levelsGained = session.levelsGained or 0
    session.gainsHistory = session.gainsHistory or {}
    session.levelUpTimestamps = session.levelUpTimestamps or {}
    session.recentGains = session.recentGains or {}
    session.questXP = session.questXP or 0
    session.otherXP = session.otherXP or 0
end

---@param session SessionData
local function updateSessionAccumTime(session)
    local elapsed = time() - (session.sessionStart or time())
    if elapsed < 0 then
        elapsed = 0
    end
    session.sessionAccumTime = elapsed
end

---@param session SessionData
local function resetSessionProgress(session)
    local now = time()
    session.sessionStart = now
    session.sessionAccumTime = 0
    session.sessionXP = 0
    session.gainedXP = 0
    session.startLevel = UnitLevel("player") or 1
    session.levelsGained = 0
    session.lastUpdate = now
    session.gainsHistory = {}
    session.levelUpTimestamps = {}
    session.recentGains = {}
    session.questXP = 0
    session.otherXP = 0
end

-------------------------------------------------------------------
-- SESSION MANAGEMENT
-------------------------------------------------------------------

---Return the currently active session table, or nil if DB unavailable
function Session:GetCurrent()
    local Database = Addon.Database
    if not Database then
        return nil
    end

    local session = Database:GetSessionData()
    ensureSessionDefaults(session)

    return session
end

function Session:Initialize()
    self:GetCurrent()
    -- External event ownership is centralized in EventRouter.
end

function Session:OnEnteringWorld(isInitialLogin, isReloadingUI)
    local session = self:GetCurrent()
    if not session then
        return
    end

    if isInitialLogin then
        resetSessionProgress(session)
    elseif isReloadingUI then
        if Addon.db and Addon.db.resetOnReload then
            resetSessionProgress(session)
        else
            local persistedElapsed = time() - (session.sessionStart or time())
            if persistedElapsed < 0 then
                persistedElapsed = 0
            end
            local accumTime = math.max(session.sessionAccumTime or 0, persistedElapsed)
            session.sessionAccumTime = accumTime
            session.sessionStart = time() - accumTime
        end
    end

    if isInitialLogin or isReloadingUI then
        session.lastXP = UnitXP("player")
        session.maxXP = UnitXPMax("player")
    end

    updateSessionAccumTime(session)

    -- Request time played if time text options are enabled
    if Addon.db and (Addon.db.showLevelTimeText or Addon.db.showSessionTimeText) then
        self:RequestTimePlayed()
    end
end

function Session:OnXPUpdate(suppressBroadcast)
    local session = self:GetCurrent()
    if not session then
        return
    end

    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 0
    local lastXP = session.lastXP or currentXP
    local lastMax = session.maxXP or maxXP

    -- Use centralized XPCalculations module for XP gain computation
    local XPCalc = Addon.XPCalculations
    local gained, didLevelUp = XPCalc.ComputeGain(currentXP, maxXP, lastXP, lastMax)
    session.gainedXP = (session.gainedXP or 0) + gained
    session.sessionXP = session.gainedXP
    session.lastXP = currentXP
    session.maxXP = maxXP
    session.lastUpdate = time()
    updateSessionAccumTime(session)

    -- Track gain source and record in history
    if gained > 0 then
        local source = self._pendingQuestTurnIn and "quest" or "other"
        self._pendingQuestTurnIn = nil

        local entry = {
            timestamp = time(),
            amount = gained,
            source = source,
            level = UnitLevel("player") or 1,
        }

        table.insert(session.gainsHistory, entry)
        if #session.gainsHistory > 500 then
            table.remove(session.gainsHistory, 1)
        end

        table.insert(session.recentGains, entry)
        if #session.recentGains > 20 then
            table.remove(session.recentGains, 1)
        end

        if source == "quest" then
            session.questXP = (session.questXP or 0) + gained
        else
            session.otherXP = (session.otherXP or 0) + gained
        end
    end

    -- Session is the single source of XP events; broadcast to all registered bars
    if not suppressBroadcast and Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(
            Addon.EventNames.XPBAR_BROADCAST_UPDATE,
            XPBarContextBuilder.BuildContext("PLAYER_XP_UPDATE")
        )
    end
end

function Session:OnLevelUp(level)
    local session = self:GetCurrent()
    if not session then
        return
    end

    -- Track levels gained this session
    session.levelsGained = (session.levelsGained or 0) + 1
    session.levelUpTimestamps = session.levelUpTimestamps or {}
    table.insert(session.levelUpTimestamps, time())

    -- Reset level time
    session.realLevelTime = 0

    -- Update current level state
    session.lastXP = UnitXP("player")
    session.maxXP = UnitXPMax("player")
    session.lastUpdate = time()

    -- Notify dependent systems (consolidated from defunct AddOnLifecycle handlers)
    if Addon.QuestXP and Addon.QuestXP.InvalidateQuestCache then
        Addon.QuestXP:InvalidateQuestCache()
    end
    if Addon.BarManager and Addon.BarManager.OnLevelUp then
        Addon.BarManager:OnLevelUp(level)
    end
    if Addon.Stats and Addon.Stats.OnLevelUp then
        Addon.Stats:OnLevelUp()
    end

    -- Broadcast update to all bars
    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(
            Addon.EventNames.XPBAR_BROADCAST_UPDATE,
            XPBarContextBuilder.BuildContext("PLAYER_LEVEL_UP")
        )
    end
end

function Session:OnTimePlayed(totalTime, levelTime)
    local session = self:GetCurrent()
    if not session then
        return
    end

    session.realTotalTime = totalTime or session.realTotalTime or 0
    session.realLevelTime = levelTime or session.realLevelTime or 0
    session.lastTimePlayedRequest = time()
    Addon.state.requestingTimePlayed = false

    -- Clear the ticker
    self:ClearTimePlayedRequest()

    -- Notify Stats module (consolidated from defunct AddOnLifecycle handler)
    local stats = Addon.Stats
    if stats and stats.OnTimePlayed then
        xpcall(stats.OnTimePlayed, Utils.ReportError, stats, totalTime, levelTime)
    end
end

-- Ensure completed-quest cache and session XP are refreshed after a quest is turned in.
-- Delay slightly to allow the server/game to update the quest/completion state.
function Session:OnQuestTurnedIn(questID)
    if not questID then
        return
    end

    -- Flag the next XP gain as quest-sourced (cleared inside OnXPUpdate)
    self._pendingQuestTurnIn = true

    local function RefreshCompletedQuests()
        -- Touch the API to ensure it's updated
        local completed = false
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            completed = C_QuestLog.IsQuestFlaggedCompleted(questID) or false
        end

        -- If the addon maintains a database/quest cache, try to update it.
        -- Use existence checks to remain non-invasive if those APIs don't exist.
        if Addon.Database and Addon.Database.UpdateQuestCompletion then
            pcall(Addon.Database.UpdateQuestCompletion, Addon.Database, questID, completed)
        elseif Addon.Database and Addon.Database.MarkQuestCompleted then
            pcall(Addon.Database.MarkQuestCompleted, Addon.Database, questID, completed)
        end

        -- Ensure session XP baseline is up-to-date (XP gains from quest may have triggered PLAYER_XP_UPDATE
        -- before the completed flag became available). Also ensure the centralized quest cache is invalidated
        -- so UI and other services can refresh based on the latest quest state.
        Session:OnXPUpdate(true)

        -- Touch session timestamps so UI/data consumers will refresh.
        local session = Session:GetCurrent()
        if session then
            session.lastUpdate = time()
        end

        -- Invalidate/rebuild the centralized QuestXP cache to ensure totals reflect the new quest state.
        if Addon.QuestXP and Addon.QuestXP.Rebuild then
            xpcall(Addon.QuestXP.Rebuild, Utils.ReportError, Addon.QuestXP, 0.1)
        elseif Addon.QuestXP and Addon.QuestXP.InvalidateQuestCache then
            xpcall(Addon.QuestXP.InvalidateQuestCache, Utils.ReportError, Addon.QuestXP)
        end

        -- Emit one coalesced update from the session owner after quest state changes.
        Session:EmitUpdate("QUEST_LOG_UPDATE")
    end

    -- Small delay: the quest history/completed flag may not be instantly available.
    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, RefreshCompletedQuests)
    else
        RefreshCompletedQuests()
    end
end

function Session:OnRestedChanged()
    -- Rested/exhaustion state changed; notify all bars via EventBus
    self:EmitUpdate("UPDATE_EXHAUSTION")
end

---Emit a fresh XP broadcast from the session layer.
--- All modules (BarManager, Config, Options) that need to trigger an XP redraw
--- MUST call this instead of building a context locally — keeps context ownership in Session.
---@param reason string Event label used as context.event
function Session:EmitUpdate(reason)
    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(
            Addon.EventNames.XPBAR_BROADCAST_UPDATE,
            XPBarContextBuilder.BuildContext(reason or "XPBAR:BROADCAST_UPDATE")
        )
    end
end

function Session:RefreshSessionTimes()
    local session = self:GetCurrent()
    if not session then
        return
    end

    session.lastUpdate = time()
end

-------------------------------------------------------------------
-- TIME PLAYED MANAGEMENT
-------------------------------------------------------------------

function Session:ClearTimePlayedRequest()
    if timePlayedTicker then
        timePlayedTicker:Cancel()
        timePlayedTicker = nil
    end
    Addon.state.requestingTimePlayed = false
end

function Session:RequestTimePlayed()
    if Addon.state.requestingTimePlayed then
        return
    end

    self:ClearTimePlayedRequest()
    Addon.state.requestingTimePlayed = true

    -- Use timer to avoid instant spam
    if C_Timer and C_Timer.NewTimer then
        timePlayedTicker =
            C_Timer.NewTimer(
            0.5,
            function()
                RequestTimePlayed()
            end
        )
    else
        RequestTimePlayed()
    end
end

-------------------------------------------------------------------
-- SESSION STATS (for backward compatibility)
-------------------------------------------------------------------
-- TIME TO LEVEL HELPER
-------------------------------------------------------------------

---Compute time to level based on session XP rate and remaining XP
function Session:GetTimeToLevel()
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")

    if not maxXP or maxXP <= 0 then
        return 0
    end

    -- Use centralized XP/hour calculation
    local xpPerHour = 0
    if self and self.GetXPPerHour then
        xpPerHour = self:GetXPPerHour() or 0
    end

    local remainingXP = (maxXP or 0) - (currentXP or 0)
    if xpPerHour > 0 and remainingXP > 0 then
        return math.floor((remainingXP / xpPerHour) * 3600)
    end

    return 0
end

---Return XP per hour based on session or level-time fallback
function Session:GetXPPerHour()
    local session = self:GetCurrent()
    if not session then
        return 0
    end

    local duration = time() - (session.sessionStart or time())
    local gainedXP = session.gainedXP or 0

    -- Prefer session-derived rate when session is meaningful
    if duration >= 10 and gainedXP > 0 then
        return math.floor((gainedXP / duration) * 3600)
    end

    -- Fallback: estimate from realLevelTime if available
    if session.realLevelTime and session.realLevelTime > 0 then
        local levelTime = session.realLevelTime
        if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
            local elapsed = time() - session.lastTimePlayedRequest
            levelTime = levelTime + elapsed
        end
        local currentXP = UnitXP("player") or 0
        if levelTime > 0 and currentXP > 0 then
            return math.floor((currentXP / levelTime) * 3600)
        end
    end

    return 0
end

---Return XP per hour based on a sliding window of recent gains
---@return number xpPerHour Recent XP/hour rate
function Session:GetRecentXPPerHour()
    local session = self:GetCurrent()
    if not session or not session.recentGains then
        return 0
    end
    local TimeCalc = Addon.TimeCalculations
    if not TimeCalc or not TimeCalc.RecentXPPerHour then
        return 0
    end
    return TimeCalc.RecentXPPerHour(session.recentGains)
end
-------------------------------------------------------------------

---Return a normalized stats table for the current session
function Session:GetStats()
    local session = self:GetCurrent()
    if not session then
        return {
            duration = 0,
            xpGained = 0,
            xpPerHour = 0,
            startTime = time()
        }
    end

    -- Calculate session duration
    local duration = time() - (session.sessionStart or time())

    -- Calculate XP per hour
    local xpPerHour = 0
    if duration > 0 then
        xpPerHour = (session.gainedXP or 0) / (duration / 3600)
    end

    return {
        duration = duration,
        xpGained = session.gainedXP or 0,
        xpPerHour = xpPerHour,
        startTime = session.sessionStart or time(),
        realTotalTime = session.realTotalTime or 0,
        realLevelTime = session.realLevelTime or 0,
        recentXPPerHour = self:GetRecentXPPerHour(),
        questXPGained = session.questXP or 0,
        otherXP = session.otherXP or 0,
        gainsCount = #(session.gainsHistory or {}),
        levelUpTimestamps = session.levelUpTimestamps or {},
    }
end

-------------------------------------------------------------------
-- BACKWARD COMPATIBILITY
-------------------------------------------------------------------

return Session
