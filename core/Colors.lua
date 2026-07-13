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
---@field Set fun(self: XPBarColorsService, colorKey: string, color: XPBarColorRGBA) Set color by key
---@field GetDefault fun(self: XPBarColorsService, colorKey: string): XPBarColorRGBA Get default color
---@field Reset fun(self: XPBarColorsService, colorKey: string) Reset color to default
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

---Set color in configuration
---@param colorKey string The color key to set
---@param color XPBarColorRGBA|table The color to set (can be {r,g,b,a} or array)
function Colors:Set(colorKey, color)
    local normalized = {
        r = color.r or color[1] or 1,
        g = color.g or color[2] or 1,
        b = color.b or color[3] or 1,
        a = color.a or color[4] or 1
    }

    if Addon.Config and Addon.Config.SetColor then
        local hex = string.format(
            "%02X%02X%02X%02X",
            math.floor(normalized.r * 255 + 0.5),
            math.floor(normalized.g * 255 + 0.5),
            math.floor(normalized.b * 255 + 0.5),
            math.floor(normalized.a * 255 + 0.5)
        )
        -- Non-silent so SetColor emits COLORS_UPDATED exactly once
        Addon.Config:SetColor(colorKey, hex)
        return
    end

    if not Addon.db then
        return
    end

    Addon.db.colors = Addon.db.colors or {}
    Addon.db.colors[colorKey] = normalized
end

---Get default color from the defaults table
---@param colorKey string The color key to look up
---@return XPBarColorRGBA color The default color table
function Colors:GetDefault(colorKey)
    if Addon.Config and Addon.Config.GetDefaultColor then
        local color = Addon.Config:GetDefaultColor(colorKey)
        if color then
            return color
        end
    end

    return Addon.defaults.colors[colorKey] or {r = 1, g = 1, b = 1, a = 1}
end

---Reset a color to its default value
---@param colorKey string The color key to reset
function Colors:Reset(colorKey)
    if Addon.Config and Addon.Config.ResetColor then
        -- Non-silent so ResetColor emits COLORS_UPDATED exactly once
        Addon.Config:ResetColor(colorKey)
        return
    end

    local defaultColor = self:GetDefault(colorKey)
    self:Set(colorKey, defaultColor)
end

---Reset all colors to defaults
function Colors:ResetAll()
    -- Clear only the active write target (the profile when one is active,
    -- otherwise the global table). Wiping both layers would destroy the
    -- user's global customizations while they are only editing a profile.
    local target = Addon.Config and Addon.Config.GetSettingsStorage and Addon.Config:GetSettingsStorage()
    if target then
        target.colors = nil
    elseif Addon.db then
        Addon.db.colors = nil
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
    if Addon.ReputationSession and Addon.ReputationSession.EmitUpdate then
        Addon.ReputationSession:EmitUpdate()
    end
    if Addon.HousingSession and Addon.HousingSession.EmitUpdate then
        Addon.HousingSession:EmitUpdate()
    end
    if Addon.HonorSession and Addon.HonorSession.EmitUpdate then
        Addon.HonorSession:EmitUpdate()
    end
    if Addon.ProfessionSession and Addon.ProfessionSession.EmitUpdate then
        Addon.ProfessionSession:EmitUpdate()
    end
end

return Colors
