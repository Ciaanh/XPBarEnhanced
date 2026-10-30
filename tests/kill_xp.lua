-- Kills to level: patterns built from the game's kill strings (English, French, and the positional
-- and grammar forms of Korean and Russian), each kind of kill line, the lines that are no kill,
-- the per-level average, the rested sum, and the readout through real CHAT_MSG_COMBAT_XP_GAIN events.
local H = dofile((arg[1] or ".") .. "/tests/harness.lua")

-- The enUS strings, as in GlobalStrings.lua (KethoDoc 12.0.5).
local ENUS = {
    COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience.",
    COMBATLOG_XPGAIN_FIRSTPERSON_GROUP = "%s dies, you gain %d experience. (+%d group bonus)",
    COMBATLOG_XPGAIN_FIRSTPERSON_RAID = "%s dies, you gain %d experience. (-%d raid penalty)",
    COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = "You gain %d experience.",
    COMBATLOG_XPGAIN_QUEST = "You gain %d experience. (%s exp %s bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION1 = "%s dies, you gain %d experience. (%s exp %s bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION2 = "%s dies, you gain %d experience. (%s exp %s bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION4 = "%s dies, you gain %d experience. (%s exp %s penalty)",
    COMBATLOG_XPGAIN_EXHAUSTION5 = "%s dies, you gain %d experience. (%s exp %s penalty)",
    COMBATLOG_XPGAIN_EXHAUSTION1_GROUP = "%s dies, you gain %d experience. (%s exp %s bonus, +%d group bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION2_GROUP = "%s dies, you gain %d experience. (%s exp %s bonus, +%d group bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION4_GROUP = "%s dies, you gain %d experience. (%s exp %s penalty, +%d group bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION5_GROUP = "%s dies, you gain %d experience. (%s exp %s penalty, +%d group bonus)",
    COMBATLOG_XPGAIN_EXHAUSTION1_RAID = "%s dies, you gain %d experience. (%s exp %s bonus, -%d raid penalty)",
    COMBATLOG_XPGAIN_EXHAUSTION2_RAID = "%s dies, you gain %d experience. (%s exp %s bonus, -%d raid penalty)",
    COMBATLOG_XPGAIN_EXHAUSTION4_RAID = "%s dies, you gain %d experience. (%s exp %s penalty, -%d raid penalty)",
    COMBATLOG_XPGAIN_EXHAUSTION5_RAID = "%s dies, you gain %d experience. (%s exp %s penalty, -%d raid penalty)",
}
for name, format in pairs(ENUS) do _G[name] = format end

H.player.level = 20
H.player.max = 10000
local Addon = H.Load(nil)
H.Login()
local KillXP = Addon.KillXP

-- Reads text with the patterns built from the current globals.
local function Parse(text)
    KillXP.ResetPatterns()
    return KillXP.Parse(text)
end

H.Section("Patterns")
local built = KillXP.BuildPattern("%s dies, you gain %d experience. (+%d group bonus)")
H.Check("plain arguments in order", table.concat(built.args, ","), "1,2,3")
H.Check("magic characters escaped", built.pattern, "^(.+) dies, you gain (%d+) experience%. %(%+(%d+) group bonus%)$")
local korean = KillXP.BuildPattern("%1$s|1이;가; 죽었습니다. %2$d의 경험치를 획득했습니다. (%4$s 경험치 보너스 %3$s)")
H.Check("positional arguments keep their numbers", table.concat(korean.args, ","), "1,2,4,3")
H.Check("an unknown conversion: no pattern", KillXP.BuildPattern("%s dies, %f experience."), nil)
H.Check("an unknown grammar code: no pattern", KillXP.BuildPattern("%s |2 dies, you gain %d."), nil)
H.Check("not a string: no pattern", KillXP.BuildPattern(nil), nil)

H.Section("English kill lines")
H.Check("plain kill", Parse("Kobold Miner dies, you gain 120 experience."), 120)
H.Check("group bonus kept", Parse("Kobold Miner dies, you gain 150 experience. (+30 group bonus)"), 150)
H.Check("raid penalty kept", Parse("Kobold Miner dies, you gain 90 experience. (-30 raid penalty)"), 90)
local base, total = Parse("Kobold Miner dies, you gain 240 experience. (+120 exp Rested bonus)")
H.Check("rested: bonus taken off", base, 120)
H.Check("rested: the line's total", total, 240)
H.Check("tired: penalty put back", Parse("Kobold Miner dies, you gain 60 experience. (-60 exp Tired penalty)"), 120)
H.Check("rested with a group bonus",
    Parse("Kobold Miner dies, you gain 300 experience. (+150 exp Rested bonus, +30 group bonus)"), 150)
H.Check("tired with a raid penalty",
    Parse("Kobold Miner dies, you gain 45 experience. (-45 exp Tired penalty, -30 raid penalty)"), 90)
H.Check("a mob name with a comma", Parse("Gath'Ilzogg, the Ogre dies, you gain 200 experience."), 200)

H.Section("Not kills")
H.Check("unnamed XP (gathering, exploration)", Parse("You gain 120 experience."), nil)
H.Check("quest XP with a rested part", Parse("You gain 240 experience. (+120 exp Rested bonus)"), nil)
H.Check("a secret line", Parse(H.Secret("string")), nil)
H.Check("nil", Parse(nil), nil)
H.Check("another chat line", Parse("Your skill in Mining has increased to 75."), nil)

H.Section("Other languages")
_G.COMBATLOG_XPGAIN_FIRSTPERSON = "%s meurt, vous gagnez %d points d'expérience."
_G.COMBATLOG_XPGAIN_EXHAUSTION1 = "%s meurt, vous gagnez %d points d'expérience. (%s exp. bonus %s)"
H.Check("French kill", Parse("Mineur kobold meurt, vous gagnez 120 points d'expérience."), 120)
H.Check("French rested kill", Parse("Mineur kobold meurt, vous gagnez 240 points d'expérience. (+120 exp. bonus reposé)"), 120)
_G.COMBATLOG_XPGAIN_EXHAUSTION1 = "%1$s|1이;가; 죽었습니다. %2$d의 경험치를 획득했습니다. (%4$s 경험치 보너스 %3$s)"
H.Check("Korean rested kill: positional arguments and |1",
    Parse("코볼트 광부가 죽었습니다. 240의 경험치를 획득했습니다. (휴식 경험치 보너스 +120)"), 120)
_G.COMBATLOG_XPGAIN_FIRSTPERSON = "%s погибает, вы получаете %d |4очко:очка:очков; опыта."
H.Check("Russian kill: |4", Parse("Кобольд-рудокоп погибает, вы получаете 120 очков опыта."), 120)

H.Section("Every locale's own strings")
-- One language's strings together, as the game loads them: a free capture in one string can read
-- another's line (Korean party kills used to be read as rested ones).
local LOCALES = dofile(H.ROOT .. "/tests/fixtures/combatlog_xpgain.lua")

-- The line the game prints for format with args: positional or plain %s/%d, |1 and |4 resolved.
local function Format(format, args)
    local n = 0
    format = format:gsub("|1([^;]*);([^;]*);", "%1"):gsub("|4([^:]*):([^:]*):([^;]*);", "%3")
    return (format:gsub("%%(%d*)%$?([sd%%])", function(position, conversion)
        if conversion == "%" then return "%" end
        n = n + 1
        return tostring(args[tonumber(position) or n])
    end))
end

-- What a line of each string must read as, base 120 XP: kills give 120 whatever was added or
-- taken off for rest, group or raid; quest and unnamed lines are no kill.
local function Case(name, mob)
    if name:find("UNNAMED") then return { 120, 30 }, nil end
    if name:find("QUEST") then return { 240, "+120", "Rested" }, nil end
    if name:find("EXHAUSTION[12]") then return { mob, 240, "+120", "Rested", 30 }, 120 end
    if name:find("EXHAUSTION[45]") then return { mob, 60, "-60", "Tired", 30 }, 120 end
    return { mob, 120, 30 }, 120
end

local localeNames = {}
for locale in pairs(LOCALES) do table.insert(localeNames, locale) end
table.sort(localeNames)
for _, locale in ipairs(localeNames) do
    for name in pairs(LOCALES.enUS) do _G[name] = nil end
    for name, format in pairs(LOCALES[locale]) do _G[name] = format end
    KillXP.ResetPatterns()
    local wrong, lines = 0, 0
    for name, format in pairs(LOCALES[locale]) do
        for _, mob in ipairs({ "Kobold Miner", "Gath'Ilzogg, the Ogre" }) do
            local args, expected = Case(name, mob)
            local line = Format(format, args)
            local got = KillXP.Parse(line)
            lines = lines + 1
            if got ~= expected then
                wrong = wrong + 1
                io.write(("      %s %s -> %s, wanted %s: %s\n"):format(locale, name, tostring(got),
                    tostring(expected), line))
            end
        end
    end
    H.Check(locale .. ": " .. lines .. " lines, wrong", wrong, 0)
end
for name in pairs(LOCALES.enUS) do _G[name] = nil end
for name, format in pairs(ENUS) do _G[name] = format end
KillXP.ResetPatterns()

H.Section("Kills needed")
local Needed = KillXP.KillsNeeded
H.Check("no rested: XP / base, rounded up", Needed(1000, 0, 120), 9)
H.Check("exact multiple", Needed(1200, 0, 120), 10)
H.Check("rested covers it all: half the kills", Needed(1200, 600, 120), 5)
H.Check("rested covers part: (remaining - rested) / base", Needed(1200, 240, 120), 8)
H.Check("nothing left: 0", Needed(0, 0, 120), 0)
H.Check("no average: 0", Needed(1000, 0, 0), 0)

H.Section("Through the chat event")
H.Check("no kill yet: unknown", KillXP:GetKillsToLevel(), nil)
H.Fire("CHAT_MSG_COMBAT_XP_GAIN", "You gain 500 experience.")
H.Check("unnamed XP records nothing", KillXP:GetKillsToLevel(), nil)
H.Fire("CHAT_MSG_COMBAT_XP_GAIN", H.Secret("string"))
H.CheckNoErrors("a secret line raises nothing")

H.player.xp = 1000
H.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Miner dies, you gain 100 experience.")
local kills, average = KillXP:GetKillsToLevel()
H.Check("one kill: 9000 XP left at 100 a kill", kills, 90)
H.Check("its average", average, 100)
H.player.rested = 3000
H.Check("3000 rested: 6000 XP of plain kills", KillXP:GetKillsToLevel(), 60)
H.player.rested = nil

H.Section("Per-level average")
local samples = Addon.Database:GetKillXPData().samples
H.Check("one sample kept", #samples, 1)
H.Check("tagged with the level", samples[1].level, 20)
H.player.level = 21
H.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Miner dies, you gain 200 experience.")
H.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Miner dies, you gain 200 experience.")
H.CheckNear("two kills at 21: every kill averaged", KillXP:GetAverage(21), 500 / 3, 0.01)
H.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Miner dies, you gain 200 experience.")
H.Check("three kills at 21: only this level's", KillXP:GetAverage(21), 200)
for _ = 1, 30 do
    H.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Miner dies, you gain 210 experience.")
end
H.Check("the last 20 kept", #Addon.Database:GetKillXPData().samples, 20)
H.Check("oldest dropped", KillXP:GetAverage(21), 210)
H.player.level = 23
H.Check("two levels up: the kills below still count", KillXP:GetAverage(23), 210)
H.player.level = 30
H.Check("nine levels up (a boost): unknown", KillXP:GetKillsToLevel(), nil)
H.Fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Miner dies, you gain 900 experience.")
H.Check("the first kill here, not the old ones", KillXP:GetAverage(30), 900)
H.player.level = 21

H.Section("Unknown")
H.player.level = 80
H.player.maxLevel = 80
H.Check("max level: unknown", KillXP:GetKillsToLevel(), nil)
H.player.level = 21
H.player.maxLevel = 80
H.player.xp = H.player.max
H.Check("nothing left to level: unknown", KillXP:GetKillsToLevel(), nil)
H.player.xp = 1000
H.player.xpDisabled = true
H.Check("XP turned off: unknown", KillXP:GetKillsToLevel(), nil)
H.player.xpDisabled = nil
H.Check("XP back on: known again", KillXP:GetKillsToLevel() ~= nil, true)

H.Section("Kept across sessions, cleared with the stats")
Addon = H.Restart(true, 600)
H.Check("samples survive a logout", #Addon.Database:GetKillXPData().samples, 20)
Addon.Config:ResetStats()
H.Check("resetstats clears them", Addon.KillXP:GetKillsToLevel(), nil)

H.Section("Rate line")
H.Check("off by default", Addon.Config:GetOptionValue("showKillsToLevelText"), false)
H.Check("on in the leveller preset", Addon.ReadoutPresets:Get("leveller").showKillsToLevelText, true)
H.Check("off in the standard preset", Addon.ReadoutPresets:Get("standard").showKillsToLevelText, false)

H.Section("Leveller saved before kills to level")
H.ResetUI()
Addon = H.Load({ readoutPreset = "leveller", showMilestoneTicks = true, showIncompleteQuestOverlay = true })
H.Login()
H.Check("still Leveller, not Custom", Addon.ReadoutPresets:Detect(), "leveller")
H.Check("the kills line turned on", Addon.Config:GetOptionValue("showKillsToLevelText"), true)

H.CheckNoErrors("no errors")
H.Done()
