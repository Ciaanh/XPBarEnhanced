-- XP Bar Enhanced - Base Mixin
-- Core functionality: event orchestration, Trigger/Action methods, overlay actions
-- Uses ContextBuilder for immutable contexts (no Session dependency)

-------------------------------------------------------------------
-- GLOBAL BASE MIXIN
-------------------------------------------------------------------

---@class XPBarMixinBase
XPBarMixinBase = {}

local BaseMixin = XPBarMixinBase

-- Reference to addon for Logger access
local Addon = XPBarEnhanced
local EventNames = Addon.EventNames

-- Route errors through Blizzard's handler when available
local function SafeCallErrorHandler(err)
	if CallErrorHandler then
		CallErrorHandler(err)
	else
		print(tostring(err))
	end
end

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
	if self._textRefreshTicker then
		self._textRefreshTicker:Cancel()
	end
	self._textRefreshTicker = C_Timer.NewTicker(2.5, function()
		if self and self:IsShown() then
			local context = XPBarContextBuilder.BuildContext("MANUAL_REFRESH")
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
					xpcall(self_ref.TriggerBarRefresh, SafeCallErrorHandler, self_ref, ctx)
				else
					xpcall(self_ref.Refresh, SafeCallErrorHandler, self_ref)
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
	if context and context.xpMax and context.xpMax > 0 then
		targetRatio = (context.currentXP or 0) / context.xpMax
	end
	return targetRatio
end

--- Single entry point for all bar updates (NEW unified pattern)
--- Orchestrates animation vs immediate render based on context
---@param context table Immutable context from ContextBuilder with event flags
function BaseMixin:TriggerBarRefresh(context)
	-- Explicit context required
	if not context then
		error("TriggerBarRefresh requires an explicit immutable context")
	end

	-- Validate required methods
	if not self.RenderBar then
		error("Style must implement RenderBar(context) method")
	end

	-- Check if player reached max level and hide bar
	local Addon = XPBarEnhanced
	if Addon.Utils and Addon.Utils.IsPlayerAtMaxLevel and Addon.Utils.IsPlayerAtMaxLevel() then
		self:Hide()
		return
	end

	local ev = context and context.event

	-- determine if this update should force render
	local forceRender = false
	if ev == "FULL_UPDATE" or ev == "XPBAR:BROADCAST_UPDATE" or ev == "MANUAL_REFRESH" or ev == "OPTIONS_CHANGED" or ev == "CVAR_UPDATE" then
		forceRender = true
	end

	-- Short-circuit: ignore pure no-change PLAYER_XP_UPDATE (avoid snapping / redundant renders)
	if ev == "PLAYER_XP_UPDATE" and not forceRender and not context.hasGainedXP and not context.hasLeveledUp then
		-- Update only overlays and text; do not call RenderBar or affect animation state
		if context.restedChanged and self.UpdateRestedBar then
			self:UpdateRestedBar(context)
		end
		if context.questsChanged and self.UpdateQuestCompleteBar then
			self:UpdateQuestCompleteBar(context)
		end
		if context.questsChanged and self.UpdateQuestIncompleteBar then
			self:UpdateQuestIncompleteBar(context)
		end
		if context.restedChanged and self.UpdateExhaustionTick then
			self:UpdateExhaustionTick(context)
		end

		if self.UpdateTextVisibility then
			self:UpdateTextVisibility(context)
		end
		if self.UpdateSessionText then
			self:UpdateSessionText(context)
		end
		if self.UpdateRateText then
			self:UpdateRateText(context)
		end
		if self.UpdateXPText then
			self:UpdateXPText(context)
		end
		if self.UpdatePercentText then
			self:UpdatePercentText(context)
		end
		if self.UpdateLevelText then
			self:UpdateLevelText(context)
		end

		return
	end

	-- ORCHESTRATION: Decide between animation vs immediate render
	if context.shouldAnimate and self.StartAnimation then
		-- Animated update path
		local targetRatio = self:CalculateTargetRatio(context)

		-- Build config from context (populated via BuildDBConfig in ContextBuilder)
		-- Context is the source of truth for all settings
		local config = {
			enableAnimations = context.enableAnimations,
			flashOnGain = context.flashOnGain,
			twoPhaseOnLevelUp = context.twoPhaseOnLevelUp
		}

		-- Apply defaults only if not explicitly set in context
		if config.enableAnimations == nil then
			config.enableAnimations = true
		end
		if config.flashOnGain == nil then
			config.flashOnGain = true
		end
		if config.twoPhaseOnLevelUp == nil then
			config.twoPhaseOnLevelUp = true
		end

		-- Before starting animation, update overlays (if present)
		-- This mirrors the non-animated RenderBar flow
		-- and avoids stale visuals during animation.
		if self.UpdateRestedBar then
			self:UpdateRestedBar(context)
		end
		if self.UpdateQuestCompleteBar then
			self:UpdateQuestCompleteBar(context)
		end
		if self.UpdateQuestIncompleteBar then
			self:UpdateQuestIncompleteBar(context)
		end
		if self.UpdateExhaustionTick then
			self:UpdateExhaustionTick(context)
		end

		-- Start animation - AnimationManager will call AnimateBarPosition on each tick
		self:StartAnimation(targetRatio, context, config)
	else
		-- Immediate render path.
		-- If an animation is currently running, a forced update (full/broadcast/manual)
		-- will stop it and render immediately.
		if self.animation and self.animation.isAnimating and forceRender then
			-- If the style provides a cleanup hook, call it to stop animations
			if self.CleanupAnimation then
				self:CleanupAnimation()
			end
			-- Ensure animation flag cleared
			if self.animation then
				self.animation.isAnimating = false
			end
		end

		if not (self.animation and self.animation.isAnimating) then
			self:RenderBar(context)
		end
	end
end

-------------------------------------------------------------------
-- ACTION METHODS
-- Visual methods provided by XPBarTextMixin (injected in OnLoad)
-- Styles can override these methods - injection only fills missing methods
-------------------------------------------------------------------

-- UpdateTextVisibility, UpdateTexts, UpdateXPText, UpdatePercentText,
-- UpdateLevelText, UpdateRateText, UpdateSessionText, UpdateQuestSummaryText
-- → Provided by XPBarTextMixin

-------------------------------------------------------------------
-- ABSTRACT VISUAL METHODS (END) - now in mixins
-------------------------------------------------------------------

return BaseMixin
