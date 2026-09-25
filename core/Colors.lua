-- XP Bar Enhanced - Colors.lua
-- Centralized color management for all XP bar elements

---@class XPBarColorRGBA
---@field r number Red component (0-1)
---@field g number Green component (0-1)
---@field b number Blue component (0-1)
---@field a number Alpha component (0-1)

---@class XPBarColorsService
---@field Key table<string, string> Color key constants
---@field Get fun(self: XPBarColorsService, colorKey: string): XPBarColorRGBA Get color by key
---@field ResetAll fun(self: XPBarColorsService) Reset all colors to defaults

local Addon = XPBarEnhanced
Addon.Colors = {}
local Colors = Addon.Colors

-------------------------------------------------------------------
-- Color Keys (Constants)
-------------------------------------------------------------------

Colors.Key = {
    XpBar = "xpBar",
    XpBarRested = "xpBarRested",
    Rested = "rested",
    QuestComplete = "questComplete",
    QuestIncomplete = "questIncomplete",
    SecondaryReputation = "secondaryReputation",
    SecondaryHousing = "secondaryHousing",
    SecondaryHonor = "secondaryHonor",
    SecondaryProfession = "secondaryProfession"
}

-------------------------------------------------------------------
-- Color Access
-------------------------------------------------------------------

---Get color from config or defaults
---@param colorKey string The color key to look up
---@return XPBarColorRGBA color The color table with r,g,b,a fields
function Colors:Get(colorKey)
    if Addon.Config and Addon.Config.GetColor then
        local color = Addon.Config:GetColor(colorKey)
        if color then
            return color
        end
    end

    -- Fallback to white if color not found
    return {r = 1, g = 1, b = 1, a = 1}
end

---Reset all colors to defaults
function Colors:ResetAll()
    -- Write the defaults into the active write target only (the profile when
    -- one is active, otherwise Global), so Global's customizations survive a
    -- reset made on a profile. Explicit defaults rather than nil: on a profile,
    -- nil inherits Global's colors instead of the defaults.
    local target = Addon.Config and Addon.Config.GetSettingsStorage and Addon.Config:GetSettingsStorage()
        or Addon.db
    if target then
        target.colors = Addon.Utils.Clone(Addon.defaults.colors)
    end

    Colors:NotifyColorsChanged()
end

---Broadcast a color change so both the options swatches and the live bars
---repaint. COLORS_UPDATED drives the options previews; the domain EmitUpdate
---calls drive the actual bars (which do not subscribe to COLORS_UPDATED).
function Colors:NotifyColorsChanged()
    if Addon.EventBus and Addon.EventBus.Emit and Addon.EventNames then
        Addon.EventBus:Emit(Addon.EventNames.COLORS_UPDATED, { event = Addon.EventNames.COLORS_UPDATED })
    end
    if Addon.Session and Addon.Session.EmitUpdate then
        Addon.Session:EmitUpdate("XPBAR:BROADCAST_UPDATE")
    end
    if Addon:IsFeatureEnabled("reputation", "EmitUpdate") then
        Addon.ReputationSession:EmitUpdate()
    end
    if Addon:IsFeatureEnabled("housing", "EmitUpdate") then
        Addon.HousingSession:EmitUpdate()
    end
    if Addon:IsFeatureEnabled("honor", "EmitUpdate") then
        Addon.HonorSession:EmitUpdate()
    end
    if Addon:IsFeatureEnabled("profession", "EmitUpdate") then
        Addon.ProfessionSession:EmitUpdate()
    end
end

return Colors
