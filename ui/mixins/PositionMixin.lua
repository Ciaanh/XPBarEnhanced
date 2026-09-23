-- XP Bar Enhanced - Position Mixin ()
-- Behavior mixin for positioning: STATIC (anchored to Blizzard bar) or DRAGGABLE (user-movable with persistence)

local Addon = XPBarEnhanced

local function GetSettingsTable(key, createIfMissing)
	if Addon.Config and Addon.Config.GetSettingsTable then
		return Addon.Config:GetSettingsTable(key, createIfMissing)
	end

	Addon.db = Addon.db or {}
	if Addon.db[key] == nil and createIfMissing then
		Addon.db[key] = {}
	end
	return Addon.db[key]
end

local function NormalizePositionKey(key)
	if type(key) ~= "string" then
		return nil
	end

	local normalized = string.lower(key)
	if string.sub(normalized, -3) == "bar" then
		normalized = string.sub(normalized, 1, -4)
	end
	return normalized
end

local function GetSavedPosition(positions, positionKey)
	if type(positions) ~= "table" then
		return nil
	end

	local seen = {}
	local keys = {
		positionKey,
		string.lower(positionKey or ""),
		NormalizePositionKey(positionKey),
	}

	for _, key in ipairs(keys) do
		if type(key) == "string" and key ~= "" and not seen[key] then
			seen[key] = true
			local value = positions[key]
			if value and value.point then
				return value
			end
		end
	end

	return nil
end

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

--- Capture the frame's current position as genuine UIParent-relative
--- coordinates. GetPoint() may be relative to another frame (e.g. the
--- Blizzard container in STATIC mode), so storing its offsets against
--- UIParent would teleport the bar; the screen rect is anchor-independent.
---@return table|nil position Saved-position table, or nil when no rect yet
local function CaptureScreenPosition(frame)
	local left = frame.GetLeft and frame:GetLeft()
	local bottom = frame.GetBottom and frame:GetBottom()
	if not left or not bottom then
		return nil
	end

	-- GetLeft/GetBottom are expressed in the frame's effective scale;
	-- convert into UIParent's coordinate space.
	local scale = frame:GetEffectiveScale()
	local parentScale = UIParent:GetEffectiveScale()
	if parentScale and parentScale > 0 and scale and scale ~= parentScale then
		left = left * scale / parentScale
		bottom = bottom * scale / parentScale
	end

	return {
		point = "BOTTOMLEFT",
		relativeTo = "UIParent",
		relativePoint = "BOTTOMLEFT",
		x = left,
		y = bottom
	}
end

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

	-- Determine mode (default: STATIC). A style whose mode is a player option
	-- names it in modeOption, read here rather than when the style's file
	-- loads: saved settings do not exist yet at file load.
	local mode = positionConfig.mode
	if positionConfig.modeOption and Addon.Config and Addon.Config.GetOptionValue then
		local draggable = Addon.Config:GetOptionValue(positionConfig.modeOption)
		mode = (draggable == false) and POSITION_MODE.STATIC or POSITION_MODE.DRAGGABLE
	end
	mode = mode or POSITION_MODE.STATIC
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
		-- Centred on the bottom edge, where Blizzard's main bar sits, rather
		-- than stretched between the anchor's top corners: stretching took the
		-- anchor's width over the bar's own (so the Classic width option did
		-- nothing to the frame) and, on Retail, put the bar in the upper slot.
		self:ClearAllPoints()
		self:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 0)
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
	local positions = GetSettingsTable("barPositions", true)

	local captured = CaptureScreenPosition(self)
	if not captured then
		return
	end

	positions[self.__position_key] = captured
end

--- Restore saved position from SavedVariables
function PositionMixin:RestorePosition()
	-- Check if saved position exists
	local positions = GetSettingsTable("barPositions")
	if not positions then
		-- No saved positions, use default
		self:SetDefaultDraggablePosition()
		return
	end

	local savedPos = GetSavedPosition(positions, self.__position_key)
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
		if not defaultPos then
			defaultPos = Addon.defaults.barPositions[NormalizePositionKey(self.__position_key)]
		end
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
	local positions = GetSettingsTable("barPositions")
	if positions then
		positions[self.__position_key] = nil
		local normalized = NormalizePositionKey(self.__position_key)
		if normalized and normalized ~= self.__position_key then
			positions[normalized] = nil
		end
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
		-- Save current STATIC screen position as initial draggable position
		-- (the STATIC anchor is container-relative and must not be replayed
		-- against UIParent)
		local captured = CaptureScreenPosition(self)
		if captured then
			local positions = GetSettingsTable("barPositions", true)
			positions[self.__position_key] = captured
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
