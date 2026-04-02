-- XP Bar Enhanced - Companion Calculations
-- Pure stateless calculation helpers for Delve companion progress.
-- The companion uses the Friendship Reputation system internally.
-- No WoW API calls, no side effects.

local Addon = XPBarEnhanced
Addon.CompanionCalculations = Addon.CompanionCalculations or {}

---@class CompanionCalculations
local CompCalc = Addon.CompanionCalculations

-------------------------------------------------------------------
-- GAIN
-------------------------------------------------------------------

--- Compute companion XP gained since last snapshot.
---@param currentXP number Current XP within current companion level
---@param lastXP number Previous XP within the level
---@return number gain Non-negative XP gained
function CompCalc.ComputeGain(currentXP, lastXP)
    return math.max(0, currentXP - lastXP)
end

-------------------------------------------------------------------
-- REMAINING
-------------------------------------------------------------------

--- Compute companion XP remaining to next level.
---@param currentXP number Current XP within current companion level
---@param maxXP number XP required for next level
---@return number remaining Non-negative XP remaining
function CompCalc.ComputeRemaining(currentXP, maxXP)
    return math.max(0, maxXP - currentXP)
end

-------------------------------------------------------------------
-- RATIO / PERCENT
-------------------------------------------------------------------

--- Compute progress ratio (0.0–1.0) within current companion level.
--- Uses raw friendship rep bracket fields:
---   standing          = raw reputation value
---   reactionThreshold = lower bound of current level
---   nextThreshold     = upper bound (nil means max level)
---@param standing number Raw friendship reputation standing
---@param reactionThreshold number Lower bound of current rank
---@param nextThreshold number|nil Upper bound of current rank (nil = max level)
---@return number ratio Progress 0.0–1.0
function CompCalc.ComputeRatio(standing, reactionThreshold, nextThreshold)
    if nextThreshold == nil or nextThreshold == reactionThreshold then
        return 1
    end
    local ratio = (standing - reactionThreshold) / (nextThreshold - reactionThreshold)
    return math.max(0, math.min(1, ratio))
end

--- Compute percentage within current companion level.
---@param standing number Raw friendship reputation standing
---@param reactionThreshold number Lower bound of current rank
---@param nextThreshold number|nil Upper bound of current rank
---@param decimals number|nil Decimal places (default 1)
---@return number percent Progress 0–100
function CompCalc.ComputePercent(standing, reactionThreshold, nextThreshold, decimals)
    local ratio = CompCalc.ComputeRatio(standing, reactionThreshold, nextThreshold)
    local d = decimals or 1
    local factor = 10 ^ d
    return math.floor(ratio * 100 * factor + 0.5) / factor
end

-------------------------------------------------------------------
-- NORMALIZE
-------------------------------------------------------------------

--- Normalize raw friendship reputation and rank data into a uniform
--- companion progress table consumed by CompanionSession and the UI layer.
---
--- friendshipData: result of C_GossipInfo.GetFriendshipReputation(factionID)
--- rankData:       result of C_GossipInfo.GetFriendshipReputationRanks(factionID)
--- companionID:    from C_DelvesUI.GetCompanionInfoForActivePlayer()
--- factionID:      from C_DelvesUI.GetFactionForCompanion()
---@param friendshipData table|nil Raw friendship reputation data
---@param rankData table|nil Raw rank info {currentLevel, maxLevel}
---@param companionID number|nil
---@param factionID number|nil
---@return table normalized Uniform companion data table
function CompCalc.NormalizeCompanionData(friendshipData, rankData, companionID, factionID)
    if not friendshipData then
        return {
            companionID       = companionID or 0,
            factionID         = factionID   or 0,
            name              = "",
            currentLevel      = 0,
            maxLevel          = 0,
            currentXP         = 0,
            maxXP             = 1,
            standing          = 0,
            reactionThreshold = 0,
            nextThreshold     = nil,
            ratio             = 0,
            percent           = 0,
            isMaxLevel        = false,
        }
    end

    local standing          = friendshipData.standing or 0
    local reactionThreshold = friendshipData.reactionThreshold or 0
    local nextThreshold     = friendshipData.nextThreshold
    local currentLevel      = (rankData and rankData.currentLevel) or 0
    local maxLevel          = (rankData and rankData.maxLevel) or 0

    local isMaxLevel = (nextThreshold == nil) or (maxLevel > 0 and currentLevel >= maxLevel)
    local currentXP  = isMaxLevel and 0 or math.max(0, standing - reactionThreshold)
    local maxXP      = isMaxLevel and 1 or math.max(1, nextThreshold - reactionThreshold)

    return {
        companionID       = companionID or 0,
        factionID         = factionID   or 0,
        name              = friendshipData.name or "",
        currentLevel      = currentLevel,
        maxLevel          = maxLevel,
        currentXP         = currentXP,
        maxXP             = maxXP,
        standing          = standing,
        reactionThreshold = reactionThreshold,
        nextThreshold     = nextThreshold,
        ratio             = CompCalc.ComputeRatio(standing, reactionThreshold, nextThreshold),
        percent           = CompCalc.ComputePercent(standing, reactionThreshold, nextThreshold),
        isMaxLevel        = isMaxLevel,
    }
end

return CompCalc
