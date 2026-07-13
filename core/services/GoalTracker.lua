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

local function notify(text)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(text, 1.0, 0.82, 0.1, 1.0)
    else
        print(text)
    end

    if Addon.Config and Addon.Config.GetOptionValue
        and Addon.Config:GetOptionValue("goalSound") == true
        and PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        PlaySound(SOUNDKIT.RAID_WARNING)
    end
end

-- Handle an XP broadcast context: fire any newly crossed milestones.
function GoalTracker:OnXPBroadcast(context)
    if not isEnabled() or not context then
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

    -- New level (or first run): reset fired milestones.
    if state.level ~= level then
        state.level = level
        state.fired = {}
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
