-- XP Bar Enhanced - Position Mixin ()
-- Behavior mixin for positioning: STATIC (anchored to Blizzard bar) or DRAGGABLE (user-movable with persistence)

local Addon = XPBarEnhanced

-------------------------------------------------------------------
-- GLOBAL POSITION MIXIN
-------------------------------------------------------------------

---@class XPBarPositionMixin
XPBarPositionMixin = {}
Addon.UI.Mixins.Position = XPBarPositionMixin

local PositionMixin = XPBarPositionMixin

-------------------------------------------------------------------
-- POSITION MODES
-------------------------------------------------------------------

local POSITION_MODE = {
	STATIC = "STATIC", -- Anchored to Blizzard MainMenuExpBar
	DRAGGABLE = "DRAGGABLE" -- User-movable with saved position
}

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

--- Initialize position state (called by OnLoad)
function PositionMixin:InitializePosition()
	local config = self.__xpbar_config or {}
	local positionConfig = config.position or {}
	local styleConfig = config.style or {}

	-- Apply size from style config if provided
	if styleConfig.width and styleConfig.height then
		self:SetSize(styleConfig.width, styleConfig.height)
	end

	-- Determine mode (default: STATIC)
	local mode = positionConfig.mode or POSITION_MODE.STATIC
	self.__position_mode = mode
	self.__position_key = positionConfig.positionKey or "XPBar_Default"

	-- Apply position based on mode
	if mode == POSITION_MODE.STATIC then
		self:ApplyStaticPosition()
	elseif mode == POSITION_MODE.DRAGGABLE then
		self:EnableDragging(true)
	end
end

-------------------------------------------------------------------
-- STATIC POSITIONING
-------------------------------------------------------------------

--- Apply static position (anchored to Blizzard bar)
function PositionMixin:ApplyStaticPosition()
	-- Anchor to MainStatusTrackingBarContainer if available.
	-- When a custom style is active, the container is hidden; use its parent instead
	-- to avoid anchoring to a hidden frame (undefined layout behavior in some clients).
	local container = _G.MainStatusTrackingBarContainer
	local anchor = container

	if container then
		if not container:IsShown() then
			anchor = container:GetParent() or container
		end
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
		self:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
		return
	end

	-- fallback to dragging if MainStatusTrackingBarContainer not found
	self:EnableDragging(true)
end

-------------------------------------------------------------------
-- DRAGGABLE POSITIONING
-------------------------------------------------------------------

--- Enable or disable dragging
---@param enabled boolean True to enable dragging
function PositionMixin:EnableDragging(enabled)
	-- Make frame movable (InteractionMixin handles the actual drag via Shift+click)
	self:SetMovable(enabled)
	self:EnableMouse(enabled)
	if (enabled) then
		-- Restore saved position
		self:RestorePosition()
	end
end

--- Save current position to SavedVariables
function PositionMixin:SavePosition()
	if not Addon.db.barPositions then
		Addon.db.barPositions = {}
	end

	-- Get first anchor point
	local point, relativeTo, relativePoint, x, y = self:GetPoint(1)
	if not point then
		return
	end

	-- Save position
	Addon.db.barPositions[self.__position_key] = {
		point = point,
		relativeTo = "UIParent", -- Always save relative to UIParent for consistency
		relativePoint = relativePoint,
		x = x,
		y = y
	}
end

--- Restore saved position from SavedVariables
function PositionMixin:RestorePosition()
	-- Check if saved position exists
	if not Addon.db or not Addon.db.barPositions then
		-- No saved positions, use default
		self:SetDefaultDraggablePosition()
		return
	end

	local savedPos = Addon.db.barPositions[self.__position_key]
	if not savedPos or not savedPos.point then
		-- No saved position for this key, use default
		self:SetDefaultDraggablePosition()
		return
	end

	-- Restore saved position
	self:ClearAllPoints()
	self:SetPoint(savedPos.point, UIParent, savedPos.relativePoint or "TOPLEFT", savedPos.x or 0, savedPos.y or 0)
end

--- Set default position for draggable bars
function PositionMixin:SetDefaultDraggablePosition()
	-- Try to get default from Config based on position key
	local Addon = XPBarEnhanced
	local defaultPos = nil

	if Addon.defaults and Addon.defaults.barPositions and self.__position_key then
		defaultPos = Addon.defaults.barPositions[self.__position_key]
	end

	self:ClearAllPoints()

	if defaultPos and defaultPos.point then
		-- Use default from Config
		self:SetPoint(
			defaultPos.point,
			UIParent,
			defaultPos.relativePoint or defaultPos.point,
			defaultPos.x or 0,
			defaultPos.y or 0
		)
	else
		-- Fallback: center of screen
		self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

--- Clear saved position
function PositionMixin:ClearSavedPosition()
	if Addon.db and Addon.db.barPositions then
		Addon.db.barPositions[self.__position_key] = nil
	end
end

-------------------------------------------------------------------
-- HELPER METHODS
-------------------------------------------------------------------

--- Get position key for this bar
---@return string key Position key for SavedVariables
function PositionMixin:GetPositionKey()
	return self.__position_key or "XPBar_Default"
end

--- Get position mode
---@return string mode "STATIC" or "DRAGGABLE"
function PositionMixin:GetPositionMode()
	return self.__position_mode or POSITION_MODE.STATIC
end

--- Reset position to default
function PositionMixin:ResetPosition()
	if self.__position_mode == POSITION_MODE.STATIC then
		self:ApplyStaticPosition()
	else
		self:ClearSavedPosition()
		self:SetDefaultDraggablePosition()
	end
end

--- Update position mode dynamically (for live switching)
---@param newMode string "STATIC" or "DRAGGABLE"
function PositionMixin:UpdatePositionMode(newMode)
	if newMode ~= POSITION_MODE.STATIC and newMode ~= POSITION_MODE.DRAGGABLE then
		error("Invalid position mode: " .. tostring(newMode))
	end

	local oldMode = self.__position_mode
	if oldMode == newMode then
		return -- No change needed
	end

	-- Update mode
	self.__position_mode = newMode

	-- When switching from STATIC to DRAGGABLE, capture current position
	if oldMode == POSITION_MODE.STATIC and newMode == POSITION_MODE.DRAGGABLE then
		-- Save current STATIC position as initial draggable position
		local point, relativeTo, relativePoint, x, y = self:GetPoint(1)
		if point then
			if not Addon.db.barPositions then
				Addon.db.barPositions = {}
			end
			Addon.db.barPositions[self.__position_key] = {
				point = point,
				relativeTo = "UIParent",
				relativePoint = relativePoint or point,
				x = x or 0,
				y = y or 0
			}
		end
		-- Enable dragging
		self:EnableDragging(true)
	elseif oldMode == POSITION_MODE.DRAGGABLE and newMode == POSITION_MODE.STATIC then
		-- Switching to STATIC: disable dragging and apply static anchor
		self:EnableMouse(false)
		self:SetMovable(false)
		self:ApplyStaticPosition()
	end
end

return PositionMixin
