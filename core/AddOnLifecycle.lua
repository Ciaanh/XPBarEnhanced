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

    -- Saved-variable state first: everything after reads settings from it.
    assert(Addon.Database, "XPBarEnhanced: Database module not loaded (check .toc order)")
    assert(Addon.Config,   "XPBarEnhanced: Config module not loaded (check .toc order)")
    assert(Addon.ProfileManager, "XPBarEnhanced: ProfileManager module not loaded (check .toc order)")

    Addon.Database:Initialize()
    Addon.ProfileManager:Initialize()
    Addon.Config:Initialize()
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

-- Re-drive the configured style: SetStyle itself falls back to Blizzard's
-- bar at the level cap or while XP gain is off.
local function RefreshConfiguredStyle()
    local manager = Addon.BarManager
    if manager and manager.SetStyle then
        manager.currentStyle = nil
        manager:SetStyle(Addon.Config:GetOptionValue("barStyle"))
    end
end

function eventHandlers:OnPlayerMaxLevelUpdate()
    RefreshConfiguredStyle()
end

function eventHandlers:OnEnableXPGain()
    RefreshConfiguredStyle()
end

function eventHandlers:OnDisableXPGain()
    -- Straight to Blizzard's bar rather than trusting IsXPUserDisabled to
    -- report the new state already.
    local manager = Addon.BarManager
    if manager and manager.SetStyle then
        manager.currentStyle = nil
        manager:SetStyle("none")
    end
end

return eventHandlers
