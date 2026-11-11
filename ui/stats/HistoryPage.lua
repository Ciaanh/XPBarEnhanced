-- XP Bar Enhanced - HistoryPage.lua
-- The Stats window's History tab: lifetime figures from History.lua, laid out
-- as cards, two histograms (hours of the day, days of the week) and share bars.
-- Built in code, parented to the XML Stats window, which keeps the Session tab
-- (its own XML children). Two tab buttons hang under the window. Nothing here
-- is read from the game.

local Addon = XPBarEnhanced
local L = Addon.L or LibStub("AceLocale-3.0"):GetLocale("XPBarEnhanced")

Addon.HistoryPage = Addon.HistoryPage or {}
local HistoryPage = Addon.HistoryPage

local TABS = {"session", "history"}

-- The Stats window's own children, shown on the Session tab only.
local SESSION_KEYS = {"HeroXPPerHour", "HeroTimeToLevel", "ChartPanel", "SummaryStrip", "DetailHeader", "LevelDetail"}

-- The Stats window is 460 wide; the page sits in its inset.
local PAD = 12
local CONTENT_W = 460 - 2 * PAD - 12
-- Window height on the History tab: the content ends near y = -442 in the
-- inset (the note's two lines), the inset starts ~24 px under the window's top,
-- plus a bottom margin. It matches the Session tab with Details open (488 in
-- Stats.lua), so switching tabs there does not resize the window.
local HISTORY_HEIGHT = 488
local REFRESH_SECONDS = 5

local LABEL_W, VALUE_W = 130, 90
local TRACK_W = CONTENT_W - LABEL_W - 6 - VALUE_W - 8

-- Monday first, as the weekly chart reads; values are date("*t").wday (1 = Sunday).
local DAY_ORDER = {2, 3, 4, 5, 6, 7, 1}

local COLORS = {
    card = {0.95, 0.93, 0.88, 0.10},
    bar = {0.18, 0.70, 0.82, 0.95},
    quest = {0.95, 0.76, 0.25, 0.95},
    other = {0.18, 0.70, 0.82, 0.95},
    green = {0.27, 0.78, 0.27, 0.95},
    yellow = {0.90, 0.80, 0.10, 0.95},
    orange = {1.00, 0.50, 0.25, 0.95},
    track = {0.95, 0.93, 0.88, 0.08},
}

local function FormatNumber(value)
    local formatter = Addon.TextFormatter
    if formatter and formatter.FormatNumber then
        return formatter:FormatNumber(value, false)
    end
    return tostring(math.floor((value or 0) + 0.5))
end

-- The game's own coin text (icons, every language) where it exists.
local function FormatMoney(copper)
    copper = math.floor(copper or 0)
    local coins = rawget(_G, "GetCoinTextureString")
    if coins then
        local ok, text = pcall(coins, copper)
        if ok and type(text) == "string" then return text end
    end
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100)
end

local function FormatSeconds(seconds)
    return Addon.Utils.FormatDuration(seconds or 0)
end

-------------------------------------------------------------------
-- WIDGETS
-------------------------------------------------------------------

local function Heading(parent, text, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    fs:SetText(text)
    return fs
end

local function SmallCaps(parent, text, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    fs:SetText(string.upper(text))
    return fs
end

local function Card(parent, label, x, y, w, h)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(w, h)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(COLORS.card))
    card.Label = card:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    card.Label:SetPoint("TOPLEFT", 7, -6)
    card.Label:SetPoint("RIGHT", -5, 0)
    card.Label:SetJustifyH("LEFT")
    card.Label:SetWordWrap(false)
    card.Label:SetText(label)
    card.Value = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    card.Value:SetPoint("BOTTOMLEFT", 7, 8)
    card.Value:SetPoint("RIGHT", -5, 0)
    card.Value:SetJustifyH("LEFT")
    card.Value:SetWordWrap(false)
    return card
end

-- A row: label, a track with a fill, and "count (pct %)".
local function ShareBar(parent, label, color, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(CONTENT_W, 16)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Label:SetPoint("LEFT", 0, 0)
    row.Label:SetWidth(LABEL_W)
    row.Label:SetJustifyH("LEFT")
    row.Label:SetWordWrap(false)
    row.Label:SetText(label)
    row.Track = row:CreateTexture(nil, "BACKGROUND")
    row.Track:SetPoint("LEFT", LABEL_W + 6, 0)
    row.Track:SetSize(TRACK_W, 10)
    row.Track:SetColorTexture(unpack(COLORS.track))
    row.Fill = row:CreateTexture(nil, "ARTWORK")
    row.Fill:SetPoint("LEFT", row.Track, "LEFT", 0, 0)
    row.Fill:SetHeight(10)
    row.Fill:SetColorTexture(unpack(color))
    row.Value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Value:SetPoint("RIGHT", 0, 0)
    row.Value:SetWidth(VALUE_W)
    row.Value:SetJustifyH("RIGHT")
    return row
end

-- The track's width is a constant: GetWidth() can read 0 before the first layout.
local function SetShare(row, count, total)
    local share = (total > 0) and count / total or 0
    row.Value:SetText(string.format("%s (%d %%)", FormatNumber(count), math.floor(share * 100 + 0.5)))
    if TRACK_W * share >= 1 then
        row.Fill:SetWidth(TRACK_W * share)
        row.Fill:Show()
    else
        row.Fill:Hide()
    end
end

local function Histogram(parent, title, n, x, y, width, height)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(width, height + 30)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box.Title = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    box.Title:SetPoint("TOPLEFT", 0, 0)
    box.Title:SetText(string.upper(title))
    box.Plot = CreateFrame("Frame", nil, box)
    box.Plot:SetPoint("TOPLEFT", 0, -16)
    box.Plot:SetSize(width, height)
    box.n, box.height = n, height
    box.bars, box.captions = {}, {}
    local slot = width / n
    for i = 1, n do
        local bar = box.Plot:CreateTexture(nil, "ARTWORK")
        bar:SetColorTexture(unpack(COLORS.bar))
        bar:SetPoint("BOTTOMLEFT", box.Plot, "BOTTOMLEFT", (i - 1) * slot + slot * 0.15, 0)
        bar:SetWidth(slot * 0.7)
        bar:SetHeight(1)
        bar:Hide()
        box.bars[i] = bar
        local cap = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        cap:SetPoint("TOP", box.Plot, "BOTTOMLEFT", (i - 0.5) * slot, -3)
        box.captions[i] = cap
    end
    return box
end

local function SetHistogram(box, values)
    local peak = 0
    for i = 1, box.n do
        if (values[i] or 0) > peak then peak = values[i] end
    end
    for i = 1, box.n do
        local v = values[i] or 0
        if peak > 0 and v > 0 then
            box.bars[i]:SetHeight(math.max(2, v / peak * box.height))
            box.bars[i]:Show()
        else
            box.bars[i]:Hide()
        end
    end
end

-------------------------------------------------------------------
-- PAGE
-------------------------------------------------------------------

local function BuildPage(stats)
    local page = CreateFrame("Frame", nil, stats)
    local inset = stats.InsetBg or stats
    page:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, 0)
    page:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, 0)
    page:Hide()

    page.Hours = Histogram(page, L["HISTORY_HOURS_PLAYED"], 24, PAD, -10, 250, 52)
    page.Days = Histogram(page, L["HISTORY_DAYS_OF_WEEK"], 7, PAD + 268, -10, CONTENT_W - 268, 52)
    for i = 1, 24 do
        page.Hours.captions[i]:SetText((i - 1) % 3 == 0 and string.format(L["HISTORY_HOUR_FMT"], i - 1) or "")
    end
    for i, wday in ipairs(DAY_ORDER) do
        page.Days.captions[i]:SetText(L["HISTORY_DAY_" .. wday])
    end

    Heading(page, L["HISTORY_EXPERIENCE"], -112)
    local cw = math.floor((CONTENT_W - 18) / 4)
    page.XPGained = Card(page, L["HISTORY_XP_GAINED"], PAD, -138, cw, 46)
    page.XPPerHour = Card(page, L["HISTORY_XP_PER_HOUR"], PAD + (cw + 6), -138, cw, 46)
    page.RestedUsed = Card(page, L["HISTORY_RESTED_USED"], PAD + 2 * (cw + 6), -138, cw, 46)
    page.Recorded = Card(page, L["HISTORY_TIME_RECORDED"], PAD + 3 * (cw + 6), -138, cw, 46)
    page.QuestShare = ShareBar(page, L["HISTORY_QUEST_XP"], COLORS.quest, -194)
    page.OtherShare = ShareBar(page, L["HISTORY_OTHER_XP"], COLORS.other, -214)

    Heading(page, L["HISTORY_QUESTS"], -246)
    page.Accepted = Card(page, L["HISTORY_ACCEPTED"], PAD, -272, cw, 46)
    page.TurnedIn = Card(page, L["HISTORY_TURNED_IN"], PAD + (cw + 6), -272, cw, 46)
    page.AverageTime = Card(page, L["HISTORY_AVERAGE_QUEST_TIME"], PAD + 2 * (cw + 6), -272, cw, 46)
    page.QuestGold = Card(page, L["HISTORY_QUEST_GOLD"], PAD + 3 * (cw + 6), -272, cw, 46)
    SmallCaps(page, L["HISTORY_QUEST_COLOURS"], -330)
    page.Green = ShareBar(page, L["HISTORY_GREEN"], COLORS.green, -348)
    page.Yellow = ShareBar(page, L["HISTORY_YELLOW"], COLORS.yellow, -368)
    page.Orange = ShareBar(page, L["HISTORY_ORANGE"], COLORS.orange, -388)

    local note = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", page, "TOPLEFT", PAD, -418)
    note:SetWidth(CONTENT_W)
    note:SetJustifyH("LEFT")
    note:SetText(L["HISTORY_NOTE"])

    -- Refreshed every few seconds while the tab is on screen only.
    page:SetScript("OnShow", function()
        HistoryPage:Refresh()
        if C_Timer and C_Timer.NewTicker and not HistoryPage._ticker then
            HistoryPage._ticker = C_Timer.NewTicker(REFRESH_SECONDS, function() HistoryPage:Refresh() end)
        end
    end)
    page:SetScript("OnHide", function()
        if HistoryPage._ticker then
            HistoryPage._ticker:Cancel()
            HistoryPage._ticker = nil
        end
    end)
    return page
end

local function BuildTabs(stats)
    local tabs = {}
    local previous
    for _, key in ipairs(TABS) do
        local tab = CreateFrame("Button", nil, stats, "UIPanelButtonTemplate")
        tab:SetSize(96, 22)
        if previous then
            tab:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            tab:SetPoint("TOPLEFT", stats, "BOTTOMLEFT", 10, 2)
        end
        tab:SetText(L[key == "history" and "STATS_TAB_HISTORY" or "STATS_TAB_SESSION"])
        tab:SetScript("OnClick", function() HistoryPage:SelectTab(key) end)
        tabs[key] = tab
        previous = tab
    end
    return tabs
end

function HistoryPage:GetTab()
    local tab = Addon.db and Addon.db.statsTab
    return tab == "history" and "history" or "session"
end

---Show one tab of the Stats window; remembered across sessions.
---@param tab string "session" or "history"
function HistoryPage:SelectTab(tab)
    tab = tab == "history" and "history" or "session"
    if Addon.db then Addon.db.statsTab = tab end
    self:ApplyTab()
end

function HistoryPage:ApplyTab()
    local stats, page = self.stats, self.page
    if not stats or not page then return end
    local history = self:GetTab() == "history"
    for _, key in ipairs(SESSION_KEYS) do
        if stats[key] and not history then
            stats[key]:Show()
        elseif stats[key] then
            stats[key]:Hide()
        end
    end
    if history then
        page:Show()
        stats:SetHeight(HISTORY_HEIGHT)
    else
        page:Hide()
        -- Puts the Details section and the window height back as the Session tab left them.
        if stats.SetDetailExpanded then
            stats:SetDetailExpanded(stats.IsDetailExpanded and stats:IsDetailExpanded())
        end
    end
    for key, button in pairs(self.tabs or {}) do
        if key == self:GetTab() then button:LockHighlight() else button:UnlockHighlight() end
    end
end

function HistoryPage:Refresh()
    local page = self.page
    if not page or not page:IsShown() then return end
    local data = Addon.History and Addon.History:Get()
    if not data then return end

    local hours, days = {}, {}
    for h = 0, 23 do hours[h + 1] = data.hours[h] end
    for i, wday in ipairs(DAY_ORDER) do days[i] = data.days[wday] end
    SetHistogram(page.Hours, hours)
    SetHistogram(page.Days, days)

    local total = data.xp.quest + data.xp.other
    page.XPGained.Value:SetText(FormatNumber(total))
    local rate = Addon.History:GetXPPerHour()
    page.XPPerHour.Value:SetText(rate and FormatNumber(rate) or "-")
    page.RestedUsed.Value:SetText(FormatNumber(data.xp.rested))
    page.Recorded.Value:SetText(FormatSeconds(data.seconds))
    SetShare(page.QuestShare, data.xp.quest, total)
    SetShare(page.OtherShare, data.xp.other, total)

    local q = data.quests
    page.Accepted.Value:SetText(FormatNumber(q.accepted))
    page.TurnedIn.Value:SetText(FormatNumber(q.turnedIn))
    local average = Addon.History:GetAverageQuestSeconds()
    page.AverageTime.Value:SetText(average and FormatSeconds(average) or "-")
    page.QuestGold.Value:SetText(FormatMoney(q.money))
    local colored = q.green + q.yellow + q.orange
    SetShare(page.Green, q.green, colored)
    SetShare(page.Yellow, q.yellow, colored)
    SetShare(page.Orange, q.orange, colored)
end

---Open the Stats window on the History tab, or close it when that tab is already on screen.
function HistoryPage:Toggle()
    local stats = self.stats
    if not stats then return end
    if stats:IsShown() and self:GetTab() == "history" then
        stats:Hide()
        return
    end
    self:SelectTab("history")
    if not stats:IsShown() and Addon.Stats and Addon.Stats.Toggle then
        Addon.Stats:Toggle()
    end
end

function HistoryPage:Initialize()
    local stats = _G["XPBarEnhancedStatsFrame"]
    if not stats or self.page then return end
    self.stats = stats
    self.page = BuildPage(stats)
    self.tabs = BuildTabs(stats)
    -- After the window's own OnShow, which lays out the Session tab.
    stats:HookScript("OnShow", function() HistoryPage:ApplyTab() end)
    self:ApplyTab()
end

return HistoryPage
