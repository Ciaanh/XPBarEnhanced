-- XP Bar Enhanced - Event Bus
-- Central event bus with a simple register/emit/unregister API

---@class XPBarContext
---@field event string The event that triggered this context
---@field timestamp number Unix timestamp when context was built
---@field source? string Source identifier for the event
---@field currentXP number Current player XP
---@field xpMax number Maximum XP for current level
---@field remainingXP? number XP remaining to next level
---@field level number Current player level
---@field restedXP number Amount of rested XP available
---@field isResting boolean Whether player is in a resting area
---@field hasRestedXP boolean Whether player has any rested XP
---@field isFullyRested boolean Whether player has max rested XP
---@field completeQuestXP? number XP from completed quests ready to turn in
---@field incompleteQuestXP? number XP from incomplete quests
---@field sessionStart? number Session start timestamp
---@field sessionXP? number Total XP gained this session
---@field levelSeconds? number Time played at current level
---@field xpGained? number XP gained in this event
---@field didLevelUp? boolean Whether player leveled up
---@field Get fun(self: XPBarContext, key: string, default?: any): any Safe getter with default value

---@alias EventHandler fun(context: XPBarContext): nil

---@class EventBusHandle
---@field Unregister fun() Unregister this subscription

---@class EventBus
---@field listeners table<string, table<string, EventHandler>> Registered event handlers keyed by event name and subscription id
---@field _executingEvents table<string, number> Re-entrancy depth counters per event
---@field _deferredRegistrations table<string, table<string, EventHandler>> Registrations deferred during dispatch
local Addon = XPBarEnhanced
Addon.EventBus = Addon.EventBus or {}
local EventBus = Addon.EventBus

EventBus.listeners = EventBus.listeners or {}
EventBus._executingEvents = EventBus._executingEvents or {}
EventBus._deferredRegistrations = EventBus._deferredRegistrations or {}

-- Route errors through Blizzard's error handler when available, fall back to print
local function SafeCallErrorHandler(err)
    if CallErrorHandler then
        CallErrorHandler(err)
    else
        print(tostring(err))
    end
end

---Register a handler for an event
---@param eventName string The event name to listen for
---@param idOrHandler string|EventHandler Subscription ID (string) or handler function
---@param handler? EventHandler Handler function (required if idOrHandler is a string)
---@return string id The subscription ID for later unregistration
function EventBus:Register(eventName, idOrHandler, handler)
    if not eventName then
        error("EventBus:Register requires an eventName")
    end
    local id
    local fn
    if type(idOrHandler) == "string" then
        id = idOrHandler
        fn = handler
    else
        fn = idOrHandler
    end
    if type(fn) ~= "function" then
        error("EventBus:Register requires a function handler")
    end
    id = id or tostring(fn)
    -- If currently dispatching this event, defer registration to avoid iterator invalidation
    if self._executingEvents[eventName] and self._executingEvents[eventName] > 0 then
        self._deferredRegistrations[eventName] = self._deferredRegistrations[eventName] or {}
        self._deferredRegistrations[eventName][id] = fn
        return id
    end
    EventBus.listeners[eventName] = EventBus.listeners[eventName] or {}
    EventBus.listeners[eventName][id] = fn
    return id
end

---Register a handler and return a handle that can unregister it
---@param eventName string The event name to listen for
---@param idOrHandler string|EventHandler Subscription ID or handler function
---@param handler? EventHandler Handler function
---@return EventBusHandle handle Object with Unregister() method
function EventBus:RegisterWithHandle(eventName, idOrHandler, handler)
    local id = self:Register(eventName, idOrHandler, handler)
    return {
        Unregister = function()
            EventBus:Unregister(eventName, id)
        end
    }
end

---Unregister a handler by id or function for an event
---@param eventName string The event name to unregister from
---@param idOrHandler string|EventHandler The subscription ID or handler function to remove
function EventBus:Unregister(eventName, idOrHandler)
    if not eventName or not EventBus.listeners[eventName] then
        return
    end
    if type(idOrHandler) == "string" then
        EventBus.listeners[eventName][idOrHandler] = nil
        return
    end
    for id, fn in pairs(EventBus.listeners[eventName]) do
        if fn == idOrHandler then
            EventBus.listeners[eventName][id] = nil
        end
    end
end

---Emit an event to all listeners
---@param eventName string The event name to emit
---@return XPBarContext context The context object passed to all handlers
function EventBus:Emit(eventName)
    -- Build a fresh immutable context
    local context = nil
    if XPBarContextBuilder and XPBarContextBuilder.BuildContext then
        local reason = eventName or "BROADCAST_UPDATE"
        context = XPBarContextBuilder.BuildContext(reason)
    end

    if context == nil then
        error("EventBus:Emit requires a valid context")
    end

    local listenersForEvent = self.listeners and self.listeners[eventName]
    if not listenersForEvent then
        return context
    end

    -- Increment re-entrancy depth so Register() knows to defer new subscriptions
    self._executingEvents[eventName] = (self._executingEvents[eventName] or 0) + 1

    for id, handler in pairs(listenersForEvent) do
        xpcall(handler, SafeCallErrorHandler, context)
    end

    self._executingEvents[eventName] = self._executingEvents[eventName] - 1

    -- Apply any registrations that were deferred during dispatch
    if self._executingEvents[eventName] == 0 then
        self._executingEvents[eventName] = nil
        local deferred = self._deferredRegistrations[eventName]
        if deferred then
            self._deferredRegistrations[eventName] = nil
            EventBus.listeners[eventName] = EventBus.listeners[eventName] or {}
            for id, fn in pairs(deferred) do
                EventBus.listeners[eventName][id] = fn
            end
        end
    end

    return context
end

return EventBus
