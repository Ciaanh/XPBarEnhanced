-- XP Bar Enhanced - Reputation Calculations
-- Pure stateless reputation calculation helpers for all faction types.
-- Uses GetText/UnitSex for localized standing labels; no other side effects.

local Addon = XPBarEnhanced
Addon.ReputationCalculations = Addon.ReputationCalculations or {}

---@class ReputationCalculations
local RepCalc = Addon.ReputationCalculations

-------------------------------------------------------------------
-- GAIN
-------------------------------------------------------------------

--- Compute reputation gained since last snapshot (simple delta).
---@param currentRep number Current reputation standing value
---@param lastRep number Previous reputation standing value
---@return number gain Non-negative reputation gained
function RepCalc.ComputeGain(currentRep, lastRep)
    return math.max(0, currentRep - lastRep)
end

--- Compute reputation gained since last snapshot for value scales that wrap
--- (renown levels, paragon cycles). When the current value drops below the
--- previous snapshot, the remainder of the previous cycle is credited.
--- Multi-level wraps only credit the final partial cycle because the
--- intermediate thresholds are no longer available.
---@param currentRep number Current reputation standing value
---@param lastRep number Previous reputation standing value
---@param lastMax number|nil Upper bound (cap) of the previous snapshot's scale
---@return number gain Non-negative reputation gained
function RepCalc.ComputeWrappedGain(currentRep, lastRep, lastMax)
    if currentRep < lastRep then
        if lastMax and lastMax > lastRep then
            return (lastMax - lastRep) + currentRep
        end
        -- Cap unknown or inconsistent with the baseline — the wrapped cycle
        -- cannot be sized, so fall back to not recording a gain.
        return 0
    end
    return currentRep - lastRep
end

-------------------------------------------------------------------
-- REMAINING
-------------------------------------------------------------------

--- Compute reputation remaining to the next threshold.
---@param currentStanding number Current reputation standing
---@param nextThreshold number Rep threshold for next standing/level
---@return number remaining Non-negative reputation remaining
function RepCalc.ComputeRemaining(currentStanding, nextThreshold)
    return math.max(0, nextThreshold - currentStanding)
end

-------------------------------------------------------------------
-- RATIO / PERCENT
-------------------------------------------------------------------

--- Compute progress ratio (0.0–1.0) within the current standing bracket.
---@param currentStanding number Current reputation standing
---@param minThreshold number Lower bound of current bracket (currentReactionThreshold)
---@param maxThreshold number Upper bound of current bracket (nextReactionThreshold)
---@return number ratio Progress 0.0–1.0
function RepCalc.ComputeRatio(currentStanding, minThreshold, maxThreshold)
    local range = maxThreshold - minThreshold
    if range <= 0 then
        return 0
    end
    return math.min(1, math.max(0, (currentStanding - minThreshold) / range))
end

--- Compute progress percentage within the current standing bracket.
---@param currentStanding number Current reputation standing
---@param minThreshold number Lower bound of current bracket
---@param maxThreshold number Upper bound of current bracket
---@param decimals number|nil Decimal places (default 1)
---@return number percent Progress 0–100
function RepCalc.ComputePercent(currentStanding, minThreshold, maxThreshold, decimals)
    decimals = decimals or 1
    local ratio = RepCalc.ComputeRatio(currentStanding, minThreshold, maxThreshold)
    local factor = 10 ^ decimals
    return math.floor(ratio * 100 * factor + 0.5) / factor
end

-------------------------------------------------------------------
-- RENOWN (Major Factions)
-------------------------------------------------------------------

--- Compute renown progress ratio (0.0–1.0) for a Major Faction.
---@param earned number Reputation earned towards next renown level
---@param threshold number Reputation required for next renown level
---@return number ratio Progress 0.0–1.0
function RepCalc.ComputeRenownProgress(earned, threshold)
    if not threshold or threshold <= 0 then
        return 0
    end
    return math.min(1, math.max(0, earned / threshold))
end

-------------------------------------------------------------------
-- PARAGON
-------------------------------------------------------------------

--- Compute cyclic paragon progress ratio (0.0–1.0).
---@param currentValue number Current paragon standing value
---@param threshold number Paragon reward threshold
---@return number ratio Cyclic progress 0.0–1.0
function RepCalc.ComputeParagonProgress(currentValue, threshold)
    if not threshold or threshold <= 0 then
        return 0
    end
    return math.min(1, math.max(0, (currentValue % threshold) / threshold))
end

-------------------------------------------------------------------
-- FRIENDSHIP
-------------------------------------------------------------------

--- Compute friendship progress ratio (delegates to ComputeRatio).
---@param standing number Current friendship standing
---@param reactionThreshold number Lower bound of current friendship rank
---@param nextThreshold number Upper bound of current friendship rank
---@return number ratio Progress 0.0–1.0
function RepCalc.ComputeFriendshipProgress(standing, reactionThreshold, nextThreshold)
    return RepCalc.ComputeRatio(standing, reactionThreshold, nextThreshold)
end

-------------------------------------------------------------------
-- NORMALIZE
-------------------------------------------------------------------

--- Normalize any reputation type into a uniform data table.
--- factionType: "standard" | "friendship" | "major" | "paragon"
--- rawData: the raw API data table (varies by type)
---@param factionType string One of "standard", "friendship", "major", "paragon"
---@param rawData table Raw API data for the faction
---@return table|nil normalized Uniform {current, min, max, ratio, percent, name, standingLabel, factionType, isMaxed}
function RepCalc.NormalizeRepData(factionType, rawData)
    if not rawData then
        return nil
    end

    local L = Addon.L
    local current, min, max, ratio, percent, name, standingLabel, isMaxed

    if factionType == "standard" then
        current = rawData.currentStanding or 0
        min = rawData.currentReactionThreshold or 0
        max = rawData.nextReactionThreshold or 0
        name = rawData.name or ""
        isMaxed = (rawData.reaction == 8)
        local gender = UnitSex and UnitSex("player") or 1
        standingLabel = (rawData.reaction and GetText("FACTION_STANDING_LABEL" .. rawData.reaction, gender)) or ""
        ratio = RepCalc.ComputeRatio(current, min, max)
        percent = RepCalc.ComputePercent(current, min, max)

    elseif factionType == "friendship" then
        local nextThreshold = rawData.nextThreshold
        isMaxed = (nextThreshold == nil)
        if isMaxed then
            current = 1
            min = 0
            max = 1
        else
            current = rawData.standing or 0
            min = rawData.reactionThreshold or 0
            max = nextThreshold
        end
        name = rawData.name or ""
        standingLabel = rawData.reaction or ""
        ratio = RepCalc.ComputeRatio(current, min, max)
        percent = RepCalc.ComputePercent(current, min, max)

    elseif factionType == "major" then
        current = rawData.renownReputationEarned or 0
        min = 0
        max = rawData.renownLevelThreshold or 0
        name = rawData.name or ""
        isMaxed = (rawData.renownLevel and rawData.maxLevel and rawData.renownLevel >= rawData.maxLevel) or false
        standingLabel = L and string.format(L["REP_STANDING_RENOWN"], rawData.renownLevel or 0)
            or ("Renown " .. (rawData.renownLevel or 0))
        ratio = RepCalc.ComputeRenownProgress(current, max)
        percent = RepCalc.ComputePercent(current, 0, max)

    elseif factionType == "paragon" then
        local threshold = rawData.threshold or 1
        if threshold <= 0 then
            threshold = 1
        end
        current = (rawData.currentValue or 0) % threshold
        min = 0
        max = threshold
        name = rawData.name or ""
        isMaxed = false
        standingLabel = (L and L["REP_STANDING_PARAGON"]) or "Paragon"
        ratio = RepCalc.ComputeParagonProgress(rawData.currentValue or 0, threshold)
        percent = RepCalc.ComputePercent(current, 0, max)

    else
        return nil
    end

    return {
        current = current,
        min = min,
        max = max,
        ratio = ratio,
        percent = percent,
        name = name,
        standingLabel = standingLabel,
        factionType = factionType,
        isMaxed = isMaxed,
    }
end

return RepCalc
