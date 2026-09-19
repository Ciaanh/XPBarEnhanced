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

    -- Always initialize saved-variable state first so profile/settings survive
    -- logout/login even while startup is intentionally held off by the manual
    -- enable gate. The UI should stay dormant until /xpbe enable, but config
    -- data must still be present.
    assert(Addon.Database, "XPBarEnhanced: Database module not loaded (check .toc order)")
    assert(Addon.Config,   "XPBarEnhanced: Config module not loaded (check .toc order)")
    assert(Addon.ProfileManager, "XPBarEnhanced: ProfileManager module not loaded (check .toc order)")

    Addon.Database:Initialize()
    Addon.ProfileManager:Initialize()
    Addon.Config:Initialize()

    if not Addon.enabled then
        return
    end

    -- Get XP gain disabled state
    Addon.state.xpGainDisabled = Addon.Database:IsXPGainDisabled()

    -- Print loaded message
    print(Addon.L["ADDON_LOADED"])
end

function eventHandlers:OnPlayerLogin()
    if not Addon.enabled then
        return
    end

    if Addon.Session and Addon.Session.Initialize then
        Addon.Session:Initialize()
    end

    if Addon:IsFeatureEnabled("reputation", "Initialize") then
        Addon.ReputationSession:Initialize()
    end

    if Addon:IsFeatureEnabled("housing", "Initialize") then
        Addon.HousingSession:Initialize()
    end

    if Addon:IsFeatureEnabled("honor", "Initialize") then
        Addon.HonorSession:Initialize()
    end

    if Addon:IsFeatureEnabled("profession", "Initialize") then
        Addon.ProfessionSession:Initialize()
    end

    if Addon.GoalTracker and Addon.GoalTracker.Initialize then
        Addon.GoalTracker:Initialize()
    end

    if Addon.DataBrokerFeed and Addon.DataBrokerFeed.Initialize then
        Addon.DataBrokerFeed:Initialize()
    end

    local stats = Addon.Stats
    if stats and stats.Initialize then
        stats:Initialize()
    end

    if Addon.BarManager and Addon.BarManager.Initialize then
        Addon.BarManager:Initialize()
    end

    if Addon.SecondaryBarManager and Addon.SecondaryBarManager.Initialize then
        Addon.SecondaryBarManager:Initialize()
    end

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
    if not Addon.enabled then
        return
    end

    if Addon.Session and Addon.Session.EmitUpdate then
        Addon.Session:EmitUpdate("PLAYER_ENTERING_WORLD")
    end

    if not Addon._changelogChecked then
        Addon._changelogChecked = true
        if Addon.Changelog and Addon.Changelog.CheckForUpdates then
            Addon.Changelog:CheckForUpdates()
        end
    end

end

function eventHandlers:OnPlayerMaxLevelUpdate()
    if Addon.BarManager and Addon.BarManager.SetStyle then
        local configuredStyle = "classic"
        if Addon.Config and Addon.Config.GetOptionValue then
            configuredStyle = Addon.Config:GetOptionValue("barStyle") or "classic"
        else
            local db = Addon.db or {}
            configuredStyle = db.barStyle or "classic"
        end
        Addon.BarManager.currentStyle = nil
        Addon.BarManager:SetStyle(configuredStyle)
    end
end

function eventHandlers:OnEnableXPGain()
    Addon.state.xpGainDisabled = false

    if Addon.Database and Addon.Database.SetXPGainDisabled then
        Addon.Database:SetXPGainDisabled(false)
    end

    if Addon.BarManager and Addon.BarManager.SetStyle then
        local configuredStyle = "classic"
        if Addon.Config and Addon.Config.GetOptionValue then
            configuredStyle = Addon.Config:GetOptionValue("barStyle") or "classic"
        else
            local db = Addon.db or {}
            configuredStyle = db.barStyle or "classic"
        end
        Addon.BarManager.currentStyle = nil
        Addon.BarManager:SetStyle(configuredStyle)
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
