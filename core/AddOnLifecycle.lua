-- AddOnLifecycle.lua
-- Lifecycle handlers extracted from XPBarEnhanced.lua

local ADDON_NAME = "XPBarEnhanced"
local Addon = XPBarEnhanced

local eventFrame = CreateFrame("Frame")

local eventHandlers = {}

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

    -- Initialize Companion session
    if Addon.CompanionSession and Addon.CompanionSession.Initialize then
        Addon.CompanionSession:Initialize()
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

    -- Initialize Minimap Button
    if Addon.MinimapButton and Addon.MinimapButton.Initialize then
        Addon.MinimapButton:Initialize()
    end

    local options = Addon.Options
    if options and options.Initialize then
        options:Initialize()
    end

end

function eventHandlers:OnPlayerEnteringWorld(isInitialLogin, isReloadingUI)
    if Addon.Session and Addon.Session.OnEnteringWorld then
        Addon.Session:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end
    if Addon.ReputationSession and Addon.ReputationSession.OnEnteringWorld then
        Addon.ReputationSession:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end
    if Addon.CompanionSession and Addon.CompanionSession.OnEnteringWorld then
        Addon.CompanionSession:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end
    if Addon.QuestXP and Addon.QuestXP.InvalidateQuestCache then
        Addon.QuestXP:InvalidateQuestCache()
    end
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    elseif Addon.BarManager and Addon.BarManager.OnEnteringWorld then
        Addon.BarManager:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end
    -- Blizzard's StatusTrackingBarManager re-shows its containers via internal
    -- code paths on PLAYER_ENTERING_WORLD. Re-apply our visibility rules after
    -- all other handlers have run (C_Timer.After(0) defers to next frame).
    C_Timer.After(0, function()
        if Addon.BarManager and Addon.BarManager.ApplyDefaultXPBarVisibility then
            Addon.BarManager:ApplyDefaultXPBarVisibility()
        end
    end)
end

function eventHandlers:OnPlayerLevelUp(level)
    -- Session:OnLevelUp handles all dependents (QuestXP, BarManager, Stats) and
    -- emits the EventBus broadcast.  Session's own eventFrame also fires OnLevelUp
    -- so we must NOT duplicate any of that work here; just forward to Session once.
    if Addon.Session and Addon.Session.OnLevelUp then
        Addon.Session:OnLevelUp(level)
    end
end

function eventHandlers:OnEnableXPGain()
    Addon.state.xpGainDisabled = false
    if Addon.Database and Addon.Database.SetXPGainDisabled then
        Addon.Database:SetXPGainDisabled(false)
    end
    -- Re-evaluate bar style (may need to show custom bar again)
    if Addon.BarManager and Addon.BarManager.SetStyle then
        local db = Addon.db or {}
        Addon.BarManager.currentStyle = nil  -- Force re-evaluation
        Addon.BarManager:SetStyle(db.barStyle or "classic")
    end
end

function eventHandlers:OnDisableXPGain()
    Addon.state.xpGainDisabled = true
    if Addon.Database and Addon.Database.SetXPGainDisabled then
        Addon.Database:SetXPGainDisabled(true)
    end
    -- Re-evaluate bar style (may need to hide custom bar)
    if Addon.BarManager and Addon.BarManager.SetStyle then
        Addon.BarManager.currentStyle = nil  -- Force re-evaluation
        Addon.BarManager:SetStyle("none")
    end
end

function eventHandlers:OnPlayerMaxLevelUpdate()
    -- Max level changed (expansion pre-patch, etc.) - re-evaluate bar visibility
    if Addon.BarManager and Addon.BarManager.SetStyle then
        local db = Addon.db or {}
        Addon.BarManager.currentStyle = nil  -- Force re-evaluation
        Addon.BarManager:SetStyle(db.barStyle or "classic")
    end
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    end
end

function eventHandlers:OnPlayerLogout()
    if Addon.EventBus and Addon.EventBus.Emit then
        Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE)
    elseif Addon.BarManager and Addon.BarManager.Shutdown then
        Addon.BarManager:Shutdown()
    end
end

local eventMap = {
    ADDON_LOADED = "OnAddonLoaded",
    PLAYER_LOGIN = "OnPlayerLogin",
    PLAYER_ENTERING_WORLD = "OnPlayerEnteringWorld",
    PLAYER_LEVEL_UP = "OnPlayerLevelUp",
    ENABLE_XP_GAIN = "OnEnableXPGain",
    DISABLE_XP_GAIN = "OnDisableXPGain",
    PLAYER_LOGOUT = "OnPlayerLogout",
    PLAYER_MAX_LEVEL_UPDATE = "OnPlayerMaxLevelUpdate",
}

eventFrame:SetScript(
    "OnEvent",
    function(self, event, ...)
        local handlerName = eventMap[event]
        if handlerName and eventHandlers[handlerName] then
            xpcall(eventHandlers[handlerName], CallErrorHandler or print, eventHandlers, ...)
        end
    end
)

for event in pairs(eventMap) do
    eventFrame:RegisterEvent(event)
end

return eventHandlers
