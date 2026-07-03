-- XP Bar Enhanced - Housing Session
-- Tracks housing favor updates for the currently tracked house.

local Addon = XPBarEnhanced
Addon.HousingSession = Addon.HousingSession or {}
local L = Addon.L or {}

---@class HousingSession
local HousingSession = Addon.HousingSession

local HOUSING_NAME = L["HOUSING_NAME"] or "Housing Favor"
local HOUSING_MAX_LEVEL_LABEL = L["HOUSING_MAX_LEVEL_LABEL"] or "Max House Level"
local HOUSING_LEVEL_FMT = L["HOUSING_LEVEL_FMT"] or "Level %d"

local function IsSecret(value)
    return (issecretvalue and issecretvalue(value)) and true or false
end

local function SafeIsSameGuid(a, b)
    if IsSecret(a) or IsSecret(b) then
        return true
    end
    if a == nil or b == nil then
        return false
    end
    return a == b
end

-- tonumber/comparisons are not allowed on secret values; treat them as absent.
local function SafeNumber(value)
    if IsSecret(value) then
        return nil
    end
    return tonumber(value)
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function BuildUnavailableContext()
    return {
        source = "housing",
        isAvailable = false,
        name = HOUSING_NAME,
        factionType = "housing",
        event = Addon.EventNames and Addon.EventNames.HOUSING_BROADCAST_UPDATE or "HOUSING:BROADCAST_UPDATE",
    }
end

local function BuildHousingContext(self)
    local session = self._session
    if not session then
        return BuildUnavailableContext()
    end

    if not C_Housing then
        return BuildUnavailableContext()
    end

    -- GetTrackedHouseGuid returns nil when the player has not checked
    -- "Show as Experience Bar" on any house. Hide the bar in that case.
    local trackedGuid = C_Housing.GetTrackedHouseGuid and C_Housing.GetTrackedHouseGuid()
    -- A secret GUID still means a house is tracked; only bail on a plain nil.
    if not IsSecret(trackedGuid) and not trackedGuid then
        return BuildUnavailableContext()
    end

    local level = tonumber(session.lastHouseLevel)
    local favor = tonumber(session.lastHouseFavor)
    if not level or not favor then
        return BuildUnavailableContext()
    end

    local minFavor = 0
    local maxFavor = 1

    if C_Housing.GetHouseLevelFavorForLevel then
        minFavor = tonumber(C_Housing.GetHouseLevelFavorForLevel(level)) or 0
        maxFavor = tonumber(C_Housing.GetHouseLevelFavorForLevel(level + 1)) or (favor + 1)
    else
        maxFavor = favor + 1
    end

    if maxFavor <= minFavor then
        maxFavor = minFavor + 1
    end

    local maxHouseLevel = (C_Housing.GetMaxHouseLevel and tonumber(C_Housing.GetMaxHouseLevel())) or 0
    local isMaxed = maxHouseLevel > 0 and level >= maxHouseLevel
    local levelProgress = math.max(0, favor - minFavor)
    local levelGoal = math.max(1, maxFavor - minFavor)
    local levelRemaining = math.max(0, maxFavor - favor)
    local percent = isMaxed and 100 or math.floor((Clamp((favor - minFavor) / math.max(1, maxFavor - minFavor), 0, 1) * 100) + 0.5)

    local repPerHour = 0
    if session.sessionStart and session.sessionGained and (time() - session.sessionStart) >= 60 then
        local elapsed = math.max(1, time() - session.sessionStart)
        repPerHour = math.floor((session.sessionGained / elapsed) * 3600)
    end

    local timeToNextLevel = nil
    if not isMaxed and repPerHour > 0 then
        local remaining = math.max(0, maxFavor - favor)
        timeToNextLevel = math.floor((remaining * 3600) / repPerHour)
    end

    return {
        source = "housing",
        isAvailable = true,
        name = HOUSING_NAME,
        standingLabel = isMaxed and HOUSING_MAX_LEVEL_LABEL or string.format(HOUSING_LEVEL_FMT, level),
        factionType = "housing",
        isCompanion = false,
        currentLevel = level,
        reactionLevel = level,
        current = favor,
        min = minFavor,
        max = maxFavor,
        ratio = Clamp((favor - minFavor) / math.max(1, maxFavor - minFavor), 0, 1),
        percent = percent,
        isMaxed = isMaxed,
        progressCurrent = levelProgress,
        progressGoal = levelGoal,
        progressRemaining = levelRemaining,
        sessionGained = session.sessionGained or 0,
        repPerHour = repPerHour,
        timeToNextLevel = timeToNextLevel,
        timeToNextStanding = timeToNextLevel,
        event = Addon.EventNames and Addon.EventNames.HOUSING_BROADCAST_UPDATE or "HOUSING:BROADCAST_UPDATE",
    }
end

function HousingSession:Initialize()
    local session = Addon.Database and Addon.Database.GetHousingSessionData and Addon.Database:GetHousingSessionData() or {}
    self._session = session

    session.sessionStart = session.sessionStart or time()
    session.lastUpdate = session.lastUpdate or time()
    session.sessionGained = tonumber(session.sessionGained) or 0

    self:RequestCurrentTrackedHouseFavor()
end

function HousingSession:RequestCurrentTrackedHouseFavor()
    if not C_Housing or not C_Housing.GetCurrentHouseLevelFavor then
        return
    end

    -- Use GetTrackedHouseGuid (the "Show as Experience Bar" house) as the
    -- primary source. Fall back to session.houseGUID from PLAYER_HOUSE_LIST_UPDATED.
    local houseGUID = C_Housing.GetTrackedHouseGuid and C_Housing.GetTrackedHouseGuid()
    if not IsSecret(houseGUID) and not houseGUID then
        local session = self._session
        houseGUID = session and session.houseGUID
    end
    -- Secret GUIDs can be passed to the API even though they cannot be inspected.
    if IsSecret(houseGUID) or houseGUID then
        pcall(C_Housing.GetCurrentHouseLevelFavor, houseGUID)
    end
end

local function resetHousingSessionProgress(session)
    session.sessionStart = time()
    session.sessionGained = 0
end

function HousingSession:OnEnteringWorld(isInitialLogin, isReloadingUI)
    local session = self._session
    if session then
        -- Same reset semantics as the XP session: fresh login always starts a
        -- new session; /reload only resets when resetOnReload is enabled.
        if isInitialLogin then
            resetHousingSessionProgress(session)
        elseif isReloadingUI and Addon.Config and Addon.Config:GetOptionValue("resetOnReload") then
            resetHousingSessionProgress(session)
        end
    end

    -- Trigger house list loading; PLAYER_HOUSE_LIST_UPDATED fires as the response
    -- and gives us the real houseGUID needed for GetCurrentHouseLevelFavor.
    if C_Timer and C_Timer.After and C_Housing and C_Housing.GetPlayerOwnedHouses then
        C_Timer.After(2, function()
            pcall(C_Housing.GetPlayerOwnedHouses)
        end)
    end
    self:RequestCurrentTrackedHouseFavor()
    self:EmitUpdate()
end

function HousingSession:OnPlayerHouseListUpdated(list)
    if not self._session then return end
    if not list or type(list) ~= "table" or #list == 0 then return end

    local session = self._session
    -- Pick the first valid house entry (most players have exactly one).
    -- The houseGUID here is what GetCurrentHouseLevelFavor actually expects.
    local chosen = list[1]
    if chosen and chosen.houseGUID then
        session.houseGUID = chosen.houseGUID
    end

    self:RequestCurrentTrackedHouseFavor()
    self:EmitUpdate()
end

function HousingSession:OnTrackedHouseChanged()
    if not self._session then
        return
    end

    self._session.lastHouseGuid = nil
    self._session.lastHouseLevel = nil
    self._session.lastHouseFavor = nil
    self._session.lastUpdate = time()

    self:RequestCurrentTrackedHouseFavor()
    self:EmitUpdate()
end

local function NormalizeHouseFavorPayload(a1, a2, a3)
    if type(a1) == "table" then
        return a1
    end

    local payloadGuid = nil
    local level = nil
    local favor = nil

    if IsSecret(a1) then
        -- A secret first arg can only be the GUID; it must not reach tonumber.
        payloadGuid = a1
        level = SafeNumber(a2)
        favor = SafeNumber(a3)
    elseif a1 ~= nil and SafeNumber(a1) == nil then
        payloadGuid = a1
        level = SafeNumber(a2)
        favor = SafeNumber(a3)
    else
        level = SafeNumber(a1)
        favor = SafeNumber(a2)
        payloadGuid = a3
    end

    if not level or not favor then
        return nil
    end

    return {
        houseGUID = payloadGuid,
        houseLevel = level,
        houseFavor = favor,
    }
end

function HousingSession:OnHouseLevelFavorUpdated(a1, a2, a3)
    if not self._session then
        return
    end

    local houseLevelFavor = NormalizeHouseFavorPayload(a1, a2, a3)
    if not houseLevelFavor then
        -- Re-request only for a genuinely empty/malformed payload. If the args
        -- were secret (SafeNumber -> nil), re-requesting would trigger the same
        -- secret payload again, an unbounded request/event loop.
        if not (IsSecret(a1) or IsSecret(a2) or IsSecret(a3)) then
            self:RequestCurrentTrackedHouseFavor()
        end
        return
    end

    local favor = SafeNumber(houseLevelFavor.houseFavor)
    local level = SafeNumber(houseLevelFavor.houseLevel)
    if not favor or not level then
        return
    end

    local session = self._session

    -- Only credit favor from the tracked house. A payload GUID that plainly
    -- differs from the tracked/known house belongs to another owned house;
    -- crediting its cumulative favor against our baseline would inflate the
    -- session and corrupt lastHouseFavor. (SafeIsSameGuid treats secret GUIDs
    -- as matching since they cannot be compared.)
    local payloadGuid = houseLevelFavor.houseGUID
    if payloadGuid ~= nil then
        local trackedGuid = C_Housing and C_Housing.GetTrackedHouseGuid and C_Housing.GetTrackedHouseGuid()
        local referenceGuid = trackedGuid
        if not IsSecret(referenceGuid) and not referenceGuid then
            referenceGuid = session.houseGUID
        end
        if referenceGuid ~= nil and not SafeIsSameGuid(payloadGuid, referenceGuid) then
            return
        end
    end

    -- Favor is a cumulative value across house levels, so the delta stays
    -- meaningful even when the house leveled up since the last update.
    if session.lastHouseFavor ~= nil then
        local gain = favor - (tonumber(session.lastHouseFavor) or favor)
        if gain > 0 then
            session.sessionGained = (session.sessionGained or 0) + gain
        end
    end

    session.lastHouseFavor = favor
    session.lastHouseLevel = level
    session.lastUpdate = time()

    self:EmitUpdate()
end

function HousingSession:GetCurrentContext()
    return self:_BuildContext()
end

function HousingSession:EmitUpdate()
    if Addon.EventBus and Addon.EventBus.Emit and Addon.EventNames then
        Addon.EventBus:Emit(Addon.EventNames.HOUSING_BROADCAST_UPDATE, self:_BuildContext())
    end
end

function HousingSession:_BuildContext()
    return BuildHousingContext(self)
end

return HousingSession
