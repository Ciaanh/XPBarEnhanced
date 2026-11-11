-- History: played time by hour and weekday, XP credited by Session, quests accepted and turned in
-- (time taken, gold, colour), the Retail / Classic QUEST_ACCEPTED argument shapes, reset, and the window.
local H = dofile((arg[1] or ".") .. "/tests/harness.lua")

H.player.level = 20
H.player.max = 10000
local Addon = H.Load(nil)
H.Login()
local History = Addon.History

H.Section("Quest colour")
H.Check("3 above is orange", History.QuestColor(23, 20), "orange")
H.Check("2 above is yellow", History.QuestColor(22, 20), "yellow")
H.Check("2 below is yellow", History.QuestColor(18, 20), "yellow")
H.Check("3 below is green", History.QuestColor(17, 20), "green")
H.Check("an unknown level is no colour", History.QuestColor(nil, 20), nil)

H.Section("Played time")
local data = History:Get()
H.Check("starts empty", data.seconds, 0)
local at = os.time({year = 2026, month = 11, day = 11, hour = 22, min = 5}) -- a Wednesday
History:AddPlayed(600, at)
H.Check("hour counted", data.hours[22], 600)
H.Check("weekday counted (Wednesday = 4)", data.days[4], 600)
H.Check("total counted", data.seconds, 600)
local before = data.seconds
H.Advance(65)
H.Check("the ticker counts played time", data.seconds > before, true)
H.CheckNoErrors("no error")

H.Section("XP")
H.player.xp = 400
H.Fire("PLAYER_XP_UPDATE", "player")
H.Check("a gain is added", data.xp.quest + data.xp.other, 400)
H.Check("a rate needs 5 minutes recorded", History:GetXPPerHour() ~= nil, true)

H.Section("Rested bonus")
COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."
COMBATLOG_XPGAIN_EXHAUSTION1 = "%s dies, you gain %d experience. (%s exp %s bonus)"
Addon.KillXP.ResetPatterns()
History:OnRestedBonus(150)
History:OnRestedBonus(-5)
H.Check("the bonus of a rested kill is added", data.xp.rested, 150)
local base, total, bonus = Addon.KillXP.Parse("Boar dies, you gain 300 experience. (+150 exp Rested bonus)")
H.Check("a rested kill line reports its bonus", bonus, 150)
H.Check("a plain kill line reports none", select(3, Addon.KillXP.Parse("Boar dies, you gain 100 experience.")), 0)
H.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Boar dies, you gain 300 experience. (+150 exp Rested bonus)")
H.Check("a rested kill adds its bonus through the event", data.xp.rested, 300)

H.Section("Quests")
C_QuestLog.GetQuestDifficultyLevel = function(id) return id == 1 and 23 or 20 end
H.Fire("QUEST_ACCEPTED", 1)
H.Fire("QUEST_ACCEPTED", 7, 2) -- the Classic shape: log index, then id
H.Check("two accepted", data.quests.accepted, 2)
H.Fire("QUEST_ACCEPTED", 1)
H.Check("accepting the same id again is not counted twice", data.quests.accepted, 2)
H.Advance(120)
H.Fire("QUEST_TURNED_IN", 1, 900, 12345)
H.Check("turned in", data.quests.turnedIn, 1)
H.Check("gold counted", data.quests.money, 12345)
H.Check("colour counted", data.quests.orange, 1)
H.CheckNear("time taken", History:GetAverageQuestSeconds(), 120, 5)
H.Fire("QUEST_TURNED_IN", 99, 100, 0)
H.Check("a quest taken before the addon counts, untimed", data.quests.turnedIn, 2)
H.CheckNear("and leaves the average alone", History:GetAverageQuestSeconds(), 120, 5)

H.Section("Removed and task quests")
H.Fire("QUEST_ACCEPTED", 50)
H.Fire("QUEST_REMOVED", 50)
H.Advance(10)
H.Check("an abandoned quest leaves pending", data.pending[50], nil)
H.Fire("QUEST_ACCEPTED", 51)
H.Fire("QUEST_REMOVED", 51)
H.Fire("QUEST_TURNED_IN", 51, 100, 0)
H.Advance(10)
H.Check("a removal before the turn-in keeps the timing", data.quests.timedCount, 2)
local accepted = data.quests.accepted
C_QuestLog.IsWorldQuest = function(id) return id == 60 end
H.Fire("QUEST_ACCEPTED", 60)
H.Check("a world quest is not counted as accepted", data.quests.accepted, accepted)
C_QuestLog.IsWorldQuest = nil

H.Section("Classic quest level")
local saved = C_QuestLog.GetQuestDifficultyLevel
C_QuestLog.GetQuestDifficultyLevel = nil
GetQuestLogTitle = function(index) return "Quest", index == 3 and 25 or 1 end
H.Fire("QUEST_ACCEPTED", 3, 70)
H.Check("the level comes from the Classic quest log", data.pending[70] and data.pending[70].level, 25)
C_QuestLog.GetQuestDifficultyLevel = saved

H.Section("Window")
local Frame = Addon.HistoryFrame
Frame:Toggle()
Frame:Refresh()
H.CheckNoErrors("builds and refreshes")

H.Section("Reset")
History:Reset()
data = History:Get()
H.Check("quests cleared", data.quests.turnedIn, 0)
H.Check("time cleared", data.seconds, 0)
H.CheckNoErrors("no error after reset")
H.Done()
