-- XP Bar Enhanced - XP Calculations
-- Shared XP calculation helpers used by ContextBuilder and Session

local Addon = XPBarEnhanced
Addon.XPCalculations = Addon.XPCalculations or {}

---@class XPCalculations
local XPCalc = Addon.XPCalculations

-------------------------------------------------------------------
-- XP GAIN COMPUTATION
-------------------------------------------------------------------

--- Compute XP gained between two snapshots, handling level-up wrap-around
---@param currentXP number Current XP amount
---@param currentMax number Current level's max XP
---@param lastXP number Previous XP snapshot
---@param lastMax number Previous level's max XP
---@param lastLevel number|nil Previous player level snapshot (optional)
---@param currentLevel number|nil Current player level (optional)
---@return number xpGained Amount of XP gained
---@return boolean didLevelUp Whether a level-up occurred
---@return boolean ambiguousDecrease XP fell with no level change and no xpMax change
function XPCalc.ComputeGain(currentXP, currentMax, lastXP, lastMax, lastLevel, currentLevel)
    local xpGained = 0
    local didLevelUp = false
    local ambiguousDecrease = false

    if lastLevel and currentLevel and currentLevel > lastLevel then
        -- Level-up detected from level snapshots (works even when consecutive
        -- levels share the same xpMax). Intermediate levels' xpMax is unknowable
        -- after the fact; per-level PLAYER_LEVEL_UP accounting in Session is the
        -- primary correctness path for multi-level jumps.
        didLevelUp = true
        xpGained = (lastMax - lastXP) + currentXP
    elseif lastMax and currentMax and lastMax ~= currentMax then
        -- Fallback level-up detection when level snapshots are not supplied:
        -- xpMax changed (new level has different XP requirement)
        didLevelUp = true
        -- Level-up occurred: XP gained = (old max - old current) + new current
        xpGained = (lastMax - lastXP) + currentXP
    elseif currentXP >= lastXP then
        -- Normal XP gain (same level)
        xpGained = currentXP - lastXP
    else
        -- currentXP < lastXP, xpMax unchanged, level snapshots unchanged. Two
        -- causes are indistinguishable from here:
        --   (a) a level boundary where PLAYER_XP_UPDATE beat UnitLevel and the two
        --       consecutive levels happen to share an xpMax -- a whole level's
        --       remainder is at stake; or
        --   (b) a genuine data reset, where treating it as a wrap would invent
        --       (lastMax - lastXP) + currentXP of XP that was never earned.
        -- Credit nothing here and report the ambiguity. Session resolves it by
        -- waiting to see whether PLAYER_LEVEL_UP follows.
        xpGained = 0
        ambiguousDecrease = true
    end

    -- Third value is additive: existing two-value call sites are unaffected
    -- because Lua discards extra returns.
    return xpGained, didLevelUp, ambiguousDecrease
end

--- Compute XP remaining to reach next level
---@param currentXP number Current XP amount
---@param xpMax number XP needed for next level
---@return number remainingXP XP needed to level up
function XPCalc.ComputeRemaining(currentXP, xpMax)
    return math.max(0, (xpMax or 0) - (currentXP or 0))
end

--- Compute current XP as a ratio (0.0 - 1.0)
---@param currentXP number Current XP amount
---@param xpMax number XP needed for next level
---@return number ratio Progress ratio (0.0 - 1.0)
function XPCalc.ComputeRatio(currentXP, xpMax)
    if not xpMax or xpMax <= 0 then
        return 0
    end
    return math.min(1, math.max(0, (currentXP or 0) / xpMax))
end

--- Compute XP percentage with configurable decimal places
---@param currentXP number Current XP amount
---@param xpMax number XP needed for next level
---@param decimals number|nil Number of decimal places (default 1)
---@return number percentage XP progress as percentage
function XPCalc.ComputePercent(currentXP, xpMax, decimals)
    decimals = decimals or 1
    local ratio = XPCalc.ComputeRatio(currentXP, xpMax)
    local multiplier = 10 ^ decimals
    return math.floor(ratio * 100 * multiplier + 0.5) / multiplier
end

-------------------------------------------------------------------
-- RESTED XP CALCULATIONS
-------------------------------------------------------------------

--- Check if player is fully rested (150% of level XP)
---@param restedXP number Current rested XP amount
---@param xpMax number XP needed for next level
---@return boolean isFullyRested True if rested XP >= 150% of level
function XPCalc.IsFullyRested(restedXP, xpMax)
    if not restedXP or not xpMax or xpMax <= 0 then
        return false
    end
    return restedXP >= (1.5 * xpMax)
end

--- Compute rested XP as percentage of level
---@param restedXP number Current rested XP amount
---@param xpMax number XP needed for next level
---@return number percent Rested XP as percentage (max 150%)
function XPCalc.RestedPercent(restedXP, xpMax)
    if not restedXP or not xpMax or xpMax <= 0 then
        return 0
    end
    return math.min(150, (restedXP / xpMax) * 100)
end

--- Compute how much rested XP extends beyond current XP position
---@param currentXP number Current XP amount
---@param restedXP number Current rested XP amount
---@param xpMax number XP needed for next level
---@return number restedEndRatio Ratio where rested bar should end (0.0 - 1.0, capped at current level)
function XPCalc.RestedEndRatio(currentXP, restedXP, xpMax)
    if not restedXP or restedXP <= 0 or not xpMax or xpMax <= 0 then
        return 0
    end
    local restedEnd = (currentXP or 0) + restedXP
    return math.min(1, restedEnd / xpMax)
end

-------------------------------------------------------------------
-- QUEST XP CALCULATIONS
-------------------------------------------------------------------

--- Compute quest XP as ratio of level
---@param questXP number Total quest XP available
---@param xpMax number XP needed for next level
---@return number ratio Quest XP as ratio (0.0 - 1.0)
function XPCalc.QuestXPRatio(questXP, xpMax)
    if not questXP or not xpMax or xpMax <= 0 then
        return 0
    end
    return math.min(1, questXP / xpMax)
end

--- Compute where quest overlay should start and end
---@param currentXP number Current XP amount
---@param questXP number Quest XP to overlay
---@param xpMax number XP needed for next level
---@return number startRatio Start position ratio
---@return number endRatio End position ratio (capped at 1.0)
function XPCalc.QuestOverlayRange(currentXP, questXP, xpMax)
    if not xpMax or xpMax <= 0 then
        return 0, 0
    end
    local startRatio = (currentXP or 0) / xpMax
    local endRatio = math.min(1, ((currentXP or 0) + (questXP or 0)) / xpMax)
    return startRatio, endRatio
end

-------------------------------------------------------------------
-- EXPORT
-------------------------------------------------------------------

return XPCalc
