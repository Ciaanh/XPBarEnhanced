-- XP Bar Enhanced - Event Router
-- Centralized external WoW event ownership for staged migration.

local Addon = XPBarEnhanced
Addon.EventRouter = Addon.EventRouter or {}

local EventRouter = Addon.EventRouter
local Utils = Addon.Utils
local CLASSIC_UNAVAILABLE_EVENTS = {
    MAJOR_FACTION_RENOWN_LEVEL_CHANGED = true,
    DELVES_ACCOUNT_DATA_ELEMENT_CHANGED = true,
    QUEST_DATA_LOAD_RESULT = true,
    HONOR_LEVEL_UPDATE = true,
}

-- Events that only exist, or only matter, where a feature is supported.
local FEATURE_EVENTS = {
    HOUSING_SERVICES_AVAILABILITY_UPDATED = "housing",
}

local function RegisterEventSafely(frame, eventName)
    if Addon:IsFeatureEnabled("classicClientBehavior") and CLASSIC_UNAVAILABLE_EVENTS[eventName] then
        return
    end
    local feature = FEATURE_EVENTS[eventName]
    if feature and not Addon:IsFeatureSupported(feature) then
        return
    end

    local ok, err = pcall(frame.RegisterEvent, frame, eventName)
    if not ok and Utils and Utils.ReportError then
        Utils.ReportError(string.format("XPBarEnhanced: skipping unavailable event '%s' (%s)", tostring(eventName), tostring(err)))
    end
end

local function EmitReputationUpdate()
    if Addon:IsFeatureEnabled("reputation", "EmitUpdate") and Addon.ReputationSession._session then
        Addon.ReputationSession:EmitUpdate()
    end
end

local function EmitHousingUpdate()
    if Addon:IsFeatureEnabled("housing", "EmitUpdate") and Addon.HousingSession._session then
        Addon.HousingSession:EmitUpdate()
    end
end

-- Retail's housing service may report itself unavailable at login and come up
-- later; start the session the first time it is available.
local function EnsureHousingSession()
    local housing = Addon.HousingSession
    if not housing._session and Addon:IsFeatureEnabled("housing", "Initialize") then
        housing:Initialize()
    end
end

local function DispatchHousingAvailabilityChanged()
    EnsureHousingSession()
    if Addon.HousingSession._session then
        -- Rebuilt either way: BuildHousingContext reports the bar unavailable
        -- while the service is down.
        Addon.HousingSession:EmitUpdate()
    end
end

local function RequestHousingFavorRefresh()
    if Addon:IsFeatureEnabled("housing", "RequestCurrentTrackedHouseFavor") and Addon.HousingSession._session then
        Addon.HousingSession:RequestCurrentTrackedHouseFavor()
    else
        EmitHousingUpdate()
    end
end

local function DispatchUpdateFaction(factionID)
    if Addon:IsFeatureEnabled("reputation", "OnFactionUpdate") and Addon.ReputationSession._session then
        Addon.ReputationSession:OnFactionUpdate()
    end
end

local function DispatchChatCombatFactionChange()
    if Addon:IsFeatureEnabled("reputation", "OnFactionUpdate") and Addon.ReputationSession._session then
        Addon.ReputationSession:OnFactionUpdate()
    end
end

local function DispatchRenownLevelChanged(...)
    if Addon:IsFeatureEnabled("reputation", "OnRenownLevelChanged") and Addon.ReputationSession._session then
        Addon.ReputationSession:OnRenownLevelChanged(...)
    end
end

local function DispatchDelvesAccountDataChanged()
    EmitReputationUpdate()
end

local function DispatchReputationVisibilityRefresh()
    EmitReputationUpdate()
end

local function DispatchTrackedHouseChanged()
    if Addon:IsFeatureEnabled("housing", "OnTrackedHouseChanged") and Addon.HousingSession._session then
        Addon.HousingSession:OnTrackedHouseChanged()
    else
        EmitHousingUpdate()
    end
end

local function DispatchPlayerHouseListUpdated(list)
    if Addon:IsFeatureEnabled("housing", "OnPlayerHouseListUpdated") and Addon.HousingSession._session then
        Addon.HousingSession:OnPlayerHouseListUpdated(list)
    else
        EmitHousingUpdate()
    end
end

local function DispatchHouseLevelFavorUpdated(...)
    if Addon:IsFeatureEnabled("housing", "OnHouseLevelFavorUpdated") and Addon.HousingSession._session then
        Addon.HousingSession:OnHouseLevelFavorUpdated(...)
    else
        EmitHousingUpdate()
    end
end

local function DispatchHouseLevelChanged()
    RequestHousingFavorRefresh()
end

local function DispatchHonorUpdate()
    if Addon:IsFeatureEnabled("honor", "OnHonorUpdate") and Addon.HonorSession._session then
        Addon.HonorSession:OnHonorUpdate()
    end
end

local function DispatchProfessionUpdate()
    if Addon:IsFeatureEnabled("profession", "OnSkillUpdate") and Addon.ProfessionSession._session then
        Addon.ProfessionSession:OnSkillUpdate()
    end
end

local function DispatchQuestEvent(event)
    if Addon.QuestXP and Addon.QuestXP.HandleRoutedEvent then
        Addon.QuestXP:HandleRoutedEvent(event)
    end
end

local function DispatchSessionXPUpdate()
    if Addon.Session and Addon.Session.OnXPUpdate then
        Addon.Session:OnXPUpdate()
    end
end

local function DispatchSessionTimePlayed(totalTime, levelTime)
    if Addon.Session and Addon.Session.OnTimePlayed then
        Addon.Session:OnTimePlayed(totalTime, levelTime)
    end
end

local function DispatchSessionQuestTurnedIn(questID)
    if Addon.Session and Addon.Session.OnQuestTurnedIn then
        Addon.Session:OnQuestTurnedIn(questID)
    end
end

local function DispatchSessionQuestLogUpdate()
    if Addon.Session and Addon.Session.RefreshSessionTimes then
        Addon.Session:RefreshSessionTimes()
    end
end

local function DispatchSessionRestedChanged()
    if Addon.Session and Addon.Session.OnRestedChanged then
        Addon.Session:OnRestedChanged()
    end
end

local function DispatchAddonLoaded(name)
    local handlers = Addon.LifecycleHandlers
    if handlers and handlers.OnAddonLoaded then
        handlers:OnAddonLoaded(name)
    end
end

local function DispatchPlayerLogin()
    local handlers = Addon.LifecycleHandlers
    if handlers and handlers.OnPlayerLogin then
        handlers:OnPlayerLogin()
    end
end

local function DispatchPlayerLogout()
    local handlers = Addon.LifecycleHandlers
    if handlers and handlers.OnPlayerLogout then
        handlers:OnPlayerLogout()
    end
end

local function DispatchLifecyclePlayerEnteringWorld(isInitialLogin, isReloadingUI)
    local handlers = Addon.LifecycleHandlers
    if handlers and handlers.OnPlayerEnteringWorld then
        handlers:OnPlayerEnteringWorld(isInitialLogin, isReloadingUI)
    end
end

local function DispatchLifecyclePlayerMaxLevelUpdate()
    local handlers = Addon.LifecycleHandlers
    if handlers and handlers.OnPlayerMaxLevelUpdate then
        handlers:OnPlayerMaxLevelUpdate()
    end
end

local function DispatchLifecycleEnableXPGain()
    local handlers = Addon.LifecycleHandlers
    if handlers and handlers.OnEnableXPGain then
        handlers:OnEnableXPGain()
    end
end

local function DispatchLifecycleDisableXPGain()
    local handlers = Addon.LifecycleHandlers
    if handlers and handlers.OnDisableXPGain then
        handlers:OnDisableXPGain()
    end
end

local function DispatchPlayerEnteringWorld(isInitialLogin, isReloadingUI)
    if Addon.Session and Addon.Session.OnEnteringWorld then
        Addon.Session:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end

    if Addon:IsFeatureEnabled("reputation", "OnEnteringWorld") and Addon.ReputationSession._session then
        Addon.ReputationSession:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end

    EnsureHousingSession()
    if Addon:IsFeatureEnabled("housing", "OnEnteringWorld") and Addon.HousingSession._session then
        Addon.HousingSession:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end

    if Addon:IsFeatureEnabled("honor", "OnEnteringWorld") and Addon.HonorSession._session then
        Addon.HonorSession:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end

    if Addon:IsFeatureEnabled("profession", "OnEnteringWorld") and Addon.ProfessionSession._session then
        Addon.ProfessionSession:OnEnteringWorld(isInitialLogin, isReloadingUI)
    end

    DispatchQuestEvent("PLAYER_ENTERING_WORLD")

    DispatchLifecyclePlayerEnteringWorld(isInitialLogin, isReloadingUI)
end

local function DispatchPlayerLevelUp(level)
    DispatchQuestEvent("PLAYER_LEVEL_UP")

    if Addon.Session and Addon.Session.OnLevelUp then
        Addon.Session:OnLevelUp(level)
    end
end

local function DispatchEnableXPGain()
    DispatchLifecycleEnableXPGain()
end

local function DispatchDisableXPGain()
    DispatchLifecycleDisableXPGain()
end

local function DispatchPlayerMaxLevelUpdate()
    DispatchLifecyclePlayerMaxLevelUpdate()
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
        DispatchReputationVisibilityRefresh()
        EmitHousingUpdate()
        DispatchQuestEvent("ZONE_CHANGED_NEW_AREA")
    end,
    GROUP_ROSTER_UPDATE = function()
        DispatchReputationVisibilityRefresh()
    end,
    TRACKED_HOUSE_CHANGED = function()
        DispatchTrackedHouseChanged()
    end,
    PLAYER_HOUSE_LIST_UPDATED = function(a1)
        DispatchPlayerHouseListUpdated(a1)
    end,
    HOUSE_LEVEL_FAVOR_UPDATED = function(...)
        DispatchHouseLevelFavorUpdated(...)
    end,
    HOUSE_LEVEL_CHANGED = function()
        DispatchHouseLevelChanged()
    end,
    HOUSING_SERVICES_AVAILABILITY_UPDATED = function()
        DispatchHousingAvailabilityChanged()
    end,
    -- Housing activity events: fire when the player completes a task (e.g. adds
    -- decor). HOUSE_LEVEL_FAVOR_UPDATED is request-response only, so we must
    -- poll for new favor after each activity. Registered via RegisterEventSafely
    -- (pcall) in case any variant is unavailable in some build.
    INITIATIVE_TASK_COMPLETED = function()
        RequestHousingFavorRefresh()
    end,
    INITIATIVE_COMPLETED = function()
        RequestHousingFavorRefresh()
    end,
    NEIGHBORHOOD_INITIATIVE_UPDATED = function()
        RequestHousingFavorRefresh()
    end,
    HONOR_XP_UPDATE = function()
        DispatchHonorUpdate()
    end,
    HONOR_LEVEL_UPDATE = function()
        DispatchHonorUpdate()
    end,
    SKILL_LINES_CHANGED = function()
        DispatchProfessionUpdate()
    end,
    CHAT_MSG_SKILL = function()
        DispatchProfessionUpdate()
    end,
    UNIT_QUEST_LOG_CHANGED = function(unit)
        -- Fires for every party member; only the player's log feeds quest XP.
        if unit == "player" then
            DispatchQuestEvent("UNIT_QUEST_LOG_CHANGED")
        end
    end,
    QUEST_TURNED_IN = function(questID)
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
    UPDATE_EXPANSION_LEVEL = function()
        DispatchPlayerMaxLevelUpdate()
    end,
    MAX_EXPANSION_LEVEL_UPDATED = function()
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
        RegisterEventSafely(frame, eventName)
    end
end

EventRouter:Initialize()

return EventRouter
