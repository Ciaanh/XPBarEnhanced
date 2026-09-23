-- XP Bar Enhanced - Client and feature detection

local Addon = XPBarEnhanced

-- Canonical client flavor identifiers. Keep comparisons on these constants so
-- a flavor rename or value change has one source of truth.
Addon.Clients = Addon.Clients or {
    RETAIL = "retail",
    VANILLA = "vanilla",
    FOREVER = "forever",
    BURNING_CRUSADE = "burning_crusade",
    WRATH = "wrath",
    CATACLYSM = "cataclysm",
    MISTS = "mists",
    UNKNOWN = "unknown",
}

local Clients = Addon.Clients

local function ResolveGlobalPath(path)
    local value = _G
    for part in string.gmatch(path, "[^%.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = rawget(value, part)
    end
    return value
end

local FEATURE_MODULES = {
    reputation = "ReputationSession",
    housing = "HousingSession",
    honor = "HonorSession",
    profession = "ProfessionSession",
}

local function ResolveAddonPath(path)
    local value = Addon
    for part in string.gmatch(path, "[^%.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = rawget(value, part)
    end
    return value
end

local function HousingServiceEnabled()
    local housing = rawget(_G, "C_Housing")
    if type(housing) ~= "table" or type(housing.IsHousingServiceEnabled) ~= "function" then
        return false
    end

    local ok, enabled = pcall(housing.IsHousingServiceEnabled)
    return ok and enabled == true
end

local interfaceVersion = 0
if GetBuildInfo then
    interfaceVersion = tonumber((select(4, GetBuildInfo()))) or 0
end
Addon.InterfaceVersion = interfaceVersion

local FEATURE_PROFILES = {
    [Clients.RETAIL] = {
        classicClientBehavior = false,
        blizzardXPBarTextCVar = {enabled = true, requires = {"GetCVarBool"}},
        housing = {
            enabled = true,
            requires = {"C_Housing.IsHousingServiceEnabled"},
            probe = HousingServiceEnabled,
        },
        honor = true,
        profession = true,
        reputation = true,
    },
    [Clients.VANILLA] = {
        classicClientBehavior = true,
        blizzardXPBarTextCVar = false,
        housing = false,
        honor = false,
        profession = true,
        reputation = false,
    },
    [Clients.FOREVER] = {
        classicClientBehavior = true,
        blizzardXPBarTextCVar = false,
        housing = false,
        honor = false,
        profession = true,
        reputation = true,
    },
    [Clients.BURNING_CRUSADE] = {
        classicClientBehavior = true,
        blizzardXPBarTextCVar = false,
        housing = false,
        honor = false,
        profession = true,
        reputation = false,
    },
    [Clients.WRATH] = {
        classicClientBehavior = true,
        blizzardXPBarTextCVar = false,
        housing = false,
        honor = false,
        profession = true,
        reputation = false,
    },
    [Clients.CATACLYSM] = {
        classicClientBehavior = true,
        blizzardXPBarTextCVar = false,
        housing = false,
        honor = false,
        profession = true,
        reputation = false,
    },
    [Clients.MISTS] = {
        classicClientBehavior = true,
        blizzardXPBarTextCVar = false,
        housing = false,
        honor = false,
        profession = true,
        reputation = false,
    },
}

-- Add new supported classic branches here. Ranges allow patch builds within a
-- branch without requiring a code change for every interface increment.
local BUILD_FLAVORS = {
    {name = Clients.FOREVER, ranges = {{min = 16000, max = 16999}}},
    {
        name = Clients.VANILLA,
        versions = {[38002] = true}, -- Titan reforged for China
        ranges = {{min = 11500, max = 11999}},
    },
    {name = Clients.BURNING_CRUSADE, ranges = {{min = 20500, max = 20999}}},
    {name = Clients.WRATH, ranges = {{min = 30400, max = 30999}}},
    {name = Clients.CATACLYSM, ranges = {{min = 40400, max = 40999}}},
    {name = Clients.MISTS, ranges = {{min = 50500, max = 50999}}},
    {name = Clients.RETAIL, ranges = {{min = 100000, max = 199999}}},
}

local function MatchesBuild(build, entry)
    if entry.versions and entry.versions[build.interfaceVersion] then
        return true
    end

    for _, range in ipairs(entry.ranges) do
        if build.interfaceVersion >= range.min and build.interfaceVersion <= range.max then
            return true
        end
    end
    return false
end

-- Resolve raw WoW build metadata to a semantic product flavor.
function Addon.ResolveFlavor(build)
    build = build or {
        interfaceVersion = interfaceVersion,
        projectID = rawget(_G, "WOW_PROJECT_ID"),
        classicProjectID = rawget(_G, "WOW_PROJECT_CLASSIC"),
    }
    build.interfaceVersion = tonumber(build.interfaceVersion) or 0

    for _, entry in ipairs(BUILD_FLAVORS) do
        if MatchesBuild(build, entry) then
            return entry.name
        end
    end

    if build.projectID ~= nil and build.projectID == build.classicProjectID then
        return Clients.VANILLA
    end

    return Clients.UNKNOWN
end

-- Resolve a semantic flavor to the feature policy used by runtime modules.
function Addon.GetFeaturesForFlavor(flavor)
    return FEATURE_PROFILES[flavor] or {}
end

local flavor = Addon.ResolveFlavor()
Addon.Client = flavor
Addon.Features = Addon.GetFeaturesForFlavor(flavor)

function Addon:IsFeatureEnabled(feature, requiredMethod)
    local definition = self.Features and self.Features[feature]
    if definition == true then
        definition = {}
    elseif type(definition) ~= "table" or definition.enabled ~= true then
        return false
    end

    for _, apiPath in ipairs(definition.requires or {}) do
        if type(ResolveGlobalPath(apiPath)) ~= "function" then
            return false
        end
    end

    if definition.probe then
        local ok, enabled = pcall(definition.probe)
        if not (ok and enabled == true) then
            return false
        end
    end

    local moduleName = FEATURE_MODULES[feature]
    if moduleName and type(self[moduleName]) ~= "table" then
        return false
    end

    if requiredMethod and moduleName then
        return type(ResolveAddonPath(moduleName .. "." .. requiredMethod)) == "function"
    end

    return true
end

--- True when this client's flavor offers `feature` at all, whether or not it
--- is usable this moment (Retail housing also waits on the housing service).
---@param feature string
---@return boolean
function Addon:IsFeatureSupported(feature)
    local definition = self.Features and self.Features[feature]
    return definition == true or (type(definition) == "table" and definition.enabled == true)
end

--- The session module that implements `feature`, or nil.
---@param feature string
---@return table|nil
function Addon:GetFeatureModule(feature)
    local moduleName = FEATURE_MODULES[feature]
    return moduleName and self[moduleName] or nil
end

-- Housing availability must be asked of the housing service itself and never
-- inferred from the flavor. The camelot beta exposes a C_Housing table whose
-- requests the realm cannot answer, so an existence check is not enough: the
-- login-time house queries were what dropped the connection there.
--
-- Fails closed. Anything other than an explicit "yes" disables housing, so a
-- client that lacks the capability query is treated as having no housing.
function Addon.IsHousingAvailable()
    return Addon:IsFeatureEnabled("housing")
end