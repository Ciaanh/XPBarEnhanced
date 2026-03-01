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

	-- Hook EditModeManagerFrame Show/Hide rather than EnterEditMode/ExitEditMode.
	-- EnterEditMode/ExitEditMode may be inherited via metatable and not table-accessible,
	-- causing hooksecurefunc to silently fail. Show/Hide are standard Frame API methods
	-- that are always directly accessible on any frame object.
	hooksecurefunc(EditModeManagerFrame, "Show", function()
		self:OnEnterEditMode()
	end)
	hooksecurefunc(EditModeManagerFrame, "Hide", function()
		self:OnExitEditMode()
	end)

	self.initialized = true
	--print("|cFF00FF00[XPBarEnhanced]|r Edit Mode: integration initialized")
end

-------------------------------------------------------------------
-- EDIT MODE CALLBACKS
-------------------------------------------------------------------

--- Called when player enters Edit Mode
function EditMode:OnEnterEditMode()
	-- Guard against EditModeManagerFrame:Show() firing multiple times
	-- (Blizzard can re-show the frame internally during Edit Mode updates)
	if self._inEditMode then
		return
	end
	self._inEditMode = true

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
	-- Use a Frame (not Texture) at HIGH strata so it renders above all bar layers
	if self.editOverlay then
		-- Re-parent to the current bar in case style changed
		self.editOverlay:SetParent(bar)
		self.editOverlay:SetAllPoints(bar)
	else
		self.editOverlay = CreateFrame("Frame", nil, bar)
		self.editOverlay:SetAllPoints(bar)
		self.editOverlay:SetFrameStrata("HIGH")

		local bg = self.editOverlay:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.2, 0.6, 1.0, 0.25)

		local border = self.editOverlay:CreateTexture(nil, "BORDER")
		border:SetPoint("TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", 1, -1)
		border:SetColorTexture(0.3, 0.7, 1.0, 0.6)
		local inner = self.editOverlay:CreateTexture(nil, "ARTWORK")
		inner:SetPoint("TOPLEFT", 1, -1)
		inner:SetPoint("BOTTOMRIGHT", -1, 1)
		inner:SetColorTexture(0.2, 0.6, 1.0, 0.25)

		local label = self.editOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("TOPRIGHT", -4, -3)
		label:SetText("Edit Mode")
		label:SetTextColor(1, 1, 1, 0.9)
	end
	self.editOverlay:Show()

	-- Temporarily unlock the bar for Edit Mode
	if Addon.db then
		Addon.db.barLocked = false
	end
end

--- Called when player exits Edit Mode
function EditMode:OnExitEditMode()
	self._inEditMode = false

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

	-- Re-hide the Blizzard bar: during Edit Mode, Blizzard re-shows its containers.
	-- Deferred to next frame so Blizzard's exit-mode cleanup completes first.
	C_Timer.After(0, function()
		if Addon.BarManager and Addon.BarManager.ApplyDefaultXPBarVisibility then
			Addon.BarManager:ApplyDefaultXPBarVisibility()
		end
	end)
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
