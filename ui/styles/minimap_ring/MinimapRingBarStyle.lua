if not XPBarStyleBuilder or not XPBarMixinBase then
    error("MinimapRingBarStyle: core (StyleBuilder/BaseMixin) not loaded.")
end

local Addon = XPBarEnhanced
local Config = Addon.Config
local StyleHelpers = Addon.UI.StyleHelpers

local function GetSharedStyleHelpers()
    return Addon and Addon.UI and Addon.UI.SharedStyleHelpers
end

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
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

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
        f:SetScript("OnMouseDown", function(_, button) ringBar:OnMouseDown(button) end)
        f:SetScript("OnMouseUp", function(_, button) ringBar:OnMouseUp(button) end)
        f:SetScript("OnMouseWheel", function(_, delta)
            if not (Minimap and Minimap.SetZoom and Minimap.GetZoom and Minimap.GetZoomLevels) then
                return
            end
            if delta > 0 then
                Minimap:SetZoom(math.min(Minimap:GetZoom() + 1, Minimap:GetZoomLevels() - 1))
            else
                Minimap:SetZoom(math.max(Minimap:GetZoom() - 1, 0))
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
        Addon.MinimapRingButtonCollection:ReleaseOwner(self)
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
    local collector = Addon.MinimapRingButtonCollection
    if not collector then
        return
    end

    collector:StartOwnerScanTimer(self, function()
        return Config and Config.GetOptionValue and Config:GetOptionValue("minimapRingCollectButtons")
    end)
end

function MinimapRingBarStyleTemplate:StopButtonScanTimer()
    local collector = Addon.MinimapRingButtonCollection
    if collector then
        collector:StopOwnerScanTimer(self)
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
    local saved = Config and Config.GetOptionValue and Config:GetOptionValue("minimapRingSegments")
    if type(saved) == "number" then
        count = saved
    end

    count = math.floor(tonumber(count) or DEFAULT_SEGMENTS)
    return math.max(25, math.min(100, count))
end

function MinimapRingBarStyleTemplate:GetSegmentWidth(displayCount)
    local base = 5
    local saved = Config and Config.GetOptionValue and Config:GetOptionValue("minimapRingSegmentWidth")
    if type(saved) == "number" then
        base = math.max(2, math.min(10, saved))
    end
    return base * (REFERENCE_SEGMENT_COUNT / displayCount)
end

function MinimapRingBarStyleTemplate:GetSegmentHeight()
    local saved = Config and Config.GetOptionValue and Config:GetOptionValue("minimapRingSegmentHeight")
    if type(saved) == "number" then
        return math.max(5, math.min(25, saved))
    end
    return MINIMAP_RING_STYLE.SEGMENT_HEIGHT_PX
end

function MinimapRingBarStyleTemplate:GetSegmentTexturePath()
    if Config and Config.GetOptionValue and Config:GetOptionValue("circularUseTexture") == false then
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
    local padding = Config and Config.GetOptionValue and Config:GetOptionValue("minimapRingPadding") or 14
    padding = math.floor(tonumber(padding) or 14)
    return math.max(0, math.min(32, padding))
end

function MinimapRingBarStyleTemplate:ComputeRingRadius()
    return StyleHelpers.GetMinimapRingRadius(self)
end

function MinimapRingBarStyleTemplate:GetBagAnchorOffset()
    local angleDegrees = Config and Config.GetOptionValue and Config:GetOptionValue("minimapRingBagAngle") or 315
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
        end
        -- Always sync collection state even when hidden (handles disable while bar is gone).
        self:UpdateButtonCollection(true)
    end)
end

function MinimapRingBarStyleTemplate:RepositionSegments()
    local displayCount = self:GetDisplaySegmentCount()
    local clockwise = -1
    local segmentWidth = self:GetSegmentWidth(displayCount)
    local segmentHeight = self:GetSegmentHeight()
    local ringRadius = self:ComputeRingRadius() + (segmentHeight / 2)
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
    local shared = GetSharedStyleHelpers()
    local currentXPColor = nil
    if shared and shared.GetXPBarColor then
        currentXPColor = shared.GetXPBarColor({hasRestedXP = hasRestedXP})
    end
    if not currentXPColor or not currentXPColor.r then
        local key = hasRestedXP and Colors.Key.XpBarRested or Colors.Key.XpBar
        currentXPColor = Colors:Get(key)
    end
    local colors = {
        currentXP = currentXPColor,
        rested = Colors:Get(Colors.Key.Rested),
        questComplete = Colors:Get(Colors.Key.QuestComplete),
        questIncomplete = Colors:Get(Colors.Key.QuestIncomplete),
    }

    local displayCount = self:GetDisplaySegmentCount()
    for index = 1, displayCount do
        local segment = self.segments[index]
        if shared and shared.ApplySegmentTypeColor then
            shared.ApplySegmentTypeColor(segment, self.segmentTypes[index], colors, EMPTY_SEGMENT_COLOR, 1.0)
        elseif segment then
            local fallback = colors.currentXP or EMPTY_SEGMENT_COLOR
            segment:SetVertexColor(fallback.r, fallback.g, fallback.b, fallback.a or 1)
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

    if Config and Config.GetOptionValue and Config:GetOptionValue("minimapRingCollectButtons") then
        -- Only claim the collection while visible; a hidden bar must never
        -- re-take ownership after OnHide released it (release stays unconditional).
        if not self:IsShown() then
            return
        end
        local needsRefresh = forceRefresh or collector.owner ~= self
        collector:SetOwner(self)
        if needsRefresh then
            collector:Refresh()
        end
    elseif collector.owner == self then
        collector:ReleaseOwner(self)
    end
end

--- Clip runtime-created effect textures (celebration glow) to the ring circle.
--- This style has no StatusBar, so the glow anchors to the bar frame and would
--- otherwise pulse as a square behind the round minimap.
function MinimapRingBarStyleTemplate:GetCelebrationMask()
    if not self._celebrationMask then
        local mask = self:CreateMaskTexture()
        mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(self)
        self._celebrationMask = mask
    end
    return self._celebrationMask
end

function MinimapRingBarStyleTemplate:AnimateBarEffect(iterationData, eventContext)
    local flashData = iterationData and iterationData.flashData
    local flashActive = flashData and flashData.active and flashData.currentAlpha and flashData.currentAlpha > 0

    if not self.segmentGlow then
        return
    end

    local lastIdx = self._lastXPSegmentIndex
    if flashActive and lastIdx and lastIdx > 0 and self._segmentPositions and self._segmentPositions[lastIdx] then
        local shared = GetSharedStyleHelpers()
        local color = shared and shared.GetXPBarColor and shared.GetXPBarColor(eventContext)
        if not color or not color.r then
            color = Addon.Colors:Get(Addon.Colors.Key.XpBar)
        end
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
