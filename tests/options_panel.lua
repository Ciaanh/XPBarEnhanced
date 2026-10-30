-- The options panel's fold state: decided at login, after a profile switch and after a reset,
-- and otherwise left to the player. Changing a setting refreshes the panel, and that refresh
-- used to fold Advanced away again. The panel's XML is not loaded, so a stand-in panel records
-- the calls the Options module makes on it.
local H = dofile((arg[1] or ".") .. "/tests/harness.lua")

local Addon = H.Load(nil)
-- Options.lua is listed in OptionsPanel.xml, which the harness skips.
assert(loadfile(H.ROOT .. "/ui/options/Options.lua"))(H.ADDON, Addon)

local panel = { controls = {}, defaultsApplied = 0, refreshes = 0 }
function panel:ApplyDisclosureDefaults() self.defaultsApplied = self.defaultsApplied + 1 end
function panel:Refresh() self.refreshes = self.refreshes + 1 end
XPBarEnhancedOptionsPanel = panel

H.Login()
H.Check("fold defaults applied at login", panel.defaultsApplied, 1)

Addon.Options:OnOptionChanged("xpRateWindow")
Addon.Options:OnOptionChanged("showKillsToLevelText")
H.Check("a setting change refreshes the panel", panel.refreshes, 2)
H.Check("but leaves the fold state alone", panel.defaultsApplied, 1)

Addon.Options:Open()
H.Check("opening the panel again leaves it alone too", panel.defaultsApplied, 1)

-- Another readout comes with another profile or a reset: fold again, as a login would.
XPBarEnhancedOptionsMixin.OnProfileChanged(panel)
H.Check("a profile switch folds again", panel.defaultsApplied, 2)
Addon.Options.frame = panel
Addon.Options:AcceptResetSettingsDialog()
H.Check("so does resetting the settings", panel.defaultsApplied, 3)

H.CheckNoErrors("no errors")
H.Done()
