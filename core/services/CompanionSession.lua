-- XP Bar Enhanced - Companion Session
-- Tracks Delve companion XP gains, rate, and level-ups for the current session.
-- Fully guarded: if C_DelvesUI is unavailable, the module initializes but no-ops.

local Addon = XPBarEnhanced
Addon.CompanionSession = Addon.CompanionSession or {}

---@class CompanionSession
local CompSession = Addon.CompanionSession

local MAX_HISTORY = 200

-------------------------------------------------------------------
-- INITIALIZE
-------------------------------------------------------------------

function CompSession:Initialize()
    local session = Addon.Database:GetCompanionSessionData()

    -- Seed defaults without overwriting persisted data
    session.sessionStart          = session.sessionStart          or time()
    session.lastUpdate            = session.lastUpdate            or time()
    session.lastStanding          = session.lastStanding          or 0
    session.lastReactionThreshold = session.lastReactionThreshold or 0
    session.lastCurrentXP         = session.lastCurrentXP         or 0
    session.lastLevel             = session.lastLevel             or 0
    session.gainedXP              = session.gainedXP              or 0
    session.gainsHistory          = session.gainsHistory          or {}
    session.levelUps              = session.levelUps              or 0

    self._session = session

    -- Guard: companion APIs must be available.
    if not (C_DelvesUI
        and C_DelvesUI.GetCompanionInfoForActivePlayer
        and C_DelvesUI.GetFactionForCompanion) then
        self._unavailable = true
        return
    end

    local companionID = C_DelvesUI.GetCompanionInfoForActivePlayer()
    if not companionID or companionID == 0 then
        self._unavailable = true
        return
    end

    local factionID = C_DelvesUI.GetFactionForCompanion(companionID)
    if not factionID then
        self._unavailable = true
        return
    end

    if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then
        self._unavailable = true
        return
    end

    local friendData = C_GossipInfo.GetFriendshipReputation(factionID)
    if not friendData then
        self._unavailable = true
        return
    end

    local rankData = C_GossipInfo.GetFriendshipReputationRanks
        and C_GossipInfo.GetFriendshipReputationRanks(factionID)

    local normalized = Addon.CompanionCalculations.NormalizeCompanionData(
        friendData, rankData, companionID, factionID
    )

    session.companionID           = companionID
    session.factionID             = factionID
    session.companionName         = normalized.name
    session.lastStanding          = friendData.standing
    session.lastReactionThreshold = friendData.reactionThreshold
    session.lastNextThreshold     = friendData.nextThreshold
    session.lastCurrentXP         = normalized.currentXP
    session.lastLevel             = normalized.currentLevel

    self._unavailable = false

    self:_SetupEventFrame()
end

-------------------------------------------------------------------
-- EVENT FRAME
-------------------------------------------------------------------

function CompSession:_SetupEventFrame()
    -- Guard against duplicate frame creation on re-initialize.
    if self._eventFrame then return end

    local frame = CreateFrame("Frame")
    self._eventFrame = frame

    frame:RegisterEvent("UPDATE_FACTION")
    frame:RegisterEvent("DELVES_ACCOUNT_DATA_ELEMENT_CHANGED")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "UPDATE_FACTION" then
            -- UPDATE_FACTION may carry a factionID argument or none (global update).
            local factionID = ...
            local sess = CompSession._session
            if not factionID or (sess and factionID == sess.factionID) then
                CompSession:OnFactionUpdate()
            end
        elseif event == "DELVES_ACCOUNT_DATA_ELEMENT_CHANGED" then
            CompSession:OnFactionUpdate()
        end
    end)
end

-------------------------------------------------------------------
-- FACTION UPDATE
-------------------------------------------------------------------

function CompSession:OnFactionUpdate()
    if self._unavailable then return end

    local session = self._session
    if not session or not session.factionID then return end

    if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then return end

    local friendData = C_GossipInfo.GetFriendshipReputation(session.factionID)
    if not friendData then return end

    local rankData = C_GossipInfo.GetFriendshipReputationRanks
        and C_GossipInfo.GetFriendshipReputationRanks(session.factionID)
    if not rankData then return end

    local normalized = Addon.CompanionCalculations.NormalizeCompanionData(
        friendData, rankData, session.companionID, session.factionID
    )

    -- Detect level-up (suppress false positive on first update after login).
    local didLevelUp = (normalized.currentLevel > session.lastLevel) and (session.lastLevel > 0)
    if didLevelUp then
        session.levelUps = session.levelUps + 1
    end

    -- Record XP gain only when no level boundary was crossed.
    if not didLevelUp then
        local lastCurrentXP = session.lastCurrentXP or 0
        local gain = Addon.CompanionCalculations.ComputeGain(normalized.currentXP, lastCurrentXP)
        if gain > 0 then
            session.gainedXP = session.gainedXP + gain
            table.insert(session.gainsHistory, { timestamp = time(), amount = gain })
            while #session.gainsHistory > MAX_HISTORY do
                table.remove(session.gainsHistory, 1)
            end
        end
    end

    -- Update snapshot.
    session.lastStanding          = friendData.standing
    session.lastReactionThreshold = friendData.reactionThreshold
    session.lastNextThreshold     = friendData.nextThreshold
    session.lastCurrentXP         = normalized.currentXP
    session.lastLevel             = normalized.currentLevel
    session.lastUpdate            = time()

    -- Broadcast update.
    if Addon.EventBus and Addon.EventNames and Addon.EventNames.COMPANION_BROADCAST_UPDATE then
        Addon.EventBus:Emit(Addon.EventNames.COMPANION_BROADCAST_UPDATE, self:_BuildContext())
    end
end

-------------------------------------------------------------------
-- CONTEXT
-------------------------------------------------------------------

function CompSession:_BuildContext()
    if XPBarContextBuilder and XPBarContextBuilder.BuildCompanionContext then
        local context = XPBarContextBuilder.BuildCompanionContext()
        context.event = Addon.EventNames.COMPANION_BROADCAST_UPDATE
        return context
    end

    return {
        event = Addon.EventNames.COMPANION_BROADCAST_UPDATE,
        isAvailable = false,
    }
end

-------------------------------------------------------------------
-- RATE & TIME
-------------------------------------------------------------------

function CompSession:GetXPPerHour()
    if self._unavailable then return 0 end

    local session = self._session
    if not session then return 0 end

    local elapsed = math.max(1, time() - (session.sessionStart or time()))
    if elapsed < 60 or session.gainedXP <= 0 then return 0 end

    return math.floor((session.gainedXP / elapsed) * 3600)
end

function CompSession:GetTimeToNextLevel()
    if self._unavailable then return nil end

    local session = self._session
    if not session then return nil end

    local remaining = session.lastNextThreshold
        and (session.lastNextThreshold - session.lastStanding)
        or 0
    if remaining <= 0 then return nil end

    local xpPerHour = self:GetXPPerHour()
    if xpPerHour <= 0 then return nil end

    return (remaining / xpPerHour) * 3600
end

-------------------------------------------------------------------
-- GETTERS
-------------------------------------------------------------------

function CompSession:GetCompanionInfo()
    if self._unavailable then return nil end

    local session = self._session
    if not session or not session.factionID then return nil end

    return {
        companionID           = session.companionID,
        factionID             = session.factionID,
        name                  = session.companionName,
        currentLevel          = session.lastLevel,
        lastStanding          = session.lastStanding,
        lastReactionThreshold = session.lastReactionThreshold,
        lastNextThreshold     = session.lastNextThreshold,
        isMaxLevel            = (session.lastNextThreshold == nil),
        gainedXP              = session.gainedXP,
        levelUps              = session.levelUps,
    }
end

function CompSession:GetStats()
    local session = self._session
    if not session then return nil end

    return {
        duration        = time() - (session.sessionStart or time()),
        companionName   = session.companionName,
        currentLevel    = session.lastLevel,
        xpGained        = session.gainedXP,
        xpPerHour       = self:GetXPPerHour(),
        timeToNextLevel = self:GetTimeToNextLevel(),
        levelUps        = session.levelUps,
        available       = not self._unavailable,
    }
end

-------------------------------------------------------------------
-- ENTERING WORLD
-------------------------------------------------------------------

function CompSession:OnEnteringWorld(isInitialLogin, isReloadingUI)
    if isInitialLogin then
        -- Reset counters; companion identity may have changed between sessions.
        local session = self._session
        if session then
            session.gainedXP     = 0
            session.gainsHistory = {}
            session.levelUps     = 0
            session.sessionStart = time()
        end
        -- Re-run full init to detect the current companion.
        self:Initialize()
        return
    end

    -- On /reload: refresh snapshot without resetting session counters.
    if self._unavailable then return end

    local session = self._session
    if not session or not session.factionID then return end

    if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then return end

    local friendData = C_GossipInfo.GetFriendshipReputation(session.factionID)
    if not friendData then return end

    local rankData = C_GossipInfo.GetFriendshipReputationRanks
        and C_GossipInfo.GetFriendshipReputationRanks(session.factionID)

    local normalized = Addon.CompanionCalculations.NormalizeCompanionData(
        friendData, rankData, session.companionID, session.factionID
    )

    session.lastStanding          = friendData.standing
    session.lastReactionThreshold = friendData.reactionThreshold
    session.lastNextThreshold     = friendData.nextThreshold
    session.lastCurrentXP         = normalized.currentXP
    session.lastLevel             = normalized.currentLevel
end

return CompSession
