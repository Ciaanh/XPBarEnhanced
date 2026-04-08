-- XP Bar Enhanced - Context Builder
-- Standalone utility module for building immutable context objects

---@class CoreState
---@field currentXP number Current player XP
---@field xpMax number Maximum XP for current level
---@field level number Current player level
---@field restedXP number Amount of rested XP available
---@field isResting boolean Whether player is in a resting area
---@field hasRestedXP boolean Whether player has any rested XP
---@field isFullyRested boolean Whether player has max rested XP

-------------------------------------------------------------------
-- STATIC CONFIGURATION (SHARED)
-------------------------------------------------------------------

---Build fresh static configuration from database
---@return table staticConfig Fresh configuration with current settings
local function BuildDBConfig()
	local db = Addon and Addon.db

	if not db then
		return {}
	end

	local cfg = {}

	local function setIfPresent(key)
		if db[key] ~= nil then
			cfg[key] = db[key]
		end
	end

	-- Display flags
	setIfPresent("showXPText")
	setIfPresent("showLevelText")
	setIfPresent("showPercentage")
	setIfPresent("showQuestXP")
	setIfPresent("showCompleteQuestOverlay")
	setIfPresent("showIncompleteQuestOverlay")
	setIfPresent("showRestedOverlay")
	setIfPresent("showExhaustionTick")
	setIfPresent("showSessionTimeText")
	setIfPresent("showLevelTimeText")
	setIfPresent("showXPPerHourText")
	setIfPresent("showTimeToLevelText")
	setIfPresent("showRemainingXP")
	setIfPresent("showQuestPercent")

	-- Configuration values
	if db.percentDecimals ~= nil then
		cfg.percentDecimals = db.percentDecimals
	end
	setIfPresent("abbreviateNumbers")
	setIfPresent("flashOnGain")

	-- Animation settings
	setIfPresent("enableAnimations")
	setIfPresent("twoPhaseOnLevelUp")

	return cfg
end

-------------------------------------------------------------------
-- GLOBAL CONTEXT BUILDER
-------------------------------------------------------------------

---@class XPBarContextBuilder
XPBarContextBuilder = {}

local ContextBuilder = XPBarContextBuilder
Addon.ContextBuilder = ContextBuilder

-------------------------------------------------------------------
-- INTERNAL HELPERS
-------------------------------------------------------------------

-- Retrieve core player XP/rested/level state
function ContextBuilder.GetCoreState()
	local currentXP = UnitXP("player") or 0
	local xpMax = UnitXPMax("player") or 1
	local level = UnitLevel("player") or 1
	local restedXP = GetXPExhaustion() or 0
	local isResting = IsResting()
	local hasRestedXP = restedXP > 0
	local isFullyRested = restedXP >= (1.5 * xpMax)
	return {
		currentXP = currentXP,
		xpMax = xpMax,
		level = level,
		restedXP = restedXP,
		isResting = isResting,
		hasRestedXP = hasRestedXP,
		isFullyRested = isFullyRested
	}
end

-- Retrieve quest XP breakdown
function ContextBuilder.GetQuestXP()
	local completeQuestXP = 0
	local incompleteQuestXP = 0

	if XPBarEnhanced and XPBarEnhanced.QuestXP and XPBarEnhanced.QuestXP.GetQuestXP then
		local total, complete, incomplete = XPBarEnhanced.QuestXP:GetQuestXP()
		completeQuestXP = complete or 0
		incompleteQuestXP = incomplete or 0
	end

	return completeQuestXP, incompleteQuestXP
end

-------------------------------------------------------------------
-- CONTEXT MANIPULATION HELPERS
-------------------------------------------------------------------

--- Extend an existing context with additional fields
function ContextBuilder.ExtendContext(baseContext, additions)
	local extended = {}

	if baseContext then
		for k, v in pairs(baseContext) do
			extended[k] = v
		end
	end

	if additions then
		for k, v in pairs(additions) do
			extended[k] = v
		end
	end

	return extended
end

--- Make a context immutable and provide a Get() function for safe access
function ContextBuilder.MakeImmutable(eventData, coreData)
	local flatContext = BuildDBConfig()

	if coreData then
		for k, v in pairs(coreData) do
			flatContext[k] = v
		end
	end

	if eventData then
		for k, v in pairs(eventData) do
			flatContext[k] = v
		end
	end

	local wrapper = {
		Get = function(self, key, default)
			local value = flatContext[key]
			if value ~= nil then
				return value
			end
			return default
		end,
		_data = flatContext
	}

	setmetatable(
		wrapper,
		{
			__index = function(t, k)
				return flatContext[k]
			end,
			__newindex = function(t, k, v)
				error(string.format("Attempt to modify immutable context field '%s'", tostring(k)), 2)
			end,
			__metatable = false
		}
	)

	return wrapper
end

-- Compute XP gained since last snapshot (handles level-up wrap-around)
function ContextBuilder.ComputeXPGained(currentXP, xpMax)
	local lastXP = ContextBuilder._lastXP or currentXP
	local lastMax = ContextBuilder._lastMaxXP or xpMax

	local XPCalc = XPBarEnhanced.XPCalculations
	local xpGained, didLevelUp = XPCalc.ComputeGain(currentXP, xpMax, lastXP, lastMax)

	local preLevelXP = lastXP
	local preLevelMax = lastMax

	ContextBuilder._lastXP = currentXP
	ContextBuilder._lastMaxXP = xpMax

	return xpGained, preLevelXP, preLevelMax, didLevelUp
end

-- Update session tracking with a gain and return session snapshot
function ContextBuilder.UpdateSessionWithGain(xpGained)
	local sessionStart = time()
	local sessionXP = 0
	local realLevelTime = 0

	if Addon and Addon.Session then
		local session = Addon.Session:GetCurrent()
		if session then
			if session.sessionStart then
				sessionStart = session.sessionStart
			end
			if session.gainedXP then
				sessionXP = session.gainedXP
			end
			if session.realLevelTime then
				realLevelTime = session.realLevelTime
				if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
					local elapsed = time() - session.lastTimePlayedRequest
					realLevelTime = realLevelTime + elapsed
				end
			end
		end
	end

	local sessionDuration = time() - sessionStart
	local currentXP = UnitXP("player") or 0
	local xpPerHour = ContextBuilder.CalculateXPPerHour(sessionStart, sessionXP, realLevelTime, currentXP)

	return sessionStart, sessionXP, sessionDuration, xpPerHour
end

--- Build minimal core context with only dynamic game state
function ContextBuilder.BuildCoreContext(coreState)
	local completeQuestXP, incompleteQuestXP = ContextBuilder.GetQuestXP()

	local sessionStart = time()
	local sessionXP = 0
	local levelSeconds = 0
	local questXPGained = 0
	local otherXP = 0
	local recentXPPerHour = 0

	if Addon and Addon.Session then
		local session = Addon.Session:GetCurrent()
		if session then
			if session.sessionStart then
				sessionStart = session.sessionStart
			end
			if session.gainedXP then
				sessionXP = session.gainedXP
			end
			if session.realLevelTime and session.realLevelTime > 0 then
				levelSeconds = session.realLevelTime
				if session.lastTimePlayedRequest and session.lastTimePlayedRequest > 0 then
					local elapsed = time() - session.lastTimePlayedRequest
					levelSeconds = levelSeconds + elapsed
				end
			end
			questXPGained = session.questXP or 0
			otherXP       = session.otherXP  or 0
		end
		if Addon.Session.GetRecentXPPerHour then
			recentXPPerHour = Addon.Session:GetRecentXPPerHour()
		end
	end

	return {
		currentXP = coreState.currentXP,
		xpMax = coreState.xpMax,
		level = coreState.level,
		restedXP = coreState.restedXP,
		isResting = coreState.isResting,
		hasRestedXP = coreState.hasRestedXP,
		isFullyRested = coreState.isFullyRested,
		completeQuestXP = completeQuestXP,
		incompleteQuestXP = incompleteQuestXP,
		sessionStart = sessionStart,
		sessionXP = sessionXP,
		levelSeconds = levelSeconds,
		questXPGained   = questXPGained,
		otherXP         = otherXP,
		recentXPPerHour = recentXPPerHour,
	}
end

-------------------------------------------------------------------
-- CONTEXT BUILDING
-------------------------------------------------------------------

-- Events that should consume (advance) the XP delta tracker.
-- EventBus broadcasts ("XPBAR:BROADCAST_UPDATE") are the primary delivery
-- path when Session drives all XP events, so they must also consume the delta.
local XP_CONSUMING_EVENTS = {
	["PLAYER_XP_UPDATE"] = true,
	["PLAYER_LEVEL_UP"] = true,
	["PLAYER_ENTERING_WORLD"] = true,
	["XPBAR:BROADCAST_UPDATE"] = true,
}

function XPBarContextBuilder.BuildContext(event, ...)
	local args = {...}
	local coreState = ContextBuilder.GetCoreState()
	local coreContext = ContextBuilder.BuildCoreContext(coreState)

	local shouldConsumeXP = XP_CONSUMING_EVENTS[event] == true

	local xpGained, preLevelXP, preLevelMax, didLevelUp
	if shouldConsumeXP then
		xpGained, preLevelXP, preLevelMax, didLevelUp = ContextBuilder.ComputeXPGained(coreState.currentXP, coreState.xpMax)
	else
		xpGained = 0
		preLevelXP = ContextBuilder._lastXP or coreState.currentXP
		preLevelMax = ContextBuilder._lastMaxXP or coreState.xpMax
		didLevelUp = false
	end

	local sessionStart, sessionXP, sessionDuration, xpPerHour = ContextBuilder.UpdateSessionWithGain(xpGained)

	local hasGainedXP = (xpGained and xpGained > 0) or false

	local eventContext = {
		event = event,
		timestamp = time(),
		source = tostring(event or "UNKNOWN"),
		xpBefore = preLevelXP or 0,
		xpAfter = coreState.currentXP,
		xpGained = xpGained or 0,
		preLevelCurrentXP = preLevelXP or 0,
		preLevelXPMax = preLevelMax or coreState.xpMax or 1,
		sessionStart = sessionStart or time(),
		sessionXP = sessionXP or 0,
		sessionDuration = sessionDuration or 0,
		sessionSeconds = sessionDuration or 0,
		xpPerHour = xpPerHour or 0,
		timeToLevel = ContextBuilder.CalculateTimeToLevel(coreState.currentXP, coreState.xpMax, xpPerHour or 0),
		previousLevel = didLevelUp and (coreState.level - 1) or nil,
		level = coreState.level,
		hasGainedXP = hasGainedXP,
		hasLeveledUp = didLevelUp,
		shouldAnimate = hasGainedXP or didLevelUp,
		shouldFlash = hasGainedXP or didLevelUp,
		restedChanged = false,
		questsChanged = false
	}

	-- Apply special handling per event
	if event == "PLAYER_XP_UPDATE" then
		eventContext.source = "PLAYER_XP_UPDATE"
	elseif event == "PLAYER_LEVEL_UP" then
		eventContext.source = "PLAYER_LEVEL_UP"
		local level = args[1] or coreState.level
		eventContext.level = level
		eventContext.previousLevel = (level and level - 1) or (coreState.level and coreState.level - 1)
		-- Allow level-up animation flags to propagate from ComputeXPGained() above.
		-- Only set hasLeveledUp/shouldAnimate if ComputeXPGained did not already detect it
		-- (handles the case where PLAYER_LEVEL_UP fires before PLAYER_XP_UPDATE).
		if not eventContext.hasLeveledUp then
			eventContext.hasLeveledUp = true
		end
		if not eventContext.shouldAnimate then
			eventContext.shouldAnimate = true
		end
		if not eventContext.shouldFlash then
			eventContext.shouldFlash = true
		end
	elseif event == "UPDATE_EXHAUSTION" or event == "PLAYER_UPDATE_RESTING" then
		eventContext.source = "RESTED_UPDATE"
		eventContext.hasGainedXP = false
		eventContext.hasLeveledUp = false
		eventContext.shouldAnimate = false
		eventContext.shouldFlash = false
		eventContext.restedChanged = true
	elseif event == "QUEST_LOG_UPDATE" then
		eventContext.source = "QUEST_UPDATE"
		eventContext.hasGainedXP = false
		eventContext.hasLeveledUp = false
		eventContext.shouldAnimate = false
		eventContext.shouldFlash = false
		eventContext.questsChanged = true
	elseif event == "TOOLTIP" then
		eventContext.source = "TOOLTIP_CONTEXT"
		eventContext.hasGainedXP = false
		eventContext.hasLeveledUp = false
		eventContext.shouldAnimate = false
		eventContext.shouldFlash = false
	end

	return ContextBuilder.MakeImmutable(eventContext, coreContext)
end

-------------------------------------------------------------------
-- SESSION CALCULATION METHODS
-------------------------------------------------------------------

function ContextBuilder.CalculateXPPerHour(sessionStart, sessionXP, realLevelTime, currentXP)
	local TimeCalc = XPBarEnhanced.TimeCalculations
	return TimeCalc.CalculateXPPerHour(sessionStart, sessionXP, realLevelTime, currentXP)
end

function ContextBuilder.CalculateTimeToLevel(currentXP, maxXP, xpPerHour)
	local TimeCalc = XPBarEnhanced.TimeCalculations
	return TimeCalc.TimeToLevelFromXP(currentXP, maxXP, xpPerHour) or 0
end

-------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------

function ContextBuilder.Initialize()
	-- UnitXP may return nil/0 before PLAYER_LOGIN fires; keep _lastXP nil in that
	-- case so ComputeXPGained defaults it to currentXP (zero gain on first event).
	local xp = UnitXP("player")
	if xp and xp > 0 then
		ContextBuilder._lastXP = xp
		ContextBuilder._lastMaxXP = UnitXPMax("player") or 1
	end
end

function ContextBuilder.ResetSession()
	ContextBuilder._lastXP = UnitXP("player") or 0
	ContextBuilder._lastMaxXP = UnitXPMax("player") or 1
end

-------------------------------------------------------------------
-- SECONDARY BAR CONTEXTS
-------------------------------------------------------------------

--- Build a context for the watched reputation bar.
--- Returns a simple table (not immutable) for direct use by secondary bar styles.
---@return table context Reputation context, isAvailable=false if no watched faction
function XPBarContextBuilder.BuildReputationContext()
	if not (Addon and Addon.ReputationSession) then
		return { isAvailable = false }
	end

	local repSession = Addon.ReputationSession
	local info = repSession:GetWatchedFactionInfo()

	if not info then
		return { isAvailable = false }
	end

	local stats = repSession:GetStats()
	local panel = rawget(_G, "XPBarEnhancedOptionsPanel")
	local isPreviewMode = (Addon.db and Addon.db.barLocked == false) or (panel and panel.IsVisible and panel:IsVisible())
	local hideCompanionOutsideDelve = Addon.db and Addon.db.hideCompanionOutsideDelve
	local isCompanionAvailable
	if hideCompanionOutsideDelve then
		isCompanionAvailable = not info.isCompanion or (info.isInDelve and not info.isMaxed)
	else
		isCompanionAvailable = not info.isCompanion or isPreviewMode or (info.isInDelve and not info.isMaxed)
	end

	if not isCompanionAvailable then
		return {
			isAvailable = false,
			isCompanion = true,
			name = info.name or "",
		}
	end

	return {
		isAvailable        = true,
		name               = info.name or "",
		standingLabel      = info.standingLabel or "",
		factionType        = info.factionType or "standard",
		isCompanion        = info.isCompanion or false,
		isInDelve          = info.isInDelve or false,
		currentLevel       = info.currentLevel or 0,
		maxLevel           = info.maxLevel or 0,
		current            = info.current or 0,
		min                = info.min or 0,
		max                = math.max(1, info.max or 1),
		ratio              = info.ratio or 0,
		percent            = info.percent or 0,
		isMaxed            = info.isMaxed or false,
		sessionGained      = info.sessionGained or 0,
		repPerHour         = (stats and stats.repPerHour) or 0,
		timeToNextStanding = stats and stats.timeToNextStanding,
		timeToNextLevel    = stats and stats.timeToNextStanding,
	}
end

ContextBuilder.Initialize()

return ContextBuilder
