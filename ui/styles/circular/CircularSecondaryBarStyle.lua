-- XP Bar Enhanced - Circular Secondary Bar Style
-- Displays tracked reputation as an inner arc for the circular primary style.

local Addon = XPBarEnhanced
local Config = Addon.Config
local FALLBACK_SHARED_STYLE_HELPERS = {
    GetSecondaryPositionConfigKey = function()
        return "secondaryBarPositions"
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

---@class XPBarCircularReputationMixin
XPBarCircularReputationMixin = {}
local StyleMixin = {}

local MAX_SEGMENTS = 60
local FULL_CIRCLE_SEGMENTS = 50
local SEMI_CIRCLE_SEGMENTS = 30
local BASE_FRAME_SIZE = 256
local INNER_RADIUS_PX = 60
local SEGMENT_WIDTH_PX = 3
local SEGMENT_HEIGHT_PX = 10

local CIRCULAR_SIZE_SCALES = {
    small = 0.75,
    medium = 1.0,
    large = 1.5,
    huge = 2.0,
}

local EMPTY_COLOR = {r = 0.10, g = 0.10, b = 0.10, a = 0.40}

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function GetCircularScale()
    local size = Config and Config.GetOptionValue and Config:GetOptionValue("circularSize") or "medium"
    if type(size) ~= "string" or not CIRCULAR_SIZE_SCALES[size] then
        size = "medium"
    end
    return CIRCULAR_SIZE_SCALES[size] or 1.0
end

local function ShouldScaleInnerArc()
    return Config and Config.GetOptionValue and Config:GetOptionValue("circularScaleCenterText") == true
end

function StyleMixin:GetPositionConfigKey()
    return SharedStyleHelpers.GetSecondaryPositionConfigKey()
end

function StyleMixin:GetFallbackPosition()
    local barDefPos = Addon.defaults and Addon.defaults.barPositions and Addon.defaults.barPositions.circular
    if barDefPos then
        return {
            point = barDefPos.point or "CENTER",
            relativeTo = barDefPos.relativeTo or "UIParent",
            relativePoint = barDefPos.relativePoint or "CENTER",
            x = barDefPos.x or 0,
            y = barDefPos.y or 0,
        }
    end

    return {
        point = "CENTER",
        relativeTo = "UIParent",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    }
end

function StyleMixin:GetAttachedAnchor()
    return "CENTER", "CENTER", 0, 0
end

function StyleMixin:GetBroadcastEventName()
    return SharedStyleHelpers.GetSecondaryBroadcastEventName()
end

function StyleMixin:GetInitialContext()
    return SharedStyleHelpers.GetSecondaryInitialContext()
end

function StyleMixin:SetDetachedInteractionEnabled(enabled)
    self._detachedInteractionEnabled = enabled and true or false
    if self.EnableMouse then
        self:EnableMouse(self._detachedInteractionEnabled)
    end
end

function StyleMixin:OnSecondaryLoad()
    self:_CreateSegments()
    self:ConfigureDragSupport()
    self:SetDetachedInteractionEnabled(false)
end

function StyleMixin:OnEnter()
    if not self._detachedInteractionEnabled then
        return
    end

    local context = self._lastContext
    if not context or not context.isAvailable then
        return
    end

    if SharedStyleHelpers.ShowSecondaryTooltip then
        SharedStyleHelpers.ShowSecondaryTooltip(self, context, "ANCHOR_TOP")
    elseif GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(context.name or "", 1, 1, 1)
    end

    if GameTooltip then
        GameTooltip:AddLine("Right-click: open Reputation", 0.4, 0.4, 0.4)
        GameTooltip:Show()
    end
end

function StyleMixin:OnLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function StyleMixin:OnMouseUp(button)
    if not self._detachedInteractionEnabled then
        return
    end

    if button == "RightButton" then
        if SharedStyleHelpers.OpenReputationPanel then
            SharedStyleHelpers.OpenReputationPanel()
        elseif ToggleCharacter then
            ToggleCharacter("ReputationFrame")
        end
    end
end

function StyleMixin:OnDragStart()
    if not self._detachedInteractionEnabled then
        return
    end

    if SharedStyleHelpers.BeginSecondaryShiftDrag then
        SharedStyleHelpers.BeginSecondaryShiftDrag(self)
    end
end

function StyleMixin:OnDragStop()
    if not self._detachedInteractionEnabled then
        return
    end

    if SharedStyleHelpers.EndSecondaryDrag then
        SharedStyleHelpers.EndSecondaryDrag(self)
    end
end

function StyleMixin:_CreateSegments()
    self._segments = self._segments or {}
    if #self._segments > 0 then
        return
    end

    for index = 1, MAX_SEGMENTS do
        local segment = self:CreateTexture(nil, "ARTWORK", nil, 1)
        segment:SetTexture("Interface\\Buttons\\WHITE8X8")
        segment:SetSize(SEGMENT_WIDTH_PX, SEGMENT_HEIGHT_PX)
        segment:SetVertexColor(EMPTY_COLOR.r, EMPTY_COLOR.g, EMPTY_COLOR.b, EMPTY_COLOR.a)
        segment:Hide()
        self._segments[index] = segment
    end
end

function StyleMixin:_GetArcConfig()
    local fullCircle = Config and Config.GetOptionValue and Config:GetOptionValue("circularSecondaryFullCircle") == true
    if fullCircle then
        return FULL_CIRCLE_SEGMENTS, math.pi / 2, (2 * math.pi)
    end

    return SEMI_CIRCLE_SEGMENTS, math.pi / 2, math.pi
end

function StyleMixin:_RebuildArcIfNeeded()
    self:_CreateSegments()

    local displayCount, startAngle, sweep = self:_GetArcConfig()
    local scale = ShouldScaleInnerArc() and GetCircularScale() or 1.0
    if self._displayCount == displayCount and self._startAngle == startAngle and self._sweep == sweep and self._arcScale == scale then
        return
    end

    self._displayCount = displayCount
    self._startAngle = startAngle
    self._sweep = sweep
    self._arcScale = scale

    local radius = INNER_RADIUS_PX * scale
    local segmentWidth = SEGMENT_WIDTH_PX * scale
    local segmentHeight = SEGMENT_HEIGHT_PX * scale
    self:SetSize(BASE_FRAME_SIZE * scale, BASE_FRAME_SIZE * scale)

    local clockwise = -1
    local denominator = math.max(displayCount - 1, 1)

    for index = 1, displayCount do
        local angle = startAngle + ((index - 1) / denominator) * sweep
        local xOffset = math.cos(angle) * radius
        local yOffset = math.sin(angle) * radius * clockwise
        local rotation = (clockwise * angle) + startAngle
        local segment = self._segments[index]

        segment:SetSize(segmentWidth, segmentHeight)
        segment:ClearAllPoints()
        segment:SetPoint("CENTER", self, "CENTER", xOffset, yOffset)
        if segment.SetRotation then
            segment:SetRotation(rotation)
        end
        segment:Show()
    end

    for index = displayCount + 1, MAX_SEGMENTS do
        self._segments[index]:Hide()
    end
end

function StyleMixin:QueueReposition()
    if self._repositionQueued then
        return
    end

    self._repositionQueued = true
    C_Timer.After(0, function()
        if not self then
            return
        end

        self._repositionQueued = nil
        self._arcScale = nil
        self._displayCount = nil
        self._startAngle = nil
        self._sweep = nil

        if self:IsShown() then
            self:_RebuildArcIfNeeded()
            if self._lastContext then
                self:_RenderArc(self._lastContext)
            else
                self:Refresh()
            end
        end
    end)
end

function StyleMixin:_RenderArc(context)
    local displayCount = self._displayCount or SEMI_CIRCLE_SEGMENTS
    local fillColor = StyleHelpers.GetFactionColor(context)
    local filledCount = math.floor((Clamp(context.percent or 0, 0, 100) / 100) * displayCount + 0.5)

    for index = 1, displayCount do
        local segment = self._segments[index]
        if index <= filledCount then
            segment:SetVertexColor(fillColor.r, fillColor.g, fillColor.b, 0.95)
        else
            segment:SetVertexColor(EMPTY_COLOR.r, EMPTY_COLOR.g, EMPTY_COLOR.b, EMPTY_COLOR.a)
        end
    end
end

function StyleMixin:Render(context)
    if not SharedStyleHelpers.BeginSecondaryRender(self, context) then
        return
    end

    self:_RebuildArcIfNeeded()
    self:_RenderArc(context)
end

XPBarCircularReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
