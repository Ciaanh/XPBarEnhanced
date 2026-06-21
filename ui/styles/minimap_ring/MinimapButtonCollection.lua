local Addon = XPBarEnhanced

Addon.MinimapRingButtonCollection = Addon.MinimapRingButtonCollection or {}

local Collection = Addon.MinimapRingButtonCollection

local IGNORE_PATTERNS = {
    "^MiniMap.*$",
    "^Minimap.*$",
    "^MiniMapTrackingFrame$",
    "^MiniMapMailFrame$",
    "^MiniMapBattlefieldFrame$",
    "^MiniMapWorldMapButton$",
    "^MinimapBackdrop$",
    "^MinimapZoomIn$",
    "^MinimapZoomOut$",
    "^MiniMapTracking$",
    "^TimeManagerClockButton$",
    "^GameTimeFrame$",
    "^MiniMapInstanceDifficulty$",
    "^MiniMapVoiceChatFrame$",
    "^MiniMapRecordingButton$",
    "^QueueStatusMinimapButton$",
    "^QueueStatusButton$",
    "^GarrisonMinimapButton$",
    "^MinimapZoneTextButton$",
    "^GuildInstanceDifficulty$",
    "^MiniMapLFGFrame$",
    "^XPBEMinimapButtonBag$",
    "^XPBEMinimapButtonBagPanel$",
    "^MBB_MinimapButtonFrame$",
    "^LibDBIcon10_XPBarEnhanced$",
    "^HandyNotes_.*Pin$",
    "^GatherMate.*$",
    "^GatherNote$",
    "^GatherArchNote$",
    "^RecipeRadarMinimapIcon$",
    "^QuestPointerPOI$",
    "^poiMinimap$",
    "^GPSArrow$",
    "^DugisArrowMinimapPoint[0-9]+$",
    "^TTMinimapButton$",
    "^FWGMinimapPOI$",
    "^CartographerNotesPOI$",
    "^MiniNotePOI$",
    "^AddonCompartmentFrame$",
}

local BUTTON_SIZE   = 31    -- displayed size of each collected button
local MIN_BUTTON_SIZE = 20  -- ignore tiny minimap icon widgets (nodes/POIs)
local DEFAULT_BUTTON_SIZE = 31
local BAG_SIZE      = 31    -- bag toggle button (matches standard minimap button size)
local PANEL_PAD     = 10    -- padding inside the panel
local PANEL_SPACING = 4     -- gap between icons
local PANEL_COLUMNS = 4     -- icons per row

local function IsIgnoredName(name)
    if type(name) ~= "string" or name == "" then
        return true
    end

    for _, pattern in ipairs(IGNORE_PATTERNS) do
        if string.find(name, pattern) then
            return true
        end
    end

    return false
end

-- Scan only the button's name, ignore-list, managed-state, and click scripts.
-- Ancestor/anchor checks are not needed because we scan Minimap children directly
-- (same approach as MBB).
local function IsCollectableButton(frame)
    if not frame or frame == Minimap or frame == MinimapCluster then
        return false
    end

    if not frame.GetName or not frame.GetObjectType then
        return false
    end

    -- Only collect actual Button objects. Minimap icons (tracking nodes, POI markers,
    -- quest pins, etc.) are plain Frame or Texture objects, not Buttons — filtering by
    -- object type keeps them untouched, matching MBB's implicit assumption.
    if frame:GetObjectType() ~= "Button" then
        return false
    end

    -- Many minimap icon-display widgets are tiny Buttons. Keep collection focused on
    -- actual addon minimap buttons by ignoring very small controls.
    local width = frame.GetWidth and frame:GetWidth() or 0
    local height = frame.GetHeight and frame:GetHeight() or 0
    if width < MIN_BUTTON_SIZE or height < MIN_BUTTON_SIZE then
        return false
    end

    local name = frame:GetName()
    if IsIgnoredName(name) then
        return false
    end

    -- Skip frames we already manage (oshow is our sentinel, matching MBB's oshow check)
    if frame.oshow then
        return false
    end

    if not frame.HasScript then
        return false
    end

    -- Use HasScript, not GetScript — GetScript returns nil for template-inherited handlers
    -- even when the handler is fully functional (confirmed by MBB source).
    return frame:HasScript("OnClick") or frame:HasScript("OnMouseUp") or frame:HasScript("OnMouseDown")
end

local function EnsureState(self)
    self.states = self.states or {}
    self.order = self.order or {}
end

-- Return (creating if needed) a scissored cell frame for slot `index`.
-- Each cell uses SetClipsChildren so the button's ring overlay textures
-- (e.g. MiniMap-TrackingBorder, ~53x53) cannot bleed over neighbouring slots.
local function GetOrCreateCell(collection, index)
    collection._cells = collection._cells or {}
    local cell = collection._cells[index]
    if not cell then
        cell = CreateFrame("Frame", nil, collection.panel)
        cell:SetClipsChildren(true)
        collection._cells[index] = cell
    end
    return cell
end

--- Compute the angle (degrees, 0-360) from Minimap centre to the cursor,
--- using the same maths as MinimapButton.lua.
local function GetCursorAngle()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    return math.deg(math.atan2(py - my, px - mx)) % 360
end

function Collection:EnsureFrames()
    if self.bagButton and self.panel then
        return
    end

    -- Bag / toggle button
    self.bagButton = self.bagButton or CreateFrame("Button", "XPBEMinimapButtonBag", UIParent)
    self.bagButton:SetSize(BAG_SIZE, BAG_SIZE)
    -- Keep the draggable bag above tooltip hit-capture strips from MinimapRingBarStyle.
    self.bagButton:SetFrameStrata("HIGH")
    self.bagButton:SetFrameLevel(30)
    self.bagButton:EnableMouse(true)

    if not self.bagButton.xpbeBuilt then
        -- Standard WoW minimap button appearance (matches LibDBIcon / MinimapButton style)
        self.bagButton:SetHighlightTexture(136477) -- UI-Minimap-ZoomButton-Highlight

        local overlay = self.bagButton:CreateTexture(nil, "OVERLAY")
        overlay:SetSize(50, 50)
        overlay:SetTexture(136430) -- MiniMap-TrackingBorder
        overlay:SetPoint("TOPLEFT")

        local background = self.bagButton:CreateTexture(nil, "BACKGROUND")
        background:SetSize(24, 24)
        background:SetTexture(136467) -- UI-Minimap-Background
        background:SetPoint("CENTER")

        local icon = self.bagButton:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetTexture(tonumber(C_AddOns.GetAddOnMetadata("XPBarEnhanced", "IconTexture")) or 4675649)
        icon:SetPoint("CENTER")
        self.bagButton.icon = icon

        local label = self.bagButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        label:SetPoint("BOTTOMRIGHT", -2, 2)
        label:SetTextColor(1, 1, 1, 1)
        self.bagButton.label = label
        self.bagButton.xpbeBuilt = true
    end

    -- Collection panel
    self.panel = self.panel or CreateFrame(
        "Frame", "XPBEMinimapButtonBagPanel", UIParent, "BackdropTemplate")
    self.panel:SetFrameStrata("HIGH")
    self.panel:SetFrameLevel(20)
    self.panel:Hide()

    if not self.panel.xpbeBuilt then
        self.panel:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileEdge = true, tileSize = 32, edgeSize = 32,
            insets = {left = 11, right = 12, top = 12, bottom = 11},
        })
        self.panel:SetBackdropColor(0, 0, 0, 0.9)
        self.panel:SetBackdropBorderColor(1, 1, 1, 0.6)
        self.panel.xpbeBuilt = true
    end

    self.bagButton:SetScript("OnClick", function()
        if self.isDragging then return end
        self:SetExpanded(not self.expanded)
    end)
    self.bagButton:RegisterForDrag("LeftButton")
    self.bagButton:SetScript("OnDragStart", function()
        self:OnBagDragStart()
    end)
    self.bagButton:SetScript("OnDragStop", function()
        self:OnBagDragStop()
    end)
    self.bagButton:SetScript("OnEnter", function()
        if self.isDragging then return end
        GameTooltip:SetOwner(self.bagButton, "ANCHOR_LEFT")
        GameTooltip:SetText("Minimap Buttons", 1, 1, 1)
        GameTooltip:AddLine("Click to show / hide", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("|cff00ff00Drag:|r Move button", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    self.bagButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function Collection:SetOwner(owner)
    self.owner = owner
    if not owner then
        self:Disable()
        return
    end

    self:EnsureFrames()
    self:UpdateAnchor()
end

function Collection:ReleaseOwner(owner)
    if self.owner == owner then
        self:Disable()
        self.owner = nil
    end
end

function Collection:StartOwnerScanTimer(owner, shouldCollect)
    self:StopOwnerScanTimer(owner)
    if not owner then
        return
    end

    owner._buttonScanTicker = C_Timer.NewTicker(3, function()
        if not owner or not owner.IsShown or not owner:IsShown() then
            self:StopOwnerScanTimer(owner)
            return
        end

        local collectEnabled = true
        if shouldCollect then
            collectEnabled = shouldCollect() == true
        end

        if collectEnabled and owner.UpdateButtonCollection then
            owner:UpdateButtonCollection(true)
        end
    end)
end

function Collection:StopOwnerScanTimer(owner)
    if owner and owner._buttonScanTicker then
        owner._buttonScanTicker:Cancel()
        owner._buttonScanTicker = nil
    end
end

function Collection:UpdateAnchor()
    if not self.owner or not self.bagButton or not self.panel then
        return
    end

    local xOffset, yOffset = self.owner:GetBagAnchorOffset()
    self.bagButton:ClearAllPoints()
    self.bagButton:SetPoint("CENTER", self.owner, "CENTER", xOffset, yOffset)

    self.panel:ClearAllPoints()
    self.panel:SetPoint("TOPRIGHT", self.bagButton, "BOTTOMLEFT", -4, -4)
end

function Collection:OnBagDragStart()
    self.isDragging = true
    if self.bagButton then
        self.bagButton:LockHighlight()
        self.bagButton:SetScript("OnUpdate", function() self:OnBagDragUpdate() end)
    end
    GameTooltip:Hide()
end

function Collection:OnBagDragUpdate()
    if not self.owner then return end
    local angle = GetCursorAngle()
    if Addon.Config and Addon.Config.SetOptionKey then
        Addon.Config:SetOptionKey("minimapRingBagAngle", angle, true)
    elseif Addon.db then
        Addon.db.minimapRingBagAngle = angle
    end
    self:UpdateAnchor()
end

function Collection:OnBagDragStop()
    if self.bagButton then
        self.bagButton:SetScript("OnUpdate", nil)
        self.bagButton:UnlockHighlight()
    end
    self.isDragging = false

    if Addon.Config and Addon.Config.ApplyPendingOptionChanges then
        Addon.Config:ApplyPendingOptionChanges()
    end
end

function Collection:PrepareButton(button, state)
    if state.prepared then
        return
    end

    state.originalParent = button:GetParent()
    state.originalShow = button.Show
    state.originalHide = button.Hide
    state.originalClearAllPoints = button.ClearAllPoints
    state.originalSetPoint = button.SetPoint
    state.originalSetAlpha = button.SetAlpha
    state.originalWidth = button:GetWidth() or DEFAULT_BUTTON_SIZE
    state.originalHeight = button:GetHeight() or DEFAULT_BUTTON_SIZE
    state.originalAlpha = button:GetAlpha() or 1
    state.wasVisible = button:IsVisible()

    button.oshow = state.originalShow
    button.ohide = state.originalHide
    button.oclearallpoints = state.originalClearAllPoints
    button.osetpoint = state.originalSetPoint

    button.Show = function(frame, ...)
        state.wasVisible = true
        if not state.managed or self.expanded then
            return state.originalShow(frame, ...)
        end
    end

    button.Hide = function(frame, ...)
        state.wasVisible = false
        return state.originalHide(frame, ...)
    end

    button.ClearAllPoints = function(frame)
        if not state.managed then
            return state.originalClearAllPoints(frame)
        end
    end

    button.SetPoint = function(frame, ...)
        if not state.managed then
            return state.originalSetPoint(frame, ...)
        end
    end

    -- While managed, suppress external alpha changes so addon OnUpdate handlers
    -- cannot dim the button inside the collection panel.
    button.SetAlpha = function(frame, value)
        if not state.managed then
            state.originalAlpha = value or 1
            return state.originalSetAlpha(frame, value)
        end
        -- Track the intended alpha so we can restore it on release.
        state.originalAlpha = value or 1
    end

    state.prepared = true
end

function Collection:AddButton(button)
    EnsureState(self)

    if self.states[button] then
        return
    end

    local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
    local state = {
        button = button,
        point = {
            point or "CENTER",
            relativeTo,
            relativePoint or "CENTER",
            x or 0,
            y or 0,
        },
    }

    self:PrepareButton(button, state)

    state.managed = true
    self.states[button] = state
    table.insert(self.order, button)

    if not self.expanded then
        state.originalHide(button)
    end
end

function Collection:RestoreButton(button)
    EnsureState(self)

    local state = self.states[button]
    if not state then
        return
    end

    state.managed = false

    button.Show = state.originalShow
    button.Hide = state.originalHide
    button.ClearAllPoints = state.originalClearAllPoints
    button.SetPoint = state.originalSetPoint
    button.SetAlpha = state.originalSetAlpha
    button.oshow = nil
    button.ohide = nil
    button.oclearallpoints = nil
    button.osetpoint = nil

    -- Reparent back to the original parent before restoring position so the
    -- anchor is resolved in the correct parent coordinate space.
    if state.originalParent then
        button:SetParent(state.originalParent)
    end

    button:ClearAllPoints()
    button:SetPoint(state.point[1], state.point[2], state.point[3], state.point[4], state.point[5])
    button:SetSize(state.originalWidth, state.originalHeight)
    button:SetAlpha(state.originalAlpha or 1)

    if state.wasVisible ~= false then
        button:Show()
    else
        button:Hide()
    end

    self.states[button] = nil
    for index, managedButton in ipairs(self.order) do
        if managedButton == button then
            table.remove(self.order, index)
            break
        end
    end
end

function Collection:RestoreAllButtons()
    EnsureState(self)

    for index = #self.order, 1, -1 do
        self:RestoreButton(self.order[index])
    end

    self:SetExpanded(false)
    if self.bagButton then
        self.bagButton:Hide()
    end
end

function Collection:SetExpanded(expanded)
    self.expanded = expanded == true

    if not self.panel then
        return
    end

    if self.expanded then
        self.panel:Show()
        self:UpdateLayout()
    else
        self.panel:Hide()
        EnsureState(self)
        for _, button in ipairs(self.order) do
            local state = self.states[button]
            if state and state.originalHide then
                state.originalHide(button)
            end
        end
        -- Hide any lingering cell frames (panel hide makes them invisible
        -- but explicit hide keeps state consistent for next expand).
        if self._cells then
            for _, cell in ipairs(self._cells) do
                cell:Hide()
            end
        end
    end
end

function Collection:UpdateLayout()
    EnsureState(self)

    local visibleButtons = {}
    for _, button in ipairs(self.order) do
        local state = self.states[button]
        if state and state.wasVisible ~= false then
            table.insert(visibleButtons, button)
        end
    end

    local buttonCount = #visibleButtons
    if buttonCount == 0 then
        self.panel:Hide()
        self.bagButton:Hide()
        return
    end

    -- Bag button: show count
    self.bagButton:Show()
    self.bagButton.label:SetText(tostring(buttonCount))

    -- Grid dimensions
    local cols  = math.min(buttonCount, PANEL_COLUMNS)
    local rows  = math.ceil(buttonCount / PANEL_COLUMNS)
    local inner = cols * BUTTON_SIZE + (cols - 1) * PANEL_SPACING
    local panelW = inner + PANEL_PAD * 2
    local panelH = rows * BUTTON_SIZE + (rows - 1) * PANEL_SPACING + PANEL_PAD * 2
    self.panel:SetSize(panelW, panelH)

    if self.expanded then
        for index, button in ipairs(visibleButtons) do
            local state = self.states[button]
            local col = (index - 1) % PANEL_COLUMNS
            local row = math.floor((index - 1) / PANEL_COLUMNS)
            local x = PANEL_PAD + col * (BUTTON_SIZE + PANEL_SPACING)
            local y = -(PANEL_PAD + row * (BUTTON_SIZE + PANEL_SPACING))

            -- Reparent into a scissored cell so the button's ring overlay
            -- texture (MiniMap-TrackingBorder, ~53x53) is clipped to the
            -- slot bounds and cannot bleed over neighbouring icons.
            local cell = GetOrCreateCell(self, index)
            cell:SetSize(BUTTON_SIZE, BUTTON_SIZE)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", self.panel, "TOPLEFT", x, y)
            cell:Show()

            button:SetParent(cell)
            state.originalClearAllPoints(button)
            state.originalSetPoint(button, "CENTER", cell, "CENTER", 0, 0)
            button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
            button:SetAlpha(1)
            state.originalShow(button)
        end

        -- Hide cell frames left over from a previous layout that had more buttons.
        if self._cells then
            for i = buttonCount + 1, #self._cells do
                if self._cells[i] then self._cells[i]:Hide() end
            end
        end
    end
end

function Collection:ScanButtons()
    -- Scan direct children of Minimap and MinimapCluster.
    -- This mirrors the MBB approach: targeted, fast, and catches all library-based
    -- minimap buttons (LibDBIcon, Ace3 minimap module, etc.) which parent
    -- themselves to Minimap. EnumerateFrames() is too broad and slow.
    local seen = {}

    local sources = {}
    if Minimap and Minimap.GetChildren then
        for _, child in ipairs({Minimap:GetChildren()}) do
            sources[#sources + 1] = child
        end
    end
    if MinimapCluster and MinimapCluster.GetChildren then
        for _, child in ipairs({MinimapCluster:GetChildren()}) do
            if not seen[child] then
                seen[child] = true
                sources[#sources + 1] = child
            end
        end
    end

    for _, frame in ipairs(sources) do
        if IsCollectableButton(frame) then
            self:AddButton(frame)
        end
    end
end

function Collection:Refresh()
    if not self.owner then
        return
    end

    EnsureState(self)
    self:EnsureFrames()
    self:UpdateAnchor()
    self:ScanButtons()
    self:UpdateLayout()
end

function Collection:Disable()
    self.enabled = false
    self:RestoreAllButtons()

    if self.panel then
        self.panel:Hide()
    end
    if self.bagButton then
        self.bagButton:Hide()
    end
end