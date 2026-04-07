-- XP Bar Enhanced - Event Router
-- Centralized external WoW event ownership for staged migration.

local Addon = XPBarEnhanced
Addon.EventRouter = Addon.EventRouter or {}

local EventRouter = Addon.EventRouter

local function SafeCallErrorHandler(err)
    if CallErrorHandler then
        CallErrorHandler(err)
    else
        print(tostring(err))
    end
end

local function DispatchUpdateFaction(factionID)
    if Addon.ReputationSession and Addon.ReputationSession._session and Addon.ReputationSession.OnFactionUpdate then
        xpcall(Addon.ReputationSession.OnFactionUpdate, SafeCallErrorHandler, Addon.ReputationSession)
    end
end

local function DispatchChatCombatFactionChange()
    if Addon.ReputationSession and Addon.ReputationSession._session and Addon.ReputationSession.OnFactionUpdate then
        xpcall(Addon.ReputationSession.OnFactionUpdate, SafeCallErrorHandler, Addon.ReputationSession)
    end
end

local function DispatchRenownLevelChanged(...)
    if Addon.ReputationSession and Addon.ReputationSession._session and Addon.ReputationSession.OnRenownLevelChanged then
        xpcall(Addon.ReputationSession.OnRenownLevelChanged, SafeCallErrorHandler, Addon.ReputationSession, ...)
    end
end

local function DispatchDelvesAccountDataChanged()
    if Addon.ReputationSession and Addon.ReputationSession._session and Addon.ReputationSession.OnFactionUpdate then
        xpcall(Addon.ReputationSession.OnFactionUpdate, SafeCallErrorHandler, Addon.ReputationSession)
    end
end

local function DispatchQuestEvent(event)
    if Addon.QuestXP and Addon.QuestXP.HandleRoutedEvent then
        xpcall(Addon.QuestXP.HandleRoutedEvent, SafeCallErrorHandler, Addon.QuestXP, event)
    end
end

local function DispatchSessionXPUpdate()
    if Addon.Session and Addon.Session.OnXPUpdate then
        xpcall(Addon.Session.OnXPUpdate, SafeCallErrorHandler, Addon.Session)
    end
end

local function DispatchSessionTimePlayed(totalTime, levelTime)
    if Addon.Session and Addon.Session.OnTimePlayed then
        xpcall(Addon.Session.OnTimePlayed, SafeCallErrorHandler, Addon.Session, totalTime, levelTime)
    end
end

local function DispatchSessionQuestTurnedIn(questID)
    if Addon.Session and Addon.Session.OnQuestTurnedIn then
        xpcall(Addon.Session.OnQuestTurnedIn, SafeCallErrorHandler, Addon.Session, questID)
    end
end

local function DispatchSessionQuestLogUpdate()
    if Addon.Session and Addon.Session.RefreshSessionTimes then
        xpcall(Addon.Session.RefreshSessionTimes, SafeCallErrorHandler, Addon.Session)
    end
end

local function DispatchSessionRestedChanged()
    if Addon.Session and Addon.Session.OnRestedChanged then
        xpcall(Addon.Session.OnRestedChanged, SafeCallErrorHandler, Addon.Session)
    end
end

local function DispatchAddonLoaded(name)
    local handlers = Addon.LifecycleHandlers
    if handlers and handlers.OnAddonLoaded then
        xpcall(handlers.OnAddonLoaded, SafeCallErrorHandler, handlers, name)
    end
end

local function DispatchPlayerLogin()
    local handlers = Addon.LifecycleHandlers
    if handlers and handlers.OnPlayerLogin then
        xpcall(handlers.OnPlayerLogin, SafeCallErrorHandler, handlers)
    end
end

local function DispatchPlayerLogout()
    local handlers = Addon.LifecycleHandlers
    if handlers and handlers.OnPlayerLogout then
        xpcall(handlers.OnPlayerLogout, SafeCallErrorHandler, handlers)
    end
end

local function DispatchPlayerEnteringWorld(isInitialLogin, isReloadingUI)
    if Addon.Session and Addon.Session.OnEnteringWorld then
        xpcall(Addon.Session.OnEnteringWorld, SafeCallErrorHandler, Addon.Session, isInitialLogin, isReloadingUI)
    end

    if Addon.ReputationSession and Addon.ReputationSession._session and Addon.ReputationSession.OnEnteringWorld then
        xpcall(Addon.ReputationSession.OnEnteringWorld, SafeCallErrorHandler, Addon.ReputationSession, isInitialLogin, isReloadingUI)
    end

    DispatchQuestEvent("PLAYER_ENTERING_WORLD")

    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        xpcall(Addon.EventBus.Emit, SafeCallErrorHandler, Addon.EventBus,
            Addon.EventNames.XPBAR_BROADCAST_UPDATE,
            XPBarContextBuilder.BuildContext("PLAYER_ENTERING_WORLD"))
    elseif Addon.BarManager and Addon.BarManager.OnEnteringWorld then
        xpcall(Addon.BarManager.OnEnteringWorld, SafeCallErrorHandler, Addon.BarManager, isInitialLogin, isReloadingUI)
    end

    C_Timer.After(0, function()
        if Addon.BarManager and Addon.BarManager.ApplyDefaultXPBarVisibility then
            xpcall(Addon.BarManager.ApplyDefaultXPBarVisibility, SafeCallErrorHandler, Addon.BarManager)
        end
        if Addon.SecondaryBarManager and Addon.SecondaryBarManager.ApplyDefaultReputationBarVisibility then
            xpcall(Addon.SecondaryBarManager.ApplyDefaultReputationBarVisibility, SafeCallErrorHandler, Addon.SecondaryBarManager)
        end
    end)
end

local function DispatchPlayerLevelUp(level)
    DispatchQuestEvent("PLAYER_LEVEL_UP")

    if Addon.Session and Addon.Session.OnLevelUp then
        xpcall(Addon.Session.OnLevelUp, SafeCallErrorHandler, Addon.Session, level)
    end
end

local function DispatchEnableXPGain()
    Addon.state.xpGainDisabled = false

    if Addon.Database and Addon.Database.SetXPGainDisabled then
        xpcall(Addon.Database.SetXPGainDisabled, SafeCallErrorHandler, Addon.Database, false)
    end

    if Addon.BarManager and Addon.BarManager.SetStyle then
        local db = Addon.db or {}
        Addon.BarManager.currentStyle = nil
        xpcall(Addon.BarManager.SetStyle, SafeCallErrorHandler, Addon.BarManager, db.barStyle or "classic")
    end
end

local function DispatchDisableXPGain()
    Addon.state.xpGainDisabled = true

    if Addon.Database and Addon.Database.SetXPGainDisabled then
        xpcall(Addon.Database.SetXPGainDisabled, SafeCallErrorHandler, Addon.Database, true)
    end

    if Addon.BarManager and Addon.BarManager.SetStyle then
        Addon.BarManager.currentStyle = nil
        xpcall(Addon.BarManager.SetStyle, SafeCallErrorHandler, Addon.BarManager, "none")
    end
end

local function DispatchPlayerMaxLevelUpdate()
    if Addon.BarManager and Addon.BarManager.SetStyle then
        local db = Addon.db or {}
        Addon.BarManager.currentStyle = nil
        xpcall(Addon.BarManager.SetStyle, SafeCallErrorHandler, Addon.BarManager, db.barStyle or "classic")
    end

    if Addon.EventBus and Addon.EventBus.Emit and XPBarContextBuilder then
        xpcall(Addon.EventBus.Emit, SafeCallErrorHandler, Addon.EventBus,
            Addon.EventNames.XPBAR_BROADCAST_UPDATE,
            XPBarContextBuilder.BuildContext("XPBAR:BROADCAST_UPDATE"))
    end
end

local ROUTER_DISPATCH = {
    ADDON_LOADED = function(name)
        DispatchAddonLoaded(name)
    end,
    PLAYER_LOGIN = function()
        DispatchPlayerLogin()
    end,
    PLAYER_LOGOUT = function()
        DispatchPlayerLogout()
    end,
    UPDATE_FACTION = function(...)
        DispatchUpdateFaction(...)
    end,
    CHAT_MSG_COMBAT_FACTION_CHANGE = function()
        DispatchChatCombatFactionChange()
    end,
    MAJOR_FACTION_RENOWN_LEVEL_CHANGED = function(...)
        DispatchRenownLevelChanged(...)
    end,
    DELVES_ACCOUNT_DATA_ELEMENT_CHANGED = function()
        DispatchDelvesAccountDataChanged()
    end,
    PLAYER_XP_UPDATE = function()
        DispatchSessionXPUpdate()
    end,
    TIME_PLAYED_MSG = function(totalTime, levelTime)
        DispatchSessionTimePlayed(totalTime, levelTime)
    end,
    QUEST_LOG_UPDATE = function()
        DispatchQuestEvent("QUEST_LOG_UPDATE")
        DispatchSessionQuestLogUpdate()
    end,
    QUEST_DATA_LOAD_RESULT = function()
        DispatchQuestEvent("QUEST_DATA_LOAD_RESULT")
    end,
    PLAYER_ENTERING_WORLD = function(isInitialLogin, isReloadingUI)
        DispatchPlayerEnteringWorld(isInitialLogin, isReloadingUI)
    end,
    PLAYER_LEVEL_UP = function(level)
        DispatchPlayerLevelUp(level)
    end,
    ZONE_CHANGED_NEW_AREA = function()
        DispatchUpdateFaction()
        DispatchQuestEvent("ZONE_CHANGED_NEW_AREA")
    end,
    UNIT_QUEST_LOG_CHANGED = function()
        DispatchQuestEvent("UNIT_QUEST_LOG_CHANGED")
    end,
    QUEST_TURNED_IN = function(questID)
        DispatchQuestEvent("QUEST_TURNED_IN")
        DispatchSessionQuestTurnedIn(questID)
    end,
    UPDATE_EXHAUSTION = function()
        DispatchSessionRestedChanged()
    end,
    PLAYER_UPDATE_RESTING = function()
        DispatchSessionRestedChanged()
    end,
    ENABLE_XP_GAIN = function()
        DispatchEnableXPGain()
    end,
    DISABLE_XP_GAIN = function()
        DispatchDisableXPGain()
    end,
    PLAYER_MAX_LEVEL_UPDATE = function()
        DispatchPlayerMaxLevelUpdate()
    end,
}

function EventRouter:Initialize()
    if self._frame then
        return
    end

    local frame = CreateFrame("Frame")
    self._frame = frame

    frame:SetScript("OnEvent", function(_, event, ...)
        local dispatcher = ROUTER_DISPATCH[event]
        if dispatcher then
            dispatcher(...)
        end
    end)

    for eventName in pairs(ROUTER_DISPATCH) do
        frame:RegisterEvent(eventName)
    end
end

EventRouter:Initialize()

return EventRouter
