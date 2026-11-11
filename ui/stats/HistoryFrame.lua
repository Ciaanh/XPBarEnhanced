-- XP Bar Enhanced - HistoryFrame.lua
-- The History window: lifetime figures from History.lua, laid out as cards,
-- two histograms (hours of the day, days of the week) and share bars. Built in
-- code rather than XML; opened by /xpbe history and by the Stats window's
-- History button. Nothing here is read from the game.

local Addon = XPBarEnhanced
local L = Addon.L or LibStub("AceLocale-3.0"):GetLocale("XPBarEnhanced")

Addon.HistoryFrame = Addon.HistoryFrame or {}
local HistoryFrame = Addon.HistoryFrame

local WIDTH, HEIGHT = 520, 600
local PAD = 14
local CONTENT_W = WIDTH - 2 * PAD - 8

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

local frame

local function FormatNumber(value)
    local formatter = Addon.TextFormatter
    if formatter and formatter.FormatNumber then
        return formatter:FormatNumber(value, false)
    end
    return tostring(math.floor((value or 0) + 0.5))
end

local function FormatMoney(copper)
    copper = math.floor(copper or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    return string.format("%d g %d s %d c", gold, silver, copper % 100)
end

local function FormatSeconds(seconds)
    return Addon.Utils.FormatDuration(seconds or 0)
end

local function Percent(part, total)
    if not total or total <= 0 then return 0 end
    return math.floor(part / total * 100 + 0.5)
end

-------------------------------------------------------------------
-- WIDGET HELPERS (return plain tables of regions so Refresh can set text)
-------------------------------------------------------------------

local function Heading(parent, text, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    fs:SetText(text)
    return fs
end

local function SmallCaps(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
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
    card.Label:SetPoint("TOPLEFT", 8, -6)
    card.Label:SetText(label)
    card.Value = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    card.Value:SetPoint("BOTTOMLEFT", 8, 7)
    card.Value:SetPoint("RIGHT", -6, 0)
    card.Value:SetJustifyH("LEFT")
    return card
end

-- A row: label on the left, a track with a fill, and "count (pct %)" on the right.
local function ShareBar(parent, label, color, x, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(CONTENT_W, 16)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Label:SetPoint("LEFT", 0, 0)
    row.Label:SetWidth(150)
    row.Label:SetJustifyH("LEFT")
    row.Label:SetText(label)
    row.Value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Value:SetPoint("RIGHT", 0, 0)
    row.Value:SetWidth(110)
    row.Value:SetJustifyH("RIGHT")
    row.Track = row:CreateTexture(nil, "BACKGROUND")
    row.Track:SetPoint("LEFT", row.Label, "RIGHT", 6, 0)
    row.Track:SetPoint("RIGHT", row.Value, "LEFT", -8, 0)
    row.Track:SetHeight(10)
    row.Track:SetColorTexture(unpack(COLORS.track))
    row.Fill = row:CreateTexture(nil, "ARTWORK")
    row.Fill:SetPoint("LEFT", row.Track, "LEFT", 0, 0)
    row.Fill:SetHeight(10)
    row.Fill:SetColorTexture(unpack(color))
    return row
end

local function SetShare(row, count, total)
    local pct = Percent(count, total)
    row.Value:SetText(string.format("%s (%d %%)", FormatNumber(count), pct))
    local width = (row.Track:GetWidth() or 0) * (total > 0 and count / total or 0)
    if width >= 1 then
        row.Fill:SetWidth(width)
        row.Fill:Show()
    else
        row.Fill:Hide()
    end
end

-- A histogram of n bars in a width x height area, with a caption under some bars.
local function Histogram(parent, title, n, x, y, width, height)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(width, height + 28)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box.Title = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    box.Title:SetPoint("TOPLEFT", 0, 0)
    box.Title:SetText(string.upper(title))
    box.Plot = CreateFrame("Frame", nil, box)
    box.Plot:SetPoint("TOPLEFT", 0, -16)
    box.Plot:SetSize(width, height)
    box.n, box.width, box.height = n, width, height
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
-- WINDOW
-------------------------------------------------------------------

local function Build()
    local f = CreateFrame("Frame", "XPBarEnhancedHistoryFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER", 40, 0)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnShow", function() HistoryFrame:Refresh() end)
    f:Hide()

    local title = f.TitleText or f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    if not f.TitleText then title:SetPoint("TOP", 0, -6) end
    title:SetText(L["HISTORY_TITLE"])

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -26)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    f.Content = content

    -- Histograms
    f.Hours = Histogram(content, L["HISTORY_HOURS_PLAYED"], 24, PAD, -12, 300, 56)
    f.Days = Histogram(content, L["HISTORY_DAYS_OF_WEEK"], 7, PAD + 320, -12, CONTENT_W - 320, 56)
    for i = 1, 24 do
        f.Hours.captions[i]:SetText((i - 1) % 3 == 0 and string.format(L["HISTORY_HOUR_FMT"], i - 1) or "")
    end
    for i, wday in ipairs(DAY_ORDER) do
        f.Days.captions[i]:SetText(L["HISTORY_DAY_" .. wday])
    end

    -- Experience
    f.ExperienceHeading = Heading(content, L["HISTORY_EXPERIENCE"], -118)
    local cw = math.floor((CONTENT_W - 16) / 3)
    f.XPGained = Card(content, L["HISTORY_XP_GAINED"], PAD, -146, cw, 54)
    f.XPPerHour = Card(content, L["HISTORY_XP_PER_HOUR"], PAD + cw + 8, -146, cw, 54)
    f.Recorded = Card(content, L["HISTORY_TIME_RECORDED"], PAD + 2 * (cw + 8), -146, cw, 54)
    f.QuestShare = ShareBar(content, L["HISTORY_QUEST_XP"], COLORS.quest, PAD, -210)
    f.OtherShare = ShareBar(content, L["HISTORY_OTHER_XP"], COLORS.other, PAD, -232)

    -- Quests
    f.QuestsHeading = Heading(content, L["HISTORY_QUESTS"], -268)
    local qw = math.floor((CONTENT_W - 24) / 4)
    f.Accepted = Card(content, L["HISTORY_ACCEPTED"], PAD, -296, qw, 54)
    f.TurnedIn = Card(content, L["HISTORY_TURNED_IN"], PAD + (qw + 8), -296, qw, 54)
    f.AverageTime = Card(content, L["HISTORY_AVERAGE_QUEST_TIME"], PAD + 2 * (qw + 8), -296, qw, 54)
    f.QuestGold = Card(content, L["HISTORY_QUEST_GOLD"], PAD + 3 * (qw + 8), -296, qw, 54)
    f.QuestGold.Value:SetFontObject("GameFontHighlight")
    SmallCaps(content, L["HISTORY_QUEST_COLOURS"], PAD, -364)
    f.Green = ShareBar(content, L["HISTORY_GREEN"], COLORS.green, PAD, -384)
    f.Yellow = ShareBar(content, L["HISTORY_YELLOW"], COLORS.yellow, PAD, -406)
    f.Orange = ShareBar(content, L["HISTORY_ORANGE"], COLORS.orange, PAD, -428)

    f.Note = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.Note:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -462)
    f.Note:SetWidth(CONTENT_W)
    f.Note:SetJustifyH("LEFT")
    f.Note:SetText(L["HISTORY_NOTE"])

    if UISpecialFrames and not tContains(UISpecialFrames, "XPBarEnhancedHistoryFrame") then
        tinsert(UISpecialFrames, "XPBarEnhancedHistoryFrame")
    end
    return f
end

function HistoryFrame:GetFrame()
    if not frame then frame = Build() end
    return frame
end

function HistoryFrame:Refresh()
    if not frame or not frame:IsShown() then return end
    local data = Addon.History and Addon.History:Get()
    if not data then return end

    local hours, days = {}, {}
    for h = 0, 23 do hours[h + 1] = data.hours[h] end
    for i, wday in ipairs(DAY_ORDER) do days[i] = data.days[wday] end
    SetHistogram(frame.Hours, hours)
    SetHistogram(frame.Days, days)

    local total = data.xp.quest + data.xp.other
    frame.XPGained.Value:SetText(FormatNumber(total))
    local rate = Addon.History:GetXPPerHour()
    frame.XPPerHour.Value:SetText(rate and FormatNumber(rate) or "-")
    frame.Recorded.Value:SetText(FormatSeconds(data.seconds))
    SetShare(frame.QuestShare, data.xp.quest, total)
    SetShare(frame.OtherShare, data.xp.other, total)

    local q = data.quests
    frame.Accepted.Value:SetText(FormatNumber(q.accepted))
    frame.TurnedIn.Value:SetText(FormatNumber(q.turnedIn))
    local average = Addon.History:GetAverageQuestSeconds()
    frame.AverageTime.Value:SetText(average and FormatSeconds(average) or "-")
    frame.QuestGold.Value:SetText(FormatMoney(q.money))
    local colored = q.green + q.yellow + q.orange
    SetShare(frame.Green, q.green, colored)
    SetShare(frame.Yellow, q.yellow, colored)
    SetShare(frame.Orange, q.orange, colored)
end

function HistoryFrame:Toggle()
    local f = self:GetFrame()
    if f:IsShown() then f:Hide() else f:Show() end
end

-- A History button in the Stats window's title bar, once that window exists.
function HistoryFrame:Initialize()
    local stats = _G["XPBarEnhancedStatsFrame"]
    if not stats or stats.HistoryButton then return end
    local button = CreateFrame("Button", nil, stats, "UIPanelButtonTemplate")
    button:SetSize(72, 20)
    button:SetText(L["HISTORY_BUTTON"])
    if stats.CloseButton then
        button:SetPoint("RIGHT", stats.CloseButton, "LEFT", -2, 0)
    else
        button:SetPoint("TOPRIGHT", stats, "TOPRIGHT", -30, -4)
    end
    button:SetScript("OnClick", function() HistoryFrame:Toggle() end)
    stats.HistoryButton = button
end

-- Keep the window current while it is open.
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(5, function() HistoryFrame:Refresh() end)
end

return HistoryFrame
