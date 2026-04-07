-- XP Bar Enhanced - Companion Session
-- Tracks Delve companion XP gains, rate, and level-ups for the current session.
-- Fully guarded: if C_DelvesUI is unavailable, the module initializes but no-ops.

local Addon = XPBarEnhanced
Addon.CompanionSession = Addon.CompanionSession or {}

---@class CompanionSession
local CompSession = Addon.CompanionSession

local MAX_HISTORY = 200

local function DebugCompanion(message, ...)
    local db = Addon and Addon.db
    if db and db.debugSecondaryBars == false then
        return
    end

    local text = tostring(message or "")
    if select("#", ...) > 0 then
        text = string.format(text, ...)
    end
    print("|cff66ccffXPBE Companion|r " .. text)
end

local function IsPositiveNumber(value)
    return type(value) == "number" and value > 0
end

local function NormalizeName(name)
    local value = tostring(name or "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:match("^%s*(.-)%s*$") or ""
    return value:lower()
end

local function FindFriendshipFactionIDByName(targetName)
    if not (targetName and targetName ~= "") then
        return nil
    end
    if not (C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex) then
        return nil
    end
    if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then
        return nil
    end

    local targetLower = NormalizeName(targetName)
    local numFactions = C_Reputation.GetNumFactions() or 0
    for index = 1, numFactions do
        local fdata = C_Reputation.GetFactionDataByIndex(index)
        if fdata and not fdata.isHeader and IsPositiveNumber(fdata.factionID) then
            local friendData = C_GossipInfo.GetFriendshipReputation(fdata.factionID)
            if friendData and IsPositiveNumber(friendData.friendshipFactionID) then
                local candidate = NormalizeName(friendData.name or fdata.name)
                if candidate == targetLower or candidate:find(targetLower, 1, true) then
                    return fdata.factionID
                end
            end
        end
    end
    return nil
end

local function ResolveCompanionIdentity(session)
    local companionInfo = C_DelvesUI.GetCompanionInfoForActivePlayer and C_DelvesUI.GetCompanionInfoForActivePlayer()
    local companionID = companionInfo
    local companionFactionFromInfo = nil
    local companionName = nil

    -- Some builds may return a table instead of a scalar companion ID.
    if type(companionInfo) == "table" then
        companionID = companionInfo.companionID or companionInfo.id or companionInfo.garrFollowerID
        companionFactionFromInfo = companionInfo.factionID
        companionName = companionInfo.name or companionInfo.companionName
    end

    if not IsPositiveNumber(companionID) then
        DebugCompanion("ResolveIdentity: no active companion ID from C_DelvesUI")
        companionID = 0
    end

    local factionID = nil
    if C_DelvesUI.GetFactionForCompanion then
        factionID = C_DelvesUI.GetFactionForCompanion(companionID)
    end

    if not IsPositiveNumber(factionID) and IsPositiveNumber(companionFactionFromInfo) then
        factionID = companionFactionFromInfo
        DebugCompanion("ResolveIdentity fallback: using companionInfo.factionID=%s", tostring(factionID))
    end

    if not IsPositiveNumber(factionID) and session and IsPositiveNumber(session.factionID)
        and IsPositiveNumber(session.companionID) and session.companionID == companionID then
        factionID = session.factionID
        DebugCompanion("ResolveIdentity fallback: using cached session factionID=%s", tostring(factionID))
    end

    if not IsPositiveNumber(factionID) and companionName and companionName ~= "" then
        factionID = FindFriendshipFactionIDByName(companionName)
        if IsPositiveNumber(factionID) then
            DebugCompanion("ResolveIdentity fallback: matched companionName=%s factionID=%s", tostring(companionName), tostring(factionID))
        end
    end

    if not IsPositiveNumber(factionID) then
        DebugCompanion("ResolveIdentity failed: no verified faction for active companionID=%s", tostring(companionID))
        return companionID, nil, "no valid companion factionID"
    end

    return companionID, factionID, nil
end

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
        DebugCompanion("Initialize unavailable: C_DelvesUI APIs missing")
        return
    end

    local companionID, factionID, identityErr = ResolveCompanionIdentity(session)
    if not companionID then
        self._unavailable = true
        DebugCompanion("Initialize unavailable: %s", tostring(identityErr))
        return
    end

    if not IsPositiveNumber(factionID) then
        self._unavailable = true
        DebugCompanion("Initialize unavailable: %s (companionID=%s, factionID=%s)", tostring(identityErr or "invalid faction"), tostring(companionID), tostring(factionID))
        return
    end

    if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then
        self._unavailable = true
        DebugCompanion("Initialize unavailable: C_GossipInfo friendship APIs missing")
        return
    end

    local friendData = C_GossipInfo.GetFriendshipReputation(factionID)
    if not friendData then
        self._unavailable = true
        DebugCompanion("Initialize unavailable: no friendship data for factionID=%s", tostring(factionID))
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
    DebugCompanion("Initialize OK: companionID=%s factionID=%s level=%s", tostring(companionID), tostring(factionID), tostring(normalized.currentLevel))
end

-------------------------------------------------------------------
-- FACTION UPDATE
-------------------------------------------------------------------

function CompSession:OnFactionUpdate()
    if not self._session then return end
    if self._unavailable then
        DebugCompanion("OnFactionUpdate while unavailable -> reinitialize attempt")
        self:Initialize()
        if self._unavailable then
            DebugCompanion("OnFactionUpdate still unavailable after reinit")
            return
        end
    end

    local session = self._session
    if not session or not IsPositiveNumber(session.factionID) then
        DebugCompanion("OnFactionUpdate aborted: missing session factionID")
        return
    end

    if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then
        DebugCompanion("OnFactionUpdate aborted: friendship API unavailable")
        return
    end

    local friendData = C_GossipInfo.GetFriendshipReputation(session.factionID)
    if not friendData then
        DebugCompanion("OnFactionUpdate aborted: no friendship data for factionID=%s", tostring(session.factionID))
        return
    end

    local rankData = C_GossipInfo.GetFriendshipReputationRanks
        and C_GossipInfo.GetFriendshipReputationRanks(session.factionID)
    if not rankData then
        DebugCompanion("OnFactionUpdate aborted: no rankData for factionID=%s", tostring(session.factionID))
        return
    end

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
        DebugCompanion("Broadcast companion update: level=%s standing=%s currentXP=%s", tostring(normalized.currentLevel), tostring(friendData.standing), tostring(normalized.currentXP))
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
    if not self._session then return end
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
        if Addon.EventBus and Addon.EventNames and Addon.EventNames.COMPANION_BROADCAST_UPDATE then
            Addon.EventBus:Emit(Addon.EventNames.COMPANION_BROADCAST_UPDATE, self:_BuildContext())
        end
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

    if Addon.EventBus and Addon.EventNames and Addon.EventNames.COMPANION_BROADCAST_UPDATE then
        Addon.EventBus:Emit(Addon.EventNames.COMPANION_BROADCAST_UPDATE, self:_BuildContext())
    end
end

return CompSession
