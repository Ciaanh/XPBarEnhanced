-- XP Bar Enhanced - LibDataBroker feed
-- Publishes a compact "12.4K XP/h · ~34m" data source consumable by any LDB
-- display (Titan Panel, Bazooka, ElvUI datatexts...). Registration is
-- conditional: LibDataBroker-1.1 is provided by every display addon, so when
-- no display is installed there is nothing to feed and we simply do nothing.

local Addon = XPBarEnhanced
Addon.DataBrokerFeed = Addon.DataBrokerFeed or {}
local L = Addon.L or {}

---@class DataBrokerFeed
local Feed = Addon.DataBrokerFeed

local REFRESH_SECONDS = 5

local function isEnabled()
    return Addon.Config and Addon.Config.GetOptionValue
        and Addon.Config:GetOptionValue("enableDataBrokerFeed") ~= false
end

local function buildText()
    -- At max level, surface the active secondary source instead of XP.
    local Shared = Addon.UI and Addon.UI.SharedStyleHelpers
    local maxLevel = tonumber((GetMaxPlayerLevel and GetMaxPlayerLevel()) or 80) or 80
    local level = tonumber(UnitLevel("player")) or 0

    if level >= maxLevel and Shared and Shared.GetSecondaryInitialContext then
        local src = Shared.GetSecondaryInitialContext()
        if src and src.isAvailable then
            return string.format(L["LDB_SOURCE_FMT"], src.name or "", src.percent or 0)
        end
        return L["LDB_MAX_LEVEL"]
    end

    local formatter = Addon.TextFormatter
    local xpPerHour = Addon.Session and Addon.Session.GetXPPerHour and Addon.Session:GetXPPerHour() or 0
    local timeToLevel = Addon.Session and Addon.Session.GetTimeToLevel and Addon.Session:GetTimeToLevel()

    if not formatter or (xpPerHour or 0) <= 0 then
        return L["LDB_CALCULATING"]
    end

    -- The broker text honours abbreviateNumbers like the rest of the UI instead
    -- of falling back to a raw tostring (which printed "551938.4571" verbatim).
    local abbreviate = true
    if Addon.Config and Addon.Config.GetOptionValue then
        abbreviate = Addon.Config:GetOptionValue("abbreviateNumbers") ~= false
    end
    local rate = formatter:FormatNumber(xpPerHour, abbreviate)
    if timeToLevel and timeToLevel > 0 and formatter.FormatTime then
        return string.format(L["LDB_TEXT_FMT"], rate, formatter:FormatTime(timeToLevel, true))
    end
    return string.format(L["LDB_RATE_FMT"], rate)
end

function Feed:Refresh()
    if self._dataObject then
        self._dataObject.text = isEnabled() and buildText() or ""
    end
end

function Feed:Initialize()
    if self._initialized then
        return
    end
    self._initialized = true

    local ldb = LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not ldb then
        return -- no LDB display installed; nothing to feed
    end

    self._dataObject = ldb:NewDataObject("XPBarEnhanced", {
        type = "data source",
        label = L["LDB_LABEL"],
        icon = 4675649, -- matches the TOC IconTexture
        text = "",
        OnClick = function()
            if Addon.Stats and Addon.Stats.Toggle then
                Addon.Stats:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then
                return
            end
            tooltip:AddLine(L["LDB_LABEL"], 1, 1, 1)
            local formatter = Addon.TextFormatter
            local session = Addon.Session and Addon.Session.GetCurrent and Addon.Session:GetCurrent()
            if session and formatter then
                if formatter.FormatNumber then
                    tooltip:AddDoubleLine(L["LDB_TT_SESSION_XP"],
                        formatter:FormatNumber(session.gainedXP or 0, false), 0.7, 0.7, 0.7, 1, 1, 1)
                end
                local xpPerHour = Addon.Session.GetXPPerHour and Addon.Session:GetXPPerHour() or 0
                if xpPerHour > 0 and formatter.FormatNumber then
                    tooltip:AddDoubleLine(L["LDB_TT_RATE"],
                        formatter:FormatNumber(xpPerHour, false), 0.7, 0.7, 0.7, 1, 1, 1)
                end
            end
            tooltip:AddLine(L["LDB_TT_CLICK"], 0.4, 0.4, 0.4)
        end,
    })

    -- Refresh on XP broadcasts plus a slow ticker for the time-based ETA drift.
    if Addon.EventBus and Addon.EventBus.Register and Addon.EventNames then
        Addon.EventBus:Register(Addon.EventNames.XPBAR_BROADCAST_UPDATE, "ldb-feed", function()
            Feed:Refresh()
        end)
        Addon.EventBus:Register(Addon.EventNames.CONFIG_UPDATED, "ldb-feed-config", function()
            Feed:Refresh()
        end)
    end
    if C_Timer and C_Timer.NewTicker then
        self._ticker = C_Timer.NewTicker(REFRESH_SECONDS, function()
            Feed:Refresh()
        end)
    end

    self:Refresh()
end

return Feed
