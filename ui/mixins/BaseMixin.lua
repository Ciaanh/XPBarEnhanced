-- XP Bar Enhanced - Base Mixin
-- Core functionality: event orchestration, Trigger/Action methods, overlay actions
-- Uses ContextBuilder for immutable contexts (no Session dependency)

-------------------------------------------------------------------
-- GLOBAL BASE MIXIN
-------------------------------------------------------------------

---@class XPBarMixinBase
XPBarMixinBase = {}

local BaseMixin = XPBarMixinBase

local Addon = XPBarEnhanced
Addon.UI.Mixins.Base = XPBarMixinBase

local EventNames = Addon.EventNames
local Utils = Addon.Utils

-------------------------------------------------------------------
-- PUBLIC API SURFACE
-------------------------------------------------------------------

--- Refresh bar state from game data ( unified pattern)
function BaseMixin:Refresh()
	-- Check if ContextBuilder exists
	if not XPBarContextBuilder then
		error("XPBarContextBuilder not loaded")
	end

	local context = XPBarContextBuilder.BuildContext("MANUAL_REFRESH")
	self:TriggerBarRefresh(context)
end

--- Full update - Called by XPBar controller for option/color changes
--- This provides V1 compatibility for live refresh features
--- @param context table Optional pre-built context (if provided by broadcaster)
function BaseMixin:FullUpdate(context)
	-- Prevent re-entrant calls
	if self._isUpdating then
		return
	end
	self._isUpdating = true

	-- Use provided context or build fresh one
	if not context then
		context = XPBarContextBuilder.BuildContext("FULL_UPDATE")
	end

	-- Use unified render pattern
	self:TriggerBarRefresh(context)

	-- Update text visibility in case options changed
	self:UpdateTextVisibility(context)

	self._isUpdating = nil
end

-------------------------------------------------------------------
-- LIFECYCLE METHODS
-------------------------------------------------------------------

--- OnLoad - One-time frame initialization (wiring and visuals only).
--- WoW event registration and EventBus subscriptions are deferred to OnShow
--- so hidden bars perform no event processing (mirrors Blizzard's pattern).
function BaseMixin:OnLoad()
	-- Initialize internal config
	self.__xpbar_config = self.__xpbar_config or {}

	-- Initialize animation system (from AnimationBase mixin)
	if self.InitializeAnimation then
		self:InitializeAnimation()
	end

	-- Initialize position behavior (if present)
	if self.InitializePosition then
		self:InitializePosition()
	end

	-- Wire up mouse event handlers (InteractionMixin)
	if self.OnMouseDown then
		self:SetScript("OnMouseDown", function(frame, button)
			frame:OnMouseDown(button)
		end)
	end

	if self.OnMouseUp then
		self:SetScript("OnMouseUp", function(frame, button)
			frame:OnMouseUp(button)
		end)
	end

	-- Call BuildVisuals if style provides it
	if self.BuildVisuals then
		self:BuildVisuals()
	end

	-- Apply style config if provided
	if self.ApplyStyle and self.__xpbar_config.style then
		self:ApplyStyle(self.__xpbar_config.style)
	end

	assert(self.Refresh, "XPBarMixinBase: Refresh method missing on style frame")
end

--- OnShow - Register WoW events, EventBus subscriptions, and start ticker.
--- Mirrors Blizzard's AzeriteBarMixin.OnShow pattern: events registered only
--- while the frame is visible so hidden bars do no unnecessary work.
function BaseMixin:OnShow()
	-- Only CVAR_UPDATE is needed directly; all other events come through EventBus
	self:RegisterCommonEvents()

	-- Subscribe to EventBus using handles so OnHide can cleanly unregister
	if Addon.EventBus and Addon.EventBus.RegisterWithHandle then
		local self_ref = self
		self.__observer_handle = Addon.EventBus:RegisterWithHandle(
			EventNames.XPBAR_BROADCAST_UPDATE,
			function(ctx)
				if self_ref then self_ref:MarkDirty(ctx) end
			end
		)
		self.__config_observer_handle = Addon.EventBus:RegisterWithHandle(
			EventNames.CONFIG_UPDATED,
			function(ctx)
				if self_ref then self_ref:MarkDirty(ctx) end
			end
		)
	end

	-- (Re-)start periodic text ticker: session time, XP/hour, time-to-level
	-- Uses a lightweight context (only time-dependent fields) to avoid
	-- full API queries every 2.5 seconds.
	if self._textRefreshTicker then
		self._textRefreshTicker:Cancel()
	end
	self._textRefreshTicker = C_Timer.NewTicker(2.5, function()
		if self and self:IsShown() and self:HasCapability("textBelowBar") then
			local context
			if XPBarContextBuilder and XPBarContextBuilder.BuildTextRefreshContext then
				context = XPBarContextBuilder.BuildTextRefreshContext("TEXT_TICK")
			else
				context = XPBarContextBuilder.BuildContext("MANUAL_REFRESH")
			end
			if self.UpdateSessionText then self:UpdateSessionText(context) end
			if self.UpdateRateText then self:UpdateRateText(context) end
		end
	end)

	-- Initial render after registering subscriptions
	self:Refresh()
end

--- Schedule a deferred render, coalescing rapid-fire events into one frame.
--- Always prefers the most recent animatable context so the bar position and
--- XP gained values reflect the latest game state when the frame callback runs.
---@param context? table Optional pre-built context from EventBus
function BaseMixin:MarkDirty(context)
	-- Always prefer the most recent should-animate context for up-to-date XP state;
	-- only fall back to keeping an earlier context if nothing is pending yet.
	if context and context.shouldAnimate then
		self._pendingContext = context
	elseif not self._pendingContext then
		self._pendingContext = context
	end

	if not self._dirty then
		self._dirty = true
		local self_ref = self
		local runFn = RunNextFrame or function(fn) C_Timer.After(0, fn) end
		runFn(function()
			local ctx = self_ref._pendingContext
			self_ref._dirty = nil
			self_ref._pendingContext = nil
			if self_ref and self_ref:IsShown() then
				if ctx then
					xpcall(self_ref.TriggerBarRefresh, Utils.ReportError, self_ref, ctx)
				else
					xpcall(self_ref.Refresh, Utils.ReportError, self_ref)
				end
			end
		end)
	end
end

--- OnHide - Unregister all event and EventBus subscriptions; clean up state.
--- Mirrors Blizzard's AzeriteBarMixin.OnHide: no processing while invisible.
function BaseMixin:OnHide()
	-- Unregister WoW events + release EventBus handles
	self:UnsubscribeFromEvents()

	-- Cancel periodic text refresh ticker
	if self._textRefreshTicker then
		self._textRefreshTicker:Cancel()
		self._textRefreshTicker = nil
	end

	-- Cleanup animation state (from AnimationBase mixin)
	if self.CleanupAnimation then
		self:CleanupAnimation()
	end
end

-------------------------------------------------------------------
-- EVENT REGISTRATION
-------------------------------------------------------------------

--- Register WoW events that bars handle directly.
--- All XP/rested/level/quest events are dispatched by Session via EventBus;
--- only CVAR_UPDATE is wired directly for the Blizzard xpBarText CVar toggle.
function BaseMixin:RegisterCommonEvents()
	self:RegisterEvent("CVAR_UPDATE")
end

function BaseMixin:UnsubscribeFromEvents()
	-- Unregister the single directly-registered WoW event
	self:UnregisterEvent("CVAR_UPDATE")

	-- Release EventBus handles (RegisterWithHandle pattern)
	if self.__observer_handle then
		self.__observer_handle:Unregister()
		self.__observer_handle = nil
	end
	if self.__config_observer_handle then
		self.__config_observer_handle:Unregister()
		self.__config_observer_handle = nil
	end
end

-------------------------------------------------------------------
-- EVENT ORCHESTRATION (Trigger/Action Pattern)
-------------------------------------------------------------------

--- Event dispatcher. Only CVAR_UPDATE is registered directly on bars;
--- all XP/rested/level/quest events arrive via EventBus (from Session).
---@param event string Event name
---@param ... any Event arguments
function BaseMixin:OnEvent(event, ...)
	if event == "CVAR_UPDATE" then
		local cvarName = ...
		if cvarName == "xpBarText" then
			local context = XPBarContextBuilder.BuildContext("CVAR_UPDATE")
			if self.UpdateTextVisibility then
				self:UpdateTextVisibility(context)
			end
		end
	end
end

-------------------------------------------------------------------
-- TRIGGER METHODS (Orchestrate Actions - NOT overridable)
-------------------------------------------------------------------

-------------------------------------------------------------------
--  UNIFIED RENDER PATTERN
-------------------------------------------------------------------

function BaseMixin:CalculateTargetRatio(context)
	if not context then
		error("BaseMixin:CalculateTargetRatio called with nil context")
	end

	local targetRatio = 0
	if context.xpMax and context.xpMax > 0 then
		targetRatio = (context.currentXP or 0) / context.xpMax
	end
	return targetRatio
end

--- Check capability flag (declared in style DefaultConfig.capabilities)
---@param cap string Capability key from XPBarStyleBuilder.Capabilities
---@return boolean
function BaseMixin:HasCapability(cap)
	local caps = self.__xpbar_capabilities
	if not caps then return true end -- default to true if capabilities not declared
	return caps[cap] ~= false
end

local FORCE_RENDER_EVENTS = {
	["FULL_UPDATE"]             = true,
	["XPBAR:BROADCAST_UPDATE"]  = true,
	["MANUAL_REFRESH"]          = true,
	["OPTIONS_CHANGED"]         = true,
	["CVAR_UPDATE"]             = true,
}

--- Determine if this event should force a full render.
---@param event string|nil Event name from context
---@return boolean
local function ShouldForceRender(event)
	return FORCE_RENDER_EVENTS[event] == true
end

--- Update overlays (rested, quest, exhaustion tick) if style supports them
---@param context table Immutable context
function BaseMixin:UpdateOverlays(context)
	if not self:HasCapability("overlays") then return end

	if self.UpdateRestedBar then
		self:UpdateRestedBar(context)
	end
	if self.UpdateQuestCompleteBar then
		self:UpdateQuestCompleteBar(context)
	end
	if self.UpdateQuestIncompleteBar then
		self:UpdateQuestIncompleteBar(context)
	end
	if self:HasCapability("exhaustionTick") and self.UpdateExhaustionTick then
		self:UpdateExhaustionTick(context)
	end
end

--- Update all text elements if style supports them
---@param context table Immutable context
function BaseMixin:UpdateAllText(context)
	if self.UpdateTextVisibility then
		self:UpdateTextVisibility(context)
	end
	if self:HasCapability("textOnBar") then
		if self.UpdateXPText then self:UpdateXPText(context) end
		if self.UpdatePercentText then self:UpdatePercentText(context) end
		if self.UpdateLevelText then self:UpdateLevelText(context) end
	end
	if self:HasCapability("textBelowBar") then
		if self.UpdateSessionText then self:UpdateSessionText(context) end
		if self.UpdateRateText then self:UpdateRateText(context) end
	end
end

--- Handle partial update path (no XP change, only overlays/text)
---@param context table Immutable context
function BaseMixin:HandlePartialUpdate(context)
	if context.restedChanged then
		self:UpdateOverlays(context)
	end
	if context.questsChanged and self:HasCapability("overlays") then
		if self.UpdateQuestCompleteBar then self:UpdateQuestCompleteBar(context) end
		if self.UpdateQuestIncompleteBar then self:UpdateQuestIncompleteBar(context) end
	end
	self:UpdateAllText(context)
end

--- Handle animated update path
---@param context table Immutable context
function BaseMixin:HandleAnimatedUpdate(context)
	local targetRatio = self:CalculateTargetRatio(context)
	local config = {
		enableAnimations   = context.enableAnimations ~= false and true,
		flashOnGain        = context.flashOnGain ~= false and true,
		twoPhaseOnLevelUp  = context.twoPhaseOnLevelUp ~= false and true,
	}

	-- Update overlays before animation to avoid stale visuals
	self:UpdateOverlays(context)

	self:StartAnimation(targetRatio, context, config)
end

--- Handle immediate (non-animated) render path
---@param context table Immutable context
---@param forceRender boolean Whether to interrupt running animations
function BaseMixin:HandleImmediateUpdate(context, forceRender)
	if self.animation and self.animation.isAnimating and forceRender then
		if self.CleanupAnimation then
			self:CleanupAnimation()
		end
		if self.animation then
			self.animation.isAnimating = false
		end
	end

	if not (self.animation and self.animation.isAnimating) then
		self:RenderBar(context)
	end
end

--- Single entry point for all bar updates
--- Orchestrates animation vs immediate render based on context
---@param context table Immutable context from ContextBuilder with event flags
function BaseMixin:TriggerBarRefresh(context)
	if not context then
		error("TriggerBarRefresh requires an explicit immutable context")
	end
	if not self.RenderBar then
		error("Style must implement RenderBar(context) method")
	end

	local Addon = XPBarEnhanced
	local manager = Addon and Addon.BarManager

	-- Let BarManager hide the bar at max level.
	if manager and manager.AdjustContextForMaxLevel then
		context = manager:AdjustContextForMaxLevel(context)
		if not context then
			if manager.GetCurrentFrame and manager:GetCurrentFrame() == self and manager.SetStyle then
				manager:SetStyle("none")
			else
				if self.CleanupAnimation then
					self:CleanupAnimation()
				end
				self:Hide()
			end
			return
		end
	end

	-- Non-max-level guard: if context cannot represent progress, hide safely.
	if context.xpMax ~= nil and context.xpMax <= 0 then
		if manager and manager.GetCurrentFrame and manager:GetCurrentFrame() == self and manager.SetStyle then
			manager:SetStyle("none")
		else
			if self.CleanupAnimation then
				self:CleanupAnimation()
			end
			self:Hide()
		end
		return
	end

	local ev = context.event
	local forceRender = ShouldForceRender(ev)

	-- Short-circuit: no-change PLAYER_XP_UPDATE → update only overlays and text
	if ev == "PLAYER_XP_UPDATE" and not forceRender and not context.hasGainedXP and not context.hasLeveledUp then
		self:HandlePartialUpdate(context)
		return
	end

	-- Decide between animation vs immediate render
	if context.shouldAnimate and self.StartAnimation then
		self:HandleAnimatedUpdate(context)
	else
		self:HandleImmediateUpdate(context, forceRender)
	end
end

-------------------------------------------------------------------
-- ABSTRACT METHODS
-- Styles must override RenderBar. Other methods have default
-- implementations from behavior mixins but are listed here
-- for documentation (following Blizzard's StatusTrackingBarMixin
-- pattern of error-throwing abstract methods).
-------------------------------------------------------------------

--- Override this in your style: render all visuals from context.
function BaseMixin:RenderBar(context)
	error("Style must implement RenderBar(context)")
end

--- Default level-up celebration: brief flash of the frame using UIFrameFlash.
--- Individual styles may override this for style-specific effects.
function BaseMixin:OnLevelUpCelebration()
	if UIFrameFlash then
		-- showWhenDone=true: keep the frame visible after the flash completes.
		-- (false would call frame:Hide() at end of animation, hiding the bar.)
		UIFrameFlash(self, 0.15, 0.15, 0.6, true, 0.1, 0)
	end
end

return BaseMixin
