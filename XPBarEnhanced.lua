-- XP Bar Enhanced - Core.lua

local addonName, ns = ...
local ADDON_NAME = addonName or "XPBarEnhanced"

-- Initialize addon namespace from WoW's addon-private table and keep
-- a compatibility global for existing module load pattern.
ns = ns or {}
XPBarEnhanced = ns
local Addon = ns
Addon.L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true)
-- Flavor detection.
--
-- WOW_PROJECT_ID alone is not usable here. The "Forever" beta runs as game type
-- camelot and reports WOW_PROJECT_MAINLINE, so a WOW_PROJECT_CLASSIC comparison
-- classifies it as retail. Its interface version is 16001, which also falls
-- outside the old 11500-11999 Classic Era band.
--
-- Interface numbering is the reliable signal: retail has been six digits since
-- 10.0 (100000, currently 120100), while every classic-style flavor is five
-- digits (Classic Era 11508, camelot 16001, Mists 50500). Treat anything below
-- the retail floor as a classic-style client.
local RETAIL_MIN_INTERFACE = 100000
local interfaceVersion = 0
if GetBuildInfo then
    interfaceVersion = tonumber((select(4, GetBuildInfo()))) or 0
end
Addon.InterfaceVersion = interfaceVersion
Addon.IsClassicEra = (rawget(_G, "WOW_PROJECT_ID") == rawget(_G, "WOW_PROJECT_CLASSIC"))
    or (interfaceVersion > 0 and interfaceVersion < RETAIL_MIN_INTERFACE)

-- Housing availability must be asked of the housing service itself and never
-- inferred from the flavor. The camelot beta exposes a C_Housing table whose
-- requests the realm cannot answer, so an existence check is not enough: the
-- login-time house queries were what dropped the connection there.
--
-- Fails closed. Anything other than an explicit "yes" disables housing, so a
-- client that lacks the capability query is treated as having no housing.
function Addon.IsHousingAvailable()
    local housing = rawget(_G, "C_Housing")
    if type(housing) ~= "table" or type(housing.IsHousingServiceEnabled) ~= "function" then
        return false
    end

    local ok, enabled = pcall(housing.IsHousingServiceEnabled)
    return (ok and enabled == true) or false
end

Addon.EventNames = {
    XPBAR_BROADCAST_UPDATE = "XPBAR:BROADCAST_UPDATE",
    CONFIG_UPDATED = "CONFIG:UPDATED",
    COLORS_UPDATED = "COLORS:UPDATED",
    PROFILE_CHANGED = "PROFILE:CHANGED",
    PROFILES_UPDATED = "PROFILES:UPDATED",
    QUESTS_CACHE_INVALIDATED = "QUESTS:CACHE_INVALIDATED",
    QUESTS_CACHE_REBUILT = "QUESTS:CACHE_REBUILT",
    XPBAR_ANIMATION_CONTEXT = "XPBAR:ANIMATION_CONTEXT",
    REPUTATION_BROADCAST_UPDATE = "REPUTATION:BROADCAST_UPDATE",
    HOUSING_BROADCAST_UPDATE = "HOUSING:BROADCAST_UPDATE",
    HONOR_BROADCAST_UPDATE = "HONOR:BROADCAST_UPDATE",
    PROFESSION_BROADCAST_UPDATE = "PROFESSION:BROADCAST_UPDATE",
}

Addon.OptionsCategory = "XP Bar Enhanced"

-- Core modules
Addon.Config = Addon.Config or {}
Addon.Database = Addon.Database or {}
Addon.ProfileManager = Addon.ProfileManager or {}
Addon.Session = Addon.Session or {}
Addon.Utils = Addon.Utils or {}
Addon.ReputationCalculations = Addon.ReputationCalculations or {}
Addon.ReputationSession = Addon.ReputationSession or {}
Addon.HousingSession = Addon.HousingSession or {}
Addon.HonorSession = Addon.HonorSession or {}
Addon.ProfessionSession = Addon.ProfessionSession or {}
Addon.SecondaryBarManager = Addon.SecondaryBarManager or {}

-- State
Addon.state =
    Addon.state or
    {
        requestingTimePlayed = false,
        xpGainDisabled = false,
        defaultXPBarHidden = false
    }

-- Default to automatic startup. The addon should initialize on login unless the
-- user explicitly disables it for troubleshooting. The earlier startup gate was
-- blocking legitimate login initialization and made settings look like they were
-- not being saved.
Addon.enabled = true
Addon.startupLog = Addon.startupLog or {}
function Addon:Log(message)
    if not message then
        return
    end
    print(string.format("|cFF00FF00[XPBarEnhanced]|r %s", tostring(message)))
    table.insert(Addon.startupLog, tostring(message))
    if #Addon.startupLog > 25 then
        table.remove(Addon.startupLog, 1)
    end
end

-- Database reference
Addon.db = Addon.db or {}

-- UI namespaces
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}

