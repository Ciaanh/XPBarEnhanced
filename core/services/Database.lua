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

-- Resolve the player's character name for the per-character storage key.
-- Forever is realmless and identifies characters by first + last name, so only
-- that flavor uses UnitFullName. Other clients keep their normal UnitName path.
local function GetSafePlayerName()
    if Addon.Client == Addon.Clients.FOREVER and UnitFullName then
        local fullName = UnitFullName("player")
        if type(fullName) == "string" and fullName ~= "" then
            return fullName
        end
    end

    local unitName = UnitName and UnitName("player")
    if type(unitName) == "string" and unitName ~= "" then
        return unitName
    end

    if C_PlayerInfo and C_PlayerInfo.GetName and PlayerLocation and PlayerLocation.CreateFromUnit then
        local ok, name = pcall(function()
            return C_PlayerInfo.GetName(PlayerLocation:CreateFromUnit("player"))
        end)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return UnitName("player") or "Unknown"
end

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

function Database:Initialize()
    -- Create database if it doesn't exist
    if type(XPBarEnhancedDB) ~= "table" then
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

    -- Optional profile system storage.
    local function ensureTable(key)
        if type(Addon.db[key]) ~= "table" then
            Addon.db[key] = {}
        end
    end

    ensureTable("profiles")
    ensureTable("characterProfileKeys")

    if Addon.db.secondaryBarPosition ~= nil and type(Addon.db.secondaryBarPosition) ~= "table" then
        Addon.db.secondaryBarPosition = nil
    end

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

    -- Migrate single secondaryBarPosition to per-style secondaryBarPositions table.
    -- Runs once; after migration the old key is removed.
    if Addon.db.secondaryBarPosition then
        if not Addon.db.secondaryBarPositions then
            local style = Addon.db.barStyle or "flat"
            Addon.db.secondaryBarPositions = { [style] = Addon.db.secondaryBarPosition }
        end
        Addon.db.secondaryBarPosition = nil
    end

    ensureTable("secondaryBarPositions")
    ensureTable("sessionData")
    ensureTable("reputationSessionData")
    ensureTable("housingSessionData")
    ensureTable("honorSessionData")
    ensureTable("professionSessionData")

    -- Set player key
    local playerName = GetSafePlayerName()
    local realmName = GetRealmName() or "Unknown"
    Addon.playerKey = string.format("%s-%s", playerName, realmName)

    -- Backward-compatible migration from older activeProfile experiments.
    if Addon.db.activeProfile ~= nil then
        Addon.db.characterProfileKeys[Addon.playerKey] = Addon.db.activeProfile
        Addon.db.activeProfile = nil
    end
end

-------------------------------------------------------------------
-- DATABASE ACCESS
-------------------------------------------------------------------

---Return the root saved-variables database table
function Database:GetDB()
    return Addon.db or {}
end

---Return the per-character subtable of a session store, migrating any legacy
---flat (account-wide) data to the current character once. Session stores are
---keyed by player-realm so alts do not inherit each other's played time.
local function getPerCharacterTable(db, storeKey)
    db[storeKey] = db[storeKey] or {}
    local store = db[storeKey]
    db._migrationFlags = db._migrationFlags or {}
    local migrations = db._migrationFlags
    local playerKey = Database:GetPlayerKey()

    if not migrations[storeKey] then
        -- Legacy layout: session fields stored directly on the store table.
        if store.sessionStart ~= nil or store.lastUpdate ~= nil then
            local legacy = {}
            for k, v in pairs(store) do
                legacy[k] = v
                store[k] = nil
            end
            store[playerKey] = legacy
        end
        migrations[storeKey] = true
    end

    store[playerKey] = store[playerKey] or {}
    return store[playerKey]
end

---Return the session data table stored in the database
function Database:GetSessionData()
    return getPerCharacterTable(self:GetDB(), "sessionData")
end

---Return the reputation session data table stored in the database
function Database:GetReputationSessionData()
    return getPerCharacterTable(self:GetDB(), "reputationSessionData")
end

---Return the housing session data table stored in the database
function Database:GetHousingSessionData()
    return getPerCharacterTable(self:GetDB(), "housingSessionData")
end

---Return the honor session data table stored in the database
function Database:GetHonorSessionData()
    return getPerCharacterTable(self:GetDB(), "honorSessionData")
end

---Return the profession session data table stored in the database
function Database:GetProfessionSessionData()
    return getPerCharacterTable(self:GetDB(), "professionSessionData")
end

---Return the cached player/realm key used for per-character storage
function Database:GetPlayerKey()
    -- Generate playerKey on-demand if not yet initialized
    if not Addon.playerKey then
        local playerName = GetSafePlayerName()
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
