-- XP Bar Enhanced - Database.lua
-- Simplified database management

---@class Database
---@field Initialize fun(self: Database) Initialize the database with defaults
---@field GetDB fun(self: Database): table Get the root saved-variables table
---@field GetSessionData fun(self: Database): table Get the session data table
---@field GetPlayerKey fun(self: Database): string Get the player-realm key
---@field IsXPGainDisabled fun(self: Database): boolean Check if XP gain is disabled
---@field SetXPGainDisabled fun(self: Database, disabled: boolean) Set XP gain disabled state

local Addon = XPBarEnhanced
Addon.Database = Addon.Database or {}

local Database = Addon.Database

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

function Database:Initialize()
    -- Create database if it doesn't exist
    if not XPBarEnhancedDB then
        XPBarEnhancedDB = {}
    end

    -- Merge defaults if Utils available
    local Utils = Addon.Utils
    local defaults = Addon.defaults
    if Utils and Utils.MergeDefaults and defaults then
        Utils.MergeDefaults(XPBarEnhancedDB, defaults)
    end

    -- Set addon database reference
    Addon.db = XPBarEnhancedDB

    if Addon.db.secondaryBarPosition
        and Addon.db.secondaryBarPosition.relativeTo == "SecondaryStatusTrackingBarContainer"
        and Addon.db.secondaryBarPosition.point == "CENTER"
        and Addon.db.secondaryBarPosition.relativePoint == "CENTER"
        and (Addon.db.secondaryBarPosition.x or 0) == 0
        and (Addon.db.secondaryBarPosition.y or 0) == 0 then
        Addon.db.secondaryBarPosition = {
            point = "BOTTOM",
            relativeTo = "UIParent",
            relativePoint = "BOTTOM",
            x = 0,
            y = 34,
        }
    end

    Addon.db.sessionData = Addon.db.sessionData or {}
    Addon.db.reputationSessionData = Addon.db.reputationSessionData or {}

    -- Set player key
    local playerName = UnitName("player") or "Unknown"
    local realmName = GetRealmName() or "Unknown"
    Addon.playerKey = string.format("%s-%s", playerName, realmName)
end

-------------------------------------------------------------------
-- DATABASE ACCESS
-------------------------------------------------------------------

---Return the root saved-variables database table
function Database:GetDB()
    return Addon.db or {}
end

---Return the session data table stored in the database
function Database:GetSessionData()
    local db = self:GetDB()
    db.sessionData = db.sessionData or {}
    return db.sessionData
end

---Return the reputation session data table stored in the database
function Database:GetReputationSessionData()
    local db = self:GetDB()
    db.reputationSessionData = db.reputationSessionData or {}
    return db.reputationSessionData
end

---Return the cached player/realm key used for per-character storage
function Database:GetPlayerKey()
    -- Generate playerKey on-demand if not yet initialized
    if not Addon.playerKey then
        local playerName = UnitName("player") or "Unknown"
        local realmName = GetRealmName() or "Unknown"
        Addon.playerKey = string.format("%s-%s", playerName, realmName)
    end
    return Addon.playerKey
end

-------------------------------------------------------------------
-- XP GAIN STATE
-------------------------------------------------------------------

---Return whether XP gain is currently disabled for the player
function Database:IsXPGainDisabled()
    -- Safe call to IsXPUserDisabled (may not exist in all versions)
    local disabled = false
    if IsXPUserDisabled then
        disabled = IsXPUserDisabled()
    end
    Addon.state.xpGainDisabled = disabled
    return disabled
end

---Set whether XP gain is disabled
function Database:SetXPGainDisabled(disabled)
    Addon.state.xpGainDisabled = disabled
end

return Database
