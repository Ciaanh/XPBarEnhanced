if not XPBarStyleBuilder or not XPBarMixinBase then
    error("MinimapRingBarStyle: core (StyleBuilder/BaseMixin) not loaded.")
end

local Addon = XPBarEnhanced

local MAX_SEGMENTS = 100
local DEFAULT_SEGMENTS = 60
local REFERENCE_SEGMENT_COUNT = 100

local SEGMENT_TYPE = {
    HIDDEN = -1,
    EMPTY = 0,
    CURRENT_XP = 1,
    RESTED = 2,
    QUEST_COMPLETE = 3,
    QUEST_INCOMPLETE = 4,
}

local EMPTY_SEGMENT_COLOR = {r = 0.08, g = 0.08, b = 0.08, a = 0.35}

local MINIMAP_RING_STYLE = {
    SEGMENT_WIDTH_PX = 5,
    SEGMENT_HEIGHT_PX = 10,
    SEGMENT_TEXTURE_PATH = "Interface\\AddOns\\XPBarEnhanced\\assets\\xp-bar",
    SEGMENT_TEXTURE_PATH_SOLID = "Interface\\Buttons\\WHITE8X8",
}

local MinimapRingBarStyleTemplate = {}

function MinimapRingBarStyleTemplate:OnLoad()
    self.segments = {}
    self.segmentTypes = {}

    if XPBarMixinBase and XPBarMixinBase.OnLoad then
        XPBarMixinBase.OnLoad(self)
    end
end

-- MinimapCluster (LOW, toplevel) intercepts mouse events before they reach the ring
-- bar (BACKGROUND). Override GetBestAnchor so tooltip follows the cursor rather than
-- trying to anchor to the occluded BACKGROUND frame.
function MinimapRingBarStyleTemplate:GetBestAnchor()
    return "ANCHOR_CURSOR"
end

-- Create thin MEDIUM-strata frames at the four cardinal positions of the ring
-- circumference. These capture OnEnter/OnLeave events that MinimapCluster blocks
-- on the BACKGROUND ring frame, and forward them to the ring bar's tooltip system.
-- IsMouseOver() returns true during these calls because the cursor is still within
-- the ring bar's 256x256 hit rect.
function MinimapRingBarStyleTemplate:_SetupRingTooltipHitFrames()
    if self._ringHitFrames then
        return
    end

    local ringBar = self

    local function MakeHitFrame(width, height, anchorPoint)
        local f = CreateFrame("Frame", nil, UIParent)
        f:SetFrameStrata("MEDIUM")
        f:SetSize(width, height)
        f:SetPoint(anchorPoint, ringBar, anchorPoint)
        f:EnableMouse(true)
        f:EnableMouseWheel(true)
        f:SetScript("OnEnter", function() ringBar:OnEnter() end)
        f:SetScript("OnLeave", function() ringBar:OnLeave() end)
        f:SetScript("OnMouseWheel", function(_, delta)
            if delta > 0 then
                Minimap_ZoomIn()
            else
                Minimap_ZoomOut()
            end
        end)
        return f
    end

    -- 4 thin strips at cardinal edges of the 256x256 ring frame
    self._ringHitFrames = {
        MakeHitFrame(120, 30, "TOP"),
        MakeHitFrame(120, 30, "BOTTOM"),
        MakeHitFrame(30, 120, "LEFT"),
        MakeHitFrame(30, 120, "RIGHT"),
    }
end

function MinimapRingBarStyleTemplate:OnShow()
    if XPBarMixinBase and XPBarMixinBase.OnShow then
        XPBarMixinBase.OnShow(self)
    end

    self:QueueReposition()
    self:UpdateButtonCollection(true)
    self:StartButtonScanTimer()
    self:_SetupRingTooltipHitFrames()
    if self._ringHitFrames then
        for _, f in ipairs(self._ringHitFrames) do
            f:Show()
        end
    end
end

function MinimapRingBarStyleTemplate:OnHide()
    self:StopButtonScanTimer()

    if Addon.MinimapRingButtonCollection and Addon.MinimapRingButtonCollection.owner == self then
        Addon.MinimapRingButtonCollection:Disable()
        Addon.MinimapRingButtonCollection.owner = nil
    end

    if XPBarMixinBase and XPBarMixinBase.OnHide then
        XPBarMixinBase.OnHide(self)
    end

    if self._ringHitFrames then
        for _, f in ipairs(self._ringHitFrames) do
            f:Hide()
        end
    end
end

-- Periodic re-scan: mirrors MBB's OnUpdate approach so addons that register
-- their minimap button after our OnShow (delayed load, late ADDON_LOADED) are
-- still picked up without requiring a manual /reload.
function MinimapRingBarStyleTemplate:StartButtonScanTimer()
    self:StopButtonScanTimer()
    self._buttonScanTicker = C_Timer.NewTicker(3, function()
        if not self or not self:IsShown() then
            self:StopButtonScanTimer()
            return
        end
        if Addon.db and Addon.db.minimapRingCollectButtons then
            self:UpdateButtonCollection(true)
        end
    end)
end

function MinimapRingBarStyleTemplate:StopButtonScanTimer()
    if self._buttonScanTicker then
        self._buttonScanTicker:Cancel()
        self._buttonScanTicker = nil
    end
end

function MinimapRingBarStyleTemplate:RegisterCommonEvents()
    XPBarMixinBase.RegisterCommonEvents(self)
    self:RegisterEvent("DISPLAY_SIZE_CHANGED")
    self:RegisterEvent("UI_SCALE_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function MinimapRingBarStyleTemplate:UnsubscribeFromEvents()
    XPBarMixinBase.UnsubscribeFromEvents(self)
    self:UnregisterEvent("DISPLAY_SIZE_CHANGED")
    self:UnregisterEvent("UI_SCALE_CHANGED")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function MinimapRingBarStyleTemplate:OnEvent(event, ...)
    if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        self:QueueReposition()
        return
    end

    XPBarMixinBase.OnEvent(self, event, ...)
end

function MinimapRingBarStyleTemplate:BuildVisuals()
    if #self.segments == 0 then
        self:CreateRingSegments()
    end
    if not self.segmentGlow then
        self:CreateSegmentGlow()
    end
end

function MinimapRingBarStyleTemplate:CreateSegmentGlow()
    local glow = self:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 1, 1, 0)
    glow:Hide()
    self.segmentGlow = glow
end

function MinimapRingBarStyleTemplate:ApplyStaticPosition()
    self:ClearAllPoints()
    if Minimap then
        self:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    else
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function MinimapRingBarStyleTemplate:GetDisplaySegmentCount()
    local count = DEFAULT_SEGMENTS
    if Addon and Addon.db and type(Addon.db.minimapRingSegments) == "number" then
        count = Addon.db.minimapRingSegments
    end

    count = math.floor(tonumber(count) or DEFAULT_SEGMENTS)
    return math.max(25, math.min(100, count))
end

function MinimapRingBarStyleTemplate:GetSegmentWidth(displayCount)
    local base = 5
    if Addon and Addon.db and type(Addon.db.minimapRingSegmentWidth) == "number" then
        base = math.max(2, math.min(10, Addon.db.minimapRingSegmentWidth))
    end
    return base * (REFERENCE_SEGMENT_COUNT / displayCount)
end

function MinimapRingBarStyleTemplate:GetSegmentHeight()
    if Addon and Addon.db and type(Addon.db.minimapRingSegmentHeight) == "number" then
        return math.max(4, math.min(24, Addon.db.minimapRingSegmentHeight))
    end
    return MINIMAP_RING_STYLE.SEGMENT_HEIGHT_PX
end

function MinimapRingBarStyleTemplate:GetSegmentTexturePath()
    if Addon and Addon.db and Addon.db.circularUseTexture == false then
        return MINIMAP_RING_STYLE.SEGMENT_TEXTURE_PATH_SOLID
    end

    return MINIMAP_RING_STYLE.SEGMENT_TEXTURE_PATH
end

function MinimapRingBarStyleTemplate:CreateRingSegments()
    local texturePath = self:GetSegmentTexturePath()
    for index = 1, MAX_SEGMENTS do
        local segment = self:CreateTexture(nil, "ARTWORK")
        segment:SetTexture(texturePath)
        segment:SetSize(MINIMAP_RING_STYLE.SEGMENT_WIDTH_PX, MINIMAP_RING_STYLE.SEGMENT_HEIGHT_PX)
        segment:SetVertexColor(EMPTY_SEGMENT_COLOR.r, EMPTY_SEGMENT_COLOR.g, EMPTY_SEGMENT_COLOR.b, EMPTY_SEGMENT_COLOR.a)
        segment:Hide()
        self.segments[index] = segment
        self.segmentTypes[index] = SEGMENT_TYPE.HIDDEN
    end
end

function MinimapRingBarStyleTemplate:GetRingPadding()
    local padding = Addon and Addon.db and Addon.db.minimapRingPadding or 14
    padding = math.floor(tonumber(padding) or 14)
    return math.max(4, math.min(32, padding))
end

function MinimapRingBarStyleTemplate:ComputeRingRadius()
    if not Minimap then
        return 112
    end

    local minimapEffScale = Minimap:GetEffectiveScale() or 1
    local ringEffScale = self:GetEffectiveScale() or 1
    local minimapRadius = (Minimap:GetWidth() / 2) * (minimapEffScale / ringEffScale)

    return minimapRadius + self:GetRingPadding()
end

function MinimapRingBarStyleTemplate:GetBagAnchorOffset()
    local angleDegrees = Addon and Addon.db and Addon.db.minimapRingBagAngle or 315
    local angleRadians = math.rad(angleDegrees)
    local distance = self:ComputeRingRadius() + 18
    return math.cos(angleRadians) * distance, math.sin(angleRadians) * distance
end

function MinimapRingBarStyleTemplate:QueueReposition()
    if self._repositionQueued then
        return
    end

    self._repositionQueued = true
    C_Timer.After(0, function()
        self._repositionQueued = nil
        if self and self:IsShown() then
            self:ApplyStaticPosition()
            self:RepositionSegments()
            self:UpdateButtonCollection(true)
        end
    end)
end

function MinimapRingBarStyleTemplate:RepositionSegments()
    local displayCount = self:GetDisplaySegmentCount()
    local clockwise = -1
    local ringRadius = self:ComputeRingRadius()
    local segmentWidth = self:GetSegmentWidth(displayCount)
    local segmentHeight = self:GetSegmentHeight()
    local texturePath = self:GetSegmentTexturePath()
    local frameDiameter = 2 * (ringRadius + (segmentHeight / 2) + 2)
    local startAngle = math.pi / 2
    local fullCircle = 2 * math.pi

    self:SetSize(frameDiameter, frameDiameter)

    self._segmentPositions = self._segmentPositions or {}

    for index = 1, MAX_SEGMENTS do
        if self.segments[index] then
            self.segments[index]:SetTexture(texturePath)
        end
    end

    for index = 1, displayCount do
        local angle = startAngle + ((index - 1) / displayCount) * fullCircle
        local xOffset = math.cos(angle) * ringRadius
        local yOffset = math.sin(angle) * ringRadius * clockwise
        local rotation = (clockwise * angle) + startAngle
        local segment = self.segments[index]

        segment:SetSize(segmentWidth, segmentHeight)
        segment:ClearAllPoints()
        segment:SetPoint("CENTER", self, "CENTER", xOffset, yOffset)
        if segment.SetRotation then
            segment:SetRotation(rotation)
        end
        segment:Show()
        if self.segmentTypes[index] == SEGMENT_TYPE.HIDDEN then
            self.segmentTypes[index] = SEGMENT_TYPE.EMPTY
        end

        self._segmentPositions[index] = {x = xOffset, y = yOffset, rotation = rotation, w = segmentWidth, h = segmentHeight}
    end

    for index = displayCount + 1, MAX_SEGMENTS do
        if self.segments[index] then
            self.segments[index]:Hide()
            self.segmentTypes[index] = SEGMENT_TYPE.HIDDEN
        end
    end

    if Addon.MinimapRingButtonCollection and Addon.MinimapRingButtonCollection.owner == self then
        Addon.MinimapRingButtonCollection:UpdateAnchor()
        Addon.MinimapRingButtonCollection:UpdateLayout()
    end

    if self.Refresh then
        self:Refresh()
    end
end

function MinimapRingBarStyleTemplate:CountSegmentsToDisplay(progress, totalSegments)
    local segments = math.floor(progress * totalSegments)
    return math.max(0, math.min(segments, totalSegments))
end

function MinimapRingBarStyleTemplate:ComputeOverlaySegments(progress, context, totalSegments)
    totalSegments = totalSegments or self:GetDisplaySegmentCount()

    local currentProgress = math.max(0, math.min(progress or 0, 1))
    local currentXPSegments = self:CountSegmentsToDisplay(currentProgress, totalSegments)
    local result = {
        currentXPSegments = currentXPSegments,
        completeCount = 0,
        completeStart = currentXPSegments + 1,
        incompleteCount = 0,
        incompleteStart = currentXPSegments + 1,
        restedCount = 0,
        restedStart = currentXPSegments + 1,
    }

    if not context then
        return result
    end

    local xpMax = context.xpMax or 0
    if xpMax <= 0 then
        return result
    end

    local currentXP = context.currentXP or 0
    local remainingXP = math.max(0, xpMax - currentXP)
    local completeXPUsed = 0
    local incompleteXPUsed = 0
    local restedXPUsed = 0

    if context.showQuestXP and context.showCompleteQuestOverlay and (context.completeQuestXP or 0) > 0 and remainingXP > 0 then
        completeXPUsed = math.min(context.completeQuestXP, remainingXP)
        remainingXP = remainingXP - completeXPUsed
    end

    if context.showQuestXP and context.showIncompleteQuestOverlay and (context.incompleteQuestXP or 0) > 0 and remainingXP > 0 then
        incompleteXPUsed = math.min(context.incompleteQuestXP, remainingXP)
        remainingXP = remainingXP - incompleteXPUsed
    end

    if context.showRestedOverlay and (context.restedXP or 0) > 0 and remainingXP > 0 then
        restedXPUsed = math.min(context.restedXP, remainingXP)
    end

    local combinedXP = currentXP + completeXPUsed + incompleteXPUsed + restedXPUsed
    local totalFillSegments = self:CountSegmentsToDisplay(combinedXP / xpMax, totalSegments)
    local slotsRemaining = totalSegments - currentXPSegments
    local completeCount = 0
    local incompleteCount = 0
    local restedCount = 0

    if completeXPUsed > 0 and slotsRemaining > 0 then
        completeCount = math.min(self:CountSegmentsToDisplay(completeXPUsed / xpMax, totalSegments), slotsRemaining)
        slotsRemaining = slotsRemaining - completeCount
    end

    if incompleteXPUsed > 0 and slotsRemaining > 0 then
        incompleteCount = math.min(self:CountSegmentsToDisplay(incompleteXPUsed / xpMax, totalSegments), slotsRemaining)
        slotsRemaining = slotsRemaining - incompleteCount
    end

    if restedXPUsed > 0 and slotsRemaining > 0 then
        restedCount = math.min(self:CountSegmentsToDisplay(restedXPUsed / xpMax, totalSegments), slotsRemaining)
    end

    local filled = currentXPSegments + completeCount + incompleteCount + restedCount
    local deficit = totalFillSegments - filled
    while deficit > 0 and (currentXPSegments + completeCount + incompleteCount + restedCount) < totalSegments do
        if completeXPUsed > 0 then
            completeCount = completeCount + 1
        elseif incompleteXPUsed > 0 then
            incompleteCount = incompleteCount + 1
        elseif restedXPUsed > 0 then
            restedCount = restedCount + 1
        else
            break
        end
        deficit = deficit - 1
    end

    result.completeCount = completeCount
    result.completeStart = currentXPSegments + 1
    result.incompleteCount = incompleteCount
    result.incompleteStart = currentXPSegments + 1 + completeCount
    result.restedCount = restedCount
    result.restedStart = currentXPSegments + 1 + completeCount + incompleteCount

    return result
end

function MinimapRingBarStyleTemplate:UpdateSegmentColors(hasRestedXP)
    local Colors = Addon.Colors
    local colorNormal = Colors:Get(Colors.Key.XpBar)
    local colorRested = Colors:Get(Colors.Key.Rested)
    local colorXpBarRested = Colors:Get(Colors.Key.XpBarRested)
    local colorQuestComplete = Colors:Get(Colors.Key.QuestComplete)
    local colorQuestIncomplete = Colors:Get(Colors.Key.QuestIncomplete)
    local currentXPColor = hasRestedXP and colorXpBarRested or colorNormal
    local displayCount = self:GetDisplaySegmentCount()

    for index = 1, displayCount do
        local segment = self.segments[index]
        local segmentType = self.segmentTypes[index]

        if segmentType == SEGMENT_TYPE.CURRENT_XP then
            segment:SetVertexColor(currentXPColor.r, currentXPColor.g, currentXPColor.b, currentXPColor.a or 1)
        elseif segmentType == SEGMENT_TYPE.QUEST_COMPLETE then
            segment:SetVertexColor(colorQuestComplete.r, colorQuestComplete.g, colorQuestComplete.b, colorQuestComplete.a or 1)
        elseif segmentType == SEGMENT_TYPE.QUEST_INCOMPLETE then
            segment:SetVertexColor(colorQuestIncomplete.r, colorQuestIncomplete.g, colorQuestIncomplete.b, colorQuestIncomplete.a or 1)
        elseif segmentType == SEGMENT_TYPE.RESTED then
            segment:SetVertexColor(colorRested.r, colorRested.g, colorRested.b, colorRested.a or 1)
        else
            segment:SetVertexColor(EMPTY_SEGMENT_COLOR.r, EMPTY_SEGMENT_COLOR.g, EMPTY_SEGMENT_COLOR.b, EMPTY_SEGMENT_COLOR.a)
        end
    end
end

function MinimapRingBarStyleTemplate:SetArcProgress(progress, context)
    if not context then
        return
    end

    local totalSegments = self:GetDisplaySegmentCount()
    local overlaySegments = self:ComputeOverlaySegments(progress, context, totalSegments)

    for index = 1, totalSegments do
        self.segmentTypes[index] = SEGMENT_TYPE.EMPTY
    end

    for index = 1, overlaySegments.currentXPSegments do
        self.segmentTypes[index] = SEGMENT_TYPE.CURRENT_XP
    end

    self._lastXPSegmentIndex = overlaySegments.currentXPSegments

    for index = overlaySegments.completeStart, math.min(overlaySegments.completeStart + overlaySegments.completeCount - 1, totalSegments) do
        if index >= 1 then
            self.segmentTypes[index] = SEGMENT_TYPE.QUEST_COMPLETE
        end
    end

    for index = overlaySegments.incompleteStart, math.min(overlaySegments.incompleteStart + overlaySegments.incompleteCount - 1, totalSegments) do
        if index >= 1 then
            self.segmentTypes[index] = SEGMENT_TYPE.QUEST_INCOMPLETE
        end
    end

    for index = overlaySegments.restedStart, math.min(overlaySegments.restedStart + overlaySegments.restedCount - 1, totalSegments) do
        if index >= 1 and self.segmentTypes[index] == SEGMENT_TYPE.EMPTY then
            self.segmentTypes[index] = SEGMENT_TYPE.RESTED
        end
    end

    self:UpdateSegmentColors(context.hasRestedXP == true)
end

function MinimapRingBarStyleTemplate:RenderBar(context)
    if not context then
        error("RenderBar requires an explicit immutable context")
    end

    local targetRatio = self:CalculateTargetRatio(context)
    self:UpdateGainedBar(targetRatio, context)
    self:UpdateButtonCollection(false)
end

function MinimapRingBarStyleTemplate:UpdateGainedBar(currentRatio, context)
    self:SetArcProgress(currentRatio, context)
    if self.SetCurrentRatio then
        self:SetCurrentRatio(currentRatio)
    end
end

function MinimapRingBarStyleTemplate:UpdateRestedBar() end
function MinimapRingBarStyleTemplate:UpdateQuestCompleteBar() end
function MinimapRingBarStyleTemplate:UpdateQuestIncompleteBar() end

function MinimapRingBarStyleTemplate:UpdateButtonCollection(forceRefresh)
    local collector = Addon.MinimapRingButtonCollection
    if not collector then
        return
    end

    if Addon.db and Addon.db.minimapRingCollectButtons then
        local needsRefresh = forceRefresh or collector.owner ~= self
        collector:SetOwner(self)
        if needsRefresh then
            collector:Refresh()
        end
    elseif collector.owner == self then
        collector:Disable()
        collector.owner = nil
    end
end

function MinimapRingBarStyleTemplate:AnimateBarEffect(iterationData, eventContext)
    local flashData = iterationData and iterationData.flashData
    local flashActive = flashData and flashData.active and flashData.currentAlpha and flashData.currentAlpha > 0

    if not self.segmentGlow then
        return
    end

    local lastIdx = self._lastXPSegmentIndex
    if flashActive and lastIdx and lastIdx > 0 and self._segmentPositions and self._segmentPositions[lastIdx] then
        local Colors = Addon.Colors
        local colorKey = eventContext and eventContext.hasRestedXP and Colors.Key.XpBarRested or Colors.Key.XpBar
        local color = Colors:Get(colorKey)
        local pos = self._segmentPositions[lastIdx]

        self.segmentGlow:ClearAllPoints()
        self.segmentGlow:SetPoint("CENTER", self, "CENTER", pos.x, pos.y)
        self.segmentGlow:SetSize(pos.w, pos.h)
        if self.segmentGlow.SetRotation then
            self.segmentGlow:SetRotation(pos.rotation)
        end
        self.segmentGlow:SetVertexColor(color.r, color.g, color.b, flashData.currentAlpha * 0.9)
        self.segmentGlow:Show()
    else
        self.segmentGlow:Hide()
    end
end

local DefaultConfig = {
    interaction = {enabled = true},
    tooltip = {enabled = true},
    animation = {
        enableAnimations = true,
        flashOnGain = true,
    },
    position = {mode = "STATIC", positionKey = "MinimapRing"},
    style = {},
    capabilities = {
        statusBar = false,
        overlays = false,
        exhaustionTick = false,
        textOnBar = false,
        textBelowBar = false,
    },
}

MinimapRingBarXPBarMixin = XPBarStyleBuilder:Create(XPBarMixinBase, MinimapRingBarStyleTemplate, DefaultConfig)
XPBarStyleBuilder:RegisterStyle("minimap_ring", MinimapRingBarXPBarMixin)
