-- XP Bar Enhanced - Classic Secondary Bar Style
-- Displays the watched faction's reputation as a Blizzard-style bordered bar
-- with standing-color atlas fill.

local Addon = XPBarEnhanced
local SharedStyleHelpers = Addon.UI.SharedStyleHelpers
local StyleHelpers = Addon.UI.StyleHelpers

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

-- Returns (atlasName, fallbackColor) for the given context.
-- atlasName is nil when a solid color fill should be used instead.
local function GetBarFill(context)
    if context.isCompanion then
        return nil, StyleHelpers.GetFactionColor(context)
    end

    if context.factionType == "major" or context.factionType == "paragon" then
        return BLUE_ATLAS, nil
    end

    local level = context.reactionLevel
    if level and STANDING_ATLAS[level] then
        return STANDING_ATLAS[level], nil
    end

    return nil, StyleHelpers.GetFactionColor(context)
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
    local c = fallbackColor or StyleHelpers.GetFactionColor(nil)
    bar:SetStatusBarColor(c.r, c.g, c.b)
end


function StyleMixin:GetPositionConfigKey()
    return SharedStyleHelpers.GetSecondaryPositionConfigKey()
end

function StyleMixin:GetFallbackPosition()
    return SharedStyleHelpers.BuildConfiguredStyleOffsetFallback("BOTTOM", 0, 34, 20)
end

function StyleMixin:GetTextTickerInterval()
    return 1.0
end

function StyleMixin:GetTextTickerContext()
    return self._lastContext or self:GetInitialContext()
end

function StyleMixin:OnTextTick(context)
    if context and self.LabelContainer then
        self.LabelContainer.Label:SetText(SharedStyleHelpers.BuildSecondaryLabel(context))
    end
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

    local atlas, color = GetBarFill(context)
    SharedStyleHelpers.ApplyStatusBarProgress(self.Bar, context, nil)
    ApplyBarFill(self.Bar, atlas, color)
    if self.LabelContainer then
        self.LabelContainer.Label:SetText(SharedStyleHelpers.BuildSecondaryLabel(context))
    end
end

function StyleMixin:OnEnter()
    if not self._lastContext then
        return
    end
    local context = self._lastContext
    SharedStyleHelpers.ShowSecondaryTooltip(self, context, "ANCHOR_TOP")
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

XPBarClassicReputationMixin = CreateFromMixins(XPBarSecondaryBaseMixin, StyleMixin)
