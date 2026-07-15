-- XP Bar Enhanced - Core.lua

local addonName, ns = ...
local ADDON_NAME = addonName or "XPBarEnhanced"

-- Initialize addon namespace from WoW's addon-private table and keep
-- a compatibility global for existing module load pattern.
ns = ns or {}
XPBarEnhanced = ns
local Addon = ns
Addon.L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true)

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

-- Database reference
Addon.db = Addon.db or {}

-- UI namespaces
Addon.UI = Addon.UI or {}
Addon.UI.Mixins = Addon.UI.Mixins or {}

