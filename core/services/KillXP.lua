-- XP Bar Enhanced - KillXP.lua
-- Kills to level, from the game's kill XP lines (CHAT_MSG_COMBAT_XP_GAIN).
-- The lines are matched with patterns built from the client's own
-- COMBATLOG_XPGAIN_* strings, so any client language works. Only a line that
-- names a mob is a kill: quest turn-ins, gathering and exploration ("You gain
-- 120 experience.") are left out. Each kill's base XP (the rested bonus taken
-- off, a tired penalty put back) is kept per character, the last KEEP kills.

local Addon = XPBarEnhanced
Addon.KillXP = Addon.KillXP or {}

local KillXP = Addon.KillXP

-- Kills kept per character.
local KEEP = 20
-- This level's kills are averaged once there are this many; before that, the
-- kills of this level and the NEAR_LEVELS below it are. Kills from further
-- down (before a boost, or a long stretch the addon did not see) say nothing
-- about this level.
local PER_LEVEL = 3
local NEAR_LEVELS = 2

local function IsSecret(value)
    return (issecretvalue and issecretvalue(value)) and true or false
end

-------------------------------------------------------------------
-- PATTERNS
-------------------------------------------------------------------

-- The kill lines, most particular first: the first pattern that matches
-- reads the line. EXHAUSTION1/2 carry a rested bonus, EXHAUSTION4/5 a tired
-- penalty. Arguments, in every locale: 1 the mob, 2 the XP gained, 3 the
-- bonus or penalty, 4 the rest state, 5 the group bonus or raid penalty.
-- A free rest-state capture can take another string's words, so:
-- - a rested kill with a group bonus comes before the plain rested kill;
-- - the group and raid kills come before the plain rested and tired kills
--   (Korean "(%4$s 경험치 보너스 %3$s)" also reads "(파티 경험치 보너스 +30)",
--   the party bonus);
-- - the tired kills come before the rested ones (Russian "(%4$s: %3$s)" also
--   reads "(штраф %4$s: %3$s)", the penalty).
local KILL_STRINGS = {}
local function AddExhaustion(suffix)
    for _, number in ipairs({"4", "5", "1", "2"}) do
        table.insert(KILL_STRINGS, {
            name = "COMBATLOG_XPGAIN_EXHAUSTION" .. number .. suffix,
            kind = (number == "4" or number == "5") and "penalty" or "bonus",
        })
    end
end
local function AddFirstPerson(suffix)
    table.insert(KILL_STRINGS, {name = "COMBATLOG_XPGAIN_FIRSTPERSON" .. suffix, kind = "plain"})
end
AddExhaustion("_GROUP")
AddExhaustion("_RAID")
AddFirstPerson("_GROUP")
AddFirstPerson("_RAID")
AddExhaustion("")
AddFirstPerson("")

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"

---Turn one of the game's format strings into a Lua pattern anchored at both
---ends. %s and %d, plain or positional (%2$d), become captures; the mob's name
---takes anything, a later %s never takes a comma or a bracket. The grammar
---escapes some locales use (|1a;b; and |4a:b:c;) match whatever form the game
---printed. Anything else unknown gives nil rather than a guess.
---@param format string
---@return table|nil built { pattern = string, args = { argument number per capture } }
function KillXP.BuildPattern(format)
    if type(format) ~= "string" or format == "" then
        return nil
    end

    local parts, args = {"^"}, {}
    local nextArg = 1
    local i, len = 1, #format
    while i <= len do
        local c = format:sub(i, i)
        if c == "%" then
            local position, conversion = format:match("^%%(%d+)%$([sd])", i)
            local width = position and (#position + 3) or 2
            if not position then
                conversion = format:sub(i + 1, i + 1)
            end
            if conversion == "%" then
                table.insert(parts, "%%")
            elseif conversion == "s" or conversion == "d" then
                local arg = tonumber(position) or nextArg
                nextArg = nextArg + 1
                table.insert(args, arg)
                if conversion == "d" then
                    table.insert(parts, "(%d+)")
                elseif arg == 1 then
                    -- Greedy and never empty: a grammar escape right after the
                    -- name (Korean "%1$s|1이;가;") would leave a lazy capture empty.
                    table.insert(parts, "(.+)")
                else
                    table.insert(parts, "([^,%(%)%[%]]-)")
                end
            else
                return nil
            end
            i = i + width
        elseif c == "|" then
            local code = format:sub(i + 1, i + 1)
            local stop
            if code == "1" then
                -- |1first;second;
                local first = format:find(";", i + 2, true)
                stop = first and format:find(";", first + 1, true)
            elseif code == "4" then
                -- |4one:few:many;
                stop = format:find(";", i + 2, true)
            end
            if not stop then
                return nil
            end
            table.insert(parts, ".-")
            i = stop + 1
        else
            table.insert(parts, c:find(MAGIC) and ("%" .. c) or c)
            i = i + 1
        end
    end
    table.insert(parts, "$")
    return {pattern = table.concat(parts), args = args}
end

local patterns -- built on the first line, once the game's strings are loaded

local function GetPatterns()
    if patterns then
        return patterns
    end
    patterns = {}
    for _, entry in ipairs(KILL_STRINGS) do
        local format = rawget(_G, entry.name)
        local built = not IsSecret(format) and KillXP.BuildPattern(format)
        if built then
            built.kind = entry.kind
            table.insert(patterns, built)
        end
    end
    return patterns
end

---Drop the built patterns (the next line builds them again from the globals).
function KillXP.ResetPatterns()
    patterns = nil
end

---Read a kill line.
---@param text string
---@return number|nil base The kill's XP without the rested bonus or tired penalty; nil when the line is no kill
---@return number|nil total The XP the line reports
function KillXP.Parse(text)
    if IsSecret(text) or type(text) ~= "string" or text == "" then
        return nil
    end
    for _, entry in ipairs(GetPatterns()) do
        local captures = {text:match(entry.pattern)}
        if captures[1] then
            local values = {}
            for index, arg in ipairs(entry.args) do
                values[arg] = captures[index]
            end
            local total = tonumber(values[2])
            if not values[1] or values[1] == "" or not total or total <= 0 then
                return nil
            end
            local base = total
            if entry.kind ~= "plain" then
                local amount = tonumber((values[3] or ""):match("%d+")) or 0
                base = (entry.kind == "bonus") and (total - amount) or (total + amount)
            end
            if base <= 0 then
                return nil
            end
            return base, total
        end
    end
    return nil
end

-------------------------------------------------------------------
-- COUNTING
-------------------------------------------------------------------

---Kills needed for remainingXP at base XP a kill. Rested XP doubles a kill's
---XP and drains by the bonus, so the pool covers rested/base double kills
---(XToLevel's sum).
---@param remainingXP number
---@param restedXP number
---@param base number
---@return number kills
function KillXP.KillsNeeded(remainingXP, restedXP, base)
    if not remainingXP or remainingXP <= 0 or not base or base <= 0 then
        return 0
    end
    restedXP = math.max(0, restedXP or 0)
    local xp
    if restedXP * 2 >= remainingXP then
        xp = remainingXP / 2
    else
        xp = remainingXP - restedXP
    end
    return math.ceil(xp / base - 1e-9)
end

local function GetSamples()
    local Database = Addon.Database
    if not Database or not Database.GetKillXPData then
        return nil
    end
    local data = Database:GetKillXPData()
    data.samples = data.samples or {}
    return data.samples
end

---Record a kill line. Secret lines and lines that are no kill change nothing.
---@param text string
function KillXP:OnCombatXPGain(text)
    local base = KillXP.Parse(text)
    if not base then
        return
    end
    local samples = GetSamples()
    if not samples then
        return
    end
    table.insert(samples, {level = UnitLevel("player") or 0, base = base})
    while #samples > KEEP do
        table.remove(samples, 1)
    end
end

---The average base XP of a kill: this level's kills once there are PER_LEVEL
---of them, else the kills of this level and the NEAR_LEVELS below it; nil
---when there are none.
---@param level number
---@return number|nil
function KillXP:GetAverage(level)
    local samples = GetSamples()
    if not samples or #samples == 0 then
        return nil
    end
    local sum, count = 0, 0
    local nearSum, nearCount = 0, 0
    for _, kill in ipairs(samples) do
        if kill.level == level then
            sum, count = sum + kill.base, count + 1
        end
        if kill.level and kill.level <= level and kill.level >= level - NEAR_LEVELS then
            nearSum, nearCount = nearSum + kill.base, nearCount + 1
        end
    end
    if count >= PER_LEVEL then
        return sum / count
    end
    if nearCount == 0 then
        return nil
    end
    return nearSum / nearCount
end

---Kills to the next level at the current average, rested XP counted.
---@return number|nil kills nil when not known (no kill yet, max level, XP off)
---@return number|nil average The average base XP of a kill
function KillXP:GetKillsToLevel()
    local level = UnitLevel("player") or 0
    local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel()
    if (maxLevel and level >= maxLevel) or (IsXPUserDisabled and IsXPUserDisabled()) then
        return nil
    end
    local average = self:GetAverage(level)
    if not average then
        return nil
    end
    local remaining = (UnitXPMax("player") or 0) - (UnitXP("player") or 0)
    if remaining <= 0 then
        return nil
    end
    return KillXP.KillsNeeded(remaining, GetXPExhaustion() or 0, average), average
end

return KillXP
