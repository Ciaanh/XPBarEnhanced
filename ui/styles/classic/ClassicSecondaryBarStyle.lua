-- XP Bar Enhanced - Classic Secondary Bar Style
-- Displays the secondary source as a bar with the same chrome as the Classic
-- XP bar, its neutral fill tinted with a standing or source color.

local Addon = XPBarEnhanced
local SharedStyleHelpers = Addon and Addon.UI and Addon.UI.SharedStyleHelpers or {}
local StyleHelpers = Addon and Addon.UI and Addon.UI.StyleHelpers or {}

local function EnsureHelpers()
    local ui = Addon and Addon.UI
    if ui then
        if not SharedStyleHelpers or not SharedStyleHelpers.GetSecondaryPositionConfigKey then
            SharedStyleHelpers = ui.SharedStyleHelpers or SharedStyleHelpers
        end
        if not StyleHelpers or not StyleHelpers.GetFactionColor then
            StyleHelpers = ui.StyleHelpers or StyleHelpers
        end
    end
end

local function GetFactionColor(context)
    EnsureHelpers()
    if StyleHelpers and StyleHelpers.GetFactionColor then
        return StyleHelpers.GetFactionColor(context)
    end

    return {r = 0.7, g = 0.3, b = 0.85, a = 1}
end

---@class XPBarClassicReputationMixin
XPBarClassicReputationMixin = {}
local StyleMixin = {}

-- Standing tints indexed by reaction level (1 = Hated, 8 = Exalted), following
-- Blizzard's barAtlases table in ReputationBarOverrides.lua. The values are the
-- bright half of Blizzard's red/orange/yellow/green/blue fills, sampled by
-- assets/raw/build_classic_bar.py, so the tinted neutral fill reproduces them
-- without depending on the client's atlases.
local RED = {r = 0.90, g = 0.34, b = 0.32}
local ORANGE = {r = 0.96, g = 0.49, b = 0.22}
local YELLOW = {r = 0.79, g = 0.61, b = 0.00}
local GREEN = {r = 0.39, g = 0.89, b = 0.31}
local BLUE = {r = 0.33, g = 0.45, b = 0.90}

local STANDING_COLORS = {
    RED,    -- 1 Hated
    RED,    -- 2 Hostile
    ORANGE, -- 3 Unfriendly
    YELLOW, -- 4 Neutral
    GREEN,  -- 5 Friendly
    GREEN,  -- 6 Honored
    GREEN,  -- 7 Revered
    GREEN,  -- 8 Exalted
}

-- Explicitly enforce draw order so the fill is never occluded:
-- background < status fill < border < label.
local function ApplyFrameLayering(frame)
    if not frame or not frame.GetFrameLevel then
        return
    end

    local baseLevel = frame:GetFrameLevel() or 1

    if frame.BackgroundFrame and frame.BackgroundFrame.SetFrameLevel then
        frame.BackgroundFrame:SetFrameLevel(baseLevel)
    end
    if frame.Bar and frame.Bar.SetFrameLevel then
        frame.Bar:SetFrameLevel(baseLevel + 1)
    end
    if frame.BorderFrame and frame.BorderFrame.SetFrameLevel then
        frame.BorderFrame:SetFrameLevel(baseLevel + 2)
    end
    if frame.LabelContainer and frame.LabelContainer.SetFrameLevel then
        frame.LabelContainer:SetFrameLevel(baseLevel + 3)
    end
end

-- Returns the tint for the given context's fill.
local function GetBarFill(context)
    if context.isCompanion then
        return GetFactionColor(context)
    end

    if context.factionType == "major" or context.factionType == "paragon" then
        return BLUE
    end

    local level = context.reactionLevel
    if level and STANDING_COLORS[level] then
        return STANDING_COLORS[level]
    end

    return GetFactionColor(context)
end

-- Tint the neutral fill texture set in ClassicSecondaryBarTemplate.xml.
local function ApplyBarFill(bar, color)
    local c = color or GetFactionColor(nil)
    bar:SetStatusBarColor(c.r, c.g, c.b)
end


function StyleMixin:GetPositionConfigKey()
    EnsureHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.GetSecondaryPositionConfigKey then
        return SharedStyleHelpers.GetSecondaryPositionConfigKey()
    end
    return "secondaryBarPositions"
end

function StyleMixin:GetFallbackPosition()
    EnsureHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.BuildConfiguredStyleOffsetFallback then
        return SharedStyleHelpers.BuildConfiguredStyleOffsetFallback("BOTTOM", 0, 34, 20)
    end
    return {
        point = "BOTTOM",
        relativeTo = "UIParent",
        relativePoint = "BOTTOM",
        x = 0,
        y = 54,
    }
end

function StyleMixin:GetTextTickerInterval()
    return 1.0
end

function StyleMixin:GetTextTickerContext()
    return self._lastContext or self:GetInitialContext()
end

function StyleMixin:OnTextTick(context)
    EnsureHelpers()
    if context and self.LabelContainer then
        if SharedStyleHelpers and SharedStyleHelpers.BuildSecondaryLabel then
            self.LabelContainer.Label:SetText(SharedStyleHelpers.BuildSecondaryLabel(context))
        else
            self.LabelContainer.Label:SetText(context.name or "")
        end
    end
end

function StyleMixin:GetBroadcastEventName()
    EnsureHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.GetSecondaryBroadcastEventName then
        return SharedStyleHelpers.GetSecondaryBroadcastEventName()
    end
    return (Addon.EventNames and Addon.EventNames.REPUTATION_BROADCAST_UPDATE) or "REPUTATION:BROADCAST_UPDATE"
end

function StyleMixin:GetInitialContext()
    EnsureHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.GetSecondaryInitialContext then
        return SharedStyleHelpers.GetSecondaryInitialContext()
    end
    if Addon:IsFeatureEnabled("reputation", "GetCurrentContext") then
        return Addon.ReputationSession:GetCurrentContext()
    end
    return nil
end


function StyleMixin:Render(context)
    EnsureHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.BeginSecondaryRender then
        if not SharedStyleHelpers.BeginSecondaryRender(self, context) then
            return
        end
    else
        self._lastContext = context
        if not context or not context.isAvailable then
            self:SetAlpha(0)
            return
        end
        self:SetAlpha(1)
    end

    if SharedStyleHelpers and SharedStyleHelpers.ApplyStatusBarProgress then
        SharedStyleHelpers.ApplyStatusBarProgress(self.Bar, context, nil)
    else
        self.Bar:SetMinMaxValues(context.min or 0, context.max or 1)
        self.Bar:SetValue(context.current or 0)
    end
    ApplyBarFill(self.Bar, GetBarFill(context))
    if self.LabelContainer then
        if SharedStyleHelpers and SharedStyleHelpers.BuildSecondaryLabel then
            self.LabelContainer.Label:SetText(SharedStyleHelpers.BuildSecondaryLabel(context))
        else
            self.LabelContainer.Label:SetText(context.name or "")
        end
    end
end

function StyleMixin:OnEnter()
    EnsureHelpers()
    if not self._lastContext then
        return
    end
    local context = self._lastContext
    if SharedStyleHelpers and SharedStyleHelpers.ShowSecondaryTooltip then
        SharedStyleHelpers.ShowSecondaryTooltip(self, context, "ANCHOR_TOP")
    else
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(context.name or "", 1, 1, 1)
        end
    end
    GameTooltip:AddLine(Addon.L["TT_OPEN_REPUTATION"], 0.4, 0.4, 0.4)
    if SharedStyleHelpers and SharedStyleHelpers.AddSecondaryTooltipMoveHint then
        SharedStyleHelpers.AddSecondaryTooltipMoveHint(context)
    end
    if SharedStyleHelpers and SharedStyleHelpers.FinishSecondaryTooltip then
        SharedStyleHelpers.FinishSecondaryTooltip()
    elseif GameTooltip then
        GameTooltip:Show()
    end
end

function StyleMixin:OnLeave()
    EnsureHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.HideTooltip then
        SharedStyleHelpers.HideTooltip()
    elseif GameTooltip then
        GameTooltip:Hide()
    end
end

function StyleMixin:OnMouseUp(button)
    EnsureHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.HandleStandardSecondaryMouseUp then
        SharedStyleHelpers.HandleStandardSecondaryMouseUp(self, button, self.OnRightClick)
        return
    end
    if button == "RightButton" then
        self:OnRightClick()
    end
end

function StyleMixin:OnRightClick()
    EnsureHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.OpenReputationPanel then
        SharedStyleHelpers.OpenReputationPanel()
    elseif ToggleCharacter then
        ToggleCharacter("ReputationFrame")
    end
end


function StyleMixin:OnDragStart()
    EnsureHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.BeginSecondaryShiftDrag then
        SharedStyleHelpers.BeginSecondaryShiftDrag(self)
    end
end

function StyleMixin:OnDragStop()
    EnsureHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.EndSecondaryDrag then
        SharedStyleHelpers.EndSecondaryDrag(self)
    end
end

--- Match the Classic primary bar's configured width. The secondary bar is
--- anchored BOTTOM-to-TOP of the primary, so any mismatch reads immediately as
--- two bars of different lengths stacked on each other.
function StyleMixin:ResizeToConfiguredWidth()
    local Chrome = Addon.UI and Addon.UI.ClassicChrome
    if not Chrome then
        return
    end

    -- The label fills LabelContainer, which fills the frame, so it follows the
    -- new size without being told.
    Chrome.LayoutBar(self, self.Bar)
end

function StyleMixin:OnSecondaryLoad()
    EnsureHelpers()
    self:ConfigureDragSupport()
    ApplyFrameLayering(self)

    local Chrome = Addon.UI and Addon.UI.ClassicChrome
    if Chrome then
        Chrome.BuildChrome(self, self.Bar, "Border")
    end
    self:ResizeToConfiguredWidth()
end

XPBarClassicReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
