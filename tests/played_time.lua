-- Played time: counted by the addon, exact once a ding or a played time reply is seen, carried
-- across /reload and logout, and asked of the server only with requestPlayedTime on (the reply
-- then kept out of chat).
local H = dofile((arg[1] or ".") .. "/tests/harness.lua")

local function Seconds(Addon)
    local seconds, exact = Addon.Session:GetLevelSeconds()
    return seconds, exact
end

H.player.level, H.player.xp, H.player.max = 10, 5000, 20000

H.Section("Fresh install, option off")
local Addon = H.Load(nil)
H.Login()
H.Advance(10)
H.Check("option off by default", Addon.Config:GetOptionValue("requestPlayedTime"), false)
H.Check("nothing requested at login", H.playedRequests, 0)
H.Advance(60)
H.Check("nor later", H.playedRequests, 0)
H.Check("chat frames never touched", #H.chatEventChanges, 0)
local seconds, exact = Seconds(Addon)
H.Check("level time counted from the login", seconds, 70)
H.Check("as a lower bound", exact, false)
H.Check("bar text marks it", Addon.TextFormatter:GetLevelTimeText(4320, "Level Time", false), "Level Time: 1h 12m+")
H.Check("an exact time has no mark", Addon.TextFormatter:GetLevelTimeText(4320, "Level Time", true), "Level Time: 1h 12m")
H.Check("no level-rate fallback from a lower bound", Addon.Session:GetXPPerHour(), 0)
H.CheckNoErrors("no error")

H.Section("The player's own /played")
local lines = H.chatPlayedLines
H.AnswerPlayed(90000, 7200)
seconds, exact = Seconds(Addon)
H.Check("level time is the game's", seconds, 7200)
H.Check("exact", exact, true)
H.Check("the reply reached every chat frame (not ours to hide)", H.chatPlayedLines - lines, NUM_CHAT_WINDOWS)
H.Check("level rate stands in before the first gain", Addon.Session:GetXPPerHour(), 2500)

H.Section("/reload and logout")
H.Advance(600)
Addon = H.Reload()
seconds, exact = Seconds(Addon)
H.Check("a /reload keeps counting", seconds, 7800)
H.Check("and stays exact", exact, true)
H.Advance(200)
Addon = H.Restart(true, 86400)
seconds, exact = Seconds(Addon)
H.Check("a day offline is not counted", seconds, 8000)
H.Check("still exact", exact, true)
H.Check("still nothing requested", H.playedRequests, 0)
H.CheckNoErrors("no error")

H.Section("A level gained with the addon off")
H.player.level = 11
Addon = H.Restart(true, 3600)
seconds, exact = Seconds(Addon)
H.Check("count starts again", seconds, 0)
H.Check("as a lower bound", exact, false)
H.Advance(120)
H.Check("and runs", (Seconds(Addon)), 120)

H.Section("A ding seen")
H.player.level, H.player.xp = 12, 100
H.Fire("PLAYER_LEVEL_UP", 12)
H.Fire("PLAYER_XP_UPDATE", "player")
seconds, exact = Seconds(Addon)
H.Check("counted from the ding", seconds, 0)
H.Check("exact without asking", exact, true)
H.Advance(300)
H.Check("and runs", (Seconds(Addon)), 300)
H.CheckNoErrors("no error")

H.Section("Option on")
local requests = H.playedRequests
Addon.Config:SetOptionKey("requestPlayedTime", true)
H.Advance(10)
H.Check("turned on while exact: nothing asked", H.playedRequests, requests)
H.player.level = 13
Addon = H.Restart(true, 600)
H.Advance(4)
H.Check("not exact at login: not before 5 s", H.playedRequests, requests)
H.Advance(1.5)
H.Check("then once", H.playedRequests, requests + 1)
H.Check("chat frames muted while it is out", _G.ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG"), false)
lines = H.chatPlayedLines
H.AnswerPlayed(95000, 3000)
H.RunTimers()
H.Check("our reply kept out of chat", H.chatPlayedLines, lines)
H.Check("chat frames get the event back", _G.ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG"), true)
seconds, exact = Seconds(Addon)
H.Check("level time from the reply", seconds, 3000)
H.Check("exact", exact, true)
Addon = H.Restart(true, 600)
H.Advance(10)
H.Check("exact at the next login: nothing asked", H.playedRequests, requests + 1)

H.Section("Option turned on while not exact")
Addon.Config:SetOptionKey("requestPlayedTime", false)
H.player.level = 14
Addon = H.Restart(true, 600)
H.Advance(10)
H.Check("option off: nothing asked", H.playedRequests, requests + 1)
Addon.Config:SetOptionKey("requestPlayedTime", true)
H.Advance(1)
H.Check("turning it on asks once", H.playedRequests, requests + 2)
H.Advance(10)
H.Check("a lost reply gives chat its event back", _G.ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG"), true)
H.CheckNoErrors("no error")

H.Section("A secret reply")
seconds = Seconds(Addon)
H.AnswerPlayed(H.Secret("number"), H.Secret("number"))
H.Check("ignored, the count goes on", (Seconds(Addon)), seconds)
H.Advance(60)
H.Check("and still adds up", (Seconds(Addon)), seconds + 60)
H.CheckNoErrors("no error")

H.Section("Shift+click on the minimap button")
H.AnswerPlayed(100000, 3600)
H.player.xp = H.player.xp + 500
H.Fire("PLAYER_XP_UPDATE", "player")
H.Advance(1800)
H.Check("a gain in the session", Addon.Session:GetCurrent().gainedXP > 0, true)
local button = _G.XPBarEnhancedMinimapButton
local shiftKey = IsShiftKeyDown
IsShiftKeyDown = function() return true end
button:GetScript("OnClick")(button, "LeftButton")
IsShiftKeyDown = shiftKey
H.Check("a new session", Addon.Session:GetCurrent().gainedXP, 0)
seconds, exact = Seconds(Addon)
H.Check("the level time kept", seconds, 5400)
H.Check("and exact", exact, true)
H.Advance(600)
Addon = H.Reload()
H.Check("carried across a /reload", (Seconds(Addon)), 6000)
H.CheckNoErrors("no error")

H.Section("/xpbe resetstats")
Addon.Config:ResetStats()
seconds, exact = Seconds(Addon)
H.Check("the level time kept", seconds, 6000)
H.Check("and exact", exact, true)
H.Advance(60)
Addon = H.Reload()
seconds = Seconds(Addon)
H.Check("a /reload after it adds the minute played, not the epoch", seconds, 6060)
H.CheckNoErrors("no error")

H.Section("A store with no anchor")
local stored = Addon.Database:GetSessionData()
stored.lastTimePlayedRequest, stored.realLevelTime = 0, 0
Addon = H.Reload()
H.Check("a /reload carries nothing from it", (Seconds(Addon)), 0)
H.CheckNoErrors("no error")

H.Section("SavedVariables from 1.3.0")
-- The level time of the last reply, never carried to the logout, and no levelTimeLevel.
H.player.level = 30
local old = {
    sessionData = {
        ["Tester-Realm"] = { sessionStart = H.epoch - 7200, lastUpdate = H.epoch - 3600, gainedXP = 0,
            realLevelTime = 5000, realTotalTime = 400000, lastTimePlayedRequest = H.epoch - 7000, lastLevel = 30,
            lastXP = 5000, maxXP = 20000 },
    },
    _migrationFlags = { sessionData = true },
}
H.ResetUI()
Addon = H.Load(old)
H.Login()
seconds, exact = Seconds(Addon)
H.Check("same level: the old time kept", seconds, 5000)
H.Check("as a lower bound", exact, false)
H.CheckNoErrors("no error")

H.Done()
