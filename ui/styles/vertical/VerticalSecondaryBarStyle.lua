-- XP Bar Enhanced - Vertical Secondary Bar Style
-- Slim 20x300 vertical reputation bar displayed alongside the vertical primary column.
-- Tooltip-only: no on-bar label (too narrow), all info surfaced on hover.

local Addon = XPBarEnhanced
local FALLBACK_SHARED_STYLE_HELPERS = {
    GetSecondaryPositionConfigKey = function()
        return "secondaryBarPositions"
    end,
    BuildConfiguredStyleCenterFallback = function(x, y)
        return {
            point = "CENTER",
            relativeTo = "UIParent",
            relativePoint = "CENTER",
            x = x or 0,
            y = y or 0,
        }
    end,
    GetSecondaryBroadcastEventName = function()
        return (Addon.EventNames and Addon.EventNames.REPUTATION_BROADCAST_UPDATE) or "REPUTATION:BROADCAST_UPDATE"
    end,
    GetSecondaryInitialContext = function()
        if Addon.ReputationSession and Addon.ReputationSession.GetCurrentContext then
            return Addon.ReputationSession:GetCurrentContext()
        end
        return nil
    end,
    BeginSecondaryRender = function(frame, context)
        frame._lastContext = context
        if not context or not context.isAvailable then
            frame:SetAlpha(0)
            return false
        end
        frame:SetAlpha(1)
        return true
    end,
    ApplyStatusBarProgress = function(bar, context, color)
        if not bar or not context then
            return
        end
        bar:SetMinMaxValues(context.min or 0, context.max or 1)
        bar:SetValue(context.current or 0)
        if color then
            bar:SetStatusBarColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
        end
    end,
    ShowSecondaryTooltip = function(frame, context, anchor)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(frame, anchor or "ANCHOR_TOP")
        GameTooltip:AddLine((context and context.name) or "", 1, 1, 1)
    end,
    AddSecondaryTooltipMoveHint = function()
    end,
    FinishSecondaryTooltip = function()
        if GameTooltip then
            GameTooltip:Show()
        end
    end,
    HideTooltip = function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end,
    HandleStandardSecondaryMouseUp = function(frame, button, onRightClick)
        if button == "RightButton" and onRightClick then
            onRightClick(frame)
        end
    end,
    OpenReputationPanel = function()
        if ToggleCharacter then
            ToggleCharacter("ReputationFrame")
        end
    end,
    BeginSecondaryShiftDrag = function()
        return false
    end,
    EndSecondaryDrag = function(frame)
        if frame and frame.StopMovingOrSizing then
            frame:StopMovingOrSizing()
        end
    end,
}

local FALLBACK_STYLE_HELPERS = {
    GetFactionColor = function()
        return {r = 0.7, g = 0.3, b = 0.85, a = 1}
    end,
}

local function ResolveSharedStyleHelpers()
    local shared = Addon and Addon.UI and Addon.UI.SharedStyleHelpers
    return shared or FALLBACK_SHARED_STYLE_HELPERS
end

local function ResolveStyleHelpers()
    local style = Addon and Addon.UI and Addon.UI.StyleHelpers
    return style or FALLBACK_STYLE_HELPERS
end

local SharedStyleHelpers = setmetatable({}, {
    __index = function(_, key)
        return ResolveSharedStyleHelpers()[key]
    end,
})

local StyleHelpers = setmetatable({}, {
    __index = function(_, key)
        return ResolveStyleHelpers()[key]
    end,
})

---@class XPBarVerticalReputationMixin
XPBarVerticalReputationMixin = {}
local StyleMixin = {}

local function GetBarColor(context)
    return StyleHelpers.GetFactionColor(context)
end


function StyleMixin:GetPositionConfigKey()
    return SharedStyleHelpers.GetSecondaryPositionConfigKey()
end

function StyleMixin:GetFallbackPosition()
    return SharedStyleHelpers.BuildConfiguredStyleCenterFallback(44, 0, 44, 0)
end

function StyleMixin:GetAttachedAnchor()
    -- Attach to the RIGHT of the vertical primary column (2px gap).
    -- All horizontal styles use the default BOTTOM→TOP stacking from SecondaryBarManager.
    return "LEFT", "RIGHT", 2, 0
end

function StyleMixin:GetBroadcastEventName()
    return SharedStyleHelpers.GetSecondaryBroadcastEventName()
end

function StyleMixin:GetInitialContext()
    return SharedStyleHelpers.GetSecondaryInitialContext()
end


function StyleMixin:Render(context)
    if not SharedStyleHelpers.BeginSecondaryRender(self, context) then
        return
    end

    local color = GetBarColor(context)
    SharedStyleHelpers.ApplyStatusBarProgress(self.Bar, context, color)
end

function StyleMixin:OnEnter()
    if not self._lastContext then
        return
    end
    local context = self._lastContext
    SharedStyleHelpers.ShowSecondaryTooltip(self, context, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Right-click: open Reputation", 0.4, 0.4, 0.4)
    SharedStyleHelpers.AddSecondaryTooltipMoveHint(context)
    SharedStyleHelpers.FinishSecondaryTooltip()
end

function StyleMixin:OnLeave()
    SharedStyleHelpers.HideTooltip()
end

function StyleMixin:OnMouseUp(button)
    SharedStyleHelpers.HandleStandardSecondaryMouseUp(self, button, self.OnRightClick)
end

function StyleMixin:OnRightClick()
    SharedStyleHelpers.OpenReputationPanel()
end

function StyleMixin:OnDragStart()
    SharedStyleHelpers.BeginSecondaryShiftDrag(self)
end

function StyleMixin:OnDragStop()
    SharedStyleHelpers.EndSecondaryDrag(self)
end

function StyleMixin:OnSecondaryLoad()
    self:ConfigureDragSupport()
end

XPBarVerticalReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
