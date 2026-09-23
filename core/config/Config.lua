-- XP Bar Enhanced - Config.lua
-- Centralized configuration management and defaults

local Addon = XPBarEnhanced
Addon.Config = Addon.Config or {}

local Config = Addon.Config
local L = Addon.L or {}
local EventNames = Addon.EventNames

local function getActiveProfileTable()
    if Addon.ProfileManager and Addon.ProfileManager.GetActiveProfile then
        local profile = Addon.ProfileManager:GetActiveProfile()
        return type(profile) == "table" and profile or nil
    end
    return nil
end

local function getWriteTargetTable()
    local profile = getActiveProfileTable()
    if profile then
        return profile
    end

    Addon.db = Addon.db or {}
    return Addon.db
end

function Config:GetSettingsStorage()
    return getWriteTargetTable()
end

function Config:GetSettingsTable(key, createIfMissing)
    if not key then
        return nil
    end

    local activeProfile = getActiveProfileTable()
    local value = activeProfile and activeProfile[key]
    
    -- If found in active profile, return it
    if value ~= nil then
        return value
    end

    -- If not creating, fall back to global for read-only access
    if not createIfMissing then
        return Addon.db and Addon.db[key]
    end

    -- If creating, create ONLY in the write target (profile or global)
    -- Do NOT fall back to global for write operations
    local target = getWriteTargetTable()
    target[key] = target[key] or {}
    return target[key]
end

-------------------------------------------------------------------
-- Defaults are extracted to `core/config/defaults.lua` and assigned to `Addon.defaults`.
-------------------------------------------------------------------

-- Export option metadata for UI (still assigned elsewhere)

-- Keys of defaults.lua that are not settings: profile bookkeeping sits beside
-- the settings but is not a profile's to reset.
local NON_SETTING_KEYS = {
    profiles = true,
    characterProfileKeys = true,
}

-- Preferred replacement, in order, for a secondary source this client lacks.
local SECONDARY_SOURCE_FALLBACKS = {"reputation", "profession", "honor", "housing"}

--- Replace a secondary source this client does not offer with one it does.
--- Asks the flavor rather than the live probe: Retail housing only reports
--- itself available once the housing service answers, and a Retail player's
--- choice must not be migrated away before it does.
local function NormalizeSecondarySource(settings)
    local source = type(settings) == "table" and settings.secondaryBarSource
    if not source or Addon:IsFeatureSupported(source) then
        return
    end
    for _, candidate in ipairs(SECONDARY_SOURCE_FALLBACKS) do
        if Addon:IsFeatureSupported(candidate) then
            settings.secondaryBarSource = candidate
            return
        end
    end
end

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

---Initialize configuration state and migrate any classic settings
function Config:Initialize()
    -- Secondary sources are activated by the resolved client feature profile,
    -- not by TOC layout or module presence: every client loads the same
    -- manifest. A source saved on a client that offered it (or by a build that
    -- misdetected this one) is moved to one this client has, in Global and in
    -- every profile.
    NormalizeSecondarySource(Addon.db)
    if Addon.db and type(Addon.db.profiles) == "table" then
        for _, profile in pairs(Addon.db.profiles) do
            NormalizeSecondarySource(profile)
            -- Profiles created before snapshots carried secondary positions
            -- read, and reset, Global's. Give each its own copy of what it
            -- shows today, so nothing moves and the profiles stop sharing.
            if type(profile) == "table" and type(profile.secondaryBarPositions) ~= "table" then
                profile.secondaryBarPositions = Addon.Utils.Clone(Addon.db.secondaryBarPositions or {})
            end
        end
    end

    if Addon and Addon.db then
        -- Prune keys that no longer exist so stale saved values can't resurface
        -- if a same-named option is ever reintroduced. barPosition predates the
        -- per-style barPositions, and delveCompanions is static data that was
        -- merged into saved settings from defaults.
        local removedKeys = {
            "fadeWhenInactive", "fadeDelay", "idleOpacity", "celebrationSound", "goalSound",
            "barPosition", "delveCompanions",
        }
        for _, key in ipairs(removedKeys) do
            Addon.db[key] = nil
        end
        if type(Addon.db.profiles) == "table" then
            for _, profile in pairs(Addon.db.profiles) do
                if type(profile) == "table" then
                    for _, key in ipairs(removedKeys) do
                        profile[key] = nil
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------
-- OPTIONS API
-------------------------------------------------------------------

---Get option metadata for a given option key
function Config:GetOptionDetail(key)
    return self.optionDetails and self.optionDetails[key]
end

---Get the effective option value (falls back to defaults)
function Config:GetOptionValue(key)
    local activeProfile = getActiveProfileTable()
    local value = activeProfile and activeProfile[key]
    if value == nil then
        value = Addon.db and Addon.db[key]
    end
    if value == nil then
        value = Addon.defaults and Addon.defaults[key]
    end
    return value
end

function Config:SetOptionKey(key, value, silent)
    local detail = self.optionDetails and self.optionDetails[key]

    -- For dropdowns, sliders, and other non-boolean options, preserve the actual value
    local newValue
    if detail and (detail.type == "dropdown" or detail.type == "slider") then
        newValue = value
    elseif type(value) == "number" then
        -- Preserve numeric values (e.g., minimap angles, segment counts)
        newValue = value
    else
        newValue = value and true or false
    end

    -- Compare against the raw stored value in the write target, not the
    -- effective value: with a profile active, an effective value inherited
    -- from global/defaults must still be written as a profile override.
    local target = getWriteTargetTable()
    if target[key] == newValue then return end
    target[key] = newValue

    if silent then
        self._pendingOptionKeys = self._pendingOptionKeys or {}
        self._pendingOptionKeys[key] = true
        return true
    end

    self:ApplyOptionSideEffects(key)
    return true
end

-------------------------------------------------------------------
-- COLOR API
-------------------------------------------------------------------

local function colorToHex(color)
    if not color then
        return "FFFFFFFF"
    end

    local function component(value)
        value = math.min(math.max(value or 1, 0), 1)
        return math.floor(value * 255 + 0.5)
    end

    local r = component(color.r or color[1])
    local g = component(color.g or color[2])
    local b = component(color.b or color[3])
    local a = component(color.a or color[4] or 1)

    return string.format("%02X%02X%02X%02X", r, g, b, a)
end

local function parseHexColor(hex)
    if not hex or hex == "" then
        return nil
    end

    hex = string.upper(hex):gsub("^#", "")

    if #hex ~= 6 and #hex ~= 8 then
        return nil
    end
    if not hex:match("^[0-9A-F]+$") then
        return nil
    end

    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = #hex == 8 and tonumber(hex:sub(7, 8), 16) or 255

    if not (r and g and b and a) then
        return nil
    end

    return r / 255, g / 255, b / 255, a / 255, hex
end

function Config:GetColor(key)
    if not key then
        return nil
    end

    local activeProfile = getActiveProfileTable()
    if activeProfile and activeProfile.colors and activeProfile.colors[key] then
        return activeProfile.colors[key]
    end

    if Addon.db and Addon.db.colors and Addon.db.colors[key] then
        return Addon.db.colors[key]
    end

    if Addon.defaults and Addon.defaults.colors and Addon.defaults.colors[key] then
        return Addon.defaults.colors[key]
    end

    return nil
end

--- True when the active write target (the profile, else Global) sets `key`
--- itself rather than inheriting it.
function Config:HasOwnColor(key)
    local target = getWriteTargetTable()
    return (target.colors ~= nil and target.colors[key] ~= nil) and true or false
end

--- Drop the active write target's own `key`, so it inherits again.
function Config:ClearOwnColor(key, silent)
    local target = getWriteTargetTable()
    if target.colors then
        target.colors[key] = nil
    end
    if not silent and Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.COLORS_UPDATED, { event = EventNames.COLORS_UPDATED })
    end
end

function Config:GetDefaultColor(key)
    return Addon.defaults and Addon.defaults.colors and Addon.defaults.colors[key]
end

function Config:GetColorHex(key)
    return colorToHex(self:GetColor(key))
end

function Config:SetColor(key, hex, silent)
    if not key then
        return false, Addon.L and Addon.L["ERR_UNKNOWN_COLOR_TARGET"]
    end

    local r, g, b, a, normalized = parseHexColor(hex)
    if not r then
        return false, Addon.L and Addon.L["ERR_INVALID_COLOR"]
    end
    local target = getWriteTargetTable()
    target.colors = target.colors or {}
    local colorTable = target.colors[key] or {}
    colorTable.r = r
    colorTable.g = g
    colorTable.b = b
    colorTable.a = a
    target.colors[key] = colorTable

    -- Emit a dedicated color update event so views can update only their color previews
    if not silent and Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.COLORS_UPDATED, { event = EventNames.COLORS_UPDATED })
    end

    return true, normalized
end

function Config:ResetColor(key, silent)
    local default = Addon.defaults and Addon.defaults.colors and Addon.defaults.colors[key]
    if not default then
        return false, Addon.L and Addon.L["ERR_NO_DEFAULT_COLOR"]
    end

    local hex = colorToHex(default)
    local success, normalized = self:SetColor(key, hex, true)
    if not success then
        return false, normalized
    end

    if not silent and Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.COLORS_UPDATED, { event = EventNames.COLORS_UPDATED })
    end

    return true, normalized
end

function Config:GetColorOptionByKey(key)
    return self.colorOptionByKey and self.colorOptionByKey[key]
end

function Config:GetColorOptionList()
    return self.colorOptionsList
end

-------------------------------------------------------------------
-- PROFILE API
-------------------------------------------------------------------

function Config:GetActiveProfileName()
    if Addon.ProfileManager and Addon.ProfileManager.GetActiveProfileKey then
        return Addon.ProfileManager:GetActiveProfileKey()
    end
    return nil
end

function Config:GetProfileNames()
    if Addon.ProfileManager and Addon.ProfileManager.GetProfileNames then
        return Addon.ProfileManager:GetProfileNames()
    end
    return {}
end

function Config:NotifyProfileChanged()
    -- Combat lockdown protection: defer UI changes if in combat.
    -- The frame is registered immediately (no timer) so a combat that ends
    -- right away still delivers PLAYER_REGEN_ENABLED, and it is reused so
    -- repeated deferrals never allocate new frames.
    if InCombatLockdown() then
        if not self._deferredProfileChange then
            self._deferredProfileChange = true
            local deferredConfig = self
            local frame = self._profileDeferFrame
            if not frame then
                frame = CreateFrame("Frame")
                self._profileDeferFrame = frame
                frame:SetScript("OnEvent", function()
                    frame:UnregisterAllEvents()
                    deferredConfig._deferredProfileChange = nil
                    deferredConfig:NotifyProfileChanged()
                end)
            end
            frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
        return
    end

    local currentStyle = self:GetOptionValue("barStyle") or ((Addon.defaults and Addon.defaults.barStyle) or "classic")

    if Addon.BarManager and Addon.BarManager.SetStyle then
        Addon.BarManager.currentStyle = nil
        Addon.BarManager:SetStyle(currentStyle)
    end

    if Addon.SecondaryBarManager and Addon.SecondaryBarManager.RefreshForPrimaryStyleChange then
        Addon.SecondaryBarManager:RefreshForPrimaryStyleChange()
    end

    -- The bar frames are cached per style, so sizes, position mode, segments
    -- and the minimap button keep the old profile's values until re-applied.
    self:ReapplyVisualOptions()

    local bar = Addon.BarManager and Addon.BarManager.GetCurrentFrame and Addon.BarManager:GetCurrentFrame()
    if bar and bar.RestorePosition then
        bar:RestorePosition()
    elseif bar and bar.ApplyInitialPosition then
        bar:ApplyInitialPosition()
    end

    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(EventNames.CONFIG_UPDATED, XPBarContextBuilder.BuildContext("CONFIG_UPDATED"))
    end

    if Addon:IsFeatureEnabled("reputation", "EmitUpdate") then
        Addon.ReputationSession:EmitUpdate()
    end

    if Addon.Session and Addon.Session.EmitUpdate then
        Addon.Session:EmitUpdate("XPBAR:BROADCAST_UPDATE")
    end

    if Addon.Stats and Addon.Stats.Update then
        Addon.Stats:Update()
    end
end

function Config:SelectProfile(profileName)
    if not (Addon.ProfileManager and Addon.ProfileManager.SetAssignedProfileKey) then
        return false, "Profile manager unavailable"
    end

    -- Prevent race conditions: block multiple concurrent profile changes
    if self._profileChangingInProgress then
        return false, "Profile change in progress"
    end

    local oldProfile = self:GetActiveProfileName()
    local success, err = Addon.ProfileManager:SetAssignedProfileKey(profileName, false)
    if not success then
        return false, err
    end

    if oldProfile ~= self:GetActiveProfileName() then
        -- Protected so an error while re-applying the profile cannot leave the
        -- guard set and block every later switch.
        self._profileChangingInProgress = true
        xpcall(function()
            self:NotifyProfileChanged()
        end, Addon.Utils.ReportError)
        self._profileChangingInProgress = false
    end

    return true
end

function Config:CreateProfile(name, switchToProfile)
    if not (Addon.ProfileManager and Addon.ProfileManager.CreateProfile) then
        return false, "Profile manager unavailable"
    end

    local success, err = Addon.ProfileManager:CreateProfile(name)
    if not success then
        return false, err
    end

    if switchToProfile == nil or switchToProfile == true then
        return self:SelectProfile(name)
    end

    return true
end

function Config:RenameProfile(oldName, newName)
    if not (Addon.ProfileManager and Addon.ProfileManager.RenameProfile) then
        return false, "Profile manager unavailable"
    end

    local activeProfile = self:GetActiveProfileName()
    local success, err = Addon.ProfileManager:RenameProfile(oldName, newName)
    if not success then
        return false, err
    end

    if activeProfile == oldName then
        self:NotifyProfileChanged()
    end

    return true
end

function Config:DeleteProfile(name)
    if not (Addon.ProfileManager and Addon.ProfileManager.DeleteProfile) then
        return false, "Profile manager unavailable"
    end

    local activeProfile = self:GetActiveProfileName()
    local success, err = Addon.ProfileManager:DeleteProfile(name)
    if not success then
        return false, err
    end

    if activeProfile == name then
        self:NotifyProfileChanged()
    end

    return true
end

-------------------------------------------------------------------
-- SIDE EFFECTS
-------------------------------------------------------------------
-- Everything an option changes outside the config table lives here, so the
-- options panel, readout presets, profile switches, resets and slash commands
-- all get the same reaction from one write.

local function PrimaryBar()
    return Addon.BarManager and Addon.BarManager.GetCurrentFrame and Addon.BarManager:GetCurrentFrame()
end

local function SecondaryBar()
    return Addon.SecondaryBarManager and Addon.SecondaryBarManager.GetCurrentFrame
        and Addon.SecondaryBarManager:GetCurrentFrame()
end

local function CallOn(bar, method, ...)
    if bar and bar[method] then
        bar[method](bar, ...)
    end
end

local function ResizeClassicBars()
    CallOn(PrimaryBar(), "ResizeToConfiguredWidth")
    CallOn(SecondaryBar(), "ResizeToConfiguredWidth")
end

local function ResizeScaledBars()
    CallOn(PrimaryBar(), "ResizeToScale")
    CallOn(SecondaryBar(), "ResizeToScale")
end

local function RepositionPrimarySegments()
    CallOn(PrimaryBar(), "RepositionSegments")
end

local function RepositionRings()
    CallOn(PrimaryBar(), "RepositionSegments")
    CallOn(SecondaryBar(), "QueueReposition")
end

local function RepositionMinimapRing()
    CallOn(PrimaryBar(), "QueueReposition")
    CallOn(SecondaryBar(), "QueueReposition")
end

local function UpdateMinimapButtonCollection()
    CallOn(PrimaryBar(), "UpdateButtonCollection", true)
end

-- Show/Hide rather than MinimapButton:SetEnabled, which writes the option and
-- would re-enter this handler.
local function UpdateMinimapButton()
    local button = Addon.MinimapButton
    if not (button and button.Show and button.Hide) then
        return
    end
    if Config:GetOptionValue("showMinimapButton") then
        button:Show()
    else
        button:Hide()
    end
end

local function UpdateAnimationSettings()
    if Addon.BarManager and Addon.BarManager.UpdateAnimationSettings then
        Addon.BarManager:UpdateAnimationSettings()
    end
end

local function UpdateMilestoneTicks()
    local bar = PrimaryBar()
    if not (bar and bar.UpdateMilestoneTicks and XPBarContextBuilder) then
        return
    end
    local context = XPBarContextBuilder.BuildContext("CONFIG_UPDATED")
    local ratio = 0
    if context and context.xpMax and context.xpMax > 0 then
        ratio = (context.currentXP or 0) / context.xpMax
    end
    bar:UpdateMilestoneTicks(ratio, context)
end

local function UpdateClassicPositionMode()
    local bar = PrimaryBar()
    if bar and bar.UpdatePositionMode and Addon.BarManager.currentStyle == Addon.StyleKeys.classic then
        bar:UpdatePositionMode(Config:GetOptionValue("classicBarDraggable") and "DRAGGABLE" or "STATIC")
    end
end

local function EmitSecondarySourceUpdates(features)
    for _, feature in ipairs(features) do
        if Addon:IsFeatureEnabled(feature, "EmitUpdate") then
            Addon:GetFeatureModule(feature):EmitUpdate()
        end
    end
end

local function EmitReputationAndHousingUpdates()
    EmitSecondarySourceUpdates({"reputation", "housing"})
end

local function EmitAllSecondarySourceUpdates()
    EmitSecondarySourceUpdates({"reputation", "housing", "honor", "profession"})
end

local function RefreshSecondaryBarLayout()
    if Addon.BarManager and Addon.BarManager.SetStyle then
        Addon.BarManager.currentStyle = nil
        Addon.BarManager:SetStyle(Config:GetOptionValue("barStyle"))
    end
    if Addon.SecondaryBarManager and Addon.SecondaryBarManager.RefreshForPrimaryStyleChange then
        Addon.SecondaryBarManager:RefreshForPrimaryStyleChange()
    end
end

-- Time texts need played time; ask for it only if none has arrived yet.
local function EnsureTimePlayedForTimeText()
    if (Config:GetOptionValue("showLevelTimeText") or Config:GetOptionValue("showSessionTimeText"))
        and Addon.Session and Addon.Session.EnsureTimePlayed then
        Addon.Session:EnsureTimePlayed()
    end
end

local function UpdateProfessionSource()
    if Addon:IsFeatureEnabled("profession") then
        if Addon.ProfessionSession.Snapshot then
            Addon.ProfessionSession:Snapshot()
        end
        if Addon.ProfessionSession.EmitUpdate then
            Addon.ProfessionSession:EmitUpdate()
        end
    end
end

local SIDE_EFFECTS = {
    barStyle = function()
        if Addon.BarManager and Addon.BarManager.SetStyle then
            Addon.BarManager:SetStyle(Config:GetOptionValue("barStyle"))
        end
    end,
    maxLevelPrimaryShowsSecondary = RefreshSecondaryBarLayout,
    showSecondaryBar = RefreshSecondaryBarLayout,
    hideCompanionOutsideDelve = EmitReputationAndHousingUpdates,
    secondaryBarSource = EmitAllSecondarySourceUpdates,
    professionSlot = UpdateProfessionSource,
    circularSecondaryFullCircle = EmitReputationAndHousingUpdates,
    minimapArcStartExpanded = EmitReputationAndHousingUpdates,
    minimapArcDisplayAngle = EmitReputationAndHousingUpdates,
    minimapArcIconAngle = EmitReputationAndHousingUpdates,
    showLevelTimeText = EnsureTimePlayedForTimeText,
    showSessionTimeText = EnsureTimePlayedForTimeText,
    classicWidth = ResizeClassicBars,
    classicSegments = ResizeClassicBars,
    classicBarDraggable = UpdateClassicPositionMode,
    flatSize = ResizeScaledBars,
    verticalSize = ResizeScaledBars,
    circularSize = RepositionRings,
    circularScaleCenterText = RepositionRings,
    circularSegments = RepositionPrimarySegments,
    circularUseTexture = RepositionPrimarySegments,
    minimapRingPadding = RepositionMinimapRing,
    minimapRingSegments = RepositionMinimapRing,
    minimapRingSegmentWidth = RepositionMinimapRing,
    minimapRingSegmentHeight = RepositionMinimapRing,
    minimapRingCollectButtons = UpdateMinimapButtonCollection,
    showMinimapButton = UpdateMinimapButton,
    enableAnimations = UpdateAnimationSettings,
    flashOnGain = UpdateAnimationSettings,
    twoPhaseOnLevelUp = UpdateAnimationSettings,
    showMilestoneTicks = UpdateMilestoneTicks,
}

-- Re-applied wholesale when every setting may have changed at once (a profile
-- switch or reset): the cached bar frames keep whatever size and mode they
-- were built with until told otherwise.
local VISUAL_REAPPLY = {
    UpdateClassicPositionMode,
    ResizeClassicBars,
    ResizeScaledBars,
    RepositionRings,
    RepositionMinimapRing,
    UpdateMinimapButtonCollection,
    UpdateMinimapButton,
    UpdateAnimationSettings,
    UpdateMilestoneTicks,
}

local STATS_OPTIONS = {
    showXPPerHourText = true,
    showLevelTimeText = true,
    showSessionTimeText = true,
    showQuestXP = true,
    abbreviateNumbers = true,
    showPercentage = true,
    showRemainingXP = true,
}

function Config:ApplyOptionSideEffects(key, suppressConfigEvent)
    local handler = SIDE_EFFECTS[key]
    if handler then
        handler()
    end

    if not suppressConfigEvent and Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(EventNames.CONFIG_UPDATED, XPBarContextBuilder.BuildContext("CONFIG_UPDATED"))
    end

    if STATS_OPTIONS[key] and Addon.Stats and Addon.Stats.Update then
        Addon.Stats:Update()
    end
end

--- Re-apply every option that shapes a bar frame. Callers emit CONFIG_UPDATED.
function Config:ReapplyVisualOptions()
    for _, apply in ipairs(VISUAL_REAPPLY) do
        apply()
    end
end

function Config:ApplyPendingOptionChanges()
    local pendingKeys = self._pendingOptionKeys
    if not pendingKeys then
        return
    end

    self._pendingOptionKeys = nil

    -- Several keys share a handler (the three animation toggles, say); run
    -- each handler once per batch.
    local ran = {}
    for key in pairs(pendingKeys) do
        local handler = SIDE_EFFECTS[key]
        if not (handler and ran[handler]) then
            if handler then
                ran[handler] = true
            end
            self:ApplyOptionSideEffects(key, true)
        end
    end

    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(EventNames.CONFIG_UPDATED, XPBarContextBuilder.BuildContext("CONFIG_UPDATED"))
    end
end

-------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------

--- Restore the active profile's settings, colors and bar positions to their
--- defaults. Other profiles, character profile assignments and tracked
--- statistics are left alone.
function Config:ResetActiveProfile()
    local target = getWriteTargetTable()
    for key, value in pairs(Addon.defaults or {}) do
        if not NON_SETTING_KEYS[key] then
            target[key] = Addon.Utils.Clone(value)
        end
    end
    -- Secondary bar positions have no default. An empty table rather than nil:
    -- on a profile, nil would fall back to Global's positions.
    target.secondaryBarPositions = {}
    NormalizeSecondarySource(target)

    self:NotifyProfileChanged()
end

function Config:ResetStats()
    if Addon and Addon.db then
        Addon.db.sessionData            = {}
        Addon.db.stats                  = {}
        Addon.db.reputationSessionData  = {}
        Addon.db.housingSessionData     = {}
        Addon.db.honorSessionData       = {}
        Addon.db.professionSessionData  = {}
    end
    if Addon.ContextBuilder and Addon.ContextBuilder.ResetSession then
        Addon.ContextBuilder.ResetSession()
    end
    -- Re-initialize the running session services so their cached _session
    -- tables point at the fresh stores. Only the features this client runs:
    -- a service that was never started (housing off Retail) stays off.
    if Addon.Session and Addon.Session.Initialize then
        Addon.Session:Initialize()
    end
    for _, feature in ipairs({"reputation", "housing", "honor", "profession"}) do
        if Addon:IsFeatureEnabled(feature, "Initialize") then
            Addon:GetFeatureModule(feature):Initialize()
        end
    end
    local stats = Addon.Stats
    if stats and stats.Update then
        stats:Update()
    end
    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(EventNames.CONFIG_UPDATED, XPBarContextBuilder.BuildContext("CONFIG_UPDATED"))
    end
end

Addon.Config = Config
return Config
