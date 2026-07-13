-- XP Bar Enhanced - Profession Session
-- Tracks a primary profession's skill level for the secondary bar.
-- Skill is an absolute value capped at maxRank (no wrap within a skill line).

local Addon = XPBarEnhanced
Addon.ProfessionSession = Addon.ProfessionSession or {}
local L = Addon.L or {}

---@class ProfessionSession
local ProfessionSession = Addon.ProfessionSession

local PROFESSION_MAX_LABEL = L["PROFESSION_MAX_LABEL"] or "Max Skill"

local function IsSecret(value)
    return (issecretvalue and issecretvalue(value)) and true or false
end

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
        source = "profession",
        isAvailable = false,
        name = L["PROFESSION_NAME"] or "Profession",
        factionType = "profession",
        event = Addon.EventNames and Addon.EventNames.PROFESSION_BROADCAST_UPDATE or "PROFESSION:BROADCAST_UPDATE",
    }
end

-- Resolve the primary profession to track: prefer the first primary profession
-- that still has room to grow, otherwise the first primary profession.
-- Returns name, rank, maxRank, skillLine (all plain numbers/strings), or nil.
local function GetTrackedProfession()
    if not (GetProfessions and GetProfessionInfo) then
        return nil
    end

    local prof1, prof2 = GetProfessions()
    local candidates = { prof1, prof2 }

    local fallback = nil
    for _, index in ipairs(candidates) do
        if index then
            local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
            rank = SafeNumber(rank)
            maxRank = SafeNumber(maxRank)
            if name and rank and maxRank and maxRank > 0 then
                fallback = fallback or { name = name, rank = rank, maxRank = maxRank, skillLine = skillLine }
                if rank < maxRank then
                    return name, rank, maxRank, skillLine
                end
            end
        end
    end

    if fallback then
        return fallback.name, fallback.rank, fallback.maxRank, fallback.skillLine
    end
    return nil
end

local function BuildProfessionContext(self)
    local session = self._session
    if not session then
        return BuildUnavailableContext()
    end

    local name, rank, maxRank, skillLine = GetTrackedProfession()
    if not name or not rank or not maxRank then
        return BuildUnavailableContext()
    end

    local isMaxed = rank >= maxRank
    local percent = isMaxed and 100 or math.floor((Clamp(rank / math.max(1, maxRank), 0, 1) * 100) + 0.5)

    local perHour = 0
    if session.sessionStart and session.sessionGained and (time() - session.sessionStart) >= 60 then
        local elapsed = math.max(1, time() - session.sessionStart)
        perHour = math.floor((session.sessionGained / elapsed) * 3600)
    end

    local timeToNextLevel = nil
    if not isMaxed and perHour > 0 then
        local remaining = math.max(0, maxRank - rank)
        timeToNextLevel = math.floor((remaining * 3600) / perHour)
    end

    return {
        source = "profession",
        isAvailable = true,
        name = name,
        standingLabel = isMaxed and PROFESSION_MAX_LABEL or string.format("%d / %d", rank, maxRank),
        factionType = "profession",
        isCompanion = false,
        current = rank,
        min = 0,
        max = maxRank,
        ratio = Clamp(rank / math.max(1, maxRank), 0, 1),
        percent = percent,
        isMaxed = isMaxed,
        sessionGained = session.sessionGained or 0,
        repPerHour = perHour,
        timeToNextLevel = timeToNextLevel,
        timeToNextStanding = timeToNextLevel,
        skillLine = skillLine,
        event = Addon.EventNames and Addon.EventNames.PROFESSION_BROADCAST_UPDATE or "PROFESSION:BROADCAST_UPDATE",
    }
end

local function resetProfessionSessionProgress(session)
    session.sessionStart = time()
    session.sessionGained = 0
end

function ProfessionSession:Initialize()
    local session = Addon.Database and Addon.Database.GetProfessionSessionData and Addon.Database:GetProfessionSessionData() or {}
    self._session = session

    session.sessionStart = session.sessionStart or time()
    session.lastUpdate = session.lastUpdate or time()
    session.sessionGained = tonumber(session.sessionGained) or 0

    self:Snapshot()
end

-- Record the tracked profession's current rank as the session baseline.
function ProfessionSession:Snapshot()
    local session = self._session
    if not session then return end
    local _, rank, _, skillLine = GetTrackedProfession()
    session.lastRank = rank
    session.lastSkillLine = skillLine
    session.lastUpdate = time()
end

function ProfessionSession:OnEnteringWorld(isInitialLogin, isReloadingUI)
    local session = self._session
    if session then
        if isInitialLogin then
            resetProfessionSessionProgress(session)
        elseif isReloadingUI and Addon.Config and Addon.Config:GetOptionValue("resetOnReload") then
            resetProfessionSessionProgress(session)
        end
    end

    self:Snapshot()
    self:EmitUpdate()
end

-- Skill rank changed (SKILL_LINES_CHANGED / TRADE_SKILL_UPDATE).
function ProfessionSession:OnSkillUpdate()
    local session = self._session
    if not session then return end

    local _, rank, _, skillLine = GetTrackedProfession()

    -- Only accrue a gain when the tracked skill line is unchanged; switching
    -- the tracked profession (or expansion skill line) re-baselines silently.
    if rank and session.lastRank ~= nil and session.lastSkillLine == skillLine then
        local gain = rank - session.lastRank
        if gain > 0 then
            session.sessionGained = (session.sessionGained or 0) + gain
        end
    end

    session.lastRank = rank
    session.lastSkillLine = skillLine
    session.lastUpdate = time()

    self:EmitUpdate()
end

function ProfessionSession:GetCurrentContext()
    return self:_BuildContext()
end

function ProfessionSession:EmitUpdate()
    if Addon.EventBus and Addon.EventBus.Emit and Addon.EventNames then
        Addon.EventBus:Emit(Addon.EventNames.PROFESSION_BROADCAST_UPDATE, self:_BuildContext())
    end
end

function ProfessionSession:_BuildContext()
    return BuildProfessionContext(self)
end

return ProfessionSession
