-- XP Bar Enhanced - Edit Mode Integration
-- Hooks into WoW's Edit Mode to allow bar repositioning
-- Gracefully degrades on clients without Edit Mode support

local Addon = XPBarEnhanced
Addon.EditMode = Addon.EditMode or {}
local EditMode = Addon.EditMode

-------------------------------------------------------------------
-- AVAILABILITY CHECK
-------------------------------------------------------------------

--- Check if Edit Mode API is available (Retail 10.0+)
--- @return boolean
function EditMode:IsAvailable()
	return EditModeManagerFrame ~= nil
end

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

--- Initialize Edit Mode integration
--- Called from AddOnLifecycle after PLAYER_LOGIN
function EditMode:Initialize()
	if not self:IsAvailable() then
		print("|cFF00FF00[XPBarEnhanced]|r Edit Mode: not available on this client")
		return
	end

	-- Hook Edit Mode enter/exit
	if EditModeManagerFrame.EnterEditMode then
		hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
			self:OnEnterEditMode()
		end)
	end

	if EditModeManagerFrame.ExitEditMode then
		hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
			self:OnExitEditMode()
		end)
	end

	self.initialized = true
	print("|cFF00FF00[XPBarEnhanced]|r Edit Mode: integration initialized")
end

-------------------------------------------------------------------
-- EDIT MODE CALLBACKS
-------------------------------------------------------------------

--- Called when player enters Edit Mode
function EditMode:OnEnterEditMode()
	print("|cFF00FF00[XPBarEnhanced]|r Edit Mode entered")

	local bar = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
	if not bar then
		return
	end

	-- Make bar movable during Edit Mode regardless of lock state
	self.wasMovable = bar:IsMovable()
	self.wasMouseEnabled = bar:IsMouseEnabled()
	self.wasLocked = Addon.db and Addon.db.barLocked

	bar:SetMovable(true)
	bar:EnableMouse(true)

	-- Show a visual indicator that the bar is in Edit Mode
	if not self.editOverlay then
		self.editOverlay = bar:CreateTexture(nil, "OVERLAY")
		self.editOverlay:SetAllPoints(bar)
		self.editOverlay:SetColorTexture(0.2, 0.6, 1.0, 0.15)
	end
	self.editOverlay:Show()

	-- Temporarily unlock the bar for Edit Mode
	if Addon.db then
		Addon.db.barLocked = false
	end
end

--- Called when player exits Edit Mode
function EditMode:OnExitEditMode()
	print("|cFF00FF00[XPBarEnhanced]|r Edit Mode exited")

	local bar = Addon.BarManager and Addon.BarManager:GetCurrentFrame()
	if not bar then
		return
	end

	-- Save position when exiting Edit Mode
	if bar.SavePosition then
		bar:SavePosition()
		print("|cFF00FF00[XPBarEnhanced]|r Edit Mode: position saved")
	end

	-- Hide edit overlay
	if self.editOverlay then
		self.editOverlay:Hide()
	end

	-- Restore previous lock/movable state
	if self.wasLocked ~= nil then
		if Addon.db then
			Addon.db.barLocked = self.wasLocked
		end
	end

	-- Restore movable state based on lock
	if Addon.db and Addon.db.barLocked then
		bar:SetMovable(false)
		bar:EnableMouse(self.wasMouseEnabled or false)
	end
end

-------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------

--- Check if currently in Edit Mode
--- @return boolean
function EditMode:IsInEditMode()
	if not self:IsAvailable() then
		return false
	end
	return EditModeManagerFrame:IsShown() or false
end

--- Re-register bar frame after style change
--- @param bar table New bar frame
function EditMode:OnStyleChanged(bar)
	if not self.initialized or not bar then
		return
	end

	-- If we were in Edit Mode during a style change, re-apply Edit Mode state
	if self:IsInEditMode() then
		self:OnEnterEditMode()
	end
end

return EditMode
