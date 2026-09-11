-- XP Bar Enhanced - QuestXP
-- Centralized quest XP calculation and caching service

local Addon = XPBarEnhanced
Addon.QuestXP = Addon.QuestXP or {}
local QuestXP = Addon.QuestXP
local LegacyGetNumQuestLogEntries = rawget(_G, "GetNumQuestLogEntries")
local LegacyGetQuestLogTitle = rawget(_G, "GetQuestLogTitle")
local LegacyGetQuestLogIsComplete = rawget(_G, "GetQuestLogIsComplete")
local GetQuestLogRewardXPCompat = rawget(_G, "GetQuestLogRewardXP")

-------------------------------------------------------------------
-- QUEST API HELPERS
-------------------------------------------------------------------

---Return number of quest log entries
local function getNumQuestLogEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        return C_QuestLog.GetNumQuestLogEntries() or 0
    end
    return (LegacyGetNumQuestLogEntries and LegacyGetNumQuestLogEntries()) or 0
end

---Return quest info table for the given index
local function getQuestInfo(index)
    if C_QuestLog and C_QuestLog.GetInfo then
        return C_QuestLog.GetInfo(index)
    end

    if not LegacyGetQuestLogTitle then
        return nil
    end

    local title, level, suggestedGroup, isHeader, isCollapsed, isComplete,
        frequency, questID, startEvent, isOnQuest, isTask, isBounty,
        isStory, isHidden = LegacyGetQuestLogTitle(index)
    return {
        title = title,
        level = level,
        suggestedGroup = suggestedGroup,
        isHeader = isHeader,
        isCollapsed = isCollapsed,
        isComplete = isComplete,
        frequency = frequency,
        questID = questID,
        isOnQuest = isOnQuest,
        isTask = isTask,
        isBounty = isBounty,
        isStory = isStory,
        isHidden = isHidden,
        questIndex = index,
    }
end

---Check if a quest is ready for turn-in
local function isQuestComplete(info)
    if not info then
        return false
    end
    if C_QuestLog and C_QuestLog.ReadyForTurnIn and C_QuestLog.IsComplete then
        return (info.questID and C_QuestLog.ReadyForTurnIn(info.questID))
            or (info.questID and C_QuestLog.IsComplete(info.questID))
            or false
    end
    if LegacyGetQuestLogIsComplete and info.questIndex then
        return LegacyGetQuestLogIsComplete(info.questIndex) and true or false
    end
    return info.isComplete and true or false
end

---Get XP reward for a quest
local function getQuestXP(info)
    if not info then
        return 0
    end
    if C_QuestLog and info.questID and GetQuestLogRewardXPCompat then
        return GetQuestLogRewardXPCompat(info.questID) or 0
    end
    if GetQuestLogRewardXPCompat and info.questIndex then
        return GetQuestLogRewardXPCompat(info.questIndex) or 0
    end
    return 0
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
        if info and not info.isHeader and not info.isHidden and not info.isTask then
            local questID = info.questID
            local key = tostring(questID or info.questIndex or info.title or i)

            if not perQuest[key] then
                local xp = getQuestXP(info)
                local complete = isQuestComplete(info)

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

local rebuildTimer

local function scheduleRebuild(delay)
    if rebuildTimer then
        rebuildTimer:Cancel()
    end
    rebuildTimer = C_Timer.NewTimer(delay, function()
        rebuildTimer = nil
        buildQuestCache()
        Addon.EventBus:Emit(Addon.EventNames.QUESTS_CACHE_REBUILT, { event = Addon.EventNames.QUESTS_CACHE_REBUILT })
        if Addon.Session and Addon.Session.EmitUpdate then
            Addon.Session:EmitUpdate("QUEST_LOG_UPDATE")
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
    self:GetQuestXP() -- ensure cache is populated
    local completeCount, incompleteCount = 0, 0
    for _, entry in pairs(questCache.perQuest) do
        if entry.complete then
            completeCount = completeCount + 1
        else
            incompleteCount = incompleteCount + 1
        end
    end
    return completeCount, incompleteCount
end

return QuestXP
