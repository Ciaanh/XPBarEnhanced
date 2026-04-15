-- XP Bar Enhanced - Minimap Arc Secondary Bar Style
-- Displays a minimap-linked icon that toggles a centered reputation arc.

local Addon = XPBarEnhanced
local StyleHelpers = Addon.UI.StyleHelpers

---@class XPBarMinimapArcReputationMixin
XPBarMinimapArcReputationMixin = {}
local StyleMixin = {}

local MAX_SEGMENTS = 60
local DISPLAY_SEGMENTS = 40
local SEGMENT_WIDTH_PX = 7
local SEGMENT_HEIGHT_PX = 12
local SEGMENT_BORDER_PAD_PX = 2
local BASE_ICON_SIZE = 28
local REPUTATION_ARC_RADIUS = 22
local REPUTATION_ICON_TEXTURE = "Interface\\Minimap\\Minimap_shield_normal"

local EMPTY_COLOR = {r = 0.10, g = 0.10, b = 0.10, a = 0.35}
local SEGMENT_BORDER_COLOR = {r = 0.03, g = 0.03, b = 0.03, a = 0.50}

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end



local function GetCursorAngle()
    if not Minimap then
        return 0
    end

    local minimapX, minimapY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale() or 1
    cursorX, cursorY = cursorX / scale, cursorY / scale
    return math.deg(math.atan2(cursorY - minimapY, cursorX - minimapX)) % 360
end

local function GetArcSweepRadians()
    local angleDegrees = Addon and Addon.db and Addon.db.minimapArcDisplayAngle or 135
    angleDegrees = Clamp(tonumber(angleDegrees) or 135, 30, 360)
    return math.rad(angleDegrees)
end

local function GetIconAngleDegrees()
    return Addon and Addon.db and Addon.db.minimapArcIconAngle or 315
end

local function NormalizeAngle(rad)
    local full = 2 * math.pi
    return ((rad % full) + full) % full
end

local function AngleDistance(a, b)
    local diff = math.abs(NormalizeAngle(a) - NormalizeAngle(b))
    if diff > math.pi then
        diff = (2 * math.pi) - diff
    end
    return diff
end

local function GetArcFillOrder(startAngle, sweep)
    local endAngle = startAngle + sweep
    local topAngle = math.pi / 2
    local startDistance = AngleDistance(startAngle, topAngle)
    local endDistance = AngleDistance(endAngle, topAngle)
    local order = {}

    if endDistance <= startDistance then
        for index = 1, DISPLAY_SEGMENTS do
            order[index] = index
        end
    else
        for index = 1, DISPLAY_SEGMENTS do
            order[index] = DISPLAY_SEGMENTS - index + 1
        end
    end

    return order
end

local function OpenReputationPanel()
    if ToggleCharacter then
        ToggleCharacter("ReputationFrame")
    end
end

function StyleMixin:GetPositionConfigKey()
    return "secondaryBarPositions"
end

function StyleMixin:GetFallbackPosition()
    return {
        point = "CENTER",
        relativeTo = "Minimap",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    }
end

function StyleMixin:ShouldAttachToPrimary()
    return false
end

function StyleMixin:GetBroadcastEventName()
    return Addon.EventNames.REPUTATION_BROADCAST_UPDATE
end

function StyleMixin:GetInitialContext()
    if Addon.ReputationSession and Addon.ReputationSession.GetCurrentContext then
        return Addon.ReputationSession:GetCurrentContext()
    end
    return nil
end

function StyleMixin:OnSecondaryLoad()
    if self.RegisterForDrag then
        self:RegisterForDrag("LeftButton")
    end
    self:_CreateArcSegments()
    self:_ApplyIconScale()
    self:_ApplyInitialExpandedState()
    self:_UpdateMinimapAnchor()

    if self.ArcFrame and self.GetFrameLevel and self.ArcFrame.SetFrameLevel then
        local targetLevel = math.max(0, (self:GetFrameLevel() or 8) - 2)
        self.ArcFrame:SetFrameLevel(targetLevel)
    end
    if self.ArcFrame and self.GetFrameStrata and self.ArcFrame.SetFrameStrata then
        self.ArcFrame:SetFrameStrata(self:GetFrameStrata() or "MEDIUM")
    end

    if self.IconTexture and self.IconTexture.SetTexture then
        self.IconTexture:SetTexture(REPUTATION_ICON_TEXTURE)
        if self.IconTexture.SetTexCoord then
            self.IconTexture:SetTexCoord(0, 1, 0, 1)
        end
        if self.IconTexture.SetVertexColor then
            self.IconTexture:SetVertexColor(1, 1, 1, 1)
        end
    end
end

function StyleMixin:OnSecondaryShow()
    -- Style switches can show this frame before a new reputation context arrives.
    -- Keep the icon visible so the minimap control does not appear missing.
    self:SetAlpha(1)
    self:_ApplyIconScale()
    self:_UpdateMinimapAnchor()

    if self.IconTexture and self.IconTexture.SetAlpha then
        self.IconTexture:SetAlpha(1)
    end
end

function StyleMixin:_CreateArcSegments()
    self._arcSegments = self._arcSegments or {}
    self._arcSegmentBorders = self._arcSegmentBorders or {}
    if #self._arcSegments > 0 then
        return
    end

    local arcFrame = self.ArcFrame
    if not arcFrame then
        return
    end

    for index = 1, MAX_SEGMENTS do
        local border = arcFrame:CreateTexture(nil, "ARTWORK", nil, 0)
        border:SetTexture("Interface\\Buttons\\WHITE8X8")
        border:SetSize(SEGMENT_WIDTH_PX + SEGMENT_BORDER_PAD_PX, SEGMENT_HEIGHT_PX + SEGMENT_BORDER_PAD_PX)
        border:SetVertexColor(SEGMENT_BORDER_COLOR.r, SEGMENT_BORDER_COLOR.g, SEGMENT_BORDER_COLOR.b, SEGMENT_BORDER_COLOR.a)
        border:Hide()
        self._arcSegmentBorders[index] = border

        local segment = arcFrame:CreateTexture(nil, "ARTWORK", nil, 1)
        segment:SetTexture("Interface\\Buttons\\WHITE8X8")
        segment:SetSize(SEGMENT_WIDTH_PX, SEGMENT_HEIGHT_PX)
        segment:SetVertexColor(EMPTY_COLOR.r, EMPTY_COLOR.g, EMPTY_COLOR.b, EMPTY_COLOR.a)
        segment:Hide()
        self._arcSegments[index] = segment
    end
end

function StyleMixin:_ApplyIconScale()
    local rawScale = Addon.db and Addon.db.minimapArcIconScale or 1.0
    local iconScale = Clamp(tonumber(rawScale) or 1.0, 0.8, 1.4)
    if self._iconScale == iconScale then
        return
    end

    self._iconScale = iconScale
    local iconSize = BASE_ICON_SIZE * iconScale
    self:SetSize(iconSize, iconSize)
end

function StyleMixin:_ComputeRingRadius()
    if not Minimap then
        return 92
    end

    local minimapEffScale = Minimap:GetEffectiveScale() or 1
    local selfEffScale = self:GetEffectiveScale() or 1
    local minimapRadius = (Minimap:GetWidth() / 2) * (minimapEffScale / selfEffScale)
    local padding = Addon and Addon.db and Addon.db.minimapRingPadding or 10
    padding = math.max(4, math.min(32, math.floor(tonumber(padding) or 10)))
    return minimapRadius + padding
end

function StyleMixin:_GetButtonOffset()
    local angleDegrees = GetIconAngleDegrees()
    local angleRadians = math.rad(angleDegrees)
    local distance = self:_ComputeRingRadius() + 18
    return math.cos(angleRadians) * distance, math.sin(angleRadians) * distance
end

function StyleMixin:_UpdateMinimapAnchor()
    if not Minimap then
        return
    end

    local xOffset, yOffset = self:_GetButtonOffset()
    self:ClearAllPoints()
    self:SetPoint("CENTER", Minimap, "CENTER", xOffset, yOffset)

    if self.ArcFrame then
        self.ArcFrame:ClearAllPoints()
        self.ArcFrame:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    end
end

function StyleMixin:_ApplyInitialExpandedState()
    local initialExpanded = Addon.db and Addon.db.minimapArcStartExpanded == true
    self._lastConfiguredStartExpanded = initialExpanded
    self._arcExpanded = initialExpanded
    self:_ApplyArcVisibility(false)
end

function StyleMixin:_ApplyArcVisibility(useFade)
    if not self.ArcFrame then
        return
    end

    local shouldShow = self._arcExpanded == true
    if shouldShow then
        self.ArcFrame:Show()
        if useFade and self.ArcFrame.SetAlpha then
            self.ArcFrame:SetAlpha(0)
            UIFrameFadeIn(self.ArcFrame, 0.15, 0, 1)
        else
            self.ArcFrame:SetAlpha(1)
        end
    else
        if useFade and self.ArcFrame:IsShown() and self.ArcFrame.SetAlpha then
            UIFrameFadeOut(self.ArcFrame, 0.15, self.ArcFrame:GetAlpha() or 1, 0)
        end
        self.ArcFrame:Hide()
    end
end

function StyleMixin:_RebuildArcGeometryIfNeeded()
    self:_CreateArcSegments()
    if not self.ArcFrame then
        return
    end

    local radius = self:_ComputeRingRadius() + REPUTATION_ARC_RADIUS
    local arcSweep = GetArcSweepRadians()
    local iconAngleRad = math.rad(GetIconAngleDegrees())
    -- Arc spans symmetrically around the icon position
    local startAngle = iconAngleRad - (arcSweep / 2)

    if self._arcRadius == radius and self._arcSweep == arcSweep and self._arcIconAngle == iconAngleRad then
        return
    end

    self._arcRadius = radius
    self._arcSweep = arcSweep
    self._arcIconAngle = iconAngleRad
    self.ArcFrame:SetSize((radius * 2) + 20, (radius * 2) + 20)

    local denominator = math.max(DISPLAY_SEGMENTS - 1, 1)
    self._arcFillOrder = GetArcFillOrder(startAngle, arcSweep)

    for index = 1, DISPLAY_SEGMENTS do
        local angle = startAngle + ((index - 1) / denominator) * arcSweep
        local xOffset = math.cos(angle) * radius
        local yOffset = math.sin(angle) * radius
        local rotation = angle - (math.pi / 2)
        local border = self._arcSegmentBorders[index]
        local segment = self._arcSegments[index]

        border:SetSize(SEGMENT_WIDTH_PX + SEGMENT_BORDER_PAD_PX, SEGMENT_HEIGHT_PX + SEGMENT_BORDER_PAD_PX)
        border:ClearAllPoints()
        border:SetPoint("CENTER", self.ArcFrame, "CENTER", xOffset, yOffset)
        if border.SetRotation then
            border:SetRotation(rotation)
        end
        border:Show()

        segment:SetSize(SEGMENT_WIDTH_PX, SEGMENT_HEIGHT_PX)
        segment:ClearAllPoints()
        segment:SetPoint("CENTER", self.ArcFrame, "CENTER", xOffset, yOffset)
        if segment.SetRotation then
            segment:SetRotation(rotation)
        end
        segment:Show()
    end

    for index = DISPLAY_SEGMENTS + 1, MAX_SEGMENTS do
        self._arcSegmentBorders[index]:Hide()
        self._arcSegments[index]:Hide()
    end
end

function StyleMixin:_RenderArc(context)
    local fillColor = StyleHelpers.GetFactionColor(context)
    local filledCount = math.floor((Clamp(context.percent or 0, 0, 100) / 100) * DISPLAY_SEGMENTS + 0.5)
    local fillOrder = self._arcFillOrder

    if not fillOrder or #fillOrder ~= DISPLAY_SEGMENTS then
        fillOrder = GetArcFillOrder(self._arcIconAngle - (self._arcSweep / 2), self._arcSweep or GetArcSweepRadians())
        self._arcFillOrder = fillOrder
    end

    for index = 1, DISPLAY_SEGMENTS do
        local segmentIndex = fillOrder[index]
        local segment = self._arcSegments[segmentIndex]
        if index <= filledCount then
            segment:SetVertexColor(fillColor.r, fillColor.g, fillColor.b, 0.95)
        else
            segment:SetVertexColor(EMPTY_COLOR.r, EMPTY_COLOR.g, EMPTY_COLOR.b, EMPTY_COLOR.a)
        end
    end
end

function StyleMixin:Render(context)
    if not context then
        return
    end

    local wasAvailable = self._lastContext and self._lastContext.isAvailable
    local isAvailable = context.isAvailable
    self._lastContext = context

    if wasAvailable and not isAvailable then
        self:FadeToAlpha(0)
        return
    end

    if not isAvailable then
        self:SetAlpha(0)
        return
    end

    if not wasAvailable then
        self:FadeToAlpha(1)
    else
        self:SetAlpha(1)
    end

    self:_ApplyIconScale()
    self:_UpdateMinimapAnchor()

    local configuredStartExpanded = Addon.db and Addon.db.minimapArcStartExpanded == true
    if self._arcExpanded == nil or configuredStartExpanded ~= self._lastConfiguredStartExpanded then
        self._lastConfiguredStartExpanded = configuredStartExpanded
        self._arcExpanded = configuredStartExpanded
        self:_ApplyArcVisibility(false)
    end

    local color = StyleHelpers.GetFactionColor(context)
    if self.IconTexture and self.IconTexture.SetVertexColor then
        self.IconTexture:SetVertexColor(1, 1, 1, 1)
    end
    if self.IconBackground and self.IconBackground.SetVertexColor then
        -- Preserve standing feedback on the neutral backdrop without using a circular frame motif.
        self.IconBackground:SetVertexColor(
            0.10 + (color.r * 0.22),
            0.10 + (color.g * 0.22),
            0.10 + (color.b * 0.22),
            0.55
        )
    end

    if self._arcExpanded then
        self:_RebuildArcGeometryIfNeeded()
        self:_RenderArc(context)
    end
end

function StyleMixin:OnEnter()
    if not GameTooltip or not self._lastContext then
        return
    end

    local context = self._lastContext
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(context.name or "", 1, 1, 1)

    if context.isCompanion and context.currentLevel and context.currentLevel > 0 then
        GameTooltip:AddLine(string.format("Level: %d", context.currentLevel), 0.7, 0.7, 0.7)
    elseif context.standingLabel and context.standingLabel ~= "" then
        GameTooltip:AddLine(context.standingLabel, 0.7, 0.7, 0.7)
    end

    GameTooltip:AddLine(string.format("Progress: %s", StyleHelpers.BuildTooltipProgressText(context)), 0.7, 1, 0.7)

    if not context.isMaxed and Addon.TextFormatter then
        local current = Addon.TextFormatter:FormatNumber(context.current or 0, false)
        local maxValue = Addon.TextFormatter:FormatNumber(context.max or 0, false)
        GameTooltip:AddLine(string.format("Current: %s / %s", current, maxValue), 0.7, 0.9, 1)
    end

    if context.sessionGained and context.sessionGained > 0 and Addon.TextFormatter then
        GameTooltip:AddLine(string.format("Gained: +%s", Addon.TextFormatter:FormatNumber(context.sessionGained, false)), 0.5, 1, 0.5)
    end

    if context.repPerHour and context.repPerHour > 0 and Addon.TextFormatter then
        GameTooltip:AddLine(string.format("Rate: %s/hr", Addon.TextFormatter:FormatNumber(context.repPerHour, false)), 0.5, 0.8, 1)
    end

    if context.timeToNextLevel and context.timeToNextLevel > 0 and Addon.TextFormatter then
        GameTooltip:AddLine(string.format("Next: %s", Addon.TextFormatter:FormatTime(context.timeToNextLevel, true)), 0.8, 0.8, 0.5)
    end

    GameTooltip:AddLine("Left-click: Toggle arc", 0.4, 0.4, 0.4)
    GameTooltip:AddLine("Right-click: open Reputation", 0.4, 0.4, 0.4)
    GameTooltip:AddLine("Drag: rotate icon around minimap", 0.4, 0.4, 0.4)
    GameTooltip:Show()
end

function StyleMixin:OnLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function StyleMixin:OnMouseUp(button)
    if self._isDraggingAngle then
        self._isDraggingAngle = nil
        if self.SetScript then
            self:SetScript("OnUpdate", nil)
        end
        return
    end

    if IsShiftKeyDown() then
        return
    end

    if button == "RightButton" then
        OpenReputationPanel()
        return
    end

    if button == "LeftButton" then
        self._arcExpanded = not self._arcExpanded
        self:_ApplyArcVisibility(true)
        if self._arcExpanded and self._lastContext then
            self:_RebuildArcGeometryIfNeeded()
            self:_RenderArc(self._lastContext)
        end
    end
end

function StyleMixin:OnDragStart()
    if not Minimap then
        return
    end

    self._isDraggingAngle = true
    -- Invalidate cached arc geometry so it rebuilds each drag tick
    self._arcIconAngle = nil
    self:SetScript("OnUpdate", function()
        local angle = GetCursorAngle()
        if Addon.db then
            Addon.db.minimapArcIconAngle = angle
        end
        self:_UpdateMinimapAnchor()
        if self._arcExpanded and self._lastContext then
            self:_RebuildArcGeometryIfNeeded()
            self:_RenderArc(self._lastContext)
        end
    end)
end

function StyleMixin:OnDragStop()
    if not self._isDraggingAngle then
        return
    end

    self._isDraggingAngle = nil
    self:SetScript("OnUpdate", nil)
end

XPBarMinimapArcReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
