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

-- Start one module on its own, so a failure in one of them (a client API that
-- changed shape, say) is reported without stopping every module after it --
-- the bars are initialized last and would otherwise never appear.
local function InitializeModule(module)
    if not (module and module.Initialize) then
        return
    end
    local report = (Addon.Utils and Addon.Utils.ReportError) or geterrorhandler()
    xpcall(function()
        module:Initialize()
    end, report)
end

function eventHandlers:OnPlayerLogin()
    if not Addon.enabled then
        return
    end

    InitializeModule(Addon.Session)

    for _, feature in ipairs({"reputation", "housing", "honor", "profession"}) do
        if Addon:IsFeatureEnabled(feature, "Initialize") then
            InitializeModule(Addon:GetFeatureModule(feature))
        end
    end

    InitializeModule(Addon.GoalTracker)
    InitializeModule(Addon.DataBrokerFeed)
    InitializeModule(Addon.Stats)
    InitializeModule(Addon.BarManager)
    InitializeModule(Addon.SecondaryBarManager)
    InitializeModule(Addon.MinimapButton)
    InitializeModule(Addon.Options)
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
