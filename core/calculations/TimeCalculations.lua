-- XP Bar Enhanced - Time Calculations
-- Shared time/rate calculation helpers used by ContextBuilder, Session, and Stats

local Addon = XPBarEnhanced
Addon.TimeCalculations = Addon.TimeCalculations or {}

---@class TimeCalculations
local TimeCalc = Addon.TimeCalculations

-------------------------------------------------------------------
-- XP RATE CALCULATIONS
-------------------------------------------------------------------

-- A rate needs at least this much time behind it. One quest turn-in a few
-- seconds into a session would otherwise read as millions of XP an hour and
-- an ETA of seconds. Matches the floor the reputation, housing, honor and
-- profession trackers use.
TimeCalc.MIN_RATE_SECONDS = 60

-- The time divided by never goes under this. A rate taken over the first
-- minutes of a session, a window or a level then reads low rather than high:
-- a burst of quest turn-ins right after a ding no longer reads as 200k XP an
-- hour with a time to level of minutes.
TimeCalc.RATE_FLOOR_SECONDS = 300

-- Seconds of gains each xpRateWindow choice covers. "session" is not listed:
-- it divides the whole session's XP by the session's length.
TimeCalc.RATE_WINDOWS = {
    ["15m"] = 900,
    ["1h"] = 3600,
}
TimeCalc.DEFAULT_RATE_WINDOW = "1h"

--- XP per hour over the level so far: XP into this level divided by the time
--- played at it. 0 below MIN_RATE_SECONDS of level time or with no XP yet.
---@param currentXP number XP into the current level
---@param levelSeconds number|nil Time played at this level
---@return number xpPerHour
function TimeCalc.LevelRate(currentXP, levelSeconds)
    if not levelSeconds or levelSeconds < TimeCalc.MIN_RATE_SECONDS or not currentXP or currentXP <= 0 then
        return 0
    end
    return currentXP / math.max(levelSeconds, TimeCalc.RATE_FLOOR_SECONDS) * 3600
end

--- Calculate XP per hour from the session's gains.
--- The single XP/hour formula: bar texts, the text ticker, tooltips, the
--- Stats window, the data broker feed and the level notifications all come
--- through here, so they cannot disagree.
---
--- With a window ("15m", "1h"), the gains since the window's start (or the
--- session's, if later) divided by the time they cover; with "session", the
--- session's XP divided by its length. Either divisor is floored at
--- RATE_FLOOR_SECONDS. Before the session has MIN_RATE_SECONDS behind it, or
--- before its first gain, there is nothing to measure: `fallbackRate` (the
--- caller's level rate when it trusts the level time, else 0) is returned.
---@param gains table|nil The session's gain history ({ timestamp, amount } entries, oldest first)
---@param sessionStart number|nil Session start timestamp (from time())
---@param sessionXP number|nil Total XP gained in session
---@param window string|nil "15m", "1h" or "session"; anything else reads as the default
---@param fallbackRate number|nil Rate to return while the session has nothing to measure
---@param now number|nil Current time (from time()); defaults to time()
---@return number xpPerHour XP gained per hour
function TimeCalc.CalculateXPPerHour(gains, sessionStart, sessionXP, window, fallbackRate, now)
    now = now or time()
    sessionStart = sessionStart or now
    local elapsed = now - sessionStart

    if elapsed < TimeCalc.MIN_RATE_SECONDS or not sessionXP or sessionXP <= 0 then
        return fallbackRate or 0
    end

    if window == "session" then
        return sessionXP / math.max(elapsed, TimeCalc.RATE_FLOOR_SECONDS) * 3600
    end

    local span = TimeCalc.RATE_WINDOWS[window] or TimeCalc.RATE_WINDOWS[TimeCalc.DEFAULT_RATE_WINDOW]
    local from = math.max(now - span, sessionStart)
    local sum = 0
    if gains then
        -- Newest last: walk back until the window's start.
        for i = #gains, 1, -1 do
            local gain = gains[i]
            if (gain.timestamp or 0) < from then
                break
            end
            sum = sum + (gain.amount or 0)
        end
    end
    return sum / math.max(now - from, TimeCalc.RATE_FLOOR_SECONDS) * 3600
end

--- Calculate time to level at current XP rate
---@param remainingXP number XP needed to level up
---@param xpPerHour number Current XP gain rate per hour
---@return number|nil secondsToLevel Estimated seconds to level, or nil if cannot estimate
function TimeCalc.CalculateTimeToLevel(remainingXP, xpPerHour)
    if not remainingXP or remainingXP <= 0 then
        return 0
    end
    if not xpPerHour or xpPerHour <= 0 then
        return nil -- Cannot estimate
    end

    -- Convert XP/hour to seconds
    return (remainingXP / xpPerHour) * 3600
end

--- Calculate time to level using XP and time values directly
---@param currentXP number Current XP amount
---@param xpMax number XP needed for next level
---@param xpPerHour number Current XP gain rate per hour
---@return number|nil secondsToLevel Estimated seconds to level
function TimeCalc.TimeToLevelFromXP(currentXP, xpMax, xpPerHour)
    local remaining = (xpMax or 0) - (currentXP or 0)
    return TimeCalc.CalculateTimeToLevel(remaining, xpPerHour)
end

-------------------------------------------------------------------
-- DURATION FORMATTING
-------------------------------------------------------------------

--- Format seconds into human-readable duration
---@param seconds number Duration in seconds
---@param compact boolean|nil Use compact format (1h 30m) vs verbose (1 hour 30 minutes)
---@return string formatted Formatted duration string
function TimeCalc.FormatDuration(seconds, compact)
    if not seconds or seconds < 0 then
        return compact and "0s" or "0 seconds"
    end

    seconds = math.floor(seconds)

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if compact then
        if days > 0 then
            return string.format("%dd %dh", days, hours)
        elseif hours > 0 then
            return string.format("%dh %dm", hours, minutes)
        elseif minutes > 0 then
            return string.format("%dm %ds", minutes, secs)
        else
            return string.format("%ds", secs)
        end
    else
        local parts = {}
        if days > 0 then
            table.insert(parts, days .. (days == 1 and " day" or " days"))
        end
        if hours > 0 then
            table.insert(parts, hours .. (hours == 1 and " hour" or " hours"))
        end
        if minutes > 0 then
            table.insert(parts, minutes .. (minutes == 1 and " minute" or " minutes"))
        end
        if #parts == 0 or (secs > 0 and seconds < 60) then
            table.insert(parts, secs .. (secs == 1 and " second" or " seconds"))
        end
        return table.concat(parts, " ")
    end
end

--- Format duration as HH:MM:SS
---@param seconds number Duration in seconds
---@return string formatted Time in HH:MM:SS format
function TimeCalc.FormatHMS(seconds)
    if not seconds or seconds < 0 then
        return "00:00:00"
    end

    seconds = math.floor(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

--- Format duration with smart abbreviation based on magnitude
---@param seconds number Duration in seconds
---@return string formatted Smart-formatted duration
function TimeCalc.FormatSmart(seconds)
    if not seconds or seconds < 0 then
        return "0s"
    end

    seconds = math.floor(seconds)

    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        local m = math.floor(seconds / 60)
        local s = seconds % 60
        if s > 0 then
            return string.format("%dm %ds", m, s)
        else
            return string.format("%dm", m)
        end
    elseif seconds < 86400 then
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        if m > 0 then
            return string.format("%dh %dm", h, m)
        else
            return string.format("%dh", h)
        end
    else
        local d = math.floor(seconds / 86400)
        local h = math.floor((seconds % 86400) / 3600)
        if h > 0 then
            return string.format("%dd %dh", d, h)
        else
            return string.format("%dd", d)
        end
    end
end

-------------------------------------------------------------------
-- SESSION HELPERS
-------------------------------------------------------------------

--- Calculate session duration from start time
---@param sessionStart number Session start timestamp
---@return number duration Session duration in seconds
function TimeCalc.SessionDuration(sessionStart)
    if not sessionStart then
        return 0
    end
    return math.max(0, time() - sessionStart)
end

--- Time played at the current level, carried forward to now: the level time
--- of the last TIME_PLAYED_MSG (or 0 from the ding onward) plus the wall-clock
--- time since. 0 only while no level time is known at all.
---@param realLevelTime number|nil Level time at lastTimePlayedRequest
---@param lastTimePlayedRequest number|nil When realLevelTime was taken
---@return number levelSeconds
function TimeCalc.AdjustedLevelTime(realLevelTime, lastTimePlayedRequest)
    local base = math.max(0, realLevelTime or 0)
    if not lastTimePlayedRequest or lastTimePlayedRequest <= 0 then
        return base
    end
    return base + math.max(0, time() - lastTimePlayedRequest)
end

-------------------------------------------------------------------
-- EXPORT
-------------------------------------------------------------------

return TimeCalc
