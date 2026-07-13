-- XP Bar Enhanced - Honor Session
-- Tracks Honor (PvP) progress for the secondary bar.
-- Honor levels wrap current back toward 0 at each level, like renown.

local Addon = XPBarEnhanced
Addon.HonorSession = Addon.HonorSession or {}
local L = Addon.L or {}

---@class HonorSession
local HonorSession = Addon.HonorSession

local HONOR_NAME = L["HONOR_NAME"] or "Honor"
local HONOR_LEVEL_FMT = L["HONOR_LEVEL_FMT"] or "Honor Level %d"

local function IsSecret(value)
    return (issecretvalue and issecretvalue(value)) and true or false
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
        source = "honor",
        isAvailable = false,
        name = HONOR_NAME,
        factionType = "honor",
        event = Addon.EventNames and Addon.EventNames.HONOR_BROADCAST_UPDATE or "HONOR:BROADCAST_UPDATE",
    }
end

local function BuildHonorContext(self)
    local session = self._session
    if not session then
        return BuildUnavailableContext()
    end

    if not (UnitHonor and UnitHonorMax and UnitHonorLevel) then
        return BuildUnavailableContext()
    end

    local current = SafeNumber(UnitHonor("player"))
    local maxHonor = SafeNumber(UnitHonorMax("player"))
    local level = SafeNumber(UnitHonorLevel("player"))
    if not current or not maxHonor or not level then
        return BuildUnavailableContext()
    end
    if maxHonor <= 0 then
        maxHonor = 1
    end

    local percent = math.floor((Clamp(current / maxHonor, 0, 1) * 100) + 0.5)

    local perHour = 0
    if session.sessionStart and session.sessionGained and (time() - session.sessionStart) >= 60 then
        local elapsed = math.max(1, time() - session.sessionStart)
        perHour = math.floor((session.sessionGained / elapsed) * 3600)
    end

    local timeToNextLevel = nil
    if perHour > 0 then
        local remaining = math.max(0, maxHonor - current)
        timeToNextLevel = math.floor((remaining * 3600) / perHour)
    end

    return {
        source = "honor",
        isAvailable = true,
        name = HONOR_NAME,
        standingLabel = string.format(HONOR_LEVEL_FMT, level),
        factionType = "honor",
        isCompanion = false,
        currentLevel = level,
        current = current,
        min = 0,
        max = maxHonor,
        ratio = Clamp(current / maxHonor, 0, 1),
        percent = percent,
        isMaxed = false,
        sessionGained = session.sessionGained or 0,
        repPerHour = perHour,
        timeToNextLevel = timeToNextLevel,
        timeToNextStanding = timeToNextLevel,
        event = Addon.EventNames and Addon.EventNames.HONOR_BROADCAST_UPDATE or "HONOR:BROADCAST_UPDATE",
    }
end

local function resetHonorSessionProgress(session)
    session.sessionStart = time()
    session.sessionGained = 0
end

function HonorSession:Initialize()
    local session = Addon.Database and Addon.Database.GetHonorSessionData and Addon.Database:GetHonorSessionData() or {}
    self._session = session

    session.sessionStart = session.sessionStart or time()
    session.lastUpdate = session.lastUpdate or time()
    session.sessionGained = tonumber(session.sessionGained) or 0

    self:Snapshot()
end

-- Record the current honor value/level as the session baseline.
function HonorSession:Snapshot()
    local session = self._session
    if not session then return end
    if not (UnitHonor and UnitHonorLevel) then return end

    session.lastHonor = SafeNumber(UnitHonor("player"))
    session.lastHonorMax = SafeNumber(UnitHonorMax and UnitHonorMax("player"))
    session.lastHonorLevel = SafeNumber(UnitHonorLevel("player"))
    session.lastUpdate = time()
end

function HonorSession:OnEnteringWorld(isInitialLogin, isReloadingUI)
    local session = self._session
    if session then
        if isInitialLogin then
            resetHonorSessionProgress(session)
        elseif isReloadingUI and Addon.Config and Addon.Config:GetOptionValue("resetOnReload") then
            resetHonorSessionProgress(session)
        end
    end

    self:Snapshot()
    self:EmitUpdate()
end

-- Honor changed (HONOR_XP_UPDATE) or a level was gained (HONOR_LEVEL_UPDATE).
function HonorSession:OnHonorUpdate()
    local session = self._session
    if not session then return end
    if not (UnitHonor and UnitHonorLevel) then return end

    local current = SafeNumber(UnitHonor("player"))
    local maxHonor = SafeNumber(UnitHonorMax and UnitHonorMax("player"))
    local level = SafeNumber(UnitHonorLevel("player"))

    if current and level and session.lastHonor ~= nil and session.lastHonorLevel ~= nil then
        local RepCalc = Addon.ReputationCalculations
        local gain
        if level > session.lastHonorLevel and RepCalc and RepCalc.ComputeWrappedGain then
            -- Level up: credit the remainder of the previous level plus the new
            -- level's progress (wrap-aware, like renown).
            gain = RepCalc.ComputeWrappedGain(current, session.lastHonor, session.lastHonorMax)
        else
            gain = math.max(0, current - session.lastHonor)
        end
        if gain > 0 then
            session.sessionGained = (session.sessionGained or 0) + gain
        end
    end

    session.lastHonor = current
    session.lastHonorMax = maxHonor
    session.lastHonorLevel = level
    session.lastUpdate = time()

    self:EmitUpdate()
end

function HonorSession:GetCurrentContext()
    return self:_BuildContext()
end

function HonorSession:EmitUpdate()
    if Addon.EventBus and Addon.EventBus.Emit and Addon.EventNames then
        Addon.EventBus:Emit(Addon.EventNames.HONOR_BROADCAST_UPDATE, self:_BuildContext())
    end
end

function HonorSession:_BuildContext()
    return BuildHonorContext(self)
end

return HonorSession
