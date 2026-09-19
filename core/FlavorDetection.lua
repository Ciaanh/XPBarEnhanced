-- XP Bar Enhanced - Flavor and capability detection

local Addon = XPBarEnhanced

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