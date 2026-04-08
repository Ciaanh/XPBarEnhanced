-- XP Bar Enhanced - Reputation Session
-- Tracks reputation gains for the current play session.
-- Maintains per-faction totals so switching the watched faction
-- preserves prior history within the same session.

local Addon = XPBarEnhanced
Addon.ReputationSession = Addon.ReputationSession or {}

---@class ReputationSession
local RepSession = Addon.ReputationSession

local MAX_HISTORY = 200

local function NormalizeFactionName(name)
    local value = tostring(name or "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:match("^%s*(.-)%s*$") or ""
    return value:lower()
end

--- Checks if a watched faction is a known Delve companion.
--- Uses faction ID lookup for locale-independent matching.
local function IsKnownDelveCompanion(factionID, name)
    local defaults = Addon.defaults
    if not defaults then return false end

    local companions = defaults.delveCompanions
    if not companions then return false end

    -- Faction ID lookup (preferred, locale-independent)
    if factionID and companions[factionID] then
        return true
    end

    -- Name fallback: scan table for matching name (less preferred, locale-dependent)
    if name then
        local normalized = NormalizeFactionName(name)
        if normalized == "" then return false end
        for _, companionName in pairs(companions) do
            if NormalizeFactionName(companionName) == normalized then
                return true
            end
        end
    end
    return false
end

local function IsInDelve()
    if C_Garrison and C_Garrison.IsInDelve then
        return C_Garrison.IsInDelve() and true or false
    end

    local _, instanceType = IsInInstance()
    return instanceType == "scenario"
end

-------------------------------------------------------------------
-- INTERNAL HELPERS
-------------------------------------------------------------------

--- Detect the reputation type for a given faction ID.
--- Returns "major", "paragon", "friendship", or "standard".
---@param factionID number
---@return string factionType
local function DetectFactionType(factionID)
    if not factionID then return "standard" end
    if C_Reputation and C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID) then
        return "major"
    end
    if C_Reputation and C_Reputation.IsFactionParagonForCurrentPlayer and C_Reputation.IsFactionParagonForCurrentPlayer(factionID) then
        return "paragon"
    end
    if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
        local friendInfo = C_GossipInfo.GetFriendshipReputation(factionID)
        if friendInfo and friendInfo.friendshipFactionID and friendInfo.friendshipFactionID > 0 then
            return "friendship"
        end
    end
    return "standard"
end

--- Fetch and normalize reputation data for a faction.
---@param factionID number
---@param factionType string
---@return table|nil snapshot Normalized rep snapshot or nil on failure
local function GetFactionSnapshot(factionID, factionType)
    if not factionID then return nil end

    local RepCalc = Addon.ReputationCalculations
    if not RepCalc then return nil end

    if factionType == "major" then
        if not (C_MajorFactions and C_MajorFactions.GetMajorFactionData) then return nil end
        local data = C_MajorFactions.GetMajorFactionData(factionID)
        if not data then return nil end
        return RepCalc.NormalizeRepData("major", data)

    elseif factionType == "paragon" then
        if not (C_Reputation and C_Reputation.GetFactionParagonInfo) then return nil end
        local paragonData = C_Reputation.GetFactionParagonInfo(factionID)
        if not paragonData then return nil end
        -- Inject name (not included in paragon info)
        if C_Reputation.GetFactionDataByID then
            local fd = C_Reputation.GetFactionDataByID(factionID)
            paragonData.name = (fd and fd.name) or ""
        end
        return RepCalc.NormalizeRepData("paragon", paragonData)

    elseif factionType == "friendship" then
        if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then return nil end
        local fd = C_GossipInfo.GetFriendshipReputation(factionID)
        if not fd then return nil end
        return RepCalc.NormalizeRepData("friendship", fd)

    else -- standard
        if not (C_Reputation and C_Reputation.GetFactionDataByID) then return nil end
        local fd = C_Reputation.GetFactionDataByID(factionID)
        if not fd then return nil end
        return RepCalc.NormalizeRepData("standard", fd)
    end
end

-------------------------------------------------------------------
-- INITIALIZE
-------------------------------------------------------------------

function RepSession:Initialize()
    local session = Addon.Database:GetReputationSessionData()
    self._session = session

    session.sessionStart    = session.sessionStart    or time()
    session.lastUpdate      = session.lastUpdate      or time()
    session.watchedFactionType = session.watchedFactionType or "standard"
    session.lastStanding    = session.lastStanding    or 0
    session.lastMin         = session.lastMin         or 0
    session.lastMax         = session.lastMax         or 0
    session.factionTotals   = session.factionTotals   or {}

    self:_SnapshotWatchedFaction()
end

-------------------------------------------------------------------
-- SNAPSHOT
-------------------------------------------------------------------

function RepSession:_SnapshotWatchedFaction()
    if not (C_Reputation and C_Reputation.GetWatchedFactionData) then return end

    local watchedData = C_Reputation.GetWatchedFactionData()
    local session = self._session

    if not watchedData or not watchedData.name or watchedData.name == "" then
        session.watchedFactionID   = nil
        session.watchedFactionName = nil
        return
    end

    local factionID   = watchedData.factionID
    local factionType = DetectFactionType(factionID)
    local snapshot    = GetFactionSnapshot(factionID, factionType)

    session.watchedFactionID   = factionID
    session.watchedFactionName = watchedData.name
    session.watchedFactionType = factionType
    session.lastStanding       = snapshot and snapshot.current or 0
    session.lastMin            = snapshot and snapshot.min     or 0
    session.lastMax            = snapshot and snapshot.max     or 0
end

-------------------------------------------------------------------
-- FACTION UPDATE
-------------------------------------------------------------------

function RepSession:OnFactionUpdate()
    if not self._session then return end
    if not (C_Reputation and C_Reputation.GetWatchedFactionData) then return end

    local watchedData = C_Reputation.GetWatchedFactionData()
    local session     = self._session

    if not watchedData or not watchedData.name or watchedData.name == "" then
        session.watchedFactionID   = nil
        session.watchedFactionName = nil
        session.watchedFactionType = nil
        session.lastStanding       = 0
        session.lastMin            = 0
        session.lastMax            = 0
        if Addon.EventBus and Addon.EventNames then
            Addon.EventBus:Emit(Addon.EventNames.REPUTATION_BROADCAST_UPDATE, self:_BuildContext())
        end
        return
    end

    local factionID   = watchedData.factionID
    local factionType = DetectFactionType(factionID)
    local snapshot    = GetFactionSnapshot(factionID, factionType)
    if not snapshot then return end

    -- If player switched watched faction, re-baseline without recording a gain.
    if factionID ~= session.watchedFactionID then
        self:_SnapshotWatchedFaction()
        if Addon.EventBus and Addon.EventNames then
            Addon.EventBus:Emit(Addon.EventNames.REPUTATION_BROADCAST_UPDATE, self:_BuildContext())
        end
        return
    end

    local gain = Addon.ReputationCalculations.ComputeGain(snapshot.current, session.lastStanding)

    if gain > 0 then
        if not session.factionTotals[factionID] then
            session.factionTotals[factionID] = {
                name         = watchedData.name,
                factionType  = factionType,
                gained       = 0,
                gainsHistory = {},
            }
        end
        local totals = session.factionTotals[factionID]
        totals.gained = totals.gained + gain
        table.insert(totals.gainsHistory, { timestamp = time(), amount = gain })
        if #totals.gainsHistory > MAX_HISTORY then
            table.remove(totals.gainsHistory, 1)
        end
    end

    session.lastStanding = snapshot.current
    session.lastMin      = snapshot.min
    session.lastMax      = snapshot.max
    session.lastUpdate   = time()

    if Addon.EventBus and Addon.EventNames then
        Addon.EventBus:Emit(Addon.EventNames.REPUTATION_BROADCAST_UPDATE, self:_BuildContext())
    end
end

function RepSession:OnRenownLevelChanged(factionID, newRenownLevel, oldRenownLevel)
    if not self._session then return end
    local session = self._session
    if factionID == session.watchedFactionID then
        self:_SnapshotWatchedFaction()
        if Addon.EventBus and Addon.EventNames then
            Addon.EventBus:Emit(Addon.EventNames.REPUTATION_BROADCAST_UPDATE, self:_BuildContext())
        end
    end
end

-------------------------------------------------------------------
-- CONTEXT
-------------------------------------------------------------------

--- Public read accessor for the current reputation context.
--- Use this instead of calling XPBarContextBuilder.BuildReputationContext() directly
--- so that the session layer remains the single owner of reputation context creation.
function RepSession:GetCurrentContext()
    return self:_BuildContext()
end

--- Emit REPUTATION_BROADCAST_UPDATE with the current context.
--- All modules that need to trigger a reputation redraw MUST call this instead
--- of building a context and emitting from outside the session layer.
function RepSession:EmitUpdate()
    if Addon.EventBus and Addon.EventNames then
        Addon.EventBus:Emit(Addon.EventNames.REPUTATION_BROADCAST_UPDATE, self:_BuildContext())
    end
end

function RepSession:_BuildContext()
    if XPBarContextBuilder and XPBarContextBuilder.BuildReputationContext then
        local context = XPBarContextBuilder.BuildReputationContext()
        context.event = Addon.EventNames.REPUTATION_BROADCAST_UPDATE
        return context
    end

    return {
        event = Addon.EventNames.REPUTATION_BROADCAST_UPDATE,
        isAvailable = false,
    }
end

-------------------------------------------------------------------
-- RATE & TIME
-------------------------------------------------------------------

function RepSession:GetRepPerHour()
    local session = self._session
    if not session.watchedFactionID then return 0 end

    local totals = session.factionTotals and session.factionTotals[session.watchedFactionID]
    if not totals or totals.gained <= 0 then return 0 end
    if not session.sessionStart then return 0 end

    local elapsed = time() - session.sessionStart
    if elapsed < 60 then return 0 end

    return math.floor((totals.gained / math.max(1, elapsed)) * 3600)
end

function RepSession:GetTimeToNextStanding()
    local session   = self._session
    local remaining = Addon.ReputationCalculations.ComputeRemaining(session.lastStanding, session.lastMax)
    local repPerHour = self:GetRepPerHour()
    if repPerHour <= 0 then return nil end
    return (remaining / repPerHour) * 3600
end

-------------------------------------------------------------------
-- GETTERS
-------------------------------------------------------------------

function RepSession:GetWatchedFactionInfo()
    local session = self._session
    if not session.watchedFactionID then return nil end

    local snapshot = GetFactionSnapshot(session.watchedFactionID, session.watchedFactionType)
    if not snapshot then return nil end

    local totals = session.factionTotals and session.factionTotals[session.watchedFactionID]
    snapshot.sessionGained = (totals and totals.gained) or 0

    local isCompanion = session.watchedFactionType == "friendship" and IsKnownDelveCompanion(session.watchedFactionID, snapshot.name)
    snapshot.isCompanion = isCompanion
    snapshot.isInDelve = isCompanion and IsInDelve() or false

    if isCompanion and C_GossipInfo and C_GossipInfo.GetFriendshipReputationRanks then
        local rankData = C_GossipInfo.GetFriendshipReputationRanks(session.watchedFactionID)
        snapshot.currentLevel = (rankData and rankData.currentLevel) or 0
        snapshot.maxLevel = (rankData and rankData.maxLevel) or 0
    else
        snapshot.currentLevel = nil
        snapshot.maxLevel = nil
    end

    return snapshot
end

function RepSession:GetStats()
    local session = self._session
    local totals  = session.factionTotals
        and session.watchedFactionID
        and session.factionTotals[session.watchedFactionID]

    return {
        duration           = time() - (session.sessionStart or time()),
        factionName        = session.watchedFactionName,
        factionType        = session.watchedFactionType,
        repGained          = (totals and totals.gained) or 0,
        repPerHour         = self:GetRepPerHour(),
        timeToNextStanding = self:GetTimeToNextStanding(),
        watchedFactionInfo = self:GetWatchedFactionInfo(),
    }
end

-------------------------------------------------------------------
-- FACTION LISTING (for exports)
-------------------------------------------------------------------

--- Print all factions and their IDs for export.
function RepSession:ListAllFactions()
    if not (C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex) then
        print("|cFFFF0000XP Bar Enhanced:|r C_Reputation API not available")
        return
    end

    print("|cFF00FF00XP Bar Enhanced - Reputation Export|r")
    print("All factions (name: ID):")
    print("-----------------------------------------")

    local numFactions = C_Reputation.GetNumFactions()
    for i = 1, numFactions do
        local fdata = C_Reputation.GetFactionDataByIndex(i)
        if fdata then
            if fdata.isHeader then
                print("|cFFFFFF00" .. (fdata.name or "?") .. "|r")
            else
                local name = fdata.name or "Unknown"
                local id = fdata.factionID or 0
                print(string.format("  %s: %d", name, id))
            end
        end
    end
    print("-----------------------------------------")
end

-------------------------------------------------------------------
-- ENTERING WORLD
-------------------------------------------------------------------

function RepSession:OnEnteringWorld(isInitialLogin, isReloadingUI)
    if not self._session then return end
    if isInitialLogin then
        local session = self._session
        session.factionTotals = {}
        session.sessionStart  = time()
    end

    self:_SnapshotWatchedFaction()

    if Addon.EventBus and Addon.EventNames then
        Addon.EventBus:Emit(Addon.EventNames.REPUTATION_BROADCAST_UPDATE, self:_BuildContext())
    end
end

return RepSession
