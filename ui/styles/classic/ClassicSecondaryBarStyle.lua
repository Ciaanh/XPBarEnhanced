-- XP Bar Enhanced - Classic Secondary Bar Style
-- Displays the watched faction's reputation as a Blizzard-style bordered bar
-- with standing-color atlas fill.

local Addon = XPBarEnhanced
local SharedStyleHelpers = nil
local StyleHelpers = nil

local function ResolveHelpers()
    local ui = Addon and Addon.UI
    if not ui then
        return
    end

    SharedStyleHelpers = ui.SharedStyleHelpers
    StyleHelpers = ui.StyleHelpers
end

local function GetFactionColor(context)
    ResolveHelpers()
    if StyleHelpers and StyleHelpers.GetFactionColor then
        return StyleHelpers.GetFactionColor(context)
    end

    return {r = 0.7, g = 0.3, b = 0.85, a = 1}
end

---@class XPBarClassicReputationMixin
XPBarClassicReputationMixin = {}
local StyleMixin = {}

-- Standing-color atlases indexed by reaction level (1 = Hated, 8 = Exalted).
-- Matches Blizzard's own barAtlases table in ReputationBarOverrides.lua.
local STANDING_ATLAS = {
    "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Red",    -- 1 Hated
    "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Red",    -- 2 Hostile
    "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Orange", -- 3 Unfriendly
    "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Yellow", -- 4 Neutral
    "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Green",  -- 5 Friendly
    "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Green",  -- 6 Honored
    "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Green",  -- 7 Revered
    "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Green",  -- 8 Exalted
}

local BLUE_ATLAS = "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Blue"

-- Authored dimensions from ClassicSecondaryBarTemplate.xml.
local FRAME_HEIGHT = 12
local BAR_HEIGHT = 10

-- Explicitly enforce draw order so atlas/texture fill is never occluded:
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

-- Returns (atlasName, fallbackColor) for the given context.
-- atlasName is nil when a solid color fill should be used instead.
local function GetBarFill(context)
    if context.isCompanion then
        return nil, GetFactionColor(context)
    end

    if context.factionType == "major" or context.factionType == "paragon" then
        return BLUE_ATLAS, nil
    end

    local level = context.reactionLevel
    if level and STANDING_ATLAS[level] then
        return STANDING_ATLAS[level], nil
    end

    return nil, GetFactionColor(context)
end

-- Apply atlas texture to a StatusBar, falling back to a solid color fill.
local function ApplyBarFill(bar, atlasName, fallbackColor)
    if atlasName and C_Texture and C_Texture.GetAtlasInfo then
        local atlasInfo = C_Texture.GetAtlasInfo(atlasName)
        if atlasInfo then
            local barTex = bar:GetStatusBarTexture()
            if barTex and barTex.SetAtlas then
                barTex:SetAtlas(atlasName)
                bar:SetStatusBarColor(1, 1, 1)
                return
            end
        end
    end

    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    local c = fallbackColor or GetFactionColor(nil)
    bar:SetStatusBarColor(c.r, c.g, c.b)
end


function StyleMixin:GetPositionConfigKey()
    ResolveHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.GetSecondaryPositionConfigKey then
        return SharedStyleHelpers.GetSecondaryPositionConfigKey()
    end
    return "secondaryBarPositions"
end

function StyleMixin:GetFallbackPosition()
    ResolveHelpers()
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
    ResolveHelpers()
    if context and self.LabelContainer then
        if SharedStyleHelpers and SharedStyleHelpers.BuildSecondaryLabel then
            self.LabelContainer.Label:SetText(SharedStyleHelpers.BuildSecondaryLabel(context))
        else
            self.LabelContainer.Label:SetText(context.name or "")
        end
    end
end

function StyleMixin:GetBroadcastEventName()
    ResolveHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.GetSecondaryBroadcastEventName then
        return SharedStyleHelpers.GetSecondaryBroadcastEventName()
    end
    return (Addon.EventNames and Addon.EventNames.REPUTATION_BROADCAST_UPDATE) or "REPUTATION:BROADCAST_UPDATE"
end

function StyleMixin:GetInitialContext()
    ResolveHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.GetSecondaryInitialContext then
        return SharedStyleHelpers.GetSecondaryInitialContext()
    end
    if Addon:IsFeatureEnabled("reputation", "GetCurrentContext") then
        return Addon.ReputationSession:GetCurrentContext()
    end
    return nil
end


function StyleMixin:Render(context)
    ResolveHelpers()
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

    local atlas, color = GetBarFill(context)
    if SharedStyleHelpers and SharedStyleHelpers.ApplyStatusBarProgress then
        SharedStyleHelpers.ApplyStatusBarProgress(self.Bar, context, nil)
    else
        self.Bar:SetMinMaxValues(context.min or 0, context.max or 1)
        self.Bar:SetValue(context.current or 0)
    end
    ApplyBarFill(self.Bar, atlas, color)
    if self.LabelContainer then
        if SharedStyleHelpers and SharedStyleHelpers.BuildSecondaryLabel then
            self.LabelContainer.Label:SetText(SharedStyleHelpers.BuildSecondaryLabel(context))
        else
            self.LabelContainer.Label:SetText(context.name or "")
        end
    end
end

function StyleMixin:OnEnter()
    ResolveHelpers()
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
    ResolveHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.HideTooltip then
        SharedStyleHelpers.HideTooltip()
    elseif GameTooltip then
        GameTooltip:Hide()
    end
end

function StyleMixin:OnMouseUp(button)
    ResolveHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.HandleStandardSecondaryMouseUp then
        SharedStyleHelpers.HandleStandardSecondaryMouseUp(self, button, self.OnRightClick)
        return
    end
    if button == "RightButton" then
        self:OnRightClick()
    end
end

function StyleMixin:OnRightClick()
    ResolveHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.OpenReputationPanel then
        SharedStyleHelpers.OpenReputationPanel()
    elseif ToggleCharacter then
        ToggleCharacter("ReputationFrame")
    end
end


function StyleMixin:OnDragStart()
    ResolveHelpers()
    if SharedStyleHelpers and SharedStyleHelpers.BeginSecondaryShiftDrag then
        SharedStyleHelpers.BeginSecondaryShiftDrag(self)
    end
end

function StyleMixin:OnDragStop()
    ResolveHelpers()
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

    local width = Chrome.GetWidth()
    self:SetSize(width, FRAME_HEIGHT)

    if self.Bar and self.Bar.SetSize then
        self.Bar:SetSize(width, BAR_HEIGHT)
    end

    if self.LabelContainer and self.LabelContainer.Label then
        self.LabelContainer.Label:SetWidth(width)
    end

    Chrome.LayoutDividers(self)
end

function StyleMixin:OnSecondaryLoad()
    ResolveHelpers()
    self:ConfigureDragSupport()
    ApplyFrameLayering(self)

    local Chrome = Addon.UI and Addon.UI.ClassicChrome
    if Chrome then
        Chrome.BuildSlicedChrome(self, "Border")
    end
    self:ResizeToConfiguredWidth()
end

XPBarClassicReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
