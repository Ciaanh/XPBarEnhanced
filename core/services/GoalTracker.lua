-- XP Bar Enhanced - Goal Tracker
-- Milestone notifications: announces 25/50/75% level progress with the
-- estimated time to ding. Driven entirely by EventBus broadcasts (no WoW
-- events, no OnUpdate); milestones fire once per level.

local Addon = XPBarEnhanced
Addon.GoalTracker = Addon.GoalTracker or {}
local L = Addon.L or {}

---@class GoalTracker
local GoalTracker = Addon.GoalTracker

local MILESTONES = { 25, 50, 75 }

local function isEnabled()
    return Addon.Config and Addon.Config.GetOptionValue
        and Addon.Config:GetOptionValue("goalNotifications") ~= false
end

-- Per-character milestone state lives in the XP session store.
local function getState()
    local session = Addon.Database and Addon.Database.GetSessionData and Addon.Database:GetSessionData()
    if not session then
        return nil
    end
    session.milestones = session.milestones or { level = 0, fired = {} }
    return session.milestones
end

-------------------------------------------------------------------
-- NOTIFICATION TOAST
-- A small bordered frame (icon + text) so milestone announcements
-- read as addon notices, distinct from Blizzard system/error text.
-------------------------------------------------------------------

local ADDON_ICON = tonumber(C_AddOns and C_AddOns.GetAddOnMetadata
    and C_AddOns.GetAddOnMetadata("XPBarEnhanced", "IconTexture")) or 4675649
local TOAST_VISIBLE_SECONDS = 4
local TOAST_MIN_WIDTH = 220
local TOAST_MAX_WIDTH = 480
-- Horizontal chrome around the text: 8 (icon left) + 28 (icon) + 10 (gap) + 12 (right)
local TOAST_TEXT_PADDING = 58

local toastFrame

local function GetToastFrame()
    if toastFrame then
        return toastFrame
    end

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(320, 44)
    f:SetPoint("TOP", UIParent, "TOP", 0, -220)
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
    f:SetBackdropBorderColor(1, 0.82, 0.1, 0.9)
    f:Hide()

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", f, "LEFT", 8, 0)
    icon:SetTexture(ADDON_ICON)
    f.Icon = icon

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetTextColor(1, 0.82, 0.1, 1)
    f.Text = text

    toastFrame = f
    return f
end

local function notify(text)
    local f = GetToastFrame()
    -- Release any previous truncation width so the string measures naturally,
    -- then size the toast to its content (clamped) and re-cap the text.
    f.Text:SetWidth(0)
    f.Text:SetText(text)
    local width = f.Text:GetStringWidth() + TOAST_TEXT_PADDING
    if width < TOAST_MIN_WIDTH then
        width = TOAST_MIN_WIDTH
    elseif width > TOAST_MAX_WIDTH then
        width = TOAST_MAX_WIDTH
    end
    f:SetWidth(width)
    f.Text:SetWidth(width - TOAST_TEXT_PADDING)
    f:Show()

    if f._hideTimer then
        f._hideTimer:Cancel()
    end
    f._hideTimer = C_Timer.NewTimer(TOAST_VISIBLE_SECONDS, function()
        f._hideTimer = nil
        f:Hide()
    end)
end

-- Handle an XP broadcast context: fire any newly crossed milestones.
function GoalTracker:OnXPBroadcast(context)
    if not isEnabled() or not context then
        return
    end

    -- Skip level-up broadcasts: UnitXP/UnitLevel can lag the event, and a
    -- mixed-stale context would silently mark the new level's milestones as
    -- fired. The following PLAYER_XP_UPDATE carries consistent values.
    if context.hasLeveledUp then
        return
    end

    local currentXP = tonumber(context.currentXP)
    local xpMax = tonumber(context.xpMax)
    local level = tonumber(context.level)
    if not currentXP or not xpMax or xpMax <= 0 or not level or level <= 0 then
        return
    end

    local state = getState()
    if not state then
        return
    end

    -- New level (or first run): reset fired milestones. On the very first
    -- run for a character, seed already-crossed milestones silently so
    -- pre-existing progress is not announced at login.
    if state.level ~= level then
        local firstRun = not state.level or state.level == 0
        state.level = level
        state.fired = {}
        if firstRun then
            local seedPct = (currentXP / xpMax) * 100
            for _, milestone in ipairs(MILESTONES) do
                if seedPct >= milestone then
                    state.fired[milestone] = true
                end
            end
        end
    end

    local pct = (currentXP / xpMax) * 100
    for _, milestone in ipairs(MILESTONES) do
        if pct >= milestone and not state.fired[milestone] then
            state.fired[milestone] = true
            -- Only announce the highest newly crossed milestone; mark the
            -- lower ones silently (a big quest turn-in can cross several).
            if pct < (milestone + 25) or milestone == 75 then
                local eta = tonumber(context.timeToLevel)
                local text
                if eta and eta > 0 and Addon.TextFormatter and Addon.TextFormatter.FormatTime then
                    text = string.format(L["GOAL_MILESTONE_ETA"],
                        level, milestone, Addon.TextFormatter:FormatTime(eta, true))
                else
                    text = string.format(L["GOAL_MILESTONE"], level, milestone)
                end
                notify(text)
            end
        end
    end
end

-- Preview a milestone notification without touching persisted milestone
-- state (used by /xpbe test milestone for promo screenshots/GIFs).
function GoalTracker:PreviewMilestone(milestone, level, eta)
    milestone = milestone or 75
    level = level or 1
    local text
    if eta and eta > 0 and Addon.TextFormatter and Addon.TextFormatter.FormatTime then
        text = string.format(L["GOAL_MILESTONE_ETA"], level, milestone, Addon.TextFormatter:FormatTime(eta, true))
    else
        text = string.format(L["GOAL_MILESTONE"], level, milestone)
    end
    notify(text)
end

function GoalTracker:Initialize()
    if self._initialized then
        return
    end
    self._initialized = true

    if Addon.EventBus and Addon.EventBus.Register and Addon.EventNames then
        Addon.EventBus:Register(Addon.EventNames.XPBAR_BROADCAST_UPDATE, "goal-tracker", function(context)
            GoalTracker:OnXPBroadcast(context)
        end)
    end
end

return GoalTracker
