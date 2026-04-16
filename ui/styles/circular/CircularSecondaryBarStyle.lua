-- XP Bar Enhanced - Circular Secondary Bar Style
-- Displays tracked reputation as an inner arc for the circular primary style.

local Addon = XPBarEnhanced
local SharedStyleHelpers = Addon.UI.SharedStyleHelpers
local StyleHelpers = Addon.UI.StyleHelpers

---@class XPBarCircularReputationMixin
XPBarCircularReputationMixin = {}
local StyleMixin = {}

local MAX_SEGMENTS = 60
local FULL_CIRCLE_SEGMENTS = 50
local SEMI_CIRCLE_SEGMENTS = 30
local INNER_RADIUS_PX = 60
local SEGMENT_WIDTH_PX = 3
local SEGMENT_HEIGHT_PX = 10

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

function StyleMixin:OnSecondaryLoad()
    self:_CreateSegments()
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
    local fullCircle = Addon.db and Addon.db.circularSecondaryFullCircle == true
    if fullCircle then
        return FULL_CIRCLE_SEGMENTS, math.pi / 2, (2 * math.pi)
    end

    return SEMI_CIRCLE_SEGMENTS, math.pi / 2, math.pi
end

function StyleMixin:_RebuildArcIfNeeded()
    self:_CreateSegments()

    local displayCount, startAngle, sweep = self:_GetArcConfig()
    if self._displayCount == displayCount and self._startAngle == startAngle and self._sweep == sweep then
        return
    end

    self._displayCount = displayCount
    self._startAngle = startAngle
    self._sweep = sweep

    local clockwise = -1
    local denominator = math.max(displayCount - 1, 1)

    for index = 1, displayCount do
        local angle = startAngle + ((index - 1) / denominator) * sweep
        local xOffset = math.cos(angle) * INNER_RADIUS_PX
        local yOffset = math.sin(angle) * INNER_RADIUS_PX * clockwise
        local rotation = (clockwise * angle) + startAngle
        local segment = self._segments[index]

        segment:SetSize(SEGMENT_WIDTH_PX, SEGMENT_HEIGHT_PX)
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
