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
    if Addon.ReputationSession and Addon.ReputationSession.OnFactionUpdate then
        xpcall(Addon.ReputationSession.OnFactionUpdate, SafeCallErrorHandler, Addon.ReputationSession)
    end

    if Addon.CompanionSession and Addon.CompanionSession.OnFactionUpdate then
        local session = Addon.CompanionSession._session
        if not factionID or (session and factionID == session.factionID) then
            xpcall(Addon.CompanionSession.OnFactionUpdate, SafeCallErrorHandler, Addon.CompanionSession)
        end
    end
end

local function DispatchChatCombatFactionChange()
    if Addon.ReputationSession and Addon.ReputationSession.OnFactionUpdate then
        xpcall(Addon.ReputationSession.OnFactionUpdate, SafeCallErrorHandler, Addon.ReputationSession)
    end
end

local function DispatchRenownLevelChanged(...)
    if Addon.ReputationSession and Addon.ReputationSession.OnRenownLevelChanged then
        xpcall(Addon.ReputationSession.OnRenownLevelChanged, SafeCallErrorHandler, Addon.ReputationSession, ...)
    end
end

local function DispatchDelvesAccountDataChanged()
    if Addon.CompanionSession and Addon.CompanionSession.OnFactionUpdate then
        xpcall(Addon.CompanionSession.OnFactionUpdate, SafeCallErrorHandler, Addon.CompanionSession)
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

local ROUTER_DISPATCH = {
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
    PLAYER_ENTERING_WORLD = function()
        DispatchQuestEvent("PLAYER_ENTERING_WORLD")
    end,
    PLAYER_LEVEL_UP = function()
        DispatchQuestEvent("PLAYER_LEVEL_UP")
    end,
    ZONE_CHANGED_NEW_AREA = function()
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

return EventRouter
