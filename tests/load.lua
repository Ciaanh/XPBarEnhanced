-- The addon loads, logs in, counts XP and survives a /reload without an error (Retail build).
local H = dofile((arg[1] or ".") .. "/tests/harness.lua")

H.Section("Retail")
local Addon = H.Load(nil)
H.Check("namespace is the addon's global", Addon, XPBarEnhanced)
H.Check("client resolved", Addon.Client, Addon.Clients.RETAIL)
H.Login()
H.Advance(10)
H.Check("session data exists", Addon.Session:GetCurrent() ~= nil, true)
H.CheckNoErrors("no error at login")

H.player.xp = 400
H.Fire("PLAYER_XP_UPDATE", "player")
H.Check("an XP gain is counted", Addon.Session:GetCurrent().gainedXP, 400)
H.CheckNoErrors("no error on an XP gain")

Addon = H.Reload()
H.Check("the session survives a /reload", Addon.Session:GetCurrent().gainedXP, 400)
H.CheckNoErrors("no error across a /reload")

H.Done()
