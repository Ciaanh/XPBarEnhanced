-- XP Bar Enhanced - Config.lua
-- Centralized configuration management and defaults

local Addon = XPBarEnhanced
Addon.Config = Addon.Config or {}

local Config = Addon.Config
local L = Addon.L or {}
local EventNames = Addon.EventNames

local function getActiveProfileTable()
    if Addon.ProfileManager and Addon.ProfileManager.GetActiveProfile then
        return Addon.ProfileManager:GetActiveProfile()
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

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

---Initialize configuration state and migrate any classic settings
function Config:Initialize()
    -- Configuration is now managed by Database module
    -- Migrate single barPosition to per-style barPositions if needed
    if Addon and Addon.db then
        if not Addon.db.barPositions then
            -- If user has an existing single position, copy it to all styles as a sensible default
            if Addon.db.barPosition then
                Addon.db.barPositions = {
                    classic = Addon.db.barPosition,
                    flat = Addon.db.barPosition,
                    vertical = Addon.db.barPosition,
                    circular = Addon.db.barPosition,
                    minimap_ring = Addon.db.barPosition
                }
            else
                -- Ensure table exists so code can write per-style entries
                Addon.db.barPositions = {}
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

    local oldValue = self:GetOptionValue(key)
    if oldValue == newValue then return end
    local target = getWriteTargetTable()
    target[key] = newValue

    self:ApplyOptionSideEffects(key)
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
    if Addon.EventBus and Addon.EventBus.Emit then
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

    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(EventNames.COLORS_UPDATED, { event = EventNames.COLORS_UPDATED })
    end

    return true, normalized
end

function Config:GetColorOption(target)
    if not target then
        return nil
    end
    return self.colorOptionMap and self.colorOptionMap[string.lower(target)]
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
    -- Combat lockdown protection: defer UI changes if in combat
    if InCombatLockdown() then
        if not self._deferredProfileChange then
            self._deferredProfileChange = true
            local deferredConfig = self
            C_Timer.After(0.1, function()
                -- Register for combat end event
                local frame = CreateFrame("Frame")
                frame:RegisterEvent("PLAYER_REGEN_ENABLED")
                frame:SetScript("OnEvent", function()
                    frame:UnregisterAllEvents()
                    deferredConfig._deferredProfileChange = nil
                    deferredConfig:NotifyProfileChanged()
                end)
            end)
        end
        return
    end

    local currentStyle = self:GetOptionValue("barStyle") or ((Addon.defaults and Addon.defaults.barStyle) or "classic")

    if Addon.BarManager and Addon.BarManager.SetStyle then
        Addon.BarManager.currentStyle = nil
        Addon.BarManager:SetStyle(currentStyle)

        local bar = Addon.BarManager.GetCurrentFrame and Addon.BarManager:GetCurrentFrame() or nil
        if bar and bar.UpdatePositionMode and currentStyle == "classic" then
            local newMode = self:GetOptionValue("classicBarDraggable") and "DRAGGABLE" or "STATIC"
            bar:UpdatePositionMode(newMode)
        end
        if bar and bar.RestorePosition then
            bar:RestorePosition()
        elseif bar and bar.ApplyInitialPosition then
            bar:ApplyInitialPosition()
        end
        if bar and bar.RepositionSegments then
            bar:RepositionSegments()
        end
    end

    if Addon.SecondaryBarManager and Addon.SecondaryBarManager.RefreshForPrimaryStyleChange then
        Addon.SecondaryBarManager:RefreshForPrimaryStyleChange()
    end

    if Addon.MinimapButton and Addon.MinimapButton.SetEnabled then
        Addon.MinimapButton:SetEnabled(self:GetOptionValue("showMinimapButton") and true or false)
    end

    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(EventNames.CONFIG_UPDATED, XPBarContextBuilder.BuildContext("CONFIG_UPDATED"))
    end

    if Addon.ReputationSession and Addon.ReputationSession.EmitUpdate then
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
        self._profileChangingInProgress = true
        self:NotifyProfileChanged()
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

function Config:ApplyOptionSideEffects(key)
    -- Apply primary bar style switch BEFORE emitting CONFIG_UPDATED so that
    -- secondary bars can attach to the new frame in the same event cycle.
    if key == "barStyle" then
        local newStyle = self:GetOptionValue("barStyle")
        if Addon.BarManager and Addon.BarManager.SetStyle then
            Addon.BarManager:SetStyle(newStyle)
        end
    end

    -- Emit a config-level event for fine-grained subscribers; also leave broadcast for compatibility
    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        Addon.EventBus:Emit(EventNames.CONFIG_UPDATED, XPBarContextBuilder.BuildContext("CONFIG_UPDATED"))
    end
    -- XP bars subscribe to CONFIG_UPDATED directly; avoid duplicate domain broadcasts.

    if key == "hideCompanionOutsideDelve" then
        -- ReputationSession owns reputation context construction.
        if Addon.ReputationSession and Addon.ReputationSession.EmitUpdate then
            Addon.ReputationSession:EmitUpdate()
        end
    end

    if key == "circularSecondaryFullCircle" or key == "minimapArcStartExpanded"
       or key == "minimapArcDisplayAngle" or key == "minimapArcIconAngle" then
        if Addon.ReputationSession and Addon.ReputationSession.EmitUpdate then
            Addon.ReputationSession:EmitUpdate()
        end
    end

    -- Request time played if time text options enabled
    if key == "showLevelTimeText" or key == "showSessionTimeText" then
        local session = Addon.db.sessionData
        if
            session and (session.lastTimePlayedRequest or 0) == 0 and
                (self:GetOptionValue("showLevelTimeText") or self:GetOptionValue("showSessionTimeText"))
         then
            if Addon.Session and Addon.Session.RequestTimePlayed then
                Addon.Session:RequestTimePlayed()
            end
        end
    end

    -- Stats options that require refresh
    local statsOptions = {
        "showXPPerHourText",
        "showLevelTimeText",
        "showSessionTimeText",
        "showQuestXP",
        "abbreviateNumbers",
        "showPercentage",
        "showRemainingXP"
    }

    local needsStatsRefresh = false
    for _, optionKey in ipairs(statsOptions) do
        if key == optionKey then
            needsStatsRefresh = true
            break
        end
    end

    if needsStatsRefresh then
        local stats = Addon.Stats
        if stats and stats.Update then
            stats:Update()
        end
    end

    -- Classic bar draggable mode changed
    if key == "classicBarDraggable" then
        local currentStyle = self:GetOptionValue("barStyle")
        if currentStyle == "classic" and Addon.BarManager and Addon.BarManager.GetCurrentFrame then
            local bar = Addon.BarManager:GetCurrentFrame()
            if bar and bar.UpdatePositionMode then
                local newMode = self:GetOptionValue("classicBarDraggable") and "DRAGGABLE" or "STATIC"
                bar:UpdatePositionMode(newMode)
            end
        end
    end
end

-------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------

function Config:ShowHelp()
    print("|cFF00FF00" .. Addon.L["ADDON_NAME"] .. " Commands:|r")
    print("  |cFFFFD700/xpbe|r or |cFFFFD700/xpbe help|r - Show this help")
    print("  |cFFFFD700/xpbe stats|r - Toggle stats window")
    print("    (Ctrl + Click the XP bar for quick access)")
    print("    (Alt + Click the XP bar to open options)")
    print("  |cFFFFD700/xpbe options|r - Open the in-game options panel")
    print("     Customize colors and features from the options panel.")
    print("  |cFFFFD700/xpbe reset|r - Reset all settings to defaults")
    print("  |cFFFFD700/xpbe resetstats|r - Clear all tracked statistics")
    print("  |cFFFFD700/xpbe style <none|classic|flat|vertical|circular|minimap_ring|terminal>|r - Change bar style")
end

function Config:Reset()
    -- Wipe saved-variables and reinitialize database
    XPBarEnhancedDB = {}
    if Addon.Database and Addon.Database.Initialize then
        Addon.Database:Initialize()
    end
    -- Emit config change so UI updates
    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        local ctx = XPBarContextBuilder.BuildContext("CONFIG_UPDATED")
        Addon.EventBus:Emit(EventNames.CONFIG_UPDATED, ctx)
    end
    if Addon.Session and Addon.Session.EmitUpdate then
        Addon.Session:EmitUpdate("XPBAR:BROADCAST_UPDATE")
    end
end

function Config:ResetStats()
    if Addon and Addon.db then
        Addon.db.sessionData            = {}
        Addon.db.stats                  = {}
        Addon.db.reputationSessionData  = {}
    end
    if Addon.ContextBuilder and Addon.ContextBuilder.ResetSession then
        Addon.ContextBuilder.ResetSession()
    end
    if Addon.Session and Addon.Session.Initialize then
        Addon.Session:Initialize()
    end
    if Addon.ReputationSession and Addon.ReputationSession.Initialize then
        Addon.ReputationSession:Initialize()
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
