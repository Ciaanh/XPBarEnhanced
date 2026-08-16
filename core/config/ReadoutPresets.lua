-- ReadoutPresets.lua
-- Named starting points for the boolean half of the options panel.
--
-- A new player has no path from "I want a minimal bar" to the individual
-- checkboxes that produce one. These presets give three such paths.
--
-- Scope: a preset owns EVERY boolean scalar in defaults.lua (see PRESET_KEYS),
-- not just the readout ones, and "Custom" detection watches that same set.
-- Applying a preset therefore normalises the whole boolean surface to a known
-- state -- including settings the player may have tuned deliberately -- and
-- flipping any one of them switches the label to Custom. That is the documented
-- trade-off of whole-panel scope; the alternative was to own only the 13 readout
-- keys and let the other 22 drift independently.
--
-- The three presets differ only in the 13 readout keys. The remaining 22 are
-- pinned to their defaults.lua values in every preset, so switching preset never
-- silently hides the minimap button or unlocks the bar.

local Addon = XPBarEnhanced

Addon.ReadoutPresets = Addon.ReadoutPresets or {}
local ReadoutPresets = Addon.ReadoutPresets

-- Every boolean scalar in defaults.lua. Presets write all of these; Custom
-- detection compares all of these. Keep in sync with defaults.lua.
local PRESET_KEYS = {
    -- readout keys: the 13 the presets actually differ on
    "showLevelText",
    "showXPText",
    "showPercentage",
    "showRemainingXP",
    "showQuestPercent",
    "showXPPerHourText",
    "showLevelTimeText",
    "showSessionTimeText",
    "showTimeToLevelText",
    "showMilestoneTicks",
    "showCompleteQuestOverlay",
    "showIncompleteQuestOverlay",
    "showRestedOverlay",
    -- remaining boolean surface: identical in every preset
    "showSecondaryBar",
    "hideCompanionOutsideDelve",
    "secondaryBarsAttached",
    "maxLevelPrimaryShowsSecondary",
    "barLocked",
    "circularUseTexture",
    "circularScaleCenterText",
    "circularSecondaryFullCircle",
    "minimapRingCollectButtons",
    "minimapArcStartExpanded",
    "showQuestXP",
    "resetOnReload",
    "abbreviateNumbers",
    "enableAnimations",
    "flashOnGain",
    "twoPhaseOnLevelUp",
    "levelUpCelebration",
    "goalNotifications",
    "enableDataBrokerFeed",
    "classicBarDraggable",
    "showMinimapButton",
    "terminalUseCustomColors",
}

-- PRESET_KEYS is every boolean scalar in defaults.lua. Enum and integer options
-- are out of scope by type: presets decide what the bar SAYS, not what one
-- style LOOKS like.

-- The 22 non-readout keys, pinned to their defaults.lua values.
local SHARED = {
    showSecondaryBar = false,
    hideCompanionOutsideDelve = false,
    secondaryBarsAttached = true,
    maxLevelPrimaryShowsSecondary = false,
    barLocked = false,
    circularUseTexture = true,
    circularScaleCenterText = false,
    circularSecondaryFullCircle = false,
    minimapRingCollectButtons = false,
    minimapArcStartExpanded = false,
    showQuestXP = true,
    resetOnReload = false,
    abbreviateNumbers = true,
    enableAnimations = true,
    flashOnGain = true,
    twoPhaseOnLevelUp = true,
    levelUpCelebration = true,
    goalNotifications = true,
    enableDataBrokerFeed = true,
    classicBarDraggable = true,
    showMinimapButton = true,
    terminalUseCustomColors = false,
}

--- Build a full preset from the shared base plus its readout overrides
local function buildPreset(readout)
    local preset = {}
    for key, value in pairs(SHARED) do
        preset[key] = value
    end
    for key, value in pairs(readout) do
        preset[key] = value
    end
    return preset
end

local presets = {
    -- Percentage only: one number on the bar, nothing beneath it.
    minimal = buildPreset({
        showLevelText = false,
        showXPText = false,
        showPercentage = true,
        showRemainingXP = false,
        showQuestPercent = false,
        showXPPerHourText = false,
        showLevelTimeText = false,
        showSessionTimeText = false,
        showTimeToLevelText = false,
        showMilestoneTicks = false,
        showCompleteQuestOverlay = true,
        showIncompleteQuestOverlay = false,
        showRestedOverlay = true,
    }),
    -- The shipped defaults, unchanged.
    standard = buildPreset({
        showLevelText = true,
        showXPText = true,
        showPercentage = true,
        showRemainingXP = true,
        showQuestPercent = true,
        showXPPerHourText = true,
        showLevelTimeText = true,
        showSessionTimeText = true,
        showTimeToLevelText = true,
        showMilestoneTicks = false,
        showCompleteQuestOverlay = true,
        showIncompleteQuestOverlay = false,
        showRestedOverlay = true,
    }),
    -- Standard plus milestone ticks and the incomplete-quest overlay.
    leveller = buildPreset({
        showLevelText = true,
        showXPText = true,
        showPercentage = true,
        showRemainingXP = true,
        showQuestPercent = true,
        showXPPerHourText = true,
        showLevelTimeText = true,
        showSessionTimeText = true,
        showTimeToLevelText = true,
        showMilestoneTicks = true,
        showCompleteQuestOverlay = true,
        showIncompleteQuestOverlay = true,
        showRestedOverlay = true,
    }),
}

-- Display order for the preset buttons
local PRESET_ORDER = {"minimal", "standard", "leveller"}

ReadoutPresets.KEYS = PRESET_KEYS
ReadoutPresets.ORDER = PRESET_ORDER
ReadoutPresets.CUSTOM = "custom"

---@param name string|nil
---@return table|nil preset Mapped key/value pairs, or nil for an unknown name
function ReadoutPresets:Get(name)
    return name and presets[name] or nil
end

---True when `key` is one of the keys a preset owns
---@param key string
---@return boolean
function ReadoutPresets:Owns(key)
    for _, owned in ipairs(PRESET_KEYS) do
        if owned == key then
            return true
        end
    end
    return false
end

---Name of the preset the current config matches, or "custom"
---@return string
function ReadoutPresets:Detect()
    local Config = Addon.Config
    if not Config or not Config.GetOptionValue then
        return self.CUSTOM
    end

    for _, name in ipairs(PRESET_ORDER) do
        local preset = presets[name]
        local matches = true
        for _, key in ipairs(PRESET_KEYS) do
            local current = Config:GetOptionValue(key) and true or false
            if current ~= (preset[key] and true or false) then
                matches = false
                break
            end
        end
        if matches then
            return name
        end
    end

    return self.CUSTOM
end

---Write a preset's keys in one batch (a single CONFIG_UPDATED) and record it
---@param name string One of PRESET_ORDER
---@return boolean applied
function ReadoutPresets:Apply(name)
    local preset = presets[name]
    local Config = Addon.Config
    if not preset or not Config or not Config.SetOptionKey then
        return false
    end

    for _, key in ipairs(PRESET_KEYS) do
        Config:SetOptionKey(key, preset[key], true)
    end
    -- Recorded before applying so consumers that react to CONFIG_UPDATED already
    -- see the new preset name rather than the stale one.
    Config:SetOptionKey("readoutPreset", name, true)
    Config:ApplyPendingOptionChanges()

    return true
end

---Re-evaluate the stored preset name after an individual toggle changed
---@return string name The preset name now in effect ("custom" when it diverges)
function ReadoutPresets:Resync()
    local Config = Addon.Config
    local name = self:Detect()
    if Config and Config.SetOptionKey and Config:GetOptionValue("readoutPreset") ~= name then
        Config:SetOptionKey("readoutPreset", name, true)
    end
    return name
end

return ReadoutPresets
