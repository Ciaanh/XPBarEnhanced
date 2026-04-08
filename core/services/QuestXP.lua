-- XP Bar Enhanced - QuestXP
-- Centralized quest XP calculation and caching service

local Addon = XPBarEnhanced
Addon.QuestXP = Addon.QuestXP or {}
local QuestXP = Addon.QuestXP

-------------------------------------------------------------------
-- QUEST API HELPERS
-------------------------------------------------------------------

---Return number of quest log entries
local function getNumQuestLogEntries()
    return C_QuestLog.GetNumQuestLogEntries() or 0
end

---Return quest info table for the given index
local function getQuestInfo(index)
    return C_QuestLog.GetInfo(index)
end

---Check if a quest is ready for turn-in
local function isQuestComplete(questID)
    if not questID then
        return false
    end
    return C_QuestLog.ReadyForTurnIn(questID) or C_QuestLog.IsComplete(questID)
end

---Get XP reward for a quest
local function getQuestXP(questID)
    if not questID then
        return 0
    end
    return GetQuestLogRewardXP(questID) or 0
end

-------------------------------------------------------------------
-- QUEST CACHE
-------------------------------------------------------------------

local questCache = {
    perQuest = {},
    totals = nil,
    timestamp = 0,
    TTL = 0.5,
}

---Build or refresh the quest cache
local function buildQuestCache()
    local numEntries = getNumQuestLogEntries()

    if numEntries <= 0 then
        questCache.perQuest = {}
        questCache.totals = {0, 0, 0}
        questCache.timestamp = GetTime()
        return questCache.totals
    end

    local totalXP, completeXP, incompleteXP = 0, 0, 0
    local perQuest = {}

    for i = 1, numEntries do
        local info = getQuestInfo(i)
        if info and not info.isHeader and not info.isHidden and not info.isTask and info.questID then
            local questID = info.questID
            local key = tostring(questID)

            if not perQuest[key] then
                local xp = getQuestXP(questID)
                local complete = isQuestComplete(questID)

                if xp > 0 then
                    perQuest[key] = {
                        xp = xp,
                        complete = complete,
                    }
                    totalXP = totalXP + xp
                    if complete then
                        completeXP = completeXP + xp
                    else
                        incompleteXP = incompleteXP + xp
                    end
                end
            end
        end
    end

    questCache.perQuest = perQuest
    questCache.totals = {totalXP, completeXP, incompleteXP}
    questCache.timestamp = GetTime()
    return questCache.totals
end

---Invalidate the quest cache
function QuestXP:InvalidateQuestCache()
    questCache.perQuest = {}
    questCache.totals = nil
    questCache.timestamp = 0
    if Addon.EventBus then
        Addon.EventBus:Emit(Addon.EventNames.QUESTS_CACHE_INVALIDATED, { event = Addon.EventNames.QUESTS_CACHE_INVALIDATED })
    end
end

-------------------------------------------------------------------
-- ROUTED EVENT HANDLERS
-------------------------------------------------------------------

local function scheduleRebuild(delay)
    C_Timer.After(delay, function()
        buildQuestCache()
        Addon.EventBus:Emit(Addon.EventNames.QUESTS_CACHE_REBUILT, { event = Addon.EventNames.QUESTS_CACHE_REBUILT })
        if XPBarContextBuilder then
            Addon.EventBus:Emit(Addon.EventNames.XPBAR_BROADCAST_UPDATE, XPBarContextBuilder.BuildContext("QUEST_LOG_UPDATE"))
        end
    end)
end

function QuestXP:HandleRoutedEvent(event)
    self:InvalidateQuestCache()

    if event == "PLAYER_ENTERING_WORLD" then
        scheduleRebuild(1.0)
    elseif event == "QUEST_TURNED_IN" then
        scheduleRebuild(0.1)
    else
        scheduleRebuild(0.5)
    end
end

-------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------

---Get quest XP totals (total, complete, incomplete)
function QuestXP:GetQuestXP(forceRefresh)
    local now = GetTime()
    if forceRefresh or not questCache.totals or (now - questCache.timestamp) > questCache.TTL then
        buildQuestCache()
    end

    if questCache.totals then
        return questCache.totals[1], questCache.totals[2], questCache.totals[3]
    end
    return 0, 0, 0
end

---Get raw per-quest data table
function QuestXP:GetPerQuestData()
    return questCache.perQuest
end

---Get quest entry by questID
function QuestXP:GetQuestByID(questID)
    if not questID then
        return nil
    end
    return questCache.perQuest[tostring(questID)]
end

---Force cache rebuild after optional delay
function QuestXP:Rebuild(delay)
    self:InvalidateQuestCache()
    scheduleRebuild(delay or 0.5)
end

---Get counts of complete and incomplete quests with XP
function QuestXP:GetQuestCounts()
    self:GetQuestXP()
    if questCache.totals then
        return questCache.totals[2] or 0, questCache.totals[3] or 0
    end
    return 0, 0
end

return QuestXP
