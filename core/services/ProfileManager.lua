-- XP Bar Enhanced - ProfileManager.lua
-- Optional profile system with global fallback.

local Addon = XPBarEnhanced
Addon.ProfileManager = Addon.ProfileManager or {}

local ProfileManager = Addon.ProfileManager
local EventNames = Addon.EventNames or {}

local RESERVED_PROFILE_NAME = "Global"

local function cloneValue(value)
    if Addon.Utils and Addon.Utils.Clone then
        return Addon.Utils.Clone(value)
    end

    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = cloneValue(inner)
    end
    return copy
end

local function trim(input)
    if type(input) ~= "string" then
        return nil
    end

    local value = input:match("^%s*(.-)%s*$")
    if value == "" then
        return nil
    end
    return value
end

local function emit(eventName, payload)
    if Addon.EventBus and Addon.EventBus.Emit and eventName then
        Addon.EventBus:Emit(eventName, payload)
    end
end

local function ensureStorage()
    Addon.db = Addon.db or {}
    Addon.db.profiles = Addon.db.profiles or {}
    Addon.db.characterProfileKeys = Addon.db.characterProfileKeys or {}
    return Addon.db
end

local function getCharacterKey(characterKey)
    if characterKey then
        return characterKey
    end

    if Addon.Database and Addon.Database.GetPlayerKey then
        return Addon.Database:GetPlayerKey()
    end

    -- Use C_PlayerInfo.GetName (REQUIRES a playerLocation) to avoid secret
    -- value issues in 12.0.0+; pcall-guarded with a UnitName fallback.
    local playerName
    if C_PlayerInfo and C_PlayerInfo.GetName and PlayerLocation and PlayerLocation.CreateFromUnit then
        local ok, name = pcall(C_PlayerInfo.GetName, PlayerLocation:CreateFromUnit("player"))
        if ok and type(name) == "string" and name ~= "" then
            playerName = name
        end
    end
    playerName = playerName or UnitName("player") or "Unknown"
    local realmName = GetRealmName() or "Unknown"
    return string.format("%s-%s", playerName, realmName)
end

local function getSettingsSnapshot(source)
    local snapshot = {}
    local defaults = Addon.defaults or {}

    for key in pairs(defaults) do
        if key ~= "profiles" and key ~= "characterProfileKeys" then
            local value = source[key]
            if value == nil then
                value = defaults[key]
            end
            snapshot[key] = cloneValue(value)
        end
    end

    return snapshot
end

local function getEffectiveSettingsSnapshot()
    local snapshot = {}
    local defaults = Addon.defaults or {}
    local config = Addon.Config

    for key in pairs(defaults) do
        if key ~= "profiles" and key ~= "characterProfileKeys" then
            local value
            if config and config.GetOptionValue then
                value = config:GetOptionValue(key)
            end
            if value == nil then
                value = defaults[key]
            end
            snapshot[key] = cloneValue(value)
        end
    end

    return snapshot
end

function ProfileManager:Initialize()
    local db = ensureStorage()

    -- Backward-compatible migration from older single key experiments.
    if db.activeProfile ~= nil then
        local playerKey = getCharacterKey()
        db.characterProfileKeys[playerKey] = db.activeProfile
        db.activeProfile = nil
    end
end

function ProfileManager:NormalizeProfileName(name)
    local normalized = trim(name)
    if not normalized then
        return nil
    end
    
    -- Validate length: max 32 characters for UI consistency, and max 128 bytes
    -- for storage safety. Characters are counted in UTF-8 so non-Latin names
    -- (Cyrillic/CJK use multiple bytes per character) are not rejected early.
    local charLength = strlenutf8 and strlenutf8(normalized) or #normalized
    local byteLength = #normalized
    if charLength > 32 or byteLength > 128 then
        return nil
    end
    
    if normalized == RESERVED_PROFILE_NAME then
        return nil
    end
    return normalized
end

function ProfileManager:GetProfiles()
    local db = ensureStorage()
    return db.profiles
end

function ProfileManager:GetProfileNames()
    local names = {}
    local profiles = self:GetProfiles()

    for name in pairs(profiles) do
        names[#names + 1] = name
    end

    table.sort(names, function(left, right)
        return string.lower(left) < string.lower(right)
    end)

    return names
end

function ProfileManager:GetProfile(name)
    local normalized = self:NormalizeProfileName(name)
    if not normalized then
        return nil
    end

    local profiles = self:GetProfiles()
    return profiles[normalized]
end

function ProfileManager:GetAssignedProfileKey(characterKey)
    local db = ensureStorage()
    local key = getCharacterKey(characterKey)
    return db.characterProfileKeys[key]
end

function ProfileManager:GetActiveProfileKey()
    local assigned = self:GetAssignedProfileKey()
    if not assigned then
        return nil
    end

    local profiles = self:GetProfiles()
    if not profiles[assigned] then
        return nil
    end

    return assigned
end

function ProfileManager:GetActiveProfile()
    local activeKey = self:GetActiveProfileKey()
    if not activeKey then
        return nil
    end

    local profiles = self:GetProfiles()
    return profiles[activeKey]
end

function ProfileManager:SetAssignedProfileKey(profileName, silent)
    local db = ensureStorage()
    local playerKey = getCharacterKey()

    local normalized = self:NormalizeProfileName(profileName)
    if profileName ~= nil and not normalized then
        return false, "Invalid profile name"
    end

    if normalized and not db.profiles[normalized] then
        return false, "Profile does not exist"
    end

    local oldProfile = db.characterProfileKeys[playerKey]
    if oldProfile == normalized then
        return true
    end

    db.characterProfileKeys[playerKey] = normalized

    if not silent then
        emit(EventNames.PROFILE_CHANGED, {
            event = EventNames.PROFILE_CHANGED,
            oldProfile = oldProfile,
            newProfile = normalized,
            playerKey = playerKey,
        })
    end

    return true
end

function ProfileManager:CreateProfile(name, source)
    local normalized = self:NormalizeProfileName(name)
    if not normalized then
        return false, "Invalid profile name"
    end

    local db = ensureStorage()
    if db.profiles[normalized] then
        return false, "Profile already exists"
    end

    local sourceTable = source
    if not sourceTable then
        sourceTable = getEffectiveSettingsSnapshot()
    end

    db.profiles[normalized] = cloneValue(sourceTable)

    emit(EventNames.PROFILES_UPDATED, {
        event = EventNames.PROFILES_UPDATED,
        action = "create",
        profile = normalized,
    })

    return true
end

function ProfileManager:RenameProfile(oldName, newName)
    local oldKey = self:NormalizeProfileName(oldName)
    local newKey = self:NormalizeProfileName(newName)

    if not oldKey or not newKey then
        return false, "Invalid profile name"
    end

    local db = ensureStorage()
    if not db.profiles[oldKey] then
        return false, "Profile does not exist"
    end
    if db.profiles[newKey] then
        return false, "Profile already exists"
    end

    db.profiles[newKey] = db.profiles[oldKey]
    db.profiles[oldKey] = nil

    for playerKey, assigned in pairs(db.characterProfileKeys) do
        if assigned == oldKey then
            db.characterProfileKeys[playerKey] = newKey
        end
    end

    emit(EventNames.PROFILES_UPDATED, {
        event = EventNames.PROFILES_UPDATED,
        action = "rename",
        oldProfile = oldKey,
        profile = newKey,
    })

    return true
end

function ProfileManager:DeleteProfile(name)
    local key = self:NormalizeProfileName(name)
    if not key then
        return false, "Invalid profile name"
    end

    local db = ensureStorage()
    if not db.profiles[key] then
        return false, "Profile does not exist"
    end

    db.profiles[key] = nil

    for playerKey, assigned in pairs(db.characterProfileKeys) do
        if assigned == key then
            db.characterProfileKeys[playerKey] = nil
        end
    end

    emit(EventNames.PROFILES_UPDATED, {
        event = EventNames.PROFILES_UPDATED,
        action = "delete",
        profile = key,
    })

    return true
end

function ProfileManager:BuildGlobalSettingsSnapshot()
    local db = ensureStorage()
    return getSettingsSnapshot(db)
end

function ProfileManager:BuildEffectiveSettingsSnapshot()
    return getEffectiveSettingsSnapshot()
end

return ProfileManager
