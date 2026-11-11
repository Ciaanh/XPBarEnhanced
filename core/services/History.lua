-- XP Bar Enhanced - History.lua
-- Lifetime statistics kept per character, for the History window: when the
-- character is played (hours of the day, days of the week), XP gained (quest
-- against other) and the quests accepted and turned in (time taken, gold, how
-- the quest's level compared with the character's). Nothing here is sent
-- anywhere; /xpbe resethistory clears it.

local Addon = XPBarEnhanced
Addon.History = Addon.History or {}

local History = Addon.History

-- Seconds between two counts of played time. A tick longer than MAX_TICK
-- (the client was suspended) is counted as MAX_TICK.
local TICK_SECONDS = 30
local MAX_TICK = 90
-- A quest accepted and never turned in (abandoned) is forgotten after this.
local PENDING_MAX_AGE = 30 * 24 * 3600
-- A turn-in slower than this is not a quest worked on in one go; it counts as
-- a quest but not towards the average time.
local MAX_QUEST_SECONDS = 7 * 24 * 3600
-- Seconds QUEST_REMOVED waits for the QUEST_TURNED_IN of the same quest.
local REMOVED_DELAY = 5

local function Store()
    return Addon.Database and Addon.Database.GetHistoryData and Addon.Database:GetHistoryData() or nil
end

local function Ensure(store)
    store.startedAt = store.startedAt or time()
    store.seconds = store.seconds or 0
    store.hours = store.hours or {}
    store.days = store.days or {}
    for h = 0, 23 do store.hours[h] = store.hours[h] or 0 end
    for d = 1, 7 do store.days[d] = store.days[d] or 0 end
    store.xp = store.xp or {}
    store.xp.quest = store.xp.quest or 0
    store.xp.other = store.xp.other or 0
    store.xp.rested = store.xp.rested or 0
    store.quests = store.quests or {}
    local q = store.quests
    q.accepted = q.accepted or 0
    q.turnedIn = q.turnedIn or 0
    q.money = q.money or 0
    q.timedCount = q.timedCount or 0
    q.timedSeconds = q.timedSeconds or 0
    q.green = q.green or 0
    q.yellow = q.yellow or 0
    q.orange = q.orange or 0
    store.pending = store.pending or {}
    return store
end

---The character's history, with every field present (nil when the database is not ready).
---@return table|nil
function History:Get()
    local store = Store()
    return store and Ensure(store) or nil
end

---Quest colour bucket from the level gap, as the quest log colours it: orange
---(or red) from 3 levels above the character, yellow within 2, green below
---(grey, trivial quests, are counted as green).
---@param questLevel number|nil
---@param playerLevel number|nil
---@return string|nil bucket "green", "yellow" or "orange"; nil when a level is unknown
function History.QuestColor(questLevel, playerLevel)
    if type(questLevel) ~= "number" or type(playerLevel) ~= "number" or questLevel <= 0 then
        return nil
    end
    local diff = questLevel - playerLevel
    if diff >= 3 then return "orange" end
    if diff >= -2 then return "yellow" end
    return "green"
end

local function IsSecret(value)
    return (issecretvalue and issecretvalue(value)) and true or false
end

local function Plain(value)
    if IsSecret(value) or type(value) ~= "number" then return nil end
    return value
end

---The quest's level: C_QuestLog.GetQuestDifficultyLevel where the client has
---it, else the level the Classic quest log lists at `logIndex`.
local function QuestLevel(questID, logIndex)
    local log = C_QuestLog
    if log and log.GetQuestDifficultyLevel and questID then
        local ok, level = pcall(log.GetQuestDifficultyLevel, questID)
        if ok and type(level) == "number" and level > 0 then
            return level
        end
    end
    local LegacyGetQuestLogTitle = rawget(_G, "GetQuestLogTitle")
    if LegacyGetQuestLogTitle and type(logIndex) == "number" and logIndex > 0 then
        local ok, _, level = pcall(LegacyGetQuestLogTitle, logIndex)
        if ok and type(level) == "number" and level > 0 then
            return level
        end
    end
end

---World quests and bonus objectives are "accepted" by entering their area, so
---they are left out of Accepted and of the timing.
local function IsTaskQuest(questID)
    local log, task = C_QuestLog, C_TaskQuest
    for _, fn in ipairs({log and log.IsWorldQuest, task and task.IsActive}) do
        local ok, yes = pcall(fn, questID)
        if ok and yes then return true end
    end
    return false
end

-------------------------------------------------------------------
-- PLAYED TIME
-------------------------------------------------------------------

---Count `seconds` of play at the current local hour and weekday.
---@param seconds number
---@param at number|nil timestamp, default now
function History:AddPlayed(seconds, at)
    local store = self:Get()
    if not store or type(seconds) ~= "number" or seconds <= 0 then return end
    local now = (rawget(_G, "date") or os.date)("*t", at or time())
    store.hours[now.hour] = store.hours[now.hour] + seconds
    store.days[now.wday] = store.days[now.wday] + seconds
    store.seconds = store.seconds + seconds
end

function History:Tick()
    local clock = GetTime()
    local last = self._lastTick or clock
    self._lastTick = clock
    self:AddPlayed(math.min(clock - last, MAX_TICK))
end

-------------------------------------------------------------------
-- XP AND QUESTS
-------------------------------------------------------------------

---Called by Session for every XP gain it credits.
---@param amount number
---@param source string "quest" or "other"
function History:OnXPGain(amount, source)
    local store = self:Get()
    if not store or type(amount) ~= "number" or amount <= 0 then return end
    local key = source == "quest" and "quest" or "other"
    store.xp[key] = store.xp[key] + amount
end

---Called by KillXP for a kill line that reports a rested bonus: the bonus is
---the rested XP that kill used. Only kills are counted: that is the one line
---that names the bonus.
---@param amount number
function History:OnRestedBonus(amount)
    local store = self:Get()
    if not store or type(amount) ~= "number" or amount <= 0 then return end
    store.xp.rested = store.xp.rested + amount
end

---QUEST_ACCEPTED: Retail passes the quest id alone, the Classic clients the
---log index then the quest id.
function History:OnQuestAccepted(a, b)
    local store = self:Get()
    a, b = Plain(a), Plain(b)
    local questID = (b and b > 0) and b or a
    local logIndex = (b and b > 0) and a or nil
    if not store or not questID or questID <= 0 then return end
    if store.pending[questID] or IsTaskQuest(questID) then return end
    store.quests.accepted = store.quests.accepted + 1
    store.pending[questID] = { at = time(), level = QuestLevel(questID, logIndex) }
end

---QUEST_REMOVED: an abandoned quest leaves `pending`. A turn-in removes the
---quest too, maybe before QUEST_TURNED_IN, so the entry is dropped a little
---later, and only if that turn-in has not already taken it.
function History:OnQuestRemoved(questID)
    questID = Plain(questID)
    local store = self:Get()
    if not store or not questID then return end
    local entry = store.pending[questID]
    if not entry then return end
    C_Timer.After(REMOVED_DELAY, function()
        local now = History:Get()
        if now and now.pending[questID] == entry then
            now.pending[questID] = nil
        end
    end)
end

---QUEST_TURNED_IN(questID, xpReward, moneyReward)
function History:OnQuestTurnedIn(questID, _, money)
    local store = self:Get()
    questID, money = Plain(questID), Plain(money)
    if not store or not questID then return end
    local q = store.quests
    q.turnedIn = q.turnedIn + 1
    if type(money) == "number" and money > 0 then
        q.money = q.money + money
    end

    local entry = store.pending[questID]
    store.pending[questID] = nil
    if entry and entry.at then
        local took = time() - entry.at
        if took >= 0 and took <= MAX_QUEST_SECONDS then
            q.timedCount = q.timedCount + 1
            q.timedSeconds = q.timedSeconds + took
        end
    end

    local bucket = History.QuestColor((entry and entry.level) or QuestLevel(questID), UnitLevel("player"))
    if bucket then
        q[bucket] = q[bucket] + 1
    end
end

---Forget quests accepted long ago and never turned in.
function History:PrunePending()
    local store = self:Get()
    if not store then return end
    local limit = time() - PENDING_MAX_AGE
    for questID, entry in pairs(store.pending) do
        if type(entry) ~= "table" or (entry.at or 0) < limit then
            store.pending[questID] = nil
        end
    end
end

function History:Reset()
    local db = Addon.Database and Addon.Database:GetDB()
    if db and db.historyData then
        db.historyData[Addon.Database:GetPlayerKey()] = nil
    end
    self:Get()
    if Addon.HistoryPage and Addon.HistoryPage.Refresh then
        Addon.HistoryPage:Refresh()
    end
end

-------------------------------------------------------------------
-- READ SIDE (the window)
-------------------------------------------------------------------

---Lifetime XP per hour played, from the time the addon recorded; nil before 5 minutes.
function History:GetXPPerHour()
    local store = self:Get()
    if not store or store.seconds < 300 then return nil end
    return (store.xp.quest + store.xp.other) / (store.seconds / 3600)
end

---Average seconds a quest took from accepting to turning in; nil when none was timed.
function History:GetAverageQuestSeconds()
    local store = self:Get()
    if not store or store.quests.timedCount <= 0 then return nil end
    return store.quests.timedSeconds / store.quests.timedCount
end

-------------------------------------------------------------------
-- LIFECYCLE
-------------------------------------------------------------------

function History:Initialize()
    if self._initialized then return end
    self._initialized = true
    self:Get()
    self:PrunePending()
    self._lastTick = GetTime()
    self._ticker = C_Timer.NewTicker(TICK_SECONDS, function() History:Tick() end)
end

return History
