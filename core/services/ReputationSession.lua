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
    -- Secret strings cannot be inspected with string operations.
    if issecretvalue and issecretvalue(name) then
        return ""
    end
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

    -- Fallback only when Delve API is unavailable.
    if IsInInstance then
        local _, instanceType = IsInInstance()
        if instanceType == "scenario" then
            return true
        end
    end

    return false
end



local function IsCompanionNPCInParty(companionName)
    local numMembers = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    if numMembers <= 0 then
        return false
    end

    -- A secret companion name cannot be compared either; treat it like the
    -- no-name case and rely on non-player detection below.
    if companionName and issecretvalue and issecretvalue(companionName) then
        companionName = nil
    end

    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists and UnitExists(unit) then
            if companionName and UnitName then
                local unitName = UnitName(unit)
                local isSecret = (issecretvalue and issecretvalue(unitName)) and true or false

                if not isSecret and unitName == companionName then
                    return true
                end

                -- In restricted states UnitName may be secret and cannot be compared.
                -- Fall back to non-player detection to avoid secret-value branching.
                if isSecret and UnitIsPlayer and not UnitIsPlayer(unit) then
                    return true
                end
            else
                local isPlayer = UnitIsPlayer and UnitIsPlayer(unit)
                if not isPlayer then
                    return true
                end
            end
        end
    end

    return false
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

local function BuildReputationContext(repSession)
    local info = repSession:GetWatchedFactionInfo()
    if not info then
        return { isAvailable = false }
    end

    local stats = repSession:GetStats()
    local panel = rawget(_G, "XPBarEnhancedOptionsPanel")
    local Config = Addon.Config
    local isPreviewMode = (Config and Config:GetOptionValue("barLocked") == false) or (panel and panel.IsVisible and panel:IsVisible())
    local hideCompanionOutsideDelve = Config and Config:GetOptionValue("hideCompanionOutsideDelve")
    local isCompanionInParty = info.isCompanion and info.isInDelve and IsCompanionNPCInParty(info.name) or false

    local isCompanionAvailable
    if hideCompanionOutsideDelve then
        isCompanionAvailable = not info.isCompanion or (info.isInDelve and isCompanionInParty and not info.isMaxed)
    else
        isCompanionAvailable = not info.isCompanion or isPreviewMode or (info.isInDelve and isCompanionInParty and not info.isMaxed)
    end

    if not isCompanionAvailable then
        return {
            isAvailable = false,
            isCompanion = true,
            isCompanionInParty = isCompanionInParty,
            name = info.name or "",
        }
    end

    return {
        isAvailable        = true,
        source             = "reputation",
        name               = info.name or "",
        standingLabel      = info.standingLabel or "",
        factionType        = info.factionType or "standard",
        isCompanion        = info.isCompanion or false,
        isCompanionInParty = isCompanionInParty,
        isInDelve          = info.isInDelve or false,
        currentLevel       = info.currentLevel or 0,
        maxLevel           = info.maxLevel or 0,
        current            = info.current or 0,
        min                = info.min or 0,
        max                = math.max(1, info.max or 1),
        ratio              = info.ratio or 0,
        percent            = info.percent or 0,
        isMaxed            = info.isMaxed or false,
        sessionGained      = info.sessionGained or 0,
        repPerHour         = (stats and stats.repPerHour) or 0,
        timeToNextStanding = stats and stats.timeToNextStanding,
        timeToNextLevel    = stats and stats.timeToNextStanding,
    }
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
    if not snapshot then
        -- Data temporarily unavailable (loading screen, phasing, etc.) —
        -- re-baseline so we don't attribute a stale delta when data returns.
        self:_SnapshotWatchedFaction()
        return
    end

    -- If player switched watched faction, re-baseline without recording a gain.
    if factionID ~= session.watchedFactionID then
        self:_SnapshotWatchedFaction()
        if Addon.EventBus and Addon.EventNames then
            Addon.EventBus:Emit(Addon.EventNames.REPUTATION_BROADCAST_UPDATE, self:_BuildContext())
        end
        return
    end

    local RepCalc = Addon.ReputationCalculations
    local gain
    if factionType ~= session.watchedFactionType then
        -- Reputation scale changed (e.g. renown cap rolling into paragon) —
        -- baselines are not comparable, so re-baseline without recording a gain.
        gain = 0
    elseif factionType == "major" or factionType == "paragon" then
        -- Renown levels and paragon cycles wrap current back towards 0;
        -- credit the remainder of the previous cycle when that happens.
        gain = RepCalc.ComputeWrappedGain(snapshot.current, session.lastStanding, session.lastMax)
    else
        gain = RepCalc.ComputeGain(snapshot.current, session.lastStanding)
    end

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

    session.lastStanding       = snapshot.current
    session.lastMin            = snapshot.min
    session.lastMax            = snapshot.max
    session.watchedFactionType = factionType
    session.lastUpdate         = time()

    if Addon.EventBus and Addon.EventNames then
        Addon.EventBus:Emit(Addon.EventNames.REPUTATION_BROADCAST_UPDATE, self:_BuildContext())
    end
end

function RepSession:OnRenownLevelChanged(factionID, newRenownLevel, oldRenownLevel)
    if not self._session then return end
    local session = self._session
    if factionID == session.watchedFactionID then
        -- Route through the gain-aware update so rep earned across the renown
        -- level-up is credited (wrap-aware) instead of re-baselined away.
        self:OnFactionUpdate()
    end
end

-------------------------------------------------------------------
-- CONTEXT
-------------------------------------------------------------------

--- Public read accessor for the current reputation context.
--- Session remains the single owner of reputation context creation.
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
    local context = BuildReputationContext(self)
    context.event = Addon.EventNames.REPUTATION_BROADCAST_UPDATE
    return context
end

-------------------------------------------------------------------
-- RATE & TIME
-------------------------------------------------------------------

function RepSession:GetRepPerHour()
    local session = self._session
    if not session or not session.watchedFactionID then return 0 end

    local totals = session.factionTotals and session.factionTotals[session.watchedFactionID]
    if not totals or totals.gained <= 0 then return 0 end
    if not session.sessionStart then return 0 end

    local elapsed = time() - session.sessionStart
    if elapsed < 60 then return 0 end

    return math.floor((totals.gained / math.max(1, elapsed)) * 3600)
end

function RepSession:GetTimeToNextStanding()
    local session = self._session
    if not session then return nil end
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
    if not session or not session.watchedFactionID then return nil end

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
    if not session then
        return {
            duration           = 0,
            factionName        = nil,
            factionType        = nil,
            repGained          = 0,
            repPerHour         = 0,
            timeToNextStanding = nil,
        }
    end
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
