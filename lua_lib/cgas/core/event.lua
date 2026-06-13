--- Queued Event Bus with deferred dispatch and error isolation.
--- Events are queued when emitted and dispatched on the next call to dispatch().
--- Listeners are isolated via pcall so one failing listener does not break others.

local M = {}

---@class cgas.core.EventBus
---@field private _listeners table<string, table<integer, function>>
---@field private _queue table<integer, {name: string, payload: table}>
---@field private _next_id integer
---@field private _dispatching boolean
---@field private _pending table<integer, {name: string, payload: table}>
local EventBus = M
EventBus.__index = EventBus

---Create a new EventBus.
---@return cgas.core.EventBus
function EventBus.new()
    local self = setmetatable({}, EventBus)
    self._listeners = {}
    self._queue = {}
    self._next_id = 0
    self._dispatching = false
    self._pending = {}
    return self
end

--- Subscribe to an event.
---@param event_name string
---@param callback function
---@return integer id
function EventBus:subscribe(event_name, callback)
    self._next_id = self._next_id + 1
    local id = self._next_id
    if not self._listeners[event_name] then
        self._listeners[event_name] = {}
    end
    self._listeners[event_name][id] = callback
    return id
end

--- Unsubscribe by id.
---@param id integer
function EventBus:unsubscribe(id)
    for event_name, listeners in pairs(self._listeners) do
        if listeners[id] then
            listeners[id] = nil
            -- Clean up empty listener tables
            local empty = true
            for _ in pairs(listeners) do
                empty = false
                break
            end
            if empty then
                self._listeners[event_name] = nil
            end
            return
        end
    end
end

--- Emit an event (queued, not dispatched immediately).
---@param event_name string
---@param payload table
function EventBus:emit(event_name, payload)
    if self._dispatching then
        table.insert(self._pending, { name = event_name, payload = payload })
    else
        table.insert(self._queue, { name = event_name, payload = payload })
    end
end

--- Dispatch all queued events.
function EventBus:dispatch()
    -- Swap queue
    local queue = self._queue
    self._queue = {}
    self._dispatching = true

    for _, event in ipairs(queue) do
        local listeners = self._listeners[event.name]
        if listeners then
            for _, callback in pairs(listeners) do
                local ok = pcall(callback, event.payload)
                if not ok then
                    print("[cgas.event] listener error")
                end
            end
        end
    end

    self._dispatching = false

    -- Move pending events to main queue for next dispatch
    if #self._pending > 0 then
        for _, event in ipairs(self._pending) do
            table.insert(self._queue, event)
        end
        self._pending = {}
    end
end

return M
