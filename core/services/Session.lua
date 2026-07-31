-- XP Bar Enhanced - Session.lua
-- Manages player session data such as XP gained and time played

---@class SessionData
---@field sessionStart number Unix timestamp when session started
---@field sessionXP number Legacy field preserved for SavedVariables compatibility
---@field gainedXP number Total XP gained this session
---@field sessionAccumTime number Persisted elapsed session seconds used to preserve session continuity across /reload
---@field lastXP number Last recorded current XP
---@field maxXP number Last recorded max XP for level
---@field lastLevel number Last recorded player level (baseline for XP gain computation)
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
local PENDING_QUEST_TURNIN_WINDOW_SECONDS = 3

-- How long a recorded gain stays consumable by ContextBuilder. OnQuestTurnedIn's
-- delayed OnXPUpdate(true) records a gain whose broadcast is suppressed, so a
-- record can outlive the event that produced it; without this bound that gain
-- resurfaces as a spurious flash on the next consuming build, which may be a
-- style switch or a colour change minutes later.
local LAST_GAIN_MAX_AGE_SECONDS = 2

-- Cap on the persisted gain history, and the block size it is trimmed by.
local GAINS_HISTORY_CAP = 500
local RECENT_GAINS_CAP = 20

local function PurgeExpiredPendingQuestTurnIns(list, now)
    local i = 1
    while i <= #list do
        local entry = list[i]
        if not entry or (entry.expiresAt and entry.expiresAt <= now) then
            table.remove(list, i)
        else
            i = i + 1
        end
    end
end

function Session:_QueuePendingQuestTurnIn(questID)
    self._pendingQuestTurnIns = self._pendingQuestTurnIns or {}
    local now = time()
    PurgeExpiredPendingQuestTurnIns(self._pendingQuestTurnIns, now)
    self._pendingQuestTurnIns[#self._pendingQuestTurnIns + 1] = {
        questID = questID,
        queuedAt = now,
        expiresAt = now + PENDING_QUEST_TURNIN_WINDOW_SECONDS,
    }
end

function Session:_ConsumePendingQuestTurnInForXPGain()
    self._pendingQuestTurnIns = self._pendingQuestTurnIns or {}
    local now = time()
    PurgeExpiredPendingQuestTurnIns(self._pendingQuestTurnIns, now)
    if #self._pendingQuestTurnIns == 0 then
        return false
    end
    table.remove(self._pendingQuestTurnIns, 1)
    return true
end

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
    session.lastLevel = session.lastLevel or UnitLevel("player") or 1
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

-- Number of entries dropped in one go when a history list overflows its cap.
local HISTORY_TRIM_BLOCK = 50

--- Trim a history list back under its cap, a block at a time.
--- `table.remove(list, 1)` is O(n) and used to run on every single gain once the
--- list reached its cap. Trimming in blocks pays that cost once per 50 gains
--- instead. Deliberately not a ring buffer: `gainsHistory` is persisted to
--- SavedVariables, so a head index would need a migration for existing saved
--- arrays while block trimming needs none.
---@param list table Array of history entries
---@param cap number Maximum length before trimming
local function trimHistory(list, cap)
    local count = #list
    local overflow = count - cap
    if overflow <= 0 then
        return
    end

    local removeCount = math.max(overflow, HISTORY_TRIM_BLOCK)
    if removeCount > count then
        removeCount = count
    end

    -- One compaction pass, rather than removeCount separate O(n) removals.
    for i = 1, count - removeCount do
        list[i] = list[i + removeCount]
    end
    for i = count - removeCount + 1, count do
        list[i] = nil
    end
end

--- Credit an XP gain to the session: totals, the legacy alias, the source split
--- and the histories.
---
--- This is the single writer of `session.sessionXP`. That field is a
--- SavedVariables-compatibility alias of `gainedXP` and used to be assigned in
--- four separate places -- four chances for the two to drift apart.
---@param session SessionData
---@param amount number XP to credit; non-positive amounts are ignored
---@param source string "quest" or "other"
---@param level number|nil Level stamped on the history entry
---@param trackRecent boolean Also append to the sliding recent-gains window
---@return table|nil entry The recorded history entry, or nil if nothing was credited
local function creditGain(session, amount, source, level, trackRecent)
    if not session or not amount or amount <= 0 then
        return nil
    end

    session.gainedXP = (session.gainedXP or 0) + amount
    session.sessionXP = session.gainedXP

    if source == "quest" then
        session.questXP = (session.questXP or 0) + amount
    else
        session.otherXP = (session.otherXP or 0) + amount
    end

    local entry = {
        timestamp = time(),
        amount = amount,
        source = source,
        level = level or UnitLevel("player") or 1,
    }

    session.gainsHistory = session.gainsHistory or {}
    table.insert(session.gainsHistory, entry)
    trimHistory(session.gainsHistory, GAINS_HISTORY_CAP)

    -- The level-up remainder path deliberately passes false here, preserving the
    -- pre-existing behaviour that the sliding window tracks only ordinary gains.
    if trackRecent then
        session.recentGains = session.recentGains or {}
        table.insert(session.recentGains, entry)
        trimHistory(session.recentGains, RECENT_GAINS_CAP)
    end

    return entry
end

-------------------------------------------------------------------
-- XP DELTA HANDOFF
-- One tracker owns the XP delta. ContextBuilder used to keep a second, private
-- baseline advanced on a different set of events and fed to ComputeGain with a
-- different arity, so the two could take different branches of the same function
-- on the same event -- and context.xpGained, which decides the gain flash, came
-- from the private one.
-------------------------------------------------------------------

--- Record the gain just credited, for one-shot consumption by ContextBuilder.
--- Module-scoped, never written into the session table: `GetCurrent` returns
--- per-character SavedVariables and preserves unknown fields, so a record parked
--- there would survive logout. This state's lifetime is the UI session.
---@param gained number
---@param preLevelXP number XP at the previous baseline
---@param preLevelMax number xpMax at the previous baseline
---@param didLevelUp boolean
function Session:_StoreLastGain(gained, preLevelXP, preLevelMax, didLevelUp)
    self._lastGain = {
        gained = gained or 0,
        preLevelXP = preLevelXP or 0,
        preLevelMax = preLevelMax or 0,
        didLevelUp = didLevelUp or false,
        at = time(),
    }
end

--- The gain credited by the most recent OnXPUpdate/OnLevelUp, consumed once.
--- Clearing on read is what stops a second consumer double-counting it.
---
--- Nothing pending returns `0` against Session's own current baseline, never nil:
--- a consuming build with no XP event behind it is routine, since
--- `XPBAR:BROADCAST_UPDATE` is a consuming event and both `BarManager:SetStyle`
--- and `Colors:NotifyColorsChanged` emit it. Returning nil there would produce
--- `xpBefore = 0` contexts and a bar that renders briefly empty on a style switch.
---@return number gained
---@return number preLevelXP
---@return number preLevelMax
---@return boolean didLevelUp
function Session:ConsumeLastGain()
    local session = self:GetCurrent()
    local baselineXP = (session and session.lastXP) or UnitXP("player") or 0
    local baselineMax = (session and session.maxXP) or UnitXPMax("player") or 0

    local pending = self._lastGain
    self._lastGain = nil

    if not pending or (time() - (pending.at or 0)) > LAST_GAIN_MAX_AGE_SECONDS then
        return 0, baselineXP, baselineMax, false
    end

    return pending.gained, pending.preLevelXP, pending.preLevelMax, pending.didLevelUp
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
    self._pendingQuestTurnIns = {}
    -- External event ownership is centralized in EventRouter.
end

function Session:OnEnteringWorld(isInitialLogin, isReloadingUI)
    local session = self:GetCurrent()
    if not session then
        return
    end

    if isInitialLogin then
        resetSessionProgress(session)
        -- lastTimePlayedRequest persists across logout; reset it so wall-clock
        -- deltas derived from it only count the current play session, not
        -- offline time (a fresh TIME_PLAYED_MSG is requested below).
        session.lastTimePlayedRequest = time()
    elseif isReloadingUI then
        if Addon.Config and Addon.Config:GetOptionValue("resetOnReload") then
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
        session.lastLevel = UnitLevel("player") or 1
        self._pendingQuestTurnIns = {}
        -- Belt-and-braces. Both already die with the UI session because they live
        -- on the module rather than in the SavedVariables-backed session table,
        -- but the rebaseline invalidates them either way: a boundary or gain
        -- recorded against the old baseline means nothing against this one.
        self._pendingLevelBoundary = nil
        self._lastGain = nil
    end

    updateSessionAccumTime(session)

    -- Always refresh played time at login (keeps level-time math anchored to
    -- fresh data); otherwise only request it when time text options need it
    local Config = Addon.Config
    if isInitialLogin
        or (Config and (Config:GetOptionValue("showLevelTimeText") or Config:GetOptionValue("showSessionTimeText"))) then
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
    local currentLevel = UnitLevel("player") or 1
    local lastXP = session.lastXP or currentXP
    local lastMax = session.maxXP or maxXP
    local lastLevel = session.lastLevel or currentLevel

    -- Use centralized XPCalculations module for XP gain computation
    local XPCalc = Addon.XPCalculations
    local gained, didLevelUp, ambiguousDecrease =
        XPCalc.ComputeGain(currentXP, maxXP, lastXP, lastMax, lastLevel, currentLevel)

    if ambiguousDecrease then
        -- XP fell with neither the level nor the xpMax moving. The likely cause is
        -- a boundary between two levels that share an xpMax, arriving before
        -- UnitLevel caught up -- but a data reset looks identical from here, so
        -- credit nothing yet and park the boundary for PLAYER_LEVEL_UP to confirm.
        --
        -- newXP has to be captured: the true gain across the boundary is
        -- (lastMax - lastXP) + currentXP, the old level's remainder *plus* the
        -- progress already made into the new level, and the rebaseline below is
        -- about to bury that progress under the new baseline.
        local previous = self._pendingLevelBoundary
        self._pendingLevelBoundary = {
            lastXP = lastXP,
            lastMax = lastMax,
            newXP = currentXP,
            at = time(),
            -- Multi-level jump before PLAYER_LEVEL_UP consumed the first boundary:
            -- fold the older one in rather than overwriting it, which would drop
            -- its remainder silently. Per-level PLAYER_LEVEL_UP accounting is the
            -- documented primary path here, so this is genuinely an edge case.
            carried = previous
                and ((previous.lastMax - previous.lastXP) + previous.newXP + (previous.carried or 0))
                or nil,
        }
    elseif gained > 0 then
        -- A normally-credited gain proves no boundary is outstanding. Clearing
        -- here stops a stale flag crediting a phantom remainder at the next ding.
        self._pendingLevelBoundary = nil
    end

    session.lastXP = currentXP
    session.maxXP = maxXP
    session.lastLevel = currentLevel
    session.lastUpdate = time()
    updateSessionAccumTime(session)

    -- Track gain source and record in history
    if gained > 0 then
        local source = self:_ConsumePendingQuestTurnInForXPGain() and "quest" or "other"
        creditGain(session, gained, source, currentLevel, true)
    end

    -- Hand the delta to ContextBuilder. Must precede the broadcast below, which is
    -- what consumes it.
    self:_StoreLastGain(gained, lastXP, lastMax, didLevelUp)

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

    -- UnitLevel can still report the old level during PLAYER_LEVEL_UP, so trust
    -- whichever source is highest.
    local currentLevel = math.max(UnitLevel("player") or 0, tonumber(level) or 0)
    if currentLevel == 0 then
        currentLevel = 1
    end

    -- Credit the remainder of the previous level. There are two entry conditions
    -- and they are mutually exclusive by construction:
    --
    --   1. A pending ambiguous boundary parked by OnXPUpdate. When it is set,
    --      OnXPUpdate has already rebaselined lastXP to the new level's progress,
    --      so the `lastXP > unitXP` guard below is false and cannot also fire.
    --   2. `lastXP > current XP` -- an unambiguous stale baseline, meaning we
    --      crossed a boundary the XP-update path has not yet rebaselined. When
    --      PLAYER_XP_UPDATE already handled the crossing it left lastXP == current
    --      XP, so this is skipped and no XP is double-counted.
    --
    -- Checking the flag first is what preserves the no-double-count invariant:
    -- the flag path must never fall through into the guard path.
    local unitXP = UnitXP("player") or 0
    local unitMax = UnitXPMax("player") or 0

    -- Captured before either branch mutates them; these describe the level just
    -- left and drive the level-up animation's first phase.
    local preLevelXP = session.lastXP or 0
    local preLevelMax = session.maxXP or unitMax

    local pending = self._pendingLevelBoundary
    local creditedXP = 0

    if pending then
        -- The ambiguous decrease was a real boundary after all. Credit the old
        -- level's remainder *plus* the progress into the new level that OnXPUpdate
        -- buried when it rebaselined.
        creditedXP = (pending.lastMax - pending.lastXP) + pending.newXP + (pending.carried or 0)
        preLevelXP = pending.lastXP
        preLevelMax = pending.lastMax
        self._pendingLevelBoundary = nil

        -- Deliberately no `session.lastXP = 0` rebaseline on this path. OnXPUpdate
        -- already set lastXP to the new level's progress and the credit above
        -- accounts for exactly that progress; zeroing it here would credit the
        -- same XP a second time at the next PLAYER_XP_UPDATE.
    elseif session.lastXP and session.maxXP and session.lastXP > unitXP then
        creditedXP = session.maxXP - session.lastXP
        -- Rebaseline to the start of the new level so the next PLAYER_XP_UPDATE
        -- credits new-level progress as an ordinary same-level gain.
        session.lastXP = 0
        session.maxXP = unitMax
    end

    if creditedXP > 0 then
        local source = self:_ConsumePendingQuestTurnInForXPGain() and "quest" or "other"
        creditGain(session, creditedXP, source, currentLevel, false)
    end

    -- Hand the delta to ContextBuilder ahead of this function's broadcast.
    self:_StoreLastGain(creditedXP, preLevelXP, preLevelMax, true)

    -- Track levels gained this session
    session.levelsGained = (session.levelsGained or 0) + 1
    session.levelUpTimestamps = session.levelUpTimestamps or {}
    table.insert(session.levelUpTimestamps, time())

    -- Reset level time
    session.realLevelTime = 0

    -- Update current level state
    session.lastLevel = currentLevel
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
            XPBarContextBuilder.BuildContext("PLAYER_LEVEL_UP", currentLevel)
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

    -- Clear the ticker but keep requestingTimePlayed true briefly so the
    -- chat filter can suppress the system message that arrives in the same frame.
    self:ClearTimePlayedRequest()
    Addon.state.requestingTimePlayed = true
    C_Timer.After(0, function()
        Addon.state.requestingTimePlayed = false
    end)

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

    -- Queue the turn-in so the next XP gain can be attributed to quests.
    -- Entries expire quickly to avoid stale quest attribution.
    self:_QueuePendingQuestTurnIn(questID)

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

-- Suppress the "Total time played" / "Time played this level" system messages
-- when *we* are the ones requesting the data. Installed once.

-- Convert a Blizzard format string (e.g. TIME_PLAYED_TOTAL) into a Lua match
-- pattern. Handles both plain (%s/%d) and positional (%1$s/%2$d) specifiers,
-- which several non-enUS locales use.
local function FormatToPattern(fmt)
    if type(fmt) ~= "string" then
        return nil
    end
    -- Swap format specifiers for sentinels before escaping magic characters,
    -- then replace the sentinels with their patterns.
    local STR, NUM = "\1", "\2"
    local s = fmt:gsub("%%%d*%$?s", STR):gsub("%%%d*%$?d", NUM)
    s = s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    s = s:gsub(STR, ".+"):gsub(NUM, "%%d+")
    return "^" .. s .. "$"
end

local timePlayedPatterns
local function GetTimePlayedPatterns()
    if not timePlayedPatterns then
        timePlayedPatterns = {}
        timePlayedPatterns[#timePlayedPatterns + 1] = FormatToPattern(TIME_PLAYED_TOTAL)
        timePlayedPatterns[#timePlayedPatterns + 1] = FormatToPattern(TIME_PLAYED_LEVEL)
    end
    return timePlayedPatterns
end

local function TimePlayedChatFilter(_, _, msg, ...)
    if not Addon.state.requestingTimePlayed then
        return false
    end
    if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then
        return false
    end
    -- Only block the actual played-time lines, never other system messages
    for _, pattern in ipairs(GetTimePlayedPatterns()) do
        if msg:find(pattern) then
            return true -- block the message
        end
    end
    return false
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", TimePlayedChatFilter)

function Session:ClearTimePlayedRequest()
    if timePlayedTicker then
        timePlayedTicker:Cancel()
        timePlayedTicker = nil
    end
    Addon.state.requestingTimePlayed = false
end

local timePlayedRequestToken = 0

function Session:RequestTimePlayed()
    if Addon.state.requestingTimePlayed then
        return
    end

    self:ClearTimePlayedRequest()
    Addon.state.requestingTimePlayed = true
    timePlayedRequestToken = timePlayedRequestToken + 1
    local token = timePlayedRequestToken

    local function fireRequest()
        RequestTimePlayed()
        -- Safety timeout: if TIME_PLAYED_MSG never arrives, stop suppressing
        -- system messages so a lost response can't filter chat forever.
        if C_Timer and C_Timer.After then
            C_Timer.After(5, function()
                if token == timePlayedRequestToken and Addon.state.requestingTimePlayed then
                    Session:ClearTimePlayedRequest()
                end
            end)
        end
    end

    -- Use timer to avoid instant spam
    if C_Timer and C_Timer.NewTimer then
        timePlayedTicker = C_Timer.NewTimer(0.5, fireRequest)
    else
        fireRequest()
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

    -- Then the sliding window of recent gains. It is a real measurement, so it
    -- beats the level-time estimate below in the two windows where the session
    -- path declines: a session's first 10 seconds, and a session that has
    -- recorded no gains at all.
    if self.GetRecentXPPerHour then
        local recent = self:GetRecentXPPerHour()
        if recent and recent > 0 then
            return recent
        end
    end

    -- Last resort: estimate from realLevelTime.
    if session.realLevelTime and session.realLevelTime > 0 then
        local levelTime = session.realLevelTime
        if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
            local elapsed = time() - session.lastTimePlayedRequest
            levelTime = levelTime + elapsed
        end
        -- Floor the divisor. This path divides a whole level's XP by the time
        -- played at that level, and a handful of seconds there yields a
        -- millions-per-hour reading -- which the circular centre ETA is derived
        -- from, so the spike is visible, not just internal.
        levelTime = math.max(60, levelTime)
        local currentXP = UnitXP("player") or 0
        if currentXP > 0 then
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
