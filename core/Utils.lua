-- XP Bar Enhanced - Utils.lua
-- General utility functions

---@class Utils
---@field Clone fun(value: any): any Deep clone a value
---@field MergeDefaults fun(target: table, source: table) Merge defaults without overwriting
---@field ShortNumber fun(value: number): string Format number as short string (1.2K, 3.4M)
---@field FormatDuration fun(seconds: number): string Format duration as compact string
---@field FormatTime fun(seconds: number): string Format time in user-friendly format

local Addon = XPBarEnhanced
Addon.Utils = Addon.Utils or {}

local Utils = Addon.Utils

---Route errors through Blizzard's handler when available, fall back to print.
---@param err any
function Utils.ReportError(err)
    if CallErrorHandler then
        CallErrorHandler(err)
    else
        print(tostring(err))
    end
end

---Deep clone a table recursively
---@param value any Value to clone
---@return any cloned Cloned value
local function cloneTable(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, innerValue in pairs(value) do
        copy[key] = cloneTable(innerValue)
    end
    return copy
end

---Merge source defaults into target without overwriting existing values
---@param target table Target table to merge into
---@param source table Source table with defaults
local function mergeDefaults(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return
    end

    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = cloneTable(value)
        elseif type(value) == "table" then
            target[key] = target[key] or {}
            mergeDefaults(target[key], value)
        end
    end
end

---Deep clone a value (tables are cloned recursively)
---@param value any Value to clone
---@return any cloned Deep copy of value
function Utils.Clone(value)
    return cloneTable(value)
end

---Merge defaults from `source` into `target` without overwriting explicit values
---@param target table Target table to merge into
---@param source table Source table with defaults
function Utils.MergeDefaults(target, source)
    mergeDefaults(target, source)
end

---Return a human-friendly short representation of a number (e.g. 1.2K, 3.4M)
---Delegates to TextFormatter:AbbreviateNumber when available for consistent output.
---@param value number The number to format
---@return string formatted Short format string
function Utils.ShortNumber(value)
    if Addon.TextFormatter and Addon.TextFormatter.AbbreviateNumber then
        return Addon.TextFormatter:AbbreviateNumber(value)
    end

    -- Inline fallback for early load before TextFormatter is available
    if not value or value <= 0 then
        return "0"
    end

    if value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fK", value / 1000)
    end

    return BreakUpLargeNumbers(math.floor(value + 0.5))
end

---Format a duration in seconds into compact days/hours/minutes string
---Uses centralized TimeCalculations module
---@param seconds number Duration in seconds
---@return string formatted Compact duration string (e.g. "1d 2h 30m")
function Utils.FormatDuration(seconds)
    local TimeCalc = Addon.TimeCalculations
    return TimeCalc.FormatSmart(seconds)
end

---Format seconds into a user-friendly time string (e.g. "1h 2m")
---Uses centralized TimeCalculations module
---@param seconds number Duration in seconds
---@return string formatted User-friendly time string
function Utils.FormatTime(seconds)
    local TimeCalc = Addon.TimeCalculations
    return TimeCalc.FormatHMS(seconds)
end

---Get a configuration option value with profile-aware fallback
---Delegates to Config:GetOptionValue when available, returns fallback otherwise
---@param key string Configuration key name
---@param fallback any Optional fallback value if key not found
---@return any value Configuration value or fallback
function Utils.GetOptionValue(key, fallback)
    if Addon.Config and Addon.Config.GetOptionValue then
        local value = Addon.Config:GetOptionValue(key)
        if value ~= nil then
            return value
        end
    end
    return fallback
end

---Get a settings table for position/collection data with profile awareness
---Delegates to Config:GetSettingsTable when available, falls back to Addon.db
---@param key string Settings table key (e.g. "barPositions", "secondaryBarPositions")
---@param createIfMissing boolean If true, creates empty table if missing
---@return table|nil settingsTable The requested settings table or nil
function Utils.GetSettingsTable(key, createIfMissing)
    if Addon.Config and Addon.Config.GetSettingsTable then
        return Addon.Config:GetSettingsTable(key, createIfMissing)
    end

    Addon.db = Addon.db or {}
    if Addon.db[key] == nil and createIfMissing then
        Addon.db[key] = {}
    end
    return Addon.db[key]
end

---Safely hide a Blizzard container, deferring to after combat if necessary
---Prevents taint violations by deferring hide operations during combat lockdown
---@param container Frame The Blizzard frame to hide
function Utils.SafeHideContainer(container)
    if not container then return end
    if InCombatLockdown() then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function()
            if container then
                container:Hide()
            end
            f:UnregisterAllEvents()
            f = nil
        end)
    else
        container:Hide()
    end
end

---Convert RGB components to WoW hex color escape sequence
---Used for terminal color rendering and other styled text output
---@param r number Red component (0-1)
---@param g number Green component (0-1)
---@param b number Blue component (0-1)
---@return string escape Hex color escape sequence (e.g. "|cFFRRGGBB")
function Utils.Hex(r, g, b)
    r = math.floor((r or 0) * 255)
    g = math.floor((g or 0) * 255)
    b = math.floor((b or 0) * 255)
    return string.format("|cFF%02X%02X%02X", r, g, b)
end
