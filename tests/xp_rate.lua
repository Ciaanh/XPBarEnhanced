-- XP/hour: the windowed formula on its own, then through the session's real events (gain merging,
-- the history cap, the xpRateWindow setting, the burst of quest XP right after a ding).
local H = dofile((arg[1] or ".") .. "/tests/harness.lua")

local Addon = H.Load(nil)
local TimeCalc = Addon.TimeCalculations
local Rate = TimeCalc.CalculateXPPerHour

local T0 = 1000000

H.Section("Nothing to measure yet")
H.Check("under a minute: the fallback", Rate({}, T0, 500, "1h", 1234, T0 + 59), 1234)
H.Check("under a minute, no fallback: 0", Rate({}, T0, 500, "1h", nil, T0 + 59), 0)
H.Check("no XP this session: the fallback", Rate({}, T0, 0, "1h", 4321, T0 + 600), 4321)

H.Section("This session")
H.Check("6000 XP over 20 min", Rate({}, T0, 6000, "session", 0, T0 + 1200), 18000)
H.Check("divisor floored at 5 min", Rate({}, T0, 6000, "session", 0, T0 + 100), 72000)

H.Section("Windows")
local gains = {
    { timestamp = T0 + 100, amount = 5000 },
    { timestamp = T0 + 4000, amount = 3000 },
    { timestamp = T0 + 7000, amount = 3000 },
}
H.Check("1h: only the last hour's gains", Rate(gains, T0, 11000, "1h", 0, T0 + 7200), 6000)
H.Check("15m: only the last 15 minutes'", Rate(gains, T0, 11000, "15m", 0, T0 + 7200), 12000)
H.Check("unknown window reads as 1h", Rate(gains, T0, 11000, "2h", 0, T0 + 7200), 6000)
H.Check("a gain on the window's start counts", Rate(gains, T0, 11000, "15m", 0, T0 + 7900), 12000)
H.Check("idle for a whole window: 0", Rate(gains, T0, 11000, "15m", 999, T0 + 9000), 0)
local short = { { timestamp = T0 + 60, amount = 1000 }, { timestamp = T0 + 590, amount = 1000 } }
H.Check("window longer than the session: from its start", Rate(short, T0, 2000, "1h", 0, T0 + 600), 12000)
H.Check("same, floored at 5 min", Rate(short, T0, 2000, "1h", 0, T0 + 120), 24000)

H.Section("Level rate")
H.Check("under a minute at this level: 0", TimeCalc.LevelRate(1000, 59), 0)
H.Check("no XP into the level: 0", TimeCalc.LevelRate(0, 3600), 0)
H.Check("5000 XP over an hour", TimeCalc.LevelRate(5000, 3600), 5000)
H.Check("divisor floored at 5 min", TimeCalc.LevelRate(1000, 120), 12000)

-- Through the addon's events ----------------------------------------------------------------

local function Gain(amount)
    H.player.xp = H.player.xp + amount
    H.Fire("PLAYER_XP_UPDATE", "player")
end

local function QuestGain(questID, amount)
    H.Fire("QUEST_TURNED_IN", questID, amount, 0)
    Gain(amount)
end

H.player.level, H.player.xp, H.player.max = 10, 0, 1000000
H.Login()
local session = Addon.Session:GetCurrent()

H.Section("Gain merging")
Gain(100)
H.Advance(2)
Gain(100)
H.Advance(2)
Gain(100)
H.Check("gains within 5 s share one entry", #session.gainsHistory, 1)
H.Check("its amount is their sum", session.gainsHistory[1].amount, 300)
H.Advance(2)
Gain(100)
H.Check("5 s after the entry's first gain: a new entry", #session.gainsHistory, 2)
H.Advance(1)
QuestGain(1, 2000)
H.Check("a quest gain doesn't merge into a kill", #session.gainsHistory, 3)
H.Check("and is attributed to quests", session.gainsHistory[3].source, "quest")
H.Check("session XP counts every gain", session.gainedXP, 2400)
H.Check("source split kept", session.questXP, 2000)
H.Advance(1)
H.player.level = 11
Gain(50)
H.Check("a gain at a new level doesn't merge", #session.gainsHistory, 4)
H.CheckNoErrors("no error")

H.Section("History cap")
for _ = 1, 1100 do
    H.Advance(6)
    Gain(10)
end
H.Check("never over 1000 entries", #session.gainsHistory <= 1000, true)
H.Check("trimmed from the oldest", session.gainsHistory[#session.gainsHistory].amount, 10)
H.Check("an hour of gains 6 s apart still fits", #session.gainsHistory >= 600, true)

H.Section("Setting")
H.Check("default window", Addon.Config:GetOptionValue("xpRateWindow"), "1h")
H.CheckNear("1h: 10 XP every 6 s", Addon.Session:GetXPPerHour(), 6000, 20)
-- Ten minutes idle: the 15 minute window holds 5 minutes of gains (51 with the one on its
-- start), the hour 50 minutes'.
H.Advance(600)
Addon.Config:SetOptionKey("xpRateWindow", "15m")
H.CheckNear("15m after 10 idle minutes", Addon.Session:GetXPPerHour(), 2040, 20)
Addon.Config:SetOptionKey("xpRateWindow", "1h")
H.CheckNear("1h after 10 idle minutes", Addon.Session:GetXPPerHour(), 5000, 20)
H.CheckNoErrors("no error")

H.Section("Quest burst right after a ding")
Addon = H.Restart(true, 3600)
session = Addon.Session:GetCurrent()
H.player.level, H.player.xp, H.player.max = 20, 0, 24100
H.Fire("PLAYER_XP_UPDATE", "player")
for _ = 1, 240 do -- two hours of a kill every 30 s: 12000 XP an hour
    H.Advance(30)
    Gain(100)
end
H.CheckNear("steady pace", Addon.Session:GetXPPerHour(), 12000, 120)
H.Advance(30)
H.player.level, H.player.xp, H.player.max = 21, 0, 30000
H.Fire("PLAYER_LEVEL_UP", 21)
H.Fire("PLAYER_XP_UPDATE", "player")
H.Advance(10)
QuestGain(11, 2000)
H.Advance(40)
QuestGain(12, 1500)
H.Advance(40)
QuestGain(13, 1500)
-- The hour now holds ~118 kills, the ding's last kill and 5000 quest XP.
H.CheckNear("the burst adds its XP to the hour, nothing more", Addon.Session:GetXPPerHour(), 16900, 150)
H.CheckNoErrors("no error")

H.Done()
