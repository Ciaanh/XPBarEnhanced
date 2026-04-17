-- AddOnLifecycle.lua
-- Lifecycle handlers extracted from XPBarEnhanced.lua

local ADDON_NAME = "XPBarEnhanced"
local Addon = XPBarEnhanced

local eventHandlers = {}
Addon.LifecycleHandlers = eventHandlers

function eventHandlers:OnAddonLoaded(name)
    if name ~= ADDON_NAME then
        return
    end

    -- Fail fast: core modules must be present; missing files indicate a load-order bug
    assert(Addon.Database, "XPBarEnhanced: Database module not loaded (check .toc order)")
    assert(Addon.Config,   "XPBarEnhanced: Config module not loaded (check .toc order)")

    -- Initialize core systems
    Addon.Database:Initialize()
    Addon.Config:Initialize()

    -- Set database reference
    Addon.db = XPBarEnhancedDB or {}

    -- Get XP gain disabled state
    Addon.state.xpGainDisabled = Addon.Database:IsXPGainDisabled()

    -- Print loaded message
    print(Addon.L["ADDON_LOADED"])
end

function eventHandlers:OnPlayerLogin()
    -- Initialize session
    if Addon.Session and Addon.Session.Initialize then
        Addon.Session:Initialize()
    end

    -- Initialize Reputation session
    if Addon.ReputationSession and Addon.ReputationSession.Initialize then
        Addon.ReputationSession:Initialize()
    end

    -- Initialize features
    local stats = Addon.Stats
    if stats and stats.Initialize then
        stats:Initialize()
    end

    -- Initialize XP bar manager / legacy XPBar shim.
    if Addon.BarManager and Addon.BarManager.Initialize then
        Addon.BarManager:Initialize()
    end

    -- Initialize Secondary Bar Manager
    if Addon.SecondaryBarManager and Addon.SecondaryBarManager.Initialize then
        Addon.SecondaryBarManager:Initialize()
    end

    -- Initialize Minimap Button
    if Addon.MinimapButton and Addon.MinimapButton.Initialize then
        Addon.MinimapButton:Initialize()
    end

    local options = Addon.Options
    if options and options.Initialize then
        options:Initialize()
    end

end

function eventHandlers:OnPlayerLogout()
    if Addon.BarManager and Addon.BarManager.Shutdown then
        Addon.BarManager:Shutdown()
    end
end

function eventHandlers:OnPlayerEnteringWorld(isInitialLogin, isReloadingUI)
    if Addon.Session and Addon.Session.EmitUpdate then
        Addon.Session:EmitUpdate("PLAYER_ENTERING_WORLD")
    end

    C_Timer.After(0, function()
        if Addon.BarManager and Addon.BarManager.SetStyle then
            local db = Addon.db or {}
            local defaultStyle = (Addon.defaults and Addon.defaults.barStyle) or "classic"
            Addon.BarManager.currentStyle = nil
            Addon.BarManager:SetStyle(db.barStyle or defaultStyle)
        end

        if Addon.BarManager and Addon.BarManager.ApplyDefaultXPBarVisibility then
            Addon.BarManager:ApplyDefaultXPBarVisibility()
        end
        if Addon.SecondaryBarManager and Addon.SecondaryBarManager.ApplyDefaultReputationBarVisibility then
            Addon.SecondaryBarManager:ApplyDefaultReputationBarVisibility()
        end
    end)
end

function eventHandlers:OnPlayerMaxLevelUpdate()
    if Addon.BarManager and Addon.BarManager.SetStyle then
        local db = Addon.db or {}
        Addon.BarManager.currentStyle = nil
        Addon.BarManager:SetStyle(db.barStyle or "classic")
    end
end

function eventHandlers:OnEnableXPGain()
    Addon.state.xpGainDisabled = false

    if Addon.Database and Addon.Database.SetXPGainDisabled then
        Addon.Database:SetXPGainDisabled(false)
    end

    if Addon.BarManager and Addon.BarManager.SetStyle then
        local db = Addon.db or {}
        Addon.BarManager.currentStyle = nil
        Addon.BarManager:SetStyle(db.barStyle or "classic")
    end
end

function eventHandlers:OnDisableXPGain()
    Addon.state.xpGainDisabled = true

    if Addon.Database and Addon.Database.SetXPGainDisabled then
        Addon.Database:SetXPGainDisabled(true)
    end

    if Addon.BarManager and Addon.BarManager.SetStyle then
        Addon.BarManager.currentStyle = nil
        Addon.BarManager:SetStyle("none")
    end
end

return eventHandlers
